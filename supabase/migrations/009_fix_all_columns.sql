-- ============================================================
-- 009_fix_all_columns.sql
-- Fix ALL column name mismatches
-- Run in Supabase SQL Editor
-- ============================================================

-- First, seed correct data with correct column names
-- ============================================================

-- hr_payroll: base_salary, allowance, deduction, overtime_pay, net_salary
INSERT INTO hr_payroll (nrp, periode, base_salary, allowance, deduction, overtime_pay, net_salary)
SELECT e.nrp, '2026-07',
  CASE WHEN ur.role_level = 5 THEN 25000000 WHEN ur.role_level = 4 THEN 18000000 WHEN ur.role_level = 3 THEN 12000000 ELSE 7000000 END,
  (random() * 3000000)::int, (random() * 1500000)::int, (random() * 2000000)::int, 0
FROM employees_master e LEFT JOIN user_roles ur ON ur.nrp = e.nrp
ON CONFLICT DO NOTHING;
UPDATE hr_payroll SET net_salary = base_salary + allowance + overtime_pay - deduction WHERE periode = '2026-07';

INSERT INTO hr_payroll (nrp, periode, base_salary, allowance, deduction, overtime_pay, net_salary)
SELECT e.nrp, '2026-06',
  CASE WHEN ur.role_level = 5 THEN 25000000 WHEN ur.role_level = 4 THEN 18000000 WHEN ur.role_level = 3 THEN 12000000 ELSE 7000000 END,
  (random() * 3000000)::int, (random() * 1500000)::int, (random() * 2000000)::int, 0
FROM employees_master e LEFT JOIN user_roles ur ON ur.nrp = e.nrp
ON CONFLICT DO NOTHING;
UPDATE hr_payroll SET net_salary = base_salary + allowance + overtime_pay - deduction WHERE periode = '2026-06';


-- hr_engagement: score, period (NO category column)
INSERT INTO hr_engagement (nrp, score, period)
SELECT e.nrp, 50 + (random() * 50)::int, '2026-07'
FROM employees_master e ON CONFLICT DO NOTHING;


-- hr_voice: type, nrp, title, description, status, votes
INSERT INTO hr_voice (id, type, nrp, title, description, status, votes)
SELECT 'V' || LPAD(n::text, 3, '0'),
  (ARRAY['IDEA','SUGGESTION','COMPLAINT'])[1 + (n % 3)],
  (ARRAY['NRP001','NRP005','NRP010','NRP020'])[1 + (n % 4)],
  (ARRAY['Ide efisiensi listrik','Saran shift fleksibel','Keluhan AC kantor','Ide penghematan ATK'])[1 + (n % 4)],
  'Detail ide #' || n,
  'SUBMITTED',
  (random() * 20)::int
FROM generate_series(1, 6) n
ON CONFLICT DO NOTHING;


-- hr_safety: incident_type, date, severity, description, near_miss, incident_date
INSERT INTO hr_safety (nrp, incident_type, date, severity, description, near_miss, incident_date)
SELECT e.nrp,
  (ARRAY['ACCIDENT','NEAR_MISS','INCIDENT'])[1 + (random()*2)::int],
  ('2026-07-' || LPAD((1 + (random()*28)::int)::text, 2, '0'))::date,
  (ARRAY['LOW','MEDIUM','HIGH'])[1 + (random()*2)::int],
  'Incident at ' || e.divisi,
  random() < 0.3,
  ('2026-07-' || LPAD((1 + (random()*28)::int)::text, 2, '0'))::date
FROM employees_master e WHERE random() < 0.1
ON CONFLICT DO NOTHING;


-- hr_compliance: kategori, status, due_date, penanggung_nrp
INSERT INTO hr_compliance (id, kategori, status, due_date, penanggung_nrp)
SELECT 'COMP' || LPAD(n::text, 3, '0'),
  (ARRAY['K3 Training','Medical Checkup','Certificate Renewal','Drug Test'])[1 + (n % 4)],
  (ARRAY['COMPLIANT','OVERDUE','PENDING'])[1 + (n % 3)],
  ('2026-08-' || LPAD((1 + (random()*28)::int)::text, 2, '0'))::date,
  (ARRAY['NRP001','NRP002','NRP005'])[1 + (n % 3)]
FROM generate_series(1, 10) n
ON CONFLICT DO NOTHING;


