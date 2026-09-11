-- ================================================================
-- 192_fix_auth_schema_drift.sql
-- Repair live auth functions broken by migration 171 regression
-- ================================================================
-- Migration 171_restore_db_only_functions.sql dipulihkan fungsi dari
-- dump LAMA yang referensia kolom yang TIDAK ADA di schema live:
--   session_tokens live: (session_token, nrp, type, expires_at, created_at)
--     -> fungsi lama pakai is_used/used_at/token_hash/ip_address/user_agent
--   login_attempts live: (identifier, attempt_type, success, ip_address,
--     user_agent, created_at) -> fungsi lama pakai nrp/attempted_at
--   otp_store live: (nrp PK, code_hash sha256, expiry, used, created_at)
--     -> fungsi lama pakai purpose/expires_at/id + hash bcrypt
--   worker_passwords.salt live: NOT NULL -> fungsi lama SET salt = NULL
-- Konsekuensi di live: login_worker, verify_worker_otp, worker_logout,
-- change_password, reset_password, generate_worker_otp(2-arg) semua
-- THROW "column does not exist" saat diexecute -> worker login/OTP/
-- logout/reset password total terkunci.
-- ================================================================
-- SEMUA definisi IDEMPOTENT (CREATE OR REPLACE / IF NOT EXISTS).
-- ================================================================

-- ════════════════════════════════════════════════════════════════
-- 0. Garantir salt nullable (bcrypt auto-upgrade SET salt = NULL)
-- ════════════════════════════════════════════════════════════════

ALTER TABLE worker_passwords ALTER COLUMN salt DROP NOT NULL;

-- Overload lama yang TIDAK dipakai frontend (frontend selalu 3-arg):
-- live punya login_worker(text,text) & generate_worker_otp(text,text)
-- sisa versi lama; drop supaya tidak ada jalur login/OTP tanpa NIK.
DROP FUNCTION IF EXISTS login_worker(TEXT, TEXT);
DROP FUNCTION IF EXISTS generate_worker_otp(TEXT, TEXT);

-- ════════════════════════════════════════════════════════════════
-- 1. login_worker(p_nrp, p_nik, p_password) — jalur login utama
--    FIX: deteksi bcrypt '$2%', schema session_tokens + login_attempts
--    live, keep reset_required/business_unit, auto-upgrade bcrypt.
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION login_worker(p_nrp TEXT, p_nik TEXT, p_password TEXT)
RETURNS JSONB AS $$
DECLARE
  v_emp RECORD; v_pwd RECORD; v_role RECORD; v_site RECORD;
  v_salt TEXT; v_hash TEXT; v_token TEXT; v_reset_required BOOLEAN := FALSE;
