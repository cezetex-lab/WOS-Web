-- 002.sql — 2026-09-09 — GRANT helper authz ke authenticated
-- Sebab: RLS policy memanggil helper ini dengan privilege CALLER.
-- Tanpa grant, authenticated selalu "permission denied" saat SELECT tabel ber-RLS.
-- Rollback: REVOKE EXECUTE ... FROM authenticated (4 statement di bawah).

GRANT EXECUTE ON FUNCTION public.authz_current_nrp() TO authenticated;
GRANT EXECUTE ON FUNCTION public.authz_check_admin(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.authz_in_scope(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.authz_has_permission(text) TO authenticated;

-- Blok verifikasi JWT-impersonasi (F-6) pindah ke 002_test_verification.sql

