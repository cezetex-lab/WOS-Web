-- 189: Backfill business_unit_id for admin accounts
--
-- ROOT CAUSE (found in dynamic-route audit, 08 Sep 2026):
-- employees_master rows for admin accounts (NRP100-NRP106) have
-- business_unit_id = NULL while the business_unit text column IS populated
-- ('HQ', 'MINING', ...). get_current_user_context() therefore returns no
-- business_unit_id for admins → get_enabled_modules() falls back to
-- v_bu_tier = 0 → every module with minimum_tier_required >= 2
-- (e.g. audit_log at /admin/audit) is filtered out of the RPC result and
-- DynamicRoutes bounces those paths back to /admin.
--
-- Fix: resolve business_unit_id from business_units.unit_code.

UPDATE public.employees_core ec
SET business_unit_id = bu.id
FROM public.business_units bu
WHERE ec.business_unit_id IS NULL
  AND bu.unit_code = ec.business_unit;

-- Sanity: report any rows still unresolved (should be none if all
-- business_unit values match a unit_code).
DO $$
DECLARE v_left INT;
BEGIN
  SELECT count(*) INTO v_left FROM public.employees_core
  WHERE business_unit_id IS NULL AND business_unit IS NOT NULL;
  IF v_left > 0 THEN
    RAISE NOTICE 'business_unit_id still NULL for % rows (unmatched business_unit text)', v_left;
  END IF;
END $$;
