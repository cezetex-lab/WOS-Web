-- ============================================================
-- 017_otp_functions.sql — OTP 2FA for Worker, Dashboard, Admin
-- Run AFTER CLEAN.sql
-- ============================================================

-- Drop old OTP functions if exist
DO $$ DECLARE fn TEXT; BEGIN
  FOREACH fn IN ARRAY ARRAY['generate_worker_otp','verify_worker_otp','generate_admin_otp','verify_admin_otp','generate_otp','verify_otp'] LOOP
    BEGIN EXECUTE 'DROP FUNCTION IF EXISTS '||fn||'(TEXT) CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE 'DROP FUNCTION IF EXISTS '||fn||'(TEXT,TEXT) CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE 'DROP FUNCTION IF EXISTS '||fn||'(TEXT,TEXT,TEXT) CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE 'DROP FUNCTION IF EXISTS '||fn||'() CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
  END LOOP;
END $$;

-- ============================================================
-- WORKER OTP — NRP + NIK = ZERO COST
-- Flow: NRP + Password → NRP + NIK match → OTP shown on screen
-- ============================================================

-- Step 1: Generate OTP after NRP+NIK validated (no email, zero cost)
CREATE OR REPLACE FUNCTION generate_worker_otp(p_nrp TEXT, p_nik TEXT)
RETURNS JSONB AS $$
DECLARE
  v_code TEXT; v_hash TEXT; v_expiry TIMESTAMPTZ;
  v_attempts INTEGER; v_emp RECORD;
BEGIN
  -- Validate NRP + NIK match
  SELECT * INTO v_emp FROM employees_master WHERE nrp = p_nrp;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok',false,'msg','NRP tidak terdaftar.');
  END IF;

  -- Normalize NIK: remove dots, spaces, dashes
  IF REPLACE(REPLACE(REPLACE(v_emp.nik,'.',''),'-',''),' ','') !=
     REPLACE(REPLACE(REPLACE(p_nik,'.',''),'-',''),' ','') THEN
    RETURN jsonb_build_object('ok',false,'msg','NRP dan NIK tidak cocok.');
  END IF;

  -- Rate limit: max 5 attempts per 15 minutes
  SELECT attempts INTO v_attempts FROM otp_attempts WHERE nrp = p_nrp;
  IF v_attempts IS NOT NULL AND v_attempts >= 5 THEN
    RETURN jsonb_build_object('ok',false,'msg','Terlalu banyak percobaan OTP. Tunggu 15 menit.');
  END IF;

  -- Generate 6-digit OTP
  v_code := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
  v_hash := encode(digest(v_code, 'sha256'), 'hex');
  v_expiry := NOW() + INTERVAL '5 minutes';

  -- Store OTP
  DELETE FROM otp_store WHERE nrp = p_nrp;
  INSERT INTO otp_store (nrp, code_hash, expiry, used)
    VALUES (p_nrp, v_hash, v_expiry, false);

  -- Return OTP on screen (zero cost, no email)
  RETURN jsonb_build_object('ok',true,'msg','Masukkan kode OTP di bawah.','otp',v_code);
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 2: Verify OTP → return session
CREATE OR REPLACE FUNCTION verify_worker_otp(p_nrp TEXT, p_code TEXT)
RETURNS JSONB AS $$
DECLARE v_otp RECORD; v_r RECORD; v_hash TEXT; v_attempts INTEGER;
BEGIN
  v_hash := encode(digest(p_code, 'sha256'), 'hex');

  SELECT * INTO v_otp FROM otp_store WHERE nrp = p_nrp AND code_hash = v_hash AND NOT used;
  IF NOT FOUND THEN
    SELECT attempts INTO v_attempts FROM otp_attempts WHERE nrp = p_nrp;
    v_attempts := COALESCE(v_attempts, 0) + 1;
    INSERT INTO otp_attempts (nrp, attempts, blocked_until)
      VALUES (p_nrp, v_attempts, CASE WHEN v_attempts >= 5 THEN NOW() + INTERVAL '15 minutes' ELSE NULL END)
      ON CONFLICT (nrp) DO UPDATE SET
        attempts = otp_attempts.attempts + 1,
        blocked_until = CASE WHEN otp_attempts.attempts + 1 >= 5 THEN NOW() + INTERVAL '15 minutes' ELSE otp_attempts.blocked_until END;
    RETURN jsonb_build_object('ok',false,'msg','Kode OTP tidak valid.');
  END IF;

  IF v_otp.expiry < NOW() THEN
    RETURN jsonb_build_object('ok',false,'msg','Kode OTP sudah kadaluarsa. Minta ulang.');
  END IF;

  UPDATE otp_store SET used = true WHERE nrp = p_nrp AND code_hash = v_hash;
  DELETE FROM otp_attempts WHERE nrp = p_nrp;

  SELECT * INTO v_r FROM user_roles WHERE nrp = p_nrp;
  RETURN jsonb_build_object('ok',true,
    'nrp', p_nrp,
    'nama', (SELECT nama FROM employees_master WHERE nrp = p_nrp LIMIT 1),
    'level', COALESCE(v_r.role_level, 1),
    'tier', COALESCE(v_r.plan, 'FREE'),
    'position', (SELECT posisi FROM employees_master WHERE nrp = p_nrp LIMIT 1),
    'divisi', (SELECT divisi FROM employees_master WHERE nrp = p_nrp LIMIT 1));
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- ADMIN OTP — Password → Gmail → OTP
-- ============================================================

-- Step 1: Generate OTP after admin password validated (sent via Gmail)
CREATE OR REPLACE FUNCTION generate_admin_otp()
RETURNS JSONB AS $$
DECLARE v_code TEXT; v_hash TEXT; v_expiry TIMESTAMPTZ; v_email TEXT;
BEGIN
  v_code := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
  v_hash := encode(digest(v_code, 'sha256'), 'hex');
  v_expiry := NOW() + INTERVAL '5 minutes';

  DELETE FROM otp_store WHERE nrp = 'ADMIN';
  INSERT INTO otp_store (nrp, code_hash, expiry, used)
    VALUES ('ADMIN', v_hash, v_expiry, false);

  -- In production: send via Gmail SMTP
  -- For now: return otp in response (remove 'otp' field when Gmail is configured)
  -- TODO: integrate Gmail SMTP to send v_code to admin email
  RETURN jsonb_build_object('ok',true,'msg','OTP dikirim ke email admin.','otp',v_code);
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 2: Verify admin OTP → return admin token
CREATE OR REPLACE FUNCTION verify_admin_otp(p_code TEXT)
RETURNS JSONB AS $$
DECLARE v_otp RECORD; v_hash TEXT;
BEGIN
  v_hash := encode(digest(p_code, 'sha256'), 'hex');

  SELECT * INTO v_otp FROM otp_store WHERE nrp = 'ADMIN' AND code_hash = v_hash AND NOT used;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok',false,'msg','Kode OTP admin tidak valid.');
  END IF;

  IF v_otp.expiry < NOW() THEN
    RETURN jsonb_build_object('ok',false,'msg','Kode OTP sudah kadaluarsa. Minta ulang.');
  END IF;

  UPDATE otp_store SET used = true WHERE nrp = 'ADMIN' AND code_hash = v_hash;

  RETURN jsonb_build_object('ok',true,
    'token', encode(gen_random_bytes(16),'hex'),
    'role', 'admin',
    'nama', 'Administrator');
END; $$ LANGUAGE plpgsql SECURITY DEFINER;
