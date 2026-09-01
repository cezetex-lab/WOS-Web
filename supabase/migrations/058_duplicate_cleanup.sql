-- ============================================================
-- 058: DUPLICATE CLEANUP
-- Phase 1: Remove duplicate tables + deprecated RPCs + fix missing RPCs
-- ============================================================
-- SAFE: Uses IF EXISTS/IF NOT EXISTS everywhere
-- ROLLBACK: Re-run migrations 018, 019, 025, 045, 050

-- ============================================================
-- 1. MIGRATE DATA: okrs → hr_okrs
-- ============================================================
DO $$
DECLARE v_old INT; v_new INT;
BEGIN
  SELECT COUNT(*) INTO v_old FROM okrs;
  SELECT COUNT(*) INTO v_new FROM hr_okrs;
  IF v_old > 0 AND v_new = 0 THEN
    INSERT INTO hr_okrs (nrp, objective, periode, status)
    SELECT DISTINCT ON (nrp, objective)
      nrp, COALESCE(objective, 'OKR ' || period),
      COALESCE(period, '2026-Q1'), COALESCE(status, 'In Progress')
    FROM okrs ON CONFLICT DO NOTHING;
    RAISE NOTICE 'Migrated % okr records to hr_okrs', v_old;
  ELSE
    RAISE NOTICE 'Skipping okrs: old=% new=%', v_old, v_new;
  END IF;
END $$;

-- ============================================================
-- 2. MIGRATE DATA: surveys → hr_surveys
-- ============================================================
DO $$
DECLARE v_old INT; v_new INT;
BEGIN
  SELECT COUNT(*) INTO v_old FROM surveys;
  SELECT COUNT(*) INTO v_new FROM hr_surveys;
  IF v_old > 0 AND v_new = 0 THEN
    INSERT INTO hr_surveys (title, questions, status)
    SELECT title,
      COALESCE(
        CASE WHEN description IS NOT NULL
          THEN jsonb_build_object('description', description, 'type', survey_type)
          ELSE NULL END, '[]'::jsonb),
      LOWER(COALESCE(status, 'active'))
    FROM surveys ON CONFLICT DO NOTHING;
    RAISE NOTICE 'Migrated % surveys to hr_surveys', v_old;
  ELSE
    RAISE NOTICE 'Skipping surveys: old=% new=%', v_old, v_new;
  END IF;
END $$;

-- ============================================================
-- 3. MIGRATE DATA: review_360 → reviews_360
-- ============================================================
-- review_360 (old): nrp, reviewer_nrp, period, score, feedback
-- reviews_360 (new): reviewee_nrp, reviewer_nrp, period, category, leadership_score, communication_score, teamwork_score, innovation_score, overall_score, comments
DO $$
DECLARE v_old INT; v_new INT;
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'review_360') THEN
    SELECT COUNT(*) INTO v_old FROM review_360;
    SELECT COUNT(*) INTO v_new FROM reviews_360;
    IF v_old > 0 AND v_new = 0 THEN
      INSERT INTO reviews_360 (reviewee_nrp, reviewer_nrp, period, overall_score, comments)
      SELECT nrp, reviewer_nrp, period, score, feedback
      FROM review_360 ON CONFLICT DO NOTHING;
      RAISE NOTICE 'Migrated % review_360 to reviews_360', v_old;
    ELSE
      RAISE NOTICE 'Skipping review_360: old=% new=%', v_old, v_new;
    END IF;
  ELSE
    RAISE NOTICE 'review_360 table does not exist — skipping';
  END IF;
END $$;

-- ============================================================
-- 4. DROP DEPRECATED RPCs (not used by frontend)
-- ============================================================

-- Old OKR RPC (reads from okrs table — now dropped)
DROP FUNCTION IF EXISTS get_okrs(TEXT);

-- Old Survey RPC (reads from surveys table — now dropped)
DROP FUNCTION IF EXISTS get_surveys();

-- Duplicate health RPCs — frontend uses neither (dashboard uses get_dashboard_stats)
DROP FUNCTION IF EXISTS get_org_health();
DROP FUNCTION IF EXISTS get_organization_health();

-- Deprecated — frontend uses get_early_warning instead
DROP FUNCTION IF EXISTS get_worker_critical(TEXT);

-- Old pending RPC — frontend uses admin_get_pending_requests
DROP FUNCTION IF EXISTS admin_get_pending();

-- Old review_360 RPC (singular, old table) — frontend calls get_reviews_360 (plural)
DROP FUNCTION IF EXISTS get_review_360(TEXT);

-- ============================================================
-- 5. CREATE MISSING RPC: get_reviews_360
-- ============================================================
-- Review360.jsx calls get_reviews_360 but it doesn't exist yet
CREATE OR REPLACE FUNCTION get_reviews_360()
RETURNS JSONB AS $$
BEGIN
  RETURN (
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
    ORDER BY t.created_at DESC
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 6. DROP DUPLICATE TABLES
-- ============================================================

-- Old okrs table (data migrated to hr_okrs above)
DROP TABLE IF EXISTS okrs CASCADE;

-- Old surveys table (data migrated to hr_surveys above)
DROP TABLE IF EXISTS surveys CASCADE;

-- Old review_360 table (data migrated to reviews_360 above)
DROP TABLE IF EXISTS review_360 CASCADE;

-- ============================================================
-- 7. KEEP CANONICAL TABLES
-- ============================================================
-- hr_okrs       — OKR management (canonical)
-- hr_surveys    — Survey management (canonical)
-- reviews_360   — 360° reviews (canonical, rich schema)
-- onboarding_tasks — kept from 050 (canonical, already recreated)
-- webhook_logs  — kept from 045 (canonical, IF NOT EXISTS)

-- ============================================================
-- 8. VERIFICATION
-- ============================================================
DO $$
BEGIN
  RAISE NOTICE '=== PHASE 1: DUPLICATE CLEANUP COMPLETE ===';
  RAISE NOTICE 'Tables DROPPED: okrs, surveys, review_360';
  RAISE NOTICE 'Tables KEPT: hr_okrs, hr_surveys, reviews_360, onboarding_tasks, webhook_logs';
  RAISE NOTICE 'RPCs DROPPED: get_okrs, get_surveys, get_org_health, get_organization_health, get_worker_critical, admin_get_pending, get_review_360';
  RAISE NOTICE 'RPCs CREATED: get_reviews_360';
  RAISE NOTICE 'Frontend RPCs unaffected: admin_get_pending_requests, get_early_warning, get_estate_blocks, admin_get_estate_blocks';
END $$;
