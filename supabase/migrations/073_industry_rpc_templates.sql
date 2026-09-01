-- INSIGHTWOS V6 - INDUSTRY RPC TEMPLATES (HARI 5)
-- 21 template: Mining 7, Estate 7, Mill 7
-- Setiap RPC: check_module_access + auth.uid() + business_unit_id filter

-- mining_simper
CREATE OR REPLACE FUNCTION get_mining_simper(p_page INT DEFAULT 1, p_limit INT DEFAULT 20)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_bu_id TEXT;
  v_result JSONB;
BEGIN
  IF v_ctx IS NULL THEN RETURN '[]'::JSONB; END IF;
  IF NOT check_module_access('mining_simper', 1) THEN RETURN '[]'::JSONB; END IF;
  v_bu_id := (v_ctx->>'business_unit_id')::TEXT;
  SELECT jsonb_agg(jsonb_build_object(
    'id', t.id, 'nrp', t.nrp, 'nama', t.nama, 'simper_type', t.simper_type, 'status', t.status, 'issued_date', t.issued_date, 'expiry_date', t.expiry_date, 'site', t.site
  )) INTO v_result
  FROM (SELECT id, nrp, nama, simper_type, status, issued_date, expiry_date, site FROM mining_simper
  WHERE business_unit_id = v_bu_id
  ORDER BY created_at DESC NULLS LAST
  LIMIT p_limit OFFSET (p_page - 1) * p_limit) t;
  RETURN COALESCE(v_result, '[]'::JSONB);
END; $$
LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- mining_equipment
CREATE OR REPLACE FUNCTION get_mining_equipment(p_page INT DEFAULT 1, p_limit INT DEFAULT 20)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_bu_id TEXT;
  v_result JSONB;
BEGIN
  IF v_ctx IS NULL THEN RETURN '[]'::JSONB; END IF;
  IF NOT check_module_access('mining_equipment', 1) THEN RETURN '[]'::JSONB; END IF;
  v_bu_id := (v_ctx->>'business_unit_id')::TEXT;
  SELECT jsonb_agg(jsonb_build_object(
    'id', t.id, 'equipment_code', t.equipment_code, 'equipment_name', t.equipment_name, 'type', t.type, 'status', t.status, 'operator_nrp', t.operator_nrp, 'operator_nama', t.operator_nama, 'last_maintenance', t.last_maintenance
  )) INTO v_result
  FROM (SELECT id, equipment_code, equipment_name, type, status, operator_nrp, operator_nama, last_maintenance FROM mining_equipment
  WHERE business_unit_id = v_bu_id
  ORDER BY created_at DESC NULLS LAST
  LIMIT p_limit OFFSET (p_page - 1) * p_limit) t;
  RETURN COALESCE(v_result, '[]'::JSONB);
END; $$
LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- mining_production
CREATE OR REPLACE FUNCTION get_mining_production(p_date DATE DEFAULT CURRENT_DATE)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_bu_id TEXT;
  v_result JSONB;
BEGIN
  IF v_ctx IS NULL THEN RETURN '[]'::JSONB; END IF;
  IF NOT check_module_access('mining_production', 1) THEN RETURN '[]'::JSONB; END IF;
  v_bu_id := (v_ctx->>'business_unit_id')::TEXT;
  SELECT jsonb_agg(jsonb_build_object(
    'id', t.id, 'date', t.date, 'pit_name', t.pit_name, 'tonnage', t.tonnage, 'truck_count', t.truck_count, 'fuel_used', t.fuel_used, 'status', t.status
  )) INTO v_result
  FROM (SELECT id, date, pit_name, tonnage, truck_count, fuel_used, status FROM mining_production
  WHERE business_unit_id = v_bu_id
  ORDER BY created_at DESC NULLS LAST
  LIMIT p_limit OFFSET (p_page - 1) * p_limit) t;
  RETURN COALESCE(v_result, '[]'::JSONB);
END; $$
LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- mining_fuel
CREATE OR REPLACE FUNCTION get_mining_fuel(p_date DATE DEFAULT CURRENT_DATE)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_bu_id TEXT;
  v_result JSONB;