-- hr_benefits: jenis_benefit, nilai
INSERT INTO hr_benefits (id, nrp, jenis_benefit, nilai)
SELECT 'BEN' || LPAD(n::text, 3, '0'),
  e.nrp,
  (ARRAY['BPJS-KES','BPJS-TK','THP','JHT','JP'])[1 + (n % 5)],
  (random() * 5000000)::int
FROM employees_master e CROSS JOIN generate_series(1, 3) n
WHERE random() < 0.5
ON CONFLICT DO NOTHING;


-- hr_learning: no required_flag, no expiry_date
INSERT INTO hr_learning (nrp, type, title, status, start_date)
SELECT e.nrp,
  (ARRAY['SAFETY','TECHNICAL','SOFT_SKILL','COMPLIANCE'])[1 + (n % 4)],
  (ARRAY['Training K3 Dasar','SOP Produksi','Leadership Basic','Compliance Anti Fraud','First Aid','Fire Safety'])[1 + (n % 6)],
  (ARRAY['COMPLETED','IN_PROGRESS','REQUESTED'])[1 + (n % 3)],
  ('2026-07-' || LPAD((1 + (random()*28)::int)::text, 2, '0'))::date
FROM employees_master e CROSS JOIN generate_series(1, 2) n
WHERE random() < 0.5
ON CONFLICT DO NOTHING;


-- hr_notifications: is_read (NOT read_flag)
INSERT INTO hr_notifications (id, nrp, category, title, message, is_read)
SELECT 'NOTIF' || LPAD(n::text, 4, '0'),
  e.nrp,
  (ARRAY['KPI','ATTENDANCE','TRAINING','SYSTEM'])[1 + (n % 4)],
  (ARRAY['Evaluasi KPI Bulanan','Pengingat Kehadiran','Training Mandatory','Update Sistem'])[1 + (n % 4)],
  (ARRAY['Silakan cek skor KPI Anda.','Pastikan kehadiran tepat waktu.','Ikuti training K3.','Sistem telah diperbarui.'])[1 + (n % 4)],
  random() < 0.3
FROM employees_master e CROSS JOIN generate_series(1, 2) n
WHERE random() < 0.3
ON CONFLICT DO NOTHING;


-- hr_coaching_catalog: type_code, coaching_type, default_topic, duration_minutes
INSERT INTO hr_coaching_catalog (type_code, coaching_type, default_topic, duration_minutes)
VALUES
  ('PIP','Performance Improvement','KPI improvement plan','60'),
  ('LEAD','Leadership','Leadership development','90'),
  ('K3R','Safety Refresher','K3 refresher training','45'),
  ('CAREER','Career','Career development planning','60')
ON CONFLICT DO NOTHING;


-- hr_compliance_catalog: kode_kategori, kategori, sub_kategori
INSERT INTO hr_compliance_catalog (kode_kategori, kategori, sub_kategori)
VALUES
  ('K3','K3 Training','Monthly safety training'),
  ('MED','Medical Checkup','Annual health check'),
  ('DRUG','Drug Test','Quarterly drug test'),
  ('CERT','Certificate Renewal','As needed')
ON CONFLICT DO NOTHING;


-- hr_benefit_catalog: kode_benefit, jenis_benefit, kategori, default_nilai
INSERT INTO hr_benefit_catalog (kode_benefit, jenis_benefit, kategori, default_nilai)
VALUES
  ('BPJS-KES','BPJS Kesehatan','Health','0'),
  ('BPJS-TK','BPJS Ketenagakerjaan','Insurance','0'),
  ('THP','Tunjangan Hari Raya','Allowance','0'),
  ('JHT','Jaminan Hari Tua','Savings','0'),
  ('JP','Jaminan Pensiun','Pension','0')
ON CONFLICT DO NOTHING;


-- ============================================================
-- NOW FIX ALL RPC FUNCTIONS
-- ============================================================

