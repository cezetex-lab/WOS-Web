-- ================================================================
-- 180_estate_mill_functions.sql — Phase 7: Industry modules
-- Creates 7 Estate + 7 Mill functions
-- All SECURITY DEFINER, search_path = public, extensions
-- ================================================================

-- ════════════════════════════════════════════════════════════════
-- ESTATE FUNCTIONS (7)
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.get_estate_blocks(p_bu_id text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions
AS $function$
BEGIN
  RETURN (SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(sub), '[]'::jsonb))
  FROM (
    SELECT jsonb_build_object(
      'id', e.id, 'block_name', e.block_name, 'area_hectare', e.area_hectare,
      'terrain', e.terrain, 'division', e.division, 'status', e.status,
      'business_unit_id', e.business_unit_id
    ) AS sub
    FROM estate_blocks e
    WHERE p_bu_id IS NULL OR e.business_unit_id = p_bu_id
    ORDER BY e.block_name
  ) sub);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_harvest_records(p_bu_id text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions
AS $function$
BEGIN
  RETURN (SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(sub), '[]'::jsonb))
  FROM (
    SELECT jsonb_build_object(
      'id', h.id, 'date', h.date, 'block_name', h.block_name,
      'tonnage', h.tonnage, 'harvester_nrp', h.harvester_nrp,
      'harvester_nama', h.harvester_nama, 'quality', h.quality, 'status', h.status
    ) AS sub
    FROM estate_harvest h
    WHERE p_bu_id IS NULL OR h.business_unit_id = p_bu_id
    ORDER BY h.date DESC
  ) sub);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_transport_dispatch(p_bu_id text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions
AS $function$
BEGIN
  RETURN (SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(sub), '[]'::jsonb))
  FROM (
    SELECT jsonb_build_object(
      'id', t.id, 'date', t.date, 'origin_block', t.origin_block,
      'destination', t.destination, 'tonnage', t.tonnage,
      'vehicle_id', t.vehicle_id, 'driver_nrp', t.driver_nrp, 'status', t.status
    ) AS sub
    FROM estate_transport t
    WHERE p_bu_id IS NULL OR t.business_unit_id = p_bu_id
    ORDER BY t.date DESC
  ) sub);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_nursery_data(p_bu_id text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions
AS $function$
BEGIN
  RETURN (SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(sub), '[]'::jsonb))
  FROM (
    SELECT jsonb_build_object(
      'id', n.id, 'date', n.date, 'block_name', n.block_name,
      'seedling_count', n.seedling_count, 'survival_rate', n.survival_rate,
      'nursery_type', n.nursery_type, 'status', n.status
    ) AS sub
    FROM estate_nursery n
    WHERE p_bu_id IS NULL OR n.business_unit_id = p_bu_id
    ORDER BY n.date DESC
  ) sub);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_irrigation_status(p_bu_id text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions
AS $function$
BEGIN
  RETURN (SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(sub), '[]'::jsonb))
  FROM (
    SELECT jsonb_build_object(
      'id', i.id, 'date', i.date, 'block_name', i.block_name,
      'water_flow', i.water_flow, 'duration_hours', i.duration_hours,
      'method', i.method, 'status', i.status
    ) AS sub
    FROM estate_irrigation i
    WHERE p_bu_id IS NULL OR i.business_unit_id = p_bu_id
    ORDER BY i.date DESC
  ) sub);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_field_status(p_bu_id text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions
AS $function$
BEGIN
  RETURN (SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(sub), '[]'::jsonb))
  FROM (
    SELECT jsonb_build_object(
      'id', f.id, 'date', f.date, 'block_name', f.block_name,
      'activity_type', f.activity_type, 'worker_count', f.worker_count,
      'description', f.description, 'supervisor_nama', f.supervisor_nama
    ) AS sub
    FROM estate_field f
    WHERE p_bu_id IS NULL OR f.business_unit_id = p_bu_id
    ORDER BY f.date DESC
  ) sub);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_yield_data(p_bu_id text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions
AS $function$
BEGIN
  RETURN (SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(sub), '[]'::jsonb))
  FROM (
    SELECT jsonb_build_object(
      'id', y.id, 'date', y.date, 'block_name', y.block_name,
      'yield_tonnage', y.yield_tonnage, 'quality_grade', y.quality_grade,
      'harvest_method', y.harvest_method, 'status', y.status
    ) AS sub
    FROM estate_yield y
    WHERE p_bu_id IS NULL OR y.business_unit_id = p_bu_id
    ORDER BY y.date DESC
  ) sub);
END;
$function$;


