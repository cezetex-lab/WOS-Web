-- ============================================================
-- 035: WAVE B — Connection & Cache Architecture
-- 1. Materialized Views (5 MVP)
-- 2. Composite Indexes
-- 3. PgBouncer config (documentasi)
-- 4. Redis session table
-- 5. Rate limiting table
-- ============================================================

-- ── 1. MATERIALIZED VIEWS (5 MVP) ──
-- Untuk sub-50ms query di dashboard

-- MV 1: Admin Summary Dashboard
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_admin_summary AS
SELECT 
  (SELECT count(*) FROM employees_master WHERE status_kerja = 'Aktif') as total_employees,
  (SELECT count(*) FROM employees_master WHERE business_unit = 'MINING') as mining_count,
  (SELECT count(*) FROM employees_master WHERE business_unit = 'ESTATE') as estate_count,
  (SELECT count(*) FROM employees_master WHERE business_unit = 'MILL') as mill_count,
  (SELECT count(*) FROM employees_master WHERE business_unit = 'HQ') as hq_count,
  (SELECT count(*) FROM hr_performance WHERE kpi_score >= 80) as high_performers,
  (SELECT count(*) FROM hr_performance WHERE kpi_score < 60) as low_performers,
  (SELECT count(*) FROM hr_requests WHERE status = 'Pending') as pending_requests,
  (SELECT count(*) FROM daftar_baru WHERE status = 'PENDING') as pending_registration,
  NOW() as refreshed_at;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_admin_summary ON mv_admin_summary (refreshed_at);

-- MV 2: Team KPI by Business Unit
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_team_kpi AS
SELECT 
  e.business_unit,
  e.divisi,
  count(*) as headcount,
  avg(p.kpi_score) as avg_kpi,
  count(*) FILTER (WHERE p.kpi_score >= 80) as high_performers,
  count(*) FILTER (WHERE p.kpi_score < 60) as low_performers
FROM employees_master e
LEFT JOIN hr_performance p ON p.nrp = e.nrp
WHERE e.status_kerja = 'Aktif'
GROUP BY e.business_unit, e.divisi;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_team_kpi ON mv_team_kpi (business_unit, divisi);

-- MV 3: Payroll Monthly Summary
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_payroll_monthly AS
SELECT 
  e.business_unit,
  p.periode,
  count(*) as employee_count,
  sum(p.base_salary) as total_gaji_pokok,
  sum(p.allowance) as total_tunjangan,
  sum(p.deduction) as total_potongan,
  sum(p.net_salary) as total_bersih
FROM hr_payroll p
JOIN employees_master e ON e.nrp = p.nrp
GROUP BY e.business_unit, p.periode;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_payroll_monthly ON mv_payroll_monthly (business_unit, periode);

-- MV 4: Attendance Daily
-- hr_attendance kolom: date, status_hadir, jam_masuk, menit_terlambat
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_attendance_daily AS
SELECT 
  e.business_unit,
  a.date as tanggal,
  count(*) as total_workers,
  count(*) FILTER (WHERE a.status_hadir = 'Hadir') as hadir,
  count(*) FILTER (WHERE a.status_hadir = 'Alpha') as alpha,
  count(*) FILTER (WHERE a.status_hadir = 'Izin') as izin,
  count(*) FILTER (WHERE a.status_hadir = 'Sakit') as sakit,
  round(count(*) FILTER (WHERE a.status_hadir = 'Hadir')::decimal / count(*) * 100, 1) as attendance_rate
FROM hr_attendance a
JOIN employees_master e ON e.nrp = a.nrp
GROUP BY e.business_unit, a.date;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_attendance_daily ON mv_attendance_daily (business_unit, tanggal);

