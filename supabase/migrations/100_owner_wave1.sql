-- ============================================================
-- 100_owner_wave1.sql
-- Owner Dashboard Wave 1 - Overview, Audit, Security, BU Management
-- Run in Supabase SQL Editor
-- ============================================================

-- 0. PRE-FLIGHT: Ensure tier column exists on business_units
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='business_units' AND column_name='tier') THEN
    ALTER TABLE business_units ADD COLUMN tier INT DEFAULT 0;
  END IF;
END $$;

-- 1. FIX: get_modules_for_owner - return ALL modules, not just industry
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
      ORDER BY bu.id, md.menu_order
    ) t
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. OVERVIEW: get_owner_overview_stats
CREATE OR REPLACE FUNCTION get_owner_overview_stats()
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_total_employees INT;
  v_active_employees INT;
  v_modules_total INT;
  v_modules_enabled INT;
  v_pending_requests INT;
  v_total_business_units INT;
  v_db_size TEXT;
  v_recent_logins INT;
  v_total_departments INT;
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN '{}'::JSONB;
  END IF;
  SELECT COUNT(*) INTO v_total_employees FROM employees_master;
  SELECT COUNT(*) INTO v_active_employees FROM employees_master
  WHERE UPPER(status_kerja) IN ('PKWTT','AKTIF','ACTIVE');
  SELECT COUNT(*) INTO v_modules_total FROM module_definitions;
  SELECT COUNT(*) INTO v_modules_enabled FROM business_unit_modules WHERE is_enabled = TRUE;
  SELECT COUNT(*) INTO v_pending_requests FROM hr_requests WHERE status = 'PENDING';
  SELECT COUNT(*) INTO v_total_business_units FROM business_units WHERE is_active = TRUE;
  SELECT pg_size_pretty(pg_database_size(current_database())) INTO v_db_size;
  SELECT COUNT(DISTINCT identifier) INTO v_recent_logins
  FROM login_attempts
  WHERE success = TRUE AND created_at > NOW() - INTERVAL '24 hours';
  SELECT COUNT(DISTINCT divisi) INTO v_total_departments
  FROM employees_master WHERE divisi IS NOT NULL;
  RETURN jsonb_build_object(
    'total_employees', COALESCE(v_total_employees, 0),
    'active_employees', COALESCE(v_active_employees, 0),
    'total_modules', COALESCE(v_modules_total, 0),
    'enabled_modules', COALESCE(v_modules_enabled, 0),
    'pending_requests', COALESCE(v_pending_requests, 0),
    'total_business_units', COALESCE(v_total_business_units, 0),
    'db_size', COALESCE(v_db_size, '0 bytes'),
    'recent_logins_24h', COALESCE(v_recent_logins, 0),
    'total_departments', COALESCE(v_total_departments, 0)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_owner_overview_stats() TO authenticated;

-- 3. OVERVIEW: get_owner_employees_by_bu
CREATE OR REPLACE FUNCTION get_owner_employees_by_bu()
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
        COALESCE(bu.unit_name, 'Headquarters') as unit_name,
        COUNT(*) as total_employees,
        COUNT(*) FILTER (WHERE UPPER(em.status_kerja) IN ('PKWTT','AKTIF','ACTIVE')) as active_employees
      FROM employees_master em
      LEFT JOIN business_units bu ON bu.id = em.business_unit_id
      GROUP BY COALESCE(em.business_unit_id, 'HQ'), bu.unit_name
      ORDER BY total_employees DESC
    ) t
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_owner_employees_by_bu() TO authenticated;

-- 4. AUDIT: get_audit_log_v2 - filtered + paginated
CREATE OR REPLACE FUNCTION get_audit_log_v2(
  p_action_type TEXT DEFAULT NULL,
  p_from TIMESTAMPTZ DEFAULT NULL,
  p_to TIMESTAMPTZ DEFAULT NULL,
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0
)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_total INT;
  v_data JSONB;
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN jsonb_build_object('data', '[]'::JSONB, 'total', 0);
  END IF;
  SELECT COUNT(*) INTO v_total
  FROM audit_log_owner
  WHERE (p_action_type IS NULL OR action = p_action_type)
    AND (p_from IS NULL OR created_at >= p_from)
    AND (p_to IS NULL OR created_at <= p_to);
  SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::JSONB) INTO v_data
  FROM (
    SELECT id, owner_nrp, action, target_type, target_id, old_value, new_value, created_at
    FROM audit_log_owner
    WHERE (p_action_type IS NULL OR action = p_action_type)
      AND (p_from IS NULL OR created_at >= p_from)
      AND (p_to IS NULL OR created_at <= p_to)
    ORDER BY created_at DESC
    LIMIT p_limit OFFSET p_offset
  ) t;
  RETURN jsonb_build_object('data', v_data, 'total', v_total);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_audit_log_v2(TEXT, TIMESTAMPTZ, TIMESTAMPTZ, INT, INT) TO authenticated;

