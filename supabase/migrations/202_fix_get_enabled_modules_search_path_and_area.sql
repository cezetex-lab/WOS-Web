-- ================================================================
-- 202_fix_get_enabled_modules_search_path_and_area.sql
-- ================================================================
-- F-4 FIX: get_enabled_modules() SECURITY DEFINER TANPA SET search_path
--   → pelanggaran Rule §6.3. Tambah SET search_path.
-- 5.10: Tambah parameter p_area untuk filter route_group (admin/worker)
--   → efisiensi + fix A12 (root fix untuk per-area module loading)
-- ================================================================

CREATE OR REPLACE FUNCTION get_enabled_modules(p_area text DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', extensions
AS $function$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_bu_tier INT := 0;
  v_result JSONB;
BEGIN
  IF v_ctx IS NULL THEN RETURN '[]'::JSONB; END IF;

  -- Owner: akses semua modul aktif (optional filter by area)
  IF (v_ctx->>'is_owner')::BOOLEAN THEN
    SELECT jsonb_agg(jsonb_build_object(
      'module_code', module_code, 'module_name', module_name,
      'module_group', module_group, 'menu_icon', menu_icon,
      'menu_order', menu_order, 'is_industry_module', is_industry_module,
      'route_path', route_path, 'route_component', route_component,
      'route_group', route_group))
    INTO v_result
    FROM module_definitions
    WHERE is_active = TRUE
      AND (p_area IS NULL OR route_group = p_area);
    RETURN COALESCE(v_result, '[]'::JSONB);
  END IF;

  -- Non-owner: filter by role_level + business unit tier
  SELECT tier INTO v_bu_tier FROM business_units
  WHERE id = (v_ctx->>'business_unit_id')::TEXT;
  IF NOT FOUND THEN v_bu_tier := 0; END IF;

  SELECT jsonb_agg(jsonb_build_object(
    'module_code', md.module_code, 'module_name', md.module_name,
    'module_group', md.module_group, 'menu_icon', md.menu_icon,
    'menu_order', md.menu_order, 'is_industry_module', md.is_industry_module,
    'route_path', md.route_path, 'route_component', md.route_component,
    'route_group', md.route_group))
  INTO v_result
  FROM module_definitions md
  LEFT JOIN business_unit_modules bum
    ON bum.module_code = md.module_code
   AND bum.business_unit_id = (v_ctx->>'business_unit_id')::TEXT
  WHERE md.is_active = TRUE
    AND (p_area IS NULL OR md.route_group = p_area)
    AND (v_ctx->>'role_level')::INT >= 1
    AND ((md.is_industry_module = TRUE AND bum.is_enabled = TRUE)
      OR (md.is_industry_module = FALSE AND v_bu_tier >= md.minimum_tier_required));
  RETURN COALESCE(v_result, '[]'::JSONB);
END;
$function$;

-- Catatan: grant tetap ke authenticated (untuk frontend).
-- Tidak perlu REVOKE anon karena get_enabled_modules sudah SECURITY DEFINER
-- dan auth.uid() harus valid (via get_current_user_context).
