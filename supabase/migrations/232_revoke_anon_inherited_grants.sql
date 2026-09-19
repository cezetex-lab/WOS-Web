-- ============================================================================
-- 232_revoke_anon_inherited_grants.sql
--
-- Menutup grant anon yang muncul kembali saat migrasi 231 "apply missing effects"
-- diterapkan ke DB live (2026-09-19). Ditemukan oleh penjaga
-- `tests/unit/db-security-and-partition-guard.test.ts` yang gagal pada
-- `verify_worker_otp_core`.
--
-- AKAR MASALAH (diverifikasi ke DB live, bukan dugaan):
--
-- 1. `verify_worker_otp_core(text,text)` — SECURITY DEFINER, MENULIS
--    (UPDATE otp_attempts / otp_store, INSERT session_tokens, INSERT audit_log).
--    Migrasi 226 SUDAH mencantumkan fungsi ini di daftar REVOKE-nya, tetapi saat 226
--    berjalan di live nama `_core` belum ada (rename dari 201 belum berefek — kelas
--    "tercatat di schema_migrations tapi efeknya tidak ada"), sehingga REVOKE-nya
--    no-op. Migrasi 231 lalu menjalankan
--    `ALTER FUNCTION verify_worker_otp → verify_worker_otp_core`, dan **RENAME
--    MEMBAWA ACL** — jadi grant `anon` milik wrapper pra-login ikut menempel ke
--    implementasi intinya. Akibatnya anon bisa memanggil verifier inti langsung dan
--    mencetak `session_tokens` tanpa lewat wrapper.
--
-- 2. `verify_mfa_core` / `verify_admin_otp_core` lahir dari RENAME yang sama, jadi
--    keduanya juga mewarisi ACL pendahulunya. Hanya *wrapper* jsonb yang boleh
--    dipanggil pra-login.
--
-- 3. `admin_get_payroll(text)` — grant `anon`-nya sudah pernah dilaporkan sebagai bug
--    (migrasi 190/215) dan dikembalikan lagi oleh 231.
--
-- Yang DIPERTAHANKAN untuk anon (memang alur pra-login): `login_worker`,
-- `login_worker_by_email`, `generate_worker_otp`, `verify_worker_otp`,
-- `verify_admin_otp`, `register_session`, `submit_registration`, `hit_rate_limit`.
-- Daftar itu identik dengan PRE_AUTH_WHITELIST di penjaga DB.
--
-- Idempoten + aman untuk instalasi dari awal: setiap nama dijaga `to_regprocedure`.
-- ============================================================================

DO $revoke$
DECLARE
  target text;
  targets text[] := ARRAY[
    'public.verify_worker_otp_core(text,text)',
    'public.verify_mfa_core(text,text)',
    'public.verify_admin_otp_core(text)',
    'public.admin_get_payroll(text)'
  ];
BEGIN
  FOREACH target IN ARRAY targets LOOP
    IF to_regprocedure(target) IS NULL THEN
      RAISE NOTICE '232: dilewati (fungsi tidak ada): %', target;
      CONTINUE;
    END IF;
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon', target);
    RAISE NOTICE '232: REVOKE anon/PUBLIC pada %', target;
  END LOOP;
END $revoke$;

-- ── Verifikasi (dijalankan sebagai statement terakhir; hasil dibaca saat apply) ──
SELECT t.sig AS fungsi,
       CASE
         WHEN to_regprocedure(t.sig) IS NULL THEN 'SKIP (tidak ada)'
         WHEN has_function_privilege('anon', to_regprocedure(t.sig), 'EXECUTE') THEN 'FAIL — masih anon'
         ELSE 'PASS — anon dicabut'
       END AS hasil
  FROM unnest(ARRAY[
    'public.verify_worker_otp_core(text,text)',
    'public.verify_mfa_core(text,text)',
    'public.verify_admin_otp_core(text)',
    'public.admin_get_payroll(text)'
  ]) AS t(sig);

-- Wrapper pra-login tidak boleh ikut tercabut (regresi isolasi login).
SELECT t.sig AS wrapper_pra_login,
       CASE
         WHEN to_regprocedure(t.sig) IS NULL THEN 'SKIP (tidak ada)'
         WHEN has_function_privilege('anon', to_regprocedure(t.sig), 'EXECUTE') THEN 'PASS — anon tetap boleh'
         ELSE 'FAIL — anon hilang, login rusak'
       END AS hasil
  FROM unnest(ARRAY[
    'public.login_worker_by_email(text,text)',
    'public.generate_worker_otp(text,text,text)',
    'public.verify_worker_otp(text,text)',
    'public.verify_admin_otp(text)',
    'public.register_session(text,text,text)',
    'public.hit_rate_limit(text,text,integer,integer)'
  ]) AS t(sig);
