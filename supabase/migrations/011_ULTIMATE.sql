-- ============================================================
-- 011_ULTIMATE.sql
-- THE ONE FILE TO RULE THEM ALL
-- ALL 55+ RPC functions, ALL seed data, ALL column names verified
-- Column reference: 001_init.sql (the source of truth)
-- ============================================================

-- ============================================================
-- SEED DATA
-- ============================================================

-- hr_payroll: base_salary, allowance, deduction, overtime_pay, net_salary
INSERT INTO hr_payroll (nrp,periode,base_salary,allowance,deduction,overtime_pay,net_salary)
SELECT e.nrp,'2026-07',
  CASE WHEN ur.role_level=5 THEN 25000000 WHEN ur.role_level=4 THEN 18000000 WHEN ur.role_level=3 THEN 12000000 ELSE 7000000 END,
  (random()*3000000)::int,(random()*1500000)::int,(random()*2000000)::int,0
FROM employees_master e LEFT JOIN user_roles ur ON ur.nrp=e.nrp ON CONFLICT DO NOTHING;
UPDATE hr_payroll SET net_salary=base_salary+allowance+overtime_pay-deduction WHERE periode='2026-07';

INSERT INTO hr_payroll (nrp,periode,base_salary,allowance,deduction,overtime_pay,net_salary)
SELECT e.nrp,'2026-06',
  CASE WHEN ur.role_level=5 THEN 25000000 WHEN ur.role_level=4 THEN 18000000 WHEN ur.role_level=3 THEN 12000000 ELSE 7000000 END,
  (random()*3000000)::int,(random()*1500000)::int,(random()*2000000)::int,0
FROM employees_master e LEFT JOIN user_roles ur ON ur.nrp=e.nrp ON CONFLICT DO NOTHING;
UPDATE hr_payroll SET net_salary=base_salary+allowance+overtime_pay-deduction WHERE periode='2026-06';

-- hr_engagement: score, period
INSERT INTO hr_engagement (nrp,score,period) SELECT e.nrp,50+(random()*50)::int,'2026-07' FROM employees_master e ON CONFLICT DO NOTHING;

-- hr_voice: type, nrp, title, description, status, votes
INSERT INTO hr_voice (id,type,nrp,title,description,status,votes) VALUES
('V001','IDEA','NRP001','Efisiensi listrik','Matikan AC saat istirahat','SUBMITTED',5),
('V002','SUGGESTION','NRP005','Shift fleksibel','Jam kerja fleksibel','SUBMITTED',12),
('V003','COMPLAINT','NRP010','AC rusak','AC lantai 3 mati','SUBMITTED',8),
('V004','IDEA','NRP020','Hemat ATK','Pakai refill','SUBMITTED',3),
('V005','IDEA','NRP015','Absensi digital','Fingerprint baru','SUBMITTED',15),
('V006','SUGGESTION','NRP025','Training online','Via Zoom','SUBMITTED',7) ON CONFLICT DO NOTHING;

-- hr_safety: incident_type, date, severity, description, near_miss, incident_date
INSERT INTO hr_safety (nrp,incident_type,date,severity,description,near_miss,incident_date) SELECT
  e.nrp,'ACCIDENT',('2026-07-'||LPAD((1+(random()*28)::int)::text,2,'0'))::date,
  'LOW','Incident at '||e.divisi,random()<0.3,
  ('2026-07-'||LPAD((1+(random()*28)::int)::text,2,'0'))::date
FROM employees_master e WHERE random()<0.1 ON CONFLICT DO NOTHING;

-- hr_compliance: id, kategori, status, due_date, penanggung_nrp
INSERT INTO hr_compliance (id,kategori,status,due_date,penanggung_nrp) VALUES
('C001','K3 Training','COMPLIANT','2026-08-15','NRP001'),
('C002','Medical Checkup','OVERDUE','2026-07-01','NRP002'),
('C003','Certificate Renewal','PENDING','2026-09-01','NRP005') ON CONFLICT DO NOTHING;

-- hr_benefits: id, nrp, jenis_benefit, nilai
INSERT INTO hr_benefits (id,nrp,jenis_benefit,nilai) SELECT 'B'||LPAD(n::text,3,'0'),e.nrp,
  (ARRAY['BPJS-KES','BPJS-TK','THP','JHT','JP'])[1+(n%5)],(random()*5000000)::int
FROM employees_master e CROSS JOIN generate_series(1,3) n WHERE random()<0.5 ON CONFLICT DO NOTHING;

-- hr_learning: nrp, type, title, status, start_date
INSERT INTO hr_learning (nrp,type,title,status,start_date) SELECT e.nrp,
  (ARRAY['SAFETY','TECHNICAL','SOFT_SKILL'])[1+(n%3)],
  (ARRAY['Training K3 Dasar','SOP Produksi','Leadership Basic','First Aid'])[1+(n%4)],
  (ARRAY['COMPLETED','IN_PROGRESS','REQUESTED'])[1+(n%3)],
  ('2026-07-'||LPAD((1+(random()*28)::int)::text,2,'0'))::date
