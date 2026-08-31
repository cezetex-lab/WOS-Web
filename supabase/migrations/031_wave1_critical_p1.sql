-- ============================================================
-- 031_wave1_critical_p1.sql
-- Wave 1: Fix 4 Critical P1 Features
-- Run in Supabase SQL Editor after 027+028+030
-- ============================================================

-- ============================================================
-- 1. #120 — Ubah Password Admin
-- ============================================================

-- Admin password stored in settings table (not worker_passwords due to FK constraint)
-- Initialize default admin password if not exists
INSERT INTO settings (key, value) VALUES ('admin_password', 'Admin123')
ON CONFLICT (key) DO NOTHING;

-- Function: Ubah password admin
DROP FUNCTION IF EXISTS admin_change_password(text, text) CASCADE;
CREATE OR REPLACE FUNCTION admin_change_password(p_old_password TEXT, p_new_password TEXT) RETURNS JSONB AS $$
DECLARE v_stored TEXT;
BEGIN
  -- Check settings table first, fallback to hardcoded
  SELECT value INTO v_stored FROM settings WHERE key = 'admin_password';
  IF v_stored IS NULL THEN v_stored := 'Admin123'; END IF;

  -- Cek password lama
  IF p_old_password != v_stored THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Password lama salah');
  END IF;

  -- Validasi password baru
  IF length(p_new_password) < 8 THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Password baru minimal 8 karakter');
  END IF;

  -- Update di settings (simpan sebagai plain untuk admin)
  INSERT INTO settings (key, value) VALUES ('admin_password', p_new_password)
  ON CONFLICT (key) DO UPDATE SET value = p_new_password;

  -- Log
  INSERT INTO audit_log (actor, action, detail) VALUES ('admin', 'CHANGE_PASSWORD', 'Admin changed password');

  RETURN jsonb_build_object('ok', true, 'msg', 'Password berhasil diubah. Gunakan password baru untuk login selanjutnya.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 2. #111 — Reset Password Pekerja
-- ============================================================

DROP FUNCTION IF EXISTS admin_reset_worker_password(text, text) CASCADE;
CREATE OR REPLACE FUNCTION admin_reset_worker_password(p_nrp TEXT, p_new_password TEXT) RETURNS JSONB AS $$
DECLARE v_emp RECORD;
BEGIN
  -- Cek employee exists
  SELECT * INTO v_emp FROM employees_master WHERE nrp = p_nrp;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Karyawan dengan NRP ' || p_nrp || ' tidak ditemukan');
  END IF;

  -- Validasi
  IF length(p_new_password) < 8 THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Password baru minimal 8 karakter');
  END IF;

  -- Update password (plain text untuk simplicity, production should hash)
  INSERT INTO worker_passwords (nrp, password_hash, salt, is_active, updated_at)
  VALUES (p_nrp, p_new_password, 'admin_reset', true, NOW())
  ON CONFLICT (nrp) DO UPDATE SET
    password_hash = p_new_password,
    salt = 'admin_reset',
    is_active = true,
    attempts = 0,
    blocked_until = NULL,
    updated_at = NOW();

  -- Log
  INSERT INTO audit_log (actor, action, detail)
  VALUES ('admin', 'RESET_PASSWORD', 'Reset password for ' || p_nrp);

  RETURN jsonb_build_object('ok', true, 'msg', 'Password ' || p_nrp || ' berhasil direset. Password baru: ' || p_new_password);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 3. #18 — PKWT Expiry Alert
-- ============================================================

DROP FUNCTION IF EXISTS get_pkwt_expiry_alert() CASCADE;
CREATE OR REPLACE FUNCTION get_pkwt_expiry_alert() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
    jsonb_build_object(
      'nrp', nrp,
      'nama', nama,
      'posisi', posisi,
      'divisi', divisi,
      'tanggal_masuk', tanggal_masuk,
      'status_kerja', status_kerja,
      'expiry_date', (tanggal_masuk + interval '2 year')::date,
      'days_remaining', EXTRACT(DAY FROM (tanggal_masuk + interval '2 year')::timestamp - NOW())::int,
      'risk_level', CASE
        WHEN (tanggal_masuk + interval '2 year')::date < NOW() THEN 'EXPIRED'
        WHEN (tanggal_masuk + interval '2 year')::date < NOW() + interval '30 days' THEN 'CRITICAL'
        WHEN (tanggal_masuk + interval '2 year')::date < NOW() + interval '90 days' THEN 'WARNING'
        ELSE 'OK'
      END
    )
    ORDER BY (tanggal_masuk + interval '2 year')::date ASC
  ), '[]'::jsonb))
  FROM employees_master
  WHERE status_kerja = 'PKWT'
  ORDER BY (tanggal_masuk + interval '2 year')::date ASC); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 4. #138 — Nonaktifkan Akses Sistem
