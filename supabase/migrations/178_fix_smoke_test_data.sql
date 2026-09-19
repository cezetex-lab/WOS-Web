-- ════════════════════════════════════════════════════════════════
-- Helper smoke test sesi — WAJIB ada sebelum asersi di bawah.
--
-- Berkas ini adalah SKRIP DIAGNOSTIK (tidak mengubah schema), tetapi ia memanggil
-- RPC dengan data demo. Pada INSTALASI DARI AWAL sebagian data itu memang belum ada
-- (mis. NRP 'TEST'), sehingga panggilan seperti create_worker_request('TEST', ...)
-- dulu melempar exception dan MEMBATALKAN SELURUH rantai instalasi di berkas ini.
-- Sejak 2026-09-18 setiap asersi dijalankan lewat helper ini: exception ditangkap dan
-- dilaporkan sebagai baris hasil (PASS / FAIL / ERROR), bukan kegagalan migrasi.
--
-- Ditempatkan di pg_temp sehingga hilang sendiri di akhir sesi: tidak pernah menjadi
-- objek produksi, tidak perlu GRANT, dan tidak ikut terhitung di metrik DB.
-- CREATE OR REPLACE supaya aman walau beberapa berkas smoke memakainya berurutan
-- dalam satu sesi.
-- ════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION pg_temp.smoke_check(p_sql text) RETURNS text
LANGUAGE plpgsql AS $smoke_helper$
DECLARE v text;
BEGIN
  EXECUTE p_sql INTO v;
  RETURN CASE
    WHEN v IN ('t','true') THEN 'PASS'
    WHEN v IS NULL         THEN 'FAIL (hasil NULL)'
    ELSE 'FAIL: ' || v
  END;
EXCEPTION WHEN OTHERS THEN
  RETURN 'ERROR: ' || SQLERRM;
END
$smoke_helper$;

-- ================================================================
-- 178_fix_smoke_test_data.sql — Use real NRP for smoke tests
--
-- The 4 remaining failures in 175 are all test data issues:
-- 'TEST' NRP doesn't exist in employees_master (FK constraint)
-- Fix: use NRP001 (CEO, exists in seed data)
-- ================================================================

-- Verify NRP001 exists
SELECT 'VERIFY: NRP001 exists' AS test,pg_temp.smoke_check($smoke$SELECT (EXISTS(SELECT 1 FROM employees_master WHERE nrp='NRP001'))$smoke$) AS result;

-- Verify all key functions work with real data
SELECT 'clock_in with NRP001' AS test,pg_temp.smoke_check($smoke$SELECT (clock_in('NRP001') IS NOT NULL)$smoke$) AS result;

SELECT 'get_timesheets with NRP001' AS test,pg_temp.smoke_check($smoke$SELECT (get_timesheets('NRP001') IS NOT NULL)$smoke$) AS result;

SELECT 'create_worker_request with NRP001' AS test,pg_temp.smoke_check($smoke$SELECT (create_worker_request('NRP001','LEAVE','test','test') IS NOT NULL)$smoke$) AS result;

SELECT 'get_whistleblowers' AS test,pg_temp.smoke_check($smoke$SELECT (get_whistleblowers() IS NOT NULL)$smoke$) AS result;

SELECT 'get_worker_narrative with NRP001' AS test,pg_temp.smoke_check($smoke$SELECT (get_worker_narrative('NRP001') IS NOT NULL)$smoke$) AS result;

SELECT 'get_worker_payroll_secure with NRP001' AS test,pg_temp.smoke_check($smoke$SELECT (get_worker_payroll_secure('NRP001') IS NOT NULL)$smoke$) AS result;

SELECT 'login_worker NRP001/CEO12345!' AS test,pg_temp.smoke_check($smoke$SELECT (login_worker('NRP001','NRP001','CEO12345!') IS NOT NULL)$smoke$) AS result;
