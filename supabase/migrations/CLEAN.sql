-- ============================================================
-- CLEAN.sql — ONE FILE TO REPLACE EVERYTHING
-- Column names verified against 001_init.sql (THE source of truth)
-- Run AFTER 001_init.sql and 000_pgcrypto.sql
-- ============================================================

-- ============================================================
-- 0. ADD plan COLUMN TO user_roles
-- ============================================================
ALTER TABLE user_roles ADD COLUMN IF NOT EXISTS plan TEXT DEFAULT 'FREE';
UPDATE user_roles SET plan = 'FREE' WHERE plan IS NULL;

-- ============================================================
-- 1. DROP ALL EXISTING FUNCTIONS (safe)
-- ============================================================
DO $$ DECLARE fn TEXT; BEGIN
  FOREACH fn IN ARRAY ARRAY[
    'login_worker','login_admin','generate_worker_otp','verify_worker_otp','generate_admin_otp','verify_admin_otp','get_worker_profile','get_worker_status',
    'get_worker_requests','create_worker_request','get_worker_payroll',
    'get_worker_leave','get_worker_learning','get_worker_engagement',
    'get_worker_notifications','get_worker_narrative','get_worker_profile',
    'get_announcements','get_my_role','get_my_plan','list_ideas','submit_voice',
    'get_my_continuous_performance','get_my_compensation_intelligence',
    'get_career_path','get_skills_intelligence','get_benefit_data',
    'get_near_miss_data','get_learning_recommendations','get_talent_marketplace',
    'get_succession','get_coaching_catalog','get_compliance_catalog',
    'get_benefit_catalog','get_document_types','get_team_data','get_team_requests',
    'approve_team_request','get_team_narrative','get_manager_command_data',
    'get_subtree_data','get_continuous_perf_team','get_people_search',
    'get_ceo_command_data','get_organization_health','get_early_warning',
    'get_executive_summary','get_workforce_planning','get_workforce_health_score',
    'get_anomaly_sentinel','get_dashboard_stats','get_kpi_by_division',
    'get_safety_summary','get_turnover_data','get_flight_risk_list',
    'get_flight_risk_details','get_action_center','get_production_output',
    'get_plantation_harvest','get_equipment_util','get_shift_schedule',
    'get_calendar_holidays','get_work_schedule','get_overtime_data',
    'get_medical_checkup','calculate_ltifr','get_compliance_rate',
    'get_exit_clearance','get_capability_gap','get_competency_matrix',
    'get_succession_matrix','get_penalty_matrix','get_monthly_snapshot_trend',
    'get_kpi_calc_log','request_training','get_my_training_requests',
    'get_training_catalog','admin_get_summary','admin_get_pending',
    'admin_approve_pending','admin_reject_pending','admin_get_audit_log',
    'admin_get_org_structure','admin_get_divisions','admin_export_sheet',
    'export_employees','export_payroll','get_financial_stats',
    'get_financial_trend','get_cost_per_unit','get_kpi_config_all',
    'get_kpi_calc_log_all','get_realtime_notifications',
    'get_auto_healing_actions','check_access_','tier_msg_',
    'get_shift_schedule','get_calendar_holidays','get_work_schedule',
    'get_overtime_data','get_medical_checkup','calculate_ltifr',
    'get_compliance_rate','get_exit_clearance','get_capability_gap',
    'get_competency_matrix','get_succession_matrix','get_penalty_matrix',
    'get_monthly_snapshot_trend','get_kpi_calc_log','request_training',
    'get_my_training_requests','get_training_catalog',
    'get_worker_leave','get_worker_payroll','get_worker_learning',
    'get_worker_engagement','get_worker_notifications','list_ideas',
    'submit_voice','get_my_continuous_performance','get_my_compensation_intelligence',
    'get_career_path','get_skills_intelligence','get_benefit_data',
    'get_near_miss_data','get_learning_recommendations','get_talent_marketplace',
    'get_succession','get_coaching_catalog','get_compliance_catalog',
    'get_benefit_catalog','get_document_types','get_team_data',
    'get_team_requests','approve_team_request','get_team_narrative',
    'get_manager_command_data','get_subtree_data','get_continuous_perf_team',
    'get_people_search','get_ceo_command_data','get_organization_health',
    'get_early_warning','get_executive_summary','get_workforce_planning',
    'get_workforce_health_score','get_anomaly_sentinel','get_dashboard_stats',
    'get_kpi_by_division','get_safety_summary','get_turnover_data',
    'get_flight_risk_list','get_flight_risk_details','get_action_center',
    'get_production_output','get_plantation_harvest','get_equipment_util',
    'get_shift_schedule','get_calendar_holidays','get_work_schedule',
    'get_overtime_data','get_medical_checkup','calculate_ltifr',
    'get_compliance_rate','get_exit_clearance','get_capability_gap',
    'get_competency_matrix','get_succession_matrix','get_penalty_matrix',
    'get_monthly_snapshot_trend','get_kpi_calc_log','request_training',
    'get_my_training_requests','get_training_catalog','admin_get_summary',
    'admin_get_pending','admin_approve_pending','admin_reject_pending',
    'admin_get_audit_log','admin_get_org_structure','admin_get_divisions',
    'admin_export_sheet','export_employees','export_payroll',
    'get_financial_stats','get_financial_trend','get_cost_per_unit',
    'get_kpi_config_all','get_kpi_calc_log_all','get_realtime_notifications',
    'get_auto_healing_actions','check_access_','tier_msg_'
  ] LOOP
    BEGIN EXECUTE 'DROP FUNCTION IF EXISTS '||fn||'(TEXT) CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE 'DROP FUNCTION IF EXISTS '||fn||'(TEXT,TEXT) CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE 'DROP FUNCTION IF EXISTS '||fn||'(TEXT,TEXT,TEXT) CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE 'DROP FUNCTION IF EXISTS '||fn||'(TEXT,DATE,DATE) CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE 'DROP FUNCTION IF EXISTS '||fn||'(INT) CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE 'DROP FUNCTION IF EXISTS '||fn||'(INT,TEXT) CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE 'DROP FUNCTION IF EXISTS '||fn||'() CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE 'DROP FUNCTION IF EXISTS '||fn||'(BOOLEAN) CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE 'DROP FUNCTION IF EXISTS '||fn||'(TEXT,BOOLEAN) CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE 'DROP FUNCTION IF EXISTS '||fn||'(TEXT,TEXT,TEXT,TEXT) CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
  END LOOP;
END $$;


-- ============================================================
-- 2. HELPER FUNCTIONS
-- ============================================================

CREATE OR REPLACE FUNCTION check_access_(p_nrp TEXT, p_min_level INT, p_min_tier TEXT) RETURNS BOOLEAN AS $$
DECLARE v_level INT; v_tier TEXT; v_tier_rank INT; v_min_rank INT;
BEGIN
  SELECT role_level INTO v_level FROM user_roles WHERE nrp = p_nrp;
  SELECT COALESCE(plan, 'FREE') INTO v_tier FROM user_roles WHERE nrp = p_nrp;
  IF v_level IS NULL THEN v_level := 1; END IF;
  IF v_tier IS NULL THEN v_tier := 'FREE'; END IF;
  IF v_level >= p_min_level THEN RETURN TRUE; END IF;
  v_tier_rank := CASE v_tier WHEN 'ENTERPRISE' THEN 5 WHEN 'PREMIUM' THEN 4 WHEN 'STANDAR' THEN 3 WHEN 'MINIMALIS' THEN 2 ELSE 1 END;
  v_min_rank := CASE p_min_tier WHEN 'ENTERPRISE' THEN 5 WHEN 'PREMIUM' THEN 4 WHEN 'STANDAR' THEN 3 WHEN 'MINIMALIS' THEN 2 ELSE 1 END;
  RETURN v_tier_rank >= v_min_rank;
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION tier_msg_(p_feature TEXT, p_min_tier TEXT) RETURNS TEXT AS $$
BEGIN RETURN 'Fitur "' || p_feature || '" memerlukan paket ' || p_min_tier; END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- 3. AUTH FUNCTIONS
-- ============================================================

