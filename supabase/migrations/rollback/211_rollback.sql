-- ================================================================
-- rollback/211_rollback.sql — Rollback migration 211
-- Drop INSTEAD OF triggers on employees_master VIEW.
-- ================================================================

DROP TRIGGER IF EXISTS employees_master_insert_trigger ON employees_master;
DROP TRIGGER IF EXISTS employees_master_update_trigger ON employees_master;
DROP TRIGGER IF EXISTS employees_master_delete_trigger ON employees_master;
DROP FUNCTION IF EXISTS employees_master_insert_trigger() CASCADE;
DROP FUNCTION IF EXISTS employees_master_update_trigger() CASCADE;
DROP FUNCTION IF EXISTS employees_master_delete_trigger() CASCADE;

DO $$ BEGIN RAISE NOTICE '211_rollback: INSTEAD OF triggers on employees_master dropped'; END $$;