DROP FUNCTION IF EXISTS get_worker_payroll(TEXT);
DROP FUNCTION IF EXISTS get_worker_engagement(TEXT);
DROP FUNCTION IF EXISTS get_worker_notifications(TEXT);
DROP FUNCTION IF EXISTS get_worker_learning(TEXT);
DROP FUNCTION IF EXISTS list_ideas(TEXT);
DROP FUNCTION IF EXISTS submit_voice(TEXT, TEXT, TEXT, TEXT, BOOLEAN);
DROP FUNCTION IF EXISTS get_my_continuous_performance(TEXT);
DROP FUNCTION IF EXISTS get_my_compensation_intelligence(TEXT);
DROP FUNCTION IF EXISTS get_succession(TEXT);
DROP FUNCTION IF EXISTS get_skills_intelligence(TEXT);
DROP FUNCTION IF EXISTS get_benefit_data(TEXT);
DROP FUNCTION IF EXISTS get_near_miss_data(TEXT);
DROP FUNCTION IF EXISTS get_learning_recommendations(TEXT);
DROP FUNCTION IF EXISTS get_talent_marketplace();
DROP FUNCTION IF EXISTS get_career_path(TEXT);
DROP FUNCTION IF EXISTS get_coaching_catalog();
DROP FUNCTION IF EXISTS get_compliance_catalog();
DROP FUNCTION IF EXISTS get_benefit_catalog();
DROP FUNCTION IF EXISTS get_document_types();
DROP FUNCTION IF EXISTS get_action_center();
DROP FUNCTION IF EXISTS get_organization_health();
DROP FUNCTION IF EXISTS get_anomaly_sentinel();
DROP FUNCTION IF EXISTS get_workforce_planning();


-- PAYROLL (base_salary, allowance, deduction, overtime_pay, net_salary)
CREATE OR REPLACE FUNCTION get_worker_payroll(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('periode', periode, 'base_salary', base_salary, 'allowance', allowance, 'deduction', deduction, 'overtime_pay', overtime_pay, 'net_salary', net_salary, 'created_at', created_at)
      ORDER BY created_at DESC
    ), '[]'::jsonb))
    FROM hr_payroll WHERE nrp = p_nrp LIMIT 12
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ENGAGEMENT (score, period — NO category)
CREATE OR REPLACE FUNCTION get_worker_engagement(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE v_eng RECORD;
BEGIN
  SELECT * INTO v_eng FROM hr_engagement WHERE nrp = p_nrp ORDER BY created_at DESC LIMIT 1;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', true, 'score', 0, 'category', 'N/A'); END IF;
  RETURN jsonb_build_object('ok', true, 'score', COALESCE(v_eng.score, 0), 'category', CASE WHEN v_eng.score >= 80 THEN 'Highly Engaged' WHEN v_eng.score >= 60 THEN 'Engaged' ELSE 'Needs Attention' END, 'period', v_eng.period);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- NOTIFICATIONS (is_read — NOT read_flag)
CREATE OR REPLACE FUNCTION get_worker_notifications(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'unread', (SELECT COUNT(*) FROM hr_notifications WHERE nrp = p_nrp AND is_read = false),
      'data', COALESCE(jsonb_agg(
        jsonb_build_object('id', id, 'category', category, 'title', title, 'message', message, 'read_flag', is_read, 'created_at', created_at)
        ORDER BY created_at DESC
      ), '[]'::jsonb))
    FROM hr_notifications WHERE nrp = p_nrp LIMIT 20
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- LEARNING (no required_flag, no expiry_date)
CREATE OR REPLACE FUNCTION get_worker_learning(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('id', id, 'type', type, 'title', title, 'status', status, 'start_date', start_date, 'end_date', end_date)
      ORDER BY created_at DESC
    ), '[]'::jsonb))
    FROM hr_learning WHERE nrp = p_nrp LIMIT 20
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- IDEAS (votes — NOT votes_json)
CREATE OR REPLACE FUNCTION list_ideas(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('id', id, 'type', type, 'title', title, 'status', status, 'votes', votes)
      ORDER BY created_at DESC
    ), '[]'::jsonb))
    FROM hr_voice LIMIT 50
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- SUBMIT VOICE
CREATE OR REPLACE FUNCTION submit_voice(p_nrp TEXT, p_type TEXT, p_title TEXT, p_details TEXT, p_anonymous BOOLEAN)
RETURNS JSONB AS $$
BEGIN
  INSERT INTO hr_voice (id, type, nrp, title, description, status) VALUES ('V' || encode(gen_random_bytes(4),'hex'), p_type, p_nrp, p_title, p_details, 'SUBMITTED');
  RETURN jsonb_build_object('ok', true, 'msg', 'Ide berhasil dikirim.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- CONTINUOUS PERFORMANCE
CREATE OR REPLACE FUNCTION get_my_continuous_performance(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('periode', periode, 'kpi_score', kpi_score, 'feedback', feedback_json) ORDER BY created_at DESC
    ), '[]'::jsonb))
    FROM hr_performance WHERE nrp = p_nrp LIMIT 12
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- COMPENSATION INTELLIGENCE
CREATE OR REPLACE FUNCTION get_my_compensation_intelligence(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE v_pay RECORD; v_avg NUMERIC;
BEGIN
  SELECT * INTO v_pay FROM hr_payroll WHERE nrp = p_nrp ORDER BY created_at DESC LIMIT 1;
  SELECT AVG(net_salary) INTO v_avg FROM hr_payroll WHERE periode = (SELECT MAX(periode) FROM hr_payroll);
  RETURN jsonb_build_object('ok', true, 'my_salary', COALESCE(v_pay.net_salary, 0), 'team_avg', COALESCE(v_avg, 0),
    'diff_pct', CASE WHEN v_avg > 0 THEN ROUND((COALESCE(v_pay.net_salary,0) - v_avg) / v_avg * 100, 1) ELSE 0 END);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- CAREER PATH
CREATE OR REPLACE FUNCTION get_career_path(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE v_emp RECORD; v_ps RECORD;
BEGIN
  SELECT * INTO v_emp FROM employees_master WHERE nrp = p_nrp;
  SELECT * INTO v_ps FROM hr_position_skills WHERE position = v_emp.posisi LIMIT 1;
  RETURN jsonb_build_object('ok', true, 'current_position', v_emp.posisi, 'current_level', (SELECT role_level FROM user_roles WHERE nrp = p_nrp),
    'required_skills', COALESCE(v_ps.skill_name, ''), 'gap_analysis', 'Complete training to unlock next level');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- SKILLS INTELLIGENCE
CREATE OR REPLACE FUNCTION get_skills_intelligence(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('skill', skill_name, 'current_level', level, 'required_level', target_level, 'gap', target_level - level)
    ), '[]'::jsonb))
    FROM hr_skills WHERE nrp = p_nrp
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- BENEFIT DATA (jenis_benefit, nilai)
CREATE OR REPLACE FUNCTION get_benefit_data(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('nrp', nrp, 'jenis_benefit', jenis_benefit, 'nilai', nilai)
    ), '[]'::jsonb))
    FROM hr_benefits WHERE nrp = p_nrp
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- NEAR MISS (incident_type, date)
CREATE OR REPLACE FUNCTION get_near_miss_data(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('id', id, 'nrp', nrp, 'incident_date', incident_date, 'description', description, 'severity', severity)
    ), '[]'::jsonb))
    FROM hr_safety WHERE near_miss = true AND (p_nrp IS NULL OR nrp = p_nrp) ORDER BY incident_date DESC LIMIT 20
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- LEARNING RECOMMENDATIONS
CREATE OR REPLACE FUNCTION get_learning_recommendations(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('title', title, 'category', category, 'reason', 'Recommended based on your role')
    ), '[]'::jsonb))
    FROM hr_training_catalog WHERE priority = 'HIGH' LIMIT 5
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- TALENT MARKETPLACE (type, judul, status)
CREATE OR REPLACE FUNCTION get_talent_marketplace()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('type', type, 'judul', judul, 'status', status, 'priority', priority)
    ), '[]'::jsonb))
    FROM hr_talent_catalog WHERE status = 'ACTIVE'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- SUCCESSION (position, candidate_nrp, readiness)
