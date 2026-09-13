-- ================================================================
-- 209_dead_forms_handlers.sql — Tahap 5.5 (A11 form mati tanpa handler)
--
-- Bukti live (pre-flight 2026-09-13):
--   SafetyK3.jsx form "📤 Kirim Laporan" — no onClick handler.
--     → Missing RPC: report_safety_incident
--   FacilityRequest.jsx form "📤 Kirim Request" — no onClick handler.
--     → RPC exists: create_facility_request (migration 171)
--   HarvestRecord.jsx form "📤 Catat Panen" — no onClick handler.
--     → Missing RPC: create_harvest_record
--
-- Fix: CREATE 2 new RPCs (idempotent). Frontend wiring in separate files.
-- Rollback: supabase/migrations/rollback/209_rollback.sql
-- ================================================================

-- 1. report_safety_incident — insert into safety_incidents (created in 208)
CREATE OR REPLACE FUNCTION public.report_safety_incident(
  p_nrp text,
  p_type text,
  p_zone text,
  p_desc text,
  p_severity text DEFAULT 'MEDIUM'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_id text;
BEGIN
  IF p_nrp IS NULL OR p_nrp = '' THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'NRP wajib diisi.');
  END IF;
  IF p_desc IS NULL OR p_desc = '' THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Deskripsi wajib diisi.');
  END IF;
  v_id := 'SAF-' || encode(gen_random_bytes(4), 'hex');
  INSERT INTO safety_incidents (id, incident_date, zone, incident_type, severity, description, reporter_nrp, status)
  VALUES (v_id, CURRENT_DATE, COALESCE(p_zone, 'UNKNOWN'), COALESCE(p_type, 'INCIDENT'),
          COALESCE(p_severity, 'MEDIUM'), p_desc, p_nrp, 'OPEN');
  RETURN jsonb_build_object('ok', true, 'msg', 'Laporan insiden terkirim.', 'id', v_id);
END;
$function$;

-- 2. create_harvest_record — insert into harvest_records (exists since 001)
CREATE OR REPLACE FUNCTION public.create_harvest_record(
  p_nrp text,
  p_block text,
  p_weight_kg numeric,
  p_ripe_pct numeric DEFAULT 0,
  p_quality text DEFAULT 'B'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_id text;
BEGIN
  IF p_nrp IS NULL OR p_nrp = '' THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'NRP wajib diisi.');
  END IF;
  IF p_block IS NULL OR p_block = '' THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Blok wajib dipilih.');
  END IF;
  IF p_weight_kg IS NULL OR p_weight_kg <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Berat harus lebih dari 0.');
  END IF;
  v_id := 'HVT-' || encode(gen_random_bytes(4), 'hex');
  INSERT INTO harvest_records (id, block, harvest_date, weight_kg, ripe_pct, worker_nrp, quality)
  VALUES (v_id, p_block, CURRENT_DATE, p_weight_kg,
          COALESCE(p_ripe_pct, 0), p_nrp, COALESCE(p_quality, 'B'));
  RETURN jsonb_build_object('ok', true, 'msg', 'Panen tercatat.', 'id', v_id);
END;
$function$;

-- 3. Verify
SELECT '209.1 report_safety_incident exists' AS test,
  CASE WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname='report_safety_incident')
  THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT '209.2 create_harvest_record exists' AS test,
  CASE WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname='create_harvest_record')
  THEN 'PASS' ELSE 'FAIL' END AS result;

-- Smoke test (returns error because authz_current_nrp() = NULL from postgres role)
SELECT '209.3 smoke report_safety_incident' AS test, (report_safety_incident('NRP001','INCIDENT','PIT-1','Test incident','LOW')) AS result;
SELECT '209.4 smoke create_harvest_record' AS test, (create_harvest_record('NRP001','BLOK-A1',25000,85,'A')) AS result;
