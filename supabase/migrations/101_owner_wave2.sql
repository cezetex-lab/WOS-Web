-- ============================================================
-- 101_owner_wave2.sql
-- Owner Dashboard Wave 2 — Employee, Announcements, Notifications, System Banner
-- ============================================================

-- 0. PRE-FLIGHT: Ensure new tables
CREATE TABLE IF NOT EXISTS notification_config (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
  event_type TEXT NOT NULL UNIQUE,
  label TEXT NOT NULL,
  email_enabled BOOLEAN DEFAULT FALSE,
  push_enabled BOOLEAN DEFAULT TRUE,
  template TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS system_announcements (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
  title TEXT NOT NULL,
  message TEXT,
  type TEXT DEFAULT 'info' CHECK (type IN ('info','warning','critical')),
  dismissible BOOLEAN DEFAULT TRUE,
  start_at TIMESTAMPTZ DEFAULT NOW(),
  end_at TIMESTAMPTZ,
  created_by TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed default notification configs
INSERT INTO notification_config (event_type, label) VALUES
  ('leave_request', 'Cuti Diajukan'),
  ('leave_approved', 'Cuti Disetujui'),
  ('leave_rejected', 'Cuti Ditolak'),
  ('overtime_request', 'Lembur Diajukan'),
  ('overtime_approved', 'Lembur Disetujui'),
  ('approval_needed', 'Menunggu Persetujuan'),
  ('announcement', 'Pengumuman Baru'),
  ('training_enrolled', 'Training Terdaftar'),
  ('kpi_updated', 'KPI Diperbarui'),
  ('payslip_ready', 'Slip Gaji Tersedia'),
  ('birthday', 'Ulang Tahun'),
  ('probation_expiring', 'Masa Percobaan Berakhir')
ON CONFLICT (event_type) DO NOTHING;

-- ============================================================
-- 1. EMPLOYEE MANAGEMENT: owner_get_employees
-- ============================================================
CREATE OR REPLACE FUNCTION owner_get_employees(
  p_bu_id TEXT DEFAULT NULL,
  p_search TEXT DEFAULT NULL,
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
  FROM employees_master em
  WHERE (p_bu_id IS NULL OR em.business_unit_id = p_bu_id)
    AND (p_search IS NULL OR em.nama ILIKE '%' || p_search || '%' OR em.nrp ILIKE '%' || p_search || '%' OR em.email ILIKE '%' || p_search || '%');
  SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::JSONB) INTO v_data
  FROM (
    SELECT em.employee_id, em.nrp, em.nama, em.email, em.divisi, em.posisi, em.status_kerja,
           em.business_unit_id, em.role_level, em.tanggal_masuk,
           bu.unit_name,
           ur.role, ur.role_level as ur_role_level
    FROM employees_master em
    LEFT JOIN business_units bu ON bu.id = em.business_unit_id
    LEFT JOIN user_roles ur ON ur.nrp = em.nrp
    WHERE (p_bu_id IS NULL OR em.business_unit_id = p_bu_id)
      AND (p_search IS NULL OR em.nama ILIKE '%' || p_search || '%' OR em.nrp ILIKE '%' || p_search || '%' OR em.email ILIKE '%' || p_search || '%')
    ORDER BY em.nrp
    LIMIT p_limit OFFSET p_offset
  ) t;
  RETURN jsonb_build_object('data', v_data, 'total', v_total);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION owner_get_employees(TEXT, TEXT, INT, INT) TO authenticated;

-- 2. EMPLOYEE MANAGEMENT: owner_create_employee
CREATE OR REPLACE FUNCTION owner_create_employee(
  p_nrp TEXT,
  p_nama TEXT,
  p_email TEXT DEFAULT NULL,
  p_divisi TEXT DEFAULT NULL,
  p_posisi TEXT DEFAULT NULL,
  p_bu_id TEXT DEFAULT NULL,
  p_status_kerja TEXT DEFAULT 'PKWTT',
  p_role TEXT DEFAULT 'worker',
  p_role_level INT DEFAULT 1
)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_emp_id TEXT;
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Owner only.');
  END IF;
  IF p_nrp IS NULL OR TRIM(p_nrp) = '' THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'NRP wajib diisi.');
  END IF;
  IF p_nama IS NULL OR TRIM(p_nama) = '' THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Nama wajib diisi.');
  END IF;
  IF EXISTS (SELECT 1 FROM employees_master WHERE nrp = TRIM(p_nrp)) THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'NRP sudah ada: ' || TRIM(p_nrp));
  END IF;
  v_emp_id := 'EMP' || LPAD((SELECT COALESCE(MAX(SUBSTRING(employee_id FROM 4)::INT), 0) + 1 FROM employees_master WHERE employee_id ~ '^EMP[0-9]+$')::TEXT, 4, '0');
  INSERT INTO employees_master (employee_id, nrp, nama, email, divisi, posisi, status_kerja, business_unit_id, role_level)
  VALUES (v_emp_id, TRIM(p_nrp), TRIM(p_nama), p_email, p_divisi, p_posisi, p_status_kerja, p_bu_id, p_role_level);
  INSERT INTO user_roles (nrp, role, role_level) VALUES (TRIM(p_nrp), p_role, p_role_level)
  ON CONFLICT (nrp) DO UPDATE SET role = p_role, role_level = p_role_level;
  INSERT INTO audit_log_owner (owner_nrp, action, target_type, target_id, new_value)
  VALUES ('OWNER001', 'CREATE_EMPLOYEE', 'employee', TRIM(p_nrp), jsonb_build_object('nama', TRIM(p_nama), 'bu_id', p_bu_id));
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'Employee created: ' || TRIM(p_nrp), 'employee_id', v_emp_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION owner_create_employee(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INT) TO authenticated;

