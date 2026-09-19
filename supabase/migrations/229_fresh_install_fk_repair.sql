-- ================================================================
-- 229_fresh_install_fk_repair.sql — policy yang harus dipasang SETELAH 141
--
-- 008_restore_missing_objects.sql membuat 25 tabel (schema-only, tanpa policy).
-- Semua POLICY (DROP IF EXISTS + CREATE) dipindah ke berkas ini karena:
--   - ai_rate_limits policy mereferensi employees_master.auth_id (kolom baru di 071);
--   - hr_okr_results/hr_survey_responses policy mereferensi hr_okrs/hr_surveys (141).
-- 229 posisinya > 141 sehingga objek yang direferensi sudah ada; idempoten di live.
-- FK ke hr_okrs/hr_surveys TIDAK dipasang (type mismatch integer→text; tanpa constraint live).
-- ================================================================

DROP POLICY IF EXISTS ai_ratelimit_admin_all ON public.ai_rate_limits;
CREATE POLICY ai_ratelimit_admin_all ON public.ai_rate_limits FOR ALL TO PUBLIC USING (((EXISTS ( SELECT 1
   FROM employees_master e
  WHERE ((e.auth_id = auth.uid()) AND (e.role_level >= 4)))) OR (EXISTS ( SELECT 1
   FROM system_owner_identity o
  WHERE ((o.auth_id = auth.uid()) AND (o.is_active = true))))));
DROP POLICY IF EXISTS ai_ratelimit_own_insert ON public.ai_rate_limits;
CREATE POLICY ai_ratelimit_own_insert ON public.ai_rate_limits FOR INSERT TO PUBLIC WITH CHECK ((nrp = ( SELECT employees_master.nrp
   FROM employees_master
  WHERE (employees_master.auth_id = auth.uid())
 LIMIT 1)));
DROP POLICY IF EXISTS ai_ratelimit_own_read ON public.ai_rate_limits;
CREATE POLICY ai_ratelimit_own_read ON public.ai_rate_limits FOR SELECT TO PUBLIC USING ((nrp = ( SELECT employees_master.nrp
   FROM employees_master
  WHERE (employees_master.auth_id = auth.uid())
 LIMIT 1)));
DROP POLICY IF EXISTS ai_ratelimit_own_update ON public.ai_rate_limits;
CREATE POLICY ai_ratelimit_own_update ON public.ai_rate_limits FOR UPDATE TO PUBLIC USING ((nrp = ( SELECT employees_master.nrp
   FROM employees_master
  WHERE (employees_master.auth_id = auth.uid())
 LIMIT 1)));
DROP POLICY IF EXISTS rls_ai_rate_limits ON public.ai_rate_limits;
CREATE POLICY rls_ai_rate_limits ON public.ai_rate_limits FOR ALL TO PUBLIC USING (authz_check_admin('employee.view_all'::text));
DROP POLICY IF EXISTS rls_api_keys ON public.api_keys;
CREATE POLICY rls_api_keys ON public.api_keys FOR ALL TO PUBLIC USING (authz_check_admin('employee.view_all'::text));
DROP POLICY IF EXISTS rls_api_rate_limits ON public.api_rate_limits;
CREATE POLICY rls_api_rate_limits ON public.api_rate_limits FOR ALL TO PUBLIC USING (authz_check_admin('employee.view_all'::text));
DROP POLICY IF EXISTS dc_admin ON public.dashboard_cache;
CREATE POLICY dc_admin ON public.dashboard_cache FOR ALL TO PUBLIC USING (false);
DROP POLICY IF EXISTS rls_authz_estate_field ON public.estate_field;
CREATE POLICY rls_authz_estate_field ON public.estate_field FOR ALL TO PUBLIC USING ((authz_in_scope(authz_current_nrp()) OR authz_check_admin('employee.view_all'::text) OR (EXISTS ( SELECT 1
   FROM system_owner_identity
  WHERE ((system_owner_identity.auth_id = auth.uid()) AND (system_owner_identity.is_active = true))))));
