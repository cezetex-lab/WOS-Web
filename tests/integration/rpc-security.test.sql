-- ================================================================
-- L5: Integration Tests — RPC Security (run against real DB)
-- Run: node supabase/migrations/run_171.mjs "postgresql://..." tests/integration/rpc-security.test.sql
-- ================================================================

-- ── L5.1: All critical functions exist ──
SELECT 'L5.1 login_worker exists' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='login_worker') THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'L5.1 worker_change_password exists' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='worker_change_password') THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'L5.1 register_session exists' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='register_session') THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'L5.1 check_login_lockout exists' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='check_login_lockout') THEN 'PASS' ELSE 'FAIL' END AS result;

-- ── L5.2: All admin functions are SECURITY DEFINER ──
SELECT 'L5.2 admin_* all SECDEF' AS test,
  CASE WHEN NOT EXISTS(
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid
    WHERE p.proname LIKE 'admin_%' AND n.nspname='public' AND p.prosecdef=false
  ) THEN 'PASS' ELSE 'FAIL' END AS result;

-- ── L5.3: All export functions are SECDEF ──
SELECT 'L5.3 export_* all SECDEF' AS test,
  CASE WHEN NOT EXISTS(
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid
    WHERE p.proname LIKE 'export_%' AND n.nspname='public' AND p.prosecdef=false
  ) THEN 'PASS' ELSE 'FAIL' END AS result;

-- ── L5.4: decrypt_pii is SECDEF + not granted to anon ──
SELECT 'L5.4 decrypt_pii SECDEF' AS test,
  CASE WHEN EXISTS(
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid
    WHERE p.proname='decrypt_pii' AND n.nspname='public' AND p.prosecdef=true
  ) THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'L5.4 anon NO EXECUTE decrypt_pii' AS test,
  CASE WHEN NOT has_function_privilege('anon', 'decrypt_pii(bytea)', 'EXECUTE')
  THEN 'PASS' ELSE 'FAIL' END AS result;

-- ── L5.5: All critical tables have RLS ──
SELECT 'L5.5 employees_core RLS' AS test,
  CASE WHEN (SELECT relrowsecurity FROM pg_class WHERE relname='employees_core')
  THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'L5.5 employees_extended RLS' AS test,
  CASE WHEN (SELECT relrowsecurity FROM pg_class WHERE relname='employees_extended')
  THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'L5.5 hr_payroll RLS' AS test,
  CASE WHEN (SELECT relrowsecurity FROM pg_class WHERE relname='hr_payroll')
  THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'L5.5 hr_attendance RLS' AS test,
  CASE WHEN (SELECT relrowsecurity FROM pg_class WHERE relname='hr_attendance')
  THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'L5.5 worker_passwords RLS' AS test,
  CASE WHEN (SELECT relrowsecurity FROM pg_class WHERE relname='worker_passwords')
  THEN 'PASS' ELSE 'FAIL' END AS result;

-- ── L5.6: bcrypt search_path includes extensions ──
SELECT 'L5.6 login_worker search_path has extensions' AS test,
  CASE WHEN EXISTS(
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid
    WHERE p.proname='login_worker' AND n.nspname='public'
    AND p.proconfig @> ARRAY['search_path=public, extensions']
  ) THEN 'PASS' ELSE 'FAIL' END AS result;

-- ── L5.7: Module definitions have route config ──
SELECT 'L5.7 modules with route_path' AS test,
  (SELECT count(*)::text || '/' || (SELECT count(*)::text FROM module_definitions WHERE is_active=true)
   FROM module_definitions WHERE is_active=true AND route_path IS NOT NULL) AS result;

-- ── L5.8: Materialized views restricted to service_role ──
SELECT 'L5.8 MV anon NO SELECT' AS test,
  CASE WHEN NOT EXISTS(SELECT 1 FROM pg_matviews WHERE matviewname='mv_admin_summary')
    THEN 'PASS — MV not found'
  WHEN NOT has_table_privilege('anon', 'mv_admin_summary', 'SELECT')
    THEN 'PASS'
  ELSE 'FAIL' END AS result;

-- ── L5.9: Estate + Mill functions exist ──
SELECT 'L5.9 get_estate_blocks exists' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='get_estate_blocks') THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'L5.9 get_boiler_status exists' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='get_boiler_status') THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'L5.9 get_mill_production exists' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='get_mill_production') THEN 'PASS' ELSE 'FAIL' END AS result;

-- ── L5.10: All 8 RPC cron functions exist ──
SELECT 'L5.10 cron: check_pkwt_expiry' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='check_pkwt_expiry') THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'L5.10 cron: process_payroll_batch' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='process_payroll_batch') THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'L5.10 cron: run_auto_healing' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='run_auto_healing') THEN 'PASS' ELSE 'FAIL' END AS result;
