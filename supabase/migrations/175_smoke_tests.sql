-- ================================================================
-- 175_smoke_tests.sql — End-to-end smoke tests
--
-- Jalankan SET ROLE ke masing-masing role untuk test:
--   SET ROLE anon;      → test pre-login
--   SET ROLE authenticated; → test post-login
--   RESET ROLE;         → back to service_role
--
-- ATAU: jalankan tanpa SET ROLE (sebagai service_role) untuk test
-- bahwa semua fungsi masih accessible via SECURITY DEFINER.
-- ================================================================

-- ════════════════════════════════════════════════════════════════
-- GROUP A: AUTH & SESSION
-- ════════════════════════════════════════════════════════════════

SELECT 'A1: get_branding callable' AS test,
  CASE WHEN get_branding() IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'A2: login_worker exists' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='login_worker') THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'A3: login_worker 3-arg exists' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='login_worker' AND pronargs=3) THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'A4: register_session exists' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='register_session') THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'A5: worker_change_password exists' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='worker_change_password') THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'A6: check_login_lockout exists' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='check_login_lockout') THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'A7: generate_worker_otp exists' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='generate_worker_otp') THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'A8: verify_worker_otp exists' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='verify_worker_otp') THEN 'PASS' ELSE 'FAIL' END AS result;


-- ════════════════════════════════════════════════════════════════
-- GROUP B: ADMIN FUNCTIONS
-- ════════════════════════════════════════════════════════════════

SELECT 'B1: admin_get_employees callable' AS test,
  CASE WHEN admin_get_employees() IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'B2: admin_approve_request callable' AS test,
  CASE WHEN admin_approve_request('TEST','test') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'B3: admin_get_role_matrix callable' AS test,
  CASE WHEN admin_get_role_matrix() IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'B4: admin_get_payroll_secure callable' AS test,
  CASE WHEN admin_get_payroll_secure() IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'B5: admin_change_password callable' AS test,
  CASE WHEN admin_change_password('wrong','new') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;


-- ════════════════════════════════════════════════════════════════
-- GROUP C: WORKER FUNCTIONS (restore dari 171)
-- ════════════════════════════════════════════════════════════════

SELECT 'C1: clock_in callable' AS test,
  CASE WHEN clock_in('TEST') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'C2: clock_out callable' AS test,
  CASE WHEN clock_out('TEST') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'C3: get_timesheets callable' AS test,
  CASE WHEN get_timesheets('TEST') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'C4: create_okr callable' AS test,
  CASE WHEN create_okr('TEST','2026-Q3','Test Objective') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'C5: get_my_okrs callable' AS test,
  CASE WHEN get_my_okrs('TEST') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'C6: create_worker_request callable' AS test,
  CASE WHEN create_worker_request('TEST','LEAVE','test','test') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'C7: submit_whistleblower callable' AS test,
  CASE WHEN submit_whistleblower('TEST','test') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'C8: get_whistleblowers callable' AS test,
  CASE WHEN get_whistleblowers() IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'C9: get_worker_narrative callable' AS test,
  CASE WHEN get_worker_narrative('TEST') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;


-- ════════════════════════════════════════════════════════════════
-- GROUP D: MINING FUNCTIONS (restore dari 168)
-- ════════════════════════════════════════════════════════════════

SELECT 'D1: get_fatigue_data callable' AS test,
  CASE WHEN get_fatigue_data('TEST') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'D2: get_heavy_equipment callable' AS test,
  CASE WHEN get_heavy_equipment('TEST') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'D3: get_jsa_list callable' AS test,
  CASE WHEN get_jsa_list('TEST') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'D4: get_production_daily callable' AS test,
  CASE WHEN get_production_daily('TEST') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'D5: get_safety_incidents callable' AS test,
  CASE WHEN get_safety_incidents('TEST') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'D6: get_simper_list callable' AS test,
  CASE WHEN get_simper_list('TEST') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;


-- ════════════════════════════════════════════════════════════════
-- GROUP E: CRON FUNCTIONS (restore dari 168)
-- ════════════════════════════════════════════════════════════════

SELECT 'E1: check_pkwt_expiry callable' AS test,
  CASE WHEN check_pkwt_expiry() IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'E2: process_payroll_batch callable' AS test,
  CASE WHEN process_payroll_batch('TEST') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'E3: calculate_monthly_kpi callable' AS test,
  CASE WHEN calculate_monthly_kpi('TEST') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'E4: generate_attendance_summary callable' AS test,
  CASE WHEN generate_attendance_summary('TEST') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'E5: calculate_workforce_health callable' AS test,
  CASE WHEN calculate_workforce_health() IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'E6: run_auto_healing callable' AS test,
  CASE WHEN run_auto_healing() IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'E7: run_early_detection callable' AS test,
  CASE WHEN run_early_detection() IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'E8: cleanup_expired_otps callable' AS test,
  CASE WHEN cleanup_expired_otps() IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;


-- ════════════════════════════════════════════════════════════════
-- GROUP F: PII ACCESS (via SECURITY DEFINER)
-- ════════════════════════════════════════════════════════════════

SELECT 'F1: employees_master accessible' AS test,
  CASE WHEN (SELECT count(*) FROM employees_master) >= 0 THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'F2: worker_passwords accessible' AS test,
  CASE WHEN (SELECT count(*) FROM worker_passwords) >= 0 THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'F3: hr_payroll accessible' AS test,
  CASE WHEN (SELECT count(*) FROM hr_payroll) >= 0 THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'F4: decrypt_pii NOT callable by anon' AS test,
  CASE WHEN has_function_privilege('anon', 'decrypt_pii(bytea)', 'EXECUTE') THEN 'FAIL - STILL ACCESSIBLE' ELSE 'PASS' END AS result;

SELECT 'F5: export_employees NOT callable by anon' AS test,
  CASE WHEN has_function_privilege('anon', 'export_employees()', 'EXECUTE') THEN 'FAIL - STILL ACCESSIBLE' ELSE 'PASS' END AS result;


-- ════════════════════════════════════════════════════════════════
-- GROUP G: RLS STATUS
-- ════════════════════════════════════════════════════════════════

SELECT 'G1: PII tables have RLS' AS test,
  CASE WHEN (
    SELECT count(*) FROM pg_tables
    WHERE schemaname='public'
      AND tablename IN ('employees_master','worker_passwords','hr_payroll')
      AND rowsecurity = true
  ) = 3 THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'G2: No public tables without RLS' AS test,
  (SELECT count(*)::text FROM pg_tables WHERE schemaname='public' AND NOT rowsecurity) AS tables_without_rls;


-- ════════════════════════════════════════════════════════════════
-- GROUP H: SEARCH_PATH HARDENING
-- ════════════════════════════════════════════════════════════════

SELECT 'H1: SECDEF functions with search_path' AS test,
  (SELECT count(*)::text FROM pg_proc p
   JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.prosecdef = true AND p.prokind = 'f'
     AND p.proconfig IS NOT NULL
     AND EXISTS (SELECT 1 FROM unnest(p.proconfig) c WHERE c LIKE 'search_path=%')
  ) AS with_search_path;

SELECT 'H2: SECDEF functions WITHOUT search_path' AS test,
  (SELECT count(*)::text FROM pg_proc p
   JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.prosecdef = true AND p.prokind = 'f'
     AND (p.proconfig IS NULL OR NOT EXISTS (SELECT 1 FROM unnest(p.proconfig) c WHERE c LIKE 'search_path=%'))
  ) AS without_search_path;
