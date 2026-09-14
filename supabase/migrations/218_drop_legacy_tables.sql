-- 218: Drop legacy/unused tables from I1 forensic audit
-- Tables: mill_boiler (0 rows, unused), mfa_store (0 rows, replaced by mfa_factors),
--          hr_preview_data (0 rows, recreated but never populated).
-- All verified empty and not referenced in frontend code.

-- 1. mill_boiler — created in migration 052, never populated, no frontend references
DROP TABLE IF EXISTS public.mill_boiler CASCADE;

-- 2. mfa_store — legacy MFA storage, replaced by mfa_factors (migration 057)
DROP TABLE IF EXISTS public.mfa_store CASCADE;

-- 3. hr_preview_data — created in 001, recreated in 162, always empty
DROP TABLE IF EXISTS public.hr_preview_data CASCADE;

NOTIFY pgrst, 'reload schema';