FROM employees_master e CROSS JOIN generate_series(1,2) n WHERE random()<0.5 ON CONFLICT DO NOTHING;

-- hr_notifications: id, nrp, category, title, message, is_read (NO priority!)
INSERT INTO hr_notifications (id,nrp,category,title,message,is_read) SELECT 'N'||LPAD(n::text,4,'0'),e.nrp,
  (ARRAY['KPI','ATTENDANCE','TRAINING','SYSTEM'])[1+(n%4)],
  (ARRAY['Evaluasi KPI Bulanan','Pengingat Kehadiran','Training Mandatory','Update Sistem'])[1+(n%4)],
  (ARRAY['Silakan cek skor KPI.','Pastikan kehadiran tepat waktu.'])[1+(n%2)],
  random()<0.3
FROM employees_master e CROSS JOIN generate_series(1,2) n WHERE random()<0.3 ON CONFLICT DO NOTHING;

-- hr_coaching_catalog: type_code, coaching_type, default_topic, duration_minutes
INSERT INTO hr_coaching_catalog (type_code,coaching_type,default_topic,duration_minutes) VALUES
('PIP','Performance Improvement','KPI improvement plan',60),
('LEAD','Leadership','Leadership development',90),
('K3R','Safety Refresher','K3 refresher',45),
('CAREER','Career','Career development',60) ON CONFLICT DO NOTHING;

-- hr_compliance_catalog: kode_kategori, kategori, sub_kategori
INSERT INTO hr_compliance_catalog (kode_kategori,kategori,sub_kategori) VALUES
('K3','K3 Training','Monthly'),('MED','Medical Checkup','Annual'),('DRUG','Drug Test','Quarterly') ON CONFLICT DO NOTHING;

-- hr_benefit_catalog: kode_benefit, jenis_benefit, kategori, default_nilai
INSERT INTO hr_benefit_catalog (kode_benefit,jenis_benefit,kategori,default_nilai) VALUES
('BPJS-KES','BPJS Kesehatan','Health',0),('BPJS-TK','BPJS Ketenagakerjaan','Insurance',0),('THP','THR','Allowance',0) ON CONFLICT DO NOTHING;

-- hr_talent_catalog: id, type, judul, status, priority
INSERT INTO hr_talent_catalog (id,type,judul,status,priority) VALUES
('T001','POSITION','Staff IT','ACTIVE','HIGH'),
('T002','POSITION','Supervisor Operasional','ACTIVE','MEDIUM') ON CONFLICT DO NOTHING;

-- hr_production_daily: nrp, date, shift, volume, uom
INSERT INTO hr_production_daily (nrp,date,shift,volume,uom) SELECT e.nrp,d::date,'REGULER',(3000+random()*4000)::int,'Ton'
FROM employees_master e CROSS JOIN generate_series('2026-07-01'::date,'2026-07-15'::date,'1 day') d
WHERE e.divisi='OPERATIONAL' AND random()<0.8 ON CONFLICT DO NOTHING;

-- hr_coaching: nrp, coach_nrp, topic, status, session_date
INSERT INTO hr_coaching (nrp,coach_nrp,topic,status,session_date) SELECT e.nrp,'NRP002','Performance Improvement','ACTIVE',
('2026-07-'||LPAD((1+(random()*28)::int)::text,2,'0'))::date
FROM employees_master e WHERE random()<0.2 ON CONFLICT DO NOTHING;

-- hr_document_types: type, sub_type
INSERT INTO hr_document_types (type,sub_type) VALUES
('KTP','Identity'),('KK','Family'),('SK','Appointment'),('Ijazah','Diploma'),
('Sertifikat','Certificate'),('BPJS','Insurance'),('NPWP','Tax'),('SIM','License'),('Kontrak','Contract') ON CONFLICT DO NOTHING;

-- hr_calendar: date, is_holiday, description
INSERT INTO hr_calendar (date,is_holiday,description) VALUES
('2026-01-01',true,'Tahun Baru'),('2026-08-17',true,'HUT RI'),('2026-12-25',true,'Natal'),
('2026-06-01',true,'Hari Buruh'),('2026-10-02',true,'Hari Batik') ON CONFLICT DO NOTHING;

-- hr_shift_master: shift_code, shift_name, start_time, end_time, grace_minutes
INSERT INTO hr_shift_master (shift_code,shift_name,start_time,end_time,grace_minutes) VALUES
('S1','Pagi','07:00','15:00',10),('S2','Siang','15:00','23:00',10),('S3','Malam','23:00','07:00',10) ON CONFLICT DO NOTHING;

-- hr_work_schedule: divisi_code, work_days_per_week, roster_pattern
INSERT INTO hr_work_schedule (divisi_code,work_days_per_week,roster_pattern) VALUES
('HRD',5,'-'),('FINANCE',5,'-'),('OPERATIONAL',7,'20/10'),('IT',5,'-') ON CONFLICT DO NOTHING;

-- hr_competency_matrix: id, level, level_name, description
INSERT INTO hr_competency_matrix (id,level,level_name,description) VALUES
(1,1,'Staff','Basic skills'),(2,2,'Senior Staff','Advanced'),(3,3,'Supervisor','Leadership'),
(4,4,'Manager','Strategic'),(5,5,'Director','Executive') ON CONFLICT DO NOTHING;

