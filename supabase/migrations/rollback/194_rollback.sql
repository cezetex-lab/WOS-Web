-- ================================================================
-- rollback/194_rollback.sql — Rollback migration 194
-- Drop the hardened RPCs from trust-the-client audit.
-- WARNING: Reverts security fixes — only for emergency rollback.
-- ================================================================

-- Functions fixed/hardened in 194:
DROP FUNCTION IF EXISTS admin_reset_worker_password(text, text);
DROP FUNCTION IF EXISTS admin_update_worker_status(text, text, text);
DROP FUNCTION IF EXISTS admin_update_worker_division(text, text, text, text);
DROP FUNCTION IF EXISTS admin_update_worker_site(text, text, text);
DROP FUNCTION IF EXISTS admin_update_worker_role(text, integer, text);
DROP FUNCTION IF EXISTS admin_update_worker_contract(text, date, date, text);
DROP FUNCTION IF EXISTS admin_update_worker_salary(text, numeric, text);
DROP FUNCTION IF EXISTS admin_update_worker_bank(text, text, text, text, text);
DROP FUNCTION IF EXISTS admin_update_worker_bpjs(text, text, text, text);
DROP FUNCTION IF EXISTS admin_update_worker_health(text, text, text, text, text);
DROP FUNCTION IF EXISTS admin_update_worker_education(text, text, text, integer, text);
DROP FUNCTION IF EXISTS admin_update_worker_training(text, text, text, text, text);
DROP FUNCTION IF EXISTS admin_update_worker_certification(text, text, text, date, text);
DROP FUNCTION IF EXISTS admin_update_worker_photo(text, text, text);
DROP FUNCTION IF EXISTS admin_update_worker_address(text, text, text);
DROP FUNCTION IF EXISTS admin_update_worker_emergency(text, text, text, text, text);

-- Permission seeded in 194 left as-is (not harmful)

DO $$ BEGIN RAISE NOTICE '194_rollback: trust-the-client hardened RPCs dropped'; END $$;
