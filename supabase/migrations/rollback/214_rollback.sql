-- ================================================================
-- rollback/214_rollback.sql — Rollback migration 214
-- Drop update_audit_timestamp, get_organization_health, and
-- remove updated_at columns from HR tables.
-- WARNING: update_audit_timestamp is referenced by 22 triggers.
-- Dropping it will cause those triggers to fail.
-- ================================================================

-- Drop functions
DROP FUNCTION IF EXISTS update_audit_timestamp() CASCADE;
DROP FUNCTION IF EXISTS get_organization_health();

-- Drop updated_at columns from HR tables
ALTER TABLE IF EXISTS hr_payroll DROP COLUMN IF EXISTS updated_at;
ALTER TABLE IF EXISTS hr_performance DROP COLUMN IF EXISTS updated_at;
ALTER TABLE IF EXISTS hr_tasks DROP COLUMN IF EXISTS updated_at;
ALTER TABLE IF EXISTS hr_leave DROP COLUMN IF EXISTS updated_at;
ALTER TABLE IF EXISTS hr_overtime DROP COLUMN IF EXISTS updated_at;
ALTER TABLE IF EXISTS hr_requests DROP COLUMN IF EXISTS updated_at;

DO $$ BEGIN RAISE NOTICE '214_rollback: update_audit_timestamp + get_organization_health dropped, updated_at columns removed'; END $$;
