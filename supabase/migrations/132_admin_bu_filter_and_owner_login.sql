-- ============================================================
-- Migration 132: Admin BU filter + owner_login security fix
-- ============================================================

-- P1-1: Fix owner_login — add auth.uid() check
CREATE OR REPLACE FUNCTION owner_login(p_email TEXT)
RETURNS JSONB AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_is_owner BOOLEAN;
BEGIN
  -- SECURITY FIX: Validate auth.uid() against system_owner_identity
  SELECT EXISTS (
    SELECT 1 FROM system_owner_identity
    WHERE auth_id = v_uid AND is_active = TRUE
  ) INTO v_is_owner;

  IF NOT v_is_owner THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akun owner tidak ditemukan atau tidak aktif');
  END IF;

  -- Also verify the email matches
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = v_uid AND email = p_email) THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Email tidak sesuai dengan akun login');
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'nrp', 'OWNER001',
    'nama', 'System Owner',
    'role', 'owner',
    'role_level', 5,
    'is_owner', true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION owner_login(TEXT) TO authenticated;

-- P0-3: Add BU filter helper for admin RPCs
CREATE OR REPLACE FUNCTION _get_admin_bu_filter()
RETURNS TEXT AS $$
  SELECT business_unit_id FROM employees_master WHERE auth_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION _get_admin_bu_filter() TO authenticated;

-- Fix admin_get_summary: add BU filter for non-pusat admins
CREATE OR REPLACE FUNCTION admin_get_summary()
RETURNS JSONB AS $$
DECLARE
  v_caller TEXT := _get_caller_nrp();
  v_is_admin BOOLEAN := _is_admin_or_owner_caller();
  v_bu TEXT := _get_admin_bu_filter();
  v_is_pusat BOOLEAN;
  v_result JSONB;
BEGIN
  IF NOT v_is_admin THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Admin access required.');
  END IF;

  -- Check if caller is admin_pusat or owner (sees all)
  SELECT role IN ('admin_pusat', 'owner') INTO v_is_pusat
  FROM user_roles WHERE nrp = v_caller;

  IF v_is_pusat THEN
    -- Admin pusat sees all
    SELECT jsonb_build_object(
      'ok', true,
      'total_employees', (SELECT COUNT(*) FROM employees_master),
      'mining_count', (SELECT COUNT(*) FROM employees_master WHERE business_unit_id = 'MINING'),
      'estate_count', (SELECT COUNT(*) FROM employees_master WHERE business_unit_id = 'ESTATE'),
      'mill_count', (SELECT COUNT(*) FROM employees_master WHERE business_unit_id = 'MILL'),
      'hq_count', (SELECT COUNT(*) FROM employees_master WHERE business_unit_id = 'HQ'),
      'high_performers', (SELECT COUNT(*) FROM hr_performance WHERE kpi_score >= 80),
      'low_performers', (SELECT COUNT(*) FROM hr_performance WHERE kpi_score < 60),
      'pending_requests', (SELECT COUNT(*) FROM hr_requests WHERE status = 'Pending'),
      'retiring_soon', (SELECT COUNT(*) FROM employees_master WHERE status_kerja = 'PKWT' AND tanggal_keluar IS NOT NULL AND tanggal_keluar < NOW() + INTERVAL '90 days')
    ) INTO v_result;
  ELSE
    -- Functional/industry admin sees only their BU
    SELECT jsonb_build_object(
      'ok', true,
      'total_employees', (SELECT COUNT(*) FROM employees_master WHERE business_unit_id = v_bu),
      'mining_count', (SELECT COUNT(*) FROM employees_master WHERE business_unit_id = 'MINING' AND (v_bu = 'MINING' OR v_bu IS NULL)),
      'estate_count', (SELECT COUNT(*) FROM employees_master WHERE business_unit_id = 'ESTATE' AND (v_bu = 'ESTATE' OR v_bu IS NULL)),
      'mill_count', (SELECT COUNT(*) FROM employees_master WHERE business_unit_id = 'MILL' AND (v_bu = 'MILL' OR v_bu IS NULL)),
      'hq_count', (SELECT COUNT(*) FROM employees_master WHERE business_unit_id = 'HQ' AND (v_bu = 'HQ' OR v_bu IS NULL)),
      'high_performers', (SELECT COUNT(*) FROM hr_performance hp JOIN employees_master em ON hp.nrp = em.nrp WHERE hp.kpi_score >= 80 AND em.business_unit_id = v_bu),
      'low_performers', (SELECT COUNT(*) FROM hr_performance hp JOIN employees_master em ON hp.nrp = em.nrp WHERE hp.kpi_score < 60 AND em.business_unit_id = v_bu),
      'pending_requests', (SELECT COUNT(*) FROM hr_requests hr JOIN employees_master em ON hr.nrp = em.nrp WHERE hr.status = 'Pending' AND em.business_unit_id = v_bu),
      'retiring_soon', 0
    ) INTO v_result;
  END IF;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION admin_get_summary() TO authenticated;
