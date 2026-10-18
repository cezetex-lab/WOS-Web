-- ============================================================================
-- 282 — Fix LIMIT no-op di 19 fungsi admin_get_* (P2-F14-AZ).
--
-- Temuan: audit P1-F14-AA §D menyebut "26 fungsi agregat"; verifikasi ulang
--   2026-10-18 (.agents/logs/m282-analyze.log + m282-19-prosrc.txt) membagi
--   26 admin_get_* yang memuat LIMIT menjadi:
--   * 19 NO-OP (diperbaiki migrasi ini) — pola
--       SELECT jsonb_build_object(..., COALESCE(jsonb_agg(...), '[]'::jsonb))
--       FROM tabel [JOIN ...] [WHERE ...] LIMIT n
--     LIMIT diterapkan pada HASIL agregat (1 baris) → tidak pernah membatasi;
--     admin_get_audit_chain terbukti runtime mengirim 614 baris audit_log
--     (RED proof .agents/logs/m282-red.log) padahal LIMIT 50.
--   * 7 SUDAH BENAR (bukan no-op, tidak disentuh):
--       kpi_trend / low_performers / top_performers / timesheet
--         = sudah pola FROM (SELECT ... LIMIT n) sub;
--       payroll / role_matrix / kpi_overview
--         = LIMIT pada scalar subquery (`role_code ... LIMIT 1`,
--           `periode ... LIMIT 1`) — memang benar.
--   Keputusan user 2026-10-18: scope HANYA 19 admin_get_*; 47 no-op non-admin
--   (worker-facing get_* dll) ditunda sebagai P3-F14-BV.
--
-- Fix: pindahkan LIMIT ke subquery FROM (SELECT kolom terpakai FROM sumber
--   [JOIN] [WHERE] [ORDER BY] LIMIT n) <alias lama> — alias dan expose kolom
--   dipilih supaya body LUAR (jsonb_build_object + gate authz + ORDER BY
--   jsonb_agg) tetap BYTE-IDENTIK dengan pre-image. Return shape, signature,
--   SECURITY DEFINER, VOLATILE, SET search_path, dan ACL TIDAK berubah
--   (CREATE OR REPLACE mempertahankan oid + ACL; 4 fungsi tanpa grant
--   authenticated — certifications/estate_blocks/headcount_plan/whistleblower
--   — tetap tanpa grant).
-- Scope-by-NRP admin_get_facility_requests (migrasi 280/281, fail-closed
--   `v_is_admin OR nrp = v_nrp`) DIPERTAHANKAN — WHERE ikut ke dalam subquery.
--
-- Pre-image byte-exact 19 fungsi: .agents/logs/m282-19-preimage.json
--   (oid, md5, prosrc live sebelum apply).
-- Rollback: supabase/scripts/rollback/282_rollback.sql (dibuat dari pre-image).
-- P4: tanpa BEGIN/COMMIT — wrapper apply-migration.mjs memegang transaksi.
-- ============================================================================

-- ─── 1. admin_get_asset_assignments — LIMIT 50 → subquery ──────────────────
CREATE OR REPLACE FUNCTION public.admin_get_asset_assignments()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$

BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code IN ('admin_pusat','admin_operasional')) AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501'; END IF;
  RETURN (
  SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
    jsonb_build_object('id', aa.id, 'asset_id', aa.asset_id, 'asset_name', aa.asset_name,
      'nrp', aa.nrp, 'nama', aa.nama, 'checkout_date', aa.checkout_date,
      'checkin_date', aa.checkin_date, 'condition_out', aa.condition_out, 'condition_in', aa.condition_in)
    ORDER BY aa.checkout_date DESC), '[]'::jsonb))
  FROM (
    SELECT aa.id, aa.asset_id, a.asset_name, aa.nrp, e.nama, aa.checkout_date,
           aa.checkin_date, aa.condition_out, aa.condition_in
    FROM asset_assignments aa
    LEFT JOIN assets a ON a.id = aa.asset_id
    LEFT JOIN employees_master e ON e.nrp = aa.nrp
    ORDER BY aa.checkout_date DESC
    LIMIT 50
  ) aa);
END;

$function$;

-- ─── 2. admin_get_assets — LIMIT 50 → subquery ─────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_get_assets()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$

BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code IN ('admin_pusat','admin_operasional')) AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501'; END IF;
  RETURN (
  SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
    jsonb_build_object('id', a.id, 'asset_name', a.asset_name, 'category', a.category,
      'serial_number', a.serial_number, 'location', a.location, 'status', a.status,
      'assigned_to', a.assigned_to, 'assigned_name', a.nama, 'purchase_date', a.purchase_date)
    ORDER BY a.created_at DESC), '[]'::jsonb))
  FROM (
    SELECT a.id, a.asset_name, a.category, a.serial_number, a.location, a.status,
           a.assigned_to, e.nama, a.purchase_date, a.created_at
    FROM assets a
    LEFT JOIN employees_master e ON e.nrp = a.assigned_to
    ORDER BY a.created_at DESC
    LIMIT 50
  ) a);
