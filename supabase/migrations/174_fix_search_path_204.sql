-- ================================================================
-- 174_fix_search_path_204.sql — Hardening search_path
--
-- Audit finding 3.4: 204 fungsi SECURITY DEFINER tanpa SET search_path
-- rentan terhadap search_path hijacking.
--
-- Fix: ALTER FUNCTION ... SET search_path = public, extensions
-- (extensions diperlukan untuk pgcrypto: crypt, digest, gen_salt)
--
-- Idempotent: aman dijalankan berulang.
-- ================================================================

-- Fix semua fungsi SECURITY DEFINER di public schema yang belum punya search_path
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
      AND (p.proconfig IS NULL OR NOT EXISTS (
        SELECT 1 FROM unnest(p.proconfig) c WHERE c LIKE 'search_path=%'
      ))
  LOOP
    BEGIN
      EXECUTE format(
        'ALTER FUNCTION %I(%s) SET search_path = public, extensions',
        r.proname, r.args
      );
      v_count := v_count + 1;
    EXCEPTION WHEN OTHERS THEN
      RAISE LOG '174: skip %: %', r.proname, SQLERRM;
    END;
  END LOOP;

  RAISE NOTICE '174: Fixed search_path on % SECURITY DEFINER functions', v_count;
END $$;

-- Verify: fungsi SECURITY DEFINER tanpa search_path harusnya 0
SELECT 'VERIFY: SECDEF without search_path' AS test,
  (SELECT count(*)::text
   FROM pg_proc p
   JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.prosecdef = true
     AND p.prokind = 'f'
     AND (p.proconfig IS NULL OR NOT EXISTS (
       SELECT 1 FROM unnest(p.proconfig) c WHERE c LIKE 'search_path=%'
     ))
  ) AS remaining_count;
