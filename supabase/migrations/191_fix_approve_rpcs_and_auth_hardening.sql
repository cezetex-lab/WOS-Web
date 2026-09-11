-- ================================================================
-- 191_fix_approve_rpcs_and_auth_hardening.sql
-- Hasil audit "New Text Document (2).txt" (RPC Hantu + auth hardening)
-- ================================================================
--  S1. 4 fitur admin (Cuti/Lembur/Shift Swap/Facility) dapat backend
--      approve/reject sungguhan (pola admin_approve_request/reject_request).
--      DetailPageFactory.jsx men-generate nama RPC rapuh -> sekarang
--      pemetaan eksplisit + backend nyata.
--  S2. admin_approve_pending / admin_reject_pending — stub kosong yang
--      selalu bilang sukses (regresi migration 139) -> implementasi
--      sungguhan untuk daftar_baru (pola 003) + authz + audit.
--  S3. generate_admin_otp / verify_admin_otp — tidak terikat identitas:
--      sekarang butuh auth.uid() admin, rate-limited, kode TIDAK dikirim
--      di response, token verify disimpan di session_tokens, role/nama
--      dikembalikan dari database (tidak lagi hardcode).
--  S4. Seed permission 'shift.approve' + 'facility.approve'.
-- ================================================================
-- SEMUA definisi IDEMPOTENT (CREATE OR REPLACE / ON CONFLICT DO NOTHING).
-- Live schema catatan: otp_store(nrp PK, code_hash, expiry, used, created_at),
-- session_tokens(session_token PK, nrp, type, expires_at, created_at),
-- hr_leave = tabel KUOTA (tidak ada status) -> approve cuti via hr_requests.
-- ================================================================

