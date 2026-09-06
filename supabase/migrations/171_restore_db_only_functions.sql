-- ================================================================
-- 171_restore_db_only_functions.sql
-- Sinkronisasi repo sebagai single source of truth:
--   Fungsi-fungsi di bawah ini ADA di database (public schema) tetapi TIDAK
--   ditemukan di file migrasi manapun (diisi manual di luar migrasi, atau
--   dari file migrasi yang sudah terhapus dari repo).
--
--   Dihasilkan via pg_get_functiondef (CREATE OR REPLACE = idempotent).
--   Aman dijalankan berulang pada DB yang sudah punya fungsi ini (no-op),
--   dan mengembalikan fungsi yang hilang saat repo di-deploy ke DB baru.
--
--   CATATAN: bila ada tipe enum/domain/komposit kustom di argumen/return,
--   tipe tsb TIDAK ikut diekspor (pg_get_functiondef hanya untuk fungsi).
--   Daftar nama yang butuh tipe kustom dicetak saat generator dijalankan.
-- ================================================================


/* ========== add_okr_result(p_okr_id integer, p_kr text, p_target numeric, p_unit text) ========== */
CREATE OR REPLACE FUNCTION public.add_okr_result(p_okr_id integer, p_kr text, p_target numeric, p_unit text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN INSERT INTO hr_okr_results(okr_id,key_result,target_val,unit) VALUES(p_okr_id,p_kr,p_target,p_unit);
RETURN jsonb_build_object('ok',true,'msg','KR added'); END;
$function$


/* ========== add_performance_note(p_nrp text, p_author text, p_type text, p_content text) ========== */
CREATE OR REPLACE FUNCTION public.add_performance_note(p_nrp text, p_author text, p_type text, p_content text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN INSERT INTO performance_notes(nrp,author_nrp,note_type,content) VALUES(p_nrp,p_author,p_type,p_content);
RETURN jsonb_build_object('ok',true,'msg','Catatan ditambahkan.'); END; $function$


/* ========== admin_approve_request(p_id text, p_note text) ========== */
CREATE OR REPLACE FUNCTION public.admin_approve_request(p_id text, p_note text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN 
  UPDATE hr_requests SET status='Approved', note=COALESCE(p_note,'Disetujui admin') WHERE id=p_id AND status='Pending';
  IF FOUND THEN RETURN jsonb_build_object('ok',true,'msg','Request disetujui.'); END IF;
  RETURN jsonb_build_object('ok',false,'msg','Tidak ditemukan atau sudah diproses.');
END;
$function$


/* ========== admin_bulk_approve(p_ids integer[]) ========== */
CREATE OR REPLACE FUNCTION public.admin_bulk_approve(p_ids integer[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
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
END; $function$


/* ========== admin_candidate_pipeline(p_vacancy_id text) ========== */
CREATE OR REPLACE FUNCTION public.admin_candidate_pipeline(p_vacancy_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'nama',nama,'email',email,'stage',stage,'notes',notes,'created_at',created_at) ORDER BY created_at DESC),'[]'::jsonb))
FROM candidate_pipeline WHERE vacancy_id=p_vacancy_id); END; $function$


/* ========== admin_change_password(p_old_password text, p_new_password text) ========== */
CREATE OR REPLACE FUNCTION public.admin_change_password(p_old_password text, p_new_password text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE v_stored TEXT;
BEGIN
  -- Check settings table first, fallback to hardcoded
  SELECT value INTO v_stored FROM settings WHERE key = 'admin_password';
  IF v_stored IS NULL THEN v_stored := 'Admin123'; END IF;

  -- Cek password lama
  IF p_old_password != v_stored THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Password lama salah');
  END IF;

  -- Validasi password baru
  IF length(p_new_password) < 8 THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Password baru minimal 8 karakter');
  END IF;

  -- Update di settings (simpan sebagai plain untuk admin)
  INSERT INTO settings (key, value) VALUES ('admin_password', p_new_password)
  ON CONFLICT (key) DO UPDATE SET value = p_new_password;

  -- Log
  INSERT INTO audit_log (actor, action, detail) VALUES ('admin', 'CHANGE_PASSWORD', 'Admin changed password');

  RETURN jsonb_build_object('ok', true, 'msg', 'Password berhasil diubah. Gunakan password baru untuk login selanjutnya.');
END;
$function$


/* ========== admin_deactivate_worker(p_nrp text) ========== */
CREATE OR REPLACE FUNCTION public.admin_deactivate_worker(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE v_emp RECORD;
BEGIN
  -- Cek employee
  SELECT * INTO v_emp FROM employees_master WHERE nrp = p_nrp;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Karyawan tidak ditemukan');
  END IF;

  -- Disable password
  UPDATE worker_passwords SET is_active = false WHERE nrp = p_nrp;

  -- Log
  INSERT INTO audit_log (actor, action, detail)
  VALUES ('admin', 'DEACTIVATE_WORKER', 'Deactivated ' || p_nrp || ' (' || v_emp.nama || ')');

  RETURN jsonb_build_object('ok', true, 'msg', 'Akses ' || p_nrp || ' (' || v_emp.nama || ') berhasil dinonaktifkan');
END;
$function$


/* ========== admin_get_payroll_secure(p_period text) ========== */
CREATE OR REPLACE FUNCTION public.admin_get_payroll_secure(p_period text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_role TEXT;
BEGIN
  v_role := COALESCE(
    current_setting('request.jwt.claims', true)::json->>'role',
    ''
  );
  
  -- Only admin_pusat, admin_hrd, admin_finance can see full payroll
  IF v_role NOT IN ('admin_pusat', 'admin_hrd', 'admin_finance') THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak');
  END IF;
  
  RETURN COALESCE((
    SELECT jsonb_build_object('ok', true, 'data', jsonb_agg(
      jsonb_build_object(
        'nrp', nrp,
        'periode', periode,
        'base_salary', base_salary,
        'allowance', allowance,
        'deduction', deduction,
        'overtime_pay', overtime_pay,
        'bonus', bonus,
        'net_salary', net_salary,
        'created_at', created_at
      )
    ))
    FROM hr_payroll
    WHERE p_period IS NULL OR periode = p_period
    ORDER BY created_at DESC
  ), jsonb_build_object('ok', true, 'data', '[]'::jsonb));
END;
$function$


/* ========== admin_get_role_matrix() ========== */
CREATE OR REPLACE FUNCTION public.admin_get_role_matrix()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',ur.nrp,'nama',e.nama,'level',ur.role_level,'scope',ur.scope_divisi,'plan',COALESCE(ur.plan,'FREE')) ORDER BY ur.role_level DESC),'[]'::jsonb))
FROM user_roles ur LEFT JOIN employees_master e ON e.nrp=ur.nrp); END; $function$


/* ========== admin_get_vacancies() ========== */
CREATE OR REPLACE FUNCTION public.admin_get_vacancies()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'position',position,'department',department,'quota',quota,'qualifications',qualifications,'status',status)),'[]'::jsonb))
FROM vacancies ORDER BY created_at DESC); END; $function$


