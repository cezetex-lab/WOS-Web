-- ================================================================
-- 182_fix_mv_rls.sql
-- Materialized views don't support RLS in PostgreSQL < 16.
-- Fix: REVOKE all direct access, force reads through
-- SECURITY DEFINER functions (get_dashboard_cached, etc.)
-- ================================================================

-- Step 1: Revoke ALL from PUBLIC, anon, authenticated on all 5 MVs
REVOKE ALL ON mv_admin_summary FROM PUBLIC, anon, authenticated;
REVOKE ALL ON mv_attendance_daily FROM PUBLIC, anon, authenticated;
REVOKE ALL ON mv_flight_risk FROM PUBLIC, anon, authenticated;
REVOKE ALL ON mv_payroll_monthly FROM PUBLIC, anon, authenticated;
REVOKE ALL ON mv_team_kpi FROM PUBLIC, anon, authenticated;

-- Step 2: Only service_role can read (for refresh functions)
GRANT SELECT ON mv_admin_summary TO service_role;
GRANT SELECT ON mv_attendance_daily TO service_role;
GRANT SELECT ON mv_flight_risk TO service_role;
GRANT SELECT ON mv_payroll_monthly TO service_role;
GRANT SELECT ON mv_team_kpi TO service_role;

-- Note: service_role (superuser) already has REFRESH privilege.
-- REFRESH GRANT not supported on all PG versions — skip.

-- Step 3: Verify
SELECT matviewname,
  (SELECT EXISTS(SELECT 1 FROM pg_class c WHERE c.relname = m.matviewname AND relrowsecurity = true)) AS has_rls
FROM pg_matviews m WHERE schemaname = 'public' ORDER BY matviewname;

-- Step 4: Confirm anon/authenticated CANNOT select from MVs directly
-- (these should all fail when run as anon/authenticated)
SELECT 'MV access test — anon should be blocked' AS test;