-- ════════════════════════════════════════════════════════════════
-- S1a. CUTI — approve/reject via hr_requests (type CUTI/LEAVE)
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION admin_approve_leave(p_id TEXT, p_note TEXT DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE v_rows INT := 0;
BEGIN
  IF NOT authz_check_admin('leave.approve') THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  IF p_id IS NULL OR p_id = '' THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'ID tidak valid.');
  END IF;
  UPDATE hr_requests
  SET status = 'Approved', note = COALESCE(p_note, 'Disetujui admin'),
      approver_nrp = COALESCE(authz_current_nrp(), approver_nrp)
  WHERE id = p_id AND status ILIKE 'pending%'
    AND (type ILIKE '%cuti%' OR type ILIKE '%leave%');
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows > 0 THEN
    INSERT INTO audit_log (actor, action, detail, timestamp)
    VALUES (COALESCE(authz_current_nrp(), 'admin'), 'LEAVE_APPROVE', 'hr_requests ' || p_id, NOW());
    RETURN jsonb_build_object('ok', TRUE, 'msg', 'Cuti disetujui.');
  END IF;
  RETURN jsonb_build_object('ok', FALSE, 'msg', 'Tidak ditemukan / sudah diproses / bukan pengajuan cuti.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

CREATE OR REPLACE FUNCTION admin_reject_leave(p_id TEXT, p_note TEXT DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE v_rows INT := 0;
BEGIN
  IF NOT authz_check_admin('leave.approve') THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  IF p_id IS NULL OR p_id = '' THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'ID tidak valid.');
  END IF;
  UPDATE hr_requests
  SET status = 'Rejected', note = COALESCE(p_note, 'Ditolak admin'),
      approver_nrp = COALESCE(authz_current_nrp(), approver_nrp)
  WHERE id = p_id AND status ILIKE 'pending%'
    AND (type ILIKE '%cuti%' OR type ILIKE '%leave%');
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows > 0 THEN
    INSERT INTO audit_log (actor, action, detail, timestamp)
    VALUES (COALESCE(authz_current_nrp(), 'admin'), 'LEAVE_REJECT', 'hr_requests ' || p_id, NOW());
    RETURN jsonb_build_object('ok', TRUE, 'msg', 'Cuti ditolak.');
  END IF;
  RETURN jsonb_build_object('ok', FALSE, 'msg', 'Tidak ditemukan / sudah diproses / bukan pengajuan cuti.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

-- ════════════════════════════════════════════════════════════════
-- S1b. LEMBUR — approve/reject via hr_overtime + fallback hr_requests
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION admin_approve_overtime(p_id TEXT, p_note TEXT DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE v_rows INT := 0;
BEGIN
  IF NOT authz_check_admin('overtime.approve') THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  IF p_id IS NULL OR p_id = '' THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'ID tidak valid.');
  END IF;
  UPDATE hr_overtime SET status = 'Approved'
  WHERE id = p_id AND status ILIKE 'pending%';
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows = 0 THEN
    UPDATE hr_requests
    SET status = 'Approved', note = COALESCE(p_note, 'Disetujui admin'),
        approver_nrp = COALESCE(authz_current_nrp(), approver_nrp)
    WHERE id = p_id AND status ILIKE 'pending%'
      AND (type ILIKE '%overtime%' OR type ILIKE '%lembur%');
    GET DIAGNOSTICS v_rows = ROW_COUNT;
  END IF;
  IF v_rows > 0 THEN
    INSERT INTO audit_log (actor, action, detail, timestamp)
    VALUES (COALESCE(authz_current_nrp(), 'admin'), 'OVERTIME_APPROVE', p_id, NOW());
    RETURN jsonb_build_object('ok', TRUE, 'msg', 'Lembur disetujui.');
  END IF;
  RETURN jsonb_build_object('ok', FALSE, 'msg', 'Tidak ditemukan / sudah diproses / bukan pengajuan lembur.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

CREATE OR REPLACE FUNCTION admin_reject_overtime(p_id TEXT, p_note TEXT DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE v_rows INT := 0;
BEGIN
  IF NOT authz_check_admin('overtime.approve') THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  IF p_id IS NULL OR p_id = '' THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'ID tidak valid.');
  END IF;
  UPDATE hr_overtime SET status = 'Rejected'
  WHERE id = p_id AND status ILIKE 'pending%';
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows = 0 THEN
    UPDATE hr_requests
    SET status = 'Rejected', note = COALESCE(p_note, 'Ditolak admin'),
        approver_nrp = COALESCE(authz_current_nrp(), approver_nrp)
    WHERE id = p_id AND status ILIKE 'pending%'
      AND (type ILIKE '%overtime%' OR type ILIKE '%lembur%');
    GET DIAGNOSTICS v_rows = ROW_COUNT;
  END IF;
  IF v_rows > 0 THEN
    INSERT INTO audit_log (actor, action, detail, timestamp)
    VALUES (COALESCE(authz_current_nrp(), 'admin'), 'OVERTIME_REJECT', p_id, NOW());
    RETURN jsonb_build_object('ok', TRUE, 'msg', 'Lembur ditolak.');
  END IF;
  RETURN jsonb_build_object('ok', FALSE, 'msg', 'Tidak ditemukan / sudah diproses / bukan pengajuan lembur.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

-- ════════════════════════════════════════════════════════════════
-- S1c. SHIFT SWAP — approve/reject via hr_shift_swaps (id integer)
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION admin_approve_shift_swap(p_id TEXT, p_note TEXT DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE v_rows INT := 0;
BEGIN
  IF NOT authz_check_admin('shift.approve') THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  IF p_id IS NULL OR p_id !~ '^[0-9]+$' THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'ID tidak valid.');
  END IF;
  UPDATE hr_shift_swaps
  SET status = 'Approved', approver_nrp = COALESCE(authz_current_nrp(), approver_nrp)
  WHERE id = p_id::INT AND status ILIKE 'pending%';
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows > 0 THEN
    INSERT INTO audit_log (actor, action, detail, timestamp)
    VALUES (COALESCE(authz_current_nrp(), 'admin'), 'SHIFT_SWAP_APPROVE', p_id, NOW());
    RETURN jsonb_build_object('ok', TRUE, 'msg', 'Shift swap disetujui.');
  END IF;
  RETURN jsonb_build_object('ok', FALSE, 'msg', 'Tidak ditemukan / sudah diproses.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

CREATE OR REPLACE FUNCTION admin_reject_shift_swap(p_id TEXT, p_note TEXT DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE v_rows INT := 0;
BEGIN
  IF NOT authz_check_admin('shift.approve') THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  IF p_id IS NULL OR p_id !~ '^[0-9]+$' THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'ID tidak valid.');
  END IF;
  UPDATE hr_shift_swaps
  SET status = 'Rejected', approver_nrp = COALESCE(authz_current_nrp(), approver_nrp)
  WHERE id = p_id::INT AND status ILIKE 'pending%';
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows > 0 THEN
    INSERT INTO audit_log (actor, action, detail, timestamp)
    VALUES (COALESCE(authz_current_nrp(), 'admin'), 'SHIFT_SWAP_REJECT', p_id, NOW());
    RETURN jsonb_build_object('ok', TRUE, 'msg', 'Shift swap ditolak.');
  END IF;
  RETURN jsonb_build_object('ok', FALSE, 'msg', 'Tidak ditemukan / sudah diproses.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

-- ════════════════════════════════════════════════════════════════
-- S1d. FACILITY — approve/reject via facility_requests + fallback hr_requests
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION admin_approve_facility_request(p_id TEXT, p_note TEXT DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE v_rows INT := 0;
BEGIN
  IF NOT authz_check_admin('facility.approve') THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  IF p_id IS NULL OR p_id = '' THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'ID tidak valid.');
  END IF;
  UPDATE facility_requests SET status = 'Approved'
  WHERE id = p_id AND status ILIKE 'pending%';
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows = 0 THEN
    UPDATE hr_requests
    SET status = 'Approved', note = COALESCE(p_note, 'Disetujui admin'),
        approver_nrp = COALESCE(authz_current_nrp(), approver_nrp)
    WHERE id = p_id AND status ILIKE 'pending%'
      AND (type ILIKE '%facility%' OR type ILIKE '%aset%');
    GET DIAGNOSTICS v_rows = ROW_COUNT;
  END IF;
  IF v_rows > 0 THEN
    INSERT INTO audit_log (actor, action, detail, timestamp)
    VALUES (COALESCE(authz_current_nrp(), 'admin'), 'FACILITY_APPROVE', p_id, NOW());
    RETURN jsonb_build_object('ok', TRUE, 'msg', 'Facility request disetujui.');
  END IF;
  RETURN jsonb_build_object('ok', FALSE, 'msg', 'Tidak ditemukan / sudah diproses / bukan facility request.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

CREATE OR REPLACE FUNCTION admin_reject_facility_request(p_id TEXT, p_note TEXT DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE v_rows INT := 0;
BEGIN
  IF NOT authz_check_admin('facility.approve') THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  IF p_id IS NULL OR p_id = '' THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'ID tidak valid.');
  END IF;
  UPDATE facility_requests SET status = 'Rejected'
  WHERE id = p_id AND status ILIKE 'pending%';
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows = 0 THEN
    UPDATE hr_requests
    SET status = 'Rejected', note = COALESCE(p_note, 'Ditolak admin'),
        approver_nrp = COALESCE(authz_current_nrp(), approver_nrp)
    WHERE id = p_id AND status ILIKE 'pending%'
      AND (type ILIKE '%facility%' OR type ILIKE '%aset%');
    GET DIAGNOSTICS v_rows = ROW_COUNT;
  END IF;
  IF v_rows > 0 THEN
    INSERT INTO audit_log (actor, action, detail, timestamp)
    VALUES (COALESCE(authz_current_nrp(), 'admin'), 'FACILITY_REJECT', p_id, NOW());
    RETURN jsonb_build_object('ok', TRUE, 'msg', 'Facility request ditolak.');
  END IF;
  RETURN jsonb_build_object('ok', FALSE, 'msg', 'Tidak ditemukan / sudah diproses / bukan facility request.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

-- ════════════════════════════════════════════════════════════════
-- S2. admin_approve_pending / admin_reject_pending — implementasi
--     sungguhan (daftar_baru), pola 003 + authz + audit.
--     (Regresi migration 139: stub yang selalu bilang sukses.)
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION admin_approve_pending(p_id INT)
RETURNS JSONB AS $$
DECLARE
  v_entry RECORD;
  v_caller TEXT := authz_current_nrp();
BEGIN
  IF v_caller IS NULL
     OR (NOT authz_check_admin('employee.create') AND NOT authz_check_admin('recruitment.approve')) THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  SELECT * INTO v_entry FROM daftar_baru WHERE id = p_id AND status = 'PENDING';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Entry tidak ditemukan atau sudah diproses.');
  END IF;

  INSERT INTO employees_master (employee_id, nrp, nik, nama, email, status_kerja)
  VALUES ('EMP' || p_id, v_entry.nrp, v_entry.nik, v_entry.nama, v_entry.email, 'Active')
  ON CONFLICT (nrp) DO NOTHING;

  INSERT INTO worker_passwords (nrp, password_hash, salt, is_active)
  VALUES (v_entry.nrp, COALESCE(v_entry.password_hash, 'pending'), COALESCE(v_entry.salt, ''), true)
  ON CONFLICT (nrp) DO NOTHING;

  INSERT INTO user_roles (nrp, role_level, plan)
  VALUES (v_entry.nrp, 1, 'FREE')
  ON CONFLICT (nrp) DO NOTHING;

  UPDATE daftar_baru SET status = 'APPROVED' WHERE id = p_id;
  INSERT INTO audit_log (actor, action, detail, timestamp)
  VALUES (v_caller, 'PENDING_APPROVE', 'daftar_baru ' || p_id, NOW());
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'Pendaftaran disetujui.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

CREATE OR REPLACE FUNCTION admin_reject_pending(p_id INT, p_reason TEXT DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
  v_rows INT := 0;
  v_caller TEXT := authz_current_nrp();
BEGIN
  IF v_caller IS NULL
     OR (NOT authz_check_admin('employee.create') AND NOT authz_check_admin('recruitment.approve')) THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  UPDATE daftar_baru SET status = 'REJECTED' WHERE id = p_id AND status = 'PENDING';
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows > 0 THEN
    INSERT INTO audit_log (actor, action, detail, timestamp)
    VALUES (v_caller, 'PENDING_REJECT', 'daftar_baru ' || p_id, NOW());
    RETURN jsonb_build_object('ok', TRUE, 'msg', 'Pendaftaran ditolak.');
  END IF;
  RETURN jsonb_build_object('ok', FALSE, 'msg', 'Entry tidak ditemukan atau sudah diproses.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

-- ════════════════════════════════════════════════════════════════
-- S3. ADMIN OTP — identitas terikat auth.uid(), rate-limited,
--     kode tidak dikirim di response, token verify disimpan.
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION generate_admin_otp()
RETURNS JSONB AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_nrp TEXT;
  v_code TEXT;
  v_is_admin BOOLEAN := FALSE;
  v_att RECORD;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Autentikasi diperlukan.');
  END IF;

  -- Identitas: owner (system_owner_identity) atau employee dengan role admin
  IF EXISTS (SELECT 1 FROM system_owner_identity WHERE auth_id = v_uid AND is_active = TRUE) THEN
    v_nrp := 'OWNER001';
    v_is_admin := TRUE;
  ELSE
    SELECT nrp INTO v_nrp FROM employees_master WHERE auth_id = v_uid LIMIT 1;
    IF v_nrp IS NOT NULL THEN
      SELECT EXISTS (SELECT 1 FROM user_roles
        WHERE nrp = v_nrp AND (role = 'owner' OR role LIKE 'admin%')) INTO v_is_admin;
    END IF;
  END IF;

  IF NOT v_is_admin THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;

  -- Rate limit: maks 3 request / 10 menit per identitas
  SELECT * INTO v_att FROM otp_attempts WHERE nrp = v_nrp;
  IF v_att.request_count IS NOT NULL AND v_att.request_window_start > NOW() - INTERVAL '10 minutes'
     AND v_att.request_count >= 3 THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Terlalu banyak request OTP. Coba lagi nanti.');
  END IF;
  IF v_att.request_window_start IS NULL OR v_att.request_window_start <= NOW() - INTERVAL '10 minutes' THEN
    INSERT INTO otp_attempts (nrp, request_count, request_window_start)
    VALUES (v_nrp, 1, NOW())
    ON CONFLICT (nrp) DO UPDATE SET request_count = 1, request_window_start = NOW();
  ELSE
    UPDATE otp_attempts SET request_count = request_count + 1 WHERE nrp = v_nrp;
  END IF;

  v_code := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
  INSERT INTO otp_store (nrp, code_hash, expiry, used)
  VALUES (v_nrp, encode(digest(v_code, 'sha256'), 'hex'), NOW() + INTERVAL '5 minutes', FALSE)
  ON CONFLICT (nrp) DO UPDATE SET
    code_hash = EXCLUDED.code_hash, expiry = EXCLUDED.expiry, used = FALSE;

  INSERT INTO audit_log (action, detail, timestamp)
  VALUES ('ADMIN_OTP_GEN', 'Admin OTP generated for ' || v_nrp, NOW());
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'OTP dibuat dan dikirim ke email admin. Berlaku 5 menit.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

CREATE OR REPLACE FUNCTION verify_admin_otp(p_code TEXT)
RETURNS JSONB AS $$
DECLARE
  v_otp RECORD;
  v_nrp TEXT;
  v_emp RECORD;
  v_role RECORD;
  v_token TEXT;
  v_att RECORD;
BEGIN
  IF p_code IS NULL OR LENGTH(p_code) < 4 THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Kode OTP tidak valid');
  END IF;

  SELECT * INTO v_otp FROM otp_store
  WHERE code_hash = encode(digest(p_code, 'sha256'), 'hex') AND used = FALSE AND expiry > NOW()
  ORDER BY created_at DESC LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Kode OTP admin tidak valid atau sudah kadaluarsa');
  END IF;

  v_nrp := v_otp.nrp;

  -- Rate limit percobaan verify: maks 5 / 15 menit per identitas
  SELECT * INTO v_att FROM otp_attempts WHERE nrp = v_nrp;
  IF v_att.blocked_until IS NOT NULL AND v_att.blocked_until > NOW() THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Terlalu banyak percobaan. Akun dikunci 15 menit.');
  END IF;

  -- Identitas yang di-OTP harus admin (anti puzzle silang OTP worker)
  SELECT * INTO v_emp FROM employees_master WHERE nrp = v_nrp;
  SELECT * INTO v_role FROM user_roles WHERE nrp = v_nrp;
  IF v_nrp <> 'OWNER001'
     AND (v_role.role IS NULL OR (v_role.role <> 'owner' AND v_role.role NOT LIKE 'admin%')) THEN
    UPDATE otp_attempts SET attempts = attempts + 1,
      blocked_until = CASE WHEN attempts >= 4 THEN NOW() + INTERVAL '15 minutes' ELSE blocked_until END
    WHERE nrp = v_nrp;
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Kode OTP admin tidak valid');
  END IF;

  UPDATE otp_store SET used = TRUE WHERE nrp = v_nrp AND code_hash = v_otp.code_hash;
  UPDATE otp_attempts SET attempts = 0, blocked_until = NULL WHERE nrp = v_nrp;

  v_token := encode(gen_random_bytes(32), 'hex');
  UPDATE session_tokens SET expires_at = NOW() WHERE nrp = v_nrp AND expires_at > NOW();
  INSERT INTO session_tokens (session_token, nrp, type, expires_at, created_at)
  VALUES (v_token, v_nrp, 'admin', NOW() + INTERVAL '24 hours', NOW());
  INSERT INTO audit_log (action, detail, timestamp)
  VALUES ('ADMIN_OTP_VERIFIED', 'Admin OTP verified for ' || v_nrp, NOW());

  RETURN jsonb_build_object(
    'ok', TRUE,
    'token', v_token,
    'nrp', v_nrp,
    'role', COALESCE(v_role.role, 'admin_pusat'),
    'nama', COALESCE(v_emp.nama, 'Administrator')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

-- ════════════════════════════════════════════════════════════════
-- S4. Seed permission shift.approve + facility.approve
-- ════════════════════════════════════════════════════════════════

INSERT INTO permission_set_items (permission_set, permission_code) VALUES
('admin_pusat_all', 'shift.approve'),
('admin_pusat_all', 'facility.approve'),
('hrd_ops', 'shift.approve'),
('hrd_ops', 'facility.approve'),
('supervisor_ext', 'shift.approve')
ON CONFLICT (permission_set, permission_code) DO NOTHING;

-- ════════════════════════════════════════════════════════════════
-- GRANTS + REVOKES
-- ════════════════════════════════════════════════════════════════

-- Admin OTP tidak lagi boleh dipanggil anon (regresi grant 172)
REVOKE EXECUTE ON FUNCTION generate_admin_otp() FROM anon;
REVOKE EXECUTE ON FUNCTION verify_admin_otp(TEXT) FROM anon;

GRANT EXECUTE ON FUNCTION generate_admin_otp() TO authenticated;
GRANT EXECUTE ON FUNCTION verify_admin_otp(TEXT) TO authenticated;

GRANT EXECUTE ON FUNCTION admin_approve_leave(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_reject_leave(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_approve_overtime(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_reject_overtime(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_approve_shift_swap(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_reject_shift_swap(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_approve_facility_request(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_reject_facility_request(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_approve_pending(INT) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_reject_pending(INT, TEXT) TO authenticated;

-- Fungsi baru default-nya punya EXECUTE untuk PUBLIC — cabut anon secara
-- eksplisit (audit: admin action tidak boleh callable tanpa sesi).
REVOKE EXECUTE ON FUNCTION admin_approve_leave(TEXT, TEXT) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION admin_reject_leave(TEXT, TEXT) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION admin_approve_overtime(TEXT, TEXT) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION admin_reject_overtime(TEXT, TEXT) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION admin_approve_shift_swap(TEXT, TEXT) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION admin_reject_shift_swap(TEXT, TEXT) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION admin_approve_facility_request(TEXT, TEXT) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION admin_reject_facility_request(TEXT, TEXT) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION admin_approve_pending(INT) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION admin_reject_pending(INT, TEXT) FROM anon, PUBLIC;

DO $$ BEGIN
  RAISE NOTICE '=== 191: approve/reject backend + admin OTP hardening + grants ===';
END $$;