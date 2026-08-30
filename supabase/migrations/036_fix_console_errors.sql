-- ============================================================
-- 036: Fix all console errors from browser
-- ============================================================

-- ──────────────────────────────────────────────────────────
-- 1. admin_get_employees — missing RPC
-- ──────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS admin_get_employees() CASCADE;
CREATE OR REPLACE FUNCTION admin_get_employees()
RETURNS JSONB AS $$
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'nrp', e.nrp,
      'nik', e.nik,
      'nama', e.nama,
      'email', e.email,
      'divisi', e.divisi,
      'jabatan', e.posisi,
      'status', e.status_kerja,
      'jenis', e.status_kerja,
      'phone', e.no_hp,
      'business_unit', e.business_unit,
      'tanggal_masuk', e.tanggal_masuk,
      'is_active', CASE WHEN e.status_kerja = 'Aktif' THEN true ELSE false END
    )
  ), '[]'::jsonb)
  FROM employees_master e
  ORDER BY e.nama;
$$ LANGUAGE sql SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────
-- 2. admin_get_employee_stats — missing RPC
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
      WHERE tanggal_habis IS NOT NULL
      AND tanggal_habis BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '90 days')
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────
-- 3. admin_get_payroll — missing RPC
-- ──────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS admin_get_payroll(p_period TEXT) CASCADE;
CREATE OR REPLACE FUNCTION admin_get_payroll(p_period TEXT DEFAULT NULL)
RETURNS JSONB AS $$
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'nrp', p.nrp,
      'nama', e.nama,
      'divisi', e.divisi,
      'periode', p.periode,
      'base_salary', p.base_salary,
      'allowance', p.allowance,
      'deduction', p.deduction,
      'overtime_pay', p.overtime_pay,
      'net_salary', p.net_salary,
      'gross_salary', p.base_salary + p.allowance + p.overtime_pay,
      'total_potongan', p.deduction,
      'nett_salary', p.net_salary,
      'business_unit', e.business_unit,
      'status', 'Processed'
    )
  ), '[]'::jsonb)
  FROM hr_payroll p
  JOIN employees_master e ON e.nrp = p.nrp
  WHERE (p_period IS NULL OR p.periode = p_period)
  ORDER BY e.nama;
$$ LANGUAGE sql SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────
-- 4. admin_get_payroll_summary — missing RPC
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
-- 5. admin_get_leave — missing RPC (used by AI copilot)
-- ──────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS admin_get_leave() CASCADE;
CREATE OR REPLACE FUNCTION admin_get_leave()
RETURNS JSONB AS $$
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'nrp', l.nrp,
      'nama', e.nama,
      'tahun', l.tahun,
      'kuota', l.annual_quota,
      'terpakai', l.annual_used,
      'sisa', l.annual_quota - l.annual_used
    )
  ), '[]'::jsonb)
  FROM hr_leave l
  JOIN employees_master e ON e.nrp = l.nrp
  WHERE l.tahun = EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER
  ORDER BY e.nama;
$$ LANGUAGE sql SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────
-- 6. Fix RLS on hr_org — allow anon read (fixes 406 error)
-- ──────────────────────────────────────────────────────────
ALTER TABLE hr_org ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_org;
CREATE POLICY "Allow read for authenticated" ON hr_org FOR SELECT USING (true);
CREATE POLICY "Allow all for service role" ON hr_org FOR ALL USING (true);

-- Also fix RLS on other tables that return 406
ALTER TABLE hr_attendance ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_attendance;
CREATE POLICY "Allow read for authenticated" ON hr_attendance FOR SELECT USING (true);
CREATE POLICY "Allow all for service role" ON hr_attendance FOR ALL USING (true);

ALTER TABLE hr_tasks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_tasks;
CREATE POLICY "Allow all for service role" ON hr_tasks FOR ALL USING (true);

ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON user_roles;
CREATE POLICY "Allow read for authenticated" ON user_roles FOR SELECT USING (true);
CREATE POLICY "Allow all for service role" ON user_roles FOR ALL USING (true);

ALTER TABLE hr_overtime ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_overtime;
CREATE POLICY "Allow all for service role" ON hr_overtime FOR ALL USING (true);

ALTER TABLE hr_learning ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_learning;
CREATE POLICY "Allow all for service role" ON hr_learning FOR ALL USING (true);

ALTER TABLE hr_skills ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_skills;
CREATE POLICY "Allow all for service role" ON hr_skills FOR ALL USING (true);

ALTER TABLE worker_passwords ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON worker_passwords;
CREATE POLICY "Allow all for service role" ON worker_passwords FOR ALL USING (true);

ALTER TABLE otp_store ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON otp_store;
CREATE POLICY "Allow all for service role" ON otp_store FOR ALL USING (true);

ALTER TABLE otp_attempts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON otp_attempts;
CREATE POLICY "Allow all for service role" ON otp_attempts FOR ALL USING (true);

ALTER TABLE settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON settings;
CREATE POLICY "Allow all for service role" ON settings FOR ALL USING (true);

ALTER TABLE daftar_baru ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON daftar_baru;
CREATE POLICY "Allow all for service role" ON daftar_baru FOR ALL USING (true);

ALTER TABLE hr_talent_catalog ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_talent_catalog;
CREATE POLICY "Allow all for service role" ON hr_talent_catalog FOR ALL USING (true);

ALTER TABLE hr_succession ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_succession;
CREATE POLICY "Allow all for service role" ON hr_succession FOR ALL USING (true);

ALTER TABLE hr_critical ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_critical;
CREATE POLICY "Allow all for service role" ON hr_critical FOR ALL USING (true);

