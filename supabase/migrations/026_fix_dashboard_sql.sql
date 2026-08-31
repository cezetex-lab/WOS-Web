-- ============================================================
-- 026: Fix ALL broken dashboard SQL — ACTUAL schema columns
-- ============================================================
-- Actual columns verified from 001_init.sql:
-- employees_master: nrp, nama, divisi, posisi (NOT jabatan), status_kerja
-- hr_org: nrp, atasan_nrp (NOT manager_nrp)
-- hr_requests: id, nrp, type, status, note (NOT detail)
-- hr_ai_tasks: id, task_type, title, status, priority, details_json, created_at (NOT nrp, NOT anomaly_type)
-- hr_notifications: id, nrp, category, title, message, is_read (NOT priority)
-- hr_monthly_snapshot: periode, divisi, total_headcount, avg_kpi, total_revenue, total_profit, total_payroll (NOT headcount/revenue/profit/labor_cost)
-- hr_performance: nrp, periode, kpi_score
-- ============================================================

-- Fix 1: get_team_data (posisi NOT jabatan, atasan_nrp NOT manager_nrp)
DROP FUNCTION IF EXISTS get_team_data(p_nrp TEXT);
CREATE OR REPLACE FUNCTION get_team_data(p_nrp TEXT) RETURNS JSONB AS $BODY$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',e.nrp,'nama',e.nama,'divisi',e.divisi,'posisi',e.posisi,'kpi_score',COALESCE(p.kpi_score,0),'status_kerja',e.status_kerja)
  ORDER BY e.nama),'[]'::jsonb))
FROM employees_master e
JOIN hr_org o ON o.nrp=e.nrp AND o.atasan_nrp=p_nrp
LEFT JOIN hr_performance p ON p.nrp=e.nrp AND p.periode=(SELECT MAX(periode) FROM hr_performance)); END;
$BODY$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fix 2: get_team_requests (detail NOT exist, use note)
DROP FUNCTION IF EXISTS get_team_requests(p_nrp TEXT);
CREATE OR REPLACE FUNCTION get_team_requests(p_nrp TEXT) RETURNS JSONB AS $BODY$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',r.id,'nrp',r.nrp,'type',r.type,'note',r.note,'status',r.status,'created_at',r.created_at)
  ORDER BY r.created_at DESC),'[]'::jsonb))
FROM hr_requests r
JOIN hr_org o ON o.nrp=r.nrp AND o.atasan_nrp=p_nrp
WHERE r.status IN ('Pending','PENDING')); END;
$BODY$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fix 3: get_monthly_snapshot_trend (correct column names)
DROP FUNCTION IF EXISTS get_monthly_snapshot_trend(p_divisi TEXT);
CREATE OR REPLACE FUNCTION get_monthly_snapshot_trend(p_divisi TEXT DEFAULT NULL) RETURNS JSONB AS $BODY$
BEGIN RETURN jsonb_build_object('ok',true,'data',COALESCE((SELECT jsonb_agg(sub) FROM (SELECT ms.periode,ms.total_headcount as headcount,ms.avg_kpi,ms.total_turnover as turnover,ms.total_revenue as revenue,ms.total_profit as profit,ms.total_payroll as payroll FROM hr_monthly_snapshot ms WHERE (p_divisi IS NULL OR ms.divisi=p_divisi) ORDER BY ms.periode DESC LIMIT 12) sub),'[]'::jsonb)); END;
$BODY$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fix 4: get_team_narrative (atosan_nrp NOT manager_nrp)
DROP FUNCTION IF EXISTS get_team_narrative(p_nrp TEXT);
CREATE OR REPLACE FUNCTION get_team_narrative(p_nrp TEXT) RETURNS JSONB AS $BODY$
DECLARE v_kpi NUMERIC; v_att NUMERIC; v_nama TEXT; v_narasi TEXT;
BEGIN
  SELECT ROUND(AVG(p.kpi_score),1) INTO v_kpi FROM hr_performance p
    JOIN hr_org o ON o.nrp=p.nrp WHERE o.atasan_nrp=p_nrp AND p.periode=(SELECT MAX(periode) FROM hr_performance);
  SELECT ROUND(COUNT(*) FILTER(WHERE a.status_hadir='Hadir')::NUMERIC/NULLIF(COUNT(*),0)*100,1) INTO v_att
    FROM hr_attendance a JOIN hr_org o ON o.nrp=a.nrp WHERE o.atasan_nrp=p_nrp AND a.date>=date_trunc('month',NOW());
  SELECT nama INTO v_nama FROM employees_master WHERE nrp=p_nrp;
  v_narasi := 'Ringkasan tim '||COALESCE(v_nama,'Manager')||'. ';
  v_narasi := v_narasi || 'Avg KPI tim: '||COALESCE(v_kpi,0)||'. ';
  v_narasi := v_narasi || 'Kehadiran tim: '||COALESCE(v_att,100)||'%.';
  RETURN jsonb_build_object('ok',true,'narrative',v_narasi,'avg_kpi',COALESCE(v_kpi,0),'attendance_pct',COALESCE(v_att,100)); END;