CREATE OR REPLACE FUNCTION login_worker(p_nrp TEXT, p_password TEXT) RETURNS JSONB AS $$
DECLARE v_w RECORD; v_r RECORD; v_new_salt TEXT; v_computed TEXT;
BEGIN
  SELECT * INTO v_w FROM worker_passwords WHERE nrp = p_nrp AND is_active = true;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'msg','NRP tidak ditemukan.'); END IF;
  IF v_w.blocked_until IS NOT NULL AND v_w.blocked_until > NOW() THEN
    RETURN jsonb_build_object('ok',false,'msg','Akun terkunci.'); END IF;
  IF v_w.salt IS NULL OR v_w.salt = '' OR v_w.password_hash IS NULL OR v_w.password_hash = '' THEN
    IF p_password = v_w.password_hash THEN
      v_new_salt := encode(gen_random_bytes(16),'hex');
      v_computed := encode(digest(p_password || v_new_salt,'sha256'),'hex');
      UPDATE worker_passwords SET password_hash=v_computed, salt=v_new_salt, attempts=0, blocked_until=NULL WHERE nrp=p_nrp;
    ELSE
      UPDATE worker_passwords SET attempts=attempts+1 WHERE nrp=p_nrp;
      IF v_w.attempts+1 >= 5 THEN UPDATE worker_passwords SET blocked_until=NOW()+INTERVAL '15 minutes' WHERE nrp=p_nrp;
        RETURN jsonb_build_object('ok',false,'msg','Terlalu banyak percobaan.'); END IF;
      RETURN jsonb_build_object('ok',false,'msg','Password salah.'); END IF;
  ELSE
    v_computed := encode(digest(p_password || v_w.salt,'sha256'),'hex');
    IF v_computed != v_w.password_hash THEN
      UPDATE worker_passwords SET attempts=attempts+1 WHERE nrp=p_nrp;
      IF v_w.attempts+1 >= 5 THEN UPDATE worker_passwords SET blocked_until=NOW()+INTERVAL '15 minutes' WHERE nrp=p_nrp;
        RETURN jsonb_build_object('ok',false,'msg','Terlalu banyak percobaan.'); END IF;
      RETURN jsonb_build_object('ok',false,'msg','Password salah.'); END IF;
    UPDATE worker_passwords SET attempts=0, blocked_until=NULL WHERE nrp=p_nrp;
  END IF;
  SELECT * INTO v_r FROM user_roles WHERE nrp=p_nrp;
  RETURN jsonb_build_object('ok',true,'nrp',p_nrp,
    'nama',(SELECT nama FROM employees_master WHERE nrp=p_nrp LIMIT 1),
    'level',COALESCE(v_r.role_level,1),'tier',COALESCE(v_r.plan,'FREE'),
    'position',(SELECT posisi FROM employees_master WHERE nrp=p_nrp LIMIT 1),
    'divisi',(SELECT divisi FROM employees_master WHERE nrp=p_nrp LIMIT 1));
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION login_admin(p_password TEXT) RETURNS JSONB AS $$
DECLARE v_stored TEXT;
BEGIN
  SELECT value INTO v_stored FROM settings WHERE key='admin_password';
  IF NOT FOUND THEN v_stored := 'Admin123'; END IF;
  IF p_password = v_stored THEN
    RETURN jsonb_build_object('ok',true,'token',encode(gen_random_bytes(16),'hex'),'role','admin');
  ELSE RETURN jsonb_build_object('ok',false,'msg','Password admin salah.'); END IF;
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_my_role(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v RECORD; BEGIN SELECT * INTO v FROM user_roles WHERE nrp=p_nrp;
IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'msg','Role not found'); END IF;
RETURN jsonb_build_object('ok',true,'nrp',p_nrp,'level',v.role_level,'tier',COALESCE(v.plan,'FREE')); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_my_plan(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v RECORD; BEGIN SELECT * INTO v FROM user_roles WHERE nrp=p_nrp;
RETURN jsonb_build_object('ok',true,'plan',COALESCE(v.plan,'FREE'),'level',COALESCE(v.role_level,1)); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- 4. WORKER FUNCTIONS (table column reference: 001_init.sql)
-- ============================================================

-- get_worker_profile: employees_master columns
CREATE OR REPLACE FUNCTION get_worker_profile(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v_e RECORD; v_r RECORD; BEGIN
  IF NOT check_access_(p_nrp,1,'MINIMALIS') THEN RETURN jsonb_build_object('ok',false,'msg',tier_msg_('Profil','MINIMALIS')); END IF;
  SELECT * INTO v_e FROM employees_master WHERE nrp=p_nrp;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'msg','Tidak ditemukan'); END IF;
  SELECT * INTO v_r FROM user_roles WHERE nrp=p_nrp;
  RETURN jsonb_build_object('ok',true,'nrp',v_e.nrp,'nama',v_e.nama,'nik',v_e.nik,'email',v_e.email,
    'divisi',v_e.divisi,'posisi',v_e.posisi,'level',COALESCE(v_r.role_level,1),'tier',COALESCE(v_r.plan,'FREE'),
    'tanggal_lahir',v_e.tanggal_lahir,'jenis_kelamin',v_e.jenis_kelamin,'status_kerja',v_e.status_kerja,
    'tanggal_mulai',v_e.tanggal_masuk,'no_hp',v_e.no_hp); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- get_worker_status: hr_performance + hr_attendance
CREATE OR REPLACE FUNCTION get_worker_status(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v_k RECORD; v_a RECORD; BEGIN
  IF NOT check_access_(p_nrp,1,'MINIMALIS') THEN RETURN jsonb_build_object('ok',false,'msg',tier_msg_('Status','MINIMALIS')); END IF;
  SELECT * INTO v_k FROM hr_performance WHERE nrp=p_nrp ORDER BY periode DESC LIMIT 1;
  SELECT COUNT(*) FILTER(WHERE status_hadir='Hadir') as h, COUNT(*) FILTER(WHERE status_hadir='Telat') as t,
    COUNT(*) FILTER(WHERE status_hadir IN ('Izin','Sakit')) as i, COUNT(*) as tot INTO v_a
  FROM hr_attendance WHERE nrp=p_nrp AND date>=date_trunc('month',NOW()) AND date<date_trunc('month',NOW())+INTERVAL '1 month';
  RETURN jsonb_build_object('ok',true,'kpi_score',COALESCE(v_k.kpi_score,0),'kpi_period',COALESCE(v_k.periode,''),
    'attendance_hadir',COALESCE(v_a.h,0),'attendance_telat',COALESCE(v_a.t,0),
    'attendance_izin',COALESCE(v_a.i,0),'attendance_total',COALESCE(v_a.tot,0)); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- get_worker_requests: hr_requests
CREATE OR REPLACE FUNCTION get_worker_requests(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'type',type,'status',status,'note',note,'created_at',created_at) ORDER BY created_at DESC),'[]'::jsonb))
FROM hr_requests WHERE nrp=p_nrp LIMIT 20); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- create_worker_request
CREATE OR REPLACE FUNCTION create_worker_request(p_nrp TEXT,p_type TEXT,p_reason TEXT,p_from DATE,p_to DATE) RETURNS JSONB AS $$
BEGIN INSERT INTO hr_requests(id,nrp,type,status,note) VALUES(encode(gen_random_bytes(8),'hex'),p_nrp,p_type,'Pending',p_reason);
RETURN jsonb_build_object('ok',true,'msg','Request dikirim.'); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- get_worker_leave: hr_leave
CREATE OR REPLACE FUNCTION get_worker_leave(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v RECORD; BEGIN SELECT * INTO v FROM hr_leave WHERE nrp=p_nrp ORDER BY tahun DESC LIMIT 1;
IF NOT FOUND THEN RETURN jsonb_build_object('ok',true,'kuota',0,'terpakai',0,'sisa',0); END IF;
RETURN jsonb_build_object('ok',true,'kuota',COALESCE(v.kuota_cuti,12),'terpakai',COALESCE(v.cuti_terpakai,0),
  'sisa',COALESCE(v.kuota_cuti,12)-COALESCE(v.cuti_terpakai,0),'tahun',v.tahun); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- get_worker_payroll: hr_payroll (base_salary, allowance, deduction, overtime_pay, net_salary)
CREATE OR REPLACE FUNCTION get_worker_payroll(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('periode',periode,'base_salary',base_salary,'allowance',allowance,'deduction',deduction,'overtime_pay',overtime_pay,'net_salary',net_salary) ORDER BY created_at DESC),'[]'::jsonb))
FROM hr_payroll WHERE nrp=p_nrp LIMIT 12); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- get_worker_learning: hr_learning
CREATE OR REPLACE FUNCTION get_worker_learning(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'type',type,'title',title,'status',status,'start_date',start_date,'end_date',end_date) ORDER BY created_at DESC),'[]'::jsonb))
FROM hr_learning WHERE nrp=p_nrp LIMIT 20); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- get_worker_engagement: hr_engagement (score, period — NO category column)
CREATE OR REPLACE FUNCTION get_worker_engagement(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v RECORD; BEGIN SELECT * INTO v FROM hr_engagement WHERE nrp=p_nrp ORDER BY created_at DESC LIMIT 1;
IF NOT FOUND THEN RETURN jsonb_build_object('ok',true,'score',0,'category','N/A'); END IF;
RETURN jsonb_build_object('ok',true,'score',COALESCE(v.score,0),
  'category',CASE WHEN v.score>=80 THEN 'Highly Engaged' WHEN v.score>=60 THEN 'Engaged' ELSE 'Needs Attention' END,'period',v.period); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- get_worker_notifications: hr_notifications (is_read — NOT read_flag)
CREATE OR REPLACE FUNCTION get_worker_notifications(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'unread',(SELECT COUNT(*) FROM hr_notifications WHERE nrp=p_nrp AND is_read=false),
  'data',COALESCE(jsonb_agg(jsonb_build_object('id',id,'category',category,'title',title,'message',message,'read_flag',is_read,'created_at',created_at) ORDER BY created_at DESC),'[]'::jsonb))
FROM hr_notifications WHERE nrp=p_nrp LIMIT 20); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- get_worker_benefits: hr_benefits (jenis_benefit, nilai)
CREATE OR REPLACE FUNCTION get_worker_benefits(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('jenis_benefit',jenis_benefit,'nilai',nilai)),'[]'::jsonb))
FROM hr_benefits WHERE nrp=p_nrp); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- get_worker_skills: hr_skills (skill_name, level, target_level)
CREATE OR REPLACE FUNCTION get_worker_skills(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('skill',skill_name,'current_level',level,'required_level',target_level,'gap',target_level-level,'certified',certified)),'[]'::jsonb))
FROM hr_skills WHERE nrp=p_nrp); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- get_worker_medical: hr_medical_checkup
CREATE OR REPLACE FUNCTION get_worker_medical(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('checkup_date',checkup_date,'result',result,'expiry_date',expiry_date) ORDER BY checkup_date DESC),'[]'::jsonb))
FROM hr_medical_checkup WHERE nrp=p_nrp LIMIT 5); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- get_worker_overtime: hr_overtime
CREATE OR REPLACE FUNCTION get_worker_overtime(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('date',date,'hours',hours,'reason',reason,'status',status) ORDER BY date DESC),'[]'::jsonb))
FROM hr_overtime WHERE nrp=p_nrp LIMIT 10); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- get_worker_exit: hr_exit_clearance
CREATE OR REPLACE FUNCTION get_worker_exit(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('resign_date',resign_date,'last_work_date',last_work_date,'clearance_status',clearance_status)),'[]'::jsonb))
FROM hr_exit_clearance WHERE nrp=p_nrp); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- get_worker_capability: hr_capability (kompetensi, level_sekarang, level_target, gap)
CREATE OR REPLACE FUNCTION get_worker_capability(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('kompetensi',kompetensi,'level_sekarang',level_sekarang,'level_target',level_target,'gap',gap,'is_mandatory',is_mandatory)),'[]'::jsonb))
FROM hr_capability WHERE nrp=p_nrp); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- get_worker_relations: hr_relations
CREATE OR REPLACE FUNCTION get_worker_relations(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('type',type,'related_nrp',related_nrp,'notes',notes)),'[]'::jsonb))
FROM hr_relations WHERE nrp=p_nrp); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- get_worker_critical: hr_critical
CREATE OR REPLACE FUNCTION get_worker_critical(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('position',position,'backup_nrp',backup_nrp,'risk_level',risk_level)),'[]'::jsonb))
FROM hr_critical WHERE nrp=p_nrp); END; $$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- 5. ENGAGEMENT (hr_voice: type, nrp, title, description, status, votes)
-- ============================================================