-- 5. AUDIT: get_audit_log_actions - distinct action types for filter dropdown
CREATE OR REPLACE FUNCTION get_audit_log_actions()
RETURNS JSONB AS $$
DECLARE v_ctx JSONB := get_current_user_context();
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN '[]'::JSONB;
  END IF;
  RETURN (
    SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::JSONB)
    FROM (
      SELECT action, COUNT(*) as count
      FROM audit_log_owner
      GROUP BY action
      ORDER BY count DESC
    ) t
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_audit_log_actions() TO authenticated;

-- 6. SECURITY: get_active_sessions - who is logged in now
CREATE OR REPLACE FUNCTION get_active_sessions()
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN '[]'::JSONB;
  END IF;
  RETURN (
    SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::JSONB)
    FROM (
      SELECT
        st.nrp,
        st.type,
        st.created_at,
        st.expires_at,
        em.nama,
        em.divisi,
        em.posisi,
        COALESCE(em.business_unit_id, 'HQ') as business_unit_id
      FROM session_tokens st
      LEFT JOIN employees_master em ON em.nrp = st.nrp
      WHERE st.expires_at > NOW()
      ORDER BY st.created_at DESC
    ) t
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_active_sessions() TO authenticated;

-- 7. SECURITY: owner_force_logout - revoke session for a user
CREATE OR REPLACE FUNCTION owner_force_logout(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_deleted INT;
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Owner only.');
  END IF;
  DELETE FROM session_tokens WHERE nrp = p_nrp;
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  INSERT INTO audit_log_owner (owner_nrp, action, target_type, target_id, new_value)
  VALUES ('OWNER001', 'FORCE_LOGOUT', 'employee', p_nrp, jsonb_build_object('sessions_revoked', v_deleted));
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'Revoked ' || v_deleted || ' session(s) for ' || p_nrp);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION owner_force_logout(TEXT) TO authenticated;

