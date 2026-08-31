-- ============================================================
-- 053_seed_remaining_tables.sql
-- Seed data lengkap untuk semua tabel yang belum terisi
-- agar semua admin page TIDAK kosong.
-- ============================================================

-- ════════════════════════════════════════════════════════════
-- A. RECRUITMENT — vacancies, candidate_pipeline
-- ════════════════════════════════════════════════════════════
INSERT INTO vacancies (id, position, department, quota, qualifications, status) VALUES
  ('VAC-001', 'Mining Engineer', 'MINING', 3, 'S1 Teknik Pertambangan, 3yr exp', 'OPEN'),
  ('VAC-002', 'Heavy Equipment Operator', 'MINING', 5, 'SIM A/B, 2yr experience', 'OPEN'),
  ('VAC-003', 'Palm Oil Mill Supervisor', 'MILL', 2, 'S1 Agroteknologi, 5yr exp', 'OPEN'),
  ('VAC-004', 'Quality Control Analyst', 'MILL', 3, 'S1 Kimia/Teknologi Pangan', 'OPEN'),
  ('VAC-005', 'Estate Manager', 'ESTATE', 2, 'S1 Perkebunan, 7yr exp', 'OPEN'),
  ('VAC-006', 'Field Assistant (Asisten Kebun)', 'ESTATE', 4, 'D3 Perkebunan, 2yr exp', 'OPEN'),
  ('VAC-007', 'HR Staff', 'HQ', 1, 'S1 Psikologi/Manajemen HR', 'OPEN'),
  ('VAC-008', 'Finance Analyst', 'HQ', 2, 'S1 Akuntansi, 3yr exp', 'OPEN'),
  ('VAC-009', 'Safety Officer (K3)', 'MINING', 2, 'S1 K3, AK3 Umum', 'CLOSED'),
  ('VAC-010', 'IT Support', 'HQ', 1, 'D3 Teknik Informatika', 'OPEN')
ON CONFLICT (id) DO NOTHING;

INSERT INTO candidate_pipeline (id, vacancy_id, nrp, nama, email, stage, notes) VALUES
  ('CP-001', 'VAC-001', NULL, 'Rizki Pratama', 'rizki@gmail.com', 'INTERVIEW', 'Wawancara technical 28 Aug'),
  ('CP-002', 'VAC-001', NULL, 'Andi Saputra', 'andi@gmail.com', 'SCREENING', 'Verifikasi dokumen'),
  ('CP-003', 'VAC-002', NULL, 'Budi Hartono', 'budi@gmail.com', 'OFFER', 'Negosiasi gaji'),
  ('CP-004', 'VAC-002', NULL, 'Dedi Kurniawan', 'dedi@gmail.com', 'APPLIED', 'Lamaran masuk 25 Aug'),
  ('CP-005', 'VAC-003', NULL, 'Siti Nurhaliza', 'siti@gmail.com', 'HIRED', 'Sudah join 1 Sep'),
  ('CP-006', 'VAC-003', NULL, 'Rina Wati', 'rina@gmail.com', 'INTERVIEW', 'Wawancara HR 29 Aug'),
  ('CP-007', 'VAC-004', NULL, 'Ahmad Fauzi', 'ahmad@gmail.com', 'APPLIED', 'Fresh graduate UI'),
  ('CP-008', 'VAC-005', NULL, 'Hendra Wijaya', 'hendra@gmail.com', 'OFFER', 'Butuh konfirmasi'),
  ('CP-009', 'VAC-006', NULL, 'Maya Putri', 'maya@gmail.com', 'SCREENING', 'Background check'),
  ('CP-010', 'VAC-007', NULL, 'Dewi Sari', 'dewi@gmail.com', 'INTERVIEW', 'Psikotes selesai'),
  ('CP-011', 'VAC-008', NULL, 'Fajar Nugroho', 'fajar@gmail.com', 'APPLIED', 'Lamaran 27 Aug'),
  ('CP-012', 'VAC-009', NULL, 'Hadi Susanto', 'hadi@gmail.com', 'HIRED', 'AK3 certified'),
  ('CP-013', 'VAC-010', NULL, 'Yoga Pratama', 'yoga@gmail.com', 'SCREENING', 'Technical test passed'),
  ('CP-014', 'VAC-001', NULL, 'Tono Sugiarto', 'tono@gmail.com', 'APPLIED', 'Exp 5yr di PT Freeport'),
  ('CP-015', 'VAC-002', NULL, 'Sugeng Riyadi', 'sugeng@gmail.com', 'REJECTED', 'Tidak memenuhi kualifikasi')
ON CONFLICT (id) DO NOTHING;

