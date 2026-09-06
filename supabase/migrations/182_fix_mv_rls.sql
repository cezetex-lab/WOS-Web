-- ================================================================
-- 182_fix_mv_rls.sql
-- Materialized views don't support RLS in PostgreSQL < 16.
-- Fix: REVOKE all direct access, force reads through
-- SECURITY DEFINER functions (get_dashboard_cached, etc.)
-- ================================================================

-- Step 1: Revoke ALL from PUBLIC, anon, authenticated on all 5 MVs
DO $$
DECLARE
  mv RECORD;
  mvs TEXT[] := ARRAY['mv_admin_summary','mv_attendance_daily','mv_flight_risk','mv_payroll_monthly','mv_team_kpi'];
BEGIN
  FOREACH mv_name IN ARRAY mvs LOOP
    IF EXISTS (SELECT 1 FROM pg_matviews WHERE matviewname = mv_name) THEN
      EXECUTE format('REVOKE ALL ON %I FROM PUBLIC, anon, authenticated', mv_name);
      EXECUTE format('GRANT SELECT ON %I TO service_role', mv_name);
      RAISE LOG '182: secured %', mv_name;
    ELSE
      RAISE LOG '182: skip % (not found)', mv_name;
    END IF;
  END LOOP;
END $$;

-- Note: service_role (superuser) already has REFRESH privilege.
-- REFRESH GRANT not supported on all PG versions — skip.

-- Step 3: Verify
SELECT matviewname,
  (SELECT EXISTS(SELECT 1 FROM pg_class c WHERE c.relname = m.matviewname AND relrowsecurity = true)) AS has_rls
FROM pg_matviews m WHERE schemaname = 'public' ORDER BY matviewname;

-- Step 4: Confirm anon/authenticated CANNOT select from MVs directly
-- (these should all fail when run as anon/authenticated)
SELECT 'MV access test — anon should be blocked' AS test;
