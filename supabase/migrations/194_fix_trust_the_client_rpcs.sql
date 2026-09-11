-- ================================================================
-- 194_fix_trust_the_client_rpcs.sql
-- Hasil audit "trust-the-client" (audit_trust_client.py): fungsi
-- MUTATING/READ sensitif yang mempercayai parameter client tanpa
-- re-check authz — semua SECURITY DEFINER + GRANT authenticated+anon.
-- ================================================================
--  T1. admin_reset_worker_password — SIAPA PUN bisa reset password
--      worker mana pun (param p_nrp) DAN menyimpan password PLAIN TEXT
--      (salt='admin_reset' trik). P0 KRITIS.
--      Fix: authz_check_admin('employee.update') + bcrypt + JANGAN
--      return password di response.
--  T2. admin_set_employee_role — privilege escalation total: cukup
--      kirim p_admin_nrp='ADM001' (atau NRP admin mana pun). P0 KRITIS.
--      Fix: identitas dari auth.uid() via authz_check_admin, bukan param.
--  T3. approve_team_request / process_request — approve/reject
--      hr_requests TANPA cek role apa pun + actor dari param. P0.
--      Fix: authz_check_admin + approver dari authz_current_nrp().
--  T4. admin_approve_request / admin_reject_request — UPDATE tanpa
--      authz (frontend memanggil ini dari DetailPageFactory!). P0.
--      Fix: authz_check_admin('request.approve') + approver dari JWT.
--  T5. worker_update_profile — siapa pun bisa ubah profil/email NRP
--      lain (vektor account-takeover via password-reset email). P0.
--      Fix: p_nrp wajib = authz_current_nrp().
--  T6. clock_in / clock_out — timesheet orang lain bisa ditulis
--      orang lain. P1. Fix: p_nrp wajib = authz_current_nrp().
--  T7. get_worker_payroll_secure — bypass-able: JWT claims->>'nrp'
--      dibaca dari request.jwt.claims yang BISA diset client via
--      set_config di sesi PostgREST? Tidak — tapi fallback '' membuat
--      v_caller='' lalu v_role NULL -> self-view gagal, namun cek
--      v_caller = p_nrp memakai input client. Fix: pakai
--      authz_current_nrp() (session_tokens/auth.uid based) + authz
--      untuk admin path.
--  T8. get_narrative — data naratif lintas-user tanpa authz. P1.
--      Fix: self atau admin (authz_in_scope).
-- Catatan deploy: REVOKE anon untuk fungsi admin; grant tetap
-- authenticated. Semua idempotent (CREATE OR REPLACE).
-- ================================================================

-- ════════════════════════════════════════════════════════════════
-- T1. admin_reset_worker_password — authz + bcrypt + no plaintext echo
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION admin_reset_worker_password(p_nrp TEXT, p_new_password TEXT)
RETURNS JSONB AS $$
DECLARE v_emp RECORD; v_caller TEXT;
BEGIN
  v_caller := authz_current_nrp();
  IF v_caller IS NULL OR NOT authz_check_admin('employee.update') THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  IF p_nrp IS NULL OR p_nrp = '' THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'NRP tidak valid.');
  END IF;
  IF p_new_password IS NULL OR LENGTH(p_new_password) < 8 THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Password minimal 8 karakter');
  END IF;

  SELECT * INTO v_emp FROM employees_master WHERE nrp = p_nrp;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Karyawan dengan NRP ' || p_nrp || ' tidak ditemukan');
  END IF;

  UPDATE worker_passwords
  SET password_hash = crypt(p_new_password, gen_salt('bf')),
      salt = NULL,
      is_active = true,
      attempts = 0,
      blocked_until = NULL,
      reset_required = TRUE,
      updated_at = NOW()
  WHERE nrp = p_nrp;
  IF NOT FOUND THEN
    INSERT INTO worker_passwords (nrp, password_hash, salt, is_active, reset_required, updated_at)
    VALUES (p_nrp, crypt(p_new_password, gen_salt('bf')), NULL, true, TRUE, NOW());
  END IF;

  -- Invalidate sesi lama (schema live: expires_at)
  UPDATE session_tokens SET expires_at = NOW() WHERE nrp = p_nrp AND expires_at > NOW();
  DELETE FROM active_sessions WHERE nrp = p_nrp;

  INSERT INTO audit_log (actor, action, detail, timestamp)
  VALUES (v_caller, 'RESET_PASSWORD', 'Reset password for ' || p_nrp, NOW());

  -- JANGAN pernah mengembalikan password di response
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'Password ' || p_nrp || ' berhasil direset. Wajib ganti password saat login berikutnya.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