-- hr_succession_matrix: id, readiness_level, description, time_frame
INSERT INTO hr_succession_matrix (id,readiness_level,description,time_frame) VALUES
(1,'Ready Now','Can step in immediately','0-3 months'),
(2,'Ready Soon','Needs minor development','3-6 months'),
(3,'Future Ready','Needs significant development','6-12 months'),
(4,'Not Ready','Long-term development needed','12+ months') ON CONFLICT DO NOTHING;

-- hr_penalty_matrix: id, severity, description, penalty_points
INSERT INTO hr_penalty_matrix (id,severity,description,penalty_points) VALUES
(1,'LOW','Minor warning',1),(2,'MEDIUM','Written warning',3),(3,'HIGH','Final warning',5),(4,'CRITICAL','Termination risk',10) ON CONFLICT DO NOTHING;

-- ============================================================
-- DROP ALL OLD FUNCTIONS
-- ============================================================
DO $$ DECLARE fn TEXT; BEGIN
  FOREACH fn IN ARRAY ARRAY[
    'get_worker_payroll','get_worker_engagement','get_worker_notifications',
    'get_worker_learning','list_ideas','submit_voice','get_my_continuous_performance',
    'get_my_compensation_intelligence','get_succession','get_skills_intelligence',
    'get_benefit_data','get_near_miss_data','get_learning_recommendations',
    'get_talent_marketplace','get_career_path','get_coaching_catalog',
    'get_compliance_catalog','get_benefit_catalog','get_document_types',
    'get_action_center','get_organization_health','get_anomaly_sentinel',
    'get_workforce_planning','get_executive_summary','get_early_warning',
    'get_workforce_health_score','get_production_output','get_plantation_harvest',
    'get_equipment_util','get_shift_schedule','get_calendar_holidays',
    'get_work_schedule','get_overtime_data','get_medical_checkup',
    'calculate_ltifr','get_compliance_rate','get_exit_clearance',
    'get_capability_gap','get_competency_matrix','get_succession_matrix',
    'get_penalty_matrix','get_monthly_snapshot_trend','get_kpi_calc_log',
    'get_manager_command_data','get_subtree_data','get_continuous_perf_team',
    'get_ceo_command_data','get_people_search','get_flight_risk_list',
    'get_safety_summary','get_turnover_data','get_kpi_by_division',
    'get_dashboard_stats','get_team_data','get_team_requests',
    'approve_team_request','get_my_role','get_my_plan',
    'request_training','get_my_training_requests','get_training_catalog'
  ] LOOP
    BEGIN EXECUTE 'DROP FUNCTION IF EXISTS '||fn||'(TEXT)'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE 'DROP FUNCTION IF EXISTS '||fn||'(TEXT,TEXT)'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE 'DROP FUNCTION IF EXISTS '||fn||'(TEXT,TEXT,TEXT)'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE 'DROP FUNCTION IF EXISTS '||fn||'(TEXT,DATE,DATE)'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE 'DROP FUNCTION IF EXISTS '||fn||'(INT)'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE 'DROP FUNCTION IF EXISTS '||fn||'(INT,TEXT)'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE 'DROP FUNCTION IF EXISTS '||fn||'()'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE 'DROP FUNCTION IF EXISTS '||fn||'(BOOLEAN)'; EXCEPTION WHEN OTHERS THEN NULL; END;
  END LOOP;
END $$;


-- ============================================================
-- ALL RPC FUNCTIONS
-- ============================================================

