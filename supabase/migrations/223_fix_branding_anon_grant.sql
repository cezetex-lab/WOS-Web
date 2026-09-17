-- ================================================================
-- Migration 223: Restore anon EXECUTE on get_branding()
-- Reason: branding is non-sensitive public info; 210 revoked it too
-- broadly, causing 401 on login page. get_branding_public (213)
-- exists but no frontend call site is switched yet; this fixes
-- the 401 immediately while keeping other revocations intact.
-- ================================================================
GRANT EXECUTE ON FUNCTION public.get_branding() TO anon, PUBLIC;

SELECT '223 get_branding grant restored to anon' AS result;