-- ════════════════════════════════════════════════════════════════
-- MILL FUNCTIONS (7)
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.get_boiler_status(p_site_code text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions
AS $function$
BEGIN
  RETURN (SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(sub), '[]'::jsonb))
  FROM (
    SELECT jsonb_build_object(
      'id', b.id, 'site_code', b.site_code, 'date', b.date,
      'temperature', b.temperature, 'pressure', b.pressure,
      'steam_output', b.steam_output, 'fuel_consumption', b.fuel_consumption,
      'efficiency', b.efficiency, 'status', b.status
    ) AS sub
    FROM mill_boiler b
    WHERE p_site_code IS NULL OR b.site_code = p_site_code
    ORDER BY b.date DESC
  ) sub);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_press_status(p_site_code text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions
AS $function$
BEGIN
  RETURN (SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(sub), '[]'::jsonb))
  FROM (
    SELECT jsonb_build_object(
      'id', p.id, 'site_code', p.site_code, 'date', p.date,
      'press_type', p.press_type, 'throughput_tph', p.throughput_tph,
      'oil_rendement', p.oil_rendement, 'fiber_pct', p.fiber_pct,
      'status', p.status
    ) AS sub
    FROM mill_press p
    WHERE p_site_code IS NULL OR p.site_code = p_site_code
    ORDER BY p.date DESC
  ) sub);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_qc_results(p_site_code text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions
AS $function$
BEGIN
  RETURN (SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(sub), '[]'::jsonb))
  FROM (
    SELECT jsonb_build_object(
      'id', q.id, 'site_code', q.site_code, 'date', q.date,
      'sample_id', q.sample_id, 'moisture', q.moisture,
      'free_fatty_acid', q.free_fatty_acid, 'dirt_content', q.dirt_content,
      'result', q.result, 'status', q.status
    ) AS sub
    FROM mill_qc_results q
    WHERE p_site_code IS NULL OR q.site_code = p_site_code
    ORDER BY q.date DESC
  ) sub);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_packing_log(p_site_code text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions
AS $function$
BEGIN
  RETURN (SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(sub), '[]'::jsonb))
  FROM (
    SELECT jsonb_build_object(
      'id', pk.id, 'site_code', pk.site_code, 'date', pk.date,
      'shift', pk.shift, 'bags_count', pk.bags_count,
      'weight_kg', pk.weight_kg, 'grade', pk.grade, 'status', pk.status
    ) AS sub
    FROM mill_packing pk
    WHERE p_site_code IS NULL OR pk.site_code = p_site_code
    ORDER BY pk.date DESC
  ) sub);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_maintenance_schedule(p_site_code text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions
AS $function$
BEGIN
  RETURN (SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(sub), '[]'::jsonb))
  FROM (
    SELECT jsonb_build_object(
      'id', m.id, 'site_code', m.site_code, 'equipment', m.equipment,
      'scheduled_date', m.scheduled_date, 'type', m.type,
      'assigned_to', m.assigned_to, 'status', m.status
    ) AS sub
    FROM mill_maintenance m
    WHERE p_site_code IS NULL OR m.site_code = p_site_code
    ORDER BY m.scheduled_date DESC
  ) sub);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_breakdown_log(p_site_code text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions
AS $function$
BEGIN
  RETURN (SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(sub), '[]'::jsonb))
  FROM (
    SELECT jsonb_build_object(
      'id', br.id, 'site_code', br.site_code, 'date', br.date,
      'equipment', br.equipment, 'description', br.description,
      'duration_hours', br.duration_hours, 'cause', br.cause, 'status', br.status
    ) AS sub
    FROM mill_breakdown br
    WHERE p_site_code IS NULL OR br.site_code = p_site_code
    ORDER BY br.date DESC
  ) sub);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_mill_production(p_site_code text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions
AS $function$
BEGIN
  RETURN (SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(sub), '[]'::jsonb))
  FROM (
    SELECT jsonb_build_object(
      'id', mp.id, 'site_code', mp.site_code, 'date', mp.date,
      'shift', mp.shift, 'crpn_tonnage', mp.crpn_tonnage,
      'cPO_tonnage', mp.cPO_tonnage, 'PKO_tonnage', mp.PKO_tonnage,
      'status', mp.status
    ) AS sub
    FROM mill_shift mp
    WHERE p_site_code IS NULL OR mp.site_code = p_site_code
    ORDER BY mp.date DESC
  ) sub);
END;
$function$;


-- ════════════════════════════════════════════════════════════════
-- GRANT EXECUTE
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
      RAISE LOG '180: skip GRANT %: %', r.proname, SQLERRM;
    END;
  END LOOP;
END $$;


-- ════════════════════════════════════════════════════════════════
-- VERIFY
-- ════════════════════════════════════════════════════════════════

SELECT 'Estate: get_estate_blocks' AS test, CASE WHEN get_estate_blocks() IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Estate: get_harvest_records' AS test, CASE WHEN get_harvest_records() IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Estate: get_transport_dispatch' AS test, CASE WHEN get_transport_dispatch() IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Estate: get_nursery_data' AS test, CASE WHEN get_nursery_data() IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Estate: get_irrigation_status' AS test, CASE WHEN get_irrigation_status() IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Estate: get_field_status' AS test, CASE WHEN get_field_status() IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Estate: get_yield_data' AS test, CASE WHEN get_yield_data() IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Mill: get_boiler_status' AS test, CASE WHEN get_boiler_status() IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Mill: get_press_status' AS test, CASE WHEN get_press_status() IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Mill: get_qc_results' AS test, CASE WHEN get_qc_results() IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Mill: get_packing_log' AS test, CASE WHEN get_packing_log() IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Mill: get_maintenance_schedule' AS test, CASE WHEN get_maintenance_schedule() IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Mill: get_breakdown_log' AS test, CASE WHEN get_breakdown_log() IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'Mill: get_mill_production' AS test, CASE WHEN get_mill_production() IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
