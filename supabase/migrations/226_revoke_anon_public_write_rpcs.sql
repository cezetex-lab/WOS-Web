-- ================================================================
-- 226_revoke_anon_public_write_rpcs.sql — RPC penulis tidak boleh diakses anon/PUBLIC
--
-- MASALAH (temuan audit 2026-09-17)
--   Supabase memasang DEFAULT PRIVILEGES:
--     objtype=f (function) : anon, authenticated, service_role  -> EXECUTE
--     objtype=r (table)    : anon, authenticated, service_role  -> ALL
--   Ditambah default bawaan PostgreSQL: EXECUTE diberikan ke PUBLIC.
--   Akibatnya SETIAP fungsi baru otomatis bisa dipanggil anon & PUBLIC,
--   termasuk RPC yang MENULIS data — kecuali di-REVOKE eksplisit.
--
--   Hasil audit 191 fungsi penulis di DB live (2026-09-17):
--     11 punya EXECUTE untuk anon, 4 di antaranya juga PUBLIC.
--
-- PEMBAGIAN (disengaja, jangan diseragamkan)
--   A. WAJIB dicabut — tidak pernah dipanggil sebelum login:
--        - worker_update_profile(...)         : RPC TULIS profil karyawan
--        - employees_master_*_trigger()       : fungsi trigger (SECURITY DEFINER)
--      Ketiganya kini anon+PUBLIC -> dicabut keduanya.
--   B. Cukup PUBLIC yang dicabut — memang dipakai alur login (pra-sesi),
--      jadi `anon` DIPERTAHANKAN sesuai keputusan arsitektur auth:
--        login_worker, login_worker_by_email, generate_worker_otp,
--        verify_worker_otp, register_session, submit_registration, hit_rate_limit
--      PUBLIC mencakup SEMUA role (termasuk masa depan), sedangkan `anon`
--      dan `authenticated` sudah punya grant sendiri -> mencabut PUBLIC
--      tidak memutus API Supabase, tapi menutup pintu bagi role lain.
--
-- PRINSIP: perubahan ini hanya MENGENCANGKAN (fail-closed). Tidak ada GRANT baru.
-- ================================================================

-- ── A. Cabut anon + PUBLIC ─────────────────────────────────────
DO $$
DECLARE
  v_sigs text[] := ARRAY[
    'public.worker_update_profile(text,text,text,text,jsonb,text,text,text,text,text,text,text,text,text,text)',
    'public.employees_master_insert_trigger()',
    'public.employees_master_update_trigger()',
    'public.employees_master_delete_trigger()'
  ];
  v_sig   text;
  v_oid   regprocedure;
BEGIN
  FOREACH v_sig IN ARRAY v_sigs LOOP
    v_oid := to_regprocedure(v_sig);
    IF v_oid IS NULL THEN
      RAISE NOTICE '226: % tidak ada — dilewati', v_sig;
      CONTINUE;
    END IF;
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM anon, PUBLIC', v_oid);
    RAISE NOTICE '226: anon+PUBLIC dicabut dari %', v_sig;
  END LOOP;
END $$;

-- ── B. Cabut PUBLIC saja (anon tetap, sesuai alur login) ───────
DO $$
DECLARE
  v_sigs text[] := ARRAY[
    'public.login_worker(text,text,text)',
    'public.login_worker_by_email(text,text)',
    'public.generate_worker_otp(text,text,text)',
    'public.verify_worker_otp(text,text)',
    'public.register_session(text,text,text)',
    'public.submit_registration(text,text,text,text,text,text,text)',
    'public.hit_rate_limit(text,text,integer,integer)'
  ];
  v_sig   text;
  v_oid   regprocedure;
BEGIN
  FOREACH v_sig IN ARRAY v_sigs LOOP
    v_oid := to_regprocedure(v_sig);
    IF v_oid IS NULL THEN
      RAISE NOTICE '226: % tidak ada — dilewati', v_sig;
      CONTINUE;
    END IF;
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC', v_oid);
    RAISE NOTICE '226: PUBLIC dicabut dari % (anon dipertahankan)', v_sig;
  END LOOP;
