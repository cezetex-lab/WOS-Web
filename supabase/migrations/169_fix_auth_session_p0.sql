-- ================================================================
-- 169_fix_auth_session_p0.sql — FIX P0 AUTH (hasil smoke test 168 + uji login)
-- Masalah yang diperbaiki:
--  W1. pgcrypto (crypt/gen_salt/digest/pgp_sym_*/gen_random_bytes) hidup di
--      schema `extensions`, tapi semua fungsi SECURITY DEFINER dipin
--      search_path = public (tanpa extensions) => runtime error 42883 saat
--      memanggil crypt/digest/gen_random_bytes (login bcrypt, change_password,
--      encrypt/decrypt PII, MFA, INSERT ke tabel ber-default gen_random_bytes).
--      => search_path ditambah `extensions` untuk SEMUA fungsi SD di public.
--  W2. Live `session_tokens` = (session_token, nrp, type, expires_at,
--      created_at) [token plaintext], sedangkan login_worker/change_password/
--      worker_logout/reset_password/verify_worker_otp menulis kolom lama
--      (token_hash/is_used/used_at) => runtime error 42703.
--      => 5 fungsi ditulis ulang memakai model live (token = session_token).
--      verify_worker_otp juga disesuaikan dengan otp_store live
--      (expiry/used + hash sha256, selaras generate_worker_otp 3-arg).
--  W3. worker_passwords.salt NOT NULL di live, padahal auto-upgrade bcrypt
--      menulis NULL => DROP NOT NULL.
-- Semua definisi IDEMPOTENT. Verifikasi: supabase/smoke/168_fix_p0_p1_smoke.sql
-- (W1-W3 harus PASS setelah migrasi ini).
-- ================================================================

-- ════════════════════════════════════════════════════════════════
-- S1. search_path = public, extensions untuk semua SECURITY DEFINER
-- di schema public yang belum punya `extensions` di proconfig-nya.
-- (extensions = schema Supabase untuk pgcrypto/pgvector — tepercaya,
-- bukan skema user, sehingga tidak membuka celah hijack.)
-- ════════════════════════════════════════════════════════════════

DO $$
DECLARE r RECORD; v_n INT := 0;
BEGIN
  FOR r IN
    SELECT p.oid
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prosecdef = true
      AND NOT COALESCE(array_to_string(p.proconfig, ' '), '') LIKE '%extensions%'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public, extensions', r.oid::regprocedure);
    v_n := v_n + 1;
  END LOOP;
  RAISE NOTICE '169-S1: search_path public,extensions diterapkan ke % fungsi SD', v_n;
END $$;

-- ════════════════════════════════════════════════════════════════
-- S2. worker_passwords.salt: DROP NOT NULL
-- (auto-upgrade sha256->bcrypt menulis salt = NULL sebagai penanda)
-- ════════════════════════════════════════════════════════════════

ALTER TABLE worker_passwords ALTER COLUMN salt DROP NOT NULL;

