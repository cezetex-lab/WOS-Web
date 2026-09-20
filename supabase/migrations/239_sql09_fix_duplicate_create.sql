-- ════════════════════════════════════════════════════════════════
-- 239_sql09_fix_duplicate_create.sql — SQL-09, versi 2 (2026-09-20)
--
-- KONTEKS (terverifikasi ke DB live + ke berkas)
--   Temuan SQL-09 ("duplikat CREATE dalam satu berkas") ternyata BUKAN duplikat
--   objek di database. Duplikatnya adalah DUA STATEMENT di dalam
--   `141_153_CONSOLIDATED_.sql`: blok `CREATE TABLE IF NOT EXISTS hr_okrs`
--   (baris 545) dan `hr_surveys` (baris 558) diulang byte-identik di STEP 3
--   (baris 1911 & 1924). Karena keduanya `IF NOT EXISTS`, pengulangan itu murni
--   dead code dan tidak pernah menghasilkan objek kembar.
--
--   Keputusannya: duplikat dihapus di SUMBER (berkas 141), BUKAN dengan DROP ke
--   DB live — sebab di live tidak ada yang kembar, sementara `hr_okrs` berisi
--   data nyata (9 baris) dan 5 fungsi bergantung padanya; DROP hanya akan
--   menghapus data tanpa memperbaiki apa pun. Klaim audit "view
--   `employees_master` 2x di berkas 183" juga terbukti SALAH: hanya ada satu
--   `CREATE VIEW employees_master` (baris 181); kemunculan lain adalah `DROP`
--   di dalam DO-block yang memang wajib.
--
-- VERSI 1 vs 2
--   v1 berkas ini HANYA berisi komentar → no-op, tidak ada aksi apa pun, dan
--   sudah terlanjur terdaftar di `schema_migrations`.
--   v2 menggantinya dengan ASSERTION non-destruktif: tidak mengubah skema dan
--   tidak menghapus apa pun — hanya GAGAL-CEPAT kalau di kemudian hari benar
--   muncul objek kembar. Inilah aksi yang memang bisa dilakukan di level DB;
--   pembersihan dead code dikerjakan di berkas migrasi sumbernya.
-- ════════════════════════════════════════════════════════════════

DO $sql09$
DECLARE
  v_kembar TEXT;
  v_ada    INT;
  v_kind   "char";
  v_kolom  INT;
BEGIN
  -- (1) tepat satu relasi per nama — duplikat nyata akan tertangkap di sini
  SELECT string_agg(relname || '=' || jumlah, ', ' ORDER BY relname)
    INTO v_kembar
    FROM (
      SELECT c.relname::text AS relname, count(*)::text AS jumlah
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE n.nspname = 'public'
         AND c.relname IN ('hr_okrs', 'hr_surveys', 'employees_master')
       GROUP BY c.relname
      HAVING count(*) > 1
    ) d;

  IF v_kembar IS NOT NULL THEN
    RAISE EXCEPTION 'SQL-09 GAGAL: objek kembar di public → %', v_kembar;
  END IF;

  -- (2) hr_okrs harus TABLE dengan 10 kolom (definisi 141 + migrasi 236)
  SELECT c.relkind INTO v_kind
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relname = 'hr_okrs';
  IF v_kind IS NULL THEN
    RAISE EXCEPTION 'SQL-09 GAGAL: public.hr_okrs tidak ada';
  END IF;
  IF v_kind::text <> 'r' THEN
    RAISE EXCEPTION 'SQL-09 GAGAL: public.hr_okrs bukan TABLE (relkind=%)', v_kind::text;
  END IF;

  SELECT count(*) INTO v_kolom
    FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'hr_okrs';
  IF v_kolom <> 10 THEN
    RAISE EXCEPTION 'SQL-09 GAGAL: hr_okrs punya % kolom, seharusnya 10', v_kolom;
  END IF;

  -- (3) hr_surveys harus ada
  SELECT count(*) INTO v_ada
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relname = 'hr_surveys';
  IF v_ada <> 1 THEN
    RAISE EXCEPTION 'SQL-09 GAGAL: public.hr_surveys tidak ada (ditemukan %)', v_ada;
  END IF;

  -- (4) employees_master harus VIEW (dibuat 183, dibaca aplikasi)
  SELECT c.relkind INTO v_kind
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relname = 'employees_master';
  IF v_kind IS NULL OR v_kind::text <> 'v' THEN
    RAISE EXCEPTION
      'SQL-09 GAGAL: public.employees_master bukan VIEW (relkind=%)',
      COALESCE(v_kind::text, 'tidak ada');
  END IF;

  RAISE NOTICE
    'SQL-09 OK: 1 hr_okrs (10 kolom), 1 hr_surveys, 1 VIEW employees_master — tidak ada objek kembar.';
END
$sql09$;
