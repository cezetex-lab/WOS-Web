-- ============================================================
-- 042_wave5_missing_rpcs.sql
-- Missing RPCs for Wave 5 pages:
--   - get_performance_notes
--   - get_incentives
-- ============================================================

-- 1. GET PERFORMANCE NOTES
CREATE OR REPLACE FUNCTION get_performance_notes(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', n.id,
        'nrp', n.nrp,
        'author', n.author_nrp,
        'type', n.note_type,
        'content', n.content,
        'created_at', n.created_at
      ) ORDER BY n.created_at DESC
    ), '[]'::jsonb))
    FROM performance_notes n
    WHERE n.nrp = p_nrp OR n.author_nrp = p_nrp
    LIMIT 50
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. GET INCENTIVES
CREATE OR REPLACE FUNCTION get_incentives(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', i.id,
        'nrp', i.nrp,
        'period', i.period,
        'type', i.incentive_type,
        'amount', i.amount,
        'detail', i.detail,
        'created_at', i.created_at
      ) ORDER BY i.created_at DESC
    ), '[]'::jsonb))
    FROM incentives i
    WHERE i.nrp = p_nrp
    LIMIT 50
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Grant execute to anon and authenticated
GRANT EXECUTE ON FUNCTION get_performance_notes(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_incentives(text) TO anon, authenticated;

-- 4. RLS: ensure performance_notes is readable
ALTER TABLE performance_notes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "performance_notes_read" ON performance_notes;
CREATE POLICY "performance_notes_read" ON performance_notes FOR SELECT USING (true);

ALTER TABLE incentives ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "incentives_read" ON incentives;
CREATE POLICY "incentives_read" ON incentives FOR SELECT USING (true);
