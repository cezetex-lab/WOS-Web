-- ================================================================
-- rollback/212_rollback.sql — Rollback migration 212
-- Unschedule pg_cron jobs. Extension left enabled (safe).
-- ================================================================

SELECT cron.unschedule('refresh-mv-admin-summary');
SELECT cron.unschedule('refresh-mv-team-kpi');
SELECT cron.unschedule('refresh-mv-attendance');
SELECT cron.unschedule('cleanup-sessions');
SELECT cron.unschedule('cleanup-rate-limits');
SELECT cron.unschedule('cleanup-otp');

DO $$ BEGIN RAISE NOTICE '212_rollback: 6 pg_cron jobs unscheduled'; END $$;