/* ========== admin_manage_vacancies(p_action text, p_id text, p_pos text, p_dept text, p_quota integer, p_qual text) ========== */
CREATE OR REPLACE FUNCTION public.admin_manage_vacancies(p_action text, p_id text, p_pos text, p_dept text, p_quota integer, p_qual text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
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
END; $function$


/* ========== admin_reject_request(p_id text, p_note text) ========== */
CREATE OR REPLACE FUNCTION public.admin_reject_request(p_id text, p_note text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN 
  UPDATE hr_requests SET status='Rejected', note=COALESCE(p_note,'Ditolak admin') WHERE id=p_id AND status='Pending';
  IF FOUND THEN RETURN jsonb_build_object('ok',true,'msg','Request ditolak.'); END IF;
  RETURN jsonb_build_object('ok',false,'msg','Tidak ditemukan atau sudah diproses.');
END;
$function$


/* ========== admin_reset_worker_password(p_nrp text, p_new_password text) ========== */
CREATE OR REPLACE FUNCTION public.admin_reset_worker_password(p_nrp text, p_new_password text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE v_emp RECORD;
BEGIN
  -- Cek employee exists
  SELECT * INTO v_emp FROM employees_master WHERE nrp = p_nrp;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Karyawan dengan NRP ' || p_nrp || ' tidak ditemukan');
  END IF;

  -- Validasi
  IF length(p_new_password) < 8 THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Password baru minimal 8 karakter');
  END IF;

  -- Update password (plain text untuk simplicity, production should hash)
  INSERT INTO worker_passwords (nrp, password_hash, salt, is_active, updated_at)
  VALUES (p_nrp, p_new_password, 'admin_reset', true, NOW())
  ON CONFLICT (nrp) DO UPDATE SET
    password_hash = p_new_password,
    salt = 'admin_reset',
    is_active = true,
    attempts = 0,
    blocked_until = NULL,
    updated_at = NOW();

  -- Log
  INSERT INTO audit_log (actor, action, detail)
  VALUES ('admin', 'RESET_PASSWORD', 'Reset password for ' || p_nrp);

  RETURN jsonb_build_object('ok', true, 'msg', 'Password ' || p_nrp || ' berhasil direset. Password baru: ' || p_new_password);
END;
$function$


/* ========== ai_check_rate_limit(p_nrp text, p_max_queries integer, p_max_tokens bigint) ========== */
CREATE OR REPLACE FUNCTION public.ai_check_rate_limit(p_nrp text, p_max_queries integer DEFAULT 50, p_max_tokens bigint DEFAULT 100000)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_count INT;
  v_tokens BIGINT;
BEGIN
  SELECT COALESCE(query_count, 0), COALESCE(tokens_used, 0) INTO v_count, v_tokens
  FROM ai_rate_limits WHERE nrp = p_nrp AND query_date = CURRENT_DATE;

  IF v_count >= p_max_queries THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Batas query AI harian tercapai (' || p_max_queries || ' queries)',
      'remaining', 0, 'limit', p_max_queries);
  END IF;

  IF v_tokens >= p_max_tokens THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Batas token AI harian tercapai',
      'remaining_tokens', 0, 'limit_tokens', p_max_tokens);
  END IF;

  RETURN jsonb_build_object('ok', true, 'remaining', p_max_queries - v_count,
    'remaining_tokens', p_max_tokens - v_tokens);
END;
$function$


/* ========== ai_record_query(p_nrp text, p_tokens integer) ========== */
CREATE OR REPLACE FUNCTION public.ai_record_query(p_nrp text, p_tokens integer DEFAULT 0)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  INSERT INTO ai_rate_limits (nrp, query_date, query_count, tokens_used)
  VALUES (p_nrp, CURRENT_DATE, 1, p_tokens)
  ON CONFLICT (nrp, query_date) DO UPDATE SET
    query_count = ai_rate_limits.query_count + 1,
    tokens_used = ai_rate_limits.tokens_used + p_tokens;
END;
$function$


/* ========== apply_data_retention() ========== */
CREATE OR REPLACE FUNCTION public.apply_data_retention()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$ DECLARE
  v_rule RECORD; v_deleted INT; v_total INT := 0; v_results JSONB := '[]'::jsonb;
BEGIN
  FOR v_rule IN SELECT * FROM data_retention_rules WHERE is_active = true LOOP
    IF v_rule.table_name = 'session_tokens' THEN
      EXECUTE format('DELETE FROM %I WHERE expires_at < NOW() - INTERVAL %L', v_rule.table_name, v_rule.retention_days || ' days');
    ELSIF v_rule.table_name = 'login_attempts' THEN
      -- FIX: login_attempts uses created_at, NOT attempt_time
      EXECUTE format('DELETE FROM %I WHERE created_at < NOW() - INTERVAL %L', v_rule.table_name, v_rule.retention_days || ' days');
    ELSE
      BEGIN
        EXECUTE format('DELETE FROM %I WHERE created_at < NOW() - INTERVAL %L', v_rule.table_name, v_rule.retention_days || ' days');
      EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'Retention skip %: %', v_rule.table_name, SQLERRM;
      END;
    END IF;
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    v_total := v_total + v_deleted;
    v_results := v_results || jsonb_build_object('table', v_rule.table_name, 'deleted', v_deleted);
  END LOOP;
  INSERT INTO audit_log (action, result, message, created_at)
  VALUES ('DATA_RETENTION_CLEANUP', 'INFO', jsonb_build_object('total_deleted', v_total, 'details', v_results)::text, NOW());
  RETURN jsonb_build_object('ok', true, 'total_deleted', v_total, 'details', v_results);
END; $function$


/* ========== ask_copilot(p_nrp text, p_question text) ========== */
CREATE OR REPLACE FUNCTION public.ask_copilot(p_nrp text, p_question text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE v_answer TEXT;
BEGIN
  v_answer := 'Ini adalah jawaban demo untuk: "'||p_question||'". ';
  v_answer := v_answer || 'Untuk jawaban AI nyata, integrasikan OpenAI/Gemini API dengan RAG.';
  INSERT INTO audit_log(actor,action,detail) VALUES(p_nrp,'COPILOT_ASK',p_question);
  RETURN jsonb_build_object('ok',true,'answer',v_answer);
END; $function$


/* ========== auto_deactivate_expired_pkwt() ========== */
CREATE OR REPLACE FUNCTION public.auto_deactivate_expired_pkwt()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  -- Deactivate PKWT yang sudah expired (2 tahun dari tanggal masuk)
  UPDATE worker_passwords
  SET is_active = false, updated_at = NOW()
  WHERE nrp IN (
    SELECT nrp FROM employees_master
    WHERE status_kerja = 'PKWT'
    AND (tanggal_masuk + interval '2 year')::date < NOW()
  )
  AND is_active = true;

  -- Log
  INSERT INTO audit_log (actor, action, detail)
  SELECT 'SYSTEM', 'AUTO_DEACTIVATE_PKWT', 'Auto-deactivated ' || nrp || ' (expired PKWT)'
  FROM employees_master
  WHERE status_kerja = 'PKWT'
  AND (tanggal_masuk + interval '2 year')::date < NOW()
  AND nrp IN (SELECT nrp FROM worker_passwords WHERE is_active = true);
END;
$function$


/* ========== calculate_incentive(p_nrp text) ========== */
CREATE OR REPLACE FUNCTION public.calculate_incentive(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE v_sal NUMERIC; v_kpi NUMERIC; v_final NUMERIC;
BEGIN
  SELECT net_salary INTO v_sal FROM hr_payroll WHERE nrp=p_nrp ORDER BY created_at DESC LIMIT 1;
  SELECT kpi_score INTO v_kpi FROM hr_performance WHERE nrp=p_nrp ORDER BY created_at DESC LIMIT 1;
  v_final := COALESCE(v_sal,0) * 0.10 * COALESCE(v_kpi,70) / 100;
  RETURN jsonb_build_object('ok',true,'base',COALESCE(v_sal,0),'kpi_factor',COALESCE(v_kpi,70),'incentive',v_final);
END; $function$


/* ========== check_api_rate_limit(p_key_hash text) ========== */
CREATE OR REPLACE FUNCTION public.check_api_rate_limit(p_key_hash text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$ DECLARE
  v_key_id INT; v_limit INT; v_count INT; v_window TIMESTAMPTZ;
BEGIN
  SELECT id, rate_limit_per_minute INTO v_key_id, v_limit
  FROM api_keys WHERE key_hash = p_key_hash AND is_active = true;
  IF v_key_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Invalid or inactive API key');
  END IF;
  v_window := date_trunc('minute', NOW());
  INSERT INTO api_rate_limits (api_key_id, window_start, request_count)
  VALUES (v_key_id, v_window, 1)
  ON CONFLICT (api_key_id, window_start) DO UPDATE SET request_count = api_rate_limits.request_count + 1;
  SELECT request_count INTO v_count FROM api_rate_limits WHERE api_key_id = v_key_id AND window_start = v_window;
  IF v_count > v_limit THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Rate limit exceeded', 'limit', v_limit, 'current', v_count);
  END IF;
  RETURN jsonb_build_object('ok', true, 'remaining', v_limit - v_count);
END; $function$


/* ========== check_contract_expiry() ========== */
CREATE OR REPLACE FUNCTION public.check_contract_expiry()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',nrp,'nama',nama,'contract_end',contract_end_date,
    'days_left',contract_end_date::DATE - CURRENT_DATE)),'[]'::jsonb))
FROM employees_master WHERE status_kerja='PKWT' AND contract_end_date IS NOT NULL
AND contract_end_date <= CURRENT_DATE + INTERVAL '90 days' ORDER BY contract_end_date ASC); END; $function$


/* ========== check_mfa_status(p_nrp text) ========== */
CREATE OR REPLACE FUNCTION public.check_mfa_status(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_mfa RECORD;
BEGIN
  SELECT * INTO v_mfa FROM mfa_store WHERE nrp = p_nrp AND enabled = true;
  
  IF v_mfa IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'enabled', false);
  END IF;
  
  RETURN jsonb_build_object('ok', true, 'enabled', true);
END;
$function$


