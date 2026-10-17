-- ============================================================================
-- ROLLBACK 281 — restore versi 280 (pre-image byte-exact)
-- (md5: admin_get_facility_requests 0bdcd68d3fa13f8bbc63e525d93b1472 ·
--  get_shift_assignments 4982fdf938e6a8b6c3ff17c40e5d889c;
--  sumber: .agents/logs/m280-preimage-280.log.
--  P4: tanpa BEGIN/COMMIT — wrapper apply yang memegang transaksi.)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_get_facility_requests()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_eff text := CASE WHEN authz_check_admin('employee.view_all') THEN NULL ELSE authz_current_nrp() END;
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'nrp',nrp,'type',type,'status',status,'note',note,'created_at',created_at)
    ORDER BY created_at DESC),'[]'::jsonb))
  FROM hr_requests
  WHERE (type ILIKE '%facility%' OR type ILIKE '%aset%')
    AND (v_eff IS NULL OR nrp = v_eff)
  LIMIT 30); END;
$function$;

CREATE OR REPLACE FUNCTION public.get_shift_assignments(p_date date DEFAULT CURRENT_DATE, p_shift text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_eff text := CASE WHEN authz_check_admin('employee.view_all') THEN NULL ELSE authz_current_nrp() END;
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', sa.id, 'nrp', sa.nrp, 'date', sa.shift_date,
        'shift', sa.shift_type, 'start', sa.start_time, 'end', sa.end_time,
        'section', sa.section, 'equipment', sa.equipment,
        'status', sa.status, 'check_in', sa.check_in_time, 'check_out', sa.check_out_time
      ) ORDER BY sa.shift_type, sa.nrp
    ), '[]'::jsonb))
    FROM shift_assignments sa
    WHERE sa.shift_date = p_date
      AND (p_shift IS NULL OR sa.shift_type = p_shift)
      AND (v_eff IS NULL OR sa.nrp = v_eff)
  );
END;
$function$;