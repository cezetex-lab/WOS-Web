-- ============================================================================
-- 277_rollback — KEMBALIKAN migrasi 277_restore_mill_boiler_and_fix_rpcs.sql.
--
-- Pre-image = pg_get_functiondef live 2026-10-17 pra-apply
-- (dump: .agents/logs/m277-preimage.log) — termasuk BUG 42803 yang asli
-- (rollback = kondisi persis sebelum 277, bukan versi "diperbaiki").
-- Kembalikan juga: DROP TABLE mill_boiler (kondisi pra-277: tabel TIDAK ADA —
-- itulah temuan BS), policy + grant ikut hilang mengikuti tabel.
--
-- TIDAK menyentuh get_boiler_status (277 juga tidak mengubahnya — oid 298291 /
-- md5 8682b9f431785e5c5e474abc20340f68 tetap identik sebelum & sesudah rollback).
--
-- Jalankan di transaksi: BEGIN; \i 277_rollback.sql; -- verifikasi; COMMIT;
-- ============================================================================
-- Pre-image md5 prosrc: breakdown a4cb6866642f42920311eee0d3e4f2d1 (729) ·
--   packing 27d9b7999d7d9057e54db46aa2bd387d (605) ·
--   qc 71386dc1ac04cb4863397b5d8300a254 (575)
-- oid pre-image: 298294 / 298423 / 298434 (CREATE OR REPLACE mempertahankan)
-- ============================================================================

DROP TABLE IF EXISTS mill_boiler;

CREATE OR REPLACE FUNCTION public.get_breakdown_log(p_limit integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', bd.id, 'equipment', bd.equipment_code, 'equipment_name', bd.equipment_name,
        'time', bd.breakdown_time, 'resolved', bd.resolved_time,
        'severity', bd.severity, 'category', bd.category,
        'description', bd.description, 'root_cause', bd.root_cause,
        'action', bd.action_taken, 'status', bd.status,
        'downtime', bd.downtime_hours, 'cost', bd.cost,
        'reported_by', bd.reported_by, 'assigned_to', bd.assigned_to
      ) ORDER BY bd.breakdown_time DESC
    ), '[]'::jsonb))
    FROM mill_breakdowns bd
    ORDER BY bd.breakdown_time DESC
    LIMIT p_limit
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_packing_log(p_limit integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', pk.id, 'date', pk.pack_date, 'time', pk.pack_time,
        'product', pk.product_type, 'quantity', pk.quantity_kg,
        'batch_id', pk.batch_id, 'destination', pk.destination,
        'truck_plate', pk.truck_plate, 'driver', pk.driver_name,
        'status', pk.status, 'qc_status', pk.qc_status
      ) ORDER BY pk.pack_date DESC, pk.pack_time DESC
    ), '[]'::jsonb))
    FROM mill_packing pk
    ORDER BY pk.pack_date DESC, pk.pack_time DESC
    LIMIT p_limit
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_qc_results(p_limit integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', q.id, 'batch_id', q.batch_id, 'date', q.sample_date,
        'time', q.sample_time, 'ffa', q.ffa_pct, 'moisture', q.moisture_pct,
        'dobi', q.dobi, 'color', q.color, 'dirt', q.dirt_pct,
        'result', q.result, 'tested_by', q.tested_by, 'notes', q.notes
      ) ORDER BY q.sample_date DESC, q.sample_time DESC
    ), '[]'::jsonb))
    FROM mill_qc_results q
    ORDER BY q.sample_date DESC, q.sample_time DESC
    LIMIT p_limit
  );
END;
$function$;