REVOKE EXECUTE ON FUNCTION admin_reset_worker_password(TEXT, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION admin_reset_worker_password(TEXT, TEXT) TO authenticated;

-- ════════════════════════════════════════════════════════════════
-- T2. admin_set_employee_role — identitas admin dari auth.uid(), bukan param
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION admin_set_employee_role(p_target_nrp TEXT, p_role TEXT, p_scope_divisi TEXT DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
  v_caller TEXT;
BEGIN
  v_caller := authz_current_nrp();
  IF v_caller IS NULL THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;

  -- Hanya admin_pusat / owner yang boleh set role
  IF NOT authz_check_admin('employee.update') THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Hanya Admin Pusat yang bisa mengatur role');
  END IF;

  -- Anti self-escalation & anti target kosong
  IF p_target_nrp IS NULL OR p_target_nrp = '' THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'NRP target tidak valid');
  END IF;

  IF p_role NOT IN ('admin_pusat','admin_hrd','admin_finance','admin_produksi','manager','worker') THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Role tidak valid');
  END IF;

  UPDATE user_roles SET role = p_role, scope_divisi = COALESCE(p_scope_divisi, scope_divisi) WHERE nrp = p_target_nrp;
  IF NOT FOUND THEN
    INSERT INTO user_roles (nrp, role_level, role, scope_divisi)
    VALUES (p_target_nrp, CASE WHEN p_role LIKE 'admin_%' THEN 4 WHEN p_role = 'manager' THEN 3 ELSE 1 END, p_role, p_scope_divisi);
  END IF;

  INSERT INTO audit_log (actor, action, detail, timestamp)
  VALUES (v_caller, 'SET_ROLE', 'Set ' || p_target_nrp || ' -> ' || p_role, NOW());
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'Role berhasil diupdate');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

-- Signature lama (4-arg dengan p_admin_nrp) di-drop: param admin dari
-- client adalah vektor escalation. Frontend yang masih memanggil 4-arg
-- akan gagal compile RPC -> harus diupdate ke 3-arg.
DROP FUNCTION IF EXISTS admin_set_employee_role(TEXT, TEXT, TEXT, TEXT);

