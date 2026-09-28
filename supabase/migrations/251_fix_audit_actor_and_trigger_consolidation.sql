-- =============================================================================
-- 251 — P1-13-01: audit_log tidak mencatat AKTOR (519 dari 526 baris = 98,7%)
-- =============================================================================
-- TEMUAN (forensik batch 02, 2026-09-25, BUKTI LIVE):
--   `actor` terisi hanya 7 dari 526 baris. Penyebabnya BUKAN konfigurasi —
--   fungsi `_generic_audit_trigger_fixed()` pada ketiga cabang INSERT-nya tidak
--   menulis kolom `actor` sama sekali (tidak ada auth.uid(), tidak ada
--   current_setting, tidak ada apa pun). Kolomnya nullable → NULL diam-diam.
--   Hash-chain tetap utuh, tapi isinya tidak bisa dipakai untuk forensik:
--   siapa yang reset password / generate OTP / mengubah data TIDAK dapat
--   ditentukan. Hanya `admin_reset_password` (migrasi 194) yang mengisi
--   `actor`, karena hanya RPC itu yang punya v_caller dari authz.
--
-- MITIGASI (3 bagian):
--   1. `_generic_audit_trigger_fixed()` mengisi `actor`. Pola yang dipakai
--      `authz_current_nrp()` — SUDAH terbukti jalan di produksi (7 baris
--      RESET_PASSWORD berisi NRP asli), SECURITY DEFINER + STABLE + search_path
--      aman, dipakai 451x di codebase. Fallback 'SYSTEM' untuk context tanpa
--      JWT (cron, service_role, seeding).
--   2. `audit_log_hash_chain()` dapat advisory lock. Tanpa itu dua INSERT
--      bersamaan bisa membaca row_hash yang sama → rantai bercabang.
--   3. Konsolidasi trigger: hr_payroll punya 3 trigger audit, user_roles punya
--      2, dan keduanya tumpang-tindih pada event yang sama → 1 perubahan =
--      2 baris audit. Tiga trigger spesialis dimatikan, trigger generic
--      (trg_audit_hr_payroll, trg_audit_user_roles) tetap.
--
-- YANG SENGAJA TIDAK DIUBAH:
--   * Struktur JSON `detail` (kunci 'nrp'/'table'/'data'/'old'/'new') dan
--     kondisi `IF v_old IS DISTINCT FROM v_new` — persis seperti versi lama.
--     Hanya kolom `actor` yang ditambahkan.
--   * 519 baris LAMA TIDAK di-backfill. Mengisi `actor` pada baris yang sudah
--     ada akan mengubah `row_hash` (actor ikut masuk rumus hash) →-chain
--     melaporkan TAMPERED untuk 519 baris sekaligus. Backfill hanya mungkin
--     dengan re-hash ulang, dan itu keputusan tersendiri.
--   * Fungsi `_audit_payroll_change()` dan `_audit_role_change()` TIDAK
--     dihapus. Trigger-nya dimatikan, fungsinya dipertahankan sebagai dead
--     code supaya string 'ROLE_CHANGE'/'PAYROLL_CREATE' yang sudah jadi
--     kontrak di baseline (freeze P1-68-01 aktif) tidak ikut berubah.
--     Pembersihannya dijadwalkan saat regenerasi baseline (Fix #9).
--   * Baseline TIDAK diregenerasi.
--
-- CATATAN: string action specialist ('ROLE_CHANGE', 'PAYROLL_CREATE',
--   'PAYROLL_UPDATE') TIDAK ada di src/ — diverifikasi 2026-09-27. UI
--   AuditLog.tsx mengklasifikasi dengan action.includes('create'|'insert'|
--   'update'|'edit'|'delete'|'remove'); format generic
--   ("UPDATE user_roles") tetap cocok, dan 'ROLE_CHANGE' yang sebelumnya tidak
--   match cabang mana pun justru jadi terklasifikasi benar.
-- =============================================================================

-- 1. Generic trigger: tambahkan actor
CREATE OR REPLACE FUNCTION public._generic_audit_trigger_fixed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_action TEXT;
  v_nrp TEXT;
  v_old JSONB;
  v_new JSONB;
  v_actor TEXT;
BEGIN
  v_action := TG_OP || ' ' || TG_TABLE_NAME;
  v_nrp := COALESCE(NEW.nrp, OLD.nrp, 'SYSTEM');
  -- P1-13-01: actor yang sebenarnya melakukan perubahan. authz_current_nrp()
  -- sudah SECURITY DEFINER + STABLE dan terbukti mengembalikan NRP asli saat
  -- dipanggil dari RPC user yang terautentikasi.
  v_actor := COALESCE(public.authz_current_nrp(), 'SYSTEM');

  IF TG_OP = 'INSERT' THEN
    v_new := to_jsonb(NEW);
    INSERT INTO audit_log (actor, action, detail, timestamp)
    VALUES (v_actor, v_action, jsonb_build_object('nrp', v_nrp, 'table', TG_TABLE_NAME, 'data', v_new)::text, NOW());
  ELSIF TG_OP = 'UPDATE' THEN
    v_old := to_jsonb(OLD);
    v_new := to_jsonb(NEW);
    IF v_old IS DISTINCT FROM v_new THEN
      INSERT INTO audit_log (actor, action, detail, timestamp)
      VALUES (v_actor, v_action, jsonb_build_object('nrp', v_nrp, 'table', TG_TABLE_NAME, 'old', v_old, 'new', v_new)::text, NOW());
    END IF;
  ELSIF TG_OP = 'DELETE' THEN
    v_old := to_jsonb(OLD);
    INSERT INTO audit_log (actor, action, detail, timestamp)
    VALUES (v_actor, v_action, jsonb_build_object('nrp', v_nrp, 'table', TG_TABLE_NAME, 'data', v_old)::text, NOW());
  END IF;

  IF TG_OP = 'DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END;
$function$;

-- 2. Hash chain: advisory lock gegen race condition
CREATE OR REPLACE FUNCTION public.audit_log_hash_chain()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_prev_hash TEXT;
BEGIN
  -- Tanpa lock, dua INSERT bersamaan bisa membaca row_hash yang sama dan
  -- membuat rantai bercabang (chain tidak lagi lurus). Lock ini diserialisasi
  -- per-transaksi sehingga hanya boleh satu penulisan audit pada satu waktu.
  PERFORM pg_advisory_xact_lock(hashtext('audit_log_hash_chain'));

  SELECT row_hash INTO v_prev_hash FROM audit_log ORDER BY id DESC LIMIT 1;

  IF v_prev_hash IS NULL THEN
    v_prev_hash := '0';
  END IF;

  NEW.prev_hash := v_prev_hash;
  NEW.row_hash := encode(
    sha256(
      (COALESCE(NEW.id::TEXT, '') ||
       COALESCE(NEW.timestamp::TEXT, '') ||
       COALESCE(NEW.actor, '') ||
       COALESCE(NEW.action, '') ||
       COALESCE(NEW.detail, '') ||
       v_prev_hash)::BYTEA
    ),
    'hex'
  );
  RETURN NEW;
END;
$function$;

-- 3. Konsolidasi trigger (fungsi spesialis TIDAK dihapus — lihat header)
DROP TRIGGER IF EXISTS trg_audit_payroll_insert ON public.hr_payroll;
DROP TRIGGER IF EXISTS trg_audit_payroll_update ON public.hr_payroll;
DROP TRIGGER IF EXISTS trg_audit_role_change ON public.user_roles;
