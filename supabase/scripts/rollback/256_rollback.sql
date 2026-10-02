-- =============================================================================
-- 256_rollback.sql — kembalikan owner_assign_admin_user() ke pemetaan level lama
-- =============================================================================
-- Cara pakai (JALANKAN MANUAL, bukan lewat apply-migration.mjs):
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/scripts/rollback/256_rollback.sql
--   atau tempelkan SQL di bawah ke SQL Editor.
--
-- Pre-image = body live sebelum migrasi 256 (SELECT prosrc FROM pg_proc,
-- 2026-10-02): pemetaan admin_pusat→5, admin_hrd/admin_finance/admin_operasional→4,
-- ELSE 3. Properti: SECURITY DEFINER, search_path=public, extensions, VOLATILE,
-- RETURNS jsonb, bukan STRICT.
--
-- Dibuat bersama migrasi 256, belum pernah dijalankan.
-- =============================================================================

BEGIN;

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
  -- PEMETAAN LAMA (pre-256): 5 / 4 / 3 — dikembalikan apa adanya.
  INSERT INTO user_roles (nrp, role, role_level)
  SELECT p_nrp, p_role_code, CASE
    WHEN p_role_code = 'admin_pusat' THEN 5
    WHEN p_role_code IN ('admin_hrd', 'admin_finance', 'admin_operasional') THEN 4
    ELSE 3
  END
  ON CONFLICT (nrp) DO UPDATE SET role = p_role_code, role_level = EXCLUDED.role_level;
  INSERT INTO audit_log_owner (owner_nrp, action, target_type, target_id, new_value)
  VALUES ((v_ctx->>'nrp'), 'ASSIGN_ADMIN_USER', 'user', p_nrp, jsonb_build_object('role_code', p_role_code));
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'Admin user assigned.');
END;
$fn$;

COMMIT;