CREATE OR REPLACE FUNCTION list_ideas(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'type',type,'title',title,'description',description,'status',status,'votes',votes) ORDER BY created_at DESC),'[]'::jsonb))
FROM hr_voice LIMIT 50); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION submit_voice(p_nrp TEXT,p_type TEXT,p_title TEXT,p_details TEXT,p_anonymous BOOLEAN) RETURNS JSONB AS $$
BEGIN INSERT INTO hr_voice(id,type,nrp,title,description,status) VALUES('V'||encode(gen_random_bytes(4),'hex'),p_type,p_nrp,p_title,p_details,'SUBMITTED');
RETURN jsonb_build_object('ok',true,'msg','Ide dikirim.'); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION vote_idea(p_idea_id TEXT) RETURNS JSONB AS $$
BEGIN UPDATE hr_voice SET votes=votes+1 WHERE id=p_idea_id;
IF FOUND THEN RETURN jsonb_build_object('ok',true,'msg','Vote berhasil.'); END IF;
RETURN jsonb_build_object('ok',false,'msg','Ide tidak ditemukan.'); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- 6. TRAINING (hr_learning, hr_training_catalog)
-- ============================================================

CREATE OR REPLACE FUNCTION request_training(p_nrp TEXT,p_code TEXT,p_reason TEXT) RETURNS JSONB AS $$
BEGIN INSERT INTO hr_learning(nrp,type,title,status) VALUES(p_nrp,'REQUEST',p_code,'REQUESTED');
RETURN jsonb_build_object('ok',true,'msg','Training request dikirim.'); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_my_training_requests(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'type',type,'title',title,'status',status,'start_date',start_date) ORDER BY created_at DESC),'[]'::jsonb))
FROM hr_learning WHERE nrp=p_nrp LIMIT 20); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_training_catalog() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'title',title,'category',category,'provider',provider,'duration_hours',duration_hours,'priority',priority)),'[]'::jsonb))
FROM hr_training_catalog); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_learning_recommendations(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('title',title,'category',category)),'[]'::jsonb))
FROM hr_training_catalog WHERE priority='HIGH' LIMIT 5); END; $$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- 7. TALENT & CAREER
-- ============================================================

CREATE OR REPLACE FUNCTION get_career_path(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v_e RECORD; v_ps RECORD; BEGIN
  SELECT * INTO v_e FROM employees_master WHERE nrp=p_nrp;
  SELECT * INTO v_ps FROM hr_position_skills WHERE position=v_e.posisi LIMIT 1;
  RETURN jsonb_build_object('ok',true,'current_position',v_e.posisi,'current_level',(SELECT role_level FROM user_roles WHERE nrp=p_nrp),
    'required_skills',COALESCE(v_ps.skill_name,''),'gap_analysis','Complete training to unlock next level'); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_talent_marketplace() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('type',type,'judul',judul,'status',status,'priority',priority)),'[]'::jsonb))
FROM hr_talent_catalog WHERE status='ACTIVE'); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_succession(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('position',position,'candidate_nrp',candidate_nrp,'readiness',readiness)),'[]'::jsonb))
FROM hr_succession WHERE candidate_nrp=p_nrp); END; $$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- 8. CATALOGS
-- ============================================================

CREATE OR REPLACE FUNCTION get_coaching_catalog() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('code',type_code,'type',coaching_type,'topic',default_topic,'duration',duration_minutes)),'[]'::jsonb))
FROM hr_coaching_catalog); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_compliance_catalog() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('kode',kode_kategori,'kategori',kategori,'sub',sub_kategori)),'[]'::jsonb))
FROM hr_compliance_catalog); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_benefit_catalog() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('kode',kode_benefit,'jenis',jenis_benefit,'kategori',kategori,'nilai_default',default_nilai)),'[]'::jsonb))
FROM hr_benefit_catalog); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_document_types() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('type',type,'sub_type',sub_type)),'[]'::jsonb))
FROM hr_document_types); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_competency_matrix() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('level',level,'level_name',level_name,'description',description)),'[]'::jsonb))
FROM hr_competency_matrix); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_penalty_matrix() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('severity',severity,'description',description,'penalty_points',penalty_points)),'[]'::jsonb))
FROM hr_penalty_matrix); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_succession_matrix() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('readiness_level',readiness_level,'description',description,'time_frame',time_frame)),'[]'::jsonb))
FROM hr_succession_matrix); END; $$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- 9. TEAM & MANAGER
-- ============================================================

