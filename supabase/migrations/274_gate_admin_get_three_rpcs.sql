-- ============================================================================
-- 274 — Tahap 1 P1-F14-AA: gate admin_pusat untuk 3 RPC admin_get_* CONFIRMED
--        GAP (admin_get_audit_chain, admin_get_org_structure, admin_get_divisions)
--
-- KENAPA 274 INI ADA
--   Audit P1-F14-AA (commit 5b1551b): ketiga fungsi SECURITY DEFINER tanpa gate
--   apa pun; ACL memberi EXECUTE ke authenticated, sehingga worker NRP002 bisa
--   membaca datanya langsung via PostgREST. RED proof pra-274 (probe transaksi
--   ROLLBACK, nol perubahan persisten):
--     admin_get_audit_chain   -> ok:true + 593 baris audit_log (actor/action/detail)
--     admin_get_org_structure -> ok:true + 17 baris PII organisasi
--     admin_get_divisions     -> ok:true + 5 agregat divisi
--   Kontrak halaman ketiganya IDENTIK: useAdminAuth(["admin_pusat"])
--   (AuditChainPage, OrgChart, OrgSubtree, DivisionsManagement) — jadi satu gate.
--
-- POLA GATE — kondisi persis migrasi 269 X1 (keputusan user)
--   IF NOT EXISTS (SELECT 1 FROM user_role_assignments
--                  WHERE nrp = authz_current_nrp() AND role_code = 'admin_pusat')
--      AND NOT authz_is_owner() THEN ...
--   Catatan jujur: bentuk JOIN `ura.role_id ... user_roles` pada draft prompt
--   TIDAK dapat dipakai — kolom role_id TIDAK ADA di user_role_assignments
--   (live: id, nrp, role_code, scope_type, scope_bu_id, scope_org_unit,
--   scope_domain, is_primary, assigned_at, assigned_by). Kondisi dipakai persis
--   bentuk 269 (nrp + role_code langsung, tanpa helper).
--   MEKANISME PENOLAKAN: RAISE EXCEPTION ... USING ERRCODE = '42501'
--   (mengikuti kode eksplisit tugas Tahap 1 + spesifikasi GREEN proof
--   "worker = 42501"). 269 memakai RETURN jsonb {ok:false} — DEVIAISI mekanisme
--   disadari; kondisi gate identik dan output untuk yang BERHAK tidak berubah.
--
-- YANG SENGAJA TIDAK BERUBAH
--   - Body SQL asli per fungsi: kolom, JOIN, LIMIT, ORDER, return shape — gate
--     hanya disisipkan tepat setelah BEGIN.
--   - Signature (), attrs (plpgsql / VOLATILE / SECURITY DEFINER / SET search_path
--     TO 'public', 'extensions') dan oid (CREATE OR REPLACE mempertahankan).
--   - ACL: TIDAK disentuh (proacl pg,authenticated,service_role; anon=false) —
--     gate in-body satu-satunya perubahan; diverifikasi identik pra/pasca.
--   - Konsumen admin: output byte-shape identik (baseline NRP100 pre-274:
--     593 / 17 / 5 baris).
--
-- REFERENSI
--   Pola: supabase/migrations/269_fix14_admin_get_role_matrix_gate.sql (X1)
--   Audit: AGENTS.md §5.8 P1-F14-AA (DECIDED, Tahap 1)
--   Rollback: supabase/scripts/rollback/274_rollback.sql
--   Pre-image prosrc md5: audit_chain b94062fd53f623b4a8034d4bc0f2efc3 (257) ·
--   divisions d40ceb57595df6ace87d880d4f519915 (251) ·
--   org_structure d871b2171734057ed1227e534a8640a5 (354)
--
-- P4: file ini TIDAK punya baris BEGIN/COMMIT — wrapper apply-migration.mjs
-- yang memegang transaksi.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_get_audit_chain()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$ BEGIN IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code = 'admin_pusat') AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak. Hanya admin_pusat.' USING ERRCODE = '42501'; END IF; RETURN (
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
BEGIN IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code = 'admin_pusat') AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak. Hanya admin_pusat.' USING ERRCODE = '42501'; END IF; RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
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
BEGIN IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code = 'admin_pusat') AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak. Hanya admin_pusat.' USING ERRCODE = '42501'; END IF; RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(jsonb_build_object('divisi',divisi,'headcount',hc)),'[]'::jsonb))
FROM (SELECT divisi,COUNT(*) as hc FROM employees_master WHERE divisi IS NOT NULL GROUP BY divisi) t); END;
$function$
;
