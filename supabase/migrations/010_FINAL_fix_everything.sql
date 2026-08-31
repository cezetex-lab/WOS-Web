-- ============================================================
-- 010_FINAL_fix_everything.sql
-- ONE FILE. ALL FIXES. Column names verified against 001_init.sql.
-- ============================================================

-- ============================================================
-- SEED DATA (correct column names)
-- ============================================================

-- hr_payroll: base_salary, allowance, deduction, overtime_pay, net_salary
INSERT INTO hr_payroll (nrp, periode, base_salary, allowance, deduction, overtime_pay, net_salary)
SELECT e.nrp, '2026-07',
  CASE WHEN ur.role_level = 5 THEN 25000000 WHEN ur.role_level = 4 THEN 18000000 WHEN ur.role_level = 3 THEN 12000000 ELSE 7000000 END,
  (random()*3000000)::int, (random()*1500000)::int, (random()*2000000)::int, 0
FROM employees_master e LEFT JOIN user_roles ur ON ur.nrp = e.nrp ON CONFLICT DO NOTHING;
UPDATE hr_payroll SET net_salary = base_salary + allowance + overtime_pay - deduction WHERE periode = '2026-07';

INSERT INTO hr_payroll (nrp, periode, base_salary, allowance, deduction, overtime_pay, net_salary)
SELECT e.nrp, '2026-06',
  CASE WHEN ur.role_level = 5 THEN 25000000 WHEN ur.role_level = 4 THEN 18000000 WHEN ur.role_level = 3 THEN 12000000 ELSE 7000000 END,
  (random()*3000000)::int, (random()*1500000)::int, (random()*2000000)::int, 0
FROM employees_master e LEFT JOIN user_roles ur ON ur.nrp = e.nrp ON CONFLICT DO NOTHING;
UPDATE hr_payroll SET net_salary = base_salary + allowance + overtime_pay - deduction WHERE periode = '2026-06';

-- hr_engagement: score, period (NO category)
INSERT INTO hr_engagement (nrp, score, period)
SELECT e.nrp, 50+(random()*50)::int, '2026-07' FROM employees_master e ON CONFLICT DO NOTHING;

-- hr_voice: type, nrp, title, description, status, votes (NO is_anonymous, NO votes_json)
INSERT INTO hr_voice (id, type, nrp, title, description, status, votes)
VALUES ('V001','IDEA','NRP001','Ide efisiensi listrik','Matikan AC saat jam istirahat','SUBMITTED',5),
       ('V002','SUGGESTION','NRP005','Shift fleksibel','Usulkan jam kerja fleksibel','SUBMITTED',12),
       ('V003','COMPLAINT','NRP010','Keluhan AC kantor','AC lantai 3 rusak','SUBMITTED',8),
       ('V004','IDEA','NRP020','Penghematan ATK','Gunakan refill','SUBMITTED',3),
       ('V005','IDEA','NRP015','Digitalisasi absensi','Fingerprint baru','SUBMITTED',15),
       ('V006','SUGGESTION','NRP025','Training online','Via Zoom','SUBMITTED',7)
ON CONFLICT DO NOTHING;

-- hr_safety: incident_type, date, severity, description, near_miss, incident_date (NO status column)
INSERT INTO hr_safety (nrp, incident_type, date, severity, description, near_miss, incident_date)
SELECT e.nrp, 'ACCIDENT', ('2026-07-'||LPAD((1+(random()*28)::int)::text,2,'0'))::date,
  'LOW', 'Incident at '||e.divisi, random()<0.3,
  ('2026-07-'||LPAD((1+(random()*28)::int)::text,2,'0'))::date
FROM employees_master e WHERE random()<0.1 ON CONFLICT DO NOTHING;

-- hr_compliance: kategori, status, due_date, penanggung_nrp (NO nrp, NO compliance_type)
INSERT INTO hr_compliance (id, kategori, status, due_date, penanggung_nrp)
VALUES ('C001','K3 Training','COMPLIANT','2026-08-15','NRP001'),
       ('C002','Medical Checkup','OVERDUE','2026-07-01','NRP002'),
       ('C003','Certificate Renewal','PENDING','2026-09-01','NRP005')
ON CONFLICT DO NOTHING;