BEGIN
  IF p_nrp IS NULL OR LENGTH(p_nrp) < 3 OR LENGTH(p_nrp) > 20 THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Format NRP tidak valid');
  END IF;
  IF p_nik IS NULL OR LENGTH(p_nik) < 5 OR LENGTH(p_nik) > 20 THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Format NIK tidak valid');
  END IF;
  IF p_password IS NULL OR LENGTH(p_password) < 6 THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Password minimal 6 karakter');
  END IF;

  SELECT * INTO v_emp FROM employees_master WHERE nrp = p_nrp AND nik = p_nik;
  IF v_emp IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'NRP/NIK tidak ditemukan');
  END IF;

  SELECT * INTO v_pwd FROM worker_passwords WHERE nrp = p_nrp AND is_active = true;
  IF v_pwd IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akun tidak aktif');
  END IF;

  IF v_pwd.blocked_until IS NOT NULL AND v_pwd.blocked_until > NOW() THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akun diblokir sementara');
  END IF;

  -- bcrypt ($2a$/$2b$) vs sha256 (hex) — deteksi via prefix '$2'
  IF v_pwd.password_hash LIKE '$2%' THEN
    IF crypt(p_password, v_pwd.password_hash) != v_pwd.password_hash THEN
      UPDATE worker_passwords SET attempts = attempts + 1,
        blocked_until = CASE WHEN attempts >= 4 THEN NOW() + INTERVAL '15 minutes' ELSE blocked_until END
      WHERE nrp = p_nrp;
      RETURN jsonb_build_object('ok', false, 'msg', 'Password salah');
    END IF;
  ELSE
    v_salt := v_pwd.salt;
    v_hash := encode(digest(p_password || COALESCE(v_salt, ''), 'sha256'), 'hex');
    IF v_hash != v_pwd.password_hash THEN
      UPDATE worker_passwords SET attempts = attempts + 1,
        blocked_until = CASE WHEN attempts >= 4 THEN NOW() + INTERVAL '15 minutes' ELSE blocked_until END
      WHERE nrp = p_nrp;
      RETURN jsonb_build_object('ok', false, 'msg', 'Password salah');
    END IF;
    -- Auto-upgrade ke bcrypt saat login sukses (hanya untuk akun sha256)
    UPDATE worker_passwords
    SET password_hash = crypt(p_password, gen_salt('bf')), salt = NULL, reset_required = FALSE
    WHERE nrp = p_nrp;
  END IF;

  UPDATE worker_passwords SET attempts = 0, blocked_until = NULL WHERE nrp = p_nrp;
  SELECT reset_required INTO v_reset_required FROM worker_passwords WHERE nrp = p_nrp;
  SELECT * INTO v_role FROM user_roles WHERE nrp = p_nrp;
  SELECT s.* INTO v_site FROM sites s WHERE s.id = v_emp.site_id;

  v_token := encode(gen_random_bytes(32), 'hex');
  INSERT INTO session_tokens (session_token, nrp, type, expires_at, created_at)
  VALUES (v_token, p_nrp, 'worker', NOW() + INTERVAL '24 hours', NOW())
  ON CONFLICT (session_token) DO NOTHING;
  INSERT INTO login_attempts (identifier, attempt_type, success, ip_address, user_agent, created_at)
  VALUES (p_nrp, 'worker', true, NULL, NULL, NOW());

  RETURN jsonb_build_object(
    'ok', true, 'nrp', v_emp.nrp, 'nama', v_emp.nama, 'nik', v_emp.nik,
    'divisi', v_emp.divisi, 'posisi', v_emp.posisi,
    'role_level', COALESCE(v_role.role_level, 1),
    'role', COALESCE(v_role.role, 'worker'),
    'business_unit', COALESCE(v_emp.business_unit, 'HQ'),
    'token', v_token, 'reset_required', COALESCE(v_reset_required, false),
    'expires_at', (NOW() + INTERVAL '24 hours')::text
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

GRANT EXECUTE ON FUNCTION login_worker(text, text, text) TO anon, authenticated;

-- ════════════════════════════════════════════════════════════════
-- 2. generate_worker_otp(p_nrp, p_nik) — schema otp_store live
--    (code_hash sha256, expiry, used — TIDAK purpose/expires_at/id)
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION generate_worker_otp(p_nrp TEXT, p_nik TEXT)
RETURNS JSONB AS $$
DECLARE v_code TEXT; v_emp RECORD; v_att RECORD;
BEGIN
  SELECT * INTO v_emp FROM employees_master WHERE nrp = p_nrp AND nik = p_nik AND is_active = true;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'NRP/NIK tidak ditemukan');
  END IF;

  -- Rate limit: maks 3 request / 10 menit
  SELECT * INTO v_att FROM otp_attempts WHERE nrp = p_nrp;
  IF v_att.request_count IS NOT NULL AND v_att.request_window_start > NOW() - INTERVAL '10 minutes'
     AND v_att.request_count >= 3 THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Terlalu banyak request OTP. Coba lagi nanti.');
  END IF;
  IF v_att.request_window_start IS NULL OR v_att.request_window_start <= NOW() - INTERVAL '10 minutes' THEN
    INSERT INTO otp_attempts (nrp, request_count, request_window_start)
    VALUES (p_nrp, 1, NOW())
    ON CONFLICT (nrp) DO UPDATE SET request_count = 1, request_window_start = NOW();
  ELSE
    UPDATE otp_attempts SET request_count = request_count + 1 WHERE nrp = p_nrp;
  END IF;

  v_code := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
  INSERT INTO otp_store (nrp, code_hash, expiry, used)
  VALUES (p_nrp, encode(digest(v_code, 'sha256'), 'hex'), NOW() + INTERVAL '5 minutes', FALSE)
  ON CONFLICT (nrp) DO UPDATE SET
    code_hash = EXCLUDED.code_hash, expiry = EXCLUDED.expiry, used = FALSE;
  INSERT INTO audit_log (action, detail, timestamp) VALUES ('OTP_GENERATED', 'NRP: ' || p_nrp, NOW());
  RETURN jsonb_build_object('ok', true, 'msg', 'OTP sent', 'otp_code', v_code);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

GRANT EXECUTE ON FUNCTION generate_worker_otp(text, text) TO anon, authenticated;

