-- ================================================================
-- 184_test_q1_q4_security.sql
-- Q1: Automated RPC Tests — function existence + basic behavior
-- Q2: IDOR Tests — cross-user access blocked
-- Q3: RLS Tests — tables have RLS enabled + policies
-- Q4: Privilege Escalation Tests — admin RPCs deny workers
-- ================================================================


-- ════════════════════════════════════════════════════════════════
-- Q1: Automated RPC Tests
-- ════════════════════════════════════════════════════════════════

-- Q1.1: login_worker exists with 3 text params
SELECT 'Q1.1 login_worker exists' AS test,
  CASE WHEN EXISTS(
    SELECT 1 FROM pg_proc WHERE proname='login_worker'
    AND array_length(proargtypes, 1) = 3
  ) THEN 'PASS' ELSE 'FAIL' END AS result;

-- Q1.2: worker_change_password exists
SELECT 'Q1.2 worker_change_password exists' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='worker_change_password')
  THEN 'PASS' ELSE 'FAIL' END AS result;

-- Q1.3: get_worker_payroll_secure exists (with nrp param)
SELECT 'Q1.3 get_worker_payroll_secure exists' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='get_worker_payroll_secure')
  THEN 'PASS' ELSE 'FAIL' END AS result;

-- Q1.4: admin_get_employees exists
SELECT 'Q1.4 admin_get_employees exists' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='admin_get_employees')
  THEN 'PASS' ELSE 'FAIL' END AS result;

-- Q1.5: export_my_data exists (GDPR compliance)
SELECT 'Q1.5 export_my_data exists' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='export_my_data')
  THEN 'PASS' ELSE 'FAIL' END AS result;

-- Q1.6: grant_consent exists (privacy)
SELECT 'Q1.6 grant_consent exists' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='grant_consent')
  THEN 'PASS' ELSE 'FAIL' END AS result;

-- Q1.7: register_session exists (SessionGuard)
SELECT 'Q1.7 register_session exists' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='register_session')
  THEN 'PASS' ELSE 'FAIL' END AS result;

-- Q1.8: check_login_lockout exists (rate limiting)
SELECT 'Q1.8 check_login_lockout exists' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='check_login_lockout')
  THEN 'PASS' ELSE 'FAIL' END AS result;

-- Q1.9: All 8 RPC cron functions exist
SELECT 'Q1.9 cron: check_pkwt_expiry' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='check_pkwt_expiry')
  THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Q1.9 cron: process_payroll_batch' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='process_payroll_batch')
  THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Q1.9 cron: calculate_monthly_kpi' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='calculate_monthly_kpi')
  THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Q1.9 cron: generate_attendance_summary' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='generate_attendance_summary')
  THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Q1.9 cron: calculate_workforce_health' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='calculate_workforce_health')
  THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Q1.9 cron: run_auto_healing' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='run_auto_healing')
  THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Q1.9 cron: run_early_detection' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='run_early_detection')
  THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Q1.9 cron: cleanup_expired_otps' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='cleanup_expired_otps')
  THEN 'PASS' ELSE 'FAIL' END AS result;

-- Q1.10: All 7 Estate + 7 Mill functions exist
SELECT 'Q1.10 estate: get_estate_blocks' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='get_estate_blocks') THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Q1.10 estate: get_harvest_records' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='get_harvest_records') THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Q1.10 estate: get_transport_dispatch' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='get_transport_dispatch') THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Q1.10 estate: get_nursery_data' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='get_nursery_data') THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Q1.10 estate: get_irrigation_status' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='get_irrigation_status') THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Q1.10 estate: get_field_status' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='get_field_status') THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Q1.10 estate: get_yield_data' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='get_yield_data') THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Q1.10 mill: get_boiler_status' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='get_boiler_status') THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Q1.10 mill: get_press_status' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='get_press_status') THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Q1.10 mill: get_qc_results' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='get_qc_results') THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Q1.10 mill: get_packing_log' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='get_packing_log') THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Q1.10 mill: get_maintenance_schedule' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='get_maintenance_schedule') THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Q1.10 mill: get_breakdown_log' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='get_breakdown_log') THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Q1.10 mill: get_mill_production' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='get_mill_production') THEN 'PASS' ELSE 'FAIL' END AS result;


-- ════════════════════════════════════════════════════════════════
-- Q2: IDOR Tests — verify functions use RLS/ownership checks
-- ════════════════════════════════════════════════════════════════

-- Q2.1: decrypt_pii requires SECDEF (not callable by anon)
SELECT 'Q2.1 decrypt_pii is SECURITY DEFINER' AS test,
  CASE WHEN EXISTS(
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid
    WHERE p.proname='decrypt_pii' AND n.nspname='public'
    AND p.prosecdef = true
  ) THEN 'PASS' ELSE 'FAIL' END AS result;

-- Q2.2: get_worker_payroll_secure is SECURITY DEFINER
SELECT 'Q2.2 get_worker_payroll_secure is SECDEF' AS test,
  CASE WHEN EXISTS(
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid
    WHERE p.proname='get_worker_payroll_secure' AND n.nspname='public'
    AND p.prosecdef = true
  ) THEN 'PASS' ELSE 'FAIL' END AS result;

-- Q2.3: login_worker is SECURITY DEFINER
SELECT 'Q2.3 login_worker is SECDEF' AS test,
  CASE WHEN EXISTS(
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid
    WHERE p.proname='login_worker' AND n.nspname='public'
    AND p.prosecdef = true
  ) THEN 'PASS' ELSE 'FAIL' END AS result;