BEGIN
  IF v_ctx IS NULL THEN RETURN '[]'::JSONB; END IF;
  IF NOT check_module_access('mining_fuel', 1) THEN RETURN '[]'::JSONB; END IF;
  v_bu_id := (v_ctx->>'business_unit_id')::TEXT;
  SELECT jsonb_agg(jsonb_build_object(
    'id', t.id, 'date', t.date, 'equipment_code', t.equipment_code, 'fuel_type', t.fuel_type, 'liters', t.liters, 'driver_nrp', t.driver_nrp, 'driver_nama', t.driver_nama
  )) INTO v_result
  FROM (SELECT id, date, equipment_code, fuel_type, liters, driver_nrp, driver_nama FROM mining_fuel
  WHERE business_unit_id = v_bu_id
  ORDER BY created_at DESC NULLS LAST
  LIMIT p_limit OFFSET (p_page - 1) * p_limit) t;
  RETURN COALESCE(v_result, '[]'::JSONB);
END; $$
LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- mining_fatigue
CREATE OR REPLACE FUNCTION get_mining_fatigue(p_page INT DEFAULT 1, p_limit INT DEFAULT 20)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_bu_id TEXT;
  v_result JSONB;
BEGIN
  IF v_ctx IS NULL THEN RETURN '[]'::JSONB; END IF;
  IF NOT check_module_access('mining_fatigue', 1) THEN RETURN '[]'::JSONB; END IF;
  v_bu_id := (v_ctx->>'business_unit_id')::TEXT;
  SELECT jsonb_agg(jsonb_build_object(
    'id', t.id, 'nrp', t.nrp, 'nama', t.nama, 'shift', t.shift, 'fatigue_level', t.fatigue_level, 'hours_worked', t.hours_worked, 'rest_hours', t.rest_hours, 'status', t.status
  )) INTO v_result
  FROM (SELECT id, nrp, nama, shift, fatigue_level, hours_worked, rest_hours, status FROM mining_fatigue
  WHERE business_unit_id = v_bu_id
  ORDER BY created_at DESC NULLS LAST
  LIMIT p_limit OFFSET (p_page - 1) * p_limit) t;
  RETURN COALESCE(v_result, '[]'::JSONB);
END; $$
LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- mining_safety
CREATE OR REPLACE FUNCTION get_mining_safety(p_date DATE DEFAULT CURRENT_DATE)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_bu_id TEXT;
  v_result JSONB;
BEGIN
  IF v_ctx IS NULL THEN RETURN '[]'::JSONB; END IF;
  IF NOT check_module_access('mining_safety', 1) THEN RETURN '[]'::JSONB; END IF;
  v_bu_id := (v_ctx->>'business_unit_id')::TEXT;
  SELECT jsonb_agg(jsonb_build_object(
    'id', t.id, 'date', t.date, 'incident_type', t.incident_type, 'severity', t.severity, 'location', t.location, 'description', t.description, 'reported_by', t.reported_by, 'status', t.status
  )) INTO v_result
  FROM (SELECT id, date, incident_type, severity, location, description, reported_by, status FROM mining_safety
  WHERE business_unit_id = v_bu_id
  ORDER BY created_at DESC NULLS LAST
  LIMIT p_limit OFFSET (p_page - 1) * p_limit) t;
  RETURN COALESCE(v_result, '[]'::JSONB);
END; $$
LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- mining_jsa
CREATE OR REPLACE FUNCTION get_mining_jsa(p_page INT DEFAULT 1, p_limit INT DEFAULT 20)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_bu_id TEXT;
  v_result JSONB;
BEGIN
  IF v_ctx IS NULL THEN RETURN '[]'::JSONB; END IF;
  IF NOT check_module_access('mining_jsa', 1) THEN RETURN '[]'::JSONB; END IF;
  v_bu_id := (v_ctx->>'business_unit_id')::TEXT;
  SELECT jsonb_agg(jsonb_build_object(
    'id', t.id, 'job_name', t.job_name, 'hazard', t.hazard, 'risk_level', t.risk_level, 'control_measure', t.control_measure, 'prepared_by', t.prepared_by, 'approved_by', t.approved_by, 'status', t.status
  )) INTO v_result
  FROM (SELECT id, job_name, hazard, risk_level, control_measure, prepared_by, approved_by, status FROM mining_jsa
  WHERE business_unit_id = v_bu_id
  ORDER BY created_at DESC NULLS LAST
  LIMIT p_limit OFFSET (p_page - 1) * p_limit) t;
  RETURN COALESCE(v_result, '[]'::JSONB);
