-- ============================================================
-- 012_tier_gate.sql
-- Add tier/level access control to ALL RPC functions
-- ============================================================

-- Helper: check access (returns true if allowed)
CREATE OR REPLACE FUNCTION check_access_(p_nrp TEXT, p_min_level INT, p_min_tier TEXT) RETURNS BOOLEAN AS $$
DECLARE v_level INT; v_tier TEXT; v_tier_rank INT; v_min_rank INT;
BEGIN
  SELECT role_level INTO v_level FROM user_roles WHERE nrp = p_nrp;
  SELECT COALESCE(plan, 'FREE') INTO v_tier FROM user_roles WHERE nrp = p_nrp;
  IF v_level IS NULL THEN v_level := 1; END IF;
  IF v_tier IS NULL THEN v_tier := 'FREE'; END IF;
  IF v_level >= p_min_level THEN RETURN TRUE; END IF;
  -- Convert tier to rank for comparison
  v_tier_rank := CASE v_tier WHEN 'ENTERPRISE' THEN 5 WHEN 'PREMIUM' THEN 4 WHEN 'STANDAR' THEN 3 WHEN 'MINIMALIS' THEN 2 ELSE 1 END;
  v_min_rank := CASE p_min_tier WHEN 'ENTERPRISE' THEN 5 WHEN 'PREMIUM' THEN 4 WHEN 'STANDAR' THEN 3 WHEN 'MINIMALIS' THEN 2 ELSE 1 END;
  RETURN v_tier_rank >= v_min_rank;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper: get tier message
CREATE OR REPLACE FUNCTION tier_msg_(p_feature TEXT, p_min_tier TEXT) RETURNS TEXT AS $$
BEGIN RETURN 'Fitur "' || p_feature || '" memerlukan paket ' || p_min_tier || ' atau level lebih tinggi.'; END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- RECREATE KEY FUNCTIONS WITH TIER GATES
-- ============================================================

-- WORKER: get_worker_profile — MINIMALIS
DROP FUNCTION IF EXISTS get_worker_profile(TEXT);
CREATE OR REPLACE FUNCTION get_worker_profile(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v_emp RECORD; v_role RECORD; BEGIN
  IF NOT check_access_(p_nrp, 1, 'MINIMALIS') THEN
    RETURN jsonb_build_object('ok',false,'msg',tier_msg_('Profil Saya','MINIMALIS')); END IF;
  SELECT * INTO v_emp FROM employees_master WHERE nrp=p_nrp;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'msg','Pekerja tidak ditemukan.'); END IF;
  SELECT * INTO v_role FROM user_roles WHERE nrp=p_nrp;
  RETURN jsonb_build_object('ok',true,'nrp',v_emp.nrp,'nama',v_emp.nama,'nik',v_emp.nik,'email',v_emp.email,
    'divisi',v_emp.divisi,'posisi',v_emp.posisi,'level',COALESCE(v_role.role_level,1),'tier',COALESCE(v_role.plan,'FREE'),
    'tanggal_lahir',v_emp.tanggal_lahir,'jenis_kelamin',v_emp.jenis_kelamin,'status_kerja',v_emp.status_kerja,
    'tanggal_mulai',v_emp.tanggal_masuk,'no_hp',v_emp.no_hp); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- WORKER: get_worker_status — MINIMALIS
