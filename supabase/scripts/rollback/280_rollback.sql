-- ============================================================================
-- ROLLBACK 280 — restore pre-image byte-exact 2 fungsi karantina
-- (teks prosrc diverifikasi md5 via .agents/scripts/m280-rollback-recon.mjs:
--  admin_get_facility_requests f60ad3ea0b52589bcd3c25571976b92d ·
--  get_shift_assignments d6a9a6d206e5abfec0bbe4eb3d066d32.
--  P4: tanpa BEGIN/COMMIT — wrapper apply yang memegang transaksi.)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_get_facility_requests()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'nrp',nrp,'type',type,'status',status,'note',note,'created_at',created_at)
    ORDER BY created_at DESC),'[]'::jsonb))
  FROM hr_requests WHERE type ILIKE '%facility%' OR type ILIKE '%aset%' LIMIT 30); END;
$function$;

CREATE OR REPLACE FUNCTION public.get_shift_assignments(p_date date DEFAULT CURRENT_DATE, p_shift text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
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
  );
END;
$function$;
