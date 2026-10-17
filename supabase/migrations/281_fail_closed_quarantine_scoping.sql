-- ============================================================================
-- 281 — Fix FAIL-CLOSED scoping P2-F14-BU (2 fungsi dari migrasi 280).
--
-- Temuan GREEN proof 280 (bukti: .agents/logs/m280-green.log run-3 bagian 4,
--   no-JWT claims → facility n=2 / shift n=2 = SEMUA baris bocor):
--   Body 280 memakai `v_eff := CASE WHEN authz_check_admin(...) THEN NULL
--   ELSE authz_current_nrp() END` + filter `(v_eff IS NULL OR nrp = v_eff)`.
--   Untuk caller TANPA JWT claims: authz_check_admin=false DAN
--   authz_current_nrp()=NULL → v_eff=NULL → cabang `v_eff IS NULL` melepas
--   SELURUH baris. (Caller PostgREST nyata selalu ber-JWT, tapi desain harus
--   fail-closed — pola 276 tanpa `IS NULL` memang fail-closed alami karena
--   `nrp = NULL` → 0 baris.)
--
-- Fix: ganti dengan dua variabel v_is_admin (boolean) + v_nrp (text), filter
--   `(v_is_admin OR nrp = v_nrp)` — identik gaya WHERE 276:
--   * admin (employee.view_all / owner bypass) → semua baris
--   * worker ber-JWT → hanya baris miliknya
--   * tanpa JWT / authz_current_nrp() NULL → `nrp = NULL` → 0 baris (fail-closed)
--
-- Signature, return shape, SECURITY DEFINER, VOLATILE, SET search_path, ACL
-- TIDAK berubah. Pre-image byte-exact (versi 280): md5 0bdcd68d3fa13f8bbc63e525d93b1472
--   / 4982fdf938e6a8b6c3ff17c40e5d889c (.agents/logs/m280-preimage-280.log).
-- Rollback: supabase/scripts/rollback/281_rollback.sql.
-- RED: no-JWT bocor n=2 (terbukti di GREEN 280 run-3); GREEN: no-JWT n=0,
--   worker n=1, admin n=2 (.agents/logs/m281-green.log).
-- P4: tanpa BEGIN/COMMIT — wrapper apply-migration.mjs memegang transaksi.
-- ============================================================================

-- ─── 1. admin_get_facility_requests — fail-closed scoping ──────────────────
CREATE OR REPLACE FUNCTION public.admin_get_facility_requests()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_is_admin boolean := authz_check_admin('employee.view_all');
  v_nrp text := authz_current_nrp();
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'nrp',nrp,'type',type,'status',status,'note',note,'created_at',created_at)
    ORDER BY created_at DESC),'[]'::jsonb))
  FROM hr_requests
  WHERE (type ILIKE '%facility%' OR type ILIKE '%aset%')
    AND (v_is_admin OR nrp = v_nrp)
  LIMIT 30); END;
$function$;

-- ─── 2. get_shift_assignments — fail-closed scoping ────────────────────────
CREATE OR REPLACE FUNCTION public.get_shift_assignments(p_date date DEFAULT CURRENT_DATE, p_shift text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_is_admin boolean := authz_check_admin('employee.view_all');
  v_nrp text := authz_current_nrp();
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
      AND (v_is_admin OR sa.nrp = v_nrp)
  );
END;
$function$;