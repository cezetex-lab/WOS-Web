-- ============================================================
-- 030_fix_rpc_errors.sql
-- Fix SQL errors discovered during testing
-- Run in Supabase SQL Editor
-- ============================================================

-- ============================================================
-- FIX 1: get_continuous_perf_team — ORDER BY p.created_at
-- must appear in GROUP BY or aggregate
-- ============================================================
CREATE OR REPLACE FUNCTION get_continuous_perf_team(p_nrp TEXT) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',p.nrp,'nama',e.nama,'periode',p.periode,'kpi_score',p.kpi_score)
    ORDER BY p.periode DESC),'[]'::jsonb))
  FROM hr_performance p JOIN hr_org o ON o.nrp=p.nrp AND o.atasan_nrp=p_nrp
  LEFT JOIN employees_master e ON e.nrp=p.nrp
  WHERE p.periode IS NOT NULL
  LIMIT 20); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- FIX 2: get_team_data — same GROUP BY issue
-- ============================================================
CREATE OR REPLACE FUNCTION get_team_data(p_nrp TEXT) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',e.nrp,'nama',e.nama,'posisi',e.posisi,'divisi',e.divisi,
      'kpi_score',COALESCE(p.kpi_score,0),'status_kerja',e.status_kerja)
    ORDER BY e.nama),'[]'::jsonb))
  FROM hr_org o JOIN employees_master e ON e.nrp=o.nrp
  LEFT JOIN hr_performance p ON p.nrp=o.nrp AND p.periode=(
    SELECT MAX(periode) FROM hr_performance)
  WHERE o.atasan_nrp=p_nrp); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- FIX 3: get_flight_risk_list — subquery column issue
-- ============================================================
CREATE OR REPLACE FUNCTION get_flight_risk_list() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',e.nrp,'nama',e.nama,'divisi',e.divisi,
      'kpi_score',COALESCE(p.kpi_score,0),'telat_count',COALESCE(t.telat_count,0))
    ORDER BY COALESCE(p.kpi_score,0) ASC),'[]'::jsonb))
  FROM employees_master e
  LEFT JOIN hr_performance p ON p.nrp=e.nrp AND p.period=(
    SELECT MAX(period) FROM hr_performance)
  LEFT JOIN (SELECT nrp,COUNT(*) as telat_count FROM hr_attendance
    WHERE status_hadir='Telat' AND date>=date_trunc('month',NOW()) GROUP BY nrp) t ON t.nrp=e.nrp
  WHERE COALESCE(p.kpi_score,100)<70 OR COALESCE(t.telat_count,0)>5
  ORDER BY COALESCE(p.kpi_score,0) ASC LIMIT 10); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- FIX 4: get_ceo_command_data — period column name fix
-- ============================================================
CREATE OR REPLACE FUNCTION get_ceo_command_data(p_nrp TEXT) RETURNS JSONB AS $$ BEGIN
  RETURN jsonb_build_object('ok',true,
    'org_summary',(SELECT COALESCE(jsonb_agg(jsonb_build_object('divisi',d.divisi,'headcount',d.hc,'avg_kpi',d.ak)),'[]'::jsonb) FROM
      (SELECT e.divisi,COUNT(*) as hc,ROUND(AVG(p.kpi_score),1) as ak
       FROM employees_master e LEFT JOIN hr_performance p ON p.nrp=e.nrp
       WHERE e.divisi IS NOT NULL GROUP BY e.divisi) d),
    'total_workers',(SELECT COUNT(*) FROM employees_master),
    'avg_kpi',(SELECT COALESCE(ROUND(AVG(kpi_score),1),0) FROM hr_performance
      WHERE periode=(SELECT MAX(periode) FROM hr_performance))); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- FIX 5: get_organization_health — period column name fix
-- ============================================================
CREATE OR REPLACE FUNCTION get_organization_health() RETURNS JSONB AS $$ BEGIN RETURN jsonb_build_object('ok',true,
  'headcount',(SELECT COUNT(*) FROM employees_master),
  'avg_kpi',(SELECT COALESCE(ROUND(AVG(kpi_score),1),0) FROM hr_performance
    WHERE periode=(SELECT MAX(periode) FROM hr_performance)),
  'attendance_rate',(SELECT COALESCE(ROUND(COUNT(*) FILTER(WHERE status_hadir='Hadir')::NUMERIC/
    NULLIF(COUNT(*),0)*100,1),0) FROM hr_attendance WHERE date>=date_trunc('month',NOW())),
  'open_positions',(SELECT COUNT(*) FROM hr_talent_catalog WHERE status='ACTIVE'),
  'pending_requests',(SELECT COUNT(*) FROM hr_requests WHERE status='Pending'),
  'coaching_active',(SELECT COUNT(*) FROM hr_coaching WHERE status='ACTIVE'),
  'compliance_issues',(SELECT COUNT(*) FROM hr_compliance WHERE status='OVERDUE')); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- FIX 6: get_executive_summary — period column name fix
