-- ============================================================
-- 027_seed_remaining_tables.sql
-- Seed data untuk 17 tables yang belum ada data
-- Run in Supabase SQL Editor
-- Uses existing employees_master data (NRP001-NRP030)
-- ============================================================

-- ============================================================
-- 1. hr_finance_kpi (P1) — Revenue, profit, opex per divisi
-- ============================================================
INSERT INTO hr_finance_kpi (periode, divisi, total_employee_avg, revenue, profit, opex, total_labor_cost)
SELECT '2026-07', d.divisi, d.hc,
  CASE
    WHEN d.divisi = 'OPERATIONAL' THEN 850000000 + (random()*150000000)::int
    WHEN d.divisi = 'FINANCE' THEN 120000000 + (random()*30000000)::int
    WHEN d.divisi = 'HRD' THEN 80000000 + (random()*20000000)::int
    WHEN d.divisi = 'IT' THEN 95000000 + (random()*25000000)::int
    ELSE 50000000 + (random()*20000000)::int
  END,
  CASE
    WHEN d.divisi = 'OPERATIONAL' THEN 250000000 + (random()*80000000)::int
    WHEN d.divisi = 'FINANCE' THEN 35000000 + (random()*15000000)::int
    ELSE 15000000 + (random()*10000000)::int
  END,
  CASE
    WHEN d.divisi = 'OPERATIONAL' THEN 400000000 + (random()*100000000)::int
    WHEN d.divisi = 'FINANCE' THEN 60000000 + (random()*15000000)::int
    ELSE 40000000 + (random()*10000000)::int
  END,
  d.hc * (CASE
    WHEN d.divisi = 'OPERATIONAL' THEN 8000000
    WHEN d.divisi = 'FINANCE' THEN 12000000
    WHEN d.divisi = 'HRD' THEN 10000000
    WHEN d.divisi = 'IT' THEN 11000000
    ELSE 7500000
  END)
FROM (SELECT divisi, COUNT(*) as hc FROM employees_master WHERE divisi IS NOT NULL GROUP BY divisi) d
ON CONFLICT DO NOTHING;

-- Period 2026-06
INSERT INTO hr_finance_kpi (periode, divisi, total_employee_avg, revenue, profit, opex, total_labor_cost)
SELECT '2026-06', d.divisi, d.hc,
  CASE
    WHEN d.divisi = 'OPERATIONAL' THEN 820000000 + (random()*140000000)::int
    WHEN d.divisi = 'FINANCE' THEN 115000000 + (random()*28000000)::int
    ELSE 48000000 + (random()*18000000)::int
  END,
  CASE
    WHEN d.divisi = 'OPERATIONAL' THEN 230000000 + (random()*70000000)::int
    WHEN d.divisi = 'FINANCE' THEN 32000000 + (random()*12000000)::int
    ELSE 12000000 + (random()*8000000)::int
  END,
  CASE
    WHEN d.divisi = 'OPERATIONAL' THEN 390000000 + (random()*95000000)::int
    WHEN d.divisi = 'FINANCE' THEN 55000000 + (random()*12000000)::int
    ELSE 38000000 + (random()*9000000)::int
  END,
  d.hc * (7000000 + (random()*5000000)::int)
FROM (SELECT divisi, COUNT(*) as hc FROM employees_master WHERE divisi IS NOT NULL GROUP BY divisi) d
ON CONFLICT DO NOTHING;

