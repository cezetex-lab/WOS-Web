-- Migration 133: RLS tightening for sensitive tables
-- Replace USING(true) with proper auth checks on critical tables
-- RPCs already handle auth, but RLS is defense-in-depth

-- Helper: check if caller is admin or owner
CREATE OR REPLACE FUNCTION _is_admin_or_owner()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_roles WHERE nrp = (SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1)
    AND role IN ('owner','admin_pusat','admin_hrd','admin_finance','admin_produksi','admin_mining','admin_mill','admin_estate')
  ) OR EXISTS (
    SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = TRUE
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- employees_master: own data + admin/owner
DROP POLICY IF EXISTS "Allow all for service role" ON employees_master;
DROP POLICY IF EXISTS "Allow anon read" ON employees_master;
CREATE POLICY "emp_own_data" ON employees_master FOR ALL
  USING (auth_id = auth.uid() OR _is_admin_or_owner());

-- hr_payroll: own salary + finance/admin
DROP POLICY IF EXISTS "Allow all for service role" ON hr_payroll;
CREATE POLICY "payroll_own_data" ON hr_payroll FOR ALL
  USING (
    nrp = (SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1)
    OR _is_admin_or_owner()
  );

-- hr_performance: own KPI + admin
DROP POLICY IF EXISTS "Allow all for service role" ON hr_performance;
CREATE POLICY "perf_own_data" ON hr_performance FOR ALL
  USING (
    nrp = (SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1)
    OR _is_admin_or_owner()
  );

-- hr_attendance: own attendance + admin
DROP POLICY IF EXISTS "Allow all for service role" ON hr_attendance;
CREATE POLICY "att_own_data" ON hr_attendance FOR ALL
  USING (
    nrp = (SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1)
    OR _is_admin_or_owner()
  );

-- hr_leave: own leave + admin
DROP POLICY IF EXISTS "Allow all for service role" ON hr_leave;
CREATE POLICY "leave_own_data" ON hr_leave FOR ALL
  USING (
    nrp = (SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1)
    OR _is_admin_or_owner()
  );

-- hr_overtime: own overtime + admin
DROP POLICY IF EXISTS "Allow all for service role" ON hr_overtime;
CREATE POLICY "ot_own_data" ON hr_overtime FOR ALL
  USING (
    nrp = (SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1)
    OR _is_admin_or_owner()
  );

-- hr_requests: own requests + admin
DROP POLICY IF EXISTS "Allow all for service role" ON hr_requests;
CREATE POLICY "req_own_data" ON hr_requests FOR ALL
  USING (
    nrp = (SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1)
    OR _is_admin_or_owner()
  );

-- session_tokens: own sessions only
DROP POLICY IF EXISTS "Allow all for service role" ON session_tokens;
CREATE POLICY "session_own" ON session_tokens FOR ALL
  USING (nrp = (SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1));

-- otp_store: own OTP only
DROP POLICY IF EXISTS "Allow all for service role" ON otp_store;
CREATE POLICY "otp_own" ON otp_store FOR ALL
  USING (nrp = (SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1));

-- otp_attempts: own attempts only
DROP POLICY IF EXISTS "Allow all for service role" ON otp_attempts;
CREATE POLICY "otp_att_own" ON otp_attempts FOR ALL
  USING (nrp = (SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1));

-- worker_passwords: admin/owner only (never expose to workers)
DROP POLICY IF EXISTS "Allow all for service role" ON worker_passwords;
CREATE POLICY "pwd_admin_only" ON worker_passwords FOR ALL
  USING (_is_admin_or_owner());

-- audit_log: admin/owner only
DROP POLICY IF EXISTS "Allow all for service role" ON audit_log;
CREATE POLICY "audit_admin_only" ON audit_log FOR ALL
  USING (_is_admin_or_owner());

-- admin_roles: owner only
DROP POLICY IF EXISTS "rls_admin_roles_all" ON admin_roles;
CREATE POLICY "admin_roles_owner" ON admin_roles FOR ALL
  USING (EXISTS (SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = TRUE));

-- user_roles: admin/owner only
DROP POLICY IF EXISTS "Allow all for service role" ON user_roles;
DROP POLICY IF EXISTS "Allow read for authenticated" ON user_roles;
CREATE POLICY "ur_admin_only" ON user_roles FOR ALL
  USING (_is_admin_or_owner());

-- company_config: owner only for writes, admin for reads
DROP POLICY IF EXISTS "rls_config_all" ON company_config;
CREATE POLICY "config_read" ON company_config FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "config_write" ON company_config FOR UPDATE
  USING (EXISTS (SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = TRUE));

-- branding: owner only for writes, all for reads
DROP POLICY IF EXISTS "rls_branding_all" ON branding;
CREATE POLICY "branding_read" ON branding FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "branding_write" ON branding FOR ALL
  USING (EXISTS (SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = TRUE));

-- module_definitions: read all, owner writes
DROP POLICY IF EXISTS "md_select" ON module_definitions;
CREATE POLICY "md_read" ON module_definitions FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "md_write" ON module_definitions FOR ALL
  USING (EXISTS (SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = TRUE));
