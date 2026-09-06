-- ================================================================
-- 181_fix_estate_mill_columns.sql
-- Fixes column mismatches in 180's estate/mill overloads
-- All column references verified against actual DB table schemas.
-- ================================================================

-- ════════════════════════════════════════════════════════════════
-- ESTATE FUNCTIONS — fix column mappings
-- ════════════════════════════════════════════════════════════════

-- get_transport_dispatch(p_bu_id): origin_block→origin, vehicle_id→vehicle_code, driver_nrp→driver_nama
CREATE OR REPLACE FUNCTION public.get_transport_dispatch(p_bu_id text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions
AS $function$
BEGIN
  RETURN (SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(sub), '[]'::jsonb))
  FROM (
    SELECT jsonb_build_object(
      'id', t.id, 'date', t.date, 'origin', t.origin,
      'destination', t.destination, 'tonnage', t.tonnage,
      'vehicle_code', t.vehicle_code, 'driver_nama', t.driver_nama, 'status', t.status
    ) AS sub
    FROM estate_transport t
    WHERE p_bu_id IS NULL OR t.business_unit_id = p_bu_id
    ORDER BY t.date DESC
  ) sub);
END;
$function$;

-- get_nursery_data(p_bu_id): old cols (date,block_name,seedling_count,survival_rate,nursery_type) → (nursery_name,seedling_type,quantity,age_weeks,health_status,target_date)
CREATE OR REPLACE FUNCTION public.get_nursery_data(p_bu_id text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions
AS $function$
BEGIN
  RETURN (SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(sub), '[]'::jsonb))
  FROM (
    SELECT jsonb_build_object(
      'id', n.id, 'nursery_name', n.nursery_name, 'seedling_type', n.seedling_type,
      'quantity', n.quantity, 'age_weeks', n.age_weeks,
      'health_status', n.health_status, 'target_date', n.target_date
    ) AS sub
    FROM estate_nursery n
    WHERE p_bu_id IS NULL OR n.business_unit_id = p_bu_id
    ORDER BY n.target_date DESC
  ) sub);
END;
$function$;

-- get_irrigation_status(p_bu_id): water_flow→water_level, remove duration_hours/method, add ph_level/operator_nama
CREATE OR REPLACE FUNCTION public.get_irrigation_status(p_bu_id text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions
AS $function$
BEGIN
  RETURN (SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(sub), '[]'::jsonb))
  FROM (
    SELECT jsonb_build_object(
      'id', i.id, 'date', i.date, 'block_name', i.block_name,
      'water_level', i.water_level, 'ph_level', i.ph_level,
      'status', i.status, 'operator_nama', i.operator_nama
    ) AS sub
    FROM estate_irrigation i
    WHERE p_bu_id IS NULL OR i.business_unit_id = p_bu_id
    ORDER BY i.date DESC
  ) sub);
END;
$function$;

-- get_yield_data(p_bu_id): date→month, yield_tonnage→actual_tonnage, add target_tonnage/achievement_pct, remove quality_grade/harvest_method
CREATE OR REPLACE FUNCTION public.get_yield_data(p_bu_id text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions
AS $function$
BEGIN
  RETURN (SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(sub), '[]'::jsonb))
  FROM (
    SELECT jsonb_build_object(
      'id', y.id, 'month', y.month, 'block_name', y.block_name,
      'actual_tonnage', y.actual_tonnage, 'target_tonnage', y.target_tonnage,
      'achievement_pct', y.achievement_pct, 'status', y.status
    ) AS sub
    FROM estate_yield y
    WHERE p_bu_id IS NULL OR y.business_unit_id = p_bu_id
    ORDER BY y.month DESC
  ) sub);
END;
$function$;


-- ════════════════════════════════════════════════════════════════
-- MILL FUNCTIONS — fix column mappings
-- ════════════════════════════════════════════════════════════════