-- ════════════════════════════════════════════════════════════
-- B. SELF-SERVICE — travel_requests, reimbursements, approval
-- ════════════════════════════════════════════════════════════
INSERT INTO travel_requests (id, nrp, destination, purpose, start_date, end_date, estimated_cost, status, per_diem) VALUES
  ('TRV-001', 'NRP001', 'Jakarta', 'Meeting kantor pusat', '2026-09-01', '2026-09-03', 5000000, 'APPROVED', 750000),
  ('TRV-002', 'NRP002', 'Balikpapan', 'Audit site tambang', '2026-09-05', '2026-09-07', 8000000, 'PENDING', 800000),
  ('TRV-003', 'NRP003', 'Medan', 'Training HR leadership', '2026-09-10', '2026-09-12', 6000000, 'APPROVED', 700000),
  ('TRV-004', 'NRP004', 'Palangkaraya', 'Inspeksi kebun Estate', '2026-09-15', '2026-09-16', 4000000, 'PENDING', 600000),
  ('TRV-005', 'NRP005', 'Banjarmasin', 'Kunjungan vendor mesin', '2026-09-20', '2026-09-22', 7000000, 'REJECTED', 700000),
  ('TRV-006', 'NRP006', 'Samarinda', 'Workshop K3 tambang', '2026-09-08', '2026-09-09', 3500000, 'APPROVED', 650000),
  ('TRV-007', 'NRP007', 'Pontianak', 'Negosiasi kontrak supplier', '2026-09-12', '2026-09-14', 5500000, 'PENDING', 600000),
  ('TRV-008', 'NRP008', 'Makassar', 'Presentasi Q3 results', '2026-09-18', '2026-09-19', 4500000, 'APPROVED', 700000)
ON CONFLICT (id) DO NOTHING;

INSERT INTO reimbursements (id, nrp, travel_id, category, amount, status) VALUES
  ('REIM-001', 'NRP001', 'TRV-001', 'Transport', 2500000, 'APPROVED'),
  ('REIM-002', 'NRP001', 'TRV-001', 'Hotel', 1500000, 'APPROVED'),
  ('REIM-003', 'NRP002', 'TRV-002', 'Transport', 3000000, 'PENDING'),
  ('REIM-004', 'NRP003', 'TRV-003', 'Training Fee', 2000000, 'APPROVED'),
  ('REIM-005', 'NRP003', 'TRV-003', 'Hotel', 1200000, 'PENDING'),
  ('REIM-006', 'NRP006', 'TRV-006', 'Transport', 1800000, 'APPROVED'),
  ('REIM-007', 'NRP008', 'TRV-008', 'Transport', 2200000, 'PENDING'),
  ('REIM-008', 'NRP008', 'TRV-008', 'Meal', 500000, 'PENDING'),
  ('REIM-009', 'NRP004', NULL, 'Medical', 750000, 'APPROVED'),
  ('REIM-010', 'NRP005', NULL, 'Office Supply', 350000, 'REJECTED')
ON CONFLICT (id) DO NOTHING;

INSERT INTO approval_instances (id, request_id, approver_nrp, level, status, note) VALUES
  ('APR-001', 'TRV-001', 'NRP010', 1, 'APPROVED', 'Disetujui manager langsung'),
  ('APR-002', 'TRV-001', 'NRP001', 2, 'APPROVED', 'Disetujui director'),
  ('APR-003', 'TRV-002', 'NRP011', 1, 'PENDING', 'Menunggu approval'),
  ('APR-004', 'TRV-003', 'NRP010', 1, 'APPROVED', 'OK'),
  ('APR-005', 'TRV-004', 'NRP012', 1, 'PENDING', 'Dalam review'),
  ('APR-006', 'TRV-005', 'NRP010', 1, 'REJECTED', 'Budget tidak mencukupi'),
  ('APR-007', 'TRV-006', 'NRP011', 1, 'APPROVED', 'Workshop penting'),
  ('APR-008', 'TRV-007', 'NRP010', 1, 'PENDING', 'Menunggu konfirmasi')
ON CONFLICT (id) DO NOTHING;

-- ════════════════════════════════════════════════════════════
-- C. PERFORMANCE — performance_notes, okrs (table 018), incentives
-- ════════════════════════════════════════════════════════════
INSERT INTO performance_notes (nrp, author_nrp, note_type, content) VALUES
  ('NRP001', 'NRP010', 'PRAISE', 'Excellent leadership in Q3 mining expansion project. Exceeded production target by 15%.'),
  ('NRP002', 'NRP010', 'FEEDBACK', 'Good attendance record. Need to improve time management for report submissions.'),
  ('NRP003', 'NRP010', 'PRAISE', 'Outstanding KPI performance. Consistently top performer in the division.'),
  ('NRP004', 'NRP011', 'WARNING', 'Frequent late arrivals in August. Please improve punctuality.'),
  ('NRP005', 'NRP010', 'FEEDBACK', 'Solid technical skills. Recommend for advanced safety training.'),
  ('NRP006', 'NRP011', 'PRAISE', 'Innovative cost-saving idea saved Rp 50M in maintenance budget.'),
  ('NRP007', 'NRP010', 'FEEDBACK', 'Good team collaboration. Consider for team lead promotion.'),
  ('NRP008', 'NRP011', 'PRAISE', 'Quick learner. Completed onboarding 2 weeks ahead of schedule.'),
  ('NRP009', 'NRP010', 'FEEDBACK', 'Needs to improve documentation skills. Attend writing workshop.'),
  ('NRP010', 'NRP001', 'PRAISE', 'Strong management skills. Team targets consistently met.'),
  ('MLL0001', 'NRP010', 'FEEDBACK', 'Boiler efficiency improved 3% this month. Good initiative.'),
  ('MLL0002', 'NRP010', 'PRAISE', 'Zero safety incidents for 90 consecutive days.'),
  ('MIN0001', 'NRP010', 'FEEDBACK', 'Production output exceeds daily target. Keep up the good work.'),
  ('MIN0002', 'NRP010', 'WARNING', 'Equipment maintenance overdue. Schedule PM immediately.'),
  ('EST0001', 'NRP011', 'PRAISE', 'Highest TBS yield in the estate this quarter.')
