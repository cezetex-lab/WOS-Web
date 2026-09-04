-- 080: Owner Control Center RPCs
-- get_modules_for_owner, get_audit_log_owner, get_business_units_for_owner, get_role_overview

-- 1. get_modules_for_owner — returns all modules with lock status
CREATE OR REPLACE FUNCTION get_modules_for_owner()
RETURNS JSONB AS $$
DECLARE v_ctx JSONB := get_current_user_context();
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN '[]'::JSONB;
  END IF;
  RETURN (
    SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::JSONB)
    FROM (
      SELECT
        bum.module_code,
        md.module_name,
        md.module_group,
        md.is_industry_module,
        bum.is_enabled,
        md.menu_order,
        bu.id as business_unit_id,
        bu.unit_code,
        bu.unit_name
      FROM business_unit_modules bum
      JOIN module_definitions md ON md.module_code = bum.module_code
      LEFT JOIN business_units bu ON bu.id = bum.business_unit_id
      WHERE md.is_industry_module = TRUE
      ORDER BY bu.id, md.menu_order
    ) t
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. get_audit_log_owner — returns audit log with limit
CREATE OR REPLACE FUNCTION get_audit_log_owner(p_limit INT DEFAULT 50)
RETURNS JSONB AS $$
DECLARE v_ctx JSONB := get_current_user_context();
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN '[]'::JSONB;
  END IF;
  RETURN (
    SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::JSONB)
    FROM (
      SELECT id, owner_nrp, action, target_type, target_id, old_value, new_value, created_at
      FROM audit_log_owner
      ORDER BY created_at DESC
      LIMIT p_limit
    ) t
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. get_business_units_for_owner — returns all BUs with tier
CREATE OR REPLACE FUNCTION get_business_units_for_owner()
RETURNS JSONB AS $$
DECLARE v_ctx JSONB := get_current_user_context();
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN '[]'::JSONB;
  END IF;
  RETURN (
    SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::JSONB)
    FROM (
      SELECT id, unit_code, unit_name, description, tier
      FROM business_units
      ORDER BY id
    ) t
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. get_role_overview — returns user count per role_level per BU
CREATE OR REPLACE FUNCTION get_role_overview()
RETURNS JSONB AS $$
DECLARE v_ctx JSONB := get_current_user_context();
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN '[]'::JSONB;
  END IF;
  RETURN (
    SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::JSONB)
    FROM (
      SELECT
        COALESCE(em.business_unit_id, 'HQ') as business_unit_id,
        GREATEST(COALESCE(ur.role_level, 1), COALESCE(em.role_level, 1)) as role_level,
        COUNT(*) as count
      FROM employees_master em
      LEFT JOIN user_roles ur ON ur.nrp = em.nrp
      WHERE em.status_kerja IN ('AKTIF', 'Aktif', 'ACTIVE', 'Active')
      GROUP BY COALESCE(em.business_unit_id, 'HQ'),
               GREATEST(COALESCE(ur.role_level, 1), COALESCE(em.role_level, 1))
      ORDER BY 1, 2
    ) t
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grants
GRANT EXECUTE ON FUNCTION get_modules_for_owner() TO authenticated;
GRANT EXECUTE ON FUNCTION get_audit_log_owner(INT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_business_units_for_owner() TO authenticated;
GRANT EXECUTE ON FUNCTION get_role_overview() TO authenticated;

-- RLS policies for audit_log_owner (allow owner read)
DROP POLICY IF EXISTS alo_owner_read ON audit_log_owner;
CREATE POLICY alo_owner_read ON audit_log_owner FOR SELECT USING (TRUE);