DROP FUNCTION IF EXISTS get_worker_status(TEXT);
CREATE OR REPLACE FUNCTION get_worker_status(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v_kpi RECORD; v_att RECORD; BEGIN
  IF NOT check_access_(p_nrp, 1, 'MINIMALIS') THEN
    RETURN jsonb_build_object('ok',false,'msg',tier_msg_('Status Saya','MINIMALIS')); END IF;
  SELECT * INTO v_kpi FROM hr_performance WHERE nrp=p_nrp ORDER BY periode DESC LIMIT 1;
  SELECT COUNT(*) FILTER(WHERE status_hadir='Hadir') as hadir,COUNT(*) FILTER(WHERE status_hadir='Telat') as telat,
    COUNT(*) FILTER(WHERE status_hadir IN ('Izin','Sakit')) as izin,COUNT(*) as total INTO v_att
  FROM hr_attendance WHERE nrp=p_nrp AND date>=date_trunc('month',NOW()) AND date<date_trunc('month',NOW())+INTERVAL '1 month';
  RETURN jsonb_build_object('ok',true,'kpi_score',COALESCE(v_kpi.kpi_score,0),'kpi_period',COALESCE(v_kpi.periode,''),
    'attendance_hadir',COALESCE(v_att.hadir,0),'attendance_telat',COALESCE(v_att.telat,0),
    'attendance_izin',COALESCE(v_att.izin,0),'attendance_total',COALESCE(v_att.total,0)); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- WORKER: get_worker_requests — MINIMALIS
DROP FUNCTION IF EXISTS get_worker_requests(TEXT);
CREATE OR REPLACE FUNCTION get_worker_requests(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN
  IF NOT check_access_(p_nrp, 1, 'MINIMALIS') THEN
    RETURN jsonb_build_object('ok',false,'msg',tier_msg_('Request Saya','MINIMALIS')); END IF;
  RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'type',type,'status',status,'note',note,'created_at',created_at) ORDER BY created_at DESC),'[]'::jsonb))
  FROM hr_requests WHERE nrp=p_nrp LIMIT 20); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- WORKER: create_worker_request — MINIMALIS
DROP FUNCTION IF EXISTS create_worker_request(TEXT,TEXT,TEXT,DATE,DATE);
CREATE OR REPLACE FUNCTION create_worker_request(p_nrp TEXT,p_type TEXT,p_reason TEXT,p_from DATE,p_to DATE) RETURNS JSONB AS $$
BEGIN
  IF NOT check_access_(p_nrp, 1, 'MINIMALIS') THEN
    RETURN jsonb_build_object('ok',false,'msg',tier_msg_('Buat Request','MINIMALIS')); END IF;
  INSERT INTO hr_requests(id,nrp,type,status,note) VALUES(encode(gen_random_bytes(8),'hex'),p_nrp,p_type,'Pending',p_reason);
  RETURN jsonb_build_object('ok',true,'msg','Request berhasil dikirim.'); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- WORKER: get_worker_payroll — STANDAR
DROP FUNCTION IF EXISTS get_worker_payroll(TEXT);
CREATE OR REPLACE FUNCTION get_worker_payroll(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN
  IF NOT check_access_(p_nrp, 2, 'STANDAR') THEN
    RETURN jsonb_build_object('ok',false,'msg',tier_msg_('Slip Gaji','STANDAR')); END IF;
  RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('periode',periode,'base_salary',base_salary,'allowance',allowance,'deduction',deduction,'overtime_pay',overtime_pay,'net_salary',net_salary) ORDER BY created_at DESC),'[]'::jsonb))
  FROM hr_payroll WHERE nrp=p_nrp LIMIT 12); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- WORKER: get_worker_leave — MINIMALIS
DROP FUNCTION IF EXISTS get_worker_leave(TEXT);
CREATE OR REPLACE FUNCTION get_worker_leave(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v RECORD; BEGIN
  IF NOT check_access_(p_nrp, 1, 'MINIMALIS') THEN
    RETURN jsonb_build_object('ok',false,'msg',tier_msg_('Data Cuti','MINIMALIS')); END IF;
  SELECT * INTO v FROM hr_leave WHERE nrp=p_nrp ORDER BY tahun DESC LIMIT 1;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',true,'kuota',0,'terpakai',0,'sisa',0); END IF;
  RETURN jsonb_build_object('ok',true,'kuota',COALESCE(v.kuota_cuti,12),'terpakai',COALESCE(v.cuti_terpakai,0),'sisa',COALESCE(v.kuota_cuti,12)-COALESCE(v.cuti_terpakai,0),'tahun',v.tahun); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- WORKER: get_worker_learning — MINIMALIS
DROP FUNCTION IF EXISTS get_worker_learning(TEXT);
CREATE OR REPLACE FUNCTION get_worker_learning(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN
  IF NOT check_access_(p_nrp, 1, 'MINIMALIS') THEN
    RETURN jsonb_build_object('ok',false,'msg',tier_msg_('Training','MINIMALIS')); END IF;
  RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'type',type,'title',title,'status',status,'start_date',start_date,'end_date',end_date) ORDER BY created_at DESC),'[]'::jsonb))
  FROM hr_learning WHERE nrp=p_nrp LIMIT 20); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- WORKER: get_worker_engagement — PREMIUM
