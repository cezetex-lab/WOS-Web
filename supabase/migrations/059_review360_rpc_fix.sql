-- ============================================================
-- 059: Fix get_reviews_360 to support NRP filtering
-- ============================================================

-- Drop old version
DROP FUNCTION IF EXISTS get_reviews_360();

-- Create with optional NRP parameter
CREATE OR REPLACE FUNCTION get_reviews_360(p_nrp TEXT DEFAULT NULL)
RETURNS JSONB AS $$
BEGIN
  RETURN jsonb_build_object(
    'ok', true,
    'summary', (
      SELECT jsonb_build_object(
        'avg_leadership', COALESCE(AVG(leadership_score)::int, 0),
        'avg_communication', COALESCE(AVG(communication_score)::int, 0),
        'avg_teamwork', COALESCE(AVG(teamwork_score)::int, 0),
        'avg_innovation', COALESCE(AVG(innovation_score)::int, 0),
        'avg_overall', COALESCE(AVG(overall_score)::int, 0),
        'total_reviews', COUNT(*)::int
      )
      FROM reviews_360
      WHERE (p_nrp IS NULL OR reviewee_nrp = p_nrp)
    ),
    'reviews', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', t.id,
        'reviewee_nrp', t.reviewee_nrp,
        'reviewer_nrp', t.reviewer_nrp,
        'relationship', t.relationship,
        'leadership_score', t.leadership_score,
        'communication_score', t.communication_score,
        'teamwork_score', t.teamwork_score,
        'innovation_score', t.innovation_score,
        'overall_score', t.overall_score,
        'comments', t.comments,
        'period', t.period,
        'status', t.status
      )), '[]'::jsonb)
      FROM reviews_360 t
      WHERE (p_nrp IS NULL OR t.reviewee_nrp = p_nrp)
      ORDER BY t.created_at DESC
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DO $$ BEGIN
  RAISE NOTICE 'get_reviews_360 updated: p_nrp parameter added (NULL = all, specific NRP = filtered)';
END $$;
