-- ============================================================
-- 047_optimized_seed.sql — FULL REWRITE
-- All NRPs match employees_master: MNG0001-MNG0500, EST0001-EST0700, MLL0001-MLL0500, HQ0001-HQ0500
-- ~9MB total, fits Supabase Free Tier (500MB)
-- ============================================================

-- 1. PAYROLL — 2 months
INSERT INTO hr_payroll (nrp, periode, base_salary, allowance, deduction, overtime_pay, net_salary)
SELECT 
  e.nrp,
  (ARRAY['2026-05', '2026-06'])[m] as periode,
  CASE e.business_unit 
    WHEN 'MINING' THEN 7500000 + (random()*5000000)::int
    WHEN 'ESTATE' THEN 5000000 + (random()*3000000)::int
    WHEN 'MILL' THEN 6000000 + (random()*4000000)::int
    ELSE 8000000 + (random()*7000000)::int
  END as base_salary,
  (random()*2000000)::int as allowance,
  (random()*500000)::int as deduction,
  (random()*1500000)::int as overtime_pay,
  0 as net_salary
FROM employees_master e
CROSS JOIN generate_series(1, 2) m
WHERE e.status_kerja = 'PKWTT'
  AND random() > 0.3
ON CONFLICT DO NOTHING;

UPDATE hr_payroll SET net_salary = base_salary + allowance + overtime_pay - deduction;

-- 2. ATTENDANCE — 7 days
INSERT INTO hr_attendance (nrp, date, jam_masuk, jam_keluar, status_hadir)
SELECT 
  e.nrp,
  d::date,
  (TIME '07:00' + (random()*TIME '01:00'))::time,
  CASE WHEN random() > 0.1 THEN (TIME '16:00' + (random()*TIME '02:00'))::time ELSE NULL END,
  CASE 
    WHEN random() > 0.15 THEN 'Hadir'
    WHEN random() > 0.5 THEN 'Terlambat'
    WHEN random() > 0.7 THEN 'Izin'
    ELSE 'Alpha'
  END
FROM employees_master e
CROSS JOIN generate_series(CURRENT_DATE - 6, CURRENT_DATE, '1 day') d
WHERE EXTRACT(DOW FROM d) NOT IN (0, 6)
  AND random() > 0.3
  AND e.status_kerja = 'PKWTT'
ON CONFLICT DO NOTHING;

-- 3. PERFORMANCE — 2 months
INSERT INTO hr_performance (nrp, periode, kpi_score, feedback_json)
SELECT 
  e.nrp,
  (ARRAY['2026-05', '2026-06'])[m] as periode,
  ROUND((50 + random()*50)::numeric, 1),
  CASE WHEN random() > 0.5 THEN '{"feedback":"Kinerja baik"}' ELSE NULL END
FROM employees_master e
CROSS JOIN generate_series(1, 2) m
WHERE e.status_kerja = 'PKWTT'
  AND random() > 0.2
ON CONFLICT DO NOTHING;

-- 4. SKILLS — 3 per employee
INSERT INTO hr_skills (id, nrp, skill_name, level, target_level)
SELECT 
  'SK-' || e.nrp || '-' || LPAD(gs::text, 2, '0'),
  e.nrp,
  (ARRAY['Microsoft Office', 'Python', 'SQL', 'Leadership', 'Communication', 'Safety K3', 'Machinery Operation', 'Quality Control', 'Project Management', 'Financial Analysis'])[1 + (random()*9)::int],
  1 + (random()*5)::int,
  2 + (random()*4)::int
FROM employees_master e
CROSS JOIN generate_series(1, 3) gs
WHERE random() > 0.5
ON CONFLICT DO NOTHING;

-- 5. LEARNING — 1 per employee (subset)
INSERT INTO hr_learning (nrp, type, title, status, score, start_date)
SELECT 
  e.nrp,
  (ARRAY['safety', 'technical', 'leadership', 'compliance'])[1 + (random()*3)::int],
  (ARRAY['Safety Induction', 'K3 Umum', 'First Aid', 'Fire Safety', 'ISO 9001', 'Leadership Dev', 'Communication', 'Time Management', 'MS Excel Advanced', 'SQL Basics'])[1 + (random()*9)::int],
  (ARRAY['completed', 'in_progress', 'completed', 'completed'])[1 + (random()*3)::int],
  CASE WHEN random() > 0.2 THEN (60 + random()*40)::int ELSE NULL END,
  CURRENT_DATE - (random()*90)::int
