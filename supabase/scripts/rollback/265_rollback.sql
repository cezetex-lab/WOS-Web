-- ============================================================================
-- 265_rollback.sql — batalkan migrasi 265 (Fix #14 §9 batch 2/5,
-- rewiring get_current_user_context ke user_role_assignments)
--
-- Dijalankan MANUAL via psql (file ini punya BEGIN/COMMIT sendiri —
-- berbeda dari file migrasi yang P4-nya forbid BEGIN/COMMIT).
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/scripts/rollback/265_rollback.sql
--
-- ISI ROLLBACK
--   1. Body fungsi dikembalikan ke PRE-IMAGE byte-exact (pg_get_functiondef LIVE
--      sebelum 265 diterapkan; salinan: .agents/logs/fix14-265-preimage-functiondef.sql)
--        md5(pg_get_functiondef) = 65c9b57823ffee398d45aaf4c3149e8b
--        md5(prosrc)             = 0227517266cd171bf6722f1b1cf7d599
--        length                  = 1211
--   2. ACL dikembalikan eksplisit ke pre-265 (defensif; CREATE OR REPLACE sudah
--      mempertahankan ACL, tapi ini mengunci kontrak supaya rollback tetap benar
--      walau ACL sempat berubah):
--        REVOKE EXECUTE ... FROM PUBLIC  (no-op di pre-265, PUBLIC memang tidak punya)
--        GRANT  EXECUTE ... TO authenticated, service_role  (sudah ada, idempoten)
--
-- CATATAN: 265 tidak mengubah signature, tidak mengubah attrs. Rollback ini
-- mengembalikan body + ACL; schema_migrations tidak disentuh oleh file ini.
--
-- Idempoten: jalan kedua kali tidak mengubah apa pun, tidak error.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public.get_current_user_context()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  v_emp RECORD;
  v_role RECORD;
  v_is_owner BOOLEAN;
BEGIN
  IF v_uid IS NULL THEN RETURN NULL; END IF;

  -- Check Owner identity (NOT role-based)
  SELECT check_owner_identity() INTO v_is_owner;

  IF v_is_owner THEN
    RETURN jsonb_build_object(
      'nrp', 'OWNER001',
      'nama', 'System Owner',
      'role', 'owner',
      'role_level', 5,
      'is_owner', TRUE,
      'business_unit_id', NULL,
      'email', (SELECT email FROM auth.users WHERE id = v_uid LIMIT 1)
    );
  END IF;

  -- Regular employee lookup
  SELECT * INTO v_emp FROM employees_master WHERE auth_id = v_uid LIMIT 1;
  IF v_emp IS NULL THEN RETURN NULL; END IF;

  SELECT * INTO v_role FROM user_roles WHERE nrp = v_emp.nrp LIMIT 1;

  RETURN jsonb_build_object(
    'nrp', v_emp.nrp,
    'nama', v_emp.nama,
    'role', COALESCE(v_role.role, 'worker'),
    'role_level', COALESCE(v_role.role_level, 1),
    'is_owner', FALSE,
    'business_unit_id', v_emp.business_unit_id,
    'email', v_emp.email
  );
END;
$function$;

-- (2) ACL pre-265 (defensif, idempoten).
REVOKE EXECUTE ON FUNCTION public.get_current_user_context() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_current_user_context() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_current_user_context() TO service_role;

COMMIT;
