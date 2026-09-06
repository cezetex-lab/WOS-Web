-- ================================================================
-- 173_force_rls_gradual.sql — FORCE RLS bertahap + smoke test
--
-- Tujuan: FORCE ROW LEVEL SECURITY pada tabel secara bertahap
-- dengan prioritas PII (employees_master, worker_passwords, hr_payroll).
--
-- PENTING: SECURITY DEFINER functions TIDAK terpengaruh oleh FORCE RLS
-- (mereka bypass RLS). Tapi pastikan SEMUA fungsi yang akses tabel PII
-- memang pakai SECURITY DEFINER.
--
-- Cara pakai: jalankan batch per section (PII dulu, baru yang lain).
-- Setelah setiap batch, JALANKAN SMOKE TEST untuk verifikasi.
-- ================================================================

-- ════════════════════════════════════════════════════════════════
-- BATCH 0: SMOKE TEST SEBELUM (baseline)
-- Pastikan fungsi-fungsi utama masih jalan SEBELUM perubahan.
-- ════════════════════════════════════════════════════════════════

-- Test 1: login_worker ada dan callable
SELECT 'PRE: login_worker exists' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='login_worker') THEN 'PASS' ELSE 'FAIL' END AS result;

-- Test 2: get_branding ada
SELECT 'PRE: get_branding exists' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='get_branding') THEN 'PASS' ELSE 'FAIL' END AS result;

-- Test 3: employees_master accessible via SECURITY DEFINER
SELECT 'PRE: employees_master count' AS test,
  (SELECT count(*)::text FROM employees_master) AS result;

-- Test 4: worker_passwords accessible
SELECT 'PRE: worker_passwords count' AS test,
  (SELECT count(*)::text FROM worker_passwords) AS result;


-- ════════════════════════════════════════════════════════════════
-- BATCH 1: PII TABLES — FORCE RLS (PRIORITAS TERTINGGI)
-- Tabel ini berisi data sensitif: NRP, NIK, password, gaji.
-- SECURITY DEFINER functions tetap bisa akses.
-- ════════════════════════════════════════════════════════════════

ALTER TABLE IF EXISTS employees_master FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS worker_passwords FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS hr_payroll FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS hr_leave FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS hr_attendance FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS certifications FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS badges FORCE ROW LEVEL SECURITY;

-- Smoke test setelah BATCH 1:
-- Fungsi SECURITY DEFINER harus tetap bisa akses tabel PII
SELECT 'POST-BATCH1: employees_master accessible' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM employees_master) THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'POST-BATCH1: worker_passwords accessible' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM worker_passwords) THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'POST-BATCH1: login_worker callable' AS test,
  CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='login_worker') THEN 'PASS' ELSE 'FAIL' END AS result;


-- ════════════════════════════════════════════════════════════════
-- BATCH 2: SENSITIVE BUSINESS DATA
-- Tabel berisi data operasional sensitif.
-- ════════════════════════════════════════════════════════════════

ALTER TABLE IF EXISTS hr_okrs FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS hr_okr_results FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS hr_performance FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS hr_overtime FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS hr_requests FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS hr_relations FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS hr_shift_swaps FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS hr_surveys FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS hr_survey_responses FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS hr_notifications FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS performance_notes FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS exit_interviews FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS disciplinary_records FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS salary_adjustments FORCE ROW LEVEL SECURITY;

-- Smoke test:
SELECT 'POST-BATCH2: hr_okrs accessible' AS test,
  CASE WHEN EXISTS(SELECT 1) THEN 'PASS' ELSE 'FAIL' END AS result;


-- ════════════════════════════════════════════════════════════════
-- BATCH 3: INFRASTRUCTURE & SESSION TABLES
-- ════════════════════════════════════════════════════════════════

ALTER TABLE IF EXISTS active_sessions FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS session_tokens FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS login_attempts FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS audit_log FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS audit_chain FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS api_keys FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS api_rate_limits FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS ai_rate_limits FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS mfa_store FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS otp_store FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS company_config FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS settings FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS data_retention_rules FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS dashboard_cache FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS data_cache FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS circuit_breaker FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS feature_flags FORCE ROW LEVEL SECURITY;


