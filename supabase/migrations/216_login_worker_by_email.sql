-- 216: login_worker_by_email — Email+Password worker login (Login Refactor step 1)
-- New RPC: login_worker_by_email(p_email TEXT, p_password TEXT)
-- Delegates to existing login_worker() after resolving NRP+NIK from email.
-- Same return shape as login_worker, plus NIK (needed by provisionWorkerAuth).
-- Lockout: uses email as identifier with attempt_type='worker'.

CREATE OR REPLACE FUNCTION login_worker_by_email(p_email TEXT, p_password TEXT)
RETURNS JSONB AS $$
DECLARE
  v_nrp TEXT;
  v_nik TEXT;
  v_emp RECORD;
  v_pwd RECORD;
  v_role RECORD;
  v_site RECORD;
  v_salt TEXT;
  v_hash TEXT;
  v_token TEXT;
  v_reset_required BOOLEAN := FALSE;
  v_failed_count INT;
  v_last_attempt TIMESTAMPTZ;
  v_remaining_seconds INT;
BEGIN
  -- ── Input validation ──
  IF p_email IS NULL OR POSITION('@' IN p_email) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Format email tidak valid');
  END IF;
  IF p_password IS NULL OR LENGTH(p_password) < 6 THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Password minimal 6 karakter');
  END IF;

  -- ── Resolve NRP + NIK from email ──
  SELECT e.nrp, e.nik INTO v_nrp, v_nik
  FROM employees_core e
  WHERE lower(trim(e.email)) = lower(trim(p_email))
  LIMIT 1;

  IF v_nrp IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Email tidak terdaftar');
  END IF;
  IF v_nik IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'NIK belum terdaftar. Hubungi admin.');
  END IF;

  -- ── Lockout check (by email) ──
  SELECT COUNT(*), MAX(created_at)
  INTO v_failed_count, v_last_attempt
  FROM login_attempts
  WHERE identifier = p_email
    AND attempt_type = 'worker'
    AND success = FALSE
    AND created_at > NOW() - INTERVAL '15 minutes';

  IF v_failed_count >= 5 THEN
    v_remaining_seconds := EXTRACT(EPOCH FROM (
      (v_last_attempt + INTERVAL '15 minutes') - NOW()
    ))::INT;
    IF v_remaining_seconds > 0 THEN
      INSERT INTO login_attempts (identifier, attempt_type, success, ip_address)
      VALUES (p_email, 'worker', FALSE, 'LOCKOUT_TRIGGERED');
      RETURN jsonb_build_object('ok', false, 'msg', 'Terlalu banyak percobaan. Coba lagi dalam ' ||
                             (v_remaining_seconds / 60)::INT || ' menit.');
    END IF;
  END IF;

  -- ── Employee lookup (same as login_worker) ──
  SELECT * INTO v_emp FROM employees_master WHERE nrp = v_nrp AND nik = v_nik;
  IF v_emp IS NULL THEN
    INSERT INTO login_attempts (identifier, attempt_type, success, ip_address)
    VALUES (p_email, 'worker', FALSE, NULL);
    RETURN jsonb_build_object('ok', false, 'msg', 'Data karyawan tidak ditemukan');
  END IF;

  -- ── Password lookup + verify (same logic as login_worker) ──
  SELECT * INTO v_pwd FROM worker_passwords WHERE nrp = v_nrp AND is_active = true;
  IF v_pwd IS NULL THEN
    INSERT INTO login_attempts (identifier, attempt_type, success, ip_address)
    VALUES (p_email, 'worker', FALSE, NULL);
    RETURN jsonb_build_object('ok', false, 'msg', 'Akun tidak aktif');
  END IF;

  IF v_pwd.blocked_until IS NOT NULL AND v_pwd.blocked_until > NOW() THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akun diblokir sementara');
  END IF;

  IF v_pwd.password_hash LIKE '$2%' THEN
    IF crypt(p_password, v_pwd.password_hash) != v_pwd.password_hash THEN
      UPDATE worker_passwords SET attempts = attempts + 1,
        blocked_until = CASE WHEN attempts >= 4 THEN NOW() + INTERVAL '15 minutes' ELSE blocked_until END
      WHERE nrp = v_nrp;
      INSERT INTO login_attempts (identifier, attempt_type, success, ip_address)
      VALUES (p_email, 'worker', FALSE, NULL);
      RETURN jsonb_build_object('ok', false, 'msg', 'Password salah');
    END IF;
  ELSE
    v_salt := v_pwd.salt;
    v_hash := encode(digest(p_password || COALESCE(v_salt, ''), 'sha256'), 'hex');
    IF v_hash != v_pwd.password_hash THEN
      UPDATE worker_passwords SET attempts = attempts + 1,
        blocked_until = CASE WHEN attempts >= 4 THEN NOW() + INTERVAL '15 minutes' ELSE blocked_until END
      WHERE nrp = v_nrp;
      INSERT INTO login_attempts (identifier, attempt_type, success, ip_address)
      VALUES (p_email, 'worker', FALSE, NULL);
      RETURN jsonb_build_object('ok', false, 'msg', 'Password salah');
    END IF;
    UPDATE worker_passwords
    SET password_hash = crypt(p_password, gen_salt('bf')), salt = NULL, reset_required = FALSE
    WHERE nrp = v_nrp;
  END IF;

  -- ── Login success ──
  UPDATE worker_passwords SET attempts = 0, blocked_until = NULL WHERE nrp = v_nrp;
  SELECT reset_required INTO v_reset_required FROM worker_passwords WHERE nrp = v_nrp;
  SELECT * INTO v_role FROM user_roles WHERE nrp = v_nrp;
  SELECT s.* INTO v_site FROM sites s WHERE s.id = v_emp.site_id;

  v_token := encode(gen_random_bytes(32), 'hex');
  INSERT INTO session_tokens (session_token, nrp, type, expires_at, created_at)
  VALUES (v_token, v_nrp, 'worker', NOW() + INTERVAL '24 hours', NOW())
  ON CONFLICT (session_token) DO NOTHING;
  INSERT INTO login_attempts (identifier, attempt_type, success, ip_address, user_agent, created_at)
  VALUES (p_email, 'worker', true, NULL, NULL, NOW());

  RETURN jsonb_build_object(
    'ok', true,
    'nrp', v_emp.nrp,
    'nama', v_emp.nama,
    'nik', v_emp.nik,
    'divisi', v_emp.divisi,
    'posisi', v_emp.posisi,
    'role_level', COALESCE(v_role.role_level, 1),
    'role', COALESCE(v_role.role, 'worker'),
    'business_unit', COALESCE(v_emp.business_unit, 'HQ'),
    'token', v_token,
    'reset_required', COALESCE(v_reset_required, false),
    'expires_at', (NOW() + INTERVAL '24 hours')::text
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

GRANT EXECUTE ON FUNCTION login_worker_by_email(text, text) TO anon, authenticated;