END;

$function$;

-- ─── 3. admin_get_audit_chain — LIMIT 50 → subquery (RED: 614 baris lolos) ─
CREATE OR REPLACE FUNCTION public.admin_get_audit_chain()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
 BEGIN IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code = 'admin_pusat') AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak. Hanya admin_pusat.' USING ERRCODE = '42501'; END IF; RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',sub.id,'timestamp',sub.timestamp,'actor',sub.actor,'action',sub.action,'detail',sub.detail)
    ORDER BY sub.timestamp DESC),'[]'::jsonb))
  FROM (
    SELECT id, timestamp, actor, action, detail
    FROM audit_log
    ORDER BY timestamp DESC
    LIMIT 50
  ) sub); END;

$function$;

-- ─── 4. admin_get_badges — LIMIT 50 → subquery ─────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_get_badges()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$

BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code IN ('admin_pusat','admin_hrd')) AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501'; END IF;
  RETURN (
  SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
    jsonb_build_object('id', b.id, 'nrp', b.nrp, 'nama', b.nama,
      'badge_name', b.badge_name, 'badge_type', b.badge_type,
      'points', b.points, 'awarded_date', b.awarded_date)
    ORDER BY b.awarded_date DESC), '[]'::jsonb))
  FROM (
    SELECT b.id, b.nrp, e.nama, b.badge_name, b.badge_type, b.points, b.awarded_date
    FROM badges b
    LEFT JOIN employees_master e ON e.nrp = b.nrp
    ORDER BY b.awarded_date DESC
    LIMIT 50
  ) b);
END;

$function$;

-- ─── 5. admin_get_budget — LIMIT 30 → subquery ─────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_get_budget()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
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
  FROM (
    SELECT ba.id, ba.divisi, ba.year, ba.gaji_budget, ba.training_budget,
           ba.operational_budget, ba.actual_gaji, ba.actual_training
    FROM budget_allocation ba
    ORDER BY ba.year DESC, ba.divisi
    LIMIT 30
  ) ba);
END;

$function$;

-- ─── 6. admin_get_certifications — LIMIT 50 → subquery (ACL: tanpa auth) ────
CREATE OR REPLACE FUNCTION public.admin_get_certifications()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$

BEGIN RETURN (
  SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
    jsonb_build_object('id', c.id, 'nrp', c.nrp, 'nama', c.nama,
      'cert_name', c.cert_name, 'issuer', c.issuer,
      'issue_date', c.issue_date, 'expiry_date', c.expiry_date, 'status', c.status)
    ORDER BY c.expiry_date), '[]'::jsonb))
  FROM (
    SELECT c.id, c.nrp, e.nama, c.cert_name, c.issuer, c.issue_date, c.expiry_date, c.status
    FROM certifications c
    LEFT JOIN employees_master e ON e.nrp = c.nrp
    ORDER BY c.expiry_date
    LIMIT 50
  ) c);
END;

$function$;

-- ─── 7. admin_get_estate_blocks — LIMIT 50 → subquery (ACL: tanpa auth) ─────
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

$function$;

-- ─── 8. admin_get_exit_interviews — LIMIT 30 → subquery ────────────────────
CREATE OR REPLACE FUNCTION public.admin_get_exit_interviews()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$

BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code IN ('admin_pusat','admin_hrd')) AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501'; END IF;
  RETURN (
  SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
    jsonb_build_object('id', ei.id, 'nrp', ei.nrp, 'nama', ei.nama,
      'satisfaction_score', ei.satisfaction_score, 'reason', ei.reason,
      'feedback', ei.feedback, 'created_at', ei.created_at)
    ORDER BY ei.created_at DESC), '[]'::jsonb))
  FROM (
    SELECT ei.id, ei.nrp, e.nama, ei.satisfaction_score, ei.reason, ei.feedback, ei.created_at
    FROM exit_interviews ei
    LEFT JOIN employees_master e ON e.nrp = ei.nrp
    ORDER BY ei.created_at DESC
    LIMIT 30
  ) ei);
END;

$function$;

