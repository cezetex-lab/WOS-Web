-- ============================================================
-- 038: FIX ALL RPC ERRORS — Comprehensive
-- Run this ONE file instead of 036 + 037
-- Fixes: GROUP BY, missing functions, column mismatches
-- ============================================================

-- ──────────────────────────────────────────────────────────
-- 1. admin_get_employees (GROUP BY fix)
-- ──────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS admin_get_employees() CASCADE;
CREATE OR REPLACE FUNCTION admin_get_employees()
RETURNS JSONB AS $$
  SELECT COALESCE(jsonb_agg(sub.* ORDER BY sub.nama), '[]'::jsonb)
  FROM (
    SELECT
      e.nrp, e.nik, e.nama, e.email, e.divisi,
      e.posisi AS jabatan,
      e.status_kerja AS status,
      e.status_kerja AS jenis,
      e.no_hp AS phone,
      e.business_unit,
      e.tanggal_masuk,
      CASE WHEN e.status_kerja = 'Aktif' THEN true ELSE false END AS is_active
    FROM employees_master e
  ) sub;
$$ LANGUAGE sql SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────
-- 2. admin_get_employee_stats (missing — create it)
-- ──────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS admin_get_employee_stats() CASCADE;
CREATE OR REPLACE FUNCTION admin_get_employee_stats()
RETURNS JSONB AS $$
  SELECT jsonb_build_object(
    'total', (SELECT COUNT(*) FROM employees_master),
    'active', (SELECT COUNT(*) FROM employees_master WHERE status_kerja = 'Aktif'),
    'pkwt', (SELECT COUNT(*) FROM employees_master WHERE status_kerja ILIKE '%PKWT%'),
    'pkwtt', (SELECT COUNT(*) FROM employees_master WHERE status_kerja ILIKE '%PKWTT%'),
    'expiring_soon', (SELECT COUNT(*) FROM employees_master
      WHERE tanggal_masuk IS NOT NULL
      AND (tanggal_masuk + interval '2 year')::date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '90 days')
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────
-- 3. admin_get_payroll (missing — create it)
-- ──────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS admin_get_payroll(p_period TEXT) CASCADE;
CREATE OR REPLACE FUNCTION admin_get_payroll(p_period TEXT DEFAULT NULL)
RETURNS JSONB AS $$
  SELECT COALESCE(jsonb_agg(sub.* ORDER BY sub.nama), '[]'::jsonb)
  FROM (
    SELECT
      p.nrp, e.nama, e.divisi, p.periode,
      p.base_salary, p.allowance, p.deduction, p.overtime_pay, p.net_salary,
      (p.base_salary + p.allowance + p.overtime_pay) AS gross_salary,
      p.deduction AS total_potongan,
      p.net_salary AS nett_salary,
      e.business_unit,
      'Processed' AS status
    FROM hr_payroll p
    JOIN employees_master e ON e.nrp = p.nrp
    WHERE (p_period IS NULL OR p.periode = p_period)
  ) sub;
$$ LANGUAGE sql SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────
-- 4. admin_get_payroll_summary (missing — create it)
-- ──────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS admin_get_payroll_summary(p_period TEXT) CASCADE;
CREATE OR REPLACE FUNCTION admin_get_payroll_summary(p_period TEXT DEFAULT NULL)
RETURNS JSONB AS $$
  SELECT jsonb_build_object(
    'total_employees', COUNT(*),
    'total_net', COALESCE(SUM(p.net_salary), 0),
    'avg_salary', COALESCE(AVG(p.net_salary), 0),
    'total_gross', COALESCE(SUM(p.base_salary + p.allowance + p.overtime_pay), 0),
    'total_deduction', COALESCE(SUM(p.deduction), 0),
    'total_deduction_items', COUNT(CASE WHEN p.deduction > 0 THEN 1 END)
  )
  FROM hr_payroll p
  WHERE (p_period IS NULL OR p.periode = p_period);
$$ LANGUAGE sql SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────
-- 5. admin_get_leave (missing — create it)
-- ──────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS admin_get_leave() CASCADE;
CREATE OR REPLACE FUNCTION admin_get_leave()
RETURNS JSONB AS $$
  SELECT COALESCE(jsonb_agg(sub.* ORDER BY sub.nama), '[]'::jsonb)
  FROM (
    SELECT
      l.nrp, e.nama, l.tahun,
      l.annual_quota AS kuota,
      l.annual_used AS terpakai,
      (l.annual_quota - l.annual_used) AS sisa
    FROM hr_leave l
    JOIN employees_master e ON e.nrp = l.nrp
    WHERE l.tahun = EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER
  ) sub;
$$ LANGUAGE sql SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────
-- 6. admin_get_summary — FIX column names for frontend
-- ──────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS admin_get_summary() CASCADE;
CREATE OR REPLACE FUNCTION admin_get_summary()
RETURNS JSONB AS $$
  SELECT jsonb_build_object(
    'ok', true,
    'total_employees', (SELECT COUNT(*) FROM employees_master),
    'total_workers', (SELECT COUNT(*) FROM employees_master),
    'total_divisions', (SELECT COUNT(DISTINCT divisi) FROM employees_master WHERE divisi IS NOT NULL),
    'mining_count', (SELECT COUNT(*) FROM employees_master WHERE business_unit = 'MINING'),
    'estate_count', (SELECT COUNT(*) FROM employees_master WHERE business_unit = 'ESTATE'),
    'mill_count', (SELECT COUNT(*) FROM employees_master WHERE business_unit = 'MILL'),
    'hq_count', (SELECT COUNT(*) FROM employees_master WHERE business_unit = 'HQ'),
    'high_performers', (SELECT COUNT(*) FROM hr_performance WHERE kpi_score >= 80),
    'low_performers', (SELECT COUNT(*) FROM hr_performance WHERE kpi_score < 60),
    'pending_requests', (SELECT COUNT(*) FROM hr_requests WHERE status = 'Pending'),
    'pending_registration', (SELECT COUNT(*) FROM daftar_baru WHERE status = 'PENDING'),
    'pkwtt_count', (SELECT COUNT(*) FROM employees_master WHERE status_kerja = 'PKWTT'),
    'pkwt_count', (SELECT COUNT(*) FROM employees_master WHERE status_kerja ILIKE '%PKWT%'),
    'retiring_soon', (SELECT COUNT(*) FROM employees_master
      WHERE status_kerja ILIKE '%PKWT%'
      AND tanggal_masuk IS NOT NULL
      AND (tanggal_masuk + interval '2 year')::date BETWEEN NOW() AND NOW() + interval '6 months'),
    'pkwt_expired', (SELECT COUNT(*) FROM employees_master
      WHERE status_kerja ILIKE '%PKWT%'
      AND tanggal_masuk IS NOT NULL
      AND (tanggal_masuk + interval '2 year')::date < NOW())
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────
-- 7. get_pkwt_expiry_alert — FIX GROUP BY error
-- ──────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS get_pkwt_expiry_alert() CASCADE;
CREATE OR REPLACE FUNCTION get_pkwt_expiry_alert()
RETURNS JSONB AS $$
  SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(sub.*), '[]'::jsonb))
  FROM (
    SELECT
      e.nrp,
      e.nama,
      e.posisi,
      e.divisi,
      e.tanggal_masuk,
      e.status_kerja,
      (e.tanggal_masuk + interval '2 year')::date AS expiry_date,
      EXTRACT(DAY FROM (e.tanggal_masuk + interval '2 year')::timestamp - NOW())::int AS days_remaining,
      CASE
        WHEN (e.tanggal_masuk + interval '2 year')::date < NOW() THEN 'EXPIRED'
        WHEN (e.tanggal_masuk + interval '2 year')::date < NOW() + interval '30 days' THEN 'CRITICAL'
        WHEN (e.tanggal_masuk + interval '2 year')::date < NOW() + interval '90 days' THEN 'WARNING'
        ELSE 'OK'
      END AS risk_level
    FROM employees_master e
    WHERE e.status_kerja ILIKE '%PKWT%'
    AND e.tanggal_masuk IS NOT NULL
    ORDER BY (e.tanggal_masuk + interval '2 year')::date ASC
  ) sub;
