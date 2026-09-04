-- Migration 135: Seed default permission sets + role assignments
-- Maps existing roles to the new permission-based system

-- ============================================================
-- PART 1: PERMISSION SETS (module.action format)
-- ============================================================

-- WORKER permissions (base)
INSERT INTO permission_set_items (permission_set, permission_code) VALUES
-- Profile
('worker_basic', 'profile.view'),
('worker_basic', 'profile.edit_own'),
-- Attendance
('worker_basic', 'attendance.view_own'),
('worker_basic', 'attendance.clock_in'),
('worker_basic', 'attendance.clock_out'),
-- Leave
('worker_basic', 'leave.view_own'),
('worker_basic', 'leave.apply'),
-- Overtime
('worker_basic', 'overtime.view_own'),
('worker_basic', 'overtime.apply'),
-- Learning
('worker_basic', 'learning.view_own'),
('worker_basic', 'learning.enroll'),
-- Engagement
('worker_basic', 'engagement.survey_respond'),
('worker_basic', 'engagement.voice_submit'),
-- Notifications
('worker_basic', 'notification.view_own')
ON CONFLICT (permission_set, permission_code) DO NOTHING;

-- SUPERVISOR permissions (extends worker)
INSERT INTO permission_set_items (permission_set, permission_code) VALUES
('supervisor_ext', 'team.view'),
('supervisor_ext', 'team.attendance_view'),
('supervisor_ext', 'leave.approve'),
('supervisor_ext', 'overtime.approve'),
('supervisor_ext', 'task.assign'),
('supervisor_ext', 'task.approve')
ON CONFLICT (permission_set, permission_code) DO NOTHING;

-- MANAGER permissions (extends supervisor)
INSERT INTO permission_set_items (permission_set, permission_code) VALUES
('manager_ext', 'department.view'),
('manager_ext', 'department.reports'),
('manager_ext', 'kpi.view_team'),
('manager_ext', 'kpi.set_targets'),
('manager_ext', 'performance.review'),
('manager_ext', 'coaching.assign')
ON CONFLICT (permission_set, permission_code) DO NOTHING;

-- HRD permissions
INSERT INTO permission_set_items (permission_set, permission_code) VALUES
('hrd_ops', 'employee.view_all'),
('hrd_ops', 'employee.create'),
('hrd_ops', 'employee.update'),
('hrd_ops', 'employee.deactivate'),
('hrd_ops', 'recruitment.view'),
('hrd_ops', 'recruitment.approve'),
('hrd_ops', 'payroll.view_all'),
('hrd_ops', 'payroll.process'),
('hrd_ops', 'training.manage'),
('hrd_ops', 'talent.manage'),
('hrd_ops', 'offboarding.manage'),
('hrd_ops', 'compliance.manage')
ON CONFLICT (permission_set, permission_code) DO NOTHING;

-- FINANCE permissions
INSERT INTO permission_set_items (permission_set, permission_code) VALUES
('finance_ops', 'payroll.view_all'),
('finance_ops', 'payroll.process'),
('hrd_ops', 'payroll.export'),
('finance_ops', 'budget.view'),
('finance_ops', 'budget.approve'),
('finance_ops', 'timesheet.approve'),
('finance_ops', 'export.payroll'),
('finance_ops', 'export_financial')
ON CONFLICT (permission_set, permission_code) DO NOTHING;

-- INDUSTRY permissions
INSERT INTO permission_set_items (permission_set, permission_code) VALUES
('mining_ops', 'mining.simper_view'),
('mining_ops', 'mining.equipment_view'),
('mining_ops', 'mining.production_view'),
('mining_ops', 'mining.safety_view'),
('mining_ops', 'mining.fatigue_view'),
('mining_ops', 'mining.jsa_view'),
('mining_ops', 'mining.block_model_view'),
('estate_ops', 'estate.harvest_view'),
('estate_ops', 'estate.blocks_view'),
('estate_ops', 'estate.transport_view'),
('estate_ops', 'estate.nursery_view'),
('estate_ops', 'estate.irrigation_view'),
('estate_ops', 'estate.field_view'),
('estate_ops', 'estate.yield_view'),
('mill_ops', 'mill.boiler_view'),
('mill_ops', 'mill.press_view'),
('mill_ops', 'mill.qc_view'),
('mill_ops', 'mill.packing_view'),
('mill_ops', 'mill.maintenance_view'),
('mill_ops', 'mill.breakdown_view'),
('mill_ops', 'mill.production_view')
ON CONFLICT (permission_set, permission_code) DO NOTHING;