-- ============================================================
-- 2. hr_kpi_config (P1) — KPI indicators & targets
-- ============================================================
INSERT INTO hr_kpi_config (position_code, periode, indicator, target_value, uom, weight, formula_type) VALUES
('ALL', '2026-07', 'Kehadiran', 95, '%', 20, 'HIGHER'),
('ALL', '2026-07', 'KPI Score', 75, 'score', 30, 'HIGHER'),
('ALL', '2026-07', 'Training Completion', 80, '%', 15, 'HIGHER'),
('ALL', '2026-07', 'Safety Compliance', 100, '%', 15, 'HIGHER'),
('ALL', '2026-07', 'Productivity Index', 85, '%', 20, 'HIGHER'),
('OPR', '2026-07', 'Output Volume', 5000, 'Ton', 25, 'HIGHER'),
('OPR', '2026-07', 'Machine Availability', 90, '%', 25, 'HIGHER'),
('OPR', '2026-07', 'Safety Incidents', 0, 'count', 25, 'LOWER'),
('OPR', '2026-07', 'Overtime Hours', 20, 'hours', 25, 'LOWER'),
('FIN', '2026-07', 'Budget Accuracy', 95, '%', 30, 'HIGHER'),
('FIN', '2026-07', 'Cost Reduction', 5, '%', 30, 'HIGHER'),
('FIN', '2026-07', 'Invoice Processing Time', 3, 'days', 20, 'LOWER'),
('FIN', '2026-07', 'Compliance Score', 90, '%', 20, 'HIGHER'),
('IT', '2026-07', 'System Uptime', 99, '%', 30, 'HIGHER'),
('IT', '2026-07', 'Ticket Resolution', 90, '%', 25, 'HIGHER'),
('IT', '2026-07', 'Project Delivery', 85, '%', 25, 'HIGHER'),
('IT', '2026-07', 'Security Score', 95, '%', 20, 'HIGHER'),
('HRD', '2026-07', 'Hiring Time', 14, 'days', 25, 'LOWER'),
('HRD', '2026-07', 'Employee Satisfaction', 80, 'score', 25, 'HIGHER'),
('HRD', '2026-07', 'Training Hours', 40, 'hours', 25, 'HIGHER'),
('HRD', '2026-07', 'Turnover Rate', 5, '%', 25, 'LOWER')
ON CONFLICT DO NOTHING;

-- ============================================================
-- 3. hr_skills (P1) — Skill levels per karyawan
-- ============================================================
INSERT INTO hr_skills (id, nrp, skill_name, level, target_level, certified, skill_code, valid_until)
SELECT
  'SK-' || e.nrp || '-' || LPAD(g.n::text, 2, '0'),
  e.nrp,
  (ARRAY['K3 Safety', 'Heavy Equipment', 'First Aid', 'Leadership', 'Data Analysis', 'Electrical', 'Mechanical', 'Communication', 'Project Management', 'Quality Control'])[1 + (g.n % 10)],
  1 + (random() * 3)::int,
  2 + (random() * 3)::int,
  random() < 0.3,
  'SK-' || LPAD(g.n::text, 3, '0'),
  ('2026-12-31'::date + (random() * 365)::int)
FROM employees_master e
CROSS JOIN generate_series(1, 3) AS g(n)
WHERE random() < 0.6
ON CONFLICT DO NOTHING;

-- ============================================================
-- 4. hr_position_skills (P1) — Required skills per posisi
-- ============================================================
INSERT INTO hr_position_skills (position, skill_name, required_level) VALUES
('Staff Operasional', 'K3 Safety', 3),
('Staff Operasional', 'Heavy Equipment', 2),
('Staff Operasional', 'First Aid', 2),
('Staff Operasional', 'Communication', 2),
('Supervisor', 'Leadership', 3),
('Supervisor', 'K3 Safety', 4),
('Supervisor', 'Project Management', 3),
('Supervisor', 'Data Analysis', 2),
('Manager', 'Leadership', 4),
('Manager', 'Strategic Planning', 4),
('Manager', 'Financial Analysis', 3),
('Manager', 'Team Management', 4),
('Staff HRD', 'Communication', 3),
('Staff HRD', 'Labor Law', 3),
('Staff HRD', 'Data Analysis', 2),
('Staff Finance', 'Financial Analysis', 4),
('Staff Finance', 'Accounting', 4),
('Staff Finance', 'Tax Regulation', 3),
('Staff IT', 'Programming', 3),
('Staff IT', 'Network Administration', 3),
('Staff IT', 'System Security', 3),
('Director', 'Leadership', 5),
('Director', 'Strategic Planning', 5),
('Director', 'Business Development', 4),
('Director', 'Financial Management', 4)
ON CONFLICT DO NOTHING;

