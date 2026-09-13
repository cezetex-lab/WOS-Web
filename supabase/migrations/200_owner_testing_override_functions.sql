-- 200_owner_testing_override_functions.sql
-- Fungsi owner: set, get, delete override bypass MFA/OTP

CREATE OR REPLACE FUNCTION owner_set_testing_override(
  p_nrp text,
  p_mfa_bypass boolean,
  p_otp_bypass boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid := auth.uid();
  v_role text;
  v_admin_nrp text;
BEGIN
  -- owner hanya bisa set override
  SELECT ar.role_code INTO v_role
  FROM admin_roles ar
  JOIN user_role_assignments ura ON ura.role_id = ar.id
  WHERE ura.nrp = (SELECT nrp FROM employees_core WHERE auth_id = v_auth_uid)
  AND ar.role_code IN ('admin_pusat', 'owner')
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_owner';
  END IF;

  -- upsert override
  INSERT INTO auth_testing_override (nrp, mfa_bypass, otp_bypass, updated_by_owner)
  VALUES (p_nrp, p_mfa_bypass, p_otp_bypass, v_auth_uid)
  ON CONFLICT (nrp) DO UPDATE
    SET mfa_bypass = EXCLUDED.mfa_bypass,
        otp_bypass = EXCLUDED.otp_bypass,
        updated_by_owner = EXCLUDED.updated_by_owner,
        updated_at = now();
END;
$$;

CREATE OR REPLACE FUNCTION owner_get_testing_override(p_nrp text)
RETURNS TABLE (nrypt text, mfa_bypass boolean, otp_bypass boolean, updated_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid := auth.uid();
  v_role text;
BEGIN
  SELECT ar.role_code INTO v_role
  FROM admin_roles ar
  JOIN user_role_assignments ura ON ura.role_id = ar.id
  WHERE ura.nrp = (SELECT nrp FROM employees_core WHERE auth_id = v_auth_uid)
  AND ar.role_code IN ('admin_pusat', 'owner')
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_owner';
  END IF;

  RETURN QUERY
  SELECT nrp, mfa_bypass, otp_bypass, updated_at
  FROM auth_testing_override
  WHERE nrp = p_nrp;
END;
$$;

CREATE OR REPLACE FUNCTION owner_delete_testing_override(p_nrp text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid := auth.uid();
  v_role text;
BEGIN
  SELECT ar.role_code INTO v_role
  FROM admin_roles ar
  JOIN user_role_assignments ura ON ura.role_id = ar.id
  WHERE ura.nrp = (SELECT nrp FROM employees_core WHERE auth_id = v_auth_uid)
  AND ar.role_code IN ('admin_pusat', 'owner')
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_owner';
  END IF;

  DELETE FROM auth_testing_override WHERE nrp = p_nrp;
END;
$$;
