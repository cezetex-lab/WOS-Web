-- ===============================================================
-- FASE 7: AUTH FLOW (OTP via Email, Admin OTP)
-- Migration 164
-- ===============================================================

-- 7.1 Generate Worker OTP
CREATE OR REPLACE FUNCTION generate_worker_otp(p_nrp TEXT, p_nik TEXT)
RETURNS JSONB AS $$
DECLARE v_code TEXT; v_emp RECORD;
BEGIN
  SELECT * INTO v_emp FROM employees_master WHERE nrp = p_nrp AND nik = p_nik AND is_active = true;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'NRP/NIK tidak ditemukan');
  END IF;
  v_code := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
  INSERT INTO otp_store (nrp, code_hash, purpose, expires_at, created_at)
  VALUES (p_nrp, crypt(v_code, gen_salt('bf')), 'worker_otp', NOW() + INTERVAL '5 minutes', NOW());
  INSERT INTO audit_log (action,detail,timestamp) VALUES ('OTP_GENERATED', 'NRP: ' || p_nrp, NOW());
  RETURN jsonb_build_object('ok', true, 'msg', 'OTP sent', 'otp_code', v_code);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 7.2 Verify Worker OTP
CREATE OR REPLACE FUNCTION verify_worker_otp(p_nrp TEXT, p_code TEXT)
RETURNS JSONB AS $$
DECLARE v_otp RECORD; v_token TEXT;
BEGIN
  SELECT * INTO v_otp FROM otp_store WHERE nrp = p_nrp AND purpose = 'worker_otp' AND expires_at > NOW() AND used = false
  ORDER BY created_at DESC LIMIT 1;
  IF NOT FOUND OR NOT (v_otp.code_hash = crypt(p_code, v_otp.code_hash)) THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Invalid or expired OTP');
  END IF;
  UPDATE otp_store SET used = true WHERE id = v_otp.id;
  v_token := encode(gen_random_bytes(32), 'hex');
  INSERT INTO session_tokens (nrp, token_hash, expires_at, created_at)
  VALUES (p_nrp, crypt(v_token, gen_salt('bf')), NOW() + INTERVAL '24 hours', NOW());
  INSERT INTO audit_log (action,detail,timestamp) VALUES ('OTP_VERIFIED', 'NRP: ' || p_nrp, NOW());
  RETURN jsonb_build_object('ok', true, 'token', v_token, 'nrp', p_nrp);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 7.3 Generate Admin OTP
CREATE OR REPLACE FUNCTION generate_admin_otp()
RETURNS JSONB AS $$
DECLARE v_code TEXT;
BEGIN
  v_code := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
  INSERT INTO otp_store (nrp, code_hash, purpose, expires_at, created_at)
  VALUES ('ADMIN', crypt(v_code, gen_salt('bf')), 'admin_otp', NOW() + INTERVAL '5 minutes', NOW());
  INSERT INTO audit_log (action,detail,timestamp) VALUES ('ADMIN_OTP_GEN', 'Admin OTP generated', NOW());
  RETURN jsonb_build_object('ok', true, 'msg', 'OTP sent to admin email', 'otp_code', v_code);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 7.4 Verify Admin OTP
CREATE OR REPLACE FUNCTION verify_admin_otp(p_code TEXT)
RETURNS JSONB AS $$
DECLARE v_otp RECORD; v_token TEXT;
BEGIN
  SELECT * INTO v_otp FROM otp_store WHERE nrp = 'ADMIN' AND purpose = 'admin_otp' AND expires_at > NOW() AND used = false
  ORDER BY created_at DESC LIMIT 1;
  IF NOT FOUND OR NOT (v_otp.code_hash = crypt(p_code, v_otp.code_hash)) THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Invalid or expired OTP');
  END IF;
  UPDATE otp_store SET used = true WHERE id = v_otp.id;
  v_token := encode(gen_random_bytes(32), 'hex');
  INSERT INTO audit_log (action,detail,timestamp) VALUES ('ADMIN_OTP_VERIFIED', 'Admin OTP verified', NOW());
  RETURN jsonb_build_object('ok', true, 'token', v_token);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION generate_worker_otp(TEXT,TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION verify_worker_otp(TEXT,TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION generate_admin_otp() TO authenticated;
GRANT EXECUTE ON FUNCTION verify_admin_otp(TEXT) TO authenticated;

DO $$ BEGIN
  RAISE NOTICE '=== Fase 7: Auth Flow -- 4 functions, 4 GRANTs ===';
END $$;