ON CONFLICT DO NOTHING;

-- OKRs (table 018)
INSERT INTO okrs (id, nrp, period, objective, key_result, target_value, actual_value, status) VALUES
  ('OKR-001', 'NRP001', '2026-Q3', 'Tingkatkan Revenue Mining 15%', 'Coal output 50K ton', 50000, 48500, 'ON_TRACK'),
  ('OKR-002', 'NRP001', '2026-Q3', 'Reduce Cost per Ton 10%', 'OPEX reduction', 10, 7.5, 'ON_TRACK'),
  ('OKR-003', 'NRP002', '2026-Q3', 'Zero Fatigue Incident', 'Fatigue reports = 0', 0, 2, 'AT_RISK'),
  ('OKR-004', 'NRP003', '2026-Q3', 'Estate Yield +20%', 'TBS yield per hectare', 20, 22, 'ON_TRACK'),
  ('OKR-005', 'NRP004', '2026-Q3', 'Improve Employee Engagement', 'eNPS score 70+', 70, 65, 'AT_RISK'),
  ('OKR-006', 'NRP005', '2026-Q3', 'ISO 45001 Certification', 'Complete all clauses', 100, 60, 'BEHIND'),
  ('OKR-007', 'NRP006', '2026-Q3', 'Reduce Turnover Rate', 'Turnover < 5%', 5, 8, 'BEHIND'),
  ('OKR-008', 'NRP007', '2026-Q3', 'MILL Efficiency 95%', 'Boiler efficiency target', 95, 93, 'ON_TRACK'),
  ('OKR-009', 'NRP008', '2026-Q3', 'Employee Satisfaction', 'Survey score 80+', 80, 82, 'ON_TRACK'),
  ('OKR-010', 'MLL0001', '2026-Q3', 'Boiler Downtime < 2%', 'Downtime hours', 2, 1.5, 'ON_TRACK'),
  ('OKR-011', 'MLL0002', '2026-Q3', 'Zero Safety Incident', 'Accident count', 0, 0, 'ON_TRACK'),
  ('OKR-012', 'MIN0001', '2026-Q3', 'Coal Output 60K ton', 'Monthly production', 60000, 55000, 'ON_TRACK'),
  ('OKR-013', 'MIN0002', '2026-Q3', 'Equipment Availability 90%', 'Uptime percentage', 90, 87, 'AT_RISK'),
  ('OKR-014', 'EST0001', '2026-Q3', 'Yield per Hectare 25 ton', 'TBS production', 25, 27, 'ON_TRACK'),
  ('OKR-015', 'NRP009', '2026-Q3', 'Complete K3 Audit', 'Audit checklist 100%', 100, 75, 'ON_TRACK'),
  ('OKR-016', 'NRP010', '2026-Q3', 'Build 100+ page HRIS', 'Feature completion', 100, 85, 'ON_TRACK'),
  ('OKR-017', 'NRP011', '2026-Q3', 'Payroll Accuracy 100%', 'Zero errors', 100, 98, 'ON_TRACK'),
  ('OKR-018', 'NRP012', '2026-Q3', 'Training Completion 90%', 'All staff trained', 90, 72, 'AT_RISK'),
  ('OKR-019', 'NRP002', '2026-Q3', 'Safety Training 100%', 'All miners trained', 100, 88, 'ON_TRACK'),
  ('OKR-020', 'NRP003', '2026-Q3', 'Harvest Planning Accuracy', 'Plan vs actual', 95, 97, 'ON_TRACK')
ON CONFLICT (id) DO NOTHING;

-- Incentives
INSERT INTO incentives (id, nrp, period, base_amount, kpi_factor, team_factor, final_amount, status) VALUES
  ('INC-001', 'NRP001', '2026-08', 5000000, 1.2, 1.1, 6600000, 'PAID'),
  ('INC-002', 'NRP002', '2026-08', 4500000, 1.1, 1.0, 4950000, 'PAID'),
  ('INC-003', 'NRP003', '2026-08', 4000000, 1.3, 1.2, 6240000, 'PAID'),
  ('INC-004', 'NRP004', '2026-08', 3500000, 1.0, 1.0, 3500000, 'CALCULATED'),
  ('INC-005', 'NRP005', '2026-08', 4200000, 0.9, 1.1, 4158000, 'CALCULATED'),
  ('INC-006', 'NRP006', '2026-08', 3800000, 1.15, 1.05, 4603500, 'PAID'),
  ('INC-007', 'MLL0001', '2026-08', 3200000, 1.25, 1.1, 4400000, 'PAID'),
  ('INC-008', 'MLL0002', '2026-08', 3000000, 1.3, 1.15, 4485000, 'PAID'),
  ('INC-009', 'MIN0001', '2026-08', 3500000, 1.2, 1.1, 4620000, 'CALCULATED'),
  ('INC-010', 'EST0001', '2026-08', 3300000, 1.15, 1.05, 4007250, 'PAID')
