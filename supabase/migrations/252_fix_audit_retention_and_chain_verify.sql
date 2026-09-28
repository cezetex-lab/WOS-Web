-- =============================================================================
-- 252 — P2-13-01: retensi audit_log + verify_audit_chain yang chain-aware
-- =============================================================================
-- TEMUAN (forensik batch 02, 2026-09-25, BUKTI LIVE):
--   P2-13-01 "tidak ada cron retensi audit_log" — ternyata LEBIH TEPAT dari
--   kbarnya: fungsi `cleanup_audit_log()` SUDAH ADA di live (default 90 hari),
--   tapi isinya `DELETE FROM audit_log WHERE created_at < ...` — dan kolom
--   `created_at` TIDAK PERNAH ADA (kolomnya `timestamp`, 0 created_at).
--   Jadi fungsinya PASTI error kalau dipanggil, dan tidak ada cron yang
--   memanggilnya, sehingga tidak ada yang pernah tahu. Bug laten yang
--   terlihat benar dari luar — kelas yang sama dengan mv_admin_summary.
--
--   Gelombang audit sekarang ±130 baris/hari, semuanya dari aktivitas
--   setup/test. Estimasi 1 tahun tanpa retensi: 13.000-48.000 baris. Belum
--   masalah performa, tapi tabel tumbuh tanpa batas.
--
--   Dua masalah yang saling terkait:
--   (a) retensi tidak pernah jalan (bug kolom);
--   (b) kalau nanti DIAJARKAN, chain AKAN putus. `verify_audit_chain()` lama
--       menginisialisasi v_prev_row_hash := '0' tanpa membaca apa pun dari
--       DB, lalu meng-loop dari baris pertama yang tersisa. Setelah retensi
--       aktif, baris pertama itu punya prev_hash = hash baris yang SUDAH
--       dihapus → langsung reported BROKEN_LINK, selamanya. Guard yang selalu
--       merah = guard yang akan diabaikan.
--
-- MITIGASI:
--   1. `cleanup_audit_log()`: created_at → timestamp, default 90 → 365 hari.
--   2. `verify_audit_chain()`: parameter p_mode.
--        - 'strict' (default)  = perilaku lama persis, genesis '0'.
--        - 'chain-aware'        = genesis diambil dari prev_hash baris
--                                 pertama dalam range; kalau baris itu
--                                 prev_hash-nya bukan '0', dilaporkan sebagai
--                                 issue TIPE BARU 'CHAIN_TRUNCATED' —
--                                 bukan BROKEN_LINK. Jadi retensi sah dan
--                                 manipulasi bisa dibedakan.
--   3. Cron harian 04:30 UTC (slot 02:00 / 03:00 / 03:15 / 03:30 sudah dipakai).
--
-- YANG SENGAJA TIDAK DIUBAH:
--   * Rumus hash TIDAK disentuh sama sekali (masih id+timestamp+actor+action
--     +detail+prev_hash). Chain yang sudah tertulis tetap bisa diverifikasi.
--   * Tipe return verify_audit_chain tetap (issue_type, row_id, detail).
--   * cleanup_audit_log tetap RETURNS jsonb.
-- =============================================================================

-- 1. Perbaiki bug kolom + retensi 365 hari
CREATE OR REPLACE FUNCTION public.cleanup_audit_log(p_days integer DEFAULT 365)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_deleted INT;
BEGIN
  -- BUG LAMA: kolom 'created_at' tidak pernah ada di audit_log (kolomnya
  -- 'timestamp'), jadi fungsi ini PASTI error setiap kali dipanggil.
  DELETE FROM audit_log
   WHERE timestamp < NOW() - (p_days || ' days')::INTERVAL;
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'deleted', v_deleted, 'retention_days', p_days);
END;
$function$;

-- 2. verify_audit_chain: mode chain-aware
CREATE OR REPLACE FUNCTION public.verify_audit_chain(
  p_start_id integer DEFAULT NULL,
  p_end_id   integer DEFAULT NULL,
  p_mode     text    DEFAULT 'strict'
)
 RETURNS TABLE(issue_type text, row_id integer, detail text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_prev_row_hash TEXT;
  v_expected_hash TEXT;
  v_id INTEGER;
  v_ts TIMESTAMPTZ;
  v_actor TEXT;
  v_action TEXT;
  v_detail TEXT;
  v_prev TEXT;
  v_hash TEXT;
  v_first BOOLEAN := TRUE;
BEGIN
  FOR v_id, v_ts, v_actor, v_action, v_detail, v_prev, v_hash IN
    SELECT al.id, al.timestamp, al.actor, al.action, al.detail, al.prev_hash, al.row_hash
    FROM audit_log al
    WHERE (p_start_id IS NULL OR al.id >= p_start_id)
      AND (p_end_id IS NULL OR al.id <= p_end_id)
    ORDER BY al.id
  LOOP
    IF v_first THEN
      IF p_mode = 'strict' THEN
        -- Perilaku lama persis: genesis '0' tanpa membaca DB.
        v_prev_row_hash := '0';
      ELSE
        -- chain-aware: genesis diambil dari baris pertama yang tersisa.
        v_prev_row_hash := v_prev;
        IF v_prev != '0' THEN
          issue_type := 'CHAIN_TRUNCATED';
          row_id := v_id;
          detail := 'chain dimulai dari prev_hash=' || left(v_prev, 16) ||
                    ' (retensi aktif — bukan manipulasi)';
          RETURN NEXT;
        END IF;
      END IF;
      v_first := FALSE;
    END IF;

    IF v_prev != v_prev_row_hash THEN
      issue_type := 'BROKEN_LINK';
      row_id := v_id;
      detail := 'prev_hash mismatch at id ' || v_id;
      RETURN NEXT;
    END IF;

    v_expected_hash := encode(
      sha256(
        (COALESCE(v_id::TEXT, '') ||
         COALESCE(v_ts::TEXT, '') ||
         COALESCE(v_actor, '') ||
         COALESCE(v_action, '') ||
         COALESCE(v_detail, '') ||
         v_prev)::BYTEA
      ),
      'hex'
    );
    IF v_hash != v_expected_hash THEN
      issue_type := 'TAMPERED';
      row_id := v_id;
      detail := 'row_hash mismatch at id ' || v_id;
      RETURN NEXT;
    END IF;

    v_prev_row_hash := v_hash;
  END LOOP;
END;
$function$;

-- 3. Cron retensi harian. Slot 04:30 UTC belum dipakai (02:00, 03:00,
--    03:15, 03:30 sudah terpakai) sehingga tidak berebut dengan cron lain.
SELECT cron.schedule(
  'cleanup-audit-log',
  '30 4 * * *',
  'SELECT public.cleanup_audit_log()'
);
