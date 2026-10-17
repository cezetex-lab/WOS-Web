-- ============================================================================
-- ROLLBACK 279 — restore pre-image byte-exact 9 fungsi batch 2
-- (sumber: .agents/logs/m278-preimage.log. admin_get_payroll_summary kembali
--  ke LANGUAGE sql; 8 lainnya tetap plpgsql tanpa gate. P4: tanpa BEGIN/COMMIT.)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_get_payroll_summary(p_period text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
  SELECT jsonb_build_object(
    'total_employees', COUNT(*),
    'total_net', COALESCE(SUM(p.net_salary), 0),
    'avg_salary', COALESCE(AVG(p.net_salary), 0),
    'total_gross', COALESCE(SUM(p.base_salary + p.allowance + p.overtime_pay), 0),
    'total_deduction', COALESCE(SUM(p.deduction), 0),
    'total_deduction_items', COUNT(CASE WHEN p.deduction > 0 THEN 1 END)
  )
  FROM hr_payroll p
  WHERE (p_period IS NULL OR p.periode = p_period);
$function$;

CREATE OR REPLACE FUNCTION public.admin_get_okr()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (
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

CREATE OR REPLACE FUNCTION public.admin_get_badges()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (
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

CREATE OR REPLACE FUNCTION public.admin_get_asset_assignments()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (
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

CREATE OR REPLACE FUNCTION public.admin_get_vacancies()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
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

CREATE OR REPLACE FUNCTION public.admin_get_referrals()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (
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

CREATE OR REPLACE FUNCTION public.admin_get_exit_interviews()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (
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

CREATE OR REPLACE FUNCTION public.admin_get_settlements()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (
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

CREATE OR REPLACE FUNCTION public.get_succession(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('position',position,'candidate_nrp',candidate_nrp,'readiness',readiness)),'[]'::jsonb))
  FROM hr_succession WHERE candidate_nrp=p_nrp); END; $function$;