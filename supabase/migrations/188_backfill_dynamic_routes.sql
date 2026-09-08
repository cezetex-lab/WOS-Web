-- 188: Backfill dynamic-route fields + seed remaining AppDrawer modules
--
-- Follow-up to 187. Two gaps remained:
-- 1. Rows whose module_code already existed (e.g. 'learning' for worker) were
--    skipped by 187's NOT EXISTS guard, so their admin counterpart
--    (/admin/learning) never got a row.
-- 2. Many AppDrawer links (/admin/audit, /admin/org, /worker/safety, ...)
--    still had no module_definitions row at all.
--
-- Strategy per entry: if a row with the same module_code exists, backfill its
-- NULL route fields; otherwise INSERT a new row. Idempotent.

-- ── 1. Backfill / insert ─────────────────────────────────────────────
INSERT INTO module_definitions
  (id, module_code, module_name, module_group, description, minimum_tier_required,
   is_industry_module, menu_icon, menu_order, is_active,
   route_path, route_component, route_group)
SELECT v.id, v.module_code, v.module_name, v.module_group, v.description, 0,
       v.is_industry, v.menu_icon, v.menu_order, TRUE,
       v.route_path, v.route_component, v.route_group
FROM (VALUES
  -- Admin — data & organization
  ('admin_org',          'org_chart',        'Organisasi',        'PLATFORM',   'Struktur organisasi',            'Network',      220, '/admin/org',           'OrgChart',             'admin', FALSE),
  ('admin_divisions',    'divisions',        'Divisi',            'PLATFORM',   'Manajemen divisi',               'FolderOpen',   221, '/admin/divisions',     'DivisionsManagement',  'admin', FALSE),
  -- Admin — talent
  ('admin_learning2',    'learning_admin',   'Learning',          'PLATFORM',   'Manajemen pembelajaran (admin)', 'GraduationCap',222, '/admin/learning',      'LearningManagement',   'admin', FALSE),
  ('admin_certs',        'certifications',   'Sertifikasi',       'PLATFORM',   'Sertifikasi karyawan',           'Award',        223, '/admin/certifications','CertificationsPage',   'admin', FALSE),
  ('admin_badges',       'badges_admin',     'Badge & Gamifikasi','PLATFORM',   'Badge & gamifikasi',             'Medal',        224, '/admin/badges',        'BadgesPage',           'admin', FALSE),
  -- Admin — assets & facility
  ('admin_asset_assign', 'asset_assign',     'Check-in/out Aset', 'PLATFORM',   'Check-in/out aset',              'Package',      225, '/admin/asset-assign',  'AssetManagement',      'admin', FALSE),
  ('admin_estate',       'estate_admin',     'Estate Blocks',     'INDUSTRY',   'Dashboard estate',               'Trees',        226, '/admin/estate',        'EstateAdminDashboard', 'admin', TRUE),
  ('admin_facility',     'facility_admin',   'Facility Request',  'PLATFORM',   'Permintaan fasilitas',           'Building',     227, '/admin/facility',      'FacilityRequest',      'admin', FALSE),
  -- Admin — engagement
  ('admin_forum',        'forum_admin',      'Forum',             'PLATFORM',   'Forum diskusi (admin)',          'MessagesSquare',228,'/admin/forum',         'ForumDiskusi',         'admin', FALSE),
  -- Admin — system & security
  ('admin_audit',        'audit_log',        'Audit Log',         'GOVERNANCE', 'Log audit sistem',               'ScrollText',   229, '/admin/audit',         'AuditLog',             'admin', FALSE),
  ('admin_export',       'export_data',      'Export Data',       'PLATFORM',   'Ekspor data',                    'FileDown',     230, '/admin/export',        'ExportPage',           'admin', FALSE),
  ('admin_settings',     'settings',         'Pengaturan',        'PLATFORM',   'Pengaturan sistem',              'Settings',     231, '/admin/settings',      'Settings',             'admin', FALSE),
  -- Admin — planning
  ('admin_headcount',    'headcount',        'Headcount Plan',    'PLATFORM',   'Perencanaan headcount',          'Users',        232, '/admin/headcount',     'HeadcountPage',        'admin', FALSE),
  ('admin_referral',     'referral_admin',   'Referral Program',  'PLATFORM',   'Program referral',               'Handshake',    233, '/admin/referral',      'ReferralPage',         'admin', FALSE),
  -- Worker — mining
  ('worker_simper',      'simper_worker',    'Simper',            'INDUSTRY',   'Simper mining',                  'IdCard',       80,  '/worker/simper',       'SimperPage',           'worker', TRUE),
  ('worker_heavy_equip', 'heavy_equip',      'Heavy Equipment',   'INDUSTRY',   'Alat berat',                     'Truck',        81,  '/worker/heavy-equip',  'HeavyEquipment',       'worker', TRUE),
  ('worker_fatigue',     'fatigue',          'Fatigue Check',     'INDUSTRY',   'Monitoring fatigue',             'BatteryLow',   82,  '/worker/fatigue',      'FatigueMonitor',       'worker', TRUE),
  ('worker_production',  'production_daily', 'Produksi Harian',   'INDUSTRY',   'Produksi harian',                'Factory',      83,  '/worker/production',   'ProductionDaily',      'worker', TRUE),
  ('worker_safety',      'safety_k3',        'Safety K3',         'INDUSTRY',   'Keselamatan kerja',              'HardHat',      84,  '/worker/safety',       'SafetyK3',             'worker', TRUE),
  ('worker_jsa',         'jsa',              'JSA',               'INDUSTRY',   'Job Safety Analysis',            'ShieldCheck',  85,  '/worker/jsa',          'JobSafetyAnalysis',    'worker', TRUE),
  -- Worker — estate
  ('worker_harvest',     'harvest',          'Panen',             'INDUSTRY',   'Catatan panen',                  'Wheat',        86,  '/worker/harvest',      'HarvestRecord',        'worker', TRUE),
  ('worker_blocks',      'blocks',           'Blok',              'INDUSTRY',   'Manajemen blok',                 'Map',          87,  '/worker/blocks',       'BlockManagement',      'worker', TRUE),
  ('worker_irrigation',  'irrigation',       'Irigasi',           'INDUSTRY',   'Irigasi kebun',                  'Droplets',     88,  '/worker/irrigation',   'IrrigationPage',       'worker', TRUE),
  ('worker_nursery',     'nursery',          'Nursery',           'INDUSTRY',   'Pembibitan',                     'Sprout',       89,  '/worker/nursery',      'NurseryPage',          'worker', TRUE),
  ('worker_transport',   'transport_tbs',    'Transport TBS',     'INDUSTRY',   'Transport TBS',                  'Truck',        90,  '/worker/transport',    'TransportTBS',         'worker', TRUE),
  -- Worker — mill
  ('worker_boiler',      'boiler',           'Boiler',            'INDUSTRY',   'Monitoring boiler',              'Flame',        91,  '/worker/boiler',       'BoilerMonitor',        'worker', TRUE),
  ('worker_machines',    'machines',         'Mesin Press',       'INDUSTRY',   'Mesin press',                    'Cog',          92,  '/worker/machines',     'MesinPress',           'worker', TRUE),
  ('worker_qc',          'qc_lab',           'QC Lab',            'INDUSTRY',   'Quality control lab',            'FlaskConical', 93,  '/worker/qc',           'QcLab',                'worker', TRUE),
  ('worker_packing',     'packing',          'Packing',           'INDUSTRY',   'Log packing',                    'Package',      94,  '/worker/packing',      'PackingLog',           'worker', TRUE),
  ('worker_maintenance', 'maintenance',      'Maintenance',       'INDUSTRY',   'Perawatan preventif',            'Wrench',       95,  '/worker/maintenance',  'PreventiveMaintenance','worker', TRUE),
  ('worker_breakdown',   'breakdown',        'Breakdown',         'INDUSTRY',   'Log breakdown',                  'AlertTriangle',96,  '/worker/breakdown',    'BreakdownLog',         'worker', TRUE),
  ('worker_shift',       'mill_shift',       'Shift Mill',        'INDUSTRY',   'Jadwal shift mill',              'CalendarClock',97,  '/worker/shift',        'MillShiftSchedule',    'worker', TRUE)
) AS v(id, module_code, module_name, module_group, description, menu_icon,
       menu_order, route_path, route_component, route_group, is_industry)
WHERE NOT EXISTS (
  SELECT 1 FROM module_definitions md
  WHERE md.id = v.id OR md.route_path = v.route_path
);

-- ── 2. Backfill route fields on pre-existing rows that lack them ─────
-- (rows matched by module_code from 187's blocked inserts)
UPDATE module_definitions md
SET route_path = v.route_path,
    route_component = v.route_component,
    route_group = v.route_group
FROM (VALUES
  ('learning',          '/admin/learning', 'LearningManagement', 'admin')
) AS v(module_code, route_path, route_component, route_group)
WHERE md.module_code = v.module_code
  AND md.route_path IS NULL;

-- ── 3. Reload PostgREST schema cache so the RPC sees new columns/rows ─
NOTIFY pgrst, 'reload schema';