-- get_boiler_status(p_site_code): fix column names to match mill_boiler
CREATE OR REPLACE FUNCTION public.get_boiler_status(p_site_code text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions
AS $function$
BEGIN
  RETURN (SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(sub), '[]'::jsonb))
  FROM (
    SELECT jsonb_build_object(
      'id', b.id, 'boiler_code', b.boiler_code, 'boiler_name', b.boiler_name,
      'capacity_kg_hr', b.capacity_kg_hr, 'status', b.status,
      'temperature_c', b.temperature_c, 'pressure_bar', b.pressure_bar,
      'steam_flow_kg_hr', b.steam_flow_kg_hr, 'fuel_type', b.fuel_type,
      'fuel_consumption_kg_hr', b.fuel_consumption_kg_hr, 'efficiency_pct', b.efficiency_pct,
      'last_maintenance', b.last_maintenance, 'next_maintenance', b.next_maintenance,
      'site_code', b.site_code
    ) AS sub
    FROM mill_boiler b
    WHERE p_site_code IS NULL OR b.site_code = p_site_code
    ORDER BY b.id
  ) sub);
END;
$function$;

-- get_press_status(p_site_code): fix column names to match mill_press
CREATE OR REPLACE FUNCTION public.get_press_status(p_site_code text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions
AS $function$
BEGIN
  RETURN (SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(sub), '[]'::jsonb))
  FROM (
    SELECT jsonb_build_object(
      'id', p.id, 'press_code', p.press_code, 'press_name', p.press_name,
      'capacity_tph', p.capacity_tph, 'status', p.status,
      'rpm', p.rpm, 'torque_nm', p.torque_nm, 'temperature_c', p.temperature_c,
      'vibration_mm_s', p.vibration_mm_s, 'oil_quality', p.oil_quality,
      'last_maintenance', p.last_maintenance, 'next_maintenance', p.next_maintenance,
      'site_code', p.site_code
    ) AS sub
    FROM mill_press p
    WHERE p_site_code IS NULL OR p.site_code = p_site_code
    ORDER BY p.id
  ) sub);
END;
$function$;

-- get_qc_results(p_site_code): fix column names to match mill_qc_results
CREATE OR REPLACE FUNCTION public.get_qc_results(p_site_code text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions
AS $function$
BEGIN
  RETURN (SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(sub), '[]'::jsonb))
  FROM (
    SELECT jsonb_build_object(
      'id', q.id, 'batch_id', q.batch_id, 'sample_date', q.sample_date,
      'sample_time', q.sample_time, 'ffa_pct', q.ffa_pct, 'moisture_pct', q.moisture_pct,
      'dobi', q.dobi, 'color', q.color, 'dirt_pct', q.dirt_pct,
      'result', q.result, 'tested_by', q.tested_by, 'notes', q.notes,
      'site_code', q.site_code
    ) AS sub
    FROM mill_qc_results q
    WHERE p_site_code IS NULL OR q.site_code = p_site_code
    ORDER BY q.sample_date DESC
  ) sub);
END;
$function$;

-- get_packing_log(p_site_code): fix to use mill_packing actual columns
CREATE OR REPLACE FUNCTION public.get_packing_log(p_site_code text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions
AS $function$
BEGIN
  RETURN (SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(sub), '[]'::jsonb))
  FROM (
    SELECT jsonb_build_object(
      'id', pk.id, 'pack_date', pk.pack_date, 'pack_time', pk.pack_time,
      'product_type', pk.product_type, 'quantity_kg', pk.quantity_kg,
      'batch_id', pk.batch_id, 'destination', pk.destination,
      'truck_plate', pk.truck_plate, 'driver_name', pk.driver_name,
      'status', pk.status, 'qc_status', pk.qc_status,
      'operator_nrp', pk.operator_nrp, 'site_code', pk.site_code
    ) AS sub
    FROM mill_packing pk
    WHERE p_site_code IS NULL OR pk.site_code = p_site_code
    ORDER BY pk.pack_date DESC
  ) sub);
END;
$function$;

-- get_maintenance_schedule: must DROP old (p_status text) first, then create (p_site_code text)
-- PG won't allow CREATE OR REPLACE with same type signature but different param name
DROP FUNCTION IF EXISTS public.get_maintenance_schedule(text);

CREATE OR REPLACE FUNCTION public.get_maintenance_schedule(p_site_code text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions
AS $function$
BEGIN
  RETURN (SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(sub), '[]'::jsonb))
  FROM (
    SELECT jsonb_build_object(
      'id', m.id, 'equipment_code', m.equipment_code, 'equipment_name', m.equipment_name,
      'maintenance_type', m.maintenance_type, 'description', m.description,
      'scheduled_date', m.scheduled_date, 'completed_date', m.completed_date,
      'status', m.status, 'assigned_to', m.assigned_to, 'priority', m.priority,
      'cost', m.cost, 'parts_used', m.parts_used, 'downtime_hours', m.downtime_hours,
      'site_code', m.site_code
    ) AS sub
    FROM mill_maintenance m
    WHERE p_site_code IS NULL OR m.site_code = p_site_code
    ORDER BY m.scheduled_date DESC
  ) sub);
