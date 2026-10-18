-- ============================================================================
-- ROLLBACK 283 — restore pre-image byte-exact admin_get_surveys (P2-F14-BW)
-- (sumber: .agents/logs/m283-preimage.json — prosrc live SEBELUM apply 283.
--  oid 298143 · md5 prosrc 3d655a3dd7179f35b3b72c772faa590b
--  Body antara AS $function$ dan $function$; = prosrc persis TANPA newline
--  injeksi. ACL pre-image: postgres=X/postgres,service_role=X/postgres — jadi GRANT authenticated DICABUT lagi
--  agar rollback benar-benar kembali ke state sebelum 283.
--  P4: tanpa BEGIN/COMMIT — wrapper apply yang memegang transaksi.)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_get_surveys()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$

BEGIN RETURN (
  SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
    jsonb_build_object('id', s.id, 'title', s.title, 'description', s.description,
      'survey_type', s.survey_type, 'status', s.status, 'target_audience', s.target_audience,
      'response_count', (SELECT COUNT(*) FROM survey_responses sr WHERE sr.survey_id = s.id),
      'avg_score', (SELECT ROUND(AVG(sr.score), 1) FROM survey_responses sr WHERE sr.survey_id = s.id),
      'created_at', s.created_at)
    ORDER BY s.created_at DESC), '[]'::jsonb))
  FROM (
    SELECT s.id, s.title, s.description, s.survey_type, s.status, s.target_audience, s.created_at
    FROM hr_surveys s   -- ✅ FIXED: was 'surveys'
    ORDER BY s.created_at DESC
    LIMIT 30
  ) s);
END;

$function$;

REVOKE EXECUTE ON FUNCTION public.admin_get_surveys() FROM authenticated;
