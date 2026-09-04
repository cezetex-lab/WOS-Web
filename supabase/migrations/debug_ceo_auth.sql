-- ============================================================
-- DEBUG SCRIPT: Verify CEO Admin Authentication Setup
-- ============================================================
-- Run this in Supabase SQL Editor to diagnose CEO login issues
-- ============================================================

-- 1. Check if CEO auth user exists in Supabase Auth
SELECT 
  'CEO Auth User Check' as check_type,
  id,
  email,
  created_at,
  last_sign_in_at,
  email_confirmed_at
FROM auth.users 
WHERE email = 'ceo@insightwos.com';

-- 2. Check CEO employee record in employees_master
SELECT 
  'CEO Employee Record' as check_type,
  employee_id,
  nrp,
  nik,
  nama,
  email,
  divisi,
  posisi,
  status_kerja,
  role_level,
  business_unit,
  auth_id,
  auth_id IS NOT NULL as has_auth_id
FROM employees_master 
WHERE nrp = 'NRP001';

-- 3. Check CEO role in user_roles
SELECT 
  'CEO Role Assignment' as check_type,
  nrp,
  role,
  role_level
FROM user_roles 
WHERE nrp = 'NRP001';

-- 4. Check CEO password in worker_passwords
SELECT 
  'CEO Password Record' as check_type,
  nrp,
  is_active,
  password_hash IS NOT NULL as has_password
FROM worker_passwords 
WHERE nrp = 'NRP001';

-- 5. Test get_user_context_by_auth_id function (if CEO auth user exists)
DO $$
DECLARE
  v_auth_id UUID;
  v_context JSONB;
BEGIN
  SELECT id INTO v_auth_id FROM auth.users WHERE email = 'ceo@insightwos.com' LIMIT 1;
  
  IF v_auth_id IS NOT NULL THEN
    v_context := get_user_context_by_auth_id(v_auth_id);
    RAISE NOTICE 'get_user_context_by_auth_id result: %', v_context;
  ELSE
    RAISE NOTICE 'CEO auth user not found, cannot test get_user_context_by_auth_id';
  END IF;
END $$;

-- 6. Summary check - all CEO data together
SELECT 
  'CEO Complete Setup' as check_type,
  em.employee_id,
  em.nrp,
  em.nama,
  em.email as employee_email,
  au.email as auth_email,
  em.auth_id IS NOT NULL as auth_linked,
  ur.role,
  ur.role_level,
  wp.is_active as password_active
FROM employees_master em
LEFT JOIN auth.users au ON em.auth_id = au.id
LEFT JOIN user_roles ur ON ur.nrp = em.nrp
LEFT JOIN worker_passwords wp ON wp.nrp = em.nrp
WHERE em.nrp = 'NRP001';

-- 7. Check all admin accounts for comparison
SELECT 
  'All Admin Accounts' as check_type,
  em.employee_id,
  em.nrp,
  em.nama,
  em.email,
  em.auth_id IS NOT NULL as auth_linked,
  ur.role,
  ur.role_level,
  wp.is_active as password_active
FROM employees_master em
LEFT JOIN user_roles ur ON ur.nrp = em.nrp
LEFT JOIN worker_passwords wp ON wp.nrp = em.nrp
WHERE em.nrp LIKE 'NRP%'
ORDER BY em.role_level DESC;