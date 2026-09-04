-- ============================================================
-- MIGRATION 120: SEED ALL ADMIN ACCOUNTS
-- ============================================================
-- RULE: All admins (except Owner) are company employees
-- Owner uses system_owner_identity, NOT employees_master
-- ============================================================

BEGIN;

-- STEP 1: Insert employees + roles + passwords

-- Direktur Utama (ceo@insightwos.com)
INSERT INTO employees_master (employee_id, nrp, nik, nama, email, divisi, posisi, status_kerja, role_level, business_unit)
VALUES ('ADM-0001', 'NRP001', 'NRP001', 'Direktur Utama', 'ceo@insightwos.com', 'KORPORAT', 'CEO', 'PKWTT', 5, 'HQ')
ON CONFLICT (nrp) DO UPDATE SET
  employee_id = EXCLUDED.employee_id, email = EXCLUDED.email,
  role_level = GREATEST(employees_master.role_level, 5),
  nama = EXCLUDED.nama, divisi = EXCLUDED.divisi, posisi = EXCLUDED.posisi;

INSERT INTO user_roles (nrp, role_level, role)
VALUES ('NRP001', 5, 'admin_pusat')
ON CONFLICT (nrp) DO UPDATE SET role_level = 5, role = 'admin_pusat';

INSERT INTO worker_passwords (nrp, password_hash, salt, is_active)
VALUES ('NRP001', crypt('CEO123!', gen_salt('bf')), 's', true)
ON CONFLICT (nrp) DO UPDATE SET password_hash = crypt('CEO123!', gen_salt('bf')), is_active = true;

-- Admin Pusat (pusat@insightwos.com)
INSERT INTO employees_master (employee_id, nrp, nik, nama, email, divisi, posisi, status_kerja, role_level, business_unit)
VALUES ('ADM-0002', 'NRP100', 'NRP100', 'Admin Pusat', 'pusat@insightwos.com', 'KORPORAT', 'Admin Pusat', 'PKWTT', 4, 'HQ')
ON CONFLICT (nrp) DO UPDATE SET
  employee_id = EXCLUDED.employee_id, email = EXCLUDED.email,
  role_level = GREATEST(employees_master.role_level, 4),
  nama = EXCLUDED.nama, divisi = EXCLUDED.divisi, posisi = EXCLUDED.posisi;

INSERT INTO user_roles (nrp, role_level, role)
VALUES ('NRP100', 4, 'admin_pusat')
ON CONFLICT (nrp) DO UPDATE SET role_level = 4, role = 'admin_pusat';

INSERT INTO worker_passwords (nrp, password_hash, salt, is_active)
VALUES ('NRP100', crypt('Admin123!', gen_salt('bf')), 's', true)
ON CONFLICT (nrp) DO UPDATE SET password_hash = crypt('Admin123!', gen_salt('bf')), is_active = true;

-- Admin HRD (hrd@insightwos.com)
INSERT INTO employees_master (employee_id, nrp, nik, nama, email, divisi, posisi, status_kerja, role_level, business_unit)
VALUES ('ADM-0003', 'NRP101', 'NRP101', 'Admin HRD', 'hrd@insightwos.com', 'HRD', 'HR Manager', 'PKWTT', 3, 'HQ')
ON CONFLICT (nrp) DO UPDATE SET
  employee_id = EXCLUDED.employee_id, email = EXCLUDED.email,
  role_level = GREATEST(employees_master.role_level, 3),
  nama = EXCLUDED.nama, divisi = EXCLUDED.divisi, posisi = EXCLUDED.posisi;

INSERT INTO user_roles (nrp, role_level, role)
VALUES ('NRP101', 3, 'admin_hrd')
ON CONFLICT (nrp) DO UPDATE SET role_level = 3, role = 'admin_hrd';

INSERT INTO worker_passwords (nrp, password_hash, salt, is_active)
VALUES ('NRP101', crypt('Hrd123!', gen_salt('bf')), 's', true)
ON CONFLICT (nrp) DO UPDATE SET password_hash = crypt('Hrd123!', gen_salt('bf')), is_active = true;

