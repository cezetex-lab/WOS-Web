-- Migration 137: Fix remaining USING(true) RLS policies
-- 59 tables: 20 scope-based + 39 authenticated-only

-- PART 1: Scope-based policies (20 tables with nrp column)
DROP POLICY IF EXISTS "daftar_bar_authz" ON daftar_baru;
CREATE POLICY "daftar_bar_authz" ON daftar_baru FOR SELECT USING (
  auth.uid() IS NOT NULL AND (
    authz_in_scope(daftar_baru.nrp) OR authz_has_permission('employee.view_all')
  )
);
DROP POLICY IF EXISTS "hr_capabil_authz" ON hr_capability;
CREATE POLICY "hr_capabil_authz" ON hr_capability FOR SELECT USING (
  auth.uid() IS NOT NULL AND (
    authz_in_scope(hr_capability.nrp) OR authz_has_permission('employee.view_all')
  )
);
DROP POLICY IF EXISTS "hr_coachin_authz" ON hr_coaching;
CREATE POLICY "hr_coachin_authz" ON hr_coaching FOR SELECT USING (
  auth.uid() IS NOT NULL AND (
    authz_in_scope(hr_coaching.nrp) OR authz_has_permission('employee.view_all')
  )
);
DROP POLICY IF EXISTS "hr_critica_authz" ON hr_critical;
CREATE POLICY "hr_critica_authz" ON hr_critical FOR SELECT USING (
  auth.uid() IS NOT NULL AND (
    authz_in_scope(hr_critical.nrp) OR authz_has_permission('employee.view_all')
  )
);
DROP POLICY IF EXISTS "hr_engagem_authz" ON hr_engagement;
CREATE POLICY "hr_engagem_authz" ON hr_engagement FOR SELECT USING (
  auth.uid() IS NOT NULL AND (
    authz_in_scope(hr_engagement.nrp) OR authz_has_permission('employee.view_all')
  )
);
DROP POLICY IF EXISTS "hr_exit_cl_authz" ON hr_exit_clearance;
CREATE POLICY "hr_exit_cl_authz" ON hr_exit_clearance FOR SELECT USING (
  auth.uid() IS NOT NULL AND (
    authz_in_scope(hr_exit_clearance.nrp) OR authz_has_permission('employee.view_all')
  )
);
DROP POLICY IF EXISTS "hr_kpi_cal_authz" ON hr_kpi_calc_log;
CREATE POLICY "hr_kpi_cal_authz" ON hr_kpi_calc_log FOR SELECT USING (
  auth.uid() IS NOT NULL AND (
    authz_in_scope(hr_kpi_calc_log.nrp) OR authz_has_permission('employee.view_all')
  )
);
DROP POLICY IF EXISTS "hr_learnin_authz" ON hr_learning;
CREATE POLICY "hr_learnin_authz" ON hr_learning FOR SELECT USING (
  auth.uid() IS NOT NULL AND (
    authz_in_scope(hr_learning.nrp) OR authz_has_permission('employee.view_all')
  )
);
DROP POLICY IF EXISTS "hr_medical_authz" ON hr_medical_checkup;
CREATE POLICY "hr_medical_authz" ON hr_medical_checkup FOR SELECT USING (
  auth.uid() IS NOT NULL AND (
    authz_in_scope(hr_medical_checkup.nrp) OR authz_has_permission('employee.view_all')
  )
);
DROP POLICY IF EXISTS "hr_notific_authz" ON hr_notifications;
CREATE POLICY "hr_notific_authz" ON hr_notifications FOR SELECT USING (
  auth.uid() IS NOT NULL AND (
    authz_in_scope(hr_notifications.nrp) OR authz_has_permission('employee.view_all')
  )
);
DROP POLICY IF EXISTS "hr_org_authz" ON hr_org;
CREATE POLICY "hr_org_authz" ON hr_org FOR SELECT USING (
  auth.uid() IS NOT NULL AND (
    authz_in_scope(hr_org.nrp) OR authz_has_permission('employee.view_all')
  )
);
DROP POLICY IF EXISTS "hr_plantat_authz" ON hr_plantation_harvest;
CREATE POLICY "hr_plantat_authz" ON hr_plantation_harvest FOR SELECT USING (
  auth.uid() IS NOT NULL AND (
    authz_in_scope(hr_plantation_harvest.nrp) OR authz_has_permission('employee.view_all')
  )
);
DROP POLICY IF EXISTS "hr_product_authz" ON hr_production_daily;
CREATE POLICY "hr_product_authz" ON hr_production_daily FOR SELECT USING (
  auth.uid() IS NOT NULL AND (
    authz_in_scope(hr_production_daily.nrp) OR authz_has_permission('employee.view_all')
  )
);
DROP POLICY IF EXISTS "hr_relatio_authz" ON hr_relations;
CREATE POLICY "hr_relatio_authz" ON hr_relations FOR SELECT USING (
  auth.uid() IS NOT NULL AND (
    authz_in_scope(hr_relations.nrp) OR authz_has_permission('employee.view_all')
  )
);
DROP POLICY IF EXISTS "hr_safety_authz" ON hr_safety;
CREATE POLICY "hr_safety_authz" ON hr_safety FOR SELECT USING (
  auth.uid() IS NOT NULL AND (
    authz_in_scope(hr_safety.nrp) OR authz_has_permission('employee.view_all')
  )
);
DROP POLICY IF EXISTS "hr_skills_authz" ON hr_skills;
CREATE POLICY "hr_skills_authz" ON hr_skills FOR SELECT USING (
  auth.uid() IS NOT NULL AND (
    authz_in_scope(hr_skills.nrp) OR authz_has_permission('employee.view_all')
  )
);
DROP POLICY IF EXISTS "incentives_authz" ON incentives;
CREATE POLICY "incentives_authz" ON incentives FOR SELECT USING (
  auth.uid() IS NOT NULL AND (
    authz_in_scope(incentives.nrp) OR authz_has_permission('employee.view_all')
  )
);
DROP POLICY IF EXISTS "shift_assi_authz" ON shift_assignments;
CREATE POLICY "shift_assi_authz" ON shift_assignments FOR SELECT USING (
  auth.uid() IS NOT NULL AND (
    authz_in_scope(shift_assignments.nrp) OR authz_has_permission('employee.view_all')
  )
);
DROP POLICY IF EXISTS "timesheets_authz" ON timesheets;
CREATE POLICY "timesheets_authz" ON timesheets FOR SELECT USING (
  auth.uid() IS NOT NULL AND (
    authz_in_scope(timesheets.nrp) OR authz_has_permission('employee.view_all')
  )
);
DROP POLICY IF EXISTS "workforce__authz" ON workforce_simulations;
CREATE POLICY "workforce__authz" ON workforce_simulations FOR SELECT USING (
  auth.uid() IS NOT NULL AND (
    authz_in_scope(workforce_simulations.nrp) OR authz_has_permission('employee.view_all')
  )
);

