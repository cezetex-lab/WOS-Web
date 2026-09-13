-- ================================================================
-- 214_f9_missing_rpcs.sql — F-9: RPC missing/kontrak
--
-- 1. update_audit_timestamp() — missing function referenced by 22 triggers
-- 2. get_organization_health() — missing RPC (dashboard health check)
-- 3. updated_at columns on HR tables (if missing)
-- ================================================================

-- 1. update_audit_timestamp — sets NEW.updated_at = NOW()
CREATE OR REPLACE FUNCTION update_audit_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    NEW.updated_at = NOW();
  END IF;
  RETURN NEW;
END;
$function$;

-- 2. get_organization_health — dashboard health check
CREATE OR REPLACE FUNCTION get_organization_health()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_total int;
  v_active int;
  v_pending_requests int;
  v_recent_logins int;
BEGIN
  SELECT count(*) INTO v_total FROM employees_core;
  SELECT count(*) INTO v_active FROM employees_core WHERE is_active = true;
  SELECT count(*) INTO v_pending_requests FROM hr_requests WHERE status ILIKE 'pending%';
  SELECT count(*) INTO v_recent_logins FROM login_attempts WHERE created_at > NOW() - INTERVAL '24 hours';

  RETURN jsonb_build_object(
    'ok', true,
    'total_employees', v_total,
    'active_employees', v_active,
    'pending_requests', v_pending_requests,
    'recent_logins_24h', v_recent_logins,
    'pg_cron_active', (SELECT count(*) > 0 FROM cron.job WHERE active = true),
    'checked_at', now()
  );
END;
$function$;

-- 3. Add updated_at columns where missing (idempotent)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='hr_payroll' AND column_name='updated_at') THEN
    ALTER TABLE hr_payroll ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='hr_performance' AND column_name='updated_at') THEN
    ALTER TABLE hr_performance ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='hr_tasks' AND column_name='updated_at') THEN
    ALTER TABLE hr_tasks ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='hr_leave' AND column_name='updated_at') THEN
    ALTER TABLE hr_leave ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='hr_overtime' AND column_name='updated_at') THEN
    ALTER TABLE hr_overtime ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='hr_requests' AND column_name='updated_at') THEN
    ALTER TABLE hr_requests ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
  END IF;
END $$;

-- 4. Verify
SELECT '214.1 update_audit_timestamp exists' AS test,
  CASE WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname='update_audit_timestamp')
  THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT '214.2 get_organization_health exists' AS test,
  CASE WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname='get_organization_health')
  THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT '214.3 health check' AS test, (get_organization_health()) AS result;
