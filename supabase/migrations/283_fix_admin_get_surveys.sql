-- ============================================================================
-- 283 — Fix admin_get_surveys (P2-F14-BW).
--
-- Temuan GREEN 282 (.agents/logs/m282-green.log) + probe 2026-10-18
-- (.agents/logs/m283-probe.log). Ternyata EMPAT masalah, bukan satu:
--   1) `42703 column s.description does not exist` — body merujuk
--      `s.description`, `s.survey_type`, `s.target_audience` yang TIDAK ADA di
--      `hr_surveys`. Kolom live: id, title, questions, status, created_at,
--      updated_at, created_by, updated_by.
--   2) `response_count`/`avg_score` membaca `survey_responses` (tabel LAIN,
--      `survey_id` text), padahal `submit_survey` dan `get_survey_results`
--      menulis/membaca `hr_survey_responses` (survey_id integer) → begitu
--      error kolom diperbaiki, angkanya tetap SALAH (selalu 0) tanpa error.
--   3) Tanpa gate authz in-body.
--   4) `authenticated` TIDAK punya EXECUTE (ACL pre-image hanya postgres +
--      service_role) → admin lewat PostgREST dapat 42501 "permission denied",
--      jadi memperbaiki kolom saja TIDAK cukup untuk menghidupkan halaman.
--
-- Kontrak konsumen (src/features/core/engagement/SurveyPage.tsx):
--   * RPC dipilih `isAdminRole(role) ? 'admin_get_surveys' : 'get_active_surveys'`;
--     `isAdminRole` = `role.startsWith('admin_') || role === 'admin'`
--     (src/lib/role-utils.ts:11).
--   * Field yang benar-benar dipakai: `data.ok`, `data.data[]`, `s.id`,
--     `s.title`, `s.questions` (jumlah pertanyaan). Key lama yang tidak ada di
--     tabel (`description`/`survey_type`/`target_audience`) DIBUANG — fungsi ini
--     belum pernah sekali pun mengembalikan data, jadi tidak ada konsumen yang
--     bisa bergantung padanya.
--   * `questions` DITAMBAH (aditif) supaya admin melihat jumlah pertanyaan sama
--     seperti worker (`get_active_surveys` mengembalikan id/title/questions).
--
-- Gate: `is_admin_or_owner()` — helper existing (EXISTS user_role_assignments
--   role_code LIKE 'admin\_%' + owner bypass) = paritas persis dengan
--   `isAdminRole` + owner. BUKAN `authz_check_admin('employee.view_all')`:
--   migrasi 272 mencabut permission itu dari HRD, sedangkan halaman ini tidak
--   membatasi HRD (guard modal tetap `[admin_pusat, admin_hrd]`). Worker →
--   RAISE 42501 (fail-closed).
--
-- Bentuk lain dipertahankan: `LIMIT` tetap DI DALAM subquery (pola 282, supaya
-- membatasi baris data), signature tanpa argumen, return `{ok, data}`,
-- SECURITY DEFINER, VOLATILE, SET search_path.
-- Pre-image byte-exact: .agents/logs/m283-preimage.json — oid 298143,
--   md5 prosrc 3d655a3dd7179f35b3b72c772faa590b, ACL postgres+service_role.
-- Rollback: supabase/scripts/rollback/283_rollback.sql.
-- P4: tanpa BEGIN/COMMIT — wrapper apply-migration.mjs memegang transaksi.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_get_surveys()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  IF NOT is_admin_or_owner() THEN
    RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501';
  END IF;
  RETURN (
  SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
    jsonb_build_object('id', s.id, 'title', s.title, 'questions', s.questions,
      'status', s.status,
      'response_count', (SELECT COUNT(*) FROM hr_survey_responses sr WHERE sr.survey_id = s.id),
      'avg_score', (SELECT ROUND(AVG(sr.score), 1) FROM hr_survey_responses sr WHERE sr.survey_id = s.id),
      'created_at', s.created_at)
    ORDER BY s.created_at DESC), '[]'::jsonb))
  FROM (
    SELECT s.id, s.title, s.questions, s.status, s.created_at
    FROM hr_surveys s
    ORDER BY s.created_at DESC
    LIMIT 30
  ) s);
END;
$function$;

-- Grant: tanpa ini admin lewat PostgREST tetap 42501 (temuan 4 di header).
GRANT EXECUTE ON FUNCTION public.admin_get_surveys() TO authenticated;
