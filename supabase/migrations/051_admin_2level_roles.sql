-- ============================================================
-- MIGRATION 051: 2-LEVEL ADMIN SYSTEM
-- Admin Pusat (all control) vs Admin Divisi (HRD/Finance/Produksi)
-- Worker Level 1 = no dashboard, info di page worker
-- ============================================================

-- 1. Add role column to user_roles
ALTER TABLE user_roles ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'worker';

-- 2. Add CHECK constraint for valid roles
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'user_roles_role_check'
  ) THEN
    ALTER TABLE user_roles ADD CONSTRAINT user_roles_role_check
      CHECK (role IN (
        'admin_pusat','admin_hrd','admin_finance','admin_produksi',
        'manager','worker'
      ));
  END IF;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 3. Backfill existing data based on role_level
-- role_level >= 5 → admin_pusat, 4 → manager, else → worker
UPDATE user_roles SET role = CASE
  WHEN role_level >= 5 THEN 'admin_pusat'
  WHEN role_level >= 4 THEN 'manager'
  ELSE 'worker'
END WHERE role IS NULL OR role = 'worker';

-- ============================================================
-- 4. ADMIN DIVISION PERMISSION MATRIX TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS admin_division_access (
  id SERIAL PRIMARY KEY,
  role TEXT NOT NULL,
  module_key TEXT NOT NULL,
  module_label TEXT NOT NULL,
  UNIQUE(role, module_key)
);

-- Admin Pusat: ALL modules
INSERT INTO admin_division_access (role, module_key, module_label) VALUES
-- Kelola Data
('admin_pusat','employees','Karyawan'),
('admin_pusat','org','Organisasi'),
('admin_pusat','divisions','Divisi'),
('admin_pusat','master','Master Data'),
('admin_pusat','roles','Role Matrix'),
('admin_pusat','reset_password','Reset Password'),
-- Operasional HR
('admin_pusat','requests','Pengajuan'),
('admin_pusat','leave','Cuti'),
('admin_pusat','overtime','Lembur'),
('admin_pusat','payroll','Payroll'),
('admin_pusat','timesheet','Timesheet'),
('admin_pusat','shift_swap','Shift Swap'),
-- Talent & Performance
('admin_pusat','kpi','KPI'),
('admin_pusat','okr','OKR'),
('admin_pusat','learning','Learning'),
('admin_pusat','certifications','Sertifikasi'),
('admin_pusat','badges','Badge & Gamifikasi'),
('admin_pusat','talent','Talent Market'),
('admin_pusat','career','Career Path'),
('admin_pusat','review_360','360 Review'),
('admin_pusat','incentive','Insentif'),
-- Aset & Fasilitas
('admin_pusat','assets','Inventaris'),
('admin_pusat','asset_assign','Check-in/out'),
('admin_pusat','estate','Estate Blocks'),
('admin_pusat','facility','Facility Request'),
-- Engagement
('admin_pusat','surveys','Survei'),
('admin_pusat','voice','Ide & Voice'),
('admin_pusat','whistleblower','Whistleblowing'),
('admin_pusat','forum','Forum'),
-- Offboarding
('admin_pusat','exit','Exit Interview'),
('admin_pusat','settlement','Final Settlement'),
('admin_pusat','clearance','Clearance'),
-- Sistem & Keamanan
('admin_pusat','audit','Audit Log'),
('admin_pusat','export','Export Data'),
('admin_pusat','features','Feature Flags'),
('admin_pusat','settings','Pengaturan'),
('admin_pusat','chain','Audit Chain'),
-- Perencanaan
('admin_pusat','headcount','Headcount Plan'),
('admin_pusat','budget','Budget Allocation'),
('admin_pusat','referral','Referral Program'),
-- Rekrutmen
('admin_pusat','recruitment','Rekrutmen'),
('admin_pusat','pipeline','Pipeline'),
('admin_pusat','onboarding','Onboarding'),
('admin_pusat','screening','Screening'),
-- Integrasi
('admin_pusat','integrations','Integrasi'),
-- Simulasi & AI
('admin_pusat','simulation','Simulasi'),
('admin_pusat','ai_tasks','AI Tasks')
ON CONFLICT (role, module_key) DO NOTHING;