-- hr_benefits: jenis_benefit, nilai (NO kode_benefit, NO nama_benefit)
INSERT INTO hr_benefits (id, nrp, jenis_benefit, nilai)
SELECT 'B'||LPAD(n::text,3,'0'), e.nrp,
  (ARRAY['BPJS-KES','BPJS-TK','THP','JHT','JP'])[1+(n%5)],
  (random()*5000000)::int
FROM employees_master e CROSS JOIN generate_series(1,3) n WHERE random()<0.5 ON CONFLICT DO NOTHING;

-- hr_learning: type, title, status, start_date (NO required_flag, NO expiry_date)
INSERT INTO hr_learning (nrp, type, title, status, start_date)
SELECT e.nrp,
  (ARRAY['SAFETY','TECHNICAL','SOFT_SKILL'])[1+(n%3)],
  (ARRAY['Training K3 Dasar','SOP Produksi','Leadership Basic','First Aid'])[1+(n%4)],
  (ARRAY['COMPLETED','IN_PROGRESS','REQUESTED'])[1+(n%3)],
  ('2026-07-'||LPAD((1+(random()*28)::int)::text,2,'0'))::date
FROM employees_master e CROSS JOIN generate_series(1,2) n WHERE random()<0.5 ON CONFLICT DO NOTHING;

-- hr_notifications: category, title, message, is_read (NO priority, NO read_flag)
INSERT INTO hr_notifications (id, nrp, category, title, message, is_read)
SELECT 'N'||LPAD(n::text,4,'0'), e.nrp,
  (ARRAY['KPI','ATTENDANCE','TRAINING','SYSTEM'])[1+(n%4)],
  (ARRAY['Evaluasi KPI Bulanan','Pengingat Kehadiran','Training Mandatory','Update Sistem'])[1+(n%4)],
  (ARRAY['Silakan cek skor KPI.','Pastikan kehadiran tepat waktu.'])[1+(n%2)],
  random()<0.3
FROM employees_master e CROSS JOIN generate_series(1,2) n WHERE random()<0.3 ON CONFLICT DO NOTHING;

-- hr_coaching_catalog: type_code, coaching_type, default_topic, duration_minutes (NO title, NO description)
INSERT INTO hr_coaching_catalog (type_code, coaching_type, default_topic, duration_minutes)
VALUES ('PIP','Performance Improvement','KPI improvement plan',60),
       ('LEAD','Leadership','Leadership development',90),
       ('K3R','Safety Refresher','K3 refresher',45),
       ('CAREER','Career','Career development',60)
ON CONFLICT DO NOTHING;

-- hr_compliance_catalog: kode_kategori, kategori, sub_kategori (NO title, NO frequency)
INSERT INTO hr_compliance_catalog (kode_kategori, kategori, sub_kategori)
VALUES ('K3','K3 Training','Monthly safety'),('MED','Medical Checkup','Annual'),('DRUG','Drug Test','Quarterly')
ON CONFLICT DO NOTHING;

-- hr_benefit_catalog: kode_benefit, jenis_benefit, kategori, default_nilai (NO nama, NO deskripsi)
INSERT INTO hr_benefit_catalog (kode_benefit, jenis_benefit, kategori, default_nilai)
VALUES ('BPJS-KES','BPJS Kesehatan','Health',0),('BPJS-TK','BPJS Ketenagakerjaan','Insurance',0),('THP','THR','Allowance',0)
ON CONFLICT DO NOTHING;

-- hr_talent_catalog: id, type, judul, status (NO position_name, NO target_divisi, NO vacancies)
INSERT INTO hr_talent_catalog (id, type, judul, status, priority)
VALUES ('T001','POSITION','Staff IT','ACTIVE','HIGH'),
       ('T002','POSITION','Supervisor Operasional','ACTIVE','MEDIUM')
ON CONFLICT DO NOTHING;

-- hr_production_daily: nrp, date, shift, machine_id, volume, uom (NO target column)
INSERT INTO hr_production_daily (nrp, date, shift, volume, uom)
SELECT e.nrp, d::date, 'REGULER', (3000+random()*4000)::int, 'Ton'
FROM employees_master e CROSS JOIN generate_series('2026-07-01'::date,'2026-07-15'::date,'1 day') d
WHERE e.divisi='OPERATIONAL' AND random()<0.8 ON CONFLICT DO NOTHING;

