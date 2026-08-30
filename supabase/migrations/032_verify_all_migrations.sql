-- ============================================================
-- 032: VERIFICATION — Cek semua migration sudah jalan
-- Jalankan di Supabase SQL Editor
-- ============================================================

-- ── 1. CEK EXTENSIONS ──
SELECT '1. Extensions' as section, extname, extversion FROM pg_extension WHERE extname IN ('vector', 'pgcrypto');

-- ── 2. CEK SEMUA TABLES (harus 57+) ──
SELECT '2. Tables' as section, count(*) as total_tables,
  string_agg(tablename, ', ' ORDER BY tablename) as table_list
FROM pg_tables WHERE schemaname = 'public';

-- ── 3. CEK SEMUA RPC FUNCTIONS ──
SELECT '3. RPC Functions' as section, count(*) as total_functions
FROM pg_proc WHERE pronamespace = 'public'::regnamespace;

-- ── 4. CEK SEED DATA ──
SELECT '4. employees_master' as table_name, count(*) as rows FROM employees_master;
SELECT '5. user_roles' as table_name, count(*) as rows FROM user_roles;
SELECT '6. hr_org' as table_name, count(*) as rows FROM hr_org;
SELECT '7. worker_passwords' as table_name, count(*) as rows FROM worker_passwords;
SELECT '8. settings' as table_name, count(*) as rows FROM settings;

-- ── 5. CEK WAVE 2 TABLES ──
SELECT '9. hr_performance' as table_name, count(*) as rows FROM hr_performance;
SELECT '10. hr_payroll' as table_name, count(*) as rows FROM hr_payroll;
SELECT '11. hr_leave' as table_name, count(*) as rows FROM hr_leave;
SELECT '12. hr_requests' as table_name, count(*) as rows FROM hr_requests;
SELECT '13. hr_overtime' as table_name, count(*) as rows FROM hr_overtime;
SELECT '14. hr_learning' as table_name, count(*) as rows FROM hr_learning;
SELECT '15. hr_skills' as table_name, count(*) as rows FROM hr_skills;
SELECT '16. hr_tasks' as table_name, count(*) as rows FROM hr_tasks;
SELECT '17. hr_engagement' as table_name, count(*) as rows FROM hr_engagement;
SELECT '18. hr_voice' as table_name, count(*) as rows FROM hr_voice;
SELECT '19. hr_safety' as table_name, count(*) as rows FROM hr_safety;
SELECT '20. hr_notifications' as table_name, count(*) as rows FROM hr_notifications;
SELECT '21. announcements' as table_name, count(*) as rows FROM announcements;
SELECT '22. hr_finance_kpi' as table_name, count(*) as rows FROM hr_finance_kpi;
SELECT '23. hr_kpi_config' as table_name, count(*) as rows FROM hr_kpi_config;
SELECT '24. hr_position_skills' as table_name, count(*) as rows FROM hr_position_skills;
SELECT '25. hr_ai_tasks' as table_name, count(*) as rows FROM hr_ai_tasks;
SELECT '26. hr_training_catalog' as table_name, count(*) as rows FROM hr_training_catalog;
SELECT '27. hr_succession' as table_name, count(*) as rows FROM hr_succession;
SELECT '28. hr_critical' as table_name, count(*) as rows FROM hr_critical;
SELECT '29. hr_exit_clearance' as table_name, count(*) as rows FROM hr_exit_clearance;
SELECT '30. hr_medical_checkup' as table_name, count(*) as rows FROM hr_medical_checkup;
SELECT '31. hr_capability' as table_name, count(*) as rows FROM hr_capability;
SELECT '32. hr_relations' as table_name, count(*) as rows FROM hr_relations;
SELECT '33. hr_monthly_snapshot' as table_name, count(*) as rows FROM hr_monthly_snapshot;
SELECT '34. hr_plantation_harvest' as table_name, count(*) as rows FROM hr_plantation_harvest;