-- 3. EMPLOYEE MANAGEMENT: owner_update_employee
CREATE OR REPLACE FUNCTION owner_update_employee(
  p_nrp TEXT,
  p_nama TEXT DEFAULT NULL,
  p_email TEXT DEFAULT NULL,
  p_divisi TEXT DEFAULT NULL,
  p_posisi TEXT DEFAULT NULL,
  p_bu_id TEXT DEFAULT NULL,
  p_status_kerja TEXT DEFAULT NULL,
  p_role TEXT DEFAULT NULL,
  p_role_level INT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_old JSONB;
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Owner only.');
  END IF;
  SELECT row_to_json(em) INTO v_old FROM employees_master em WHERE nrp = p_nrp;
  IF v_old IS NULL THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Employee tidak ditemukan.');
  END IF;
  UPDATE employees_master SET
    nama = COALESCE(p_nama, nama),
    email = COALESCE(p_email, email),
    divisi = COALESCE(p_divisi, divisi),
    posisi = COALESCE(p_posisi, posisi),
    business_unit_id = COALESCE(p_bu_id, business_unit_id),
    status_kerja = COALESCE(p_status_kerja, status_kerja),
    role_level = COALESCE(p_role_level, role_level),
    updated_at = NOW()
  WHERE nrp = p_nrp;
  IF p_role IS NOT NULL THEN
    INSERT INTO user_roles (nrp, role, role_level) VALUES (p_nrp, p_role, COALESCE(p_role_level, 1))
    ON CONFLICT (nrp) DO UPDATE SET role = p_role, role_level = COALESCE(p_role_level, user_roles.role_level);
  END IF;
  INSERT INTO audit_log_owner (owner_nrp, action, target_type, target_id, old_value, new_value)
  VALUES ('OWNER001', 'UPDATE_EMPLOYEE', 'employee', p_nrp, v_old,
    jsonb_build_object('nama', p_nama, 'divisi', p_divisi, 'posisi', p_posisi, 'bu_id', p_bu_id, 'role', p_role));
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'Employee updated: ' || p_nrp);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION owner_update_employee(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INT) TO authenticated;

-- 4. EMPLOYEE MANAGEMENT: owner_deactivate_employee
CREATE OR REPLACE FUNCTION owner_deactivate_employee(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_old JSONB;
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Owner only.');
  END IF;
  SELECT row_to_json(em) INTO v_old FROM employees_master em WHERE nrp = p_nrp;
  IF v_old IS NULL THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Employee tidak ditemukan.');
  END IF;
  UPDATE employees_master SET status_kerja = 'RESIGN', updated_at = NOW() WHERE nrp = p_nrp;
  INSERT INTO audit_log_owner (owner_nrp, action, target_type, target_id, old_value)
  VALUES ('OWNER001', 'DEACTIVATE_EMPLOYEE', 'employee', p_nrp, v_old);
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'Employee deactivated: ' || p_nrp);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION owner_deactivate_employee(TEXT) TO authenticated;