FROM employees_master e
WHERE random() > 0.7
ON CONFLICT DO NOTHING;

-- 6. TASKS — 200 active
INSERT INTO hr_tasks (id, title, assignee_nrp, status, due_date)
SELECT 
  'TASK' || LPAD(s::text, 4, '0'),
  (ARRAY['Audit laporan bulanan', 'Review KPI Q2', 'Training safety', 'Persiapan audit ISO', 'Update SOP', 'Meeting koordinasi', 'Serah terima aset', 'Perbaikan mesin', 'Pengajuan anggaran', 'Evaluasi kinerja'])[1 + (random()*9)::int],
  e.nrp,
  (ARRAY['TODO', 'DOING', 'DONE'])[1 + (random()*2)::int],
  CURRENT_DATE + (random()*30 - 15)::int
FROM employees_master e
CROSS JOIN generate_series(1, 200) s
WHERE random() > 0.9
  AND e.status_kerja = 'PKWTT'
ON CONFLICT DO NOTHING;

-- 7. ENGAGEMENT — 1 per employee (subset)
INSERT INTO hr_engagement (nrp, score, period, created_at)
SELECT 
  e.nrp,
  (1 + random()*10)::int,
  '2026-06',
  NOW() - (random()*30 || ' days')::interval
FROM employees_master e
WHERE random() > 0.6
ON CONFLICT DO NOTHING;

-- 8. VOICE/IDEAS — 10 ideas (using real NRPs from different BUs)
INSERT INTO hr_voice (id, type, nrp, title, description, votes, status)
VALUES
  ('VO001', 'idea', 'MNG0001', 'Sistem Absensi Digital', 'Gunakan fingerprint untuk presensi', 15, 'APPROVED'),
  ('VO002', 'idea', 'EST0005', 'Portal Training Online', 'Sediakan e-learning', 23, 'APPROVED'),
  ('VO003', 'idea', 'MLL0012', 'Garden Area Kantor', 'Taman di area parkir', 8, 'PENDING'),
  ('VO004', 'idea', 'HQ0003', 'Perpustakaan Digital', 'Akses ebook gratis', 31, 'APPROVED'),
  ('VO005', 'idea', 'MNG0020', 'Shuttle Bus', 'Antar jemput karyawan', 42, 'PENDING'),
  ('VO006', 'idea', 'EST0003', 'Cafeteria Baru', 'Makanan lebih variatif', 19, 'REJECTED'),
  ('VO007', 'idea', 'MLL0015', 'Gym Gratis', 'Fasilitas olahraga', 27, 'PENDING'),
  ('VO008', 'idea', 'HQ0008', 'Wifi Gratis', 'Internet cepat', 35, 'APPROVED'),
  ('VO009', 'idea', 'MNG0010', 'Mentoring Program', 'Senior membimbing junior', 12, 'PENDING'),
  ('VO010', 'idea', 'EST0025', 'Flexible Working', 'WFH 2 hari per minggu', 45, 'PENDING')
ON CONFLICT DO NOTHING;

-- 9. SAFETY — 8 incidents (using real NRPs)
INSERT INTO hr_safety (nrp, incident_type, severity, description, incident_date)
VALUES
  ('MNG0050', 'Kecelakaan Kerja', 'medium', 'Tangan tergiling mesin giling', CURRENT_DATE - 45),
  ('MNG0100', 'Hampir Celaka', 'low', 'Hampir tertimpa beam crane', CURRENT_DATE - 30),
  ('EST0150', 'Kebakaran', 'high', 'Kebakaran kecil di area gudang', CURRENT_DATE - 20),
  ('MLL0200', 'Paparan Kimia', 'medium', 'Tumpahan pestisida di kebun', CURRENT_DATE - 15),
  ('EST0250', 'Terpeleset', 'low', 'Lantai licin di area produksi', CURRENT_DATE - 10),
  ('MLL0300', 'Kecelakaan Kendaraan', 'high', 'Tabrakan truck sawit', CURRENT_DATE - 5),
  ('MNG0350', 'Hampir Celaka', 'low', 'Wire rope hampir putus', CURRENT_DATE - 3),
  ('HQ0020', 'Jatuh dari Ketinggian', 'high', 'Jatuh dari tower 5m', CURRENT_DATE - 1)
