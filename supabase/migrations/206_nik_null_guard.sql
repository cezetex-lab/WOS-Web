-- ================================================================
-- 206_nik_null_guard.sql — Tahap 5.3 / P0-6: guard permanen NIK NULL
--
-- Bukti live (pre-flight 2026-09-13, read-only):
--   A. employees_core: 17/17 baris, nik NULL = 0, panjang 6..16 — aman di-strict.
--      (8 baris placeholder NRP100–106 = 6 char alnum; 9 baris NRP001–009 = 16 digit.)
--   B. BELUM ada constraint NOT NULL/CHECK pada nik → P0-6 terbuka.
--   C. Live gap: generate_worker_otp TIDAK punya NULL/format guard p_nik
--      (login_worker sudah punya: `p_nik IS NULL OR LENGTH(p_nik) < 5 OR > 20`).
--   D. REGRESI ditemukan: admin_approve_pending / admin_bulk_approve_pending
--      (migration 191) masih INSERT INTO employees_master = VIEW sejak
--      migration 183 → INSERT PASTI GAGAL ("cannot insert into view").
--      Sekaligus mem-pipe nik mentah dari daftar_baru tanpa validasi.
--      Diperbaiki di sini: INSERT ke employees_core (+ guard NIK), sisanya
--      write-path permanen VIEW = item 5.9 (tidak diubah di sini).
--
-- Idempotent: ALTER IF NOT EXISTS pattern + CREATE OR REPLACE.
-- Rollback: supabase/migrations/rollback/206_rollback.sql
-- ================================================================

-- ── 1. Constraint permanen di base table ─────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.employees_core'::regclass AND conname = 'employees_core_nik_not_null'
  ) THEN
    ALTER TABLE public.employees_core
      ADD CONSTRAINT employees_core_nik_not_null CHECK (nik IS NOT NULL AND btrim(nik) <> '');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.employees_core'::regclass AND conname = 'employees_core_nik_format'
  ) THEN
    ALTER TABLE public.employees_core
      ADD CONSTRAINT employees_core_nik_format CHECK (char_length(btrim(nik)) BETWEEN 6 AND 20);
  END IF;
END $$;

COMMENT ON CONSTRAINT employees_core_nik_not_null ON public.employees_core IS
  'P0-6 (Tahap 5.3): NIK wajib terisi — guard permanen, migration 206';
COMMENT ON CONSTRAINT employees_core_nik_format ON public.employees_core IS
  'P0-6 (Tahap 5.3): NIK 6..20 char setelah trim — guard permanen, migration 206';

-- ── 2. Guard p_nik di generate_worker_otp (CREATE OR REPLACE utuh) ──
-- Body live di-dump dulu (preflight7) agar perubahan seminimal mungkin:
-- hanya tambah blok guard p_nik/p_nrp di awal; logika lain identik.

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
  -- ── P0-6 guard (migration 206): p_nrp/p_nik wajib valid sebelum lookup ──
  IF p_nrp IS NULL OR btrim(p_nrp) = '' THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'NRP wajib diisi.');
  END IF;
  IF p_nik IS NULL OR LENGTH(btrim(p_nik)) < 5 OR LENGTH(btrim(p_nik)) > 20 THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'NIK tidak valid.');
  END IF;
  IF p_nik !~ '^[A-Za-z0-9 .\-]+$' THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'NIK tidak valid.');
  END IF;

  SELECT * INTO v_emp FROM employees_master WHERE nrp = p_nrp;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'NRP tidak terdaftar.');
  END IF;

  IF REPLACE(REPLACE(REPLACE(v_emp.nik,'.',''),'-',''),' ','') !=
     REPLACE(REPLACE(REPLACE(p_nik,'.',''),'-',''),' ','') THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'NRP dan NIK tidak cocok.');
  END IF;

  -- Rate limit dicek SEBELUM verifikasi password
  SELECT attempts INTO v_attempts FROM otp_attempts WHERE nrp = p_nrp;
  IF v_attempts IS NOT NULL AND v_attempts >= 5 THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Terlalu banyak percobaan. Tunggu 15 menit.');
  END IF;

  SELECT * INTO v_wp FROM worker_passwords WHERE nrp = p_nrp AND is_active = true;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akun belum aktif.');
  END IF;

  -- Password: bcrypt / sha256+salt / plaintext legacy
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

-- ── 3. Regresi: approve RPCs INSERT ke VIEW employees_master ─────
-- employees_master = VIEW (migration 183) → INSERT selalu error.
-- Tulis ke BASE TABLE employees_core + guard NIK (P0-6).
-- (5.9: write-path permanen untuk VIEW = item terpisah.)

CREATE OR REPLACE FUNCTION public.admin_approve_pending(p_id INT)
RETURNS JSONB AS $$
DECLARE
  v_entry RECORD;
  v_caller TEXT := authz_current_nrp();
  v_nik TEXT;
