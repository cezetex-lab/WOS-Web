-- ================================================================
-- 219_schema_versioning.sql — A7: Migration Versioning System
--
-- Purpose:
--   Track applied migrations with version + checksum.
--   Detect unapplied / duplicate / tampered migrations.
--   Enable startup check before app initializes.
--
-- Components:
--   1. schema_migrations table
--   2. apply_migration() — register a migration with checksum
--   3. check_migrations() — detect unapplied/duplicate
--   4. verify_migration_checksum() — detect tampering
-- ================================================================

-- 1. Schema migrations tracking table
CREATE TABLE IF NOT EXISTS schema_migrations (
  id            SERIAL PRIMARY KEY,
  version       TEXT NOT NULL,              -- e.g. '219' or '219_schema_versioning'
  filename      TEXT NOT NULL UNIQUE,       -- e.g. '219_schema_versioning.sql'
  checksum      TEXT NOT NULL,              -- SHA-256 of file content
  applied_at    TIMESTAMPTZ DEFAULT now(),
  applied_by    TEXT DEFAULT current_user,
  execution_ms  INTEGER,                    -- how long it took (optional)
  description   TEXT                        -- human-readable note
);

COMMENT ON TABLE schema_migrations IS 'Tracks all applied DB migrations (A7 versioning system)';

-- Index for fast lookup
-- Note: version unique index removed — multiple files can share a version number
-- (e.g. 176_fix_search_path + 176_original). Filename is the true unique key.
CREATE INDEX IF NOT EXISTS idx_schema_migrations_filename ON schema_migrations (filename);

-- 2. Function: register a migration after successful apply
CREATE OR REPLACE FUNCTION apply_migration(
  p_version TEXT,
  p_filename TEXT,
  p_checksum TEXT,
  p_description TEXT DEFAULT NULL,
  p_execution_ms INTEGER DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check for duplicate version
  IF EXISTS (SELECT 1 FROM schema_migrations WHERE version = p_version) THEN
    RAISE WARNING 'Migration version % already applied', p_version;
    RETURN FALSE;
  END IF;

  -- Check for duplicate filename
  IF EXISTS (SELECT 1 FROM schema_migrations WHERE filename = p_filename) THEN
    RAISE WARNING 'Migration file % already applied', p_filename;
    RETURN FALSE;
  END IF;

  INSERT INTO schema_migrations (version, filename, checksum, description, execution_ms)
  VALUES (p_version, p_filename, p_checksum, p_description, p_execution_ms);

  RETURN TRUE;
END;
$$;

-- 3. Function: check for unapplied / duplicate migrations
--    Input: list of expected migration filenames (text[])
--    Returns: table of issues
CREATE OR REPLACE FUNCTION check_migrations(p_expected_files TEXT[] DEFAULT NULL)
RETURNS TABLE (
  issue_type TEXT,       -- 'UNAPPLIED', 'DUPLICATE', 'ORPHANED'
  detail TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_file TEXT;
  v_count BIGINT;
BEGIN
  -- If expected files provided, check for unapplied
  IF p_expected_files IS NOT NULL THEN
    FOREACH v_file IN ARRAY p_expected_files LOOP
      IF NOT EXISTS (SELECT 1 FROM schema_migrations WHERE filename = v_file) THEN
        issue_type := 'UNAPPLIED';
        detail := v_file;
        RETURN NEXT;
      END IF;
    END LOOP;
  END IF;

  -- Check for duplicate versions
  FOR v_count, v_file IN
    SELECT count(*), version
    FROM schema_migrations
    GROUP BY version
    HAVING count(*) > 1
  LOOP
    issue_type := 'DUPLICATE';
    detail := v_file || ' (x' || v_count || ')';
    RETURN NEXT;
  END LOOP;

  -- Check for orphaned entries (applied but file missing — informational)
  -- This requires file system access, so we skip it in SQL
  -- Use the Python checker script instead for full validation
END;
$$;

-- 4. Function: verify checksum hasn't been tampered
CREATE OR REPLACE FUNCTION verify_migration_checksum(
  p_filename TEXT,
  p_expected_checksum TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_stored TEXT;
BEGIN
  SELECT checksum INTO v_stored
  FROM schema_migrations
  WHERE filename = p_filename;

  IF v_stored IS NULL THEN
    RAISE WARNING 'Migration % not found in schema_migrations', p_filename;
    RETURN FALSE;
  END IF;

  IF v_stored != p_expected_checksum THEN
    RAISE WARNING 'Checksum mismatch for %: expected %, got %', p_filename, p_expected_checksum, v_stored;
    RETURN FALSE;
  END IF;

  RETURN TRUE;
END;
$$;

-- 5. Grant execute to authenticated (for startup check)
GRANT EXECUTE ON FUNCTION check_migrations TO authenticated;
GRANT EXECUTE ON FUNCTION verify_migration_checksum TO authenticated;

-- 6. Auto-apply this migration itself
SELECT apply_migration(
  '219',
  '219_schema_versioning.sql',
  encode(sha256(current_setting('search_path')::bytea), 'hex'),  -- placeholder; real checksum set by applier
  'A7: schema_migrations table + helper functions'
);

-- ================================================================
-- Post-verify: table exists, functions exist
-- ================================================================
-- SELECT table_name FROM information_schema.tables WHERE table_name = 'schema_migrations';
-- SELECT routine_name FROM information_schema.routines WHERE routine_name IN ('apply_migration','check_migrations','verify_migration_checksum');