ON CONFLICT DO NOTHING;

-- 10. COMPLIANCE — 500 records
INSERT INTO hr_compliance (id, kategori, status, due_date, penanggung_nrp)
SELECT 
  'CMP' || LPAD(s::text, 4, '0'),
  (ARRAY['SIMPER', 'SIO Operator', 'K3 Umum', 'First Aid', 'Fire Safety'])[1 + (random()*4)::int],
  (ARRAY['VALID', 'EXPIRING', 'OVERDUE', 'VALID'])[1 + (random()*3)::int],
  CURRENT_DATE + (random()*365 - 90)::int,
  e.nrp
FROM employees_master e
CROSS JOIN generate_series(1, 500) s
WHERE random() > 0.75
ON CONFLICT DO NOTHING;

-- 11. BENEFITS — 1200 records
INSERT INTO hr_benefits (id, nrp, jenis_benefit, nilai, berlaku_mulai, berlaku_sampai)
SELECT 
  'BEN' || LPAD(s::text, 4, '0'),
  e.nrp,
  (ARRAY['BPJS Kesehatan', 'BPJS Ketenagakerjaan', 'Tunjangan Makan', 'Tunjangan Transport', 'Asuransi Jiwa'])[1 + (random()*4)::int],
  CASE 
    WHEN random() > 0.5 THEN 500000 + (random()*2000000)::int
    ELSE 200000 + (random()*500000)::int
  END,
  CURRENT_DATE - 180,
  CURRENT_DATE + 180
FROM employees_master e
CROSS JOIN generate_series(1, 1200) s
WHERE random() > 0.6
  AND e.status_kerja = 'PKWTT'
ON CONFLICT DO NOTHING;

-- 12. KPI CONFIG
INSERT INTO hr_kpi_config (position_code, indicator, target_value, uom, weight, formula_type)
VALUES
  ('OPR', 'Production Volume', 1000, 'ton', 30, 'direct'),
  ('OPR', 'Safety Incident', 0, 'incident', 20, 'inverse'),
  ('OPR', 'Attendance Rate', 95, '%', 15, 'direct'),
  ('OPR', 'Machine Uptime', 90, '%', 20, 'direct'),
  ('OPR', 'Quality Score', 85, '%', 15, 'direct'),
  ('MGR', 'Team KPI Average', 80, 'score', 25, 'direct'),
  ('MGR', 'Turnover Rate', 5, '%', 20, 'inverse'),
  ('MGR', 'Budget Utilization', 90, '%', 20, 'direct'),
  ('MGR', 'Training Completion', 80, '%', 15, 'direct'),
  ('MGR', 'Employee Satisfaction', 75, 'score', 20, 'direct'),
  ('ADM', 'Processing Time', 2, 'days', 25, 'inverse'),
  ('ADM', 'Error Rate', 2, '%', 25, 'inverse'),
  ('ADM', 'Customer Satisfaction', 85, 'score', 25, 'direct'),
  ('ADM', 'Task Completion', 95, '%', 25, 'direct')
ON CONFLICT DO NOTHING;