DROP POLICY IF EXISTS rls_authz_estate_irrigation ON public.estate_irrigation;
CREATE POLICY rls_authz_estate_irrigation ON public.estate_irrigation FOR ALL TO PUBLIC USING ((authz_in_scope(authz_current_nrp()) OR authz_check_admin('employee.view_all'::text) OR (EXISTS ( SELECT 1
   FROM system_owner_identity
  WHERE ((system_owner_identity.auth_id = auth.uid()) AND (system_owner_identity.is_active = true))))));
DROP POLICY IF EXISTS rls_authz_estate_nursery ON public.estate_nursery;
CREATE POLICY rls_authz_estate_nursery ON public.estate_nursery FOR ALL TO PUBLIC USING ((authz_in_scope(authz_current_nrp()) OR authz_check_admin('employee.view_all'::text) OR (EXISTS ( SELECT 1
   FROM system_owner_identity
  WHERE ((system_owner_identity.auth_id = auth.uid()) AND (system_owner_identity.is_active = true))))));
DROP POLICY IF EXISTS rls_authz_estate_transport ON public.estate_transport;
CREATE POLICY rls_authz_estate_transport ON public.estate_transport FOR ALL TO PUBLIC USING ((authz_in_scope(authz_current_nrp()) OR authz_check_admin('employee.view_all'::text) OR (EXISTS ( SELECT 1
   FROM system_owner_identity
  WHERE ((system_owner_identity.auth_id = auth.uid()) AND (system_owner_identity.is_active = true))))));
DROP POLICY IF EXISTS rls_authz_estate_yield ON public.estate_yield;
CREATE POLICY rls_authz_estate_yield ON public.estate_yield FOR ALL TO PUBLIC USING ((authz_in_scope(authz_current_nrp()) OR authz_check_admin('employee.view_all'::text) OR (EXISTS ( SELECT 1
   FROM system_owner_identity
  WHERE ((system_owner_identity.auth_id = auth.uid()) AND (system_owner_identity.is_active = true))))));
DROP POLICY IF EXISTS hr_audit_c_auth ON public.hr_audit_chain;
CREATE POLICY hr_audit_c_auth ON public.hr_audit_chain FOR ALL TO PUBLIC USING ((auth.uid() IS NOT NULL));
DROP POLICY IF EXISTS hr_okr_res_auth ON public.hr_okr_results;
CREATE POLICY hr_okr_res_auth ON public.hr_okr_results FOR ALL TO PUBLIC USING ((auth.uid() IS NOT NULL));
DROP POLICY IF EXISTS hr_shift_s_auth ON public.hr_shift_swaps;
CREATE POLICY hr_shift_s_auth ON public.hr_shift_swaps FOR ALL TO PUBLIC USING ((auth.uid() IS NOT NULL));
DROP POLICY IF EXISTS hr_survey__auth ON public.hr_survey_responses;
CREATE POLICY hr_survey__auth ON public.hr_survey_responses FOR ALL TO PUBLIC USING ((auth.uid() IS NOT NULL));
DROP POLICY IF EXISTS hr_task_bo_auth ON public.hr_task_board;
CREATE POLICY hr_task_bo_auth ON public.hr_task_board FOR ALL TO PUBLIC USING ((auth.uid() IS NOT NULL));
DROP POLICY IF EXISTS rls_authz_mill_breakdown ON public.mill_breakdown;
CREATE POLICY rls_authz_mill_breakdown ON public.mill_breakdown FOR ALL TO PUBLIC USING ((authz_in_scope(authz_current_nrp()) OR authz_check_admin('employee.view_all'::text) OR (EXISTS ( SELECT 1
   FROM system_owner_identity
  WHERE ((system_owner_identity.auth_id = auth.uid()) AND (system_owner_identity.is_active = true))))));
