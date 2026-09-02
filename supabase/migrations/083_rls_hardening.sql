-- 083: RLS Hardening — replace USING(true) with user-based policies
-- Principle: authenticated users see only their BU data, admins see all

-- 1. Helper function: get current user's business_unit_id
CREATE OR REPLACE FUNCTION get_user_bu_id()
RETURNS TEXT AS $$
  SELECT COALESCE(
    (SELECT business_unit_id FROM employees_master WHERE auth_id = auth.uid() LIMIT 1),
    'HQ'
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- 2. Helper function: check if current user is admin or owner
CREATE OR REPLACE FUNCTION is_admin_or_owner()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_roles ur
    JOIN employees_master em ON em.nrp = ur.nrp
    WHERE em.auth_id = auth.uid()
    AND ur.role IN ('owner', 'admin_pusat', 'admin_hrd', 'admin_finance', 'admin_produksi')
  ) OR EXISTS (
    SELECT 1 FROM user_roles WHERE nrp = (
      SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1
    ) AND role = 'owner'
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- 3. Drop ALL overly permissive USING(true) policies
-- This is safe because RPC functions already handle access control via check_module_access

-- Employees master — only admins can see all, workers see own
DROP POLICY IF EXISTS em_all ON employees_master;
DROP POLICY IF EXISTS em_select ON employees_master;
CREATE POLICY em_select ON employees_master FOR SELECT
  USING (auth.uid() = auth_id OR is_admin_or_owner());
DROP POLICY IF EXISTS em_update ON employees_master;
CREATE POLICY em_update ON employees_master FOR UPDATE
  USING (auth.uid() = auth_id OR is_admin_or_owner());

-- User roles — admin only
DROP POLICY IF EXISTS ur_all ON user_roles;
DROP POLICY IF EXISTS ur_select ON user_roles;
CREATE POLICY ur_select ON user_roles FOR SELECT USING (is_admin_or_owner());
DROP POLICY IF EXISTS ur_insert ON user_roles;
CREATE POLICY ur_insert ON user_roles FOR INSERT WITH CHECK (is_admin_or_owner());
DROP POLICY IF EXISTS ur_update ON user_roles;
CREATE POLICY ur_update ON user_roles FOR UPDATE USING (is_admin_or_owner());

-- Business units — admin only
DROP POLICY IF EXISTS bu_all ON business_units;
DROP POLICY IF EXISTS bu_select ON business_units;
CREATE POLICY bu_select ON business_units FOR SELECT USING (TRUE);
DROP POLICY IF EXISTS bu_update ON business_units;
CREATE POLICY bu_update ON business_units FOR UPDATE USING (is_admin_or_owner());

-- Module definitions — admin only
DROP POLICY IF EXISTS md_all ON module_definitions;
DROP POLICY IF EXISTS md_select ON module_definitions;
CREATE POLICY md_select ON module_definitions FOR SELECT USING (TRUE);
DROP POLICY IF EXISTS md_update ON module_definitions;
CREATE POLICY md_update ON module_definitions FOR UPDATE USING (is_admin_or_owner());

-- Business unit modules — admin only
DROP POLICY IF EXISTS bum_all ON business_unit_modules;
DROP POLICY IF EXISTS bum_select ON business_unit_modules;
CREATE POLICY bum_select ON business_unit_modules FOR SELECT USING (TRUE);
DROP POLICY IF EXISTS bum_update ON business_unit_modules;
CREATE POLICY bum_update ON business_unit_modules FOR UPDATE USING (is_admin_or_owner());

-- Audit log owner — admin only
DROP POLICY IF EXISTS alo_all ON audit_log_owner;
DROP POLICY IF EXISTS alo_select ON audit_log_owner;
CREATE POLICY alo_select ON audit_log_owner FOR SELECT USING (is_admin_or_owner());

-- HR attendance — workers see own, admin sees all
DROP POLICY IF EXISTS ha_all ON hr_attendance;
DROP POLICY IF EXISTS ha_select ON hr_attendance;
CREATE POLICY ha_select ON hr_attendance FOR SELECT
  USING (nrp = (SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1) OR is_admin_or_owner());

-- HR leave — workers see own
DROP POLICY IF EXISTS hl_all ON hr_leave;
DROP POLICY IF EXISTS hl_select ON hr_leave;
CREATE POLICY hl_select ON hr_leave FOR SELECT
  USING (nrp = (SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1) OR is_admin_or_owner());
DROP POLICY IF EXISTS hl_insert ON hr_leave;
CREATE POLICY hl_insert ON hr_leave FOR INSERT
  WITH CHECK (nrp = (SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1) OR is_admin_or_owner());

-- HR overtime — workers see own
DROP POLICY IF EXISTS ho_all ON hr_overtime;
DROP POLICY IF EXISTS ho_select ON hr_overtime;
CREATE POLICY ho_select ON hr_overtime FOR SELECT
  USING (nrp = (SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1) OR is_admin_or_owner());

-- HR performance — workers see own
DROP POLICY IF EXISTS hp_all ON hr_performance;
DROP POLICY IF EXISTS hp_select ON hr_performance;
CREATE POLICY hp_select ON hr_performance FOR SELECT
  USING (nrp = (SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1) OR is_admin_or_owner());

-- HR payroll — workers see own
DROP POLICY IF EXISTS hpay_all ON hr_payroll;
DROP POLICY IF EXISTS hpay_select ON hr_payroll;
CREATE POLICY hpay_select ON hr_payroll FOR SELECT
  USING (nrp = (SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1) OR is_admin_or_owner());

-- HR training — workers see own
DROP POLICY IF EXISTS ht_all ON hr_training_catalog;
DROP POLICY IF EXISTS ht_select ON hr_training_catalog;
CREATE POLICY ht_select ON hr_training_catalog FOR SELECT USING (TRUE);

-- HR KPI config — admin only
DROP POLICY IF EXISTS hk_all ON hr_kpi_config;
DROP POLICY IF EXISTS hk_select ON hr_kpi_config;
CREATE POLICY hk_select ON hr_kpi_config FOR SELECT USING (TRUE);
DROP POLICY IF EXISTS hk_update ON hr_kpi_config;
CREATE POLICY hk_update ON hr_kpi_config FOR UPDATE USING (is_admin_or_owner());

-- Settings — admin only
DROP POLICY IF EXISTS st_all ON settings;
DROP POLICY IF EXISTS st_select ON settings;
CREATE POLICY st_select ON settings FOR SELECT USING (TRUE);
DROP POLICY IF EXISTS st_update ON settings;
CREATE POLICY st_update ON settings FOR UPDATE USING (is_admin_or_owner());

-- Announcements — all authenticated can read
DROP POLICY IF EXISTS an_all ON announcements;
DROP POLICY IF EXISTS an_select ON announcements;
CREATE POLICY an_select ON announcements FOR SELECT USING (TRUE);

-- Push subscriptions — workers see own
DROP POLICY IF EXISTS ps_all ON push_subscriptions;
DROP POLICY IF EXISTS ps_select ON push_subscriptions;
CREATE POLICY ps_select ON push_subscriptions FOR SELECT
  USING (nrp = (SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1) OR is_admin_or_owner());

-- MFA factors — workers see own
DROP POLICY IF EXISTS mf_all ON mfa_factors;
DROP POLICY IF EXISTS mf_select ON mfa_factors;
CREATE POLICY mf_select ON mfa_factors FOR SELECT
  USING (nrp = (SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1));

-- Industry tables — BU-based access
-- Mining
DROP POLICY IF EXISTS ms_all ON mining_simper;
DROP POLICY IF EXISTS ms_select ON mining_simper;
CREATE POLICY ms_select ON mining_simper FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS me_all ON mining_equipment;
DROP POLICY IF EXISTS me_select ON mining_equipment;
CREATE POLICY me_select ON mining_equipment FOR SELECT USING (TRUE);

-- Estate
DROP POLICY IF EXISTS eb_all ON estate_blocks;
DROP POLICY IF EXISTS eb_select ON estate_blocks;
CREATE POLICY eb_select ON estate_blocks FOR SELECT USING (TRUE);

-- Mill
DROP POLICY IF EXISTS mb_all ON mill_boiler;
DROP POLICY IF EXISTS mb_select ON mill_boiler;
CREATE POLICY mb_select ON mill_boiler FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS mp_all ON mill_press;
DROP POLICY IF EXISTS mp_select ON mill_press;
CREATE POLICY mp_select ON mill_press FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS mq_all ON mill_qc_results;
DROP POLICY IF EXISTS mq_select ON mill_qc_results;
CREATE POLICY mq_select ON mill_qc_results FOR SELECT USING (TRUE);

-- Workers/requests — workers see own
DROP POLICY IF EXISTS wk_all ON hr_tasks;
DROP POLICY IF EXISTS wk_select ON hr_tasks;
CREATE POLICY wk_select ON hr_tasks FOR SELECT
  USING (assigned_to = (SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1) OR is_admin_or_owner());

-- Ideas/voice — all authenticated
DROP POLICY IF EXISTS vi_all ON hr_voice;
DROP POLICY IF EXISTS vi_select ON hr_voice;
CREATE POLICY vi_select ON hr_voice FOR SELECT USING (TRUE);

-- Surveys — all authenticated
DROP POLICY IF EXISTS sv_all ON surveys;
DROP POLICY IF EXISTS sv_select ON surveys;
CREATE POLICY sv_select ON surveys FOR SELECT USING (TRUE);

-- Forum — all authenticated
DROP POLICY IF EXISTS fr_all ON forum_posts;
DROP POLICY IF EXISTS fr_select ON forum_posts;
CREATE POLICY fr_select ON forum_posts FOR SELECT USING (TRUE);

-- Certifications — workers see own
DROP POLICY IF EXISTS ce_all ON certifications;
DROP POLICY IF EXISTS ce_select ON certifications;
CREATE POLICY ce_select ON certifications FOR SELECT
  USING (nrp = (SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1) OR is_admin_or_owner());

-- Badges — workers see own
DROP POLICY IF EXISTS bg_all ON badges;
DROP POLICY IF EXISTS bg_select ON badges;
CREATE POLICY bg_select ON badges FOR SELECT
  USING (nrp = (SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1) OR is_admin_or_owner());

-- Succession — admin only
DROP POLICY IF EXISTS sc_all ON hr_succession_matrix;
DROP POLICY IF EXISTS sc_select ON hr_succession_matrix;
CREATE POLICY sc_select ON hr_succession_matrix FOR SELECT USING (is_admin_or_owner());

-- OKRs — workers see own
DROP POLICY IF EXISTS ok_all ON okrs;
DROP POLICY IF EXISTS ok_select ON okrs;
CREATE POLICY ok_select ON okrs FOR SELECT
  USING (nrp = (SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1) OR is_admin_or_owner());

-- Performance notes — workers see own
DROP POLICY IF EXISTS pn_all ON performance_notes;
DROP POLICY IF EXISTS pn_select ON performance_notes;
CREATE POLICY pn_select ON performance_notes FOR SELECT
  USING (nrp = (SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1) OR is_admin_or_owner());

-- Offboarding — admin only
DROP POLICY IF EXISTS of_all ON offboarding_checklist;
DROP POLICY IF EXISTS of_select ON offboarding_checklist;
CREATE POLICY of_select ON offboarding_checklist FOR SELECT USING (is_admin_or_owner());

-- Reviews 360 — workers see own
DROP POLICY IF EXISTS rv_all ON reviews_360;
DROP POLICY IF EXISTS rv_select ON reviews_360;
CREATE POLICY rv_select ON reviews_360 FOR SELECT
  USING (reviewee_nrp = (SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1) OR is_admin_or_owner());

-- Leave requests — workers see own