ON CONFLICT (id) DO NOTHING;

-- ════════════════════════════════════════════════════════════
-- D. TALENT — certifications, badges, employee_mutations
-- ════════════════════════════════════════════════════════════
INSERT INTO certifications (id, nrp, cert_name, issuer, issue_date, expiry_date, status) VALUES
  ('CERT-001', 'NRP001', 'AK3 Umum', 'Kemnaker', '2024-01-15', '2027-01-15', 'ACTIVE'),
  ('CERT-002', 'NRP002', 'Sertifikat Kompetensi Operator Alat Berat', 'BNSP', '2023-06-01', '2026-06-01', 'EXPIRED'),
  ('CERT-003', 'NRP003', 'ISO 9001 Lead Auditor', 'IRCA', '2024-03-20', '2027-03-20', 'ACTIVE'),
  ('CERT-004', 'NRP004', 'Certified Human Resource Professional', 'SHRM', '2023-09-10', '2026-09-10', 'ACTIVE'),
  ('CERT-005', 'NRP005', 'Sertifikat Ahli K3 Lingkungan Kerja', 'Kemnaker', '2024-05-15', '2027-05-15', 'ACTIVE'),
  ('CERT-006', 'NRP006', 'PMP (Project Management Professional)', 'PMI', '2023-11-01', '2026-11-01', 'ACTIVE'),
  ('CERT-007', 'MLL0001', 'Operator Boiler Bersertifikat', 'BNSP', '2024-02-10', '2027-02-10', 'ACTIVE'),
  ('CERT-008', 'MLL0002', 'Sertifikat K3 Boiler', 'Kemnaker', '2023-08-20', '2026-08-20', 'EXPIRED'),
  ('CERT-009', 'MIN0001', 'Blast Manager Certificate', 'BOMBA', '2024-04-01', '2027-04-01', 'ACTIVE'),
  ('CERT-010', 'NRP007', 'SAP HR Module Certified', 'SAP', '2024-01-01', '2027-01-01', 'ACTIVE'),
  ('CERT-011', 'NRP008', 'Financial Analyst (CFA Level 1)', 'CFA Institute', '2023-07-15', '2026-07-15', 'EXPIRED'),
  ('CERT-012', 'NRP009', 'ISO 14001 Internal Auditor', 'IRCA', '2024-06-01', '2027-06-01', 'ACTIVE'),
  ('CERT-013', 'MLL0003', 'QC Analyst Palm Oil', 'MPOB', '2024-02-15', '2027-02-15', 'ACTIVE'),
  ('CERT-014', 'NRP010', 'Full Stack Developer', 'freeCodeCamp', '2023-12-01', '2028-12-01', 'ACTIVE'),
  ('CERT-015', 'EST0001', 'Sertifikat Agronom Sawit', 'ISPO', '2024-03-01', '2027-03-01', 'ACTIVE')
ON CONFLICT (id) DO NOTHING;

INSERT INTO badges (id, nrp, badge_name, badge_type, points, awarded_date) VALUES
  ('BDG-001', 'NRP001', 'Safety Champion', 'SAFETY', 500, '2026-08-01'),
  ('BDG-002', 'NRP002', 'Top Performer Q2', 'PERFORMANCE', 300, '2026-07-15'),
  ('BDG-003', 'NRP003', 'Innovation Award', 'INNOVATION', 400, '2026-08-10'),
  ('BDG-004', 'NRP004', 'Perfect Attendance', 'ATTENDANCE', 200, '2026-08-01'),
  ('BDG-005', 'NRP005', 'Team Builder', 'LEADERSHIP', 350, '2026-07-20'),
  ('BDG-006', 'MLL0001', 'Zero Incident 90 Days', 'SAFETY', 600, '2026-08-15'),
  ('BDG-007', 'MLL0002', 'Efficiency Expert', 'PERFORMANCE', 450, '2026-08-10'),
  ('BDG-008', 'MIN0001', 'Coal King', 'PRODUCTION', 500, '2026-08-05'),
  ('BDG-009', 'NRP006', 'Cost Saver', 'INNOVATION', 300, '2026-07-25'),
  ('BDG-010', 'NRP007', 'Quick Learner', 'DEVELOPMENT', 200, '2026-08-20'),
  ('BDG-011', 'NRP008', 'Rising Star', 'PERFORMANCE', 350, '2026-08-15'),
  ('BDG-012', 'EST0001', 'Harvest Hero', 'PRODUCTION', 400, '2026-08-12'),
  ('BDG-013', 'NRP009', 'Audit Master', 'COMPLIANCE', 250, '2026-07-30'),
  ('BDG-014', 'NRP010', 'Digital Pioneer', 'INNOVATION', 500, '2026-08-01'),
  ('BDG-015', 'NRP011', 'People Person', 'LEADERSHIP', 300, '2026-08-10')
ON CONFLICT (id) DO NOTHING;

