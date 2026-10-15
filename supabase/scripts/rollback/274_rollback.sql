-- ============================================================================
-- 274_rollback.sql — batalkan migrasi 274 (Tahap 1 P1-F14-AA: gate admin_pusat
-- untuk admin_get_audit_chain, admin_get_org_structure, admin_get_divisions)
--
-- Dijalankan MANUAL via psql (file ini punya BEGIN/COMMIT sendiri — berbeda dari
-- file migrasi yang P4-nya forbid BEGIN/COMMIT):
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/scripts/rollback/274_rollback.sql
--
-- ISI ROLLBACK
--   Ketiga fungsi dikembalikan ke PRE-IMAGE byte-exact sebelum 274 (tanpa gate),
--   diambil dari live pre-274 (2026-10-15, md5 prosrc identik dengan inventaris
--   audit P1-F14-AA):
--     admin_get_audit_chain   md5(prosrc) = b94062fd53f623b4a8034d4bc0f2efc3  len 257
--     admin_get_divisions     md5(prosrc) = d40ceb57595df6ace87d880d4f519915  len 251
--     admin_get_org_structure md5(prosrc) = d871b2171734057ed1227e534a8640a5  len 354
--   md5(pg_get_functiondef) pre-274:
--     audit_chain 243770b46f10e9df480753cdf64dea86 (433)
--     divisions   737ba0eb587ebbff46a43597f10dd434 (425)
--     org_structure de7751ae89ef404f69087fc3d7217b2a (532)
--
-- CATATAN
--   - 274 TIDAK mengubah signature/attrs/oid (CREATE OR REPLACE) dan TIDAK
--     menyentuh ACL → rollback juga tidak perlu manipulasi GRANT/REVOKE.
--   - schema_migrations TIDAK disentuh oleh rollback ini (baris 274 tetap tercatat;
--     hapus manual hanya bila registry juga harus mundur — keputusan terpisah).
--   - Idempoten: jalan kedua kali tidak mengubah apa pun.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.admin_get_audit_chain()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'timestamp',timestamp,'actor',actor,'action',action,'detail',detail)
    ORDER BY timestamp DESC),'[]'::jsonb))
  FROM audit_log LIMIT 50); END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_get_org_structure()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',e.nrp,'nama',e.nama,'divisi',e.divisi,'posisi',e.posisi,'atasan',o.atasan_nrp,'level',COALESCE(ur.role_level,1)) ORDER BY e.nama),'[]'::jsonb))
FROM employees_master e LEFT JOIN hr_org o ON o.nrp=e.nrp LEFT JOIN user_roles ur ON ur.nrp=e.nrp); END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_get_divisions()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(jsonb_build_object('divisi',divisi,'headcount',hc)),'[]'::jsonb))
FROM (SELECT divisi,COUNT(*) as hc FROM employees_master WHERE divisi IS NOT NULL GROUP BY divisi) t); END;
$function$
;

COMMIT;
