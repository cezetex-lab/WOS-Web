-- ============================================================================
-- 233_reapply_226c_intended_revokes.sql
--
-- Melanjutkan kelas temuan yang sama dengan 232: migrasi 226 bagian C SUDAH menulis
-- niat "cabut anon/PUBLIC" untuk 10 fungsi, tetapi setiap nama dijaga
-- `to_regprocedure` — dan saat 226 berjalan di live sebagian fungsi itu BELUM ADA
-- (efek migrasi 199/201 tidak pernah sampai ke live). REVOKE-nya no-op, lalu
-- migrasi 231 membuat nama-namanya dengan default privilege Supabase sehingga anon
-- mendapat EXECUTE. Jadi niat 226 perlu DITERAPKAN ULANG, bukan ditulis ulang.
--
-- Dipisahkan dari 232 karena 232 sudah terdaftar di `schema_migrations` (checksum
-- terkunci — berkas yang diubah setelah diterapkan tidak boleh diedit diam-diam).
--
-- ── SATU nama dari daftar 226C sengaja TIDAK dicabut: `verify_admin_otp(text)` ──
-- Diverifikasi ke kode live 2026-09-19: `src/pages/Home.tsx:361` dan `:468` memanggil
-- `rpc('verify_admin_otp', { p_code })` SEBELUM ada sesi Supabase (verifikasi OTP admin
-- di halaman login). Artinya anon memang HARUS boleh memanggilnya; niat 226C untuk
-- mencabutnya keliru, dan grant eksplisit di 231-lah yang benar. Ini dicatat sebagai
-- "sudah diverifikasi BUKAN masalah" di `AGENTS.md` §5.8 supaya tidak diinvestigasi ulang.
--
-- `auth_testing_override_bypass(text,text)` sebaliknya TIDAK punya pemanggil di client:
-- hanya wrapper `verify_mfa`/`verify_worker_otp` (keduanya SECURITY DEFINER) yang
-- memanggilnya, jadi keduanya berjalan sebagai pemilik fungsi. Membiarkannya terbuka
-- membuat anon bisa menanyakan "apakah NRP ini sedang di-bypass MFA/OTP" —
-- kebocoran informasi kecil tapi nyata, dan tidak dibutuhkan pra-login.
--
-- Idempoten + aman untuk instalasi dari awal.
-- ============================================================================

DO $reapply$
DECLARE
  v_sigs text[] := ARRAY[
    -- harus dicabut dari anon/PUBLIC (tanpa pemanggil pra-sesi)
    'public.auth_testing_override_bypass(text,text)',
    'public.owner_get_testing_override(text)',
    'public.owner_set_testing_override(text,boolean,boolean)',
    'public.owner_delete_testing_override(text)',
    'public.admin_set_employee_role(text,text,text)',
    'public.verify_mfa_core(text,text)',
    'public.verify_worker_otp_core(text,text)',
    'public.get_estate_blocks()',
    'public.get_organization_health()'
  ];
  v_sig text;
  v_oid regprocedure;
BEGIN
  FOREACH v_sig IN ARRAY v_sigs LOOP
    v_oid := to_regprocedure(v_sig);
    IF v_oid IS NULL THEN
      RAISE NOTICE '233: % tidak ada — dilewati', v_sig;
      CONTINUE;
    END IF;
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM anon, PUBLIC', v_oid);
    RAISE NOTICE '233: REVOKE anon/PUBLIC pada %', v_sig;
  END LOOP;
END $reapply$;

-- ── Verifikasi 1: daftar di atas harus benar-benar bersih dari anon ───────────
SELECT t.sig AS harus_tanpa_anon,
       CASE
         WHEN to_regprocedure(t.sig) IS NULL THEN 'SKIP (tidak ada)'
         WHEN has_function_privilege('anon', to_regprocedure(t.sig), 'EXECUTE') THEN 'FAIL — masih anon'
         ELSE 'PASS — anon dicabut'
       END AS hasil
  FROM unnest(ARRAY[
    'public.auth_testing_override_bypass(text,text)',
    'public.verify_worker_otp_core(text,text)',
    'public.verify_mfa_core(text,text)',
    'public.owner_get_testing_override(text)',
    'public.admin_set_employee_role(text,text,text)'
  ]) AS t(sig);

-- ── Verifikasi 2: entry pra-login HARUS tetap bisa dipanggil anon ─────────────
-- (regresi di sini = login rusak; `verify_admin_otp` dipanggil Home.tsx pra-sesi)
SELECT t.sig AS entry_pra_login,
       CASE
         WHEN to_regprocedure(t.sig) IS NULL THEN 'SKIP (tidak ada)'
         WHEN has_function_privilege('anon', to_regprocedure(t.sig), 'EXECUTE') THEN 'PASS — anon tetap boleh'
         ELSE 'FAIL — anon hilang, login rusak'
       END AS hasil
  FROM unnest(ARRAY[
    'public.verify_admin_otp(text)',
    'public.verify_worker_otp(text,text)',
    'public.login_worker_by_email(text,text)',
    'public.generate_worker_otp(text,text,text)',
    'public.register_session(text,text,text)',
    'public.hit_rate_limit(text,text,integer,integer)',
    'public.submit_registration(text,text,text,text,text,text,text)',
    'public.get_branding()',
    'public.get_branding_public()',
    'public.get_enabled_modules(text)'
  ]) AS t(sig);