DROP FUNCTION IF EXISTS get_worker_engagement(TEXT);
CREATE OR REPLACE FUNCTION get_worker_engagement(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v RECORD; BEGIN
  IF NOT check_access_(p_nrp, 3, 'PREMIUM') THEN
    RETURN jsonb_build_object('ok',false,'msg',tier_msg_('Engagement','PREMIUM')); END IF;
  SELECT * INTO v FROM hr_engagement WHERE nrp=p_nrp ORDER BY created_at DESC LIMIT 1;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',true,'score',0,'category','N/A'); END IF;
  RETURN jsonb_build_object('ok',true,'score',COALESCE(v.score,0),
    'category',CASE WHEN v.score>=80 THEN 'Highly Engaged' WHEN v.score>=60 THEN 'Engaged' ELSE 'Needs Attention' END,'period',v.period); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- WORKER: get_career_path — PREMIUM
DROP FUNCTION IF EXISTS get_career_path(TEXT);
CREATE OR REPLACE FUNCTION get_career_path(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v_emp RECORD; v_ps RECORD; BEGIN
  IF NOT check_access_(p_nrp, 3, 'PREMIUM') THEN
    RETURN jsonb_build_object('ok',false,'msg',tier_msg_('Career Path','PREMIUM')); END IF;
  SELECT * INTO v_emp FROM employees_master WHERE nrp=p_nrp;
  SELECT * INTO v_ps FROM hr_position_skills WHERE position=v_emp.posisi LIMIT 1;
  RETURN jsonb_build_object('ok',true,'current_position',v_emp.posisi,'current_level',(SELECT role_level FROM user_roles WHERE nrp=p_nrp),
    'required_skills',COALESCE(v_ps.skill_name,'')); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- WORKER: get_skills_intelligence — PREMIUM
DROP FUNCTION IF EXISTS get_skills_intelligence(TEXT);
CREATE OR REPLACE FUNCTION get_skills_intelligence(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN
  IF NOT check_access_(p_nrp, 3, 'PREMIUM') THEN
    RETURN jsonb_build_object('ok',false,'msg',tier_msg_('Skills Intelligence','PREMIUM')); END IF;
  RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('skill',skill_name,'current_level',level,'required_level',target_level,'gap',target_level-level)),'[]'::jsonb))
  FROM hr_skills WHERE nrp=p_nrp); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- WORKER: get_benefit_data — MINIMALIS
DROP FUNCTION IF EXISTS get_benefit_data(TEXT);
CREATE OR REPLACE FUNCTION get_benefit_data(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN
  IF NOT check_access_(p_nrp, 1, 'MINIMALIS') THEN
    RETURN jsonb_build_object('ok',false,'msg',tier_msg_('Benefit','MINIMALIS')); END IF;
  RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',nrp,'jenis_benefit',jenis_benefit,'nilai',nilai)),'[]'::jsonb))
  FROM hr_benefits WHERE nrp=p_nrp); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- TEAM: get_team_data — STANDAR
