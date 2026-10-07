-- ============================================================================
-- 268 — Fix #14 §9: rewiring admin_get_role_matrix() (batch penutup, item 9/10)
--
-- KENAPA 268 INI ADA
--   Item 9 rencana rewiring §9b: satu-satunya RPC baca admin yang belum mengenal
--   user_role_assignments (sumber kebenaran role admin sejak 261/262). Fungsi ini
--   TIDAK pernah membaca user_roles.role — ia mengembalikan nrp/nama/level/scope/
--   plan dari user_roles + employees_master, dan belum punya field role dari
--   assignment.
--
-- PERUBAHAN — 1 hunk (inverse proof di compose; md5 pre/post di expect.json)
--   jsonb_build_object per baris: tambah field 'role_code'
--     'role_code', COALESCE((SELECT a.role_code FROM user_role_assignments a
--        WHERE a.nrp = ur.nrp ORDER BY a.is_primary DESC NULLS LAST,
--        a.role_code ASC LIMIT 1), ur.role)
--   Pola hybrid 265/266/267: assignment menang; user_roles.role hanya jaring bila
--   assignment benar-benar absen (instalasi baru). Data live 17/17 user punya
--   assignment dengan role_code == user_roles.role (diff 2 arah = 0).
--
-- KEPUTUSAN D1 — scope_divisi DIPERTAHANKAN (deprecated), TIDAK diganti
--   §7 menetapkan scope = assignments (scope_type + scope_bu_id), tapi
--   scope_divisi masih dirender sebagai field 'scope' (NULL 17/17, semantik mati).
--   Menggantinya = mengubah NILAI field LAMA — di luar netralitas batch ini.
--   268 hanya MENAMBAH field BARU. Pemindahan scope + perbaikan RoleMatrixPage
--   (page membaca 'role_level'/'divisi' yang TIDAK ada di output) = sprint
--   terpisah, bukan 268.
--
-- YANG SENGAJA TIDAK BERUBAH
--   - Signature () + RETURNS jsonb + LANGUAGE plpgsql + VOLATILE + SECURITY
--     DEFINER + SET search_path — attrs preserved (dibuktikan FASE F).
--   - Field LAMA (nrp/nama/level/scope/plan): nilai + sumber sama (FASE G).
--   - ORDER BY ur.role_level DESC: tie-breaker (, ur.nrp) akan mengubah urutan
--     render page -> kandidat terpisah; TIDAK di 268.
--   - TIDAK menambah authz check internal. Fungsi ini bisa dipanggil authenticated
--     mana pun (worker NRP002 ikut) — temuan laporan batch 268, kandidat item
--     terpisah (perubahan kontrak authz butuh keputusan user, bukan 268).
--   - admin_set_employee_role TIDAK disentuh (pindah ke §11 — P2-F14-F).
--
-- GRANT (defensif, P10)
--   ACL live: authenticated + service_role, TANPA anon. REVOKE/GRANT idempoten
--   mengunci kontrak itu.
--
-- P4: file ini TIDAK BOLEH punya BEGIN/COMMIT — wrapper apply-migration.mjs yang
-- memegang transaksi. Rollback: supabase/scripts/rollback/268_rollback.sql
-- ============================================================================

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

-- ACL defensif (idempoten): kunci kontrak pre-268 (authenticated + service_role, tanpa anon).
REVOKE EXECUTE ON FUNCTION public.admin_get_role_matrix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_get_role_matrix() TO authenticated, service_role;