INSERT INTO employee_mutations (nrp, from_position, to_position, effective_date, reason) VALUES
  ('NRP001', 'Mining Supervisor', 'Mining Manager', '2026-01-01', 'Promosi berdasarkan kinerja'),
  ('NRP002', 'Operator Alat Berat', 'Senior Operator', '2026-03-01', 'Peningkatan kompetensi'),
  ('NRP003', 'Asisten Kebun', 'Estate Manager', '2026-02-01', 'Rotasi karir'),
  ('NRP004', 'HR Staff', 'HR Supervisor', '2026-04-01', 'Promosi'),
  ('NRP005', 'Safety Officer', 'Safety Manager', '2026-01-15', 'Pembentukan dept K3'),
  ('NRP006', 'Finance Analyst', 'Finance Manager', '2026-06-01', 'Promosi'),
  ('NRP007', 'IT Support', 'IT Supervisor', '2026-03-15', 'Pembentukan tim IT'),
  ('NRP008', 'Admin HR', 'HR Generalist', '2026-05-01', 'Rotasi internal'),
  ('MLL0001', 'Operator Boiler', 'Shift Leader Boiler', '2026-04-01', 'Promosi'),
  ('MLL0002', 'Operator Press', 'Supervisor Press', '2026-02-15', 'Peningkatan tanggung jawab')
ON CONFLICT DO NOTHING;

-- ════════════════════════════════════════════════════════════
-- E. COMPLIANCE — whistleblowers, hr_exit_clearance
-- ════════════════════════════════════════════════════════════
INSERT INTO whistleblowers (id, category, description, status, investigator_nrp, resolution_notes) VALUES
  ('WB-001', 'CORRUPTION', 'Dugaan markup biaya procurement alat berat', 'UNDER_INVESTIGATION', 'NRP010', NULL),
  ('WB-002', 'SAFETY', 'Laporan tidak ada APD di area blasting', 'RESOLVED', 'NRP009', 'Tim sudah dipasang APD dan safety briefing'),
  ('WB-003', 'HARASSMENT', 'Keluhan tentang supervisor yang kasar', 'SUBMITTED', NULL, NULL),
  ('WB-004', 'ENVIRONMENT', 'Limbah cair tidak diolah sebelum dibuang', 'UNDER_INVESTIGATION', 'NRP012', 'Tim environment sedang audit'),
  ('WB-005', 'FRAUD', 'Dugaan ghost employee di shift malam', 'RESOLVED', 'NRP010', 'Tidak ditemukan bukti, workers verified'),
  ('WB-006', 'SAFETY', 'Mesin press beroperasi tanpa guard', 'RESOLVED', 'NRP009', 'Guard sudah dipasang, mesin dihentikan sementara')
ON CONFLICT (id) DO NOTHING;

INSERT INTO hr_exit_clearance (nrp, department_clearance, it_clearance, finance_clearance, hr_clearance, status) VALUES
  ('NRP013', TRUE, TRUE, TRUE, TRUE, 'COMPLETED'),
  ('NRP014', TRUE, TRUE, FALSE, FALSE, 'IN_PROGRESS'),
  ('NRP015', FALSE, FALSE, FALSE, FALSE, 'PENDING'),
  ('NRP016', TRUE, TRUE, TRUE, FALSE, 'IN_PROGRESS'),
  ('NRP017', TRUE, TRUE, TRUE, TRUE, 'COMPLETED')
ON CONFLICT (nrp) DO NOTHING;

INSERT INTO final_settlements (nrp, final_salary, unused_leave_pay, severance_pay, bonus_pro_rata, total, status) VALUES
  ('NRP013', 8000000, 2400000, 24000000, 4000000, 38400000, 'PAID'),
  ('NRP014', 6500000, 1300000, 19500000, 3250000, 30550000, 'CALCULATED'),
  ('NRP015', 5000000, 0, 15000000, 2500000, 22500000, 'PENDING'),
  ('NRP016', 7000000, 1750000, 21000000, 3500000, 33250000, 'CALCULATED'),
  ('NRP017', 5500000, 1100000, 16500000, 2750000, 25850000, 'PAID')
ON CONFLICT (nrp) DO NOTHING;

-- ════════════════════════════════════════════════════════════
-- F. FINANCE — budget_allocation, salary_adjustments
-- ════════════════════════════════════════════════════════════
INSERT INTO budget_allocation (division, year, category, allocated, used) VALUES
  ('MINING', 2026, 'Training', 500000000, 320000000),
  ('MINING', 2026, 'Equipment', 2000000000, 1400000000),
  ('MINING', 2026, 'Safety', 300000000, 250000000),
  ('ESTATE', 2026, 'Fertilizer', 800000000, 600000000),
  ('ESTATE', 2026, 'Transport', 600000000, 420000000),
  ('ESTATE', 2026, 'Labor', 1200000000, 950000000),
  ('MILL', 2026, 'Maintenance', 400000000, 280000000),
  ('MILL', 2026, 'Energy', 350000000, 290000000),
  ('MILL', 2026, 'Raw Material', 1500000000, 1100000000),
  ('HQ', 2026, 'HR', 200000000, 150000000),
  ('HQ', 2026, 'IT', 300000000, 180000000),
  ('HQ', 2026, 'Marketing', 250000000, 120000000)
ON CONFLICT DO NOTHING;

