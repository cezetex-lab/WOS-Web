-- ============================================================
-- 029_verify_all.sql
-- VERIFICATION QUERIES — Run after 027 + 028
-- Checks all 57 tables and 65+ RPC functions
-- ============================================================

-- ============================================================
-- 1. TABLE DATA COUNTS
-- ============================================================
SELECT '--- TABLE COUNTS ---' as section;

SELECT 'employees_master' as tbl, count(*) as rows FROM employees_master
UNION ALL SELECT 'user_roles', count(*) FROM user_roles
UNION ALL SELECT 'hr_org', count(*) FROM hr_org
UNION ALL SELECT 'worker_passwords', count(*) FROM worker_passwords
UNION ALL SELECT 'hr_performance', count(*) FROM hr_performance
UNION ALL SELECT 'hr_attendance', count(*) FROM hr_attendance
UNION ALL SELECT 'hr_leave', count(*) FROM hr_leave
UNION ALL SELECT 'hr_payroll', count(*) FROM hr_payroll
UNION ALL SELECT 'hr_benefits', count(*) FROM hr_benefits
UNION ALL SELECT 'hr_requests', count(*) FROM hr_requests
UNION ALL SELECT 'hr_learning', count(*) FROM hr_learning
UNION ALL SELECT 'hr_voice', count(*) FROM hr_voice
UNION ALL SELECT 'hr_engagement', count(*) FROM hr_engagement
UNION ALL SELECT 'hr_notifications', count(*) FROM hr_notifications
UNION ALL SELECT 'hr_safety', count(*) FROM hr_safety
UNION ALL SELECT 'hr_compliance', count(*) FROM hr_compliance
UNION ALL SELECT 'hr_coaching', count(*) FROM hr_coaching
UNION ALL SELECT 'hr_production_daily', count(*) FROM hr_production_daily
UNION ALL SELECT 'hr_competency_matrix', count(*) FROM hr_competency_matrix
UNION ALL SELECT 'hr_talent_catalog', count(*) FROM hr_talent_catalog
UNION ALL SELECT 'hr_succession_matrix', count(*) FROM hr_succession_matrix
UNION ALL SELECT 'hr_penalty_matrix', count(*) FROM hr_penalty_matrix
UNION ALL SELECT 'hr_shift_master', count(*) FROM hr_shift_master
UNION ALL SELECT 'hr_work_schedule', count(*) FROM hr_work_schedule
UNION ALL SELECT 'hr_calendar', count(*) FROM hr_calendar
UNION ALL SELECT 'hr_document_types', count(*) FROM hr_document_types
UNION ALL SELECT 'hr_finance_kpi', count(*) FROM hr_finance_kpi
UNION ALL SELECT 'hr_kpi_config', count(*) FROM hr_kpi_config
UNION ALL SELECT 'hr_skills', count(*) FROM hr_skills
UNION ALL SELECT 'hr_position_skills', count(*) FROM hr_position_skills
UNION ALL SELECT 'hr_tasks', count(*) FROM hr_tasks
UNION ALL SELECT 'hr_ai_tasks', count(*) FROM hr_ai_tasks
UNION ALL SELECT 'announcements', count(*) FROM announcements
UNION ALL SELECT 'hr_training_catalog', count(*) FROM hr_training_catalog
UNION ALL SELECT 'hr_succession', count(*) FROM hr_succession
UNION ALL SELECT 'hr_critical', count(*) FROM hr_critical
UNION ALL SELECT 'hr_overtime', count(*) FROM hr_overtime
UNION ALL SELECT 'hr_exit_clearance', count(*) FROM hr_exit_clearance
UNION ALL SELECT 'hr_medical_checkup', count(*) FROM hr_medical_checkup
UNION ALL SELECT 'hr_capability', count(*) FROM hr_capability
UNION ALL SELECT 'hr_relations', count(*) FROM hr_relations
UNION ALL SELECT 'hr_monthly_snapshot', count(*) FROM hr_monthly_snapshot
UNION ALL SELECT 'hr_plantation_harvest', count(*) FROM hr_plantation_harvest
UNION ALL SELECT 'settings', count(*) FROM settings
UNION ALL SELECT 'daftar_baru', count(*) FROM daftar_baru
ORDER BY tbl;

