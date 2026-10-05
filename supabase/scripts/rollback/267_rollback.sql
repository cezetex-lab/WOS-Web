-- ============================================================================
-- 267_rollback.sql — batalkan migrasi 267 (Fix #14 §9 batch 4/5,
-- rewiring verify_admin_otp_core + generate_admin_otp)
--
-- Dijalankan MANUAL via psql (file ini punya BEGIN/COMMIT sendiri — berbeda dari
-- file migrasi yang P4-nya forbid BEGIN/COMMIT).
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/scripts/rollback/267_rollback.sql
--
-- ISI ROLLBACK
--   1. Kedua fungsi dikembalikan ke PRE-IMAGE byte-exact (pg_get_functiondef LIVE
--      sebelum 267; salinan: .agents/logs/fix14-267-preimage-*.sql)
--        verify_admin_otp_core: md5(pg_get_functiondef) = 5ec65ec8d66a1a50b2f7ee1b647a8adf
--                               md5(prosrc)             = 05a1767b76b8d5520cb9c344b9a725f1
--                               length(def/prosrc)      = 2438 / 2251
--        generate_admin_otp:    md5(pg_get_functiondef) = 0605759c243854f7920d4c4c52ab668b
--                               md5(prosrc)             = 09cfb3bdded7ee122c50e5b4cbd91c92
--                               length(def/prosrc)      = 2320 / 2147
--   2. ACL dikembalikan eksplisit ke pre-267 (defensif; CREATE OR REPLACE sudah
--      mempertahankan ACL, tapi ini mengunci kontrak):
--        REVOKE EXECUTE ... FROM PUBLIC, anon     (no-op di pre-267)
--        GRANT  EXECUTE ... TO authenticated, service_role  (idempoten)
--
-- CATATAN: 267 tidak mengubah signature, tidak mengubah attrs, tidak menyentuh
-- wrapper verify_admin_otp(text). schema_migrations tidak disentuh oleh file ini.
-- Idempoten: jalan kedua kali tidak mengubah apa pun.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public.verify_admin_otp_core(p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.generate_admin_otp()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
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
$function$
;

-- (2) ACL pre-267 (defensif, idempoten).
REVOKE EXECUTE ON FUNCTION public.verify_admin_otp_core(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.verify_admin_otp_core(text) TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.generate_admin_otp() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.generate_admin_otp() TO authenticated, service_role;

COMMIT;