INSERT INTO salary_adjustments (id, nrp, current_salary, recommended_salary, increase_pct, reason, status) VALUES
  ('SA-001', 'NRP001', 15000000, 18000000, 20, 'Promosi Mining Manager', 'APPROVED'),
  ('SA-002', 'NRP002', 8000000, 9500000, 18.75, 'Peningkatan ke Senior Operator', 'APPROVED'),
  ('SA-003', 'NRP003', 12000000, 15000000, 25, 'Promosi Estate Manager', 'PENDING'),
  ('SA-004', 'NRP004', 7000000, 8500000, 21.4, 'Promosi HR Supervisor', 'APPROVED'),
  ('SA-005', 'NRP005', 9000000, 11000000, 22.2, 'Promosi Safety Manager', 'PENDING'),
  ('SA-006', 'NRP006', 10000000, 13000000, 30, 'Promosi Finance Manager', 'APPROVED'),
  ('SA-007', 'MLL0001', 5000000, 6500000, 30, 'Promosi Shift Leader', 'APPROVED'),
  ('SA-008', 'MLL0002', 5500000, 7000000, 27.3, 'Promosi Supervisor Press', 'PENDING')
ON CONFLICT (id) DO NOTHING;

-- ════════════════════════════════════════════════════════════
-- G. INTEGRATION — webhook_configs, sso_providers, ext_notif
-- ════════════════════════════════════════════════════════════
INSERT INTO webhook_configs (name, url, events, active) VALUES
  ('Slack HR Alerts', 'https://hooks.slack.com/services/T00/B00/xxx', '["LEAVE_REQUEST","OVERTIME_REQUEST","SAFETY_INCIDENT"]', TRUE),
  ('Email Notification', 'https://api.sendgrid.com/v3/mail/send', '["NEW_REGISTRATION","APPROVAL_PENDING","EXIT_INTERVIEW"]', TRUE),
  ('Payroll Sync', 'https://internal payroll-api.company.com/sync', '["PAYROLL_GENERATED","SALARY_ADJUSTMENT"]', FALSE),
  ('Teams Integration', 'https://outlook.office.com/webhook/xxx', '["ANNOUNCEMENT","TASK_ASSIGNED"]', FALSE)
ON CONFLICT (name) DO NOTHING;

INSERT INTO sso_providers (name, provider_type, client_id, enabled) VALUES
  ('Google Workspace', 'GOOGLE', 'google-client-id-xxx', TRUE),
  ('Microsoft Azure AD', 'AZURE_AD', 'azure-client-id-xxx', FALSE),
  ('Okta SSO', 'OKTA', 'okta-client-id-xxx', FALSE)
ON CONFLICT (name) DO NOTHING;

INSERT INTO external_notifications (provider, event_type, channel, active) VALUES
  ('Slack', 'LEAVE_APPROVED', 'webhook', TRUE),
  ('Slack', 'SAFETY_INCIDENT', 'webhook', TRUE),
  ('Email', 'PAYROLL_READY', 'smtp', TRUE),
  ('SMS', 'EMERGENCY_ALERT', 'api', FALSE),
  ('Teams', 'WEEKLY_SUMMARY', 'webhook', FALSE)
ON CONFLICT DO NOTHING;

-- ════════════════════════════════════════════════════════════
-- H. ADMIN — feature_flags, announcements
-- ════════════════════════════════════════════════════════════
INSERT INTO feature_flags (name, enabled, description) VALUES
  ('ai_copilot', TRUE, 'AI Chatbot untuk HR queries'),
  ('dark_mode', TRUE, 'Toggle dark/light mode'),
  ('push_notifications', TRUE, 'Web push notifications'),
  ('offline_mode', FALSE, 'PWA offline mode (belum stabil)'),
  ('pdf_export', TRUE, 'Export laporan ke PDF'),
  ('real_time_attendance', TRUE, 'Live attendance updates'),
  ('gamification', TRUE, 'Badge dan poin untuk engagement'),
  ('multi_level_approval', TRUE, 'Dynamic approval workflow'),
  ('recruitment_pipeline', TRUE, 'Kanban recruitment pipeline'),
  ('e_sign', FALSE, 'Electronic signature (belum deploy)')
ON CONFLICT (name) DO NOTHING;

-- announcements
INSERT INTO announcements (title, content, author_nrp, priority, target_audience, expires_at) VALUES
  ('Selamat Hari Kemerdekaan RI ke-81', 'Seluruh karyawan mendapat tunjangan hari kemerdekaan. Upacara 17 Agustus di halaman kantor pusat.', 'NRP001', 'HIGH', 'ALL', '2026-08-31'),
  ('Jadwal Annual Medical Checkup', 'Medical checkup akan dilaksanakan 1-15 September. Silakan daftar via aplikasi.', 'NRP004', 'MEDIUM', 'ALL', '2026-09-15'),
  ('Peningkatan Sistem HR', 'Versi baru insightWOS v4.0 sudah live. Silakan cek fitur-fitur baru di menu Help.', 'NRP010', 'LOW', 'ALL', '2026-10-01'),
  ('Safety Alert — Hujan Deras', 'Cuaca ekstrem diperkirakan seminggu ke depan. Patuhi protokol K3 tambang dan kebun.', 'NRP005', 'URGENT', 'MINING,ESTATE', '2026-09-07'),
  ('Training Mandatory — K3 Ulang', 'Semua karyawan wajib mengikuti refreshment K3 bulan ini. Jadwal terlampir.', 'NRP005', 'HIGH', 'MINING,MILL', '2026-09-30')
