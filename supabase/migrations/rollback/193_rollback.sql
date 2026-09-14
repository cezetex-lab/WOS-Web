-- ================================================================
-- rollback/193_rollback.sql — Rollback migration 193
-- Drop atomic rate limit function + revert hit_rate_limit.
-- ================================================================

DROP FUNCTION IF EXISTS atomic_rate_limit(text, text, integer, integer);
DROP FUNCTION IF EXISTS hit_rate_limit(text, text, integer, integer);
DROP FUNCTION IF EXISTS cleanup_rate_limits();

DO $$ BEGIN RAISE NOTICE '193_rollback: atomic rate limit functions dropped'; END $$;
