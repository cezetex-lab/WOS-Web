-- ============================================================================
-- 279 — Gate in-body 9 RPC admin (BATCH 2 — split Opsi B, STOP #2 resolved):
--   P2-F14-AY sebagian + P2-F14-BN Fase 2 (get_succession = bucket A terakhir).
--
-- ISI 279 (9 fungsi): admin_get_payroll_summary, admin_get_okr,
--   admin_get_badges, admin_get_vacancies, admin_get_referrals,
--   admin_get_exit_interviews, admin_get_settlements, get_succession,
--   admin_get_asset_assignments.
--
-- KARANTINA (STOP #1 brief — sub-item P2-F14-BU, TIDAK digate di sini juga):
--   admin_get_facility_requests + get_shift_assignments. Alasan lengkap di
--   header 278_gate_8_admin_rpcs.sql.
--
-- Role target dual-mount ber-guard (Badges/Okrs/Referral punya route /worker/*
--   TAPI useAdminAuth [admin_pusat, admin_hrd] me-redirect worker saat mount →
--   gate DB hanya menambah lapis; perilaku worker TIDAK berubah):
--   okr, badges, vacancies, referrals, exit_interviews, settlements,
--   succession → admin_pusat, admin_hrd
--   payroll_summary (p_period text) → admin_pusat, admin_finance
--   asset_assignments → admin_pusat, admin_operasional
--
-- TEMUAN TEKNIS: admin_get_payroll_summary ber-LANGUAGE sql → KONVERSI ke
--   plpgsql (fungsi ke-5 dari 5 total; 4 lainnya di batch 278). Signature
--   (argumen p_period text DEFAULT NULL), SECURITY DEFINER, VOLATILE,
--   SET search_path, ACL, return SHAPE identik.
--
-- RED/GREEN: .agents/logs/m279-red.log → m279-green.log; pre-image byte-exact
--   di .agents/logs/m278-preimage.log; rollback: supabase/scripts/rollback/279_rollback.sql.
-- P4: tanpa BEGIN/COMMIT — wrapper apply-migration.mjs yang memegang transaksi.
-- ============================================================================

-- ─── 1. admin_get_payroll_summary — SQL→plpgsql, gate (pusat, finance) ─────
CREATE OR REPLACE FUNCTION public.admin_get_payroll_summary(p_period text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code IN ('admin_pusat','admin_finance')) AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501'; END IF;
  RETURN (
    SELECT jsonb_build_object(
      'total_employees', COUNT(*),
      'total_net', COALESCE(SUM(p.net_salary), 0),
      'avg_salary', COALESCE(AVG(p.net_salary), 0),
      'total_gross', COALESCE(SUM(p.base_salary + p.allowance + p.overtime_pay), 0),
      'total_deduction', COALESCE(SUM(p.deduction), 0),
      'total_deduction_items', COUNT(CASE WHEN p.deduction > 0 THEN 1 END)
    )
    FROM hr_payroll p
    WHERE (p_period IS NULL OR p.periode = p_period)
  );
END;
$function$;

-- ─── 2. admin_get_okr — gate (pusat, hrd) ──────────────────────────────────
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

-- ─── 3. admin_get_badges — gate (pusat, hrd) ───────────────────────────────
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
    jsonb_build_object('id', b.id, 'nrp', b.nrp, 'nama', e.nama,
      'badge_name', b.badge_name, 'badge_type', b.badge_type,
      'points', b.points, 'awarded_date', b.awarded_date)
    ORDER BY b.awarded_date DESC), '[]'::jsonb))
  FROM badges b
  LEFT JOIN employees_master e ON e.nrp = b.nrp
  LIMIT 50);
END;
$function$;

-- ─── 4. admin_get_asset_assignments — gate (pusat, operasional) ─────────────
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

-- ─── 5. admin_get_vacancies — gate (pusat, hrd) ────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_get_vacancies()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code IN ('admin_pusat','admin_hrd')) AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501'; END IF;
  RETURN (
    SELECT jsonb_build_object(
      'ok', true,
      'data', COALESCE(
        jsonb_agg(
          jsonb_build_object(
            'id', id,
            'position', position,
            'department', department,
            'quota', quota,
            'qualifications', qualifications,
            'status', status
          ) ORDER BY created_at DESC
        ),
        '[]'::jsonb
      )
    )
    FROM vacancies
  );
END;
$function$;

-- ─── 6. admin_get_referrals — gate (pusat, hrd) ────────────────────────────
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
    jsonb_build_object('id', r.id, 'referrer_nrp', r.referrer_nrp, 'referrer_name', e.nama,
      'candidate_name', r.candidate_name, 'candidate_email', r.candidate_email,
      'position', r.position, 'status', r.status, 'bonus_paid', r.bonus_paid)
    ORDER BY r.created_at DESC), '[]'::jsonb))
  FROM referrals r
  LEFT JOIN employees_master e ON e.nrp = r.referrer_nrp
  LIMIT 30);
END;
$function$;

-- ─── 7. admin_get_exit_interviews — gate (pusat, hrd) ──────────────────────
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
    jsonb_build_object('id', ei.id, 'nrp', ei.nrp, 'nama', e.nama,
      'satisfaction_score', ei.satisfaction_score, 'reason', ei.reason,
      'feedback', ei.feedback, 'created_at', ei.created_at)
    ORDER BY ei.created_at DESC), '[]'::jsonb))
  FROM exit_interviews ei
  LEFT JOIN employees_master e ON e.nrp = ei.nrp
  LIMIT 30);
END;
$function$;

-- ─── 8. admin_get_settlements — gate (pusat, hrd) ──────────────────────────
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
    jsonb_build_object('id', fs.id, 'nrp', fs.nrp, 'nama', e.nama,
      'sisa_cuti_paid', fs.sisa_cuti_paid, 'thr_prorata', fs.thr_prorata,
      'pesangon', fs.pesangon, 'total_settlement', fs.total_settlement, 'status', fs.status)
    ORDER BY fs.created_at DESC), '[]'::jsonb))
  FROM final_settlements fs
  LEFT JOIN employees_master e ON e.nrp = fs.nrp
  LIMIT 30);
END;
$function$;

-- ─── 9. get_succession — bucket A (BN Fase 2), gate (pusat, hrd) ───────────
CREATE OR REPLACE FUNCTION public.get_succession(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code IN ('admin_pusat','admin_hrd')) AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501'; END IF;
 RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('position',position,'candidate_nrp',candidate_nrp,'readiness',readiness)),'[]'::jsonb))
  FROM hr_succession WHERE candidate_nrp=p_nrp); END; $function$;