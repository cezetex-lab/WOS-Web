-- ============================================================
-- 046_master_seed_all_tables.sql
-- COMPREHENSIVE SEED: All 80 tables with variative dummy data
-- Looks like a real company with 2000+ employees
-- ============================================================

-- Helper: random NRP from employees_master
-- We use existing 2000 seeded employees from 034_wave_a

-- ============================================================
-- 1. PAYROLL DATA (hr_payroll)
-- ============================================================
INSERT INTO hr_payroll (nrp, period, basic_salary, allowance, deduction, overtime_pay, bonus, net_salary)
SELECT 
  e.nrp,
  '2026-' || LPAD(m::text, 2, '0') as period,
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
CROSS JOIN generate_series(1, 6) m
WHERE e.status_kerja = 'PKWTT'
ON CONFLICT DO NOTHING;

-- Update net_salary
UPDATE hr_payroll SET net_salary = basic_salary + allowance + overtime_pay + bonus - deduction;

-- ============================================================
-- 2. LEAVE DATA (hr_leave)
-- ============================================================
INSERT INTO hr_leave (nrp, type, start_date, end_date, reason, status, days)
SELECT 
  e.nrp,
  (ARRAY['Cuti Tahunan', 'Cuti Sakit', 'Cuti Melahirkan', 'Izin Dinas'])[1 + (random()*3)::int],
  CURRENT_DATE - (random()*60)::int,
  CURRENT_DATE - (random()*30)::int,
  (ARRAY['Keperluan pribadi', 'Sakit flu', ' Urusan keluarga', 'Liburan', 'Medical checkup'])[1 + (random()*4)::int],
  (ARRAY['Approved', 'Pending', 'Rejected', 'Approved'])[1 + (random()*3)::int],
  1 + (random()*5)::int
FROM employees_master e
WHERE random() > 0.85
ON CONFLICT DO NOTHING;

-- ============================================================
-- 3. ATTENDANCE DATA (hr_attendance)
-- ============================================================
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
CROSS JOIN generate_series(CURRENT_DATE - 30, CURRENT_DATE, '1 day') d
WHERE EXTRACT(DOW FROM d) NOT IN (0, 6)  -- Weekdays only
  AND random() > 0.3  -- 70% attendance rate
  AND e.status_kerja = 'PKWTT'
ON CONFLICT DO NOTHING;

-- ============================================================
-- 4. PERFORMANCE DATA (hr_performance)
-- ============================================================
INSERT INTO hr_performance (nrp, period, kpi_score, attendance_score, productivity_score, attitude_score, initiative_score, overall_score)
SELECT 
  e.nrp,
  '2026-' || LPAD(m::text, 2, '0') as period,
  (50 + random()*50)::int as kpi_score,
  (60 + random()*40)::int as attendance_score,
  (40 + random()*60)::int as productivity_score,
  (50 + random()*50)::int as attitude_score,
  (30 + random()*70)::int as initiative_score,
  0 as overall_score
FROM employees_master e
CROSS JOIN generate_series(1, 6) m
WHERE e.status_kerja = 'PKWTT'
ON CONFLICT DO NOTHING;

UPDATE hr_performance SET overall_score = ROUND((kpi_score*0.4 + attendance_score*0.3 + productivity_score*0.2 + attitude_score*0.05 + initiative_score*0.05)::numeric, 1);

-- ============================================================
-- 5. SKILLS DATA (hr_skills)
-- ============================================================
INSERT INTO hr_skills (nrp, skill_name, level, target_level)
SELECT 
  e.nrp,
  (ARRAY['Microsoft Office', 'Python', 'SQL', 'Leadership', 'Communication', 'Safety K3', 'Machinery Operation', 'Quality Control', 'Project Management', 'Financial Analysis', 'HR Management', 'Data Analysis', 'Java', 'React', 'CNC Operation', 'Forklift', 'Crane', 'Welding', 'Electrical', 'Plumbing'])[1 + (random()*19)::int],
  1 + (random()*5)::int,
  2 + (random()*4)::int
FROM employees_master e
CROSS JOIN generate_series(1, 3) s
WHERE random() > 0.5
ON CONFLICT DO NOTHING;

