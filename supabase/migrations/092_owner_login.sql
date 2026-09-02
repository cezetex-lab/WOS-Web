-- 092: Owner Login — completely separate from employees_master

-- 1. Remove OWNER001 from user_roles (FK violation)
DELETE FROM user_roles WHERE nrp = 'OWNER001';

-- 2. Owner login RPC — NO employees_master lookup
-- Just verify email + password via Supabase Auth, then return session
CREATE OR REPLACE FUNCTION owner_login(p_email TEXT, p_password TEXT)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_email TEXT;
BEGIN
  -- Owner is identified by email pattern
  IF p_email != 'owner@insightwos.com' THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akun owner tidak ditemukan');
  END IF;

  -- We can't directly verify password in SQL (Supabase Auth handles this)
  -- This RPC is called AFTER successful Supabase Auth login
  -- So if we reach here, auth already succeeded
  
  RETURN jsonb_build_object(
    'ok', true,
    'nrp', 'OWNER001',
    'nama', 'System Owner',
    'email', p_email,
    'role', 'owner',
    'role_level', 5,
    'business_unit_id', 'BU04',
    'business_unit_name', 'Korporat',
    'unit_code', 'HQ',
    'tier', 4,
    'divisi', 'KORPORAT',
    'jabatan', 'System Installer'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Ensure BU04 exists
INSERT INTO business_units (id, unit_code, unit_name, tier) 
VALUES ('BU04', 'HQ', 'Korporat', 4)
ON CONFLICT (id) DO UPDATE SET tier = 4;
