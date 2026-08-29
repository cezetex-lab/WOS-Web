-- ============================================================
-- WOS-Web: SQL Migration 001
-- Konversi 58 Google Sheets → 58 PostgreSQL Tables
-- Generated from GAS Config.SHEETS
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- 1. CORE HRIS
-- ============================================================

CREATE TABLE employees_master (
  employee_id TEXT PRIMARY KEY,
  nrp TEXT UNIQUE NOT NULL,
  nik TEXT,
  nama TEXT NOT NULL,
  email TEXT,
  divisi TEXT,
  posisi TEXT,
  status_kerja TEXT DEFAULT 'PKWTT',
  tanggal_lahir DATE,
  jenis_kelamin TEXT,
  alamat TEXT,
  no_hp TEXT,
  tanggal_masuk DATE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE user_roles (
  nrp TEXT PRIMARY KEY REFERENCES employees_master(nrp),
  role_level INTEGER DEFAULT 1,
  scope_divisi TEXT
);

CREATE TABLE hr_org (
  nrp TEXT PRIMARY KEY REFERENCES employees_master(nrp),
  atasan_nrp TEXT REFERENCES employees_master(nrp)
);

CREATE TABLE worker_passwords (
  nrp TEXT PRIMARY KEY REFERENCES employees_master(nrp),
  password_hash TEXT NOT NULL,
  salt TEXT NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  attempts INTEGER DEFAULT 0,
  blocked_until TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE daftar_baru (
  id SERIAL PRIMARY KEY,
  nrp TEXT,
  nik TEXT,
  nama TEXT,
  email TEXT,
  divisi TEXT,
  posisi TEXT,
  status_kerja TEXT,
  password_hash TEXT,
  salt TEXT,
  status TEXT DEFAULT 'PENDING',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE idx_nrp (
  nrp TEXT PRIMARY KEY,
  row_index INTEGER
);

CREATE TABLE session_tokens (
  session_token TEXT PRIMARY KEY,
  nrp TEXT NOT NULL,
  type TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE otp_store (
  nrp TEXT PRIMARY KEY,
  code_hash TEXT NOT NULL,
  expiry TIMESTAMPTZ NOT NULL,
  used BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE otp_attempts (
  nrp TEXT PRIMARY KEY,
  attempts INTEGER DEFAULT 0,
  blocked_until TIMESTAMPTZ,
  request_count INTEGER DEFAULT 0,
  request_window_start TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT
);

CREATE TABLE audit_log (
  id SERIAL PRIMARY KEY,
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  actor TEXT,
  action TEXT,
  detail TEXT
);

-- ============================================================
-- 2. PERFORMANCE & LEAVE
-- ============================================================

CREATE TABLE hr_performance (
  id SERIAL PRIMARY KEY,
  nrp TEXT NOT NULL REFERENCES employees_master(nrp),
  periode TEXT NOT NULL,
  kpi_score NUMERIC(5,2),
  feedback_json TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE hr_leave (
  id SERIAL PRIMARY KEY,
  nrp TEXT NOT NULL REFERENCES employees_master(nrp),
  tahun INTEGER NOT NULL,
  kuota_cuti INTEGER DEFAULT 12,
  cuti_terpakai INTEGER DEFAULT 0,
  roster_cycle TEXT,
  annual_quota INTEGER DEFAULT 12,
  annual_used INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE hr_attendance (
  id SERIAL PRIMARY KEY,
  nrp TEXT NOT NULL REFERENCES employees_master(nrp),
  date DATE NOT NULL,
  status_hadir TEXT,
  jam_masuk TIME,
  menit_terlambat INTEGER DEFAULT 0,
  jam_keluar TIME,
  shift TEXT,
  menit_lembur INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 3. FINANCE & KPI
-- ============================================================

CREATE TABLE hr_finance_kpi (
  id SERIAL PRIMARY KEY,
  periode TEXT NOT NULL,
  divisi TEXT NOT NULL,
  total_employee_avg NUMERIC(10,2),
  revenue NUMERIC(15,2),
  profit NUMERIC(15,2),
  opex NUMERIC(15,2),
  total_labor_cost NUMERIC(15,2),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE hr_kpi_config (
  id SERIAL PRIMARY KEY,
  position_code TEXT,
  periode TEXT DEFAULT 'ALL',
  indicator TEXT NOT NULL,
  target_value NUMERIC(10,2),
  uom TEXT,
  weight NUMERIC(5,2),
  formula_type TEXT DEFAULT 'HIGHER',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE hr_kpi_calc_log (
  id SERIAL PRIMARY KEY,
  nrp TEXT REFERENCES employees_master(nrp),
  periode TEXT,
  indicator TEXT,
  realisasi NUMERIC(10,2),
  target NUMERIC(10,2),
  raw_score NUMERIC(5,2),
  final_score NUMERIC(5,2),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 4. REQUESTS & LEARNING
-- ============================================================

CREATE TABLE hr_requests (
  id TEXT PRIMARY KEY,
  nrp TEXT NOT NULL REFERENCES employees_master(nrp),
  type TEXT NOT NULL,
  status TEXT DEFAULT 'PENDING',
  sub_type TEXT,
  details_json TEXT,
  approver_nrp TEXT,
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE hr_learning (
  id SERIAL PRIMARY KEY,
  nrp TEXT REFERENCES employees_master(nrp),
  type TEXT,
  title TEXT,
  status TEXT DEFAULT 'PENDING',
  training_code TEXT,
  start_date DATE,
  end_date DATE,
  score NUMERIC(5,2),
  certificate_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE hr_training_catalog (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  category TEXT,
  provider TEXT,
  duration_hours INTEGER,
  priority TEXT DEFAULT 'NORMAL'
);

-- ============================================================
-- 5. SKILLS & COMPETENCY
-- ============================================================

CREATE TABLE hr_skills (
  id TEXT PRIMARY KEY,
  nrp TEXT NOT NULL REFERENCES employees_master(nrp),
  skill_name TEXT NOT NULL,
  level INTEGER DEFAULT 1,
  target_level INTEGER DEFAULT 3,
  certified BOOLEAN DEFAULT FALSE,
  skill_code TEXT,
  valid_until DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE hr_position_skills (
  id SERIAL PRIMARY KEY,
  position TEXT NOT NULL,
  skill_name TEXT NOT NULL,
  required_level INTEGER DEFAULT 2
);

CREATE TABLE hr_competency_matrix (
  id SERIAL PRIMARY KEY,
  level INTEGER UNIQUE NOT NULL,
  level_name TEXT,
  description TEXT
);

-- ============================================================
-- 6. TALENT & SUCCESSION
-- ============================================================

CREATE TABLE hr_talent_catalog (
  id TEXT PRIMARY KEY,
  type TEXT,
  judul TEXT,
  target_nrp TEXT,
  status TEXT DEFAULT 'ACTIVE',
  priority TEXT DEFAULT 'NORMAL',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE hr_succession (
  id TEXT PRIMARY KEY,
  position TEXT,
  candidate_nrp TEXT REFERENCES employees_master(nrp),
  readiness TEXT DEFAULT 'NOT_READY',
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE hr_succession_matrix (
  id SERIAL PRIMARY KEY,
  readiness_level TEXT UNIQUE NOT NULL,
  description TEXT,
  time_frame TEXT
);

CREATE TABLE hr_critical (
  id SERIAL PRIMARY KEY,
  nrp TEXT REFERENCES employees_master(nrp),
  position TEXT,
  backup_nrp TEXT,
  risk_level TEXT DEFAULT 'LOW',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 7. COACHING & TASKS
-- ============================================================

CREATE TABLE hr_coaching (
  id SERIAL PRIMARY KEY,
  nrp TEXT REFERENCES employees_master(nrp),
  coach_nrp TEXT,
  topic TEXT,
  status TEXT DEFAULT 'SCHEDULED',
  session_date DATE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE hr_coaching_catalog (
  type_code TEXT PRIMARY KEY,
  coaching_type TEXT,
  default_topic TEXT,
  duration_minutes INTEGER DEFAULT 60
);

CREATE TABLE hr_tasks (
  id TEXT PRIMARY KEY,
  assignee_nrp TEXT REFERENCES employees_master(nrp),
  title TEXT NOT NULL,
  status TEXT DEFAULT 'PENDING',
  due_date DATE
);

-- ============================================================
-- 8. AI & ENGAGEMENT
-- ============================================================

CREATE TABLE hr_ai_tasks (
  id TEXT PRIMARY KEY,
  agent_name TEXT,
  task_type TEXT,
  title TEXT,
  status TEXT DEFAULT 'PENDING',
  priority TEXT DEFAULT 'NORMAL',
  details_json TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE hr_engagement (
  id SERIAL PRIMARY KEY,
  nrp TEXT NOT NULL REFERENCES employees_master(nrp),
  score NUMERIC(5,2),
  period TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE hr_voice (
  id TEXT PRIMARY KEY,
  type TEXT,
  nrp TEXT REFERENCES employees_master(nrp),
  title TEXT,
  description TEXT,
  status TEXT DEFAULT 'SUBMITTED',
  votes INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 9. SAFETY & COMPLIANCE
-- ============================================================

CREATE TABLE hr_safety (
  id SERIAL PRIMARY KEY,
  nrp TEXT REFERENCES employees_master(nrp),
  incident_type TEXT,
  date DATE,
  severity TEXT DEFAULT 'LOW',
  description TEXT,
  near_miss BOOLEAN DEFAULT FALSE,
  incident_date DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE hr_compliance (
  id TEXT PRIMARY KEY,
  kategori TEXT,
  status TEXT DEFAULT 'PENDING',
  due_date DATE,
  penanggung_nrp TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE hr_compliance_catalog (
  kode_kategori TEXT PRIMARY KEY,
  kategori TEXT,
  sub_kategori TEXT
);

CREATE TABLE hr_penalty_matrix (
  id SERIAL PRIMARY KEY,
  severity TEXT UNIQUE NOT NULL,
  description TEXT,
  penalty_points INTEGER DEFAULT 0
);

-- ============================================================
-- 10. BENEFITS & PAYROLL
-- ============================================================

CREATE TABLE hr_benefits (
  id TEXT PRIMARY KEY,
  nrp TEXT REFERENCES employees_master(nrp),
  jenis_benefit TEXT,
  nilai NUMERIC(12,2),
  berlaku_mulai DATE,
  berlaku_sampai DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE hr_benefit_catalog (
  kode_benefit TEXT PRIMARY KEY,
  jenis_benefit TEXT,
  kategori TEXT,
  default_nilai NUMERIC(12,2)
);

CREATE TABLE hr_payroll (
  id SERIAL PRIMARY KEY,
  nrp TEXT NOT NULL REFERENCES employees_master(nrp),
  periode TEXT NOT NULL,
  base_salary NUMERIC(15,2),
  allowance NUMERIC(15,2) DEFAULT 0,
  deduction NUMERIC(15,2) DEFAULT 0,
  overtime_pay NUMERIC(15,2) DEFAULT 0,
  net_salary NUMERIC(15,2),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 11. NOTIFICATIONS & ANNOUNCEMENTS
-- ============================================================

CREATE TABLE hr_notifications (
  id TEXT PRIMARY KEY,
  nrp TEXT REFERENCES employees_master(nrp),
  category TEXT,
  title TEXT,
  message TEXT,
  is_read BOOLEAN DEFAULT FALSE,
  link_page TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE announcements (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  message TEXT,
  priority TEXT DEFAULT 'NORMAL',
  target_audience TEXT DEFAULT 'ALL',
  expiry_date DATE,
  created_by TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE hr_document_types (
  type TEXT NOT NULL,
  sub_type TEXT
);

-- ============================================================
-- 12. WORK SCHEDULE
-- ============================================================

CREATE TABLE hr_shift_master (
  shift_code TEXT PRIMARY KEY,
  shift_name TEXT,
  start_time TIME,
  end_time TIME,
  grace_minutes INTEGER DEFAULT 10
);

CREATE TABLE hr_calendar (
  date DATE PRIMARY KEY,
  is_holiday BOOLEAN DEFAULT FALSE,
  description TEXT
);

CREATE TABLE hr_work_schedule (
  divisi_code TEXT PRIMARY KEY,
  work_days_per_week INTEGER DEFAULT 5,
  roster_pattern TEXT
);

CREATE TABLE hr_overtime (
  id TEXT PRIMARY KEY,
  nrp TEXT REFERENCES employees_master(nrp),
  date DATE NOT NULL,
  hours NUMERIC(4,2),
  reason TEXT,
  status TEXT DEFAULT 'PENDING'
);

-- ============================================================
-- 13. PRODUCTION & MINING
-- ============================================================

CREATE TABLE hr_production_daily (
  id SERIAL PRIMARY KEY,
  nrp TEXT REFERENCES employees_master(nrp),
  date DATE NOT NULL,
  shift TEXT,
  machine_id TEXT,
  volume NUMERIC(10,2),
  uom TEXT DEFAULT 'Ton',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE hr_plantation_harvest (
  id SERIAL PRIMARY KEY,
  nrp TEXT REFERENCES employees_master(nrp),
  date DATE NOT NULL,
  block_area TEXT,
  tbs_kg NUMERIC(10,2),
  quality TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE hr_equipment_util (
  id SERIAL PRIMARY KEY,
  machine_id TEXT NOT NULL,
  date DATE NOT NULL,
  shift TEXT,
  fuel_liters NUMERIC(8,2),
  cycle_time_avg NUMERIC(6,2),
  availability_pct NUMERIC(5,2)
);

-- ============================================================
-- 14. EXIT & HEALTH
-- ============================================================

CREATE TABLE hr_exit_clearance (
  id SERIAL PRIMARY KEY,
  nrp TEXT REFERENCES employees_master(nrp),
  resign_date DATE,
  last_work_date DATE,
  clearance_status TEXT DEFAULT 'PENDING',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE hr_medical_checkup (
  id SERIAL PRIMARY KEY,
  nrp TEXT REFERENCES employees_master(nrp),
  checkup_date DATE,
  result TEXT,
  expiry_date DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 15. CAPABILITY & RELATIONS
-- ============================================================

CREATE TABLE hr_capability (
  id SERIAL PRIMARY KEY,
  nrp TEXT REFERENCES employees_master(nrp),
  kompetensi TEXT,
  level_sekarang INTEGER DEFAULT 1,
  level_target INTEGER DEFAULT 3,
  gap NUMERIC(3,1),
  is_mandatory BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE hr_relations (
  id SERIAL PRIMARY KEY,
  nrp TEXT REFERENCES employees_master(nrp),
  type TEXT,
  related_nrp TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE hr_monthly_snapshot (
  id SERIAL PRIMARY KEY,
  periode TEXT NOT NULL,
  divisi TEXT,
  total_headcount INTEGER DEFAULT 0,
  avg_kpi NUMERIC(5,2),
  total_turnover INTEGER DEFAULT 0,
  total_hire INTEGER DEFAULT 0,
  avg_engagement NUMERIC(5,2),
  total_training_hours NUMERIC(8,2),
  total_incidents INTEGER DEFAULT 0,
  total_overtime_hours NUMERIC(8,2),
  total_payroll NUMERIC(15,2),
  total_revenue NUMERIC(15,2),
  total_profit NUMERIC(15,2),
  productivity_index NUMERIC(5,2),
  compliance_rate NUMERIC(5,2),
  retention_rate NUMERIC(5,2),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 16. PREVIEW DATA (untuk tier FREE/MINIMALIS)
-- ============================================================

CREATE TABLE hr_preview_data (
  id SERIAL PRIMARY KEY,
  section TEXT NOT NULL,
  key TEXT NOT NULL,
  value TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(section, key)
);

-- ============================================================
-- 17. SIMULATION LOGS
-- ============================================================

CREATE TABLE simulation_logs (
  id SERIAL PRIMARY KEY,
  action TEXT,
  details TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- INDEXES untuk performance
-- ============================================================

CREATE INDEX idx_attendance_nrp_date ON hr_attendance(nrp, date);
CREATE INDEX idx_performance_nrp_periode ON hr_performance(nrp, periode);
CREATE INDEX idx_leave_nrp_tahun ON hr_leave(nrp, tahun);
CREATE INDEX idx_requests_nrp_status ON hr_requests(nrp, status);
CREATE INDEX idx_skills_nrp ON hr_skills(nrp);
CREATE INDEX idx_production_nrp_date ON hr_production_daily(nrp, date);
CREATE INDEX idx_payroll_nrp_periode ON hr_payroll(nrp, periode);
CREATE INDEX idx_notifications_nrp ON hr_notifications(nrp, is_read);
CREATE INDEX idx_safety_date ON hr_safety(date);
CREATE INDEX idx_overtime_nrp_date ON hr_overtime(nrp, date);
CREATE INDEX idx_hr_benefits_nrp ON hr_benefits(nrp);
CREATE INDEX idx_hr_learning_nrp ON hr_learning(nrp);
CREATE INDEX idx_hr_engagement_nrp ON hr_engagement(nrp);
CREATE INDEX idx_hr_capability_nrp ON hr_capability(nrp);
CREATE INDEX idx_audit_log_timestamp ON audit_log(timestamp);
CREATE INDEX idx_session_tokens_expires ON session_tokens(expires_at);
CREATE INDEX idx_hr_preview_data_section ON hr_preview_data(section);

-- ============================================================
-- ROW LEVEL SECURITY (RLS) — Supabase Auth
-- ============================================================

ALTER TABLE employees_master ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr_performance ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr_leave ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr_payroll ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr_engagement ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr_voice ENABLE ROW LEVEL SECURITY;

-- Basic policies (akan di-upgrade saat port auth)
CREATE POLICY "Allow all for service role" ON employees_master FOR ALL USING (true);
CREATE POLICY "Allow all for service role" ON hr_performance FOR ALL USING (true);
CREATE POLICY "Allow all for service role" ON hr_leave FOR ALL USING (true);
CREATE POLICY "Allow all for service role" ON hr_requests FOR ALL USING (true);
CREATE POLICY "Allow all for service role" ON hr_payroll FOR ALL USING (true);
CREATE POLICY "Allow all for service role" ON hr_notifications FOR ALL USING (true);
CREATE POLICY "Allow all for service role" ON hr_engagement FOR ALL USING (true);
CREATE POLICY "Allow all for service role" ON hr_voice FOR ALL USING (true);