-- hr_coaching: nrp, coach_nrp, topic, status, session_date (NO notes needed)
INSERT INTO hr_coaching (nrp, coach_nrp, topic, status, session_date)
SELECT e.nrp, 'NRP002', 'Performance Improvement', 'ACTIVE',
  ('2026-07-'||LPAD((1+(random()*28)::int)::text,2,'0'))::date
FROM employees_master e WHERE random()<0.2 ON CONFLICT DO NOTHING;

-- hr_document_types: type, sub_type (NO doc_code, NO doc_name)
INSERT INTO hr_document_types (type, sub_type)
VALUES ('KTP','Identity'),('KK','Family Card'),('SK','Appointment Letter'),('Ijazah','Diploma'),
       ('Sertifikat','Certificate'),('BPJS','Insurance'),('NPWP','Tax'),('SIM','License'),('Kontrak','Contract')
ON CONFLICT DO NOTHING;


-- ============================================================
-- DROP OLD FUNCTIONS (safely)
-- ============================================================
DO $$
DECLARE fn TEXT;
BEGIN
  FOREACH fn IN ARRAY ARRAY[
    'get_worker_payroll','get_worker_engagement','get_worker_notifications',
    'get_worker_learning','list_ideas','submit_voice',
    'get_my_continuous_performance','get_my_compensation_intelligence',
    'get_succession','get_skills_intelligence','get_benefit_data',
    'get_near_miss_data','get_learning_recommendations','get_talent_marketplace',
    'get_career_path','get_coaching_catalog','get_compliance_catalog',
    'get_benefit_catalog','get_document_types','get_action_center',
    'get_organization_health','get_anomaly_sentinel','get_workforce_planning',
    'get_executive_summary','get_early_warning','get_workforce_health_score'
  ] LOOP
    EXECUTE 'DROP FUNCTION IF EXISTS ' || fn || '(TEXT)';
    EXECUTE 'DROP FUNCTION IF EXISTS ' || fn || '()';
  END LOOP;
END $$;


-- ============================================================
-- ALL RPC FUNCTIONS (correct columns)
-- ============================================================

CREATE OR REPLACE FUNCTION get_worker_payroll(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('periode',periode,'base_salary',base_salary,'allowance',allowance,'deduction',deduction,'overtime_pay',overtime_pay,'net_salary',net_salary,'created_at',created_at)
    ORDER BY created_at DESC),'[]'::jsonb))
  FROM hr_payroll WHERE nrp=p_nrp LIMIT 12); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_worker_engagement(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v RECORD; BEGIN
  SELECT * INTO v FROM hr_engagement WHERE nrp=p_nrp ORDER BY created_at DESC LIMIT 1;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',true,'score',0,'category','N/A'); END IF;
  RETURN jsonb_build_object('ok',true,'score',COALESCE(v.score,0),
    'category',CASE WHEN v.score>=80 THEN 'Highly Engaged' WHEN v.score>=60 THEN 'Engaged' ELSE 'Needs Attention' END,'period',v.period);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_worker_notifications(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'unread',(SELECT COUNT(*) FROM hr_notifications WHERE nrp=p_nrp AND is_read=false),
    'data',COALESCE(jsonb_agg(
      jsonb_build_object('id',id,'category',category,'title',title,'message',message,'read_flag',is_read,'created_at',created_at)
      ORDER BY created_at DESC),'[]'::jsonb))
  FROM hr_notifications WHERE nrp=p_nrp LIMIT 20); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_worker_learning(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'type',type,'title',title,'status',status,'start_date',start_date,'end_date',end_date)
    ORDER BY created_at DESC),'[]'::jsonb))
  FROM hr_learning WHERE nrp=p_nrp LIMIT 20); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION list_ideas(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'type',type,'title',title,'status',status,'votes',votes)
    ORDER BY created_at DESC),'[]'::jsonb))
  FROM hr_voice LIMIT 50); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION submit_voice(p_nrp TEXT, p_type TEXT, p_title TEXT, p_details TEXT, p_anon BOOLEAN) RETURNS JSONB AS $$