-- ════════════════════════════════════════════════════════════════
-- 3. verify_worker_otp(p_nrp, p_code) — schema live + rate limit
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION verify_worker_otp(p_nrp TEXT, p_code TEXT)
RETURNS JSONB AS $$
DECLARE v_otp RECORD; v_token TEXT; v_att RECORD;
BEGIN
  IF p_nrp IS NULL OR p_code IS NULL OR LENGTH(p_code) < 4 THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'NRP/kode OTP tidak valid');
  END IF;

  SELECT * INTO v_otp FROM otp_store
  WHERE nrp = p_nrp AND used = false AND expiry > NOW()
  ORDER BY created_at DESC LIMIT 1;
  IF NOT FOUND OR encode(digest(p_code, 'sha256'), 'hex') != v_otp.code_hash THEN
    -- Rate limit percobaan gagal: 5 / 15 menit
    UPDATE otp_attempts SET attempts = attempts + 1,
      blocked_until = CASE WHEN attempts >= 4 THEN NOW() + INTERVAL '15 minutes' ELSE blocked_until END
    WHERE nrp = p_nrp;
    RETURN jsonb_build_object('ok', false, 'msg', 'Invalid or expired OTP');
  END IF;

  SELECT * INTO v_att FROM otp_attempts WHERE nrp = p_nrp;
  IF v_att.blocked_until IS NOT NULL AND v_att.blocked_until > NOW() THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Terlalu banyak percobaan. Akun dikunci 15 menit.');
  END IF;

  UPDATE otp_store SET used = true WHERE nrp = p_nrp AND code_hash = v_otp.code_hash;
  UPDATE otp_attempts SET attempts = 0, blocked_until = NULL WHERE nrp = p_nrp;

  v_token := encode(gen_random_bytes(32), 'hex');
  INSERT INTO session_tokens (session_token, nrp, type, expires_at, created_at)
  VALUES (v_token, p_nrp, 'worker', NOW() + INTERVAL '24 hours', NOW())
  ON CONFLICT (session_token) DO NOTHING;
  INSERT INTO audit_log (action, detail, timestamp) VALUES ('OTP_VERIFIED', 'NRP: ' || p_nrp, NOW());
  RETURN jsonb_build_object('ok', true, 'token', v_token, 'nrp', p_nrp);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

GRANT EXECUTE ON FUNCTION verify_worker_otp(text, text) TO anon, authenticated;

-- ════════════════════════════════════════════════════════════════
-- 4. worker_logout() — schema session_tokens live
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION worker_logout()
RETURNS JSONB AS $$
DECLARE v_nrp TEXT;
BEGIN
  v_nrp := authz_current_nrp();
  IF v_nrp IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Tidak ada session aktif');
  END IF;
  UPDATE session_tokens SET expires_at = NOW() WHERE nrp = v_nrp AND expires_at > NOW();
  DELETE FROM active_sessions WHERE nrp = v_nrp;
  RETURN jsonb_build_object('ok', true, 'msg', 'Berhasil logout', 'jwt_note', 'Frontend MUST also call supabase.auth.signOut()');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

GRANT EXECUTE ON FUNCTION worker_logout() TO authenticated;

-- ════════════════════════════════════════════════════════════════
-- 5. change_password(p_nrp, p_old_password, p_new_password) —
--    deteksi bcrypt '$2%', salt nullable (bcrypt), schema live
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION change_password(
  p_nrp TEXT, p_old_password TEXT, p_new_password TEXT
) RETURNS JSONB AS $$
DECLARE
  v_pwd RECORD; v_valid BOOLEAN := FALSE;
BEGIN
  IF p_new_password IS NULL OR LENGTH(p_new_password) < 8 THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Password baru minimal 8 karakter');
  END IF;
  SELECT * INTO v_pwd FROM worker_passwords WHERE nrp = p_nrp AND is_active = true;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akun tidak ditemukan');
  END IF;
  IF v_pwd.password_hash LIKE '$2%' THEN
    v_valid := (crypt(p_old_password, v_pwd.password_hash) = v_pwd.password_hash);
  ELSE
    v_valid := (encode(digest(p_old_password || COALESCE(v_pwd.salt, ''), 'sha256'), 'hex') = v_pwd.password_hash);
  END IF;
  IF NOT v_valid THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Password lama salah');
  END IF;
  UPDATE worker_passwords
  SET password_hash = crypt(p_new_password, gen_salt('bf')),
      salt = NULL, reset_required = FALSE, attempts = 0, blocked_until = NULL
  WHERE nrp = p_nrp;
  UPDATE session_tokens SET expires_at = NOW() WHERE nrp = p_nrp AND expires_at > NOW();
  INSERT INTO audit_log (action, detail, timestamp)
  VALUES ('PASSWORD_CHANGED', jsonb_build_object('nrp', p_nrp)::text, NOW());
  RETURN jsonb_build_object('ok', true, 'msg', 'Password berhasil diubah');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

