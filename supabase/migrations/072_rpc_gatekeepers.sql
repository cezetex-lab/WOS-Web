-- INSIGHTWOS V6 - RPC GATEKEEPERS (HARI 2)
-- Semua RPC pakai auth.uid() untuk identifikasi user
-- Semua RPC idempotent (CREATE OR REPLACE)

-- 1. get_current_user_context()
CREATE OR REPLACE FUNCTION get_current_user_context()
RETURNS JSONB AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_emp RECORD;
  v_role RECORD;
  v_is_owner BOOLEAN := FALSE;
BEGIN
  IF v_uid IS NULL THEN RETURN 'null'::JSONB; END IF;
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
END; $$
LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 2. check_module_access(p_module_code, p_required_role_level)
CREATE OR REPLACE FUNCTION check_module_access(p_module_code TEXT, p_required_role_level INT DEFAULT 1)
RETURNS BOOLEAN AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_module RECORD;
  v_bu_tier INT;
  v_lock_enabled BOOLEAN;
BEGIN
  IF v_ctx IS NULL THEN RETURN FALSE; END IF;
  IF (v_ctx->>'is_owner')::BOOLEAN THEN RETURN TRUE; END IF;
  SELECT * INTO v_module FROM module_definitions WHERE module_code = p_module_code AND is_active = TRUE;
  IF NOT FOUND THEN RETURN FALSE; END IF;
  IF (v_ctx->>'role_level')::INT < p_required_role_level THEN RETURN FALSE; END IF;
  IF v_module.is_industry_module THEN
    SELECT is_enabled INTO v_lock_enabled FROM business_unit_modules
    WHERE business_unit_id = (v_ctx->>'business_unit_id')::TEXT AND module_code = p_module_code;
    IF NOT FOUND OR v_lock_enabled = FALSE THEN RETURN FALSE; END IF;
    RETURN TRUE;
  END IF;
  SELECT tier INTO v_bu_tier FROM business_units WHERE id = (v_ctx->>'business_unit_id')::TEXT;
  IF NOT FOUND THEN v_bu_tier := 0; END IF;
  IF v_bu_tier < v_module.minimum_tier_required THEN RETURN FALSE; END IF;
  RETURN TRUE;
END; $$
LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 3. get_enabled_modules()
CREATE OR REPLACE FUNCTION get_enabled_modules()
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_bu_tier INT := 0;
  v_result JSONB;
BEGIN
  IF v_ctx IS NULL THEN RETURN '[]'::JSONB; END IF;
  IF (v_ctx->>'is_owner')::BOOLEAN THEN
    SELECT jsonb_agg(jsonb_build_object('module_code', module_code, 'module_name', module_name, 'module_group', module_group, 'menu_icon', menu_icon, 'menu_order', menu_order, 'is_industry_module', is_industry_module)) INTO v_result FROM module_definitions WHERE is_active = TRUE;
    RETURN COALESCE(v_result, '[]'::JSONB);
  END IF;
  SELECT tier INTO v_bu_tier FROM business_units WHERE id = (v_ctx->>'business_unit_id')::TEXT;
  IF NOT FOUND THEN v_bu_tier := 0; END IF;
  SELECT jsonb_agg(jsonb_build_object('module_code', md.module_code, 'module_name', md.module_name, 'module_group', md.module_group, 'menu_icon', md.menu_icon, 'menu_order', md.menu_order, 'is_industry_module', md.is_industry_module)) INTO v_result
  FROM module_definitions md LEFT JOIN business_unit_modules bum ON bum.module_code = md.module_code AND bum.business_unit_id = (v_ctx->>'business_unit_id')::TEXT
  WHERE md.is_active = TRUE AND (v_ctx->>'role_level')::INT >= 1
  AND ((md.is_industry_module = TRUE AND bum.is_enabled = TRUE) OR (md.is_industry_module = FALSE AND v_bu_tier >= md.minimum_tier_required));
  RETURN COALESCE(v_result, '[]'::JSONB);
END; $$
LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 4. owner_toggle_lock(p_module_code, p_enable)
CREATE OR REPLACE FUNCTION owner_toggle_lock(p_module_code TEXT, p_enable BOOLEAN)
RETURNS JSONB AS $$
DECLARE v_ctx JSONB := get_current_user_context(); v_old BOOLEAN; v_bu_id TEXT;
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Hanya Owner.');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM module_definitions WHERE module_code = p_module_code AND is_industry_module = TRUE) THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Bukan Industry module.');
  END IF;
  v_bu_id := (v_ctx->>'business_unit_id')::TEXT;
  SELECT is_enabled INTO v_old FROM business_unit_modules WHERE business_unit_id = v_bu_id AND module_code = p_module_code;
  UPDATE business_unit_modules SET is_enabled = p_enable, toggled_by = (v_ctx->>'nrp'), toggled_at = NOW() WHERE business_unit_id = v_bu_id AND module_code = p_module_code;
  INSERT INTO audit_log_owner (owner_nrp, action, target_type, target_id, old_value, new_value)
  VALUES ((v_ctx->>'nrp'), 'TOGGLE_LOCK', 'module', p_module_code, jsonb_build_object('enabled', COALESCE(v_old, FALSE)), jsonb_build_object('enabled', p_enable));
  RETURN jsonb_build_object('ok', TRUE, 'msg', CASE WHEN p_enable THEN 'Lock ON' ELSE 'Lock OFF' END);
END; $$
LANGUAGE plpgsql SECURITY DEFINER;

-- 5. owner_set_tier(p_bu_id, p_tier)
CREATE OR REPLACE FUNCTION owner_set_tier(p_bu_id TEXT, p_tier INT)
RETURNS JSONB AS $$
DECLARE v_ctx JSONB := get_current_user_context(); v_old INT;
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Hanya Owner.');
  END IF;
  IF p_tier NOT BETWEEN 0 AND 4 THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Tier harus 0-4.');
  END IF;
  SELECT tier INTO v_old FROM business_units WHERE id = p_bu_id;
  UPDATE business_units SET tier = p_tier WHERE id = p_bu_id;
  INSERT INTO audit_log_owner (owner_nrp, action, target_type, target_id, old_value, new_value)
  VALUES ((v_ctx->>'nrp'), 'SET_TIER', 'business_unit', p_bu_id, jsonb_build_object('tier', v_old), jsonb_build_object('tier', p_tier));
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'Tier diubah.');
END; $$
LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Trigger: prevent_duplicate_owner
CREATE OR REPLACE FUNCTION fn_prevent_duplicate_owner()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.role = 'owner' THEN
    IF EXISTS (SELECT 1 FROM user_roles WHERE role = 'owner' AND nrp != NEW.nrp) THEN
      RAISE EXCEPTION 'Hanya boleh ada 1 Owner.';
    END IF;
  END IF;
  RETURN NEW;
END; $$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prevent_duplicate_owner ON user_roles;
CREATE TRIGGER trg_prevent_duplicate_owner BEFORE INSERT OR UPDATE ON user_roles FOR EACH ROW EXECUTE FUNCTION fn_prevent_duplicate_owner();

-- 7. GRANT execute
GRANT EXECUTE ON FUNCTION get_current_user_context() TO authenticated;
GRANT EXECUTE ON FUNCTION check_module_access(TEXT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_enabled_modules() TO authenticated;
GRANT EXECUTE ON FUNCTION owner_toggle_lock(TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION owner_set_tier(TEXT, INT) TO authenticated;