-- ─── 9. admin_get_facility_requests — LIMIT 30 → subquery (scope 280/281 UTUH) ─
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
    jsonb_build_object('id',sub.id,'nrp',sub.nrp,'type',sub.type,'status',sub.status,'note',sub.note,'created_at',sub.created_at)
    ORDER BY sub.created_at DESC),'[]'::jsonb))
  FROM (
    SELECT id, nrp, type, status, note, created_at
    FROM hr_requests
    WHERE (type ILIKE '%facility%' OR type ILIKE '%aset%')
      AND (v_is_admin OR nrp = v_nrp)
    ORDER BY created_at DESC
    LIMIT 30
  ) sub); END;

$function$;

-- ─── 10. admin_get_headcount_plan — LIMIT 30 → subquery (ACL: tanpa auth) ───
CREATE OR REPLACE FUNCTION public.admin_get_headcount_plan()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$

BEGIN RETURN (
  SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
    jsonb_build_object('id', hp.id, 'divisi', hp.divisi, 'year', hp.year,
      'quarter', hp.quarter, 'planned_hc', hp.planned_hc, 'actual_hc', hp.actual_hc,
      'notes', hp.notes)
    ORDER BY hp.year DESC, hp.quarter), '[]'::jsonb))
  FROM (
    SELECT hp.id, hp.divisi, hp.year, hp.quarter, hp.planned_hc, hp.actual_hc, hp.notes
    FROM headcount_plans hp
    ORDER BY hp.year DESC, hp.quarter
    LIMIT 30
  ) hp);
END;

$function$;

-- ─── 11. admin_get_master_data — roles LIMIT 100 → subquery ────────────────
-- (divisions tanpa LIMIT — dibiarkan persis pre-image)
CREATE OR REPLACE FUNCTION public.admin_get_master_data()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$

BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code = 'admin_pusat') AND NOT authz_is_owner() THEN
    RAISE EXCEPTION 'Akses ditolak. Hanya admin_pusat.' USING ERRCODE = '42501';
  END IF;
  RETURN (
    SELECT jsonb_build_object('ok', true,
      'roles', (SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'nrp', ur.nrp, 'role', ur.role, 'tier', ur.role_level
      ) ORDER BY ur.role_level DESC, ur.nrp ASC), '[]'::jsonb)
      FROM (
        SELECT nrp, role, role_level
        FROM user_roles
        ORDER BY role_level DESC, nrp ASC
        LIMIT 100
      ) ur),
      'divisions', (SELECT COALESCE(jsonb_agg(DISTINCT jsonb_build_object(
        'divisi', md.division_name
      )), '[]'::jsonb) FROM master_divisions md WHERE md.division_name IS NOT NULL)
    )
  );
END;

$function$;

-- ─── 12. admin_get_okr — LIMIT 50 → subquery ───────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_get_okr()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$

BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code IN ('admin_pusat','admin_hrd')) AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501'; END IF;
  RETURN (
  SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
    jsonb_build_object('id', o.id, 'nrp', o.nrp, 'nama', o.nama,
      'objective', o.objective, 'key_result', o.key_result,
      'target_value', o.target_value, 'current_value', o.current_value,
      'status', o.status, 'periode', o.periode)
    ORDER BY o.periode DESC, o.nrp), '[]'::jsonb))
  FROM (
    SELECT o.id, o.nrp, e.nama, o.objective, o.key_result, o.target_value,
           o.current_value, o.status, o.periode
    FROM hr_okrs o   -- ✅ FIXED: was 'okrs'
    LEFT JOIN employees_master e ON e.nrp = o.nrp
    ORDER BY o.periode DESC, o.nrp
    LIMIT 50
  ) o);
END;

$function$;

-- ─── 13. admin_get_overtime — LIMIT 50 → subquery ──────────────────────────
CREATE OR REPLACE FUNCTION public.admin_get_overtime()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
 BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code IN ('admin_pusat','admin_finance','admin_operasional')) AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501'; END IF;
 RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',sub.id,'nrp',sub.nrp,'date',sub.date,'hours',sub.hours,'reason',sub.reason,'status',sub.status)
    ORDER BY sub.date DESC),'[]'::jsonb))
  FROM (
    SELECT id, nrp, date, hours, reason, status
    FROM hr_overtime
    ORDER BY date DESC
    LIMIT 50
  ) sub); END;

$function$;

-- ─── 14. admin_get_pending_requests — LIMIT 50 → subquery ──────────────────
CREATE OR REPLACE FUNCTION public.admin_get_pending_requests()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
 BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code IN ('admin_pusat','admin_hrd','admin_operasional')) AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501'; END IF;
 RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',r.id,'nrp',r.nrp,'nama',r.nama,'type',r.type,'status',r.status,'note',r.note,'created_at',r.created_at)
    ORDER BY r.created_at DESC),'[]'::jsonb))
  FROM (
    SELECT r.id, r.nrp, e.nama, r.type, r.status, r.note, r.created_at
    FROM hr_requests r LEFT JOIN employees_master e ON e.nrp=r.nrp WHERE r.status='Pending'
    ORDER BY r.created_at DESC
    LIMIT 50
  ) r); END;