-- ============================================================
-- 2. RPC FUNCTION TESTS
-- ============================================================
SELECT '--- RPC TESTS ---' as section;

-- Auth
SELECT 'get_my_role' as fn, (get_my_role('NRP001'))->>'ok' as ok;
SELECT 'get_my_plan' as fn, (get_my_plan('NRP001'))->>'ok' as ok;

-- Worker Data
SELECT 'get_worker_payroll' as fn, (get_worker_payroll('NRP001'))->>'ok' as ok;
SELECT 'get_worker_engagement' as fn, (get_worker_engagement('NRP001'))->>'ok' as ok;
SELECT 'get_worker_notifications' as fn, (get_worker_notifications('NRP001'))->>'ok' as ok;
SELECT 'get_worker_learning' as fn, (get_worker_learning('NRP001'))->>'ok' as ok;
SELECT 'get_worker_attendance' as fn, (get_worker_attendance('NRP001'))->>'ok' as ok;
SELECT 'get_worker_leave' as fn, (get_worker_leave('NRP001'))->>'ok' as ok;
SELECT 'get_worker_overtime' as fn, (get_worker_overtime('NRP001'))->>'ok' as ok;
SELECT 'get_worker_kpi' as fn, (get_worker_kpi('NRP001'))->>'ok' as ok;
SELECT 'get_worker_career' as fn, (get_worker_career('NRP001'))->>'ok' as ok;
SELECT 'get_worker_tasks' as fn, (get_worker_tasks('NRP001'))->>'ok' as ok;
SELECT 'get_worker_profile' as fn, (get_worker_profile('NRP001'))->>'ok' as ok;
SELECT 'get_worker_activities' as fn, (get_worker_activities('NRP001'))->>'ok' as ok;

-- Talent & Performance
SELECT 'get_career_path' as fn, (get_career_path('NRP001'))->>'ok' as ok;
SELECT 'get_skills_intelligence' as fn, (get_skills_intelligence('NRP001'))->>'ok' as ok;
SELECT 'get_talent_marketplace' as fn, (get_talent_marketplace())->>'ok' as ok;
SELECT 'get_succession' as fn, (get_succession('NRP001'))->>'ok' as ok;
SELECT 'get_capability_gap' as fn, (get_capability_gap('NRP001'))->>'ok' as ok;
SELECT 'get_learning_recommendations' as fn, (get_learning_recommendations('NRP001'))->>'ok' as ok;
SELECT 'get_my_continuous_performance' as fn, (get_my_continuous_performance('NRP001'))->>'ok' as ok;
SELECT 'get_my_compensation_intelligence' as fn, (get_my_compensation_intelligence('NRP001'))->>'ok' as ok;

-- Engagement
SELECT 'list_ideas' as fn, (list_ideas('NRP001'))->>'ok' as ok;
SELECT 'get_benefit_data' as fn, (get_benefit_data('NRP001'))->>'ok' as ok;

-- Team & Manager
SELECT 'get_team_data' as fn, (get_team_data('NRP002'))->>'ok' as ok;
SELECT 'get_team_requests' as fn, (get_team_requests('NRP002'))->>'ok' as ok;
SELECT 'get_manager_command_data' as fn, (get_manager_command_data('NRP002'))->>'ok' as ok;
SELECT 'get_subtree_data' as fn, (get_subtree_data('NRP002'))->>'ok' as ok;
SELECT 'get_continuous_perf_team' as fn, (get_continuous_perf_team('NRP002'))->>'ok' as ok;
SELECT 'get_people_search' as fn, (get_people_search('Budi'))->>'ok' as ok;

-- CEO & Executive
SELECT 'get_ceo_command_data' as fn, (get_ceo_command_data('NRP001'))->>'ok' as ok;
SELECT 'get_organization_health' as fn, (get_organization_health())->>'ok' as ok;
SELECT 'get_early_warning' as fn, (get_early_warning())->>'ok' as ok;
SELECT 'get_executive_summary' as fn, (get_executive_summary())->>'ok' as ok;
SELECT 'get_workforce_planning' as fn, (get_workforce_planning())->>'ok' as ok;
SELECT 'get_workforce_health_score' as fn, (get_workforce_health_score())->>'ok' as ok;
SELECT 'get_flight_risk_list' as fn, (get_flight_risk_list())->>'ok' as ok;
SELECT 'get_anomaly_sentinel' as fn, (get_anomaly_sentinel())->>'ok' as ok;
SELECT 'get_auto_healing_actions' as fn, (get_auto_healing_actions())->>'ok' as ok;