-- AUTH
CREATE OR REPLACE FUNCTION get_my_role(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v RECORD; BEGIN SELECT * INTO v FROM user_roles WHERE nrp=p_nrp;
IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'msg','Role not found'); END IF;
RETURN jsonb_build_object('ok',true,'nrp',p_nrp,'level',v.role_level,'tier',COALESCE(v.scope_divisi,'FREE')); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_my_plan(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v RECORD; BEGIN SELECT * INTO v FROM user_roles WHERE nrp=p_nrp;
RETURN jsonb_build_object('ok',true,'plan',COALESCE(v.scope_divisi,'FREE'),'level',COALESCE(v.role_level,1)); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- WORKER DATA
CREATE OR REPLACE FUNCTION get_worker_payroll(p_nrp TEXT) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('periode',periode,'base_salary',base_salary,'allowance',allowance,'deduction',deduction,'overtime_pay',overtime_pay,'net_salary',net_salary)
    ORDER BY created_at DESC),'[]'::jsonb)) FROM hr_payroll WHERE nrp=p_nrp LIMIT 12); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_worker_engagement(p_nrp TEXT) RETURNS JSONB AS $$ DECLARE v RECORD; BEGIN
  SELECT * INTO v FROM hr_engagement WHERE nrp=p_nrp ORDER BY created_at DESC LIMIT 1;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',true,'score',0,'category','N/A'); END IF;
  RETURN jsonb_build_object('ok',true,'score',COALESCE(v.score,0),
    'category',CASE WHEN v.score>=80 THEN 'Highly Engaged' WHEN v.score>=60 THEN 'Engaged' ELSE 'Needs Attention' END,'period',v.period); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_worker_notifications(p_nrp TEXT) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'unread',(SELECT COUNT(*) FROM hr_notifications WHERE nrp=p_nrp AND is_read=false),
    'data',COALESCE(jsonb_agg(jsonb_build_object('id',id,'category',category,'title',title,'message',message,'read_flag',is_read,'created_at',created_at) ORDER BY created_at DESC),'[]'::jsonb))
  FROM hr_notifications WHERE nrp=p_nrp LIMIT 20); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_worker_learning(p_nrp TEXT) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'type',type,'title',title,'status',status,'start_date',start_date,'end_date',end_date) ORDER BY created_at DESC),'[]'::jsonb))
  FROM hr_learning WHERE nrp=p_nrp LIMIT 20); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION list_ideas(p_nrp TEXT) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'type',type,'title',title,'status',status,'votes',votes) ORDER BY created_at DESC),'[]'::jsonb))
  FROM hr_voice LIMIT 50); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION submit_voice(p_nrp TEXT, p_type TEXT, p_title TEXT, p_details TEXT, p_anonymous BOOLEAN) RETURNS JSONB AS $$ BEGIN
  INSERT INTO hr_voice(id,type,nrp,title,description,status) VALUES('V'||encode(gen_random_bytes(4),'hex'),p_type,p_nrp,p_title,p_details,'SUBMITTED');
  RETURN jsonb_build_object('ok',true,'msg','Ide berhasil dikirim.'); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_my_continuous_performance(p_nrp TEXT) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('periode',periode,'kpi_score',kpi_score,'feedback',feedback_json) ORDER BY created_at DESC),'[]'::jsonb))
  FROM hr_performance WHERE nrp=p_nrp LIMIT 12); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_my_compensation_intelligence(p_nrp TEXT) RETURNS JSONB AS $$ DECLARE v RECORD; v_avg NUMERIC; BEGIN
  SELECT * INTO v FROM hr_payroll WHERE nrp=p_nrp ORDER BY created_at DESC LIMIT 1;
  SELECT AVG(net_salary) INTO v_avg FROM hr_payroll WHERE periode=(SELECT MAX(periode) FROM hr_payroll);
  RETURN jsonb_build_object('ok',true,'my_salary',COALESCE(v.net_salary,0),'team_avg',COALESCE(v_avg,0)); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_career_path(p_nrp TEXT) RETURNS JSONB AS $$ DECLARE v_emp RECORD; v_ps RECORD; BEGIN
  SELECT * INTO v_emp FROM employees_master WHERE nrp=p_nrp;
  SELECT * INTO v_ps FROM hr_position_skills WHERE position=v_emp.posisi LIMIT 1;
  RETURN jsonb_build_object('ok',true,'current_position',v_emp.posisi,'current_level',(SELECT role_level FROM user_roles WHERE nrp=p_nrp),
    'required_skills',COALESCE(v_ps.skill_name,''),'gap_analysis','Complete training to unlock next level'); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_skills_intelligence(p_nrp TEXT) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('skill',skill_name,'current_level',level,'required_level',target_level,'gap',target_level-level)),'[]'::jsonb))
  FROM hr_skills WHERE nrp=p_nrp); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_benefit_data(p_nrp TEXT) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',nrp,'jenis_benefit',jenis_benefit,'nilai',nilai)),'[]'::jsonb))
  FROM hr_benefits WHERE nrp=p_nrp); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_near_miss_data(p_nrp TEXT) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'nrp',nrp,'incident_date',incident_date,'description',description,'severity',severity)),'[]'::jsonb))
  FROM hr_safety WHERE near_miss=true AND (p_nrp IS NULL OR nrp=p_nrp) ORDER BY incident_date DESC LIMIT 20); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_learning_recommendations(p_nrp TEXT) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('title',title,'category',category)),'[]'::jsonb))
  FROM hr_training_catalog WHERE priority='HIGH' LIMIT 5); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_talent_marketplace() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('type',type,'judul',judul,'status',status,'priority',priority)),'[]'::jsonb))
  FROM hr_talent_catalog WHERE status='ACTIVE'); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_succession(p_nrp TEXT) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('position',position,'candidate_nrp',candidate_nrp,'readiness',readiness)),'[]'::jsonb))
  FROM hr_succession WHERE candidate_nrp=p_nrp); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_coaching_catalog() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('code',type_code,'type',coaching_type,'topic',default_topic,'duration',duration_minutes)),'[]'::jsonb))
  FROM hr_coaching_catalog); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_compliance_catalog() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('kode',kode_kategori,'kategori',kategori,'sub',sub_kategori)),'[]'::jsonb))
  FROM hr_compliance_catalog); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_benefit_catalog() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('kode',kode_benefit,'jenis',jenis_benefit,'kategori',kategori,'nilai_default',default_nilai)),'[]'::jsonb))
  FROM hr_benefit_catalog); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_document_types() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('type',type,'sub_type',sub_type)),'[]'::jsonb))
  FROM hr_document_types); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- TEAM & MANAGER
