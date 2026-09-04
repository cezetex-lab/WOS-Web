-- Migration 140: Recreate industry tables + fix 073 RPC column names
-- mining_simper, mining_equipment, estate_harvest were in 074 (deleted)

CREATE TABLE IF NOT EXISTS mining_simper (
  id SERIAL PRIMARY KEY,
  simper_no TEXT NOT NULL, applicant_name TEXT NOT NULL, company TEXT,
  commodity TEXT DEFAULT "COAL", area_hectare NUMERIC DEFAULT 0,
  status TEXT DEFAULT "PENDING" CHECK (status IN ("PENDING","ACTIVE","EXPIRED","REVOKED")),
  issue_date DATE, expiry_date DATE, notes TEXT, business_unit_id TEXT, created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS mining_equipment (
  id SERIAL PRIMARY KEY,
  equipment_code TEXT NOT NULL UNIQUE, equipment_name TEXT NOT NULL,
  category TEXT DEFAULT "HEAVY",
  status TEXT DEFAULT "OFFLINE" CHECK (status IN ("RUNNING","STANDBY","MAINTENANCE","OFFLINE")),
  location TEXT, hours_run NUMERIC DEFAULT 0, fuel_level NUMERIC DEFAULT 100,
  last_maintenance DATE, next_maintenance DATE, business_unit_id TEXT, created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS estate_harvest (
  id SERIAL PRIMARY KEY,
  block_name TEXT NOT NULL, harvest_date DATE DEFAULT CURRENT_DATE,
  tonnage NUMERIC DEFAULT 0, harvester_nrp TEXT, harvester_nama TEXT,
  quality TEXT DEFAULT "GOOD",
  status TEXT DEFAULT "PENDING" CHECK (status IN ("PENDING","LOADED","TRANSPORTED","REJECTED")),
  business_unit_id TEXT, created_at TIMESTAMPTZ DEFAULT NOW()
);

DROP FUNCTION IF EXISTS get_mill_boiler(DATE);
CREATE OR REPLACE FUNCTION get_mill_boiler(p_date DATE DEFAULT CURRENT_DATE)
RETURNS JSONB AS $$
DECLARE v_bu TEXT := authz_get_bu(); v_result JSONB;
BEGIN
  IF NOT authz_check_admin('mill.boiler_view') THEN RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.'); END IF;
  SELECT jsonb_agg(jsonb_build_object('boiler_code', t.boiler_code, 'boiler_name', t.boiler_name, 'capacity_kg_hr', t.capacity_kg_hr, 'temperature_c', t.temperature_c, 'pressure_bar', t.pressure_bar, 'steam_flow_kg_hr', t.steam_flow_kg_hr, 'fuel_type', t.fuel_type, 'fuel_consumption_kg_hr', t.fuel_consumption_kg_hr, 'efficiency_pct', t.efficiency_pct, 'status', t.status, 'site_code', t.site_code)) INTO v_result FROM mill_boiler t WHERE site_code = v_bu OR v_bu IS NULL;
  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP FUNCTION IF EXISTS get_mill_press(DATE);
CREATE OR REPLACE FUNCTION get_mill_press(p_date DATE DEFAULT CURRENT_DATE)
RETURNS JSONB AS $$
DECLARE v_bu TEXT := authz_get_bu(); v_result JSONB;
BEGIN
  IF NOT authz_check_admin('mill.press_view') THEN RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.'); END IF;
  SELECT jsonb_agg(jsonb_build_object('press_code', t.press_code, 'press_name', t.press_name, 'capacity_tph', t.capacity_tph, 'rpm', t.rpm, 'torque_nm', t.torque_nm, 'temperature_c', t.temperature_c, 'vibration_mm_s', t.vibration_mm_s, 'oil_quality', t.oil_quality, 'status', t.status, 'site_code', t.site_code)) INTO v_result FROM mill_press t WHERE site_code = v_bu OR v_bu IS NULL;
  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP FUNCTION IF EXISTS get_mill_qc(DATE);
CREATE OR REPLACE FUNCTION get_mill_qc(p_date DATE DEFAULT CURRENT_DATE)
RETURNS JSONB AS $$
DECLARE v_bu TEXT := authz_get_bu(); v_result JSONB;
BEGIN
  IF NOT authz_check_admin('mill.qc_view') THEN RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.'); END IF;
  SELECT jsonb_agg(jsonb_build_object('batch_id', t.batch_id, 'sample_date', t.sample_date, 'ffa_pct', t.ffa_pct, 'moisture_pct', t.moisture_pct, 'dobi', t.dobi, 'color', t.color, 'dirt_pct', t.dirt_pct, 'result', t.result, 'tested_by', t.tested_by, 'site_code', t.site_code)) INTO v_result FROM mill_qc_results t WHERE site_code = v_bu OR v_bu IS NULL;
  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP FUNCTION IF EXISTS get_mining_simper(INT, INT);
CREATE OR REPLACE FUNCTION get_mining_simper(p_page INT DEFAULT 1, p_limit INT DEFAULT 20)
RETURNS JSONB AS $$
DECLARE v_bu TEXT := authz_get_bu(); v_result JSONB;
v_offset INT := (p_page - 1) * p_limit;
BEGIN
  IF NOT authz_check_admin('mining.simper_view') THEN RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.'); END IF;
  SELECT jsonb_agg(jsonb_build_object('simper_no', t.simper_no, 'applicant_name', t.applicant_name, 'company', t.company, 'commodity', t.commodity, 'area_hectare', t.area_hectare, 'status', t.status, 'issue_date', t.issue_date, 'expiry_date', t.expiry_date)) INTO v_result FROM mining_simper t WHERE business_unit_id = v_bu OR v_bu IS NULL ORDER BY t.created_at DESC LIMIT p_limit OFFSET v_offset;
  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP FUNCTION IF EXISTS get_mining_equipment(INT, INT);
CREATE OR REPLACE FUNCTION get_mining_equipment(p_page INT DEFAULT 1, p_limit INT DEFAULT 20)
RETURNS JSONB AS $$
DECLARE v_bu TEXT := authz_get_bu(); v_result JSONB;
v_offset INT := (p_page - 1) * p_limit;
BEGIN
  IF NOT authz_check_admin('mining.equipment_view') THEN RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.'); END IF;
  SELECT jsonb_agg(jsonb_build_object('equipment_code', t.equipment_code, 'equipment_name', t.equipment_name, 'category', t.category, 'status', t.status, 'hours_run', t.hours_run, 'fuel_level', t.fuel_level, 'location', t.location)) INTO v_result FROM mining_equipment t WHERE business_unit_id = v_bu OR v_bu IS NULL ORDER BY t.created_at DESC LIMIT p_limit OFFSET v_offset;
  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP FUNCTION IF EXISTS get_estate_harvest(DATE);
CREATE OR REPLACE FUNCTION get_estate_harvest(p_date DATE DEFAULT CURRENT_DATE)
RETURNS JSONB AS $$
DECLARE v_bu TEXT := authz_get_bu(); v_result JSONB;
BEGIN
  IF NOT authz_check_admin('estate.harvest_view') THEN RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.'); END IF;
  SELECT jsonb_agg(jsonb_build_object('block_name', t.block_name, 'harvest_date', t.harvest_date, 'tonnage', t.tonnage, 'harvester_nrp', t.harvester_nrp, 'harvester_nama', t.harvester_nama, 'quality', t.quality, 'status', t.status)) INTO v_result FROM estate_harvest t WHERE harvest_date = p_date AND (business_unit_id = v_bu OR v_bu IS NULL);
  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

