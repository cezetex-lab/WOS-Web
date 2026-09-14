-- ================================================================
-- rollback/216_rollback.sql — Rollback migration 216
-- Drop login_worker_by_email function
-- ================================================================

DROP FUNCTION IF EXISTS public.login_worker_by_email(text, text);

NOTIFY pgrst, 'reload schema';
