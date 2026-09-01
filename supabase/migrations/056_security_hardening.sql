-- ============================================================
-- 056_security_hardening.sql — Phase 3 Security Hardening
-- ============================================================

-- 3.1: Salary Masking RPCs
-- Worker sees own salary (self-view = OK)
-- Admin/HR sees all (with role check)
-- Other roles get masked data

CREATE OR REPLACE FUNCTION get_worker_payroll_secure(
  p_nrp TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_caller TEXT;
  v_role TEXT;
BEGIN
  -- Get caller NRP from JWT or session
  v_caller := COALESCE(
    current_setting('request.jwt.claims', true)::json->>'nrp',
    ''
  );
  
  -- Get caller role
  SELECT role INTO v_role FROM user_roles WHERE nrp = v_caller LIMIT 1;
  
  -- Self-view: show full salary
  IF v_caller = p_nrp OR v_role IN ('admin_pusat', 'admin_hrd', 'admin_finance', 'manager') THEN
    RETURN COALESCE((
      SELECT jsonb_build_object('ok', true, 'data', jsonb_agg(
        jsonb_build_object(
          'periode', periode,
          'base_salary', base_salary,
          'allowance', allowance,
          'deduction', deduction,
          'overtime_pay', overtime_pay,
          'bonus', bonus,
          'net_salary', net_salary,
          'created_at', created_at
        )
      ))
      FROM hr_payroll WHERE nrp = p_nrp
      ORDER BY created_at DESC
    ), jsonb_build_object('ok', true, 'data', '[]'::jsonb));
  ELSE
    -- Masked view for unauthorized users
    RETURN COALESCE((
      SELECT jsonb_build_object('ok', true, 'data', jsonb_agg(
        jsonb_build_object(
          'periode', periode,
          'base_salary', 0,
          'allowance', 0,
          'deduction', 0,
          'overtime_pay', 0,
          'bonus', 0,
          'net_salary', 0,
          'created_at', created_at
        )
      ))
      FROM hr_payroll WHERE nrp = p_nrp
      ORDER BY created_at DESC
    ), jsonb_build_object('ok', true, 'data', '[]'::jsonb));
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3.1b: Admin payroll with role check
CREATE OR REPLACE FUNCTION admin_get_payroll_secure(
  p_period TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_role TEXT;
BEGIN
  v_role := COALESCE(
    current_setting('request.jwt.claims', true)::json->>'role',
    ''
  );
  
  -- Only admin_pusat, admin_hrd, admin_finance can see full payroll
  IF v_role NOT IN ('admin_pusat', 'admin_hrd', 'admin_finance') THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak');
  END IF;
  
  RETURN COALESCE((
    SELECT jsonb_build_object('ok', true, 'data', jsonb_agg(
      jsonb_build_object(
        'nrp', nrp,
        'periode', periode,
        'base_salary', base_salary,
        'allowance', allowance,
        'deduction', deduction,
        'overtime_pay', overtime_pay,
        'bonus', bonus,
        'net_salary', net_salary,
        'created_at', created_at
      )
    ))
    FROM hr_payroll
    WHERE p_period IS NULL OR periode = p_period
    ORDER BY created_at DESC
  ), jsonb_build_object('ok', true, 'data', '[]'::jsonb));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3.2: Whistleblower — already anonymous, add description masking for extra safety
-- submit_whistleblower already does NOT store NRP — confirmed safe

-- 3.3: Edge function auth check helper
CREATE OR REPLACE FUNCTION check_admin_access()
RETURNS BOOLEAN AS $$
DECLARE
  v_role TEXT;
BEGIN
  v_role := COALESCE(
    current_setting('request.jwt.claims', true)::json->>'role',
    ''
  );
  RETURN v_role IN ('admin_pusat', 'admin_hrd', 'admin_finance', 'manager');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Log completion
DO $$ BEGIN
  RAISE NOTICE 'Security hardening: salary masking RPCs + admin access check created';
END $$;
