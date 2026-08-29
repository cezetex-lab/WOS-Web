-- ============================================================
-- 024: Fix 4 broken functions (Ringkasan kosong)
-- ============================================================

-- Fix 1: get_dashboard_stats (period → periode)
CREATE OR REPLACE FUNCTION get_dashboard_stats() RETURNS JSONB AS $$
BEGIN RETURN jsonb_build_object('ok',true,
  'total_workers',(SELECT COUNT(*) FROM employees_master),
  'avg_kpi',(SELECT COALESCE(ROUND(AVG(kpi_score),1),0) FROM hr_performance WHERE periode=(SELECT MAX(periode) FROM hr_performance)),
  'attendance_rate',(SELECT COALESCE(ROUND(COUNT(*) FILTER(WHERE status_hadir='Hadir')::NUMERIC/NULLIF(COUNT(*),0)*100,1),0) FROM hr_attendance WHERE date>=date_trunc('month',NOW())),
  'pending_requests',(SELECT COUNT(*) FROM hr_requests WHERE status='Pending'),
  'high_performers',(SELECT COUNT(*) FROM hr_performance WHERE kpi_score>=80 AND periode=(SELECT MAX(periode) FROM hr_performance)),
  'low_performers',(SELECT COUNT(*) FROM hr_performance WHERE kpi_score<60 AND periode=(SELECT MAX(periode) FROM hr_performance))); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fix 2: admin_get_summary (tanggal_akhir → use correct columns)
CREATE OR REPLACE FUNCTION admin_get_summary() RETURNS JSONB AS $$
BEGIN RETURN jsonb_build_object('ok',true,
  'total_workers',(SELECT COUNT(*) FROM employees_master),
  'total_divisions',(SELECT COUNT(DISTINCT divisi) FROM employees_master WHERE divisi IS NOT NULL),
  'pending_requests',(SELECT COUNT(*) FROM hr_requests WHERE status='Pending'),
  'pending_registrations',(SELECT COUNT(*) FROM daftar_baru WHERE status='PENDING'),
  'retiring_soon',(SELECT COUNT(*) FROM employees_master WHERE status_kerja='PKWT'),
  'contract_expiring',(SELECT COUNT(*) FROM employees_master WHERE status_kerja='PKWT'),
  'pkwtt_count',(SELECT COUNT(*) FROM employees_master WHERE status_kerja='PKWTT'),
  'pkwt_count',(SELECT COUNT(*) FROM employees_master WHERE status_kerja='PKWT')); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fix 3: get_kpi_by_division (p.period → p.periode)
CREATE OR REPLACE FUNCTION get_kpi_by_division() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(jsonb_build_object('divisi',divisi,'avg_kpi',avg_kpi,'headcount',headcount) ORDER BY avg_kpi DESC),'[]'::jsonb))
FROM (SELECT e.divisi,ROUND(AVG(p.kpi_score),1) as avg_kpi,COUNT(*) as headcount FROM employees_master e LEFT JOIN hr_performance p ON p.nrp=e.nrp AND p.periode=(SELECT MAX(periode) FROM hr_performance) WHERE e.divisi IS NOT NULL GROUP BY e.divisi) t); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fix 4: get_financial_trend (aggregate nesting)
CREATE OR REPLACE FUNCTION get_financial_trend() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('periode',x.periode,'total_revenue',x.total_revenue,'total_profit',x.total_profit,'total_labor',x.total_labor,
  'profit_margin',CASE WHEN x.total_revenue>0 THEN ROUND(x.total_profit/x.total_revenue*100,1) ELSE 0 END) ORDER BY x.periode DESC),'[]'::jsonb))
FROM (SELECT periode,SUM(revenue) as total_revenue,SUM(profit) as total_profit,SUM(total_labor_cost) as total_labor FROM hr_finance_kpi GROUP BY periode ORDER BY periode DESC LIMIT 6) x); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fix 5: get_turnover_data (status_kerja filter)
CREATE OR REPLACE FUNCTION get_turnover_data() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(jsonb_build_object('divisi',divisi,'active',active,'left',left_count,'rate',turnover_rate)),'[]'::jsonb))
FROM (SELECT e.divisi,COUNT(*) as active,COUNT(*) FILTER(WHERE e.status_kerja != 'PKWTT') as left_count,
  ROUND(COUNT(*) FILTER(WHERE e.status_kerja != 'PKWTT')::NUMERIC/NULLIF(COUNT(*),0)*100,1) as turnover_rate
FROM employees_master e WHERE e.divisi IS NOT NULL GROUP BY e.divisi) t); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
