-- ================================================================
-- rollback/209_rollback.sql — Rollback migration 209
-- Drop report_safety_incident and create_harvest_record RPCs.
-- ================================================================

DROP FUNCTION IF EXISTS report_safety_incident(text, text, text, text, text, text);
DROP FUNCTION IF EXISTS create_harvest_record(text, text, text, numeric, text, text);

DO $$ BEGIN RAISE NOTICE '209_rollback: dead form handler RPCs dropped'; END $$;
