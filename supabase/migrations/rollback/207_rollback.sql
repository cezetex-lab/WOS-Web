-- ================================================================
-- rollback/207_rollback.sql — Rollback migration 207
-- Mengembalikan search_path=public (TANPA extensions) pada fungsi
-- yang ditemukan forensic report §1. HANYA menyentuh SECDEF functions
-- yang kini punya extensions (idempotent-guard per fungsi).
-- ================================================================

DO $$
DECLARE
  r RECORD;
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
        WHERE c LIKE 'search_path=%extensions%'
      )
  LOOP
    BEGIN
      EXECUTE format(
        'ALTER FUNCTION %I(%s) SET search_path = public',
        r.proname, r.args
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE LOG 'rb207: skip %: %', r.proname, SQLERRM;
    END;
  END LOOP;
END $$;

-- Verify: fungsi sasaran kembali tanpa extensions
SELECT 'rb207.1 SECDEF without extensions in search_path' AS test,
  count(*)::text AS result
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prosecdef = true
  AND p.prokind = 'f'
  AND (p.proconfig IS NULL OR NOT EXISTS (
    SELECT 1 FROM unnest(p.proconfig) c WHERE c LIKE 'search_path=%extensions%'
  ));
