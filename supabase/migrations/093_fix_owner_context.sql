-- Migration 093: Fix get_current_user_context() for Owner
-- Owner is NOT in employees_master, so the old function returned NULL.
-- New flow: check auth.users + user_roles for 'owner' role FIRST.

CREATE OR REPLACE FUNCTION get_current_user_context()
RETURNS JSONB AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_emp RECORD;
  v_role RECORD;
  v_is_owner BOOLEAN := FALSE;
BEGIN
  IF v_uid IS NULL THEN RETURN 'null'::JSONB; END IF;

  -- Step 1: Check if this auth.uid() is an Owner via auth.users email
  -- Owner email is 'owner@insightwos.com', role='owner' in user_roles
  FOR v_role IN
    SELECT ur.nrp, ur.role, ur.role_level
    FROM user_roles ur
    WHERE ur.role = 'owner' AND ur.nrp = 'OWNER001'
  LOOP
    -- Verify this is the right auth user by checking auth.users
    IF EXISTS (SELECT 1 FROM auth.users WHERE id = v_uid AND email = 'owner@insightwos.com') THEN
      v_is_owner := TRUE;
      RETURN jsonb_build_object(
        'nrp', v_role.nrp,
        'nama', 'System Owner',
        'role_level', 5,
        'role', 'owner',
        'business_unit_id', NULL,
        'divisi', NULL,
        'posisi', NULL,
        'is_owner', TRUE
      );
    END IF;
  END LOOP;

  -- Step 2: Regular employee lookup
  SELECT employee_id, nrp, nama, role_level, business_unit_id, divisi, posisi
  INTO v_emp FROM employees_master WHERE auth_id = v_uid;
  IF NOT FOUND THEN RETURN 'null'::JSONB; END IF;

  SELECT role INTO v_role FROM user_roles WHERE nrp = v_emp.nrp;
  v_is_owner := (v_role.role = 'owner');

  RETURN jsonb_build_object(
    'nrp', v_emp.nrp, 'nama', v_emp.nama,
    'role_level', v_emp.role_level, 'role', v_role.role,
    'business_unit_id', v_emp.business_unit_id,
    'divisi', v_emp.divisi, 'posisi', v_emp.posisi,
    'is_owner', v_is_owner
  );
END; $$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Verify: this should return owner context when called by owner@insightwos.com
-- SELECT get_current_user_context();
