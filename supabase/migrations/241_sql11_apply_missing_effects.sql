-- ═══════════════════════════════════════════════════════════════════════════
-- 241_sql11_apply_missing_effects.sql — SQL-11 (temuan audit 2026-09-17)
--
-- Konteks: registry `schema_migrations` menyimpang dari 35 berkas migrasi
-- (drift checksum KONTEN, bukan EOL). Audit per-berkas 2026-09-21 memverifikasi
-- setiap klaim ke DB live (probe read-only `.agents/scripts/sql11-verify-claims*.mjs`):
--
--   * 33 berkosong  → live SUDAH memuat efeknya; registry di-restamp
--                     (refresh-migration-checksums.mjs --only, terpisah).
--   * 054, 083      → live TIDAK memuat sebagian efek (terbukti query live):
--                       - 054: kolom audit hr_surveys 0/3, hr_okrs 1/3;
--                              trigger trg_hr_okrs_updated & trg_hr_surveys_updated absen
--                       - 083: policy sv_select (hr_surveys) & ok_select (hr_okrs) absen,
--                              padahal kedua tabel RLS enabled + FORCED
--                     Berkas aslinya kini idempoten (guard to_regclass), jadi efeknya
--                     dijalankan ulang DI SINI lewat migrasi bernomor baru — bukan
--                     re-apply berkas lama — supaya pendaftaran registry tetap satu
--                     transaksi (MIGRATION_GUIDE.md §0).
--
-- Idempoten penuh: aman dijalankan berulang (ADD COLUMN IF NOT EXISTS,
-- DROP TRIGGER IF EXISTS, DROP POLICY IF EXISTS). Tanpa data, tanpa DROP objek.
--
-- Dampak lintas-page (G6/G7): hr_okrs/hr_surveys tidak pernah dibaca langsung
-- oleh src/ (semua via SECURITY DEFINER RPC — diverifikasi grep 2026-09-21);
-- policy SELECT baru tidak mengubah hasil RPC mana pun. Trigger updated_at
-- hanya mengisi kolom audit pada UPDATE.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. Efek 054 — kolom audit + fungsi + trigger (hr_okrs & hr_surveys) ───

ALTER TABLE public.hr_okrs    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.hr_okrs    ADD COLUMN IF NOT EXISTS created_by TEXT;
ALTER TABLE public.hr_okrs    ADD COLUMN IF NOT EXISTS updated_by TEXT;
ALTER TABLE public.hr_surveys ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.hr_surveys ADD COLUMN IF NOT EXISTS created_by TEXT;
ALTER TABLE public.hr_surveys ADD COLUMN IF NOT EXISTS updated_by TEXT;

-- Definisi 1:1 dengan 054_audit_columns.sql (fungsi sudah ada di live;
-- CREATE OR REPLACE untuk instalasi dari awal yang belum memilikinya).
CREATE OR REPLACE FUNCTION public.update_audit_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_hr_okrs_updated    ON public.hr_okrs;
DROP TRIGGER IF EXISTS trg_hr_surveys_updated ON public.hr_surveys;
CREATE TRIGGER trg_hr_okrs_updated    BEFORE UPDATE ON public.hr_okrs    FOR EACH ROW EXECUTE FUNCTION public.update_audit_timestamp();
CREATE TRIGGER trg_hr_surveys_updated BEFORE UPDATE ON public.hr_surveys FOR EACH ROW EXECUTE FUNCTION public.update_audit_timestamp();

-- ── 2. Efek 083 — policy SELECT (hr_surveys & hr_okrs) ────────────────────
-- Definisi 1:1 dengan 083_rls_hardening.sql baris 189-235 (termasuk guard
-- to_regclass-nya; tabel memang sudah ada di live).

DO $$
BEGIN
  IF to_regclass('public.hr_surveys') IS NOT NULL THEN
    DROP POLICY IF EXISTS sv_all    ON public.hr_surveys;
    DROP POLICY IF EXISTS sv_select ON public.hr_surveys;
    CREATE POLICY sv_select ON public.hr_surveys FOR SELECT USING (TRUE);
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.hr_okrs') IS NOT NULL THEN
    DROP POLICY IF EXISTS ok_all    ON public.hr_okrs;
    DROP POLICY IF EXISTS ok_select ON public.hr_okrs;
    CREATE POLICY ok_select ON public.hr_okrs FOR SELECT
      USING (nrp = (SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1) OR is_admin_or_owner());
  END IF;
END $$;

-- ── 3. Verifikasi (hasil = bukti DoD, ikut tercatat di output apply) ──────
SELECT '241.1 kolom audit hr_okrs'    AS test, count(*)::int AS kolom FROM information_schema.columns
 WHERE table_name='public.hr_okrs'    AND column_name IN ('updated_at','created_by','updated_by')
UNION ALL
SELECT '241.2 kolom audit hr_surveys', count(*)::int FROM information_schema.columns
 WHERE table_name='public.hr_surveys' AND column_name IN ('updated_at','created_by','updated_by')
UNION ALL
SELECT '241.3 trigger hr_okrs/hr_surveys', count(*)::int FROM pg_trigger
 WHERE tgname IN ('trg_hr_okrs_updated','trg_hr_surveys_updated') AND NOT tgisinternal
UNION ALL
SELECT '241.4 policy sv_select/ok_select', count(*)::int FROM pg_policies
 WHERE schemaname='public' AND policyname IN ('sv_select','ok_select');
