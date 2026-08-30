-- ============================================================
-- 047_optimized_seed.sql
-- OPTIMIZED SEED: All tables, within 10MB total
-- Attendance: 7 days, Payroll: 2 months, Performance: 2 months
-- ============================================================

-- 1. PAYROLL — 2 months only
INSERT INTO hr_payroll (nrp, period, basic_salary, allowance, deduction, overtime_pay, bonus, net_salary)
SELECT 
  e.nrp,
  (ARRAY['2026-05', '2026-06'])[m] as period,
  CASE e.business_unit 
    WHEN 'MINING' THEN 7500000 + (random()*5000000)::int
    WHEN 'ESTATE' THEN 5000000 + (random()*3000000)::int
    WHEN 'MILL' THEN 6000000 + (random()*4000000)::int
    ELSE 8000000 + (random()*7000000)::int
  END as basic_salary,
  (random()*2000000)::int as allowance,
  (random()*500000)::int as deduction,
  (random()*1500000)::int as overtime_pay,
  CASE WHEN random() > 0.7 THEN (random()*3000000)::int ELSE 0 END as bonus,
  0 as net_salary
FROM employees_master e
CROSS JOIN generate_series(1, 2) m
WHERE e.status_kerja = 'PKWTT'
  AND random() > 0.3  -- 70% have payroll
ON CONFLICT DO NOTHING;

UPDATE hr_payroll SET net_salary = basic_salary + allowance + overtime_pay + bonus - deduction;

-- 2. ATTENDANCE — 7 days only (weekdays)
INSERT INTO hr_attendance (nrp, date, check_in, check_out, status_hadir)
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

-- 3. PERFORMANCE — 2 months only
INSERT INTO hr_performance (nrp, period, kpi_score, attendance_score, productivity_score, attitude_score, initiative_score, overall_score)
SELECT 
  e.nrp,
  (ARRAY['2026-05', '2026-06'])[m] as period,
  (50 + random()*50)::int,
  (60 + random()*40)::int,
  (40 + random()*60)::int,
  (50 + random()*50)::int,
  (30 + random()*70)::int,
  0
FROM employees_master e
CROSS JOIN generate_series(1, 2) m
WHERE e.status_kerja = 'PKWTT'
  AND random() > 0.2  -- 80% have performance data
ON CONFLICT DO NOTHING;

UPDATE hr_performance SET overall_score = ROUND((kpi_score*0.4 + attendance_score*0.3 + productivity_score*0.2 + attitude_score*0.05 + initiative_score*0.05)::numeric, 1);

-- 4. SKILLS — 3 per employee
INSERT INTO hr_skills (nrp, skill_name, level, target_level)
SELECT 
  e.nrp,
  (ARRAY['Microsoft Office', 'Python', 'SQL', 'Leadership', 'Communication', 'Safety K3', 'Machinery Operation', 'Quality Control', 'Project Management', 'Financial Analysis'])[1 + (random()*9)::int],
  1 + (random()*5)::int,
  2 + (random()*4)::int
FROM employees_master e
CROSS JOIN generate_series(1, 3) s
WHERE random() > 0.5
ON CONFLICT DO NOTHING;

-- 5. LEARNING — 1 per employee
INSERT INTO hr_learning (nrp, course_name, status, score, completed_at)
SELECT 
  e.nrp,
  (ARRAY['Safety Induction', 'K3 Umum', 'First Aid', 'Fire Safety', 'ISO 9001', 'Leadership Development', 'Communication Skills', 'Time Management', 'MS Excel Advanced', 'SQL Basics'])[1 + (random()*9)::int],
  (ARRAY['completed', 'in_progress', 'completed', 'completed'])[1 + (random()*3)::int],
  CASE WHEN random() > 0.2 THEN (60 + random()*40)::int ELSE NULL END,
  CASE WHEN random() > 0.3 THEN CURRENT_DATE - (random()*90)::int ELSE NULL END
FROM employees_master e
WHERE random() > 0.7
ON CONFLICT DO NOTHING;

-- 6. TASKS — 200 active
INSERT INTO hr_tasks (title, description, assignee_nrp, creator_nrp, status, priority, due_date)
SELECT 
  (ARRAY['Audit laporan bulanan', 'Review KPI Q2', 'Training safety', 'Persiapan audit ISO', 'Update SOP', 'Meeting koordinasi', 'Serah terima aset', 'Perbaikan mesin', 'Pengajuan anggaran', 'Evaluasi kinerja'])[1 + (random()*9)::int],
  'Deskripsi tugas',
  e.nrp,
  (SELECT nrp FROM hr_org WHERE atasan_nrp = e.nrp LIMIT 1),
  (ARRAY['TODO', 'DOING', 'DONE'])[1 + (random()*2)::int],
  (ARRAY['high', 'medium', 'low'])[1 + (random()*2)::int],
  CURRENT_DATE + (random()*30 - 15)::int
