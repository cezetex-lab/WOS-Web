-- Rollback 258 — kembalikan authz_in_scope() ke pre-image byte-exact.
-- Dijalankan MANUAL via psql (file rollback WAJIB punya BEGIN/COMMIT sendiri).
-- Pre-image = pg_get_functiondef hasil probe B2.23 (sha256 pre-image:
-- 4d2fdeb322af0316f7cea2d6450868374c3d00153ef4f9f4d2b23bb24d0044f5).
-- Membalik H2: atasan_nrp → manager_nrp (mengembalikan kondisi yang error).

BEGIN;

CREATE OR REPLACE FUNCTION public.authz_in_scope(p_target_nrp text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_caller TEXT := authz_current_nrp();
  v_scope TEXT;
  v_bu TEXT;
BEGIN
  IF EXISTS (SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = true) THEN
    RETURN TRUE;
  END IF;

  IF p_target_nrp = v_caller THEN RETURN TRUE; END IF;

  SELECT scope_type, scope_bu_id INTO v_scope, v_bu
  FROM user_role_assignments WHERE nrp = v_caller AND is_primary = TRUE LIMIT 1;

  IF v_scope IS NULL THEN RETURN FALSE; END IF;

  CASE v_scope
    WHEN 'SELF' THEN RETURN FALSE;
    WHEN 'TEAM' THEN
      RETURN EXISTS (
        SELECT 1 FROM hr_org ho1
        JOIN hr_org ho2 ON ho1.manager_nrp = ho2.manager_nrp
        WHERE ho1.nrp = v_caller AND ho2.nrp = p_target_nrp
      );
    WHEN 'DEPARTMENT' THEN
      RETURN EXISTS (
        SELECT 1 FROM employees_master em1
        JOIN employees_master em2 ON em1.divisi = em2.divisi
        WHERE em1.nrp = v_caller AND em2.nrp = p_target_nrp
      );
    WHEN 'BU' THEN
      RETURN EXISTS (
        SELECT 1 FROM employees_master em1
        JOIN employees_master em2 ON em1.business_unit_id = em2.business_unit_id
        WHERE em1.nrp = v_caller AND em2.nrp = p_target_nrp
      );
    WHEN 'DOMAIN' THEN
      RETURN EXISTS (
        SELECT 1 FROM employees_master em
        WHERE em.nrp = p_target_nrp AND em.business_unit_id = v_bu
      );
    WHEN 'ENTERPRISE' THEN
      RETURN TRUE;
    ELSE
      RETURN FALSE;
  END CASE;
END;
$function$;

COMMIT;