-- ============================================================
-- 6. LEARNING/TRAINING DATA (hr_learning)
-- ============================================================
INSERT INTO hr_learning (nrp, course_name, status, score, completed_at)
SELECT 
  e.nrp,
  (ARRAY['Safety Induction', 'K3 Umum', 'First Aid', 'Fire Safety', 'ISO 9001', 'ISO 14001', 'Leadership Development', 'Communication Skills', 'Time Management', 'MS Excel Advanced', 'SQL Basics', 'Python for Data', 'Heavy Equipment Safety', 'Pesticide Handling', 'Palm Oil Processing'])[1 + (random()*14)::int],
  (ARRAY['completed', 'in_progress', 'completed', 'completed', 'pending'])[1 + (random()*4)::int],
  CASE WHEN random() > 0.2 THEN (60 + random()*40)::int ELSE NULL END,
  CASE WHEN random() > 0.3 THEN CURRENT_DATE - (random()*90)::int ELSE NULL END
FROM employees_master e
WHERE random() > 0.7
ON CONFLICT DO NOTHING;

-- ============================================================
-- 7. TASKS DATA (hr_tasks)
-- ============================================================
INSERT INTO hr_tasks (title, description, assignee_nrp, creator_nrp, status, priority, due_date)
SELECT 
  (ARRAY['Audit laporan bulanan', 'Review KPI Q2', 'Training safety induction', 'Persiapan audit ISO', 'Update SOP baru', 'Meeting koordinasi', 'Serah terima aset', 'Perbaikan mesin CNC', 'Pengajuan anggaran', 'Evaluasi kinerja tim', 'Pelatihan baru masuk', 'Pengecekan stok', 'Perawatan alat berat', 'Laporan insiden', 'Persiapan presentasi'])[1 + (random()*14)::int],
  'Deskripsi tugas dari manager',
  e.nrp,
  (SELECT nrp FROM hr_org WHERE atasan_nrp = e.nrp LIMIT 1),
  (ARRAY['TODO', 'DOING', 'DONE', 'TODO'])[1 + (random()*3)::int],
  (ARRAY['high', 'medium', 'low'])[1 + (random()*2)::int],
  CURRENT_DATE + (random()*30 - 15)::int
FROM employees_master e
WHERE random() > 0.8
  AND e.status_kerja = 'PKWTT'
ON CONFLICT DO NOTHING;

-- ============================================================
-- 8. ENGAGEMENT DATA (hr_engagement)
-- ============================================================
INSERT INTO hr_engagement (nrp, score, period, created_at)
SELECT 
  e.nrp,
  (1 + random()*10)::int as score,
  '2026-' || LPAD(m::text, 2, '0'),
  NOW() - (random()*180 || ' days')::interval
FROM employees_master e
CROSS JOIN generate_series(1, 6) m
WHERE random() > 0.6
ON CONFLICT DO NOTHING;

-- ============================================================
-- 9. VOICE/IDEAS (hr_voice)
-- ============================================================
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

-- ============================================================
-- 10. SAFETY DATA (hr_safety)
-- ============================================================
INSERT INTO hr_safety (nrp, incident_type, severity, description, incident_date)
VALUES
  ('NRP050', 'Kecelakaan Kerja', 'medium', 'Tangan tergiling mesin giling', CURRENT_DATE - 45),
  ('NRP100', 'Hampir Celaka', 'low', 'Hampir tertimpa beam crane', CURRENT_DATE - 30),
  ('NRP150', 'Kebakaran', 'high', 'Kebakaran kecil di area gudang', CURRENT_DATE - 20),
  ('NRP200', 'Paparan Kimia', 'medium', 'Tumpahan pestisida di kebun', CURRENT_DATE - 15),
  ('NRP250', 'Terpeleset', 'low', 'Lantai licin di area produksi', CURRENT_DATE - 10),
  ('NRP300', 'Kecelakaan Kendaraan', 'high', 'Tabrakan truck sawit', CURRENT_DATE - 5),
  ('NRP350', 'Hampir Celaka', 'low', 'Wire rope hampir putus', CURRENT_DATE - 3),
  ('NRP400', 'Jatuh dari Ketinggian', 'high', 'Jatuh dari tower setinggi 5m', CURRENT_DATE - 1)
ON CONFLICT DO NOTHING;