FROM employees_master e
WHERE random() > 0.9
  AND e.status_kerja = 'PKWTT'
ON CONFLICT DO NOTHING;

-- 7. ENGAGEMENT — 1 per employee
INSERT INTO hr_engagement (nrp, score, period, created_at)
SELECT 
  e.nrp,
  (1 + random()*10)::int,
  '2026-06',
  NOW() - (random()*30 || ' days')::interval
FROM employees_master e
WHERE random() > 0.6
ON CONFLICT DO NOTHING;

-- 8. VOICE/IDEAS — 10 ideas
INSERT INTO hr_voice (nrp, title, description, votes, status)
VALUES
  ('NRP001', 'Sistem Absensi Digital', 'Gunakan fingerprint untuk presensi', 15, 'approved'),
  ('NRP005', 'Portal Training Online', 'Sediakan e-learning untuk training wajib', 23, 'approved'),
  ('NRP012', 'Garden Area Kantor', 'Taman di area parkir untuk relaksasi', 8, 'pending'),
  ('NRP025', 'Perpustakaan Digital', 'Akses ebook dan jurnal gratis', 31, 'approved'),
  ('NRP010', 'Shuttle Bus', 'Antar jemput karyawan dari kota', 42, 'pending'),
  ('NRP003', 'Cafeteria Baru', 'Makanan lebih variatif dan sehat', 19, 'rejected'),
  ('NRP015', 'Gym Gratis', 'Fasilitas olahraga di area kantor', 27, 'pending'),
  ('NRP008', 'Wifi Gratis', 'Internet cepat di seluruh area', 35, 'approved'),
  ('NRP020', 'Mentoring Program', 'Senior membimbing junior', 12, 'pending'),
  ('NRP030', 'Flexible Working', 'WFH 2 hari per minggu', 45, 'pending')
ON CONFLICT DO NOTHING;

-- 9. SAFETY — 8 incidents
INSERT INTO hr_safety (nrp, incident_type, severity, description, incident_date)
VALUES
  ('NRP050', 'Kecelakaan Kerja', 'medium', 'Tangan tergiling mesin giling', CURRENT_DATE - 45),
  ('NRP100', 'Hampir Celaka', 'low', 'Hampir tertimpa beam crane', CURRENT_DATE - 30),
  ('NRP150', 'Kebakaran', 'high', 'Kebakaran kecil di area gudang', CURRENT_DATE - 20),
  ('NRP200', 'Paparan Kimia', 'medium', 'Tumpahan pestisida di kebun', CURRENT_DATE - 15),
  ('NRP250', 'Terpeleset', 'low', 'Lantai licin di area produksi', CURRENT_DATE - 10),
  ('NRP300', 'Kecelakaan Kendaraan', 'high', 'Tabrakan truck sawit', CURRENT_DATE - 5),
  ('NRP350', 'Hampir Celaka', 'low', 'Wire rope hampir putus', CURRENT_DATE - 3),
  ('NRP400', 'Jatuh dari Ketinggian', 'high', 'Jatuh dari tower 5m', CURRENT_DATE - 1)
ON CONFLICT DO NOTHING;

-- 10. COMPLIANCE — 500 records
INSERT INTO hr_compliance (nrp, compliance_type, status, expiry_date)
SELECT 
  e.nrp,
  (ARRAY['SIMPER', 'SIO Operator', 'K3 Umum', 'First Aid', 'Fire Safety'])[1 + (random()*4)::int],
  (ARRAY['valid', 'expiring', 'expired', 'valid'])[1 + (random()*3)::int],
  CURRENT_DATE + (random()*365 - 90)::int
FROM employees_master e
WHERE random() > 0.75
ON CONFLICT DO NOTHING;

-- 11. BENEFITS — 1 per employee
INSERT INTO hr_benefits (nrp, benefit_type, amount, status)
SELECT 
  e.nrp,
  (ARRAY['BPJS Kesehatan', 'BPJS Ketenagakerjaan', 'Tunjangan Makan', 'Tunjangan Transport', 'Asuransi Jiwa'])[1 + (random()*4)::int],
  CASE 
    WHEN random() > 0.5 THEN 500000 + (random()*2000000)::int
    ELSE 200000 + (random()*500000)::int
  END,
  'active'
