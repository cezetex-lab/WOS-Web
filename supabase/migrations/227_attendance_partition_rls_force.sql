-- ================================================================
-- 227_attendance_partition_rls_force.sql — partisi baru harus ikut FORCE RLS
--
-- MASALAH (ditemukan saat verifikasi migrasi 225, 2026-09-17)
--   `CREATE TABLE ... PARTITION OF` MEWARISI `ENABLE ROW LEVEL SECURITY` dari
--   parent, tetapi TIDAK mewarisi `FORCE ROW LEVEL SECURITY`. Bukti pada DB live
--   setelah migrasi 225:
--       hr_attendance_2024_01 .. 2027_12  -> rls=true force=true   (48 partisi)
--       hr_attendance_2028_01 .. 2028_09  -> rls=true force=false  ( 9 partisi BARU)
--   Jadi setiap partisi yang lahir dari `ensure_attendance_partitions()` akan
--   selamanya "enabled tapi tidak forced" — berbeda dari 48 partisi historis yang
--   di-FORCE oleh loop migrasi 173 saat mereka sudah ada.
--
-- DAMPAK
--   Tidak ada kebocoran data: `anon`/`authenticated` bukan pemilik tabel, jadi RLS
--   tetap berlaku bagi mereka (terverifikasi: 57/57 partisi `relrowsecurity = true`).
--   Yang bocor hanya bagi PEMILIK tabel (`postgres`) — dan itu justru inkonsistensi
--   yang harus ditutup, karena §7.4 menyatakan RLS di-FORCE dan berkas ini adalah
--   sumber partisi berikutnya.
--
-- PERBAIKAN
--   1. `CREATE OR REPLACE` fungsi 225: tiap partisi yang BARU dibuat langsung
--      diberi `ENABLE` + `FORCE ROW LEVEL SECURITY` (idempoten).
--   2. Backfill: FORCE-kan partisi yang belum (`hr_attendance_2028_*`).
--   3. Verifikasi: 57/57 partisi harus `relrowsecurity AND relforcerowsecurity`.
--
-- CATATAN: 9 tabel BUKAN partisi juga belum FORCE (`employees_core`,
-- `employees_extended`, `fatigue_data`, `heavy_equipment`, `jsa_data`,
-- `production_daily`, `safety_incidents`, `schema_migrations`, `simper_data`).
-- TIDAK disentuh di sini karena FORCE membuat PEMILIK tunduk pada policy →
-- berisiko memutus alur SQL Editor/dashboard bila policy-nya role-specific.
-- Itu keputusan terpisah untuk user (dicatat sebagai item OPEN di AGENTS.md).
-- ================================================================

-- ── 1. Fungsi 225 diperbarui: ikut men-FORCE partisi baru ──────
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
      -- WARISAN: partition baru TIDAK otomatis FORCE (lihat header)
      EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', v_name);
      EXECUTE format('ALTER TABLE public.%I FORCE ROW LEVEL SECURITY', v_name);
      v_created := v_created + 1;
    END IF;
  END LOOP;

  RETURN v_created;
END
$function$;

REVOKE EXECUTE ON FUNCTION public.ensure_attendance_partitions(date, integer) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.ensure_attendance_partitions(date, integer) TO service_role;

-- ── 2. Backfill: FORCE-kan partisi yang belum ──────────────────
DO $$
DECLARE
  r       RECORD;
  v_fixed integer := 0;
BEGIN
  FOR r IN
    SELECT c.relname
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relispartition
      AND c.relkind = 'r'
      AND c.relname ~ '^hr_attendance_2[0-9]{3}_[0-9]{2}$'
      AND NOT c.relforcerowsecurity
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', r.relname);
    EXECUTE format('ALTER TABLE public.%I FORCE ROW LEVEL SECURITY', r.relname);
    v_fixed := v_fixed + 1;
  END LOOP;
  RAISE NOTICE '227: % partisi absensi di-FORCE RLS', v_fixed;
END $$;

-- ── 3. Verifikasi ──────────────────────────────────────────────
DO $$
DECLARE
  v_total integer;
  v_ok    integer;
BEGIN
  SELECT count(*),
         count(*) FILTER (WHERE c.relrowsecurity AND c.relforcerowsecurity)
    INTO v_total, v_ok
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relispartition AND c.relkind = 'r'
    AND c.relname ~ '^hr_attendance_2[0-9]{3}_[0-9]{2}$';

  IF v_total = v_ok THEN
    RAISE NOTICE '227 VERIFY: PASS — %/% partisi absensi RLS enabled + forced', v_ok, v_total;
  ELSE
    RAISE WARNING '227 VERIFY: GAGAL — hanya %/% partisi yang forced', v_ok, v_total;
  END IF;
END $$;