/* ========== checkin_asset(p_asset_id text, p_condition text) ========== */
CREATE OR REPLACE FUNCTION public.checkin_asset(p_asset_id text, p_condition text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  UPDATE assets SET status='AVAILABLE', assigned_to=NULL WHERE id=p_asset_id;
  UPDATE asset_assignments SET checkin_date=CURRENT_DATE, condition_in=p_condition
    WHERE ctid IN (SELECT ctid FROM asset_assignments WHERE asset_id=p_asset_id AND checkin_date IS NULL ORDER BY checkout_date DESC LIMIT 1);
  RETURN jsonb_build_object('ok',true,'msg','Aset di-checkin.');
END; $function$


/* ========== checkout_asset(p_asset_id text, p_nrp text) ========== */
CREATE OR REPLACE FUNCTION public.checkout_asset(p_asset_id text, p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  UPDATE assets SET status='ASSIGNED', assigned_to=p_nrp WHERE id=p_asset_id AND status='AVAILABLE';
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'msg','Aset tidak tersedia.'); END IF;
  INSERT INTO asset_assignments(asset_id,nrp,checkout_date,condition_out) VALUES(p_asset_id,p_nrp,CURRENT_DATE,'GOOD');
  RETURN jsonb_build_object('ok',true,'msg','Aset di-checkout.');
END; $function$


/* ========== cleanup_api_rate_limits() ========== */
CREATE OR REPLACE FUNCTION public.cleanup_api_rate_limits()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$ BEGIN
  DELETE FROM api_rate_limits WHERE window_start < NOW() - INTERVAL '2 hours';
END; $function$


/* ========== cleanup_dashboard_cache() ========== */
CREATE OR REPLACE FUNCTION public.cleanup_dashboard_cache()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN DELETE FROM dashboard_cache WHERE cached_at < NOW() - INTERVAL '1 hour'; END;
$function$


/* ========== cleanup_expired_data() ========== */
CREATE OR REPLACE FUNCTION public.cleanup_expired_data()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_audit_days INT;
  v_ai_days INT;
  v_session_days INT;
  v_attempt_days INT;
  v_audit_deleted INT := 0;
  v_ai_deleted INT := 0;
  v_session_deleted INT := 0;
  v_attempt_deleted INT := 0;
  v_results JSONB := '[]'::jsonb;
BEGIN
  -- Read config values (owner can change via dashboard)
  SELECT (config_value->>'value')::INT INTO v_audit_days
  FROM company_config WHERE config_key = 'audit_log_retention_days';
  SELECT (config_value->>'value')::INT INTO v_ai_days
  FROM company_config WHERE config_key = 'ai_rate_limit_retention_days';
  SELECT (config_value->>'value')::INT INTO v_session_days
  FROM company_config WHERE config_key = 'session_retention_days';
  SELECT (config_value->>'value')::INT INTO v_attempt_days
  FROM company_config WHERE config_key = 'login_attempt_retention_days';

  -- Defaults if config missing
  v_audit_days := COALESCE(v_audit_days, 90);
  v_ai_days := COALESCE(v_ai_days, 30);
  v_session_days := COALESCE(v_session_days, 7);
  v_attempt_days := COALESCE(v_attempt_days, 14);

  -- 1. Cleanup audit_log (if retention > 0)
  IF v_audit_days > 0 THEN
    DELETE FROM audit_log WHERE created_at < NOW() - (v_audit_days || ' days')::INTERVAL;
    GET DIAGNOSTICS v_audit_deleted = ROW_COUNT;
  END IF;

  -- 2. Cleanup ai_rate_limits / api_rate_limits
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'api_rate_limits') THEN
    DELETE FROM api_rate_limits WHERE window_start < NOW() - (v_ai_days || ' days')::INTERVAL;
    GET DIAGNOSTICS v_ai_deleted = ROW_COUNT;
  END IF;

  -- 3. Cleanup expired sessions
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'session_tokens') THEN
    DELETE FROM session_tokens WHERE expires_at < NOW() - (v_session_days || ' days')::INTERVAL;
    GET DIAGNOSTICS v_session_deleted = ROW_COUNT;
  END IF;

  -- 4. Cleanup old login attempts
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'login_attempts') THEN
    DELETE FROM login_attempts WHERE attempt_time < NOW() - (v_attempt_days || ' days')::INTERVAL;
    GET DIAGNOSTICS v_attempt_deleted = ROW_COUNT;
  END IF;

  -- 5. Cleanup expired password reset tokens (otp_store)
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'otp_store') THEN
    DELETE FROM otp_store WHERE expiry < NOW() AND used = true;
  END IF;

  -- Audit log the cleanup itself (with guard to avoid recursive trigger)
  INSERT INTO audit_log (action, result, message, created_at)
  VALUES ('AUTO_CLEANUP', 'SUCCESS',
    jsonb_build_object(
      'audit_deleted', v_audit_deleted,
      'ai_rate_deleted', v_ai_deleted,
      'session_deleted', v_session_deleted,
      'attempt_deleted', v_attempt_deleted,
      'config', jsonb_build_object(
        'audit_log', v_audit_days || ' days',
        'ai_rate_limit', v_ai_days || ' days',
        'session', v_session_days || ' days',
        'login_attempt', v_attempt_days || ' days'
      )
    )::text, NOW());

  RETURN jsonb_build_object(
    'ok', true,
    'audit_deleted', v_audit_deleted,
    'ai_rate_deleted', v_ai_deleted,
    'session_deleted', v_session_deleted,
    'attempt_deleted', v_attempt_deleted,
    'config', jsonb_build_object(
      'audit_log_retention', v_audit_days || ' days',
      'ai_rate_limit_retention', v_ai_days || ' days',
      'session_retention', v_session_days || ' days',
      'login_attempt_retention', v_attempt_days || ' days'
    )
  );
END;
$function$


/* ========== clock_in(p_nrp text) ========== */
CREATE OR REPLACE FUNCTION public.clock_in(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN INSERT INTO timesheets(nrp,work_date,clock_in) VALUES(p_nrp,CURRENT_DATE,CURRENT_TIME)
  ON CONFLICT (nrp,work_date) DO UPDATE SET clock_in=CURRENT_TIME;
RETURN jsonb_build_object('ok',true,'msg','Clock in tercatat.','time',CURRENT_TIME::TEXT); END; $function$


/* ========== clock_out(p_nrp text) ========== */
CREATE OR REPLACE FUNCTION public.clock_out(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN UPDATE timesheets SET clock_out=CURRENT_TIME,
  total_hours=EXTRACT(EPOCH FROM (CURRENT_TIME-clock_in))/3600 WHERE nrp=p_nrp AND work_date=CURRENT_DATE;
RETURN jsonb_build_object('ok',true,'msg','Clock out tercatat.','time',CURRENT_TIME::TEXT); END; $function$


/* ========== create_exit_interview(p_nrp text, p_score integer, p_reason text, p_feedback text) ========== */
CREATE OR REPLACE FUNCTION public.create_exit_interview(p_nrp text, p_score integer, p_reason text, p_feedback text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN INSERT INTO exit_interviews(id,nrp,satisfaction_score,reason,feedback) VALUES('EI'||encode(gen_random_bytes(4),'hex'),p_nrp,p_score,p_reason,p_feedback);
RETURN jsonb_build_object('ok',true,'msg','Exit interview tercatat.'); END; $function$


/* ========== create_facility_request(p_nrp text, p_type text, p_desc text, p_priority text) ========== */
CREATE OR REPLACE FUNCTION public.create_facility_request(p_nrp text, p_type text, p_desc text, p_priority text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN INSERT INTO facility_requests(id,nrp,facility_type,description,priority) VALUES(encode(gen_random_bytes(8),'hex'),p_nrp,p_type,p_desc,COALESCE(p_priority,'NORMAL'));
RETURN jsonb_build_object('ok',true,'msg','Pengajuan fasilitas dikirim.'); END; $function$


/* ========== create_okr(p_nrp text, p_periode text, p_objective text) ========== */
CREATE OR REPLACE FUNCTION public.create_okr(p_nrp text, p_periode text, p_objective text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE v_id INT;
BEGIN INSERT INTO hr_okrs(nrp,periode,objective) VALUES(p_nrp,p_periode,p_objective) RETURNING id INTO v_id;
RETURN jsonb_build_object('ok',true,'id',v_id); END;
$function$


/* ========== create_overtime_request(p_nrp text, p_date date, p_hours numeric, p_reason text) ========== */
CREATE OR REPLACE FUNCTION public.create_overtime_request(p_nrp text, p_date date, p_hours numeric, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  INSERT INTO hr_overtime(id,nrp,date,hours,reason,status) VALUES(encode(gen_random_bytes(8),'hex'),p_nrp,p_date,p_hours,p_reason,'PENDING');
  RETURN jsonb_build_object('ok',true,'msg','Lembur diajukan.');
END; $function$


/* ========== create_reimbursement(p_nrp text, p_travel_id text, p_category text, p_amount numeric) ========== */
CREATE OR REPLACE FUNCTION public.create_reimbursement(p_nrp text, p_travel_id text, p_category text, p_amount numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  INSERT INTO reimbursements(id,nrp,travel_id,category,amount,status) VALUES(encode(gen_random_bytes(8),'hex'),p_nrp,p_travel_id,p_category,p_amount,'PENDING');
  RETURN jsonb_build_object('ok',true,'msg','Reimbursement diajukan.');
END; $function$


/* ========== create_shift_swap(p_req text, p_tgt text, p_date date, p_req_shift text, p_tgt_shift text) ========== */
CREATE OR REPLACE FUNCTION public.create_shift_swap(p_req text, p_tgt text, p_date date, p_req_shift text, p_tgt_shift text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN INSERT INTO shift_swaps(id,requester_nrp,target_nrp,swap_date,requester_shift,target_shift)
  VALUES(encode(gen_random_bytes(8),'hex'),p_req,p_tgt,p_date,p_req_shift,p_tgt_shift);
RETURN jsonb_build_object('ok',true,'msg','Swap shift diajukan.'); END; $function$


/* ========== create_travel_request(p_nrp text, p_dest text, p_purpose text, p_start date, p_end date, p_cost numeric) ========== */
CREATE OR REPLACE FUNCTION public.create_travel_request(p_nrp text, p_dest text, p_purpose text, p_start date, p_end date, p_cost numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE v_days INT; v_perdiem NUMERIC;
BEGIN
  v_days := GREATEST(p_end - p_start + 1, 1);
  v_perdiem := v_days * 350000;
  INSERT INTO travel_requests(id,nrp,destination,purpose,start_date,end_date,estimated_cost,per_diem,status)
    VALUES(encode(gen_random_bytes(8),'hex'),p_nrp,p_dest,p_purpose,p_start,p_end,p_cost,v_perdiem,'PENDING');
  RETURN jsonb_build_object('ok',true,'msg','Perjalanan diajukan.','per_diem',v_perdiem);
END; $function$


/* ========== export_attendance(p_periode text) ========== */
CREATE OR REPLACE FUNCTION public.export_attendance(p_periode text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,
  'headers','NRP;Nama;Tanggal;Status;Shift;Telat(mnt)',
  'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',a.nrp,'nama',e.nama,'date',a.date,
      'status_hadir',a.status_hadir,'shift',a.shift,'menit_terlambat',a.menit_terlambat) 
    ORDER BY a.nrp,a.date),'[]'::jsonb))
FROM hr_attendance a LEFT JOIN employees_master e ON e.nrp=a.nrp 
WHERE (p_periode IS NULL OR TO_CHAR(a.date,'YYYY-MM')=p_periode) LIMIT 1000); END;
$function$


/* ========== export_employees() ========== */
CREATE OR REPLACE FUNCTION public.export_employees()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,
  'headers','NRP;Nama;NIK;Email;Divisi;Posisi;Status Kerja;No HP;Status Aktif',
  'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',nrp,'nama',nama,'nik',nik,'email',email,'divisi',divisi,
      'posisi',posisi,'status_kerja',status_kerja,'no_hp',no_hp,'status_kerja',status_kerja) 
    ORDER BY nama),'[]'::jsonb))
FROM employees_master); END;
$function$