FROM employees_master e
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

-- 13. AI TASKS — 8 tasks
INSERT INTO hr_ai_tasks (task_type, title, status, agent_name, priority, details)
VALUES
  ('anomaly', 'KPI Anomaly — NRP150', 'open', 'AnomalySentinel', 'high', 'KPI turun 30%'),
  ('anomaly', 'Attendance Pattern — NRP200', 'open', 'AnomalySentinel', 'medium', 'Alpha 5x berturut'),
  ('prediction', 'Flight Risk — NRP300', 'open', 'FlightRiskPredictor', 'high', 'Risk score 78%'),
  ('recommendation', 'Training Rec — NRP400', 'pending', 'RecommendationEngine', 'low', 'Butuh Safety K3'),
  ('auto_heal', 'Auto-Reject Overtime', 'completed', 'AutoHealer', 'medium', 'Budget 95%'),
  ('alert', 'PKWT Expiry — 15 emp', 'open', 'ContractMonitor', 'high', 'Habis 30 hari'),
  ('anomaly', 'Payroll Spike — Mill', 'open', 'AnomalySentinel', 'medium', 'Lembur +200%'),
  ('recommendation', 'Succession — Director', 'pending', 'RecommendationEngine', 'low', 'Pensiun 6 bulan')
ON CONFLICT DO NOTHING;

-- 14. KPI CALC LOG — 500 records
INSERT INTO hr_kpi_calc_log (nrp, period, kpi_score, calculation_detail, calculated_at)
SELECT 
  e.nrp,
  '2026-06',
  (50 + random()*50)::int,
  'Auto: KPI=' || (50 + random()*50)::int,
  NOW() - (random()*30 || ' days')::interval
FROM employees_master e
WHERE random() > 0.75
ON CONFLICT DO NOTHING;

-- 15. SHIFT SWAPS — 5
INSERT INTO hr_shift_swaps (requester_nrp, target_nrp, request_date, target_date, status)
VALUES
  ('NRP001', 'NRP005', CURRENT_DATE + 1, CURRENT_DATE + 3, 'approved'),
  ('NRP010', 'NRP015', CURRENT_DATE + 2, CURRENT_DATE + 4, 'pending'),
  ('NRP020', 'NRP025', CURRENT_DATE + 5, CURRENT_DATE + 7, 'pending'),
  ('NRP030', 'NRP035', CURRENT_DATE + 3, CURRENT_DATE + 6, 'rejected'),
  ('NRP040', 'NRP045', CURRENT_DATE + 8, CURRENT_DATE + 10, 'approved')
ON CONFLICT DO NOTHING;

-- 16. CERTIFICATIONS — 200
INSERT INTO certifications (nrp, cert_name, issued_date, expiry_date, status)
SELECT 
  e.nrp,
  (ARRAY['SIMPER A', 'SIO Boiler', 'SIO Crane', 'K3 Umum', 'First Aid'])[1 + (random()*4)::int],
  CURRENT_DATE - (random()*730)::int,
  CURRENT_DATE + (random()*730 - 365)::int,
  (ARRAY['active', 'expiring', 'expired'])[1 + (random()*2)::int]
FROM employees_master e
WHERE random() > 0.9
ON CONFLICT DO NOTHING;

-- 17. ASSETS — 20 items
INSERT INTO assets (name, category, location, condition_status, status)
VALUES
  ('Excavator CAT 320D', 'equipment', 'Site A Mining', 'good', 'available'),
  ('Bulldozer D6T', 'equipment', 'Site B Mining', 'fair', 'in_use'),
  ('Crane 50 Ton', 'equipment', 'Workshop Mill', 'good', 'available'),
  ('Forklift Toyota 3T', 'vehicle', 'Warehouse Estate', 'good', 'in_use'),
  ('Truck Sawit 10W', 'vehicle', 'Estate Block A', 'fair', 'maintenance'),
  ('Truck Sawit 10W', 'vehicle', 'Estate Block B', 'good', 'available'),
  ('Laptop Dell Latitude', 'it', 'HQ Office', 'good', 'in_use'),
  ('Laptop ThinkPad X1', 'it', 'HQ Office', 'good', 'available'),
  ('Server Dell R740', 'it', 'Server Room HQ', 'good', 'in_use'),
  ('Printer HP M428', 'it', 'HR Office', 'good', 'available'),
  ('Boiler PKS', 'equipment', 'Mill Section A', 'fair', 'in_use'),
  ('Palm Oil Press', 'equipment', 'Mill Section B', 'good', 'available'),
  ('First Aid Kit', 'safety', 'All Sites', 'good', 'available'),
  ('Fire Extinguisher', 'safety', 'All Buildings', 'good', 'available'),
  ('Gas Detector', 'safety', 'Mining Site', 'good', 'in_use'),
  ('Meja Kerja Ergonomis', 'office', 'HQ Open Plan', 'good', 'in_use'),
  ('Kursi Ergonomis', 'office', 'HQ Open Plan', 'good', 'available'),
  ('Whiteboard 120cm', 'office', 'Meeting Room', 'good', 'in_use'),
  ('AC Daikin 2PK', 'office', 'Director Room', 'good', 'in_use'),
  ('CCTV 8 Camera', 'safety', 'Gate + Parking', 'good', 'in_use')
