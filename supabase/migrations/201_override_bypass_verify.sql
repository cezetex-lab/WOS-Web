-- 201_override_bypass_verify.sql
-- Override bypass MFA/OTP untuk testing owner (OWNER = hantu, tak terlihat worker/admin).
--
-- ── PERBAIKAN 2026-09-18 ────────────────────────────────────────────────────────
-- Berkas ini sebelumnya mendefinisikan ULANG verify_mfa / verify_worker_otp /
-- verify_admin_otp dengan `RETURNS boolean` dan memanggil helper yang tidak pernah
-- ada (mfa_verify_login, verify_worker_otp_asli, verify_admin_otp_asli). Kontrak DB
-- live — dan yang dipakai src/ — adalah `jsonb`, sehingga setiap CREATE OR REPLACE
-- gagal dengan:
--     ERROR: cannot change return type of existing function
-- Verifikasi ke live 2026-09-18: ketiganya `jsonb`, artinya berkas ini TIDAK PERNAH
-- benar-benar diterapkan walaupun terdaftar di schema_migrations.
--
-- Sekarang: implementasi asli di-rename ke `*_core` (pola pensiun `_legacy_*`,
-- AGENTS.md §3.4) dan wrapper jsonb hanya menambahkan short-circuit override di
-- atasnya — sehingga kontrak yang dilihat aplikasi tidak berubah sama sekali.
-- Idempoten: rename dijalankan sekali saja (dijaga oleh keberadaan `*_core`).
-- ================================================================

-- ── 1. Helper: cek override bypass (dipakai wrapper di bawah) ───────────────────
CREATE OR REPLACE FUNCTION auth_testing_override_bypass(p_nrp text, p_type text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $bypass$
DECLARE
  v_override auth_testing_override;
BEGIN
  IF p_type = 'mfa' THEN
    SELECT * INTO v_override FROM auth_testing_override WHERE nrp = p_nrp AND mfa_bypass = true;
  ELSIF p_type = 'otp' THEN
    SELECT * INTO v_override FROM auth_testing_override WHERE nrp = p_nrp AND otp_bypass = true;
  END IF;
  RETURN FOUND;
END;
$bypass$;

-- ── 2. Pensiunkan implementasi asli menjadi `*_core` (hanya sekali) ─────────────
DO $retire$
BEGIN
  IF to_regprocedure('public.verify_mfa(text,text)') IS NOT NULL
     AND to_regprocedure('public.verify_mfa_core(text,text)') IS NULL THEN
    ALTER FUNCTION public.verify_mfa(text, text) RENAME TO verify_mfa_core;
  END IF;

  IF to_regprocedure('public.verify_worker_otp(text,text)') IS NOT NULL
     AND to_regprocedure('public.verify_worker_otp_core(text,text)') IS NULL THEN
    ALTER FUNCTION public.verify_worker_otp(text, text) RENAME TO verify_worker_otp_core;
  END IF;

  IF to_regprocedure('public.verify_admin_otp(text)') IS NOT NULL
     AND to_regprocedure('public.verify_admin_otp_core(text)') IS NULL THEN
    ALTER FUNCTION public.verify_admin_otp(text) RENAME TO verify_admin_otp_core;
  END IF;
END $retire$;

-- ── 3. Wrapper jsonb (kontrak tetap, hanya menambah short-circuit override) ─────
-- Catatan plpgsql: pernyataan SQL di dalam blok disiapkan saat pertama kali
-- dieksekusi, jadi `to_regprocedure(...) IS NULL THEN RETURN ...` di bawah benar-benar
-- menjaga panggilan ke `*_core` yang mungkin belum ada pada jalur instalasi
-- (fail-closed: verifikasi ditolak, bukan error).
CREATE OR REPLACE FUNCTION verify_mfa(p_nrp text, p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $mfa$
BEGIN
  IF auth_testing_override_bypass(p_nrp, 'mfa') THEN
    RETURN jsonb_build_object('ok', true, 'bypass', true, 'msg', 'MFA dilewati (auth_testing_override)');
  END IF;
  IF to_regprocedure('public.verify_mfa_core(text,text)') IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Implementasi verify_mfa tidak tersedia');
  END IF;
  RETURN verify_mfa_core(p_nrp, p_code);
END;
$mfa$;

CREATE OR REPLACE FUNCTION verify_worker_otp(p_nrp text, p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $wotp$
BEGIN
  IF auth_testing_override_bypass(p_nrp, 'otp') THEN
    RETURN jsonb_build_object('ok', true, 'bypass', true, 'msg', 'OTP dilewati (auth_testing_override)');
  END IF;
  IF to_regprocedure('public.verify_worker_otp_core(text,text)') IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Implementasi verify_worker_otp tidak tersedia');
  END IF;
  RETURN verify_worker_otp_core(p_nrp, p_code);
END;
$wotp$;

CREATE OR REPLACE FUNCTION verify_admin_otp(p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $aotp$
BEGIN
  -- verify_admin_otp tidak menerima NRP, jadi override tidak dipakai di sini
  -- (memberi bypass akan mengizinkan owner melewati SEMUA OTP admin).
  IF to_regprocedure('public.verify_admin_otp_core(text)') IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Implementasi verify_admin_otp tidak tersedia');
  END IF;
  RETURN verify_admin_otp_core(p_code);
END;
$aotp$;

-- ── 4. Hak akses ───────────────────────────────────────────────────────────────
-- Fungsi BARU otomatis mendapat EXECUTE untuk PUBLIC (default PostgreSQL) dan
-- anon/authenticated (default privilege Supabase), sedangkan 172_hardening_grants.sql
-- sudah mencabutnya dari semua fungsi dan hanya memberi daftar putih. Samakan
-- kembali supaya wrapper tidak membuka lubang yang baru saja ditutup.
REVOKE ALL ON FUNCTION public.verify_mfa(text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.verify_worker_otp(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.verify_admin_otp(text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.verify_worker_otp(text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.verify_admin_otp(text) TO anon;
GRANT EXECUTE ON FUNCTION public.verify_mfa(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_worker_otp(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_admin_otp(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.auth_testing_override_bypass(text, text) TO authenticated;

-- `*_core` mewarisi ACL dari fungsi aslinya (ALTER FUNCTION ... RENAME tidak
-- mengubah hak akses), sehingga tidak ada hak yang perlu dipasang ulang.
