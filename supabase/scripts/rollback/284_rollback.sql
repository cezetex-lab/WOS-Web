-- ============================================================================
-- ROLLBACK 284 — restore pre-image 9 signature + cabut grant 284
-- (sumber: .agents/logs/m284-preimage.json — definisi live SEBELUM apply 284.
--  Body = prosrc persis TANPA newline injeksi (pelajaran 282 v1: 0/19 md5).
--  ACL pre-image semua fungsi = postgres + service_role, jadi grant
--  authenticated/anon yang ditambahkan 284 DICABUT di akhir berkas.
--  P4: tanpa BEGIN/COMMIT — wrapper apply yang memegang transaksi.)
-- ============================================================================

-- admin_get_estate_blocks() oid=298118 md5=ff4a87c7b6e5fd1bbb91c449488bc1ea
CREATE OR REPLACE FUNCTION public.admin_get_estate_blocks()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$

BEGIN RETURN (
  SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
    jsonb_build_object('id', eb.id, 'block_name', eb.block_name, 'area_hectare', eb.area_hectare,
      'terrain', eb.terrain, 'division', eb.division, 'status', eb.status)
    ORDER BY eb.block_name), '[]'::jsonb))
  FROM (
    SELECT eb.id, eb.block_name, eb.area_hectare, eb.terrain, eb.division, eb.status
    FROM estate_blocks eb
    ORDER BY eb.block_name
    LIMIT 50
  ) eb);
END;

$function$
;

-- check_registration_status(p_query text) oid=298217 md5=a1f8da94918f8f7a3e2e922b0f7e90df
CREATE OR REPLACE FUNCTION public.check_registration_status(p_query text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_status TEXT;
BEGIN
  IF p_query IS NULL OR LENGTH(TRIM(p_query)) < 4 THEN
    RETURN jsonb_build_object('ok', true, 'found', false, 'status', 'NOT_FOUND');
  END IF;
  SELECT status INTO v_status FROM daftar_baru
  WHERE nik = TRIM(p_query) OR LOWER(email) = LOWER(TRIM(p_query))
  ORDER BY id DESC LIMIT 1;
  IF v_status IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'found', false, 'status', 'NOT_FOUND');
  END IF;
  RETURN jsonb_build_object('ok', true, 'found', true, 'status', v_status);
END;
$function$
;

-- create_facility_request(p_nrp text, p_type text, p_desc text, p_priority text) oid=298235 md5=c8af90a26c03b4fc03ef16a43deeaf25
CREATE OR REPLACE FUNCTION public.create_facility_request(p_nrp text, p_type text, p_desc text, p_priority text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN INSERT INTO facility_requests(id,nrp,facility_type,description,priority) VALUES(encode(gen_random_bytes(8),'hex'),p_nrp,p_type,p_desc,COALESCE(p_priority,'NORMAL'));
RETURN jsonb_build_object('ok',true,'msg','Pengajuan fasilitas dikirim.'); END; $function$
;

-- get_active_surveys() oid=298274 md5=a97ad30c08c55585130298e3c149b247
CREATE OR REPLACE FUNCTION public.get_active_surveys()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN jsonb_build_object('ok',true,'data',COALESCE((SELECT jsonb_agg(jsonb_build_object('id',id,'title',title,'questions',questions)) FROM hr_surveys WHERE status='active'),'[]'::jsonb)); END;
$function$
;

-- get_exit_clearance(p_nrp text) oid=298345 md5=e2492effe0d9fce58649d1417dc042e2
CREATE OR REPLACE FUNCTION public.get_exit_clearance(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', ec.id, 'nrp', ec.nrp, 'step', ec.step, 'status', ec.status,
        'completed_at', ec.completed_at, 'notes', ec.notes
      ) ORDER BY ec.id
    ), '[]'::jsonb))
    FROM hr_exit_clearance ec
    WHERE ec.nrp = p_nrp
    LIMIT 20
  );
END;
$function$
;

-- get_overtime_data(p_nrp text) oid=298418 md5=8b57777e7e551f7dbf325e5a108b4b70
CREATE OR REPLACE FUNCTION public.get_overtime_data(p_nrp text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', r.id, 'nrp', r.nrp, 'type', r.type, 'status', r.status,
        'note', r.note, 'created_at', r.created_at
      ) ORDER BY r.created_at DESC
    ), '[]'::jsonb))
    FROM hr_requests r
    WHERE r.type ILIKE '%overtime%' OR r.type ILIKE '%lembur%'
    AND (p_nrp IS NULL OR r.nrp = p_nrp)
    LIMIT 50
  );
END;
$function$
;

-- get_overtime_data(p_nrp text, p_from date, p_to date) oid=298419 md5=f9ae63de4b859ab8adcbd122ce656e20
CREATE OR REPLACE FUNCTION public.get_overtime_data(p_nrp text, p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',nrp,'date',date,'hours',hours,'reason',reason,'status',status) ORDER BY date DESC),'[]'::jsonb))
  FROM hr_overtime WHERE (p_nrp IS NULL OR nrp=p_nrp) AND (p_from IS NULL OR date>=p_from) AND (p_to IS NULL OR date<=p_to) LIMIT 30); END;
$function$
;

-- get_worker_engagement(p_nrp text) oid=298478 md5=6280b36c00a6cdd5dbc87df2106e01e9
CREATE OR REPLACE FUNCTION public.get_worker_engagement(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE v_caller TEXT; v_is_owner BOOLEAN; v RECORD;
BEGIN
  IF p_nrp IS NULL OR LENGTH(p_nrp) < 3 OR LENGTH(p_nrp) > 20 THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Format NRP tidak valid');
  END IF;
  v_caller := authz_current_nrp();
  SELECT EXISTS (SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = TRUE) INTO v_is_owner;
  IF NOT v_is_owner AND p_nrp != v_caller AND NOT authz_in_scope(p_nrp) THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak');
  END IF;
  SELECT * INTO v FROM hr_engagement WHERE nrp = p_nrp ORDER BY created_at DESC LIMIT 1;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', true, 'score', 0, 'category', 'N/A'); END IF;
  RETURN jsonb_build_object('ok', true, 'score', COALESCE(v.score, 0),
    'category', CASE WHEN v.score>=80 THEN 'Highly Engaged' WHEN v.score>=60 THEN 'Engaged' ELSE 'Needs Attention' END,
    'period', v.period);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('ok', false, 'msg', 'Terjadi kesalahan sistem');
END;
$function$
;

-- get_worker_tasks(p_nrp text) oid=298496 md5=074688893f8a25d19e2d2acb61b0d2d4
CREATE OR REPLACE FUNCTION public.get_worker_tasks(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'title',title,'status',status,'due_date',due_date)
    ORDER BY due_date),'[]'::jsonb))
  FROM hr_tasks WHERE assignee_nrp=p_nrp LIMIT 20); END;
$function$
;

-- Cabut grant yang ditambahkan 284 (ACL kembali ke pre-image)
REVOKE EXECUTE ON FUNCTION public.get_worker_tasks(text) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.get_worker_engagement(text) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.get_exit_clearance(text) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.get_overtime_data(text) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.get_overtime_data(text, date, date) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.create_facility_request(text, text, text, text) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.admin_get_estate_blocks() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.get_active_surveys() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.check_registration_status(text) FROM anon, authenticated;
