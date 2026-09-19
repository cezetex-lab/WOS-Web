-- ============================================================================
-- 231_apply_missing_effects.sql
--
-- Migrasi ini menambahkan efek yang tercatat di schema_migrations (199/201/206/214/215)
-- tapi belum ada di DB live. Semua pernyataan idempoten; aman dijalankan berulang kali.
--
-- Sumber: audit 2026-09-18, temp-audit-missing-effects.mjs → 13 efek hilang.
-- ============================================================================

-- ── 199: auth_testing_override table + index + RLS + policy ─────────────────
CREATE TABLE IF NOT EXISTS public.auth_testing_override (
  id integer PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  nrp text NOT NULL UNIQUE,
  mfa_bypass boolean NOT NULL DEFAULT false,
  otp_bypass boolean NOT NULL DEFAULT false,
  updated_by_owner uuid NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_auth_testing_override_nrp
  ON public.auth_testing_override (nrp);

ALTER TABLE public.auth_testing_override ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS owner_only_testing_override ON public.auth_testing_override;
CREATE POLICY owner_only_testing_override ON public.auth_testing_override
  FOR ALL
  USING (auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1 FROM admin_roles ar
    JOIN user_role_assignments ura ON ura.role_code = ar.role_code
    WHERE ura.nrp = (SELECT nrp FROM employees_core WHERE auth_id = auth.uid())
      AND ar.role_code IN ('admin_pusat', 'owner')
  ));

