CREATE OR REPLACE FUNCTION get_user_context_by_auth_id(p_auth_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_emp RECORD;
  v_role RECORD;
  v_bu RECORD;
BEGIN
  SELECT employee_id, nrp, nama, email, business_unit_id, role_level, divisi, posisi
  INTO v_emp
  FROM employees_master
  WHERE auth_id = p_auth_id
  LIMIT 1;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akun tidak ditemukan di sistem');
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
    'unit_code', COALESCE(v_bu.unit_code, 'HQ'),
    'business_unit_name', COALESCE(v_bu.unit_name, ''),
    'tier', COALESCE(v_bu.tier, 0),
    'divisi', v_emp.divisi,
    'jabatan', v_emp.posisi
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