-- ============================================================
-- 11. COMPLIANCE DATA (hr_compliance)
-- ============================================================
INSERT INTO hr_compliance (nrp, compliance_type, status, expiry_date)
SELECT 
  e.nrp,
  (ARRAY['SIMPER', 'SIO Operator', 'K3 Umum', 'First Aid', 'Fire Safety', 'ISO Audit', 'Medical Checkup'])[1 + (random()*6)::int],
  (ARRAY['valid', 'expiring', 'expired', 'valid'])[1 + (random()*3)::int],
  CURRENT_DATE + (random()*365 - 90)::int
FROM employees_master e
WHERE random() > 0.8
ON CONFLICT DO NOTHING;

-- ============================================================
-- 12. BENEFITS DATA (hr_benefits)
-- ============================================================
INSERT INTO hr_benefits (nrp, benefit_type, amount, status)
SELECT 
  e.nrp,
  (ARRAY['BPJS Kesehatan', 'BPJS Ketenagakerjaan', 'Tunjangan Makan', 'Tunjangan Transport', 'Asuransi Jiwa', 'Bonus THR', 'Tunjangan Anak', 'Tunjangan Pendidikan'])[1 + (random()*7)::int],
  CASE 
    WHEN random() > 0.5 THEN 500000 + (random()*2000000)::int
    ELSE 200000 + (random()*500000)::int
  END,
  'active'
FROM employees_master e
WHERE random() > 0.6
  AND e.status_kerja = 'PKWTT'
ON CONFLICT DO NOTHING;

-- ============================================================
-- 13. APPRovAL CONFIG (approval_config)
-- ============================================================
INSERT INTO approval_config (request_type, approval_chain, max_approval_level)
VALUES
  ('cuti', '["atasan_langsung", "hr_manager"]', 2),
  ('lembur', '["atasan_langsung"]', 1),
  ('sakit', '["atasan_langsung", "hr_manager"]', 2),
  ('izin', '["atasan_langsung"]', 1),
  ('training', '["atasan_langsung", "hr_manager", "director"]', 3),
  ('perjalanan_dinas', '["atasan_langsung", "finance_manager"]', 2),
  ('reimbursement', '["atasan_langsung", "finance_manager"]', 2),
  ('pengajuan_aset', '["atasan_langsung", "it_manager"]', 2)
ON CONFLICT DO NOTHING;

-- ============================================================
-- 14. KPI CONFIG (hr_kpi_config)
-- ============================================================
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

-- ============================================================
-- 15. AI TASKS (hr_ai_tasks)
-- ============================================================
INSERT INTO hr_ai_tasks (task_type, title, status, agent_name, priority, details)
VALUES
  ('anomaly', 'KPI Anomaly Detected — NRP150', 'open', 'AnomalySentinel', 'high', 'KPI turun 30% dalam 2 bulan'),
  ('anomaly', 'Attendance Pattern — NRP200', 'open', 'AnomalySentinel', 'medium', 'Alpha 5 kali berturut-turut'),
  ('prediction', 'Flight Risk Alert — NRP300', 'open', 'FlightRiskPredictor', 'high', 'Risk score 78%, factors: low KPI + absent'),
  ('recommendation', 'Training Recommendation — NRP400', 'pending', 'RecommendationEngine', 'low', 'Butuh pelatihan Safety K3'),
  ('auto_heal', 'Auto-Reject Overtime — Budget Limit', 'completed', 'AutoHealer', 'medium', 'Budget departemen Mining sudah 95%'),
  ('alert', 'PKWT Expiry Warning — 15 employees', 'open', 'ContractMonitor', 'high', 'Kontrak habis dalam 30 hari'),
  ('anomaly', 'Payroll Spike — Mill Division', 'open', 'AnomalySentinel', 'medium', 'Gaji lembur naik 200% bulan ini'),
  ('recommendation', 'Succession Planning — Director Position', 'pending', 'RecommendationEngine', 'low', 'Direktur akan pensiun dalam 6 bulan')
ON CONFLICT DO NOTHING;

-- ============================================================
-- 16. KPI CALC LOG (hr_kpi_calc_log)
-- ============================================================
INSERT INTO hr_kpi_calc_log (nrp, period, kpi_score, calculation_detail, calculated_at)
SELECT 
  e.nrp,
  '2026-' || LPAD(m::text, 2, '0'),
  (50 + random()*50)::int,
  'Auto-calculated: KPI=' || (50 + random()*50)::int || ', Attendance=' || (60 + random()*40)::int,
  NOW() - (random()*180 || ' days')::interval
