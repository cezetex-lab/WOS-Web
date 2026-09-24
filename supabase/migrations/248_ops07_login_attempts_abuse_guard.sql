-- ════════════════════════════════════════════════════════════════════════════
-- 248_ops07_login_attempts_abuse_guard.sql — OPS-07 (P3)
-- PREVIEW — BELUM DI-APPLY (menunggu "APPROVE OPS-07")
--
-- TEMUAN FASE 1 yang mengubah premis task:
--   1. Grant anon untuk `check_login_lockout` (diberikan OPS-05 via migrasi 245,
--      2026-09-21; saat itu RPC anon = 200) **SUDAH HILANG** di live:
--      proacl = {postgres, authenticated, service_role} — tanpa `anon`.
--      Uji nyata pemanggilan anon → HTTP 401 `42501 permission denied`.
--      Dampak: `Home.tsx:206` (worker) & `:313` (admin) memanggil fungsi ini pra-sesi
--      lalu memeriksa `lockCheck?.locked` → saat 42501 hasilnya undefined → **fail-open**:
--      kontrol lockout pra-login MATI LAGI (regresi dari OPS-05 yang sudah DONE).
--   2. `check_login_lockout` tidak INSERT di setiap panggilan — hanya saat kondisi
--      lockout terpicu (≥5 gagal/15 mnt atau ≥10 gagal/24 jam). Vektor spam ada
--      (tiap panggilan yang memenuhi kondisi menambah 1 baris) tapi tidak terbatas.
--   3. Fungsi `cleanup_login_attempts()` (retensi 7 hari) **SUDAH ADA** di live tapi
--      TIDAK punya cron job (cron.job hanya: cleanup-sessions, cleanup-rate-limits,
--      cleanup-otp) → tabel tidak pernah dipangkas.
--   4. `hit_rate_limit(identifier, action, max, window) → boolean` tersedia & dipakai
--      edge `password-reset` (action berawalan `pwreset_*`). Limiter existing TIDAK
--      disentuh (aturan).
--   5. Trafik nyata kecil: 30 baris total (3 hari), 6 baris/24 jam, puncak 24/hari
--      (nrp008 12 · nrp002 9 · hrd 7).
--
-- STRATEGI: (a) + (b) + pulihkan grant
--   a. Rate-limit HANYA pada cabang INSERT (bukan seluruh fungsi) → cek lockout tetap
--      selalu bisa dibaca user sah, penulisan saja yang dibatasi.
--   b. Jadwalkan cleanup 7 hari dengan leverage fungsi yang sudah ada.
--   Plus: restore grant anon (menhidupkan kembali fix OPS-05 yang mati).
-- ════════════════════════════════════════════════════════════════════════════

-- ── (1) Rate-limit CABANG INSERT di check_login_lockout ────────────────────
-- Gate global (batas TOTAL per jendela, tahan rotasi identifier) + per-identifier.
-- Angka jauh di atas trafik nyata (puncak 24 baris/hari) → user sah tidak pernah
-- kena, spam tetap terpotong.
CREATE OR REPLACE FUNCTION public.check_login_lockout(p_identifier text, p_attempt_type text DEFAULT 'worker'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_failed_count INT;
  v_last_attempt TIMESTAMPTZ;
  v_is_locked BOOLEAN := FALSE;
  v_lockout_reason TEXT := '';
  v_remaining_seconds INT := 0;
  v_write_allowed BOOLEAN := TRUE;
BEGIN
  SELECT COUNT(*), MAX(created_at)
  INTO v_failed_count, v_last_attempt
  FROM login_attempts
  WHERE identifier = p_identifier
    AND attempt_type = p_attempt_type
    AND success = FALSE
    AND created_at > NOW() - INTERVAL '15 minutes';

  IF v_failed_count >= 5 THEN
    v_remaining_seconds := EXTRACT(EPOCH FROM (
      (v_last_attempt + INTERVAL '15 minutes') - NOW()
    ))::INT;

    IF v_remaining_seconds > 0 THEN
      v_is_locked := TRUE;
      v_lockout_reason := 'Terlalu banyak percobaan gagal. Coba lagi dalam ' ||
                          (v_remaining_seconds / 60)::INT || ' menit.';

      -- OPS-07: rate-limit HANYA penulisan audit-lockout. Pembacaan status lockout
      -- di atas tidak pernah dibatasi → user sah selalu bisa mengecek.
      --  - global : batas TOTAL baris per jendela (tahan rotasi identifier)
      --  - per-ID : batas per akun (tahan spam pada satu identifier)
      v_write_allowed :=
        hit_rate_limit('global', 'login_lockout_record', 300, 900)
        AND hit_rate_limit('ident:' || p_identifier, 'login_lockout_record', 30, 900);

      IF v_write_allowed THEN
        INSERT INTO login_attempts (identifier, attempt_type, success, ip_address)
        VALUES (p_identifier, p_attempt_type, FALSE, 'LOCKOUT_TRIGGERED');
      END IF;
    END IF;
  END IF;


  SELECT COUNT(*), MAX(created_at)
  INTO v_failed_count, v_last_attempt
  FROM login_attempts
  WHERE identifier = p_identifier
    AND attempt_type = p_attempt_type
    AND success = FALSE
    AND created_at > NOW() - INTERVAL '24 hours';

  IF v_failed_count >= 10 THEN
    v_remaining_seconds := EXTRACT(EPOCH FROM (
      (v_last_attempt + INTERVAL '1 hour') - NOW()
    ))::INT;

    IF v_remaining_seconds > 0 THEN
      v_is_locked := TRUE;
      v_lockout_reason := 'Akun dikunci karena terlalu banyak percobaan gagal. Coba lagi dalam ' ||
                          (v_remaining_seconds / 60)::INT || ' menit.';
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'locked', v_is_locked,
    'reason', v_lockout_reason,
    'remaining_seconds', GREATEST(v_remaining_seconds, 0),
    'failed_attempts', v_failed_count,
    'audit_logged', v_write_allowed
  );
END;
$function$;

-- ── (2) Restore grant anon (menghidupkan kembali fix OPS-05) ─────────────────
-- Migrasi 245 (OPS-05) sudah pernah melakukan ini; grant hilang di live
-- (proacl tanpa `anon`, uji anon = 42501). Idempoten.
GRANT EXECUTE ON FUNCTION public.check_login_lockout(text, text) TO anon;

-- ── (3) Cron cleanup login_attempts (retensi 7 hari) ────────────────────────
-- Leverage `cleanup_login_attempts()` yang sudah ada. Jadwal 03:30 UTC dipisah dari
-- cleanup-rate-limits (03:00) supaya tidak menumpuk. Idempoten: unschedule dulu.
DO $do$
BEGIN
  PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'cleanup-login-attempts';
EXCEPTION WHEN OTHERS THEN
  NULL;
END;
$do$;

SELECT cron.schedule('cleanup-login-attempts', '30 3 * * *', 'SELECT cleanup_login_attempts()');