$$ LANGUAGE sql SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────
-- 8. get_anomaly_sentinel — FIX column names (hr_ai_tasks schema)
-- ──────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS get_anomaly_sentinel() CASCADE;
CREATE OR REPLACE FUNCTION get_anomaly_sentinel()
RETURNS JSONB AS $$
  SELECT COALESCE(jsonb_build_object('ok', true, 'data', jsonb_agg(sub.*)), jsonb_build_object('ok', true, 'data', '[]'::jsonb))
  FROM (
    SELECT
      a.nrp,
      COALESCE((SELECT nama FROM employees_master WHERE nrp = a.nrp), 'System') AS nama,
      a.task_type AS type,
      COALESCE(a.title, a.details_json, 'No detail') AS detail,
      a.priority AS severity,
      a.created_at
    FROM hr_ai_tasks a
    WHERE a.status = 'PENDING'
    ORDER BY a.created_at DESC
    LIMIT 10
  ) sub;
$$ LANGUAGE sql SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────
-- 9. RLS policies — allow anon read on all tables
-- ──────────────────────────────────────────────────────────

-- employees_master
ALTER TABLE employees_master ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON employees_master;
CREATE POLICY "Allow anon read" ON employees_master FOR SELECT USING (true);
CREATE POLICY "Allow all for service role" ON employees_master FOR ALL USING (true);

