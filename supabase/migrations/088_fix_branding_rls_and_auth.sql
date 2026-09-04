-- 088: Fix branding RLS + auth lookup with email fallback

-- Fix 1: Branding RLS — INSERT needs WITH CHECK, not USING
DROP POLICY IF EXISTS br_insert ON branding;
CREATE POLICY br_insert ON branding FOR INSERT WITH CHECK (TRUE);

DROP POLICY IF EXISTS br_update ON branding;
CREATE POLICY br_update ON branding FOR UPDATE USING (TRUE) WITH CHECK (TRUE);

-- Fix 2: Auth lookup — robust version with email matching
CREATE OR REPLACE FUNCTION get_user_context_by_auth_id(p_auth_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_emp RECORD;
  v_role RECORD;
  v_bu RECORD;
  v_email TEXT;
BEGIN
  -- Get email from auth.users
  SELECT email INTO v_email FROM auth.users WHERE id = p_auth_id;
  
  -- Try lookup by auth_id first
  SELECT employee_id, nrp, nama, email, business_unit_id, role_level, divisi, posisi
  INTO v_emp
  FROM employees_master
  WHERE auth_id = p_auth_id
  LIMIT 1;
  
  -- If not found, try by email (case-insensitive, trim spaces)
  IF NOT FOUND AND v_email IS NOT NULL THEN
    SELECT employee_id, nrp, nama, email, business_unit_id, role_level, divisi, posisi
    INTO v_emp
    FROM employees_master
    WHERE LOWER(TRIM(email)) = LOWER(TRIM(v_email))
    LIMIT 1;
    
    -- Auto-link auth_id for future lookups
    IF FOUND THEN
      UPDATE employees_master SET auth_id = p_auth_id WHERE nrp = v_emp.nrp;
    END IF;
  END IF;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false, 
      'msg', 'Akun tidak ditemukan. Email auth: ' || COALESCE(v_email, 'null') || 
      '. Pastikan email di Supabase Auth sama dengan email di employees_master.'
    );
  END IF;

  SELECT role, role_level INTO v_role
  FROM user_roles WHERE nrp = v_emp.nrp LIMIT 1;

  SELECT tier, unit_name, unit_code INTO v_bu
  FROM business_units WHERE id = v_emp.business_unit_id;

  RETURN jsonb_build_object(
    'ok', true,
    'nrp', v_emp.nrp,
    'nama', v_emp.nama,
    'email', v_emp.email,
    'role', COALESCE(v_role.role, 'worker'),
    'role_level', GREATEST(COALESCE(v_role.role_level, 1), COALESCE(v_emp.role_level, 1)),
    'business_unit_id', v_emp.business_unit_id,
    'business_unit_name', COALESCE(v_bu.unit_name, ''),
    'unit_code', COALESCE(v_bu.unit_code, 'HQ'),
    'tier', COALESCE(v_bu.tier, 0),
    'divisi', v_emp.divisi,
    'jabatan', v_emp.posisi
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fix 3: Ensure Owner and CEO emails match in employees_master
-- Run this to sync emails if needed:
DO $$
DECLARE
  v_owner_email TEXT;
  v_ceo_email TEXT;
BEGIN
  -- Get emails from auth.users
  SELECT email INTO v_owner_email FROM auth.users WHERE email = 'owner@insightwos.com';
  SELECT email INTO v_ceo_email FROM auth.users WHERE email = 'ceo@insightwos.com';
  
  -- Update employees_master if emails don't match
  IF v_owner_email IS NOT NULL THEN
    UPDATE employees_master SET email = v_owner_email, auth_id = (
      SELECT id FROM auth.users WHERE email = v_owner_email
    ) WHERE nrp = 'OWNER001';
  END IF;
  
  IF v_ceo_email IS NOT NULL THEN
    UPDATE employees_master SET email = v_ceo_email, auth_id = (
      SELECT id FROM auth.users WHERE email = v_ceo_email
    ) WHERE nrp = 'NRP001';
  END IF;
END $$;
