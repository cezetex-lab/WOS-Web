-- ================================================================
-- 210_revoke_anon_remaining.sql — Tahap 5.8 (F-8 + A1/A2)
--
-- REVOKE anon/PUBLIC EXECUTE from 9 RPCs that should not be
-- callable without authentication.
-- ================================================================

-- REVOKE from anon and PUBLIC
REVOKE EXECUTE ON FUNCTION get_field_status(text) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION get_irrigation_status(text) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION get_maintenance_schedule(text) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION get_mill_production(text) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION get_yield_data(text) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION change_password(text, text, text) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION check_login_lockout(text, text) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION get_branding() FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION cleanup_rate_limits() FROM anon, PUBLIC;

-- Verify: anon should have 0 EXECUTE on these
SELECT '210.1 anon revoked from 9 RPCs' AS test,
  CASE WHEN (
    SELECT count(*) FROM (
      SELECT p.proname, g.rolname
      FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace,
      aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
      JOIN pg_roles g ON g.oid=a.grantee
      WHERE n.nspname='public' AND p.proname IN (
        'get_field_status','get_irrigation_status','get_maintenance_schedule',
        'get_mill_production','get_yield_data','change_password',
        'check_login_lockout','get_branding','cleanup_rate_limits'
      ) AND g.rolname = 'anon'
    ) t
  ) = 0 THEN 'PASS' ELSE 'FAIL' END AS result;
