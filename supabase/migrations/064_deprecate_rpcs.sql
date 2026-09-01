-- ============================================================
-- Migration 064: Deprecate unused RPCs
-- ============================================================

-- These RPCs are duplicates or truly unused:
-- admin_get_pending -> use get_pending_approvals instead
-- admin_get_summary -> use get_dashboard_stats instead
-- get_org_health -> use get_organization_health instead
-- get_worker_critical -> use get_early_warning instead
-- get_review_360 -> use get_reviews_360 instead (fixed in 059)
-- check_access_ -> incomplete name, unused
-- tier_msg_ -> incomplete name, unused

-- Drop deprecated RPCs (safe: no frontend references)
DROP FUNCTION IF EXISTS admin_get_pending();
DROP FUNCTION IF EXISTS admin_get_summary();
DROP FUNCTION IF EXISTS get_org_health();
DROP FUNCTION IF EXISTS get_worker_critical();
DROP FUNCTION IF EXISTS get_review_360();
DROP FUNCTION IF EXISTS check_access_();
DROP FUNCTION IF EXISTS tier_msg_();

-- Summary:
-- 7 RPCs deprecated
-- 21 RPCs kept (auth/utility, called indirectly)
-- 39 RPCs flagged for wiring to existing pages (future work)
-- ~145 RPCs available for future feature development