-- ============================================================================
-- 278 — Gate in-body 8 RPC admin (BATCH 1 — split Opsi B, STOP #2 resolved):
--   P2-F14-AY sebagian + P2-F14-BN Fase 2. 17 fungsi dipecah jadi 278 (8) +
--   279 (9) supaya tiap file < 400 baris (batas brief).
--
-- ISI 278 (8 fungsi): admin_get_leave, admin_get_pending_requests,
--   admin_get_overtime, admin_get_kpi_trend, admin_get_top_performers,
--   admin_get_low_performers, admin_get_assets, admin_get_budget.
--
-- KARANTINA (STOP #1 brief — diterima user, TIDAK digate di 278/279,
--   jadi sub-item P2-F14-BU): admin_get_facility_requests + get_shift_assignments
--   — keduanya terbukti dikonsumsi worker (FacilityRequest.tsx di /worker/facility
--   + /worker/field tanpa guard; ShiftSchedule.tsx di /worker/shift yang PUNYA
--   baris role_page_access). Butuh desain scope by NRP, bukan gate admin.
--
-- ROLE TARGET per RPC = kontrak halaman konsumen (G3: useAdminAuth komponen,
--   dicek ulang terhadap AdminRouteGuard ROLE_ACCESS; Owner selalu bypass):
--   leave, pending_requests → admin_pusat, admin_hrd, admin_operasional
--   kpi_trend/top/low       → admin_pusat, admin_hrd, admin_finance, admin_operasional
--   assets                  → admin_pusat, admin_operasional
--   overtime                → admin_pusat, admin_finance, admin_operasional
--   budget                  → admin_pusat, admin_finance
--
-- TEMUAN TEKNIS: 4 fungsi di batch ini ber-LANGUAGE sql (leave, kpi_trend,
--   top/low_performers) KONVERSI ke plpgsql supaya gate RAISE EXCEPTION mungkin;
--   fungsi ke-5 (payroll_summary) ada di batch 279. Konsekuensi: prolang
--   berubah sql→plpgsql; signature, SECURITY DEFINER, VOLATILE, SET search_path,
--   ACL, dan return SHAPE identik. P2-F14-M (guard atribut) belum terpasang —
--   dicatat di entri log.
--
-- RED/GREEN: .agents/logs/m278-red.log (pra-apply) → m278-green.log (pasca).
--   pre-image byte-exact: .agents/logs/m278-preimage.log (md5 per fungsi di META).
--   Rollback: supabase/scripts/rollback/278_rollback.sql.
-- P4: file ini TIDAK punya baris BEGIN/COMMIT — wrapper apply-migration.mjs
--   yang memegang transaksi.
-- ============================================================================

-- ─── 1. admin_get_leave — SQL→plpgsql, gate (pusat, hrd, operasional) ───────
CREATE OR REPLACE FUNCTION public.admin_get_leave()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code IN ('admin_pusat','admin_hrd','admin_operasional')) AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501'; END IF;
  RETURN (
    SELECT COALESCE(jsonb_agg(sub.* ORDER BY sub.nama), '[]'::jsonb)
    FROM (
      SELECT
        l.nrp, e.nama, l.tahun,
        l.annual_quota AS kuota,
        l.annual_used AS terpakai,
        (l.annual_quota - l.annual_used) AS sisa
      FROM hr_leave l
      JOIN employees_master e ON e.nrp = l.nrp
      WHERE l.tahun = EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER
    ) sub
  );
END;
$function$;

-- ─── 2. admin_get_low_performers — SQL→plpgsql, gate (pusat, hrd, finance, operasional) ─
CREATE OR REPLACE FUNCTION public.admin_get_low_performers()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code IN ('admin_pusat','admin_hrd','admin_finance','admin_operasional')) AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501'; END IF;
  RETURN (
    SELECT COALESCE(jsonb_agg(sub.*), '[]'::jsonb)
    FROM (
      SELECT
        p.nrp,
        e.nama,
        e.divisi,
        e.business_unit,
        e.posisi,
        p.kpi_score,
        p.periode
      FROM hr_performance p
      JOIN employees_master e ON e.nrp = p.nrp
      WHERE e.status_kerja = 'Aktif'
      ORDER BY p.kpi_score ASC NULLS LAST
      LIMIT 10
    ) sub
  );
END;
$function$;

