-- ============================================================================
-- 280 — P2-F14-BU: scope-by-NRP 2 RPC karantina (TIDAK digate admin).
--
-- Latar (STOP #1 brief 278/279, diterima user): kedua fungsi ini terbukti
-- dikonsumsi halaman WORKER nyata, jadi gate `role_code admin_*` akan MEMUTUS
-- halaman worker. Keputusan user (brief smoke pasca-279): ubah body menjadi
-- scope-by-NRP dengan pola migrasi 276:
--   CASE WHEN authz_check_admin('employee.view_all') THEN <lihat semua>
--        ELSE <hanya baris milik authz_current_nrp()> END
-- Owner tetap lolos lewat bypass internal `authz_check_admin` (pola 276 —
-- authz_check_admin sendiri punya owner bypass).
--
-- 1. admin_get_facility_requests() — konsumen FacilityRequest.tsx (TANPA
--    useAdminAuth; mount /admin/facility, /admin/estate/facility,
--    /worker/facility, /worker/field). Body lama: SELECT semua baris
--    hr_requests tipe facility/aset LIMIT 30. Body baru: filter tambahan
--    `AND (sa-via-v_eff) ...` → worker hanya melihat miliknya sendiri.
-- 2. get_shift_assignments(p_date date, p_shift text) — konsumen
--    MillShiftSchedule.tsx (TANPA guard; mount /admin/mill/shift +
--    /worker/shift yang punya baris role_page_access). Body lama: semua
--    shift_assignments per tanggal. Body baru: non-admin hanya baris miliknya.
--
-- Signature, return shape, SECURITY DEFINER, VOLATILE, SET search_path, ACL
-- TIDAK berubah. Pre-image byte-exact: .agents/logs/m280-preimage.log
-- (oid 298121 / 298444; md5 f60ad3ea… / d6a9a6d2…).
-- Rollback: supabase/scripts/rollback/280_rollback.sql.
-- RED/GREEN: .agents/logs/m280-red.log → m280-green.log.
-- P4: tanpa BEGIN/COMMIT — wrapper apply-migration.mjs memegang transaksi.
-- ============================================================================

-- ─── 1. admin_get_facility_requests — scope-by-NRP (admin semua, worker miliknya) ───
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

-- ─── 2. get_shift_assignments — scope-by-NRP (admin semua, worker miliknya) ───
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