-- Admin Finance (finance@insightwos.com)
INSERT INTO employees_master (employee_id, nrp, nik, nama, email, divisi, posisi, status_kerja, role_level, business_unit)
VALUES ('ADM-0004', 'NRP102', 'NRP102', 'Admin Finance', 'finance@insightwos.com', 'FINANCE', 'Finance Manager', 'PKWTT', 3, 'HQ')
ON CONFLICT (nrp) DO UPDATE SET
  employee_id = EXCLUDED.employee_id, email = EXCLUDED.email,
  role_level = GREATEST(employees_master.role_level, 3),
  nama = EXCLUDED.nama, divisi = EXCLUDED.divisi, posisi = EXCLUDED.posisi;

INSERT INTO user_roles (nrp, role_level, role)
VALUES ('NRP102', 3, 'admin_finance')
ON CONFLICT (nrp) DO UPDATE SET role_level = 3, role = 'admin_finance';

INSERT INTO worker_passwords (nrp, password_hash, salt, is_active)
VALUES ('NRP102', crypt('Fin123!', gen_salt('bf')), 's', true)
ON CONFLICT (nrp) DO UPDATE SET password_hash = crypt('Fin123!', gen_salt('bf')), is_active = true;

-- Admin Operasional (operasional@insightwos.com)
INSERT INTO employees_master (employee_id, nrp, nik, nama, email, divisi, posisi, status_kerja, role_level, business_unit)
VALUES ('ADM-0005', 'NRP103', 'NRP103', 'Admin Operasional', 'operasional@insightwos.com', 'OPERASIONAL', 'Ops Manager', 'PKWTT', 3, 'HQ')
ON CONFLICT (nrp) DO UPDATE SET
  employee_id = EXCLUDED.employee_id, email = EXCLUDED.email,
  role_level = GREATEST(employees_master.role_level, 3),
  nama = EXCLUDED.nama, divisi = EXCLUDED.divisi, posisi = EXCLUDED.posisi;

INSERT INTO user_roles (nrp, role_level, role)
VALUES ('NRP103', 3, 'admin_produksi')
ON CONFLICT (nrp) DO UPDATE SET role_level = 3, role = 'admin_produksi';

INSERT INTO worker_passwords (nrp, password_hash, salt, is_active)
VALUES ('NRP103', crypt('Ops123!', gen_salt('bf')), 's', true)
ON CONFLICT (nrp) DO UPDATE SET password_hash = crypt('Ops123!', gen_salt('bf')), is_active = true;

-- Admin Mining (mining@insightwos.com)
INSERT INTO employees_master (employee_id, nrp, nik, nama, email, divisi, posisi, status_kerja, role_level, business_unit)
VALUES ('ADM-0006', 'NRP104', 'NRP104', 'Admin Mining', 'mining@insightwos.com', 'MINING', 'Mining Manager', 'PKWTT', 3, 'MINING')
ON CONFLICT (nrp) DO UPDATE SET
  employee_id = EXCLUDED.employee_id, email = EXCLUDED.email,
  role_level = GREATEST(employees_master.role_level, 3),
  nama = EXCLUDED.nama, divisi = EXCLUDED.divisi, posisi = EXCLUDED.posisi;

INSERT INTO user_roles (nrp, role_level, role)
VALUES ('NRP104', 3, 'admin_mining')
ON CONFLICT (nrp) DO UPDATE SET role_level = 3, role = 'admin_mining';

INSERT INTO worker_passwords (nrp, password_hash, salt, is_active)
VALUES ('NRP104', crypt('Mining123!', gen_salt('bf')), 's', true)
ON CONFLICT (nrp) DO UPDATE SET password_hash = crypt('Mining123!', gen_salt('bf')), is_active = true;

-- Admin Mill (mill@insightwos.com)
INSERT INTO employees_master (employee_id, nrp, nik, nama, email, divisi, posisi, status_kerja, role_level, business_unit)
VALUES ('ADM-0007', 'NRP105', 'NRP105', 'Admin Mill', 'mill@insightwos.com', 'MILL', 'Mill Manager', 'PKWTT', 3, 'MILL')
ON CONFLICT (nrp) DO UPDATE SET
  employee_id = EXCLUDED.employee_id, email = EXCLUDED.email,
  role_level = GREATEST(employees_master.role_level, 3),
  nama = EXCLUDED.nama, divisi = EXCLUDED.divisi, posisi = EXCLUDED.posisi;

