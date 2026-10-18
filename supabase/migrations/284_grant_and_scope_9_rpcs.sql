-- ============================================================================
-- 284 — Grant bertarget + scope-by-NRP untuk 9 RPC P1-POST-HARDENING-AUDIT.
--
-- Sumber: audit 2026-10-18 (`.agents/logs/audit-46-noexec-2026-10-18.json`,
--   `p1-posthardening-runtime.log`). 8 nama fungsi (9 signature) dipanggil
--   `src/` tapi `authenticated` TIDAK punya EXECUTE → 42501 di produksi:
--     check_registration_status  (Home.tsx:926 — PRA-LOGIN, butuh `anon`)
--     create_facility_request    (FacilityRequest.tsx:50)
--     get_active_surveys         (SurveyPage.tsx:67)
--     get_overtime_data ×2       (DetailPageFactory.tsx:46)
--     get_worker_tasks           (DetailPageFactory.tsx:86)
--     get_worker_engagement      (DetailPageFactory.tsx:59)
--     get_exit_clearance         (DetailPageFactory.tsx:62,64)
--     admin_get_estate_blocks    (DetailPageFactory.tsx:57)
--   Guard `npm run verify:acl-dependencies` MERAH pada 10 pelanggaran sebelum
--   migrasi ini (RED proof) dan HIJAU sesudahnya.
--
-- KEPUTUSAN USER 2026-10-18 (Q1): grant TIDAK boleh polos — setiap fungsi yang
--   menerima `p_nrp` WAJIB langsung di-scope agar tidak mengulang kerja 276.
--   Pola yang dipakai = pola 276/281:
--     * admin (`is_admin_or_owner()`): boleh lihat semua (p_nrp NULL) atau
--       orang tertentu (p_nrp diisi)
--     * worker: `p_nrp` DIPAKSA dari JWT (`authz_current_nrp()`), parameter
--       diabaikan → tidak bisa mengintip NRP lain
--     * tanpa JWT: `authz_current_nrp()` NULL dan bukan admin → RAISE 42501
--       (fail-closed, pelajaran 281)
--
-- Gate in-body untuk `admin_get_estate_blocks` = `is_admin_or_owner()` (paritas
--   dengan halaman DetailPageFactory admin; bukan `employee.view_all` karena
--   272 mencabutnya dari HRD).
-- `get_active_surveys` TIDAK diberi gate: isinya survei aktif perusahaan (tanpa
--   PII) dan memang untuk semua karyawan; grant `authenticated` = cukup.
-- `check_registration_status` di-grant ke `anon` + `authenticated` karena
--   dipanggil di halaman login sebelum sesi terbentuk (bukti Home.tsx:926).
--
-- TIDAK diubah di sini (sengaja): `LIMIT ... ` di luar agregat pada
--   `get_worker_tasks`/`get_exit_clearance`/`get_overtime_data` masih no-op —
--   itu scope **P3-F14-BV**, bukan item ini; mengubahnya sekarang menambah
--   blast radius tanpa keputusan user.
--
-- Pre-image byte-exact: .agents/logs/m284-preimage.json (oid + md5 + definisi).
-- Rollback: supabase/scripts/rollback/284_rollback.sql (restore body + cabut
--   grant authenticated/anon agar ACL kembali ke postgres+service_role).
-- P4: tanpa BEGIN/COMMIT — wrapper apply-migration.mjs memegang transaksi.
-- ============================================================================

-- ─── 1. get_worker_tasks — scope worker, admin boleh semua ────────────────
CREATE OR REPLACE FUNCTION public.get_worker_tasks(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_is_admin boolean := is_admin_or_owner();
  v_eff text := CASE WHEN is_admin_or_owner() THEN NULLIF(TRIM(p_nrp), '') ELSE authz_current_nrp() END;
BEGIN
  IF NOT v_is_admin AND v_eff IS NULL THEN
    RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501';
  END IF;
  RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'title',title,'status',status,'due_date',due_date)
    ORDER BY due_date),'[]'::jsonb))
  FROM hr_tasks
  WHERE (v_is_admin AND v_eff IS NULL) OR assignee_nrp = v_eff
  LIMIT 20); END;