-- ============================================================
-- 5. ANNOUNCEMENTS: owner_create_announcement
-- ============================================================
CREATE OR REPLACE FUNCTION owner_create_announcement(
  p_title TEXT,
  p_message TEXT DEFAULT NULL,
  p_priority TEXT DEFAULT 'NORMAL',
  p_target_audience TEXT DEFAULT 'ALL',
  p_expiry_date DATE DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_id TEXT;
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Owner only.');
  END IF;
  IF p_title IS NULL OR TRIM(p_title) = '' THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Title wajib diisi.');
  END IF;
  v_id := 'ANN' || LPAD((SELECT COALESCE(MAX(SUBSTRING(id FROM 4)::INT), 0) + 1 FROM announcements WHERE id ~ '^ANN[0-9]+$')::TEXT, 4, '0');
  INSERT INTO announcements (id, title, message, priority, target_audience, expiry_date, created_by)
  VALUES (v_id, TRIM(p_title), p_message, p_priority, p_target_audience, p_expiry_date, 'OWNER001');
  INSERT INTO audit_log_owner (owner_nrp, action, target_type, target_id, new_value)
  VALUES ('OWNER001', 'CREATE_ANNOUNCEMENT', 'announcement', v_id, jsonb_build_object('title', TRIM(p_title), 'priority', p_priority));
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'Announcement created: ' || v_id, 'id', v_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION owner_create_announcement(TEXT, TEXT, TEXT, TEXT, DATE) TO authenticated;

-- 6. ANNOUNCEMENTS: owner_get_announcements
CREATE OR REPLACE FUNCTION owner_get_announcements()
RETURNS JSONB AS $$
DECLARE v_ctx JSONB := get_current_user_context();
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN '[]'::JSONB;
  END IF;
  RETURN (
    SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::JSONB)
    FROM (
      SELECT id, title, message, priority, target_audience, expiry_date, created_by, created_at
      FROM announcements ORDER BY created_at DESC
    ) t
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION owner_get_announcements() TO authenticated;

-- 7. ANNOUNCEMENTS: owner_delete_announcement
CREATE OR REPLACE FUNCTION owner_delete_announcement(p_id TEXT)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_old JSONB;
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Owner only.');
  END IF;
  SELECT row_to_json(a) INTO v_old FROM announcements a WHERE id = p_id;
  IF v_old IS NULL THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Announcement tidak ditemukan.');
  END IF;
  DELETE FROM announcements WHERE id = p_id;
  INSERT INTO audit_log_owner (owner_nrp, action, target_type, target_id, old_value)
  VALUES ('OWNER001', 'DELETE_ANNOUNCEMENT', 'announcement', p_id, v_old);
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'Announcement deleted: ' || p_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION owner_delete_announcement(TEXT) TO authenticated;

-- ============================================================
-- 8. NOTIFICATION CONFIG: get_notification_config
-- ============================================================
CREATE OR REPLACE FUNCTION get_notification_config()
RETURNS JSONB AS $$
DECLARE v_ctx JSONB := get_current_user_context();
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN '[]'::JSONB;
  END IF;
  RETURN (
    SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::JSONB)
    FROM (
      SELECT id, event_type, label, email_enabled, push_enabled, template, updated_at
      FROM notification_config ORDER BY event_type
    ) t
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_notification_config() TO authenticated;

-- 9. NOTIFICATION CONFIG: update_notification_config
CREATE OR REPLACE FUNCTION update_notification_config(p_id TEXT, p_email_enabled BOOLEAN DEFAULT NULL, p_push_enabled BOOLEAN DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_old JSONB;
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Owner only.');
  END IF;
  SELECT row_to_json(nc) INTO v_old FROM notification_config nc WHERE id = p_id;
  IF v_old IS NULL THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Config tidak ditemukan.');
  END IF;
  UPDATE notification_config SET
    email_enabled = COALESCE(p_email_enabled, email_enabled),
    push_enabled = COALESCE(p_push_enabled, push_enabled),
    updated_at = NOW()
  WHERE id = p_id;
  INSERT INTO audit_log_owner (owner_nrp, action, target_type, target_id, old_value, new_value)
  VALUES ('OWNER001', 'UPDATE_NOTIFICATION', 'notification_config', p_id, v_old,
    jsonb_build_object('email_enabled', p_email_enabled, 'push_enabled', p_push_enabled));
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'Notification config updated.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION update_notification_config(TEXT, BOOLEAN, BOOLEAN) TO authenticated;

-- ============================================================
-- 10. SYSTEM ANNOUNCEMENTS: owner_create_system_announcement
-- ============================================================
CREATE OR REPLACE FUNCTION owner_create_system_announcement(
  p_title TEXT,
  p_message TEXT DEFAULT NULL,
  p_type TEXT DEFAULT 'info',
  p_dismissible BOOLEAN DEFAULT TRUE,
  p_end_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_id TEXT;
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Owner only.');
  END IF;
  IF p_title IS NULL OR TRIM(p_title) = '' THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Title wajib diisi.');
  END IF;
  v_id := 'SYSANN' || LPAD((SELECT COALESCE(MAX(SUBSTRING(id FROM 7)::INT), 0) + 1 FROM system_announcements WHERE id ~ '^SYSANN[0-9]+$')::TEXT, 4, '0');
  INSERT INTO system_announcements (id, title, message, type, dismissible, end_at, created_by)
  VALUES (v_id, TRIM(p_title), p_message, p_type, p_dismissible, p_end_at, 'OWNER001');
  INSERT INTO audit_log_owner (owner_nrp, action, target_type, target_id, new_value)
  VALUES ('OWNER001', 'CREATE_SYSTEM_ANNOUNCEMENT', 'system_announcement', v_id, jsonb_build_object('title', TRIM(p_title), 'type', p_type));
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'System announcement created: ' || v_id, 'id', v_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION owner_create_system_announcement(TEXT, TEXT, TEXT, BOOLEAN, TIMESTAMPTZ) TO authenticated;

-- 11. SYSTEM ANNOUNCEMENTS: get_active_system_announcements (public)
CREATE OR REPLACE FUNCTION get_active_system_announcements()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::JSONB)
    FROM (
      SELECT id, title, message, type, dismissible, created_at
      FROM system_announcements
      WHERE start_at <= NOW() AND (end_at IS NULL OR end_at >= NOW())
      ORDER BY
        CASE type WHEN 'critical' THEN 1 WHEN 'warning' THEN 2 ELSE 3 END,
        created_at DESC
    ) t
  );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_active_system_announcements() TO authenticated;

-- 12. SYSTEM ANNOUNCEMENTS: owner_get_system_announcements
CREATE OR REPLACE FUNCTION owner_get_system_announcements()
RETURNS JSONB AS $$
DECLARE v_ctx JSONB := get_current_user_context();
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN '[]'::JSONB;
  END IF;
  RETURN (
    SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::JSONB)
    FROM (
      SELECT id, title, message, type, dismissible, start_at, end_at, created_by, created_at
      FROM system_announcements ORDER BY created_at DESC
    ) t
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION owner_get_system_announcements() TO authenticated;

-- 13. SYSTEM ANNOUNCEMENTS: owner_delete_system_announcement
CREATE OR REPLACE FUNCTION owner_delete_system_announcement(p_id TEXT)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_old JSONB;
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Owner only.');
  END IF;
  SELECT row_to_json(sa) INTO v_old FROM system_announcements sa WHERE id = p_id;
  IF v_old IS NULL THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Announcement tidak ditemukan.');
  END IF;
  DELETE FROM system_announcements WHERE id = p_id;
  INSERT INTO audit_log_owner (owner_nrp, action, target_type, target_id, old_value)
  VALUES ('OWNER001', 'DELETE_SYSTEM_ANNOUNCEMENT', 'system_announcement', p_id, v_old);
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'System announcement deleted: ' || p_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION owner_delete_system_announcement(TEXT) TO authenticated;

-- INDEXES
CREATE INDEX IF NOT EXISTS idx_system_announcements_active ON system_announcements(start_at, end_at);
CREATE INDEX IF NOT EXISTS idx_notification_config_event ON notification_config(event_type);
