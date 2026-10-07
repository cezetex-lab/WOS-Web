-- ============================================================================
-- 268_rollback.sql — batalkan migrasi 268 (Fix #14 §9: rewiring
-- admin_get_role_matrix)
--
-- Dijalankan MANUAL via psql (file ini punya BEGIN/COMMIT sendiri — berbeda dari
-- file migrasi yang P4-nya forbid BEGIN/COMMIT).
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/scripts/rollback/268_rollback.sql
--
-- ISI ROLLBACK
--   1. Fungsi dikembalikan ke PRE-IMAGE byte-exact (pg_get_functiondef LIVE
--      sebelum 268; salinan: .agents/logs/fix14-268-preimage-admin_get_role_matrix.sql)
--        md5(pg_get_functiondef) = 2693bca841a7c4e34171fb5f5d27344d
--        md5(prosrc)             = e5db8c011fd6237819e6d0642ff8d76c
--        length(def/prosrc)      = 495 / 319
--   2. ACL dikembalikan eksplisit ke pre-268 (defensif; CREATE OR REPLACE sudah
--      mempertahankan ACL, ini mengunci kontrak):
--        REVOKE ... FROM PUBLIC, anon; GRANT ... TO authenticated, service_role
--
-- CATATAN: 268 tidak mengubah signature/attrs/oid; schema_migrations tidak
-- disentuh. Idempoten (jalan kedua kali tidak mengubah apa pun).
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.admin_get_role_matrix()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',ur.nrp,'nama',e.nama,'level',ur.role_level,'scope',ur.scope_divisi,'plan',COALESCE(ur.plan,'FREE')) ORDER BY ur.role_level DESC),'[]'::jsonb))
FROM user_roles ur LEFT JOIN employees_master e ON e.nrp=ur.nrp); END; $function$
;

-- ACL pre-268 (defensif, idempoten).
REVOKE EXECUTE ON FUNCTION public.admin_get_role_matrix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_get_role_matrix() TO authenticated, service_role;

COMMIT;
