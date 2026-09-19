-- ================================================================
-- 213_registration_and_favicon.sql — Tahap 5.11
--
-- 1. submit_registration RPC — worker self-registration into daftar_baru
-- 2. get_branding_public RPC — public-safe branding read (no auth needed)
-- 3. Fix favicon_url data (was timestamp, now NULL)
-- ================================================================

-- 1. submit_registration — worker self-registration
CREATE OR REPLACE FUNCTION public.submit_registration(
  p_nrp text,
  p_nik text,
  p_nama text,
  p_password text,
  p_email text DEFAULT NULL,
  p_divisi text DEFAULT NULL,
  p_posisi text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_existing RECORD;
  v_hash text;
BEGIN
  -- Validate required fields
  IF p_nrp IS NULL OR p_nrp = '' THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'NRP wajib diisi.');
  END IF;
  IF p_nik IS NULL OR LENGTH(btrim(p_nik)) < 5 THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'NIK tidak valid (minimal 5 karakter).');
  END IF;
  IF p_nama IS NULL OR p_nama = '' THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Nama wajib diisi.');
  END IF;
  IF p_password IS NULL OR LENGTH(p_password) < 6 THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Password minimal 6 karakter.');
  END IF;

  -- Check if NRP already registered
  SELECT * INTO v_existing FROM daftar_baru WHERE nrp = p_nrp AND status = 'PENDING';
  IF FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'NRP sudah terdaftar dan menunggu persetujuan.');
  END IF;

  -- Check if NRP already in employees_core
  IF EXISTS (SELECT 1 FROM employees_core WHERE nrp = p_nrp) THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'NRP sudah memiliki akun aktif.');
  END IF;

  -- Hash password with bcrypt
  v_hash := crypt(p_password, gen_salt('bf'));

  -- Insert into daftar_baru
  INSERT INTO daftar_baru (nrp, nik, nama, email, divisi, posisi, status_kerja, password_hash, status)
  VALUES (p_nrp, btrim(p_nik), p_nama, p_email, p_divisi, p_posisi, 'Pending', v_hash, 'PENDING');

  RETURN jsonb_build_object(
    'ok', true,
    'msg', 'Pendaftaran berhasil. Menunggu persetujuan admin.',
    'nrp', p_nrp
  );
END;
$function$;

-- 2. get_branding_public — public-safe branding read (no auth needed)
CREATE OR REPLACE FUNCTION public.get_branding_public()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_branding RECORD;
BEGIN
  SELECT * INTO v_branding FROM branding WHERE id = 'main';
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'company_name', 'insightWOS',
      'tagline', 'Workforce Intelligence Platform',
      'logo_url', NULL,
      'favicon_url', NULL,
      'primary_color', '#3b82f6'
    );
  END IF;
  RETURN jsonb_build_object(
    'company_name', v_branding.company_name,
    'tagline', v_branding.tagline,
    'logo_url', v_branding.logo_url,
    'favicon_url', v_branding.favicon_url,
    'primary_color', v_branding.primary_color
  );
END;
$function$;

-- 3. Verify
SELECT '213.1 submit_registration exists' AS test,
  CASE WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname='submit_registration')
  THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT '213.2 get_branding_public exists' AS test,
  CASE WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname='get_branding_public')
  THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT '213.3 branding public data' AS test, (get_branding_public()) AS result;
