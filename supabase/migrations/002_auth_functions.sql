-- ============================================================
-- 002_auth_functions.sql (FIXED — snake_case columns)
-- RPC functions for login, profile, session management
-- Run in Supabase SQL Editor AFTER 001_init.sql
-- ============================================================

-- 1. WORKER LOGIN (NRP + Password)
CREATE OR REPLACE FUNCTION login_worker(p_nrp TEXT, p_password TEXT)
RETURNS JSONB AS $$
DECLARE
  v_worker RECORD;
  v_role RECORD;
  v_hash TEXT;
  v_salt TEXT;
  v_computed TEXT;
BEGIN
  -- Find worker password
  SELECT * INTO v_worker
  FROM worker_passwords
  WHERE nrp = p_nrp AND is_active = true;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'NRP tidak ditemukan atau tidak aktif.');
  END IF;
  
  -- Check if blocked
  IF v_worker.blocked_until IS NOT NULL AND v_worker.blocked_until > NOW() THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akun terkunci. Coba lagi nanti.');
  END IF;
  
  v_salt := v_worker.salt;
  v_hash := v_worker.password_hash;
  
  -- If no salt/hash (legacy), use plain compare
  IF v_salt IS NULL OR v_salt = '' OR v_hash IS NULL OR v_hash = '' THEN
    IF p_password = v_worker.password_hash THEN
      v_salt := encode(gen_random_bytes(8), 'hex');
      v_computed := encode(digest(p_password || v_salt, 'sha256'), 'hex');
      UPDATE worker_passwords 
      SET password_hash = v_computed, salt = v_salt, attempts = 0, blocked_until = NULL
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
    -- Hashed password check
    v_computed := encode(digest(p_password || v_salt, 'sha256'), 'hex');
    IF v_computed != v_hash THEN
      UPDATE worker_passwords SET attempts = attempts + 1 WHERE nrp = p_nrp;
      IF v_worker.attempts + 1 >= 5 THEN
        UPDATE worker_passwords SET blocked_until = NOW() + INTERVAL '15 minutes' WHERE nrp = p_nrp;
        RETURN jsonb_build_object('ok', false, 'msg', 'Terlalu banyak percobaan. Akun dikunci 15 menit.');
      END IF;
      RETURN jsonb_build_object('ok', false, 'msg', 'Password salah.');
    END IF;
    UPDATE worker_passwords SET attempts = 0, blocked_until = NULL WHERE nrp = p_nrp;
  END IF;
  
  -- Get role/level
  SELECT * INTO v_role FROM user_roles WHERE nrp = p_nrp;
  
  -- Get employee info
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


-- 2. ADMIN LOGIN (Password only)
CREATE OR REPLACE FUNCTION login_admin(p_password TEXT)
RETURNS JSONB AS $$
DECLARE
  v_stored TEXT;
BEGIN
  SELECT value INTO v_stored FROM settings WHERE key = 'admin_password';
  IF NOT FOUND THEN
    v_stored := 'Admin123';
  END IF;
  
  IF p_password = v_stored THEN
    RETURN jsonb_build_object(
      'ok', true,
      'token', encode(gen_random_bytes(16), 'hex'),
      'role', 'admin'
    );
  ELSE
    RETURN jsonb_build_object('ok', false, 'msg', 'Password admin salah.');
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3. GET WORKER PROFILE
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


