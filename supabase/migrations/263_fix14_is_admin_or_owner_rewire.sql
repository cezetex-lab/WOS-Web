-- ============================================================================
-- 263 — Fix #14 §9 batch 1/5: rewiring is_admin_or_owner() (Work Queue P2-F14-N)
--
-- MASALAH 1 (P2-F14-N — whitelist gerbang tidak lengkap)
--   is_admin_or_owner() membaca role lewat user_roles dengan whitelist
--   literal 4 dari 7 admin role:
--       IN ('owner','admin_pusat','admin_hrd','admin_finance')
--   Yang HILANG: admin_operasional, admin_mining, admin_mill, admin_estate.
--   Keempatnya role_code aktif di role_codes (is_active = TRUE, probe
--   .agents/logs/fix14-c3g-semantik.log), punya role_page_access sendiri
--   (6-7 halaman can_access = TRUE), punya role_permission_sets khusus
--   (estate_ops / mill_ops / mining_ops / supervisor_ext, 7 item + worker_basic
--   14 item), dan TIDAK punya alasan bisnis untuk ditolak.
--
--   Bukti pre-263 (probe read-only, simulasi 17 employees_core):
--       NRP100 admin_pusat     lama=true   baru=true
--       NRP101 admin_hrd       lama=true   baru=true
--       NRP102 admin_finance   lama=true   baru=true
--       NRP103 admin_operasional lama=FALSE baru=TRUE   <-- berubah
--       NRP104 admin_mining    lama=FALSE  baru=TRUE   <-- berubah
--       NRP105 admin_mill      lama=FALSE  baru=TRUE   <-- berubah
--       NRP106 admin_estate    lama=FALSE  baru=TRUE   <-- berubah
--
-- MASALAH 2 (temuan BARU 2026-10-03, blocking — grant hilang sejak 172)
--   ACL live is_admin_or_owner() = {postgres, service_role} — TIDAK ada
--   authenticated. Policy RLS yang memanggil fungsi dievaluasi dengan hak akses
--   role PEMANGGIL, sehingga keenam policy itu tidak pernah bisa dievaluasi:
--
--       business_units.bu_update        [UPDATE]  is_admin_or_owner()
--       hr_kpi_config.hk_update         [UPDATE]  is_admin_or_owner()
--       hr_okrs.ok_select               [SELECT]  (nrp = <self>) OR is_admin_or_owner()
--       hr_succession_matrix.sc_select  [SELECT]  is_admin_or_owner()
--       offboarding_checklist.of_select [SELECT]  is_admin_or_owner()
--       settings.st_update              [UPDATE]  is_admin_or_owner()
--
--   Bukti pre-263 sebagai role=authenticated (probe .agents/logs/fix14-c3e-rls-pre-clean.log):
--       NRP001..NRP106 + NRP002  SELECT hr_okrs              = 42501
--       NRP001..NRP106 + NRP002  SELECT offboarding_checklist = 42501
--       NRP001..NRP106 + NRP002  SELECT hr_succession_matrix = 42501
--   Bandingkan tabel yang memakai authz_check_admin (aclauthenticated = TRUE):
--       NRP105 SELECT ai_rate_limits = OK:0
--       NRP105 SELECT api_keys        = OK:0
--       NRP105 SELECT api_rate_limits = OK:0
--
--   AKAR: migrasi 172_hardening_grants.sql me-REVOKE seluruh fungsi dari
--   PUBLIC/anon/authenticated, lalu grant balik hanya nama-nama di daftar
--   putih. is_admin_or_owner() TIDAK ada di daftar putih itu
--   (git grep is_admin_or_owner -- supabase/migrations/172_hardening_grants.sql
--   = 0 hit). Bandingkan authz_check_admin / authz_has_permission /
--   authz_current_nrp / authz_in_scope yang semuanya punya authenticated=X.
--
--   DAMPAK: saat ini ketiga tabel itu tidak bisa dibaca oleh SIAPAPUN yang
--   memakai JWT. Bukan hanya 4 admin role — semua user, termasuk worker.
--   UI kebetulan tidak membaca tabel itu langsung (git grep hr_okrs / offboarding_checklist
--   -- src = 0 hit untuk hr_okrs; Offboarding.tsx:95 memakai RPC
--   get_offboarding_checklist), jadi bug ini LATENT — bukan sampai user komplain.
--
-- KEPUTUSAN USER (2026-10-02/03)
--   - Pattern A: gate membaca user_role_assignments dengan pola admin_%.
--   - 5 batch (263-267); 263 = is_admin_or_owner SAJA.
--   - Owner bypass WAJIB tetap jalan.
--
-- PERBEDAAN BODY vs PRE-263 (selain blok yang memang diganti)
--   1. Blok pertama: user_roles + whitelist literal  ->  user_role_assignments
--      + pola admin\_%. Ini inti fix P2-F14-N.
--   2. Ditambah cabang authz_is_owner() di akhir.
--      Alasan: owner (system_owner_identity.auth_id = a8a77284-...) TIDAK punya
--      baris di employees_core (probe: owner_di_employees_core = 0), sehingga
--      TIDAK bisa dicocokkan lewat JOIN employees_master sama sekali. Cabang
--      kedua yang lama (user_roles.role = 'owner') juga MATI secara struktural
--      karena butuh employees_master yang tidak ada — user_roles.role='owner'
--      = 0 baris. Tanpa cabang ini owner berubah dari FALSE menjadi TRUE=false,
--      yaitu REGRESI dari perilaku 247 (owner GOD bypass).
--      authz_is_owner() dipakai, bukan EXISTS ditulis ulang, supaya tetap satu
--      sumber kebenaran (AGENTS.md G2) dan helper itu punya grant
--      authenticated.
--   3. Blok kedua (user_roles.role = 'owner') DIPERTAHANKAN apa adanya. Ia
--      vestigial saat ini, tapi tidak Salah dan Removing-nya di luar scope 263.
--
-- CATATAN PENTING SOAL POLA LIKE
--   Pola ditulis 'admin\_%' (underscore di-escape), bukan 'admin_%' polos.
--   Tanpa escape, %Replacement adalah wildcard satu karakter, sehingga role_code
--   seperti 'adminX' ikut cocok. Pada 13 baris role_codes live hasil keduanya
--   IDENTIK (probe: beda = 0), jadi ini tidak mengubah perilaku sekarang —
--   hanya menutup celah kalau role_codes nanti menambah kode liar.
--
-- GRANT
--   GRANT EXECUTE ... TO authenticatedWAJIB ada di berkas yang sama dengan
--   rewrite body. Kalau dipisah, policy RLS tetap 42501 dan fix P2-F14-N jadi
--   tidak teramati untuk 6 policy tersebut. Keamanan tidak melemah: fungsi
--   hanya mengembalikan boolean "apakah pemanggil admin/owner", tidak
--   mengembalikan data baris apa pun. Bandingkan authz_check_admin yang sudah
--   diberi authenticated dan dipakai 90 policy RLS.
--   TIDAK ada grant ke anon — fail-closed untuk JWT kosong.
--
-- P4: file ini TIDAK BOLEH punya BEGIN/COMMIT — wrapper apply-migration.mjs
-- yang memegang transaksi.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.is_admin_or_owner()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM user_role_assignments ura
    JOIN employees_master em ON em.nrp = ura.nrp
    WHERE em.auth_id = auth.uid()
    AND ura.role_code LIKE 'admin\_%'
  ) OR EXISTS (
    SELECT 1 FROM user_roles WHERE nrp = (
      SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1
    ) AND role = 'owner'
  ) OR authz_is_owner();
$function$;

-- Wajib: tanpa grant ini 6 policy RLS tetap 42501 untuk semua role
-- authenticated (lihat blok MASALAH 2 di header).
GRANT EXECUTE ON FUNCTION public.is_admin_or_owner() TO authenticated;