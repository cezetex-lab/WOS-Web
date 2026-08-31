-- ============================================================
-- 019_missing_rpc.sql — Missing RPC Functions for 141 Features
-- Run AFTER CLEAN.sql + 018_new_25_tables.sql
-- ============================================================

-- ============================================================
-- A. REKRUTMEN & ONBOARDING (#3-#9)
-- ============================================================

CREATE OR REPLACE FUNCTION admin_bulk_approve(p_ids INT[]) RETURNS JSONB AS $$
DECLARE v_ok INT := 0; v_fail INT := 0; v_id INT;
BEGIN
  FOREACH v_id IN ARRAY p_ids LOOP
    BEGIN
      PERFORM admin_approve_pending(v_id);
      v_ok := v_ok + 1;
    EXCEPTION WHEN OTHERS THEN v_fail := v_fail + 1;
    END;
  END LOOP;
  RETURN jsonb_build_object('ok',true,'approved',v_ok,'failed',v_fail);
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION admin_manage_vacancies(p_action TEXT, p_id TEXT, p_pos TEXT, p_dept TEXT, p_quota INT, p_qual TEXT) RETURNS JSONB AS $$
BEGIN
  IF p_action = 'CREATE' THEN
    INSERT INTO vacancies(id,position,department,quota,qualifications) VALUES(p_id,p_pos,p_dept,p_quota,p_qual);
    RETURN jsonb_build_object('ok',true,'msg','Lowongan dibuat.');
  ELSIF p_action = 'CLOSE' THEN
    UPDATE vacancies SET status='CLOSED' WHERE id=p_id;
    RETURN jsonb_build_object('ok',true,'msg','Lowongan ditutup.');
  ELSIF p_action = 'DELETE' THEN
    DELETE FROM vacancies WHERE id=p_id;
    RETURN jsonb_build_object('ok',true,'msg','Lowongan dihapus.');
  END IF;
  RETURN jsonb_build_object('ok',false,'msg','Aksi tidak dikenal.');
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION admin_get_vacancies() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'position',position,'department',department,'quota',quota,'qualifications',qualifications,'status',status)),'[]'::jsonb))
FROM vacancies ORDER BY created_at DESC); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION admin_candidate_pipeline(p_vacancy_id TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'nama',nama,'email',email,'stage',stage,'notes',notes,'created_at',created_at) ORDER BY created_at DESC),'[]'::jsonb))
FROM candidate_pipeline WHERE vacancy_id=p_vacancy_id); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_onboarding_tasks(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'task_name',task_name,'assigned_to',assigned_to,'status',status,'due_date',due_date)),'[]'::jsonb))
FROM onboarding_tasks WHERE nrp=p_nrp); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_employee_documents(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('type',type,'sub_type',sub_type)),'[]'::jsonb))
FROM hr_document_types LIMIT 20); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- B. DATA KARYAWAN (#11, #14, #17)
-- ============================================================

CREATE OR REPLACE FUNCTION worker_update_profile(p_nrp TEXT, p_email TEXT, p_no_hp TEXT, p_alamat TEXT) RETURNS JSONB AS $$
BEGIN
  UPDATE employees_master SET email=COALESCE(p_email,email), no_hp=COALESCE(p_no_hp,no_hp),
    alamat=COALESCE(p_alamat,alamat), updated_at=NOW() WHERE nrp=p_nrp;
  RETURN jsonb_build_object('ok',true,'msg','Profil diperbarui.');
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION admin_get_role_matrix() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',ur.nrp,'nama',e.nama,'level',ur.role_level,'scope',ur.scope_divisi,'plan',COALESCE(ur.plan,'FREE')) ORDER BY ur.role_level DESC),'[]'::jsonb))
FROM user_roles ur LEFT JOIN employees_master e ON e.nrp=ur.nrp); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION admin_set_role(p_nrp TEXT, p_level INT, p_scope TEXT, p_plan TEXT) RETURNS JSONB AS $$
BEGIN
  UPDATE user_roles SET role_level=p_level, scope_divisi=COALESCE(p_scope,scope_divisi), plan=COALESCE(p_plan,plan) WHERE nrp=p_nrp;
  IF FOUND THEN RETURN jsonb_build_object('ok',true,'msg','Role diperbarui.'); END IF;
  INSERT INTO user_roles(nrp,role_level,scope_divisi,plan) VALUES(p_nrp,p_level,p_scope,p_plan);
  RETURN jsonb_build_object('ok',true,'msg','Role ditambahkan.');
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_employee_mutations(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('from_position',from_position,'to_position',to_position,'effective_date',effective_date,'reason',reason) ORDER BY effective_date DESC),'[]'::jsonb))
FROM employee_mutations WHERE nrp=p_nrp); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- C. SELF-SERVICE (#21, #27, #30, #32)
-- ============================================================

CREATE OR REPLACE FUNCTION create_overtime_request(p_nrp TEXT, p_date DATE, p_hours NUMERIC, p_reason TEXT) RETURNS JSONB AS $$
BEGIN
  INSERT INTO hr_overtime(id,nrp,date,hours,reason,status) VALUES(encode(gen_random_bytes(8),'hex'),p_nrp,p_date,p_hours,p_reason,'PENDING');
  RETURN jsonb_build_object('ok',true,'msg','Lembur diajukan.');
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION worker_change_password(p_nrp TEXT, p_old TEXT, p_new TEXT) RETURNS JSONB AS $$
DECLARE v_w RECORD; v_new_salt TEXT; v_new_hash TEXT; v_old_hash TEXT;
BEGIN
  SELECT * INTO v_w FROM worker_passwords WHERE nrp=p_nrp AND is_active=true;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'msg','Akun tidak ditemukan.'); END IF;
  IF v_w.salt IS NULL OR v_w.salt='' THEN
    v_old_hash := p_old;
  ELSE
    v_old_hash := encode(digest(p_old||v_w.salt,'sha256'),'hex');
  END IF;
  IF v_old_hash != v_w.password_hash THEN
    RETURN jsonb_build_object('ok',false,'msg','Password lama salah.'); END IF;
  v_new_salt := encode(gen_random_bytes(16),'hex');
  v_new_hash := encode(digest(p_new||v_new_salt,'sha256'),'hex');
  UPDATE worker_passwords SET password_hash=v_new_hash, salt=v_new_salt, updated_at=NOW() WHERE nrp=p_nrp;
  RETURN jsonb_build_object('ok',true,'msg','Password berhasil diubah.');
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_travel_request(p_nrp TEXT, p_dest TEXT, p_purpose TEXT, p_start DATE, p_end DATE, p_cost NUMERIC) RETURNS JSONB AS $$
DECLARE v_days INT; v_perdiem NUMERIC;
BEGIN
  v_days := GREATEST(p_end - p_start + 1, 1);
  v_perdiem := v_days * 350000;
  INSERT INTO travel_requests(id,nrp,destination,purpose,start_date,end_date,estimated_cost,per_diem,status)
    VALUES(encode(gen_random_bytes(8),'hex'),p_nrp,p_dest,p_purpose,p_start,p_end,p_cost,v_perdiem,'PENDING');
  RETURN jsonb_build_object('ok',true,'msg','Perjalanan diajukan.','per_diem',v_perdiem);
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_travel_requests(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'destination',destination,'purpose',purpose,'start_date',start_date,'end_date',end_date,'status',status,'per_diem',per_diem)),'[]'::jsonb))
FROM travel_requests WHERE p_nrp IS NULL OR nrp=p_nrp ORDER BY created_at DESC LIMIT 20); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_reimbursement(p_nrp TEXT, p_travel_id TEXT, p_category TEXT, p_amount NUMERIC) RETURNS JSONB AS $$
BEGIN
  INSERT INTO reimbursements(id,nrp,travel_id,category,amount,status) VALUES(encode(gen_random_bytes(8),'hex'),p_nrp,p_travel_id,p_category,p_amount,'PENDING');
  RETURN jsonb_build_object('ok',true,'msg','Reimbursement diajukan.');
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- D. KINERJA & KOMPENSASI (#37, #38, #42-#46)
-- ============================================================

CREATE OR REPLACE FUNCTION get_my_continuous_performance(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('author',author_nrp,'type',note_type,'content',content,'created_at',created_at) ORDER BY created_at DESC),'[]'::jsonb))
FROM performance_notes WHERE nrp=p_nrp LIMIT 20); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION add_performance_note(p_nrp TEXT, p_author TEXT, p_type TEXT, p_content TEXT) RETURNS JSONB AS $$
BEGIN INSERT INTO performance_notes(nrp,author_nrp,note_type,content) VALUES(p_nrp,p_author,p_type,p_content);
RETURN jsonb_build_object('ok',true,'msg','Catatan ditambahkan.'); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_compensation_intelligence(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v RECORD; v_avg NUMERIC;
BEGIN
  SELECT net_salary INTO v FROM hr_payroll WHERE nrp=p_nrp ORDER BY created_at DESC LIMIT 1;
  SELECT AVG(net_salary) INTO v_avg FROM hr_payroll WHERE periode=(SELECT MAX(periode) FROM hr_payroll);
  RETURN jsonb_build_object('ok',true,'my_salary',COALESCE(v,0),'avg_salary',COALESCE(v_avg,0),
    'percentile',CASE WHEN v_avg>0 THEN ROUND(v/v_avg*100,1) ELSE 0 END);
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_review_360(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('reviewer',reviewer_nrp,'category',category,'score',score,'feedback',feedback)),'[]'::jsonb))
FROM review_360 WHERE reviewee_nrp=p_nrp); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_okrs(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'objective',objective,'key_result',key_result,'target',target_value,'actual',actual_value,'progress',
    CASE WHEN target_value>0 THEN ROUND(actual_value/target_value*100,1) ELSE 0 END,'status',status)),'[]'::jsonb))