/* ========== export_leave() ========== */
CREATE OR REPLACE FUNCTION public.export_leave()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,
  'headers','NRP;Nama;Tahun;Kuota;Terpakai;Sisa',
  'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',l.nrp,'nama',e.nama,'tahun',l.tahun,
      'kuota',l.kuota_cuti,'terpakai',l.cuti_terpakai,'sisa',l.kuota_cuti-l.cuti_terpakai) 
    ORDER BY l.nrp),'[]'::jsonb))
FROM hr_leave l LEFT JOIN employees_master e ON e.nrp=l.nrp); END;
$function$


/* ========== export_org() ========== */
CREATE OR REPLACE FUNCTION public.export_org()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,
  'headers','NRP;Nama;Divisi;Posisi;Atasan;Level',
  'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',e.nrp,'nama',e.nama,'divisi',e.divisi,
      'posisi',e.posisi,'atasan',o.atasan_nrp,'level',COALESCE(ur.role_level,1)) 
    ORDER BY e.nama),'[]'::jsonb))
FROM employees_master e 
LEFT JOIN hr_org o ON o.nrp=e.nrp 
LEFT JOIN user_roles ur ON ur.nrp=e.nrp); END;
$function$


/* ========== export_payroll(p_periode text) ========== */
CREATE OR REPLACE FUNCTION public.export_payroll(p_periode text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,
  'headers','NRP;Nama;Periode;Gaji Pokok;Tunjangan;Potongan;Lembur;Bersih',
  'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',e.nrp,'nama',e.nama,'periode',p.periode,
      'base_salary',p.base_salary,'allowance',p.allowance,'deduction',p.deduction,
      'overtime_pay',p.overtime_pay,'net_salary',p.net_salary) 
    ORDER BY e.nrp),'[]'::jsonb))
FROM hr_payroll p LEFT JOIN employees_master e ON e.nrp=p.nrp 
WHERE p.periode=COALESCE(p_periode,(SELECT MAX(periode) FROM hr_payroll))); END;
$function$


/* ========== export_sheet(p_sheet text) ========== */
CREATE OR REPLACE FUNCTION public.export_sheet(p_sheet text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  IF p_sheet = 'employees_master' OR p_sheet = 'employees' THEN RETURN export_employees();
  ELSIF p_sheet = 'hr_payroll' OR p_sheet = 'payroll' THEN RETURN export_payroll(NULL);
  ELSIF p_sheet = 'hr_attendance' OR p_sheet = 'attendance' THEN RETURN export_attendance(NULL);
  ELSIF p_sheet = 'hr_leave' OR p_sheet = 'leave' THEN RETURN export_leave();
  ELSIF p_sheet = 'hr_org' OR p_sheet = 'org' THEN RETURN export_org();
  ELSE RETURN jsonb_build_object('ok',false,'msg','Sheet tidak dikenali: '||p_sheet);
  END IF;
END;
$function$


/* ========== get_active_surveys() ========== */
CREATE OR REPLACE FUNCTION public.get_active_surveys()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN jsonb_build_object('ok',true,'data',COALESCE((SELECT jsonb_agg(jsonb_build_object('id',id,'title',title,'questions',questions)) FROM hr_surveys WHERE status='active'),'[]'::jsonb)); END;
$function$


/* ========== get_ai_tasks() ========== */
CREATE OR REPLACE FUNCTION public.get_ai_tasks()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'agent',agent_name,'type',task_type,'title',title,'status',status,'priority',priority)),'[]'::jsonb))
FROM hr_ai_tasks ORDER BY created_at DESC LIMIT 20); END; $function$


/* ========== get_anomaly_details() ========== */
CREATE OR REPLACE FUNCTION public.get_anomaly_details()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'type',task_type,'title',title,'priority',priority,'status',status,'details',details_json,'created_at',created_at)
  ORDER BY created_at DESC),'[]'::jsonb))
FROM hr_ai_tasks LIMIT 20); END;
$function$


/* ========== get_assets(p_category text) ========== */
CREATE OR REPLACE FUNCTION public.get_assets(p_category text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'name',asset_name,'category',category,'status',status,'location',location,'assigned_to',assigned_to)),'[]'::jsonb))
FROM assets WHERE p_category IS NULL OR category=p_category ORDER BY asset_name); END; $function$


/* ========== get_audit_chain() ========== */
CREATE OR REPLACE FUNCTION public.get_audit_chain()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'actor',actor,'action',action,'log_hash',log_hash,'created_at',created_at) ORDER BY id DESC),'[]'::jsonb))
FROM audit_chain LIMIT 50); END; $function$


/* ========== get_auto_healing_actions() ========== */
CREATE OR REPLACE FUNCTION public.get_auto_healing_actions()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'agent',agent_name,'type',task_type,'title',title,'status',status,'details',details_json)
    ORDER BY created_at DESC),'[]'::jsonb))
  FROM hr_ai_tasks WHERE task_type IN ('AUTO_COACHING','AUTO_ENROLL','AUTO_REJECT') LIMIT 20); END;
$function$


/* ========== get_badges(p_nrp text) ========== */
CREATE OR REPLACE FUNCTION public.get_badges(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('badge_name',badge_name,'badge_type',badge_type,'points',points,'awarded_date',awarded_date)),'[]'::jsonb))
FROM badges WHERE nrp=p_nrp); END; $function$


/* ========== get_badges_leaderboard() ========== */
CREATE OR REPLACE FUNCTION public.get_badges_leaderboard()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',b.nrp,'nama',e.nama,'total_points',b.total_points) ORDER BY b.total_points DESC),'[]'::jsonb))
FROM (SELECT nrp,SUM(points) as total_points FROM badges GROUP BY nrp) b LEFT JOIN employees_master e ON e.nrp=b.nrp LIMIT 20); END; $function$


/* ========== get_budget_allocation(p_year integer) ========== */
CREATE OR REPLACE FUNCTION public.get_budget_allocation(p_year integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('divisi',divisi,'gaji_budget',gaji_budget,'training_budget',training_budget,'operational_budget',operational_budget,
    'gaji_used',actual_gaji,'training_used',actual_training,
    'training_pct',CASE WHEN training_budget>0 THEN ROUND(actual_training/training_budget*100,1) ELSE 0 END)),'[]'::jsonb))
FROM budget_allocation WHERE year=COALESCE(p_year,EXTRACT(YEAR FROM NOW())::INT)); END; $function$


/* ========== get_cached(p_key text, p_ttl integer) ========== */
CREATE OR REPLACE FUNCTION public.get_cached(p_key text, p_ttl integer DEFAULT 300)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$ DECLARE v_cached JSONB;
BEGIN
  SELECT cache_data INTO v_cached FROM dashboard_cache
  WHERE cache_key = p_key AND cached_at > NOW() - (p_ttl || ' seconds')::INTERVAL;
  IF v_cached IS NOT NULL THEN
    UPDATE dashboard_cache SET hit_count = hit_count + 1 WHERE cache_key = p_key;
    RETURN v_cached;
  END IF;
  RETURN NULL;
END; $function$


/* ========== get_certifications(p_nrp text) ========== */
CREATE OR REPLACE FUNCTION public.get_certifications(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'cert_name',cert_name,'issuer',issuer,'issue_date',issue_date,'expiry_date',expiry_date,'status',status)),'[]'::jsonb))
FROM certifications WHERE nrp=p_nrp); END; $function$


