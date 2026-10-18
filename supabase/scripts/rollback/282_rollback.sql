-- ============================================================================
-- ROLLBACK 282 — restore pre-image byte-exact 19 fungsi admin_get_* (AZ)
-- (sumber: .agents/logs/m282-19-preimage.json — prosrc live SEBELUM apply 282.
--  Body antara AS $function$ dan $function$; = prosrc persis TANPA newline
--  injeksi (bug generator v1: 0/19 md5 cocok — terbukti green bagian 4 run-1).
--  P4: tanpa BEGIN/COMMIT — wrapper apply yang memegang transaksi.)
-- ============================================================================

-- admin_get_asset_assignments oid=298108 md5=28ef015c24cbc32ca8cfa2bf4b5fa452
CREATE OR REPLACE FUNCTION public.admin_get_asset_assignments()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path=public, extensions
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code IN ('admin_pusat','admin_operasional')) AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501'; END IF;
  RETURN (
  SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
    jsonb_build_object('id', aa.id, 'asset_id', aa.asset_id, 'asset_name', a.asset_name,
      'nrp', aa.nrp, 'nama', e.nama, 'checkout_date', aa.checkout_date,
      'checkin_date', aa.checkin_date, 'condition_out', aa.condition_out, 'condition_in', aa.condition_in)
    ORDER BY aa.checkout_date DESC), '[]'::jsonb))
  FROM asset_assignments aa
  LEFT JOIN assets a ON a.id = aa.asset_id
  LEFT JOIN employees_master e ON e.nrp = aa.nrp
  LIMIT 50);
END;
$function$;

-- admin_get_assets oid=298109 md5=758dabd428de64e81bd1187cbbf65671
CREATE OR REPLACE FUNCTION public.admin_get_assets()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path=public, extensions
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code IN ('admin_pusat','admin_operasional')) AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501'; END IF;
  RETURN (
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

-- admin_get_audit_chain oid=298110 md5=1c45ea53f63d2f86302d4e4ede10e6be
CREATE OR REPLACE FUNCTION public.admin_get_audit_chain()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path=public, extensions
AS $function$ BEGIN IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code = 'admin_pusat') AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak. Hanya admin_pusat.' USING ERRCODE = '42501'; END IF; RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'timestamp',timestamp,'actor',actor,'action',action,'detail',detail)
    ORDER BY timestamp DESC),'[]'::jsonb))
  FROM audit_log LIMIT 50); END;
$function$;

-- admin_get_badges oid=298112 md5=37b73a1f7c892c781bf6eee19f6f3dbd
CREATE OR REPLACE FUNCTION public.admin_get_badges()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path=public, extensions
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code IN ('admin_pusat','admin_hrd')) AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501'; END IF;
  RETURN (
  SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
    jsonb_build_object('id', b.id, 'nrp', b.nrp, 'nama', e.nama,
      'badge_name', b.badge_name, 'badge_type', b.badge_type,
      'points', b.points, 'awarded_date', b.awarded_date)
    ORDER BY b.awarded_date DESC), '[]'::jsonb))
  FROM badges b
  LEFT JOIN employees_master e ON e.nrp = b.nrp
  LIMIT 50);
END;
$function$;

-- admin_get_budget oid=298113 md5=8ea688c46240cf8f3840449741b64715
CREATE OR REPLACE FUNCTION public.admin_get_budget()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path=public, extensions
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code IN ('admin_pusat','admin_finance')) AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501'; END IF;
  RETURN (
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

-- admin_get_certifications oid=298114 md5=6ac63a7088478cd282a75cdd2ba278b2
CREATE OR REPLACE FUNCTION public.admin_get_certifications()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path=public, extensions
AS $function$
BEGIN RETURN (
  SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
    jsonb_build_object('id', c.id, 'nrp', c.nrp, 'nama', e.nama,
      'cert_name', c.cert_name, 'issuer', c.issuer,
      'issue_date', c.issue_date, 'expiry_date', c.expiry_date, 'status', c.status)
    ORDER BY c.expiry_date), '[]'::jsonb))
  FROM certifications c
  LEFT JOIN employees_master e ON e.nrp = c.nrp
  LIMIT 50);
END;
$function$;

-- admin_get_estate_blocks oid=298118 md5=60cf263933e21da000d06fb6ba184a97
CREATE OR REPLACE FUNCTION public.admin_get_estate_blocks()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path=public, extensions
AS $function$
BEGIN RETURN (
  SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
    jsonb_build_object('id', eb.id, 'block_name', eb.block_name, 'area_hectare', eb.area_hectare,
      'terrain', eb.terrain, 'division', eb.division, 'status', eb.status)
    ORDER BY eb.block_name), '[]'::jsonb))
  FROM estate_blocks eb
  LIMIT 50);
