-- ================================================================
-- 179_fix_payroll_groupby_and_smoke.sql
-- 1. Fix get_worker_payroll_secure: wrap in subquery to fix GROUP BY
-- 2. Remove \set psql syntax from 178
-- ================================================================

-- 1. Fix get_worker_payroll_secure (both branches: full + masked)
CREATE OR REPLACE FUNCTION public.get_worker_payroll_secure(p_nrp text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_caller TEXT;
  v_role TEXT;
BEGIN
  v_caller := COALESCE(
    current_setting('request.jwt.claims', true)::json->>'nrp', ''
  );

  SELECT role INTO v_role FROM user_roles WHERE nrp = v_caller LIMIT 1;

  IF v_caller = p_nrp OR v_role IN ('admin_pusat', 'admin_hrd', 'admin_finance', 'manager') THEN
    RETURN COALESCE((
      SELECT jsonb_build_object('ok', true, 'data', jsonb_agg(sub))
      FROM (
        SELECT jsonb_build_object(
          'periode', periode,
          'base_salary', base_salary,
          'allowance', allowance,
          'deduction', deduction,
          'overtime_pay', overtime_pay,
          'bonus', bonus,
          'net_salary', net_salary,
          'created_at', created_at
        ) AS sub
        FROM hr_payroll WHERE nrp = p_nrp
        ORDER BY created_at DESC
      ) sub
    ), jsonb_build_object('ok', true, 'data', '[]'::jsonb));
  ELSE
    RETURN COALESCE((
      SELECT jsonb_build_object('ok', true, 'data', jsonb_agg(sub))
      FROM (
        SELECT jsonb_build_object(
          'periode', periode,
          'base_salary', 0,
          'allowance', 0,
          'deduction', 0,
          'overtime_pay', 0,
          'bonus', 0,
          'net_salary', 0,
          'created_at', created_at
        ) AS sub
        FROM hr_payroll WHERE nrp = p_nrp
        ORDER BY created_at DESC
      ) sub
    ), jsonb_build_object('ok', true, 'data', '[]'::jsonb));
  END IF;
END;
$function$;

-- Verify
SELECT 'VERIFY: get_worker_payroll_secure callable' AS test,
  CASE WHEN get_worker_payroll_secure('NRP001') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