/* ========== get_compensation_intelligence(p_nrp text) ========== */
CREATE OR REPLACE FUNCTION public.get_compensation_intelligence(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE v RECORD; v_avg NUMERIC;
BEGIN
  SELECT net_salary INTO v FROM hr_payroll WHERE nrp=p_nrp ORDER BY created_at DESC LIMIT 1;
  SELECT AVG(net_salary) INTO v_avg FROM hr_payroll WHERE periode=(SELECT MAX(periode) FROM hr_payroll);
  RETURN jsonb_build_object('ok',true,'my_salary',COALESCE(v,0),'avg_salary',COALESCE(v_avg,0),
    'percentile',CASE WHEN v_avg>0 THEN ROUND(v/v_avg*100,1) ELSE 0 END);
END; $function$


/* ========== get_corporate_licenses() ========== */
CREATE OR REPLACE FUNCTION public.get_corporate_licenses()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('name',license_name,'number',license_number,'issuer',issuer,'expiry',expiry_date,'status',status)),'[]'::jsonb))
FROM corporate_licenses ORDER BY expiry_date ASC); END; $function$


/* ========== get_cost_per_unit() ========== */
CREATE OR REPLACE FUNCTION public.get_cost_per_unit()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE v_labor NUMERIC; v_prod NUMERIC; BEGIN
  SELECT SUM(total_labor_cost) INTO v_labor FROM hr_finance_kpi WHERE periode=(SELECT MAX(periode) FROM hr_finance_kpi);
  SELECT SUM(volume) INTO v_prod FROM hr_production_daily WHERE date>=date_trunc('month',NOW());
  RETURN jsonb_build_object('ok',true,'labor_cost',COALESCE(v_labor,0),'total_production',COALESCE(v_prod,0),
    'cost_per_ton',CASE WHEN v_prod>0 THEN ROUND(v_labor/v_prod,2) ELSE 0 END); END;
$function$


/* ========== get_dashboard_cached() ========== */
CREATE OR REPLACE FUNCTION public.get_dashboard_cached()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$ DECLARE v_cached JSONB;
BEGIN
  v_cached := get_cached('dashboard_summary', 300);
  IF v_cached IS NOT NULL THEN
    RETURN jsonb_build_object('ok', true, 'cached', true, 'data', v_cached);
  END IF;
  SELECT jsonb_build_object(
    'total_employees', (SELECT COUNT(*) FROM employees_master WHERE status_kerja = 'PKWTT'),
    'active_leaves', (SELECT COUNT(*) FROM hr_leave WHERE status = 'pending'),
    'pending_overtime', (SELECT COUNT(*) FROM hr_overtime WHERE status = 'pending'),
    'pending_requests', (SELECT COUNT(*) FROM hr_requests WHERE status = 'pending'),
    'total_payroll_this_month', (SELECT COALESCE(SUM(gross_salary), 0) FROM hr_payroll WHERE periode = to_char(NOW(), 'YYYY-MM'))
  ) INTO v_cached;
  PERFORM set_cache('dashboard_summary', v_cached, 300);
  RETURN jsonb_build_object('ok', true, 'cached', false, 'data', v_cached);
END; $function$


/* ========== get_disciplinary_records() ========== */
CREATE OR REPLACE FUNCTION public.get_disciplinary_records()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',d.nrp,'nama',e.nama,'sp_level',d.sp_level,'reason',d.reason,'issued_date',d.issued_date)),'[]'::jsonb))
FROM disciplinary_records d LEFT JOIN employees_master e ON e.nrp=d.nrp ORDER BY d.issued_date DESC); END; $function$


/* ========== get_employee_documents(p_nrp text) ========== */
CREATE OR REPLACE FUNCTION public.get_employee_documents(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('type',type,'sub_type',sub_type)),'[]'::jsonb))
FROM hr_document_types LIMIT 20); END; $function$


/* ========== get_employee_mutations(p_nrp text) ========== */
CREATE OR REPLACE FUNCTION public.get_employee_mutations(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('from_position',from_position,'to_position',to_position,'effective_date',effective_date,'reason',reason) ORDER BY effective_date DESC),'[]'::jsonb))
FROM employee_mutations WHERE nrp=p_nrp); END; $function$


/* ========== get_enps_score() ========== */
CREATE OR REPLACE FUNCTION public.get_enps_score()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE v_total INT; v_promoters INT; v_detractors INT; v_score NUMERIC;
BEGIN
  SELECT COUNT(*),COUNT(*) FILTER(WHERE score>=9),COUNT(*) FILTER(WHERE score<=6) INTO v_total,v_promoters,v_detractors FROM survey_responses;
  v_score := CASE WHEN v_total>0 THEN ROUND((v_promoters::NUMERIC/v_total - v_detractors::NUMERIC/v_total)*100,1) ELSE 0 END;
  RETURN jsonb_build_object('ok',true,'total_respondents',v_total,'promoters',v_promoters,'detractors',v_detractors,'enps_score',v_score);
END; $function$


/* ========== get_executive_brief() ========== */
CREATE OR REPLACE FUNCTION public.get_executive_brief()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE v_hp INT; v_lp INT; v_fr INT; v_com INT;
BEGIN
  SELECT COUNT(*) INTO v_hp FROM hr_performance WHERE kpi_score>=80 AND period=(SELECT MAX(period) FROM hr_performance);
  SELECT COUNT(*) INTO v_lp FROM hr_performance WHERE kpi_score<60 AND period=(SELECT MAX(period) FROM hr_performance);
  SELECT COUNT(*) INTO v_fr FROM hr_performance WHERE kpi_score<70 AND period=(SELECT MAX(period) FROM hr_performance);
  SELECT COUNT(*) INTO v_com FROM hr_compliance WHERE status='OVERDUE';
  RETURN jsonb_build_object('ok',true,'critical_items',v_lp,'attention_items',v_fr,'positive_items',v_hp,'compliance_issues',v_com,
    'recommendations',jsonb_build_array('Review karyawan KPI < 60','Perpanjang sertifikasi expired','Tinjau anggaran training'));
END; $function$


/* ========== get_exit_interviews(p_nrp text) ========== */
CREATE OR REPLACE FUNCTION public.get_exit_interviews(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',nrp,'score',satisfaction_score,'reason',reason,'feedback',feedback)),'[]'::jsonb))
FROM exit_interviews WHERE p_nrp IS NULL OR nrp=p_nrp); END; $function$


/* ========== get_final_settlement(p_nrp text) ========== */
CREATE OR REPLACE FUNCTION public.get_final_settlement(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE v_sal NUMERIC; v_leave INT; v_tenure NUMERIC;
BEGIN
  SELECT net_salary INTO v_sal FROM hr_payroll WHERE nrp=p_nrp ORDER BY created_at DESC LIMIT 1;
  SELECT kuota_cuti-cuti_terpakai INTO v_leave FROM hr_leave WHERE nrp=p_nrp ORDER BY tahun DESC LIMIT 1;
  SELECT EXTRACT(YEAR FROM AGE(CURRENT_DATE,COALESCE(tanggal_masuk,CURRENT_DATE))) INTO v_tenure FROM employees_master WHERE nrp=p_nrp;
  v_sal := COALESCE(v_sal,7000000); v_leave := COALESCE(v_leave,0);
  RETURN jsonb_build_object('ok',true,'sisa_cuti_paid',v_leave*(v_sal/30),
    'thr_prorata',v_sal/12,'pesangon',v_sal*GREATEST(v_tenure,1)*1.5,
    'total',v_leave*(v_sal/30)+v_sal/12+v_sal*GREATEST(v_tenure,1)*1.5);
END; $function$


/* ========== get_financial_stats() ========== */
CREATE OR REPLACE FUNCTION public.get_financial_stats()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('periode',periode,'divisi',divisi,'revenue',revenue,'profit',profit,'opex',opex,'labor_cost',total_labor_cost,
    'profit_margin',CASE WHEN revenue>0 THEN ROUND(profit/revenue*100,1) ELSE 0 END,
    'labor_pct',CASE WHEN revenue>0 THEN ROUND(total_labor_cost/revenue*100,1) ELSE 0 END)
    ORDER BY periode DESC, revenue DESC),'[]'::jsonb))
  FROM hr_finance_kpi); END;
$function$


/* ========== get_financial_trend() ========== */
CREATE OR REPLACE FUNCTION public.get_financial_trend()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('periode',x.periode,'total_revenue',x.total_revenue,'total_profit',x.total_profit,'total_labor',x.total_labor,
  'profit_margin',CASE WHEN x.total_revenue>0 THEN ROUND(x.total_profit/x.total_revenue*100,1) ELSE 0 END) ORDER BY x.periode DESC),'[]'::jsonb))
FROM (SELECT periode,SUM(revenue) as total_revenue,SUM(profit) as total_profit,SUM(total_labor_cost) as total_labor FROM hr_finance_kpi GROUP BY periode ORDER BY periode DESC LIMIT 6) x); END;
$function$