-- Admin HRD: People + Self-Service + Talent + Engagement
INSERT INTO admin_division_access (role, module_key, module_label) VALUES
('admin_hrd','employees','Karyawan'),
('admin_hrd','org','Organisasi'),
('admin_hrd','divisions','Divisi'),
('admin_hrd','master','Master Data'),
('admin_hrd','roles','Role Matrix'),
('admin_hrd','reset_password','Reset Password'),
('admin_hrd','requests','Pengajuan'),
('admin_hrd','leave','Cuti'),
('admin_hrd','overtime','Lembur'),
('admin_hrd','kpi','KPI'),
('admin_hrd','okr','OKR'),
('admin_hrd','learning','Learning'),
('admin_hrd','certifications','Sertifikasi'),
('admin_hrd','badges','Badge & Gamifikasi'),
('admin_hrd','talent','Talent Market'),
('admin_hrd','career','Career Path'),
('admin_hrd','review_360','360 Review'),
('admin_hrd','surveys','Survei'),
('admin_hrd','voice','Ide & Voice'),
('admin_hrd','whistleblower','Whistleblowing'),
('admin_hrd','forum','Forum'),
('admin_hrd','recruitment','Rekrutmen'),
('admin_hrd','pipeline','Pipeline'),
('admin_hrd','onboarding','Onboarding'),
('admin_hrd','screening','Screening'),
('admin_hrd','exit','Exit Interview'),
('admin_hrd','settlement','Final Settlement'),
('admin_hrd','clearance','Clearance'),
('admin_hrd','headcount','Headcount Plan'),
('admin_hrd','referral','Referral Program'),
('admin_hrd','settings','Pengaturan')
ON CONFLICT (role, module_key) DO NOTHING;

-- Admin Finance: Payroll + Budget + Financial Analytics
INSERT INTO admin_division_access (role, module_key, module_label) VALUES
('admin_finance','payroll','Payroll'),
('admin_finance','budget','Budget Allocation'),
('admin_finance','kpi','KPI'),
('admin_finance','incentive','Insentif'),
('admin_finance','timesheet','Timesheet'),
('admin_finance','overtime','Lembur'),
('admin_finance','export','Export Data'),
('admin_finance','requests','Pengajuan'),
('admin_finance','assets','Inventaris'),
('admin_finance','settlement','Final Settlement'),
('admin_finance','audit','Audit Log'),
('admin_finance','settings','Pengaturan')
ON CONFLICT (role, module_key) DO NOTHING;

-- Admin Produksi: Operations + Attendance + Shift + Assets + Safety
INSERT INTO admin_division_access (role, module_key, module_label) VALUES
('admin_produksi','timesheet','Timesheet'),
('admin_produksi','shift_swap','Shift Swap'),
('admin_produksi','overtime','Lembur'),
('admin_produksi','requests','Pengajuan'),
('admin_produksi','kpi','KPI'),
('admin_produksi','assets','Inventaris'),
('admin_produksi','asset_assign','Check-in/out'),
('admin_produksi','estate','Estate Blocks'),
('admin_produksi','facility','Facility Request'),
('admin_produksi','leave','Cuti'),
('admin_produksi','certifications','Sertifikasi'),
('admin_produksi','badges','Badge & Gamifikasi'),
('admin_produksi','audit','Audit Log'),
('admin_produksi','settings','Pengaturan')
ON CONFLICT (role, module_key) DO NOTHING;