CREATE OR REPLACE FUNCTION get_team_data(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',e.nrp,'nama',e.nama,'posisi',e.posisi,'divisi',e.divisi,'kpi_score',COALESCE(p.kpi_score,0),'status_kerja',e.status_kerja)),'[]'::jsonb))
FROM hr_org o JOIN employees_master e ON e.nrp=o.nrp LEFT JOIN hr_performance p ON p.nrp=o.nrp WHERE o.atasan_nrp=p_nrp ORDER BY e.nama); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_team_requests(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',r.id,'nrp',r.nrp,'nama',e.nama,'type',r.type,'status',r.status,'note',r.note,'created_at',r.created_at)),'[]'::jsonb))
FROM hr_requests r JOIN hr_org o ON o.nrp=r.nrp AND o.atasan_nrp=p_nrp LEFT JOIN employees_master e ON e.nrp=r.nrp WHERE r.status='Pending' ORDER BY r.created_at ASC); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION approve_team_request(p_id TEXT,p_status TEXT,p_note TEXT) RETURNS JSONB AS $$
BEGIN UPDATE hr_requests SET status=p_status,note=p_note WHERE id=p_id AND status='Pending';
IF FOUND THEN RETURN jsonb_build_object('ok',true,'msg','Request '||p_status); END IF;
RETURN jsonb_build_object('ok',false,'msg','Tidak ditemukan.'); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_manager_command_data(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v_t JSONB; v_r JSONB; BEGIN
  SELECT jsonb_agg(jsonb_build_object('nrp',e.nrp,'nama',e.nama,'kpi',COALESCE(p.kpi_score,0))) INTO v_t
  FROM hr_org o JOIN employees_master e ON e.nrp=o.nrp LEFT JOIN hr_performance p ON p.nrp=o.nrp WHERE o.atasan_nrp=p_nrp;
  SELECT jsonb_agg(jsonb_build_object('id',r.id,'type',r.type,'status',r.status)) INTO v_r
  FROM hr_requests r JOIN hr_org o ON o.nrp=r.nrp AND o.atasan_nrp=p_nrp WHERE r.status='Pending';
  RETURN jsonb_build_object('ok',true,'team',COALESCE(v_t,'[]'::jsonb),'pending',COALESCE(v_r,'[]'::jsonb)); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_subtree_data(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',e.nrp,'nama',e.nama,'atasan',o.atasan_nrp,'posisi',e.posisi,'divisi',e.divisi,'level',COALESCE(ur.role_level,1))),'[]'::jsonb))
FROM employees_master e LEFT JOIN hr_org o ON o.nrp=e.nrp LEFT JOIN user_roles ur ON ur.nrp=e.nrp ORDER BY e.nama); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_continuous_perf_team(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',p.nrp,'nama',e.nama,'periode',p.periode,'kpi_score',p.kpi_score)),'[]'::jsonb))
FROM hr_performance p JOIN hr_org o ON o.nrp=p.nrp AND o.atasan_nrp=p_nrp LEFT JOIN employees_master e ON e.nrp=p.nrp ORDER BY p.created_at DESC LIMIT 20); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_people_search(p_query TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',nrp,'nama',nama,'divisi',divisi,'posisi',posisi)),'[]'::jsonb))
FROM employees_master WHERE nama ILIKE '%'||p_query||'%' OR nrp ILIKE '%'||p_query||'%' LIMIT 20); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- 10. CEO & EXECUTIVE
-- ============================================================

CREATE OR REPLACE FUNCTION get_ceo_command_data(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN jsonb_build_object('ok',true,
  'org_summary',(SELECT COALESCE(jsonb_agg(jsonb_build_object('divisi',d.divisi,'headcount',d.hc,'avg_kpi',d.ak)),'[]'::jsonb) FROM
    (SELECT e.divisi,COUNT(*) as hc,ROUND(AVG(p.kpi_score),1) as ak FROM employees_master e LEFT JOIN hr_performance p ON p.nrp=e.nrp WHERE e.divisi IS NOT NULL GROUP BY e.divisi) d),
  'total_workers',(SELECT COUNT(*) FROM employees_master),
  'avg_kpi',(SELECT COALESCE(ROUND(AVG(kpi_score),1),0) FROM hr_performance WHERE period=(SELECT MAX(period) FROM hr_performance))); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_organization_health() RETURNS JSONB AS $$
BEGIN RETURN jsonb_build_object('ok',true,
  'headcount',(SELECT COUNT(*) FROM employees_master),
  'avg_kpi',(SELECT COALESCE(ROUND(AVG(kpi_score),1),0) FROM hr_performance WHERE periode=(SELECT MAX(periode) FROM hr_performance)),
  'attendance_rate',(SELECT COALESCE(ROUND(COUNT(*) FILTER(WHERE status_hadir='Hadir')::NUMERIC/NULLIF(COUNT(*),0)*100,1),0) FROM hr_attendance WHERE date>=date_trunc('month',NOW())),
  'open_positions',(SELECT COUNT(*) FROM hr_talent_catalog WHERE status='ACTIVE'),
  'pending_requests',(SELECT COUNT(*) FROM hr_requests WHERE status='Pending'),
  'coaching_active',(SELECT COUNT(*) FROM hr_coaching WHERE status='ACTIVE'),
  'compliance_issues',(SELECT COUNT(*) FROM hr_compliance WHERE status='OVERDUE')); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_early_warning() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('category',category,'title',title,'message',message,'created_at',created_at)),'[]'::jsonb))
FROM hr_notifications WHERE is_read=false ORDER BY created_at DESC LIMIT 10); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_executive_summary() RETURNS JSONB AS $$
BEGIN RETURN jsonb_build_object('ok',true,
  'headcount',(SELECT COUNT(*) FROM employees_master),
  'avg_kpi',(SELECT COALESCE(ROUND(AVG(kpi_score),1),0) FROM hr_performance WHERE period=(SELECT MAX(period) FROM hr_performance)),
  'high_performers',(SELECT COUNT(*) FROM hr_performance WHERE kpi_score>=80 AND period=(SELECT MAX(period) FROM hr_performance)),
  'low_performers',(SELECT COUNT(*) FROM hr_performance WHERE kpi_score<60 AND period=(SELECT MAX(period) FROM hr_performance)),
  'turnover_rate',0,'total_payroll',(SELECT COALESCE(SUM(net_salary),0) FROM hr_payroll WHERE periode=(SELECT MAX(periode) FROM hr_payroll))); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_workforce_planning() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('type',type,'judul',judul,'status',status,'priority',priority)),'[]'::jsonb))
FROM hr_talent_catalog); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_workforce_health_score() RETURNS JSONB AS $$
DECLARE v_k NUMERIC; v_a NUMERIC; v_e NUMERIC; BEGIN
  SELECT COALESCE(AVG(kpi_score),70) INTO v_k FROM hr_performance WHERE period=(SELECT MAX(period) FROM hr_performance);
  SELECT COALESCE(COUNT(*) FILTER(WHERE status_hadir='Hadir')::NUMERIC/NULLIF(COUNT(*),0)*100,90) INTO v_a FROM hr_attendance WHERE date>=date_trunc('month',NOW());
  SELECT COALESCE(AVG(score),75) INTO v_e FROM hr_engagement;
  RETURN jsonb_build_object('ok',true,'score',ROUND(v_k*0.4+v_a*0.3+v_e*0.3,1)); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_announcements() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'title',title,'message',message,'priority',priority,'target_audience',target_audience) ORDER BY created_at DESC),'[]'::jsonb))
FROM announcements LIMIT 10); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_skills_intelligence(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN get_worker_skills(p_nrp); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_benefit_data(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN get_worker_benefits(p_nrp); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_anomaly_sentinel() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'agent',agent_name,'type',task_type,'title',title,'status',status)),'[]'::jsonb))
FROM hr_ai_tasks WHERE status='PENDING' ORDER BY created_at DESC LIMIT 10); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- 11. DASHBOARD STATS
-- ============================================================

CREATE OR REPLACE FUNCTION get_dashboard_stats() RETURNS JSONB AS $$
BEGIN RETURN jsonb_build_object('ok',true,
  'total_workers',(SELECT COUNT(*) FROM employees_master),
  'avg_kpi',(SELECT COALESCE(ROUND(AVG(kpi_score),1),0) FROM hr_performance WHERE period=(SELECT MAX(period) FROM hr_performance)),
  'attendance_rate',(SELECT COALESCE(ROUND(COUNT(*) FILTER(WHERE status_hadir='Hadir')::NUMERIC/NULLIF(COUNT(*),0)*100,1),0) FROM hr_attendance WHERE date>=date_trunc('month',NOW())),
  'pending_requests',(SELECT COUNT(*) FROM hr_requests WHERE status='Pending'),
  'high_performers',(SELECT COUNT(*) FROM hr_performance WHERE kpi_score>=80 AND period=(SELECT MAX(period) FROM hr_performance)),
  'low_performers',(SELECT COUNT(*) FROM hr_performance WHERE kpi_score<60 AND period=(SELECT MAX(period) FROM hr_performance))); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_kpi_by_division() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(jsonb_build_object('divisi',divisi,'avg_kpi',avg_kpi,'headcount',headcount) ORDER BY avg_kpi DESC),'[]'::jsonb))
FROM (SELECT e.divisi,ROUND(AVG(p.kpi_score),1) as avg_kpi,COUNT(*) as headcount FROM employees_master e LEFT JOIN hr_performance p ON p.nrp=e.nrp AND p.periode=(SELECT MAX(periode) FROM hr_performance) WHERE e.divisi IS NOT NULL GROUP BY e.divisi) t); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_safety_summary() RETURNS JSONB AS $$
DECLARE v_int INT; v_hrs NUMERIC; BEGIN
  SELECT COUNT(*) INTO v_int FROM hr_safety;
  SELECT SUM(menit_lembur+480)/60 INTO v_hrs FROM hr_attendance WHERE date>=date_trunc('month',NOW());
  RETURN jsonb_build_object('ok',true,'total_incidents',COALESCE(v_int,0),
    'ltifr',CASE WHEN v_hrs>0 THEN ROUND(v_int::NUMERIC/(v_hrs/1000000)*1000000,2) ELSE 0 END,
    'status',CASE WHEN COALESCE(v_int,0)=0 THEN 'AMAN' ELSE 'PERLU PERHATIAN' END); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_turnover_data() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(jsonb_build_object('divisi',divisi,'active',active,'left',left_count,'rate',turnover_rate)),'[]'::jsonb))
FROM (SELECT e.divisi,COUNT(*) as active,COUNT(*) FILTER(WHERE e.status_kerja != 'PKWTT') as left_count,
  ROUND(COUNT(*) FILTER(WHERE e.status_kerja='PKWT')::NUMERIC/NULLIF(COUNT(*),0)*100,1) as turnover_rate
FROM employees_master e WHERE e.divisi IS NOT NULL GROUP BY e.divisi) t); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_flight_risk_list() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',e.nrp,'nama',e.nama,'divisi',e.divisi,'kpi_score',COALESCE(p.kpi_score,0),'telat_count',COALESCE(t.telat_count,0))
  ORDER BY p.kpi_score ASC),'[]'::jsonb))