BEGIN
  INSERT INTO hr_voice(id,type,nrp,title,description,status) VALUES('V'||encode(gen_random_bytes(4),'hex'),p_type,p_nrp,p_title,p_details,'SUBMITTED');
  RETURN jsonb_build_object('ok',true,'msg','Ide berhasil dikirim.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_my_continuous_performance(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('periode',periode,'kpi_score',kpi_score,'feedback',feedback_json) ORDER BY created_at DESC),'[]'::jsonb))
  FROM hr_performance WHERE nrp=p_nrp LIMIT 12); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_my_compensation_intelligence(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v RECORD; v_avg NUMERIC; BEGIN
  SELECT * INTO v FROM hr_payroll WHERE nrp=p_nrp ORDER BY created_at DESC LIMIT 1;
  SELECT AVG(net_salary) INTO v_avg FROM hr_payroll WHERE periode=(SELECT MAX(periode) FROM hr_payroll);
  RETURN jsonb_build_object('ok',true,'my_salary',COALESCE(v.net_salary,0),'team_avg',COALESCE(v_avg,0),
    'diff_pct',CASE WHEN v_avg>0 THEN ROUND((COALESCE(v.net_salary,0)-v_avg)/v_avg*100,1) ELSE 0 END);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_career_path(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v_emp RECORD; v_ps RECORD; BEGIN
  SELECT * INTO v_emp FROM employees_master WHERE nrp=p_nrp;
  SELECT * INTO v_ps FROM hr_position_skills WHERE position=v_emp.posisi LIMIT 1;
  RETURN jsonb_build_object('ok',true,'current_position',v_emp.posisi,'current_level',(SELECT role_level FROM user_roles WHERE nrp=p_nrp),
    'required_skills',COALESCE(v_ps.skill_name,''),'gap_analysis','Complete training to unlock next level');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_skills_intelligence(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('skill',skill_name,'current_level',level,'required_level',target_level,'gap',target_level-level)
  ),'[]'::jsonb)) FROM hr_skills WHERE nrp=p_nrp); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_benefit_data(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',nrp,'jenis_benefit',jenis_benefit,'nilai',nilai)
  ),'[]'::jsonb)) FROM hr_benefits WHERE nrp=p_nrp); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_near_miss_data(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'nrp',nrp,'incident_date',incident_date,'description',description,'severity',severity)
  ),'[]'::jsonb)) FROM hr_safety WHERE near_miss=true AND (p_nrp IS NULL OR nrp=p_nrp) ORDER BY incident_date DESC LIMIT 20); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_learning_recommendations(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('title',title,'category',category,'reason','Recommended')
  ),'[]'::jsonb)) FROM hr_training_catalog WHERE priority='HIGH' LIMIT 5); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_talent_marketplace() RETURNS JSONB AS $$
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('type',type,'judul',judul,'status',status,'priority',priority)
  ),'[]'::jsonb)) FROM hr_talent_catalog WHERE status='ACTIVE'); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_succession(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('position',position,'candidate_nrp',candidate_nrp,'readiness',readiness)
  ),'[]'::jsonb)) FROM hr_succession WHERE candidate_nrp=p_nrp); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_coaching_catalog() RETURNS JSONB AS $$
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('code',type_code,'type',coaching_type,'topic',default_topic,'duration',duration_minutes)
  ),'[]'::jsonb)) FROM hr_coaching_catalog); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_compliance_catalog() RETURNS JSONB AS $$
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('kode',kode_kategori,'kategori',kategori,'sub_kategori',sub_kategori)
  ),'[]'::jsonb)) FROM hr_compliance_catalog); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_benefit_catalog() RETURNS JSONB AS $$
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('kode',kode_benefit,'jenis',jenis_benefit,'kategori',kategori,'nilai_default',default_nilai)
  ),'[]'::jsonb)) FROM hr_benefit_catalog); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- hr_document_types: type, sub_type (NOT doc_code, NOT doc_name)
CREATE OR REPLACE FUNCTION get_document_types() RETURNS JSONB AS $$
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('type',type,'sub_type',sub_type)
  ),'[]'::jsonb)) FROM hr_document_types); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_action_center() RETURNS JSONB AS $$
BEGIN RETURN jsonb_build_object('ok',true,
  'pending_requests',(SELECT COUNT(*) FROM hr_requests WHERE status='Pending'),
  'pending_registrations',(SELECT COUNT(*) FROM daftar_baru WHERE status='PENDING'),
  'expired_certs',(SELECT COUNT(*) FROM hr_skills WHERE valid_until<NOW()),
  'coaching_pending',(SELECT COUNT(*) FROM hr_coaching WHERE status='SCHEDULED'),
  'compliance_overdue',(SELECT COUNT(*) FROM hr_compliance WHERE status='OVERDUE'),
  'exit_clearance_pending',(SELECT COUNT(*) FROM hr_exit_clearance WHERE clearance_status='PENDING')); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_organization_health() RETURNS JSONB AS $$
