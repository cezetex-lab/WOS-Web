-- ============================================================================
-- 230_owner_email_fail_closed.sql
-- ============================================================================
-- MASALAH (ditemukan 2026-09-18 saat menyiapkan instalasi satu-perintah):
--
--   get_owner_email() berakhir dengan:
--       RETURN COALESCE(v_email, 'owner@insightwos.com');
--
--   yaitu DOMAIN PERUSAHAAN KITA di-hardcode di dalam fungsi DB bersama.
--   Akibatnya untuk setiap perusahaan baru:
--     1. kalau baris company_config 'owner_email' tidak ada, owner_login()
--        mewajibkan email kita — owner perusahaan itu TIDAK PERNAH bisa login;
--     2. alamat email perusahaan kita bocor sebagai "default" resmi sistem.
--
--   Risikonya makin tajam karena owner_login() membandingkan `p_email != v_owner_email`
--   dengan nilai hasil get_owner_email(). Jadi nilai default itu bukan sekadar kosmetik:
--   ia menentukan siapa yang boleh masuk ke OwnerDashboard.
--
-- PERBAIKAN: fail-closed. Tanpa konfigurasi eksplisit, fungsi mengembalikan NULL dan
-- tidak ada email siapa pun yang diterima. owner_login() memberi pesan yang jelas
-- supaya operator tahu langkah yang harus dilakukan, bukan gagal tanpa petunjuk.
--
-- CATATAN KEAMANAN: pemeriksaan IS NULL WAJIB ada. Tanpa itu `p_email != NULL`
-- bernilai NULL → blok IF tidak dijalankan → login owner BERHASIL dengan email apa pun.
CREATE OR REPLACE FUNCTION public.get_owner_email()
RETURNS text
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_email TEXT;
BEGIN
  SELECT config_value->>'value' INTO v_email
  FROM company_config WHERE config_key = 'owner_email';

  -- Fail-closed: tidak ada konfigurasi = tidak ada email yang sah.
  -- Jangan pernah mengembalikan domain perusahaan mana pun dari kode bersama.
  IF v_email IS NULL OR btrim(v_email) = '' THEN
    RETURN NULL;
  END IF;

  RETURN btrim(v_email);
END;
$function$;

CREATE OR REPLACE FUNCTION public.owner_login(p_email text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  v_is_owner BOOLEAN;
  v_owner_email TEXT;
BEGIN
  -- Baca owner_email dari config (bisa diubah owner/admin lewat OwnerDashboard)
  SELECT get_owner_email() INTO v_owner_email;

  -- Validate against system_owner_identity
  SELECT EXISTS (
    SELECT 1 FROM system_owner_identity
    WHERE auth_id = v_uid AND is_active = TRUE
  ) INTO v_is_owner;

  IF NOT v_is_owner THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akun owner tidak ditemukan atau tidak aktif');
  END IF;

  -- Instalasi baru belum mengisi owner_email. Beri pesan yang bisa ditindaklanjuti;
  -- JANGAN menerima email apa pun (lihat catatan keamanan di header).
  IF v_owner_email IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'msg', 'owner_email belum dikonfigurasi. Isi dulu: company_config config_key=owner_email, '
             || 'atau jalankan installer dengan --owner-email="email-owner@perusahaan.com".'
    );
  END IF;

  IF lower(btrim(p_email)) IS DISTINCT FROM lower(v_owner_email) THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Email tidak sesuai dengan konfigurasi owner');
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
$function$;

-- CREATE OR REPLACE mempertahankan ACL, jadi REVOKE anon/PUBLIC dari migrasi
-- 172/210/221/226 tetap berlaku. Tidak ada GRANT baru di sini.
