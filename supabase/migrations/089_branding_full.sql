-- 089: Branding — FULL (create table + RLS + RPCs + auth fix)

-- 1. Create branding table (idempotent)
CREATE TABLE IF NOT EXISTS branding (
  id TEXT PRIMARY KEY DEFAULT 'main',
  company_name TEXT DEFAULT 'insightWOS',
  tagline TEXT DEFAULT 'Workforce Intelligence Platform',
  logo_url TEXT,
  logo_dark_url TEXT,
  primary_color TEXT DEFAULT '#3b82f6',
  favicon_url TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  updated_by TEXT
);

-- Seed default
INSERT INTO branding (id, company_name, tagline) 
VALUES ('main', 'insightWOS', 'Workforce Intelligence Platform')
ON CONFLICT (id) DO NOTHING;

-- 2. RLS
ALTER TABLE branding ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS br_select ON branding;
CREATE POLICY br_select ON branding FOR SELECT USING (TRUE);
DROP POLICY IF EXISTS br_insert ON branding;
CREATE POLICY br_insert ON branding FOR INSERT WITH CHECK (TRUE);
DROP POLICY IF EXISTS br_update ON branding;
CREATE POLICY br_update ON branding FOR UPDATE USING (TRUE) WITH CHECK (TRUE);

-- 3. Get branding
CREATE OR REPLACE FUNCTION get_branding()
RETURNS JSONB AS $$
DECLARE v_result JSONB;
BEGIN
  SELECT row_to_json(b)::jsonb INTO v_result FROM branding b WHERE b.id = 'main';
  RETURN COALESCE(v_result, jsonb_build_object('company_name', 'insightWOS', 'tagline', 'Workforce Intelligence Platform'));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Update branding (owner only)
CREATE OR REPLACE FUNCTION update_branding(
  p_company_name TEXT DEFAULT NULL,
  p_tagline TEXT DEFAULT NULL,
  p_logo_url TEXT DEFAULT NULL,
  p_primary_color TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE v_nrp TEXT; v_role TEXT;
BEGIN
  SELECT em.nrp, ur.role INTO v_nrp, v_role
  FROM employees_master em
  LEFT JOIN user_roles ur ON em.nrp = ur.nrp
  WHERE em.auth_id = auth.uid() LIMIT 1;

  IF v_role != 'owner' THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Hanya Owner');
  END IF;

  UPDATE branding SET
    company_name = COALESCE(p_company_name, company_name),
    tagline = COALESCE(p_tagline, tagline),
    logo_url = COALESCE(p_logo_url, logo_url),
    primary_color = COALESCE(p_primary_color, primary_color),
    updated_at = NOW(), updated_by = v_nrp
  WHERE id = 'main';

  RETURN jsonb_build_object('ok', true, 'msg', 'Updated');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Auth lookup fix (try auth_id → try email → auto-link)
CREATE OR REPLACE FUNCTION get_user_context_by_auth_id(p_auth_id UUID)
RETURNS JSONB AS $$
DECLARE v_emp RECORD; v_role RECORD; v_bu RECORD; v_email TEXT;
BEGIN
  SELECT email INTO v_email FROM auth.users WHERE id = p_auth_id;
  
  SELECT employee_id, nrp, nama, email, business_unit_id, role_level, divisi, posisi
  INTO v_emp FROM employees_master WHERE auth_id = p_auth_id LIMIT 1;
  
  IF NOT FOUND AND v_email IS NOT NULL THEN
    SELECT employee_id, nrp, nama, email, business_unit_id, role_level, divisi, posisi
    INTO v_emp FROM employees_master
    WHERE LOWER(TRIM(email)) = LOWER(TRIM(v_email)) LIMIT 1;
    IF FOUND THEN
      UPDATE employees_master SET auth_id = p_auth_id WHERE nrp = v_emp.nrp;
    END IF;
  END IF;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akun tidak ditemukan. Email: ' || COALESCE(v_email, 'null'));
  END IF;

  SELECT role, role_level INTO v_role FROM user_roles WHERE nrp = v_emp.nrp LIMIT 1;
  SELECT tier, unit_name, unit_code INTO v_bu FROM business_units WHERE id = v_emp.business_unit_id;

  RETURN jsonb_build_object(
    'ok', true, 'nrp', v_emp.nrp, 'nama', v_emp.nama, 'email', v_emp.email,
    'role', COALESCE(v_role.role, 'worker'),
    'role_level', GREATEST(COALESCE(v_role.role_level, 1), COALESCE(v_emp.role_level, 1)),
    'business_unit_id', v_emp.business_unit_id,
    'business_unit_name', COALESCE(v_bu.unit_name, ''),
    'unit_code', COALESCE(v_bu.unit_code, 'HQ'),
    'tier', COALESCE(v_bu.tier, 0),
    'divisi', v_emp.divisi, 'jabatan', v_emp.posisi
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Sync Owner/CEO emails from auth.users
DO $$ DECLARE v_email TEXT;
BEGIN
  SELECT email INTO v_email FROM auth.users WHERE email = 'owner@insightwos.com';
  IF v_email IS NOT NULL THEN
    UPDATE employees_master 
    SET email = v_email, auth_id = (SELECT id FROM auth.users WHERE email = v_email)
    WHERE nrp = 'OWNER001';
  END IF;
  SELECT email INTO v_email FROM auth.users WHERE email = 'ceo@insightwos.com';
  IF v_email IS NOT NULL THEN
    UPDATE employees_master 
    SET email = v_email, auth_id = (SELECT id FROM auth.users WHERE email = v_email)
    WHERE nrp = 'NRP001';
  END IF;
END $$;
