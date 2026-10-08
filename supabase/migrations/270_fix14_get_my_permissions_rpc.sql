-- ============================================================================
-- 270 — Fix #14 B2-FULL batch 270B (keputusan user H-a): RPC baru
--        get_my_permissions() untuk session.permissions (additive).
--
-- KENAPA 270B INI ADA
--   Audit P1-F14-AA (42 admin_get_*, 28 bocor) + 35 route guardless
--   membuktikan guard role-string di klien tidak punya dasar permission.
--   Desain 270A memutuskan sumber permission = RPC BARU (H-a) supaya
--   kontrak get_current_user_context TIDAK disentuh (G3 aman) dan 7 penulis
--   session tidak perlu diubah satu-satu — cukup initSession + setSession.
--
-- SIFAT — ADDITIVE MURNI
--   Fungsi BARU; tidak ada fungsi existing diubah (batch 263-269 tetap utuh).
--   TANPA BEGIN/COMMIT (P4) — wrapper apply-migration.mjs yang membungkus.
--
-- KONSISTEN DENGAN HELPER YANG SUDAH ADA (FASE B, live)
--   authz_has_permission(text) : plpgsql, STABLE, SECDEF, search_path
--     'public, extensions', grant authenticated+service_role, anon=false.
--     Join chain: user_role_assignments -> role_permission_sets ->
--     permission_set_items. 270B memakai rantai join PERSIS sama, hanya
--     hasilnya di-agg jadi text[] per pemanggil (bukan boolean per kode).
--   authz_current_nrp() : text, STABLE, SECDEF — sumber nrp pemanggil.
--   authz_is_owner()    : boolean, STABLE, SECDEF — owner bypass (pola 263).
--
-- RETURN text[] (bukan Set) — JSON-serializable ke sessionStorage.
--   Catatan: belum ada fungsi public yang return text[] (FASE B: 0 hasil;
--   hanya ekstensi vector) — tipe standar PostgreSQL, PostgREST mengembalikan
--   JSON array tanpa konversi khusus.
--
-- GRANT — fail-closed (pelajaran P10: whitelist grant yang melewatkan fungsi
--   kritis = mati senyap; di sini kebalikannya — REVOKE eksplisit supaya anon
--   TIDAK dapat akses walau default PUBLIC EXECUTE).
--
-- FALLBACK — user tanpa assignment / auth.uid() NULL -> ARRAY[]::text[]
--   (bukan error) — pemanggil lama yang tidak punya field permissions tidak
--   pernah gagal; guard klien memakai fallback allowedRoles (E2) selama 270C-E.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_my_permissions()
RETURNS text[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $function$
  -- Owner bypass: SEMUA permission aktif (pola authz_is_owner dari 263/269).
  SELECT CASE
    WHEN public.authz_is_owner() THEN
      (SELECT array_agg(DISTINCT permission_code ORDER BY permission_code)
       FROM permission_set_items)
    ELSE
      COALESCE(
        (SELECT array_agg(DISTINCT psi.permission_code
                              ORDER BY psi.permission_code)
         FROM user_role_assignments ura
         JOIN role_permission_sets rps
           ON rps.role_code = ura.role_code
         JOIN permission_set_items psi
           ON psi.permission_set = rps.permission_set
         WHERE ura.nrp = public.authz_current_nrp()),
        ARRAY[]::text[]
      )
  END;
$function$;

-- Grant: authenticated saja + service_role (anon fail-closed eksplisit).
REVOKE ALL ON FUNCTION public.get_my_permissions() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_my_permissions() FROM anon;
GRANT EXECUTE ON FUNCTION public.get_my_permissions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_permissions() TO service_role;
