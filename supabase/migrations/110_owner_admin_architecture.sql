-- Migration 110: Owner Identity + Dynamic Admin Roles + Page Access Control
-- INSIGHTWOS V6 Architecture
-- Generated: September 3, 2026

-- =============================================================
-- PART 1: OWNER IDENTITY TABLE (NOT role-based)
-- =============================================================

CREATE TABLE IF NOT EXISTS system_owner_identity (
  id SERIAL PRIMARY KEY,
  auth_id UUID UNIQUE NOT NULL,
  owner_email TEXT UNIQUE NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed: insert current owner (run after auth user exists)
DO $$
DECLARE v_auth_id UUID;
BEGIN
  SELECT id INTO v_auth_id FROM auth.users WHERE email = 'owner@insightwos.com' LIMIT 1;
  IF v_auth_id IS NOT NULL THEN
    INSERT INTO system_owner_identity (auth_id, owner_email)
    VALUES (v_auth_id, 'owner@insightwos.com')
    ON CONFLICT (auth_id) DO NOTHING;
  END IF;
END $$;

-- =============================================================
-- PART 2: DYNAMIC ADMIN ROLES TABLE
-- =============================================================

CREATE TABLE IF NOT EXISTS admin_roles (
  id SERIAL PRIMARY KEY,
  role_code TEXT UNIQUE NOT NULL,
  role_name TEXT NOT NULL,
  scope_type TEXT NOT NULL CHECK (scope_type IN ('global', 'function', 'industry')),
  scope_id TEXT,
  permissions JSONB DEFAULT '[]'::JSONB,
  can_manage_users BOOLEAN DEFAULT FALSE,
  can_manage_modules BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by TEXT
);

-- Seed default admin roles
INSERT INTO admin_roles (role_code, role_name, scope_type, scope_id, permissions, can_manage_users) VALUES
  ('admin_pusat', 'Admin Pusat', 'global', NULL, '["*"]'::JSONB, TRUE),
  ('admin_hrd', 'Admin HRD', 'function', 'hrd', '["employees.*", "recruitment.*", "kpi.*", "learning.*", "talent.*", "exit.*"]'::JSONB, FALSE),
  ('admin_finance', 'Admin Finance', 'function', 'finance', '["payroll.*", "budget.*", "timesheet.*", "overtime.*", "export.*", "kpi.*"]'::JSONB, FALSE),
  ('admin_operasional', 'Admin Operasional', 'function', 'operasional', '["requests.*", "leave.*", "overtime.*", "timesheet.*", "assets.*", "shift.*"]'::JSONB, FALSE),
  ('admin_mining', 'Admin Mining', 'industry', 'mining', '["mining.*"]'::JSONB, FALSE),
  ('admin_mill', 'Admin Mill', 'industry', 'mill', '["mill.*"]'::JSONB, FALSE),
  ('admin_estate', 'Admin Estate', 'industry', 'estate', '["estate.*"]'::JSONB, FALSE)
ON CONFLICT (role_code) DO NOTHING;

-- =============================================================
-- PART 3: ROLE PAGE ACCESS TABLE
-- =============================================================

CREATE TABLE IF NOT EXISTS role_page_access (
  id SERIAL PRIMARY KEY,
  role_code TEXT NOT NULL,
  page_pattern TEXT NOT NULL,
  can_access BOOLEAN DEFAULT TRUE,
  can_action BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(role_code, page_pattern)
);
-- Seed: admin_pusat - can access ALL admin pages
INSERT INTO role_page_access (role_code, page_pattern, can_access, can_action) VALUES
  ('admin_pusat', '/admin/*', TRUE, TRUE)
ON CONFLICT (role_code, page_pattern) DO NOTHING;

-- Seed: admin_hrd - HR pages only
INSERT INTO role_page_access (role_code, page_pattern, can_access, can_action) VALUES
  ('admin_hrd', '/admin/employees', TRUE, TRUE),
  ('admin_hrd', '/admin/recruitment', TRUE, TRUE),
  ('admin_hrd', '/admin/kpi', TRUE, TRUE),
  ('admin_hrd', '/admin/learning', TRUE, TRUE),
  ('admin_hrd', '/admin/talent', TRUE, TRUE),
  ('admin_hrd', '/admin/exit', TRUE, TRUE),
  ('admin_hrd', '/admin/requests', TRUE, TRUE),
  ('admin_hrd', '/admin/review-360', TRUE, TRUE),
  ('admin_hrd', '/admin/*', FALSE, FALSE)
ON CONFLICT (role_code, page_pattern) DO NOTHING;

-- Seed: admin_finance - finance pages only
INSERT INTO role_page_access (role_code, page_pattern, can_access, can_action) VALUES
  ('admin_finance', '/admin/payroll', TRUE, TRUE),
  ('admin_finance', '/admin/budget', TRUE, TRUE),
  ('admin_finance', '/admin/timesheet', TRUE, TRUE),
  ('admin_finance', '/admin/overtime', TRUE, TRUE),
  ('admin_finance', '/admin/export', TRUE, TRUE),
  ('admin_finance', '/admin/kpi', TRUE, TRUE),
  ('admin_finance', '/admin/*', FALSE, FALSE)
ON CONFLICT (role_code, page_pattern) DO NOTHING;

-- Seed: admin_operasional - operations pages only
INSERT INTO role_page_access (role_code, page_pattern, can_access, can_action) VALUES
  ('admin_operasional', '/admin/requests', TRUE, TRUE),
  ('admin_operasional', '/admin/leave', TRUE, TRUE),
  ('admin_operasional', '/admin/overtime', TRUE, TRUE),
  ('admin_operasional', '/admin/timesheet', TRUE, TRUE),
  ('admin_operasional', '/admin/shift-swap', TRUE, TRUE),
  ('admin_operasional', '/admin/assets', TRUE, TRUE),
  ('admin_operasional', '/admin/*', FALSE, FALSE)
ON CONFLICT (role_code, page_pattern) DO NOTHING;

-- Seed: admin_mining - mining pages only
INSERT INTO role_page_access (role_code, page_pattern, can_access, can_action) VALUES
  ('admin_mining', '/worker/simper', TRUE, TRUE),
  ('admin_mining', '/worker/heavy-equip', TRUE, TRUE),
  ('admin_mining', '/worker/fatigue', TRUE, TRUE),
  ('admin_mining', '/worker/production', TRUE, TRUE),
  ('admin_mining', '/worker/safety', TRUE, TRUE),
  ('admin_mining', '/worker/emergency', TRUE, TRUE),
  ('admin_mining', '/worker/jsa', TRUE, TRUE),
  ('admin_mining', '/admin/*', FALSE, FALSE)
ON CONFLICT (role_code, page_pattern) DO NOTHING;

-- Seed: admin_mill - mill pages only
INSERT INTO role_page_access (role_code, page_pattern, can_access, can_action) VALUES
  ('admin_mill', '/worker/boiler', TRUE, TRUE),
  ('admin_mill', '/worker/machines', TRUE, TRUE),
  ('admin_mill', '/worker/qc', TRUE, TRUE),
  ('admin_mill', '/worker/packing', TRUE, TRUE),
  ('admin_mill', '/worker/maintenance', TRUE, TRUE),
  ('admin_mill', '/worker/breakdown', TRUE, TRUE),
  ('admin_mill', '/worker/shift', TRUE, TRUE),
  ('admin_mill', '/admin/*', FALSE, FALSE)
ON CONFLICT (role_code, page_pattern) DO NOTHING;

-- Seed: admin_estate - estate pages only
INSERT INTO role_page_access (role_code, page_pattern, can_access, can_action) VALUES
  ('admin_estate', '/worker/harvest', TRUE, TRUE),
  ('admin_estate', '/worker/blocks', TRUE, TRUE),
  ('admin_estate', '/worker/transport', TRUE, TRUE),
  ('admin_estate', '/worker/nursery', TRUE, TRUE),
  ('admin_estate', '/worker/irrigation', TRUE, TRUE),
  ('admin_estate', '/worker/facility', TRUE, TRUE),
  ('admin_estate', '/worker/medical', TRUE, TRUE),
  ('admin_estate', '/admin/*', FALSE, FALSE)
ON CONFLICT (role_code, page_pattern) DO NOTHING;
-- =============================================================
-- PART 4: UPDATE USER_ROLES CONSTRAINT
-- =============================================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'user_roles_role_check') THEN
    ALTER TABLE user_roles DROP CONSTRAINT user_roles_role_check;
  END IF;
  ALTER TABLE user_roles ADD CONSTRAINT user_roles_role_check
    CHECK (role IN (
      'owner', 'admin', 'worker',
      'admin_pusat', 'admin_hrd', 'admin_finance', 'admin_produksi',
      'admin_operasional', 'admin_mining', 'admin_mill', 'admin_estate',
      'manager', 'supervisor', 'director'
    ));
