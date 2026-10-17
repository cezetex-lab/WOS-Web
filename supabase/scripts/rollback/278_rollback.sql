-- ============================================================================
-- ROLLBACK 278 — restore pre-image byte-exact 8 fungsi batch 1
-- (sumber: .agents/logs/m278-preimage.log, md5 per fungsi di META.
--  4 fungsi kembali ke LANGUAGE sql; 4 lainnya tetap plpgsql tanpa gate.
--  P4: tanpa BEGIN/COMMIT — wrapper apply yang memegang transaksi.)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_get_leave()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
  SELECT COALESCE(jsonb_agg(sub.* ORDER BY sub.nama), '[]'::jsonb)
  FROM (
    SELECT
      l.nrp, e.nama, l.tahun,
      l.annual_quota AS kuota,
      l.annual_used AS terpakai,
      (l.annual_quota - l.annual_used) AS sisa
    FROM hr_leave l
    JOIN employees_master e ON e.nrp = l.nrp
    WHERE l.tahun = EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER
  ) sub;
$function$;

CREATE OR REPLACE FUNCTION public.admin_get_low_performers()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
  SELECT COALESCE(jsonb_agg(sub.*), '[]'::jsonb)
  FROM (
    SELECT
      p.nrp,
      e.nama,
      e.divisi,
      e.business_unit,
      e.posisi,
      p.kpi_score,
      p.periode
    FROM hr_performance p
    JOIN employees_master e ON e.nrp = p.nrp
    WHERE e.status_kerja = 'Aktif'
    ORDER BY p.kpi_score ASC NULLS LAST
    LIMIT 10
  ) sub;
$function$;

CREATE OR REPLACE FUNCTION public.admin_get_top_performers()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
  SELECT COALESCE(jsonb_agg(sub.*), '[]'::jsonb)
  FROM (
    SELECT
      p.nrp,
      e.nama,
      e.divisi,
      e.business_unit,
      e.posisi,
      p.kpi_score,
      p.periode
    FROM hr_performance p
    JOIN employees_master e ON e.nrp = p.nrp
    WHERE e.status_kerja = 'Aktif'
    ORDER BY p.kpi_score DESC
    LIMIT 10
  ) sub;
$function$;

CREATE OR REPLACE FUNCTION public.admin_get_kpi_trend()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
  SELECT COALESCE(jsonb_agg(sub.* ORDER BY sub.periode ASC), '[]'::jsonb)
  FROM (
    SELECT
      p.periode,
      ROUND(AVG(p.kpi_score), 1) AS avg_kpi,
      COUNT(*) AS total_employees,
      COUNT(CASE WHEN p.kpi_score >= 80 THEN 1 END) AS high_count,
      COUNT(CASE WHEN p.kpi_score < 60 THEN 1 END) AS low_count
    FROM hr_performance p
    WHERE p.periode IS NOT NULL
    GROUP BY p.periode
    ORDER BY p.periode DESC
    LIMIT 12
  ) sub;
$function$;

CREATE OR REPLACE FUNCTION public.admin_get_assets()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (
  SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
    jsonb_build_object('id', a.id, 'asset_name', a.asset_name, 'category', a.category,
      'serial_number', a.serial_number, 'location', a.location, 'status', a.status,
      'assigned_to', a.assigned_to, 'assigned_name', e.nama, 'purchase_date', a.purchase_date)
    ORDER BY a.created_at DESC), '[]'::jsonb))
  FROM assets a
  LEFT JOIN employees_master e ON e.nrp = a.assigned_to
  LIMIT 50);
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_get_overtime()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'nrp',nrp,'date',date,'hours',hours,'reason',reason,'status',status)
    ORDER BY date DESC),'[]'::jsonb))
  FROM hr_overtime LIMIT 50); END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_get_pending_requests()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',r.id,'nrp',r.nrp,'nama',e.nama,'type',r.type,'status',r.status,'note',r.note,'created_at',r.created_at)
    ORDER BY r.created_at DESC),'[]'::jsonb))
  FROM hr_requests r LEFT JOIN employees_master e ON e.nrp=r.nrp WHERE r.status='Pending' LIMIT 50); END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_get_budget()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (
  SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
    jsonb_build_object('id', ba.id, 'divisi', ba.divisi, 'year', ba.year,
      'gaji_budget', ba.gaji_budget, 'training_budget', ba.training_budget,
      'operational_budget', ba.operational_budget, 'actual_gaji', ba.actual_gaji,
      'actual_training', ba.actual_training)
    ORDER BY ba.year DESC, ba.divisi), '[]'::jsonb))
  FROM budget_allocation ba
  LIMIT 30);
END;
$function$;