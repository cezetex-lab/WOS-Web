-- ============================================================
-- 008_seed_sample_data.sql
-- Seed sample data untuk semua empty tables
-- Run in Supabase SQL Editor
-- ============================================================

-- ============================================================
-- hr_performance (KPI scores untuk 30 pekerja)
-- ============================================================
INSERT INTO hr_performance (nrp, periode, kpi_score, feedback_json)
SELECT e.nrp, '2026-07',
  CASE
    WHEN e.nrp IN ('NRP001','NRP002','NRP003','NRP004') THEN 85 + (random()*15)::int
    WHEN e.nrp IN ('NRP005','NRP006','NRP007','NRP026') THEN 75 + (random()*20)::int
    ELSE 60 + (random()*25)::int
  END,
  '{"source":"auto_calculated"}'
FROM employees_master e
ON CONFLICT DO NOTHING;

-- Period 2026-06
INSERT INTO hr_performance (nrp, periode, kpi_score, feedback_json)
SELECT e.nrp, '2026-06',
  CASE
    WHEN e.nrp IN ('NRP001','NRP002','NRP003','NRP004') THEN 80 + (random()*15)::int
    WHEN e.nrp IN ('NRP005','NRP006','NRP007','NRP026') THEN 70 + (random()*20)::int
    ELSE 55 + (random()*30)::int
  END,
  '{"source":"auto_calculated"}'
FROM employees_master e
ON CONFLICT DO NOTHING;


-- ============================================================
-- hr_attendance (30 hari × 30 pekerja = 900 rows)
-- ============================================================
INSERT INTO hr_attendance (nrp, date, status_hadir, jam_masuk, menit_terlambat, shift)
SELECT
  e.nrp,
  d::date,
  CASE
    WHEN random() < 0.82 THEN 'Hadir'
    WHEN random() < 0.5 THEN 'Telat'
    WHEN random() < 0.5 THEN 'Izin'
    ELSE 'Sakit'
  END,
  (TIME '08:00' + (random() * 30)::int * INTERVAL '1 minute'),
  CASE WHEN random() < 0.15 THEN (random() * 30)::int ELSE 0 END,
  'REGULER'
FROM employees_master e
CROSS JOIN generate_series('2026-07-01'::date, '2026-07-30'::date, '1 day') d
WHERE random() < 0.95
ON CONFLICT DO NOTHING;


-- ============================================================
-- hr_leave (cuti untuk semua pekerja)
-- ============================================================
INSERT INTO hr_leave (nrp, tahun, kuota_cuti, cuti_terpakai)
SELECT e.nrp, 2026, 12, (random() * 8)::int
FROM employees_master e
ON CONFLICT DO NOTHING;


-- ============================================================
-- hr_payroll (gaji 2 bulan terakhir)
-- ============================================================
INSERT INTO hr_payroll (nrp, periode, gaji_pokok, tunjangan, potongan, total_bersih)
SELECT e.nrp, '2026-07',
  CASE WHEN ur.role_level = 5 THEN 25000000 WHEN ur.role_level = 4 THEN 18000000 WHEN ur.role_level = 3 THEN 12000000 ELSE 7000000 END,
  (random() * 3000000)::int,
  (random() * 1500000)::int,
  0
FROM employees_master e LEFT JOIN user_roles ur ON ur.nrp = e.nrp
ON CONFLICT DO NOTHING;

UPDATE hr_payroll SET total_bersih = gaji_pokok + tunjangan - potongan WHERE periode = '2026-07';

INSERT INTO hr_payroll (nrp, periode, gaji_pokok, tunjangan, potongan, total_bersih)
SELECT e.nrp, '2026-06',
  CASE WHEN ur.role_level = 5 THEN 25000000 WHEN ur.role_level = 4 THEN 18000000 WHEN ur.role_level = 3 THEN 12000000 ELSE 7000000 END,
  (random() * 3000000)::int,
  (random() * 1500000)::int,
  0
FROM employees_master e LEFT JOIN user_roles ur ON ur.nrp = e.nrp
ON CONFLICT DO NOTHING;

UPDATE hr_payroll SET total_bersih = gaji_pokok + tunjangan - potongan WHERE periode = '2026-06';