FROM employees_master e LEFT JOIN hr_performance p ON p.nrp=e.nrp AND p.period=(SELECT MAX(period) FROM hr_performance)
LEFT JOIN (SELECT nrp,COUNT(*) as telat_count FROM hr_attendance WHERE status_hadir='Telat' AND date>=date_trunc('month',NOW()) GROUP BY nrp) t ON t.nrp=e.nrp
WHERE COALESCE(p.kpi_score,100)<70 OR COALESCE(t.telat_count,0)>5 ORDER BY p.kpi_score ASC LIMIT 10); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_flight_risk_details() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',e.nrp,'nama',e.nama,'divisi',e.divisi,'kpi_score',COALESCE(p.kpi_score,0),'telat_count',COALESCE(t.telat_count,0),
  'sp_count',COALESCE(s.sp_count,0)) ORDER BY COALESCE(p.kpi_score,100) ASC),'[]'::jsonb))
FROM employees_master e LEFT JOIN hr_performance p ON p.nrp=e.nrp AND p.period=(SELECT MAX(period) FROM hr_performance)
LEFT JOIN (SELECT nrp,COUNT(*) as telat_count FROM hr_attendance WHERE status_hadir='Telat' AND date>=date_trunc('month',NOW()) GROUP BY nrp) t ON t.nrp=e.nrp
LEFT JOIN (SELECT nrp,COUNT(*) as sp_count FROM hr_relations WHERE type='SP' GROUP BY nrp) s ON s.nrp=e.nrp
WHERE COALESCE(p.kpi_score,100)<70 OR COALESCE(t.telat_count,0)>5); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_action_center() RETURNS JSONB AS $$
BEGIN RETURN jsonb_build_object('ok',true,
  'pending_requests',(SELECT COUNT(*) FROM hr_requests WHERE status='Pending'),
  'pending_registrations',(SELECT COUNT(*) FROM daftar_baru WHERE status='PENDING'),
  'expired_certs',(SELECT COUNT(*) FROM hr_skills WHERE valid_until<NOW()),
  'coaching_pending',(SELECT COUNT(*) FROM hr_coaching WHERE status='SCHEDULED'),
  'compliance_overdue',(SELECT COUNT(*) FROM hr_compliance WHERE status='OVERDUE')); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_anomaly_details() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'agent',agent_name,'type',task_type,'title',title,'status',status,'priority',priority,'details',details_json)),'[]'::jsonb))
FROM hr_ai_tasks ORDER BY created_at DESC LIMIT 20); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_auto_healing_actions() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'type',task_type,'title',title,'status',status,'details',details_json)),'[]'::jsonb))
FROM hr_ai_tasks WHERE task_type IN ('AUTO_COACHING','AUTO_ENROLL','AUTO_REJECT') LIMIT 20); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- 12. NARRATIVE ENGINE
-- ============================================================

CREATE OR REPLACE FUNCTION get_worker_narrative(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v_e RECORD; v_k RECORD; v_a RECORD; v_sapaan TEXT; v_analisis TEXT; v_action TEXT; v_outcome TEXT;
BEGIN
  SELECT * INTO v_e FROM employees_master WHERE nrp=p_nrp;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'msg','Tidak ditemukan'); END IF;
  SELECT * INTO v_k FROM hr_performance WHERE nrp=p_nrp ORDER BY periode DESC LIMIT 1;
  SELECT COUNT(*) FILTER(WHERE status_hadir='Hadir') as h,COUNT(*) as tot,COUNT(*) FILTER(WHERE status_hadir='Telat') as t INTO v_a
  FROM hr_attendance WHERE nrp=p_nrp AND date>=date_trunc('month',NOW()) AND date<date_trunc('month',NOW())+INTERVAL '1 month';
  v_sapaan := 'Halo '||v_e.nama||', performa Anda pada periode '||COALESCE(v_k.periode,'-')||' telah kami evaluasi.';
  IF COALESCE(v_k.kpi_score,0) < 85 THEN
    v_analisis := 'Skor KPI Anda '||COALESCE(v_k.kpi_score,0)::INT||' dari target 85. ';
    IF COALESCE(v_a.t,0) > 3 THEN v_analisis := v_analisis||'Keterlambatan '||v_a.t||' kali perlu diperhatikan. '; END IF;
    v_action := '1. Datang 15 menit lebih awal. 2. Gunakan Digital Leave Request. 3. Evaluasi mandiri setiap Jumat.';
    v_outcome := 'Jika konsisten 1 bulan, KPI naik ke 85+.';
  ELSE
    v_analisis := 'Skor KPI Anda '||COALESCE(v_k.kpi_score,0)::INT||' sudah sesuai target.';
    v_action := '1. Pertahankan konsistensi. 2. Ikuti training lanjutan. 3. Bantu rekan tim.';
    v_outcome := 'Anda berpeluang menjadi High Performer.';
  END IF;
  RETURN jsonb_build_object('ok',true,'nrp',p_nrp,'nama',v_e.nama,'period',COALESCE(v_k.periode,'-'),
    'kpi_score',COALESCE(v_k.kpi_score,0),'kpi_target',85,'gap',85-COALESCE(v_k.kpi_score,0)::INT,
    'sapaan',v_sapaan,'analisis',v_analisis,'action_plan',v_action,'outcome',v_outcome,
    'penutup','Tim HRD siap mendukung.','data_source_mode','live'); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_team_narrative(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v_avg NUMERIC; v_cnt INT; v_low INT; v_high INT; v_n TEXT;
BEGIN
  SELECT ROUND(AVG(p.kpi_score),1),COUNT(*),COUNT(*) FILTER(WHERE p.kpi_score<60),COUNT(*) FILTER(WHERE p.kpi_score>=80)
  INTO v_avg,v_cnt,v_low,v_high FROM hr_performance p JOIN hr_org o ON o.nrp=p.nrp WHERE o.atasan_nrp=p_nrp AND p.period=(SELECT MAX(period) FROM hr_performance);
  v_n := 'Tim '||v_cnt||' anggota, avg KPI '||COALESCE(v_avg,0)||'. ';
  IF v_low>0 THEN v_n:=v_n||v_low||' perlu perhatian. '; END IF;
  IF v_high>0 THEN v_n:=v_n||v_high||' High Performers.'; END IF;
  RETURN jsonb_build_object('ok',true,'avg_kpi',COALESCE(v_avg,0),'team_size',COALESCE(v_cnt,0),
    'low',COALESCE(v_low,0),'high',COALESCE(v_high,0),'narrative',v_n); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- 13. PRODUCTION & OPS
-- ============================================================

CREATE OR REPLACE FUNCTION get_production_output(p_nrp TEXT,p_from DATE,p_to DATE) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('date',date,'volume',volume,'uom',uom,'shift',shift) ORDER BY date DESC),'[]'::jsonb))
FROM hr_production_daily WHERE (p_nrp IS NULL OR nrp=p_nrp) AND (p_from IS NULL OR date>=p_from) AND (p_to IS NULL OR date<=p_to) LIMIT 30); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_plantation_harvest(p_nrp TEXT,p_from DATE,p_to DATE) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('date',date,'block_area',block_area,'tbs_kg',tbs_kg,'quality',quality) ORDER BY date DESC),'[]'::jsonb))
FROM hr_plantation_harvest WHERE (p_nrp IS NULL OR nrp=p_nrp) AND (p_from IS NULL OR date>=p_from) AND (p_to IS NULL OR date<=p_to) LIMIT 30); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_equipment_util(p_machine TEXT,p_from DATE,p_to DATE) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('date',date,'machine_id',machine_id,'availability_pct',availability_pct,'fuel_liters',fuel_liters) ORDER BY date DESC),'[]'::jsonb))
FROM hr_equipment_util WHERE (p_machine IS NULL OR machine_id=p_machine) AND (p_from IS NULL OR date>=p_from) AND (p_to IS NULL OR date<=p_to) LIMIT 30); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- 14. SCHEDULE
-- ============================================================

CREATE OR REPLACE FUNCTION get_shift_schedule() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('shift_code',shift_code,'shift_name',shift_name,'start_time',start_time,'end_time',end_time)),'[]'::jsonb))
FROM hr_shift_master); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_calendar_holidays(p_year INT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('date',date,'is_holiday',is_holiday,'description',description)),'[]'::jsonb))
FROM hr_calendar WHERE EXTRACT(YEAR FROM date)=COALESCE(p_year,EXTRACT(YEAR FROM NOW())::INT)); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_work_schedule(p_divisi TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('divisi_code',divisi_code,'work_days_per_week',work_days_per_week,'roster_pattern',roster_pattern)),'[]'::jsonb))
FROM hr_work_schedule WHERE p_divisi IS NULL OR divisi_code=p_divisi); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_overtime_data(p_nrp TEXT,p_from DATE,p_to DATE) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',nrp,'date',date,'hours',hours,'reason',reason,'status',status) ORDER BY date DESC),'[]'::jsonb))
FROM hr_overtime WHERE (p_nrp IS NULL OR nrp=p_nrp) AND (p_from IS NULL OR date>=p_from) AND (p_to IS NULL OR date<=p_to) LIMIT 30); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- 15. SAFETY & COMPLIANCE
-- ============================================================

