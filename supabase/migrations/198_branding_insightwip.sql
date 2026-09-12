-- ============================================================
-- 198_branding_insightwip.sql — Default company branding → insightWIP
-- ============================================================
-- Branding is OWNER-configurable (update_branding RPC, Owner Config UI).
-- This migration only changes the DEFAULT/seed value so that new/current
-- deployments show "insightWIP" instead of "insightWOS". It does NOT
-- remove Owner ability to change name/logo later via update_branding.
-- Applies to the "main" row in the `branding` table (migration 089).
-- ============================================================

-- Update default company name (idempotent — safe to re-run).
-- Only touches company_name so it's safe against any column-name drift.
UPDATE branding
   SET company_name = 'insightWIP'
 WHERE id = 'main';

-- Guard: ensure the 'main' row exists even if a fresh DB never seeded it.
INSERT INTO branding (id, company_name)
VALUES ('main', 'insightWIP')
ON CONFLICT (id) DO NOTHING;

-- Sanity probe: return the resulting row (no-op for app, visible in apply log).
SELECT id, company_name, logo_url, primary_color
  FROM branding WHERE id = 'main';