END $$;

-- =============================================================
-- PART 5: RPC check_owner_identity()
-- =============================================================

CREATE OR REPLACE FUNCTION check_owner_identity()
RETURNS BOOLEAN AS $$
DECLARE v_is_owner BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM system_owner_identity
    WHERE auth_id = auth.uid() AND is_active = TRUE
  ) INTO v_is_owner;
  RETURN COALESCE(v_is_owner, FALSE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION check_owner_identity() TO authenticated;

-- =============================================================
-- PART 6: RPC check_admin_access(p_path)
-- =============================================================

CREATE OR REPLACE FUNCTION check_admin_access(p_path TEXT)
RETURNS JSONB AS $$
DECLARE
  v_role TEXT;
  v_is_owner BOOLEAN;
  v_result JSONB;
  v_scope_type TEXT;
  v_scope_id TEXT;
  v_permissions JSONB;
BEGIN
  -- 1. Owner bypass (identity-based)
  SELECT check_owner_identity() INTO v_is_owner;
  IF v_is_owner THEN
    RETURN jsonb_build_object('ok', TRUE, 'can_access', TRUE, 'can_action', TRUE, 'reason', 'owner_bypass');
  END IF;

  -- 2. Get user role from user_roles
  SELECT ur.role INTO v_role
  FROM user_roles ur
  WHERE ur.nrp = (SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1)
  ORDER BY ur.role_level DESC LIMIT 1;

  IF v_role IS NULL OR v_role = 'worker' THEN
    RETURN jsonb_build_object('ok', TRUE, 'can_access', FALSE, 'can_action', FALSE, 'reason', 'not_admin');
  END IF;

  -- 3. Look up dynamic admin role
  SELECT ar.scope_type, ar.scope_id, ar.permissions
  INTO v_scope_type, v_scope_id, v_permissions
  FROM admin_roles ar
  WHERE ar.role_code = v_role AND ar.is_active = TRUE;

  IF v_scope_type IS NULL THEN
    RETURN jsonb_build_object('ok', TRUE, 'can_access', FALSE, 'can_action', FALSE, 'reason', 'role_not_found');
  END IF;

  -- 4. Global scope
  IF v_scope_type = 'global' THEN
    IF p_path IN ('/admin/modules', '/admin/system-config', '/admin/access-control') THEN
      RETURN jsonb_build_object('ok', TRUE, 'can_access', FALSE, 'can_action', FALSE, 'reason', 'owner_only_feature');
    END IF;
    RETURN jsonb_build_object('ok', TRUE, 'can_access', TRUE, 'can_action', TRUE, 'reason', 'global_admin');
  END IF;

  -- 5. Function/Industry scope - check role_page_access table
  SELECT jsonb_build_object('ok', TRUE, 'can_access', rpa.can_access, 'can_action', rpa.can_action)
  INTO v_result
  FROM role_page_access rpa
  WHERE rpa.role_code = v_role AND (
    rpa.page_pattern = p_path
    OR (rpa.page_pattern LIKE '%/*' AND p_path LIKE REPLACE(rpa.page_pattern, '/*', '') || '%')
  )
  LIMIT 1;

  IF v_result IS NOT NULL THEN
    RETURN v_result;
  END IF;

  -- 6. Default: deny
  RETURN jsonb_build_object('ok', TRUE, 'can_access', FALSE, 'can_action', FALSE, 'reason', 'no_matching_rule');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION check_admin_access(TEXT) TO authenticated;
-- =============================================================
-- PART 7: OWNER RPCs — Admin Role Management
-- =============================================================

-- 7.1 Get all admin roles
CREATE OR REPLACE FUNCTION owner_get_admin_roles()
RETURNS JSONB AS $$
DECLARE v_ctx JSONB := get_current_user_context();
BEGIN
  IF v_ctx IS NULL OR NOT check_owner_identity() THEN
    RETURN '[]'::JSONB;
  END IF;
  RETURN (
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'id', ar.id,
      'role_code', ar.role_code,
      'role_name', ar.role_name,
      'scope_type', ar.scope_type,
      'scope_id', ar.scope_id,
      'permissions', ar.permissions,
      'can_manage_users', ar.can_manage_users,
      'can_manage_modules', ar.can_manage_modules,
      'is_active', ar.is_active,
      'created_at', ar.created_at,
      'created_by', ar.created_by
    )), '[]'::JSONB)
    FROM admin_roles ar
    ORDER BY ar.role_code
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION owner_get_admin_roles() TO authenticated;