CREATE OR REPLACE FUNCTION calculate_ltifr(p_periode TEXT) RETURNS JSONB AS $$
DECLARE v_int INT; v_hrs NUMERIC; BEGIN
  SELECT COUNT(*) INTO v_int FROM hr_safety;
  SELECT SUM(menit_lembur+480)/60 INTO v_hrs FROM hr_attendance WHERE date>=date_trunc('month',NOW());
  RETURN jsonb_build_object('ok',true,'ltifr',CASE WHEN v_hrs>0 THEN ROUND(v_int::NUMERIC/(v_hrs/1000000)*1000000,2) ELSE 0 END,'incidents',v_int); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_compliance_rate(p_divisi TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(jsonb_build_object('kategori',kategori,'status',status,'count',cnt)),'[]'::jsonb))
FROM (SELECT kategori,status,COUNT(*) as cnt FROM hr_compliance GROUP BY kategori,status) t); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_exit_clearance(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',nrp,'resign_date',resign_date,'clearance_status',clearance_status)),'[]'::jsonb))
FROM hr_exit_clearance WHERE p_nrp IS NULL OR nrp=p_nrp); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_medical_checkup(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',nrp,'checkup_date',checkup_date,'result',result,'expiry_date',expiry_date) ORDER BY checkup_date DESC),'[]'::jsonb))
FROM hr_medical_checkup WHERE p_nrp IS NULL OR nrp=p_nrp LIMIT 10); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- 16. CAPABILITY
-- ============================================================

CREATE OR REPLACE FUNCTION get_capability_gap(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',nrp,'kompetensi',kompetensi,'level_sekarang',level_sekarang,'level_target',level_target,'gap',gap,'is_mandatory',is_mandatory)),'[]'::jsonb))
FROM hr_capability WHERE p_nrp IS NULL OR nrp=p_nrp); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- 17. SNAPSHOT & LOGS
-- ============================================================

CREATE OR REPLACE FUNCTION get_monthly_snapshot_trend(p_divisi TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('periode',periode,'divisi',divisi,'headcount',total_headcount,'avg_kpi',avg_kpi,'total_payroll',total_payroll,'revenue',total_revenue,'profit',total_profit) ORDER BY periode DESC),'[]'::jsonb))
FROM hr_monthly_snapshot WHERE p_divisi IS NULL OR divisi=p_divisi LIMIT 12); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_kpi_calc_log() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'nrp',nrp,'periode',periode,'indicator',indicator,'realisasi',realisasi,'target',target,'final_score',final_score) ORDER BY created_at DESC),'[]'::jsonb))
FROM hr_kpi_calc_log LIMIT 50); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_kpi_config_all() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('position_code',position_code,'indicator',indicator,'target_value',target_value,'uom',uom,'weight',weight,'formula_type',formula_type)),'[]'::jsonb))
FROM hr_kpi_config); END; $$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- 18. FINANCIAL (P7)
-- ============================================================

CREATE OR REPLACE FUNCTION get_financial_stats() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('periode',periode,'divisi',divisi,'revenue',revenue,'profit',profit,'opex',opex,  'labor_cost',total_labor_cost,
  'labor_pct',CASE WHEN revenue>0 THEN ROUND(total_labor_cost/revenue*100,1) ELSE 0 END,
  'profit_margin',CASE WHEN revenue>0 THEN ROUND(profit/revenue*100,1) ELSE 0 END) ORDER BY periode DESC),'[]'::jsonb))
FROM hr_finance_kpi); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_financial_trend() RETURNS JSONB AS $
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('periode',x.periode,'total_revenue',x.total_revenue,'total_profit',x.total_profit,'total_labor',x.total_labor,
  'profit_margin',CASE WHEN x.total_revenue>0 THEN ROUND(x.total_profit/x.total_revenue*100,1) ELSE 0 END) ORDER BY x.periode DESC),'[]'::jsonb))
FROM (SELECT periode,SUM(revenue) as total_revenue,SUM(profit) as total_profit,SUM(total_labor_cost) as total_labor FROM hr_finance_kpi GROUP BY periode ORDER BY periode DESC LIMIT 6) x); END;
$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_cost_per_unit() RETURNS JSONB AS $$
DECLARE v_l NUMERIC; v_p NUMERIC; BEGIN
  SELECT SUM(total_labor_cost) INTO v_l FROM hr_finance_kpi WHERE periode=(SELECT MAX(periode) FROM hr_finance_kpi);
  SELECT SUM(volume) INTO v_p FROM hr_production_daily WHERE date>=date_trunc('month',NOW());
  RETURN jsonb_build_object('ok',true,'labor_cost',COALESCE(v_l,0),'total_production',COALESCE(v_p,0),
    'cost_per_ton',CASE WHEN v_p>0 THEN ROUND(v_l/v_p,2) ELSE 0 END); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- 19. PLATFORM (P10)
-- ============================================================

CREATE OR REPLACE FUNCTION export_employees() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',nrp,'nama',nama,'nik',nik,'email',email,'divisi',divisi,'posisi',posisi,'status_kerja',status_kerja,'no_hp',no_hp) ORDER BY nama),'[]'::jsonb))
FROM employees_master); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION export_payroll(p_periode TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',nrp,'periode',periode,'base_salary',base_salary,'allowance',allowance,'deduction',deduction,'net_salary',net_salary) ORDER BY nrp),'[]'::jsonb))
FROM hr_payroll WHERE periode=COALESCE(p_periode,(SELECT MAX(periode) FROM hr_payroll))); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_realtime_notifications(p_nrp TEXT,p_since TIMESTAMPTZ) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'category',category,'title',title,'message',message,'created_at',created_at) ORDER BY created_at DESC),'[]'::jsonb))
FROM hr_notifications WHERE nrp=p_nrp AND created_at > COALESCE(p_since,NOW()-INTERVAL '1 hour') LIMIT 10); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- 20. ADMIN
-- ============================================================

CREATE OR REPLACE FUNCTION admin_get_summary() RETURNS JSONB AS $$
BEGIN RETURN jsonb_build_object('ok',true,
  'total_workers',(SELECT COUNT(*) FROM employees_master),
  'total_divisions',(SELECT COUNT(DISTINCT divisi) FROM employees_master),
  'pending_requests',(SELECT COUNT(*) FROM hr_requests WHERE status='Pending'),
  'pending_registrations',(SELECT COUNT(*) FROM daftar_baru WHERE status='PENDING')); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION admin_get_pending() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'nrp',nrp,'nik',nik,'nama',nama,'email',email,'status',status,'created_at',created_at) ORDER BY created_at ASC),'[]'::jsonb))
FROM daftar_baru WHERE status='PENDING'); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION admin_approve_pending(p_id INT) RETURNS JSONB AS $$
DECLARE v_e RECORD; BEGIN SELECT * INTO v_e FROM daftar_baru WHERE id=p_id AND status='PENDING';
IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'msg','Tidak ditemukan'); END IF;
INSERT INTO employees_master(employee_id,nrp,nik,nama,email,status_kerja) VALUES('EMP'||p_id,v_e.nrp,v_e.nik,v_e.nama,v_e.email,'Active') ON CONFLICT(nrp) DO NOTHING;
INSERT INTO worker_passwords(nrp,password_hash,salt,is_active) VALUES(v_e.nrp,COALESCE(v_e.password_hash,'pending'),COALESCE(v_e.salt,''),true) ON CONFLICT(nrp) DO NOTHING;
INSERT INTO user_roles(nrp,role_level,plan) VALUES(v_e.nrp,1,'FREE') ON CONFLICT(nrp) DO NOTHING;
UPDATE daftar_baru SET status='APPROVED' WHERE id=p_id;
RETURN jsonb_build_object('ok',true,'msg','Disetujui.'); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION admin_reject_pending(p_id INT,p_reason TEXT) RETURNS JSONB AS $$
BEGIN UPDATE daftar_baru SET status='REJECTED' WHERE id=p_id AND status='PENDING';
IF FOUND THEN RETURN jsonb_build_object('ok',true,'msg','Ditolak.'); END IF;
RETURN jsonb_build_object('ok',false,'msg','Tidak ditemukan.'); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION admin_get_audit_log() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('action',action,'result','OK','message',detail,'created_at',timestamp) ORDER BY timestamp DESC),'[]'::jsonb))
FROM audit_log LIMIT 50); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION admin_get_org_structure() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',e.nrp,'nama',e.nama,'divisi',e.divisi,'posisi',e.posisi,'atasan',o.atasan_nrp,'level',COALESCE(ur.role_level,1)) ORDER BY e.nama),'[]'::jsonb))
FROM employees_master e LEFT JOIN hr_org o ON o.nrp=e.nrp LEFT JOIN user_roles ur ON ur.nrp=e.nrp); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION admin_get_divisions() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(jsonb_build_object('divisi',divisi,'headcount',hc)),'[]'::jsonb))
FROM (SELECT divisi,COUNT(*) as hc FROM employees_master WHERE divisi IS NOT NULL GROUP BY divisi) t); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION admin_export_sheet(p_sheet TEXT) RETURNS JSONB AS $$
BEGIN RETURN jsonb_build_object('ok',true,'msg','Export prepared for '||p_sheet); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- 21. SEED DATA (ALL correct column names)
-- ============================================================

