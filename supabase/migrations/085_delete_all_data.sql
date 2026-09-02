-- ============================================
-- DELETE ALL DATA — CLEAN SLATE
-- INSIGHTWOS V6 Database Reset
-- ============================================
-- WARNING: This will delete ALL data from ALL tables!
-- Run this BEFORE seeding new data.
-- ============================================

-- Disable triggers temporarily
SET session_replication_role = 'replica';

TRUNCATE TABLE admin_division_access CASCADE;
TRUNCATE TABLE ai_conversations CASCADE;
TRUNCATE TABLE ai_documents CASCADE;
TRUNCATE TABLE announcements CASCADE;
TRUNCATE TABLE approval_config CASCADE;
TRUNCATE TABLE approval_instances CASCADE;
TRUNCATE TABLE asset_assignments CASCADE;
TRUNCATE TABLE assets CASCADE;
TRUNCATE TABLE audit_chain CASCADE;
TRUNCATE TABLE audit_log CASCADE;
TRUNCATE TABLE audit_log_owner CASCADE;
TRUNCATE TABLE badges CASCADE;
TRUNCATE TABLE bu_divisions CASCADE;
TRUNCATE TABLE budget_allocation CASCADE;
TRUNCATE TABLE business_unit_modules CASCADE;
TRUNCATE TABLE business_units CASCADE;
TRUNCATE TABLE candidate_pipeline CASCADE;
TRUNCATE TABLE certifications CASCADE;
TRUNCATE TABLE corporate_licenses CASCADE;
TRUNCATE TABLE currency_master CASCADE;
TRUNCATE TABLE daftar_baru CASCADE;
TRUNCATE TABLE disciplinary_records CASCADE;
TRUNCATE TABLE emergency_procedures CASCADE;
TRUNCATE TABLE employee_mutations CASCADE;
TRUNCATE TABLE employees_master CASCADE;
TRUNCATE TABLE estate_blocks CASCADE;
TRUNCATE TABLE estate_field CASCADE;
TRUNCATE TABLE estate_harvest CASCADE;
TRUNCATE TABLE estate_irrigation CASCADE;
TRUNCATE TABLE estate_nursery CASCADE;
TRUNCATE TABLE estate_transport CASCADE;
TRUNCATE TABLE estate_yield CASCADE;
TRUNCATE TABLE exit_interviews CASCADE;
TRUNCATE TABLE external_notification_logs CASCADE;
TRUNCATE TABLE external_notifications CASCADE;
TRUNCATE TABLE facility_requests CASCADE;
TRUNCATE TABLE feature_flags CASCADE;
TRUNCATE TABLE final_settlements CASCADE;
TRUNCATE TABLE forum_posts CASCADE;
TRUNCATE TABLE forum_replies CASCADE;
TRUNCATE TABLE harvest_records CASCADE;
TRUNCATE TABLE headcount_plans CASCADE;
TRUNCATE TABLE hr_ai_tasks CASCADE;
TRUNCATE TABLE hr_attendance CASCADE;
TRUNCATE TABLE hr_audit_chain CASCADE;
TRUNCATE TABLE hr_benefit_catalog CASCADE;
TRUNCATE TABLE hr_benefits CASCADE;
TRUNCATE TABLE hr_calendar CASCADE;
TRUNCATE TABLE hr_capability CASCADE;
TRUNCATE TABLE hr_coaching CASCADE;
TRUNCATE TABLE hr_coaching_catalog CASCADE;
TRUNCATE TABLE hr_competency_matrix CASCADE;
TRUNCATE TABLE hr_compliance CASCADE;
TRUNCATE TABLE hr_compliance_catalog CASCADE;
TRUNCATE TABLE hr_critical CASCADE;
TRUNCATE TABLE hr_document_types CASCADE;
TRUNCATE TABLE hr_engagement CASCADE;
TRUNCATE TABLE hr_equipment_util CASCADE;
TRUNCATE TABLE hr_exit_clearance CASCADE;
TRUNCATE TABLE hr_finance_kpi CASCADE;
TRUNCATE TABLE hr_kpi_calc_log CASCADE;
TRUNCATE TABLE hr_kpi_config CASCADE;
TRUNCATE TABLE hr_learning CASCADE;
TRUNCATE TABLE hr_leave CASCADE;
TRUNCATE TABLE hr_medical_checkup CASCADE;
TRUNCATE TABLE hr_monthly_snapshot CASCADE;
TRUNCATE TABLE hr_notifications CASCADE;
TRUNCATE TABLE hr_okr_results CASCADE;
TRUNCATE TABLE hr_okrs CASCADE;
TRUNCATE TABLE hr_org CASCADE;
TRUNCATE TABLE hr_overtime CASCADE;
TRUNCATE TABLE hr_payroll CASCADE;
TRUNCATE TABLE hr_penalty_matrix CASCADE;
TRUNCATE TABLE hr_performance CASCADE;
TRUNCATE TABLE hr_plantation_harvest CASCADE;
TRUNCATE TABLE hr_position_skills CASCADE;
TRUNCATE TABLE hr_preview_data CASCADE;
TRUNCATE TABLE hr_production_daily CASCADE;
TRUNCATE TABLE hr_relations CASCADE;
TRUNCATE TABLE hr_requests CASCADE;
TRUNCATE TABLE hr_safety CASCADE;
TRUNCATE TABLE hr_shift_master CASCADE;
TRUNCATE TABLE hr_shift_swaps CASCADE;
TRUNCATE TABLE hr_skills CASCADE;
TRUNCATE TABLE hr_succession CASCADE;
TRUNCATE TABLE hr_succession_matrix CASCADE;
TRUNCATE TABLE hr_survey_responses CASCADE;
TRUNCATE TABLE hr_surveys CASCADE;
TRUNCATE TABLE hr_talent_catalog CASCADE;
TRUNCATE TABLE hr_task_board CASCADE;
TRUNCATE TABLE hr_tasks CASCADE;
TRUNCATE TABLE hr_training_catalog CASCADE;
TRUNCATE TABLE hr_voice CASCADE;
TRUNCATE TABLE hr_work_schedule CASCADE;
TRUNCATE TABLE idx_nrp CASCADE;
TRUNCATE TABLE incentives CASCADE;
TRUNCATE TABLE irrigation_blocks CASCADE;
TRUNCATE TABLE legal_documents CASCADE;
TRUNCATE TABLE login_attempts CASCADE;
TRUNCATE TABLE mfa_factors CASCADE;
TRUNCATE TABLE mill_boiler CASCADE;
TRUNCATE TABLE mill_breakdown CASCADE;
TRUNCATE TABLE mill_breakdowns CASCADE;
TRUNCATE TABLE mill_maintenance CASCADE;
TRUNCATE TABLE mill_packing CASCADE;
TRUNCATE TABLE mill_press CASCADE;
TRUNCATE TABLE mill_qc CASCADE;
TRUNCATE TABLE mill_qc_results CASCADE;
TRUNCATE TABLE mill_shift CASCADE;
TRUNCATE TABLE mining_equipment CASCADE;
TRUNCATE TABLE mining_fatigue CASCADE;
TRUNCATE TABLE mining_fuel CASCADE;
TRUNCATE TABLE mining_jsa CASCADE;
TRUNCATE TABLE mining_production CASCADE;
TRUNCATE TABLE mining_safety CASCADE;
TRUNCATE TABLE mining_simper CASCADE;
TRUNCATE TABLE module_definitions CASCADE;
TRUNCATE TABLE nursery_blocks CASCADE;
TRUNCATE TABLE offboarding_checklist CASCADE;
TRUNCATE TABLE okrs CASCADE;
TRUNCATE TABLE onboarding_tasks CASCADE;
TRUNCATE TABLE otp_attempts CASCADE;
TRUNCATE TABLE otp_store CASCADE;
TRUNCATE TABLE performance_notes CASCADE;
TRUNCATE TABLE push_subscriptions CASCADE;
TRUNCATE TABLE rate_limits CASCADE;
TRUNCATE TABLE referrals CASCADE;
TRUNCATE TABLE reimbursements CASCADE;
TRUNCATE TABLE review_360 CASCADE;
TRUNCATE TABLE reviews_360 CASCADE;
TRUNCATE TABLE salary_adjustments CASCADE;
TRUNCATE TABLE screening_results CASCADE;
TRUNCATE TABLE security_audit_log CASCADE;
TRUNCATE TABLE session_store CASCADE;
TRUNCATE TABLE session_tokens CASCADE;
TRUNCATE TABLE settings CASCADE;
TRUNCATE TABLE shift_assignments CASCADE;
TRUNCATE TABLE shift_swaps CASCADE;
TRUNCATE TABLE simulation_logs CASCADE;
TRUNCATE TABLE simulations CASCADE;
TRUNCATE TABLE sites CASCADE;
TRUNCATE TABLE sso_providers CASCADE;
TRUNCATE TABLE survey_responses CASCADE;
TRUNCATE TABLE surveys CASCADE;
TRUNCATE TABLE system_bootstrap CASCADE;
TRUNCATE TABLE team_budgets CASCADE;
TRUNCATE TABLE timesheets CASCADE;
TRUNCATE TABLE timezone_master CASCADE;
TRUNCATE TABLE transport_dispatch CASCADE;
TRUNCATE TABLE travel_requests CASCADE;
TRUNCATE TABLE user_roles CASCADE;
TRUNCATE TABLE vacancies CASCADE;
TRUNCATE TABLE webhook_configs CASCADE;
TRUNCATE TABLE webhook_logs CASCADE;
TRUNCATE TABLE whistleblowers CASCADE;
TRUNCATE TABLE worker_passwords CASCADE;
TRUNCATE TABLE workforce_simulations CASCADE;

