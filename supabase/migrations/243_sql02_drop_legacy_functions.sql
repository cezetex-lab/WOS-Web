-- 243_sql02_drop_legacy_functions.sql
-- SQL-02 — DROP 13 fungsi legacy tanpa sumber migrasi (keputusan user: Opsi A).
--
-- Bukti read-only (probe live + grep, 2026-09-21):
--   * 0 pemakai di src/          (git grep "_legacy" src/        -> 0 match)
--   * 0 fungsi caller internal   (pg_proc.prosrc cross-join      -> 0 baris)
--   * 0 view yang menyinggung    (pg_views.definition            -> 0 baris)
--   * grant sudah dicabut        (REVOKE di 210 / 073)
-- Sengaja TIDAK di-drop:
--   * _legacy_get_estate_blocks_paged (punya sumber di 073, di-restamp SQL-11)
--   * get_enabled_modules_legacy_noarg (punya sumber di 205)
-- Pola idempoten: guard to_regprocedure (sama seperti 172/210/221/226) —
-- replay di instalasi baru = semua "skip (not found)", tanpa error.
-- Lihat juga 008_restore_missing_objects.sql:19 (keputusan desain: fungsi ini
-- memang tidak di-instalasi; 243 menyelaraskan live dengan keputusan itu).

DO $$
DECLARE
  v_names text[] := ARRAY[
    '_legacy_create_worker_request_dated(text,text,text,date,date)',
    '_legacy_generate_worker_otp_nopass(text,text)',
    '_legacy_get_breakdown_log_by_site(text)',
    '_legacy_get_estate_blocks_by_bu(text)',
    '_legacy_get_harvest_records_by_bu(text)',
    '_legacy_get_nursery_data_by_bu(text)',
    '_legacy_get_packing_log_by_site(text)',
    '_legacy_get_qc_results_by_site(text)',
    '_legacy_get_transport_dispatch_by_bu(text)',
    '_legacy_get_worker_requests_by_nrp(text)',
    '_legacy_list_ideas_by_nrp(text)',
    '_legacy_owner_toggle_lock_2arg(text,boolean)',
    'worker_update_profile_legacy(text,text,text,text)'
  ];
  v_name text;
BEGIN
  FOREACH v_name IN ARRAY v_names LOOP
    IF to_regprocedure('public.' || v_name) IS NOT NULL THEN
      EXECUTE 'DROP FUNCTION public.' || v_name;
      RAISE NOTICE 'dropped: %', v_name;
    ELSE
      RAISE NOTICE 'skip (not found): %', v_name;
    END IF;
  END LOOP;
END $$;
