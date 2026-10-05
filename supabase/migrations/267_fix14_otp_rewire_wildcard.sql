-- ============================================================================
-- 267 — Fix #14 §9 batch 4/5: rewiring verify_admin_otp_core() + generate_admin_otp()
--
-- KENAPA 267 INI ADA
--   Kedua fungsi OTP membaca identitas admin dari user_roles.role dengan wildcard
--   LIKE 'admin%' — sumber LAMA dan pola yang terlalu longgar:
--     (a) sejak 261/262 sumber kebenaran role admin adalah
--         user_role_assignments.role_code (pola §9, sama dengan 263/265/266);
--     (b) 'admin%' TANPA escape juga cocok untuk role generik 'admin' (ada di
--         role_codes sebagai reservasi is_active=false) dan kode liar seperti
--         'adminX' — underscore harus di-escape ('admin\_%') supaya literal.
--   Dampak (a): admin yang punya assignment (semua 17 user live punya, diff = 0)
--   tetap hijau; yang diperbaiki adalah sumber & fail-safe.
--   Dampak (b): hanya mempersempit — menutup celah hipotetis; 0 user existing
--   memakai role yang match 'admin%' tapi bukan 'admin_%' (probe D1/D2/D3 = 0).
--
-- PERUBAHAN — 5 hunk (dibuktikan inverse proof di FASE E)
--   verify_admin_otp_core (4 hunk):
--     1. DECLARE: tambah `v_assign_role TEXT;`
--     2. Tambah SELECT a.role_code INTO v_assign_role FROM user_role_assignments
--        (ORDER BY is_primary DESC NULLS LAST, role_code ASC LIMIT 1) — pola 265/266.
--     3. Gate identitas: v_role.role -> COALESCE(v_assign_role, v_role.role);
--        wildcard 'admin%' -> 'admin\_%'.
--     4. RETURN 'role': COALESCE(v_assign_role, v_role.role, 'admin_pusat') —
--        fallback 'admin_pusat' DIPERTAHANKAN (fail-safe jalur OWNER001).
--   generate_admin_otp (1 hunk):
--     5. Gate v_is_admin: EXISTS user_roles(admin%) -> CASE:
--        - nrp PUNYA assignment  -> putuskan dari assignments (admin\_%);
--        - nrp TANPA assignment  -> fallback user_roles (owner | admin\_%).
--        (assignment override; alasan lengkap di blok "KEPUTUSAN E2" bawah)
--
-- KEPUTUSAN E2 — kenapa CASE assignment-override, bukan EXISTS-assignments murni
--   Tiga kandidat dipertimbangkan: (A) assignments murni + carve-out owner (pola
--   263), (B) CASE override + fallback user_roles (dipilih), (C) OR dua sumber.
--   Dipilih (B) karena: (i) simetris dengan COALESCE hybrid verify (kedua fungsi
--   satu semantik: assignment menang; user_roles hanya jaring bila assignment
--   benar-benar absen); (ii) OTP = entry point login — mempertahankan fallback
--   terhadap instalasi yang assignment-nya belum terseed (kasus OPS-14 nyata);
--   (iii) demosi role di assignments langsung berlaku, user_roles basi tidak
--   bisa "menyelamatkan" akses. Pada data live keduanya identik: 17/17 user
--   punya tepat 1 assignment dengan role_code == user_roles.role (diff 2 arah = 0).
--
-- YANG SENGAJA TIDAK BERUBAH
--   - Signature + RETURNS jsonb + LANGUAGE plpgsql + VOLATILE + SECURITY DEFINER
--     + SET search_path TIDAK disentuh (attrs preserved, dibuktikan FASE F).
--   - Owner bypass: system_owner_identity di generate; cabang v_nrp <> 'OWNER001'
--     di verify — TIDAK disentuh.
--   - Rate limit OTP, otp_store/otp_attempts/session_tokens/audit_log — tidak disentuh.
--   - Wrapper publik verify_admin_otp(text) (grant anon = jalur pre-sesi
--     Home.tsx:361/468) TIDAK disentuh.
--   - login_worker / login_worker_by_email tetap baca user_roles (di luar scope §9).
--
-- GRANT (defensif, P10)
--   ACL live kedua fungsi sudah memuat authenticated + service_role dan TIDAK
--   memuat anon. GRANT idempoten di bawah mengunci kontrak itu supaya tidak bisa
--   lepas diam-diam. TIDAK ada grant ke anon — fail-closed.
--
-- P4: file ini TIDAK BOLEH punya BEGIN/COMMIT — wrapper apply-migration.mjs
-- yang memegang transaksi.
-- ============================================================================
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
  v_assign_role TEXT;
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

  -- Fix #14 §9 batch 267: role dari user_role_assignments (sumber kebenaran
  -- sejak 261/262), fallback ke user_roles.role — pola hybrid 265/266.
  SELECT a.role_code INTO v_assign_role
    FROM user_role_assignments a
   WHERE a.nrp = v_nrp
   ORDER BY a.is_primary DESC NULLS LAST, a.role_code ASC
   LIMIT 1;

  IF v_nrp <> 'OWNER001'
     AND (COALESCE(v_assign_role, v_role.role) IS NULL
          OR (COALESCE(v_assign_role, v_role.role) <> 'owner'
              AND COALESCE(v_assign_role, v_role.role) NOT LIKE 'admin\_%')) THEN
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
    'role', COALESCE(v_assign_role, v_role.role, 'admin_pusat'),
    'nama', COALESCE(v_emp.nama, 'Administrator')
  );
END;
$function$;

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
      -- Fix #14 §9 batch 267: admin\_% dari user_role_assignments (assignment
      -- override); fallback user_roles HANYA bila nrp tanpa assignment sama sekali.
      SELECT CASE
               WHEN EXISTS (SELECT 1 FROM user_role_assignments a WHERE a.nrp = v_nrp) THEN
                 EXISTS (SELECT 1 FROM user_role_assignments a
                          WHERE a.nrp = v_nrp AND a.role_code LIKE 'admin\_%')
               ELSE
                 EXISTS (SELECT 1 FROM user_roles ur
                          WHERE ur.nrp = v_nrp AND (ur.role = 'owner' OR ur.role LIKE 'admin\_%'))
             END
        INTO v_is_admin;
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
$function$;

GRANT EXECUTE ON FUNCTION public.verify_admin_otp_core(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.generate_admin_otp() TO authenticated, service_role;
