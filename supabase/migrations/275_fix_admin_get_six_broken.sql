-- ============================================================================
-- 275 — P2-F14-AX (P1-F14-AA Tahap 2): perbaiki SQL 6 admin_get_* rusak +
--        sisipkan authz gate internal dalam SATU migrasi.
--
-- KENAPA SATU MIGRASI
--   6 fungsi error untuk SEMUA caller (42703/42803 — probe audit P1-F14-AA,
--   .agents/logs/ax-red-20261016.log: 12/12 error termasuk worker). Memperbaiki
--   SQL tanpa gate = membuka keran baru (worker langsung kena fungsi yang kini
--   jalan). Fix SQL + gate wajib bersamaan.
--
-- PELAJARAN AUDIT (dicatat di log): error pertama MENYEMBUNYIKAN error
-- berikutnya — loop pemeriksaan kolom harus sampai nol error, bukan berhenti di
-- 42703 pertama. Terbukti: master_data punya 2 error (tier + divisi), webhook_logs
-- punya 4 (webhook_id + event + success + response_status).
--
-- DAFTAR 6 FUNGSI + FIX
--   1. admin_get_master_data      42703 ur.tier → ur.role_level
--      + error tersembunyi: o.divisi (hr_org tidak punya kolom divisi)
--        → master_divisions.division_name
--      KEPUTUSAN USER 2026-10-16: tier→role_level (semantik level 1-5, basis
--      RBAC LV1-LV5); divisi→master_divisions (baca tabel master, bukan turunan).
--   2. admin_get_timesheet        42703 a.check_in (+ a.check_out, a.status)
--        → a.jam_masuk / a.jam_keluar / a.status_hadir (kandidat tunggal skema
--        hr_attendance); output key check_in/check_out/status DIPERTAHANKAN
--        lewat alias AS — konsumen tidak berubah.
--   3. admin_get_webhooks         42803 GROUP BY w.id
--        → ORDER BY dipindah ke subquery (pola admin_get_timesheet yang hidup).
--   4. admin_get_sso_providers    42803 GROUP BY s.id → idem.
--   5. admin_get_external_notifications 42803 GROUP BY e.id → idem.
--   6. admin_get_webhook_logs     42703 l.webhook_id (+ 3 error tersembunyi)
--        webhook_id    → target_url   (kolom baru di output; konsumen Integrations
--                        .tsx TIDAK memakai key 'webhook_id' — interface WebhookLog
--                        = {id,event,created_at,success,response_status})
--        event         → event_type   (key output 'event' dipertahankan)
--        success       → COALESCE(response_code BETWEEN 200 AND 299, FALSE)
--        response_status → response_code (integer — cocok kontrak TS konsumen)
--      KEPUTUSAN USER 2026-10-16: response_code dipilih di atas status text
--      karena kolom status 0 rows (tanpa sampel nilai — tak boleh diasumsi).
--
-- GATE (pola persis 274: EXISTS user_role_assignments + owner bypass + ERRCODE 42501)
--   - master_data, webhooks, sso_providers, external_notifications, webhook_logs
--     → role_code = 'admin_pusat' (semua konsumen useAdminAuth(["admin_pusat"]):
--       MasterDataPage:21, Integrations:21/82).
--   - timesheet → role_code IN ('admin_pusat','admin_finance','admin_operasional')
--     KEBIJAKAN USER 2026-10-16: mengikuti kontrak TimesheetPage
--     (useAdminAuth(["admin_pusat","admin_finance","admin_operasional"])).
--     AdminAttendance + TimesheetManagement tanpa guard in-file = temuan
--     TERPISAH (P2-F14-BB), tidak diputuskan di sesi ini.
--
-- PRE-IMAGE md5(prosrc) / length(prosrc) — dasar verifikasi rollback:
--   admin_get_master_data            ac61d5941d7c5b6249d31464676f6b66 / 472
--   admin_get_timesheet              0386cea9c28298104bffce5f931ec593 / 533
--   admin_get_webhooks               ce2eb0560eeea37eba7db536cdc680d3 / 309
--   admin_get_sso_providers          2fe571522c8fa6e2f17c2f33396c6611 / 267
--   admin_get_external_notifications 5b0cc42ceea7088fdf6a2d281e568605 / 308
--   admin_get_webhook_logs           115559464476bbb5c74137c0a5717f6f / 356
--   Definisi pra-275 lengkap (byte-exact, dari pg_get_functiondef LIVE) ada di
--   supabase/scripts/rollback/275_rollback.sql.
--
-- YANG SENGAJA TIDAK BERUBAH
--   - Signature () / RETURNS jsonb / LANGUAGE plpgsql / VOLATILE / SECURITY
--     DEFINER / SET search_path / oid (CREATE OR REPLACE mempertahankan).
--   - ACL pre-275: postgres+authenticated+service_role, tanpa anon (dikunci
--     ulang defensif, pola 269 P10).
--   - Output shape (key jsonb) KECUALI 'webhook_id' → 'target_url' (keputusan
--     user; konsumen tak terpengaruh, lihat di atas).
--   - LIMIT 100/50 — no-op pada query agregat = P2-F14-AZ (terpisah); bukan
--     bagian dari bug SQL ini, jadi dipertahankan.
--
-- PATCH PASCA-APPLY PERTAMA (keputusan user 2026-10-16, sebelum commit/push —
-- jalur "edit 275 + refresh checksum", disetujui user; 275 belum pernah di-commit
-- jadi tanpa drift riwayat):\--   GREEN proof pertama menemukan error TERSEMBUNYI ke-3 di master_data:
--   42703 ur.created_at does not exist (user_roles = nrp, role_level,
--   scope_divisi, plan, role — tanpa kolom waktu). Keputusan user:
--   hapus key 'created_at' dari output roles; ORDER BY ur.created_at DESC →
--   ur.role_level DESC, ur.nrp ASC (deterministik; konsumen MasterDataPage
--   tidak membaca created_at — interface MasterDataRow tanpa field itu).
--   Pelajaran: audit kolom harus LOOP sampai nol error — error pertama
--   menyembunyikan error berikutnya (terbukti: master_data 3 error,
--   webhook_logs 4).
--
-- P4: file ini TIDAK BOLEH punya baris BEGIN/COMMIT — wrapper apply-migration.mjs
-- yang memegang transaksi. Rollback: supabase/scripts/rollback/275_rollback.sql
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. admin_get_master_data — fix ur.tier → ur.role_level; hr_org.divisi →
--    master_divisions.division_name; gate admin_pusat.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_get_master_data()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code = 'admin_pusat') AND NOT authz_is_owner() THEN
    RAISE EXCEPTION 'Akses ditolak. Hanya admin_pusat.' USING ERRCODE = '42501';
  END IF;
  RETURN (
    SELECT jsonb_build_object('ok', true,
      'roles', (SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'nrp', ur.nrp, 'role', ur.role, 'tier', ur.role_level
      ) ORDER BY ur.role_level DESC, ur.nrp ASC), '[]'::jsonb) FROM user_roles ur LIMIT 100),
      'divisions', (SELECT COALESCE(jsonb_agg(DISTINCT jsonb_build_object(
        'divisi', md.division_name
      )), '[]'::jsonb) FROM master_divisions md WHERE md.division_name IS NOT NULL)
    )
  );
