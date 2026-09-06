-- ===============================================================
-- FASE 6: WORKFORCE SIMULATION & PLANNING
-- Migration 163
-- ===============================================================

-- 6.1 Workforce Simulation
CREATE OR REPLACE FUNCTION run_workforce_simulation(p_years INT DEFAULT 3, p_pct NUMERIC DEFAULT 10, p_division TEXT DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
  v_total INT; v_affected INT; v_pkwt INT; v_critical INT;
BEGIN
  SELECT COUNT(*) INTO v_total FROM employees_master WHERE is_active = true;
  SELECT COUNT(*) INTO v_pkwt FROM employees_master WHERE is_active = true AND employment_type = 'PKWT';
  v_affected := ROUND(v_total * p_pct / 100 * p_years / 10);
  v_critical := GREATEST(0, v_affected - v_pkwt);
  INSERT INTO audit_log (action,detail,timestamp) VALUES (
    'SIMULATION', jsonb_build_object(
    'years', p_years, 'pct', p_pct,
    'headcount', v_total, 'affected', v_affected,
    'pkwt', v_pkwt, 'critical', v_critical
  )::text, NOW());
  RETURN jsonb_build_object(
    'ok', true,
    'headcount', v_total,
    'affected', v_affected,
    'pkwt', v_pkwt,
    'critical_positions', v_critical,
    'operational_risk', CASE WHEN v_critical > 5 THEN 'HIGH' WHEN v_critical > 2 THEN 'MEDIUM' ELSE 'LOW' END
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 6.2 Workforce Planning
CREATE OR REPLACE FUNCTION get_workforce_planning()
RETURNS JSONB AS $$
BEGIN
  RETURN jsonb_build_object(
    'ok', true,
    'total_active', (SELECT COUNT(*) FROM employees_master WHERE is_active=true),
    'pkwt_count', (SELECT COUNT(*) FROM employees_master WHERE is_active=true AND employment_type='PKWT'),
    'avg_kpi', (SELECT COALESCE(AVG(kpi_score),0) FROM hr_performance WHERE period=to_char(NOW(), 'YYYY-MM')),
    'division_breakdown', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'division', division, 'count', cnt)), '[]'::jsonb)
      FROM (SELECT division, COUNT(*) AS cnt FROM employees_master WHERE is_active=true GROUP BY division ORDER BY cnt DESC) sub
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION run_workforce_simulation(INT, NUMERIC, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_workforce_planning() TO authenticated;

DO $$ BEGIN
  RAISE NOTICE '=== Fase 6: Workforce Simulation -- 2 functions, 2 GRANTs ===';
END $$;
