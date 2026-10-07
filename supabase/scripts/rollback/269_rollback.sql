-- ============================================================================
-- 269_rollback.sql — batalkan migrasi 269 (Fix #14 §9 rapid follow-up:
-- authz gate admin_get_role_matrix, item P1-F14-X)
--
-- Dijalankan MANUAL via psql (file ini punya BEGIN/COMMIT sendiri — berbeda
-- dari file migrasi yang P4-nya forbid BEGIN/COMMIT).
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/scripts/rollback/269_rollback.sql
--
-- ISI ROLLBACK
--   1. Fungsi dikembalikan ke PRE-IMAGE byte-exact (pg_get_functiondef LIVE
--      sebelum 269; salinan: .agents/logs/fix14-269-preimage-def.sql)
--        md5(pg_get_functiondef) = 6760b06856318ef8989c857b14a19d40
--        md5(prosrc)             = 2a724d0fe31cbfbd7c44577610460e1d
--        length(def/prosrc)      = 660 / 484
--   2. ACL dikembalikan eksplisit ke pre-269 (defensif; CREATE OR REPLACE sudah
--      mempertahankan ACL, ini mengunci kontrak):
--        REVOKE ... FROM PUBLIC, anon; GRANT ... TO authenticated, service_role
--
-- CATATAN: 269 tidak mengubah signature/attrs/oid; schema_migrations tidak
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
  jsonb_build_object('nrp',ur.nrp,'nama',e.nama,'level',ur.role_level,'scope',ur.scope_divisi,'plan',COALESCE(ur.plan,'FREE'),'role_code',COALESCE((SELECT a.role_code FROM user_role_assignments a WHERE a.nrp = ur.nrp ORDER BY a.is_primary DESC NULLS LAST, a.role_code ASC LIMIT 1), ur.role)) ORDER BY ur.role_level DESC),'[]'::jsonb))
FROM user_roles ur LEFT JOIN employees_master e ON e.nrp=ur.nrp); END; $function$
;

-- ACL pre-269 (defensif, idempoten).
REVOKE EXECUTE ON FUNCTION public.admin_get_role_matrix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_get_role_matrix() TO authenticated, service_role;

COMMIT;