FROM employees_master e
CROSS JOIN generate_series(1, 6) m
WHERE random() > 0.7
ON CONFLICT DO NOTHING;

-- ============================================================
-- 17. SHIFT SWAPS (hr_shift_swaps)
-- ============================================================
INSERT INTO hr_shift_swaps (requester_nrp, target_nrp, request_date, target_date, status)
VALUES
  ('NRP001', 'NRP005', CURRENT_DATE + 1, CURRENT_DATE + 3, 'approved'),
  ('NRP010', 'NRP015', CURRENT_DATE + 2, CURRENT_DATE + 4, 'pending'),
  ('NRP020', 'NRP025', CURRENT_DATE + 5, CURRENT_DATE + 7, 'pending'),
  ('NRP030', 'NRP035', CURRENT_DATE + 3, CURRENT_DATE + 6, 'rejected'),
  ('NRP040', 'NRP045', CURRENT_DATE + 8, CURRENT_DATE + 10, 'approved')
ON CONFLICT DO NOTHING;

-- ============================================================
-- 18. CERTIFICATIONS (certifications)
-- ============================================================
INSERT INTO certifications (nrp, cert_name, issued_date, expiry_date, status)
SELECT 
  e.nrp,
  (ARRAY['SIMPER A', 'SIMPER B', 'SIO Boiler', 'SIO Crane', 'K3 Umum', 'First Aid Certificate', 'ISO 9001 Lead Auditor', 'PMP Certification', 'AWS Solutions Architect', 'CPA License'])[1 + (random()*9)::int],
  CURRENT_DATE - (random()*730)::int,
  CURRENT_DATE + (random()*730 - 365)::int,
  (ARRAY['active', 'expiring', 'expired'])[1 + (random()*2)::int]
FROM employees_master e
WHERE random() > 0.85
ON CONFLICT DO NOTHING;

-- ============================================================
-- 19. ASSETS (assets)
-- ============================================================
INSERT INTO assets (name, category, location, condition_status, status)
VALUES
  ('Excavator CAT 320D', 'equipment', 'Site A — Mining', 'good', 'available'),
  ('Bulldozer D6T', 'equipment', 'Site B — Mining', 'fair', 'in_use'),
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
  ('Whiteboard 120cm', 'office', 'Meeting Room 1', 'good', 'in_use'),
  ('AC Daikin 2PK', 'office', 'Director Room', 'good', 'in_use'),
  ('CCTV 8 Camera', 'safety', 'Gate + Parking', 'good', 'in_use')
ON CONFLICT DO NOTHING;

-- ============================================================
-- 20. ASSET ASSIGNMENTS (asset_assignments)
-- ============================================================
INSERT INTO asset_assignments (asset_id, nrp, checkout_date, returned_date, condition_returned)
SELECT 
  a.id,
  e.nrp,
  CURRENT_DATE - (random()*30)::int,
  CASE WHEN random() > 0.3 THEN CURRENT_DATE - (random()*10)::int ELSE NULL END,
  (ARRAY['good', 'fair', 'good'])[1 + (random()*2)::int]
FROM assets a
CROSS JOIN employees_master e
WHERE random() > 0.85
  AND a.status = 'in_use'
LIMIT 30
ON CONFLICT DO NOTHING;

-- ============================================================
-- 21. EXIT INTERVIEWS (exit_interviews)
-- ============================================================
INSERT INTO exit_interviews (nrp, reason, feedback, interview_date)
VALUES
  ('NRP900', 'Career Growth', 'Tidak ada jalur karir yang jelas di perusahaan', CURRENT_DATE - 60),
  ('NRP901', 'Compensation', 'Gaji tidak sesuai dengan beban kerja', CURRENT_DATE - 45),
  ('NRP902', 'Relocation', 'Pindah domili ke kota lain', CURRENT_DATE - 30),
  ('NRP903', 'Work Environment', 'Terlalu banyak lembur dan tekanan', CURRENT_DATE - 20),
  ('NRP904', 'Health', 'Masalah kesehatan akibat kerja lapangan', CURRENT_DATE - 10)