ON CONFLICT DO NOTHING;

-- ════════════════════════════════════════════════════════════
-- I. OFFBOARDING — offboarding_checklist
-- ════════════════════════════════════════════════════════════
INSERT INTO offboarding_checklist (nrp, item_name, status, completed_date) VALUES
  ('NRP013', 'Return laptop & accessories', 'DONE', '2026-08-25'),
  ('NRP013', 'Transfer knowledge', 'DONE', '2026-08-24'),
  ('NRP013', 'Clear IT accounts', 'DONE', '2026-08-25'),
  ('NRP013', 'Final settlement', 'DONE', '2026-08-26'),
  ('NRP013', 'Exit interview', 'DONE', '2026-08-23'),
  ('NRP014', 'Return equipment', 'DONE', '2026-08-28'),
  ('NRP014', 'Knowledge transfer', 'IN_PROGRESS', NULL),
  ('NRP014', 'Clear IT accounts', 'PENDING', NULL),
  ('NRP014', 'Final settlement', 'PENDING', NULL),
  ('NRP015', 'Return equipment', 'PENDING', NULL),
  ('NRP015', 'Knowledge transfer', 'PENDING', NULL),
  ('NRP016', 'Return laptop', 'DONE', '2026-08-20'),
  ('NRP016', 'Final settlement', 'PENDING', NULL),
  ('NRP017', 'Return equipment', 'DONE', '2026-08-15'),
  ('NRP017', 'Knowledge transfer', 'DONE', '2026-08-14'),
  ('NRP017', 'Clear IT accounts', 'DONE', '2026-08-15'),
  ('NRP017', 'Final settlement', 'DONE', '2026-08-16')
ON CONFLICT DO NOTHING;

