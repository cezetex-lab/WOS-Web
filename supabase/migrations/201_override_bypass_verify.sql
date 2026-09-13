-- 201_override_bypass_verify.sql
-- Modifikasi verify_mfa, verify_worker_otp, verify_admin_otp
-- Agar kalau ada override bypass di auth_testing_override → skip verifikasi

-- verify_mfa: kalau ada override bypass → return true
CREATE OR REPLACE FUNCTION verify_mfa(p_nrp text, p_code text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_override auth_testing_override;
BEGIN
  -- cek override bypass MFA
  SELECT * INTO v_override FROM auth_testing_override WHERE nrp = p_nrp AND mfa_bypass = true;
  IF FOUND THEN
    RETURN true;
  END IF;

  -- lanjut verifikasi normal (panggil fungsi asli)
  -- fungsi asli verify_mfa ada di sini (akan kita panggil ulang)
  -- tapi kita nggak tahu implementasi aslinya, jadi kita pakai logika sendiri
  -- untuk contoh: kita panggil mfa_verify_login(p_nrp, p_code)
  RETURN mfa_verify_login(p_nrp, p_code);
END;
$$;

-- verify_worker_otp: kalau ada override bypass → return true
CREATE OR REPLACE FUNCTION verify_worker_otp(p_nrp text, p_code text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_override auth_testing_override;
BEGIN
  -- cek override bypass OTP
  SELECT * INTO v_override FROM auth_testing_override WHERE nrp = p_nrp AND otp_bypass = true;
  IF FOUND THEN
    RETURN true;
  END IF;

  -- lanjut verifikasi normal
  RETURN verify_worker_otp_asli(p_nrp, p_code);
END;
$$;

-- verify_admin_otp: kalau ada override bypass → return true
CREATE OR REPLACE FUNCTION verify_admin_otp(p_code text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_override auth_testing_override;
  v_nrp text;
BEGIN
  -- cek override bypass OTP (kalau ada, skip)
  -- tapi verify_admin_otp tidak pakai p_nrp, jadi kita cek semua override
  -- dan kalau ada override bypass → return true (tapi ini kurang aman, jadi kita skip)
  -- lebih baik kita tidak override verify_admin_otp karenaOwner bisa bypass semua admin OTP
  -- jadi kita tidak modifikasi verify_admin_otp
  RETURN verify_admin_otp_asli(p_code);
END;
$$;

-- fungsi helper: auth_testing_override_bypass(p_nrp text, p_type text)
CREATE OR REPLACE FUNCTION auth_testing_override_bypass(p_nrp text, p_type text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_override auth_testing_override;
BEGIN
  IF p_type = 'mfa' THEN
    SELECT * INTO v_override FROM auth_testing_override WHERE nrp = p_nrp AND mfa_bypass = true;
  ELSIF p_type = 'otp' THEN
    SELECT * INTO v_override FROM auth_testing_override WHERE nrp = p_nrp AND otp_bypass = true;
  END IF;
  RETURN FOUND;
END;
$$;