END;
$function$;

-- admin_get_exit_interviews oid=298119 md5=7319847b18c3cae53bfeb1e858648c26
CREATE OR REPLACE FUNCTION public.admin_get_exit_interviews()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path=public, extensions
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code IN ('admin_pusat','admin_hrd')) AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501'; END IF;
  RETURN (
  SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
    jsonb_build_object('id', ei.id, 'nrp', ei.nrp, 'nama', e.nama,
      'satisfaction_score', ei.satisfaction_score, 'reason', ei.reason,
      'feedback', ei.feedback, 'created_at', ei.created_at)
    ORDER BY ei.created_at DESC), '[]'::jsonb))
  FROM exit_interviews ei
  LEFT JOIN employees_master e ON e.nrp = ei.nrp
  LIMIT 30);
END;
$function$;

-- admin_get_facility_requests oid=298121 md5=1c020df80e269affe1ecd6f7b45b8ae4
CREATE OR REPLACE FUNCTION public.admin_get_facility_requests()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path=public, extensions
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

-- admin_get_headcount_plan oid=298123 md5=35af3d195b00d5435f3c2bcf277728dd
CREATE OR REPLACE FUNCTION public.admin_get_headcount_plan()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path=public, extensions
AS $function$
BEGIN RETURN (
  SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
    jsonb_build_object('id', hp.id, 'divisi', hp.divisi, 'year', hp.year,
      'quarter', hp.quarter, 'planned_hc', hp.planned_hc, 'actual_hc', hp.actual_hc,
      'notes', hp.notes)
    ORDER BY hp.year DESC, hp.quarter), '[]'::jsonb))
  FROM headcount_plans hp
  LIMIT 30);
END;
$function$;

-- admin_get_master_data oid=298129 md5=d658f876ebce8ebdaaed8f8b6cdf2812
CREATE OR REPLACE FUNCTION public.admin_get_master_data()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path=public, extensions
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code = 'admin_pusat') AND NOT authz_is_owner() THEN
    RAISE EXCEPTION 'Akses ditolak. Hanya admin_pusat.' USING ERRCODE = '42501';
  END IF;
  RETURN (
    SELECT jsonb_build_object('ok', true,
      'roles', (SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'nrp', ur.nrp, 'role', ur.role, 'tier', ur.role_level
      ) ORDER BY ur.role_level DESC, ur.nrp ASC), '[]'::jsonb) FROM user_roles ur LIMIT 100),
      'divisions', (SELECT COALESCE(jsonb_agg(DISTINCT jsonb_build_object(
        'divisi', md.division_name
      )), '[]'::jsonb) FROM master_divisions md WHERE md.division_name IS NOT NULL)
    )
  );
END;
$function$;

-- admin_get_okr oid=298130 md5=0dd06ac6c55756b5689ec2394519042b
CREATE OR REPLACE FUNCTION public.admin_get_okr()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path=public, extensions
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code IN ('admin_pusat','admin_hrd')) AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501'; END IF;
  RETURN (
  SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
    jsonb_build_object('id', o.id, 'nrp', o.nrp, 'nama', e.nama,
      'objective', o.objective, 'key_result', o.key_result,
      'target_value', o.target_value, 'current_value', o.current_value,
      'status', o.status, 'periode', o.periode)
    ORDER BY o.periode DESC, o.nrp), '[]'::jsonb))
  FROM hr_okrs o   -- ✅ FIXED: was 'okrs'
  LEFT JOIN employees_master e ON e.nrp = o.nrp
  LIMIT 50);
END;
$function$;

-- admin_get_overtime oid=298132 md5=d5767cb062f669193b26c94211bd2c9c
CREATE OR REPLACE FUNCTION public.admin_get_overtime()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path=public, extensions
AS $function$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code IN ('admin_pusat','admin_finance','admin_operasional')) AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501'; END IF;
 RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'nrp',nrp,'date',date,'hours',hours,'reason',reason,'status',status)
    ORDER BY date DESC),'[]'::jsonb))
  FROM hr_overtime LIMIT 50); END;
$function$;

