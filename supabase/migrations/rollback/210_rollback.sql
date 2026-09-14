-- ================================================================
-- rollback/210_rollback.sql — Rollback migration 210
-- GRANT back anon/PUBLIC EXECUTE on RPCs that were revoked.
-- WARNING: Re-exposes unauthenticated access to these RPCs.
-- ================================================================

GRANT EXECUTE ON FUNCTION get_field_status(text) TO anon, PUBLIC;
GRANT EXECUTE ON FUNCTION get_irrigation_status(text) TO anon, PUBLIC;
GRANT EXECUTE ON FUNCTION get_maintenance_schedule(text) TO anon, PUBLIC;
GRANT EXECUTE ON FUNCTION get_mill_production(text) TO anon, PUBLIC;
GRANT EXECUTE ON FUNCTION get_yield_data(text) TO anon, PUBLIC;
GRANT EXECUTE ON FUNCTION change_password(text, text, text) TO anon, PUBLIC;
GRANT EXECUTE ON FUNCTION check_login_lockout(text, text) TO anon, PUBLIC;
GRANT EXECUTE ON FUNCTION get_branding() TO anon, PUBLIC;
GRANT EXECUTE ON FUNCTION cleanup_rate_limits() TO anon, PUBLIC;

DO $$ BEGIN RAISE NOTICE '210_rollback: anon/PUBLIC EXECUTE restored on 9 RPCs'; END $$;
