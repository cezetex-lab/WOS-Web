-- ================================================================
-- 204_admin_mill_routes.sql
-- ================================================================
-- ISOLASI 3-PAGE (keputusan user §8.1): admin TIDAK boleh navigasi ke
-- /worker/*. MillAdminDashboard + tiles Admin.jsx sebelumnya menunjuk
-- /worker/* → RoleGuard menolak (entry mismatch) → redirect ke "/".
-- Fix: daftarkan route /admin/mill/* yang memakai komponen yang sama.
-- Idempotent: ON CONFLICT (id) DO NOTHING.
-- ================================================================

INSERT INTO module_definitions
  (id, module_code, module_name, module_group, description, menu_icon,
   menu_order, is_active, route_path, route_component, route_group,
   is_industry_module, minimum_tier_required)
VALUES
  ('admin_mill_boiler',    'MILL_BOILER_ADM',    'Mill Boiler',    'INDUSTRY', 'Pemantauan Boiler PKS (admin)',        '🔥', 1, TRUE, '/admin/mill/boiler',     'BoilerMonitor',          'admin', FALSE, 0),
  ('admin_mill_press',     'MILL_PRESS_ADM',     'Mill Mesin Press','INDUSTRY','Mesin Press & Pemipahan (admin)',      '⚙️', 2, TRUE, '/admin/mill/machines',   'MesinPress',             'admin', FALSE, 0),
  ('admin_mill_qc',        'MILL_QC_ADM',        'Mill QC Lab',    'INDUSTRY', 'QC Lab (admin)',                       '🔬', 3, TRUE, '/admin/mill/qc',         'QcLab',                  'admin', FALSE, 0),
  ('admin_mill_packing',   'MILL_PACKING_ADM',   'Mill Packing',   'INDUSTRY', 'Packing Log (admin)',                  '📦', 4, TRUE, '/admin/mill/packing',    'PackingLog',             'admin', FALSE, 0),
  ('admin_mill_maint',     'MILL_MAINT_ADM',     'Mill Maintenance','INDUSTRY','Preventive Maintenance (admin)',       '🔧', 5, TRUE, '/admin/mill/maintenance','PreventiveMaintenance',  'admin', FALSE, 0),
  ('admin_mill_breakdown', 'MILL_BREAKDOWN_ADM', 'Mill Breakdown', 'INDUSTRY', 'Breakdown Log (admin)',                '🚨', 6, TRUE, '/admin/mill/breakdown',  'BreakdownLog',           'admin', FALSE, 0),
  ('admin_mill_shift',     'MILL_SHIFT_ADM',     'Mill Shift',     'INDUSTRY', 'Jadwal Shift Pabrik (admin)',          '📅', 7, TRUE, '/admin/mill/shift',      'MillShiftSchedule',      'admin', FALSE, 0)
ON CONFLICT (id) DO NOTHING;

-- Pastikan 14 route admin estate/mining yang dibuat manual juga konsisten
-- (idempotent — menu-kan ulang nilai kuncinya).
UPDATE module_definitions
SET is_active = TRUE,
    route_group = 'admin',
    is_industry_module = FALSE,
    minimum_tier_required = 0
WHERE id IN (
  'EST_HARVEST_ADM','EST_BLOCK_ADM','EST_TRANSPORT_ADM','EST_NURSERY_ADM',
  'EST_IRRIGATION_ADM','EST_FACILITY_ADM','EST_MEDICAL_ADM',
  'MINE_SIMPER_ADM','MINE_HEAVY_ADM','MINE_FATIGUE_ADM','MINE_PROD_ADM',
  'MINE_SAFETY_ADM','MINE_EMERGENCY_ADM','MINE_JSA_ADM'
);