$function$;

-- ─── 15. admin_get_referrals — LIMIT 30 → subquery ─────────────────────────
CREATE OR REPLACE FUNCTION public.admin_get_referrals()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$

BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code IN ('admin_pusat','admin_hrd')) AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501'; END IF;
  RETURN (
  SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
    jsonb_build_object('id', r.id, 'referrer_nrp', r.referrer_nrp, 'referrer_name', r.nama,
      'candidate_name', r.candidate_name, 'candidate_email', r.candidate_email,
      'position', r.position, 'status', r.status, 'bonus_paid', r.bonus_paid)
    ORDER BY r.created_at DESC), '[]'::jsonb))
  FROM (
    SELECT r.id, r.referrer_nrp, e.nama, r.candidate_name, r.candidate_email,
           r.position, r.status, r.bonus_paid, r.created_at
    FROM referrals r
    LEFT JOIN employees_master e ON e.nrp = r.referrer_nrp
    ORDER BY r.created_at DESC
    LIMIT 30
  ) r);
END;

$function$;

-- ─── 16. admin_get_settlements — LIMIT 30 → subquery ───────────────────────
CREATE OR REPLACE FUNCTION public.admin_get_settlements()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$

BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code IN ('admin_pusat','admin_hrd')) AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501'; END IF;
  RETURN (
  SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
    jsonb_build_object('id', fs.id, 'nrp', fs.nrp, 'nama', fs.nama,
      'sisa_cuti_paid', fs.sisa_cuti_paid, 'thr_prorata', fs.thr_prorata,
      'pesangon', fs.pesangon, 'total_settlement', fs.total_settlement, 'status', fs.status)
    ORDER BY fs.created_at DESC), '[]'::jsonb))
  FROM (
    SELECT fs.id, fs.nrp, e.nama, fs.sisa_cuti_paid, fs.thr_prorata, fs.pesangon,
           fs.total_settlement, fs.status, fs.created_at
    FROM final_settlements fs
    LEFT JOIN employees_master e ON e.nrp = fs.nrp
    ORDER BY fs.created_at DESC
    LIMIT 30
  ) fs);
END;

$function$;

-- ─── 17. admin_get_surveys — LIMIT 30 → subquery ───────────────────────────
-- (subquery skalar response_count/avg_score mereferensikan s.id — alias sub
--  dipertahankan 's' supaya referensi tetap resolve)
CREATE OR REPLACE FUNCTION public.admin_get_surveys()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$

BEGIN RETURN (
  SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
    jsonb_build_object('id', s.id, 'title', s.title, 'description', s.description,
      'survey_type', s.survey_type, 'status', s.status, 'target_audience', s.target_audience,
      'response_count', (SELECT COUNT(*) FROM survey_responses sr WHERE sr.survey_id = s.id),
      'avg_score', (SELECT ROUND(AVG(sr.score), 1) FROM survey_responses sr WHERE sr.survey_id = s.id),
      'created_at', s.created_at)
    ORDER BY s.created_at DESC), '[]'::jsonb))
  FROM (
    SELECT s.id, s.title, s.description, s.survey_type, s.status, s.target_audience, s.created_at
    FROM hr_surveys s   -- ✅ FIXED: was 'surveys'
    ORDER BY s.created_at DESC
    LIMIT 30
  ) s);
END;

$function$;

-- ─── 18. admin_get_webhook_logs — LIMIT 50 → subquery ──────────────────────
CREATE OR REPLACE FUNCTION public.admin_get_webhook_logs()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
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
    FROM (
      SELECT l.id, l.target_url, l.event_type, l.response_code, l.created_at
      FROM webhook_logs l
      ORDER BY l.created_at DESC
      LIMIT 50
    ) l
  );
END;

$function$;

-- ─── 19. admin_get_whistleblower — LIMIT 30 → subquery (ACL: tanpa auth) ────
CREATE OR REPLACE FUNCTION public.admin_get_whistleblower()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$

BEGIN RETURN (
  SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
    jsonb_build_object('id', w.id, 'category', w.category, 'description', w.description,
      'status', w.status, 'investigator_nrp', w.investigator_nrp,
      'resolution_notes', w.resolution_notes, 'created_at', w.created_at)
    ORDER BY w.created_at DESC), '[]'::jsonb))
  FROM (
    SELECT w.id, w.category, w.description, w.status, w.investigator_nrp,
           w.resolution_notes, w.created_at
    FROM whistleblowers w
    ORDER BY w.created_at DESC
    LIMIT 30
  ) w);
END;

$function$;
