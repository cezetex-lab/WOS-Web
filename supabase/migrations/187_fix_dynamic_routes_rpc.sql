-- 187: Fix dynamic routing — get_enabled_modules must return route fields
--
-- ROOT CAUSE (found in login/navigation audit, 07 Sep 2026):
-- Migration 185 added route_path/route_component/route_group columns to
-- module_definitions and seeded 61 modules, but never updated
-- get_enabled_modules() (originally defined in 072). The RPC still returns
-- only module_code/module_name/module_group/menu_icon/menu_order/
-- is_industry_module — so DynamicRoutes.jsx (which filters on
-- m.route_path && m.route_component) always received an EMPTY list and
-- every dynamic route (e.g. /admin/payroll, /worker/leave) rendered nothing
-- or bounced back to /.
--
-- Also seeds module rows for pages that exist in route-config.js and are
-- linked from AppDrawer.jsx but were never registered in module_definitions
-- (dead navigation links, incl. /admin/payroll used by payroll flows).

-- ── 1. Seed missing modules (idempotent) ──────────────────────────────
INSERT INTO module_definitions
  (id, module_code, module_name, module_group, description, minimum_tier_required,
   is_industry_module, menu_icon, menu_order, is_active,
   route_path, route_component, route_group)
SELECT v.id, v.module_code, v.module_name, v.module_group, v.description, 0,
       FALSE, v.menu_icon, v.menu_order, TRUE,
       v.route_path, v.route_component, v.route_group
FROM (VALUES
  ('admin_payroll',    'payroll_admin',   'Payroll',            'PLATFORM',
   'Proses payroll & laporan gaji',                    'DollarSign',    210, '/admin/payroll',     'Payroll',            'admin'),
  ('admin_budget',     'budget',          'Budget',             'GOVERNANCE',
   'Perencanaan & monitoring anggaran',                'Wallet',        211, '/admin/budget',      'BudgetPage',         'admin'),
  ('admin_employees',  'employees',       'Data Karyawan',      'PLATFORM',
   'Manajemen master data karyawan',                   'Users',         212, '/admin/employees',   'Employees',          'admin'),
  ('admin_learning',   'learning',        'Learning',           'PLATFORM',
   'Manajemen pembelajaran & pelatihan',               'GraduationCap', 213, '/admin/learning',    'LearningManagement', 'admin'),
  ('admin_leave',      'leave_admin',     'Cuti',               'PLATFORM',
   'Manajemen pengajuan cuti',                         'CalendarDays',  214, '/admin/leave',       'LeaveManagement',    'admin'),
  ('admin_overtime',   'overtime_admin',  'Lembur',             'PLATFORM',
   'Manajemen pengajuan lembur',                       'Clock',         215, '/admin/overtime',    'OvertimeManagement', 'admin'),
  ('admin_career',     'career_admin',    'Career Development', 'PLATFORM',
   'Karir & pengembangan karyawan',                    'TrendingUp',    216, '/admin/career',      'CareerDevelopment',  'admin'),
  ('worker_kpi',       'kpi_worker',      'KPI Saya',           'CORE',
   'KPI & performa individu',                          'Target',        70,  '/worker/kpi',        'WorkerKpi',          'worker'),
  ('worker_activities','activities',      'Aktivitas',          'CORE',
   'Log aktivitas workforce',                          'Activity',      71,  '/worker/activities', 'WorkerActivities',   'worker')
) AS v(id, module_code, module_name, module_group, description, menu_icon,
       menu_order, route_path, route_component, route_group)
WHERE NOT EXISTS (
  SELECT 1 FROM module_definitions md
  WHERE md.id = v.id OR md.module_code = v.module_code
);

-- ── 2. Fix get_enabled_modules: return route fields ───────────────────
CREATE OR REPLACE FUNCTION get_enabled_modules()
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_bu_tier INT := 0;
  v_result JSONB;
BEGIN
  IF v_ctx IS NULL THEN RETURN '[]'::JSONB; END IF;
  IF (v_ctx->>'is_owner')::BOOLEAN THEN
    SELECT jsonb_agg(jsonb_build_object(
      'module_code', module_code, 'module_name', module_name,
      'module_group', module_group, 'menu_icon', menu_icon,
      'menu_order', menu_order, 'is_industry_module', is_industry_module,
      'route_path', route_path, 'route_component', route_component,
      'route_group', route_group))
    INTO v_result
    FROM module_definitions WHERE is_active = TRUE;
    RETURN COALESCE(v_result, '[]'::JSONB);
  END IF;
  SELECT tier INTO v_bu_tier FROM business_units
  WHERE id = (v_ctx->>'business_unit_id')::TEXT;
  IF NOT FOUND THEN v_bu_tier := 0; END IF;
  SELECT jsonb_agg(jsonb_build_object(
    'module_code', md.module_code, 'module_name', md.module_name,
    'module_group', md.module_group, 'menu_icon', md.menu_icon,
    'menu_order', md.menu_order, 'is_industry_module', md.is_industry_module,
    'route_path', md.route_path, 'route_component', md.route_component,
    'route_group', md.route_group))
  INTO v_result
  FROM module_definitions md
  LEFT JOIN business_unit_modules bum
    ON bum.module_code = md.module_code
   AND bum.business_unit_id = (v_ctx->>'business_unit_id')::TEXT
  WHERE md.is_active = TRUE
    AND (v_ctx->>'role_level')::INT >= 1
    AND ((md.is_industry_module = TRUE AND bum.is_enabled = TRUE)
      OR (md.is_industry_module = FALSE AND v_bu_tier >= md.minimum_tier_required));
  RETURN COALESCE(v_result, '[]'::JSONB);
END; $$
LANGUAGE plpgsql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_enabled_modules() TO anon, authenticated;
