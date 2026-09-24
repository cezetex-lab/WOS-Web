-- ════════════════════════════════════════════════════════════════════════════
-- 247_ops14b_owner_god_bypass.sql — OPS-14b (keputusan user 2026-09-24)
-- PREVIEW — BELUM DI-APPLY (menunggu "APPROVE OPS-14b")
--
-- KONSEP (kunci user): Owner = shadow/GOD.
--   - Identitas = EMAIL di `system_owner_identity` (bukan NRP).
--   - Owner TIDAK butuh baris `employees_core` / `employees_master` / `user_roles`.
--   - Owner TIDAK boleh "menyamar" jadi NRP (DILARANG patch `authz_current_nrp`).
--   - Owner TIDAK muncul di headcount/statistik.
--
-- MASALAH: `admin_reset_worker_password` menolak owner dengan "Akses ditolak."
--   v_caller := authz_current_nrp();              -- NULL untuk owner (tidak ada di employees_master)
--   IF v_caller IS NULL OR NOT authz_check_admin('employee.update') THEN  -- short-circuit
-- Gate `v_caller IS NULL` menolak SEBELUM owner-bypass di `authz_check_admin`
-- (yang membandingkan `system_owner_identity.auth_id = auth.uid()`) sempat dicek.
--
-- Helper `authz_is_owner()` memakai OR auth_id ATAU email:
--   - `auth_id` = identitas immutable (tahan perubahan email / user dibuat ulang),
--     dan inilah bypass yang SUDAH dipakai `authz_check_admin` & `check_owner_identity`.
--   - `email` = konsep GOD yang dikunci user (identitas follows email, seperti
--     `get_current_user_context()` yang mengembalikan nrp='OWNER001' dari
--     `check_owner_identity()`, bukan dari tabel karyawan).
--   Email berasal dari claim JWT yang ditandatangani GoTrue — bukan input client.
--   Tidak ada alur signUp di `src/`; seluruh 18 akun auth.users ber-email confirmed
--   (probe 2026-09-24), jadi claim email tidak bisa diklaim orang lain.
-- ════════════════════════════════════════════════════════════════════════════

-- ── (a) HELPER BARU: authz_is_owner() ──────────────────────────────────────
CREATE OR REPLACE FUNCTION public.authz_is_owner()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $fn$
  SELECT COALESCE(
    EXISTS (
      SELECT 1
        FROM public.system_owner_identity
       WHERE is_active = TRUE
         AND (
              auth_id = auth.uid()
           OR lower(owner_email) = lower(COALESCE(auth.jwt() ->> 'email', ''))
         )
    ),
    FALSE
  );
$fn$;

-- ACL: helper ini membuka bypass → TIDAK boleh untuk anon/PUBLIC (pola sama
-- ── (b) PATCH: admin_reset_worker_password ─────────────────────────────────
-- Gate owner dicek SEBELUM gate NRP, dan TIDAK weaken gate untuk non-owner:
--   non-owner  → v_caller terisi & wajib lolos authz_check_admin (SAMA seperti sebelumnya)
--   owner      → v_caller NULL & lolos authz_is_owner() (GOD bypass)
CREATE OR REPLACE FUNCTION public.admin_reset_worker_password(p_nrp text, p_new_password text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE v_emp RECORD; v_caller TEXT;
BEGIN
  v_caller := authz_current_nrp();
  -- OPS-14b: owner bypass diperiksa SEBELUM gate v_caller (owner tidak punya NRP).
  IF (v_caller IS NULL AND NOT authz_is_owner())
     OR (v_caller IS NOT NULL AND NOT authz_check_admin('employee.update')) THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  IF p_nrp IS NULL OR p_nrp = '' THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'NRP tidak valid.');
  END IF;
  IF p_new_password IS NULL OR LENGTH(p_new_password) < 8 THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Password minimal 8 karakter');
  END IF;

  SELECT * INTO v_emp FROM employees_master WHERE nrp = p_nrp;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Karyawan dengan NRP ' || p_nrp || ' tidak ditemukan');
  END IF;

  UPDATE worker_passwords
  SET password_hash = crypt(p_new_password, gen_salt('bf')),
      salt = NULL,
      is_active = true,
      attempts = 0,
      blocked_until = NULL,
      reset_required = TRUE,
      updated_at = NOW()
  WHERE nrp = p_nrp;
  IF NOT FOUND THEN
    INSERT INTO worker_passwords (nrp, password_hash, salt, is_active, reset_required, updated_at)
    VALUES (p_nrp, crypt(p_new_password, gen_salt('bf')), NULL, true, TRUE, NOW());
  END IF;

  -- Invalidate sesi lama (schema live: expires_at)
  UPDATE session_tokens SET expires_at = NOW() WHERE nrp = p_nrp AND expires_at > NOW();
  DELETE FROM active_sessions WHERE nrp = p_nrp;

  -- OPS-14b: actor fallback ke email owner bila v_caller NULL (audit tetap bisa ditelusuri).
  INSERT INTO audit_log (actor, action, detail, timestamp)
  VALUES (COALESCE(v_caller, 'owner:' || lower(COALESCE(auth.jwt() ->> 'email', 'unknown'))),
          'RESET_PASSWORD', 'Reset password for ' || p_nrp, NOW());

  -- JANGAN pernah mengembalikan password di response
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'Password ' || p_nrp || ' berhasil direset. Wajib ganti password saat login berikutnya.');
END;
$function$;

-- dengan authz_check_admin & check_owner_identity: anon_exec=false, auth_exec=true).
REVOKE ALL ON FUNCTION public.authz_is_owner() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.authz_is_owner() FROM anon;
GRANT EXECUTE ON FUNCTION public.authz_is_owner() TO authenticated;
