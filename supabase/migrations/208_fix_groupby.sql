-- ================================================================
-- 208_fix_groupby.sql — Fix GROUP BY errors in 6 industry RPCs
-- Pattern: jsonb_agg(sub) FROM (SELECT jsonb_build_object(...) as sub ...) t
-- ================================================================

-- get_safety_incidents
CREATE OR REPLACE FUNCTION public.get_safety_incidents(p_nrp text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN jsonb_build_object('ok', true, 'data', COALESCE((
    SELECT jsonb_agg(sub)
    FROM (
      SELECT jsonb_build_object(
        'id', si.id, 'date', si.incident_date, 'zone', si.zone,
        'type', si.incident_type, 'severity', si.severity,
        'description', si.description, 'reporter', si.reporter_nrp,
        'status', si.status, 'action_taken', si.action_taken
      ) as sub
      FROM safety_incidents si
      WHERE (p_nrp IS NULL OR si.reporter_nrp = p_nrp)
      ORDER BY si.incident_date DESC
    ) t
  ), '[]'::jsonb));
END;
$function$;

-- get_jsa_list
CREATE OR REPLACE FUNCTION public.get_jsa_list(p_nrp text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN jsonb_build_object('ok', true, 'data', COALESCE((
    SELECT jsonb_agg(sub)
    FROM (
      SELECT jsonb_build_object(
        'id', j.id, 'job', j.job, 'area', j.area,
        'risk_level', j.risk_level, 'hazards', j.hazards,
        'controls', j.controls, 'status', j.status,
        'prepared_by', j.prepared_by, 'valid_date', j.valid_until
      ) as sub
      FROM jsa_data j
      WHERE (p_nrp IS NULL OR j.prepared_by = p_nrp)
      ORDER BY j.created_at DESC
    ) t
  ), '[]'::jsonb));
END;
$function$;

-- get_production_daily
CREATE OR REPLACE FUNCTION public.get_production_daily(p_nrp text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN jsonb_build_object('ok', true, 'data', COALESCE((
    SELECT jsonb_agg(sub)
    FROM (
      SELECT jsonb_build_object(
        'zone', pd.zone, 'product', pd.product,
        'target', pd.target_qty, 'actual', pd.actual_qty,
        'unit', pd.unit, 'operator_count', pd.operator_count
      ) as sub
      FROM production_daily pd
      WHERE pd.record_date = CURRENT_DATE
      ORDER BY pd.zone
    ) t
  ), '[]'::jsonb));
END;
$function$;

-- get_heavy_equipment
CREATE OR REPLACE FUNCTION public.get_heavy_equipment(p_nrp text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN jsonb_build_object('ok', true, 'data', COALESCE((
    SELECT jsonb_agg(sub)
    FROM (
      SELECT jsonb_build_object(
        'id', he.id, 'type', he.equipment_type, 'brand', he.brand,
        'status', he.status, 'operator', he.operator_nrp,
        'zone', he.zone, 'hours', he.hours_run,
        'fuel_level', he.fuel_level, 'next_service', he.next_service
      ) as sub
      FROM heavy_equipment he
      WHERE (p_nrp IS NULL OR he.operator_nrp = p_nrp)
      ORDER BY he.zone
    ) t
  ), '[]'::jsonb));
END;
$function$;

-- get_fatigue_data
CREATE OR REPLACE FUNCTION public.get_fatigue_data(p_nrp text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN jsonb_build_object('ok', true, 'data', COALESCE((
    SELECT jsonb_agg(sub)
    FROM (
      SELECT jsonb_build_object(
        'nrp', fd.nrp, 'name', fd.nama, 'shift', fd.shift,
        'hours_worked', fd.hours_worked, 'hours_rest', fd.hours_rest,
        'fatigue_level', fd.fatigue_level, 'status', fd.status,
        'last_check', fd.last_check
      ) as sub
      FROM fatigue_data fd
      WHERE (p_nrp IS NULL OR fd.nrp = p_nrp)
      ORDER BY fd.fatigue_level DESC, fd.nama
    ) t
  ), '[]'::jsonb));
END;
$function$;

-- get_simper_list
CREATE OR REPLACE FUNCTION public.get_simper_list(p_nrp text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN jsonb_build_object('ok', true, 'data', COALESCE((
    SELECT jsonb_agg(sub)
    FROM (
      SELECT jsonb_build_object(
        'id', sd.id, 'nrp', sd.nrp, 'zone', sd.zone,
        'purpose', sd.purpose, 'status', sd.status,
        'valid_until', sd.valid_until, 'issued_by', sd.issued_by
      ) as sub
      FROM simper_data sd
      WHERE (p_nrp IS NULL OR sd.nrp = p_nrp)
      ORDER BY sd.valid_until DESC
    ) t
  ), '[]'::jsonb));
END;
$function$;

-- Verify: all 6 RPCs return {ok: true, data: []} for empty tables
SELECT '208_fix.1 get_safety_incidents' AS test, (get_safety_incidents()) AS result;
SELECT '208_fix.2 get_jsa_list' AS test, (get_jsa_list()) AS result;
SELECT '208_fix.3 get_production_daily' AS test, (get_production_daily()) AS result;
SELECT '208_fix.4 get_heavy_equipment' AS test, (get_heavy_equipment()) AS result;
SELECT '208_fix.5 get_fatigue_data' AS test, (get_fatigue_data()) AS result;
SELECT '208_fix.6 get_simper_list' AS test, (get_simper_list()) AS result;
