-- 091: Owner = System Installer (NOT employee)
-- Owner TIDAK ada di employees_master
-- Owner HANYA di auth.users + user_roles

-- 1. Remove Owner from employees_master (if exists)
DELETE FROM employees_master WHERE nrp = 'OWNER001';

-- 2. Ensure Owner is in user_roles
INSERT INTO user_roles (nrp, role, role_level) VALUES ('OWNER001', 'owner', 5)
ON CONFLICT (nrp) DO UPDATE SET role = 'owner', role_level = 5;

-- 3. Fix get_user_context_by_auth_id — check user_roles FIRST for owner
CREATE OR REPLACE FUNCTION get_user_context_by_auth_id(p_auth_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_emp RECORD;
  v_role RECORD;
  v_bu RECORD;
  v_email TEXT;
  v_nrp TEXT;
  v_role_name TEXT;
BEGIN
  -- Get email from auth.users
  SELECT email INTO v_email FROM auth.users WHERE id = p_auth_id;
  
  -- Check user_roles FIRST (for Owner who is NOT in employees_master)
  SELECT nrp, role, role_level INTO v_nrp, v_role_name, v_role.role_level
  FROM user_roles 
  WHERE nrp = (SELECT nrp FROM user_roles WHERE nrp LIKE 'OWNER%' LIMIT 1)
  LIMIT 1;
  
  -- If this is the Owner (by email match)
  IF v_email = 'owner@insightwos.com' OR v_role_name = 'owner' THEN
    RETURN jsonb_build_object(
      'ok', true,
      'nrp', 'OWNER001',
      'nama', 'System Owner',
      'email', v_email,
      'role', 'owner',
      'role_level', 5,
      'business_unit_id', 'BU04',
      'business_unit_name', 'Korporat',
      'unit_code', 'HQ',
      'tier', 4,
      'divisi', 'KORPORAT',
      'jabatan', 'System Installer'
    );
  END IF;
  
  -- For regular employees, look up in employees_master
  SELECT employee_id, nrp, nama, email, business_unit_id, role_level, divisi, posisi
  INTO v_emp
  FROM employees_master
  WHERE auth_id = p_auth_id
  LIMIT 1;
  
  -- Fallback: try by email
  IF NOT FOUND AND v_email IS NOT NULL THEN
    SELECT employee_id, nrp, nama, email, business_unit_id, role_level, divisi, posisi
    INTO v_emp
    FROM employees_master
    WHERE LOWER(TRIM(email)) = LOWER(TRIM(v_email))
    LIMIT 1;
    IF FOUND THEN
      UPDATE employees_master SET auth_id = p_auth_id WHERE nrp = v_emp.nrp;
    END IF;
  END IF;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akun tidak ditemukan');
  END IF;

  SELECT role, role_level INTO v_role FROM user_roles WHERE nrp = v_emp.nrp LIMIT 1;
  SELECT tier, unit_name, unit_code INTO v_bu FROM business_units WHERE id = v_emp.business_unit_id;

  RETURN jsonb_build_object(
    'ok', true, 'nrp', v_emp.nrp, 'nama', v_emp.nama, 'email', v_emp.email,
    'role', COALESCE(v_role.role, 'worker'),
    'role_level', GREATEST(COALESCE(v_role.role_level, 1), COALESCE(v_emp.role_level, 1)),
    'business_unit_id', v_emp.business_unit_id,
    'business_unit_name', COALESCE(v_bu.unit_name, ''),
    'unit_code', COALESCE(v_bu.unit_code, 'HQ'),
    'tier', COALESCE(v_bu.tier, 0),
    'divisi', v_emp.divisi, 'jabatan', v_emp.posisi
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