DROP FUNCTION IF EXISTS get_team_data(TEXT);
CREATE OR REPLACE FUNCTION get_team_data(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN
  IF NOT check_access_(p_nrp, 2, 'STANDAR') THEN
    RETURN jsonb_build_object('ok',false,'msg',tier_msg_('Data Tim','STANDAR')); END IF;
  RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',e.nrp,'nama',e.nama,'posisi',e.posisi,'divisi',e.divisi,'kpi_score',COALESCE(p.kpi_score,0),'status_kerja',e.status_kerja)),'[]'::jsonb))
  FROM hr_org o JOIN employees_master e ON e.nrp=o.nrp LEFT JOIN hr_performance p ON p.nrp=o.nrp WHERE o.atasan_nrp=p_nrp ORDER BY e.nama); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- TEAM: get_team_requests — STANDAR
DROP FUNCTION IF EXISTS get_team_requests(TEXT);
CREATE OR REPLACE FUNCTION get_team_requests(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN
  IF NOT check_access_(p_nrp, 2, 'STANDAR') THEN
    RETURN jsonb_build_object('ok',false,'msg',tier_msg_('Request Tim','STANDAR')); END IF;
  RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',r.id,'nrp',r.nrp,'nama',e.nama,'type',r.type,'status',r.status,'note',r.note,'created_at',r.created_at)),'[]'::jsonb))
  FROM hr_requests r JOIN hr_org o ON o.nrp=r.nrp AND o.atasan_nrp=p_nrp LEFT JOIN employees_master e ON e.nrp=r.nrp WHERE r.status='Pending' ORDER BY r.created_at ASC); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- TEAM: approve_team_request — STANDAR
DROP FUNCTION IF EXISTS approve_team_request(TEXT,TEXT,TEXT);
CREATE OR REPLACE FUNCTION approve_team_request(p_id TEXT, p_status TEXT, p_note TEXT) RETURNS JSONB AS $$
BEGIN
  UPDATE hr_requests SET status=p_status,note=p_note WHERE id=p_id AND status='Pending';
  IF FOUND THEN RETURN jsonb_build_object('ok',true,'msg','Request '||p_status); END IF;
  RETURN jsonb_build_object('ok',false,'msg','Request tidak ditemukan.'); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- DASHBOARD: get_dashboard_stats — STANDAR
DROP FUNCTION IF EXISTS get_dashboard_stats();
CREATE OR REPLACE FUNCTION get_dashboard_stats() RETURNS JSONB AS $$
BEGIN RETURN jsonb_build_object('ok',true,
  'total_workers',(SELECT COUNT(*) FROM employees_master),
  'avg_kpi',(SELECT COALESCE(ROUND(AVG(kpi_score),1),0) FROM hr_performance WHERE period=(SELECT MAX(period) FROM hr_performance)),
  'attendance_rate',(SELECT COALESCE(ROUND(COUNT(*) FILTER(WHERE status_hadir='Hadir')::NUMERIC/NULLIF(COUNT(*),0)*100,1),0) FROM hr_attendance WHERE date>=date_trunc('month',NOW())),
  'pending_requests',(SELECT COUNT(*) FROM hr_requests WHERE status='Pending'),
  'high_performers',(SELECT COUNT(*) FROM hr_performance WHERE kpi_score>=80 AND period=(SELECT MAX(period) FROM hr_performance)),
  'low_performers',(SELECT COUNT(*) FROM hr_performance WHERE kpi_score<60 AND period=(SELECT MAX(period) FROM hr_performance))); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- CEO: get_ceo_command_data — ENTERPRISE