-- Dashboard Stats
SELECT 'get_dashboard_stats' as fn, (get_dashboard_stats())->>'ok' as ok;
SELECT 'get_kpi_by_division' as fn, (get_kpi_by_division())->>'ok' as ok;
SELECT 'get_safety_summary' as fn, (get_safety_summary())->>'ok' as ok;
SELECT 'get_turnover_data' as fn, (get_turnover_data())->>'ok' as ok;
SELECT 'get_monthly_snapshot_trend' as fn, (get_monthly_snapshot_trend(NULL))->>'ok' as ok;

-- Admin
SELECT 'admin_get_summary' as fn, (admin_get_summary())->>'ok' as ok;
SELECT 'admin_get_pending_requests' as fn, (admin_get_pending_requests())->>'ok' as ok;
SELECT 'admin_get_org_structure' as fn, (admin_get_org_structure())->>'ok' as ok;
SELECT 'admin_get_divisions' as fn, (admin_get_divisions())->>'ok' as ok;

-- Production & Ops
SELECT 'get_shift_schedule' as fn, (get_shift_schedule())->>'ok' as ok;
SELECT 'get_work_schedule' as fn, (get_work_schedule(NULL))->>'ok' as ok;
SELECT 'get_overtime_data' as fn, (get_overtime_data(NULL,'2026-07-01','2026-07-31'))->>'ok' as ok;

-- Capability & Compliance
SELECT 'get_competency_matrix' as fn, (get_competency_matrix())->>'ok' as ok;
SELECT 'get_succession_matrix' as fn, (get_succession_matrix())->>'ok' as ok;
SELECT 'get_penalty_matrix' as fn, (get_penalty_matrix())->>'ok' as ok;
SELECT 'get_exit_clearance' as fn, (get_exit_clearance(NULL))->>'ok' as ok;

-- Training & Catalog
SELECT 'get_training_catalog' as fn, (get_training_catalog())->>'ok' as ok;
SELECT 'get_coaching_catalog' as fn, (get_coaching_catalog())->>'ok' as ok;
SELECT 'get_compliance_catalog' as fn, (get_compliance_catalog())->>'ok' as ok;
SELECT 'get_benefit_catalog' as fn, (get_benefit_catalog())->>'ok' as ok;
SELECT 'get_document_types' as fn, (get_document_types())->>'ok' as ok;

-- Admin New RPCs
SELECT 'admin_get_timesheet' as fn, (admin_get_timesheet())->>'ok' as ok;
SELECT 'admin_get_certifications' as fn, (admin_get_certifications())->>'ok' as ok;
SELECT 'admin_get_badges' as fn, (admin_get_badges())->>'ok' as ok;
SELECT 'admin_get_okr' as fn, (admin_get_okr())->>'ok' as ok;
SELECT 'admin_get_assets' as fn, (admin_get_assets())->>'ok' as ok;
SELECT 'admin_get_budget' as fn, (admin_get_budget())->>'ok' as ok;
SELECT 'admin_get_referrals' as fn, (admin_get_referrals())->>'ok' as ok;
SELECT 'admin_get_feature_flags' as fn, (admin_get_feature_flags())->>'ok' as ok;
SELECT 'admin_get_audit_chain' as fn, (admin_get_audit_chain())->>'ok' as ok;
SELECT 'admin_get_surveys' as fn, (admin_get_surveys())->>'ok' as ok;
SELECT 'admin_get_whistleblower' as fn, (admin_get_whistleblower())->>'ok' as ok;

-- ============================================================
-- 3. SUMMARY
-- ============================================================
SELECT '--- SUMMARY ---' as section;
SELECT 
  (SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE') as total_tables,
  (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace) as total_functions;
