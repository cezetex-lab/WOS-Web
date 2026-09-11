-- 190: Fix admin_get_payroll signature mismatch
--
-- Frontend (Payroll.jsx, Analytics.jsx) calls admin_get_payroll(p_period).
-- Live DB only had admin_get_payroll(p_nrp) — a stub returning
-- {ok:true, msg:'RPC executed with role check.'} with no data — so PostgREST
-- reported "Could not find the function public.admin_get_payroll(p_period)".
--
-- Fix: replace with a real implementation matching admin_get_payroll_secure
-- semantics (hr_payroll table, role-gated), parameterized by p_period.

DROP FUNCTION IF EXISTS public.admin_get_payroll(text);

CREATE OR REPLACE FUNCTION public.admin_get_payroll(p_period text DEFAULT NULL::text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_role TEXT;
BEGIN
  -- Role via authz helpers (JWT role claim is absent for worker-token logins);
  -- mirrors authz_has_role's owner bypass + user_role_assignments lookup.
  IF EXISTS (SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = TRUE) THEN
    v_role := 'admin_pusat';
  ELSE
    SELECT ura.role_code INTO v_role
    FROM user_role_assignments ura
    WHERE ura.nrp = authz_current_nrp()
      AND ura.role_code IN ('admin_pusat', 'admin_hrd', 'admin_finance')
    LIMIT 1;
  END IF;
  IF v_role IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak');
  END IF;
  RETURN COALESCE(
    (SELECT jsonb_build_object('ok', true, 'data', jsonb_agg(
      jsonb_build_object(
        'nrp', t.nrp, 'periode', t.periode, 'base_salary', t.base_salary,
        'allowance', t.allowance, 'deduction', t.deduction,
        'overtime_pay', t.overtime_pay, 'net_salary', t.net_salary,
        'gross_salary', t.gross_salary, 'pph21_ter', t.pph21_ter,
        'thr_amount', t.thr_amount, 'created_at', t.created_at
      ) ORDER BY t.periode DESC, t.nrp))
    FROM hr_payroll t
    WHERE p_period IS NULL OR t.periode = p_period),
    jsonb_build_object('ok', true, 'data', '[]'::jsonb)
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.admin_get_payroll(text) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