-- ════════════════════════════════════════════════════════════════
-- S3. login_worker(p_nrp,p_nik,p_password) — model sesi live
-- * deteksi bcrypt via prefix '$2' (perbaikan 168 dipertahankan)
-- * sha256 legacy + auto-upgrade ke bcrypt
-- * session_tokens: invalidasi token lama (expires_at), INSERT token baru
--   ke kolom session_token (raw token) + type='worker'
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION login_worker(p_nrp TEXT, p_nik TEXT, p_password TEXT)
RETURNS JSONB AS $$
DECLARE
  v_emp RECORD; v_pwd RECORD; v_role RECORD;
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
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'NRP/NIK tidak ditemukan');
  END IF;

  SELECT * INTO v_pwd FROM worker_passwords WHERE nrp = p_nrp AND is_active = true;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akun tidak aktif');
  END IF;

  IF v_pwd.blocked_until IS NOT NULL AND v_pwd.blocked_until > NOW() THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akun diblokir sementara');
  END IF;

  -- bcrypt ($2a$/$2b$) vs sha256 (hex)
  IF v_pwd.password_hash LIKE '$2%' THEN
    IF crypt(p_password, v_pwd.password_hash) != v_pwd.password_hash THEN
      UPDATE worker_passwords SET attempts = attempts + 1,
        blocked_until = CASE WHEN attempts >= 4 THEN NOW() + INTERVAL '15 minutes' ELSE blocked_until END
      WHERE nrp = p_nrp;
      RETURN jsonb_build_object('ok', false, 'msg', 'Password salah');
    END IF;
  ELSE
    v_salt := v_pwd.salt;
    v_hash := encode(digest(p_password || v_salt, 'sha256'), 'hex');
    IF v_hash != v_pwd.password_hash THEN
      UPDATE worker_passwords SET attempts = attempts + 1,
        blocked_until = CASE WHEN attempts >= 4 THEN NOW() + INTERVAL '15 minutes' ELSE blocked_until END
      WHERE nrp = p_nrp;
      RETURN jsonb_build_object('ok', false, 'msg', 'Password salah');
    END IF;
    -- Auto-upgrade ke bcrypt (salt NULL = penanda; kini kolom nullable)
    UPDATE worker_passwords
    SET password_hash = crypt(p_password, gen_salt('bf')), salt = NULL, reset_required = FALSE
    WHERE nrp = p_nrp;
  END IF;

  UPDATE worker_passwords SET attempts = 0, blocked_until = NULL WHERE nrp = p_nrp;
  SELECT reset_required INTO v_reset_required FROM worker_passwords WHERE nrp = p_nrp;
  SELECT * INTO v_role FROM user_roles WHERE nrp = p_nrp;

  v_token := encode(gen_random_bytes(32), 'hex');
  UPDATE session_tokens SET expires_at = NOW() WHERE nrp = p_nrp AND expires_at > NOW();
  INSERT INTO session_tokens (session_token, nrp, type, expires_at, created_at)
  VALUES (v_token, p_nrp, 'worker', NOW() + INTERVAL '24 hours', NOW());
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

GRANT EXECUTE ON FUNCTION login_worker(text, text, text) TO authenticated;

-- ════════════════════════════════════════════════════════════════
-- S4. change_password — model sesi live + bcrypt (fix 168 dipertahankan)
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
    v_valid := (encode(digest(p_old_password || v_pwd.salt, 'sha256'), 'hex') = v_pwd.password_hash);
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

GRANT EXECUTE ON FUNCTION change_password(text, text, text) TO authenticated;

-- ════════════════════════════════════════════════════════════════
-- S5. worker_logout — invalidasi sesi model live
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
-- S6. reset_password — invalidasi sesi model live (kontrak token
-- otp_store: code_hash = sha256(token), expiry/used — tidak diubah)
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

-- ════════════════════════════════════════════════════════════════
-- S7. verify_worker_otp — disesuaikan otp_store live
-- (expiry/used, hash sha256 selaras generate_worker_otp 3-arg 164)
-- + pembuatan sesi model live
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION verify_worker_otp(p_nrp TEXT, p_code TEXT)
RETURNS JSONB AS $$
DECLARE v_otp RECORD; v_token TEXT;
BEGIN
  IF p_nrp IS NULL OR p_code IS NULL OR LENGTH(p_code) < 4 THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'NRP/kode OTP tidak valid');
  END IF;
  SELECT * INTO v_otp FROM otp_store
  WHERE nrp = p_nrp AND used = false AND expiry > NOW()
  ORDER BY created_at DESC LIMIT 1;
  IF NOT FOUND OR encode(digest(p_code, 'sha256'), 'hex') != v_otp.code_hash THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Invalid or expired OTP');
  END IF;
  UPDATE otp_store SET used = true WHERE nrp = p_nrp AND code_hash = v_otp.code_hash AND used = false;

  v_token := encode(gen_random_bytes(32), 'hex');
  UPDATE session_tokens SET expires_at = NOW() WHERE nrp = p_nrp AND expires_at > NOW();
  INSERT INTO session_tokens (session_token, nrp, type, expires_at, created_at)
  VALUES (v_token, p_nrp, 'worker', NOW() + INTERVAL '24 hours', NOW());
  INSERT INTO audit_log (action, detail, timestamp) VALUES ('OTP_VERIFIED', 'NRP: ' || p_nrp, NOW());
  RETURN jsonb_build_object('ok', true, 'token', v_token, 'nrp', p_nrp);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

GRANT EXECUTE ON FUNCTION verify_worker_otp(text, text) TO authenticated;