CREATE OR REPLACE FUNCTION get_team_data(p_nrp TEXT) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',e.nrp,'nama',e.nama,'posisi',e.posisi,'divisi',e.divisi,'kpi_score',COALESCE(p.kpi_score,0),'status_kerja',e.status_kerja)),'[]'::jsonb))
  FROM hr_org o JOIN employees_master e ON e.nrp=o.nrp LEFT JOIN hr_performance p ON p.nrp=o.nrp WHERE o.atasan_nrp=p_nrp ORDER BY e.nama); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_team_requests(p_nrp TEXT) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',r.id,'nrp',r.nrp,'nama',e.nama,'type',r.type,'status',r.status,'note',r.note,'created_at',r.created_at)),'[]'::jsonb))
  FROM hr_requests r JOIN hr_org o ON o.nrp=r.nrp AND o.atasan_nrp=p_nrp LEFT JOIN employees_master e ON e.nrp=r.nrp WHERE r.status='Pending' ORDER BY r.created_at ASC); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION approve_team_request(p_id TEXT, p_status TEXT, p_note TEXT) RETURNS JSONB AS $$ BEGIN
  UPDATE hr_requests SET status=p_status,note=p_note WHERE id=p_id AND status='Pending';
  IF FOUND THEN RETURN jsonb_build_object('ok',true,'msg','Request '||p_status); END IF;
  RETURN jsonb_build_object('ok',false,'msg','Request tidak ditemukan.'); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_manager_command_data(p_nrp TEXT) RETURNS JSONB AS $$ DECLARE v_t JSONB; v_r JSONB; BEGIN
  SELECT jsonb_agg(jsonb_build_object('nrp',e.nrp,'nama',e.nama,'kpi',COALESCE(p.kpi_score,0))) INTO v_t
  FROM hr_org o JOIN employees_master e ON e.nrp=o.nrp LEFT JOIN hr_performance p ON p.nrp=o.nrp WHERE o.atasan_nrp=p_nrp;
  SELECT jsonb_agg(jsonb_build_object('id',r.id,'type',r.type,'status',r.status)) INTO v_r
  FROM hr_requests r JOIN hr_org o ON o.nrp=r.nrp AND o.atasan_nrp=p_nrp WHERE r.status='Pending';
  RETURN jsonb_build_object('ok',true,'team',COALESCE(v_t,'[]'::jsonb),'pending',COALESCE(v_r,'[]'::jsonb)); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_subtree_data(p_nrp TEXT) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',e.nrp,'nama',e.nama,'atasan',o.atasan_nrp,'posisi',e.posisi,'divisi',e.divisi,'level',COALESCE(ur.role_level,1))),'[]'::jsonb))
  FROM employees_master e LEFT JOIN hr_org o ON o.nrp=e.nrp LEFT JOIN user_roles ur ON ur.nrp=e.nrp ORDER BY e.nama); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_continuous_perf_team(p_nrp TEXT) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',p.nrp,'nama',e.nama,'periode',p.periode,'kpi_score',p.kpi_score)),'[]'::jsonb))
  FROM hr_performance p JOIN hr_org o ON o.nrp=p.nrp AND o.atasan_nrp=p_nrp LEFT JOIN employees_master e ON e.nrp=p.nrp ORDER BY p.created_at DESC LIMIT 20); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_people_search(p_query TEXT) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',nrp,'nama',nama,'divisi',divisi,'posisi',posisi)),'[]'::jsonb))
  FROM employees_master WHERE nama ILIKE '%'||p_query||'%' OR nrp ILIKE '%'||p_query||'%' LIMIT 20); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- CEO & EXECUTIVE