DROP POLICY IF EXISTS rls_authz_mill_qc ON public.mill_qc;
CREATE POLICY rls_authz_mill_qc ON public.mill_qc FOR ALL TO PUBLIC USING ((authz_in_scope(authz_current_nrp()) OR authz_check_admin('employee.view_all'::text) OR (EXISTS ( SELECT 1
   FROM system_owner_identity
  WHERE ((system_owner_identity.auth_id = auth.uid()) AND (system_owner_identity.is_active = true))))));
DROP POLICY IF EXISTS rls_authz_mill_shift ON public.mill_shift;
CREATE POLICY rls_authz_mill_shift ON public.mill_shift FOR ALL TO PUBLIC USING ((authz_in_scope(authz_current_nrp()) OR authz_check_admin('employee.view_all'::text) OR (EXISTS ( SELECT 1
   FROM system_owner_identity
  WHERE ((system_owner_identity.auth_id = auth.uid()) AND (system_owner_identity.is_active = true))))));
DROP POLICY IF EXISTS rls_authz_mining_fatigue ON public.mining_fatigue;
CREATE POLICY rls_authz_mining_fatigue ON public.mining_fatigue FOR ALL TO PUBLIC USING ((authz_in_scope(authz_current_nrp()) OR authz_check_admin('employee.view_all'::text) OR (EXISTS ( SELECT 1
   FROM system_owner_identity
  WHERE ((system_owner_identity.auth_id = auth.uid()) AND (system_owner_identity.is_active = true))))));
DROP POLICY IF EXISTS rls_authz_mining_fuel ON public.mining_fuel;
CREATE POLICY rls_authz_mining_fuel ON public.mining_fuel FOR ALL TO PUBLIC USING ((authz_in_scope(authz_current_nrp()) OR authz_check_admin('employee.view_all'::text) OR (EXISTS ( SELECT 1
   FROM system_owner_identity
  WHERE ((system_owner_identity.auth_id = auth.uid()) AND (system_owner_identity.is_active = true))))));
DROP POLICY IF EXISTS rls_authz_mining_jsa ON public.mining_jsa;
CREATE POLICY rls_authz_mining_jsa ON public.mining_jsa FOR ALL TO PUBLIC USING ((authz_in_scope(authz_current_nrp()) OR authz_check_admin('employee.view_all'::text) OR (EXISTS ( SELECT 1
   FROM system_owner_identity
  WHERE ((system_owner_identity.auth_id = auth.uid()) AND (system_owner_identity.is_active = true))))));
DROP POLICY IF EXISTS rls_authz_mining_production ON public.mining_production;
CREATE POLICY rls_authz_mining_production ON public.mining_production FOR ALL TO PUBLIC USING ((authz_in_scope(authz_current_nrp()) OR authz_check_admin('employee.view_all'::text) OR (EXISTS ( SELECT 1
   FROM system_owner_identity
  WHERE ((system_owner_identity.auth_id = auth.uid()) AND (system_owner_identity.is_active = true))))));
DROP POLICY IF EXISTS rls_authz_mining_safety ON public.mining_safety;
CREATE POLICY rls_authz_mining_safety ON public.mining_safety FOR ALL TO PUBLIC USING ((authz_in_scope(authz_current_nrp()) OR authz_check_admin('employee.view_all'::text) OR (EXISTS ( SELECT 1
   FROM system_owner_identity
  WHERE ((system_owner_identity.auth_id = auth.uid()) AND (system_owner_identity.is_active = true))))));
DROP POLICY IF EXISTS all_service ON public.safety_incidents;
CREATE POLICY all_service ON public.safety_incidents FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS select_auth ON public.safety_incidents;
CREATE POLICY select_auth ON public.safety_incidents FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS webhook_lo_auth ON public.webhook_logs;
CREATE POLICY webhook_lo_auth ON public.webhook_logs FOR SELECT TO PUBLIC USING ((auth.uid() IS NOT NULL));