-- ─── 3. admin_get_top_performers — SQL→plpgsql, gate (pusat, hrd, finance, operasional) ─
CREATE OR REPLACE FUNCTION public.admin_get_top_performers()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code IN ('admin_pusat','admin_hrd','admin_finance','admin_operasional')) AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501'; END IF;
  RETURN (
    SELECT COALESCE(jsonb_agg(sub.*), '[]'::jsonb)
    FROM (
      SELECT
        p.nrp,
        e.nama,
        e.divisi,
        e.business_unit,
        e.posisi,
        p.kpi_score,
        p.periode
      FROM hr_performance p
      JOIN employees_master e ON e.nrp = p.nrp
      WHERE e.status_kerja = 'Aktif'
      ORDER BY p.kpi_score DESC
      LIMIT 10
    ) sub
  );
END;
$function$;

-- ─── 4. admin_get_kpi_trend — SQL→plpgsql, gate (pusat, hrd, finance, operasional) ─
CREATE OR REPLACE FUNCTION public.admin_get_kpi_trend()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code IN ('admin_pusat','admin_hrd','admin_finance','admin_operasional')) AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501'; END IF;
  RETURN (
    SELECT COALESCE(jsonb_agg(sub.* ORDER BY sub.periode ASC), '[]'::jsonb)
    FROM (
      SELECT
        p.periode,
        ROUND(AVG(p.kpi_score), 1) AS avg_kpi,
        COUNT(*) AS total_employees,
        COUNT(CASE WHEN p.kpi_score >= 80 THEN 1 END) AS high_count,
        COUNT(CASE WHEN p.kpi_score < 60 THEN 1 END) AS low_count
      FROM hr_performance p
      WHERE p.periode IS NOT NULL
      GROUP BY p.periode
      ORDER BY p.periode DESC
      LIMIT 12
    ) sub
  );
END;
$function$;

-- ─── 5. admin_get_assets — gate (pusat, operasional) ────────────────────────
CREATE OR REPLACE FUNCTION public.admin_get_assets()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code IN ('admin_pusat','admin_operasional')) AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501'; END IF;
  RETURN (
  SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
    jsonb_build_object('id', a.id, 'asset_name', a.asset_name, 'category', a.category,
      'serial_number', a.serial_number, 'location', a.location, 'status', a.status,
      'assigned_to', a.assigned_to, 'assigned_name', e.nama, 'purchase_date', a.purchase_date)
    ORDER BY a.created_at DESC), '[]'::jsonb))
  FROM assets a
  LEFT JOIN employees_master e ON e.nrp = a.assigned_to
  LIMIT 50);
END;
$function$;

-- ─── 6. admin_get_overtime — gate (pusat, finance, operasional) ─────────────
CREATE OR REPLACE FUNCTION public.admin_get_overtime()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code IN ('admin_pusat','admin_finance','admin_operasional')) AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501'; END IF;
 RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'nrp',nrp,'date',date,'hours',hours,'reason',reason,'status',status)
    ORDER BY date DESC),'[]'::jsonb))
  FROM hr_overtime LIMIT 50); END;
$function$;

-- ─── 7. admin_get_pending_requests — gate (pusat, hrd, operasional) ────────
CREATE OR REPLACE FUNCTION public.admin_get_pending_requests()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code IN ('admin_pusat','admin_hrd','admin_operasional')) AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501'; END IF;
 RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',r.id,'nrp',r.nrp,'nama',e.nama,'type',r.type,'status',r.status,'note',r.note,'created_at',r.created_at)
    ORDER BY r.created_at DESC),'[]'::jsonb))
  FROM hr_requests r LEFT JOIN employees_master e ON e.nrp=r.nrp WHERE r.status='Pending' LIMIT 50); END;
$function$;

-- ─── 8. admin_get_budget — gate (pusat, finance) ───────────────────────────
CREATE OR REPLACE FUNCTION public.admin_get_budget()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code IN ('admin_pusat','admin_finance')) AND NOT authz_is_owner() THEN RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501'; END IF;
  RETURN (
  SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
    jsonb_build_object('id', ba.id, 'divisi', ba.divisi, 'year', ba.year,
      'gaji_budget', ba.gaji_budget, 'training_budget', ba.training_budget,
      'operational_budget', ba.operational_budget, 'actual_gaji', ba.actual_gaji,
      'actual_training', ba.actual_training)
    ORDER BY ba.year DESC, ba.divisi), '[]'::jsonb))
  FROM budget_allocation ba
  LIMIT 30);
END;
$function$;