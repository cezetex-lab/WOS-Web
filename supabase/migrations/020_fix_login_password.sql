-- ============================================================
-- 020_fix_login_password.sql — Add password verification to OTP flow
-- Run AFTER 017_otp_functions.sql
-- ============================================================

-- Drop old function signatures
DO $$ DECLARE fn TEXT; BEGIN
  FOREACH fn IN ARRAY ARRAY['generate_worker_otp','verify_worker_otp'] LOOP
    BEGIN EXECUTE 'DROP FUNCTION IF EXISTS '||fn||'(TEXT,TEXT) CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE 'DROP FUNCTION IF EXISTS '||fn||'(TEXT,TEXT,TEXT) CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
  END LOOP;
END $$;

-- ============================================================
-- WORKER OTP — NRP + NIK + Password → OTP (zero cost)
-- ============================================================

-- Step 1: Validate NRP + NIK + Password → show OTP on screen
CREATE OR REPLACE FUNCTION generate_worker_otp(p_nrp TEXT, p_nik TEXT, p_password TEXT)
RETURNS JSONB AS $$
DECLARE
  v_code TEXT; v_hash TEXT; v_expiry TIMESTAMPTZ;
  v_attempts INTEGER; v_emp RECORD; v_wp RECORD;
BEGIN
  -- 1. Validate NRP exists
  SELECT * INTO v_emp FROM employees_master WHERE nrp = p_nrp;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok',false,'msg','NRP tidak terdaftar.');
  END IF;

  -- 2. Validate NIK matches
  IF REPLACE(REPLACE(REPLACE(v_emp.nik,'.',''),'-',''),' ','') !=
     REPLACE(REPLACE(REPLACE(p_nik,'.',''),'-',''),' ','') THEN
    RETURN jsonb_build_object('ok',false,'msg','NRP dan NIK tidak cocok.');
  END IF;

  -- 3. Validate password
  SELECT * INTO v_wp FROM worker_passwords WHERE nrp = p_nrp AND is_active = true;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok',false,'msg','Akun belum aktif.');
  END IF;

  -- Password check: compare with stored hash or plain text
  IF v_wp.salt IS NOT NULL AND v_wp.salt != '' THEN
    -- Hashed password: compare digest
    IF encode(digest(p_password || v_wp.salt, 'sha256'), 'hex') != v_wp.password_hash THEN
      RETURN jsonb_build_object('ok',false,'msg','Password salah.');
    END IF;
  ELSE
    -- Plain text password (legacy/demo mode)
    IF v_wp.password_hash != p_password THEN
      RETURN jsonb_build_object('ok',false,'msg','Password salah.');
    END IF;
  END IF;

  -- 4. Rate limit: max 5 attempts per 15 minutes
  SELECT attempts INTO v_attempts FROM otp_attempts WHERE nrp = p_nrp;
  IF v_attempts IS NOT NULL AND v_attempts >= 5 THEN
    RETURN jsonb_build_object('ok',false,'msg','Terlalu banyak percobaan. Tunggu 15 menit.');
  END IF;

  -- 5. Generate 6-digit OTP
  v_code := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
  v_hash := encode(digest(v_code, 'sha256'), 'hex');
  v_expiry := NOW() + INTERVAL '5 minutes';

  -- 6. Store OTP
  DELETE FROM otp_store WHERE nrp = p_nrp;
  INSERT INTO otp_store (nrp, code_hash, expiry, used)
    VALUES (p_nrp, v_hash, v_expiry, false);

  -- 7. Return OTP on screen (zero cost)
  RETURN jsonb_build_object('ok',true,'msg','Masukkan kode OTP di bawah.','otp',v_code);
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 2: Verify OTP → return session (unchanged)
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
-- ADMIN OTP — Password → OTP (unchanged, just drop old sig)
-- ============================================================

DO $$ DECLARE fn TEXT; BEGIN
  FOREACH fn IN ARRAY ARRAY['generate_admin_otp'] LOOP
    BEGIN EXECUTE 'DROP FUNCTION IF EXISTS '||fn||'() CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION generate_admin_otp()
RETURNS JSONB AS $$
DECLARE v_code TEXT; v_hash TEXT; v_expiry TIMESTAMPTZ;
BEGIN
  v_code := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
  v_hash := encode(digest(v_code, 'sha256'), 'hex');
  v_expiry := NOW() + INTERVAL '5 minutes';

  DELETE FROM otp_store WHERE nrp = 'ADMIN';
  INSERT INTO otp_store (nrp, code_hash, expiry, used)
    VALUES ('ADMIN', v_hash, v_expiry, false);

  RETURN jsonb_build_object('ok',true,'msg','OTP ditampilkan di layar.','otp',v_code);
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

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
    RETURN jsonb_build_object('ok',false,'msg','Kode OTP sudah kadaluarsa.');
  END IF;

  UPDATE otp_store SET used = true WHERE nrp = 'ADMIN' AND code_hash = v_hash;

  RETURN jsonb_build_object('ok',true,
    'token', encode(gen_random_bytes(16),'hex'),
    'role', 'admin',
    'nama', 'Administrator');
END; $$ LANGUAGE plpgsql SECURITY DEFINER;