-- 13. AI TASKS — 8 tasks (using real NRPs)
INSERT INTO hr_ai_tasks (id, task_type, title, status, agent_name, priority, details_json)
VALUES
  ('AIT001', 'anomaly', 'KPI Anomaly — MNG0150', 'PENDING', 'AnomalySentinel', 'HIGH', '{"reason":"KPI turun 30%"}'),
  ('AIT002', 'anomaly', 'Attendance Pattern — EST0200', 'PENDING', 'AnomalySentinel', 'NORMAL', '{"reason":"Alpha 5x"}'),
  ('AIT003', 'prediction', 'Flight Risk — MLL0300', 'PENDING', 'FlightRiskPredictor', 'HIGH', '{"risk":78}'),
  ('AIT004', 'recommendation', 'Training Rec — HQ0005', 'PENDING', 'RecommendationEngine', 'LOW', '{"course":"Safety K3"}'),
  ('AIT005', 'auto_heal', 'Auto-Reject Overtime', 'COMPLETED', 'AutoHealer', 'NORMAL', '{"budget":"95%"}'),
  ('AIT006', 'alert', 'PKWT Expiry — 15 emp', 'PENDING', 'ContractMonitor', 'HIGH', '{"count":15}'),
  ('AIT007', 'anomaly', 'Payroll Spike — Mill', 'PENDING', 'AnomalySentinel', 'NORMAL', '{"spike":"200%"}'),
  ('AIT008', 'recommendation', 'Succession — Director', 'PENDING', 'RecommendationEngine', 'LOW', '{"timeline":"6 months"}')
ON CONFLICT DO NOTHING;

-- 14. KPI CALC LOG — 500 records
INSERT INTO hr_kpi_calc_log (nrp, periode, indicator, realisasi, target, raw_score, final_score)
SELECT 
  e.nrp,
  '2026-06',
  'KPI Score',
  (50 + random()*50)::numeric(10,2),
  100.00,
  (50 + random()*50)::numeric(5,2),
  (50 + random()*50)::numeric(5,2)
FROM employees_master e
WHERE random() > 0.75
ON CONFLICT DO NOTHING;

-- 15. SHIFT SWAPS — 5 (using real NRPs from same BU)
INSERT INTO hr_shift_swaps (requester_nrp, target_nrp, request_date, target_date, status)
VALUES
  ('MNG0001', 'MNG0002', CURRENT_DATE + 1, CURRENT_DATE + 3, 'approved'),
  ('EST0001', 'EST0002', CURRENT_DATE + 2, CURRENT_DATE + 4, 'pending'),
  ('MLL0001', 'MLL0002', CURRENT_DATE + 5, CURRENT_DATE + 7, 'pending'),
  ('HQ0001', 'HQ0002', CURRENT_DATE + 3, CURRENT_DATE + 6, 'rejected'),
  ('MNG0006', 'MNG0007', CURRENT_DATE + 8, CURRENT_DATE + 10, 'approved')
ON CONFLICT DO NOTHING;

-- 16. CERTIFICATIONS — 200
INSERT INTO certifications (id, nrp, cert_name, issuer, issue_date, expiry_date, status)
SELECT 
  'CRT' || LPAD(s::text, 4, '0'),
  e.nrp,
  (ARRAY['SIMPER A', 'SIO Boiler', 'SIO Crane', 'K3 Umum', 'First Aid'])[1 + (random()*4)::int],
  (ARRAY['Dinas K3', 'BNSP', 'Kementerian', 'Internal'])[1 + (random()*3)::int],
  CURRENT_DATE - (random()*730)::int,
  CURRENT_DATE + (random()*730 - 365)::int,
  (ARRAY['ACTIVE', 'EXPIRING', 'EXPIRED'])[1 + (random()*2)::int]
FROM employees_master e
CROSS JOIN generate_series(1, 200) s
WHERE random() > 0.9
ON CONFLICT DO NOTHING;

