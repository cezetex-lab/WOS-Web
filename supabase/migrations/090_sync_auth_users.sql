-- 090: Sync auth users → employees_master
-- Run ini SETELAH 089

-- 1. Pastikan employees_master punya kolom auth_id
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='employees_master' AND column_name='auth_id') THEN
    ALTER TABLE employees_master ADD COLUMN auth_id UUID;
  END IF;
END $$;

-- 2. Upsert Owner
INSERT INTO employees_master (employee_id, nrp, nama, email, auth_id, business_unit_id, role_level, divisi, posisi, status_kerja)
SELECT 
  'OWNER001', 'OWNER001', 'System Owner', au.email, au.id,
  'BU04', 5, 'KORPORAT', 'System Owner', 'AKTIF'
FROM auth.users au WHERE au.email = 'owner@insightwos.com'
ON CONFLICT (nrp) DO UPDATE SET 
  email = EXCLUDED.email, 
  auth_id = EXCLUDED.auth_id,
  role_level = GREATEST(employees_master.role_level, 5);

-- 3. Upsert CEO
INSERT INTO employees_master (employee_id, nrp, nama, email, auth_id, business_unit_id, role_level, divisi, posisi, status_kerja)
SELECT 
  'NRP001', 'NRP001', 'Chief Executive Officer', au.email, au.id,
  'BU04', 5, 'KORPORAT', 'CEO', 'AKTIF'
FROM auth.users au WHERE au.email = 'ceo@insightwos.com'
ON CONFLICT (nrp) DO UPDATE SET 
  email = EXCLUDED.email, 
  auth_id = EXCLUDED.auth_id,
  role_level = GREATEST(employees_master.role_level, 5);

-- 4. Pastikan user_roles ada
INSERT INTO user_roles (nrp, role, role_level) VALUES ('OWNER001', 'owner', 5)
ON CONFLICT (nrp) DO UPDATE SET role = 'owner', role_level = 5;

INSERT INTO user_roles (nrp, role, role_level) VALUES ('NRP001', 'worker', 5)
ON CONFLICT (nrp) DO UPDATE SET role = 'worker', role_level = 5;

-- 5. Pastikan business_units ada
INSERT INTO business_units (id, unit_code, unit_name, tier) VALUES ('BU04', 'HQ', 'Korporat', 4)
ON CONFLICT (id) DO UPDATE SET tier = 4;

-- 6. Verify
SELECT em.nrp, em.nama, em.email, em.auth_id, ur.role, bu.unit_name
FROM employees_master em
LEFT JOIN user_roles ur ON em.nrp = ur.nrp
LEFT JOIN business_units bu ON em.business_unit_id = bu.id
WHERE em.nrp IN ('OWNER001', 'NRP001');