$BODY$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fix 5: get_anomaly_details (hr_ai_tasks has no nrp column)
DROP FUNCTION IF EXISTS get_anomaly_details();
CREATE OR REPLACE FUNCTION get_anomaly_details() RETURNS JSONB AS $BODY$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'type',task_type,'title',title,'priority',priority,'status',status,'details',details_json,'created_at',created_at)
  ORDER BY created_at DESC),'[]'::jsonb))
FROM hr_ai_tasks LIMIT 20); END;
$BODY$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fix 6: get_subtree_data (posisi NOT jabatan, atasan_nrp NOT manager_nrp)
DROP FUNCTION IF EXISTS get_subtree_data(p_nrp TEXT);
CREATE OR REPLACE FUNCTION get_subtree_data(p_nrp TEXT) RETURNS JSONB AS $BODY$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',e.nrp,'nama',e.nama,'divisi',e.divisi,'posisi',e.posisi,'level',ur.role_level,'atasan_nrp',o.atasan_nrp)
  ORDER BY ur.role_level,e.nama),'[]'::jsonb))
FROM employees_master e
JOIN hr_org o ON o.nrp=e.nrp
LEFT JOIN user_roles ur ON ur.nrp=e.nrp
WHERE o.atasan_nrp=p_nrp OR e.nrp=p_nrp); END;
$BODY$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fix 7: get_executive_summary (periode NOT period)
DROP FUNCTION IF EXISTS get_executive_summary();
CREATE OR REPLACE FUNCTION get_executive_summary() RETURNS JSONB AS $BODY$
BEGIN RETURN jsonb_build_object('ok',true,
  'headcount',(SELECT COUNT(*) FROM employees_master),
  'avg_kpi',(SELECT COALESCE(ROUND(AVG(kpi_score),1),0) FROM hr_performance WHERE periode=(SELECT MAX(periode) FROM hr_performance)),
  'high_performers',(SELECT COUNT(*) FROM hr_performance WHERE kpi_score>=80 AND periode=(SELECT MAX(periode) FROM hr_performance)),
  'low_performers',(SELECT COUNT(*) FROM hr_performance WHERE kpi_score<60 AND periode=(SELECT MAX(periode) FROM hr_performance)),
  'turnover_rate',(SELECT COALESCE(ROUND(COUNT(*) FILTER(WHERE status_kerja!='PKWTT')::NUMERIC/NULLIF(COUNT(*),0)*100,1),0) FROM employees_master),
  'total_payroll',(SELECT COALESCE(SUM(net_salary),0) FROM hr_payroll WHERE periode=(SELECT MAX(periode) FROM hr_payroll))); END;