-- ============================================================
-- 5. hr_tasks (P1) — Tasks untuk karyawan
-- ============================================================
INSERT INTO hr_tasks (id, assignee_nrp, title, status, due_date)
SELECT
  'TASK-' || LPAD(g.n::text, 4, '0'),
  (ARRAY['NRP001','NRP002','NRP003','NRP004','NRP005','NRP006','NRP007','NRP010','NRP015','NRP020'])[1 + (g.n % 10)],
  (ARRAY[
    'Laporan kehadiran bulanan',
    'Review KPI tim',
    'Update database karyawan',
    'Persiapan training K3',
    'Audit aset inventaris',
    'Meeting koordinasi divisi',
    'Submit laporan produksi',
    'Verifikasi slip gaji',
    'Training onboarding new hire',
    'Maintenance sistem IT'
  ])[1 + (g.n % 10)],
  (ARRAY['PENDING', 'IN_PROGRESS', 'COMPLETED', 'PENDING'])[1 + (g.n % 4)],
  ('2026-08-' || LPAD((1 + (random() * 28)::int)::text, 2, '0'))::date
FROM generate_series(1, 20) AS g(n)
ON CONFLICT DO NOTHING;

-- ============================================================
-- 6. hr_ai_tasks (P1) — AI auto-healing tasks
-- ============================================================
INSERT INTO hr_ai_tasks (id, agent_name, task_type, title, status, priority, details_json) VALUES
('AIT001', 'attendance-monitor', 'ANOMALY', 'Deteksi pola ketidakhadiran NRP015', 'PENDING', 'HIGH', '{"days_absent":5,"pattern":"weekly_monday"}'),
('AIT002', 'kpi-sentinel', 'ALERT', 'KPI score NRP020 di bawah threshold', 'PENDING', 'HIGH', '{"score":45,"threshold":60}'),
('AIT003', 'compliance-bot', 'REMINDER', 'Sertifikasi K3 NRP003 expired dalam 30 hari', 'PENDING', 'MEDIUM', '{"cert":"K3","expiry":"2026-09-15"}'),
('AIT004', 'payroll-validator', 'CHECK', 'Validasi payroll periode 2026-07', 'COMPLETED', 'LOW', '{"records":30,"status":"validated"}'),
('AIT005', 'overtime-analyzer', 'ANALYSIS', 'Analisis lembur berlebihan divisi OPERATIONAL', 'PENDING', 'MEDIUM', '{"avg_overtime":45,"threshold":20}'),
('AIT006', 'flight-risk', 'PREDICT', 'Prediksi flight risk karyawan', 'PENDING', 'HIGH', '{"model":"v2","threshold":0.7}'),
('AIT007', 'training-gaper', 'REMINDER', 'Gap training untuk 5 karyawan', 'PENDING', 'MEDIUM', '{"gap_count":5}'),
('AIT008', 'safety-sentinel', 'MONITOR', 'Monitor insiden safety 7 hari terakhir', 'COMPLETED', 'LOW', '{"incidents":0,"status":"safe"}')
ON CONFLICT DO NOTHING;

-- ============================================================
-- 7. announcements (P2) — Pengumuman perusahaan
-- ============================================================
INSERT INTO announcements (id, title, message, priority, target_audience, expiry_date, created_by) VALUES
('ANN001', 'HUT RI ke-81', 'Selamat Hari Kemerdekaan RI! Hari libur nasional 17 Agustus 2026.', 'HIGH', 'ALL', '2026-08-20', 'NRP001'),
('ANN002', 'Training K3 Wajib', 'Semua karyawan operasional wajib mengikuti training K3 refresh bulan ini.', 'HIGH', 'OPERATIONAL', '2026-08-31', 'NRP001'),
('ANN003', 'Pembaruan Sistem', 'Sistem insightWOS akan di-maintenance Sabtu 30 Agustus 2026 pukul 22:00-02:00 WIB.', 'MEDIUM', 'ALL', '2026-08-31', 'NRP002'),
('ANN004', 'Bonus Kinerja Q2', 'Bonus kinerja Q2 2026 akan dicairkan bersama gaji Juli.', 'HIGH', 'ALL', '2026-09-15', 'NRP001'),
('ANN005', 'Medical Checkup', 'Medical checkup tahunan akan dilaksanakan September 2026. Silakan daftar ke HRD.', 'MEDIUM', 'ALL', '2026-09-30', 'NRP001'),
('ANN006', 'Jam Kerja Baru', 'Mulai 1 September 2026, jam kerja flextime diberlakukan untuk divisi IT dan HRD.', 'MEDIUM', 'ALL', '2026-09-01', 'NRP001')
ON CONFLICT DO NOTHING;

