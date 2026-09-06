-- ================================================================
-- 178_fix_smoke_test_data.sql — Use real NRP for smoke tests
--
-- The 4 remaining failures in 175 are all test data issues:
-- 'TEST' NRP doesn't exist in employees_master (FK constraint)
-- Fix: use NRP001 (CEO, exists in seed data)
-- ================================================================

-- Use NRP001 for all tests that need a real NRP
\set real_nrp '''NRP001'''

-- Verify NRP001 exists
SELECT 'VERIFY: NRP001 exists' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM employees_master WHERE nrp='NRP001') THEN 'PASS' ELSE 'FAIL' END AS result;

-- Verify all key functions work with real data
SELECT 'clock_in with NRP001' AS test,
  CASE WHEN clock_in('NRP001') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'get_timesheets with NRP001' AS test,
  CASE WHEN get_timesheets('NRP001') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'create_worker_request with NRP001' AS test,
  CASE WHEN create_worker_request('NRP001','LEAVE','test','test') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'get_whistleblowers' AS test,
  CASE WHEN get_whistleblowers() IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'get_worker_narrative with NRP001' AS test,
  CASE WHEN get_worker_narrative('NRP001') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'get_worker_payroll_secure with NRP001' AS test,
  CASE WHEN get_worker_payroll_secure('NRP001') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'login_worker NRP001/CEO12345!' AS test,
  CASE WHEN login_worker('NRP001','NRP001','CEO12345!') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
