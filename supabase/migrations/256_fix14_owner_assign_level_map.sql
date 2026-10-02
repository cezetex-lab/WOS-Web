-- =============================================================================
-- 256_fix14_owner_assign_level_map.sql
-- Fix #14 §8 — selaraskan pemetaan level owner_assign_admin_user() dengan §5d
-- =============================================================================
-- Alasan (temuan T4, fakta probe B2.10–B2.11):
--   Fungsi live memetakan  CASE WHEN 'admin_pusat' THEN 5
--                                   WHEN 'admin_hrd','admin_finance',
--                                        'admin_operasional' THEN 4
--                                   ELSE 3 END
--   §5d mengunci: ADMIN ROLE = FUNGSI, bukan level → semua admin_* = level 3
--   (Manager), seperti NRP100–106 pada migrasi 255.
--
--   Pemetaan lama TIDAK dorman: dipanggil internal oleh
--   admin_pusat_manage_admin('assign', ...) dan langsung dari UI
--   src/pages/OwnerDashboard.tsx:398. Tanpa perubahan ini, setiap penugasan admin
--   oleh Owner menimpa role_level hasil backfill 255 (admin_pusat kembali ke 5).
--
-- Bukti aman (tanpa regresi):
--   - Saat ini tidak ada baris ber-level 5 (user_roles 17/17 = 1).
--   - Gate check_module_access() hanya menambah akses saat level naik
--     (module_definitions.minimum_tier_required maksimum 3).
--
-- Blok ELSE sengaja dipertahankan bernilai 3 (semua nilai lama ELSE = 3) agar
-- perilaku non-admin tidak berubah. Cabang itu praktis tak terjangkau saat ini:
-- gate EXISTS di atas hanya menerima role_code yang ada di admin_roles, dan
-- tabel itu berisi 7 role_code admin_* saja.
--
-- SELURUH body selain blok CASE itu PERSIS sama dengan versi live
-- (dicek ulang lewat SELECT prosrc FROM pg_proc pada 2026-10-02).
-- SECURITY DEFINER + SET search_path ditulis EKSPLISIT karena CREATE OR REPLACE
-- menimpa properti yang tidak disebutkan (SECURITY DEFINER akan hilang).
-- Properti lain (VOLATILE, bukan STRICT, RETURNS jsonb) juga ditulis eksplisit
-- agar tidak berubah. GRANT tidak perlu diulang: CREATE OR REPLACE tidak
-- mengubah kepemilikan maupun ACL.
--
-- Rollback: supabase/scripts/rollback/256_rollback.sql (memuat body lama 5/4/3)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.owner_assign_admin_user(p_nrp text, p_role_code text)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, extensions
AS $fn$

DECLARE v_ctx JSONB := get_current_user_context(); v_exists BOOLEAN;
BEGIN
  IF v_ctx IS NULL OR NOT check_owner_identity() THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Owner only.');
  END IF;
  SELECT EXISTS(SELECT 1 FROM admin_roles WHERE role_code = p_role_code AND is_active = TRUE) INTO v_exists;
  IF NOT v_exists THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Role not found or inactive.');
  END IF;
  -- Upsert user_roles for this NRP
  -- PERUBAHAN SATU-SATUNYA (256): pemetaan level diselaraskan ke §5d —
  -- admin adalah fungsi, bukan tingkat; semua admin_* = level 3.
  INSERT INTO user_roles (nrp, role, role_level)
  SELECT p_nrp, p_role_code, CASE
    WHEN p_role_code LIKE 'admin_%' THEN 3
    ELSE 3
  END
  ON CONFLICT (nrp) DO UPDATE SET role = p_role_code, role_level = EXCLUDED.role_level;
  INSERT INTO audit_log_owner (owner_nrp, action, target_type, target_id, new_value)
  VALUES ((v_ctx->>'nrp'), 'ASSIGN_ADMIN_USER', 'user', p_nrp, jsonb_build_object('role_code', p_role_code));
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'Admin user assigned.');
END;
$fn$;