FROM okrs WHERE nrp=p_nrp); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION calculate_incentive(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v_sal NUMERIC; v_kpi NUMERIC; v_final NUMERIC;
BEGIN
  SELECT net_salary INTO v_sal FROM hr_payroll WHERE nrp=p_nrp ORDER BY created_at DESC LIMIT 1;
  SELECT kpi_score INTO v_kpi FROM hr_performance WHERE nrp=p_nrp ORDER BY created_at DESC LIMIT 1;
  v_final := COALESCE(v_sal,0) * 0.10 * COALESCE(v_kpi,70) / 100;
  RETURN jsonb_build_object('ok',true,'base',COALESCE(v_sal,0),'kpi_factor',COALESCE(v_kpi,70),'incentive',v_final);
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_salary_adjustments() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',s.nrp,'nama',e.nama,'current',s.current_salary,'recommended',s.recommended_salary,'pct',s.increase_pct,'status',s.status)),'[]'::jsonb))
FROM salary_adjustments s LEFT JOIN employees_master e ON e.nrp=s.nrp); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- E. TALENT & SERTIFIKASI (#54, #55)
-- ============================================================

CREATE OR REPLACE FUNCTION get_certifications(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'cert_name',cert_name,'issuer',issuer,'issue_date',issue_date,'expiry_date',expiry_date,'status',status)),'[]'::jsonb))
FROM certifications WHERE nrp=p_nrp); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_badges(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('badge_name',badge_name,'badge_type',badge_type,'points',points,'awarded_date',awarded_date)),'[]'::jsonb))
FROM badges WHERE nrp=p_nrp); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_badges_leaderboard() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',b.nrp,'nama',e.nama,'total_points',b.total_points) ORDER BY b.total_points DESC),'[]'::jsonb))
FROM (SELECT nrp,SUM(points) as total_points FROM badges GROUP BY nrp) b LEFT JOIN employees_master e ON e.nrp=b.nrp LIMIT 20); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- F. ENGAGEMENT & SURVEI (#60, #61, #64)
-- ============================================================

CREATE OR REPLACE FUNCTION admin_update_idea_status(p_id TEXT, p_status TEXT) RETURNS JSONB AS $$
BEGIN UPDATE hr_voice SET status=p_status WHERE id=p_id;
IF FOUND THEN RETURN jsonb_build_object('ok',true,'msg','Status diperbarui.'); END IF;
RETURN jsonb_build_object('ok',false,'msg','Tidak ditemukan.'); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_surveys() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'title',title,'description',description,'type',survey_type,'status',status)),'[]'::jsonb))
FROM surveys WHERE status='ACTIVE'); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION submit_survey_response(p_survey_id TEXT, p_nrp TEXT, p_score INT, p_response TEXT) RETURNS JSONB AS $$
BEGIN INSERT INTO survey_responses(survey_id,nrp,score,response_json) VALUES(p_survey_id,p_nrp,p_score,p_response);
RETURN jsonb_build_object('ok',true,'msg','Jawaban tersimpan.'); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_enps_score() RETURNS JSONB AS $$
DECLARE v_total INT; v_promoters INT; v_detractors INT; v_score NUMERIC;
BEGIN
  SELECT COUNT(*),COUNT(*) FILTER(WHERE score>=9),COUNT(*) FILTER(WHERE score<=6) INTO v_total,v_promoters,v_detractors FROM survey_responses;
  v_score := CASE WHEN v_total>0 THEN ROUND((v_promoters::NUMERIC/v_total - v_detractors::NUMERIC/v_total)*100,1) ELSE 0 END;
  RETURN jsonb_build_object('ok',true,'total_respondents',v_total,'promoters',v_promoters,'detractors',v_detractors,'enps_score',v_score);
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION submit_whistleblower(p_category TEXT, p_desc TEXT) RETURNS JSONB AS $$
BEGIN INSERT INTO whistleblowers(id,category,description) VALUES('WB'||encode(gen_random_bytes(4),'hex'),p_category,p_desc);
RETURN jsonb_build_object('ok',true,'msg','Laporan terkirim secara anonim.'); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_whistleblowers() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'category',category,'status',status,'created_at',created_at)),'[]'::jsonb))
FROM whistleblowers ORDER BY created_at DESC); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- G. MANAJEMEN TIM (#71, #72, #74, #75)
-- ============================================================

CREATE OR REPLACE FUNCTION get_task_board(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'title',title,'status',status,'due_date',due_date)),'[]'::jsonb))
FROM hr_tasks WHERE assignee_nrp=p_nrp OR p_nrp IS NULL ORDER BY due_date ASC); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_task(p_assignee TEXT, p_title TEXT, p_due DATE) RETURNS JSONB AS $$
BEGIN INSERT INTO hr_tasks(id,assignee_nrp,title,status,due_date) VALUES(encode(gen_random_bytes(8),'hex'),p_assignee,p_title,'TODO',p_due);
RETURN jsonb_build_object('ok',true,'msg','Tugas dibuat.'); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_task_status(p_id TEXT, p_status TEXT) RETURNS JSONB AS $$
BEGIN UPDATE hr_tasks SET status=p_status WHERE id=p_id;
IF FOUND THEN RETURN jsonb_build_object('ok',true,'msg','Status diperbarui.'); END IF;
RETURN jsonb_build_object('ok',false,'msg','Tidak ditemukan.'); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_timesheets(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('work_date',work_date,'clock_in',clock_in,'clock_out',clock_out,'total_hours',total_hours)),'[]'::jsonb))
FROM timesheets WHERE nrp=p_nrp ORDER BY work_date DESC LIMIT 14); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION clock_in(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN INSERT INTO timesheets(nrp,work_date,clock_in) VALUES(p_nrp,CURRENT_DATE,CURRENT_TIME)
  ON CONFLICT (nrp,work_date) DO UPDATE SET clock_in=CURRENT_TIME;
RETURN jsonb_build_object('ok',true,'msg','Clock in tercatat.','time',CURRENT_TIME::TEXT); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION clock_out(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN UPDATE timesheets SET clock_out=CURRENT_TIME,
  total_hours=EXTRACT(EPOCH FROM (CURRENT_TIME-clock_in))/3600 WHERE nrp=p_nrp AND work_date=CURRENT_DATE;
RETURN jsonb_build_object('ok',true,'msg','Clock out tercatat.','time',CURRENT_TIME::TEXT); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_shift_swap(p_req TEXT, p_tgt TEXT, p_date DATE, p_req_shift TEXT, p_tgt_shift TEXT) RETURNS JSONB AS $$
BEGIN INSERT INTO shift_swaps(id,requester_nrp,target_nrp,swap_date,requester_shift,target_shift)
  VALUES(encode(gen_random_bytes(8),'hex'),p_req,p_tgt,p_date,p_req_shift,p_tgt_shift);
RETURN jsonb_build_object('ok',true,'msg','Swap shift diajukan.'); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- H. CEO & EXECUTIVE (#81, #82, #86-#89, #91)
-- ============================================================

CREATE OR REPLACE FUNCTION get_executive_brief() RETURNS JSONB AS $$
DECLARE v_hp INT; v_lp INT; v_fr INT; v_com INT;
BEGIN
  SELECT COUNT(*) INTO v_hp FROM hr_performance WHERE kpi_score>=80 AND period=(SELECT MAX(period) FROM hr_performance);
  SELECT COUNT(*) INTO v_lp FROM hr_performance WHERE kpi_score<60 AND period=(SELECT MAX(period) FROM hr_performance);
  SELECT COUNT(*) INTO v_fr FROM hr_performance WHERE kpi_score<70 AND period=(SELECT MAX(period) FROM hr_performance);
  SELECT COUNT(*) INTO v_com FROM hr_compliance WHERE status='OVERDUE';
  RETURN jsonb_build_object('ok',true,'critical_items',v_lp,'attention_items',v_fr,'positive_items',v_hp,'compliance_issues',v_com,
    'recommendations',jsonb_build_array('Review karyawan KPI < 60','Perpanjang sertifikasi expired','Tinjau anggaran training'));
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_ai_tasks() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'agent',agent_name,'type',task_type,'title',title,'status',status,'priority',priority)),'[]'::jsonb))
FROM hr_ai_tasks ORDER BY created_at DESC LIMIT 20); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_ai_task_status(p_id TEXT, p_status TEXT) RETURNS JSONB AS $$
BEGIN UPDATE hr_ai_tasks SET status=p_status WHERE id=p_id;
IF FOUND THEN RETURN jsonb_build_object('ok',true,'msg','Status diperbarui.'); END IF;
RETURN jsonb_build_object('ok',false,'msg','Tidak ditemukan.'); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION run_simulation(p_turnover_change NUMERIC) RETURNS JSONB AS $$
DECLARE v_hc INT; v_profit NUMERIC; v_new_hc INT; v_new_profit NUMERIC;
BEGIN
  SELECT COUNT(*) INTO v_hc FROM employees_master;
  SELECT SUM(profit) INTO v_profit FROM hr_finance_kpi WHERE periode=(SELECT MAX(periode) FROM hr_finance_kpi);
  v_new_hc := GREATEST(v_hc * (1 + p_turnover_change/100), 1);
  v_new_profit := v_profit * (1 + (-p_turnover_change * 0.3)/100);
  INSERT INTO simulations(id,scenario_name,params_json,result_json,created_by)
    VALUES('SIM'||encode(gen_random_bytes(4),'hex'),'Turnover Simulation',
      jsonb_build_object('turnover_change',p_turnover_change)::TEXT,
      jsonb_build_object('new_hc',v_new_hc,'new_profit',v_new_profit)::TEXT,'SYSTEM');
  RETURN jsonb_build_object('ok',true,'current_hc',v_hc,'projected_hc',v_new_hc,
    'current_profit',v_profit,'projected_profit',v_new_profit);
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_narrative(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v_kpi NUMERIC; v_att NUMERIC; v_nrp TEXT; v_nama TEXT; v_narasi TEXT;
BEGIN
  SELECT kpi_score INTO v_kpi FROM hr_performance WHERE nrp=p_nrp ORDER BY created_at DESC LIMIT 1;
  SELECT ROUND(COUNT(*) FILTER(WHERE status_hadir='Hadir')::NUMERIC/NULLIF(COUNT(*),0)*100,1) INTO v_att
    FROM hr_attendance WHERE nrp=p_nrp AND date>=date_trunc('month',NOW());
  SELECT nama INTO v_nama FROM employees_master WHERE nrp=p_nrp;
  v_narasi := 'Halo '||COALESCE(v_nama,'Karyawan')||'. ';
  IF COALESCE(v_kpi,0) >= 80 THEN
    v_narasi := v_narasi || 'KPI Anda Excellent ('||COALESCE(v_kpi,0)||'). Pertahankan! ';
  ELSIF COALESCE(v_kpi,0) >= 60 THEN
    v_narasi := v_narasi || 'KPI Anda cukup baik ('||COALESCE(v_kpi,0)||'). Ada ruang untuk improvement. ';
  ELSE
    v_narasi := v_narasi || 'KPI Anda perlu perhatian ('||COALESCE(v_kpi,0)||'). Rekomendasi: coaching 1:1 dengan atasan. ';
  END IF;
  IF COALESCE(v_att,100) < 90 THEN
    v_narasi := v_narasi || 'Kehadiran Anda ('||v_att||'%) perlu diperbaiki.';
  END IF;
  RETURN jsonb_build_object('ok',true,'narrative',v_narasi,'kpi',COALESCE(v_kpi,0),'attendance_pct',COALESCE(v_att,100));
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION ask_copilot(p_nrp TEXT, p_question TEXT) RETURNS JSONB AS $$
DECLARE v_answer TEXT;
BEGIN
  v_answer := 'Ini adalah jawaban demo untuk: "'||p_question||'". ';
  v_answer := v_answer || 'Untuk jawaban AI nyata, integrasikan OpenAI/Gemini API dengan RAG.';
  INSERT INTO audit_log(actor,action,detail) VALUES(p_nrp,'COPILOT_ASK',p_question);
  RETURN jsonb_build_object('ok',true,'answer',v_answer);
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_turnover_prediction() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',e.nrp,'nama',e.nama,'divisi',e.divisi,
    'risk_score',GREATEST(100-COALESCE(p.kpi_score,50)-COALESCE(t.days_present,25)*2,0),
    'factors',jsonb_build_array(CASE WHEN COALESCE(p.kpi_score,100)<70 THEN 'KPI rendah' ELSE 'OK' END,
      CASE WHEN COALESCE(t.days_present,25)<20 THEN 'Absensi rendah' ELSE 'OK' END))
  ORDER BY GREATEST(100-COALESCE(p.kpi_score,50)-COALESCE(t.days_present,25)*2,0) DESC),'[]'::jsonb))