$function$;

-- ─── 2. get_worker_engagement — scope worker, bentuk respons dipertahankan ──
CREATE OR REPLACE FUNCTION public.get_worker_engagement(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_is_admin BOOLEAN := is_admin_or_owner();
  v_eff TEXT := CASE WHEN is_admin_or_owner() THEN NULLIF(TRIM(p_nrp), '') ELSE authz_current_nrp() END;
  v RECORD;
BEGIN
  IF NOT v_is_admin AND v_eff IS NULL THEN
    RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501';
  END IF;
  IF v_eff IS NOT NULL AND (LENGTH(v_eff) < 3 OR LENGTH(v_eff) > 20) THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Format NRP tidak valid');
  END IF;
  SELECT * INTO v FROM hr_engagement WHERE nrp = v_eff ORDER BY created_at DESC LIMIT 1;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', true, 'score', 0, 'category', 'N/A'); END IF;
  RETURN jsonb_build_object('ok', true, 'score', COALESCE(v.score, 0),
    'category', CASE WHEN v.score>=80 THEN 'Highly Engaged' WHEN v.score>=60 THEN 'Engaged' ELSE 'Needs Attention' END,
    'period', v.period);
EXCEPTION WHEN OTHERS THEN
  -- Jangan menelan penolakan authz: RAISE 42501 di atas WAJIB sampai ke caller
  -- (fail-closed terlihat), hanya error lain yang dijadikan pesan generik.
  IF SQLSTATE = '42501' THEN RAISE; END IF;
  RETURN jsonb_build_object('ok', false, 'msg', 'Terjadi kesalahan sistem');
END;
$function$;

-- ─── 3. get_exit_clearance — scope worker + fix kolom mati ────────────────
-- TEMUAN saat menyiapkan probe: body lama merujuk `ec.step`, `ec.status`,
-- `ec.completed_at`, `ec.notes` yang TIDAK ADA di `hr_exit_clearance` (kolom
-- live: id, nrp, resign_date, last_work_date, clearance_status, created_at)
-- → 42703 untuk semua caller. Memberi grant tanpa memperbaiki ini = GREEN
-- palsu (guard hijau, halaman tetap error). Key `status` dipertahankan (dipakai
-- kolom generik DetailPageFactory); `step`/`completed_at`/`notes` diganti kolom
-- nyata. Tidak ada konsumen `src/` yang membaca ketiga key mati itu.
CREATE OR REPLACE FUNCTION public.get_exit_clearance(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_is_admin boolean := is_admin_or_owner();
  v_eff text := CASE WHEN is_admin_or_owner() THEN NULLIF(TRIM(p_nrp), '') ELSE authz_current_nrp() END;
BEGIN
  IF NOT v_is_admin AND v_eff IS NULL THEN
    RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501';
  END IF;
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', ec.id, 'nrp', ec.nrp,
        'resign_date', ec.resign_date, 'last_work_date', ec.last_work_date,
        'status', ec.clearance_status, 'created_at', ec.created_at
      ) ORDER BY ec.id
    ), '[]'::jsonb))
    FROM hr_exit_clearance ec
    WHERE (v_is_admin AND v_eff IS NULL) OR ec.nrp = v_eff
    LIMIT 20
  );
END;
$function$;

