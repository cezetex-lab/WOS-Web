-- ================================================================
-- 210_revoke_anon_remaining.sql — Tahap 5.8 (F-8 + A1/A2)
--
-- REVOKE anon/PUBLIC EXECUTE from 9 RPCs that should not be
-- callable without authentication.
-- ================================================================

-- REVOKE dari anon dan PUBLIC.
--
-- GUARD (2026-09-18): sebelumnya tiap REVOKE ditulis langsung, sehingga instalasi dari
-- awal GAGAL dengan `function ... does not exist` — fungsi `_legacy_*` ada di live hanya
-- karena RENAME manual (sumber migrasinya hilang, §5.8 SQL-02), dan di DB baru memang
-- tidak pernah dibuat. Sekarang tiap tanda tangan diperiksa `to_regprocedure()`:
-- yang tidak ada → NOTICE (bukan ERROR), yang ada → REVOKE (perilaku sama seperti live).
DO $$
DECLARE
  v_sigs TEXT[] := ARRAY[
    -- tahap 5.8 (F-8 + A1/A2)
    'public.get_field_status(text)',
    'public.get_irrigation_status(text)',
    'public.get_maintenance_schedule(text)',
    'public.get_mill_production(text)',
    'public.get_yield_data(text)',
    'public.change_password(text, text, text)',
    'public.check_login_lockout(text, text)',
    'public.get_branding()',
    'public.cleanup_rate_limits()',
    -- additional REVOKEs (post-verifikasi 2026-09-13)
    'public.create_harvest_record(text, text, numeric, numeric, text)',
    'public.get_organization_health()',
    'public.report_safety_incident(text, text, text, text, text)',
    'public.update_audit_timestamp()',
    'public._legacy_get_breakdown_log_by_site(text)',
    'public._legacy_get_estate_blocks_by_bu(text)',
    'public._legacy_get_harvest_records_by_bu(text)',
    'public._legacy_get_nursery_data_by_bu(text)',
    'public._legacy_get_packing_log_by_site(text)',
    'public._legacy_get_qc_results_by_site(text)',
    'public._legacy_get_transport_dispatch_by_bu(text)'
  ];
  v_sig TEXT;
  v_oid regprocedure;
  v_n INTEGER := 0;
BEGIN
  FOREACH v_sig IN ARRAY v_sigs LOOP
    v_oid := to_regprocedure(v_sig);
    IF v_oid IS NULL THEN
      RAISE NOTICE '210: % tidak ada — REVOKE dilewati', v_sig;
      CONTINUE;
    END IF;
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM anon, PUBLIC', v_oid);
    v_n := v_n + 1;
  END LOOP;
  RAISE NOTICE '210: REVOKE diterapkan pada % fungsi', v_n;
END $$;

-- Verify: anon should have 0 EXECUTE on these
SELECT '210.1 anon revoked from 9 RPCs' AS test,
  CASE WHEN (
    SELECT count(*) FROM (
      SELECT p.proname, g.rolname
      FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace,
      aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
      JOIN pg_roles g ON g.oid=a.grantee
      WHERE n.nspname='public' AND p.proname IN (
        'get_field_status','get_irrigation_status','get_maintenance_schedule',
        'get_mill_production','get_yield_data','change_password',
        'check_login_lockout','get_branding','cleanup_rate_limits'
      ) AND g.rolname = 'anon'
    ) t
  ) = 0 THEN 'PASS' ELSE 'FAIL' END AS result;

-- Additional REVOKEs (post-verifikasi 2026-09-13) — sudah dipindahkan ke blok
-- ber-guard `to_regprocedure` di atas (2026-09-18) supaya berkas ini tidak lagi
-- menggagalkan instalasi dari awal.
