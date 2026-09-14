-- ================================================================
-- rollback/213_rollback.sql — Rollback migration 213
-- Drop submit_registration and get_branding_public RPCs.
-- ================================================================

DROP FUNCTION IF EXISTS submit_registration(text, text, text, text, text, text, text);
DROP FUNCTION IF EXISTS get_branding_public();

DO $$ BEGIN RAISE NOTICE '213_rollback: registration and branding RPCs dropped'; END $$;