-- hr_org
ALTER TABLE hr_org ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_org;
CREATE POLICY "Allow anon read" ON hr_org FOR SELECT USING (true);
CREATE POLICY "Allow all for service role" ON hr_org FOR ALL USING (true);

-- hr_performance
ALTER TABLE hr_performance ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_performance;
CREATE POLICY "Allow anon read" ON hr_performance FOR SELECT USING (true);
CREATE POLICY "Allow all for service role" ON hr_performance FOR ALL USING (true);

-- hr_payroll
ALTER TABLE hr_payroll ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_payroll;
CREATE POLICY "Allow anon read" ON hr_payroll FOR SELECT USING (true);
CREATE POLICY "Allow all for service role" ON hr_payroll FOR ALL USING (true);

-- hr_leave
ALTER TABLE hr_leave ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_leave;
CREATE POLICY "Allow anon read" ON hr_leave FOR SELECT USING (true);
CREATE POLICY "Allow all for service role" ON hr_leave FOR ALL USING (true);

-- hr_requests
ALTER TABLE hr_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_requests;
CREATE POLICY "Allow anon read" ON hr_requests FOR SELECT USING (true);
CREATE POLICY "Allow all for service role" ON hr_requests FOR ALL USING (true);

-- hr_notifications
ALTER TABLE hr_notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_notifications;
CREATE POLICY "Allow anon read" ON hr_notifications FOR SELECT USING (true);
CREATE POLICY "Allow all for service role" ON hr_notifications FOR ALL USING (true);

-- hr_attendance
ALTER TABLE hr_attendance ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_attendance;
CREATE POLICY "Allow anon read" ON hr_attendance FOR SELECT USING (true);
CREATE POLICY "Allow all for service role" ON hr_attendance FOR ALL USING (true);

-- hr_engagement
ALTER TABLE hr_engagement ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_engagement;
CREATE POLICY "Allow anon read" ON hr_engagement FOR SELECT USING (true);
CREATE POLICY "Allow all for service role" ON hr_engagement FOR ALL USING (true);

-- hr_voice
ALTER TABLE hr_voice ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_voice;
CREATE POLICY "Allow anon read" ON hr_voice FOR SELECT USING (true);
CREATE POLICY "Allow all for service role" ON hr_voice FOR ALL USING (true);

-- announcements
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON announcements;
CREATE POLICY "Allow anon read" ON announcements FOR SELECT USING (true);
CREATE POLICY "Allow all for service role" ON announcements FOR ALL USING (true);

-- hr_tasks
ALTER TABLE hr_tasks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_tasks;
CREATE POLICY "Allow all for service role" ON hr_tasks FOR ALL USING (true);

-- user_roles
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON user_roles;
CREATE POLICY "Allow anon read" ON user_roles FOR SELECT USING (true);
CREATE POLICY "Allow all for service role" ON user_roles FOR ALL USING (true);

-- worker_passwords
ALTER TABLE worker_passwords ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON worker_passwords;
CREATE POLICY "Allow all for service role" ON worker_passwords FOR ALL USING (true);

-- otp_store
ALTER TABLE otp_store ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON otp_store;
CREATE POLICY "Allow all for service role" ON otp_store FOR ALL USING (true);

-- otp_attempts
ALTER TABLE otp_attempts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON otp_attempts;
CREATE POLICY "Allow all for service role" ON otp_attempts FOR ALL USING (true);

-- settings
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON settings;
CREATE POLICY "Allow all for service role" ON settings FOR ALL USING (true);

-- daftar_baru
ALTER TABLE daftar_baru ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON daftar_baru;
CREATE POLICY "Allow all for service role" ON daftar_baru FOR ALL USING (true);

-- hr_ai_tasks
ALTER TABLE hr_ai_tasks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_ai_tasks;
CREATE POLICY "Allow anon read" ON hr_ai_tasks FOR SELECT USING (true);
CREATE POLICY "Allow all for service role" ON hr_ai_tasks FOR ALL USING (true);

-- session_tokens
ALTER TABLE session_tokens ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON session_tokens;
CREATE POLICY "Allow all for service role" ON session_tokens FOR ALL USING (true);

-- audit_log
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON audit_log;
CREATE POLICY "Allow all for service role" ON audit_log FOR ALL USING (true);