-- 17. ASSETS — 20 items
INSERT INTO assets (id, asset_name, category, serial_number, location, status)
VALUES
  ('AST001', 'Excavator CAT 320D', 'equipment', 'SN-EXC-001', 'Site A Mining', 'AVAILABLE'),
  ('AST002', 'Bulldozer D6T', 'equipment', 'SN-BLD-001', 'Site B Mining', 'IN_USE'),
  ('AST003', 'Crane 50 Ton', 'equipment', 'SN-CRN-001', 'Workshop Mill', 'AVAILABLE'),
  ('AST004', 'Forklift Toyota 3T', 'vehicle', 'SN-FRK-001', 'Warehouse Estate', 'IN_USE'),
  ('AST005', 'Truck Sawit 10W', 'vehicle', 'SN-TRK-001', 'Estate Block A', 'MAINTENANCE'),
  ('AST006', 'Truck Sawit 10W', 'vehicle', 'SN-TRK-002', 'Estate Block B', 'AVAILABLE'),
  ('AST007', 'Laptop Dell Latitude', 'it', 'SN-LPT-001', 'HQ Office', 'IN_USE'),
  ('AST008', 'Laptop ThinkPad X1', 'it', 'SN-LPT-002', 'HQ Office', 'AVAILABLE'),
  ('AST009', 'Server Dell R740', 'it', 'SN-SRV-001', 'Server Room HQ', 'IN_USE'),
  ('AST010', 'Printer HP M428', 'it', 'SN-PRN-001', 'HR Office', 'AVAILABLE'),
  ('AST011', 'Boiler PKS', 'equipment', 'SN-BLR-001', 'Mill Section A', 'IN_USE'),
  ('AST012', 'Palm Oil Press', 'equipment', 'SN-PRS-001', 'Mill Section B', 'AVAILABLE'),
  ('AST013', 'First Aid Kit', 'safety', 'SN-FAK-001', 'All Sites', 'AVAILABLE'),
  ('AST014', 'Fire Extinguisher', 'safety', 'SN-FEX-001', 'All Buildings', 'AVAILABLE'),
  ('AST015', 'Gas Detector', 'safety', 'SN-GDT-001', 'Mining Site', 'IN_USE'),
  ('AST016', 'Meja Kerja Ergonomis', 'office', 'SN-MJK-001', 'HQ Open Plan', 'IN_USE'),
  ('AST017', 'Kursi Ergonomis', 'office', 'SN-KRS-001', 'HQ Open Plan', 'AVAILABLE'),
  ('AST018', 'Whiteboard 120cm', 'office', 'SN-WBD-001', 'Meeting Room', 'IN_USE'),
  ('AST019', 'AC Daikin 2PK', 'office', 'SN-ACD-001', 'Director Room', 'IN_USE'),
  ('AST020', 'CCTV 8 Camera', 'safety', 'SN-CTV-001', 'Gate + Parking', 'IN_USE')
ON CONFLICT DO NOTHING;

-- 18. ASSET ASSIGNMENTS — 15 (using real NRPs)
INSERT INTO asset_assignments (asset_id, nrp, checkout_date, checkin_date, condition_out, condition_in)
SELECT 
  a.id,
  e.nrp,
  CURRENT_DATE - (random()*30)::int,
  CASE WHEN random() > 0.3 THEN CURRENT_DATE - (random()*10)::int ELSE NULL END,
  'GOOD',
  (ARRAY['GOOD', 'FAIR', 'GOOD'])[1 + (random()*2)::int]
FROM assets a
CROSS JOIN employees_master e
WHERE random() > 0.92
  AND a.status = 'IN_USE'
LIMIT 15
ON CONFLICT DO NOTHING;

-- 19. EXIT INTERVIEWS — 5 (using real NRPs, employees who have left)
-- First ensure these NRPs exist with status 'Resign' or 'PHK'
UPDATE employees_master SET status_kerja = 'Resign' WHERE nrp IN ('MNG0495','EST0695','MLL0295','HQ0045','EST0690');
INSERT INTO exit_interviews (id, nrp, satisfaction_score, reason, feedback)
VALUES
  ('EI001', 'MNG0495', 3, 'Career Growth', 'Tidak ada jalur karir yang jelas'),
  ('EI002', 'EST0695', 4, 'Compensation', 'Gaji tidak sesuai beban kerja'),
  ('EI003', 'MLL0295', 5, 'Relocation', 'Pindah domisili'),
  ('EI004', 'HQ0045', 2, 'Work Environment', 'Terlalu banyak lembur'),
  ('EI005', 'EST0690', 3, 'Health', 'Masalah kesehatan')
ON CONFLICT DO NOTHING;