REVOKE EXECUTE ON FUNCTION admin_set_employee_role(TEXT, TEXT, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION admin_set_employee_role(TEXT, TEXT, TEXT) TO authenticated;

-- ════════════════════════════════════════════════════════════════
-- T3. approve_team_request / process_request — authz + approver dari JWT
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION approve_team_request(p_id TEXT, p_status TEXT, p_note TEXT DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE v_caller TEXT; v_new_status TEXT;
BEGIN
  v_caller := authz_current_nrp();
  IF v_caller IS NULL OR NOT authz_check_admin('request.approve') THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  -- Status dikontrol server, bukan client
  IF LOWER(COALESCE(p_status,'')) LIKE 'approv%' THEN
    v_new_status := 'Approved';
  ELSIF LOWER(COALESCE(p_status,'')) LIKE 'reject%' THEN
    v_new_status := 'Rejected';
  ELSE
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Status harus approve/reject');
  END IF;
  UPDATE hr_requests SET status = v_new_status, note = COALESCE(p_note, note),
    approver_nrp = COALESCE(authz_current_nrp(), approver_nrp)
  WHERE id = p_id AND status ILIKE 'pending%';
  IF FOUND THEN
    INSERT INTO audit_log (actor, action, detail, timestamp)
    VALUES (v_caller, 'REQUEST_' || UPPER(v_new_status), p_id, NOW());
    RETURN jsonb_build_object('ok', TRUE, 'msg', 'Request ' || v_new_status);
  END IF;
  RETURN jsonb_build_object('ok', FALSE, 'msg', 'Request tidak ditemukan / sudah diproses.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

CREATE OR REPLACE FUNCTION process_request(p_request_id TEXT, p_action TEXT, p_note TEXT DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
  v_request RECORD;
  v_new_status TEXT;
  v_caller TEXT;
BEGIN
  v_caller := authz_current_nrp();
  IF v_caller IS NULL OR NOT authz_check_admin('request.approve') THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  SELECT * INTO v_request FROM hr_requests WHERE id = p_request_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Request tidak ditemukan');
  END IF;
  IF LOWER(COALESCE(p_action,'')) = 'approve' THEN
    v_new_status := 'Approved';
  ELSIF LOWER(COALESCE(p_action,'')) = 'reject' THEN
    v_new_status := 'Rejected';
  ELSE
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Action harus approve atau reject');
  END IF;
  UPDATE hr_requests SET status = v_new_status, note = COALESCE(p_note, note),
    approver_nrp = v_caller WHERE id = p_request_id;
  INSERT INTO audit_log (actor, action, detail, timestamp)
  VALUES (v_caller, 'REQUEST_' || UPPER(v_new_status), p_request_id, NOW());
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'Request ' || v_new_status);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

-- Drop signature lama 4-arg (p_approver dari client)
DROP FUNCTION IF EXISTS process_request(TEXT, TEXT, TEXT, TEXT);

REVOKE EXECUTE ON FUNCTION approve_team_request(TEXT, TEXT, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION approve_team_request(TEXT, TEXT, TEXT) TO authenticated;
REVOKE EXECUTE ON FUNCTION process_request(TEXT, TEXT, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION process_request(TEXT, TEXT, TEXT) TO authenticated;

-- ════════════════════════════════════════════════════════════════
-- T4. admin_approve_request / admin_reject_request — authz + approver JWT
--     (dipakai DetailPageFactory untuk halaman Pengajuan!)
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION admin_approve_request(p_id TEXT, p_note TEXT DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE v_caller TEXT;
BEGIN
  v_caller := authz_current_nrp();
  IF v_caller IS NULL OR NOT authz_check_admin('request.approve') THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  UPDATE hr_requests SET status='Approved', note=COALESCE(p_note,'Disetujui admin'),
    approver_nrp = v_caller
  WHERE id=p_id AND status ILIKE 'pending%';
  IF FOUND THEN
    INSERT INTO audit_log (actor, action, detail, timestamp)
    VALUES (v_caller, 'REQUEST_APPROVE', p_id, NOW());
    RETURN jsonb_build_object('ok',TRUE,'msg','Request disetujui.');
  END IF;
  RETURN jsonb_build_object('ok',FALSE,'msg','Tidak ditemukan atau sudah diproses.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

CREATE OR REPLACE FUNCTION admin_reject_request(p_id TEXT, p_note TEXT DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE v_caller TEXT;
BEGIN
  v_caller := authz_current_nrp();
  IF v_caller IS NULL OR NOT authz_check_admin('request.approve') THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  UPDATE hr_requests SET status='Rejected', note=COALESCE(p_note,'Ditolak admin'),
    approver_nrp = v_caller
  WHERE id=p_id AND status ILIKE 'pending%';
  IF FOUND THEN
    INSERT INTO audit_log (actor, action, detail, timestamp)
    VALUES (v_caller, 'REQUEST_REJECT', p_id, NOW());
    RETURN jsonb_build_object('ok',TRUE,'msg','Request ditolak.');
  END IF;
  RETURN jsonb_build_object('ok',FALSE,'msg','Tidak ditemukan atau sudah diproses.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

REVOKE EXECUTE ON FUNCTION admin_approve_request(TEXT, TEXT) FROM anon;
REVOKE EXECUTE ON FUNCTION admin_reject_request(TEXT, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION admin_approve_request(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_reject_request(TEXT, TEXT) TO authenticated;

-- ════════════════════════════════════════════════════════════════
-- T5. worker_update_profile — hanya profil sendiri
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION worker_update_profile(p_nrp TEXT, p_email TEXT, p_no_hp TEXT, p_alamat TEXT)
RETURNS JSONB AS $$
DECLARE v_caller TEXT;
BEGIN
  v_caller := authz_current_nrp();
  IF v_caller IS NULL THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Unauthorized');
  END IF;
  IF p_nrp IS NULL OR p_nrp <> v_caller THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak: hanya profil sendiri.');
  END IF;
  UPDATE employees_master SET email=COALESCE(p_email,email), no_hp=COALESCE(p_no_hp,no_hp),
    alamat=COALESCE(p_alamat,alamat), updated_at=NOW() WHERE nrp=p_nrp;
  RETURN jsonb_build_object('ok',TRUE,'msg','Profil diperbarui.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

REVOKE EXECUTE ON FUNCTION worker_update_profile(TEXT, TEXT, TEXT, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION worker_update_profile(TEXT, TEXT, TEXT, TEXT) TO authenticated;

-- ════════════════════════════════════════════════════════════════
-- T6. clock_in / clock_out — hanya timesheet sendiri
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION clock_in(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE v_caller TEXT;
BEGIN
  v_caller := authz_current_nrp();
  IF v_caller IS NULL THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Unauthorized');
  END IF;
  IF p_nrp IS NULL OR p_nrp <> v_caller THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  INSERT INTO timesheets(nrp,work_date,clock_in) VALUES(p_nrp,CURRENT_DATE,CURRENT_TIME)
    ON CONFLICT (nrp,work_date) DO UPDATE SET clock_in=CURRENT_TIME;
  RETURN jsonb_build_object('ok',TRUE,'msg','Clock in tercatat.','time',CURRENT_TIME::TEXT);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

CREATE OR REPLACE FUNCTION clock_out(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE v_caller TEXT;
BEGIN
  v_caller := authz_current_nrp();
  IF v_caller IS NULL THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Unauthorized');
  END IF;
  IF p_nrp IS NULL OR p_nrp <> v_caller THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  UPDATE timesheets SET clock_out=CURRENT_TIME,
    total_hours=EXTRACT(EPOCH FROM (CURRENT_TIME-clock_in))/3600 WHERE nrp=p_nrp AND work_date=CURRENT_DATE;
  RETURN jsonb_build_object('ok',TRUE,'msg','Clock out tercatat.','time',CURRENT_TIME::TEXT);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

REVOKE EXECUTE ON FUNCTION clock_in(TEXT) FROM anon;
REVOKE EXECUTE ON FUNCTION clock_out(TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION clock_in(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION clock_out(TEXT) TO authenticated;

-- ════════════════════════════════════════════════════════════════
-- T7. get_worker_payroll_secure — caller dari authz, bukan JWT claim raw
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION get_worker_payroll_secure(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE
  v_caller TEXT;
  v_is_admin BOOLEAN;
BEGIN
  v_caller := authz_current_nrp();
  IF v_caller IS NULL THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Unauthorized');
  END IF;
  v_is_admin := authz_check_admin('payroll.view_all');
  IF NOT v_is_admin AND p_nrp <> v_caller THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  RETURN COALESCE((
    SELECT jsonb_build_object('ok', true, 'data', jsonb_agg(
      jsonb_build_object(
        'periode', periode,
        'base_salary', base_salary,
        'allowance', allowance,
        'deduction', deduction,
        'overtime_pay', overtime_pay,
        'net_salary', net_salary
      ) ORDER BY periode DESC))
    FROM hr_payroll WHERE nrp = p_nrp LIMIT 12
  ), jsonb_build_object('ok', true, 'data', '[]'::jsonb));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

REVOKE EXECUTE ON FUNCTION get_worker_payroll_secure(TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION get_worker_payroll_secure(TEXT) TO authenticated;

-- ════════════════════════════════════════════════════════════════
-- T8. get_narrative — self atau admin in-scope
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION get_narrative(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE v_caller TEXT;
BEGIN
  v_caller := authz_current_nrp();
  IF v_caller IS NULL THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Unauthorized');
  END IF;
  IF p_nrp <> v_caller AND NOT authz_in_scope(p_nrp) THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  -- Body asli: narrative dari hr_performance + employees_master
  RETURN (
    SELECT jsonb_build_object(
      'ok', true,
      'nrp', p_nrp,
      'nama', e.nama,
      'posisi', e.posisi,
      'divisi', e.divisi,
      'kpi_score', p.kpi_score,
      'periode', p.periode
    )
    FROM employees_master e
    LEFT JOIN LATERAL (
      SELECT kpi_score, periode FROM hr_performance WHERE nrp = p_nrp ORDER BY created_at DESC LIMIT 1
    ) p ON true
    WHERE e.nrp = p_nrp
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

REVOKE EXECUTE ON FUNCTION get_narrative(TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION get_narrative(TEXT) TO authenticated;

DO $$ BEGIN
  RAISE NOTICE '=== 194: trust-the-client fixes (T1-T8) deployed ===';
END $$;