-- hr_calendar
ALTER TABLE hr_calendar ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_calendar;
CREATE POLICY "Allow all for service role" ON hr_calendar FOR ALL USING (true);

-- hr_shift_master
ALTER TABLE hr_shift_master ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_shift_master;
CREATE POLICY "Allow all for service role" ON hr_shift_master FOR ALL USING (true);

-- hr_work_schedule
ALTER TABLE hr_work_schedule ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_work_schedule;
CREATE POLICY "Allow all for service role" ON hr_work_schedule FOR ALL USING (true);

-- hr_overtime
ALTER TABLE hr_overtime ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_overtime;
CREATE POLICY "Allow all for service role" ON hr_overtime FOR ALL USING (true);

-- hr_production_daily
ALTER TABLE hr_production_daily ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_production_daily;
CREATE POLICY "Allow all for service role" ON hr_production_daily FOR ALL USING (true);

-- hr_plantation_harvest
ALTER TABLE hr_plantation_harvest ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_plantation_harvest;
CREATE POLICY "Allow all for service role" ON hr_plantation_harvest FOR ALL USING (true);

-- hr_equipment_util
ALTER TABLE hr_equipment_util ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_equipment_util;
CREATE POLICY "Allow all for service role" ON hr_equipment_util FOR ALL USING (true);

-- hr_safety
ALTER TABLE hr_safety ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_safety;
CREATE POLICY "Allow all for service role" ON hr_safety FOR ALL USING (true);

-- hr_compliance
ALTER TABLE hr_compliance ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_compliance;
CREATE POLICY "Allow all for service role" ON hr_compliance FOR ALL USING (true);

-- hr_benefits
ALTER TABLE hr_benefits ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_benefits;
CREATE POLICY "Allow all for service role" ON hr_benefits FOR ALL USING (true);

-- hr_capability
ALTER TABLE hr_capability ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_capability;
CREATE POLICY "Allow all for service role" ON hr_capability FOR ALL USING (true);

-- hr_medical_checkup
ALTER TABLE hr_medical_checkup ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_medical_checkup;
CREATE POLICY "Allow all for service role" ON hr_medical_checkup FOR ALL USING (true);

-- hr_exit_clearance
ALTER TABLE hr_exit_clearance ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_exit_clearance;
CREATE POLICY "Allow all for service role" ON hr_exit_clearance FOR ALL USING (true);

-- hr_preview_data
ALTER TABLE hr_preview_data ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_preview_data;
CREATE POLICY "Allow all for service role" ON hr_preview_data FOR ALL USING (true);

-- hr_talent_catalog
ALTER TABLE hr_talent_catalog ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_talent_catalog;
CREATE POLICY "Allow all for service role" ON hr_talent_catalog FOR ALL USING (true);

-- hr_succession
ALTER TABLE hr_succession ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_succession;
CREATE POLICY "Allow all for service role" ON hr_succession FOR ALL USING (true);

-- hr_critical
ALTER TABLE hr_critical ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_critical;
CREATE POLICY "Allow all for service role" ON hr_critical FOR ALL USING (true);

-- hr_coaching
ALTER TABLE hr_coaching ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_coaching;
CREATE POLICY "Allow all for service role" ON hr_coaching FOR ALL USING (true);

-- hr_monthly_snapshot
ALTER TABLE hr_monthly_snapshot ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_monthly_snapshot;
CREATE POLICY "Allow all for service role" ON hr_monthly_snapshot FOR ALL USING (true);

-- simulation_logs
ALTER TABLE simulation_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON simulation_logs;
CREATE POLICY "Allow all for service role" ON simulation_logs FOR ALL USING (true);

-- hr_kpi_config
ALTER TABLE hr_kpi_config ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_kpi_config;
CREATE POLICY "Allow all for service role" ON hr_kpi_config FOR ALL USING (true);

-- hr_kpi_calc_log
ALTER TABLE hr_kpi_calc_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_kpi_calc_log;
CREATE POLICY "Allow all for service role" ON hr_kpi_calc_log FOR ALL USING (true);

-- hr_finance_kpi
ALTER TABLE hr_finance_kpi ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_finance_kpi;
CREATE POLICY "Allow all for service role" ON hr_finance_kpi FOR ALL USING (true);

-- hr_skills
ALTER TABLE hr_skills ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_skills;
CREATE POLICY "Allow all for service role" ON hr_skills FOR ALL USING (true);

-- hr_learning
ALTER TABLE hr_learning ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_learning;
CREATE POLICY "Allow all for service role" ON hr_learning FOR ALL USING (true);

-- ============================================================
SELECT '038_fix_all_rpc_errors.sql applied successfully' as status;