-- 8. SECURITY: get_login_attempt_stats
CREATE OR REPLACE FUNCTION get_login_attempt_stats()
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_total_success INT;
  v_total_failed INT;
  v_locked_accounts INT;
  v_unique_users INT;
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN '{}'::JSONB;
  END IF;
  SELECT COUNT(*) INTO v_total_success
  FROM login_attempts WHERE success = TRUE AND created_at > NOW() - INTERVAL '24 hours';
  SELECT COUNT(*) INTO v_total_failed
  FROM login_attempts WHERE success = FALSE AND created_at > NOW() - INTERVAL '24 hours';
  SELECT COALESCE(COUNT(*), 0) INTO v_locked_accounts FROM (
    SELECT identifier FROM login_attempts
    WHERE success = FALSE AND created_at > NOW() - INTERVAL '15 minutes'
    GROUP BY identifier HAVING COUNT(*) >= 5
  ) sub;
  SELECT COUNT(DISTINCT identifier) INTO v_unique_users
  FROM login_attempts WHERE created_at > NOW() - INTERVAL '24 hours';
  RETURN jsonb_build_object(
    'success_24h', COALESCE(v_total_success, 0),
    'failed_24h', COALESCE(v_total_failed, 0),
    'locked_accounts', COALESCE(v_locked_accounts, 0),
    'unique_users_24h', COALESCE(v_unique_users, 0)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_login_attempt_stats() TO authenticated;

-- 9. BU MANAGEMENT: owner_create_bu
CREATE OR REPLACE FUNCTION owner_create_bu(
  p_unit_code TEXT,
  p_unit_name TEXT,
  p_description TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_id TEXT;
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Owner only.');
  END IF;
  IF p_unit_code IS NULL OR TRIM(p_unit_code) = '' THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Unit code wajib diisi.');
  END IF;
  IF p_unit_name IS NULL OR TRIM(p_unit_name) = '' THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Unit name wajib diisi.');
  END IF;
  IF EXISTS (SELECT 1 FROM business_units WHERE unit_code = UPPER(TRIM(p_unit_code))) THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Unit code sudah ada: ' || UPPER(TRIM(p_unit_code)));
  END IF;
  v_id := 'BU' || LPAD((SELECT COALESCE(MAX(SUBSTRING(id FROM 3)::INT), 0) + 1 FROM business_units WHERE id ~ '^BU[0-9]+$')::TEXT, 2, '0');
  INSERT INTO business_units (id, unit_code, unit_name, description, tier, is_active)
  VALUES (v_id, UPPER(TRIM(p_unit_code)), TRIM(p_unit_name), p_description, 0, TRUE);
  INSERT INTO business_unit_modules (business_unit_id, module_code, is_enabled)
  SELECT v_id, module_code, FALSE FROM module_definitions
  ON CONFLICT (business_unit_id, module_code) DO NOTHING;
  INSERT INTO audit_log_owner (owner_nrp, action, target_type, target_id, new_value)
  VALUES ('OWNER001', 'CREATE_BU', 'business_unit', v_id, jsonb_build_object('unit_code', UPPER(TRIM(p_unit_code)), 'unit_name', TRIM(p_unit_name)));
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'BU created: ' || v_id, 'bu_id', v_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION owner_create_bu(TEXT, TEXT, TEXT) TO authenticated;

-- 10. BU MANAGEMENT: owner_update_bu
CREATE OR REPLACE FUNCTION owner_update_bu(
  p_bu_id TEXT,
  p_unit_name TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL,
  p_is_active BOOLEAN DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_old JSONB;
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Owner only.');
  END IF;
  SELECT row_to_json(bu) INTO v_old FROM business_units bu WHERE id = p_bu_id;
  IF v_old IS NULL THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'BU tidak ditemukan.');
  END IF;
  UPDATE business_units SET
    unit_name = COALESCE(p_unit_name, unit_name),
    description = COALESCE(p_description, description),
    is_active = COALESCE(p_is_active, is_active)
  WHERE id = p_bu_id;
  INSERT INTO audit_log_owner (owner_nrp, action, target_type, target_id, old_value, new_value)
  VALUES ('OWNER001', 'UPDATE_BU', 'business_unit', p_bu_id, v_old,
    jsonb_build_object('unit_name', p_unit_name, 'description', p_description, 'is_active', p_is_active));
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'BU updated: ' || p_bu_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION owner_update_bu(TEXT, TEXT, TEXT, BOOLEAN) TO authenticated;

-- 11. BU MANAGEMENT: owner_delete_bu
CREATE OR REPLACE FUNCTION owner_delete_bu(p_bu_id TEXT)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_emp_count INT;
  v_old JSONB;
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Owner only.');
  END IF;
  SELECT row_to_json(bu) INTO v_old FROM business_units bu WHERE id = p_bu_id;
  IF v_old IS NULL THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'BU tidak ditemukan.');
  END IF;
  SELECT COUNT(*) INTO v_emp_count FROM employees_master WHERE business_unit_id = p_bu_id;
  IF v_emp_count > 0 THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Tidak bisa hapus: ada ' || v_emp_count || ' karyawan di BU ini.');
  END IF;
  DELETE FROM business_unit_modules WHERE business_unit_id = p_bu_id;
  DELETE FROM business_units WHERE id = p_bu_id;
  INSERT INTO audit_log_owner (owner_nrp, action, target_type, target_id, old_value)
  VALUES ('OWNER001', 'DELETE_BU', 'business_unit', p_bu_id, v_old);
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'BU deleted: ' || p_bu_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION owner_delete_bu(TEXT) TO authenticated;

-- 12. SECURITY: owner_get_security_settings
CREATE OR REPLACE FUNCTION owner_get_security_settings()
RETURNS JSONB AS $$
DECLARE v_ctx JSONB := get_current_user_context();
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN '[]'::JSONB;
  END IF;
  RETURN (
    SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::JSONB)
    FROM (
      SELECT cc.config_key, cc.config_value, cc.data_type, cc.label, cc.description, cc.min_value, cc.max_value
      FROM company_config cc
      WHERE cc.category_id = 'security'
      ORDER BY cc.config_key
    ) t
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION owner_get_security_settings() TO authenticated;

-- INDEXES
CREATE INDEX IF NOT EXISTS idx_audit_log_owner_action ON audit_log_owner(action);
CREATE INDEX IF NOT EXISTS idx_audit_log_owner_created ON audit_log_owner(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_login_attempts_success ON login_attempts(success, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_session_tokens_expires_active ON session_tokens(expires_at);
