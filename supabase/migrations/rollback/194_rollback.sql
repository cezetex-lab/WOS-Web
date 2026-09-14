-- ================================================================
-- rollback/194_rollback.sql — Rollback migration 194
-- Drop the hardened RPCs from trust-the-client audit.
-- Verified against live DB + migration source (2026-09-14).
-- NOTE: Only admin_reset_worker_password exists on live.
-- Other functions (admin_set_employee_role, approve_team_request,
-- process_request, admin_approve_request, admin_reject_request,
-- worker_update_profile, clock_in, clock_out, get_worker_payroll_secure,
-- get_narrative) may be called by frontend — DROP with caution.
-- ================================================================

-- Functions from migration 194:
DROP FUNCTION IF EXISTS admin_reset_worker_password(text, text);
DROP FUNCTION IF EXISTS admin_set_employee_role(text, integer, text);
DROP FUNCTION IF EXISTS approve_team_request(text, text, text);
DROP FUNCTION IF EXISTS process_request(text, text, text);
DROP FUNCTION IF EXISTS admin_approve_request(text, text, text);
DROP FUNCTION IF EXISTS admin_reject_request(text, text, text);
DROP FUNCTION IF EXISTS worker_update_profile(text, text);
DROP FUNCTION IF EXISTS clock_in(text, text);
DROP FUNCTION IF EXISTS clock_out(text, text);
DROP FUNCTION IF EXISTS get_worker_payroll_secure(text);
DROP FUNCTION IF EXISTS get_narrative(text);

DO $$ BEGIN RAISE NOTICE '194_rollback: trust-the-client RPCs dropped'; END $$;
