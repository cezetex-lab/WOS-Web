-- 086: Branding — Logo & Company Settings

-- 1. Branding table
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

-- Seed default branding
INSERT INTO branding (id, company_name, tagline) 
VALUES ('main', 'insightWOS', 'Workforce Intelligence Platform')
ON CONFLICT (id) DO NOTHING;

-- RLS
ALTER TABLE branding ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS br_select ON branding;
CREATE POLICY br_select ON branding FOR SELECT USING (TRUE);
DROP POLICY IF EXISTS br_insert ON branding;
CREATE POLICY br_insert ON branding FOR INSERT USING (TRUE);
DROP POLICY IF EXISTS br_update ON branding;
CREATE POLICY br_update ON branding FOR UPDATE USING (TRUE);

-- 2. Get branding (public — anyone can read)
CREATE OR REPLACE FUNCTION get_branding()
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT row_to_json(b)::jsonb INTO v_result
  FROM branding b WHERE b.id = 'main';
  RETURN COALESCE(v_result, jsonb_build_object('company_name', 'insightWOS', 'tagline', 'Workforce Intelligence Platform'));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Update branding (owner only)
CREATE OR REPLACE FUNCTION update_branding(
  p_company_name TEXT DEFAULT NULL,
  p_tagline TEXT DEFAULT NULL,
  p_logo_url TEXT DEFAULT NULL,
  p_primary_color TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_nrp TEXT;
  v_role TEXT;
BEGIN
  -- Get user
  SELECT em.nrp, ur.role INTO v_nrp, v_role
  FROM employees_master em
  LEFT JOIN user_roles ur ON em.nrp = ur.nrp
  WHERE em.auth_id = auth.uid() LIMIT 1;

  -- Only owner can update
  IF v_role != 'owner' THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Hanya Owner yang bisa mengubah branding');
  END IF;

  UPDATE branding SET
    company_name = COALESCE(p_company_name, company_name),
    tagline = COALESCE(p_tagline, tagline),
    logo_url = COALESCE(p_logo_url, logo_url),
    primary_color = COALESCE(p_primary_color, primary_color),
    updated_at = NOW(),
    updated_by = v_nrp
  WHERE id = 'main';

  -- Log
  INSERT INTO audit_log_owner (action, details, performed_by)
  VALUES ('update_branding', jsonb_build_object('by', v_nrp), v_nrp);

  RETURN jsonb_build_object('ok', true, 'msg', 'Branding updated');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
