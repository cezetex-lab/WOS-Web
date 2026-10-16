-- ============================================================================
-- 275_rollback.sql — batalkan migrasi 275 (P2-F14-AX: fix SQL + gate 6
-- admin_get_* rusak).
--
-- Dijalankan MANUAL via psql (file ini punya BEGIN/COMMIT sendiri — berbeda
-- dari file migrasi yang P4-nya forbid BEGIN/COMMIT).
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/scripts/rollback/275_rollback.sql
--
-- ISI ROLLBACK
--   1. 6 fungsi dikembalikan ke PRE-IMAGE byte-exact (pg_get_functiondef LIVE
--      sebelum 275, digenerate .agents/scripts/ax-gen-rollback.mjs dengan guard
--      assert md5+length per fungsi):
--        admin_get_master_data            md5 ac61d5941d7c5b6249d31464676f6b66 len 472
--        admin_get_timesheet              md5 0386cea9c28298104bffce5f931ec593 len 533
--        admin_get_webhooks               md5 ce2eb0560eeea37eba7db536cdc680d3 len 309
--        admin_get_sso_providers          md5 2fe571522c8fa6e2f17c2f33396c6611 len 267
--        admin_get_external_notifications md5 5b0cc42ceea7088fdf6a2d281e568605 len 308
--        admin_get_webhook_logs           md5 115559464476bbb5c74137c0a5717f6f len 356
--      (fungsi rusak kembali: error 42703/42803; gate hilang — worker kena
--       error SQL lagi, baseline pra-275 persis).
--   2. ACL dikembalikan eksplisit ke pre-275 (defensif; CREATE OR REPLACE sudah
--      mempertahankan ACL, ini mengunci kontrak):
--        REVOKE ... FROM PUBLIC, anon; GRANT ... TO authenticated, service_role
--
-- CATATAN: 275 tidak mengubah signature/attrs/oid; schema_migrations tidak
-- disentuh oleh file ini (registrasi hanya lewat wrapper db:migrate).
-- Idempoten (jalan kedua kali tidak mengubah apa pun).
-- ============================================================================

BEGIN;

-- pre-image md5 ac61d5941d7c5b6249d31464676f6b66 len 472
CREATE OR REPLACE FUNCTION public.admin_get_master_data()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true,
      'roles', (SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'nrp', ur.nrp, 'role', ur.role, 'tier', ur.tier, 'created_at', ur.created_at
      ) ORDER BY ur.created_at DESC), '[]'::jsonb) FROM user_roles ur LIMIT 100),
      'divisions', (SELECT COALESCE(jsonb_agg(DISTINCT jsonb_build_object(
        'divisi', o.divisi
      )), '[]'::jsonb) FROM hr_org o WHERE o.divisi IS NOT NULL)
    )
  );
END;
$function$;

-- pre-image md5 0386cea9c28298104bffce5f931ec593 len 533
CREATE OR REPLACE FUNCTION public.admin_get_timesheet()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'nrp', sub.nrp, 'date', sub.date, 'check_in', sub.check_in,
        'check_out', sub.check_out, 'status', sub.status, 'hours', sub.hours
      )
    ), '[]'::jsonb))
    FROM (
      SELECT a.nrp, a.date, a.check_in, a.check_out, a.status,
        ROUND(EXTRACT(EPOCH FROM (a.check_out - a.check_in)) / 3600, 1) as hours
      FROM hr_attendance a
      ORDER BY a.date DESC
      LIMIT 100
    ) sub
  );
END;
$function$;

-- pre-image md5 ce2eb0560eeea37eba7db536cdc680d3 len 309
CREATE OR REPLACE FUNCTION public.admin_get_webhooks()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('id', w.id, 'name', w.name, 'url', w.url, 'events', w.events, 'active', w.active, 'last_triggered_at', w.last_triggered_at)
    ), '[]'::jsonb))
    FROM webhook_configs w ORDER BY w.id
  );
END;
$function$;

-- pre-image md5 2fe571522c8fa6e2f17c2f33396c6611 len 267
CREATE OR REPLACE FUNCTION public.admin_get_sso_providers()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('id', s.id, 'name', s.name, 'provider_type', s.provider_type, 'enabled', s.enabled)
    ), '[]'::jsonb))
    FROM sso_providers s ORDER BY s.id
  );
END;
$function$;

-- pre-image md5 5b0cc42ceea7088fdf6a2d281e568605 len 308
CREATE OR REPLACE FUNCTION public.admin_get_external_notifications()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('id', e.id, 'channel', e.channel, 'event_types', e.event_types, 'active', e.active, 'last_sent_at', e.last_sent_at)
    ), '[]'::jsonb))
    FROM external_notifications e ORDER BY e.id
  );
END;
$function$;

-- pre-image md5 115559464476bbb5c74137c0a5717f6f len 356
CREATE OR REPLACE FUNCTION public.admin_get_webhook_logs()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('id', l.id, 'webhook_id', l.webhook_id, 'event', l.event, 'success', l.success, 'response_status', l.response_status, 'created_at', l.created_at)
      ORDER BY l.created_at DESC
    ), '[]'::jsonb))
    FROM webhook_logs l LIMIT 50
  );
END;
$function$;

-- ACL pre-275 (defensif, idempoten): postgres+authenticated+service_role, tanpa anon.
REVOKE EXECUTE ON FUNCTION public.admin_get_master_data() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_get_master_data() TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.admin_get_timesheet() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_get_timesheet() TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.admin_get_webhooks() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_get_webhooks() TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.admin_get_sso_providers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_get_sso_providers() TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.admin_get_external_notifications() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_get_external_notifications() TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.admin_get_webhook_logs() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_get_webhook_logs() TO authenticated, service_role;

COMMIT;
