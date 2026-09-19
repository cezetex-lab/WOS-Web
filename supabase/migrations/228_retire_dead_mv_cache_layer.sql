-- ================================================================
-- 228_retire_dead_mv_cache_layer.sql — hentikan cron MV yang gagal + buang fungsi yatim
--
-- KEPUTUSAN (2026-09-17, berdasarkan bukti — bukan tebakan)
--   Lapisan cache 5 materialized view SUDAH MATI dan digantikan tabel
--   `dashboard_cache` (dipakai `get_dashboard_cached`/`set_cache`). Bukti:
--     1. `pg_matviews` schema public = 0 — kelima MV (`mv_admin_summary`,
--        `mv_team_kpi`, `mv_payroll_monthly`, `mv_attendance_daily`,
--        `mv_flight_risk`) tidak ada, padahal migrasi 035 membuatnya.
--     2. TIDAK ADA satu pun migrasi `DROP MATERIALIZED VIEW` → dihapus manual.
--     3. `grep` seluruh `src/` → 0 referensi ke `mv_*`.
--     4. Referensi di migrasi hanya dari: 035 (definisi + verifikasi),
--        171 (definisi fungsi refresh), 182 (loop guard `pg_matviews`),
--        212 (penjadwalan cron). Tidak ada konsumen data.
--     5. Akibat nyatanya: 3 cron job gagal SETIAP JAM sejak MV hilang —
--        `refresh-mv-admin-summary` 94×, `refresh-mv-team-kpi` 94×,
--        `refresh-mv-attendance` 189× (`relation "mv_…" does not exist`).
--
--   Pilihan yang diambil: **PENSIUN** lapisan ini (bukan membuat ulang 5 MV).
--   Membuat ulang MV yang tidak dibaca siapa pun hanya menambah beban refresh
--   berkala tanpa manfaat. Kalau nanti cache MV dibutuhkan lagi, definisinya
--   masih utuh di `035_wave_b_connection_cache.sql` dan fungsi refresh-nya di
--   `171_restore_db_only_functions.sql` — tinggal dihidupkan kembali lewat
--   migrasi baru.
--
-- YANG DILAKUKAN
--   1. Unschedule cron job MV (idempoten, aman kalau tidak ada).
--   2. Drop 6 fungsi refresh yatim (`refresh_mv_*`, `refresh_all_materialized_views`)
--      — diverifikasi TIDAK ada pemanggil (`prosrc` seluruh fungsi public tidak
--      menyebut mereka) dan job yang memanggilnya sudah dihentikan di langkah 1.
--   3. Verifikasi: 0 job & 0 fungsi yang menyentuh `mv_*`.
-- ================================================================

-- ── 1. Hentikan cron job MV ────────────────────────────────────
DO $$
DECLARE
  v_names text[] := ARRAY[
    'refresh-mv-admin-summary',
    'refresh-mv-team-kpi',
    'refresh-mv-attendance',
    'refresh-all-mv'
  ];
  v_name text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    RAISE NOTICE '228: pg_cron tidak aktif — tidak ada job untuk dihentikan';
    RETURN;
  END IF;

  FOREACH v_name IN ARRAY v_names LOOP
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = v_name) THEN
      PERFORM cron.unschedule(v_name);
      RAISE NOTICE '228: job % dihentikan', v_name;
    END IF;
  END LOOP;

  -- jaring pengaman: hentikan job LAIN apa pun yang menyentuh mv_*
  FOR v_name IN
    SELECT jobname FROM cron.job WHERE command ~* '\bmv_[a-z_]+'
  LOOP
    PERFORM cron.unschedule(v_name);
    RAISE NOTICE '228: job tambahan % dihentikan (menyentuh mv_*)', v_name;
  END LOOP;
END $$;

-- ── 2. Buang fungsi refresh yatim ──────────────────────────────
DO $$
DECLARE
  v_sigs text[] := ARRAY[
    'public.refresh_mv_admin_summary()',
    'public.refresh_mv_team_kpi()',
    'public.refresh_mv_payroll_monthly()',
    'public.refresh_mv_attendance_daily()',
    'public.refresh_mv_flight_risk()',
    'public.refresh_all_materialized_views()'
  ];
  v_sig text;
  v_oid regprocedure;
BEGIN
  FOREACH v_sig IN ARRAY v_sigs LOOP
    v_oid := to_regprocedure(v_sig);
    IF v_oid IS NULL THEN
      RAISE NOTICE '228: % tidak ada — dilewati', v_sig;
      CONTINUE;
    END IF;
    EXECUTE format('DROP FUNCTION IF EXISTS %s', v_oid);
    RAISE NOTICE '228: fungsi % dibuang', v_sig;
  END LOOP;
END $$;

-- ── 3. Verifikasi ──────────────────────────────────────────────
DO $$
DECLARE
  v_jobs integer := 0;
  v_fns  integer;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    SELECT count(*) INTO v_jobs FROM cron.job WHERE command ~* '\bmv_[a-z_]+';
  END IF;

  SELECT count(*) INTO v_fns
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.prosrc ~* '\bmv_[a-z_]+';

  IF v_jobs = 0 AND v_fns = 0 THEN
    RAISE NOTICE '228 VERIFY: PASS — 0 cron job & 0 fungsi menyentuh mv_*';
  ELSE
    RAISE WARNING '228 VERIFY: masih ada % job dan % fungsi menyentuh mv_*', v_jobs, v_fns;
  END IF;
END $$;
