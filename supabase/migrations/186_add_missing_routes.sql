-- ================================================================
-- 186_add_missing_routes.sql
-- Add utility/standalone routes not yet in module_definitions.
-- These are non-module pages (auth, settings, dashboards).
-- ================================================================

-- Worker utility routes
INSERT INTO module_definitions (id, module_code, module_name, module_group, menu_icon, menu_order, is_active, route_path, route_component, route_group)
VALUES
  ('worker_landing', 'worker_landing', 'Worker Home', 'CORE', 'Home', 5, true, '/worker', 'Worker', 'worker'),
  ('worker_changepw', 'worker_changepw', 'Ubah Password', 'PLATFORM', 'Key', 999, true, '/worker/change-password', 'WorkerChangePassword', 'worker'),
  ('worker_mfa', 'worker_mfa', 'MFA Setup', 'PLATFORM', 'Lock', 998, true, '/worker/mfa', 'MfaSetup', 'worker'),
  ('worker_request', 'worker_request', 'Buat Pengajuan', 'CORE', 'Send', 56, true, '/worker/request', 'MultiStepRequest', 'worker'),
  ('worker_taskboard', 'worker_taskboard', 'Task Board', 'CORE', 'ListTodo', 57, true, '/worker/task-board', 'TaskBoard', 'worker'),
  ('worker_perf_notes', 'worker_perf_notes', 'Performance Notes', 'CORE', 'FileText', 71, true, '/worker/performance-notes', 'PerformanceNotes', 'worker'),
  ('worker_okr', 'worker_okr', 'My OKR', 'CORE', 'Target', 61, true, '/worker/okr', 'Okrs', 'worker'),
  ('worker_surveys', 'worker_surveys', 'Surveys', 'PLATFORM', 'Clipboard', 131, true, '/worker/surveys', 'SurveyPage', 'worker'),
  ('worker_voice', 'worker_voice', 'Voice & Ideas', 'PLATFORM', 'MessageCircle', 141, true, '/worker/voice', 'VoiceIdeasPage', 'worker'),
  ('worker_forum', 'worker_forum', 'Forum Diskusi', 'PLATFORM', 'MessagesSquare', 151, true, '/worker/forum', 'ForumDiskusi', 'worker'),
  ('worker_perf_trend', 'worker_perf_trend', 'Performance Trend', 'CORE', 'TrendingUp', 72, true, '/worker/perf-trend', 'PerformanceTrend', 'worker'),
  ('worker_compensation', 'worker_compensation', 'Compensation Intel', 'CORE', 'DollarSign', 73, true, '/worker/compensation', 'CompensationIntel', 'worker'),
  ('worker_continuous', 'worker_continuous', 'Continuous Perf', 'CORE', 'RefreshCw', 74, true, '/worker/continuous-perf', 'ContinuousPerf', 'worker'),
  ('worker_training', 'worker_training', 'Training Form', 'CORE', 'BookOpen', 81, true, '/worker/training', 'TrainingForm', 'worker'),
  ('worker_emergency', 'worker_emergency', 'Prosedur Darurat', 'GOVERNANCE', 'AlertTriangle', 561, true, '/worker/emergency', 'EmergencyProcedures', 'worker'),
  ('worker_facility', 'worker_facility', 'Fasilitas', 'CORE', 'Building', 651, true, '/worker/facility', 'FacilityRequest', 'worker'),
  ('worker_medical', 'worker_medical', 'Medical Checkup', 'CORE', 'HeartPulse', 661, true, '/worker/medical', 'MedicalCheckup', 'worker')
ON CONFLICT (module_code) DO UPDATE SET
  route_path = EXCLUDED.route_path,
  route_component = EXCLUDED.route_component,
  route_group = EXCLUDED.route_group;