END;
$function$;

-- get_breakdown_log(p_site_code): fix to use mill_breakdowns actual columns
CREATE OR REPLACE FUNCTION public.get_breakdown_log(p_site_code text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions
AS $function$
BEGIN
  RETURN (SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(sub), '[]'::jsonb))
  FROM (
    SELECT jsonb_build_object(
      'id', br.id, 'equipment_code', br.equipment_code, 'equipment_name', br.equipment_name,
      'breakdown_time', br.breakdown_time, 'resolved_time', br.resolved_time,
      'severity', br.severity, 'category', br.category,
      'description', br.description, 'root_cause', br.root_cause,
      'action_taken', br.action_taken, 'reported_by', br.reported_by,
      'assigned_to', br.assigned_to, 'status', br.status,
      'downtime_hours', br.downtime_hours, 'cost', br.cost, 'site_code', br.site_code
    ) AS sub
    FROM mill_breakdowns br
    WHERE p_site_code IS NULL OR br.site_code = p_site_code
    ORDER BY br.breakdown_time DESC
  ) sub);
END;
$function$;

-- get_mill_production(p_site_code): fix to use mill_shift actual columns
CREATE OR REPLACE FUNCTION public.get_mill_production(p_site_code text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions
AS $function$
BEGIN
  RETURN (SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(sub), '[]'::jsonb))
  FROM (
    SELECT jsonb_build_object(
      'id', ms.id, 'date', ms.date, 'shift_name', ms.shift_name,
      'start_time', ms.start_time, 'end_time', ms.end_time,
      'headcount', ms.headcount, 'supervisor_nama', ms.supervisor_nama,
      'status', ms.status
    ) AS sub
    FROM mill_shift ms
    ORDER BY ms.date DESC
  ) sub);
END;
$function$;


-- ════════════════════════════════════════════════════════════════
-- GRANT EXECUTE on all overloads
-- ════════════════════════════════════════════════════════════════

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN (
        'get_estate_blocks','get_harvest_records','get_transport_dispatch',
        'get_nursery_data','get_irrigation_status','get_field_status','get_yield_data',
        'get_boiler_status','get_press_status','get_qc_results','get_packing_log',
        'get_maintenance_schedule','get_breakdown_log','get_mill_production'
      )
  LOOP
    BEGIN
      EXECUTE format('GRANT EXECUTE ON FUNCTION %I(%s) TO authenticated', r.proname, r.args);
    EXCEPTION WHEN OTHERS THEN
      RAISE LOG '181: skip GRANT %(%): %', r.proname, r.args, SQLERRM;
    END;
  END LOOP;
END $$;


-- ════════════════════════════════════════════════════════════════
-- VERIFY (use explicit param to avoid ambiguous overloads)
-- ════════════════════════════════════════════════════════════════

SELECT 'Estate: get_estate_blocks' AS test, CASE WHEN get_estate_blocks(NULL) IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Estate: get_harvest_records' AS test, CASE WHEN get_harvest_records(NULL) IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Estate: get_transport_dispatch' AS test, CASE WHEN get_transport_dispatch(NULL) IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Estate: get_nursery_data' AS test, CASE WHEN get_nursery_data(NULL) IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Estate: get_irrigation_status' AS test, CASE WHEN get_irrigation_status(NULL) IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Estate: get_field_status' AS test, CASE WHEN get_field_status(NULL) IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Estate: get_yield_data' AS test, CASE WHEN get_yield_data(NULL) IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Mill: get_boiler_status' AS test, CASE WHEN get_boiler_status(NULL) IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Mill: get_press_status' AS test, CASE WHEN get_press_status(NULL) IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Mill: get_qc_results' AS test, CASE WHEN get_qc_results(NULL) IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Mill: get_packing_log' AS test, CASE WHEN get_packing_log(NULL) IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Mill: get_maintenance_schedule' AS test, CASE WHEN get_maintenance_schedule(NULL) IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Mill: get_breakdown_log' AS test, CASE WHEN get_breakdown_log(NULL) IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Mill: get_mill_production' AS test, CASE WHEN get_mill_production(NULL) IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