-- ============================================================
-- 8. hr_training_catalog (P2) — Daftar training
-- ============================================================
INSERT INTO hr_training_catalog (id, title, category, provider, duration_hours, priority) VALUES
('TC001', 'K3 Dasar & Lanjutan', 'SAFETY', 'Internal Safety Team', 16, 'HIGH'),
('TC002', 'First Aid & CPR', 'SAFETY', 'Red Cross Indonesia', 8, 'HIGH'),
('TC003', 'Heavy Equipment Operation', 'TECHNICAL', 'CAT Training Center', 40, 'NORMAL'),
('TC004', 'Leadership Development Program', 'SOFT_SKILL', 'HRD Academy', 24, 'NORMAL'),
('TC005', 'Financial Analysis & Reporting', 'TECHNICAL', 'Finance Academy', 16, 'NORMAL'),
('TC006', 'Data Analytics with Excel', 'TECHNICAL', 'IT Training Hub', 12, 'NORMAL'),
('TC007', 'Communication Skills', 'SOFT_SKILL', 'HRD Academy', 8, 'LOW'),
('TC008', 'Fire Safety & Evacuation', 'SAFETY', 'Internal Safety Team', 4, 'HIGH'),
('TC009', 'Anti-Corruption & Compliance', 'COMPLIANCE', 'Legal Department', 4, 'HIGH'),
('TC010', 'Project Management Professional', 'TECHNICAL', 'PMI Indonesia', 35, 'NORMAL')
ON CONFLICT DO NOTHING;

-- ============================================================
-- 9. hr_succession (P2) — Succession planning
-- ============================================================
INSERT INTO hr_succession (id, position, candidate_nrp, readiness, notes) VALUES
('SUC001', 'Supervisor Operasional', 'NRP003', 'Ready Now', 'KPI consistently above 80, strong leadership'),
('SUC002', 'Supervisor Operasional', 'NRP004', 'Ready Soon', 'Good performance, needs leadership training'),
('SUC003', 'Manager HRD', 'NRP010', 'Future Ready', 'High potential, 2+ years experience needed'),
('SUC004', 'Staff Senior IT', 'NRP005', 'Ready Now', 'Top performer, certified in multiple areas'),
('SUC005', 'Supervisor Finance', 'NRP008', 'Ready Soon', 'Strong financial skills, good communicator'),
('SUC006', 'Direktur Operasional', 'NRP002', 'Ready Now', '15+ years experience, excellent track record')
ON CONFLICT DO NOTHING;

-- ============================================================
-- 10. hr_critical (P2) — Critical positions
-- ============================================================
INSERT INTO hr_critical (nrp, position, backup_nrp, risk_level) VALUES
('NRP001', 'Direktur Utama', 'NRP002', 'HIGH'),
('NRP002', 'Direktur Operasional', 'NRP003', 'HIGH'),
('NRP005', 'Staff Senior IT', 'NRP006', 'MEDIUM'),
('NRP008', 'Manager Finance', 'NRP009', 'MEDIUM'),
('NRP010', 'Manager HRD', 'NRP011', 'LOW'),
('NRP003', 'Supervisor Operasional', 'NRP004', 'HIGH')
ON CONFLICT DO NOTHING;

-- ============================================================
-- 11. hr_overtime (P2) — Data lembur
-- ============================================================
INSERT INTO hr_overtime (id, nrp, date, hours, reason, status)
SELECT
  'OT-' || LPAD(g.n::text, 4, '0'),
  (ARRAY['NRP001','NRP003','NRP005','NRP007','NRP010','NRP015','NRP020','NRP025'])[1 + (g.n % 8)],
  ('2026-07-' || LPAD((1 + (random() * 28)::int)::text, 2, '0'))::date,
  (1 + (random() * 6) * 2)::decimal(4,2),
  (ARRAY['Deadline project', 'Maintenance mesin', 'Laporan bulanan', 'Training sesi malam', 'Urgent task'])[1 + (g.n % 5)],
  (ARRAY['APPROVED', 'PENDING', 'APPROVED', 'APPROVED'])[1 + (g.n % 4)]