-- MV 5: Flight Risk Score
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_flight_risk AS
SELECT 
  e.nrp,
  e.nama,
  e.divisi,
  e.business_unit,
  COALESCE(p.kpi_score, 0) as kpi_score,
  CASE 
    WHEN COALESCE(p.kpi_score, 0) < 50 THEN 'HIGH'
    WHEN COALESCE(p.kpi_score, 0) < 70 THEN 'MEDIUM'
    ELSE 'LOW'
  END as risk_level,
  CASE 
    WHEN COALESCE(p.kpi_score, 0) < 50 THEN 3
    WHEN COALESCE(p.kpi_score, 0) < 70 THEN 2
    ELSE 1
  END as risk_score
FROM employees_master e
LEFT JOIN hr_performance p ON p.nrp = e.nrp
WHERE e.status_kerja = 'Aktif';

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_flight_risk ON mv_flight_risk (nrp);

-- ── 2. COMPOSITE INDEXES ──
-- Covering indexes untuk query paling sering

-- Employees by business_unit + status
CREATE INDEX IF NOT EXISTS idx_emp_bu_status 
ON employees_master (business_unit, status_kerja, nrp, nama, divisi, posisi);

-- Performance by NRP + periode
CREATE INDEX IF NOT EXISTS idx_perf_nrp_periode 
ON hr_performance (nrp, periode DESC, kpi_score);

-- Payroll by NRP + periode
CREATE INDEX IF NOT EXISTS idx_payroll_nrp_periode 
ON hr_payroll (nrp, periode DESC, net_salary);

-- Requests by status + type
CREATE INDEX IF NOT EXISTS idx_requests_status_type 
ON hr_requests (status, type, nrp, created_at DESC);

-- Attendance by NRP + date
CREATE INDEX IF NOT EXISTS idx_attendance_nrp_date 
ON hr_attendance (nrp, date DESC, status_hadir);

-- Org hierarchy
CREATE INDEX IF NOT EXISTS idx_org_atasan 
ON hr_org (atasan_nrp, nrp);

-- ── 3. PGBOUNCER CONFIGURATION ──
-- Dokumentasi untuk Supabase Dashboard:
-- 
-- Untuk menggunakan PgBouncer Transaction Mode:
-- 1. Buka Supabase Dashboard → Settings → Database
-- 2. Scroll ke "Connection pooling"
-- 3. Enable "Transaction" mode (port 6543)
-- 4. Ganti connection string di .env:
--    VITE_SUPABASE_URL=https://xxx.supabase.co (tetap sama)
--    Vite menggunakan anon key, tidak perlu ganti port
--    
-- Untuk Edge Functions yang pakai SERVICE_ROLE_KEY:
--    Gunakan pooler URL: postgresql://postgres.xxx:password@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres
--    Mode: Transaction (default)

