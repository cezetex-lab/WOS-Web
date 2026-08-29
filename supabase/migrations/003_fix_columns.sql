-- ============================================================
-- 003_fix_columns.sql
-- Fix column name mismatches + add plan column to user_roles
-- Run in Supabase SQL Editor AFTER 001_init.sql
-- (skip 002 — this replaces it entirely)
-- ============================================================

-- 1. Add plan column to user_roles
ALTER TABLE user_roles ADD COLUMN IF NOT EXISTS plan TEXT DEFAULT 'FREE';
UPDATE user_roles SET plan = 'FREE' WHERE plan IS NULL;

-- 2. Drop old functions if they exist
DROP FUNCTION IF EXISTS login_worker(TEXT, TEXT);
DROP FUNCTION IF EXISTS login_admin(TEXT);
DROP FUNCTION IF EXISTS get_worker_profile(TEXT);
DROP FUNCTION IF EXISTS get_worker_status(TEXT);
DROP FUNCTION IF EXISTS get_worker_requests(TEXT);
DROP FUNCTION IF EXISTS create_worker_request(TEXT, TEXT, TEXT, DATE, DATE);
DROP FUNCTION IF EXISTS get_announcements();
DROP FUNCTION IF EXISTS admin_get_summary();
DROP FUNCTION IF EXISTS admin_get_pending();
DROP FUNCTION IF EXISTS admin_approve_pending(INT);
DROP FUNCTION IF EXISTS admin_reject_pending(INT, TEXT);
DROP FUNCTION IF EXISTS admin_get_audit_log();


-- ============================================================
-- LOGIN WORKER
-- ============================================================
CREATE OR REPLACE FUNCTION login_worker(p_nrp TEXT, p_password TEXT)
RETURNS JSONB AS $$
DECLARE
  v_worker RECORD;
  v_role RECORD;
  v_computed TEXT;