-- ════════════════════════════════════════════════════════════
-- J. ONBOARDING (table 018 — different from 050's table)
-- ════════════════════════════════════════════════════════════
INSERT INTO onboarding_tasks (nrp, task_name, assigned_to, status, due_date) VALUES
  ('NRP018', 'Submit KTP & KK', 'HR-01', 'DONE', '2026-09-01'),
  ('NRP018', 'Medical checkup', 'Medical', 'DONE', '2026-09-02'),
  ('NRP018', 'IT account setup', 'IT-01', 'DONE', '2026-09-01'),
  ('NRP018', 'Safety induction', 'K3-01', 'PENDING', '2026-09-05'),
  ('NRP018', 'Buddy assignment', 'NRP001', 'PENDING', '2026-09-03'),
  ('NRP019', 'Submit documents', 'HR-01', 'DONE', '2026-09-01'),
  ('NRP019', 'Medical checkup', 'Medical', 'PENDING', '2026-09-03'),
  ('NRP019', 'Orientation day 1', 'HR-01', 'PENDING', '2026-09-02'),
  ('NRP020', 'Submit documents', 'HR-01', 'DONE', '2026-09-01'),
  ('NRP020', 'Badge & uniform', 'Admin', 'PENDING', '2026-09-02'),
  ('NRP020', 'Parking pass', 'Facility', 'PENDING', '2026-09-03'),
  ('NRP021', 'Visa processing', 'HR-01', 'IN_PROGRESS', '2026-09-15'),
  ('NRP021', 'Housing arrangement', 'Admin', 'PENDING', '2026-09-20')
ON CONFLICT DO NOTHING;

-- ════════════════════════════════════════════════════════════
-- K. TIMESHEETS (additional seed)
-- ════════════════════════════════════════════════════════════
INSERT INTO timesheets (nrp, work_date, clock_in, clock_out, total_hours, notes) VALUES
  ('NRP001', '2026-08-28', '07:55', '17:05', 9.0, 'Normal day'),
  ('NRP001', '2026-08-29', '07:50', '18:30', 10.5, 'OT — deadline project'),
  ('NRP002', '2026-08-28', '06:00', '14:00', 8.0, 'Shift pagi'),
  ('NRP002', '2026-08-29', '06:00', '18:00', 12.0, 'OT shift malam'),
  ('NRP003', '2026-08-28', '07:30', '16:30', 9.0, 'Estate visit'),
  ('NRP004', '2026-08-28', '08:00', '17:00', 9.0, 'Office day'),
  ('MLL0001', '2026-08-28', '06:00', '14:00', 8.0, 'Shift Pagi'),
  ('MLL0001', '2026-08-29', '14:00', '22:00', 8.0, 'Shift Sore'),
  ('MLL0002', '2026-08-28', '14:00', '22:00', 8.0, 'Shift Sore'),
  ('MLL0002', '2026-08-29', '22:00', '06:00', 8.0, 'Shift Malam'),
  ('MIN0001', '2026-08-28', '05:30', '17:30', 12.0, 'OT blasting schedule'),
  ('MIN0002', '2026-08-28', '06:00', '14:00', 8.0, 'Hauling shift'),
  ('EST0001', '2026-08-28', '05:00', '14:00', 9.0, 'Harvest shift'),
  ('EST0002', '2026-08-28', '06:00', '15:00', 9.0, 'Transport TBS'),
  ('NRP005', '2026-08-28', '07:45', '17:15', 9.5, 'Safety inspection')
ON CONFLICT DO NOTHING;

-- ════════════════════════════════════════════════════════════
-- L. REVIEW 360 (table 018 — additional)
-- ════════════════════════════════════════════════════════════
INSERT INTO review_360 (reviewee_nrp, reviewer_nrp, period, category, score, feedback) VALUES
  ('NRP001', 'NRP010', '2026-Q3', 'LEADERSHIP', 4.5, 'Strong strategic vision, good delegation'),
  ('NRP001', 'NRP002', '2026-Q3', 'COMMUNICATION', 4.0, 'Clear instructions, regular check-ins'),
  ('NRP001', 'NRP003', '2026-Q3', 'TEAMWORK', 4.2, 'Supportive leader, approachable'),
  ('NRP002', 'NRP001', '2026-Q3', 'TECHNICAL', 4.3, 'Excellent operator skills'),
  ('NRP002', 'NRP011', '2026-Q3', 'ATTITUDE', 3.8, 'Good but sometimes late'),
  ('NRP003', 'NRP001', '2026-Q3', 'LEADERSHIP', 4.6, 'Best estate manager we have'),
  ('NRP004', 'NRP001', '2026-Q3', 'PROFESSIONALISM', 4.1, 'Professional and dedicated'),
  ('NRP005', 'NRP001', '2026-Q3', 'SAFETY_AWARENESS', 4.8, 'Safety champion, zero incidents'),
  ('MLL0001', 'NRP010', '2026-Q3', 'TECHNICAL', 4.4, 'Boiler expert, efficient operations'),
  ('MLL0002', 'NRP010', '2026-Q3', 'TEAMWORK', 4.0, 'Good team player in press section'),
  ('NRP006', 'NRP001', '2026-Q3', 'ANALYTICAL', 4.3, 'Sharp financial analysis'),
  ('NRP007', 'NRP001', '2026-Q3', 'PROBLEM_SOLVING', 4.2, 'Quick IT solutions'),
  ('NRP008', 'NRP010', '2026-Q3', 'ADAPTABILITY', 4.5, 'Fast learner, flexible'),
  ('NRP009', 'NRP001', '2026-Q3', 'COMPLIANCE', 4.6, 'Thorough audit work'),
  ('NRP010', 'NRP001', '2026-Q3', 'LEADERSHIP', 4.7, 'Excellent admin, keeps everything running'),
  ('MIN0001', 'NRP010', '2026-Q3', 'PRODUCTION', 4.4, 'Exceeds coal targets consistently'),
  ('EST0001', 'NRP011', '2026-Q3', 'AGRONOMY', 4.5, 'Best yield in estate division'),
  ('NRP011', 'NRP001', '2026-Q3', 'ATTENTION_TO_DETAIL', 4.3, 'Payroll always accurate'),
  ('NRP012', 'NRP001', '2026-Q3', 'TRAINING_DESIGN', 4.1, 'Good training materials'),
  ('NRP013', 'NRP010', '2026-Q3', 'INITIATIVE', 3.9, 'Good work but left')
ON CONFLICT DO NOTHING;

-- ════════════════════════════════════════════════════════════
-- M. HR TASKS (additional)
-- ════════════════════════════════════════════════════════════
INSERT INTO hr_tasks (nrp, title, description, status, priority, due_date) VALUES
  ('NRP001', 'Finalize Q3 Budget Report', 'Review dan approve laporan budget Q3', 'DONE', 'HIGH', '2026-08-30'),
  ('NRP001', 'Prepare Board Presentation', 'Buat presentasi untuk board meeting September', 'TODO', 'HIGH', '2026-09-05'),
  ('NRP002', 'Submit Safety Report', 'Kirim laporan kecelakaan bulanan', 'TODO', 'MEDIUM', '2026-09-03'),
  ('NRP003', 'Harvest Plan Q4', 'Rencana panen Q4 untuk seluruh estate', 'TODO', 'HIGH', '2026-09-15'),
  ('NRP004', 'Recruitment Plan 2027', 'Usulan kebutuhan tenaga kerja tahun depan', 'IN_PROGRESS', 'MEDIUM', '2026-09-30'),
  ('NRP005', 'ISO 45001 Preparation', 'Dokumen dan evidence untuk sertifikasi K3', 'IN_PROGRESS', 'HIGH', '2026-10-15'),
  ('NRP006', 'Annual Audit Preparation', 'Siapkan dokumen untuk audit eksternal', 'TODO', 'HIGH', '2026-09-20'),
  ('NRP007', 'System Upgrade Plan', 'Rencana upgrade ke insightWOS v5.0', 'TODO', 'MEDIUM', '2026-09-30'),
  ('MLL0001', 'Boiler Maintenance Schedule', 'Jadwal preventive maintenance boiler bulan September', 'TODO', 'HIGH', '2026-09-01'),
  ('MLL0002', 'QC Report August', 'Laporan quality control bulanan', 'IN_PROGRESS', 'MEDIUM', '2026-09-05')
ON CONFLICT DO NOTHING;

SELECT '053 SEED REMAINING TABLES DONE — 150+ rows inserted' as status;
