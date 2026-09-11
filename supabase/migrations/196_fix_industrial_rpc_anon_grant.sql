-- 196: Fix industrial RPCs incorrectly grantable to anon
-- 
-- Audit finding F-8: Certain industrial RPCs were incorrectly executable by anon 
-- due to being created after the hardening grant migration (172) which revoked 
-- EXECUTE from PUBLIC but didn't explicitly revoke the default PUBLIC privilege 
-- for newly created functions.
--
-- This migration explicitly revokes EXECUTE from PUBLIC (which removes access 
-- from anon and authenticated) then re-grants to authenticated only.
DO $$
DECLARE
    r RECORD;
BEGIN
    -- List of industrial RPCs that should be authenticated-only
    FOR r IN
        SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.proname IN (
              'get_field_status',
              'get_irrigation_status', 
              'get_maintenance_schedule',
              'get_mill_production',
              'get_yield_data'
          )
    LOOP
        BEGIN
            -- First revoke from PUBLIC (removes access from anon and authenticated)
            EXECUTE format('REVOKE EXECUTE ON FUNCTION %I(%s) FROM PUBLIC', r.proname, r.args);
            -- Then grant explicitly to authenticated only
            EXECUTE format('GRANT EXECUTE ON FUNCTION %I(%s) TO authenticated', r.proname, r.args);
        EXCEPTION WHEN OTHERS THEN
            RAISE LOG '196: fix %: %', r.proname, SQLERRM;
        END;
    END LOOP;
END $$

