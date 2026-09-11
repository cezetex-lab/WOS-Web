-- 195.sql — 2026-09-09 — generate_worker_otp: dukung bcrypt + rate-limit attempts
-- Sebab: login_worker auto-upgrade sha256→bcrypt membuat jalur OTP rusak
-- Rollback: CREATE OR REPLACE versi lama

CREATE OR REPLACE FUNCTION public.generate_worker_otp(p_nrp text, p_nik text, p_password text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'extensions' AS $function$
DECLARE
  v_code TEXT; v_hash TEXT; v_expiry TIMESTAMPTZ;
  v_attempts INTEGER; v_emp RECORD; v_wp RECORD;
BEGIN
  SELECT * INTO v_emp FROM employees_master WHERE nrp = p_nrp;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'NRP tidak terdaftar.');
  END IF;

  IF REPLACE(REPLACE(REPLACE(v_emp.nik,'.',''),'-',''),' ','') !=
     REPLACE(REPLACE(REPLACE(p_nik,'.',''),'-',''),' ','') THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'NRP dan NIK tidak cocok.');
  END IF;

  -- Rate limit dicek SEBELUM verifikasi password
  SELECT attempts INTO v_attempts FROM otp_attempts WHERE nrp = p_nrp;
  IF v_attempts IS NOT NULL AND v_attempts >= 5 THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Terlalu banyak percobaan. Tunggu 15 menit.');
  END IF;

  SELECT * INTO v_wp FROM worker_passwords WHERE nrp = p_nrp AND is_active = true;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akun belum aktif.');
  END IF;

  -- Password: bcrypt / sha256+salt / plaintext legacy
  IF v_wp.password_hash LIKE '$2%' THEN
    IF crypt(p_password, v_wp.password_hash) <> v_wp.password_hash THEN
      UPDATE otp_attempts SET attempts = COALESCE(attempts,0) + 1 WHERE nrp = p_nrp;
      RETURN jsonb_build_object('ok', false, 'msg', 'Password salah.');
    END IF;
  ELSIF v_wp.salt IS NOT NULL AND v_wp.salt <> '' THEN
    IF encode(digest(p_password || v_wp.salt, 'sha256'), 'hex') <> v_wp.password_hash THEN
      UPDATE otp_attempts SET attempts = COALESCE(attempts,0) + 1 WHERE nrp = p_nrp;
      RETURN jsonb_build_object('ok', false, 'msg', 'Password salah.');
    END IF;
  ELSE
    IF v_wp.password_hash <> p_password THEN
      UPDATE otp_attempts SET attempts = COALESCE(attempts,0) + 1 WHERE nrp = p_nrp;
      RETURN jsonb_build_object('ok', false, 'msg', 'Password salah.');
    END IF;
  END IF;

  UPDATE otp_attempts SET attempts = 0 WHERE nrp = p_nrp;

  v_code := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
  v_hash := encode(digest(v_code, 'sha256'), 'hex');
  v_expiry := NOW() + INTERVAL '5 minutes';

  DELETE FROM otp_store WHERE nrp = p_nrp;
  INSERT INTO otp_store (nrp, code_hash, expiry, used)
    VALUES (p_nrp, v_hash, v_expiry, false);

  RETURN jsonb_build_object('ok', true, 'msg', 'Masukkan kode OTP di bawah.', 'otp', v_code);
END; $function$;
