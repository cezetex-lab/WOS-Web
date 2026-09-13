-- ================================================================
-- 207_fix_search_path_strays.sql — F-8 residual / forensic §1 finding:
-- 8 SECURITY DEFINER functions masih `search_path=public` (TANPA extensions)
-- → pelanggaran Rule §3.3 (SECDEF wajib SET search_path incl. extensions).
--
-- Bukti live (pre-flight 2026-09-13): count SECDEF tanpa extensions = 8.
-- Daftar: cleanup_rate_limits, get_fatigue_data, get_heavy_equipment,
--         get_jsa_list, get_production_daily, get_safety_incidents,
--         get_simper_list, hit_rate_limit.
--
-- Migrasi 174/176 loop-nya skip fungsi yang proconfig SUDAH punya
-- search_path (walau tanpa extensions) → 8 ini tidak tersentuh.
-- Fix: loop yang menargetkan SECDEF dengan search_path TIDAK mengandung
-- 'extensions' (apapun nilainya), lalu set `search_path = public, extensions`.
-- Idempotent: aman dijalankan berulang (kondisi jadi false setelah fix).
--
-- Rollback: supabase/migrations/rollback/207_rollback.sql
-- ================================================================

DO $$
DECLARE
  r RECORD;
  v_count INT := 0;
BEGIN
  FOR r IN
    SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prosecdef = true
      AND p.prokind = 'f'
      AND EXISTS (
        SELECT 1 FROM unnest(p.proconfig) c
        WHERE c LIKE 'search_path=%' AND c NOT LIKE '%extensions%'
      )
  LOOP
    BEGIN
      EXECUTE format(
        'ALTER FUNCTION %I(%s) SET search_path = public, extensions',
        r.proname, r.args
      );
      v_count := v_count + 1;
      RAISE LOG '207: fixed search_path on %', r.proname;
    EXCEPTION WHEN OTHERS THEN
      RAISE LOG '207: skip %: %', r.proname, SQLERRM;
    END;
  END LOOP;

  RAISE NOTICE '207: fixed search_path on % SECURITY DEFINER functions', v_count;
END $$;

-- Verify: harus 0
SELECT '207.1 SECDEF without extensions in search_path' AS test,
  CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL: ' || count(*) END AS result
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prosecdef = true
  AND p.prokind = 'f'
  AND (p.proconfig IS NULL OR NOT EXISTS (
    SELECT 1 FROM unnest(p.proconfig) c WHERE c LIKE 'search_path=%extensions%'
  ));

-- Verify: 8 fungsi sasaran kini punya extensions
SELECT '207.2 target functions fixed' AS test,
  count(*)::text AS result
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('cleanup_rate_limits','get_fatigue_data','get_heavy_equipment',
                    'get_jsa_list','get_production_daily','get_safety_incidents',
                    'get_simper_list','hit_rate_limit')
  AND EXISTS (SELECT 1 FROM unnest(p.proconfig) c WHERE c LIKE 'search_path=%extensions%');
