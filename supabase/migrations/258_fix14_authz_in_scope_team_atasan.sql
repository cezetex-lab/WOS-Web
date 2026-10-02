-- Fix #14 §9 P2-F14-H (keputusan user: H2) — authz_in_scope() cabang 'TEAM'
-- memakai hr_org.manager_nrp, tapi kolom itu TIDAK ADA. hr_org hanya punya
-- atasan_nrp. Akibatnya cabang TEAM error saat runtime (bukan sekadar false).
--
-- Bukti (probe B2.22 + B2.23, 2026-10-01):
--   B3 hr_org columns = nrp, atasan_nrp, status, effective_from, effective_to,
--                       created_at, updated_at  (7 kolom, TANPA manager_nrp)
--   Q4 scope_type distinct = BU 3, ENTERPRISE 4, SELF 9  → TEAM = 0 baris
--   (scope_type DEPARTMENT = 0 dan DOMAIN = 0 juga; tidak disentuh di sini)
--
-- PERUBAHAN SATU-SATUNYA dari pre-image: manager_nrp → atasan_nrp (2 baris).
-- Body selebihnya byte-identik hasil pg_get_functiondef (probe B1).
-- WAJIB preserve: STABLE SECURITY DEFINER, SET search_path TO 'public','extensions',
-- signature (p_target_nrp text) → RETURNS boolean.
--
-- P4: TANPA BEGIN/COMMIT (wrapper apply-migration.mjs membungkus sendiri).

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
        JOIN hr_org ho2 ON ho1.atasan_nrp = ho2.atasan_nrp
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
$function$