-- worker_passwords: default Password123
UPDATE worker_passwords SET password_hash='Password123', salt='', is_active=true, attempts=0, blocked_until=NULL;

-- admin password: Admin123 (explicit, not 'Password123')
INSERT INTO settings (key, value) VALUES ('admin_password', 'Admin123') ON CONFLICT (key) DO UPDATE SET value = 'Admin123';

-- hr_performance (30 workers x 2 periods)
INSERT INTO hr_performance (nrp,periode,kpi_score,feedback_json)
SELECT e.nrp,'2026-07',CASE WHEN e.nrp IN ('NRP001','NRP002','NRP003','NRP004') THEN 85+(random()*15)::int WHEN e.nrp IN ('NRP005','NRP006','NRP007','NRP026') THEN 75+(random()*20)::int ELSE 60+(random()*25)::int END,'{}'
FROM employees_master e ON CONFLICT DO NOTHING;

INSERT INTO hr_performance (nrp,periode,kpi_score,feedback_json)
SELECT e.nrp,'2026-06',CASE WHEN e.nrp IN ('NRP001','NRP002','NRP003','NRP004') THEN 80+(random()*15)::int WHEN e.nrp IN ('NRP005','NRP006','NRP007','NRP026') THEN 70+(random()*20)::int ELSE 55+(random()*30)::int END,'{}'
FROM employees_master e ON CONFLICT DO NOTHING;

-- hr_attendance (30 days x 30 workers)
INSERT INTO hr_attendance (nrp,date,status_hadir,jam_masuk,menit_terlambat,shift)
SELECT e.nrp,d::date,CASE WHEN random()<0.82 THEN 'Hadir' WHEN random()<0.5 THEN 'Telat' WHEN random()<0.5 THEN 'Izin' ELSE 'Sakit' END,
  (TIME '08:00'+(random()*30)::int*INTERVAL '1 minute'),CASE WHEN random()<0.15 THEN (random()*30)::int ELSE 0 END,'REGULER'
FROM employees_master e CROSS JOIN generate_series('2026-07-01'::date,'2026-07-30'::date,'1 day') d WHERE random()<0.95 ON CONFLICT DO NOTHING;

-- hr_leave
INSERT INTO hr_leave (nrp,tahun,kuota_cuti,cuti_terpakai)
SELECT e.nrp,2026,12,(random()*8)::int FROM employees_master e ON CONFLICT DO NOTHING;

-- hr_payroll (2 periods)
INSERT INTO hr_payroll (nrp,periode,base_salary,allowance,deduction,overtime_pay,net_salary)
SELECT e.nrp,'2026-07',CASE WHEN ur.role_level=5 THEN 25000000 WHEN ur.role_level=4 THEN 18000000 WHEN ur.role_level=3 THEN 12000000 ELSE 7000000 END,
  (random()*3000000)::int,(random()*1500000)::int,(random()*2000000)::int,0
FROM employees_master e LEFT JOIN user_roles ur ON ur.nrp=e.nrp ON CONFLICT DO NOTHING;
UPDATE hr_payroll SET net_salary=base_salary+allowance+overtime_pay-deduction WHERE periode='2026-07';

INSERT INTO hr_payroll (nrp,periode,base_salary,allowance,deduction,overtime_pay,net_salary)
SELECT e.nrp,'2026-06',CASE WHEN ur.role_level=5 THEN 25000000 WHEN ur.role_level=4 THEN 18000000 WHEN ur.role_level=3 THEN 12000000 ELSE 7000000 END,
  (random()*3000000)::int,(random()*1500000)::int,(random()*2000000)::int,0
FROM employees_master e LEFT JOIN user_roles ur ON ur.nrp=e.nrp ON CONFLICT DO NOTHING;
UPDATE hr_payroll SET net_salary=base_salary+allowance+overtime_pay-deduction WHERE periode='2026-06';

-- hr_engagement
INSERT INTO hr_engagement (nrp,score,period) SELECT e.nrp,50+(random()*50)::int,'2026-07' FROM employees_master e ON CONFLICT DO NOTHING;

-- hr_voice
INSERT INTO hr_voice (id,type,nrp,title,description,status,votes) VALUES
('V001','IDEA','NRP001','Efisiensi listrik','Matikan AC saat istirahat','SUBMITTED',5),
('V002','SUGGESTION','NRP005','Shift fleksibel','Jam kerja fleksibel','SUBMITTED',12),
('V003','COMPLAINT','NRP010','AC rusak','AC lantai 3 mati','SUBMITTED',8),
('V004','IDEA','NRP020','Hemat ATK','Pakai refill','SUBMITTED',3) ON CONFLICT DO NOTHING;

-- hr_requests
INSERT INTO hr_requests (id,nrp,type,status,note) VALUES
('R001','NRP008','Cuti','Pending','Cuti tahunan'),('R002','NRP010','Surat','Approved','Surat keterangan'),
('R003','NRP015','Lembur','Pending','Lembur projek'),('R004','NRP020','Sakit','Rejected','Tanpa surat dokter') ON CONFLICT DO NOTHING;

-- hr_learning
INSERT INTO hr_learning (nrp,type,title,status,start_date) SELECT e.nrp,
  (ARRAY['SAFETY','TECHNICAL','SOFT_SKILL'])[1+(n%3)],(ARRAY['Training K3','SOP Produksi','Leadership','First Aid'])[1+(n%4)],
  (ARRAY['COMPLETED','IN_PROGRESS','REQUESTED'])[1+(n%3)],('2026-07-'||LPAD((1+(random()*28)::int)::text,2,'0'))::date
FROM employees_master e CROSS JOIN generate_series(1,2) n WHERE random()<0.5 ON CONFLICT DO NOTHING;

-- hr_notifications (NO priority column!)
INSERT INTO hr_notifications (id,nrp,category,title,message,is_read) SELECT 'N'||LPAD(n::text,4,'0'),e.nrp,
  (ARRAY['KPI','ATTENDANCE','TRAINING','SYSTEM'])[1+(n%4)],(ARRAY['Evaluasi KPI','Pengingat Kehadiran','Training Mandatory','Update Sistem'])[1+(n%4)],
  (ARRAY['Silakan cek KPI.','Pastikan kehadiran tepat waktu.'])[1+(n%2)],random()<0.3
FROM employees_master e CROSS JOIN generate_series(1,2) n WHERE random()<0.3 ON CONFLICT DO NOTHING;

-- hr_safety
INSERT INTO hr_safety (nrp,incident_type,date,severity,description,near_miss,incident_date) SELECT e.nrp,'ACCIDENT',
  ('2026-07-'||LPAD((1+(random()*28)::int)::text,2,'0'))::date,'LOW','Incident at '||e.divisi,random()<0.3,
  ('2026-07-'||LPAD((1+(random()*28)::int)::text,2,'0'))::date
FROM employees_master e WHERE random()<0.1 ON CONFLICT DO NOTHING;

-- hr_compliance
INSERT INTO hr_compliance (id,kategori,status,due_date,penanggung_nrp) VALUES
('C001','K3 Training','COMPLIANT','2026-08-15','NRP001'),('C002','Medical Checkup','OVERDUE','2026-07-01','NRP002'),('C003','Certificate','PENDING','2026-09-01','NRP005') ON CONFLICT DO NOTHING;

-- hr_benefits
INSERT INTO hr_benefits (id,nrp,jenis_benefit,nilai) SELECT 'B'||LPAD(n::text,3,'0'),e.nrp,(ARRAY['BPJS-KES','BPJS-TK','THP'])[1+(n%3)],(random()*5000000)::int
FROM employees_master e CROSS JOIN generate_series(1,3) n WHERE random()<0.5 ON CONFLICT DO NOTHING;

-- hr_coaching
INSERT INTO hr_coaching (nrp,coach_nrp,topic,status,session_date) SELECT e.nrp,'NRP002','Performance Improvement','ACTIVE',
('2026-07-'||LPAD((1+(random()*28)::int)::text,2,'0'))::date FROM employees_master e WHERE random()<0.2 ON CONFLICT DO NOTHING;

-- hr_skills
INSERT INTO hr_skills (id,nrp,skill_name,level,target_level,certified) VALUES
('SK001','NRP001','Leadership',4,5,true),('SK002','NRP002','People Management',3,4,true),
('SK003','NRP005','Safety K3',2,3,true),('SK004','NRP008','Data Analysis',2,3,false),('SK005','NRP020','Operational',1,3,false) ON CONFLICT DO NOTHING;

