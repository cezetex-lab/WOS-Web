-- ================================================================
-- rollback/192_rollback.sql — Rollback migration 192
-- Drop auth functions that were restored/fixed in 192.
-- WARNING: This will break worker login/OTP/logout/reset.
-- Only run if you need to revert to the broken state from 171.
-- ================================================================

-- These functions were CREATE OR REPLACE'd in 192 to fix column mismatches.
-- Rolling back means dropping them — but they existed before 192 (just broken).
-- Better approach: do NOT drop; instead note that 192 is a FIX, not an addition.
-- If you truly need to revert, drop these and they'll need to be re-created
-- from the pre-192 state (which was broken).

-- Functions fixed in 192:
-- login_worker(text, text, text)
-- verify_worker_otp(text, text, text)
-- worker_logout(text)
-- change_password(text, text, text)
-- reset_password(text, text)
-- generate_worker_otp(text, text, text)

-- DROP FUNCTION IF EXISTS login_worker(text, text, text);  -- COMMENTED: would break login
-- DROP FUNCTION IF EXISTS verify_worker_otp(text, text, text);
-- DROP FUNCTION IF EXISTS worker_logout(text);
-- DROP FUNCTION IF EXISTS change_password(text, text, text);
-- DROP FUNCTION IF EXISTS reset_password(text, text);
-- DROP FUNCTION IF EXISTS generate_worker_otp(text, text, text);

-- Instead, revert the salt nullable change:
-- ALTER TABLE worker_passwords ALTER COLUMN salt SET NOT NULL;  -- COMMENTED: may fail if salt NULLs exist

DO $$ BEGIN RAISE NOTICE '192_rollback: NOTE — 192 is a fix, not addition. Rollback is destructive. Functions NOT dropped by default.'; END $$;