INSERT INTO user_roles (nrp, role_level, role)
VALUES ('NRP105', 3, 'admin_mill')
ON CONFLICT (nrp) DO UPDATE SET role_level = 3, role = 'admin_mill';

INSERT INTO worker_passwords (nrp, password_hash, salt, is_active)
VALUES ('NRP105', crypt('Mill123!', gen_salt('bf')), 's', true)
ON CONFLICT (nrp) DO UPDATE SET password_hash = crypt('Mill123!', gen_salt('bf')), is_active = true;

-- Admin Estate (estate@insightwos.com)
INSERT INTO employees_master (employee_id, nrp, nik, nama, email, divisi, posisi, status_kerja, role_level, business_unit)
VALUES ('ADM-0008', 'NRP106', 'NRP106', 'Admin Estate', 'estate@insightwos.com', 'ESTATE', 'Estate Manager', 'PKWTT', 3, 'ESTATE')
ON CONFLICT (nrp) DO UPDATE SET
  employee_id = EXCLUDED.employee_id, email = EXCLUDED.email,
  role_level = GREATEST(employees_master.role_level, 3),
  nama = EXCLUDED.nama, divisi = EXCLUDED.divisi, posisi = EXCLUDED.posisi;

INSERT INTO user_roles (nrp, role_level, role)
VALUES ('NRP106', 3, 'admin_estate')
ON CONFLICT (nrp) DO UPDATE SET role_level = 3, role = 'admin_estate';

INSERT INTO worker_passwords (nrp, password_hash, salt, is_active)
VALUES ('NRP106', crypt('Estate123!', gen_salt('bf')), 's', true)
ON CONFLICT (nrp) DO UPDATE SET password_hash = crypt('Estate123!', gen_salt('bf')), is_active = true;

-- Owner: NOT in employees_master, uses system_owner_identity only
-- Owner role is handled by system_owner_identity table (migration 110)
-- No user_roles insert for OWNER001 (would violate FK constraint)

COMMIT;

-- STEP 2: Link auth_id (auth users already exist in Dashboard)

UPDATE employees_master SET auth_id = (SELECT id FROM auth.users WHERE email = 'ceo@insightwos.com' LIMIT 1)
WHERE nrp = 'NRP001' AND auth_id IS NULL;
UPDATE employees_master SET auth_id = (SELECT id FROM auth.users WHERE email = 'pusat@insightwos.com' LIMIT 1)
WHERE nrp = 'NRP100' AND auth_id IS NULL;
UPDATE employees_master SET auth_id = (SELECT id FROM auth.users WHERE email = 'hrd@insightwos.com' LIMIT 1)
WHERE nrp = 'NRP101' AND auth_id IS NULL;
UPDATE employees_master SET auth_id = (SELECT id FROM auth.users WHERE email = 'finance@insightwos.com' LIMIT 1)
WHERE nrp = 'NRP102' AND auth_id IS NULL;
UPDATE employees_master SET auth_id = (SELECT id FROM auth.users WHERE email = 'operasional@insightwos.com' LIMIT 1)
WHERE nrp = 'NRP103' AND auth_id IS NULL;
UPDATE employees_master SET auth_id = (SELECT id FROM auth.users WHERE email = 'mining@insightwos.com' LIMIT 1)
WHERE nrp = 'NRP104' AND auth_id IS NULL;
UPDATE employees_master SET auth_id = (SELECT id FROM auth.users WHERE email = 'mill@insightwos.com' LIMIT 1)
WHERE nrp = 'NRP105' AND auth_id IS NULL;
UPDATE employees_master SET auth_id = (SELECT id FROM auth.users WHERE email = 'estate@insightwos.com' LIMIT 1)
WHERE nrp = 'NRP106' AND auth_id IS NULL;

-- Verify:
SELECT em.employee_id, em.nrp, em.nama, em.email, em.divisi, em.role_level,
  ur.role, em.auth_id IS NOT NULL as has_auth
FROM employees_master em
LEFT JOIN user_roles ur ON ur.nrp = em.nrp
WHERE em.nrp IN ('NRP001','NRP100','NRP101','NRP102','NRP103','NRP104','NRP105','NRP106')
ORDER BY em.role_level DESC;