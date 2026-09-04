-- Migration 131: Fix IDOR vulnerabilities in Worker RPCs
-- Validate p_nrp matches callers own NRP (or admin/owner bypass)

CREATE OR REPLACE FUNCTION _get_caller_nrp()
RETURNS TEXT AS $$
  SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION _is_admin_or_owner_caller()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_roles WHERE nrp = _get_caller_nrp()
    AND role IN ('owner','admin_pusat','admin_hrd','admin_finance','admin_produksi','admin_mining','admin_mill','admin_estate')
  ) OR EXISTS (
    SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = TRUE
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

DROP FUNCTION IF EXISTS get_worker_profile(TEXT);
CREATE OR REPLACE FUNCTION get_worker_profile(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v_caller TEXT := _get_caller_nrp(); v_is_admin BOOLEAN := _is_admin_or_owner_caller(); v_emp RECORD; v_role RECORD;
BEGIN
  IF NOT v_is_admin AND p_nrp != v_caller THEN RETURN jsonb_build_object('ok',false,'msg','Akses ditolak.'); END IF;
  SELECT * INTO v_emp FROM employees_master WHERE nrp = p_nrp;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'msg','Pekerja tidak ditemukan.'); END IF;
  SELECT * INTO v_role FROM user_roles WHERE nrp = p_nrp;
  RETURN jsonb_build_object('ok',true,'nrp',v_emp.nrp,'nama',v_emp.nama,'nik',v_emp.nik,'email',v_emp.email,'divisi',v_emp.divisi,'posisi',v_emp.posisi,'level',COALESCE(v_role.role_level,1),'tier',COALESCE(v_role.plan,'FREE'),'tanggal_lahir',v_emp.tanggal_lahir,'jenis_kelamin',v_emp.jenis_kelamin,'status_kerja',v_emp.status_kerja,'tanggal_mulai',v_emp.tanggal_masuk,'no_hp',v_emp.no_hp);
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS get_worker_status(TEXT);
CREATE OR REPLACE FUNCTION get_worker_status(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v_caller TEXT := _get_caller_nrp(); v_is_admin BOOLEAN := _is_admin_or_owner_caller(); v_kpi RECORD; v_att RECORD;
BEGIN
  IF NOT v_is_admin AND p_nrp != v_caller THEN RETURN jsonb_build_object('ok',false,'msg','Akses ditolak.'); END IF;
  SELECT * INTO v_kpi FROM hr_performance WHERE nrp = p_nrp ORDER BY periode DESC LIMIT 1;
  SELECT COUNT(*) FILTER(WHERE status_hadir='Hadir') as hadir, COUNT(*) FILTER(WHERE status_hadir='Telat') as telat, COUNT(*) FILTER(WHERE status_hadir IN ('Izin','Sakit')) as izin, COUNT(*) as total INTO v_att FROM hr_attendance WHERE nrp = p_nrp AND date >= date_trunc('month',NOW()) AND date < date_trunc('month',NOW())+INTERVAL '1 month';
  RETURN jsonb_build_object('ok',true,'kpi_score',COALESCE(v_kpi.kpi_score,0),'kpi_period',COALESCE(v_kpi.periode,''),'attendance_hadir',COALESCE(v_att.hadir,0),'attendance_telat',COALESCE(v_att.telat,0),'attendance_izin',COALESCE(v_att.izin,0),'attendance_total',COALESCE(v_att.total,0));
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS get_worker_payroll(TEXT);
CREATE OR REPLACE FUNCTION get_worker_payroll(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v_caller TEXT := _get_caller_nrp(); v_is_admin BOOLEAN := _is_admin_or_owner_caller(); 
BEGIN
  IF NOT v_is_admin AND p_nrp != v_caller THEN RETURN jsonb_build_object('ok',false,'msg','Akses ditolak.'); END IF;
  RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(jsonb_build_object('periode',periode,'base_salary',base_salary,'allowance',allowance,'deduction',deduction,'overtime_pay',overtime_pay,'net_salary',net_salary,'created_at',created_at) ORDER BY created_at DESC),'[]'::jsonb)) FROM hr_payroll WHERE nrp = p_nrp LIMIT 12);
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS get_worker_leave(TEXT);
CREATE OR REPLACE FUNCTION get_worker_leave(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v_caller TEXT := _get_caller_nrp(); v_is_admin BOOLEAN := _is_admin_or_owner_caller(); 
BEGIN
  IF NOT v_is_admin AND p_nrp != v_caller THEN RETURN jsonb_build_object('ok',false,'msg','Akses ditolak.'); END IF;
  RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(row_to_json(t)),'[]'::jsonb)) FROM (SELECT * FROM hr_leave WHERE nrp = p_nrp ORDER BY tahun DESC LIMIT 5) t);
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS get_worker_engagement(TEXT);
CREATE OR REPLACE FUNCTION get_worker_engagement(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v_caller TEXT := _get_caller_nrp(); v_is_admin BOOLEAN := _is_admin_or_owner_caller(); v RECORD;
BEGIN
  IF NOT v_is_admin AND p_nrp != v_caller THEN RETURN jsonb_build_object('ok',false,'msg','Akses ditolak.'); END IF;
  SELECT * INTO v FROM hr_engagement WHERE nrp = p_nrp ORDER BY created_at DESC LIMIT 1;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',true,'score',0,'category','N/A'); END IF;
  RETURN jsonb_build_object('ok',true,'score',COALESCE(v.score,0),'category',CASE WHEN v.score>=80 THEN 'Highly Engaged' WHEN v.score>=60 THEN 'Engaged' ELSE 'Needs Attention' END,'period',v.period);
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS get_worker_learning(TEXT);
CREATE OR REPLACE FUNCTION get_worker_learning(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v_caller TEXT := _get_caller_nrp(); v_is_admin BOOLEAN := _is_admin_or_owner_caller(); 
BEGIN
  IF NOT v_is_admin AND p_nrp != v_caller THEN RETURN jsonb_build_object('ok',false,'msg','Akses ditolak.'); END IF;
  RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(row_to_json(t)),'[]'::jsonb)) FROM (SELECT * FROM hr_learning WHERE nrp = p_nrp ORDER BY created_at DESC LIMIT 20) t);
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS get_worker_notifications(TEXT);
CREATE OR REPLACE FUNCTION get_worker_notifications(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v_caller TEXT := _get_caller_nrp(); v_is_admin BOOLEAN := _is_admin_or_owner_caller(); 
BEGIN
  IF NOT v_is_admin AND p_nrp != v_caller THEN RETURN jsonb_build_object('ok',false,'msg','Akses ditolak.'); END IF;
  RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(row_to_json(t)),'[]'::jsonb)) FROM (SELECT * FROM hr_notifications WHERE nrp = p_nrp ORDER BY created_at DESC LIMIT 20) t);
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS get_worker_benefits(TEXT);
CREATE OR REPLACE FUNCTION get_worker_benefits(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v_caller TEXT := _get_caller_nrp(); v_is_admin BOOLEAN := _is_admin_or_owner_caller(); 
BEGIN
  IF NOT v_is_admin AND p_nrp != v_caller THEN RETURN jsonb_build_object('ok',false,'msg','Akses ditolak.'); END IF;
  RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(row_to_json(t)),'[]'::jsonb)) FROM (SELECT * FROM hr_benefits WHERE nrp = p_nrp) t);
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS get_worker_skills(TEXT);
CREATE OR REPLACE FUNCTION get_worker_skills(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v_caller TEXT := _get_caller_nrp(); v_is_admin BOOLEAN := _is_admin_or_owner_caller(); 
BEGIN
  IF NOT v_is_admin AND p_nrp != v_caller THEN RETURN jsonb_build_object('ok',false,'msg','Akses ditolak.'); END IF;
  RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(row_to_json(t)),'[]'::jsonb)) FROM (SELECT * FROM hr_skills WHERE nrp = p_nrp) t);
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS get_worker_overtime(TEXT);
CREATE OR REPLACE FUNCTION get_worker_overtime(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v_caller TEXT := _get_caller_nrp(); v_is_admin BOOLEAN := _is_admin_or_owner_caller(); 
BEGIN
  IF NOT v_is_admin AND p_nrp != v_caller THEN RETURN jsonb_build_object('ok',false,'msg','Akses ditolak.'); END IF;
  RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(row_to_json(t)),'[]'::jsonb)) FROM (SELECT * FROM hr_overtime WHERE nrp = p_nrp ORDER BY created_at DESC LIMIT 20) t);
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS get_worker_medical(TEXT);
CREATE OR REPLACE FUNCTION get_worker_medical(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v_caller TEXT := _get_caller_nrp(); v_is_admin BOOLEAN := _is_admin_or_owner_caller(); 
BEGIN
  IF NOT v_is_admin AND p_nrp != v_caller THEN RETURN jsonb_build_object('ok',false,'msg','Akses ditolak.'); END IF;
  RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(row_to_json(t)),'[]'::jsonb)) FROM (SELECT * FROM hr_medical_checkup WHERE nrp = p_nrp) t);
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS submit_voice(TEXT,TEXT,TEXT,TEXT,BOOLEAN);
CREATE OR REPLACE FUNCTION submit_voice(p_type TEXT, p_nrp TEXT, p_title TEXT, p_details TEXT, p_anonymous BOOLEAN DEFAULT TRUE) RETURNS JSONB AS $$
DECLARE v_caller TEXT := _get_caller_nrp(); v_is_admin BOOLEAN := _is_admin_or_owner_caller();
BEGIN
  IF NOT v_is_admin AND p_nrp != v_caller THEN RETURN jsonb_build_object('ok',false,'msg','Akses ditolak.'); END IF;
  INSERT INTO hr_voice (id,type,nrp,title,description,status) VALUES ('V'||encode(gen_random_bytes(4),'hex'),p_type,p_nrp,p_title,p_details,'SUBMITTED');
  RETURN jsonb_build_object('ok',true,'msg','Ide berhasil dikirim.');
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_worker_profile(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_worker_status(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_worker_payroll(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_worker_leave(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_worker_engagement(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_worker_learning(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_worker_notifications(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_worker_benefits(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_worker_skills(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_worker_overtime(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_worker_medical(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION submit_voice(TEXT,TEXT,TEXT,TEXT,BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION _get_caller_nrp() TO authenticated;
GRANT EXECUTE ON FUNCTION _is_admin_or_owner_caller() TO authenticated;