-- ─── 4. get_overtime_data(p_nrp) — scope + perbaikan presedensi WHERE ──────
-- Bug laten: `WHERE type ILIKE ... OR type ILIKE ... AND (p_nrp IS NULL OR ...)`
-- = `A OR (B AND C)` → filter NRP hilang saat p_nrp NULL. Diberi tanda kurung.
CREATE OR REPLACE FUNCTION public.get_overtime_data(p_nrp text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_is_admin boolean := is_admin_or_owner();
  v_eff text := CASE WHEN is_admin_or_owner() THEN NULLIF(TRIM(p_nrp), '') ELSE authz_current_nrp() END;
BEGIN
  IF NOT v_is_admin AND v_eff IS NULL THEN
    RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501';
  END IF;
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', r.id, 'nrp', r.nrp, 'type', r.type, 'status', r.status,
        'note', r.note, 'created_at', r.created_at
      ) ORDER BY r.created_at DESC
    ), '[]'::jsonb))
    FROM hr_requests r
    WHERE (r.type ILIKE '%overtime%' OR r.type ILIKE '%lembur%')
      AND ((v_is_admin AND v_eff IS NULL) OR r.nrp = v_eff)
    LIMIT 50
  );
END;
$function$;

-- ─── 5. get_overtime_data(p_nrp, p_from, p_to) — scope + rentang tanggal ───
CREATE OR REPLACE FUNCTION public.get_overtime_data(p_nrp text, p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_is_admin boolean := is_admin_or_owner();
  v_eff text := CASE WHEN is_admin_or_owner() THEN NULLIF(TRIM(p_nrp), '') ELSE authz_current_nrp() END;
BEGIN
  IF NOT v_is_admin AND v_eff IS NULL THEN
    RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501';
  END IF;
  RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',nrp,'date',date,'hours',hours,'reason',reason,'status',status) ORDER BY date DESC),'[]'::jsonb))
  FROM hr_overtime
  WHERE ((v_is_admin AND v_eff IS NULL) OR nrp = v_eff)
    AND (p_from IS NULL OR date >= p_from)
    AND (p_to IS NULL OR date <= p_to)
  LIMIT 30); END;
$function$;

-- ─── 6. create_facility_request — paksa NRP pemohon dari JWT ──────────────
CREATE OR REPLACE FUNCTION public.create_facility_request(p_nrp text, p_type text, p_desc text, p_priority text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_eff text := COALESCE(
    CASE WHEN is_admin_or_owner() THEN NULLIF(TRIM(p_nrp), '') ELSE authz_current_nrp() END,
    authz_current_nrp());
BEGIN
  IF v_eff IS NULL THEN
    RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501';
  END IF;
  INSERT INTO facility_requests(id,nrp,facility_type,description,priority)
  VALUES(encode(gen_random_bytes(8),'hex'),v_eff,p_type,p_desc,COALESCE(p_priority,'NORMAL'));
  RETURN jsonb_build_object('ok',true,'msg','Pengajuan fasilitas dikirim.'); END;
$function$;

-- ─── 7. admin_get_estate_blocks — gate in-body (data admin) ───────────────
CREATE OR REPLACE FUNCTION public.admin_get_estate_blocks()
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
    jsonb_build_object('id', eb.id, 'block_name', eb.block_name, 'area_hectare', eb.area_hectare,
      'terrain', eb.terrain, 'division', eb.division, 'status', eb.status)
    ORDER BY eb.block_name), '[]'::jsonb))
  FROM (
    SELECT eb.id, eb.block_name, eb.area_hectare, eb.terrain, eb.division, eb.status
    FROM estate_blocks eb
    ORDER BY eb.block_name
    LIMIT 50
  ) eb);
END;
$function$;

-- ─── GRANT ────────────────────────────────────────────────────────────────
GRANT EXECUTE ON FUNCTION public.get_worker_tasks(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_worker_engagement(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_exit_clearance(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_overtime_data(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_overtime_data(text, date, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_facility_request(text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_estate_blocks() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_active_surveys() TO authenticated;
-- pra-login: Home.tsx memanggil sebelum sesi ada
GRANT EXECUTE ON FUNCTION public.check_registration_status(text) TO anon, authenticated;
