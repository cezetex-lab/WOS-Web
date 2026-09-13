-- ================================================================
-- rollback/206_rollback.sql — Rollback migration 206 (P0-6 NIK guard)
-- Run ONLY if 206 must be reverted. Order: functions first, then constraints.
-- ================================================================

-- 1. generate_worker_otp → kembali ke body pre-206 (dump live 2026-09-13,
--    .freebuff/audit/_gwo_live_body.sql) yaitu TANPA blok guard P0-6 di awal.
--    (Body identik dengan migration 206 kecuali blok guard dihapus.)
CREATE OR REPLACE FUNCTION public.generate_worker_otp(p_nrp text, p_nik text, p_password text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_code TEXT; v_hash TEXT; v_expiry TIMESTAMPTZ;
  v_attempts INTEGER; v_emp RECORD; v_wp RECORD;
BEGIN
  SELECT * INTO v_emp FROM employees_master WHERE nrp = p_nrp;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'NRP tidak terdaftar.');
  END IF;

  IF REPLACE(REPLACE(REPLACE(v_emp.nik,'.',''),'-',''),' ','') !=
     REPLACE(REPLACE(REPLACE(p_nik,'.',''),'-',''),' ','') THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'NRP dan NIK tidak cocok.');
  END IF;

  SELECT attempts INTO v_attempts FROM otp_attempts WHERE nrp = p_nrp;
  IF v_attempts IS NOT NULL AND v_attempts >= 5 THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Terlalu banyak percobaan. Tunggu 15 menit.');
  END IF;

  SELECT * INTO v_wp FROM worker_passwords WHERE nrp = p_nrp AND is_active = true;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akun belum aktif.');
  END IF;

  IF v_wp.password_hash LIKE '$2%' THEN
    IF crypt(p_password, v_wp.password_hash) <> v_wp.password_hash THEN
      UPDATE otp_attempts SET attempts = COALESCE(attempts,0) + 1 WHERE nrp = p_nrp;
      RETURN jsonb_build_object('ok', false, 'msg', 'Password salah.');
    END IF;
  ELSIF v_wp.salt IS NOT NULL AND v_wp.salt <> '' THEN
    IF encode(digest(p_password || v_wp.salt, 'sha256'), 'hex') <> v_wp.password_hash THEN
      UPDATE otp_attempts SET attempts = COALESCE(attempts,0) + 1 WHERE nrp = p_nrp;
      RETURN jsonb_build_object('ok', false, 'msg', 'Password salah.');
    END IF;
  ELSE
    IF v_wp.password_hash <> p_password THEN
      UPDATE otp_attempts SET attempts = COALESCE(attempts,0) + 1 WHERE nrp = p_nrp;
      RETURN jsonb_build_object('ok', false, 'msg', 'Password salah.');
    END IF;
  END IF;

  UPDATE otp_attempts SET attempts = 0 WHERE nrp = p_nrp;

  v_code := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
  v_hash := encode(digest(v_code, 'sha256'), 'hex');
  v_expiry := NOW() + INTERVAL '5 minutes';

  DELETE FROM otp_store WHERE nrp = p_nrp;
  INSERT INTO otp_store (nrp, code_hash, expiry, used)
    VALUES (p_nrp, v_hash, v_expiry, false);

  RETURN jsonb_build_object('ok', true, 'msg', 'Masukkan kode OTP di bawah.', 'otp', v_code);
END;
$function$;

-- 2. admin_approve_pending / admin_bulk_approve_pending → body migration 191.
--    CATATAN: body 191 INSERT ke VIEW employees_master = SUDAH RUSAK sejak 183
--    (regresi yang justru diperbaiki 206). Rollback mengembalikan perilaku lama
--    secara sadar — jangan dipakai kecuali benar-benar perlu.
--    Sumber body lama: supabase/migrations/191_fix_approve_rpcs_and_auth_hardening.sql
--    (S2). Jalankan file itu jika rollback penuh diperlukan; 191 idempotent.

-- 3. Drop constraints P0-6
ALTER TABLE public.employees_core DROP CONSTRAINT IF EXISTS employees_core_nik_format;
ALTER TABLE public.employees_core DROP CONSTRAINT IF EXISTS employees_core_nik_not_null;

-- 4. Verify rollback
SELECT 'rb206.1 constraints dropped' AS test,
  CASE WHEN NOT EXISTS (SELECT 1 FROM pg_constraint
    WHERE conrelid='public.employees_core'::regclass
      AND conname IN ('employees_core_nik_not_null','employees_core_nik_format'))
  THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'rb206.2 guard removed from generate_worker_otp' AS test,
  CASE WHEN position('p_nik tidak valid' in lower(pg_get_functiondef(p.oid))) = 0
  THEN 'PASS' ELSE 'FAIL' END AS result
FROM pg_proc p WHERE p.proname='generate_worker_otp'
  AND pg_get_function_identity_arguments(p.oid) LIKE '%p_nik%';