-- 7.2 Create admin role
CREATE OR REPLACE FUNCTION owner_create_admin_role(
  p_role_code TEXT, p_role_name TEXT, p_scope_type TEXT,
  p_scope_id TEXT, p_permissions JSONB
)
RETURNS JSONB AS $$
DECLARE v_ctx JSONB := get_current_user_context();
BEGIN
  IF v_ctx IS NULL OR NOT check_owner_identity() THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Owner only.');
  END IF;
  IF p_role_code IS NULL OR p_role_name IS NULL OR p_scope_type IS NULL THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Missing required fields.');
  END IF;
  INSERT INTO admin_roles (role_code, role_name, scope_type, scope_id, permissions, created_by)
  VALUES (p_role_code, p_role_name, p_scope_type, p_scope_id, COALESCE(p_permissions, '[]'::JSONB), (v_ctx->>'nrp'));
  INSERT INTO audit_log_owner (owner_nrp, action, target_type, target_id, new_value)
  VALUES ((v_ctx->>'nrp'), 'CREATE_ADMIN_ROLE', 'admin_role', p_role_code, jsonb_build_object('role_name', p_role_name, 'scope_type', p_scope_type, 'scope_id', p_scope_id));
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'Admin role created.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION owner_create_admin_role(TEXT, TEXT, TEXT, TEXT, JSONB) TO authenticated;