-- ── 4. REDIS SESSION TABLE (Fallback jika Redis down) ──
CREATE TABLE IF NOT EXISTS session_store (
  token TEXT PRIMARY KEY,
  nrp TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'worker',
  role_level INTEGER DEFAULT 1,
  business_unit TEXT DEFAULT 'HQ',
  data JSONB DEFAULT '{}',
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_session_nrp ON session_store (nrp);
CREATE INDEX IF NOT EXISTS idx_session_expires ON session_store (expires_at);

-- Function: Create session (for Level 3-5 users)
CREATE OR REPLACE FUNCTION create_session(
  p_nrp TEXT,
  p_role TEXT DEFAULT 'worker',
  p_role_level INTEGER DEFAULT 1,
  p_business_unit TEXT DEFAULT 'HQ',
  p_data JSONB DEFAULT '{}',
  p_ttl_hours INTEGER DEFAULT 24
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  v_token TEXT;
BEGIN
  v_token := encode(gen_random_bytes(32), 'hex');
  
  INSERT INTO session_store (token, nrp, role, role_level, business_unit, data, expires_at)
  VALUES (v_token, p_nrp, p_role, p_role_level, p_business_unit, p_data, NOW() + (p_ttl_hours || ' hours')::interval);
  
  RETURN v_token;
END;
$$;

-- Function: Validate session
CREATE OR REPLACE FUNCTION validate_session(p_token TEXT)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_session RECORD;
BEGIN
  SELECT * INTO v_session
  FROM session_store
  WHERE token = p_token AND expires_at > NOW();
  
  IF v_session IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Session expired or invalid');
  END IF;
  
  RETURN jsonb_build_object(
    'ok', true,
    'nrp', v_session.nrp,
    'role', v_session.role,
    'role_level', v_session.role_level,
    'business_unit', v_session.business_unit,
    'data', v_session.data
  );
END;
$$;

-- Function: Delete session (logout)
CREATE OR REPLACE FUNCTION delete_session(p_token TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
  DELETE FROM session_store WHERE token = p_token;
  RETURN true;
END;
$$;

-- Function: Cleanup expired sessions
CREATE OR REPLACE FUNCTION cleanup_expired_sessions()
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  DELETE FROM session_store WHERE expires_at < NOW();
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- ── 5. RATE LIMITING TABLE ──
CREATE TABLE IF NOT EXISTS rate_limits (
  id SERIAL PRIMARY KEY,
  identifier TEXT NOT NULL,  -- IP address or NRP
  action TEXT NOT NULL,       -- 'login', 'otp', 'api_call'
  count INTEGER DEFAULT 1,
  window_start TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rate_limits_lookup 
ON rate_limits (identifier, action, window_start);

-- Function: Check rate limit
CREATE OR REPLACE FUNCTION check_rate_limit(
  p_identifier TEXT,
  p_action TEXT,
  p_max_count INTEGER DEFAULT 10,
  p_window_minutes INTEGER DEFAULT 15
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  -- Count requests in window
  SELECT count(*) INTO v_count
  FROM rate_limits
  WHERE identifier = p_identifier
    AND action = p_action
    AND window_start > NOW() - (p_window_minutes || ' minutes')::interval;
  
  -- Allow if under limit
  IF v_count < p_max_count THEN
    INSERT INTO rate_limits (identifier, action) VALUES (p_identifier, p_action);
    RETURN true;
  END IF;
  
  RETURN false;
END;
$$;

-- Function: Cleanup old rate limits
CREATE OR REPLACE FUNCTION cleanup_rate_limits()
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  DELETE FROM rate_limits WHERE window_start < NOW() - INTERVAL '1 hour';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- ── 6. AUTO-REFRESH MATERIALIZED VIEWS ──
-- Refresh setiap 1 jam via pg_cron (jika tersedia)
-- Atau via Edge Function scheduler

-- pg_cron setup (uncomment jika pg_cron ter-install)
-- SELECT cron.schedule('refresh-mv-admin-summary', '0 * * * *', 'REFRESH MATERIALIZED VIEW CONCURRENTLY mv_admin_summary');
-- SELECT cron.schedule('refresh-mv-team-kpi', '0 * * * *', 'REFRESH MATERIALIZED VIEW CONCURRENTLY mv_team_kpi');
-- SELECT cron.schedule('refresh-mv-attendance', '*/30 * * * *', 'REFRESH MATERIALIZED VIEW CONCURRENTLY mv_attendance_daily');
-- SELECT cron.schedule('cleanup-sessions', '0 2 * * *', 'SELECT cleanup_expired_sessions()');
-- SELECT cron.schedule('cleanup-rate-limits', '0 3 * * *', 'SELECT cleanup_rate_limits()');

-- ── 7. VERIFY ──
SELECT 'MV admin_summary' as view_name, count(*) as rows FROM mv_admin_summary
UNION ALL
SELECT 'MV team_kpi', count(*) FROM mv_team_kpi
UNION ALL
SELECT 'MV flight_risk', count(*) FROM mv_flight_risk;

SELECT 'DONE: Wave B — Connection & Cache complete' as status;
