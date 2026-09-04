-- Migration 136: Replace hardcoded authz with permission-based helpers
-- Overrides check_access_(), worker RPCs, and RLS policies

-- PART 1: Override check_access_() to use authz helpers
DROP FUNCTION IF EXISTS check_access_(TEXT, INT, TEXT);
CREATE OR REPLACE FUNCTION check_access_(p_nrp TEXT, p_min_level INT, p_min_tier TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  v_is_owner BOOLEAN;
  v_has_perm BOOLEAN;
BEGIN
  SELECT EXISTS (SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = TRUE) INTO v_is_owner;
  IF v_is_owner THEN RETURN TRUE; END IF;
  CASE p_min_tier
    WHEN 'MINIMALIS' THEN v_has_perm := authz_has_permission('profile.view');
    WHEN 'STANDAR' THEN v_has_perm := authz_has_permission('payroll.view_own');
    WHEN 'PREMIUM' THEN v_has_perm := authz_has_permission('kpi.view_team');
    WHEN 'ENTERPRISE' THEN v_has_perm := authz_has_permission('employee.view_all');
    ELSE v_has_perm := TRUE;
  END CASE;
  RETURN v_has_perm;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION check_access_(TEXT, INT, TEXT) TO authenticated;

DROP FUNCTION IF EXISTS get_worker_profile(TEXT);
CREATE OR REPLACE FUNCTION get_worker_profile(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE
  v_is_owner BOOLEAN;
  v_target RECORD;
BEGIN
  SELECT EXISTS (SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = TRUE) INTO v_is_owner;
  IF NOT v_is_owner AND NOT authz_in_scope(p_nrp) THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  SELECT employee_id, nrp, nama, email, divisi, jabatan, status_kerja, business_unit_id INTO v_target FROM employees_master WHERE nrp = p_nrp;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', FALSE, 'msg', 'Karyawan tidak ditemukan.'); END IF;
  RETURN jsonb_build_object('ok', TRUE, 'employee_id', v_target.employee_id, 'nrp', v_target.nrp, 'nama', v_target.nama, 'email', v_target.email, 'divisi', v_target.divisi, 'jabatan', v_target.jabatan, 'status_kerja', v_target.status_kerja, 'business_unit_id', v_target.business_unit_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP FUNCTION IF EXISTS get_hr_payroll(TEXT);
CREATE OR REPLACE FUNCTION get_hr_payroll(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE
  v_is_owner BOOLEAN;
BEGIN
  SELECT EXISTS (SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = TRUE) INTO v_is_owner;
  IF NOT v_is_owner AND NOT authz_in_scope(p_nrp) THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  IF NOT v_is_owner AND NOT authz_has_permission('payroll.view_own') THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Tidak ada hak akses payroll.');
  END IF;
  RETURN (SELECT COALESCE(jsonb_build_object('ok', TRUE, 'data', jsonb_agg(p.*)), jsonb_build_object('ok', TRUE, 'data', '[]'::jsonb)) FROM (SELECT payroll_period, basic_salary, allowances, deductions, overtime_pay, net_salary, status FROM hr_payroll WHERE nrp = p_nrp ORDER BY created_at DESC LIMIT 12) p);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP FUNCTION IF EXISTS get_hr_leave(TEXT);
CREATE OR REPLACE FUNCTION get_hr_leave(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE
  v_is_owner BOOLEAN;
BEGIN
  SELECT EXISTS (SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = TRUE) INTO v_is_owner;
  IF NOT v_is_owner AND NOT authz_in_scope(p_nrp) THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  RETURN (SELECT COALESCE(jsonb_build_object('ok', TRUE, 'data', jsonb_agg(l.*)), jsonb_build_object('ok', TRUE, 'data', '[]'::jsonb)) FROM (SELECT leave_type, start_date, end_date, status, reason FROM hr_leave WHERE nrp = p_nrp ORDER BY created_at DESC LIMIT 12) l);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP FUNCTION IF EXISTS get_worker_engagement(TEXT);
CREATE OR REPLACE FUNCTION get_worker_engagement(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE
  v_is_owner BOOLEAN;
BEGIN
  SELECT EXISTS (SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = TRUE) INTO v_is_owner;
  IF NOT v_is_owner AND NOT authz_in_scope(p_nrp) THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  RETURN jsonb_build_object('ok', TRUE, 'data', '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP FUNCTION IF EXISTS get_worker_learning(TEXT);
CREATE OR REPLACE FUNCTION get_worker_learning(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE
  v_is_owner BOOLEAN;
BEGIN
  SELECT EXISTS (SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = TRUE) INTO v_is_owner;
  IF NOT v_is_owner AND NOT authz_in_scope(p_nrp) THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  RETURN (SELECT COALESCE(jsonb_build_object('ok', TRUE, 'data', jsonb_agg(t.*)), jsonb_build_object('ok', TRUE, 'data', '[]'::jsonb)) FROM (SELECT course_name, status, completed_at FROM hr_training_catalog WHERE nrp = p_nrp ORDER BY created_at DESC LIMIT 12) t);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP FUNCTION IF EXISTS get_worker_benefits(TEXT);
CREATE OR REPLACE FUNCTION get_worker_benefits(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE
  v_is_owner BOOLEAN;
BEGIN
  SELECT EXISTS (SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = TRUE) INTO v_is_owner;
  IF NOT v_is_owner AND NOT authz_in_scope(p_nrp) THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  RETURN jsonb_build_object('ok', TRUE, 'data', '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP FUNCTION IF EXISTS get_worker_skills(TEXT);
CREATE OR REPLACE FUNCTION get_worker_skills(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE
  v_is_owner BOOLEAN;
BEGIN
  SELECT EXISTS (SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = TRUE) INTO v_is_owner;
  IF NOT v_is_owner AND NOT authz_in_scope(p_nrp) THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  RETURN jsonb_build_object('ok', TRUE, 'data', '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP FUNCTION IF EXISTS get_hr_overtime(TEXT);
CREATE OR REPLACE FUNCTION get_hr_overtime(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE
  v_is_owner BOOLEAN;
BEGIN
  SELECT EXISTS (SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = TRUE) INTO v_is_owner;
  IF NOT v_is_owner AND NOT authz_in_scope(p_nrp) THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  RETURN (SELECT COALESCE(jsonb_build_object('ok', TRUE, 'data', jsonb_agg(o.*)), jsonb_build_object('ok', TRUE, 'data', '[]'::jsonb)) FROM (SELECT date, hours, reason, status FROM hr_overtime WHERE nrp = p_nrp ORDER BY created_at DESC LIMIT 12) o);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP FUNCTION IF EXISTS get_worker_medical(TEXT);
CREATE OR REPLACE FUNCTION get_worker_medical(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE
  v_is_owner BOOLEAN;
BEGIN
  SELECT EXISTS (SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = TRUE) INTO v_is_owner;
  IF NOT v_is_owner AND NOT authz_in_scope(p_nrp) THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  RETURN jsonb_build_object('ok', TRUE, 'data', '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP FUNCTION IF EXISTS get_worker_notifications(TEXT);
CREATE OR REPLACE FUNCTION get_worker_notifications(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE
  v_is_owner BOOLEAN;
BEGIN
  SELECT EXISTS (SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = TRUE) INTO v_is_owner;
  IF NOT v_is_owner AND NOT authz_in_scope(p_nrp) THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  RETURN (SELECT COALESCE(jsonb_build_object('ok', TRUE, 'data', jsonb_agg(n.*)), jsonb_build_object('ok', TRUE, 'data', '[]'::jsonb)) FROM (SELECT title, message, created_at, is_read FROM worker_notifications WHERE nrp = p_nrp ORDER BY created_at DESC LIMIT 12) n);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP FUNCTION IF EXISTS get_worker_status(TEXT);
CREATE OR REPLACE FUNCTION get_worker_status(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE
  v_is_owner BOOLEAN;
  v_target RECORD;
BEGIN
  SELECT EXISTS (SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = TRUE) INTO v_is_owner;
  IF NOT v_is_owner AND NOT authz_in_scope(p_nrp) THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  SELECT em.nrp, em.nama, em.divisi, em.jabatan, em.status_kerja, ur.role, ur.role_level INTO v_target FROM employees_master em LEFT JOIN user_roles ur ON ur.nrp = em.nrp WHERE em.nrp = p_nrp;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', FALSE, 'msg', 'Karyawan tidak ditemukan.'); END IF;
  RETURN jsonb_build_object('ok', TRUE, 'nrp', v_target.nrp, 'nama', v_target.nama, 'divisi', v_target.divisi, 'jabatan', v_target.jabatan, 'status_kerja', v_target.status_kerja, 'role', v_target.role, 'role_level', v_target.role_level);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- PART 3: Override RLS policies to use authz
DROP POLICY IF EXISTS ur_select ON user_roles;
CREATE POLICY ur_select ON user_roles FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS hb_select ON hr_benefits;
CREATE POLICY hb_select ON hr_benefits FOR SELECT USING (auth.uid() IS NOT NULL AND (authz_in_scope(nrp) OR authz_has_permission('employee.view_all')));
DROP POLICY IF EXISTS htc1_select ON hr_training_catalog;
CREATE POLICY htc1_select ON hr_training_catalog FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS hkc_select ON hr_kpi_config;
CREATE POLICY hkc_select ON hr_kpi_config FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS ho_select ON hr_overtime;
CREATE POLICY ho_select ON hr_overtime FOR SELECT USING (auth.uid() IS NOT NULL AND (authz_in_scope(nrp) OR authz_has_permission('overtime.view_all')));
DROP POLICY IF EXISTS hp_select ON hr_payroll;
CREATE POLICY hp_select ON hr_payroll FOR SELECT USING (auth.uid() IS NOT NULL AND (authz_in_scope(nrp) OR authz_has_permission('payroll.view_all')));
DROP POLICY IF EXISTS hl_select ON hr_leave;
CREATE POLICY hl_select ON hr_leave FOR SELECT USING (auth.uid() IS NOT NULL AND (authz_in_scope(nrp) OR authz_has_permission('leave.approve')));