CREATE OR REPLACE FUNCTION get_succession(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('position', position, 'candidate_nrp', candidate_nrp, 'readiness', readiness)
    ), '[]'::jsonb))
    FROM hr_succession WHERE candidate_nrp = p_nrp
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- COACHING CATALOG (type_code, coaching_type, default_topic, duration_minutes)
CREATE OR REPLACE FUNCTION get_coaching_catalog()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('code', type_code, 'type', coaching_type, 'topic', default_topic, 'duration', duration_minutes)
    ), '[]'::jsonb))
    FROM hr_coaching_catalog
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- COMPLIANCE CATALOG (kode_kategori, kategori, sub_kategori)
CREATE OR REPLACE FUNCTION get_compliance_catalog()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('kode', kode_kategori, 'kategori', kategori, 'sub_kategori', sub_kategori)
    ), '[]'::jsonb))
    FROM hr_compliance_catalog
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- BENEFIT CATALOG (kode_benefit, jenis_benefit, kategori, default_nilai)
CREATE OR REPLACE FUNCTION get_benefit_catalog()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('kode', kode_benefit, 'jenis', jenis_benefit, 'kategori', kategori, 'nilai_default', default_nilai)
    ), '[]'::jsonb))
    FROM hr_benefit_catalog
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- DOCUMENT TYPES (hr_document_types table)
CREATE OR REPLACE FUNCTION get_document_types()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('code', doc_code, 'name', doc_name)
    ), '[]'::jsonb))
    FROM hr_document_types
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ACTION CENTER (fix: hr_compliance uses kategori, not compliance_type)
CREATE OR REPLACE FUNCTION get_action_center()
RETURNS JSONB AS $$
BEGIN
  RETURN jsonb_build_object('ok', true,
    'pending_requests', (SELECT COUNT(*) FROM hr_requests WHERE status = 'Pending'),
    'pending_registrations', (SELECT COUNT(*) FROM daftar_baru WHERE status = 'PENDING'),
    'expired_certs', (SELECT COUNT(*) FROM hr_skills WHERE valid_until < NOW()),
    'coaching_pending', (SELECT COUNT(*) FROM hr_coaching WHERE status = 'SCHEDULED'),
    'compliance_overdue', (SELECT COUNT(*) FROM hr_compliance WHERE status = 'OVERDUE'),
    'exit_clearance_pending', (SELECT COUNT(*) FROM hr_exit_clearance WHERE status = 'PENDING')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ORGANIZATION HEALTH
CREATE OR REPLACE FUNCTION get_organization_health()
RETURNS JSONB AS $$
BEGIN
  RETURN jsonb_build_object('ok', true,
    'headcount', (SELECT COUNT(*) FROM employees_master),
    'avg_kpi', (SELECT COALESCE(ROUND(AVG(kpi_score),1),0) FROM hr_performance WHERE period = (SELECT MAX(period) FROM hr_performance)),
    'attendance_rate', (SELECT COALESCE(ROUND(COUNT(*) FILTER(WHERE status_hadir='Hadir')::NUMERIC/NULLIF(COUNT(*),0)*100,1),0) FROM hr_attendance WHERE date >= date_trunc('month',NOW())),
    'open_positions', (SELECT COUNT(*) FROM hr_talent_catalog WHERE status='ACTIVE'),
    'pending_requests', (SELECT COUNT(*) FROM hr_requests WHERE status='Pending'),
    'coaching_active', (SELECT COUNT(*) FROM hr_coaching WHERE status='ACTIVE'),
    'compliance_issues', (SELECT COUNT(*) FROM hr_compliance WHERE status='OVERDUE')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ANOMALY SENTINEL
CREATE OR REPLACE FUNCTION get_anomaly_sentinel()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('id', id, 'agent', agent_name, 'type', task_type, 'title', title, 'status', status, 'created_at', created_at)
    ), '[]'::jsonb))
    FROM hr_ai_tasks WHERE status = 'PENDING' ORDER BY created_at DESC LIMIT 10
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- EXECUTIVE SUMMARY (fix total_bersih → net_salary)
DROP FUNCTION IF EXISTS get_executive_summary();
CREATE OR REPLACE FUNCTION get_executive_summary()
RETURNS JSONB AS $$
BEGIN
  RETURN jsonb_build_object('ok', true,
    'headcount', (SELECT COUNT(*) FROM employees_master),
    'avg_kpi', (SELECT COALESCE(ROUND(AVG(kpi_score),1),0) FROM hr_performance WHERE period = (SELECT MAX(period) FROM hr_performance)),
    'high_performers', (SELECT COUNT(*) FROM hr_performance WHERE kpi_score >= 80 AND period = (SELECT MAX(period) FROM hr_performance)),
    'low_performers', (SELECT COUNT(*) FROM hr_performance WHERE kpi_score < 60 AND period = (SELECT MAX(period) FROM hr_performance)),
    'turnover_rate', (SELECT COALESCE(ROUND(COUNT(*) FILTER(WHERE status_kerja != 'Active')::NUMERIC/NULLIF(COUNT(*),0)*100,1),0) FROM employees_master),
    'total_payroll', (SELECT COALESCE(SUM(net_salary),0) FROM hr_payroll WHERE periode = (SELECT MAX(periode) FROM hr_payroll))
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- WORKFORCE PLANNING (type, judul)
CREATE OR REPLACE FUNCTION get_workforce_planning()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('type', type, 'judul', judul, 'status', status, 'priority', priority)
    ), '[]'::jsonb))
    FROM hr_talent_catalog
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