ON CONFLICT DO NOTHING;

-- 18. ASSET ASSIGNMENTS — 15
INSERT INTO asset_assignments (asset_id, nrp, checkout_date, returned_date, condition_returned)
SELECT 
  a.id,
  e.nrp,
  CURRENT_DATE - (random()*30)::int,
  CASE WHEN random() > 0.3 THEN CURRENT_DATE - (random()*10)::int ELSE NULL END,
  (ARRAY['good', 'fair', 'good'])[1 + (random()*2)::int]
FROM assets a
CROSS JOIN employees_master e
WHERE random() > 0.9
  AND a.status = 'in_use'
LIMIT 15
ON CONFLICT DO NOTHING;

-- 19. EXIT INTERVIEWS — 5
INSERT INTO exit_interviews (nrp, reason, feedback, interview_date)
VALUES
  ('NRP900', 'Career Growth', 'Tidak ada jalur karir yang jelas', CURRENT_DATE - 60),
  ('NRP901', 'Compensation', 'Gaji tidak sesuai beban kerja', CURRENT_DATE - 45),
  ('NRP902', 'Relocation', 'Pindah domisili', CURRENT_DATE - 30),
  ('NRP903', 'Work Environment', 'Terlalu banyak lembur', CURRENT_DATE - 20),
  ('NRP904', 'Health', 'Masalah kesehatan', CURRENT_DATE - 10)
ON CONFLICT DO NOTHING;

-- 20. FINAL SETTLEMENTS — 5
INSERT INTO final_settlements (nrp, basic_salary, severance, leave_pay, total_settlement, status)
VALUES
  ('NRP900', 8500000, 25500000, 12000000, 46000000, 'completed'),
  ('NRP901', 6000000, 12000000, 8000000, 26000000, 'completed'),
  ('NRP902', 7000000, 14000000, 9500000, 30500000, 'pending'),
  ('NRP903', 5500000, 11000000, 6000000, 22500000, 'pending'),
  ('NRP904', 9000000, 27000000, 15000000, 51000000, 'completed')
ON CONFLICT DO NOTHING;

-- 21. TEAM BUDGETS — 8
INSERT INTO team_budgets (divisi, period, allocated, spent, category)
VALUES
  ('Mining Operations', '2026-Q2', 500000000, 380000000, 'operational'),
  ('Estate Management', '2026-Q2', 350000000, 290000000, 'operational'),
  ('Mill Production', '2026-Q2', 400000000, 350000000, 'operational'),
  ('HR & GA', '2026-Q2', 200000000, 165000000, 'operational'),
  ('Finance', '2026-Q2', 150000000, 140000000, 'operational'),
  ('IT Department', '2026-Q2', 250000000, 220000000, 'capital'),
  ('Safety & Compliance', '2026-Q2', 100000000, 85000000, 'operational'),
  ('Mining Operations', '2026-Q1', 500000000, 420000000, 'operational')
ON CONFLICT DO NOTHING;

-- 22. HEADCOUNT PLANS — 7
INSERT INTO headcount_plans (divisi, position, planned_count, approved_count, period, status)
VALUES
  ('Mining Operations', 'Operator Heavy Equipment', 10, 8, '2026-Q3', 'approved'),
  ('Mining Operations', 'Safety Officer', 3, 3, '2026-Q3', 'approved'),
  ('Estate Management', 'Pemanen Sawit', 20, 15, '2026-Q3', 'pending'),
  ('Mill Production', 'Operator Mesin', 8, 6, '2026-Q3', 'approved'),
  ('HR & GA', 'Staff HRD', 2, 2, '2026-Q3', 'approved'),
  ('IT Department', 'Software Developer', 3, 2, '2026-Q3', 'pending'),
  ('Finance', 'Accountant', 2, 1, '2026-Q3', 'pending')