-- hr_capability
INSERT INTO hr_capability (nrp,kompetensi,level_sekarang,level_target,gap,is_mandatory) VALUES
('NRP001','Leadership',4,5,1,false),('NRP002','People Management',3,4,1,false),
('NRP005','Safety K3',2,3,1,true),('NRP008','Data Analysis',2,3,1,false),('NRP020','Operational',1,3,2,true) ON CONFLICT DO NOTHING;

-- hr_production_daily
INSERT INTO hr_production_daily (nrp,date,shift,volume,uom) SELECT e.nrp,d::date,'REGULER',(3000+random()*4000)::int,'Ton'
FROM employees_master e CROSS JOIN generate_series('2026-07-01'::date,'2026-07-15'::date,'1 day') d WHERE e.divisi='OPERATIONAL' AND random()<0.8 ON CONFLICT DO NOTHING;

-- hr_finance_kpi
INSERT INTO hr_finance_kpi (periode,divisi,total_employee_avg,revenue,profit,opex,total_labor_cost) VALUES
('2026-07','HRD',8,250000000,50000000,180000000,120000000),('2026-07','FINANCE',6,180000000,35000000,130000000,90000000),
('2026-07','OPERATIONAL',12,450000000,120000000,280000000,200000000),('2026-07','IT',4,120000000,25000000,85000000,60000000),
('2026-06','HRD',8,240000000,48000000,175000000,118000000),('2026-06','FINANCE',6,175000000,33000000,128000000,88000000),
('2026-06','OPERATIONAL',12,430000000,115000000,270000000,195000000),('2026-06','IT',4,115000000,23000000,82000000,58000000) ON CONFLICT DO NOTHING;

-- hr_monthly_snapshot
INSERT INTO hr_monthly_snapshot (periode,divisi,total_headcount,avg_kpi,total_payroll,total_revenue,total_profit) VALUES
('2026-07','HRD',8,82,120000000,250000000,50000000),('2026-07','FINANCE',6,85,90000000,180000000,35000000),
('2026-07','OPERATIONAL',12,72,200000000,450000000,120000000),('2026-07','IT',4,88,60000000,120000000,25000000),
('2026-06','HRD',8,80,118000000,240000000,48000000),('2026-06','FINANCE',6,83,88000000,175000000,33000000),
('2026-06','OPERATIONAL',12,70,195000000,430000000,115000000),('2026-06','IT',4,86,58000000,115000000,23000000) ON CONFLICT DO NOTHING;

-- hr_ai_tasks
INSERT INTO hr_ai_tasks (id,agent_name,task_type,title,status,priority,details_json) VALUES
('AI001','HREngine','ANOMALY','Produksi turun 25% OPERATIONAL','ACTIVE','HIGH','{"division":"OPERATIONAL","drop_pct":25}'),
('AI002','HREngine','FLIGHT_RISK','NRP020 high risk score 82','ACTIVE','HIGH','{"nrp":"NRP020","score":82}'),
('AI003','HREngine','AUTO_COACHING','Auto-coaching NRP020 KPI<60','ACTIVE','HIGH','{"nrp":"NRP020","topic":"PIP"}') ON CONFLICT DO NOTHING;

-- hr_relations
INSERT INTO hr_relations (nrp,type,related_nrp,notes) VALUES ('NRP020','SP','NRP002','SP1 - Keterlambatan'),('NRP021','SP','NRP002','SP1 - Absensi') ON CONFLICT DO NOTHING;

-- hr_succession
INSERT INTO hr_succession (id,position,candidate_nrp,readiness,notes) VALUES
('SUC001','Manager HRD','NRP005','Ready Soon','6 bulan'),('SUC002','Kepala IT','NRP026','Ready Now','Senior') ON CONFLICT DO NOTHING;

-- hr_critical
INSERT INTO hr_critical (nrp,position,backup_nrp,risk_level) VALUES
('NRP001','CEO','NRP002','HIGH'),('NRP002','Manager HRD','NRP005','MEDIUM'),('NRP004','Manager Operasional','NRP007','HIGH') ON CONFLICT DO NOTHING;

-- hr_talent_catalog
INSERT INTO hr_talent_catalog (id,type,judul,status,priority) VALUES ('T001','POSITION','Staff IT','ACTIVE','HIGH'),('T002','POSITION','Supervisor Operasional','ACTIVE','MEDIUM') ON CONFLICT DO NOTHING;

-- hr_coaching_catalog
INSERT INTO hr_coaching_catalog (type_code,coaching_type,default_topic,duration_minutes) VALUES ('PIP','Performance Improvement','KPI improvement',60),('LEAD','Leadership','Leadership dev',90) ON CONFLICT DO NOTHING;

-- hr_compliance_catalog
INSERT INTO hr_compliance_catalog (kode_kategori,kategori,sub_kategori) VALUES ('K3','K3 Training','Monthly'),('MED','Medical Checkup','Annual') ON CONFLICT DO NOTHING;

-- hr_benefit_catalog
INSERT INTO hr_benefit_catalog (kode_benefit,jenis_benefit,kategori,default_nilai) VALUES ('BPJS-KES','BPJS Kesehatan','Health',0),('BPJS-TK','BPJS Ketenagakerjaan','Insurance',0) ON CONFLICT DO NOTHING;

-- hr_document_types
INSERT INTO hr_document_types (type,sub_type) VALUES ('KTP','Identity'),('SK','Appointment'),('Ijazah','Diploma'),('Sertifikat','Certificate'),('Kontrak','Contract') ON CONFLICT DO NOTHING;

-- hr_competency_matrix
INSERT INTO hr_competency_matrix (id,level,level_name,description) VALUES (1,1,'Staff','Basic'),(2,2,'Senior','Advanced'),(3,3,'Supervisor','Leadership'),(4,4,'Manager','Strategic'),(5,5,'Director','Executive') ON CONFLICT DO NOTHING;

-- hr_succession_matrix
INSERT INTO hr_succession_matrix (id,readiness_level,description,time_frame) VALUES (1,'Ready Now','Immediately','0-3mo'),(2,'Ready Soon','Minor dev','3-6mo'),(3,'Future Ready','Major dev','6-12mo') ON CONFLICT DO NOTHING;

-- hr_penalty_matrix
INSERT INTO hr_penalty_matrix (id,severity,description,penalty_points) VALUES (1,'LOW','Minor warning',1),(2,'MEDIUM','Written warning',3),(3,'HIGH','Final warning',5) ON CONFLICT DO NOTHING;

-- hr_shift_master
INSERT INTO hr_shift_master (shift_code,shift_name,start_time,end_time,grace_minutes) VALUES ('S1','Pagi','07:00','15:00',10),('S2','Siang','15:00','23:00',10),('S3','Malam','23:00','07:00',10) ON CONFLICT DO NOTHING;

-- hr_calendar
INSERT INTO hr_calendar (date,is_holiday,description) VALUES ('2026-01-01',true,'Tahun Baru'),('2026-08-17',true,'HUT RI'),('2026-12-25',true,'Natal') ON CONFLICT DO NOTHING;

-- hr_work_schedule
INSERT INTO hr_work_schedule (divisi_code,work_days_per_week,roster_pattern) VALUES ('HRD',5,'-'),('FINANCE',5,'-'),('OPERATIONAL',7,'20/10'),('IT',5,'-') ON CONFLICT DO NOTHING;

-- hr_kpi_config
INSERT INTO hr_kpi_config (position_code,indicator,target_value,uom,weight,formula_type) VALUES
('POS-OPR','PRODUKSI',5000,'Ton',40,'HIGHER'),('POS-OPR','DISIPLIN',10,'Menit',20,'LOWER'),
('POS-OPR','K3',0,'Insiden',30,'LOWER'),('POS-OPR','KEHADIRAN',95,'%',10,'HIGHER') ON CONFLICT DO NOTHING;

-- hr_preview_data
INSERT INTO hr_preview_data (section,key,value) VALUES
('KPI','avg_3_periode','{"P1":85,"P2":82,"P3":80}'),('FINANCE','total_ytd','{"Y":500000000}'),
('ATTENDANCE','rata_rata_hadir','92'),('SAFETY','incident_count','3') ON CONFLICT DO NOTHING;

-- announcements
INSERT INTO announcements (id,title,message,priority,target_audience) VALUES
('ANN001','Selamat Datang','Platform insightWOS v1.0','HIGH','ALL'),
('ANN002','Evaluasi KPI Q3','Evaluasi dimulai 1 Oktober','NORMAL','ALL'),
('ANN003','Training K3','Wajib bagi semua pekerja','HIGH','ALL') ON CONFLICT DO NOTHING;

-- settings
INSERT INTO settings (key,value) VALUES ('PLAN_LEVEL','FREE'),('LICENSE_KEY',''),('ENV','PRODUCTION'),('APP_VERSION','1.0.0'),('COMPANY_NAME','PT. AMM'),('admin_password','Admin123') ON CONFLICT (key) DO UPDATE SET value=EXCLUDED.value;
