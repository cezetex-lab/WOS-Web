-- ================================================================
-- 221_revoke_anon_admin_grants.sql
-- 
-- AUDIT FINDING: 7 SECURITY DEFINER functions are callable by
-- anon/PUBLIC, allowing unauthenticated users to:
--   1. View all employee payroll data (admin_get_payroll)
--   2. Approve/reject requests as any user (process_request)
--   3. Execute database migrations (apply_migration)
--   4. Leak audit trail integrity data (audit_log_hash_chain,
--      verify_audit_chain, check_migrations,
--      verify_migration_checksum)
--
-- Source: DB live audit 2026-09-16 via information_schema
-- Migration chain that caused this:
--   043: GRANT admin functions to anon (wrong pattern)
--   172: GRANT login/auth to anon (correct)
--   190: GRANT admin_get_payroll to anon (BUG)
--   194: REVOKE anon from process_request (partial - missed PUBLIC)
--   215: RE-GRANT admin_get_payroll to anon (BUG override!)
--   216: GRANT login_worker_by_email to anon (correct)
-- ================================================================

-- ── PHASE 1: REVOKE from anon (direct grants) ───────────────────
-- These functions should NEVER be callable without authentication.
REVOKE EXECUTE ON FUNCTION public.admin_get_payroll(text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.process_request(text, text, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.apply_migration(text, text, text, text, integer) FROM anon;
REVOKE EXECUTE ON FUNCTION public.audit_log_hash_chain() FROM anon;
REVOKE EXECUTE ON FUNCTION public.verify_audit_chain(int, int) FROM anon;
REVOKE EXECUTE ON FUNCTION public.check_migrations(text[]) FROM anon;
REVOKE EXECUTE ON FUNCTION public.verify_migration_checksum(text, text) FROM anon;

-- ── PHASE 2: REVOKE from PUBLIC ─────────────────────────────────
-- PUBLIC grants are inherited by ALL roles including anon.
-- Migration 194 only revoked from anon, missing the PUBLIC grant
-- on process_request. All 7 functions + triggers must be cleaned.
REVOKE EXECUTE ON FUNCTION public.admin_get_payroll(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.process_request(text, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.apply_migration(text, text, text, text, integer) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.audit_log_hash_chain() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.verify_audit_chain(int, int) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.check_migrations(text[]) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.verify_migration_checksum(text, text) FROM PUBLIC;

-- Also revoke trigger functions that should not be PUBLIC-callable
REVOKE EXECUTE ON FUNCTION public.employees_master_delete_trigger() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.employees_master_insert_trigger() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.employees_master_update_trigger() FROM PUBLIC;

-- ── PHASE 3: RE-GRANT to authenticated only ─────────────────────
-- admin_get_payroll: called by admin pages -> authenticated role
GRANT EXECUTE ON FUNCTION public.admin_get_payroll(text) TO authenticated;

-- process_request: called by admin/worker approval UI -> authenticated
GRANT EXECUTE ON FUNCTION public.process_request(text, text, text) TO authenticated;

-- Note: apply_migration, audit_log_hash_chain, verify_audit_chain,
-- check_migrations, verify_migration_checksum - NO re-grant needed.
-- These are admin/infra-only functions. Access controlled by
-- SECURITY DEFINER + RLS policies + app-level auth checks.

-- Note: change_password(text,text,text) - VERIFIED SAFE.
-- Only granted to authenticated, postgres, service_role.
-- NOT in this migration.

-- ================================================================
-- POST-REVOKE: Verify by querying information_schema
-- Run after applying:
--   SELECT routine_name, grantee
--   FROM information_schema.role_routine_grants
--   WHERE routine_name IN (
--     'admin_get_payroll', 'process_request', 'apply_migration',
--     'audit_log_hash_chain', 'verify_audit_chain',
--     'check_migrations', 'verify_migration_checksum'
--   )
--   AND grantee IN ('anon', 'PUBLIC')
--   ORDER BY routine_name, grantee;
-- Expected: 0 rows
-- ================================================================