-- ================================================================
-- rollback/208_rollback.sql — Rollback migration 208
-- Drop 6 tables + restore 6 fake-data RPCs (pre-208 bodies).
-- WARNING: This re-introduces fake/fallback data.
-- ================================================================

-- 1. Restore RPCs to fake-data versions (pre-208)
CREATE OR REPLACE FUNCTION public.get_safety_incidents(p_nrp text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'id', 'SAF-' || LPAD(rn::text, 3, '0'),
      'date', CURRENT_DATE - (rn * 3),
      'zone', (ARRAY['PIT-1','PIT-2','CRUSHER','WORKSHOP','HAUL ROAD'])[1 + rn % 5],
      'type', (ARRAY['NEAR_MISS','INCIDENT','OBSERVATION'])[1 + rn % 3],
      'severity', (ARRAY['LOW','MEDIUM','HIGH','CRITICAL'])[1 + rn % 4],
      'description', 'Safety incident ' || rn,
      'reporter', 'NRP001',
      'status', (ARRAY['OPEN','INVESTIGATING','CLOSED'])[1 + rn % 3],
      'action_taken', NULL
    ))
    FROM generate_series(1, 10) rn
  ), '[]'::jsonb);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_jsa_list(p_nrp text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'id', 'JSA-' || LPAD(rn::text, 3, '0'),
      'job', (ARRAY['Blasting','Hauling','Excavation','Crusher Maintenance','Night Patrol','Fuel Delivery'])[1 + rn % 6],
      'area', (ARRAY['PIT-1','PIT-2','CRUSHER','HAUL ROAD'])[1 + rn % 4],
      'risk_level', (ARRAY['LOW','MEDIUM','HIGH','CRITICAL'])[1 + rn % 4],
      'hazards', ARRAY['Hazard 1','Hazard 2'],
      'controls', ARRAY['Control 1','Control 2'],
      'status', 'ACTIVE',
      'prepared_by', 'NRP001',
      'valid_date', CURRENT_DATE + (rn * 10)
    ))
    FROM generate_series(1, 6) rn
  ), '[]'::jsonb);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_production_daily(p_nrp text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'zone', (ARRAY['PIT-1','PIT-2','PIT-3','CRUSHER','HAUL ROAD'])[1 + rn % 5],
      'product', 'Coal',
      'target', 5000,
      'actual', 5000,
      'unit', 'ton',
      'operator_count', 10
    ))
    FROM generate_series(1, 5) rn
  ), '[]'::jsonb);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_heavy_equipment(p_nrp text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'id', 'EQ-' || LPAD(rn::text, 3, '0'),
      'type', 'Excavator',
      'brand', 'CAT 320',
      'status', (ARRAY['OPERATIONAL','MAINTENANCE','IDLE'])[1 + rn % 3],
      'operator', 'NRP001',
      'zone', 'PIT-1',
      'hours', 10000,
      'fuel_level', 80,
      'next_service', CURRENT_DATE::text
    ))
    FROM generate_series(1, 5) rn
  ), '[]'::jsonb);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_fatigue_data(p_nrp text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'nrp', 'NRP' || LPAD(rn::text, 3, '0'),
      'name', 'Worker ' || rn,
      'shift', (ARRAY['Pagi','Sore','Malam'])[1 + rn % 3],
      'hours_worked', 10,
      'hours_rest', 8,
      'fatigue_level', (ARRAY['LOW','MEDIUM','HIGH'])[1 + rn % 3],
      'status', (ARRAY['FIT','CAUTION'])[1 + rn % 2],
      'last_check', '06:00'
    ))
    FROM generate_series(1, 5) rn
  ), '[]'::jsonb);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_simper_list(p_nrp text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'id', 'SIM-' || LPAD(rn::text, 3, '0'),
      'nrp', COALESCE(p_nrp, 'NRP001'),
      'zone', (ARRAY['PIT-1','CRUSHER','WORKSHOP'])[1 + rn % 3],
      'purpose', 'Operasi',
      'status', 'ACTIVE',
      'valid_until', CURRENT_DATE + (rn * 30),
      'issued_by', 'Safety Manager'
    ))
    FROM generate_series(1, 3) rn
  ), '[]'::jsonb);
END;
$function$;

-- 2. Drop tables (CASCADE to drop dependent objects)
DROP TABLE IF EXISTS safety_incidents CASCADE;
DROP TABLE IF EXISTS jsa_data CASCADE;
DROP TABLE IF EXISTS production_daily CASCADE;
DROP TABLE IF EXISTS heavy_equipment CASCADE;
DROP TABLE IF EXISTS fatigue_data CASCADE;
DROP TABLE IF EXISTS simper_data CASCADE;

-- 3. Verify
SELECT 'rb208.1 tables dropped' AS test,
  CASE WHEN (
    SELECT count(*) FROM information_schema.tables
    WHERE table_schema='public' AND table_name IN (
      'safety_incidents','jsa_data','production_daily',
      'heavy_equipment','fatigue_data','simper_data'
    )
  ) = 0 THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'rb208.2 fake data restored' AS test,
  CASE WHEN position('ARRAY[' in pg_get_functiondef(p.oid)) > 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM pg_proc p WHERE p.proname='get_safety_incidents'
  AND pg_get_function_identity_arguments(p.oid) LIKE '%p_nrp%';