/* ========== get_flight_risk_details() ========== */
CREATE OR REPLACE FUNCTION public.get_flight_risk_details()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',e.nrp,'nama',e.nama,'divisi',e.divisi,'posisi',e.posisi,
    'kpi_score',COALESCE(p.kpi_score,0),'telat_count',COALESCE(t.telat_count,0),
    'sp_count',COALESCE(s.sp_count,0),'risk_score',ROUND(COALESCE(p.kpi_score,100)*0.3 + COALESCE(t.telat_count,0)*10*0.4 + COALESCE(s.sp_count,0)*15*0.3,0))
    ORDER BY COALESCE(p.kpi_score,100) ASC),'[]'::jsonb))
  FROM employees_master e
  LEFT JOIN hr_performance p ON p.nrp=e.nrp AND p.period=(SELECT MAX(period) FROM hr_performance)
  LEFT JOIN (SELECT nrp,COUNT(*) as telat_count FROM hr_attendance WHERE status_hadir='Telat' AND date>=date_trunc('month',NOW()) GROUP BY nrp) t ON t.nrp=e.nrp
  LEFT JOIN (SELECT nrp,COUNT(*) as sp_count FROM hr_relations WHERE type='SP' GROUP BY nrp) s ON s.nrp=e.nrp
  WHERE COALESCE(p.kpi_score,100)<70 OR COALESCE(t.telat_count,0)>5); END;
$function$


/* ========== get_headcount_plans(p_year integer) ========== */
CREATE OR REPLACE FUNCTION public.get_headcount_plans(p_year integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('divisi',divisi,'quarter',quarter,'planned',planned_hc,'actual',actual_hc,
    'variance',actual_hc-planned_hc)),'[]'::jsonb))
FROM headcount_plans WHERE year=COALESCE(p_year,EXTRACT(YEAR FROM NOW())::INT) ORDER BY divisi,quarter); END; $function$


/* ========== get_kpi_calc_log_all() ========== */
CREATE OR REPLACE FUNCTION public.get_kpi_calc_log_all()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',nrp,'periode',periode,'indicator',indicator,'realisasi',realisasi,'target',target,'final_score',final_score) ORDER BY created_at DESC),'[]'::jsonb))
  FROM hr_kpi_calc_log LIMIT 50); END;
$function$


/* ========== get_kpi_config_all() ========== */
CREATE OR REPLACE FUNCTION public.get_kpi_config_all()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('position_code',position_code,'indicator',indicator,'target_value',target_value,'uom',uom,'weight',weight,'formula_type',formula_type)),'[]'::jsonb))
  FROM hr_kpi_config); END;
$function$


/* ========== get_legal_documents() ========== */
CREATE OR REPLACE FUNCTION public.get_legal_documents()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'type',doc_type,'title',title,'status',status)),'[]'::jsonb))
FROM legal_documents ORDER BY created_at DESC LIMIT 20); END; $function$


/* ========== get_my_consents(p_nrp text) ========== */
CREATE OR REPLACE FUNCTION public.get_my_consents(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE v_caller TEXT;
BEGIN
  v_caller := authz_current_nrp();
  IF p_nrp != v_caller THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak');
  END IF;
  RETURN (SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
    jsonb_build_object('type', consent_type, 'given', consent_given,
      'version', consent_version, 'revoked_at', revoked_at, 'created_at', created_at)
  ), '[]'::jsonb)) FROM user_consents WHERE nrp = p_nrp);
END;
$function$


/* ========== get_my_okrs(p_nrp text) ========== */
CREATE OR REPLACE FUNCTION public.get_my_okrs(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',o.id,'objective',o.objective,'status',o.status,'periode',o.periode,
    'key_results',(SELECT COALESCE(jsonb_agg(jsonb_build_object('id',r.id,'kr',r.key_result,'target',r.target_val,'actual',r.actual_val,'unit',r.unit,'pct',CASE WHEN r.target_val>0 THEN ROUND(r.actual_val/r.target_val*100,0) ELSE 0 END)),'[]'::jsonb) FROM hr_okr_results r WHERE r.okr_id=o.id)
  ) ORDER BY o.created_at DESC),'[]'::jsonb))
FROM hr_okrs o WHERE o.nrp=p_nrp); END;
$function$


/* ========== get_my_tasks(p_nrp text) ========== */
CREATE OR REPLACE FUNCTION public.get_my_tasks(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'title',title,'description',description,'status',status,'priority',priority,'due_date',due_date,'assigner_nrp',assigner_nrp)
  ORDER BY CASE priority WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END, due_date ASC),'[]'::jsonb))
FROM hr_task_board WHERE nrp=p_nrp); END;
$function$


/* ========== get_narrative(p_nrp text) ========== */
CREATE OR REPLACE FUNCTION public.get_narrative(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE v_kpi NUMERIC; v_att NUMERIC; v_nama TEXT; v_narasi TEXT;
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
END; $function$


/* ========== get_offboarding_checklist(p_nrp text) ========== */
CREATE OR REPLACE FUNCTION public.get_offboarding_checklist(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'item',item_name,'status',status,'checked_by',checked_by)),'[]'::jsonb))
FROM offboarding_checklist WHERE nrp=p_nrp); END; $function$


/* ========== get_realtime_alerts() ========== */
CREATE OR REPLACE FUNCTION public.get_realtime_alerts()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'type',task_type,'title',title,'priority',priority,'status',status,'created_at',created_at)),'[]'::jsonb))
FROM hr_ai_tasks WHERE priority='HIGH' AND status='ACTIVE' ORDER BY created_at DESC LIMIT 10); END; $function$


/* ========== get_realtime_notifications(p_nrp text, p_since timestamp with time zone) ========== */
CREATE OR REPLACE FUNCTION public.get_realtime_notifications(p_nrp text, p_since timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'category',category,'title',title,'message',message,'created_at',created_at) ORDER BY created_at DESC),'[]'::jsonb))
  FROM hr_notifications WHERE nrp=p_nrp AND created_at > COALESCE(p_since, NOW() - INTERVAL '1 hour') LIMIT 10); END;
$function$


/* ========== get_referrals(p_nrp text) ========== */
CREATE OR REPLACE FUNCTION public.get_referrals(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('candidate',candidate_name,'position',position,'status',status,'bonus_paid',bonus_paid)),'[]'::jsonb))
FROM referrals WHERE nrp=p_nrp); END; $function$


/* ========== get_salary_adjustments() ========== */
CREATE OR REPLACE FUNCTION public.get_salary_adjustments()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',s.nrp,'nama',e.nama,'current',s.current_salary,'recommended',s.recommended_salary,'pct',s.increase_pct,'status',s.status)),'[]'::jsonb))
FROM salary_adjustments s LEFT JOIN employees_master e ON e.nrp=s.nrp); END; $function$


/* ========== get_shift_swaps(p_nrp text) ========== */
CREATE OR REPLACE FUNCTION public.get_shift_swaps(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'requester',requester_nrp,'target',target_nrp,'req_date',request_date,'target_date',target_date,'status',status)
  ORDER BY created_at DESC),'[]'::jsonb))
FROM hr_shift_swaps WHERE requester_nrp=p_nrp OR target_nrp=p_nrp); END;
$function$


/* ========== get_survey_results(p_survey_id integer) ========== */
CREATE OR REPLACE FUNCTION public.get_survey_results(p_survey_id integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE v_total INT; v_promoter INT; v_detractor INT; v_enps NUMERIC;
BEGIN
  SELECT COUNT(*),COUNT(*) FILTER(WHERE score>=9),COUNT(*) FILTER(WHERE score<=6) INTO v_total,v_promoter,v_detractor FROM hr_survey_responses WHERE survey_id=p_survey_id;
  v_enps := CASE WHEN v_total>0 THEN ROUND((v_promoter::NUMERIC/v_total - v_detractor::NUMERIC/v_total)*100,0) ELSE 0 END;
  RETURN jsonb_build_object('ok',true,'total',v_total,'promoter',v_promoter,'detractor',v_detractor,'enps',v_enps); END;
$function$


/* ========== get_team_narrative(p_nrp text) ========== */
CREATE OR REPLACE FUNCTION public.get_team_narrative(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE v_kpi NUMERIC; v_att NUMERIC; v_nama TEXT; v_narasi TEXT;
BEGIN
  SELECT ROUND(AVG(p.kpi_score),1) INTO v_kpi FROM hr_performance p
    JOIN hr_org o ON o.nrp=p.nrp WHERE o.atasan_nrp=p_nrp AND p.periode=(SELECT MAX(periode) FROM hr_performance);
  SELECT ROUND(COUNT(*) FILTER(WHERE a.status_hadir='Hadir')::NUMERIC/NULLIF(COUNT(*),0)*100,1) INTO v_att
    FROM hr_attendance a JOIN hr_org o ON o.nrp=a.nrp WHERE o.atasan_nrp=p_nrp AND a.date>=date_trunc('month',NOW());
  SELECT nama INTO v_nama FROM employees_master WHERE nrp=p_nrp;
  v_narasi := 'Ringkasan tim '||COALESCE(v_nama,'Manager')||'. ';
  v_narasi := v_narasi || 'Avg KPI tim: '||COALESCE(v_kpi,0)||'. ';
  v_narasi := v_narasi || 'Kehadiran tim: '||COALESCE(v_att,100)||'%.';
  RETURN jsonb_build_object('ok',true,'narrative',v_narasi,'avg_kpi',COALESCE(v_kpi,0),'attendance_pct',COALESCE(v_att,100)); END;
$function$


/* ========== get_timesheets(p_nrp text) ========== */
CREATE OR REPLACE FUNCTION public.get_timesheets(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('work_date',work_date,'clock_in',clock_in,'clock_out',clock_out,'total_hours',total_hours)),'[]'::jsonb))
FROM timesheets WHERE nrp=p_nrp ORDER BY work_date DESC LIMIT 14); END; $function$