END; $$
LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- estate_harvest
CREATE OR REPLACE FUNCTION get_estate_harvest(p_date DATE DEFAULT CURRENT_DATE)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_bu_id TEXT;
  v_result JSONB;
BEGIN
  IF v_ctx IS NULL THEN RETURN '[]'::JSONB; END IF;
  IF NOT check_module_access('estate_harvest', 1) THEN RETURN '[]'::JSONB; END IF;
  v_bu_id := (v_ctx->>'business_unit_id')::TEXT;
  SELECT jsonb_agg(jsonb_build_object('id', t.id, 'date', t.date, 'block_name', t.block_name, 'tonnage', t.tonnage, 'harvester_nrp', t.harvester_nrp, 'harvester_nama', t.harvester_nama, 'quality', t.quality, 'status', t.status)) INTO v_result
  FROM (SELECT id, date, block_name, tonnage, harvester_nrp, harvester_nama, quality, status FROM estate_harvest
  WHERE business_unit_id = v_bu_id
  ORDER BY created_at DESC NULLS LAST
  LIMIT p_limit OFFSET (p_page - 1) * p_limit) t;
  RETURN COALESCE(v_result, '[]'::JSONB);
END; $$
LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- estate_blocks
CREATE OR REPLACE FUNCTION get_estate_blocks(p_page INT DEFAULT 1, p_limit INT DEFAULT 20)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_bu_id TEXT;
  v_result JSONB;
BEGIN
  IF v_ctx IS NULL THEN RETURN '[]'::JSONB; END IF;
  IF NOT check_module_access('estate_blocks', 1) THEN RETURN '[]'::JSONB; END IF;
  v_bu_id := (v_ctx->>'business_unit_id')::TEXT;
  SELECT jsonb_agg(jsonb_build_object('id', t.id, 'block_code', t.block_code, 'block_name', t.block_name, 'area_ha', t.area_ha, 'plant_age', t.plant_age, 'yield_potential', t.yield_potential, 'status', t.status)) INTO v_result
  FROM (SELECT id, block_code, block_name, area_ha, plant_age, yield_potential, status FROM estate_blocks
  WHERE business_unit_id = v_bu_id
  ORDER BY created_at DESC NULLS LAST
  LIMIT p_limit OFFSET (p_page - 1) * p_limit) t;
  RETURN COALESCE(v_result, '[]'::JSONB);
END; $$
LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- estate_irrigation
CREATE OR REPLACE FUNCTION get_estate_irrigation(p_date DATE DEFAULT CURRENT_DATE)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_bu_id TEXT;
  v_result JSONB;
BEGIN
  IF v_ctx IS NULL THEN RETURN '[]'::JSONB; END IF;
  IF NOT check_module_access('estate_irrigation', 1) THEN RETURN '[]'::JSONB; END IF;
  v_bu_id := (v_ctx->>'business_unit_id')::TEXT;
  SELECT jsonb_agg(jsonb_build_object('id', t.id, 'date', t.date, 'block_name', t.block_name, 'water_level', t.water_level, 'ph_level', t.ph_level, 'status', t.status, 'operator_nama', t.operator_nama)) INTO v_result
  FROM (SELECT id, date, block_name, water_level, ph_level, status, operator_nama FROM estate_irrigation
  WHERE business_unit_id = v_bu_id
  ORDER BY created_at DESC NULLS LAST
  LIMIT p_limit OFFSET (p_page - 1) * p_limit) t;
  RETURN COALESCE(v_result, '[]'::JSONB);
END; $$
LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- estate_nursery
CREATE OR REPLACE FUNCTION get_estate_nursery(p_page INT DEFAULT 1, p_limit INT DEFAULT 20)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_bu_id TEXT;
  v_result JSONB;