FROM generate_series(1, 25) AS g(n)
ON CONFLICT DO NOTHING;

-- ============================================================
-- 12. hr_exit_clearance (P2) — Exit clearance
-- ============================================================
INSERT INTO hr_exit_clearance (nrp, resign_date, last_work_date, clearance_status) VALUES
('NRP028', '2026-07-01', '2026-07-15', 'COMPLETED'),
('NRP029', '2026-06-15', '2026-06-30', 'COMPLETED'),
('NRP030', '2026-08-01', '2026-08-15', 'IN_PROGRESS')
ON CONFLICT DO NOTHING;

-- ============================================================
-- 13. hr_medical_checkup (P3) — Medical checkup
-- ============================================================
INSERT INTO hr_medical_checkup (nrp, checkup_date, result, expiry_date)
SELECT
  e.nrp,
  ('2026-01-' || LPAD((1 + (random() * 28)::int)::text, 2, '0'))::date,
  (ARRAY['NORMAL', 'NORMAL', 'NORMAL', 'NORMAL', 'KONTROL TEKANAN DARAH', 'KONTROL GULA DARAH'])[1 + (random() * 5)::int],
  ('2027-01-' || LPAD((1 + (random() * 28)::int)::text, 2, '0'))::date
FROM employees_master e
WHERE random() < 0.7
ON CONFLICT DO NOTHING;

-- ============================================================
-- 14. hr_capability (P3) — Competency gap
-- ============================================================
INSERT INTO hr_capability (nrp, kompetensi, level_sekarang, level_target, gap, is_mandatory)
SELECT
  e.nrp,
  (ARRAY['K3 Safety', 'Leadership', 'Technical Skills', 'Data Analysis', 'Communication', 'Project Management'])[1 + (random() * 5)::int],
  1 + (random() * 3)::int,
  3 + (random() * 2)::int,
  (random() * 2)::decimal(3,1),
  random() < 0.4
FROM employees_master e
CROSS JOIN generate_series(1, 2) AS g(n)
WHERE random() < 0.5
ON CONFLICT DO NOTHING;

-- ============================================================
-- 15. hr_relations (P3) — Employee relations
-- ============================================================
INSERT INTO hr_relations (nrp, type, related_nrp, notes) VALUES
('NRP001', 'SUPERVISOR', 'NRP003', 'Direct reporting line'),
('NRP002', 'SUPERVISOR', 'NRP004', 'Direct reporting line'),
('NRP003', 'PEER', 'NRP004', 'Cross-functional collaboration'),
('NRP005', 'PEER', 'NRP006', 'IT team collaboration'),
('NRP010', 'SUPERVISOR', 'NRP011', 'HRD team lead'),
('NRP015', 'MENTOR', 'NRP003', 'Assigned mentor for new hire'),
('NRP020', 'MENTOR', 'NRP005', 'Technical mentorship'),
('NRP007', 'PEER', 'NRP010', 'HR-Operations liaison')
ON CONFLICT DO NOTHING;