$BODY$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fix 8: get_workforce_health_score (periode NOT period)
DROP FUNCTION IF EXISTS get_workforce_health_score();
CREATE OR REPLACE FUNCTION get_workforce_health_score() RETURNS JSONB AS $BODY$
DECLARE v_kpi NUMERIC; v_att NUMERIC; v_eng NUMERIC;
BEGIN
  SELECT COALESCE(ROUND(AVG(kpi_score),1),0) INTO v_kpi FROM hr_performance WHERE periode=(SELECT MAX(periode) FROM hr_performance);
  SELECT COALESCE(ROUND(COUNT(*) FILTER(WHERE status_hadir='Hadir')::NUMERIC/NULLIF(COUNT(*),0)*100,1),0) INTO v_att FROM hr_attendance WHERE date>=date_trunc('month',NOW());
  SELECT COALESCE(ROUND(AVG(score),0),0) INTO v_eng FROM hr_engagement;
  RETURN jsonb_build_object('ok',true,'kpi_score',v_kpi,'attendance_rate',v_att,'engagement_score',v_eng,
    'overall_score',ROUND((COALESCE(v_kpi,0)*0.4+COALESCE(v_att,0)*0.3+COALESCE(v_eng,0)*0.3),1)); END;
$BODY$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fix 9: get_flight_risk_list (periode NOT period)
DROP FUNCTION IF EXISTS get_flight_risk_list();
CREATE OR REPLACE FUNCTION get_flight_risk_list() RETURNS JSONB AS $BODY$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',e.nrp,'nama',e.nama,'divisi',e.divisi,'kpi_score',COALESCE(p.kpi_score,0),'risk_level',
    CASE WHEN COALESCE(p.kpi_score,0)<50 THEN 'HIGH' WHEN COALESCE(p.kpi_score,0)<70 THEN 'MEDIUM' ELSE 'LOW' END)
  ORDER BY COALESCE(p.kpi_score,0) ASC),'[]'::jsonb))
FROM employees_master e
LEFT JOIN hr_performance p ON p.nrp=e.nrp AND p.periode=(SELECT MAX(periode) FROM hr_performance)
WHERE e.status_kerja='PKWTT'); END;
$BODY$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fix 10: get_organization_health (periode NOT period)
DROP FUNCTION IF EXISTS get_organization_health();
CREATE OR REPLACE FUNCTION get_organization_health() RETURNS JSONB AS $BODY$
BEGIN RETURN jsonb_build_object('ok',true,
  'headcount',(SELECT COUNT(*) FROM employees_master),
  'avg_kpi',(SELECT COALESCE(ROUND(AVG(kpi_score),1),0) FROM hr_performance WHERE periode=(SELECT MAX(periode) FROM hr_performance)),
  'turnover_rate',(SELECT COALESCE(ROUND(COUNT(*) FILTER(WHERE status_kerja!='PKWTT')::NUMERIC/NULLIF(COUNT(*),0)*100,1),0) FROM employees_master),
  'engagement_score',(SELECT COALESCE(ROUND(AVG(score),0),0) FROM hr_engagement),
  'compliance_rate',(SELECT COALESCE(ROUND(COUNT(*) FILTER(WHERE status='Compliant')::NUMERIC/NULLIF(COUNT(*),0)*100,1),0) FROM hr_compliance),
  'safety_incidents',(SELECT COUNT(*) FROM hr_safety)); END;
$BODY$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fix 11: get_early_warning (hr_notifications has no priority)
DROP FUNCTION IF EXISTS get_early_warning();
CREATE OR REPLACE FUNCTION get_early_warning() RETURNS JSONB AS $BODY$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'nrp',nrp,'category',category,'title',title,'message',message,'is_read',is_read,'created_at',created_at)
  ORDER BY created_at DESC),'[]'::jsonb))
FROM hr_notifications WHERE is_read=false LIMIT 10); END;
$BODY$ LANGUAGE plpgsql SECURITY DEFINER;

SELECT '026 ALL dashboard functions FIXED with ACTUAL schema' as status;