-- 7.3 Update admin role
CREATE OR REPLACE FUNCTION owner_update_admin_role(
  p_role_id INT, p_role_name TEXT, p_permissions JSONB, p_is_active BOOLEAN
)
RETURNS JSONB AS $$
DECLARE v_ctx JSONB := get_current_user_context();
BEGIN
  IF v_ctx IS NULL OR NOT check_owner_identity() THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Owner only.');
  END IF;
  UPDATE admin_roles SET
    role_name = COALESCE(p_role_name, role_name),
    permissions = COALESCE(p_permissions, permissions),
    is_active = COALESCE(p_is_active, is_active)
  WHERE id = p_role_id;
  INSERT INTO audit_log_owner (owner_nrp, action, target_type, target_id, new_value)
  VALUES ((v_ctx->>'nrp'), 'UPDATE_ADMIN_ROLE', 'admin_role', p_role_id::TEXT, jsonb_build_object('role_name', p_role_name, 'is_active', p_is_active));
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'Admin role updated.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION owner_update_admin_role(INT, TEXT, JSONB, BOOLEAN) TO authenticated;

-- 7.4 Delete (deactivate) admin role
CREATE OR REPLACE FUNCTION owner_delete_admin_role(p_role_id INT)
RETURNS JSONB AS $$
DECLARE v_ctx JSONB := get_current_user_context(); v_code TEXT;
BEGIN
  IF v_ctx IS NULL OR NOT check_owner_identity() THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Owner only.');
  END IF;
  SELECT role_code INTO v_code FROM admin_roles WHERE id = p_role_id;
  UPDATE admin_roles SET is_active = FALSE WHERE id = p_role_id;
  INSERT INTO audit_log_owner (owner_nrp, action, target_type, target_id, new_value)
  VALUES ((v_ctx->>'nrp'), 'DELETE_ADMIN_ROLE', 'admin_role', v_code, '{}'::JSONB);
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'Admin role deactivated.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION owner_delete_admin_role(INT) TO authenticated;
-- 7.5 Assign admin user to role
CREATE OR REPLACE FUNCTION owner_assign_admin_user(p_nrp TEXT, p_role_code TEXT)
RETURNS JSONB AS $$
DECLARE v_ctx JSONB := get_current_user_context(); v_exists BOOLEAN;
BEGIN
  IF v_ctx IS NULL OR NOT check_owner_identity() THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Owner only.');
  END IF;
  SELECT EXISTS(SELECT 1 FROM admin_roles WHERE role_code = p_role_code AND is_active = TRUE) INTO v_exists;
  IF NOT v_exists THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Role not found or inactive.');
  END IF;
  -- Upsert user_roles for this NRP
  INSERT INTO user_roles (nrp, role, role_level)
  SELECT p_nrp, p_role_code, CASE
    WHEN p_role_code = 'admin_pusat' THEN 5
    WHEN p_role_code IN ('admin_hrd', 'admin_finance', 'admin_operasional') THEN 4
    ELSE 3
  END
  ON CONFLICT (nrp) DO UPDATE SET role = p_role_code, role_level = EXCLUDED.role_level;
  INSERT INTO audit_log_owner (owner_nrp, action, target_type, target_id, new_value)
  VALUES ((v_ctx->>'nrp'), 'ASSIGN_ADMIN_USER', 'user', p_nrp, jsonb_build_object('role_code', p_role_code));
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'Admin user assigned.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION owner_assign_admin_user(TEXT, TEXT) TO authenticated;