END;
$function$;

-- ---------------------------------------------------------------------------
-- 2. admin_get_timesheet — fix jam_masuk/jam_keluar/status_hadir (alias output
--    lama dipertahankan); gate 3 role = KEBIJAKAN USER 2026-10-16 (kontrak
--    TimesheetPage useAdminAuth admin_pusat+admin_finance+admin_operasional).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_get_timesheet()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code IN ('admin_pusat', 'admin_finance', 'admin_operasional')) AND NOT authz_is_owner() THEN
    RAISE EXCEPTION 'Akses ditolak. Hanya admin_pusat, admin_finance, admin_operasional.' USING ERRCODE = '42501';
  END IF;
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'nrp', sub.nrp, 'date', sub.date, 'check_in', sub.check_in,
        'check_out', sub.check_out, 'status', sub.status, 'hours', sub.hours
      )
    ), '[]'::jsonb))
    FROM (
      SELECT a.nrp, a.date, a.jam_masuk AS check_in, a.jam_keluar AS check_out, a.status_hadir AS status,
        ROUND(EXTRACT(EPOCH FROM (a.jam_keluar - a.jam_masuk)) / 3600, 1) as hours
      FROM hr_attendance a
      ORDER BY a.date DESC
      LIMIT 100
    ) sub
  );
