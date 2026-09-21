-- 240_drop_hr_attendance_partitioned.sql — SQL-08: drop struktur absensi mati.
--
-- CATATAN RESTORASI (2026-09-21, sesi SQL-11): berkas asli diterapkan ke DB live
-- pada 2026-09-20 (registry checksum 2877ffba…) tetapi TIDAK sempat di-commit —
-- hilang dari repo. Berkas ini rekonstruksi setia dari catatan
-- agentsLogs_2026-09.md entri SQL-08; checksum registry di-restamp ke berkas ini.
-- Live sudah memuat efeknya, jadi re-run di live = no-op (semua IF EXISTS).
--
-- Efek yang dibuang (terbukti 0 baris / 0 pemanggil saat SQL-08):
--   * tabel partisi induk hr_attendance_partitioned + 57 partisi hr_attendance_YYYY_MM
--   * fungsi ensure_attendance_partitions(p_from date, p_months integer)
--   * cron job 'ensure-attendance-partitions' (0 4 1 * *)
-- Tabel absensi aktif hr_attendance TIDAK disentuh (96 baris saat itu, utuh).
--
-- Idempoten: aman dijalankan berulang; verifikasi akhir gagal-cepat bila sisa.

-- 1) Lepas cron partisi absensi (bila extension pg_cron + job-nya ada).
DO $$
DECLARE
  j record;
BEGIN
  IF to_regclass('cron.job') IS NOT NULL THEN
    FOR j IN SELECT jobname FROM cron.job WHERE jobname = 'ensure-attendance-partitions' LOOP
      PERFORM cron.unschedule(j.jobname);
    END LOOP;
  END IF;
END $$;

-- 2) Drop tabel partisi induk (partisi anak ikut CASCADE).
DROP TABLE IF EXISTS public.hr_attendance_partitioned CASCADE;

-- 3) Drop fungsi pembuat partisi.
DROP FUNCTION IF EXISTS public.ensure_attendance_partitions(p_from date, p_months integer);

-- 4) Verifikasi gagal-cepat: sisa apa pun = error (migrasi tidak dianggap sukses).
DO $$
DECLARE
  v_t int; v_f int; v_j int;
BEGIN
  SELECT count(*) INTO v_t FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname LIKE 'hr_attendance_partitioned%';
  SELECT count(*) INTO v_f FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'ensure_attendance_partitions';
  SELECT count(*) INTO v_j FROM cron.job WHERE jobname = 'ensure-attendance-partitions';
  IF v_t > 0 OR v_f > 0 OR v_j > 0 THEN
    RAISE EXCEPTION 'SQL-08: sisa struktur absensi mati — tabel=%, fungsi=%, cron=%', v_t, v_f, v_j;
  END IF;
  RAISE NOTICE 'SQL-08 verifikasi: tabel=0, fungsi=0, cron=0 — bersih.';
END $$;
