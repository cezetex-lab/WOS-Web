-- ============================================================
-- insightWOS — pg_cron Setup
-- Automated tasks: KPI calculation, early detection, etc.
-- ============================================================
-- Prerequisites:
--   ALTER DATABASE postgres SET "app.settings" TO '{"cron_secret":"YOUR_SECRET"}';
--   CREATE EXTENSION IF NOT EXISTS pg_cron;
-- ============================================================

-- ── Enable pg_cron (Supabase Dashboard → Database → Extensions)
-- CREATE EXTENSION IF NOT EXISTS pg_cron;

-- ── 1. KPI BULANAN — Setiap tanggal 1 jam 02:00 UTC
-- ============================================================
SELECT cron.schedule(
  'calculate-monthly-kpi',           -- Job name
  '0 2 1 * *',                       -- Cron expression: 1st of month at 02:00
  $$
  SELECT net.http_post(
    url := current_setting('app.settings.supabase_url') || '/functions/v1/cron-handler',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', current_setting('app.settings.cron_secret')
    ),
    body := jsonb_build_object(
      'task', 'calculate_monthly_kpi',
      'params', jsonb_build_object('period', to_char(now() - interval '1 month', 'YYYY-MM'))
    )
  );
  $$
);

-- ── 2. DETEKSI DINI HARIAN — Setiap hari jam 06:00 UTC
-- ============================================================
SELECT cron.schedule(
  'run-early-detection',
  '0 6 * * *',                       -- Daily at 06:00 UTC
  $$
  SELECT net.http_post(
    url := current_setting('app.settings.supabase_url') || '/functions/v1/cron-handler',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', current_setting('app.settings.cron_secret')
    ),
    body := jsonb_build_object('task', 'run_early_detection')
  );
  $$
);

-- ── 3. AUTO-HEALING — Setiap hari jam 07:00 UTC
-- ============================================================
SELECT cron.schedule(
  'run-auto-healing',
  '0 7 * * *',                       -- Daily at 07:00 UTC
  $$
  SELECT net.http_post(
    url := current_setting('app.settings.supabase_url') || '/functions/v1/cron-handler',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', current_setting('app.settings.cron_secret')
    ),
    body := jsonb_build_object('task', 'run_auto_healing')
  );
  $$
);

-- ── 4. PKWT EXPIRY CHECK — Setiap hari jam 08:00 UTC
-- ============================================================
SELECT cron.schedule(
  'check-pkwt-expiry',
  '0 8 * * *',                       -- Daily at 08:00 UTC
  $$
  SELECT net.http_post(
    url := current_setting('app.settings.supabase_url') || '/functions/v1/cron-handler',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', current_setting('app.settings.cron_secret')
    ),
    body := jsonb_build_object(
      'task', 'check_pkwt_expiry',
      'params', jsonb_build_object('days_before', 90)
    )
  );
  $$
);

-- ── 5. ATTENDANCE SUMMARY — Setiap hari jam 23:00 UTC
-- ============================================================
SELECT cron.schedule(
  'generate-attendance-summary',
  '0 23 * * *',                      -- Daily at 23:00 UTC
  $$
  SELECT net.http_post(
    url := current_setting('app.settings.supabase_url') || '/functions/v1/cron-handler',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', current_setting('app.settings.cron_secret')
    ),
    body := jsonb_build_object(
      'task', 'generate_attendance_summary',
      'params', jsonb_build_object('date', to_char(now(), 'YYYY-MM-DD'))
    )
  );
  $$
);

-- ── 6. HEALTH SCORE — Setiap hari jam 09:00 UTC
-- ============================================================
SELECT cron.schedule(
  'calculate-health-score',
  '0 9 * * *',                       -- Daily at 09:00 UTC
  $$
  SELECT net.http_post(
    url := current_setting('app.settings.supabase_url') || '/functions/v1/cron-handler',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', current_setting('app.settings.cron_secret')
    ),
    body := jsonb_build_object('task', 'calculate_health_score')
  );
  $$
);

-- ── 7. CLEANUP EXPIRED OTP — Setiap jam
-- ============================================================
SELECT cron.schedule(
  'cleanup-expired-otps',
  '0 * * * *',                       -- Every hour
  $$
  DELETE FROM otp_codes WHERE expires_at < now();
  $$
);

-- ── 8. CLEANUP OLD CRON LOGS — Setiap minggu
-- ============================================================
SELECT cron.schedule(
  'cleanup-old-cron-logs',
  '0 3 * * 0',                       -- Every Sunday at 03:00 UTC
  $$
  DELETE FROM cron_log WHERE executed_at < now() - interval '30 days';
  DELETE FROM gas_migration_log WHERE executed_at < now() - interval '30 days';
  $$
);

-- ── Verify schedules ──
-- SELECT * FROM cron.job;
-- SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;