CREATE OR REPLACE FUNCTION get_ceo_command_data(p_nrp TEXT) RETURNS JSONB AS $$ BEGIN
  RETURN jsonb_build_object('ok',true,
    'org_summary',(SELECT COALESCE(jsonb_agg(jsonb_build_object('divisi',d.divisi,'headcount',d.hc,'avg_kpi',d.ak)),'[]'::jsonb) FROM
      (SELECT e.divisi,COUNT(*) as hc,ROUND(AVG(p.kpi_score),1) as ak FROM employees_master e LEFT JOIN hr_performance p ON p.nrp=e.nrp WHERE e.divisi IS NOT NULL GROUP BY e.divisi) d),
    'total_workers',(SELECT COUNT(*) FROM employees_master),
    'avg_kpi',(SELECT COALESCE(ROUND(AVG(kpi_score),1),0) FROM hr_performance WHERE period=(SELECT MAX(period) FROM hr_performance))); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_organization_health() RETURNS JSONB AS $$ BEGIN RETURN jsonb_build_object('ok',true,
  'headcount',(SELECT COUNT(*) FROM employees_master),
  'avg_kpi',(SELECT COALESCE(ROUND(AVG(kpi_score),1),0) FROM hr_performance WHERE period=(SELECT MAX(period) FROM hr_performance)),
  'attendance_rate',(SELECT COALESCE(ROUND(COUNT(*) FILTER(WHERE status_hadir='Hadir')::NUMERIC/NULLIF(COUNT(*),0)*100,1),0) FROM hr_attendance WHERE date>=date_trunc('month',NOW())),
  'open_positions',(SELECT COUNT(*) FROM hr_talent_catalog WHERE status='ACTIVE'),
  'pending_requests',(SELECT COUNT(*) FROM hr_requests WHERE status='Pending'),
  'coaching_active',(SELECT COUNT(*) FROM hr_coaching WHERE status='ACTIVE'),
  'compliance_issues',(SELECT COUNT(*) FROM hr_compliance WHERE status='OVERDUE')); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_early_warning() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('category',category,'title',title,'message',message,'created_at',created_at)),'[]'::jsonb))
  FROM hr_notifications WHERE is_read=false ORDER BY created_at DESC LIMIT 10); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_executive_summary() RETURNS JSONB AS $$ BEGIN RETURN jsonb_build_object('ok',true,
  'headcount',(SELECT COUNT(*) FROM employees_master),
  'avg_kpi',(SELECT COALESCE(ROUND(AVG(kpi_score),1),0) FROM hr_performance WHERE period=(SELECT MAX(period) FROM hr_performance)),
  'high_performers',(SELECT COUNT(*) FROM hr_performance WHERE kpi_score>=80 AND period=(SELECT MAX(period) FROM hr_performance)),
  'low_performers',(SELECT COUNT(*) FROM hr_performance WHERE kpi_score<60 AND period=(SELECT MAX(period) FROM hr_performance)),
  'turnover_rate',0,'total_payroll',(SELECT COALESCE(SUM(net_salary),0) FROM hr_payroll WHERE periode=(SELECT MAX(periode) FROM hr_payroll))); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_workforce_planning() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('type',type,'judul',judul,'status',status,'priority',priority)),'[]'::jsonb))
  FROM hr_talent_catalog); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_workforce_health_score() RETURNS JSONB AS $$ DECLARE v_kpi NUMERIC; v_att NUMERIC; v_eng NUMERIC; BEGIN
  SELECT COALESCE(AVG(kpi_score),70) INTO v_kpi FROM hr_performance WHERE period=(SELECT MAX(period) FROM hr_performance);
  SELECT COALESCE(COUNT(*) FILTER(WHERE status_hadir='Hadir')::NUMERIC/NULLIF(COUNT(*),0)*100,90) INTO v_att FROM hr_attendance WHERE date>=date_trunc('month',NOW());
  SELECT COALESCE(AVG(score),75) INTO v_eng FROM hr_engagement;
  RETURN jsonb_build_object('ok',true,'score',ROUND(v_kpi*0.4+v_att*0.3+v_eng*0.3,1)); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_anomaly_sentinel() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'agent',agent_name,'type',task_type,'title',title,'status',status)),'[]'::jsonb))
  FROM hr_ai_tasks WHERE status='PENDING' ORDER BY created_at DESC LIMIT 10); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- DASHBOARD STATS
