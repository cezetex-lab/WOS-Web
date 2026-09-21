-- ═══════════════════════════════════════════════════════════════════════════
-- 242_sql13_deactivate_dashboard_landing.sql — SQL-13 (keputusan user: Opsi B)
--
-- Masalah: 2 baris aktif untuk route_path '/dashboard':
--   mod_021 / ceo_dashboard      / CORE / menu_order 200 / route_component Dashboard
--   dashboard_landing            / INTELLIGENCE / menu_order 201 / route_component Dashboard
-- Kolom lain identik (module_name, icon, tier 0, industry=false).
--
-- Bukti analisa read-only 2026-09-21 (log agentsLogs_2026-09.md entri SQL-13):
--   * dashboard_landing: 0 referensi di src/ (git grep 0 match); TIDAK ada di
--     pathMap getModulePath() menu-builder → sudah tersaring keluar dari menu
--     oleh dedup per route_path (buildMenu, kalah menu_order 201 vs 200).
--   * ceo_dashboard: dipakai menu-builder.ts:124 (pathMap → '/dashboard');
--     tetap aktif melayani route + menu Dashboard.
--
-- Eksekusi: UPDATE tunggal ter-guard idempoten — aman dijalankan berulang
-- (re-run mengubah 0 baris). Tanpa DROP, tanpa perubahan kontrak.
-- Dampak lintas-page (G1–G7): DynamicRoutes menemukan ceo_dashboard duluan
-- (urutan sort/konflik tidak berubah); komponen sama ('Dashboard'); menu
-- tidak berubah (dashboard_landing memang sudah tidak muncul).
-- ═══════════════════════════════════════════════════════════════════════════

UPDATE public.module_definitions
SET is_active = false
WHERE module_code = 'dashboard_landing'
  AND route_path  = '/dashboard';

-- Verifikasi gagal-cepat: state akhir wajib tepat seperti keputusan user.
DO $$
DECLARE
  v_inactive int; v_active_landing int; v_active_ceo int;
BEGIN
  SELECT count(*) INTO v_inactive FROM module_definitions
   WHERE module_code = 'dashboard_landing' AND route_path = '/dashboard' AND is_active = false;
  SELECT count(*) INTO v_active_landing FROM module_definitions
   WHERE module_code = 'dashboard_landing' AND route_path = '/dashboard' AND is_active = true;
  SELECT count(*) INTO v_active_ceo FROM module_definitions
   WHERE module_code = 'ceo_dashboard' AND route_path = '/dashboard' AND is_active = true;
  IF v_inactive <> 1 OR v_active_landing <> 0 OR v_active_ceo <> 1 THEN
    RAISE EXCEPTION 'SQL-13: state akhir tidak sesuai — inactive=%, landing_aktif=%, ceo_aktif=%',
      v_inactive, v_active_landing, v_active_ceo;
  END IF;
  RAISE NOTICE 'SQL-13 OK: ceo_dashboard aktif, dashboard_landing nonaktif.';
END $$;