BEGIN
  IF v_ctx IS NULL THEN RETURN '[]'::JSONB; END IF;
  IF NOT check_module_access('estate_nursery', 1) THEN RETURN '[]'::JSONB; END IF;
  v_bu_id := (v_ctx->>'business_unit_id')::TEXT;
  SELECT jsonb_agg(jsonb_build_object('id', t.id, 'nursery_name', t.nursery_name, 'seedling_type', t.seedling_type, 'quantity', t.quantity, 'age_weeks', t.age_weeks, 'health_status', t.health_status, 'target_date', t.target_date)) INTO v_result
  FROM (SELECT id, nursery_name, seedling_type, quantity, age_weeks, health_status, target_date FROM estate_nursery
  WHERE business_unit_id = v_bu_id
  ORDER BY created_at DESC NULLS LAST
  LIMIT p_limit OFFSET (p_page - 1) * p_limit) t;
  RETURN COALESCE(v_result, '[]'::JSONB);
END; $$
LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- estate_transport
CREATE OR REPLACE FUNCTION get_estate_transport(p_date DATE DEFAULT CURRENT_DATE)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_bu_id TEXT;
  v_result JSONB;
BEGIN
  IF v_ctx IS NULL THEN RETURN '[]'::JSONB; END IF;
  IF NOT check_module_access('estate_transport', 1) THEN RETURN '[]'::JSONB; END IF;
  v_bu_id := (v_ctx->>'business_unit_id')::TEXT;
  SELECT jsonb_agg(jsonb_build_object('id', t.id, 'date', t.date, 'vehicle_code', t.vehicle_code, 'driver_nama', t.driver_nama, 'tonnage', t.tonnage, 'origin', t.origin, 'destination', t.destination, 'status', t.status)) INTO v_result
  FROM (SELECT id, date, vehicle_code, driver_nama, tonnage, origin, destination, status FROM estate_transport
  WHERE business_unit_id = v_bu_id
  ORDER BY created_at DESC NULLS LAST
  LIMIT p_limit OFFSET (p_page - 1) * p_limit) t;
  RETURN COALESCE(v_result, '[]'::JSONB);
END; $$
LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- estate_field
CREATE OR REPLACE FUNCTION get_estate_field(p_date DATE DEFAULT CURRENT_DATE)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_bu_id TEXT;
  v_result JSONB;
BEGIN
  IF v_ctx IS NULL THEN RETURN '[]'::JSONB; END IF;
  IF NOT check_module_access('estate_field', 1) THEN RETURN '[]'::JSONB; END IF;
  v_bu_id := (v_ctx->>'business_unit_id')::TEXT;
  SELECT jsonb_agg(jsonb_build_object('id', t.id, 'date', t.date, 'activity_type', t.activity_type, 'block_name', t.block_name, 'worker_count', t.worker_count, 'description', t.description, 'supervisor_nama', t.supervisor_nama)) INTO v_result
  FROM (SELECT id, date, activity_type, block_name, worker_count, description, supervisor_nama FROM estate_field
  WHERE business_unit_id = v_bu_id
  ORDER BY created_at DESC NULLS LAST
  LIMIT p_limit OFFSET (p_page - 1) * p_limit) t;
  RETURN COALESCE(v_result, '[]'::JSONB);