FROM employees_master e
LEFT JOIN hr_performance p ON p.nrp=e.nrp AND p.period=(SELECT MAX(period) FROM hr_performance)
LEFT JOIN (SELECT nrp,COUNT(*) as days_present FROM hr_attendance WHERE status_hadir='Hadir' AND date>=date_trunc('month',NOW()) GROUP BY nrp) t ON t.nrp=e.nrp
WHERE e.status_kerja='PKWTT' LIMIT 10); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_realtime_alerts() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'type',task_type,'title',title,'priority',priority,'status',status,'created_at',created_at)),'[]'::jsonb))
FROM hr_ai_tasks WHERE priority='HIGH' AND status='ACTIVE' ORDER BY created_at DESC LIMIT 10); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- I. KEAMANAN (#102, #106, #108)
-- ============================================================

CREATE OR REPLACE FUNCTION get_audit_chain() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'actor',actor,'action',action,'log_hash',log_hash,'created_at',created_at) ORDER BY id DESC),'[]'::jsonb))
FROM audit_chain LIMIT 50); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION check_contract_expiry() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',nrp,'nama',nama,'contract_end',contract_end_date,
    'days_left',contract_end_date::DATE - CURRENT_DATE)),'[]'::jsonb))
FROM employees_master WHERE status_kerja='PKWT' AND contract_end_date IS NOT NULL
AND contract_end_date <= CURRENT_DATE + INTERVAL '90 days' ORDER BY contract_end_date ASC); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_disciplinary_records() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',d.nrp,'nama',e.nama,'sp_level',d.sp_level,'reason',d.reason,'issued_date',d.issued_date)),'[]'::jsonb))
FROM disciplinary_records d LEFT JOIN employees_master e ON e.nrp=d.nrp ORDER BY d.issued_date DESC); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- J. ADMIN (#111, #113, #115, #120)
-- ============================================================

CREATE OR REPLACE FUNCTION admin_reset_password(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v_new TEXT; v_salt TEXT; v_hash TEXT;
BEGIN
  v_new := substr(md5(random()::text),1,12);
  v_salt := encode(gen_random_bytes(16),'hex');
  v_hash := encode(digest(v_new||v_salt,'sha256'),'hex');
  UPDATE worker_passwords SET password_hash=v_hash, salt=v_salt WHERE nrp=p_nrp;
  RETURN jsonb_build_object('ok',true,'msg','Password direset.','new_password',v_new);
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION admin_get_feature_flags() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('name',name,'enabled',enabled,'description',description)),'[]'::jsonb))
FROM feature_flags); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION admin_set_feature_flag(p_name TEXT, p_enabled BOOLEAN) RETURNS JSONB AS $$
BEGIN UPDATE feature_flags SET enabled=p_enabled, updated_at=NOW() WHERE name=p_name;
IF FOUND THEN RETURN jsonb_build_object('ok',true,'msg','Flag diperbarui.'); END IF;
INSERT INTO feature_flags(name,enabled) VALUES(p_name,p_enabled);
RETURN jsonb_build_object('ok',true,'msg','Flag dibuat.'); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION admin_change_password(p_old TEXT, p_new TEXT) RETURNS JSONB AS $$
DECLARE v_stored TEXT;
BEGIN SELECT value INTO v_stored FROM settings WHERE key='admin_password';
IF v_stored IS NULL THEN v_stored:='Admin123'; END IF;
IF p_old != v_stored THEN RETURN jsonb_build_object('ok',false,'msg','Password lama salah.'); END IF;
UPDATE settings SET value=p_new WHERE key='admin_password';
RETURN jsonb_build_object('ok',true,'msg','Password admin diubah.'); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- K. ASET & FASILITAS (#131, #132, #134)
-- ============================================================

CREATE OR REPLACE FUNCTION get_assets(p_category TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'name',asset_name,'category',category,'status',status,'location',location,'assigned_to',assigned_to)),'[]'::jsonb))
FROM assets WHERE p_category IS NULL OR category=p_category ORDER BY asset_name); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION checkout_asset(p_asset_id TEXT, p_nrp TEXT) RETURNS JSONB AS $$
BEGIN
  UPDATE assets SET status='ASSIGNED', assigned_to=p_nrp WHERE id=p_asset_id AND status='AVAILABLE';
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'msg','Aset tidak tersedia.'); END IF;
  INSERT INTO asset_assignments(asset_id,nrp,checkout_date,condition_out) VALUES(p_asset_id,p_nrp,CURRENT_DATE,'GOOD');
  RETURN jsonb_build_object('ok',true,'msg','Aset di-checkout.');
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION checkin_asset(p_asset_id TEXT, p_condition TEXT) RETURNS JSONB AS $$
BEGIN
  UPDATE assets SET status='AVAILABLE', assigned_to=NULL WHERE id=p_asset_id;
  UPDATE asset_assignments SET checkin_date=CURRENT_DATE, condition_in=p_condition
    WHERE ctid IN (SELECT ctid FROM asset_assignments WHERE asset_id=p_asset_id AND checkin_date IS NULL ORDER BY checkout_date DESC LIMIT 1);
  RETURN jsonb_build_object('ok',true,'msg','Aset di-checkin.');
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_estate_blocks() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'name',block_name,'area',area_hectare,'terrain',terrain,'division',division,'status',status)),'[]'::jsonb))
FROM estate_blocks WHERE status='ACTIVE'); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_facility_request(p_nrp TEXT, p_type TEXT, p_desc TEXT, p_priority TEXT) RETURNS JSONB AS $$
BEGIN INSERT INTO facility_requests(id,nrp,facility_type,description,priority) VALUES(encode(gen_random_bytes(8),'hex'),p_nrp,p_type,p_desc,COALESCE(p_priority,'NORMAL'));
RETURN jsonb_build_object('ok',true,'msg','Pengajuan fasilitas dikirim.'); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- L. OFFBOARDING (#135-#139)
-- ============================================================

CREATE OR REPLACE FUNCTION get_exit_interviews(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',nrp,'score',satisfaction_score,'reason',reason,'feedback',feedback)),'[]'::jsonb))
FROM exit_interviews WHERE p_nrp IS NULL OR nrp=p_nrp); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_exit_interview(p_nrp TEXT, p_score INT, p_reason TEXT, p_feedback TEXT) RETURNS JSONB AS $$
BEGIN INSERT INTO exit_interviews(id,nrp,satisfaction_score,reason,feedback) VALUES('EI'||encode(gen_random_bytes(4),'hex'),p_nrp,p_score,p_reason,p_feedback);
RETURN jsonb_build_object('ok',true,'msg','Exit interview tercatat.'); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_final_settlement(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v_sal NUMERIC; v_leave INT; v_tenure NUMERIC;
BEGIN
  SELECT net_salary INTO v_sal FROM hr_payroll WHERE nrp=p_nrp ORDER BY created_at DESC LIMIT 1;
  SELECT kuota_cuti-cuti_terpakai INTO v_leave FROM hr_leave WHERE nrp=p_nrp ORDER BY tahun DESC LIMIT 1;
  SELECT EXTRACT(YEAR FROM AGE(CURRENT_DATE,COALESCE(tanggal_masuk,CURRENT_DATE))) INTO v_tenure FROM employees_master WHERE nrp=p_nrp;
  v_sal := COALESCE(v_sal,7000000); v_leave := COALESCE(v_leave,0);
  RETURN jsonb_build_object('ok',true,'sisa_cuti_paid',v_leave*(v_sal/30),
    'thr_prorata',v_sal/12,'pesangon',v_sal*GREATEST(v_tenure,1)*1.5,
    'total',v_leave*(v_sal/30)+v_sal/12+v_sal*GREATEST(v_tenure,1)*1.5);
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_offboarding_checklist(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'item',item_name,'status',status,'checked_by',checked_by)),'[]'::jsonb))
FROM offboarding_checklist WHERE nrp=p_nrp); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- M. PERENCANAAN (#139-#141)
-- ============================================================

CREATE OR REPLACE FUNCTION get_headcount_plans(p_year INT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('divisi',divisi,'quarter',quarter,'planned',planned_hc,'actual',actual_hc,
    'variance',actual_hc-planned_hc)),'[]'::jsonb))
