-- ================================================================
-- 177_fix_preexisting_bugs.sql — Fix bugs found in smoke test
--
-- 1. clock_in: ON CONFLICT (nrp,work_date) needs unique constraint
-- 2. get_timesheets: GROUP BY bug — work_date in jsonb_agg without GROUP BY
-- 3. get_whistleblowers: GROUP BY bug — created_at in jsonb_agg without GROUP BY
-- ================================================================

-- 1. Add unique constraint on timesheets (nrp, work_date)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'timesheets_nrp_work_date_key'
      AND conrelid = 'timesheets'::regclass
  ) THEN
    ALTER TABLE timesheets ADD CONSTRAINT timesheets_nrp_work_date_key UNIQUE (nrp, work_date);
  END IF;
END $$;

-- 2. Fix get_timesheets: wrap in subquery to avoid GROUP BY issue
CREATE OR REPLACE FUNCTION public.get_timesheets(p_nrp text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN (SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(sub), '[]'::jsonb))
  FROM (
    SELECT jsonb_build_object(
      'work_date', t.work_date,
      'clock_in', t.clock_in,
      'clock_out', t.clock_out,
      'total_hours', t.total_hours
    ) AS sub
    FROM timesheets t
    WHERE t.nrp = p_nrp
    ORDER BY t.work_date DESC
    LIMIT 14
  ) sub);
END;
$function$;

-- 3. Fix get_whistleblowers: wrap in subquery to avoid GROUP BY issue
CREATE OR REPLACE FUNCTION public.get_whistleblowers()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN (SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(sub), '[]'::jsonb))
  FROM (
    SELECT jsonb_build_object(
      'id', w.id,
      'category', w.category,
      'status', w.status,
      'created_at', w.created_at
    ) AS sub
    FROM whistleblowers w
    ORDER BY w.created_at DESC
  ) sub);
END;
$function$;

-- Verify
SELECT 'VERIFY: timesheets constraint' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_constraint WHERE conname='timesheets_nrp_work_date_key') THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'VERIFY: get_timesheets callable' AS test,
  CASE WHEN get_timesheets('TEST') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'VERIFY: get_whistleblowers callable' AS test,
  CASE WHEN get_whistleblowers() IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
