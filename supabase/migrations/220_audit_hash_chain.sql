-- ================================================================
-- 220_audit_hash_chain.sql — O5: Hash-chain audit log
--
-- Purpose:
--   Make audit_log tamper-evident by chaining rows with SHA-256 hashes.
--   Each row's hash depends on the previous row's hash, forming a
--   blockchain-like chain. Any modification to historical rows breaks
--   the chain and is detectable.
--
-- Design:
--   prev_hash: SHA-256 of the previous row (genesis row = '0')
--   row_hash:  SHA-256(id + timestamp + actor + action + detail + prev_hash)
--   BEFORE INSERT trigger: auto-compute both fields
--   verify_audit_chain(): walk chain and report broken links
-- ================================================================

-- 1. Add hash columns to audit_log
ALTER TABLE audit_log ADD COLUMN IF NOT EXISTS prev_hash TEXT;
ALTER TABLE audit_log ADD COLUMN IF NOT EXISTS row_hash TEXT;

-- 2. Trigger function: compute hash chain on INSERT
CREATE OR REPLACE FUNCTION audit_log_hash_chain()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prev_hash TEXT;
BEGIN
  -- Get the last row's hash (or '0' for genesis)
  SELECT row_hash INTO v_prev_hash
  FROM audit_log
  ORDER BY id DESC
  LIMIT 1;

  IF v_prev_hash IS NULL THEN
    v_prev_hash := '0';
  END IF;

  NEW.prev_hash := v_prev_hash;

  -- Compute this row's hash: SHA-256(id || timestamp || actor || action || detail || prev_hash)
  NEW.row_hash := encode(
    sha256(
      (COALESCE(NEW.id::TEXT, '') ||
       COALESCE(NEW.timestamp::TEXT, '') ||
       COALESCE(NEW.actor, '') ||
       COALESCE(NEW.action, '') ||
       COALESCE(NEW.detail, '') ||
       v_prev_hash)::BYTEA
    ),
    'hex'
  );

  RETURN NEW;
END;
$$;

-- 3. Create trigger
DROP TRIGGER IF EXISTS trg_audit_hash_chain ON audit_log;
CREATE TRIGGER trg_audit_hash_chain
  BEFORE INSERT ON audit_log
  FOR EACH ROW
  EXECUTE FUNCTION audit_log_hash_chain();

-- 4. Backfill existing rows (compute hashes for all 162 rows)
DO $$
DECLARE
  r RECORD;
  v_prev_hash TEXT := '0';
  v_row_hash TEXT;
BEGIN
  FOR r IN SELECT id, timestamp, actor, action, detail FROM audit_log ORDER BY id LOOP
    v_row_hash := encode(
      sha256(
        (COALESCE(r.id::TEXT, '') ||
         COALESCE(r.timestamp::TEXT, '') ||
         COALESCE(r.actor, '') ||
         COALESCE(r.action, '') ||
         COALESCE(r.detail, '') ||
         v_prev_hash)::BYTEA
      ),
      'hex'
    );

    UPDATE audit_log
    SET prev_hash = v_prev_hash,
        row_hash = v_row_hash
    WHERE id = r.id;

    v_prev_hash := v_row_hash;
  END LOOP;

  RAISE NOTICE 'Backfilled % audit_log rows with hash chain', (SELECT count(*) FROM audit_log);
END $$;

-- 5. Verification function: walk chain, detect broken links
CREATE OR REPLACE FUNCTION verify_audit_chain(
  p_start_id INTEGER DEFAULT NULL,
  p_end_id INTEGER DEFAULT NULL
)
RETURNS TABLE (
  issue_type TEXT,
  row_id INTEGER,
  detail TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prev_row_hash TEXT := '0';
  v_expected_hash TEXT;
  v_id INTEGER;
  v_ts TIMESTAMPTZ;
  v_actor TEXT;
  v_action TEXT;
  v_detail TEXT;
  v_prev TEXT;
  v_hash TEXT;
BEGIN
  FOR v_id, v_ts, v_actor, v_action, v_detail, v_prev, v_hash IN
    SELECT al.id, al.timestamp, al.actor, al.action, al.detail, al.prev_hash, al.row_hash
    FROM audit_log al
    WHERE (p_start_id IS NULL OR al.id >= p_start_id)
      AND (p_end_id IS NULL OR al.id <= p_end_id)
    ORDER BY al.id
  LOOP
    IF v_prev != v_prev_row_hash THEN
      issue_type := 'BROKEN_LINK';
      row_id := v_id;
      detail := 'prev_hash mismatch at id ' || v_id;
      RETURN NEXT;
    END IF;
    v_expected_hash := encode(
      sha256(
        (COALESCE(v_id::TEXT, '') ||
         COALESCE(v_ts::TEXT, '') ||
         COALESCE(v_actor, '') ||
         COALESCE(v_action, '') ||
         COALESCE(v_detail, '') ||
         v_prev)::BYTEA
      ),
      'hex'
    );
    IF v_hash != v_expected_hash THEN
      issue_type := 'TAMPERED';
      row_id := v_id;
      detail := 'row_hash mismatch at id ' || v_id;
      RETURN NEXT;
    END IF;
    v_prev_row_hash := v_hash;
  END LOOP;
END;
$$;

-- 6. Grant verify to authenticated (read-only check)
GRANT EXECUTE ON FUNCTION verify_audit_chain TO authenticated;

-- 7. Post-verify: run chain check
-- SELECT count(*) AS total_issues FROM verify_audit_chain();
