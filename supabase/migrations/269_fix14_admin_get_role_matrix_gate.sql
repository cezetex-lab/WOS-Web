-- ============================================================================
-- 269 — Fix #14 §9 rapid follow-up: TUTUP P1-F14-X (admin_get_role_matrix
--        tanpa authz gate internal — worker bisa baca 17 baris role semua user)
--
-- KENAPA 269 INI ADA
--   Setelah 268, admin_get_role_matrix() mengembalikan 17 baris (nrp + nama +
--   level + scope + plan + role_code SEMUA user) ke setiap caller
--   terautentikasi — termasuk worker. UI RoleMatrixPage di-guard
--   useAdminAuth(["admin_pusat"]), tapi RPC dipanggil langsung via PostgREST
--   sehingga guard UI bisa dilewati. Baseline pre-269 (FASE D, bukti kebocoran):
--   NRP002 (worker) -> 17 baris, md5 byte-identik dengan output admin
--   (b4a6c150cf39441546f879c92f787483, len 1727); UUID nol pun dapat 17 baris.
--
-- KEPUTUSAN USER X1 — gate = admin_pusat SAJA (+ owner bypass)
--   Pola diambil dari codebase (FASE C), bukan pola baru:
--   - admin_get_payroll: EXISTS user_role_assignments role_code + owner bypass;
--   - admin_pusat_manage_admin (§4.21): cek literal 'admin_pusat' + owner bypass.
--   authz_check_admin TIDAK dipakai untuk gate ini: permission semantik
--   terdekat employee.view_all dimiliki [admin_pusat, admin_hrd] (C7) -> admin_hrd
--   ikut lolos = MELANGGAR X1 (dan akan membocorkan lewat jalur yang sama).
--   Bila HRD nanti perlu akses: tambahkan role_code di gate (edit 1 baris).
--
-- PERUBAHAN — 1 hunk (inverse proof: hunk dibalik === pre-image persis)
--   Gate di awal blok BEGIN, sebelum RETURN utama:
--     IF NOT EXISTS (SELECT 1 FROM user_role_assignments
--                    WHERE nrp = authz_current_nrp() AND role_code = 'admin_pusat')
--        AND NOT authz_is_owner() THEN
--       RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak. Hanya admin_pusat.');
--     END IF;
--
-- YANG SENGAJA TIDAK BERUBAH
--   - Signature () / RETURNS jsonb / LANGUAGE plpgsql / VOLATILE / SECURITY
--     DEFINER / SET search_path / oid: attrs preserved (FASE F).
--   - Output shape untuk yang BERHAK: byte-identik baseline pre-269
--     (FASE G netralitas — NRP100 & owner tetap md5 b4a6c150...).
--   - ORDER BY ur.role_level DESC: tie-breaker = P3-F14-Z (terpisah).
--   - Kontrak page RoleMatrixPage ('role_level'/'divisi') = P2-F14-Y (terpisah).
--   - admin_set_employee_role TIDAK disentuh (pindah §11 — P2-F14-F).
--
-- GRANT (defensif, P10): kunci ACL pre-269 (authenticated + service_role,
-- TANPA anon).
--
-- P4: file ini TIDAK BOLEH punya baris BEGIN/COMMIT — wrapper
-- apply-migration.mjs yang memegang transaksi. Rollback:
-- supabase/scripts/rollback/269_rollback.sql
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_get_role_matrix()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code = 'admin_pusat') AND NOT authz_is_owner() THEN RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak. Hanya admin_pusat.'); END IF; RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',ur.nrp,'nama',e.nama,'level',ur.role_level,'scope',ur.scope_divisi,'plan',COALESCE(ur.plan,'FREE'),'role_code',COALESCE((SELECT a.role_code FROM user_role_assignments a WHERE a.nrp = ur.nrp ORDER BY a.is_primary DESC NULLS LAST, a.role_code ASC LIMIT 1), ur.role)) ORDER BY ur.role_level DESC),'[]'::jsonb))
FROM user_roles ur LEFT JOIN employees_master e ON e.nrp=ur.nrp); END; $function$
;

-- ACL defensif (idempoten): kunci kontrak pre-269 (authenticated + service_role, tanpa anon).
REVOKE EXECUTE ON FUNCTION public.admin_get_role_matrix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_get_role_matrix() TO authenticated, service_role;
