-- ================================================================
-- Migration 224: check_migrations() — aturan DUPLICATE dirapikan
--
-- MASALAH
--   Migration 219 membuat unique index pada `version`, lalu MENGHAPUSNYA
--   karena beberapa berkas boleh berbagi nomor versi:
--     "Note: version unique index removed — multiple files can share a
--      version number (e.g. 176_fix_search_path + 176_original).
--      Filename is the true unique key."
--   Tapi cabang DUPLICATE di check_migrations() masih dari era index itu:
--   setiap `version` yang dipakai >1 berkas dilaporkan DUPLICATE. Akibatnya
--   fungsi ini MUSTAHIL melaporkan 0 issue — 4 pasangan sah selalu muncul:
--     v176  176_fix_rownum_and_pgcrypto_path + 176_fix_search_path_extensions
--     v186  186_add_missing_routes          + 186_enable_pg_cron_schedules
--     v208  208_fix_groupby                 + 208_industry_tables_and_rpcs
--     v215  215_ai_rag_access_and_rate_limits + 215_gap_employee_fields
--   Efek buruknya nyata: sinyal yang benar-benar penting (UNAPPLIED) tenggelam
--   di antara 4 kebisingan tetap, sampai-sampai drift migrasi 221/222/223
--   (AGENTS.md §5.7 no.11) tidak terlihat.
--
-- PERBAIKAN
--   1. DUPLICATE hanya untuk duplikasi SUNGGUHAN: dalam satu versi ada >1
--      berkas dengan slug sama (nama tanpa prefiks nomor). Karena `filename`
--      sudah UNIQUE, cabang ini praktis tidak pernah menyala — ia kini menjadi
--      assertion integritas, bukan pendeteksi utama. Pemakaian nomor versi
--      bersama oleh berkas berbeda TIDAK lagi dilaporkan.
--   2. Ditambah VERSION_MISMATCH: baris yang `version`-nya tidak sama dengan
--      prefiks nomor pada `filename` (atau filename tanpa prefiks nomor).
--      Inilah kelas kesalahan yang nyata saat pendaftaran manual — dan versi
--      lama fungsi ini tidak bisa melihatnya sama sekali.
--   3. UNAPPLIED tidak diubah.
--
-- CATATAN AKSES
--   CREATE OR REPLACE FUNCTION mempertahankan ACL yang ada, jadi REVOKE dari
--   anon/PUBLIC (migration 221) tetap berlaku. Migrasi ini sengaja TIDAK
--   menambah GRANT baru — jangan tambahkan tanpa keputusan eksplisit.
-- ================================================================

CREATE OR REPLACE FUNCTION public.check_migrations(p_expected_files text[] DEFAULT NULL::text[])
RETURNS TABLE(issue_type text, detail text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_file    TEXT;
  v_version TEXT;
  v_detail  TEXT;
BEGIN
  -- 1) UNAPPLIED — berkas yang seharusnya ada tapi belum tercatat.
  IF p_expected_files IS NOT NULL THEN
    FOREACH v_file IN ARRAY p_expected_files LOOP
      IF NOT EXISTS (SELECT 1 FROM schema_migrations WHERE filename = v_file) THEN
        issue_type := 'UNAPPLIED';
        detail := v_file;
        RETURN NEXT;
      END IF;
    END LOOP;
  END IF;

  -- 2) DUPLICATE — duplikasi sungguhan: versi sama DAN slug sama.
  --    Nomor versi yang dipakai bersama berkas berbeda adalah sah (lihat header).
  FOR v_version, v_detail IN
    SELECT version, string_agg(filename, ' + ' ORDER BY filename)
    FROM schema_migrations
    GROUP BY version, regexp_replace(filename, '^[0-9]+_', '')
    HAVING count(*) > 1
  LOOP
    issue_type := 'DUPLICATE';
    detail := v_version || ' -> ' || v_detail;
    RETURN NEXT;
  END LOOP;

  -- 3) VERSION_MISMATCH — `version` harus sama dengan prefiks nomor `filename`.
  FOR v_detail IN
    SELECT filename
           || ' (tercatat versi ' || version
           || ', seharusnya ' || COALESCE(substring(filename from '^[0-9]+'), 'tanpa nomor versi')
           || ')'
    FROM schema_migrations
    WHERE version <> substring(filename from '^[0-9]+')
       OR substring(filename from '^[0-9]+') IS NULL
  LOOP
    issue_type := 'VERSION_MISMATCH';
    detail := v_detail;
    RETURN NEXT;
  END LOOP;
END;
$function$;

SELECT '224 check_migrations: DUPLICATE dipersempit + VERSION_MISMATCH ditambah' AS result;