BEGIN RETURN jsonb_build_object('ok',true,
  'headcount',(SELECT COUNT(*) FROM employees_master),
  'avg_kpi',(SELECT COALESCE(ROUND(AVG(kpi_score),1),0) FROM hr_performance WHERE period=(SELECT MAX(period) FROM hr_performance)),
  'attendance_rate',(SELECT COALESCE(ROUND(COUNT(*) FILTER(WHERE status_hadir='Hadir')::NUMERIC/NULLIF(COUNT(*),0)*100,1),0) FROM hr_attendance WHERE date>=date_trunc('month',NOW())),
  'open_positions',(SELECT COUNT(*) FROM hr_talent_catalog WHERE status='ACTIVE'),
  'pending_requests',(SELECT COUNT(*) FROM hr_requests WHERE status='Pending'),
  'coaching_active',(SELECT COUNT(*) FROM hr_coaching WHERE status='ACTIVE'),
  'compliance_issues',(SELECT COUNT(*) FROM hr_compliance WHERE status='OVERDUE')); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_anomaly_sentinel() RETURNS JSONB AS $$
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'agent',agent_name,'type',task_type,'title',title,'status',status,'created_at',created_at)
  ),'[]'::jsonb)) FROM hr_ai_tasks WHERE status='PENDING' ORDER BY created_at DESC LIMIT 10); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_workforce_planning() RETURNS JSONB AS $$
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('type',type,'judul',judul,'status',status,'priority',priority)
  ),'[]'::jsonb)) FROM hr_talent_catalog); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_executive_summary() RETURNS JSONB AS $$
BEGIN RETURN jsonb_build_object('ok',true,
  'headcount',(SELECT COUNT(*) FROM employees_master),
  'avg_kpi',(SELECT COALESCE(ROUND(AVG(kpi_score),1),0) FROM hr_performance WHERE period=(SELECT MAX(period) FROM hr_performance)),
  'high_performers',(SELECT COUNT(*) FROM hr_performance WHERE kpi_score>=80 AND period=(SELECT MAX(period) FROM hr_performance)),
  'low_performers',(SELECT COUNT(*) FROM hr_performance WHERE kpi_score<60 AND period=(SELECT MAX(period) FROM hr_performance)),
  'turnover_rate',(SELECT COALESCE(ROUND(COUNT(*) FILTER(WHERE status_kerja!='Active')::NUMERIC/NULLIF(COUNT(*),0)*100,1),0) FROM employees_master),
  'total_payroll',(SELECT COALESCE(SUM(net_salary),0) FROM hr_payroll WHERE periode=(SELECT MAX(periode) FROM hr_payroll))); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_early_warning() RETURNS JSONB AS $$
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('category',category,'title',title,'message',message,'created_at',created_at)
  ),'[]'::jsonb)) FROM hr_notifications WHERE is_read=false ORDER BY created_at DESC LIMIT 10); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_workforce_health_score() RETURNS JSONB AS $$
DECLARE v_kpi NUMERIC; v_att NUMERIC; v_eng NUMERIC; v_score NUMERIC; BEGIN
  SELECT COALESCE(AVG(kpi_score),70) INTO v_kpi FROM hr_performance WHERE period=(SELECT MAX(period) FROM hr_performance);
  SELECT COALESCE(COUNT(*) FILTER(WHERE status_hadir='Hadir')::NUMERIC/NULLIF(COUNT(*),0)*100,90) INTO v_att FROM hr_attendance WHERE date>=date_trunc('month',NOW());
  SELECT COALESCE(AVG(score),75) INTO v_eng FROM hr_engagement;
  v_score := v_kpi*0.4 + v_att*0.3 + v_eng*0.3;
  RETURN jsonb_build_object('ok',true,'score',ROUND(v_score,1),'kpi_component',ROUND(v_kpi,1),'attendance_component',ROUND(v_att,1),'engagement_component',ROUND(v_eng,1));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
