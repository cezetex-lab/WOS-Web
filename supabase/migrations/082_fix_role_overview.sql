-- 082: Fix get_role_overview — count ALL employees, flexible status filter

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
      -- No status filter — count ALL employees for overview
      GROUP BY COALESCE(em.business_unit_id, 'HQ'),
               GREATEST(COALESCE(ur.role_level, 1), COALESCE(em.role_level, 1))
      ORDER BY 1, 2
    ) t
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_role_overview() TO authenticated;

-- Also: set role_level for employees based on their user_roles
UPDATE employees_master em
SET role_level = GREATEST(COALESCE(ur.role_level, 1), COALESCE(em.role_level, 1))
FROM user_roles ur
WHERE ur.nrp = em.nrp;

-- Set CEO (NRP001) to level 5 if not already
UPDATE employees_master SET role_level = 5 WHERE nrp = 'NRP001';
UPDATE user_roles SET role_level = 5 WHERE nrp = 'NRP001';

-- Set default role_level=1 for employees without one
UPDATE employees_master SET role_level = 1 WHERE role_level IS NULL;

-- Also fix get_business_units_for_owner — COALESCE unit_name
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
      SELECT id, unit_code, COALESCE(unit_name, unit_code, id) as unit_name, description, tier
      FROM business_units
      ORDER BY id
    ) t
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_business_units_for_owner() TO authenticated;