ALTER TABLE hr_coaching ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_coaching;
CREATE POLICY "Allow all for service role" ON hr_coaching FOR ALL USING (true);

ALTER TABLE hr_safety ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_safety;
CREATE POLICY "Allow all for service role" ON hr_safety FOR ALL USING (true);

ALTER TABLE hr_compliance ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_compliance;
CREATE POLICY "Allow all for service role" ON hr_compliance FOR ALL USING (true);

ALTER TABLE hr_benefits ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_benefits;
CREATE POLICY "Allow all for service role" ON hr_benefits FOR ALL USING (true);

ALTER TABLE hr_capability ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_capability;
CREATE POLICY "Allow all for service role" ON hr_capability FOR ALL USING (true);

ALTER TABLE hr_medical_checkup ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_medical_checkup;
CREATE POLICY "Allow all for service role" ON hr_medical_checkup FOR ALL USING (true);

ALTER TABLE hr_exit_clearance ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_exit_clearance;
CREATE POLICY "Allow all for service role" ON hr_exit_clearance FOR ALL USING (true);

ALTER TABLE hr_preview_data ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_preview_data;
CREATE POLICY "Allow all for service role" ON hr_preview_data FOR ALL USING (true);

ALTER TABLE hr_ai_tasks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_ai_tasks;
CREATE POLICY "Allow all for service role" ON hr_ai_tasks FOR ALL USING (true);

ALTER TABLE session_tokens ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON session_tokens;
CREATE POLICY "Allow all for service role" ON session_tokens FOR ALL USING (true);

ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON audit_log;
CREATE POLICY "Allow all for service role" ON audit_log FOR ALL USING (true);

ALTER TABLE hr_calendar ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_calendar;
CREATE POLICY "Allow all for service role" ON hr_calendar FOR ALL USING (true);

ALTER TABLE hr_shift_master ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_shift_master;
CREATE POLICY "Allow all for service role" ON hr_shift_master FOR ALL USING (true);

ALTER TABLE hr_work_schedule ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_work_schedule;
CREATE POLICY "Allow all for service role" ON hr_work_schedule FOR ALL USING (true);

ALTER TABLE hr_production_daily ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_production_daily;
CREATE POLICY "Allow all for service role" ON hr_production_daily FOR ALL USING (true);

ALTER TABLE hr_plantation_harvest ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_plantation_harvest;
CREATE POLICY "Allow all for service role" ON hr_plantation_harvest FOR ALL USING (true);

ALTER TABLE hr_equipment_util ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_equipment_util;
CREATE POLICY "Allow all for service role" ON hr_equipment_util FOR ALL USING (true);

ALTER TABLE hr_monthly_snapshot ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON hr_monthly_snapshot;
CREATE POLICY "Allow all for service role" ON hr_monthly_snapshot FOR ALL USING (true);

ALTER TABLE simulation_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON simulation_logs;
CREATE POLICY "Allow all for service role" ON simulation_logs FOR ALL USING (true);

-- ============================================================
-- 7. Allow anon read on employees_master (fixes 406 on direct queries)
-- ============================================================
DROP POLICY IF EXISTS "Allow all for service role" ON employees_master;
CREATE POLICY "Allow anon read" ON employees_master FOR SELECT USING (true);
CREATE POLICY "Allow all for service role" ON employees_master FOR ALL USING (true);

-- Also allow anon read on hr_payroll
DROP POLICY IF EXISTS "Allow all for service role" ON hr_payroll;
CREATE POLICY "Allow anon read" ON hr_payroll FOR SELECT USING (true);
CREATE POLICY "Allow all for service role" ON hr_payroll FOR ALL USING (true);

-- Allow anon read on hr_performance
DROP POLICY IF EXISTS "Allow all for service role" ON hr_performance;
CREATE POLICY "Allow anon read" ON hr_performance FOR SELECT USING (true);
CREATE POLICY "Allow all for service role" ON hr_performance FOR ALL USING (true);

-- Allow anon read on announcements
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for service role" ON announcements;
CREATE POLICY "Allow anon read" ON announcements FOR SELECT USING (true);
CREATE POLICY "Allow all for service role" ON announcements FOR ALL USING (true);

-- Allow anon read on hr_leave
DROP POLICY IF EXISTS "Allow all for service role" ON hr_leave;
CREATE POLICY "Allow anon read" ON hr_leave FOR SELECT USING (true);
CREATE POLICY "Allow all for service role" ON hr_leave FOR ALL USING (true);

-- Allow anon read on hr_requests
DROP POLICY IF EXISTS "Allow all for service role" ON hr_requests;
CREATE POLICY "Allow anon read" ON hr_requests FOR SELECT USING (true);
CREATE POLICY "Allow all for service role" ON hr_requests FOR ALL USING (true);

-- Allow anon on hr_notifications
DROP POLICY IF EXISTS "Allow all for service role" ON hr_notifications;
CREATE POLICY "Allow anon read" ON hr_notifications FOR SELECT USING (true);
CREATE POLICY "Allow all for service role" ON hr_notifications FOR ALL USING (true);

-- Allow anon on hr_engagement
DROP POLICY IF EXISTS "Allow all for service role" ON hr_engagement;
CREATE POLICY "Allow anon read" ON hr_engagement FOR SELECT USING (true);
CREATE POLICY "Allow all for service role" ON hr_engagement FOR ALL USING (true);

-- Allow anon on hr_voice
DROP POLICY IF EXISTS "Allow all for service role" ON hr_voice;
CREATE POLICY "Allow anon read" ON hr_voice FOR SELECT USING (true);
CREATE POLICY "Allow all for service role" ON hr_voice FOR ALL USING (true);

SELECT '036_fix_console_errors.sql applied successfully' as status;