-- ============================================================
-- hr_requests (sample requests)
-- ============================================================
INSERT INTO hr_requests (id, nrp, type, status, note)
SELECT
  'REQ' || LPAD(n::text, 4, '0'),
  e.nrp,
  (ARRAY['Cuti','Surat Keterangan','Izin Sakit','Lembur'])[1 + (n % 4)],
  (ARRAY['Pending','Approved','Pending','Approved'])[1 + (n % 4)],
  'Sample request #' || n
FROM employees_master e
CROSS JOIN generate_series(1, 3) n
WHERE random() < 0.5
ON CONFLICT DO NOTHING;


-- ============================================================
-- hr_learning (training records)
-- ============================================================
INSERT INTO hr_learning (nrp, type, title, status, required_flag)
SELECT e.nrp,
  (ARRAY['SAFETY','TECHNICAL','SOFT_SKILL','COMPLIANCE'])[1 + (n % 4)],
  (ARRAY['Training K3 Dasar','SOP Produksi','Leadership Basic','Compliance Anti Fraud','First Aid','Fire Safety','Communication Skill','Quality Management'])[1 + (n % 8)],
  (ARRAY['COMPLETED','IN_PROGRESS','COMPLETED','REQUESTED'])[1 + (n % 4)],
  n % 2 = 0
FROM employees_master e
CROSS JOIN generate_series(1, 3) n
WHERE random() < 0.6
ON CONFLICT DO NOTHING;


-- ============================================================
-- hr_engagement (skor engagement)
-- ============================================================
INSERT INTO hr_engagement (nrp, score, category)
SELECT e.nrp,
  50 + (random() * 50)::int,
  CASE
    WHEN 50 + (random() * 50)::int >= 80 THEN 'Highly Engaged'
    WHEN 50 + (random() * 50)::int >= 60 THEN 'Engaged'
    ELSE 'Needs Attention'
  END
FROM employees_master e
ON CONFLICT DO NOTHING;


-- ============================================================
-- hr_safety (incidents)
-- ============================================================
INSERT INTO hr_safety (nrp, incident_date, type, description, severity, status)
SELECT
  e.nrp,
  ('2026-07-' || LPAD((1 + (random()*28)::int)::text, 2, '0'))::date,
  (ARRAY['ACCIDENT','NEAR_MISS','INCIDENT'])[1 + (random()*2)::int],
  'Sample incident at ' || e.divisi,
  (ARRAY['LOW','MEDIUM','HIGH'])[1 + (random()*2)::int],
  (ARRAY['OPEN','CLOSED','UNDER_REVIEW'])[1 + (random()*2)::int]
FROM employees_master e
WHERE random() < 0.1
ON CONFLICT DO NOTHING;


-- ============================================================
-- hr_production_daily (produksi harian)
-- ============================================================
INSERT INTO hr_production_daily (nrp, date, volume, unit, target)
SELECT
  e.nrp,
  d::date,
  (3000 + random() * 4000)::int,
  'Ton',
  5000
FROM employees_master e
CROSS JOIN generate_series('2026-07-01'::date, '2026-07-15'::date, '1 day') d
WHERE e.divisi = 'OPERATIONAL' AND random() < 0.8
ON CONFLICT DO NOTHING;


-- ============================================================
-- hr_coaching (coaching sessions)
-- ============================================================
INSERT INTO hr_coaching (nrp, coach_nrp, topic, status, session_date)
SELECT e.nrp, 'NRP002',
  (ARRAY['Performance Improvement','Career Development','K3 Reminder','Leadership Coaching'])[1 + (random()*3)::int],
  (ARRAY['ACTIVE','COMPLETED','SCHEDULED'])[1 + (random()*2)::int],
  ('2026-07-' || LPAD((1 + (random()*28)::int)::text, 2, '0'))::date
FROM employees_master e
WHERE random() < 0.2
ON CONFLICT DO NOTHING;


-- ============================================================
-- hr_compliance (compliance records)
-- ============================================================
INSERT INTO hr_compliance (nrp, compliance_type, status, due_date)
SELECT e.nrp,
  (ARRAY['K3 Training','Medical Checkup','Certificate Renewal','Drug Test'])[1 + (random()*3)::int],
  (ARRAY['COMPLIANT','OVERDUE','PENDING'])[1 + (random()*2)::int],
  ('2026-08-' || LPAD((1 + (random()*28)::int)::text, 2, '0'))::date