-- ADMIN PUSAT permissions (all operational)
INSERT INTO permission_set_items (permission_set, permission_code) VALUES
('admin_pusat_all', 'employee.view_all'),
('admin_pusat_all', 'employee.create'),
('admin_pusat_all', 'employee.update'),
('admin_pusat_all', 'employee.deactivate'),
('admin_pusat_all', 'payroll.view_all'),
('admin_pusat_all', 'payroll.process'),
('admin_pusat_all', 'payroll.export'),
('admin_pusat_all', 'budget.view'),
('admin_pusat_all', 'budget.approve'),
('admin_pusat_all', 'kpi.manage'),
('admin_pusat_all', 'learning.manage'),
('admin_pusat_all', 'recruitment.manage'),
('admin_pusat_all', 'talent.manage'),
('admin_pusat_all', 'timesheet.approve'),
('admin_pusat_all', 'leave.approve'),
('admin_pusat_all', 'overtime.approve'),
('admin_pusat_all', 'compliance.manage'),
('admin_pusat_all', 'audit.view'),
('admin_pusat_all', 'mining.manage'),
('admin_pusat_all', 'estate.manage'),
('admin_pusat_all', 'mill.manage')
ON CONFLICT (permission_set, permission_code) DO NOTHING;

-- ============================================================
-- PART 2: ROLE → PERMISSION SET MAPPING
-- ============================================================

INSERT INTO role_permission_sets (role_code, permission_set) VALUES
('worker', 'worker_basic'),
('supervisor', 'worker_basic'),
('supervisor', 'supervisor_ext'),
('manager', 'worker_basic'),
('manager', 'supervisor_ext'),
('manager', 'manager_ext'),
('admin_hrd', 'worker_basic'),
('admin_hrd', 'supervisor_ext'),
('admin_hrd', 'manager_ext'),
('admin_hrd', 'hrd_ops'),
('admin_finance', 'worker_basic'),
('admin_finance', 'supervisor_ext'),
('admin_finance', 'finance_ops'),
('admin_produksi', 'worker_basic'),
('admin_produksi', 'supervisor_ext'),
('admin_produksi', 'manager_ext'),
('admin_mining', 'worker_basic'),
('admin_mining', 'mining_ops'),
('admin_estate', 'worker_basic'),
('admin_estate', 'estate_ops'),
('admin_mill', 'worker_basic'),
('admin_mill', 'mill_ops'),
('admin_pusat', 'worker_basic'),
('admin_pusat', 'supervisor_ext'),
('admin_pusat', 'manager_ext'),
('admin_pusat', 'admin_pusat_all')
ON CONFLICT (role_code, permission_set) DO NOTHING;

-- ============================================================
-- PART 3: SEED user_role_assignments FROM existing user_roles
-- ============================================================

INSERT INTO user_role_assignments (nrp, role_code, scope_type, scope_bu_id, is_primary)
SELECT
  ur.nrp,
  ur.role,
  CASE
    WHEN ur.role = 'worker' THEN 'SELF'
    WHEN ur.role IN ('admin_mining') THEN 'BU'
    WHEN ur.role IN ('admin_estate') THEN 'BU'
    WHEN ur.role IN ('admin_mill') THEN 'BU'
    WHEN ur.role IN ('admin_hrd', 'admin_finance', 'admin_produksi') THEN 'ENTERPRISE'
    WHEN ur.role = 'admin_pusat' THEN 'ENTERPRISE'
    ELSE 'SELF'
  END,
  COALESCE(em.business_unit_id, 'HQ'),
  TRUE
FROM user_roles ur
LEFT JOIN employees_master em ON em.nrp = ur.nrp
ON CONFLICT (nrp, role_code, scope_type, scope_bu_id) DO NOTHING;

-- ============================================================
-- PART 4: SEED bu_subscription FROM existing business_units
-- ============================================================

INSERT INTO bu_subscription (bu_id, plan, enabled_modules)
SELECT
  id,
  CASE WHEN tier >= 4 THEN 'ENTERPRISE' WHEN tier >= 3 THEN 'PREMIUM' WHEN tier >= 2 THEN 'STANDARD' WHEN tier >= 1 THEN 'BASIC' ELSE 'FREE' END,
  ARRAY(SELECT module_code FROM module_definitions WHERE is_active = TRUE)
FROM business_units
ON CONFLICT (bu_id) DO UPDATE SET
  plan = EXCLUDED.plan,
  enabled_modules = EXCLUDED.enabled_modules,
  updated_at = NOW();
