-- ============================================================
-- 022: UI Fix RPC functions
-- For admin page: pending requests sub-tab + approval
-- For worker page: roster leave support
-- ============================================================

-- 1. Admin: Get pending requests (hr_requests where status='Pending')
DROP FUNCTION IF EXISTS admin_get_pending_requests();
CREATE OR REPLACE FUNCTION admin_get_pending_requests() RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', r.id,
        'nrp', r.nrp,
        'nama', COALESCE(e.nama, r.nrp),
        'type', r.request_type,
        'note', r.notes,
        'status', r.status,
        'created_at', r.created_at
      )
    ), '[]'::jsonb))
    FROM hr_requests r
    LEFT JOIN employees_master e ON r.nrp = e.nrp
    WHERE r.status = 'Pending'
    ORDER BY r.created_at DESC
  );
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Admin: Approve a pending request
DROP FUNCTION IF EXISTS admin_approve_request(TEXT);
CREATE OR REPLACE FUNCTION admin_approve_request(p_id TEXT) RETURNS JSONB AS $$
BEGIN
  UPDATE hr_requests SET status = 'Approved', reviewed_at = NOW() WHERE id = p_id;
  RETURN jsonb_build_object('ok', true, 'msg', 'Request disetujui');
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Admin: Reject a pending request
DROP FUNCTION IF EXISTS admin_reject_request(TEXT, TEXT);
CREATE OR REPLACE FUNCTION admin_reject_request(p_id TEXT, p_reason TEXT) RETURNS JSONB AS $$
BEGIN
  UPDATE hr_requests SET status = 'Rejected', review_note = p_reason, reviewed_at = NOW() WHERE id = p_id;
  RETURN jsonb_build_object('ok', true, 'msg', 'Request ditolak');
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Worker leave: include roster_leave info
DROP FUNCTION IF EXISTS get_worker_leave(TEXT);
CREATE OR REPLACE FUNCTION get_worker_leave(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE
  v_kuota NUMERIC := 12;
  v_terpakai NUMERIC;
  v_sisa NUMERIC;
  v_tahun TEXT;
  v_roster TEXT;
BEGIN
  v_tahun := TO_CHAR(NOW(), 'YYYY');
  SELECT COUNT(*) INTO v_terpakai
    FROM hr_leave WHERE nrp = p_nrp AND EXTRACT(YEAR FROM start_date) = EXTRACT(YEAR FROM NOW()) AND status = 'Approved';
  v_sisa := GREATEST(v_kuota - COALESCE(v_terpakai, 0), 0);
  -- Check if there's a roster-based leave (shift-based scheduling)
  SELECT string_agg(DISTINCT shift_name, ', ') INTO v_roster
    FROM hr_shift_master WHERE is_active = true;
  RETURN jsonb_build_object(
    'ok', true,
    'kuota', v_kuota,
    'terpakai', COALESCE(v_terpakai, 0),
    'sisa', v_sisa,
    'tahun', v_tahun,
    'roster_leave', COALESCE(v_roster, 'Tidak ada jadwal roster aktif')
  );
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Admin summary: add retiring_soon and contract_ending counts
DROP FUNCTION IF EXISTS admin_get_summary();
CREATE OR REPLACE FUNCTION admin_get_summary() RETURNS JSONB AS $$
DECLARE
  v_total NUMERIC;
  v_div NUMERIC;
  v_pend_req NUMERIC;
  v_pend_reg NUMERIC;
  v_retiring NUMERIC;
  v_contract NUMERIC;
BEGIN
  SELECT COUNT(*) INTO v_total FROM employees_master;
  SELECT COUNT(DISTINCT divisi) INTO v_div FROM employees_master;
  SELECT COUNT(*) INTO v_pend_req FROM hr_requests WHERE status = 'Pending';
  SELECT COUNT(*) INTO v_pend_reg FROM daftar_baru;
  -- Pensiun: contract ending within 6 months (approximate for PKWT)
  SELECT COUNT(*) INTO v_retiring FROM employees_master
    WHERE tanggal_akhir IS NOT NULL
    AND tanggal_akhir::date BETWEEN NOW() AND NOW() + INTERVAL '6 months';
  -- Akhir kontrak PKWT
  SELECT COUNT(*) INTO v_contract FROM employees_master
    WHERE tipe_kontrak = 'PKWT'
    AND tanggal_akhir IS NOT NULL
    AND tanggal_akhir::date BETWEEN NOW() AND NOW() + INTERVAL '3 months';
  RETURN jsonb_build_object(
    'ok', true,
    'total_workers', v_total,
    'total_divisions', v_div,
    'pending_requests', v_pend_req,
    'pending_registrations', v_pend_reg,
    'retiring_soon', v_retiring,
    'contract_ending', v_contract
  );
END; $$ LANGUAGE plpgsql SECURITY DEFINER;