-- Re-enable triggers
SET session_replication_role = 'origin';

-- Reset sequences
ALTER SEQUENCE IF EXISTS admin_division_access_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS ai_conversations_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS ai_documents_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS announcements_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS approval_config_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS approval_instances_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS asset_assignments_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS assets_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS audit_chain_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS audit_log_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS audit_log_owner_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS badges_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS bu_divisions_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS budget_allocation_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS business_unit_modules_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS business_units_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS candidate_pipeline_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS certifications_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS corporate_licenses_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS currency_master_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS daftar_baru_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS disciplinary_records_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS emergency_procedures_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS employee_mutations_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS employees_master_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS estate_blocks_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS estate_field_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS estate_harvest_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS estate_irrigation_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS estate_nursery_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS estate_transport_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS estate_yield_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS exit_interviews_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS external_notification_logs_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS external_notifications_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS facility_requests_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS feature_flags_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS final_settlements_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS forum_posts_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS forum_replies_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS harvest_records_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS headcount_plans_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_ai_tasks_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_attendance_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_audit_chain_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_benefit_catalog_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_benefits_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_calendar_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_capability_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_coaching_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_coaching_catalog_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_competency_matrix_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_compliance_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_compliance_catalog_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_critical_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_document_types_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_engagement_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_equipment_util_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_exit_clearance_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_finance_kpi_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_kpi_calc_log_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_kpi_config_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_learning_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_leave_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_medical_checkup_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_monthly_snapshot_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_notifications_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_okr_results_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_okrs_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_org_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_overtime_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_payroll_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_penalty_matrix_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_performance_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_plantation_harvest_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_position_skills_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_preview_data_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_production_daily_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_relations_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_requests_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_safety_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_shift_master_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_shift_swaps_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_skills_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_succession_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_succession_matrix_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_survey_responses_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_surveys_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_talent_catalog_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_task_board_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_tasks_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_training_catalog_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_voice_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hr_work_schedule_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS idx_nrp_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS incentives_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS irrigation_blocks_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS legal_documents_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS login_attempts_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS mfa_factors_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS mill_boiler_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS mill_breakdown_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS mill_breakdowns_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS mill_maintenance_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS mill_packing_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS mill_press_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS mill_qc_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS mill_qc_results_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS mill_shift_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS mining_equipment_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS mining_fatigue_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS mining_fuel_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS mining_jsa_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS mining_production_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS mining_safety_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS mining_simper_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS module_definitions_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS nursery_blocks_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS offboarding_checklist_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS okrs_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS onboarding_tasks_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS otp_attempts_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS otp_store_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS performance_notes_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS push_subscriptions_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS rate_limits_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS referrals_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS reimbursements_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS review_360_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS reviews_360_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS salary_adjustments_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS screening_results_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS security_audit_log_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS session_store_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS session_tokens_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS settings_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS shift_assignments_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS shift_swaps_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS simulation_logs_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS simulations_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS sites_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS sso_providers_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS survey_responses_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS surveys_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS system_bootstrap_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS team_budgets_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS timesheets_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS timezone_master_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS transport_dispatch_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS travel_requests_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS user_roles_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS vacancies_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS webhook_configs_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS webhook_logs_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS whistleblowers_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS worker_passwords_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS workforce_simulations_id_seq RESTART WITH 1;

