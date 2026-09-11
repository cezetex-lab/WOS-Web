-- Enable pg_cron extension (F-7: pg_cron belum terinstal — aktif dari migration
-- supaya schedule setup di bawah bisa jalan; migrasi di-run sebagai postgres)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- ============================================================
-- insightWOS — Migration 186: Enable pg_cron Schedules
-- Enables previously commented-out cron jobs for:
--   1. Materialized View auto-refresh (hourly)
--   2. Data retention cleanup (daily 02:00 UTC)
--   3. Session cleanup (daily 02:30 UTC)
-- ============================================================
-- Prerequisites:
--   - pg_cron extension must be enabled in Supabase Dashboard
--     (Database -> Extensions -> pg_cron)
--   - All referenced functions must exist (migrations 035, 145, 147)
-- ============================================================

-- Guard: only run if pg_cron is installed
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    RAISE NOTICE 'pg_cron not installed — skipping schedule setup';
    RETURN;
  END IF;

  -- ── 1. MATERIALIZED VIEW REFRESH (Hourly) ──
  -- Refreshes all materialized views via the unified RPC
  -- Previously defined in migration 035 (commented out)

  -- Unschedule existing jobs if they exist (idempotent)
  PERFORM cron.unschedule('refresh-mv-admin-summary') WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'refresh-mv-admin-summary'
  );
  PERFORM cron.unschedule('refresh-mv-team-kpi') WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'refresh-mv-team-kpi'
  );
  PERFORM cron.unschedule('refresh-mv-attendance') WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'refresh-mv-attendance'
  );
  PERFORM cron.unschedule('refresh-all-mv') WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'refresh-all-mv'
  );

  -- Schedule: refresh all materialized views every hour at :05
  PERFORM cron.schedule(
    'refresh-all-mv',
    '5 * * * *',
    'SELECT refresh_all_materialized_views()'
  );

  RAISE NOTICE 'Scheduled: refresh-all-mv (hourly at :05)';

  -- ── 2. DATA RETENTION CLEANUP (Daily 02:00 UTC) ──
  -- Cleans expired audit_log, api_rate_limits, session_tokens,
  -- login_attempts, otp_store based on company_config retention rules
  -- Function: cleanup_expired_data() (migration 147)

  PERFORM cron.unschedule('cleanup-expired-data') WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'cleanup-expired-data'
  );

  PERFORM cron.schedule(
    'cleanup-expired-data',
    '0 2 * * *',
    'SELECT cleanup_expired_data()'
  );

  RAISE NOTICE 'Scheduled: cleanup-expired-data (daily 02:00 UTC)';

  -- ── 3. SESSION CLEANUP (Daily 02:30 UTC) ──
  -- Removes expired/old sessions from session_tokens
  -- Function: cleanup_expired_sessions() (migration 084 area)

  PERFORM cron.unschedule('cleanup-expired-sessions') WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'cleanup-expired-sessions'
  );

  PERFORM cron.schedule(
    'cleanup-expired-sessions',
    '30 2 * * *',
    'SELECT cleanup_expired_sessions()'
  );

  RAISE NOTICE 'Scheduled: cleanup-expired-sessions (daily 02:30 UTC)';

  -- ── 4. RATE LIMIT CLEANUP (Daily 03:00 UTC) ──
  -- Cleans expired rate limit entries
  -- Function: cleanup_rate_limits() (migration 035 area)

  PERFORM cron.unschedule('cleanup-rate-limits') WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'cleanup-rate-limits'
  );

  PERFORM cron.schedule(
    'cleanup-rate-limits',
    '0 3 * * *',
    'SELECT cleanup_rate_limits()'
  );

  RAISE NOTICE 'Scheduled: cleanup-rate-limits (daily 03:00 UTC)';

END $$;

-- ── Verify ──
-- Run after migration to confirm schedules:
-- SELECT jobid, jobname, schedule, command FROM cron.job ORDER BY jobid;
