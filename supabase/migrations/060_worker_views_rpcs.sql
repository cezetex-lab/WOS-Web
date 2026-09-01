-- ============================================================
-- 060: Worker view RPCs — submit_idea, get_worker_badges, get_worker_referrals
-- ============================================================

-- 1. SUBMIT IDEA (worker kirim ide baru)
CREATE OR REPLACE FUNCTION submit_idea(
  p_nrp TEXT,
  p_title TEXT,
  p_description TEXT DEFAULT '',
  p_category TEXT DEFAULT 'Umum'
)
RETURNS JSONB AS $$
DECLARE v_id TEXT;
BEGIN
  v_id := 'IDE-' || EXTRACT(EPOCH FROM NOW())::TEXT;
  INSERT INTO hr_voice (id, nrp, title, description, status, votes)
  VALUES (v_id, p_nrp, p_title, p_description, 'New', 0);
  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. WORKER BADGES (lihat badge sendiri)
CREATE OR REPLACE FUNCTION get_worker_badges(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'id', b.id, 'nrp', b.nrp, 'badge_name', b.badge_name,
      'badge_type', b.badge_type, 'points', b.points,
      'awarded_at', b.awarded_at
    )), '[]'::jsonb)
    FROM hr_badges b
    WHERE b.nrp = p_nrp
    ORDER BY b.awarded_at DESC
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. WORKER CERTIFICATIONS (lihat sertifikat sendiri)
CREATE OR REPLACE FUNCTION get_worker_certifications(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'id', c.id, 'nrp', c.nrp, 'cert_name', c.cert_name,
      'issuer', c.issuer, 'issue_date', c.issue_date,
      'expiry_date', c.expiry_date, 'status', c.status
    )), '[]'::jsonb)
    FROM hr_certifications c
    WHERE c.nrp = p_nrp
    ORDER BY c.issue_date DESC
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. WORKER REFERRALS (lihat referral sendiri)
CREATE OR REPLACE FUNCTION get_worker_referrals(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'id', r.id, 'referrant_nrp', r.referrant_nrp,
      'candidate_name', r.candidate_name, 'position', r.position,
      'status', r.status, 'created_at', r.created_at
    )), '[]'::jsonb)
    FROM hr_referrals r
    WHERE r.referrant_nrp = p_nrp
    ORDER BY r.created_at DESC
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DO $$ BEGIN
  RAISE NOTICE 'Worker view RPCs created: submit_idea, get_worker_badges, get_worker_certifications, get_worker_referrals';
END $$;