/* ========== get_travel_requests(p_nrp text) ========== */
CREATE OR REPLACE FUNCTION public.get_travel_requests(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'destination',destination,'purpose',purpose,'start_date',start_date,'end_date',end_date,'status',status,'per_diem',per_diem)),'[]'::jsonb))
FROM travel_requests WHERE p_nrp IS NULL OR nrp=p_nrp ORDER BY created_at DESC LIMIT 20); END; $function$


/* ========== get_turnover_prediction() ========== */
CREATE OR REPLACE FUNCTION public.get_turnover_prediction()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',e.nrp,'nama',e.nama,'divisi',e.divisi,
    'risk_score',GREATEST(100-COALESCE(p.kpi_score,50)-COALESCE(t.days_present,25)*2,0),
    'factors',jsonb_build_array(CASE WHEN COALESCE(p.kpi_score,100)<70 THEN 'KPI rendah' ELSE 'OK' END,
      CASE WHEN COALESCE(t.days_present,25)<20 THEN 'Absensi rendah' ELSE 'OK' END))
  ORDER BY GREATEST(100-COALESCE(p.kpi_score,50)-COALESCE(t.days_present,25)*2,0) DESC),'[]'::jsonb))
FROM employees_master e
LEFT JOIN hr_performance p ON p.nrp=e.nrp AND p.period=(SELECT MAX(period) FROM hr_performance)
LEFT JOIN (SELECT nrp,COUNT(*) as days_present FROM hr_attendance WHERE status_hadir='Hadir' AND date>=date_trunc('month',NOW()) GROUP BY nrp) t ON t.nrp=e.nrp
WHERE e.status_kerja='PKWTT' LIMIT 10); END; $function$


/* ========== get_whistleblowers() ========== */
CREATE OR REPLACE FUNCTION public.get_whistleblowers()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'category',category,'status',status,'created_at',created_at)),'[]'::jsonb))
FROM whistleblowers ORDER BY created_at DESC); END; $function$


/* ========== get_worker_capability(p_nrp text) ========== */
CREATE OR REPLACE FUNCTION public.get_worker_capability(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('kompetensi',kompetensi,'level_sekarang',level_sekarang,'level_target',level_target,'gap',gap,'is_mandatory',is_mandatory)),'[]'::jsonb))
FROM hr_capability WHERE nrp=p_nrp); END; $function$


/* ========== get_worker_exit(p_nrp text) ========== */
CREATE OR REPLACE FUNCTION public.get_worker_exit(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('resign_date',resign_date,'last_work_date',last_work_date,'clearance_status',clearance_status)),'[]'::jsonb))
FROM hr_exit_clearance WHERE nrp=p_nrp); END; $function$


/* ========== get_worker_narrative(p_nrp text) ========== */
CREATE OR REPLACE FUNCTION public.get_worker_narrative(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE v_emp RECORD; v_kpi RECORD; v_att RECORD; v_leave RECORD; v_narrative TEXT;
DECLARE v_sapaan TEXT; v_analisis TEXT; v_action TEXT; v_outcome TEXT; v_penutup TEXT;
DECLARE v_kpi_score INT; v_kpi_target INT; v_gap INT;
BEGIN
  SELECT * INTO v_emp FROM employees_master WHERE nrp=p_nrp;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'msg','Pekerja tidak ditemukan'); END IF;
  SELECT * INTO v_kpi FROM hr_performance WHERE nrp=p_nrp ORDER BY periode DESC LIMIT 1;
  SELECT COUNT(*) FILTER(WHERE status_hadir='Hadir') as hadir,COUNT(*) as total,
    COUNT(*) FILTER(WHERE status_hadir='Telat') as telat INTO v_att
  FROM hr_attendance WHERE nrp=p_nrp AND date>=date_trunc('month',NOW()) AND date<date_trunc('month',NOW())+INTERVAL '1 month';
  SELECT * INTO v_leave FROM hr_leave WHERE nrp=p_nrp ORDER BY tahun DESC LIMIT 1;

  v_kpi_score := COALESCE(v_kpi.kpi_score, 70)::INT;
  v_kpi_target := 85;
  v_gap := v_kpi_target - v_kpi_score;

  -- Sapaan
  v_sapaan := 'Halo ' || v_emp.nama || ', performa Anda pada periode ' || COALESCE(v_kpi.periode,'-') || ' telah kami evaluasi dengan semangat membangun.';

  -- Analisis
  IF v_gap > 0 THEN
    v_analisis := 'Skor KPI Anda saat ini ' || v_kpi_score || ' dari target ' || v_kpi_target || '. ';
    IF COALESCE(v_att.telat, 0) > 3 THEN
      v_analisis := v_analisis || 'Penurunan terutama disebabkan oleh keterlambatan sebanyak ' || v_att.telat || ' kali dalam sebulan terakhir. ';
    END IF;
    IF COALESCE(v_att.hadir, 0) < COALESCE(v_att.total, 0) * 0.9 THEN
      v_analisis := v_analisis || 'Tingkat kehadiran ' || ROUND(COALESCE(v_att.hadir,0)::NUMERIC/NULLIF(COALESCE(v_att.total,1),0)*100) || '% perlu ditingkatkan. ';
    END IF;
  ELSE
    v_analisis := 'Skor KPI Anda ' || v_kpi_score || ' sudah sesuai target. Pertahankan performa positif ini! ';
  END IF;

  -- Action plan
  IF v_gap > 0 THEN
    v_action := '1. Datang 15 menit lebih awal untuk menghindari keterlambatan. ';
    v_action := v_action || '2. Gunakan fitur Digital Leave Request di WOS jika berhalangan hadir. ';
    v_action := v_action || '3. Evaluasi mandiri setiap Jumat sore dengan mengecek dashboard kehadiran.';
  ELSE
    v_action := '1. Pertahankan konsistensi kehadiran tepat waktu. ';
    v_action := v_action || '2. Ikuti training lanjutan untuk meningkatkan skill. ';
    v_action := v_action || '3. Bantu rekan tim yang membutuhkan bimbingan.';
  END IF;

  -- Outcome
  IF v_gap > 0 THEN
    v_outcome := 'Jika konsisten selama 1 bulan, skor KPI dipastikan naik ke ' || v_kpi_target || '+. Peluang bonus dan promosi akan terbuka.';
  ELSE
    v_outcome := 'Dengan performa ini, Anda berpeluang menjadi High Performer dan mendapatkan reward tahunan.';
  END IF;

  -- Penutup
  v_penutup := 'Tim HRD siap mendukung. Silakan jadwalkan sesi coaching jika perlu.';

  RETURN jsonb_build_object('ok',true,
    'nrp',p_nrp,'nama',v_emp.nama,'period',COALESCE(v_kpi.periode,'-'),
    'kpi_score',v_kpi_score,'kpi_target',v_kpi_target,'gap',v_gap,
    'sapaan',v_sapaan,'analisis',v_analisis,'action_plan',v_action,'outcome',v_outcome,'penutup',v_penutup,
    'data_source_mode',CASE WHEN v_kpi_score > 0 THEN 'live' ELSE 'dummy' END); END;
$function$


/* ========== get_worker_payroll_secure(p_nrp text) ========== */
CREATE OR REPLACE FUNCTION public.get_worker_payroll_secure(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_caller TEXT;
  v_role TEXT;
BEGIN
  -- Get caller NRP from JWT or session
  v_caller := COALESCE(
    current_setting('request.jwt.claims', true)::json->>'nrp',
    ''
  );
  
  -- Get caller role
  SELECT role INTO v_role FROM user_roles WHERE nrp = v_caller LIMIT 1;
  
  -- Self-view: show full salary
  IF v_caller = p_nrp OR v_role IN ('admin_pusat', 'admin_hrd', 'admin_finance', 'manager') THEN
    RETURN COALESCE((
      SELECT jsonb_build_object('ok', true, 'data', jsonb_agg(
        jsonb_build_object(
          'periode', periode,
          'base_salary', base_salary,
          'allowance', allowance,
          'deduction', deduction,
          'overtime_pay', overtime_pay,
          'bonus', bonus,
          'net_salary', net_salary,
          'created_at', created_at
        )
      ))
      FROM hr_payroll WHERE nrp = p_nrp
      ORDER BY created_at DESC
    ), jsonb_build_object('ok', true, 'data', '[]'::jsonb));
  ELSE
    -- Masked view for unauthorized users
    RETURN COALESCE((
      SELECT jsonb_build_object('ok', true, 'data', jsonb_agg(
        jsonb_build_object(
          'periode', periode,
          'base_salary', 0,
          'allowance', 0,
          'deduction', 0,
          'overtime_pay', 0,
          'bonus', 0,
          'net_salary', 0,
          'created_at', created_at
        )
      ))
      FROM hr_payroll WHERE nrp = p_nrp
      ORDER BY created_at DESC
    ), jsonb_build_object('ok', true, 'data', '[]'::jsonb));
  END IF;
END;
$function$


/* ========== get_worker_relations(p_nrp text) ========== */
CREATE OR REPLACE FUNCTION public.get_worker_relations(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('type',type,'related_nrp',related_nrp,'notes',notes)),'[]'::jsonb))
FROM hr_relations WHERE nrp=p_nrp); END; $function$