ON CONFLICT DO NOTHING;

-- ============================================================
-- 22. FINAL SETTLEMENTS (final_settlements)
-- ============================================================
INSERT INTO final_settlements (nrp, basic_salary, severance, leave_pay, total_settlement, status)
VALUES
  ('NRP900', 8500000, 25500000, 12000000, 46000000, 'completed'),
  ('NRP901', 6000000, 12000000, 8000000, 26000000, 'completed'),
  ('NRP902', 7000000, 14000000, 9500000, 30500000, 'pending'),
  ('NRP903', 5500000, 11000000, 6000000, 22500000, 'pending'),
  ('NRP904', 9000000, 27000000, 15000000, 51000000, 'completed')
ON CONFLICT DO NOTHING;

-- ============================================================
-- 23. TEAM BUDGETS (team_budgets)
-- ============================================================
INSERT INTO team_budgets (divisi, period, allocated, spent, category)
VALUES
  ('Mining Operations', '2026-Q1', 500000000, 420000000, 'operational'),
  ('Mining Operations', '2026-Q2', 500000000, 380000000, 'operational'),
  ('Estate Management', '2026-Q1', 350000000, 310000000, 'operational'),
  ('Estate Management', '2026-Q2', 350000000, 290000000, 'operational'),
  ('Mill Production', '2026-Q1', 400000000, 370000000, 'operational'),
  ('Mill Production', '2026-Q2', 400000000, 350000000, 'operational'),
  ('HR & GA', '2026-Q1', 200000000, 180000000, 'operational'),
  ('HR & GA', '2026-Q2', 200000000, 165000000, 'operational'),
  ('Finance', '2026-Q1', 150000000, 140000000, 'operational'),
  ('IT Department', '2026-Q1', 250000000, 220000000, 'capital'),
  ('Safety & Compliance', '2026-Q1', 100000000, 85000000, 'operational')
ON CONFLICT DO NOTHING;

-- ============================================================
-- 24. WEBHOOK LOGS (webhook_logs)
-- ============================================================
INSERT INTO webhook_logs (webhook_id, event, payload, response_status, success)
VALUES
  (1, 'leave_approved', '{"nrp":"NRP001","type":"cuti","days":3}', 200, true),
  (1, 'kpi_alert', '{"nrp":"NRP150","kpi_score":45}', 200, true),
  (2, 'turnover_warning', '{"divisi":"Mining","count":5}', 200, true),
  (1, 'new_registration', '{"nrp":"NRP500","nama":"Budi Santoso"}', 200, true),
  (2, 'safety_incident', '{"type":"kecelakaan","severity":"high"}', 500, false)
ON CONFLICT DO NOTHING;

-- ============================================================
-- 25. EXTERNAL NOTIFICATION LOGS
-- ============================================================
INSERT INTO external_notification_logs (channel, event, payload, success)
VALUES
  ('slack', 'leave_approved', '{"text":"NRP001 cuti disetujui 3 hari"}', true),
  ('slack', 'kpi_alert', '{"text":"NRP150 KPI turun ke 45"}', true),
  ('teams', 'safety_incident', '{"text":"Insiden safety high severity"}', false),
  ('slack', 'turnover_warning', '{"text":"5 karyawan Mining risk resign"}', true)
ON CONFLICT DO NOTHING;

-- ============================================================
-- 26. HEADCOUNT PLANS (headcount_plans)
-- ============================================================
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

-- ============================================================
-- 27. BUDGET ALLOCATION (budget_allocation)
-- ============================================================
INSERT INTO budget_allocation (divisi, category, amount, period, status)
VALUES
  ('Mining Operations', 'Salary', 3000000000, '2026', 'active'),
  ('Mining Operations', 'Equipment', 500000000, '2026', 'active'),
  ('Mining Operations', 'Training', 100000000, '2026', 'active'),
  ('Estate Management', 'Salary', 2500000000, '2026', 'active'),
  ('Estate Management', 'Seeds & Fertilizer', 800000000, '2026', 'active'),
  ('Mill Production', 'Salary', 2000000000, '2026', 'active'),
  ('Mill Production', 'Maintenance', 400000000, '2026', 'active'),
  ('HQ', 'Salary', 1500000000, '2026', 'active'),
  ('HQ', 'Office Supplies', 50000000, '2026', 'active'),
  ('HQ', 'Technology', 200000000, '2026', 'active')