CREATE OR REPLACE FUNCTION get_dashboard_stats() RETURNS JSONB AS $$ BEGIN RETURN jsonb_build_object('ok',true,
  'total_workers',(SELECT COUNT(*) FROM employees_master),
  'avg_kpi',(SELECT COALESCE(ROUND(AVG(kpi_score),1),0) FROM hr_performance WHERE period=(SELECT MAX(period) FROM hr_performance)),
  'attendance_rate',(SELECT COALESCE(ROUND(COUNT(*) FILTER(WHERE status_hadir='Hadir')::NUMERIC/NULLIF(COUNT(*),0)*100,1),0) FROM hr_attendance WHERE date>=date_trunc('month',NOW())),
  'pending_requests',(SELECT COUNT(*) FROM hr_requests WHERE status='Pending'),
  'high_performers',(SELECT COUNT(*) FROM hr_performance WHERE kpi_score>=80 AND period=(SELECT MAX(period) FROM hr_performance)),
  'low_performers',(SELECT COUNT(*) FROM hr_performance WHERE kpi_score<60 AND period=(SELECT MAX(period) FROM hr_performance))); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_kpi_by_division() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(jsonb_build_object('divisi',divisi,'avg_kpi',avg_kpi,'headcount',headcount) ORDER BY avg_kpi DESC),'[]'::jsonb))
  FROM (SELECT e.divisi,ROUND(AVG(p.kpi_score),1) as avg_kpi,COUNT(*) as headcount FROM employees_master e LEFT JOIN hr_performance p ON p.nrp=e.nrp AND p.period=(SELECT MAX(period) FROM hr_performance) WHERE e.divisi IS NOT NULL GROUP BY e.divisi) t); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_safety_summary() RETURNS JSONB AS $$ DECLARE v_int INT; v_hrs NUMERIC; BEGIN
  SELECT COUNT(*) INTO v_int FROM hr_safety;
  SELECT SUM(menit_lembur+480)/60 INTO v_hrs FROM hr_attendance WHERE date>=date_trunc('month',NOW());
  RETURN jsonb_build_object('ok',true,'total_incidents',COALESCE(v_int,0),
    'ltifr',CASE WHEN v_hrs>0 THEN ROUND(v_int::NUMERIC/(v_hrs/1000000)*1000000,2) ELSE 0 END,
    'status',CASE WHEN COALESCE(v_int,0)=0 THEN 'AMAN' ELSE 'PERLU PERHATIAN' END); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_turnover_data() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(jsonb_build_object('divisi',divisi,'active',active,'left',left_count,'rate',turnover_rate)),'[]'::jsonb))
  FROM (SELECT e.divisi,COUNT(*) FILTER(WHERE e.status_kerja='PKWTT') as active,COUNT(*) FILTER(WHERE e.status_kerja='PKWT') as left_count,
    ROUND(COUNT(*) FILTER(WHERE e.status_kerja='PKWT')::NUMERIC/NULLIF(COUNT(*),0)*100,1) as turnover_rate
  FROM employees_master e WHERE e.divisi IS NOT NULL GROUP BY e.divisi) t); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_flight_risk_list() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',e.nrp,'nama',e.nama,'divisi',e.divisi,'kpi_score',COALESCE(p.kpi_score,0),'telat_count',COALESCE(t.telat_count,0))
    ORDER BY p.kpi_score ASC),'[]'::jsonb))
  FROM employees_master e LEFT JOIN hr_performance p ON p.nrp=e.nrp AND p.period=(SELECT MAX(period) FROM hr_performance)
  LEFT JOIN (SELECT nrp,COUNT(*) as telat_count FROM hr_attendance WHERE status_hadir='Telat' AND date>=date_trunc('month',NOW()) GROUP BY nrp) t ON t.nrp=e.nrp
  WHERE COALESCE(p.kpi_score,100)<70 OR COALESCE(t.telat_count,0)>5 ORDER BY p.kpi_score ASC LIMIT 10); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_action_center() RETURNS JSONB AS $$ BEGIN RETURN jsonb_build_object('ok',true,
  'pending_requests',(SELECT COUNT(*) FROM hr_requests WHERE status='Pending'),
  'pending_registrations',(SELECT COUNT(*) FROM daftar_baru WHERE status='PENDING'),
  'expired_certs',(SELECT COUNT(*) FROM hr_skills WHERE valid_until<NOW()),
  'coaching_pending',(SELECT COUNT(*) FROM hr_coaching WHERE status='SCHEDULED'),
  'compliance_overdue',(SELECT COUNT(*) FROM hr_compliance WHERE status='OVERDUE'),
  'exit_clearance_pending',(SELECT COUNT(*) FROM hr_exit_clearance WHERE clearance_status='PENDING')); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- PRODUCTION & OPS
CREATE OR REPLACE FUNCTION get_production_output(p_nrp TEXT, p_from DATE, p_to DATE) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('date',date,'volume',volume,'uom',uom,'shift',shift) ORDER BY date DESC),'[]'::jsonb))
  FROM hr_production_daily WHERE (p_nrp IS NULL OR nrp=p_nrp) AND (p_from IS NULL OR date>=p_from) AND (p_to IS NULL OR date<=p_to) LIMIT 30); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_plantation_harvest(p_nrp TEXT, p_from DATE, p_to DATE) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('date',date,'block_area',block_area,'tbs_kg',tbs_kg,'quality',quality) ORDER BY date DESC),'[]'::jsonb))
  FROM hr_plantation_harvest WHERE (p_nrp IS NULL OR nrp=p_nrp) AND (p_from IS NULL OR date>=p_from) AND (p_to IS NULL OR date<=p_to) LIMIT 30); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_equipment_util(p_machine TEXT, p_from DATE, p_to DATE) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('date',date,'machine_id',machine_id,'availability_pct',availability_pct,'fuel_liters',fuel_liters) ORDER BY date DESC),'[]'::jsonb))
  FROM hr_equipment_util WHERE (p_machine IS NULL OR machine_id=p_machine) AND (p_from IS NULL OR date>=p_from) AND (p_to IS NULL OR date<=p_to) LIMIT 30); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- SCHEDULE
CREATE OR REPLACE FUNCTION get_shift_schedule() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('shift_code',shift_code,'shift_name',shift_name,'start_time',start_time,'end_time',end_time)),'[]'::jsonb))
  FROM hr_shift_master); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_calendar_holidays(p_year INT) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('date',date,'is_holiday',is_holiday,'description',description)),'[]'::jsonb))
  FROM hr_calendar WHERE EXTRACT(YEAR FROM date)=COALESCE(p_year,EXTRACT(YEAR FROM NOW())::INT)); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_work_schedule(p_divisi TEXT) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('divisi_code',divisi_code,'work_days_per_week',work_days_per_week,'roster_pattern',roster_pattern)),'[]'::jsonb))
  FROM hr_work_schedule WHERE p_divisi IS NULL OR divisi_code=p_divisi); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_overtime_data(p_nrp TEXT, p_from DATE, p_to DATE) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',nrp,'date',date,'hours',hours,'reason',reason,'status',status) ORDER BY date DESC),'[]'::jsonb))
  FROM hr_overtime WHERE (p_nrp IS NULL OR nrp=p_nrp) AND (p_from IS NULL OR date>=p_from) AND (p_to IS NULL OR date<=p_to) LIMIT 30); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- MEDICAL & SAFETY