-- PART 2: Authenticated-only policies (39 tables without nrp column)
DROP POLICY IF EXISTS "assets_auth" ON assets;
CREATE POLICY "assets_auth" ON assets FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "bu_divisio_auth" ON bu_divisions;
CREATE POLICY "bu_divisio_auth" ON bu_divisions FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "currency_m_auth" ON currency_master;
CREATE POLICY "currency_m_auth" ON currency_master FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "emergency__auth" ON emergency_procedures;
CREATE POLICY "emergency__auth" ON emergency_procedures FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "external_n_auth" ON external_notification_logs;
CREATE POLICY "external_n_auth" ON external_notification_logs FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "external_n_auth" ON external_notifications;
CREATE POLICY "external_n_auth" ON external_notifications FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "feature_fl_auth" ON feature_flags;
CREATE POLICY "feature_fl_auth" ON feature_flags FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "harvest_re_auth" ON harvest_records;
CREATE POLICY "harvest_re_auth" ON harvest_records FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "hr_ai_task_auth" ON hr_ai_tasks;
CREATE POLICY "hr_ai_task_auth" ON hr_ai_tasks FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "hr_benefit_auth" ON hr_benefit_catalog;
CREATE POLICY "hr_benefit_auth" ON hr_benefit_catalog FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "hr_calenda_auth" ON hr_calendar;
CREATE POLICY "hr_calenda_auth" ON hr_calendar FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "hr_coachin_auth" ON hr_coaching_catalog;
CREATE POLICY "hr_coachin_auth" ON hr_coaching_catalog FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "hr_compete_auth" ON hr_competency_matrix;
CREATE POLICY "hr_compete_auth" ON hr_competency_matrix FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "hr_complia_auth" ON hr_compliance;
CREATE POLICY "hr_complia_auth" ON hr_compliance FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "hr_complia_auth" ON hr_compliance_catalog;
CREATE POLICY "hr_complia_auth" ON hr_compliance_catalog FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "hr_documen_auth" ON hr_document_types;
CREATE POLICY "hr_documen_auth" ON hr_document_types FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "hr_equipme_auth" ON hr_equipment_util;
CREATE POLICY "hr_equipme_auth" ON hr_equipment_util FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "hr_finance_auth" ON hr_finance_kpi;
CREATE POLICY "hr_finance_auth" ON hr_finance_kpi FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "hr_monthly_auth" ON hr_monthly_snapshot;
CREATE POLICY "hr_monthly_auth" ON hr_monthly_snapshot FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "hr_penalty_auth" ON hr_penalty_matrix;
CREATE POLICY "hr_penalty_auth" ON hr_penalty_matrix FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "hr_positio_auth" ON hr_position_skills;
CREATE POLICY "hr_positio_auth" ON hr_position_skills FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "hr_preview_auth" ON hr_preview_data;
CREATE POLICY "hr_preview_auth" ON hr_preview_data FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "hr_shift_m_auth" ON hr_shift_master;
CREATE POLICY "hr_shift_m_auth" ON hr_shift_master FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "hr_success_auth" ON hr_succession;
CREATE POLICY "hr_success_auth" ON hr_succession FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "hr_talent__auth" ON hr_talent_catalog;
CREATE POLICY "hr_talent__auth" ON hr_talent_catalog FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "hr_work_sc_auth" ON hr_work_schedule;
CREATE POLICY "hr_work_sc_auth" ON hr_work_schedule FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "irrigation_auth" ON irrigation_blocks;
CREATE POLICY "irrigation_auth" ON irrigation_blocks FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "mill_break_auth" ON mill_breakdowns;
CREATE POLICY "mill_break_auth" ON mill_breakdowns FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "mill_maint_auth" ON mill_maintenance;
CREATE POLICY "mill_maint_auth" ON mill_maintenance FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "mill_packi_auth" ON mill_packing;
CREATE POLICY "mill_packi_auth" ON mill_packing FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "nursery_bl_auth" ON nursery_blocks;
CREATE POLICY "nursery_bl_auth" ON nursery_blocks FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "simulation_auth" ON simulation_logs;
CREATE POLICY "simulation_auth" ON simulation_logs FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "sso_provid_auth" ON sso_providers;
CREATE POLICY "sso_provid_auth" ON sso_providers FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "timezone_m_auth" ON timezone_master;
CREATE POLICY "timezone_m_auth" ON timezone_master FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "transport__auth" ON transport_dispatch;
CREATE POLICY "transport__auth" ON transport_dispatch FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "vacancies_auth" ON vacancies;
CREATE POLICY "vacancies_auth" ON vacancies FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "webhook_co_auth" ON webhook_configs;
CREATE POLICY "webhook_co_auth" ON webhook_configs FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "webhook_lo_auth" ON webhook_logs;
CREATE POLICY "webhook_lo_auth" ON webhook_logs FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "whistleblo_auth" ON whistleblowers;
CREATE POLICY "whistleblo_auth" ON whistleblowers FOR SELECT USING (auth.uid() IS NOT NULL);