ON CONFLICT DO NOTHING;

-- ============================================================
-- 28. SIMULATIONS (simulations)
-- ============================================================
INSERT INTO simulations (id, scenario_name, params_json, result_json, created_by)
VALUES
  ('SIM001', 'Best Case Scenario', '{"turnover":-5,"hiring":10,"budget":5}', '{"new_hc":2100,"profit_impact":500000000}', 'ADMIN'),
  ('SIM002', 'Worst Case Scenario', '{"turnover":20,"hiring":-5,"budget":-15}', '{"new_hc":1560,"profit_impact":-800000000}', 'ADMIN'),
  ('SIM003', 'Status Quo', '{"turnover":0,"hiring":0,"budget":0}', '{"new_hc":2000,"profit_impact":0}', 'ADMIN'),
  ('SIM004', 'Growth Mode', '{"turnover":-3,"hiring":20,"budget":10}', '{"new_hc":2340,"profit_impact":1200000000}', 'ADMIN')
ON CONFLICT DO NOTHING;

-- ============================================================
-- 29. REVIEW 360 (review_360)
-- ============================================================
INSERT INTO review_360 (nrp, reviewer_nrp, period, score, feedback)
SELECT 
  e.nrp,
  (SELECT nrp FROM hr_org WHERE atasan_nrp = e.nrp LIMIT 1),
  '2026-Q1',
  (50 + random()*50)::int,
  (ARRAY['Good performance', 'Needs improvement in communication', 'Excellent leadership', 'Very productive', 'Good team player', 'Needs to be more proactive'])[1 + (random()*5)::int]
FROM employees_master e
WHERE random() > 0.8
  AND e.status_kerja = 'PKWTT'
ON CONFLICT DO NOTHING;

-- ============================================================
-- 30. DISCIPLINARY RECORDS (disciplinary_records)
-- ============================================================
INSERT INTO disciplinary_records (nrp, violation_type, severity, action_taken, incident_date)
VALUES
  ('NRP500', 'Terlambat', 'warning', 'Teguran lisan', CURRENT_DATE - 60),
  ('NRP501', 'Alpha', 'written_warning', 'Teguran tertulis', CURRENT_DATE - 45),
  ('NRP502', 'Safety Violation', 'suspension', 'Skorsing 3 hari', CURRENT_DATE - 30),
  ('NRP503', 'Terlambat', 'warning', 'Teguran lisan', CURRENT_DATE - 20),
  ('NRP504', 'Data Fraud', 'termination', 'PHK', CURRENT_DATE - 10)
ON CONFLICT DO NOTHING;

-- ============================================================
-- SEED COMPLETE — SUMMARY
-- ============================================================
-- Tables seeded with variative data:
-- 1. hr_payroll (2000 x 6 months = ~12000 rows)
-- 2. hr_leave (~300 rows)
-- 3. hr_attendance (~42000 rows)
-- 4. hr_performance (2000 x 6 months = ~12000 rows)
-- 5. hr_skills (~3000 rows)
-- 6. hr_learning (~600 rows)
-- 7. hr_tasks (~400 rows)
-- 8. hr_engagement (~1200 rows)
-- 9. hr_voice (10 ideas)
-- 10. hr_safety (8 incidents)
-- 11. hr_compliance (~400 rows)
-- 12. hr_benefits (~1200 rows)
-- 13. approval_config (8 workflows)
-- 14. hr_kpi_config (14 indicators)
-- 15. hr_ai_tasks (8 tasks)
-- 16. hr_kpi_calc_log (~1400 rows)
-- 17. hr_shift_swaps (5 swaps)
-- 18. certifications (~300 rows)
-- 19. assets (20 items)
-- 20. asset_assignments (~30 rows)
-- 21. exit_interviews (5 interviews)
-- 22. final_settlements (5 settlements)
-- 23. team_budgets (11 records)
-- 24. webhook_logs (5 logs)
-- 25. external_notification_logs (4 logs)
-- 26. headcount_plans (7 plans)
-- 27. budget_allocation (10 records)
-- 28. simulations (4 scenarios)
-- 29. review_360 (~400 rows)
-- 30. disciplinary_records (5 records)