/* ========== grant_consent(p_nrp text, p_type text, p_given boolean) ========== */
CREATE OR REPLACE FUNCTION public.grant_consent(p_nrp text, p_type text, p_given boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE v_caller TEXT;
BEGIN
  v_caller := authz_current_nrp();
  IF p_nrp != v_caller THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Hanya bisa ubah consent sendiri');
  END IF;
  INSERT INTO user_consents (nrp, consent_type, consent_given, created_at)
  VALUES (p_nrp, p_type, p_given, NOW())
  ON CONFLICT (nrp, consent_type) DO UPDATE SET
    consent_given = EXCLUDED.consent_given,
    revoked_at = CASE WHEN NOT EXCLUDED.consent_given THEN NOW() ELSE NULL END,
    created_at = NOW();
  INSERT INTO audit_log (action, result, message, created_at)
  VALUES ('CONSENT_' || CASE WHEN p_given THEN 'GRANT' ELSE 'REVOKE' END,
    'INFO', jsonb_build_object('nrp', p_nrp, 'type', p_type, 'given', p_given)::text, NOW());
  RETURN jsonb_build_object('ok', true, 'msg', 'Consent updated');
END;
$function$


/* ========== refresh_all_materialized_views() ========== */
CREATE OR REPLACE FUNCTION public.refresh_all_materialized_views()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$ DECLARE
  v_count INT := 0; v_start TIMESTAMPTZ := clock_timestamp();
BEGIN
  PERFORM refresh_mv_admin_summary(); v_count := v_count + 1;
  PERFORM refresh_mv_team_kpi(); v_count := v_count + 1;
  PERFORM refresh_mv_payroll_monthly(); v_count := v_count + 1;
  PERFORM refresh_mv_attendance_daily(); v_count := v_count + 1;
  PERFORM refresh_mv_flight_risk(); v_count := v_count + 1;
  RETURN jsonb_build_object('ok', true, 'refreshed', v_count,
    'elapsed_ms', EXTRACT(MILLISECONDS FROM clock_timestamp() - v_start)::INT);
END; $function$


/* ========== refresh_mv_admin_summary() ========== */
CREATE OR REPLACE FUNCTION public.refresh_mv_admin_summary()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN REFRESH MATERIALIZED VIEW CONCURRENTLY mv_admin_summary; END;
$function$


/* ========== refresh_mv_attendance_daily() ========== */
CREATE OR REPLACE FUNCTION public.refresh_mv_attendance_daily()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN REFRESH MATERIALIZED VIEW CONCURRENTLY mv_attendance_daily; END;
$function$


/* ========== refresh_mv_flight_risk() ========== */
CREATE OR REPLACE FUNCTION public.refresh_mv_flight_risk()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN REFRESH MATERIALIZED VIEW CONCURRENTLY mv_flight_risk; END;
$function$


/* ========== refresh_mv_payroll_monthly() ========== */
CREATE OR REPLACE FUNCTION public.refresh_mv_payroll_monthly()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN REFRESH MATERIALIZED VIEW CONCURRENTLY mv_payroll_monthly; END;
$function$


/* ========== refresh_mv_team_kpi() ========== */
CREATE OR REPLACE FUNCTION public.refresh_mv_team_kpi()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN REFRESH MATERIALIZED VIEW CONCURRENTLY mv_team_kpi; END;
$function$


/* ========== request_shift_swap(p_requester text, p_target text, p_req_date date, p_target_date date) ========== */
CREATE OR REPLACE FUNCTION public.request_shift_swap(p_requester text, p_target text, p_req_date date, p_target_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN INSERT INTO hr_shift_swaps(requester_nrp,target_nrp,request_date,target_date) VALUES(p_requester,p_target,p_req_date,p_target_date);
RETURN jsonb_build_object('ok',true,'msg','Swap requested'); END;
$function$


/* ========== rls_auto_enable() ========== */
CREATE OR REPLACE FUNCTION public.rls_auto_enable()
 RETURNS event_trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$function$


/* ========== run_simulation(p_turnover_change numeric) ========== */
CREATE OR REPLACE FUNCTION public.run_simulation(p_turnover_change numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
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
END; $function$


/* ========== set_cache(p_key text, p_data jsonb, p_ttl integer) ========== */
CREATE OR REPLACE FUNCTION public.set_cache(p_key text, p_data jsonb, p_ttl integer DEFAULT 300)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$ BEGIN
  INSERT INTO dashboard_cache (cache_key, cache_data, ttl_seconds, cached_at)
  VALUES (p_key, p_data, p_ttl, NOW())
  ON CONFLICT (cache_key) DO UPDATE SET cache_data = EXCLUDED.cache_data, cached_at = NOW(), ttl_seconds = EXCLUDED.ttl_seconds, hit_count = 0;
END; $function$


/* ========== submit_referral(p_nrp text, p_name text, p_email text, p_position text) ========== */
CREATE OR REPLACE FUNCTION public.submit_referral(p_nrp text, p_name text, p_email text, p_position text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN INSERT INTO referrals(id,referrer_nrp,candidate_name,candidate_email,position) VALUES('REF'||encode(gen_random_bytes(4),'hex'),p_nrp,p_name,p_email,p_position);
RETURN jsonb_build_object('ok',true,'msg','Referral dikirim. Bonus Rp 1.000.000 jika kandidat hire & lulus probation.'); END; $function$


/* ========== submit_survey(p_survey_id integer, p_nrp text, p_answers jsonb, p_score integer) ========== */
CREATE OR REPLACE FUNCTION public.submit_survey(p_survey_id integer, p_nrp text, p_answers jsonb, p_score integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN INSERT INTO hr_survey_responses(survey_id,nrp,answers,score) VALUES(p_survey_id,p_nrp,p_answers,p_score);
RETURN jsonb_build_object('ok',true,'msg','Survey submitted'); END;
$function$


/* ========== submit_survey_response(p_survey_id text, p_nrp text, p_score integer, p_response text) ========== */
CREATE OR REPLACE FUNCTION public.submit_survey_response(p_survey_id text, p_nrp text, p_score integer, p_response text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN INSERT INTO survey_responses(survey_id,nrp,score,response_json) VALUES(p_survey_id,p_nrp,p_score,p_response);
RETURN jsonb_build_object('ok',true,'msg','Jawaban tersimpan.'); END; $function$


/* ========== submit_whistleblower(p_category text, p_desc text) ========== */
CREATE OR REPLACE FUNCTION public.submit_whistleblower(p_category text, p_desc text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN INSERT INTO whistleblowers(id,category,description) VALUES('WB'||encode(gen_random_bytes(4),'hex'),p_category,p_desc);
RETURN jsonb_build_object('ok',true,'msg','Laporan terkirim secara anonim.'); END; $function$


/* ========== tier_msg_(p_feature text, p_min_tier text) ========== */
CREATE OR REPLACE FUNCTION public.tier_msg_(p_feature text, p_min_tier text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN 'Fitur "' || p_feature || '" memerlukan paket ' || p_min_tier || ' atau level lebih tinggi.'; END;
$function$


/* ========== update_ai_task_status(p_id text, p_status text) ========== */
CREATE OR REPLACE FUNCTION public.update_ai_task_status(p_id text, p_status text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN UPDATE hr_ai_tasks SET status=p_status WHERE id=p_id;
IF FOUND THEN RETURN jsonb_build_object('ok',true,'msg','Status diperbarui.'); END IF;
RETURN jsonb_build_object('ok',false,'msg','Tidak ditemukan.'); END; $function$


/* ========== verify_mfa(p_nrp text, p_code text) ========== */
CREATE OR REPLACE FUNCTION public.verify_mfa(p_nrp text, p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_mfa RECORD;
  v_hash TEXT;
BEGIN
  -- Hash the code
  v_hash := encode(digest(p_code, 'sha256'), 'hex');
  
  -- Find matching MFA record
  SELECT * INTO v_mfa FROM mfa_store 
  WHERE nrp = p_nrp 
    AND code_hash = v_hash 
    AND enabled = true 
    AND expires_at > NOW();
  
  IF v_mfa IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Kode MFA tidak valid atau sudah kadaluarsa');
  END IF;
  
  -- Mark as used
  UPDATE mfa_store SET used = true WHERE id = v_mfa.id;
  
  RETURN jsonb_build_object('ok', true, 'msg', 'Verifikasi berhasil');
END;
$function$


/* ========== worker_change_password(p_nrp text, p_old text, p_new text) ========== */
CREATE OR REPLACE FUNCTION public.worker_change_password(p_nrp text, p_old text, p_new text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
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
END; $function$


/* ========== worker_update_profile(p_nrp text, p_email text, p_no_hp text, p_alamat text) ========== */
CREATE OR REPLACE FUNCTION public.worker_update_profile(p_nrp text, p_email text, p_no_hp text, p_alamat text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  UPDATE employees_master SET email=COALESCE(p_email,email), no_hp=COALESCE(p_no_hp,no_hp),
    alamat=COALESCE(p_alamat,alamat), updated_at=NOW() WHERE nrp=p_nrp;
  RETURN jsonb_build_object('ok',true,'msg','Profil diperbarui.');
END; $function$