-- Verify: all tables should have 0 rows
-- Run this to check:
-- SELECT schemaname, tablename, n_live_tup FROM pg_stat_user_table;

SELECT 'DELETE COMPLETE' AS status, COUNT(*) AS tables_cleared FROM (
  SELECT COUNT(*) FROM admin_division_access
  UNION ALL
  SELECT COUNT(*) FROM ai_conversations
  UNION ALL
  SELECT COUNT(*) FROM ai_documents
  UNION ALL
  SELECT COUNT(*) FROM announcements
  UNION ALL
  SELECT COUNT(*) FROM approval_config
  UNION ALL
  SELECT COUNT(*) FROM approval_instances
  UNION ALL
  SELECT COUNT(*) FROM asset_assignments
  UNION ALL
  SELECT COUNT(*) FROM assets
  UNION ALL
  SELECT COUNT(*) FROM audit_chain
  UNION ALL
  SELECT COUNT(*) FROM audit_log
  UNION ALL
  SELECT COUNT(*) FROM audit_log_owner
  UNION ALL
  SELECT COUNT(*) FROM badges
  UNION ALL
  SELECT COUNT(*) FROM bu_divisions
  UNION ALL
  SELECT COUNT(*) FROM budget_allocation
  UNION ALL
  SELECT COUNT(*) FROM business_unit_modules
  UNION ALL
  SELECT COUNT(*) FROM business_units
  UNION ALL
  SELECT COUNT(*) FROM candidate_pipeline
  UNION ALL
  SELECT COUNT(*) FROM certifications
  UNION ALL
  SELECT COUNT(*) FROM corporate_licenses
  UNION ALL
  SELECT COUNT(*) FROM currency_master
  UNION ALL
  SELECT COUNT(*) FROM daftar_baru
  UNION ALL
  SELECT COUNT(*) FROM disciplinary_records
  UNION ALL
  SELECT COUNT(*) FROM emergency_procedures
  UNION ALL
  SELECT COUNT(*) FROM employee_mutations
  UNION ALL
  SELECT COUNT(*) FROM employees_master
  UNION ALL
  SELECT COUNT(*) FROM estate_blocks
  UNION ALL
  SELECT COUNT(*) FROM estate_field
  UNION ALL
  SELECT COUNT(*) FROM estate_harvest
  UNION ALL
  SELECT COUNT(*) FROM estate_irrigation
  UNION ALL
  SELECT COUNT(*) FROM estate_nursery
  UNION ALL
  SELECT COUNT(*) FROM estate_transport
  UNION ALL
  SELECT COUNT(*) FROM estate_yield
  UNION ALL
  SELECT COUNT(*) FROM exit_interviews
  UNION ALL
  SELECT COUNT(*) FROM external_notification_logs
  UNION ALL
  SELECT COUNT(*) FROM external_notifications
  UNION ALL
  SELECT COUNT(*) FROM facility_requests
  UNION ALL
  SELECT COUNT(*) FROM feature_flags
  UNION ALL
  SELECT COUNT(*) FROM final_settlements
  UNION ALL
  SELECT COUNT(*) FROM forum_posts
  UNION ALL
  SELECT COUNT(*) FROM forum_replies
  UNION ALL
  SELECT COUNT(*) FROM harvest_records
  UNION ALL
  SELECT COUNT(*) FROM headcount_plans
  UNION ALL
  SELECT COUNT(*) FROM hr_ai_tasks
  UNION ALL
  SELECT COUNT(*) FROM hr_attendance
  UNION ALL
  SELECT COUNT(*) FROM hr_audit_chain
  UNION ALL
  SELECT COUNT(*) FROM hr_benefit_catalog
  UNION ALL
  SELECT COUNT(*) FROM hr_benefits
  UNION ALL
  SELECT COUNT(*) FROM hr_calendar
  UNION ALL
  SELECT COUNT(*) FROM hr_capability
  UNION ALL
  SELECT COUNT(*) FROM hr_coaching
  UNION ALL
  SELECT COUNT(*) FROM hr_coaching_catalog
  UNION ALL
  SELECT COUNT(*) FROM hr_competency_matrix
  UNION ALL
  SELECT COUNT(*) FROM hr_compliance
  UNION ALL
  SELECT COUNT(*) FROM hr_compliance_catalog
  UNION ALL
  SELECT COUNT(*) FROM hr_critical
  UNION ALL
  SELECT COUNT(*) FROM hr_document_types
  UNION ALL
  SELECT COUNT(*) FROM hr_engagement
  UNION ALL
  SELECT COUNT(*) FROM hr_equipment_util
  UNION ALL
  SELECT COUNT(*) FROM hr_exit_clearance
  UNION ALL
  SELECT COUNT(*) FROM hr_finance_kpi
  UNION ALL
  SELECT COUNT(*) FROM hr_kpi_calc_log
  UNION ALL
  SELECT COUNT(*) FROM hr_kpi_config
  UNION ALL
  SELECT COUNT(*) FROM hr_learning
  UNION ALL
  SELECT COUNT(*) FROM hr_leave
  UNION ALL
  SELECT COUNT(*) FROM hr_medical_checkup
  UNION ALL
  SELECT COUNT(*) FROM hr_monthly_snapshot
  UNION ALL
  SELECT COUNT(*) FROM hr_notifications
  UNION ALL
  SELECT COUNT(*) FROM hr_okr_results
  UNION ALL
  SELECT COUNT(*) FROM hr_okrs
  UNION ALL
  SELECT COUNT(*) FROM hr_org
  UNION ALL
  SELECT COUNT(*) FROM hr_overtime
  UNION ALL
  SELECT COUNT(*) FROM hr_payroll
  UNION ALL
  SELECT COUNT(*) FROM hr_penalty_matrix
  UNION ALL
  SELECT COUNT(*) FROM hr_performance
  UNION ALL
  SELECT COUNT(*) FROM hr_plantation_harvest
  UNION ALL
  SELECT COUNT(*) FROM hr_position_skills
  UNION ALL
  SELECT COUNT(*) FROM hr_preview_data
  UNION ALL
  SELECT COUNT(*) FROM hr_production_daily
  UNION ALL
  SELECT COUNT(*) FROM hr_relations
  UNION ALL
  SELECT COUNT(*) FROM hr_requests
  UNION ALL
  SELECT COUNT(*) FROM hr_safety
  UNION ALL
  SELECT COUNT(*) FROM hr_shift_master
  UNION ALL
  SELECT COUNT(*) FROM hr_shift_swaps
  UNION ALL
  SELECT COUNT(*) FROM hr_skills
  UNION ALL
  SELECT COUNT(*) FROM hr_succession
  UNION ALL
  SELECT COUNT(*) FROM hr_succession_matrix
  UNION ALL
  SELECT COUNT(*) FROM hr_survey_responses
  UNION ALL
  SELECT COUNT(*) FROM hr_surveys
  UNION ALL
  SELECT COUNT(*) FROM hr_talent_catalog
  UNION ALL
  SELECT COUNT(*) FROM hr_task_board
  UNION ALL
  SELECT COUNT(*) FROM hr_tasks
  UNION ALL
  SELECT COUNT(*) FROM hr_training_catalog
  UNION ALL
  SELECT COUNT(*) FROM hr_voice
  UNION ALL
  SELECT COUNT(*) FROM hr_work_schedule
  UNION ALL
  SELECT COUNT(*) FROM idx_nrp
  UNION ALL
  SELECT COUNT(*) FROM incentives
  UNION ALL
  SELECT COUNT(*) FROM irrigation_blocks
  UNION ALL
  SELECT COUNT(*) FROM legal_documents
  UNION ALL
  SELECT COUNT(*) FROM login_attempts
  UNION ALL
  SELECT COUNT(*) FROM mfa_factors
  UNION ALL
  SELECT COUNT(*) FROM mill_boiler
  UNION ALL
  SELECT COUNT(*) FROM mill_breakdown
  UNION ALL
  SELECT COUNT(*) FROM mill_breakdowns
  UNION ALL
  SELECT COUNT(*) FROM mill_maintenance
  UNION ALL
  SELECT COUNT(*) FROM mill_packing
  UNION ALL
  SELECT COUNT(*) FROM mill_press
  UNION ALL
  SELECT COUNT(*) FROM mill_qc
  UNION ALL
  SELECT COUNT(*) FROM mill_qc_results
  UNION ALL
  SELECT COUNT(*) FROM mill_shift
  UNION ALL
  SELECT COUNT(*) FROM mining_equipment
  UNION ALL
  SELECT COUNT(*) FROM mining_fatigue
  UNION ALL
  SELECT COUNT(*) FROM mining_fuel
  UNION ALL
  SELECT COUNT(*) FROM mining_jsa
  UNION ALL
  SELECT COUNT(*) FROM mining_production
  UNION ALL
  SELECT COUNT(*) FROM mining_safety
  UNION ALL
  SELECT COUNT(*) FROM mining_simper
  UNION ALL
  SELECT COUNT(*) FROM module_definitions
  UNION ALL
  SELECT COUNT(*) FROM nursery_blocks
  UNION ALL
  SELECT COUNT(*) FROM offboarding_checklist
  UNION ALL
  SELECT COUNT(*) FROM okrs
  UNION ALL
  SELECT COUNT(*) FROM onboarding_tasks
  UNION ALL
  SELECT COUNT(*) FROM otp_attempts
  UNION ALL
  SELECT COUNT(*) FROM otp_store
  UNION ALL
  SELECT COUNT(*) FROM performance_notes
  UNION ALL
  SELECT COUNT(*) FROM push_subscriptions
  UNION ALL
  SELECT COUNT(*) FROM rate_limits
  UNION ALL
  SELECT COUNT(*) FROM referrals
  UNION ALL
  SELECT COUNT(*) FROM reimbursements
  UNION ALL
  SELECT COUNT(*) FROM review_360
  UNION ALL
  SELECT COUNT(*) FROM reviews_360
  UNION ALL
  SELECT COUNT(*) FROM salary_adjustments
  UNION ALL
  SELECT COUNT(*) FROM screening_results
  UNION ALL
  SELECT COUNT(*) FROM security_audit_log
  UNION ALL
  SELECT COUNT(*) FROM session_store
  UNION ALL
  SELECT COUNT(*) FROM session_tokens
  UNION ALL
  SELECT COUNT(*) FROM settings
  UNION ALL
  SELECT COUNT(*) FROM shift_assignments
  UNION ALL
  SELECT COUNT(*) FROM shift_swaps
  UNION ALL
  SELECT COUNT(*) FROM simulation_logs
  UNION ALL
  SELECT COUNT(*) FROM simulations
  UNION ALL
  SELECT COUNT(*) FROM sites
  UNION ALL
  SELECT COUNT(*) FROM sso_providers
  UNION ALL
  SELECT COUNT(*) FROM survey_responses
  UNION ALL
  SELECT COUNT(*) FROM surveys
  UNION ALL
  SELECT COUNT(*) FROM system_bootstrap
  UNION ALL
  SELECT COUNT(*) FROM team_budgets
  UNION ALL
  SELECT COUNT(*) FROM timesheets
  UNION ALL
  SELECT COUNT(*) FROM timezone_master
  UNION ALL
  SELECT COUNT(*) FROM transport_dispatch
  UNION ALL
  SELECT COUNT(*) FROM travel_requests
  UNION ALL
  SELECT COUNT(*) FROM user_roles
  UNION ALL
  SELECT COUNT(*) FROM vacancies
  UNION ALL
  SELECT COUNT(*) FROM webhook_configs
  UNION ALL
  SELECT COUNT(*) FROM webhook_logs
  UNION ALL
  SELECT COUNT(*) FROM whistleblowers
  UNION ALL
  SELECT COUNT(*) FROM worker_passwords
  UNION ALL
  SELECT COUNT(*) FROM workforce_simulations
) t;