-- ── 201: auth_testing_override_bypass + wrapper verify_* ────────────────────
CREATE OR REPLACE FUNCTION public.auth_testing_override_bypass(p_nrp text, p_type text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $bypass$
DECLARE
  v_override public.auth_testing_override;
BEGIN
  IF p_type = 'mfa' THEN
    SELECT * INTO v_override FROM public.auth_testing_override
     WHERE nrp = p_nrp AND mfa_bypass = true;
  ELSIF p_type = 'otp' THEN
    SELECT * INTO v_override FROM public.auth_testing_override
     WHERE nrp = p_nrp AND otp_bypass = true;
  END IF;
  RETURN FOUND;
END;
$bypass$;

-- Pensiunkan implementasi asli menjadi *_core (hanya sekali)
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

-- Wrapper jsonb (kontrak tetap, hanya menambah short-circuit override)
CREATE OR REPLACE FUNCTION public.verify_mfa(p_nrp text, p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $mfa$
BEGIN
  IF public.auth_testing_override_bypass(p_nrp, 'mfa') THEN
    RETURN jsonb_build_object('ok', true, 'bypass', true, 'msg', 'MFA dilewati (auth_testing_override)');
  END IF;
  IF to_regprocedure('public.verify_mfa_core(text,text)') IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Implementasi verify_mfa tidak tersedia');
  END IF;
  RETURN public.verify_mfa_core(p_nrp, p_code);
END;
$mfa$;

CREATE OR REPLACE FUNCTION public.verify_worker_otp(p_nrp text, p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $wotp$
BEGIN
  IF public.auth_testing_override_bypass(p_nrp, 'otp') THEN
    RETURN jsonb_build_object('ok', true, 'bypass', true, 'msg', 'OTP dilewati (auth_testing_override)');
  END IF;
  IF to_regprocedure('public.verify_worker_otp_core(text,text)') IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Implementasi verify_worker_otp tidak tersedia');
  END IF;
  RETURN public.verify_worker_otp_core(p_nrp, p_code);
END;
$wotp$;

CREATE OR REPLACE FUNCTION public.verify_admin_otp(p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $aotp$
BEGIN
  IF to_regprocedure('public.verify_admin_otp_core(text)') IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Implementasi verify_admin_otp tidak tersedia');
  END IF;
  RETURN public.verify_admin_otp_core(p_code);
END;
$aotp$;

-- Hak akses wrapper
REVOKE ALL ON FUNCTION public.verify_mfa(text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.verify_worker_otp(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.verify_admin_otp(text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.verify_worker_otp(text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.verify_admin_otp(text) TO anon;
GRANT EXECUTE ON FUNCTION public.verify_mfa(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_worker_otp(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_admin_otp(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.auth_testing_override_bypass(text, text) TO authenticated;

-- ── 206: NIK guard + approve RPCs tulis ke employees_core ──────────────────
-- Backfill NIK sebelum constraint (idempoten; live sudah bersih)
UPDATE public.employees_core
   SET nik = 'NRP-' || nrp
 WHERE nik IS NULL
    OR btrim(nik) = ''
    OR char_length(btrim(nik)) NOT BETWEEN 6 AND 20;

-- Constraint permanen NIK
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.employees_core'::regclass
      AND conname = 'employees_core_nik_not_null'
  ) THEN
    ALTER TABLE public.employees_core
      ADD CONSTRAINT employees_core_nik_not_null
      CHECK (nik IS NOT NULL AND btrim(nik) <> '');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.employees_core'::regclass
      AND conname = 'employees_core_nik_format'
  ) THEN
    ALTER TABLE public.employees_core
      ADD CONSTRAINT employees_core_nik_format
      CHECK (char_length(btrim(nik)) BETWEEN 6 AND 20);
  END IF;
END $$;

-- Guard NIK di generate_worker_otp
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

-- Approve RPCs: tulis ke base table employees_core
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

  v_nik := btrim(COALESCE(v_entry.nik, ''));
  IF v_nik = '' OR LENGTH(v_nik) < 5 OR LENGTH(v_nik) > 20
     OR v_nik !~ '^[A-Za-z0-9 .\-]+$' THEN
    UPDATE daftar_baru SET status = 'REJECTED' WHERE id = p_id AND status = 'PENDING';
    INSERT INTO audit_log (actor, action, detail, timestamp)
    VALUES (v_caller, 'PENDING_APPROVE_REJECTED_NIK', 'daftar_baru ' || p_id || ' — NIK tidak valid', NOW());
    RETURN jsonb_build_object('ok', FALSE,
      'msg', 'NIK pendaftar tidak valid — pendaftaran ditolak, minta pendaftar ulang dengan NIK benar.');
  END IF;

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
        v_nik := btrim(COALESCE(v_entry.nik, ''));
        IF v_nik = '' OR LENGTH(v_nik) < 5 OR LENGTH(v_nik) > 20
           OR v_nik !~ '^[A-Za-z0-9 .\-]+$' THEN
          UPDATE daftar_baru SET status = 'REJECTED' WHERE id = v_id AND status = 'PENDING';
          v_fail := v_fail + 1;
          CONTINUE;
        END IF;

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

-- ── 215: RLS enabled + fix match_documents + admin_get_payroll join ─────────
-- RLS enabled untuk ai_* tables
ALTER TABLE public.ai_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_rate_limits ENABLE ROW LEVEL SECURITY;

-- match_documents: pastikan tidak ada precedence bug
CREATE OR REPLACE FUNCTION public.match_documents(
  query_embedding vector,
  match_count integer DEFAULT 5,
  filter_context text DEFAULT NULL::text
)
RETURNS TABLE(id uuid, title text, content text, context text, similarity double precision, metadata jsonb)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_caller TEXT;
  v_bu TEXT;
  v_role_level INT;
BEGIN
  SELECT nrp, business_unit_id, role_level INTO v_caller, v_bu, v_role_level
  FROM employees_master WHERE auth_id = auth.uid() LIMIT 1;

  IF v_role_level >= 4 OR EXISTS (
    SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = true
  ) THEN
    RETURN QUERY
    SELECT d.id, d.title, LEFT(d.content, 500)::text AS content, d.context,
      1 - (d.embedding <=> query_embedding) AS similarity, d.metadata
    FROM ai_documents d
    WHERE (filter_context IS NULL OR d.context = filter_context)
      AND d.embedding IS NOT NULL
    ORDER BY d.embedding <=> query_embedding
    LIMIT match_count;
    RETURN;
  END IF;

  RETURN QUERY
  SELECT d.id, d.title, LEFT(d.content, 500)::text AS content, d.context,
    1 - (d.embedding <=> query_embedding) AS similarity, d.metadata
  FROM ai_documents d
  WHERE (filter_context IS NULL OR d.context = filter_context)
    AND d.embedding IS NOT NULL
    AND (
      (d.metadata->>'bu') IS NULL
      OR d.metadata->>'bu' = v_bu
      OR v_bu IS NULL
    )
  ORDER BY d.embedding <=> query_embedding
  LIMIT match_count;
END;
$function$;

-- admin_get_payroll: pastikan join employees_core
CREATE OR REPLACE FUNCTION public.admin_get_payroll(p_period text DEFAULT NULL::text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $function$
DECLARE
  v_role TEXT;
BEGIN
  IF EXISTS (SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = TRUE) THEN
    v_role := 'admin_pusat';
  ELSE
    SELECT ura.role_code INTO v_role
    FROM user_role_assignments ura
    WHERE ura.nrp = authz_current_nrp()
      AND ura.role_code IN ('admin_pusat', 'admin_hrd', 'admin_finance')
    LIMIT 1;
  END IF;
  IF v_role IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak');
  END IF;
  RETURN COALESCE(
    (SELECT jsonb_build_object('ok', true, 'data', jsonb_agg(
       jsonb_build_object(
         'nrp', t.nrp, 'periode', t.periode,
         'nama', c.nama, 'divisi', c.divisi,
         'status_kerja', c.status_kerja, 'jenis', c.status_kerja,
         'base_salary', t.base_salary, 'allowance', t.allowance,
         'deduction', t.deduction, 'overtime_pay', t.overtime_pay,
         'net_salary', t.net_salary, 'gross_salary', t.gross_salary,
         'pph21_ter', t.pph21_ter, 'thr_amount', t.thr_amount,
         'nama_bank', e.nama_bank, 'no_rekening', e.no_rekening,
         'nama_rekening', e.nama_rekening,
         'lokasi_penempatan', c.lokasi_penempatan,
         'created_at', t.created_at
       ) ORDER BY t.periode DESC, t.nrp))
    FROM hr_payroll t
    LEFT JOIN employees_core c ON c.nrp = t.nrp
    LEFT JOIN employees_extended e ON e.nrp = t.nrp
    WHERE p_period IS NULL OR t.periode = p_period),
    jsonb_build_object('ok', true, 'data', '[]'::jsonb)
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.admin_get_payroll(text) TO anon, authenticated;

-- ── Verifikasi ──────────────────────────────────────────────────────────────
SELECT '231.1 auth_testing_override table' AS test,
  CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='auth_testing_override')
  THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT '231.2 auth_testing_override index' AS test,
  CASE WHEN EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='idx_auth_testing_override_nrp')
  THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT '231.3 auth_testing_override RLS' AS test,
  CASE WHEN (SELECT relrowsecurity FROM pg_class WHERE relname='auth_testing_override')
  THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT '231.4 auth_testing_override policy' AS test,
  CASE WHEN (SELECT count(*) FROM pg_policies WHERE schemaname='public' AND tablename='auth_testing_override') > 0
  THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT '231.5 auth_testing_override_bypass' AS test,
  CASE WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname='auth_testing_override_bypass')
  THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT '231.6 generate_worker_otp NIK guard' AS test,
  CASE WHEN position('nik tidak valid' in lower(pg_get_functiondef('public.generate_worker_otp(text,text,text)'::regprocedure))) > 0
  THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT '231.7 admin_approve_pending writes employees_core' AS test,
  CASE WHEN position('insert into employees_core' in lower(pg_get_functiondef('public.admin_approve_pending(int)'::regprocedure))) > 0
  THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT '231.8 admin_bulk_approve_pending writes employees_core' AS test,
  CASE WHEN position('insert into employees_core' in lower(pg_get_functiondef('public.admin_bulk_approve_pending(integer[])'::regprocedure))) > 0
  THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT '231.9 ai_documents RLS' AS test,
  CASE WHEN (SELECT relrowsecurity FROM pg_class WHERE relname='ai_documents')
  THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT '231.10 ai_conversations RLS' AS test,
  CASE WHEN (SELECT relrowsecurity FROM pg_class WHERE relname='ai_conversations')
  THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT '231.11 ai_rate_limits RLS' AS test,
  CASE WHEN (SELECT relrowsecurity FROM pg_class WHERE relname='ai_rate_limits')
  THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT '231.12 match_documents no precedence bug' AS test,
  CASE WHEN position('IS NULL OR' in pg_get_functiondef('public.match_documents(vector,integer,text)'::regprocedure)) = 0
  THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT '231.13 admin_get_payroll joins employees_core' AS test,
  CASE WHEN position('LEFT JOIN employees_core' in lower(pg_get_functiondef('public.admin_get_payroll(text)'::regprocedure))) > 0
  THEN 'PASS' ELSE 'FAIL' END AS result;