-- ── 6. CEK AI COPILOT TABLES ──
SELECT '35. ai_documents' as table_name, count(*) as rows FROM ai_documents;
SELECT '36. ai_conversations' as table_name, count(*) as rows FROM ai_conversations;

-- ── 7. CEK KEY RPC FUNCTIONS ──
SELECT '37. RPC: get_worker_status' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'get_worker_status') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;
SELECT '38. RPC: get_worker_profile' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'get_worker_profile') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;
SELECT '39. RPC: get_worker_payroll' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'get_worker_payroll') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;
SELECT '40. RPC: get_worker_kpi' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'get_worker_kpi') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;
SELECT '41. RPC: get_worker_overtime' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'get_worker_overtime') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;
SELECT '42. RPC: get_worker_learning' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'get_worker_learning') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;
SELECT '43. RPC: get_worker_tasks' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'get_worker_tasks') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;
SELECT '44. RPC: get_worker_activities' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'get_worker_activities') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;
SELECT '45. RPC: get_worker_attendance' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'get_worker_attendance') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;
SELECT '46. RPC: get_worker_leave' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'get_worker_leave') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;
SELECT '47. RPC: get_worker_career' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'get_worker_career') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;
SELECT '48. RPC: get_worker_benefits' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'get_worker_benefits') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;
SELECT '49. RPC: create_worker_request' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'create_worker_request') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;
SELECT '50. RPC: get_worker_requests' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'get_worker_requests') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;

-- ── 8. CEK ADMIN RPC ──
SELECT '51. RPC: admin_get_summary' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'admin_get_summary') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;
SELECT '52. RPC: admin_get_employees' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'admin_get_employees') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;
SELECT '53. RPC: admin_get_pending' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'admin_get_pending') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;
SELECT '54. RPC: admin_get_org_structure' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'admin_get_org_structure') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;
SELECT '55. RPC: admin_get_divisions' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'admin_get_divisions') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;
SELECT '56. RPC: admin_change_password' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'admin_change_password') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;
SELECT '57. RPC: admin_reset_worker_password' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'admin_reset_worker_password') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;
SELECT '58. RPC: get_pkwt_expiry_alert' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'get_pkwt_expiry_alert') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;
SELECT '59. RPC: admin_deactivate_worker' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'admin_deactivate_worker') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;

-- ── 9. CEK MANAGER RPC ──
SELECT '60. RPC: get_team_data' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'get_team_data') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;
SELECT '61. RPC: get_team_requests' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'get_team_requests') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;
SELECT '62. RPC: approve_team_request' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'approve_team_request') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;
SELECT '63. RPC: get_executive_summary' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'get_executive_summary') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;
SELECT '64. RPC: get_early_warning' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'get_early_warning') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;
SELECT '65. RPC: get_team_narrative' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'get_team_narrative') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;
SELECT '66. RPC: get_dashboard_stats' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'get_dashboard_stats') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;

-- ── 10. CEK WAVE 1 FUNCTIONS ──
SELECT '67. RPC: update_worker_profile' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'update_worker_profile') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;
SELECT '68. RPC: get_continuous_perf_team' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'get_continuous_perf_team') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;

-- ── 11. CEK AI COPILOT RPC ──
SELECT '69. RPC: match_documents' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'match_documents') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;
SELECT '70. RPC: upsert_document' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'upsert_document') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;

-- ── 12. CEK ADMIN_PASSWORD di settings ──
SELECT '71. Settings: admin_password' as check_name, 
  CASE WHEN EXISTS(SELECT 1 FROM settings WHERE key = 'admin_password') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;

-- ── 13. SUMMARY ──
SELECT '=== SUMMARY ===' as section;
SELECT 
  (SELECT count(*) FROM pg_tables WHERE schemaname = 'public') as total_tables,
  (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace) as total_functions,
  (SELECT count(*) FROM employees_master) as employees,
  (SELECT count(*) FROM hr_performance) as performance_records,
  (SELECT count(*) FROM ai_documents) as ai_documents;