BEGIN
  SELECT * INTO v_worker FROM worker_passwords WHERE nrp = p_nrp AND is_active = true;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'NRP tidak ditemukan atau tidak aktif.');
  END IF;

  IF v_worker.blocked_until IS NOT NULL AND v_worker.blocked_until > NOW() THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akun terkunci. Coba lagi nanti.');
  END IF;

  IF v_worker.salt IS NULL OR v_worker.salt = '' OR v_worker.password_hash IS NULL OR v_worker.password_hash = '' THEN
    -- Legacy plain text
    IF p_password = v_worker.password_hash THEN
      UPDATE worker_passwords
      SET password_hash = encode(digest(p_password || encode(gen_random_bytes(8),'hex'), 'sha256'), 'hex'),
          salt = encode(gen_random_bytes(8), 'hex'),
          attempts = 0, blocked_until = NULL
      WHERE nrp = p_nrp;
    ELSE
      UPDATE worker_passwords SET attempts = attempts + 1 WHERE nrp = p_nrp;
      IF v_worker.attempts + 1 >= 5 THEN
        UPDATE worker_passwords SET blocked_until = NOW() + INTERVAL '15 minutes' WHERE nrp = p_nrp;
        RETURN jsonb_build_object('ok', false, 'msg', 'Terlalu banyak percobaan. Akun dikunci 15 menit.');
      END IF;
      RETURN jsonb_build_object('ok', false, 'msg', 'Password salah.');
    END IF;
  ELSE
    v_computed := encode(digest(p_password || v_worker.salt, 'sha256'), 'hex');
    IF v_computed != v_worker.password_hash THEN
      UPDATE worker_passwords SET attempts = attempts + 1 WHERE nrp = p_nrp;
      IF v_worker.attempts + 1 >= 5 THEN
        UPDATE worker_passwords SET blocked_until = NOW() + INTERVAL '15 minutes' WHERE nrp = p_nrp;
        RETURN jsonb_build_object('ok', false, 'msg', 'Terlalu banyak percobaan. Akun dikunci 15 menit.');
      END IF;
      RETURN jsonb_build_object('ok', false, 'msg', 'Password salah.');
    END IF;
    UPDATE worker_passwords SET attempts = 0, blocked_until = NULL WHERE nrp = p_nrp;
  END IF;

  SELECT * INTO v_role FROM user_roles WHERE nrp = p_nrp;

  RETURN jsonb_build_object(
    'ok', true,
    'nrp', p_nrp,
    'nama', (SELECT nama FROM employees_master WHERE nrp = p_nrp LIMIT 1),
    'level', COALESCE(v_role.role_level, 1),
    'tier', COALESCE(v_role.plan, 'FREE'),
    'position', (SELECT posisi FROM employees_master WHERE nrp = p_nrp LIMIT 1),
    'divisi', (SELECT divisi FROM employees_master WHERE nrp = p_nrp LIMIT 1)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- LOGIN ADMIN
-- ============================================================
CREATE OR REPLACE FUNCTION login_admin(p_password TEXT)
RETURNS JSONB AS $$
DECLARE
  v_stored TEXT;
BEGIN
  SELECT value INTO v_stored FROM settings WHERE key = 'admin_password';
  IF NOT FOUND THEN v_stored := 'Admin123'; END IF;

  IF p_password = v_stored THEN
    RETURN jsonb_build_object('ok', true, 'token', encode(gen_random_bytes(16), 'hex'), 'role', 'admin');
  ELSE
    RETURN jsonb_build_object('ok', false, 'msg', 'Password admin salah.');
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- WORKER PROFILE
-- ============================================================
CREATE OR REPLACE FUNCTION get_worker_profile(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE
  v_emp RECORD;
  v_role RECORD;
BEGIN
  SELECT * INTO v_emp FROM employees_master WHERE nrp = p_nrp;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Pekerja tidak ditemukan.');
  END IF;
  SELECT * INTO v_role FROM user_roles WHERE nrp = p_nrp;

  RETURN jsonb_build_object(
    'ok', true,
    'nrp', v_emp.nrp,
    'nama', v_emp.nama,
    'nik', v_emp.nik,
    'email', v_emp.email,
    'divisi', v_emp.divisi,
    'posisi', v_emp.posisi,
    'level', COALESCE(v_role.role_level, 1),
    'tier', COALESCE(v_role.plan, 'FREE'),
    'tanggal_lahir', v_emp.tanggal_lahir,
    'jenis_kelamin', v_emp.jenis_kelamin,
    'status_kerja', v_emp.status_kerja,
    'tanggal_mulai', v_emp.tanggal_masuk,
    'no_hp', v_emp.no_hp
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- ANNOUNCEMENTS
-- ============================================================
CREATE OR REPLACE FUNCTION get_announcements()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object(
      'ok', true,
      'data', COALESCE(jsonb_agg(
        jsonb_build_object(
          'id', id,
          'title', title,
          'message', message,
          'priority', priority,
          'target_audience', target_audience,
          'created_at', created_at
        )
        ORDER BY
          CASE priority WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 ELSE 4 END,
          created_at DESC
      ), '[]'::jsonb)
    )
    FROM announcements
    WHERE (expiry_date IS NULL OR expiry_date > NOW())
    LIMIT 10
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- WORKER STATUS (KPI + Attendance)
-- ============================================================
CREATE OR REPLACE FUNCTION get_worker_status(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE
  v_kpi RECORD;
  v_att RECORD;
BEGIN
  SELECT * INTO v_kpi FROM hr_performance WHERE nrp = p_nrp ORDER BY periode DESC LIMIT 1;

  SELECT
    COUNT(*) FILTER (WHERE status_hadir = 'Hadir') as hadir,
    COUNT(*) FILTER (WHERE status_hadir = 'Telat') as telat,
    COUNT(*) FILTER (WHERE status_hadir IN ('Izin','Sakit')) as izin,
    COUNT(*) as total
  INTO v_att
  FROM hr_attendance
  WHERE nrp = p_nrp
    AND date >= date_trunc('month', NOW())
    AND date < date_trunc('month', NOW()) + INTERVAL '1 month';

  RETURN jsonb_build_object(
    'ok', true,
    'kpi_score', COALESCE(v_kpi.kpi_score, 0),
    'kpi_period', COALESCE(v_kpi.periode, ''),
    'attendance_hadir', COALESCE(v_att.hadir, 0),
    'attendance_telat', COALESCE(v_att.telat, 0),
    'attendance_izin', COALESCE(v_att.izin, 0),
    'attendance_total', COALESCE(v_att.total, 0)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- WORKER REQUESTS
-- ============================================================
CREATE OR REPLACE FUNCTION get_worker_requests(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object(
      'ok', true,
      'data', COALESCE(jsonb_agg(
        jsonb_build_object(
          'id', id,
          'type', type,
          'status', status,
          'note', note,
          'created_at', created_at
        )
        ORDER BY created_at DESC
      ), '[]'::jsonb)
    )
    FROM hr_requests
    WHERE nrp = p_nrp
    LIMIT 20
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- CREATE REQUEST
-- ============================================================
CREATE OR REPLACE FUNCTION create_worker_request(
  p_nrp TEXT, p_type TEXT, p_reason TEXT, p_start_date DATE, p_end_date DATE
)
RETURNS JSONB AS $$
BEGIN
  INSERT INTO hr_requests (id, nrp, type, status, note)
  VALUES (encode(gen_random_bytes(8),'hex'), p_nrp, p_type, 'Pending', p_reason);
  RETURN jsonb_build_object('ok', true, 'msg', 'Request berhasil dikirim.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- ADMIN SUMMARY
-- ============================================================
CREATE OR REPLACE FUNCTION admin_get_summary()
RETURNS JSONB AS $$
BEGIN
  RETURN jsonb_build_object(
    'ok', true,
    'total_workers', (SELECT COUNT(*) FROM employees_master),
    'total_divisions', (SELECT COUNT(DISTINCT divisi) FROM employees_master),
    'pending_requests', (SELECT COUNT(*) FROM hr_requests WHERE status = 'Pending'),
    'pending_registrations', (SELECT COUNT(*) FROM daftar_baru WHERE status = 'PENDING'),
    'total_announcements', (SELECT COUNT(*) FROM announcements)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- ADMIN PENDING REGISTRATIONS
-- ============================================================
CREATE OR REPLACE FUNCTION admin_get_pending()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object(
      'ok', true,
      'data', COALESCE(jsonb_agg(
        jsonb_build_object(
          'id', id,
          'nrp', nrp,
          'nik', nik,
          'nama', nama,
          'email', email,
          'status', status,
          'created_at', created_at
        )
      ), '[]'::jsonb)
    )
    FROM daftar_baru
    WHERE status = 'PENDING'
    ORDER BY created_at ASC
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- ADMIN APPROVE
-- ============================================================
CREATE OR REPLACE FUNCTION admin_approve_pending(p_id INT)
RETURNS JSONB AS $$
DECLARE
  v_entry RECORD;
BEGIN
  SELECT * INTO v_entry FROM daftar_baru WHERE id = p_id AND status = 'PENDING';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Entry tidak ditemukan atau sudah diproses.');
  END IF;

  INSERT INTO employees_master (employee_id, nrp, nik, nama, email, status_kerja)
  VALUES ('EMP' || p_id, v_entry.nrp, v_entry.nik, v_entry.nama, v_entry.email, 'Active')
  ON CONFLICT (nrp) DO NOTHING;

  INSERT INTO worker_passwords (nrp, password_hash, salt, is_active)
  VALUES (v_entry.nrp, COALESCE(v_entry.password_hash, 'pending'), COALESCE(v_entry.salt, ''), true)
  ON CONFLICT (nrp) DO NOTHING;

  INSERT INTO user_roles (nrp, role_level, plan)
  VALUES (v_entry.nrp, 1, 'FREE')
  ON CONFLICT (nrp) DO NOTHING;

  UPDATE daftar_baru SET status = 'APPROVED' WHERE id = p_id;
  RETURN jsonb_build_object('ok', true, 'msg', 'Pendaftaran disetujui.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- ADMIN REJECT
-- ============================================================
CREATE OR REPLACE FUNCTION admin_reject_pending(p_id INT, p_reason TEXT)
RETURNS JSONB AS $$
BEGIN
  UPDATE daftar_baru SET status = 'REJECTED' WHERE id = p_id AND status = 'PENDING';
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'msg', 'Pendaftaran ditolak.');
  ELSE
    RETURN jsonb_build_object('ok', false, 'msg', 'Entry tidak ditemukan.');
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- ADMIN AUDIT LOG
-- ============================================================
CREATE OR REPLACE FUNCTION admin_get_audit_log()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object(
      'ok', true,
      'data', COALESCE(jsonb_agg(
        jsonb_build_object(
          'action', action,
          'result', 'OK',
          'message', detail,
          'created_at', timestamp
        )
        ORDER BY timestamp DESC
      ), '[]'::jsonb)
    )
    FROM audit_log
    LIMIT 50
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