-- ============================================================

DROP FUNCTION IF EXISTS admin_deactivate_worker(text) CASCADE;
CREATE OR REPLACE FUNCTION admin_deactivate_worker(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v_emp RECORD;
BEGIN
  -- Cek employee
  SELECT * INTO v_emp FROM employees_master WHERE nrp = p_nrp;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Karyawan tidak ditemukan');
  END IF;

  -- Disable password
  UPDATE worker_passwords SET is_active = false WHERE nrp = p_nrp;

  -- Log
  INSERT INTO audit_log (actor, action, detail)
  VALUES ('admin', 'DEACTIVATE_WORKER', 'Deactivated ' || p_nrp || ' (' || v_emp.nama || ')');

  RETURN jsonb_build_object('ok', true, 'msg', 'Akses ' || p_nrp || ' (' || v_emp.nama || ') berhasil dinonaktifkan');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 5. Auto-deactivate expired PKWT (pg_cron)
-- ============================================================

-- Fungsi untuk auto-deactivate PKWT yang sudah expired
DROP FUNCTION IF EXISTS auto_deactivate_expired_pkwt() CASCADE;
CREATE OR REPLACE FUNCTION auto_deactivate_expired_pkwt() RETURNS void AS $$
BEGIN
  -- Deactivate PKWT yang sudah expired (2 tahun dari tanggal masuk)
  UPDATE worker_passwords
  SET is_active = false, updated_at = NOW()
  WHERE nrp IN (
    SELECT nrp FROM employees_master
    WHERE status_kerja = 'PKWT'
    AND (tanggal_masuk + interval '2 year')::date < NOW()
  )
  AND is_active = true;

  -- Log
  INSERT INTO audit_log (actor, action, detail)
  SELECT 'SYSTEM', 'AUTO_DEACTIVATE_PKWT', 'Auto-deactivated ' || nrp || ' (expired PKWT)'
  FROM employees_master
  WHERE status_kerja = 'PKWT'
  AND (tanggal_masuk + interval '2 year')::date < NOW()
  AND nrp IN (SELECT nrp FROM worker_passwords WHERE is_active = true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 6. Dashboard summary — tambah PKWT count
-- ============================================================

DROP FUNCTION IF EXISTS admin_get_summary() CASCADE;
CREATE OR REPLACE FUNCTION admin_get_summary() RETURNS JSONB AS $$ BEGIN RETURN jsonb_build_object('ok', true,
  'total_workers', (SELECT COUNT(*) FROM employees_master),
  'total_divisions', (SELECT COUNT(DISTINCT divisi) FROM employees_master WHERE divisi IS NOT NULL),
  'pending_requests', (SELECT COUNT(*) FROM hr_requests WHERE status = 'Pending'),
  'pkwtt_count', (SELECT COUNT(*) FROM employees_master WHERE status_kerja = 'PKWTT'),
  'pkwt_count', (SELECT COUNT(*) FROM employees_master WHERE status_kerja = 'PKWT'),
  'retiring_soon', (SELECT COUNT(*) FROM employees_master
    WHERE status_kerja = 'PKWT'
    AND (tanggal_masuk + interval '2 year')::date BETWEEN NOW() AND NOW() + interval '6 months'),
  'pkwt_expired', (SELECT COUNT(*) FROM employees_master
    WHERE status_kerja = 'PKWT'
    AND (tanggal_masuk + interval '2 year')::date < NOW())
); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 7. Update login_admin to check settings table
-- ============================================================

DROP FUNCTION IF EXISTS login_admin(text) CASCADE;
CREATE OR REPLACE FUNCTION login_admin(p_password TEXT) RETURNS JSONB AS $$
DECLARE v_stored TEXT;
BEGIN
  -- Check settings table first, fallback to hardcoded
  SELECT value INTO v_stored FROM settings WHERE key = 'admin_password';
  IF v_stored IS NULL THEN v_stored := 'Admin123'; END IF;

  IF p_password = v_stored THEN
    RETURN jsonb_build_object('ok', true, 'msg', 'Password verified. Request OTP.');
  ELSE
    RETURN jsonb_build_object('ok', false, 'msg', 'Password salah');
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- DONE — Wave 1 Critical P1 Fixes
-- ============================================================