-- ============================================================
-- 16. hr_monthly_snapshot (P3) — Monthly metrics
-- ============================================================
INSERT INTO hr_monthly_snapshot (periode, divisi, total_headcount, avg_kpi, total_turnover, total_hire, avg_engagement, total_training_hours, total_incidents, total_overtime_hours, total_payroll, total_revenue, total_profit, productivity_index, compliance_rate, retention_rate)
SELECT
  '2026-07',
  d.divisi,
  d.hc,
  COALESCE(p.avg_kpi, 70),
  CASE WHEN d.divisi = 'OPERATIONAL' THEN 2 ELSE 1 END,
  1,
  50 + (random() * 40)::int,
  d.hc * (16 + (random() * 24)::int),
  (random() * 3)::int,
  d.hc * (8 + (random() * 12)::int),
  d.hc * (CASE WHEN d.divisi = 'OPERATIONAL' THEN 8000000 WHEN d.divisi = 'FINANCE' THEN 12000000 ELSE 10000000 END),
  CASE WHEN d.divisi = 'OPERATIONAL' THEN 850000000 WHEN d.divisi = 'FINANCE' THEN 120000000 ELSE 80000000 END,
  CASE WHEN d.divisi = 'OPERATIONAL' THEN 250000000 WHEN d.divisi = 'FINANCE' THEN 35000000 ELSE 15000000 END,
  75 + (random() * 20)::decimal(5,2),
  85 + (random() * 15)::decimal(5,2),
  90 + (random() * 10)::decimal(5,2)
FROM (SELECT divisi, COUNT(*) as hc FROM employees_master WHERE divisi IS NOT NULL GROUP BY divisi) d
LEFT JOIN (
  SELECT e.divisi, ROUND(AVG(p.kpi_score), 1) as avg_kpi
  FROM employees_master e LEFT JOIN hr_performance p ON p.nrp = e.nrp
  WHERE e.divisi IS NOT NULL AND p.periode = '2026-07'
  GROUP BY e.divisi
) p ON p.divisi = d.divisi
ON CONFLICT DO NOTHING;

-- Period 2026-06
INSERT INTO hr_monthly_snapshot (periode, divisi, total_headcount, avg_kpi, total_turnover, total_hire, avg_engagement, total_training_hours, total_incidents, total_overtime_hours, total_payroll, total_revenue, total_profit, productivity_index, compliance_rate, retention_rate)
SELECT
  '2026-06',
  d.divisi,
  d.hc,
  COALESCE(p.avg_kpi, 68),
  CASE WHEN d.divisi = 'OPERATIONAL' THEN 1 ELSE 0 END,
  2,
  48 + (random() * 38)::int,
  d.hc * (14 + (random() * 20)::int),
  (random() * 2)::int,
  d.hc * (10 + (random() * 10)::int),
  d.hc * (CASE WHEN d.divisi = 'OPERATIONAL' THEN 7800000 WHEN d.divisi = 'FINANCE' THEN 11500000 ELSE 9500000 END),
  CASE WHEN d.divisi = 'OPERATIONAL' THEN 820000000 WHEN d.divisi = 'FINANCE' THEN 115000000 ELSE 75000000 END,
  CASE WHEN d.divisi = 'OPERATIONAL' THEN 230000000 WHEN d.divisi = 'FINANCE' THEN 32000000 ELSE 12000000 END,
  72 + (random() * 18)::decimal(5,2),
  83 + (random() * 14)::decimal(5,2),
  89 + (random() * 9)::decimal(5,2)
FROM (SELECT divisi, COUNT(*) as hc FROM employees_master WHERE divisi IS NOT NULL GROUP BY divisi) d
LEFT JOIN (
  SELECT e.divisi, ROUND(AVG(p.kpi_score), 1) as avg_kpi
  FROM employees_master e LEFT JOIN hr_performance p ON p.nrp = e.nrp
  WHERE e.divisi IS NOT NULL AND p.periode = '2026-06'
  GROUP BY e.divisi
) p ON p.divisi = d.divisi
ON CONFLICT DO NOTHING;

-- ============================================================
-- 17. hr_plantation_harvest (P3) — Harvest data
-- ============================================================
INSERT INTO hr_plantation_harvest (nrp, date, block_area, tbs_kg, quality)
SELECT
  e.nrp,
  d::date,
  'Block-' || (1 + (random() * 20)::int),
  (800 + random() * 1200)::decimal(10,2),
  (ARRAY['A', 'A', 'B', 'B', 'C'])[1 + (random() * 4)::int]
FROM employees_master e
CROSS JOIN generate_series('2026-07-01'::date, '2026-07-28'::date, '1 day') AS d
WHERE e.divisi = 'OPERATIONAL' AND random() < 0.4
ON CONFLICT DO NOTHING;

-- ============================================================
-- DONE — All 17 tables seeded
-- ============================================================