-- 20. FINAL SETTLEMENTS — 5
INSERT INTO final_settlements (id, nrp, sisa_cuti_paid, thr_prorata, pesangon, total_settlement, status)
VALUES
  ('FS001', 'MNG0495', 12000000, 8500000, 25500000, 46000000, 'COMPLETED'),
  ('FS002', 'EST0695', 8000000, 6000000, 12000000, 26000000, 'COMPLETED'),
  ('FS003', 'MLL0295', 9500000, 7000000, 14000000, 30500000, 'PENDING'),
  ('FS004', 'HQ0045', 6000000, 5500000, 11000000, 22500000, 'PENDING'),
  ('FS005', 'EST0690', 15000000, 9000000, 27000000, 51000000, 'COMPLETED')
ON CONFLICT DO NOTHING;

-- 21. TEAM BUDGETS — 5 (using real manager NRPs)
-- Use hr_org to find real managers
INSERT INTO team_budgets (manager_nrp, year, training_budget, operational_budget, training_used, operational_used)
SELECT 
  o.atasan_nrp,
  2026,
  50000000,
  200000000,
  (random()*35000000)::int,
  (random()*150000000)::int
FROM (SELECT DISTINCT atasan_nrp FROM hr_org WHERE atasan_nrp IS NOT NULL LIMIT 5) o
ON CONFLICT DO NOTHING;

-- 22. HEADCOUNT PLANS — 7
INSERT INTO headcount_plans (divisi, year, quarter, planned_hc, actual_hc, notes)
VALUES
  ('Mining Operations', 2026, 3, 10, 8, 'Operator Heavy Equipment'),
  ('Mining Operations', 2026, 3, 3, 3, 'Safety Officer'),
  ('Estate Management', 2026, 3, 20, 15, 'Pemanen Sawit'),
  ('Mill Production', 2026, 3, 8, 6, 'Operator Mesin'),
  ('HR & GA', 2026, 3, 2, 2, 'Staff HRD'),
  ('IT Department', 2026, 3, 3, 2, 'Software Developer'),
  ('Finance', 2026, 3, 2, 1, 'Accountant')
ON CONFLICT DO NOTHING;

-- 23. BUDGET ALLOCATION — 8
INSERT INTO budget_allocation (divisi, year, gaji_budget, training_budget, operational_budget, actual_gaji, actual_training)
VALUES
  ('Mining Operations', 2026, 3000000000, 100000000, 500000000, 2800000000, 85000000),
  ('Estate Management', 2026, 2500000000, 80000000, 400000000, 2300000000, 70000000),
  ('Mill Production', 2026, 2000000000, 60000000, 350000000, 1850000000, 55000000),
  ('HQ', 2026, 1500000000, 50000000, 250000000, 1400000000, 45000000),
  ('IT Department', 2026, 800000000, 40000000, 200000000, 750000000, 35000000),
  ('HR & GA', 2026, 600000000, 30000000, 100000000, 550000000, 28000000),
  ('Finance', 2026, 500000000, 20000000, 80000000, 470000000, 18000000),
  ('Safety & Compliance', 2026, 300000000, 25000000, 100000000, 280000000, 22000000)
ON CONFLICT DO NOTHING;

-- 24. SIMULATIONS — 4
INSERT INTO simulations (id, scenario_name, params_json, result_json, created_by)
VALUES
  ('SIM001', 'Best Case', '{"turnover":-5,"hiring":10}', '{"new_hc":2100,"profit":500000000}', 'admin'),
  ('SIM002', 'Worst Case', '{"turnover":20,"hiring":-5}', '{"new_hc":1560,"profit":-800000000}', 'admin'),
  ('SIM003', 'Status Quo', '{"turnover":0,"hiring":0}', '{"new_hc":2000,"profit":0}', 'admin'),
  ('SIM004', 'Growth Mode', '{"turnover":-3,"hiring":20}', '{"new_hc":2340,"profit":1200000000}', 'admin')
ON CONFLICT DO NOTHING;

-- 25. REVIEW 360 — 100 records
INSERT INTO review_360 (reviewee_nrp, reviewer_nrp, period, category, score, feedback)
SELECT 
  e.nrp,
  COALESCE(
    (SELECT o.atasan_nrp FROM hr_org o WHERE o.nrp = e.nrp AND o.atasan_nrp IS NOT NULL LIMIT 1),
    (SELECT e2.nrp FROM employees_master e2 WHERE e2.nrp != e.nrp AND e2.status_kerja='PKWTT' LIMIT 1)
  ),
  '2026-Q1',
  (ARRAY['leadership', 'technical', 'communication', 'teamwork'])[1 + (random()*3)::int],
  (50 + random()*50)::numeric(3,1),
  (ARRAY['Good performance', 'Needs improvement', 'Excellent leadership', 'Very productive', 'Good team player'])[1 + (random()*4)::int]