-- admin_get_pending_requests oid=298137 md5=12511a0f1bb691cf2ae5795525638eb2
CREATE OR REPLACE FUNCTION public.admin_get_pending_requests()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path=public, extensions
AS $function$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code IN ('admin_pusat','admin_hrd','admin_operasional')) AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501'; END IF;
 RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',r.id,'nrp',r.nrp,'nama',e.nama,'type',r.type,'status',r.status,'note',r.note,'created_at',r.created_at)
    ORDER BY r.created_at DESC),'[]'::jsonb))
  FROM hr_requests r LEFT JOIN employees_master e ON e.nrp=r.nrp WHERE r.status='Pending' LIMIT 50); END;
$function$;

-- admin_get_referrals oid=298138 md5=aac1aca2633e789215cbfc6189253335
CREATE OR REPLACE FUNCTION public.admin_get_referrals()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path=public, extensions
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code IN ('admin_pusat','admin_hrd')) AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501'; END IF;
  RETURN (
  SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
    jsonb_build_object('id', r.id, 'referrer_nrp', r.referrer_nrp, 'referrer_name', e.nama,
      'candidate_name', r.candidate_name, 'candidate_email', r.candidate_email,
      'position', r.position, 'status', r.status, 'bonus_paid', r.bonus_paid)
    ORDER BY r.created_at DESC), '[]'::jsonb))
  FROM referrals r
  LEFT JOIN employees_master e ON e.nrp = r.referrer_nrp
  LIMIT 30);
END;
$function$;

-- admin_get_settlements oid=298140 md5=8569bb81cfeb405944e6d9acbc8a3bce
CREATE OR REPLACE FUNCTION public.admin_get_settlements()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path=public, extensions
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code IN ('admin_pusat','admin_hrd')) AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501'; END IF;
  RETURN (
  SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
    jsonb_build_object('id', fs.id, 'nrp', fs.nrp, 'nama', e.nama,
      'sisa_cuti_paid', fs.sisa_cuti_paid, 'thr_prorata', fs.thr_prorata,
      'pesangon', fs.pesangon, 'total_settlement', fs.total_settlement, 'status', fs.status)
    ORDER BY fs.created_at DESC), '[]'::jsonb))
  FROM final_settlements fs
  LEFT JOIN employees_master e ON e.nrp = fs.nrp
  LIMIT 30);
END;
$function$;

-- admin_get_surveys oid=298143 md5=4b142aaf7c7d01cc2b861efc43b8eb0a
CREATE OR REPLACE FUNCTION public.admin_get_surveys()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path=public, extensions
AS $function$
BEGIN RETURN (
  SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
    jsonb_build_object('id', s.id, 'title', s.title, 'description', s.description,
      'survey_type', s.survey_type, 'status', s.status, 'target_audience', s.target_audience,
      'response_count', (SELECT COUNT(*) FROM survey_responses sr WHERE sr.survey_id = s.id),
      'avg_score', (SELECT ROUND(AVG(sr.score), 1) FROM survey_responses sr WHERE sr.survey_id = s.id),
      'created_at', s.created_at)
    ORDER BY s.created_at DESC), '[]'::jsonb))
  FROM hr_surveys s   -- ✅ FIXED: was 'surveys'
  LIMIT 30);
END;
$function$;

-- admin_get_webhook_logs oid=298147 md5=84171eb8aea6f07b7636b42a6a140b0a
CREATE OR REPLACE FUNCTION public.admin_get_webhook_logs()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path=public, extensions
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code = 'admin_pusat') AND NOT authz_is_owner() THEN
    RAISE EXCEPTION 'Akses ditolak. Hanya admin_pusat.' USING ERRCODE = '42501';
  END IF;
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('id', l.id, 'target_url', l.target_url, 'event', l.event_type, 'success', COALESCE(l.response_code BETWEEN 200 AND 299, FALSE), 'response_status', l.response_code, 'created_at', l.created_at)
      ORDER BY l.created_at DESC
    ), '[]'::jsonb))
    FROM webhook_logs l LIMIT 50
  );
END;
$function$;

-- admin_get_whistleblower oid=298149 md5=9da665237e6db423f49ea998be21176c
CREATE OR REPLACE FUNCTION public.admin_get_whistleblower()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path=public, extensions
AS $function$
BEGIN RETURN (
  SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
    jsonb_build_object('id', w.id, 'category', w.category, 'description', w.description,
      'status', w.status, 'investigator_nrp', w.investigator_nrp,
      'resolution_notes', w.resolution_notes, 'created_at', w.created_at)
    ORDER BY w.created_at DESC), '[]'::jsonb))
  FROM whistleblowers w
  LIMIT 30);
END;
$function$;