-- 4. GET ANNOUNCEMENTS
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
    WHERE (expires_at IS NULL OR expires_at > NOW())
    LIMIT 10
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 5. GET WORKER STATUS (KPI, Attendance)
CREATE OR REPLACE FUNCTION get_worker_status(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE
  v_kpi RECORD;
  v_attendance RECORD;
BEGIN
  SELECT * INTO v_kpi 
  FROM hr_performance 
  WHERE nrp = p_nrp 
  ORDER BY period DESC LIMIT 1;
  
  SELECT 
    COUNT(*) FILTER (WHERE status = 'Hadir') as hadir,
    COUNT(*) FILTER (WHERE status = 'Telat') as telat,
    COUNT(*) FILTER (WHERE status IN ('Izin', 'Sakit')) as izin,
    COUNT(*) as total
  INTO v_attendance
  FROM hr_attendance
  WHERE nrp = p_nrp 
  AND date >= date_trunc('month', NOW())
  AND date < date_trunc('month', NOW()) + INTERVAL '1 month';
  
  RETURN jsonb_build_object(
    'ok', true,
    'kpi_score', COALESCE(v_kpi.kpi_score, 0),
    'kpi_period', COALESCE(v_kpi.period, ''),
    'attendance_hadir', COALESCE(v_attendance.hadir, 0),
    'attendance_telat', COALESCE(v_attendance.telat, 0),
    'attendance_izin', COALESCE(v_attendance.izin, 0),
    'attendance_total', COALESCE(v_attendance.total, 0)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 6. GET WORKER REQUESTS
CREATE OR REPLACE FUNCTION get_worker_requests(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object(
      'ok', true,
      'data', COALESCE(jsonb_agg(
        jsonb_build_object(
          'id', id,
          'type', request_type,
          'status', status,
          'reason', reason,
          'start_date', start_date,
          'end_date', end_date,
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


-- 7. CREATE REQUEST
CREATE OR REPLACE FUNCTION create_worker_request(
  p_nrp TEXT,
  p_type TEXT,
  p_reason TEXT,
  p_start_date DATE,
  p_end_date DATE
)
RETURNS JSONB AS $$
BEGIN
  INSERT INTO hr_requests (nrp, request_type, status, reason, start_date, end_date)
  VALUES (p_nrp, p_type, 'Pending', p_reason, p_start_date, p_end_date);
  
  RETURN jsonb_build_object('ok', true, 'msg', 'Request berhasil dikirim.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 8. ADMIN GET SUMMARY
CREATE OR REPLACE FUNCTION admin_get_summary()
RETURNS JSONB AS $$
BEGIN
  RETURN jsonb_build_object(
    'ok', true,
    'total_workers', (SELECT COUNT(*) FROM employees_master),
    'total_divisions', (SELECT COUNT(DISTINCT divisi) FROM employees_master),
    'pending_requests', (SELECT COUNT(*) FROM hr_requests WHERE status = 'Pending'),
    'pending_registrations', (SELECT COUNT(*) FROM daftar_baru WHERE status = 'Pending'),
    'total_announcements', (SELECT COUNT(*) FROM announcements)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 9. ADMIN GET PENDING REGISTRATIONS
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
        ORDER BY created_at ASC
      ), '[]'::jsonb)
    )
    FROM daftar_baru
    WHERE status = 'Pending'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 10. ADMIN APPROVE REGISTRATION
CREATE OR REPLACE FUNCTION admin_approve_pending(p_id INT)
RETURNS JSONB AS $$
DECLARE
  v_entry RECORD;
BEGIN
  SELECT * INTO v_entry FROM daftar_baru WHERE id = p_id AND status = 'Pending';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Entry tidak ditemukan atau sudah diproses.');
  END IF;
  
  INSERT INTO employees_master (nrp, nik, nama, email, status_kerja)
  VALUES (v_entry.nrp, v_entry.nik, v_entry.nama, v_entry.email, 'Active')
  ON CONFLICT (nrp) DO NOTHING;
  
  INSERT INTO worker_passwords (nrp, password_hash, salt, is_active)
  VALUES (v_entry.nrp, 'pending', '', true)
  ON CONFLICT (nrp) DO NOTHING;
  
  INSERT INTO user_roles (nrp, role_level, plan)
  VALUES (v_entry.nrp, 1, 'FREE')
  ON CONFLICT (nrp) DO NOTHING;
  
  UPDATE daftar_baru SET status = 'Approved' WHERE id = p_id;
  
  RETURN jsonb_build_object('ok', true, 'msg', 'Pendaftaran disetujui.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 11. ADMIN REJECT REGISTRATION
CREATE OR REPLACE FUNCTION admin_reject_pending(p_id INT, p_reason TEXT)
RETURNS JSONB AS $$
BEGIN
  UPDATE daftar_baru SET status = 'Rejected', notes = p_reason WHERE id = p_id AND status = 'Pending';
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'msg', 'Pendaftaran ditolak.');
  ELSE
    RETURN jsonb_build_object('ok', false, 'msg', 'Entry tidak ditemukan.');
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 12. ADMIN GET AUDIT LOG
CREATE OR REPLACE FUNCTION admin_get_audit_log()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object(
      'ok', true,
      'data', COALESCE(jsonb_agg(
        jsonb_build_object(
          'action', action,
          'result', result,
          'message', message,
          'created_at', created_at
        )
        ORDER BY created_at DESC
      ), '[]'::jsonb)
    )
    FROM audit_log
    LIMIT 50
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