END;
$function$;

-- ---------------------------------------------------------------------------
-- 3. admin_get_webhooks — fix 42803 (ORDER BY pindah ke subquery, pola
--    admin_get_timesheet); gate admin_pusat.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_get_webhooks()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code = 'admin_pusat') AND NOT authz_is_owner() THEN
    RAISE EXCEPTION 'Akses ditolak. Hanya admin_pusat.' USING ERRCODE = '42501';
  END IF;
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('id', w.id, 'name', w.name, 'url', w.url, 'events', w.events, 'active', w.active, 'last_triggered_at', w.last_triggered_at)
    ), '[]'::jsonb))
    FROM (SELECT id, name, url, events, active, last_triggered_at FROM webhook_configs ORDER BY id) w
  );
END;
$function$;

-- ---------------------------------------------------------------------------
-- 4. admin_get_sso_providers — fix 42803 (pola subquery); gate admin_pusat.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_get_sso_providers()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code = 'admin_pusat') AND NOT authz_is_owner() THEN
    RAISE EXCEPTION 'Akses ditolak. Hanya admin_pusat.' USING ERRCODE = '42501';
  END IF;
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('id', s.id, 'name', s.name, 'provider_type', s.provider_type, 'enabled', s.enabled)
    ), '[]'::jsonb))
    FROM (SELECT id, name, provider_type, enabled FROM sso_providers ORDER BY id) s
  );
END;
$function$;

-- ---------------------------------------------------------------------------
-- 5. admin_get_external_notifications — fix 42803 (pola subquery); gate admin_pusat.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_get_external_notifications()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code = 'admin_pusat') AND NOT authz_is_owner() THEN
    RAISE EXCEPTION 'Akses ditolak. Hanya admin_pusat.' USING ERRCODE = '42501';
  END IF;
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('id', e.id, 'channel', e.channel, 'event_types', e.event_types, 'active', e.active, 'last_sent_at', e.last_sent_at)
    ), '[]'::jsonb))
    FROM (SELECT id, channel, event_types, active, last_sent_at FROM external_notifications ORDER BY id) e
  );
END;
$function$;

-- ---------------------------------------------------------------------------
-- 6. admin_get_webhook_logs — fix 4 kolom (webhook_id→target_url,
--    event→event_type, response_status→response_code,
--    success→COALESCE(response_code 2xx, FALSE)); gate admin_pusat.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_get_webhook_logs()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code = 'admin_pusat') AND NOT authz_is_owner() THEN
    RAISE EXCEPTION 'Akses ditolak. Hanya admin_pusat.' USING ERRCODE = '42501';
  END IF;
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('id', l.id, 'target_url', l.target_url, 'event', l.event_type, 'success', COALESCE(l.response_code BETWEEN 200 AND 299, FALSE), 'response_status', l.response_code, 'created_at', l.created_at)
      ORDER BY l.created_at DESC
    ), '[]'::jsonb))
    FROM webhook_logs l LIMIT 50
  );
END;
$function$;

-- ACL defensif (idempoten, pola 269 P10): kunci kontrak pre-275
-- (authenticated + service_role, TANPA anon).
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
