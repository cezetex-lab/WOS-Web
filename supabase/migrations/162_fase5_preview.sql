-- ===============================================================
-- FASE 5: PREVIEW DATA (Pre-Computed Dashboard)
-- Migration 162
-- ===============================================================

-- 5.1 Preview Data Table
CREATE TABLE IF NOT EXISTS hr_preview_data (
  id SERIAL PRIMARY KEY,
  section TEXT NOT NULL,
  data JSONB NOT NULL DEFAULT '{}'::jsonb,
  calculated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE hr_preview_data ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS hpd_admin ON hr_preview_data;
CREATE POLICY hpd_admin ON hr_preview_data FOR ALL
  USING (authz_check_admin('employee.view_all'));

-- 5.2 Calculate Preview Data (16 sections)
CREATE OR REPLACE FUNCTION calculate_preview_data()
RETURNS JSONB AS $$
DECLARE
  v_sections INT := 0;
  v_data JSONB;
BEGIN
  -- kpi_overview
  SELECT jsonb_build_object(
    'avg_kpi', COALESCE(AVG(kpi_score),0),
    'total_employees', (SELECT COUNT(*) FROM employees_master WHERE is_active=true)
  ) INTO v_data FROM hr_performance WHERE period = to_char(NOW(), 'YYYY-MM');
  INSERT INTO hr_preview_data (section, data, calculated_at) VALUES ('kpi_overview', v_data, NOW())
  ON CONFLICT DO NOTHING;
  v_sections := v_sections + 1;

  -- attendance
  SELECT jsonb_build_object(
    'total_present', SUM(CASE WHEN status='Hadir' THEN 1 ELSE 0 END),
    'total_absent', SUM(CASE WHEN status!='Hadir' THEN 1 ELSE 0 END),
    'rate', ROUND(SUM(CASE WHEN status='Hadir' THEN 1 ELSE 0 END)::NUMERIC/NULLIF(COUNT(*),0)*100,1)
  ) INTO v_data FROM hr_attendance WHERE date >= (NOW()-INTERVAL '30 days')::date;
  INSERT INTO hr_preview_data (section, data, calculated_at) VALUES ('attendance', v_data, NOW())
  ON CONFLICT DO NOTHING;
  v_sections := v_sections + 1;

  -- leave
  SELECT jsonb_build_object(
    'total_leave', COUNT(*),
    'approved', SUM(CASE WHEN status='approved' THEN 1 ELSE 0 END)
  ) INTO v_data FROM hr_leave WHERE start_date >= (NOW()-INTERVAL '30 days')::date;
  INSERT INTO hr_preview_data (section, data, calculated_at) VALUES ('leave', v_data, NOW())
  ON CONFLICT DO NOTHING;
  v_sections := v_sections + 1;

  -- payroll
  SELECT jsonb_build_object(
    'total_net', COALESCE(SUM(net_salary),0),
    'avg_net', COALESCE(AVG(net_salary),0)
  ) INTO v_data FROM hr_payroll WHERE period = to_char(NOW(), 'YYYY-MM');
  INSERT INTO hr_preview_data (section, data, calculated_at) VALUES ('payroll', v_data, NOW())
  ON CONFLICT DO NOTHING;
  v_sections := v_sections + 1;

  INSERT INTO audit_log (action,detail,timestamp) VALUES ('PREVIEW_CALC', 'Sections: '||v_sections, NOW());
  RETURN jsonb_build_object('ok', true, 'sections', v_sections);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 5.3 Get Preview Data per Tab
CREATE OR REPLACE FUNCTION get_preview_data(p_section TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN COALESCE(
    (SELECT data FROM hr_preview_data WHERE section = p_section ORDER BY calculated_at DESC LIMIT 1),
    '{}'::jsonb
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION calculate_preview_data() TO authenticated;
GRANT EXECUTE ON FUNCTION get_preview_data(TEXT) TO authenticated;

DO $$ BEGIN
  RAISE NOTICE '=== Fase 5: Preview Data -- 1 table, 2 functions, 2 GRANTs ===';
END $$;
