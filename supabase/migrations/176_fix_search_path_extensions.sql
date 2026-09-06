-- ================================================================
-- 176_fix_search_path_extensions.sql
--
-- Root cause: 23 functions have search_path = public (without extensions)
-- but call gen_random_bytes/crypt/digest from the extensions schema.
-- Fix: add 'extensions' to their search_path.
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
      AND p.proconfig IS NOT NULL
      AND EXISTS (SELECT 1 FROM unnest(p.proconfig) c WHERE c LIKE 'search_path=%')
      AND NOT EXISTS (SELECT 1 FROM unnest(p.proconfig) c WHERE c LIKE 'search_path=%extensions%')
  LOOP
    BEGIN
      EXECUTE format(
        'ALTER FUNCTION %I(%s) SET search_path = public, extensions',
        r.proname, r.args
      );
      v_count := v_count + 1;
    EXCEPTION WHEN OTHERS THEN
      RAISE LOG '176: skip %: %', r.proname, SQLERRM;
    END;
  END LOOP;

  RAISE NOTICE '176: Added extensions to search_path on % functions', v_count;
END $$;

-- Verify: all SECDEF functions should now have extensions in search_path
SELECT 'VERIFY: SECDEF without extensions in search_path' AS test,
  (SELECT count(*)::text
   FROM pg_proc p
   JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.prosecdef = true
     AND p.prokind = 'f'
     AND (p.proconfig IS NULL OR NOT EXISTS (
       SELECT 1 FROM unnest(p.proconfig) c WHERE c LIKE 'search_path=%extensions%'
     ))
  ) AS remaining;