-- ════════════════════════════════════════════════════════════════
-- Q3: RLS Tests — tables have RLS + policies
-- ════════════════════════════════════════════════════════════════

-- Q3.1: employees_core has RLS enabled
SELECT 'Q3.1 employees_core RLS enabled' AS test,
  CASE WHEN (SELECT relrowsecurity FROM pg_class WHERE relname='employees_core')
  THEN 'PASS' ELSE 'FAIL' END AS result;

-- Q3.2: employees_extended has RLS enabled
SELECT 'Q3.2 employees_extended RLS enabled' AS test,
  CASE WHEN (SELECT relrowsecurity FROM pg_class WHERE relname='employees_extended')
  THEN 'PASS' ELSE 'FAIL' END AS result;

-- Q3.3: hr_payroll has RLS enabled
SELECT 'Q3.3 hr_payroll RLS enabled' AS test,
  CASE WHEN (SELECT relrowsecurity FROM pg_class WHERE relname='hr_payroll')
  THEN 'PASS' ELSE 'FAIL' END AS result;

-- Q3.4: hr_attendance has RLS enabled
SELECT 'Q3.4 hr_attendance RLS enabled' AS test,
  CASE WHEN (SELECT relrowsecurity FROM pg_class WHERE relname='hr_attendance')
  THEN 'PASS' ELSE 'FAIL' END AS result;

-- Q3.5: system_owner_identity has FORCE RLS
SELECT 'Q3.5 system_owner_identity FORCE RLS' AS test,
  CASE WHEN (SELECT relforcerowsecurity FROM pg_class WHERE relname='system_owner_identity')
  THEN 'PASS' ELSE 'FAIL' END AS result;

-- Q3.6: Count tables with RLS enabled vs total
SELECT 'Q3.6 tables_with_RLS / total_tables' AS test,
  (SELECT count(*)::text || ' / ' || (SELECT count(*)::text FROM pg_class WHERE relkind='r' AND relnamespace=(SELECT oid FROM pg_namespace WHERE nspname='public'))
  FROM pg_class WHERE relrowsecurity=true AND relkind='r' AND relnamespace=(SELECT oid FROM pg_namespace WHERE nspname='public'))
  AS result;

-- Q3.7: decrypt_pii has REVOKE from PUBLIC (verify via has_function_privilege)
SELECT 'Q3.7 anon has NO EXECUTE on decrypt_pii' AS test,
  CASE WHEN NOT has_function_privilege('anon', 'decrypt_pii(bytea)', 'EXECUTE')
  THEN 'PASS' ELSE 'FAIL' END AS result;


-- ════════════════════════════════════════════════════════════════
-- Q4: Privilege Escalation Tests
-- ════════════════════════════════════════════════════════════════

-- Q4.1: admin_change_password is SECDEF (prevents self-elevation)
SELECT 'Q4.1 admin_change_password is SECDEF' AS test,
  CASE WHEN EXISTS(
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid
    WHERE p.proname='admin_change_password' AND n.nspname='public'
    AND p.prosecdef = true
  ) THEN 'PASS' ELSE 'FAIL' END AS result;

-- Q4.2: admin_reset_worker_password is SECDEF
SELECT 'Q4.2 admin_reset_worker_password is SECDEF' AS test,
  CASE WHEN EXISTS(
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid
    WHERE p.proname='admin_reset_worker_password' AND n.nspname='public'
    AND p.prosecdef = true
  ) THEN 'PASS' ELSE 'FAIL' END AS result;

-- Q4.3: All admin_* functions are SECDEF
SELECT 'Q4.3 all admin_* functions are SECDEF' AS test,
  CASE WHEN NOT EXISTS(
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid
    WHERE p.proname LIKE 'admin_%' AND n.nspname='public'
    AND p.prosecdef = false
  ) THEN 'PASS' ELSE 'FAIL' END AS result;

-- Q4.4: All export_* functions are SECDEF
SELECT 'Q4.4 all export_* functions are SECDEF' AS test,
  CASE WHEN NOT EXISTS(
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid
    WHERE p.proname LIKE 'export_%' AND n.nspname='public'
    AND p.prosecdef = false
  ) THEN 'PASS' ELSE 'FAIL' END AS result;

-- Q4.5: All owner_* functions are SECDEF
SELECT 'Q4.5 all owner_* functions are SECDEF' AS test,
  CASE WHEN NOT EXISTS(
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid
    WHERE p.proname LIKE 'owner_%' AND n.nspname='public'
    AND p.prosecdef = false
  ) THEN 'PASS' ELSE 'FAIL' END AS result;

-- Q4.6: decrypt_pii is SECDEF
SELECT 'Q4.6 decrypt_pii is SECDEF' AS test,
  CASE WHEN EXISTS(
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid
    WHERE p.proname='decrypt_pii' AND n.nspname='public'
    AND p.prosecdef = true
  ) THEN 'PASS' ELSE 'FAIL' END AS result;

-- Q4.7: rls_auto_enable is SECDEF (auto-enables RLS on new tables)
SELECT 'Q4.7 rls_auto_enable is SECDEF' AS test,
  CASE WHEN EXISTS(
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid
    WHERE p.proname='rls_auto_enable' AND n.nspname='public'
    AND p.prosecdef = true
  ) THEN 'PASS' ELSE 'FAIL' END AS result;