END $$;

-- ── C. Sapuan kedua (2026-09-18) — fungsi di luar berkas "penulis" ─────
-- Blok A/B di atas hanya butuh daftar RPC yang sudah dikenal. Sapuan kedua ini
-- menutup temuan dari replay instalasi dari awal (156/156 berkas sukses): fungsi yang
-- dibuat SETELAH 172 menerima ulang EXECUTE anon/PUBLIC dari default privilege
-- Supabase + bawaan PostgreSQL, dan verify di bawah (yang hanya memeriksa fungsi
-- PENULIS) tidak melihatnya karena sebagian besar adalah RPC BACA / RPC owner.
-- Diverifikasi ke DB live 2026-09-18: live TIDAK punya anon/PUBLIC untuk kesepuluh
-- fungsi ini, jadi REVOKE di bawah hanya menyamakan hasil instalasi dengan live.
-- Prinsip sama: hanya mengencangkan, tidak ada GRANT baru.
DO $$
DECLARE
  v_sigs text[] := ARRAY[
    -- owner / admin-only
    'public.admin_set_employee_role(text,text,text)',
    'public.owner_get_testing_override(text)',
    'public.owner_set_testing_override(text,boolean,boolean)',
    'public.owner_delete_testing_override(text)',
    'public.auth_testing_override_bypass(text,text)',
    -- internal flow (bukan entry pra-login)
    'public.verify_admin_otp(text)',
    'public.verify_mfa_core(text,text)',
    'public.verify_worker_otp_core(text,text)',
    -- RPC baca dashboard/industri (dipanggil sesudah login)
    'public.get_estate_blocks()',
    'public.get_organization_health()'
  ];
  v_sig text;
  v_oid regprocedure;
BEGIN
  FOREACH v_sig IN ARRAY v_sigs LOOP
    v_oid := to_regprocedure(v_sig);
    IF v_oid IS NULL THEN
      RAISE NOTICE '226C: % tidak ada — dilewati', v_sig;
      CONTINUE;
    END IF;
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM anon, PUBLIC', v_oid);
  END LOOP;
END $$;

-- generate_worker_otp versi 2 argumen: dipakai alur login pra-sesi, jadi `anon`
-- DIPERTAHANKAN (kategori B) — hanya PUBLIC yang dicabut.
DO $$
BEGIN
  IF to_regprocedure('public.generate_worker_otp(text,text)') IS NOT NULL THEN
    REVOKE EXECUTE ON FUNCTION public.generate_worker_otp(text, text) FROM PUBLIC;
  END IF;
END $$;

-- ── Verifikasi: tidak boleh ada fungsi PENULIS yang bisa diakses anon/PUBLIC,
--    kecuali 7 RPC alur login yang memang harus pra-sesi (daftar putih eksplisit).
DO $$
DECLARE
  v_offenders text;
BEGIN
  SELECT string_agg(p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')', E'\n  ')
    INTO v_offenders
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.prokind = 'f'
    AND p.prosrc ~* '(^|[^a-z_])(insert\s+into|update\s+[a-z_"]|delete\s+from|truncate\s|alter\s+table|drop\s+table)'
    AND EXISTS (
      SELECT 1 FROM unnest(coalesce(p.proacl, '{}')) a
      WHERE a::text LIKE 'anon=X/%' OR a::text LIKE '=X/%'
    )
    AND p.proname NOT IN (
      'login_worker', 'login_worker_by_email', 'generate_worker_otp',
      'verify_worker_otp', 'register_session', 'submit_registration', 'hit_rate_limit'
    );

  IF v_offenders IS NULL THEN
    RAISE NOTICE '226 VERIFY: PASS — tidak ada RPC penulis yang terjangkau anon/PUBLIC';
  ELSE
    RAISE WARNING '226 VERIFY: masih ada RPC penulis terjangkau anon/PUBLIC:%', E'\n  ' || v_offenders;
  END IF;
END $$;
