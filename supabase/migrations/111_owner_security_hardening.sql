-- Migration 111: Security Hardening — Owner Identity + OWNER_OVERRIDE + Per-Action Permissions
-- INSIGHTWOS V6 Architecture
-- Generated: September 3, 2026

-- =============================================================
-- PART 1: UPDATE get_current_user_context() to use identity check
-- =============================================================

CREATE OR REPLACE FUNCTION get_current_user_context()
RETURNS JSONB AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_emp RECORD;
  v_role RECORD;
  v_is_owner BOOLEAN;
BEGIN
  IF v_uid IS NULL THEN RETURN NULL; END IF;

  -- Check Owner identity (NOT role-based)
  SELECT check_owner_identity() INTO v_is_owner;

  IF v_is_owner THEN
    RETURN jsonb_build_object(
      'nrp', 'OWNER001',
      'nama', 'System Owner',
      'role', 'owner',
      'role_level', 5,
      'is_owner', TRUE,
      'business_unit_id', NULL,
      'email', (SELECT email FROM auth.users WHERE id = v_uid LIMIT 1)
    );
  END IF;

  -- Regular employee lookup
  SELECT * INTO v_emp FROM employees_master WHERE auth_id = v_uid LIMIT 1;
  IF v_emp IS NULL THEN RETURN NULL; END IF;

  SELECT * INTO v_role FROM user_roles WHERE nrp = v_emp.nrp LIMIT 1;

  RETURN jsonb_build_object(
    'nrp', v_emp.nrp,
    'nama', v_emp.nama,
    'role', COALESCE(v_role.role, 'worker'),
    'role_level', COALESCE(v_role.role_level, 1),
    'is_owner', FALSE,
    'business_unit_id', v_emp.business_unit_id,
    'email', v_emp.email
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================
-- PART 2: PER-ACTION PERMISSION CHECK
-- =============================================================

CREATE OR REPLACE FUNCTION check_action_permission(p_module TEXT, p_action TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  v_ctx JSONB;
  v_role TEXT;
  v_permissions JSONB;
  v_perm TEXT;
BEGIN
  v_ctx := get_current_user_context();
  IF v_ctx IS NULL THEN RETURN FALSE; END IF;

  -- Owner bypasses all action checks
  IF (v_ctx->>'is_owner')::BOOLEAN THEN RETURN TRUE; END IF;

  v_role := v_ctx->>'role';

  -- Get permissions from admin_roles
  SELECT permissions INTO v_permissions
  FROM admin_roles
  WHERE role_code = v_role AND is_active = TRUE;

  IF v_permissions IS NULL THEN
    -- Fallback: check role_page_access for basic access
    IF v_role = 'admin_pusat' THEN RETURN TRUE; END IF;
    RETURN FALSE;
  END IF;

  -- Check wildcard permission
  IF v_permissions ? '*' THEN RETURN TRUE; END IF;

  -- Check module.action permission (e.g. leave.approve)
  v_perm := p_module || '.' || p_action;
  IF v_permissions ? v_perm THEN RETURN TRUE; END IF;

  -- Check module.* permission
  IF v_permissions ? (p_module || '.*') THEN RETURN TRUE; END IF;

  RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION check_action_permission(TEXT, TEXT) TO authenticated;
-- =============================================================
-- PART 3: OWNER OVERRIDE LOGGING
-- =============================================================

CREATE OR REPLACE FUNCTION log_owner_override(
  p_action TEXT, p_target_type TEXT, p_target_id TEXT, p_details JSONB
)
RETURNS VOID AS $$
DECLARE v_ctx JSONB := get_current_user_context();
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN RETURN; END IF;
  INSERT INTO audit_log_owner (owner_nrp, action, target_type, target_id, old_value, new_value)
  VALUES (
    (v_ctx->>'nrp'),
    'OWNER_OVERRIDE',
    p_target_type,
    p_target_id,
    NULL,
    jsonb_build_object('action', p_action, 'details', p_details, 'timestamp', NOW())
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION log_owner_override(TEXT, TEXT, TEXT, JSONB) TO authenticated;

-- =============================================================
-- PART 4: ADMIN PUSAT CAN MANAGE ADMINS (but NOT Owner)
-- =============================================================

CREATE OR REPLACE FUNCTION admin_pusat_manage_admin(
  p_action TEXT, p_nrp TEXT, p_role_code TEXT
)
RETURNS JSONB AS $$
DECLARE v_ctx JSONB := get_current_user_context(); v_role TEXT; v_can_manage BOOLEAN;
BEGIN
  IF v_ctx IS NULL THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Not authenticated.');
  END IF;
  -- Owner always allowed
  IF (v_ctx->>'is_owner')::BOOLEAN THEN
    -- proceed below
  ELSE
    v_role := v_ctx->>'role';
    IF v_role != 'admin_pusat' THEN
      RETURN jsonb_build_object('ok', FALSE, 'msg', 'Admin Pusat only.');
    END IF;
    -- Check can_manage_users in admin_roles
    SELECT can_manage_users INTO v_can_manage FROM admin_roles WHERE role_code = v_role;
    IF NOT COALESCE(v_can_manage, FALSE) THEN
      RETURN jsonb_build_object('ok', FALSE, 'msg', 'No permission to manage users.');
    END IF;
  END IF;

  -- Block: cannot create/modify Owner
  IF p_role_code = 'owner' THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Cannot modify Owner.');
  END IF;

  -- Execute action
  IF p_action = 'assign' THEN
    PERFORM owner_assign_admin_user(p_nrp, p_role_code);
    RETURN jsonb_build_object('ok', TRUE, 'msg', 'Admin user assigned.');
  ELSIF p_action = 'deactivate' THEN
    UPDATE user_roles SET role = 'worker', role_level = 1 WHERE nrp = p_nrp;
    RETURN jsonb_build_object('ok', TRUE, 'msg', 'Admin deactivated.');
  END IF;

  RETURN jsonb_build_object('ok', FALSE, 'msg', 'Unknown action.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION admin_pusat_manage_admin(TEXT, TEXT, TEXT) TO authenticated;
-- =============================================================
-- PART 5: HELPER — Owner Override Context for Admin Functions
-- =============================================================

-- When Owner operates in admin context, log it
-- Usage: SELECT owner_override_context('payroll_approve', 'payroll', 'PAY001');

CREATE OR REPLACE FUNCTION owner_override_context(
  p_admin_action TEXT, p_module TEXT, p_record_id TEXT
)
RETURNS JSONB AS $$
DECLARE v_ctx JSONB := get_current_user_context();
BEGIN
  IF v_ctx IS NULL THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Not authenticated.');
  END IF;
  IF NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Owner only.');
  END IF;
  -- Log the override
  PERFORM log_owner_override(p_admin_action, p_module, p_record_id, jsonb_build_object(
    'admin_context', TRUE,
    'original_action', p_admin_action,
    'module', p_module,
    'record_id', p_record_id
  ));
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'Override logged.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION owner_override_context(TEXT, TEXT, TEXT) TO authenticated;

-- =============================================================
-- PART 6: INDUSTRY ADMIN MINI-DASHBOARD HELPER
-- =============================================================

-- Get industry-specific stats for admin dashboard
CREATE OR REPLACE FUNCTION get_industry_admin_stats(p_industry TEXT)
RETURNS JSONB AS $$
DECLARE v_ctx JSONB := get_current_user_context(); v_role TEXT; v_scope TEXT; v_result JSONB;
BEGIN
  IF v_ctx IS NULL THEN RETURN '{}'::JSONB; END IF;
  v_role := v_ctx->>'role';

  -- Verify user has industry admin role
  SELECT scope_id INTO v_scope FROM admin_roles WHERE role_code = v_role AND scope_type = 'industry' AND is_active = TRUE;
  IF v_scope IS NULL AND v_role != 'admin_pusat' AND NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN '{}'::JSONB;
  END IF;

  -- Return industry-specific stats based on type
  IF p_industry = 'mining' THEN
    RETURN jsonb_build_object(
      'industry', 'mining',
      'workers', (SELECT COUNT(*) FROM employees_master WHERE business_unit_id IN (SELECT id FROM business_units WHERE unit_code ILIKE '%mining%')),
      'equipment', (SELECT COUNT(*) FROM mining_equipment WHERE business_unit_id IN (SELECT id FROM business_units WHERE unit_code ILIKE '%mining%')),
      'safety_incidents', (SELECT COUNT(*) FROM mining_safety WHERE business_unit_id IN (SELECT id FROM business_units WHERE unit_code ILIKE '%mining%'))
    );
  ELSIF p_industry = 'mill' THEN
    RETURN jsonb_build_object(
      'industry', 'mill',
      'workers', (SELECT COUNT(*) FROM employees_master WHERE business_unit_id IN (SELECT id FROM business_units WHERE unit_code ILIKE '%mill%')),
      'boilers', (SELECT COUNT(*) FROM mill_boiler WHERE business_unit_id IN (SELECT id FROM business_units WHERE unit_code ILIKE '%mill%')),
      'maintenance', (SELECT COUNT(*) FROM mill_maintenance WHERE business_unit_id IN (SELECT id FROM business_units WHERE unit_code ILIKE '%mill%'))
    );
  ELSIF p_industry = 'estate' THEN
    RETURN jsonb_build_object(
      'industry', 'estate',
      'workers', (SELECT COUNT(*) FROM employees_master WHERE business_unit_id IN (SELECT id FROM business_units WHERE unit_code ILIKE '%estate%')),
      'blocks', (SELECT COUNT(*) FROM estate_blocks WHERE business_unit_id IN (SELECT id FROM business_units WHERE unit_code ILIKE '%estate%')),
      'harvest', (SELECT COUNT(*) FROM estate_harvest WHERE business_unit_id IN (SELECT id FROM business_units WHERE unit_code ILIKE '%estate%'))
    );
  END IF;

  RETURN '{}'::JSONB;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_industry_admin_stats(TEXT) TO authenticated;

-- =============================================================
-- PART 7: PERFORMANCE INDEXES
-- =============================================================

CREATE INDEX IF NOT EXISTS idx_audit_log_owner_action ON audit_log_owner(action);
CREATE INDEX IF NOT EXISTS idx_user_roles_role ON user_roles(role);
CREATE INDEX IF NOT EXISTS idx_employees_master_auth ON employees_master(auth_id);

-- Done. Migration 111 complete.