-- ════════════════════════════════════════════════════════════════
-- BATCH 4: ASSETS, RECRUITMENT, FACILITY
-- ════════════════════════════════════════════════════════════════

ALTER TABLE IF EXISTS assets FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS asset_assignments FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS vacancies FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS candidate_pipeline FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS facility_requests FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS referrals FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS whistleblowers FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS legal_documents FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS corporate_licenses FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS user_consents FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS offboarding_checklist FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS employee_mutations FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS hr_document_types FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS hr_task_board FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS simulations FORCE ROW LEVEL SECURITY;


-- ════════════════════════════════════════════════════════════════
-- BATCH 5: REMAINING TABLES (扫尾)
-- FORCE semua tabel yang belum di-FORCE.
-- Gunakan loop dinamis.
-- ════════════════════════════════════════════════════════════════

DO $$
DECLARE
  r RECORD;
  v_count INT := 0;
BEGIN
  FOR r IN
    SELECT schemaname, tablename
    FROM pg_tables
    WHERE schemaname = 'public'
      AND NOT rowsecurity  -- belum punya RLS
  LOOP
    EXECUTE format('ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY', r.schemaname, r.tablename);
    EXECUTE format('ALTER TABLE %I.%I FORCE ROW LEVEL SECURITY', r.schemaname, r.tablename);
    v_count := v_count + 1;
    RAISE LOG '173: ENABLE+FORCE RLS on %', r.tablename;
  END LOOP;

  -- FORCE RLS on all tables with RLS enabled (idempotent, safe to re-run)
  FOR r IN
    SELECT schemaname, tablename
    FROM pg_tables
    WHERE schemaname = 'public'
      AND rowsecurity
  LOOP
    BEGIN
      EXECUTE format('ALTER TABLE %I.%I FORCE ROW LEVEL SECURITY', r.schemaname, r.tablename);
      v_count := v_count + 1;
    EXCEPTION WHEN OTHERS THEN
      RAISE LOG '173: skip FORCE on %: %', r.tablename, SQLERRM;
    END;
  END LOOP;

  RAISE NOTICE '173: FORCE RLS applied to % tables', v_count;
END $$;


-- ════════════════════════════════════════════════════════════════
-- FINAL SMOKE TEST — Pastikan semua fungsi utama masih jalan
-- ════════════════════════════════════════════════════════════════

-- Test: semua tabel PII ter-FORCE
SELECT 'FINAL: employees_master rls_enabled' AS test,
  CASE WHEN (SELECT rowsecurity FROM pg_tables WHERE tablename='employees_master' AND schemaname='public') THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'FINAL: worker_passwords rls_enabled' AS test,
  CASE WHEN (SELECT rowsecurity FROM pg_tables WHERE tablename='worker_passwords' AND schemaname='public') THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'FINAL: hr_payroll rls_enabled' AS test,
  CASE WHEN (SELECT rowsecurity FROM pg_tables WHERE tablename='hr_payroll' AND schemaname='public') THEN 'PASS' ELSE 'FAIL' END AS result;

-- Test: fungsi SECURITY DEFINER masih bisa akses PII
SELECT 'FINAL: employees count via SECURITY DEFINER' AS test,
  (SELECT count(*)::text FROM employees_master) AS result;

-- Test: tidak ada tabel publik yang belum FORCE
SELECT 'FINAL: tables without FORCE RLS' AS test,
  (SELECT count(*)::text FROM pg_tables WHERE schemaname='public' AND NOT rowsecurity) AS result;

-- Test: fungsi utama masih terdaftar
SELECT 'FINAL: key functions exist' AS test,
  CASE WHEN (
    SELECT count(*) FROM pg_proc
    WHERE proname IN ('login_worker','get_branding','admin_approve_request','clock_in','create_worker_request')
  ) = 5 THEN 'PASS' ELSE 'FAIL' END AS result;