-- ============================================================
-- 5. RPC: Get admin division access
-- ============================================================
CREATE OR REPLACE FUNCTION get_my_admin_modules(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE
  v_role TEXT;
  v_modules JSONB;
BEGIN
  SELECT role INTO v_role FROM user_roles WHERE nrp = p_nrp;
  IF v_role IS NULL OR v_role = 'worker' THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Bukan admin');
  END IF;

  SELECT jsonb_agg(jsonb_build_object(
    'key', module_key,
    'label', module_label
  ) ORDER BY module_key)
  INTO v_modules
  FROM admin_division_access
  WHERE role = v_role;

  RETURN jsonb_build_object(
    'ok', true,
    'role', v_role,
    'modules', COALESCE(v_modules, '[]'::jsonb)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 6. UPDATE login_worker → RETURN role column
-- ============================================================
DROP FUNCTION IF EXISTS login_worker(text, text, text) CASCADE;
CREATE OR REPLACE FUNCTION login_worker(
  p_nrp TEXT,
  p_nik TEXT,
  p_password TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_emp RECORD;
  v_pwd RECORD;
  v_role RECORD;
  v_salt TEXT;
  v_hash TEXT;
BEGIN
  SELECT * INTO v_emp FROM employees_master WHERE nrp = p_nrp AND nik = p_nik;
  IF v_emp IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'NRP/NIK tidak ditemukan');
  END IF;

  SELECT * INTO v_pwd FROM worker_passwords WHERE nrp = p_nrp AND is_active = true;
  IF v_pwd IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akun tidak aktif');
  END IF;

  IF v_pwd.blocked_until IS NOT NULL AND v_pwd.blocked_until > NOW() THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akun diblokir sementara');
  END IF;

  v_salt := v_pwd.salt;
  v_hash := encode(digest(p_password || v_salt, 'sha256'), 'hex');

  IF v_hash != v_pwd.password_hash THEN
    UPDATE worker_passwords SET attempts = attempts + 1,
      blocked_until = CASE WHEN attempts >= 4 THEN NOW() + INTERVAL '15 minutes' ELSE blocked_until END
    WHERE nrp = p_nrp;
    RETURN jsonb_build_object('ok', false, 'msg', 'Password salah');
  END IF;

  UPDATE worker_passwords SET attempts = 0, blocked_until = NULL WHERE nrp = p_nrp;

  SELECT * INTO v_role FROM user_roles WHERE nrp = p_nrp;

  RETURN jsonb_build_object(
    'ok', true,
    'nrp', v_emp.nrp,
    'nama', v_emp.nama,
    'nik', v_emp.nik,
    'divisi', v_emp.divisi,
    'posisi', v_emp.posisi,
    'role', COALESCE(v_role.role, 'worker'),
    'role_level', COALESCE(v_role.role_level, 1),
    'scope_divisi', v_role.scope_divisi,
    'business_unit', COALESCE(v_emp.business_unit, 'HQ'),
    'token', encode(gen_random_bytes(32), 'hex'),
    'expires_at', (NOW() + INTERVAL '24 hours')::text
  );
END;
$$;

-- ============================================================
-- 7. UPDATE verify_worker_otp → RETURN role column
-- ============================================================
DROP FUNCTION IF EXISTS verify_worker_otp(text, text) CASCADE;
CREATE OR REPLACE FUNCTION verify_worker_otp(p_nrp TEXT, p_code TEXT)
RETURNS JSONB AS $$
DECLARE
  v_otp RECORD;
  v_emp RECORD;
  v_role RECORD;
  v_hash TEXT;
BEGIN
  v_hash := encode(digest(p_code, 'sha256'), 'hex');

  SELECT * INTO v_otp FROM otp_store WHERE nrp = p_nrp AND code_hash = v_hash AND NOT used;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Kode OTP tidak valid');
  END IF;
  IF v_otp.expiry < NOW() THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Kode OTP sudah kadaluarsa');
  END IF;

  UPDATE otp_store SET used = true WHERE nrp = p_nrp AND code_hash = v_hash;

  SELECT * INTO v_emp FROM employees_master WHERE nrp = p_nrp;
  SELECT * INTO v_role FROM user_roles WHERE nrp = p_nrp;

  RETURN jsonb_build_object(
    'ok', true,
    'nrp', p_nrp,
    'nama', v_emp.nama,
    'nik', v_emp.nik,
    'divisi', v_emp.divisi,
    'posisi', v_emp.posisi,
    'role', COALESCE(v_role.role, 'worker'),
    'role_level', COALESCE(v_role.role_level, 1),
    'scope_divisi', v_role.scope_divisi,
    'business_unit', COALESCE(v_emp.business_unit, 'HQ'),
    'token', encode(gen_random_bytes(32), 'hex'),
    'expires_at', (NOW() + INTERVAL '24 hours')::text
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 8. UPDATE verify_admin_otp → RETURN role from user_roles
-- ============================================================
DROP FUNCTION IF EXISTS verify_admin_otp(text) CASCADE;
CREATE OR REPLACE FUNCTION verify_admin_otp(p_code TEXT)
RETURNS JSONB AS $$
DECLARE
  v_otp RECORD;
  v_hash TEXT;
  v_admin_role TEXT;
BEGIN
  v_hash := encode(digest(p_code, 'sha256'), 'hex');

  SELECT * INTO v_otp FROM otp_store WHERE nrp = 'ADMIN' AND code_hash = v_hash AND NOT used;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Kode OTP admin tidak valid');
  END IF;
  IF v_otp.expiry < NOW() THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Kode OTP sudah kadaluarsa');
  END IF;

  UPDATE otp_store SET used = true WHERE nrp = 'ADMIN' AND code_hash = v_hash;

  -- Default admin is admin_pusat (full control)
  v_admin_role := 'admin_pusat';

  RETURN jsonb_build_object(
    'ok', true,
    'token', encode(gen_random_bytes(16), 'hex'),
    'role', v_admin_role,
    'nama', 'Administrator',
    'nrp', 'ADMIN'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 9. SEED: Admin Pusat (NRP = ADMIN, role_level=5)
-- ============================================================
-- First ensure ADMIN exists in employees_master (required by FK)
INSERT INTO employees_master (employee_id, nrp, nik, nama, email, divisi, posisi, status_kerja, business_unit, tanggal_masuk)
VALUES ('EMP-ADMIN-001','ADMIN','NIK-ADMIN','Administrator','admin@company.com','Admin','System Administrator','PKWTT','HQ','2018-01-01')
ON CONFLICT (nrp) DO NOTHING;

-- Now insert user_roles
INSERT INTO user_roles (nrp, role_level, role, scope_divisi, plan)
VALUES ('ADMIN', 5, 'admin_pusat', NULL, 'ENTERPRISE')
ON CONFLICT (nrp) DO UPDATE SET
  role_level = 5, role = 'admin_pusat', plan = 'ENTERPRISE';

-- ============================================================
-- 10. SEED: Admin Divisi Users (4 demo users)
-- ============================================================

-- Admin HRD Lead
INSERT INTO employees_master (employee_id, nrp, nik, nama, email, divisi, posisi, status_kerja, business_unit, tanggal_masuk)
VALUES ('EMP-HRD-001','ADM-HRD-01','NIK-HRD-01','Siti Rahmawati','siti.hr@company.com','HRD','Head of HRD','PKWTT','HQ','2020-01-15')
ON CONFLICT (nrp) DO NOTHING;

INSERT INTO worker_passwords (nrp, password_hash, salt, is_active)
VALUES ('ADM-HRD-01', encode(digest('admin123' || encode(gen_random_bytes(8),'hex'), 'sha256'), 'hex'), encode(gen_random_bytes(8), 'hex'), true)
ON CONFLICT (nrp) DO NOTHING;

-- Update password with proper salt
DO $$
DECLARE v_salt TEXT;
BEGIN
  SELECT salt INTO v_salt FROM worker_passwords WHERE nrp = 'ADM-HRD-01';
  UPDATE worker_passwords SET password_hash = encode(digest('admin123' || v_salt, 'sha256'), 'hex') WHERE nrp = 'ADM-HRD-01';
END $$;

INSERT INTO user_roles (nrp, role_level, role, scope_divisi, plan)
VALUES ('ADM-HRD-01', 4, 'admin_hrd', 'HRD', 'PRO')
ON CONFLICT (nrp) DO UPDATE SET
  role_level = 4, role = 'admin_hrd', scope_divisi = 'HRD', plan = 'PRO';

-- Admin Finance Lead
INSERT INTO employees_master (employee_id, nrp, nik, nama, email, divisi, posisi, status_kerja, business_unit, tanggal_masuk)
VALUES ('EMP-FIN-001','ADM-FIN-01','NIK-FIN-01','Budi Santoso','budi.finance@company.com','Finance','Head of Finance','PKWTT','HQ','2019-06-01')
ON CONFLICT (nrp) DO NOTHING;

INSERT INTO worker_passwords (nrp, password_hash, salt, is_active)
VALUES ('ADM-FIN-01', encode(digest('admin123' || encode(gen_random_bytes(8),'hex'), 'sha256'), 'hex'), encode(gen_random_bytes(8), 'hex'), true)
ON CONFLICT (nrp) DO NOTHING;

DO $$
DECLARE v_salt TEXT;
BEGIN
  SELECT salt INTO v_salt FROM worker_passwords WHERE nrp = 'ADM-FIN-01';
  UPDATE worker_passwords SET password_hash = encode(digest('admin123' || v_salt, 'sha256'), 'hex') WHERE nrp = 'ADM-FIN-01';
END $$;

INSERT INTO user_roles (nrp, role_level, role, scope_divisi, plan)
VALUES ('ADM-FIN-01', 4, 'admin_finance', 'Finance', 'PRO')
ON CONFLICT (nrp) DO UPDATE SET
  role_level = 4, role = 'admin_finance', scope_divisi = 'Finance', plan = 'PRO';

-- Admin Produksi Lead
INSERT INTO employees_master (employee_id, nrp, nik, nama, email, divisi, posisi, status_kerja, business_unit, tanggal_masuk)
VALUES ('EMP-PRD-001','ADM-PRD-01','NIK-PRD-01','Ahmad Fauzi','ahmad.prod@company.com','Produksi','Head of Produksi','PKWTT','MINING','2018-03-20')
ON CONFLICT (nrp) DO NOTHING;

INSERT INTO worker_passwords (nrp, password_hash, salt, is_active)
VALUES ('ADM-PRD-01', encode(digest('admin123' || encode(gen_random_bytes(8),'hex'), 'sha256'), 'hex'), encode(gen_random_bytes(8), 'hex'), true)
ON CONFLICT (nrp) DO NOTHING;

DO $$
DECLARE v_salt TEXT;
BEGIN
  SELECT salt INTO v_salt FROM worker_passwords WHERE nrp = 'ADM-PRD-01';
  UPDATE worker_passwords SET password_hash = encode(digest('admin123' || v_salt, 'sha256'), 'hex') WHERE nrp = 'ADM-PRD-01';
END $$;

INSERT INTO user_roles (nrp, role_level, role, scope_divisi, plan)
VALUES ('ADM-PRD-01', 4, 'admin_produksi', 'Produksi', 'PRO')
ON CONFLICT (nrp) DO UPDATE SET
  role_level = 4, role = 'admin_produksi', scope_divisi = 'Produksi', plan = 'PRO';

-- Admin HRD 2nd staff
INSERT INTO employees_master (employee_id, nrp, nik, nama, email, divisi, posisi, status_kerja, business_unit, tanggal_masuk)
VALUES ('EMP-HRD-002','ADM-HRD-02','NIK-HRD-02','Dewi Lestari','dewi.hr@company.com','HRD','HR Staff','PKWTT','HQ','2022-07-10')
ON CONFLICT (nrp) DO NOTHING;

INSERT INTO worker_passwords (nrp, password_hash, salt, is_active)
VALUES ('ADM-HRD-02', encode(digest('admin123' || encode(gen_random_bytes(8),'hex'), 'sha256'), 'hex'), encode(gen_random_bytes(8), 'hex'), true)
ON CONFLICT (nrp) DO NOTHING;

DO $$
DECLARE v_salt TEXT;
BEGIN
  SELECT salt INTO v_salt FROM worker_passwords WHERE nrp = 'ADM-HRD-02';
  UPDATE worker_passwords SET password_hash = encode(digest('admin123' || v_salt, 'sha256'), 'hex') WHERE nrp = 'ADM-HRD-02';
END $$;

INSERT INTO user_roles (nrp, role_level, role, scope_divisi, plan)
VALUES ('ADM-HRD-02', 3, 'admin_hrd', 'HRD', 'PRO')
ON CONFLICT (nrp) DO UPDATE SET
  role_level = 3, role = 'admin_hrd', scope_divisi = 'HRD', plan = 'PRO';

-- ============================================================
-- 11. RPC: Admin set sub-role for employee
-- ============================================================
CREATE OR REPLACE FUNCTION admin_set_employee_role(
  p_admin_nrp TEXT,
  p_target_nrp TEXT,
  p_role TEXT,
  p_scope_divisi TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE v_admin_role TEXT;
BEGIN
  SELECT role INTO v_admin_role FROM user_roles WHERE nrp = p_admin_nrp;
  IF v_admin_role != 'admin_pusat' THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Hanya Admin Pusat yang bisa mengatur role');
  END IF;

  IF p_role NOT IN ('admin_pusat','admin_hrd','admin_finance','admin_produksi','manager','worker') THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Role tidak valid');
  END IF;

  UPDATE user_roles SET role = p_role, scope_divisi = COALESCE(p_scope_divisi, scope_divisi) WHERE nrp = p_target_nrp;

  IF NOT FOUND THEN
    INSERT INTO user_roles (nrp, role_level, role, scope_divisi)
    VALUES (p_target_nrp, CASE WHEN p_role LIKE 'admin_%' THEN 4 WHEN p_role = 'manager' THEN 3 ELSE 1 END, p_role, p_scope_divisi);
  END IF;

  RETURN jsonb_build_object('ok', true, 'msg', 'Role berhasil diupdate');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 12. Enable RLS on admin_division_access
-- ============================================================
ALTER TABLE admin_division_access ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY admin_division_access_select ON admin_division_access
    FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- DONE — Migration 051: 2-Level Admin System
-- ============================================================