BEGIN
  IF v_caller IS NULL
     OR (NOT authz_check_admin('employee.create') AND NOT authz_check_admin('recruitment.approve')) THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  SELECT * INTO v_entry FROM daftar_baru WHERE id = p_id AND status = 'PENDING';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Entry tidak ditemukan atau sudah diproses.');
  END IF;

  -- P0-6: NIK wajib valid sebelum employee dibuat
  v_nik := btrim(COALESCE(v_entry.nik, ''));
  IF v_nik = '' OR LENGTH(v_nik) < 5 OR LENGTH(v_nik) > 20
     OR v_nik !~ '^[A-Za-z0-9 .\-]+$' THEN
    UPDATE daftar_baru SET status = 'REJECTED' WHERE id = p_id AND status = 'PENDING';
    INSERT INTO audit_log (actor, action, detail, timestamp)
    VALUES (v_caller, 'PENDING_APPROVE_REJECTED_NIK', 'daftar_baru ' || p_id || ' — NIK tidak valid', NOW());
    RETURN jsonb_build_object('ok', FALSE,
      'msg', 'NIK pendaftar tidak valid — pendaftaran ditolak, minta pendaftar ulang dengan NIK benar.');
  END IF;

  -- migration 183: employees_master = VIEW → INSERT ke BASE TABLE employees_core
  INSERT INTO employees_core (employee_id, nrp, nik, nama, email, status_kerja, is_active)
  VALUES ('EMP' || p_id, v_entry.nrp, v_nik, v_entry.nama, v_entry.email, 'Active', true)
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

CREATE OR REPLACE FUNCTION public.admin_bulk_approve_pending(p_ids integer[])
RETURNS JSONB AS $$
DECLARE
  v_id INT;
  v_entry RECORD;
  v_ok INT := 0;
  v_fail INT := 0;
  v_caller TEXT := authz_current_nrp();
  v_nik TEXT;
BEGIN
  IF v_caller IS NULL
     OR (NOT authz_check_admin('employee.create') AND NOT authz_check_admin('recruitment.approve')) THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak');
  END IF;
  IF p_ids IS NULL OR array_length(p_ids, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Tidak ada ID yang dipilih');
  END IF;

  FOREACH v_id IN ARRAY p_ids LOOP
    BEGIN
      SELECT * INTO v_entry FROM daftar_baru WHERE id = v_id AND status = 'PENDING';
      IF FOUND THEN
        -- P0-6: NIK wajib valid; entry tanpa NIK valid di-skip (ditolak), loop lanjut
        v_nik := btrim(COALESCE(v_entry.nik, ''));
        IF v_nik = '' OR LENGTH(v_nik) < 5 OR LENGTH(v_nik) > 20
           OR v_nik !~ '^[A-Za-z0-9 .\-]+$' THEN
          UPDATE daftar_baru SET status = 'REJECTED' WHERE id = v_id AND status = 'PENDING';
          v_fail := v_fail + 1;
          CONTINUE;
        END IF;

        -- migration 183: INSERT ke BASE TABLE employees_core (bukan VIEW)
        INSERT INTO employees_core (employee_id, nrp, nik, nama, email, status_kerja, is_active)
        VALUES ('EMP' || v_id, v_entry.nrp, v_nik, v_entry.nama, v_entry.email, 'Active', true)
        ON CONFLICT (nrp) DO NOTHING;

        INSERT INTO worker_passwords (nrp, password_hash, salt, is_active)
        VALUES (v_entry.nrp, COALESCE(v_entry.password_hash, 'pending'), COALESCE(v_entry.salt, ''), true)
        ON CONFLICT (nrp) DO NOTHING;

        INSERT INTO user_roles (nrp, role_level, plan)
        VALUES (v_entry.nrp, 1, 'FREE')
        ON CONFLICT (nrp) DO NOTHING;

        UPDATE daftar_baru SET status = 'APPROVED' WHERE id = v_id;
        v_ok := v_ok + 1;
      ELSE
        v_fail := v_fail + 1;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      v_fail := v_fail + 1;
    END;
  END LOOP;

  INSERT INTO audit_log (actor, action, detail, timestamp)
  VALUES (v_caller, 'PENDING_BULK_APPROVE', 'ok=' || v_ok || ', fail=' || v_fail, NOW());
  RETURN jsonb_build_object('ok', TRUE, 'approved', v_ok, 'failed', v_fail);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

-- ── 4. Verify ─────────────────────────────────────────────────────
SELECT '206.1 nik constraint present' AS test,
  CASE WHEN EXISTS (SELECT 1 FROM pg_constraint
    WHERE conrelid='public.employees_core'::regclass AND conname='employees_core_nik_not_null')
  THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT '206.2 nik format constraint present' AS test,
  CASE WHEN EXISTS (SELECT 1 FROM pg_constraint
    WHERE conrelid='public.employees_core'::regclass AND conname='employees_core_nik_format')
  THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT '206.3 generate_worker_otp has P0-6 guard' AS test,
  CASE WHEN position('nik tidak valid' in lower(pg_get_functiondef(p.oid))) > 0
  THEN 'PASS' ELSE 'FAIL' END AS result
FROM pg_proc p WHERE p.proname='generate_worker_otp'
  AND pg_get_function_identity_arguments(p.oid) LIKE '%p_nik%';

SELECT '206.4 approve RPCs write base table' AS test,
  CASE WHEN position('insert into employees_core' in lower(pg_get_functiondef(p.oid))) > 0
        AND position('employees_master' in lower(pg_get_functiondef(p.oid))) = 0
  THEN 'PASS' ELSE 'FAIL' END AS result
FROM pg_proc p WHERE p.proname='admin_approve_pending';

SELECT '206.5 bulk approve RPC writes base table' AS test,
  CASE WHEN position('insert into employees_core' in lower(pg_get_functiondef(p.oid))) > 0
  THEN 'PASS' ELSE 'FAIL' END AS result
FROM pg_proc p WHERE p.proname='admin_bulk_approve_pending';
