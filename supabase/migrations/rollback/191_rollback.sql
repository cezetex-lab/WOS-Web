-- ================================================================
-- rollback/191_rollback.sql — Rollback migration 191
-- Drop admin approve/reject/OTP functions created in 191.
-- Note: These functions may be called by other code; ensure no
-- active callers before rolling back.
-- ================================================================

DROP FUNCTION IF EXISTS admin_approve_leave(text, text);
DROP FUNCTION IF EXISTS admin_reject_leave(text, text);
DROP FUNCTION IF EXISTS admin_approve_overtime(text, text);
DROP FUNCTION IF EXISTS admin_reject_overtime(text, text);
DROP FUNCTION IF EXISTS admin_approve_shift_swap(text, text);
DROP FUNCTION IF EXISTS admin_reject_shift_swap(text, text);
DROP FUNCTION IF EXISTS admin_approve_facility(text, text);
DROP FUNCTION IF EXISTS admin_reject_facility(text, text);
DROP FUNCTION IF EXISTS admin_approve_pending(text, text);
DROP FUNCTION IF EXISTS admin_reject_pending(text, text);
DROP FUNCTION IF EXISTS admin_bulk_approve_pending(text[], text);
DROP FUNCTION IF EXISTS generate_admin_otp(text);
DROP FUNCTION IF EXISTS verify_admin_otp(text, text, text);

-- Note: permissions seeded in 191 are left as-is (not harmful)
-- Audit log entries from 191 are left as-is

DO $$ BEGIN RAISE NOTICE '191_rollback: admin approve/reject/OTP functions dropped'; END $$;