END; $$
LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- estate_yield
CREATE OR REPLACE FUNCTION get_estate_yield(p_month TEXT DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_bu_id TEXT;
  v_result JSONB;
BEGIN
  IF v_ctx IS NULL THEN RETURN '[]'::JSONB; END IF;
  IF NOT check_module_access('estate_yield', 1) THEN RETURN '[]'::JSONB; END IF;
  v_bu_id := (v_ctx->>'business_unit_id')::TEXT;
  SELECT jsonb_agg(jsonb_build_object('id', t.id, 'month', t.month, 'block_name', t.block_name, 'actual_tonnage', t.actual_tonnage, 'target_tonnage', t.target_tonnage, 'achievement_pct', t.achievement_pct, 'status', t.status)) INTO v_result
  FROM (SELECT id, month, block_name, actual_tonnage, target_tonnage, achievement_pct, status FROM estate_yield
  WHERE business_unit_id = v_bu_id
  ORDER BY created_at DESC NULLS LAST
  LIMIT p_limit OFFSET (p_page - 1) * p_limit) t;
  RETURN COALESCE(v_result, '[]'::JSONB);
END; $$
LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- mill_boiler
CREATE OR REPLACE FUNCTION get_mill_boiler(p_date DATE DEFAULT CURRENT_DATE)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_bu_id TEXT;
  v_result JSONB;
BEGIN
  IF v_ctx IS NULL THEN RETURN '[]'::JSONB; END IF;
  IF NOT check_module_access('mill_boiler', 1) THEN RETURN '[]'::JSONB; END IF;
  v_bu_id := (v_ctx->>'business_unit_id')::TEXT;
  SELECT jsonb_agg(jsonb_build_object('id', t.id, 'date', t.date, 'boiler_id', t.boiler_id, 'temperature', t.temperature, 'pressure', t.pressure, 'fuel_consumption', t.fuel_consumption, 'efficiency_pct', t.efficiency_pct, 'status', t.status)) INTO v_result
  FROM (SELECT id, date, boiler_id, temperature, pressure, fuel_consumption, efficiency_pct, status FROM mill_boiler
  WHERE business_unit_id = v_bu_id
  ORDER BY created_at DESC NULLS LAST
  LIMIT p_limit OFFSET (p_page - 1) * p_limit) t;
  RETURN COALESCE(v_result, '[]'::JSONB);
END; $$
LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- mill_press
CREATE OR REPLACE FUNCTION get_mill_press(p_date DATE DEFAULT CURRENT_DATE)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_bu_id TEXT;
  v_result JSONB;
BEGIN
  IF v_ctx IS NULL THEN RETURN '[]'::JSONB; END IF;
  IF NOT check_module_access('mill_press', 1) THEN RETURN '[]'::JSONB; END IF;
  v_bu_id := (v_ctx->>'business_unit_id')::TEXT;
  SELECT jsonb_agg(jsonb_build_object('id', t.id, 'date', t.date, 'press_id', t.press_id, 'rpm', t.rpm, 'load_tons', t.load_tons, 'oil_quality', t.oil_quality, 'status', t.status)) INTO v_result
  FROM (SELECT id, date, press_id, rpm, load_tons, oil_quality, status FROM mill_press
  WHERE business_unit_id = v_bu_id
  ORDER BY created_at DESC NULLS LAST
  LIMIT p_limit OFFSET (p_page - 1) * p_limit) t;
  RETURN COALESCE(v_result, '[]'::JSONB);
END; $$
LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- mill_qc
CREATE OR REPLACE FUNCTION get_mill_qc(p_date DATE DEFAULT CURRENT_DATE)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_bu_id TEXT;
  v_result JSONB;
BEGIN
  IF v_ctx IS NULL THEN RETURN '[]'::JSONB; END IF;
  IF NOT check_module_access('mill_qc', 1) THEN RETURN '[]'::JSONB; END IF;
  v_bu_id := (v_ctx->>'business_unit_id')::TEXT;
  SELECT jsonb_agg(jsonb_build_object('id', t.id, 'date', t.date, 'batch_id', t.batch_id, 'ffa_pct', t.ffa_pct, 'moisture_pct', t.moisture_pct, 'dobi', t.dobi, 'grade', t.grade, 'status', t.status)) INTO v_result
  FROM (SELECT id, date, batch_id, ffa_pct, moisture_pct, dobi, grade, status FROM mill_qc
  WHERE business_unit_id = v_bu_id
  ORDER BY created_at DESC NULLS LAST
  LIMIT p_limit OFFSET (p_page - 1) * p_limit) t;
  RETURN COALESCE(v_result, '[]'::JSONB);
END; $$
LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- mill_packing
CREATE OR REPLACE FUNCTION get_mill_packing(p_date DATE DEFAULT CURRENT_DATE)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_bu_id TEXT;
  v_result JSONB;
BEGIN
  IF v_ctx IS NULL THEN RETURN '[]'::JSONB; END IF;
  IF NOT check_module_access('mill_packing', 1) THEN RETURN '[]'::JSONB; END IF;
  v_bu_id := (v_ctx->>'business_unit_id')::TEXT;
  SELECT jsonb_agg(jsonb_build_object('id', t.id, 'date', t.date, 'product_type', t.product_type, 'quantity_kg', t.quantity_kg, 'pallet_count', t.pallet_count, 'warehouse', t.warehouse, 'status', t.status)) INTO v_result
  FROM (SELECT id, date, product_type, quantity_kg, pallet_count, warehouse, status FROM mill_packing
  WHERE business_unit_id = v_bu_id
  ORDER BY created_at DESC NULLS LAST
  LIMIT p_limit OFFSET (p_page - 1) * p_limit) t;
  RETURN COALESCE(v_result, '[]'::JSONB);
END; $$
LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- mill_maintenance
CREATE OR REPLACE FUNCTION get_mill_maintenance(p_page INT DEFAULT 1, p_limit INT DEFAULT 20)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_bu_id TEXT;
  v_result JSONB;
BEGIN
  IF v_ctx IS NULL THEN RETURN '[]'::JSONB; END IF;
  IF NOT check_module_access('mill_maintenance', 1) THEN RETURN '[]'::JSONB; END IF;
  v_bu_id := (v_ctx->>'business_unit_id')::TEXT;
  SELECT jsonb_agg(jsonb_build_object('id', t.id, 'equipment_id', t.equipment_id, 'equipment_name', t.equipment_name, 'maintenance_type', t.maintenance_type, 'scheduled_date', t.scheduled_date, 'completed_date', t.completed_date, 'technician_nama', t.technician_nama, 'status', t.status)) INTO v_result
  FROM (SELECT id, equipment_id, equipment_name, maintenance_type, scheduled_date, completed_date, technician_nama, status FROM mill_maintenance
  WHERE business_unit_id = v_bu_id
  ORDER BY created_at DESC NULLS LAST
  LIMIT p_limit OFFSET (p_page - 1) * p_limit) t;
  RETURN COALESCE(v_result, '[]'::JSONB);
END; $$
LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- mill_breakdown
CREATE OR REPLACE FUNCTION get_mill_breakdown(p_page INT DEFAULT 1, p_limit INT DEFAULT 20)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_bu_id TEXT;
  v_result JSONB;
BEGIN
  IF v_ctx IS NULL THEN RETURN '[]'::JSONB; END IF;
  IF NOT check_module_access('mill_breakdown', 1) THEN RETURN '[]'::JSONB; END IF;
  v_bu_id := (v_ctx->>'business_unit_id')::TEXT;
  SELECT jsonb_agg(jsonb_build_object('id', t.id, 'equipment_id', t.equipment_id, 'equipment_name', t.equipment_name, 'breakdown_type', t.breakdown_type, 'severity', t.severity, 'start_time', t.start_time, 'end_time', t.end_time, 'status', t.status)) INTO v_result
  FROM (SELECT id, equipment_id, equipment_name, breakdown_type, severity, start_time, end_time, status FROM mill_breakdown
  WHERE business_unit_id = v_bu_id
  ORDER BY created_at DESC NULLS LAST
  LIMIT p_limit OFFSET (p_page - 1) * p_limit) t;
  RETURN COALESCE(v_result, '[]'::JSONB);
END; $$
LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- mill_shift
CREATE OR REPLACE FUNCTION get_mill_shift(p_date DATE DEFAULT CURRENT_DATE)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_bu_id TEXT;
  v_result JSONB;
BEGIN
  IF v_ctx IS NULL THEN RETURN '[]'::JSONB; END IF;
  IF NOT check_module_access('mill_shift', 1) THEN RETURN '[]'::JSONB; END IF;
  v_bu_id := (v_ctx->>'business_unit_id')::TEXT;
  SELECT jsonb_agg(jsonb_build_object('id', t.id, 'date', t.date, 'shift_name', t.shift_name, 'start_time', t.start_time, 'end_time', t.end_time, 'headcount', t.headcount, 'supervisor_nama', t.supervisor_nama, 'status', t.status)) INTO v_result
  FROM (SELECT id, date, shift_name, start_time, end_time, headcount, supervisor_nama, status FROM mill_shift
  WHERE business_unit_id = v_bu_id
  ORDER BY created_at DESC NULLS LAST
  LIMIT p_limit OFFSET (p_page - 1) * p_limit) t;
  RETURN COALESCE(v_result, '[]'::JSONB);
END; $$
LANGUAGE plpgsql STABLE SECURITY DEFINER;

