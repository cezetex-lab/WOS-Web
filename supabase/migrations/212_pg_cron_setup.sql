-- ================================================================
-- 212_pg_cron_setup.sql — F-7: pg_cron installation + cron jobs
--
-- PREREQUISITE: Enable pg_cron in Supabase Dashboard:
--   Database → Extensions → pg_cron → Enable
--
-- This migration will fail if pg_cron is not installed.
-- Run AFTER enabling pg_cron in the dashboard.
-- ================================================================

-- 1. Install pg_cron (idempotent)
-- Guard (2026-09-18): pg_cron hanya bisa dipasang di database `postgres`; di
-- database scratch/CI perintah ini ERROR dan menggagalkan seluruh berkas.
-- Dibungkus supaya instalasi tetap lanjut (NOTICE, bukan gagal).
DO $$
BEGIN
  BEGIN
    CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '212: pg_cron tidak bisa dipasang di database ini (%) — dilewati', SQLERRM;
  END;
END $$;

-- 2. Schedule cron jobs (idempotent via unschedule + schedule)

-- 2a. Refresh materialized views (hourly)
SELECT cron.schedule('refresh-mv-admin-summary', '0 * * * *',
  'REFRESH MATERIALIZED VIEW CONCURRENTLY mv_admin_summary');
SELECT cron.schedule('refresh-mv-team-kpi', '0 * * * *',
  'REFRESH MATERIALIZED VIEW CONCURRENTLY mv_team_kpi');
SELECT cron.schedule('refresh-mv-attendance', '*/30 * * * *',
  'REFRESH MATERIALIZED VIEW CONCURRENTLY mv_attendance_daily');

-- 2b. Cleanup expired sessions (daily at 2am)
SELECT cron.schedule('cleanup-sessions', '0 2 * * *',
  'SELECT cleanup_expired_sessions()');

-- 2c. Cleanup rate limits (daily at 3am)
SELECT cron.schedule('cleanup-rate-limits', '0 3 * * *',
  'SELECT cleanup_rate_limits()');

-- 2d. Cleanup old OTP codes (every 15 minutes)
SELECT cron.schedule('cleanup-otp', '*/15 * * * *',
  $$DELETE FROM otp_store WHERE expiry < NOW() - INTERVAL '1 hour'$$);

-- 3. Verify
SELECT '212.1 pg_cron installed' AS test,
  CASE WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname='cron')
  THEN 'PASS' ELSE 'FAIL: enable pg_cron in Supabase Dashboard' END AS result;

SELECT '212.2 cron jobs scheduled' AS test,
  count(*)::text AS result FROM cron.job;
