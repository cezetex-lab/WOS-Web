-- ================================================================
-- 225_dynamic_attendance_partitions.sql — partisi absensi tidak lagi berbatas tahun
--
-- MASALAH (temuan audit 2026-09-17)
--   `141_153_CONSOLIDATED_.sql` membuat partisi absensi dengan loop
--   HARDCODED 2024..2027:
--       FOR v_year IN 2024..2027 LOOP ... FOR v_month IN 1..12 LOOP
--   Tidak ada cron/fungsi penjaga. Konsekuensi pada instalasi perusahaan baru:
--   begitu masuk Januari 2028, INSERT ke `hr_attendance_partitioned` gagal
--   dengan "no partition of relation ... found for row". Loop seperti ini juga
--   ikut tersalin ke DB setiap perusahaan, jadi kesalahannya berulang.
--
-- PERBAIKAN
--   1. `ensure_attendance_partitions(p_from, p_months)` — pembuat partisi
--      dinamis + idempoten (aman dipanggil berkali-kali, hanya membuat yang
--      belum ada). Bisa dipanggil untuk rentang masa depan berapa pun.
--   2. Backfill: tutup celah dari 2024-01 sampai bulan ini + 24 bulan,
--      sehingga instalasi baru langsung punya partisi jauh ke depan.
--   3. Cron bulanan `ensure-attendance-partitions` menjaga jendela 24 bulan
--      ke depan selamanya (dijaga guard bila pg_cron belum aktif).
--   4. Selaraskan skema `hr_attendance_partitioned` dengan `hr_attendance`
--      (kolom `overtime_approved` hanya ada di sisi non-partisi — akan hilang
--      bila `RENAME` yang masih dikomentari di 141:1403 nanti dijalankan).
--
-- CATATAN STATUS (jangan dihapus)
--   Per 2026-09-17 kedua tabel absensi SAMA-SAMA KOSONG (0 baris) dan tidak ada
--   fungsi/view yang menyentuh `hr_attendance_partitioned`; `141:1403` masih
--   mengomentari `ALTER TABLE hr_attendance_partitioned RENAME TO hr_attendance`.
--   Migrasi ini TIDAK mengubah struktur kepemilikan data — ia hanya memastikan
--   bagian partisi tetap sehat untuk saat rename itu (atau adopsi lain) dipakai.
-- ================================================================

-- ── 1. Pembuat partisi dinamis (idempoten) ──────────────────────
CREATE OR REPLACE FUNCTION public.ensure_attendance_partitions(
  p_from   date    DEFAULT NULL,
  p_months integer DEFAULT 24
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_parent  text := 'hr_attendance_partitioned';
  v_start   date;
  v_month   date;
  v_name    text;
  v_created integer := 0;
  i         integer;
  v_count   integer;
BEGIN
  -- fail-closed: hanya jalan bila parent benar-benar ada dan benar-benar partitioned
  IF NOT EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = v_parent AND c.relkind = 'p'
  ) THEN
    RETURN 0;
  END IF;

  v_count := GREATEST(COALESCE(p_months, 24), 1);
  v_start := COALESCE(p_from, date_trunc('month', CURRENT_DATE)::date);

  FOR i IN 0 .. v_count - 1 LOOP
    v_month := (v_start + (i || ' month')::interval)::date;
    v_name  := 'hr_attendance_' || to_char(v_month, 'YYYY_MM');

    IF NOT EXISTS (
      SELECT 1 FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relname = v_name
    ) THEN
      EXECUTE format(
        'CREATE TABLE public.%I PARTITION OF public.%I FOR VALUES FROM (%L) TO (%L)',
        v_name, v_parent, v_month, (v_month + interval '1 month')::date
      );
      v_created := v_created + 1;
    END IF;
  END LOOP;

  RETURN v_created;
END
$function$;

COMMENT ON FUNCTION public.ensure_attendance_partitions(date, integer) IS
  'Membuat partisi hr_attendance_partitioned secara dinamis & idempoten (pengganti loop hardcoded 2024..2027 di migrasi 141)';

-- ── 2. Backfill: 2024-01 .. (bulan ini + 24 bulan) ──────────────
DO $$
DECLARE
  v_months integer;
BEGIN
  v_months := (EXTRACT(YEAR FROM CURRENT_DATE + interval '24 months')::int * 12
             + EXTRACT(MONTH FROM CURRENT_DATE + interval '24 months')::int)
            - (2024 * 12 + 1) + 1;

  RAISE NOTICE '225: memastikan % partisi (2024-01 s/d % bulan ke depan)',
    v_months, 24;
  RAISE NOTICE '225: % partisi baru dibuat',
    public.ensure_attendance_partitions('2024-01-01'::date, v_months);
END $$;

-- ── 3. Selaraskan kolom dengan hr_attendance ───────────────────
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables
             WHERE table_schema = 'public' AND table_name = 'hr_attendance_partitioned')
     AND EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'public' AND table_name = 'hr_attendance'
                   AND column_name = 'overtime_approved')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns
                     WHERE table_schema = 'public' AND table_name = 'hr_attendance_partitioned'
                       AND column_name = 'overtime_approved')
  THEN
    ALTER TABLE public.hr_attendance_partitioned
      ADD COLUMN IF NOT EXISTS overtime_approved boolean DEFAULT false;
    RAISE NOTICE '225: kolom overtime_approved ditambahkan ke hr_attendance_partitioned';
  ELSE
    RAISE NOTICE '225: kolom overtime_approved sudah selaras / tidak diperlukan';
  END IF;
END $$;

-- ── 4. Cron bulanan (dijaga bila pg_cron belum aktif) ──────────
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    RAISE NOTICE '225: pg_cron belum aktif — jadwal ensure-attendance-partitions dilewati';
    RETURN;
  END IF;

  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'ensure-attendance-partitions') THEN
    PERFORM cron.unschedule('ensure-attendance-partitions');
  END IF;

  PERFORM cron.schedule(
    'ensure-attendance-partitions',
    '0 4 1 * *',
    'SELECT public.ensure_attendance_partitions(NULL, 24)'
  );
  RAISE NOTICE '225: jadwal ensure-attendance-partitions aktif (tgl 1 jam 04:00 UTC)';
END $$;

-- ── 5. ACL: infrastruktur, bukan untuk anon/PUBLIC ─────────────
REVOKE EXECUTE ON FUNCTION public.ensure_attendance_partitions(date, integer) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.ensure_attendance_partitions(date, integer) TO service_role;

-- ── 6. Verifikasi ──────────────────────────────────────────────
DO $$
DECLARE
  v_parts integer;
  v_max   text;
BEGIN
  SELECT count(*) INTO v_parts
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relispartition
    AND c.relname LIKE 'hr_attendance_2%';

  SELECT max(c.relname) INTO v_max
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relispartition
    AND c.relname LIKE 'hr_attendance_2%';

  RAISE NOTICE '225 VERIFY: % partisi absensi, partisi terakhir = %', v_parts, v_max;
END $$;