ON CONFLICT DO NOTHING;

-- 23. BUDGET ALLOCATION — 8
INSERT INTO budget_allocation (divisi, category, amount, period, status)
VALUES
  ('Mining Operations', 'Salary', 3000000000, '2026', 'active'),
  ('Mining Operations', 'Equipment', 500000000, '2026', 'active'),
  ('Estate Management', 'Salary', 2500000000, '2026', 'active'),
  ('Mill Production', 'Salary', 2000000000, '2026', 'active'),
  ('Mill Production', 'Maintenance', 400000000, '2026', 'active'),
  ('HQ', 'Salary', 1500000000, '2026', 'active'),
  ('HQ', 'Technology', 200000000, '2026', 'active'),
  ('HQ', 'Office Supplies', 50000000, '2026', 'active')
ON CONFLICT DO NOTHING;

-- 24. SIMULATIONS — 4
INSERT INTO simulations (id, scenario_name, params_json, result_json, created_by)
VALUES
  ('SIM001', 'Best Case', '{"turnover":-5,"hiring":10}', '{"new_hc":2100,"profit":500000000}', 'ADMIN'),
  ('SIM002', 'Worst Case', '{"turnover":20,"hiring":-5}', '{"new_hc":1560,"profit":-800000000}', 'ADMIN'),
  ('SIM003', 'Status Quo', '{"turnover":0,"hiring":0}', '{"new_hc":2000,"profit":0}', 'ADMIN'),
  ('SIM004', 'Growth Mode', '{"turnover":-3,"hiring":20}', '{"new_hc":2340,"profit":1200000000}', 'ADMIN')
ON CONFLICT DO NOTHING;

-- 25. REVIEW 360 — 100
INSERT INTO review_360 (nrp, reviewer_nrp, period, score, feedback)
SELECT 
  e.nrp,
  (SELECT nrp FROM hr_org WHERE atasan_nrp = e.nrp LIMIT 1),
  '2026-Q1',
  (50 + random()*50)::int,
  (ARRAY['Good performance', 'Needs improvement', 'Excellent leadership', 'Very productive', 'Good team player'])[1 + (random()*4)::int]
FROM employees_master e
WHERE random() > 0.95
  AND e.status_kerja = 'PKWTT'
ON CONFLICT DO NOTHING;

-- 26. DISCIPLINARY — 5
INSERT INTO disciplinary_records (nrp, violation_type, severity, action_taken, incident_date)
VALUES
  ('NRP500', 'Terlambat', 'warning', 'Teguran lisan', CURRENT_DATE - 60),
  ('NRP501', 'Alpha', 'written_warning', 'Teguran tertulis', CURRENT_DATE - 45),
  ('NRP502', 'Safety Violation', 'suspension', 'Skorsing 3 hari', CURRENT_DATE - 30),
  ('NRP503', 'Terlambat', 'warning', 'Teguran lisan', CURRENT_DATE - 20),
  ('NRP504', 'Data Fraud', 'termination', 'PHK', CURRENT_DATE - 10)
ON CONFLICT DO NOTHING;

-- 27. WEBHOOK LOGS — 5
INSERT INTO webhook_logs (webhook_id, event, payload, response_status, success)
VALUES
  (1, 'leave_approved', '{"nrp":"NRP001","days":3}', 200, true),
  (1, 'kpi_alert', '{"nrp":"NRP150","kpi":45}', 200, true),
  (2, 'turnover_warning', '{"divisi":"Mining","count":5}', 200, true),
  (1, 'new_registration', '{"nrp":"NRP500"}', 200, true),
  (2, 'safety_incident', '{"type":"kecelakaan","severity":"high"}', 500, false)
ON CONFLICT DO NOTHING;

-- 28. EXTERNAL NOTIFICATION LOGS — 4
INSERT INTO external_notification_logs (channel, event, payload, success)
VALUES
  ('slack', 'leave_approved', '{"text":"NRP001 cuti disetujui"}', true),
  ('slack', 'kpi_alert', '{"text":"NRP150 KPI turun"}', true),
  ('teams', 'safety_incident', '{"text":"Insiden safety high"}', false),
  ('slack', 'turnover_warning', '{"text":"5 karyawan risk resign"}', true)
ON CONFLICT DO NOTHING;

-- ============================================================
-- SEED COMPLETE — OPTIMIZED
-- ============================================================
-- Total estimated size: ~9 MB (1.8% of 500MB free tier)
-- All tables have realistic, variative data
-- Data looks like a real palm oil/mining company
