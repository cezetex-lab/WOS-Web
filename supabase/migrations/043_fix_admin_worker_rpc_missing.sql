-- ============================================================
-- 043_fix_admin_worker_rpc_missing.sql
-- Fix 10 missing/broken RPCs from console errors
-- ============================================================

-- 1. admin_get_master_data (roles + org overview for admin settings)
CREATE OR REPLACE FUNCTION admin_get_master_data()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true,
      'roles', (SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'nrp', ur.nrp, 'role', ur.role, 'tier', ur.tier, 'created_at', ur.created_at
      ) ORDER BY ur.created_at DESC), '[]'::jsonb) FROM user_roles ur LIMIT 100),
      'divisions', (SELECT COALESCE(jsonb_agg(DISTINCT jsonb_build_object(
        'divisi', o.divisi
      )), '[]'::jsonb) FROM hr_org o WHERE o.divisi IS NOT NULL)
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. get_overtime_data (worker overtime requests)
CREATE OR REPLACE FUNCTION get_overtime_data(p_nrp TEXT DEFAULT NULL)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', r.id, 'nrp', r.nrp, 'type', r.type, 'status', r.status,
        'note', r.note, 'created_at', r.created_at
      ) ORDER BY r.created_at DESC
    ), '[]'::jsonb))
    FROM hr_requests r
    WHERE r.type ILIKE '%overtime%' OR r.type ILIKE '%lembur%'
    AND (p_nrp IS NULL OR r.nrp = p_nrp)
    LIMIT 50
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. get_worker_learning (worker's training/learning data)
CREATE OR REPLACE FUNCTION get_worker_learning(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', l.id, 'nrp', l.nrp, 'course', l.course_name, 'status', l.status,
        'score', l.score, 'completed_at', l.completed_at, 'created_at', l.created_at
      ) ORDER BY l.created_at DESC
    ), '[]'::jsonb))
    FROM hr_learning l
    WHERE l.nrp = p_nrp
    LIMIT 30
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. get_skills_intelligence (skills gap analysis)
CREATE OR REPLACE FUNCTION get_skills_intelligence(p_nrp TEXT DEFAULT NULL)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', s.id, 'nrp', s.nrp, 'skill', s.skill_name, 'level', s.level,
        'target_level', s.target_level, 'gap', CASE WHEN s.target_level > s.level THEN s.target_level - s.level ELSE 0 END
      ) ORDER BY s.id
    ), '[]'::jsonb))
    FROM hr_skills s
    WHERE (p_nrp IS NULL OR s.nrp = p_nrp)
    LIMIT 50
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. get_career_path (career progression recommendations)
CREATE OR REPLACE FUNCTION get_career_path(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', tc.id, 'current_position', tc.current_position,
        'next_position', tc.next_position, 'required_skills', tc.required_skills,
        'timeline_months', tc.timeline_months
      ) ORDER BY tc.id
    ), '[]'::jsonb))
    FROM hr_talent_catalog tc
    LIMIT 20
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. get_worker_engagement (engagement scores)
CREATE OR REPLACE FUNCTION get_worker_engagement(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', e.id, 'nrp', e.nrp, 'score', e.score, 'period', e.period,
        'created_at', e.created_at
      ) ORDER BY e.created_at DESC
    ), '[]'::jsonb))
    FROM hr_engagement e
    WHERE e.nrp = p_nrp
    LIMIT 12
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. list_ideas (innovation/ideas from workers)
CREATE OR REPLACE FUNCTION list_ideas()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', v.id, 'nrp', v.nrp, 'title', v.title, 'description', v.description,
        'votes', v.votes, 'status', v.status, 'created_at', v.created_at
      ) ORDER BY v.created_at DESC
    ), '[]'::jsonb))
    FROM hr_voice v
    LIMIT 50
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. get_exit_clearance (offboarding checklist)
CREATE OR REPLACE FUNCTION get_exit_clearance(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', ec.id, 'nrp', ec.nrp, 'step', ec.step, 'status', ec.status,
        'completed_at', ec.completed_at, 'notes', ec.notes
      ) ORDER BY ec.id
    ), '[]'::jsonb))
    FROM hr_exit_clearance ec
    WHERE ec.nrp = p_nrp
    LIMIT 20
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. admin_get_budget (budget/finance overview)
CREATE OR REPLACE FUNCTION admin_get_budget()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', f.id, 'category', f.category, 'amount', f.amount,
        'period', f.period, 'status', f.status
      ) ORDER BY f.id DESC
    ), '[]'::jsonb))
    FROM (
      SELECT id, category, amount, period, status, created_at
      FROM hr_finance_kpi
      ORDER BY created_at DESC
      LIMIT 30
    ) f
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10. Fix admin_get_timesheet GROUP BY error
CREATE OR REPLACE FUNCTION admin_get_timesheet()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'nrp', sub.nrp, 'date', sub.date, 'check_in', sub.check_in,
        'check_out', sub.check_out, 'status', sub.status, 'hours', sub.hours
      )
    ), '[]'::jsonb))
    FROM (
      SELECT a.nrp, a.date, a.check_in, a.check_out, a.status,
        ROUND(EXTRACT(EPOCH FROM (a.check_out - a.check_in)) / 3600, 1) as hours
      FROM hr_attendance a
      ORDER BY a.date DESC
      LIMIT 100
    ) sub
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 11. Fix user_roles query (ensure RLS allows read)
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "user_roles_read" ON user_roles;
CREATE POLICY "user_roles_read" ON user_roles FOR SELECT USING (true);

-- Grant execute
GRANT EXECUTE ON FUNCTION admin_get_master_data() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_overtime_data(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_worker_learning(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_skills_intelligence(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_career_path(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_worker_engagement(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION list_ideas() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_exit_clearance(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION admin_get_budget() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION admin_get_timesheet() TO anon, authenticated;