-- 7.6 Get all admin accounts
CREATE OR REPLACE FUNCTION owner_get_admin_accounts()
RETURNS JSONB AS $$
DECLARE v_ctx JSONB := get_current_user_context();
BEGIN
  IF v_ctx IS NULL OR NOT check_owner_identity() THEN
    RETURN '[]'::JSONB;
  END IF;
  RETURN (
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'nrp', ur.nrp,
      'role', ur.role,
      'role_level', ur.role_level,
      'nama', em.nama,
      'email', em.email
    )), '[]'::JSONB)
    FROM user_roles ur
    LEFT JOIN employees_master em ON em.nrp = ur.nrp
    WHERE ur.role LIKE 'admin_%'
    ORDER BY ur.role
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION owner_get_admin_accounts() TO authenticated;

-- =============================================================
-- PART 8: PERFORMANCE INDEXES
-- =============================================================

CREATE INDEX IF NOT EXISTS idx_admin_roles_code ON admin_roles(role_code);
CREATE INDEX IF NOT EXISTS idx_admin_roles_scope ON admin_roles(scope_type, scope_id);
CREATE INDEX IF NOT EXISTS idx_role_page_access_role ON role_page_access(role_code);
CREATE INDEX IF NOT EXISTS idx_system_owner_auth ON system_owner_identity(auth_id);

-- Done. Migration 110 complete.
