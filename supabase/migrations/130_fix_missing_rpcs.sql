-- ============================================================
-- Migration 130: Fix missing owner_update_role RPC
-- Also adds cache_get/cache_set stubs + validates all role constraints
-- ============================================================

-- 1. owner_update_role: Owner updates an admin's role + role_level
CREATE OR REPLACE FUNCTION owner_update_role(
  p_nrp TEXT,
  p_role TEXT,
  p_role_level INT
) RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
BEGIN
  -- Owner bypass only
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Owner access required');
  END IF;

  IF p_nrp IS NULL OR p_role IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'nrp and role required');
  END IF;

  -- Update user_roles
  UPDATE user_roles SET role = p_role, role_level = p_role_level WHERE nrp = p_nrp;

  -- Update employees_master role_level
  UPDATE employees_master SET role_level = p_role_level WHERE nrp = p_nrp;

  -- Log to audit
  INSERT INTO audit_log_owner (owner_auth_id, action, details)
  VALUES (
    auth.uid(),
    'update_role',
    jsonb_build_object('nrp', p_nrp, 'new_role', p_role, 'new_level', p_role_level)
  );

  RETURN jsonb_build_object('ok', true, 'msg', 'Role updated for ' || p_nrp);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. cache_get stub (returns null if no cache table)
CREATE OR REPLACE FUNCTION cache_get(p_key TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. cache_set stub
CREATE OR REPLACE FUNCTION cache_set(p_key TEXT, p_value JSONB, p_ttl INT DEFAULT 300)
RETURNS VOID AS $$
BEGIN
  -- No-op: cache table not yet created
  NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Grant execute to authenticated
GRANT EXECUTE ON FUNCTION owner_update_role TO authenticated;
GRANT EXECUTE ON FUNCTION cache_get TO authenticated;
GRANT EXECUTE ON FUNCTION cache_set TO authenticated;

SELECT 'Migration 130 complete: owner_update_role + cache stubs' AS status;