-- Admin utility routes
INSERT INTO module_definitions (id, module_code, module_name, module_group, menu_icon, menu_order, is_active, route_path, route_component, route_group)
VALUES
  ('admin_landing', 'admin_landing', 'Admin Home', 'PLATFORM', 'LayoutDashboard', 5, true, '/admin', 'Admin', 'admin'),
  ('admin_reset_pw', 'admin_reset_pw', 'Reset Password Worker', 'PLATFORM', 'KeyRound', 997, true, '/admin/reset-password', 'ResetPassword', 'admin'),
  ('admin_mfa', 'admin_mfa', 'MFA Setup Admin', 'PLATFORM', 'Lock', 996, true, '/admin/mfa', 'MfaSetup', 'admin'),
  ('admin_chain', 'admin_chain', 'Audit Chain', 'GOVERNANCE', 'Link', 331, true, '/admin/chain', 'AuditChainPage', 'admin'),
  ('admin_incentive', 'admin_incentive', 'Incentive Calc', 'CORE', 'Coins', 62, true, '/admin/incentive', 'IncentiveCalc', 'admin'),
  ('admin_okr', 'admin_okr', 'OKR Management', 'CORE', 'Target', 63, true, '/admin/okr', 'Okrs', 'admin'),
  ('admin_shift_swap', 'admin_shift_swap', 'Shift Swap', 'CORE', 'ArrowLeftRight', 315, true, '/admin/shift-swap', 'ShiftSchedule', 'admin'),
  ('admin_requests', 'admin_requests', 'Daftar Pengajuan', 'PLATFORM', 'Inbox', 321, true, '/admin/requests', 'RequestsList', 'admin'),
  ('admin_pipeline', 'admin_pipeline', 'Pipeline Kanban', 'CORE', 'Columns', 112, true, '/admin/pipeline', 'PipelineKanban', 'admin'),
  ('admin_screening', 'admin_screening', 'Screening', 'CORE', 'Search', 113, true, '/admin/screening', 'ScreeningPage', 'admin'),
  ('admin_approval_wf', 'admin_approval_wf', 'Approval Workflow', 'PLATFORM', 'GitPullRequest', 322, true, '/admin/approval-workflow', 'ApprovalWorkflow', 'admin'),
  ('admin_review360', 'admin_review360', 'Review 360', 'CORE', 'Users', 86, true, '/admin/review-360', 'Review360', 'admin'),
  ('admin_org_subtree', 'admin_org_subtree', 'Org Subtree', 'PLATFORM', 'Network', 301, true, '/admin/org-subtree', 'OrgSubtree', 'admin'),
  ('admin_master', 'admin_master', 'Master Data', 'PLATFORM', 'Database', 311, true, '/admin/master', 'MasterDataPage', 'admin'),
  ('admin_roles', 'admin_roles', 'Role Matrix', 'PLATFORM', 'Shield', 312, true, '/admin/roles', 'RoleMatrixPage', 'admin'),
  ('admin_assets', 'admin_assets', 'Asset Management', 'CORE', 'Package', 450, true, '/admin/assets', 'AssetManagement', 'admin'),
  ('admin_surveys', 'admin_surveys', 'Surveys Admin', 'PLATFORM', 'Clipboard', 132, true, '/admin/surveys', 'SurveyPage', 'admin'),
  ('admin_voice', 'admin_voice', 'Voice Ideas Admin', 'PLATFORM', 'MessageCircle', 142, true, '/admin/voice', 'VoiceIdeasPage', 'admin'),
  ('admin_whistleblower', 'admin_whistleblower', 'Whistleblowing Admin', 'GOVERNANCE', 'Shield', 371, true, '/admin/whistleblower', 'WhistleblowingPage', 'admin'),
  ('admin_features', 'admin_features', 'Feature Flags', 'PLATFORM', 'ToggleLeft', 341, true, '/admin/features', 'FeatureFlagsPage', 'admin'),
  ('admin_integrations', 'admin_integrations', 'Integrations', 'PLATFORM', 'Plug', 342, true, '/admin/integrations', 'Integrations', 'admin'),
  ('admin_timesheet_mgmt', 'admin_timesheet_mgmt', 'Timesheet Management', 'CORE', 'Clock', 21, true, '/admin/timesheet', 'TimesheetManagement', 'admin'),
  ('admin_attendance', 'admin_attendance', 'Attendance Admin', 'CORE', 'CheckSquare', 22, true, '/admin/attendance', 'AdminAttendance', 'admin'),
  ('dashboard_landing', 'dashboard_landing', 'CEO Dashboard', 'INTELLIGENCE', 'Layout', 201, true, '/dashboard', 'Dashboard', 'admin')
ON CONFLICT (module_code) DO UPDATE SET
  route_path = EXCLUDED.route_path,
  route_component = EXCLUDED.route_component,
  route_group = EXCLUDED.route_group;

-- Industry admin dashboards
INSERT INTO module_definitions (id, module_code, module_name, module_group, menu_icon, menu_order, is_active, route_path, route_component, route_group, is_industry_module)
VALUES
  ('admin_mining', 'admin_mining', 'Mining Dashboard', 'INDUSTRY', 'HardHat', 501, true, '/admin/mining', 'MiningAdminDashboard', 'admin', true),
  ('admin_estate', 'admin_estate', 'Estate Dashboard', 'INDUSTRY', 'TreePine', 601, true, '/admin/estate', 'EstateAdminDashboard', 'admin', true),
  ('admin_mill', 'admin_mill', 'Mill Dashboard', 'INDUSTRY', 'Factory', 701, true, '/admin/mill', 'MillAdminDashboard', 'admin', true)
ON CONFLICT (module_code) DO UPDATE SET
  route_path = EXCLUDED.route_path,
  route_component = EXCLUDED.route_component,
  route_group = EXCLUDED.route_group;
