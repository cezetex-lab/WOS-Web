-- Migration 134: Authorization Architecture v2
-- Tables + Helper Functions for ROLE → PERMISSION → SCOPE model
-- Replaces hardcoded role lists and tier-level checks

-- ============================================================
-- PART 1: TABLES
-- ============================================================

-- 1.1 Subscription per BU (replaces tier on user_roles)
CREATE TABLE IF NOT EXISTS bu_subscription (
  id SERIAL PRIMARY KEY,
  bu_id TEXT NOT NULL REFERENCES business_units(id),
  plan TEXT NOT NULL DEFAULT 'FREE',
  enabled_modules TEXT[] DEFAULT ARRAY[]::TEXT[],
  activated_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(bu_id)
);

-- 1.2 Role assignments (who has what role in what scope)
CREATE TABLE IF NOT EXISTS user_role_assignments (
  id SERIAL PRIMARY KEY,
  nrp TEXT NOT NULL,
  role_code TEXT NOT NULL,
  scope_type TEXT NOT NULL DEFAULT 'SELF',
  scope_bu_id TEXT,
  scope_org_unit TEXT,
  scope_domain TEXT,
  is_primary BOOLEAN DEFAULT TRUE,
  assigned_at TIMESTAMPTZ DEFAULT NOW(),
  assigned_by TEXT,
  UNIQUE(nrp, role_code, scope_type, scope_bu_id)
);

-- 1.3 Role → Permission set mapping
CREATE TABLE IF NOT EXISTS role_permission_sets (
  id SERIAL PRIMARY KEY,
  role_code TEXT NOT NULL,
  permission_set TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(role_code, permission_set)
);

-- 1.4 Permission set → individual permissions
CREATE TABLE IF NOT EXISTS permission_set_items (
  id SERIAL PRIMARY KEY,
  permission_set TEXT NOT NULL,
  permission_code TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(permission_set, permission_code)
);

-- 1.5 Indexes
CREATE INDEX IF NOT EXISTS idx_ura_nrp ON user_role_assignments(nrp);
CREATE INDEX IF NOT EXISTS idx_ura_role ON user_role_assignments(role_code);
CREATE INDEX IF NOT EXISTS idx_rps_role ON role_permission_sets(role_code);
CREATE INDEX IF NOT EXISTS idx_psi_set ON permission_set_items(permission_set);
CREATE INDEX IF NOT EXISTS idx_bs_bu ON bu_subscription(bu_id);

-- 1.6 RLS
ALTER TABLE bu_subscription ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_role_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_permission_sets ENABLE ROW LEVEL SECURITY;
ALTER TABLE permission_set_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "bs_admin" ON bu_subscription FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "ura_admin" ON user_role_assignments FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "rps_read" ON role_permission_sets FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "psi_read" ON permission_set_items FOR SELECT USING (auth.uid() IS NOT NULL);

-- ============================================================
-- PART 2: AUTHZ HELPER FUNCTIONS
-- ============================================================

-- 2.1 Get caller's NRP from auth.uid()
CREATE OR REPLACE FUNCTION authz_current_nrp()
RETURNS TEXT AS $$
  SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- 2.2 Check if caller has a specific permission
CREATE OR REPLACE FUNCTION authz_has_permission(p_permission_code TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  -- Owner bypasses everything
  IF EXISTS (SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = TRUE) THEN
    RETURN TRUE;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM user_role_assignments ura
    JOIN role_permission_sets rps ON rps.role_code = ura.role_code
    JOIN permission_set_items psi ON psi.permission_set = rps.permission_set
    WHERE ura.nrp = authz_current_nrp()
      AND psi.permission_code = p_permission_code
  );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 2.3 Check if target NRP/row is within caller's scope