FROM headcount_plans WHERE year=COALESCE(p_year,EXTRACT(YEAR FROM NOW())::INT) ORDER BY divisi,quarter); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_budget_allocation(p_year INT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('divisi',divisi,'gaji_budget',gaji_budget,'training_budget',training_budget,'operational_budget',operational_budget,
    'gaji_used',actual_gaji,'training_used',actual_training,
    'training_pct',CASE WHEN training_budget>0 THEN ROUND(actual_training/training_budget*100,1) ELSE 0 END)),'[]'::jsonb))
FROM budget_allocation WHERE year=COALESCE(p_year,EXTRACT(YEAR FROM NOW())::INT)); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION submit_referral(p_nrp TEXT, p_name TEXT, p_email TEXT, p_position TEXT) RETURNS JSONB AS $$
BEGIN INSERT INTO referrals(id,referrer_nrp,candidate_name,candidate_email,position) VALUES('REF'||encode(gen_random_bytes(4),'hex'),p_nrp,p_name,p_email,p_position);
RETURN jsonb_build_object('ok',true,'msg','Referral dikirim. Bonus Rp 1.000.000 jika kandidat hire & lulus probation.'); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_referrals(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('candidate',candidate_name,'position',position,'status',status,'bonus_paid',bonus_paid)),'[]'::jsonb))
FROM referrals WHERE nrp=p_nrp); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- N. LEGAL (#105, #107)
-- ============================================================

CREATE OR REPLACE FUNCTION get_corporate_licenses() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('name',license_name,'number',license_number,'issuer',issuer,'expiry',expiry_date,'status',status)),'[]'::jsonb))
FROM corporate_licenses ORDER BY expiry_date ASC); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_legal_documents() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'type',doc_type,'title',title,'status',status)),'[]'::jsonb))
FROM legal_documents ORDER BY created_at DESC LIMIT 20); END; $$ LANGUAGE plpgsql SECURITY DEFINER;