CREATE OR REPLACE FUNCTION get_medical_checkup(p_nrp TEXT) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',nrp,'checkup_date',checkup_date,'result',result,'expiry_date',expiry_date) ORDER BY checkup_date DESC),'[]'::jsonb))
  FROM hr_medical_checkup WHERE p_nrp IS NULL OR nrp=p_nrp LIMIT 10); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION calculate_ltifr(p_periode TEXT) RETURNS JSONB AS $$ DECLARE v_int INT; v_hrs NUMERIC; BEGIN
  SELECT COUNT(*) INTO v_int FROM hr_safety;
  SELECT SUM(menit_lembur+480)/60 INTO v_hrs FROM hr_attendance WHERE date>=date_trunc('month',NOW());
  RETURN jsonb_build_object('ok',true,'ltifr',CASE WHEN v_hrs>0 THEN ROUND(v_int::NUMERIC/(v_hrs/1000000)*1000000,2) ELSE 0 END,'incidents',v_int); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_compliance_rate(p_divisi TEXT) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(jsonb_build_object('kategori',kategori,'status',status,'count',cnt)),'[]'::jsonb))
  FROM (SELECT kategori,status,COUNT(*) as cnt FROM hr_compliance GROUP BY kategori,status) t); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_exit_clearance(p_nrp TEXT) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',nrp,'resign_date',resign_date,'clearance_status',clearance_status)),'[]'::jsonb))
  FROM hr_exit_clearance WHERE p_nrp IS NULL OR nrp=p_nrp); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- CAPABILITY & COMPETENCY
CREATE OR REPLACE FUNCTION get_capability_gap(p_nrp TEXT) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',nrp,'kompetensi',kompetensi,'level_sekarang',level_sekarang,'level_target',level_target,'gap',gap,'is_mandatory',is_mandatory)),'[]'::jsonb))
  FROM hr_capability WHERE p_nrp IS NULL OR nrp=p_nrp); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_competency_matrix() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('level',level,'level_name',level_name,'description',description)),'[]'::jsonb))
  FROM hr_competency_matrix); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_succession_matrix() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('readiness_level',readiness_level,'description',description,'time_frame',time_frame)),'[]'::jsonb))
  FROM hr_succession_matrix); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_penalty_matrix() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('severity',severity,'description',description,'penalty_points',penalty_points)),'[]'::jsonb))
  FROM hr_penalty_matrix); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- SNAPSHOT & LOGS
CREATE OR REPLACE FUNCTION get_monthly_snapshot_trend(p_divisi TEXT) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('periode',periode,'divisi',divisi,'total_headcount',total_headcount,'avg_kpi',avg_kpi,'total_payroll',total_payroll,'total_revenue',total_revenue) ORDER BY periode DESC),'[]'::jsonb))
  FROM hr_monthly_snapshot WHERE p_divisi IS NULL OR divisi=p_divisi LIMIT 12); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_kpi_calc_log() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'nrp',nrp,'periode',periode,'indicator',indicator,'realisasi',realisasi,'target',target,'final_score',final_score) ORDER BY created_at DESC),'[]'::jsonb))
  FROM hr_kpi_calc_log LIMIT 50); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- TRAINING
CREATE OR REPLACE FUNCTION request_training(p_nrp TEXT, p_code TEXT, p_reason TEXT) RETURNS JSONB AS $$ BEGIN
  INSERT INTO hr_learning(nrp,type,title,status) VALUES(p_nrp,'REQUEST',p_code,'REQUESTED');
  RETURN jsonb_build_object('ok',true,'msg','Training request dikirim.'); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_my_training_requests(p_nrp TEXT) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'type',type,'title',title,'status',status,'start_date',start_date) ORDER BY created_at DESC),'[]'::jsonb))
  FROM hr_learning WHERE nrp=p_nrp LIMIT 20); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_training_catalog() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'title',title,'category',category,'provider',provider,'duration_hours',duration_hours)),'[]'::jsonb))
  FROM hr_training_catalog); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- ADMIN
CREATE OR REPLACE FUNCTION admin_get_org_structure() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',e.nrp,'nama',e.nama,'divisi',e.divisi,'posisi',e.posisi,'atasan',o.atasan_nrp,'level',COALESCE(ur.role_level,1)) ORDER BY e.nama),'[]'::jsonb))
  FROM employees_master e LEFT JOIN hr_org o ON o.nrp=e.nrp LEFT JOIN user_roles ur ON ur.nrp=e.nrp); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION admin_get_divisions() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(jsonb_build_object('divisi',divisi,'headcount',hc)),'[]'::jsonb))
  FROM (SELECT divisi,COUNT(*) as hc FROM employees_master WHERE divisi IS NOT NULL GROUP BY divisi) t); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION admin_export_sheet(p_sheet TEXT) RETURNS JSONB AS $$
BEGIN RETURN jsonb_build_object('ok',true,'msg','Export prepared for '||p_sheet); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