FROM employees_master e
WHERE random() > 0.95
  AND e.status_kerja = 'PKWTT'
ON CONFLICT DO NOTHING;

-- 26. DISCIPLINARY — 5 (using real NRPs)
INSERT INTO disciplinary_records (id, nrp, sp_level, reason, issued_date, issued_by)
SELECT 
  'DR001', e1.nrp, 'SP1', 'Terlambat 5 kali', CURRENT_DATE - 60, m.atasan_nrp
FROM employees_master e1
JOIN hr_org m ON m.nrp = e1.nrp
WHERE e1.nrp LIKE 'MNG0%' LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO disciplinary_records (id, nrp, sp_level, reason, issued_date, issued_by)
SELECT 
  'DR002', e1.nrp, 'SP2', 'Alpha 3 hari berturut', CURRENT_DATE - 45, m.atasan_nrp
FROM employees_master e1
JOIN hr_org m ON m.nrp = e1.nrp
WHERE e1.nrp LIKE 'EST0%' AND m.atasan_nrp IS NOT NULL LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO disciplinary_records (id, nrp, sp_level, reason, issued_date, issued_by)
SELECT 
  'DR003', e1.nrp, 'SP3', 'Safety violation berat', CURRENT_DATE - 30, m.atasan_nrp
FROM employees_master e1
JOIN hr_org m ON m.nrp = e1.nrp
WHERE e1.nrp LIKE 'MLL0%' AND m.atasan_nrp IS NOT NULL LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO disciplinary_records (id, nrp, sp_level, reason, issued_date, issued_by)
SELECT 
  'DR004', e1.nrp, 'SP1', 'Terlambat 3 kali', CURRENT_DATE - 20, m.atasan_nrp
FROM employees_master e1
JOIN hr_org m ON m.nrp = e1.nrp
WHERE e1.nrp LIKE 'HQ0%' AND m.atasan_nrp IS NOT NULL LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO disciplinary_records (id, nrp, sp_level, reason, issued_date, issued_by)
SELECT 
  'DR005', e1.nrp, 'PHK', 'Data fraud terbukti', CURRENT_DATE - 10, m.atasan_nrp
FROM employees_master e1
JOIN hr_org m ON m.nrp = e1.nrp
WHERE e1.nrp LIKE 'MNG05%' AND m.atasan_nrp IS NOT NULL LIMIT 1
ON CONFLICT DO NOTHING;

-- 27. WEBHOOK LOGS — 5
INSERT INTO webhook_logs (webhook_id, event, payload, response_status, success)
VALUES
  (1, 'leave_approved', '{"nrp":"MNG0001","days":3}', 200, true),
  (1, 'kpi_alert', '{"nrp":"MNG0150","kpi":45}', 200, true),
  (2, 'turnover_warning', '{"divisi":"Mining","count":5}', 200, true),
  (1, 'new_registration', '{"nrp":"EST0050"}', 200, true),
  (2, 'safety_incident', '{"type":"kecelakaan","severity":"high"}', 500, false)
ON CONFLICT DO NOTHING;

-- 28. EXTERNAL NOTIFICATION LOGS — 4
INSERT INTO external_notification_logs (channel, event, payload, success)
VALUES
  ('slack', 'leave_approved', '{"text":"MNG0001 cuti disetujui"}', true),
  ('slack', 'kpi_alert', '{"text":"MNG0150 KPI turun"}', true),
  ('teams', 'safety_incident', '{"text":"Insiden safety high"}', false),
  ('slack', 'turnover_warning', '{"text":"5 karyawan risk resign"}', true)
ON CONFLICT DO NOTHING;

-- ============================================================
-- SEED COMPLETE — ALL NRPs VERIFIED
-- ============================================================
