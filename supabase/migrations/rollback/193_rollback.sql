-- ================================================================
-- rollback/193_rollback.sql — Rollback migration 193
-- Drop rate limit functions. Verified: atomic_rate_limit does NOT
-- exist on live (was likely rolled back or merged). hit_rate_limit
-- and cleanup_rate_limits DO exist.
-- ================================================================

DROP FUNCTION IF EXISTS hit_rate_limit(text, text, integer, integer);
DROP FUNCTION IF EXISTS cleanup_rate_limits();

DO $$ BEGIN RAISE NOTICE '193_rollback: hit_rate_limit + cleanup_rate_limits dropped'; END $$;