CREATE OR REPLACE FUNCTION authz_in_scope(p_target_nrp TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  v_caller TEXT := authz_current_nrp();
  v_scope TEXT;
  v_bu TEXT;
BEGIN
  -- Owner bypasses everything
  IF EXISTS (SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = TRUE) THEN
    RETURN TRUE;
  END IF;

  -- SELF scope
  IF p_target_nrp = v_caller THEN RETURN TRUE; END IF;

  -- Check caller's scope from user_role_assignments
  SELECT scope_type, scope_bu_id INTO v_scope, v_bu
  FROM user_role_assignments WHERE nrp = v_caller AND is_primary = TRUE LIMIT 1;

  IF v_scope IS NULL THEN RETURN FALSE; END IF;

  CASE v_scope
    WHEN 'SELF' THEN RETURN FALSE; -- already checked above
    WHEN 'TEAM' THEN
      -- Same manager/supervisor
      RETURN EXISTS (
        SELECT 1 FROM hr_org ho1
        JOIN hr_org ho2 ON ho1.manager_nrp = ho2.manager_nrp
        WHERE ho1.nrp = v_caller AND ho2.nrp = p_target_nrp
      );
    WHEN 'DEPARTMENT' THEN
      RETURN EXISTS (
        SELECT 1 FROM employees_master em1
        JOIN employees_master em2 ON em1.divisi = em2.divisi
        WHERE em1.nrp = v_caller AND em2.nrp = p_target_nrp
      );
    WHEN 'BU' THEN
      RETURN EXISTS (
        SELECT 1 FROM employees_master em1
        JOIN employees_master em2 ON em1.business_unit_id = em2.business_unit_id
        WHERE em1.nrp = v_caller AND em2.nrp = p_target_nrp
      );
    WHEN 'DOMAIN' THEN
      -- Same domain (e.g., all MINING roles)
      RETURN EXISTS (
        SELECT 1 FROM employees_master em
        WHERE em.nrp = p_target_nrp AND em.business_unit_id = v_bu
      );
    WHEN 'ENTERPRISE' THEN
      RETURN TRUE;
    ELSE
      RETURN FALSE;
  END CASE;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 2.4 Check if caller has a specific role
CREATE OR REPLACE FUNCTION authz_has_role(p_role_code TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = TRUE) THEN
    RETURN TRUE;
  END IF;
  RETURN EXISTS (
    SELECT 1 FROM user_role_assignments
    WHERE nrp = authz_current_nrp() AND role_code = p_role_code
  );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 2.5 Get caller's scope
CREATE OR REPLACE FUNCTION authz_get_scope()
RETURNS TEXT AS $$
  SELECT scope_type FROM user_role_assignments
  WHERE nrp = authz_current_nrp() AND is_primary = TRUE LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- 2.6 Get caller's BU
CREATE OR REPLACE FUNCTION authz_get_bu()
RETURNS TEXT AS $$
  SELECT business_unit_id FROM employees_master WHERE auth_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- ============================================================
-- PART 3: BILLING HELPER
-- ============================================================

-- 3.1 Check if module is enabled for BU
CREATE OR REPLACE FUNCTION billing_module_enabled(p_module_code TEXT, p_bu_id TEXT DEFAULT NULL)
RETURNS BOOLEAN AS $$
DECLARE
  v_bu TEXT := COALESCE(p_bu_id, authz_get_bu());
BEGIN
  -- Owner bypasses
  IF EXISTS (SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = TRUE) THEN
    RETURN TRUE;
  END IF;

  -- Check bu_subscription
  RETURN EXISTS (
    SELECT 1 FROM bu_subscription
    WHERE bu_id = v_bu AND p_module_code = ANY(enabled_modules)
  );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ============================================================
-- PART 4: GRANT PERMISSIONS
-- ============================================================
GRANT EXECUTE ON FUNCTION authz_current_nrp() TO authenticated;
GRANT EXECUTE ON FUNCTION authz_has_permission(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION authz_in_scope(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION authz_has_role(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION authz_get_scope() TO authenticated;
GRANT EXECUTE ON FUNCTION authz_get_bu() TO authenticated;
GRANT EXECUTE ON FUNCTION billing_module_enabled(TEXT, TEXT) TO authenticated;
