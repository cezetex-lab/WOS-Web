-- Pilar 5: Fleksibilitas Platform (4 tables + 3 RPCs)

-- TABLES
CREATE TABLE IF NOT EXISTS employee_custom_fields (
  id SERIAL PRIMARY KEY, business_id TEXT NOT NULL,
  field_key TEXT NOT NULL, field_label TEXT NOT NULL,
  field_type TEXT NOT NULL DEFAULT 'text', options JSONB,
  is_required BOOLEAN DEFAULT false, created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (business_id, field_key)
);
ALTER TABLE employee_custom_fields ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ecf_admin ON employee_custom_fields;
CREATE POLICY ecf_admin ON employee_custom_fields FOR ALL USING (authz_check_admin('employee.view_all'));

CREATE TABLE IF NOT EXISTS employee_custom_values (
  id SERIAL PRIMARY KEY, nrp TEXT NOT NULL,
  field_id INT NOT NULL, value TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW(), UNIQUE (nrp, field_id)
);
ALTER TABLE employee_custom_values ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ecv_own ON employee_custom_values;
CREATE POLICY ecv_own ON employee_custom_values FOR ALL USING (nrp = authz_current_nrp() OR authz_check_admin('employee.view_all'));

CREATE TABLE IF NOT EXISTS vendors (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
  vendor_name TEXT NOT NULL, vendor_type TEXT,
  contact_person TEXT, email TEXT, phone TEXT, address TEXT,
  is_active BOOLEAN DEFAULT true, created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS vendor_admin ON vendors;
CREATE POLICY vendor_admin ON vendors FOR ALL USING (authz_check_admin('employee.view_all'));

CREATE TABLE IF NOT EXISTS vendor_contracts (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
  vendor_id TEXT NOT NULL, contract_name TEXT NOT NULL,
  start_date DATE, end_date DATE, value NUMERIC,
  status TEXT DEFAULT 'ACTIVE', created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE vendor_contracts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS vc_admin ON vendor_contracts;
CREATE POLICY vc_admin ON vendor_contracts FOR ALL USING (authz_check_admin('employee.view_all'));

CREATE OR REPLACE FUNCTION get_employee_custom_fields(p_nrp TEXT) RETURNS JSONB AS $$ DECLARE v_caller TEXT; BEGIN v_caller := authz_current_nrp(); IF v_caller IS NULL OR (p_nrp != v_caller AND NOT authz_check_admin('employee.view_all')) THEN RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak'); END IF; RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(row_to_json(t)),'[]'::jsonb)) FROM (SELECT ecf.field_key, ecf.field_label, ecf.field_type, ecv.value FROM employee_custom_fields ecf LEFT JOIN employee_custom_values ecv ON ecv.field_id=ecf.id AND ecv.nrp=p_nrp WHERE ecf.is_active IS NOT FALSE ORDER BY ecf.id) t); END; $$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION list_vendors() RETURNS JSONB AS $$ BEGIN IF NOT authz_check_admin('employee.view_all') THEN RETURN jsonb_build_object('ok', false, 'msg', 'Admin only'); END IF; RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(row_to_json(t)),'[]'::jsonb)) FROM (SELECT * FROM vendors WHERE is_active=true ORDER BY vendor_name) t); END; $$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION create_vendor(p_name TEXT, p_type TEXT DEFAULT NULL, p_contact TEXT DEFAULT NULL, p_email TEXT DEFAULT NULL, p_phone TEXT DEFAULT NULL) RETURNS JSONB AS $$ DECLARE v_id TEXT; BEGIN IF NOT authz_check_admin('employee.view_all') THEN RETURN jsonb_build_object('ok', false, 'msg', 'Admin only'); END IF; v_id := gen_random_uuid()::TEXT; INSERT INTO vendors (id, vendor_name, vendor_type, contact_person, email, phone) VALUES (v_id, p_name, p_type, p_contact, p_email, p_phone); RETURN jsonb_build_object('ok', true, 'id', v_id); END; $$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION get_employee_custom_fields(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION list_vendors() TO authenticated;
GRANT EXECUTE ON FUNCTION create_vendor(TEXT,TEXT,TEXT,TEXT,TEXT) TO authenticated;