GRANT EXECUTE ON FUNCTION change_password(text, text, text) TO anon, authenticated;

-- ════════════════════════════════════════════════════════════════
-- 5b. worker_change_password(p_nrp, p_old, p_new) — jalur worker
--     self-service (WorkerChangePassword.jsx): deteksi bcrypt '$2%'
--     + invalidasi session live
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION worker_change_password(p_nrp TEXT, p_old TEXT, p_new TEXT)
RETURNS JSONB AS $$
DECLARE v_w RECORD; v_new_salt TEXT; v_new_hash TEXT; v_valid BOOLEAN := FALSE;
BEGIN
  SELECT * INTO v_w FROM worker_passwords WHERE nrp = p_nrp AND is_active = true;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'msg', 'Akun tidak ditemukan.'); END IF;
  IF p_new IS NULL OR LENGTH(p_new) < 8 THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Password baru minimal 8 karakter');
  END IF;
  IF v_w.password_hash LIKE '$2%' THEN
    v_valid := (crypt(p_old, v_w.password_hash) = v_w.password_hash);
  ELSE
    v_valid := (encode(digest(p_old || COALESCE(v_w.salt, ''), 'sha256'), 'hex') = v_w.password_hash);
  END IF;
  IF NOT v_valid THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Password lama salah.');
  END IF;
  v_new_salt := encode(gen_random_bytes(16), 'hex');
  v_new_hash := encode(digest(p_new || v_new_salt, 'sha256'), 'hex');
  UPDATE worker_passwords SET password_hash = v_new_hash, salt = v_new_salt,
    attempts = 0, blocked_until = NULL, reset_required = FALSE, updated_at = NOW()
  WHERE nrp = p_nrp;
  UPDATE session_tokens SET expires_at = NOW() WHERE nrp = p_nrp AND expires_at > NOW();
  INSERT INTO audit_log (action, detail, timestamp)
  VALUES ('WORKER_PASSWORD_CHANGED', 'NRP: ' || p_nrp, NOW());
  RETURN jsonb_build_object('ok', true, 'msg', 'Password berhasil diubah.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

GRANT EXECUTE ON FUNCTION worker_change_password(text, text, text) TO authenticated;

-- ════════════════════════════════════════════════════════════════
-- 6. reset_password(p_nrp, p_token, p_new_password) — schema live
--    (digunakan oleh edge function password-reset)
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION reset_password(p_nrp TEXT, p_token TEXT, p_new_password TEXT)
RETURNS JSONB AS $$
DECLARE
  v_otp RECORD;
  v_salt TEXT;
  v_hash TEXT;
BEGIN
  IF p_new_password IS NULL OR LENGTH(p_new_password) < 6 THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Password minimal 6 karakter');
  END IF;

  SELECT * INTO v_otp FROM otp_store
  WHERE nrp = p_nrp AND code_hash = encode(digest(p_token, 'sha256'), 'hex') AND NOT used AND expiry > NOW();
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Token tidak valid atau sudah kadaluarsa');
  END IF;

  UPDATE otp_store SET used = true WHERE nrp = p_nrp AND code_hash = v_otp.code_hash;

  v_salt := encode(gen_random_bytes(8), 'hex');
  v_hash := encode(digest(p_new_password || v_salt, 'sha256'), 'hex');
  UPDATE worker_passwords SET password_hash = v_hash, salt = v_salt,
    attempts = 0, blocked_until = NULL, reset_required = FALSE
  WHERE nrp = p_nrp;

  UPDATE session_tokens SET expires_at = NOW() WHERE nrp = p_nrp AND expires_at > NOW();
  DELETE FROM active_sessions WHERE nrp = p_nrp;

  INSERT INTO audit_log (action, detail, timestamp)
  VALUES ('PASSWORD_RESET_COMPLETE', 'SUCCESS', 'Password reset for NRP ' || p_nrp, NOW());

  RETURN jsonb_build_object('ok', true, 'msg', 'Password berhasil direset. Silakan login dengan password baru.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

GRANT EXECUTE ON FUNCTION reset_password(text, text, text) TO authenticated, service_role;

DO $$ BEGIN
  RAISE NOTICE '=== 192: auth schema drift repair (login/OTP/logout/change/reset password) ===';
END $$;