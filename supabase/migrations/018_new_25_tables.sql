-- ============================================================
-- 018_new_25_tables.sql — 25 Tabel Baru insightWOS v3.0
-- Run AFTER 001_init.sql + CLEAN.sql + 017_otp_functions.sql
-- ============================================================

-- ============================================================
-- 0. ADD business_unit KE employees_master
-- ============================================================
ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS business_unit TEXT DEFAULT 'HQ';
ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS contract_end_date DATE;
UPDATE employees_master SET business_unit = 'HQ' WHERE business_unit IS NULL;

-- ============================================================
-- A. REKRUTMEN & ONBOARDING (tambahan)
-- ============================================================

CREATE TABLE IF NOT EXISTS vacancies (
  id TEXT PRIMARY KEY,
  position TEXT NOT NULL,
  department TEXT,
  quota INTEGER DEFAULT 1,
  qualifications TEXT,
  status TEXT DEFAULT 'OPEN',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS candidate_pipeline (
  id TEXT PRIMARY KEY,
  vacancy_id TEXT REFERENCES vacancies(id),
  nrp TEXT,
  nama TEXT,
  email TEXT,
  stage TEXT DEFAULT 'APPLIED',
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS onboarding_tasks (
  id SERIAL PRIMARY KEY,
  nrp TEXT REFERENCES employees_master(nrp),
  task_name TEXT NOT NULL,
  assigned_to TEXT,
  status TEXT DEFAULT 'PENDING',
  due_date DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- B. DATA KARYAWAN (tambahan)
-- ============================================================

CREATE TABLE IF NOT EXISTS employee_mutations (
  id SERIAL PRIMARY KEY,
  nrp TEXT REFERENCES employees_master(nrp),
  from_position TEXT,
  to_position TEXT,
  effective_date DATE,
  reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- C. SELF-SERVICE (tambahan)
-- ============================================================

CREATE TABLE IF NOT EXISTS approval_config (
  id SERIAL PRIMARY KEY,
  request_type TEXT NOT NULL,
  min_days INTEGER DEFAULT 0,
  required_approvers INTEGER DEFAULT 1,
  required_level INTEGER DEFAULT 2,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS approval_instances (
  id TEXT PRIMARY KEY,
  request_id TEXT,
  approver_nrp TEXT,
  level INTEGER DEFAULT 1,
  status TEXT DEFAULT 'PENDING',
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS travel_requests (
  id TEXT PRIMARY KEY,
  nrp TEXT REFERENCES employees_master(nrp),
  destination TEXT,
  purpose TEXT,
  start_date DATE,
  end_date DATE,
  estimated_cost NUMERIC(12,2),
  status TEXT DEFAULT 'PENDING',
  per_diem NUMERIC(12,2) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS reimbursements (
  id TEXT PRIMARY KEY,
  nrp TEXT REFERENCES employees_master(nrp),
  travel_id TEXT REFERENCES travel_requests(id),
  category TEXT,
  amount NUMERIC(12,2),
  receipt_url TEXT,
  status TEXT DEFAULT 'PENDING',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- D. KINERJA & KOMPENSASI (tambahan)
-- ============================================================

CREATE TABLE IF NOT EXISTS performance_notes (
  id SERIAL PRIMARY KEY,
  nrp TEXT REFERENCES employees_master(nrp),
  author_nrp TEXT,
  note_type TEXT DEFAULT 'FEEDBACK',
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS review_360 (
  id SERIAL PRIMARY KEY,
  reviewee_nrp TEXT REFERENCES employees_master(nrp),
  reviewer_nrp TEXT REFERENCES employees_master(nrp),
  period TEXT,
  category TEXT,
  score NUMERIC(3,1),
  feedback TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS okrs (
  id TEXT PRIMARY KEY,
  nrp TEXT REFERENCES employees_master(nrp),
  period TEXT,
  objective TEXT NOT NULL,
  key_result TEXT,
  target_value NUMERIC(10,2),
  actual_value NUMERIC(10,2) DEFAULT 0,
  status TEXT DEFAULT 'ACTIVE',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS incentives (
  id TEXT PRIMARY KEY,
  nrp TEXT REFERENCES employees_master(nrp),
  period TEXT,
  base_amount NUMERIC(15,2),
  kpi_factor NUMERIC(5,2),
  team_factor NUMERIC(5,2),
  final_amount NUMERIC(15,2),
  status TEXT DEFAULT 'CALCULATED',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS salary_adjustments (
  id TEXT PRIMARY KEY,
  nrp TEXT REFERENCES employees_master(nrp),
  current_salary NUMERIC(15,2),
  recommended_salary NUMERIC(15,2),
  increase_pct NUMERIC(5,2),
  reason TEXT,
  status TEXT DEFAULT 'PENDING',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- E. TALENT & SERTIFIKASI
-- ============================================================

CREATE TABLE IF NOT EXISTS certifications (
  id TEXT PRIMARY KEY,
  nrp TEXT REFERENCES employees_master(nrp),
  cert_name TEXT NOT NULL,
  issuer TEXT,
  issue_date DATE,
  expiry_date DATE,
  status TEXT DEFAULT 'ACTIVE',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS badges (
  id TEXT PRIMARY KEY,
  nrp TEXT REFERENCES employees_master(nrp),
  badge_name TEXT NOT NULL,
  badge_type TEXT,
  points INTEGER DEFAULT 0,
  awarded_date DATE DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- F. ENGAGEMENT & SURVEI
-- ============================================================

CREATE TABLE IF NOT EXISTS surveys (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  survey_type TEXT DEFAULT 'ENPS',
  status TEXT DEFAULT 'ACTIVE',
  target_audience TEXT DEFAULT 'ALL',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS survey_responses (
  id SERIAL PRIMARY KEY,
  survey_id TEXT REFERENCES surveys(id),
  nrp TEXT REFERENCES employees_master(nrp),
  score INTEGER,
  response_json TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS whistleblowers (
  id TEXT PRIMARY KEY,
  category TEXT,
  description TEXT NOT NULL,
  status TEXT DEFAULT 'SUBMITTED',
  investigator_nrp TEXT,
  resolution_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- G. MANAJEMEN TIM & OPERASIONAL
-- ============================================================

CREATE TABLE IF NOT EXISTS timesheets (
  id SERIAL PRIMARY KEY,
  nrp TEXT REFERENCES employees_master(nrp),
  work_date DATE NOT NULL,
  clock_in TIME,
  clock_out TIME,
  total_hours NUMERIC(5,2),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS shift_swaps (
  id TEXT PRIMARY KEY,
  requester_nrp TEXT REFERENCES employees_master(nrp),
  target_nrp TEXT REFERENCES employees_master(nrp),
  swap_date DATE,
  requester_shift TEXT,
  target_shift TEXT,
  status TEXT DEFAULT 'PENDING',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS team_budgets (
  id SERIAL PRIMARY KEY,
  manager_nrp TEXT REFERENCES employees_master(nrp),
  year INTEGER,
  training_budget NUMERIC(15,2) DEFAULT 0,
  operational_budget NUMERIC(15,2) DEFAULT 0,
  training_used NUMERIC(15,2) DEFAULT 0,
  operational_used NUMERIC(15,2) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- H. EKSEKUTIF
-- ============================================================

CREATE TABLE IF NOT EXISTS simulations (
  id TEXT PRIMARY KEY,
  scenario_name TEXT,
  params_json TEXT,
  result_json TEXT,
  created_by TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- I. INTEGRASI
-- ============================================================

CREATE TABLE IF NOT EXISTS webhook_logs (
  id SERIAL PRIMARY KEY,
  event_type TEXT,
  payload TEXT,
  target_url TEXT,
  status TEXT DEFAULT 'PENDING',
  response_code INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- J. KEAMANAN & KEPATUHAN (tambahan)
-- ============================================================

CREATE TABLE IF NOT EXISTS feature_flags (
  name TEXT PRIMARY KEY,
  enabled BOOLEAN DEFAULT TRUE,
  description TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS audit_chain (
  id SERIAL PRIMARY KEY,
  prev_hash TEXT,
  log_hash TEXT,
  actor TEXT,
  action TEXT,
  detail TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS disciplinary_records (
  id TEXT PRIMARY KEY,
  nrp TEXT REFERENCES employees_master(nrp),
  sp_level TEXT DEFAULT 'SP1',
  reason TEXT,
  issued_date DATE,
  issued_by TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- K. PERENCANAAN
-- ============================================================

CREATE TABLE IF NOT EXISTS headcount_plans (
  id SERIAL PRIMARY KEY,
  divisi TEXT,
  year INTEGER,
  quarter INTEGER,
  planned_hc INTEGER DEFAULT 0,
  actual_hc INTEGER DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS budget_allocation (
  id SERIAL PRIMARY KEY,
  divisi TEXT,
  year INTEGER,
  gaji_budget NUMERIC(15,2) DEFAULT 0,
  training_budget NUMERIC(15,2) DEFAULT 0,
  operational_budget NUMERIC(15,2) DEFAULT 0,
  actual_gaji NUMERIC(15,2) DEFAULT 0,
  actual_training NUMERIC(15,2) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- M. ASET & FASILITAS
-- ============================================================

CREATE TABLE IF NOT EXISTS assets (
  id TEXT PRIMARY KEY,
  asset_name TEXT NOT NULL,
  category TEXT,
  serial_number TEXT,
  location TEXT,
  status TEXT DEFAULT 'AVAILABLE',
  assigned_to TEXT REFERENCES employees_master(nrp),
  purchase_date DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS asset_assignments (
  id SERIAL PRIMARY KEY,
  asset_id TEXT REFERENCES assets(id),
  nrp TEXT REFERENCES employees_master(nrp),
  checkout_date DATE,
  checkin_date DATE,
  condition_out TEXT DEFAULT 'GOOD',
  condition_in TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS estate_blocks (
  id TEXT PRIMARY KEY,
  block_name TEXT NOT NULL,
  area_hectare NUMERIC(10,2),
  terrain TEXT,
  division TEXT,
  status TEXT DEFAULT 'ACTIVE',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS facility_requests (
  id TEXT PRIMARY KEY,
  nrp TEXT REFERENCES employees_master(nrp),
  facility_type TEXT,
  description TEXT,
  priority TEXT DEFAULT 'NORMAL',
  status TEXT DEFAULT 'PENDING',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- N. OFFBOARDING
-- ============================================================

CREATE TABLE IF NOT EXISTS exit_interviews (
  id TEXT PRIMARY KEY,
  nrp TEXT REFERENCES employees_master(nrp),
  satisfaction_score INTEGER,
  reason TEXT,
  feedback TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS final_settlements (
  id TEXT PRIMARY KEY,
  nrp TEXT REFERENCES employees_master(nrp),
  sisa_cuti_paid NUMERIC(15,2) DEFAULT 0,
  thr_prorata NUMERIC(15,2) DEFAULT 0,
  pesangon NUMERIC(15,2) DEFAULT 0,
  total_settlement NUMERIC(15,2) DEFAULT 0,
  status TEXT DEFAULT 'CALCULATED',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS offboarding_checklist (
  id SERIAL PRIMARY KEY,
  nrp TEXT REFERENCES employees_master(nrp),
  item_name TEXT NOT NULL,
  status TEXT DEFAULT 'PENDING',
  checked_by TEXT,
  checked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS referrals (
  id TEXT PRIMARY KEY,
  referrer_nrp TEXT REFERENCES employees_master(nrp),
  candidate_name TEXT,
  candidate_email TEXT,
  position TEXT,
  status TEXT DEFAULT 'SUBMITTED',
  bonus_paid BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- O. PLATFORM
-- ============================================================

CREATE TABLE IF NOT EXISTS sites (
  id TEXT PRIMARY KEY,
  site_name TEXT NOT NULL,
  location TEXT,
  business_unit TEXT,
  latitude NUMERIC(10,7),
  longitude NUMERIC(10,7),
  radius_meters INTEGER DEFAULT 100,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS business_units (
  id TEXT PRIMARY KEY,
  unit_code TEXT UNIQUE NOT NULL,
  unit_name TEXT NOT NULL,
  description TEXT,
  is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS legal_documents (
  id TEXT PRIMARY KEY,
  doc_type TEXT,
  title TEXT,
  file_url TEXT,
  status TEXT DEFAULT 'DRAFT',
  signed_by TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS corporate_licenses (
  id TEXT PRIMARY KEY,
  license_name TEXT NOT NULL,
  license_number TEXT,
  issuer TEXT,
  issue_date DATE,
  expiry_date DATE,
  status TEXT DEFAULT 'ACTIVE',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_vacancies_status ON vacancies(status);
CREATE INDEX IF NOT EXISTS idx_candidate_pipeline_vacancy ON candidate_pipeline(vacancy_id);
CREATE INDEX IF NOT EXISTS idx_onboarding_tasks_nrp ON onboarding_tasks(nrp);
CREATE INDEX IF NOT EXISTS idx_employee_mutations_nrp ON employee_mutations(nrp);
CREATE INDEX IF NOT EXISTS idx_travel_requests_nrp ON travel_requests(nrp);
CREATE INDEX IF NOT EXISTS idx_reimbursements_nrp ON reimbursements(nrp);
CREATE INDEX IF NOT EXISTS idx_performance_notes_nrp ON performance_notes(nrp);
CREATE INDEX IF NOT EXISTS idx_review_360_reviewee ON review_360(reviewee_nrp);
CREATE INDEX IF NOT EXISTS idx_okrs_nrp ON okrs(nrp);
CREATE INDEX IF NOT EXISTS idx_incentives_nrp ON incentives(nrp);
CREATE INDEX IF NOT EXISTS idx_certifications_nrp ON certifications(nrp);
CREATE INDEX IF NOT EXISTS idx_certifications_expiry ON certifications(expiry_date);
CREATE INDEX IF NOT EXISTS idx_badges_nrp ON badges(nrp);
CREATE INDEX IF NOT EXISTS idx_survey_responses_survey ON survey_responses(survey_id);
CREATE INDEX IF NOT EXISTS idx_timesheets_nrp_date ON timesheets(nrp, work_date);
CREATE INDEX IF NOT EXISTS idx_shift_swaps_date ON shift_swaps(swap_date);
CREATE INDEX IF NOT EXISTS idx_assets_status ON assets(status);
CREATE INDEX IF NOT EXISTS idx_assets_category ON assets(category);
CREATE INDEX IF NOT EXISTS idx_asset_assignments_asset ON asset_assignments(asset_id);
CREATE INDEX IF NOT EXISTS idx_estate_blocks_division ON estate_blocks(division);
CREATE INDEX IF NOT EXISTS idx_facility_requests_nrp ON facility_requests(nrp);
CREATE INDEX IF NOT EXISTS idx_exit_interviews_nrp ON exit_interviews(nrp);
CREATE INDEX IF NOT EXISTS idx_final_settlements_nrp ON final_settlements(nrp);
CREATE INDEX IF NOT EXISTS idx_disciplinary_records_nrp ON disciplinary_records(nrp);
CREATE INDEX IF NOT EXISTS idx_headcount_plans_divisi ON headcount_plans(divisi);
CREATE INDEX IF NOT EXISTS idx_budget_allocation_divisi ON budget_allocation(divisi);
CREATE INDEX IF NOT EXISTS idx_referrals_nrp ON referrals(referrer_nrp);
CREATE INDEX IF NOT EXISTS idx_audit_chain_hash ON audit_chain(log_hash);
CREATE INDEX IF NOT EXISTS idx_whistleblowers_status ON whistleblowers(status);

-- ============================================================
-- RLS (basic service role policies)
-- ============================================================

ALTER TABLE vacancies ENABLE ROW LEVEL SECURITY;
ALTER TABLE assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE certifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE okrs ENABLE ROW LEVEL SECURITY;
ALTER TABLE timesheets ENABLE ROW LEVEL SECURITY;
ALTER TABLE surveys ENABLE ROW LEVEL SECURITY;
ALTER TABLE whistleblowers ENABLE ROW LEVEL SECURITY;
ALTER TABLE estate_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE feature_flags ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='Allow all for service role' AND tablename='vacancies') THEN CREATE POLICY "Allow all for service role" ON vacancies FOR ALL USING (true); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='Allow all for service role' AND tablename='assets') THEN CREATE POLICY "Allow all for service role" ON assets FOR ALL USING (true); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='Allow all for service role' AND tablename='certifications') THEN CREATE POLICY "Allow all for service role" ON certifications FOR ALL USING (true); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='Allow all for service role' AND tablename='okrs') THEN CREATE POLICY "Allow all for service role" ON okrs FOR ALL USING (true); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='Allow all for service role' AND tablename='timesheets') THEN CREATE POLICY "Allow all for service role" ON timesheets FOR ALL USING (true); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='Allow all for service role' AND tablename='surveys') THEN CREATE POLICY "Allow all for service role" ON surveys FOR ALL USING (true); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='Allow all for service role' AND tablename='whistleblowers') THEN CREATE POLICY "Allow all for service role" ON whistleblowers FOR ALL USING (true); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='Allow all for service role' AND tablename='estate_blocks') THEN CREATE POLICY "Allow all for service role" ON estate_blocks FOR ALL USING (true); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='Allow all for service role' AND tablename='feature_flags') THEN CREATE POLICY "Allow all for service role" ON feature_flags FOR ALL USING (true); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- ============================================================
-- SEED DATA — 25 NEW TABLES
-- ============================================================

-- business_units
INSERT INTO business_units (id, unit_code, unit_name, description) VALUES
('BU01','MINING','Tambang','Operasional Pertambangan'),
('BU02','ESTATE','Kebun','Perkebunan Sawit'),
('BU03','MILL','Pabrik','Pabrik Kelapa Sawit (PKS)'),
('BU04','HQ','Korporat','Kantor Pusat') ON CONFLICT DO NOTHING;

-- sites
INSERT INTO sites (id, site_name, location, business_unit) VALUES
('S01','Site Utama Tambang','Kalimantan Selatan','MINING'),
('S02','Kebun Blok A','Kalimantan Tengah','ESTATE'),
('S03','PKS Unit 1','Sumatera Selatan','MILL'),
('S04','Kantor Pusat','Jakarta','HQ') ON CONFLICT DO NOTHING;

-- vacancies
INSERT INTO vacancies (id, position, department, quota, qualifications, status) VALUES
('VAC001','Staff IT','IT',2,'D3/S1 Teknik Informatika','OPEN'),
('VAC002','Supervisor Operasional','OPERATIONAL',1,'S1 + 3yr exp','OPEN'),
('VAC003','Operator Alat Berat','MINING',3,'SIMPER + K3','CLOSED') ON CONFLICT DO NOTHING;

-- certifications
INSERT INTO certifications (id, nrp, cert_name, issuer, issue_date, expiry_date, status) VALUES
('CERT001','NRP001','K3 Umum','Disnaker','2025-01-15','2027-01-15','ACTIVE'),
('CERT002','NRP005','SIMPER A','Disnaker','2025-06-01','2028-06-01','ACTIVE'),
('CERT003','NRP008','First Aid','Red Cross','2025-03-10','2026-03-10','EXPIRED'),
('CERT004','NRP020','SIO Boiler','Disnaker','2024-12-01','2026-12-01','ACTIVE') ON CONFLICT DO NOTHING;

-- badges
INSERT INTO badges (id, nrp, badge_name, badge_type, points) VALUES
('BDG001','NRP001','Top Performer','KPI',2),
('BDG002','NRP005','Safety Champion','SAFETY',3),
('BDG003','NRP010','Idea Pioneer','ENGAGEMENT',3),
('BDG004','NRP026','Quick Learner','TRAINING',1) ON CONFLICT DO NOTHING;

-- surveys
INSERT INTO surveys (id, title, description, survey_type, status) VALUES
('SRV001','eNPS Q3 2026','Survei kepuasan karyawan kuartal 3','ENPS','ACTIVE'),
('SRV002','Pulse Survey Safety','Survei keselamatan kerja','PULSE','ACTIVE') ON CONFLICT DO NOTHING;

-- survey_responses
INSERT INTO survey_responses (survey_id, nrp, score, response_json)
SELECT 'SRV001', e.nrp, (5+random()*5)::int, '{"q1":"Baik","q2":"Lingkungan positif"}'
FROM employees_master e WHERE random()<0.5 ON CONFLICT DO NOTHING;

-- feature_flags
INSERT INTO feature_flags (name, enabled, description) VALUES
('DARK_MODE',true,'Toggle dark/light theme'),
('NOTIFICATIONS',true,'Push notifications'),
('OTP_LOGIN',true,'OTP 2FA login'),
('ANALYTICS_ADVANCED',false,'Advanced analytics (Phase 6)'),
('AI_COPILOT',false,'AI Copilot chat') ON CONFLICT DO NOTHING;

-- estate_blocks
INSERT INTO estate_blocks (id, block_name, area_hectare, terrain, division, status) VALUES
('BLK001','Blok A1',50.5,'Dataran Rendah','OPERATIONAL','ACTIVE'),
('BLK002','Blok B2',35.2,'Bukit','OPERATIONAL','ACTIVE'),
('BLK003','Blok C1',42.0,'Pegunungan','OPERATIONAL','MAINTENANCE') ON CONFLICT DO NOTHING;

-- assets
INSERT INTO assets (id, asset_name, category, serial_number, location, status) VALUES
('AST001','Excavator CAT 320D','HEAVY_EQUIPMENT','CAT-320D-001','Site Tambang','ASSIGNED'),
('AST002','Dump Truck Hino 500','VEHICLE','HINO-500-003','Site Tambang','AVAILABLE'),
('AST003','Laptop ThinkPad X1','IT','LEN-X1-012','Kantor Pusat','ASSIGNED'),
('AST004','GPS Garmin Montana','GPS','GPS-MT-007','Kebun Blok A','AVAILABLE'),
('AST005','Chain Saw Stihl MS382','TOOL','STIH-382-015','Kebun Blok B','MAINTENANCE') ON CONFLICT DO NOTHING;

-- team_budgets
INSERT INTO team_budgets (manager_nrp, year, training_budget, operational_budget, training_used, operational_used) VALUES
('NRP002',2026,50000000,30000000,15000000,8000000),
('NRP004',2026,80000000,50000000,25000000,12000000) ON CONFLICT DO NOTHING;

-- headcount_plans
INSERT INTO headcount_plans (divisi, year, quarter, planned_hc, actual_hc) VALUES
('HRD',2026,1,8,8),('HRD',2026,2,9,8),('HRD',2026,3,9,8),('HRD',2026,4,10,0),
('FINANCE',2026,1,6,6),('FINANCE',2026,2,6,6),('FINANCE',2026,3,7,6),('FINANCE',2026,4,7,0),
('OPERATIONAL',2026,1,12,12),('OPERATIONAL',2026,2,14,13),('OPERATIONAL',2026,3,15,13),('OPERATIONAL',2026,4,16,0),
('IT',2026,1,4,4),('IT',2026,2,5,4),('IT',2026,3,5,4),('IT',2026,4,6,0) ON CONFLICT DO NOTHING;

-- budget_allocation
INSERT INTO budget_allocation (divisi, year, gaji_budget, training_budget, operational_budget, actual_gaji, actual_training) VALUES
('HRD',2026,1200000000,50000000,30000000,600000000,25000000),
('FINANCE',2026,900000000,30000000,20000000,450000000,15000000),
('OPERATIONAL',2026,2400000000,80000000,50000000,1200000000,40000000),
('IT',2026,720000000,60000000,40000000,360000000,30000000) ON CONFLICT DO NOTHING;

-- disciplinary_records
INSERT INTO disciplinary_records (id, nrp, sp_level, reason, issued_date, issued_by) VALUES
('DISC001','NRP020','SP1','Keterlambatan berulang','2026-06-15','NRP002'),
('DISC002','NRP021','SP1','Absensi tanpa keterangan','2026-07-01','NRP002') ON CONFLICT DO NOTHING;

-- corporate_licenses
INSERT INTO corporate_licenses (id, license_name, license_number, issuer, issue_date, expiry_date, status) VALUES
('LIC001','Izin Usaha Pertambangan','IUP-2025-001','Kementerian ESDM','2025-01-01','2030-01-01','ACTIVE'),
('LIC002','AMDAL','AMDAL-2024-005','Kementerian LHK','2024-06-01','2029-06-01','ACTIVE'),
('LIC003','SIUP','SIUP-2023-012','Kemendag','2023-03-15','2028-03-15','ACTIVE') ON CONFLICT DO NOTHING;

-- approval_config
INSERT INTO approval_config (request_type, min_days, required_approvers, required_level) VALUES
('CUTI',3,2,2),('CUTI',0,1,2),('LEMBUR',0,1,2),('TRAVEL',0,2,3),
('TRAINING',0,1,2),('TRAINING_BUDGET',0,2,4) ON CONFLICT DO NOTHING;

-- approval_config: default
INSERT INTO approval_config (request_type, min_days, required_approvers, required_level) VALUES
('IZIN',0,1,2),('SAKIT',0,1,2) ON CONFLICT DO NOTHING;
