-- ===============================================================
-- FASE 4: NARRATIVE INTELLIGENCE
-- Migration 161
-- ===============================================================

-- 4.1 Mesin Narasi
CREATE OR REPLACE FUNCTION generate_narrative(p_tab TEXT, p_nrp TEXT DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
  v_nrp TEXT; v_nama TEXT; v_kpi NUMERIC; v_absence NUMERIC; v_result JSONB;
BEGIN
  IF p_nrp IS NULL THEN
    SELECT nrp INTO v_nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1;
  ELSE v_nrp := p_nrp; END IF;
  SELECT nama INTO v_nama FROM employees_master WHERE nrp = v_nrp;
  SELECT kpi_score INTO v_kpi FROM hr_performance WHERE nrp = v_nrp ORDER BY period DESC LIMIT 1;
  SELECT COALESCE(ROUND(SUM(CASE WHEN status != 'Hadir' THEN 1 ELSE 0 END)::NUMERIC/NULLIF(COUNT(*),0)*100,1),0)
  INTO v_absence FROM hr_attendance WHERE nrp = v_nrp AND date >= (NOW()-INTERVAL '30 days')::date;
  v_result := jsonb_build_object(
    'nrp', v_nrp,
    'nama', COALESCE(v_nama, 'Unknown'),
    'tab', p_tab,
    'sapaan', 'Halo ' || COALESCE(v_nama, 'Karyawan') || ',',
    'analisis', CASE
      WHEN p_tab = 'kpi' THEN 'Skor KPI Anda ' || COALESCE(v_kpi::TEXT, '-')
      WHEN p_tab = 'attendance' THEN 'Ketidakhadiran 30 hari: ' || v_absence || '%'
      ELSE 'Data sedang dianalisis.' END,
    'action_plan', CASE
      WHEN p_tab = 'kpi' AND v_kpi < 60 THEN ('["Fokus kehadiran","Selesaikan training"]')::jsonb
      ELSE '[]'::jsonb END,
    'outcome', 'Perbaikan bertahap meningkatkan skor 5-10 poin dalam 1 bulan.'
  );
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION generate_narrative(TEXT, TEXT) TO authenticated;

DO $$ BEGIN
  RAISE NOTICE '=== Fase 4: Narrative Intelligence -- 1 function, 1 GRANT ===';
END $$;