FROM employees_master e
WHERE random() < 0.3
ON CONFLICT DO NOTHING;


-- ============================================================
-- hr_benefits (benefit data)
-- ============================================================
INSERT INTO hr_benefits (nrp, kode_benefit, nama_benefit, nilai, status)
SELECT e.nrp,
  (ARRAY['BPJS-KES','BPJS-TK','THP','JHT','JP'])[1 + (random()*4)::int],
  (ARRAY['BPJS Kesehatan','BPJS Ketenagakerjaan','Tunjangan Hari Raya','Jaminan Hari Tua','Jaminan Pensiun'])[1 + (random()*4)::int],
  (random() * 5000000)::int,
  'ACTIVE'
FROM employees_master e
WHERE random() < 0.7
ON CONFLICT DO NOTHING;


-- ============================================================
-- hr_notifications (notifications for all workers)
-- ============================================================
INSERT INTO hr_notifications (nrp, category, title, message, priority, read_flag)
SELECT e.nrp,
  (ARRAY['KPI','ATTENDANCE','TRAINING','SYSTEM'])[1 + (random()*3)::int],
  (ARRAY['Evaluasi KPI Bulanan','Pengingat Kehadiran','Training Mandatory','Update Sistem'])[1 + (random()*3)::int],
  (ARRAY['Silakan cek skor KPI Anda bulan ini.','Pastikan kehadiran tepat waktu.','Ikuti training K3 wajib.','Sistem telah diperbarui.'])[1 + (random()*3)::int],
  (ARRAY['NORMAL','HIGH','NORMAL','LOW'])[1 + (random()*3)::int],
  random() < 0.3
FROM employees_master e
WHERE random() < 0.4
ON CONFLICT DO NOTHING;


-- ============================================================
-- hr_shift_master
-- ============================================================
INSERT INTO hr_shift_master (shift_code, shift_name, start_time, end_time)
VALUES ('S1','Pagi','07:00','15:00'),('S2','Siang','15:00','23:00'),('S3','Malam','23:00','07:00')
ON CONFLICT DO NOTHING;


-- ============================================================
-- hr_talent_catalog (open positions)
-- ============================================================
INSERT INTO hr_talent_catalog (position_name, target_divisi, vacancies, urgency, status)
VALUES
  ('Staff IT','INFORMATION TECHNOLOGY / IT',2,'HIGH','OPEN'),
  ('Supervisor Operasional','OPERATIONAL',1,'MEDIUM','OPEN'),
  ('Analis HRD','HRD',1,'LOW','OPEN')
ON CONFLICT DO NOTHING;


-- ============================================================
-- hr_coaching_catalog
-- ============================================================
INSERT INTO hr_coaching_catalog (title, description, duration_min)
VALUES
  ('Performance Improvement Plan','Coaching untuk meningkatkan KPI','60'),
  ('Leadership Development','Pengembangan kemampuan memimpin','90'),
  ('K3 Refresher','Pengulangan keselamatan kerja','45'),
  ('Career Development Planning','Perencanaan karir jangka panjang','60')
ON CONFLICT DO NOTHING;


-- ============================================================
-- hr_compliance_catalog
-- ============================================================
INSERT INTO hr_compliance_catalog (title, frequency, required_for)
VALUES
  ('Training K3','MONTHLY','ALL'),
  ('Medical Checkup','ANNUALLY','ALL'),
  ('Drug Test','QUARTERLY','OPERATIONAL'),
  ('Certificate Renewal','AS_NEEDED','CERTIFIED')
ON CONFLICT DO NOTHING;


-- ============================================================
-- hr_benefit_catalog
-- ============================================================
INSERT INTO hr_benefit_catalog (kode_benefit, nama, deskripsi, nilai_default)
VALUES
  ('BPJS-KES','BPJS Kesehatan','Jaminan kesehatan','0'),
  ('BPJS-TK','BPJS Ketenagakerjaan','Jaminan ketenagakerjaan','0'),
  ('THP','Tunjangan Hari Raya','THR tahunan','0'),
  ('JHT','Jaminan Hari Tua','Simpanan pensiun','0'),
  ('JP','Jaminan Pensiun','Iuran pensiun','0')
ON CONFLICT DO NOTHING;