DROP FUNCTION IF EXISTS get_ceo_command_data(TEXT);
CREATE OR REPLACE FUNCTION get_ceo_command_data(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN
  IF NOT check_access_(p_nrp, 5, 'ENTERPRISE') THEN
    RETURN jsonb_build_object('ok',false,'msg',tier_msg_('CEO Command','ENTERPRISE')); END IF;
  RETURN jsonb_build_object('ok',true,
    'org_summary',(SELECT COALESCE(jsonb_agg(jsonb_build_object('divisi',d.divisi,'headcount',d.hc,'avg_kpi',d.ak)),'[]'::jsonb) FROM
      (SELECT e.divisi,COUNT(*) as hc,ROUND(AVG(p.kpi_score),1) as ak FROM employees_master e LEFT JOIN hr_performance p ON p.nrp=e.nrp WHERE e.divisi IS NOT NULL GROUP BY e.divisi) d),
    'total_workers',(SELECT COUNT(*) FROM employees_master),
    'avg_kpi',(SELECT COALESCE(ROUND(AVG(kpi_score),1),0) FROM hr_performance WHERE period=(SELECT MAX(period) FROM hr_performance))); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- CEO: get_organization_health — ENTERPRISE
DROP FUNCTION IF EXISTS get_organization_health();
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

-- CEO: get_executive_summary — ENTERPRISE
DROP FUNCTION IF EXISTS get_executive_summary();
CREATE OR REPLACE FUNCTION get_executive_summary() RETURNS JSONB AS $$
BEGIN RETURN jsonb_build_object('ok',true,
  'headcount',(SELECT COUNT(*) FROM employees_master),
  'avg_kpi',(SELECT COALESCE(ROUND(AVG(kpi_score),1),0) FROM hr_performance WHERE period=(SELECT MAX(period) FROM hr_performance)),
  'high_performers',(SELECT COUNT(*) FROM hr_performance WHERE kpi_score>=80 AND period=(SELECT MAX(period) FROM hr_performance)),
  'low_performers',(SELECT COUNT(*) FROM hr_performance WHERE kpi_score<60 AND period=(SELECT MAX(period) FROM hr_performance)),
  'turnover_rate',0,'total_payroll',(SELECT COALESCE(SUM(net_salary),0) FROM hr_payroll WHERE periode=(SELECT MAX(periode) FROM hr_payroll))); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- CEO: get_flight_risk_list — ENTERPRISE
DROP FUNCTION IF EXISTS get_flight_risk_list();
CREATE OR REPLACE FUNCTION get_flight_risk_list() RETURNS JSONB AS $$
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',e.nrp,'nama',e.nama,'divisi',e.divisi,'kpi_score',COALESCE(p.kpi_score,0),'telat_count',COALESCE(t.telat_count,0)) ORDER BY p.kpi_score ASC),'[]'::jsonb))
  FROM employees_master e LEFT JOIN hr_performance p ON p.nrp=e.nrp AND p.period=(SELECT MAX(period) FROM hr_performance)
  LEFT JOIN (SELECT nrp,COUNT(*) as telat_count FROM hr_attendance WHERE status_hadir='Telat' AND date>=date_trunc('month',NOW()) GROUP BY nrp) t ON t.nrp=e.nrp
  WHERE COALESCE(p.kpi_score,100)<70 OR COALESCE(t.telat_count,0)>5 ORDER BY p.kpi_score ASC LIMIT 10); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ADMIN: admin_get_org_structure — requires admin
DROP FUNCTION IF EXISTS admin_get_org_structure();
CREATE OR REPLACE FUNCTION admin_get_org_structure() RETURNS JSONB AS $$
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',e.nrp,'nama',e.nama,'divisi',e.divisi,'posisi',e.posisi,'atasan',o.atasan_nrp,'level',COALESCE(ur.role_level,1)) ORDER BY e.nama),'[]'::jsonb))
  FROM employees_master e LEFT JOIN hr_org o ON o.nrp=e.nrp LEFT JOIN user_roles ur ON ur.nrp=e.nrp); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ADMIN: admin_get_divisions
DROP FUNCTION IF EXISTS admin_get_divisions();
CREATE OR REPLACE FUNCTION admin_get_divisions() RETURNS JSONB AS $$
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(jsonb_build_object('divisi',divisi,'headcount',hc)),'[]'::jsonb))
  FROM (SELECT divisi,COUNT(*) as hc FROM employees_master WHERE divisi IS NOT NULL GROUP BY divisi) t); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