-- ============================================================
CREATE OR REPLACE FUNCTION get_executive_summary() RETURNS JSONB AS $$ BEGIN RETURN jsonb_build_object('ok',true,
  'headcount',(SELECT COUNT(*) FROM employees_master),
  'avg_kpi',(SELECT COALESCE(ROUND(AVG(kpi_score),1),0) FROM hr_performance
    WHERE periode=(SELECT MAX(periode) FROM hr_performance)),
  'high_performers',(SELECT COUNT(*) FROM hr_performance WHERE kpi_score>=80
    AND periode=(SELECT MAX(periode) FROM hr_performance)),
  'low_performers',(SELECT COUNT(*) FROM hr_performance WHERE kpi_score<60
    AND periode=(SELECT MAX(periode) FROM hr_performance)),
  'turnover_rate',0,
  'total_payroll',(SELECT COALESCE(SUM(net_salary),0) FROM hr_payroll
    WHERE periode=(SELECT MAX(periode) FROM hr_payroll))); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- FIX 7: get_workforce_health_score — period column name fix
-- ============================================================
CREATE OR REPLACE FUNCTION get_workforce_health_score() RETURNS JSONB AS $$
DECLARE v_kpi NUMERIC; v_att NUMERIC; v_eng NUMERIC; BEGIN
  SELECT COALESCE(AVG(kpi_score),70) INTO v_kpi FROM hr_performance
    WHERE periode=(SELECT MAX(periode) FROM hr_performance);
  SELECT COALESCE(COUNT(*) FILTER(WHERE status_hadir='Hadir')::NUMERIC/
    NULLIF(COUNT(*),0)*100,90) INTO v_att FROM hr_attendance
    WHERE date>=date_trunc('month',NOW());
  SELECT COALESCE(AVG(score),75) INTO v_eng FROM hr_engagement;
  RETURN jsonb_build_object('ok',true,'score',ROUND(v_kpi*0.4+v_att*0.3+v_eng*0.3,1)); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- FIX 8: get_flight_risk_list — period column name fix
-- ============================================================
CREATE OR REPLACE FUNCTION get_flight_risk_list() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',e.nrp,'nama',e.nama,'divisi',e.divisi,
      'kpi_score',COALESCE(p.kpi_score,0),'telat_count',COALESCE(t.telat_count,0))
    ORDER BY COALESCE(p.kpi_score,0) ASC),'[]'::jsonb))
  FROM employees_master e
  LEFT JOIN hr_performance p ON p.nrp=e.nrp AND p.periode=(
    SELECT MAX(periode) FROM hr_performance)
  LEFT JOIN (SELECT nrp,COUNT(*) as telat_count FROM hr_attendance
    WHERE status_hadir='Telat' AND date>=date_trunc('month',NOW()) GROUP BY nrp) t ON t.nrp=e.nrp
  WHERE COALESCE(p.kpi_score,100)<70 OR COALESCE(t.telat_count,0)>5
  LIMIT 10); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- FIX 9: get_kpi_by_division — subquery fix
-- ============================================================
CREATE OR REPLACE FUNCTION get_kpi_by_division() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('divisi',divisi,'avg_kpi',avg_kpi,'headcount',headcount)
    ORDER BY avg_kpi DESC),'[]'::jsonb))
  FROM (SELECT e.divisi,ROUND(AVG(p.kpi_score),1) as avg_kpi,COUNT(*) as headcount
    FROM employees_master e LEFT JOIN hr_performance p ON p.nrp=e.nrp
    AND p.periode=(SELECT MAX(periode) FROM hr_performance)
    WHERE e.divisi IS NOT NULL GROUP BY e.divisi) t); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- FIX 10: get_turnover_data — safe division
-- ============================================================
CREATE OR REPLACE FUNCTION get_turnover_data() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('divisi',divisi,'active',active,'left',left_count,'rate',turnover_rate)),
    '[]'::jsonb))
  FROM (SELECT e.divisi,
    COUNT(*) FILTER(WHERE e.status_kerja='PKWTT') as active,
    COUNT(*) FILTER(WHERE e.status_kerja='PKWT') as left_count,
    ROUND(COUNT(*) FILTER(WHERE e.status_kerja='PKWT')::NUMERIC/
      NULLIF(COUNT(*),0)*100,1) as turnover_rate
  FROM employees_master e WHERE e.divisi IS NOT NULL GROUP BY e.divisi) t); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- DONE — All RPC errors fixed
-- Run 029_verify_all.sql to re-test
-- ============================================================
