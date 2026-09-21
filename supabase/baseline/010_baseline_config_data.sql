-- ================================================================
-- BASELINE DATA REFERENSI + CAP REGISTRY MIGRASI
-- ================================================================
--
-- Sumber    : DB live (host, project ref & password sengaja TIDAK ditulis)
-- Generator : supabase/scripts/generate-baseline-data.mjs
--
-- JALANKAN SETELAH 000_baseline_schema.sql, sebagai role `postgres`.
--
-- ISI
--   * Baris tabel konfigurasi/referensi (menu, route, role, permission, config).
--   * Cap `schema_migrations` untuk seluruh berkas migrasi repo.
--
--   * Branding asli        : baris `branding` di-emit NETRAL (nama dari
--     `--company-name`, logo & warna dikosongkan) — merek DB sumber tidak menular.
--
-- YANG SENGAJA TIDAK ADA
--   * Data karyawan / PII  : employees_core, employees_extended, user_roles,
--     user_role_assignments, worker_passwords.
--   * Data transaksi       : attendance, payroll, overtime, audit_log, hr_okrs,
--     reviews_360, sessions, login_attempts, forum_*.
--   Perusahaan baru mulai dari data kosong lalu onboarding karyawannya sendiri.
--
-- KENAPA ADA CAP schema_migrations
--   Tanpa cap, operator akan mengira migrasi 000..NNN belum jalan lalu
--   me-replay-nya di atas baseline. Replay itu HANCUR (86 berkas gagal — akar:
--   tidak ada migrasi yang men-seed karyawan, sehingga seed anak melanggar FK).
--
-- IDEMPOTEN: tiap tabel hanya diisi bila masih kosong.

set client_min_messages = warning;

-- ── business_units (4 baris) ──
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.business_units LIMIT 1) THEN
    RAISE NOTICE 'business_units sudah berisi data — dilewati';
    RETURN;
  END IF;
  INSERT INTO public.business_units (id, unit_code, unit_name, description, is_active, effective_from, effective_to, tier) VALUES ('BU04', 'HQ', 'Korporat', NULL, 'true', '2026-09-02'::date, NULL, '4');
  INSERT INTO public.business_units (id, unit_code, unit_name, description, is_active, effective_from, effective_to, tier) VALUES ('BU01', 'MINING', 'Tambang', 'Unit Bisnis Pertambangan', 'true', '2026-09-03'::date, NULL, '4');
  INSERT INTO public.business_units (id, unit_code, unit_name, description, is_active, effective_from, effective_to, tier) VALUES ('BU03', 'MILL', 'Pabrik', 'Unit Bisnis Pabrik Kelapa Sawit', 'true', '2026-09-03'::date, NULL, '4');
  INSERT INTO public.business_units (id, unit_code, unit_name, description, is_active, effective_from, effective_to, tier) VALUES ('BU02', 'ESTATE', 'Perkebunan', 'Unit Bisnis Perkebunan Sawit', 'true', '2026-09-03'::date, NULL, '4');
END $$;

-- ── module_definitions (155 baris) ──
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.module_definitions LIMIT 1) THEN
    RAISE NOTICE 'module_definitions sudah berisi data — dilewati';
    RETURN;
  END IF;
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('worker_compensation', 'worker_compensation', 'Compensation Intel', 'CORE', NULL, '0', 'false', 'DollarSign', '73', 'true', '2026-09-06 13:29:00.111314+00'::timestamptz, '/worker/compensation', 'CompensationIntel', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('worker_continuous', 'worker_continuous', 'Continuous Perf', 'CORE', NULL, '0', 'false', 'RefreshCw', '74', 'true', '2026-09-06 13:29:00.111314+00'::timestamptz, '/worker/continuous-perf', 'ContinuousPerf', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('worker_training', 'worker_training', 'Training Form', 'CORE', NULL, '0', 'false', 'BookOpen', '81', 'true', '2026-09-06 13:29:00.111314+00'::timestamptz, '/worker/training', 'TrainingForm', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('worker_emergency', 'worker_emergency', 'Prosedur Darurat', 'GOVERNANCE', NULL, '0', 'false', 'AlertTriangle', '561', 'true', '2026-09-06 13:29:00.111314+00'::timestamptz, '/worker/emergency', 'EmergencyProcedures', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('worker_facility', 'worker_facility', 'Fasilitas', 'CORE', NULL, '0', 'false', 'Building', '651', 'true', '2026-09-06 13:29:00.111314+00'::timestamptz, '/worker/facility', 'FacilityRequest', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('worker_medical', 'worker_medical', 'Medical Checkup', 'CORE', NULL, '0', 'false', 'HeartPulse', '661', 'true', '2026-09-06 13:29:00.111314+00'::timestamptz, '/worker/medical', 'MedicalCheckup', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_org_subtree', 'admin_org_subtree', 'Org Subtree', 'PLATFORM', NULL, '0', 'false', 'Network', '301', 'true', '2026-09-06 13:29:00.313317+00'::timestamptz, '/admin/org-subtree', 'OrgSubtree', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_master', 'admin_master', 'Master Data', 'PLATFORM', NULL, '0', 'false', 'Database', '311', 'true', '2026-09-06 13:29:00.313317+00'::timestamptz, '/admin/master', 'MasterDataPage', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_roles', 'admin_roles', 'Role Matrix', 'PLATFORM', NULL, '0', 'false', 'Shield', '312', 'true', '2026-09-06 13:29:00.313317+00'::timestamptz, '/admin/roles', 'RoleMatrixPage', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_assets', 'admin_assets', 'Asset Management', 'CORE', NULL, '0', 'false', 'Package', '450', 'true', '2026-09-06 13:29:00.313317+00'::timestamptz, '/admin/assets', 'AssetManagement', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_surveys', 'admin_surveys', 'Surveys Admin', 'PLATFORM', NULL, '0', 'false', 'Clipboard', '132', 'true', '2026-09-06 13:29:00.313317+00'::timestamptz, '/admin/surveys', 'SurveyPage', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_voice', 'admin_voice', 'Voice Ideas Admin', 'PLATFORM', NULL, '0', 'false', 'MessageCircle', '142', 'true', '2026-09-06 13:29:00.313317+00'::timestamptz, '/admin/voice', 'VoiceIdeasPage', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_whistleblower', 'admin_whistleblower', 'Whistleblowing Admin', 'GOVERNANCE', NULL, '0', 'false', 'Shield', '371', 'true', '2026-09-06 13:29:00.313317+00'::timestamptz, '/admin/whistleblower', 'WhistleblowingPage', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_features', 'admin_features', 'Feature Flags', 'PLATFORM', NULL, '0', 'false', 'ToggleLeft', '341', 'true', '2026-09-06 13:29:00.313317+00'::timestamptz, '/admin/features', 'FeatureFlagsPage', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_integrations', 'admin_integrations', 'Integrations', 'PLATFORM', NULL, '0', 'false', 'Plug', '342', 'true', '2026-09-06 13:29:00.313317+00'::timestamptz, '/admin/integrations', 'Integrations', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_timesheet_mgmt', 'admin_timesheet_mgmt', 'Timesheet Management', 'CORE', NULL, '0', 'false', 'Clock', '21', 'true', '2026-09-06 13:29:00.313317+00'::timestamptz, '/admin/timesheet', 'TimesheetManagement', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_attendance', 'admin_attendance', 'Attendance Admin', 'CORE', NULL, '0', 'false', 'CheckSquare', '22', 'true', '2026-09-06 13:29:00.313317+00'::timestamptz, '/admin/attendance', 'AdminAttendance', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_learning2', 'learning_admin', 'Learning', 'PLATFORM', 'Manajemen pembelajaran (admin)', '0', 'false', 'GraduationCap', '222', 'true', '2026-09-07 23:15:21.613059+00'::timestamptz, '/admin/learning', 'LearningManagement', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_badges', 'badges_admin', 'Badge & Gamifikasi', 'PLATFORM', 'Badge & gamifikasi', '0', 'false', 'Medal', '224', 'true', '2026-09-07 23:15:21.613059+00'::timestamptz, '/admin/badges', 'BadgesPage', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_asset_assign', 'asset_assign', 'Check-in/out Aset', 'PLATFORM', 'Check-in/out aset', '0', 'false', 'Package', '225', 'true', '2026-09-07 23:15:21.613059+00'::timestamptz, '/admin/asset-assign', 'AssetManagement', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_facility', 'facility_admin', 'Facility Request', 'PLATFORM', 'Permintaan fasilitas', '0', 'false', 'Building', '227', 'true', '2026-09-07 23:15:21.613059+00'::timestamptz, '/admin/facility', 'FacilityRequest', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_forum', 'forum_admin', 'Forum', 'PLATFORM', 'Forum diskusi (admin)', '0', 'false', 'MessagesSquare', '228', 'true', '2026-09-07 23:15:21.613059+00'::timestamptz, '/admin/forum', 'ForumDiskusi', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_headcount', 'headcount', 'Headcount Plan', 'PLATFORM', 'Perencanaan headcount', '0', 'false', 'Users', '232', 'true', '2026-09-07 23:15:21.613059+00'::timestamptz, '/admin/headcount', 'HeadcountPage', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_referral', 'referral_admin', 'Referral Program', 'PLATFORM', 'Program referral', '0', 'false', 'Handshake', '233', 'true', '2026-09-07 23:15:21.613059+00'::timestamptz, '/admin/referral', 'ReferralPage', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('3f521b6b-772f-4688-9baa-73737e5a38b4', 'compensation-intel', 'compensation intel', 'PLATFORM', NULL, '0', 'false', NULL, '0', 'true', '2026-09-11 15:11:34.650998+00'::timestamptz, '/admin/compensation-intel', 'CompensationIntel', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('00fe460c-45e7-4541-bcff-1923a3e35d18', 'feature-flags', 'feature flags', 'PLATFORM', NULL, '0', 'false', NULL, '0', 'true', '2026-09-11 16:06:55.758868+00'::timestamptz, '/admin/feature-flags', 'FeatureFlagsPage', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('6622ebb7-d077-4a36-9c11-2ec961e8a9b9', 'okrs', 'okrs', 'PLATFORM', NULL, '0', 'false', NULL, '0', 'true', '2026-09-11 16:06:52.789316+00'::timestamptz, '/admin/okrs', 'Okrs', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('50e5a820-d9d5-4c5c-8b9f-4118e32c0baa', 'org-chart', 'org chart', 'PLATFORM', NULL, '0', 'false', NULL, '0', 'true', '2026-09-11 16:06:49.408507+00'::timestamptz, '/admin/org-chart', 'OrgChart', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('19ae6de2-e5ca-4728-8cfa-3272971a3e68', 'performance-trend', 'performance trend', 'PLATFORM', NULL, '0', 'false', NULL, '0', 'true', '2026-09-11 16:06:55.143909+00'::timestamptz, '/admin/performance-trend', 'PerformanceTrend', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('d5903f1d-2c88-4d09-990d-0e5c75600cf7', 'role-matrix', 'role matrix', 'PLATFORM', NULL, '0', 'false', NULL, '0', 'true', '2026-09-11 16:06:50.279683+00'::timestamptz, '/admin/role-matrix', 'RoleMatrixPage', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('e31db590-3694-448c-aaa9-668e5ae6975b', 'shift-schedule', 'shift schedule', 'PLATFORM', NULL, '0', 'false', NULL, '0', 'true', '2026-09-11 16:06:51.560044+00'::timestamptz, '/admin/shift-schedule', 'ShiftSchedule', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('1f2c64a1-973c-4f18-a72b-d767ccd59d86', 'talent-market', 'talent market', 'PLATFORM', NULL, '0', 'false', NULL, '0', 'true', '2026-09-11 16:06:53.710609+00'::timestamptz, '/admin/talent-market', 'TalentMarketPage', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_001', 'profile', 'Profil Karyawan', 'CORE', NULL, '0', 'false', 'User', '10', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/worker/profile', 'WorkerProfile', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_002', 'attendance', 'Absensi', 'CORE', NULL, '0', 'false', 'Clock', '20', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/worker/attendance', 'WorkerAttendance', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_003', 'leave', 'Cuti', 'CORE', NULL, '0', 'false', 'Calendar', '30', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/worker/leave', 'WorkerLeave', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_004', 'overtime', 'Lembur', 'CORE', NULL, '0', 'false', 'Timer', '40', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/worker/overtime', 'WorkerOvertime', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_005', 'payroll', 'Gaji', 'CORE', NULL, '0', 'false', 'DollarSign', '50', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/worker/payroll', 'WorkerPayroll', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_006', 'self_service', 'Self-Service', 'CORE', NULL, '0', 'false', 'Layers', '55', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/worker/tasks', 'TaskBoard', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_009', 'learning', 'Learning', 'CORE', NULL, '0', 'false', 'BookOpen', '80', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/worker/learning', 'WorkerLearning', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_010', '360_review', 'Review 360', 'CORE', NULL, '0', 'false', 'Users', '85', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/worker/review-360', 'WorkerReview360', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_012', 'career_path', 'Career Path', 'CORE', NULL, '0', 'false', 'Route', '95', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/worker/career', 'WorkerCareer', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_007', 'kpi', 'KPI', 'CORE', NULL, '0', 'false', 'Target', '60', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/admin/kpi', 'Kpi', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_008', 'performance', 'Kinerja', 'CORE', NULL, '0', 'false', 'BarChart', '70', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/admin/performance', 'PerformanceNotes', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_011', 'talent', 'Talent', 'CORE', NULL, '0', 'false', 'Star', '90', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/admin/talent', 'TalentMarketPage', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_013', 'succession', 'Succession', 'CORE', NULL, '0', 'false', 'GitBranch', '100', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/admin/succession', 'SuccessionPlanning', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_014', 'recruitment', 'Rekrutmen', 'CORE', NULL, '0', 'false', 'UserPlus', '110', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/admin/recruitment', 'RecruitmentDashboard', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_015', 'onboarding', 'Onboarding', 'CORE', NULL, '0', 'false', 'Clipboard', '115', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/admin/onboarding', 'OnboardingWorkflow', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('worker_changepw', 'worker_changepw', 'Ubah Password', 'PLATFORM', NULL, '0', 'false', 'Key', '999', 'true', '2026-09-06 13:29:00.111314+00'::timestamptz, '/worker/change-password', 'WorkerChangePassword', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('worker_mfa', 'worker_mfa', 'MFA Setup', 'PLATFORM', NULL, '0', 'false', 'Lock', '998', 'true', '2026-09-06 13:29:00.111314+00'::timestamptz, '/worker/mfa', 'MfaSetup', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('worker_request', 'worker_request', 'Buat Pengajuan', 'CORE', NULL, '0', 'false', 'Send', '56', 'true', '2026-09-06 13:29:00.111314+00'::timestamptz, '/worker/request', 'MultiStepRequest', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('worker_taskboard', 'worker_taskboard', 'Task Board', 'CORE', NULL, '0', 'false', 'ListTodo', '57', 'true', '2026-09-06 13:29:00.111314+00'::timestamptz, '/worker/task-board', 'TaskBoard', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_020', 'referral', 'Referral', 'CORE', NULL, '0', 'false', 'Share2', '150', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/worker/referral', 'ReferralPage', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_016', 'offboarding', 'Offboarding', 'CORE', NULL, '0', 'false', 'UserMinus', '120', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/admin/exit', 'Offboarding', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_023', 'workforce_planning', 'Workforce Planning', 'CORE', NULL, '0', 'false', 'TrendingUp', '220', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/admin/workforce', 'HeadcountPage', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_024', 'simulation', 'Simulasi', 'CORE', NULL, '0', 'false', 'Cpu', '230', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/admin/simulation', 'WorkforceSimulation', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_025', 'turnover', 'Turnover', 'CORE', NULL, '0', 'false', 'Activity', '240', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/admin/turnover', 'TurnoverPrediction', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_026', 'flight_risk', 'Flight Risk', 'CORE', NULL, '0', 'false', 'AlertTriangle', '250', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/admin/flight-risk', 'TurnoverPrediction', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_027', 'narrative', 'Narrative AI', 'CORE', NULL, '0', 'false', 'Brain', '260', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/admin/narrative', 'Analytics', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_050', 'org_structure', 'Struktur Organisasi', 'PLATFORM', NULL, '2', 'false', 'Network', '300', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/admin/org', 'OrgChart', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_051', 'divisions', 'Divisi', 'PLATFORM', NULL, '2', 'false', 'Grid', '310', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/admin/divisions', 'DivisionsManagement', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_052', 'approvals', 'Approval', 'PLATFORM', NULL, '2', 'false', 'CheckCircle', '320', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/admin/approvals', 'ApprovalCenter', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_053', 'audit_log', 'Audit Log', 'PLATFORM', NULL, '2', 'false', 'FileText', '330', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/admin/audit', 'AuditLog', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_054', 'settings', 'Pengaturan', 'PLATFORM', NULL, '2', 'false', 'Settings', '340', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/admin/settings', 'Settings', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_055', 'export_data', 'Export Data', 'PLATFORM', NULL, '2', 'false', 'Download', '350', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/admin/export', 'ExportPage', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_056', 'announcements', 'Pengumuman', 'PLATFORM', NULL, '2', 'false', 'Bell', '360', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/admin/announcements', 'SurveyPage', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_057', 'whistleblowing', 'Whistleblowing', 'PLATFORM', NULL, '2', 'false', 'Shield', '370', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/worker/whistleblowing', 'WhistleblowingPage', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_058', 'mfa', 'MFA Setup', 'PLATFORM', NULL, '2', 'false', 'Lock', '380', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/admin/mfa', 'MfaSetup', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_059', 'module_management', 'Module Management', 'PLATFORM', NULL, '2', 'false', 'Package', '390', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/admin/modules', 'ModuleManagement', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_060', 'safety', 'Safety K3', 'GOVERNANCE', NULL, '2', 'false', 'ShieldAlert', '400', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/admin/safety', 'SafetyK3', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_061', 'qhse', 'QHSE', 'GOVERNANCE', NULL, '2', 'false', 'ClipboardCheck', '410', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/admin/qhse', 'SafetyK3', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_101', 'mining_simper', 'SIMPER', 'INDUSTRY', NULL, '3', 'true', 'HardHat', '500', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/worker/simper', 'SimperPage', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_102', 'mining_equipment', 'Heavy Equipment', 'INDUSTRY', NULL, '3', 'true', 'Truck', '510', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/worker/heavy-equip', 'HeavyEquipment', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_103', 'mining_production', 'Produksi Tambang', 'INDUSTRY', NULL, '3', 'true', 'Factory', '520', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/worker/production', 'ProductionDaily', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_104', 'mining_fuel', 'BBM & Fuel', 'INDUSTRY', NULL, '3', 'true', 'Droplet', '530', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/worker/fuel', 'ProductionDaily', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_105', 'mining_fatigue', 'Fatigue Monitor', 'INDUSTRY', NULL, '3', 'true', 'Eye', '540', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/worker/fatigue', 'FatigueMonitor', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_106', 'mining_safety', 'K3 Tambang', 'INDUSTRY', NULL, '3', 'true', 'ShieldAlert', '550', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/worker/safety', 'SafetyK3', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_107', 'mining_jsa', 'JSA', 'INDUSTRY', NULL, '3', 'true', 'FileCheck', '560', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/worker/jsa', 'JobSafetyAnalysis', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_111', 'estate_harvest', 'Panen', 'INDUSTRY', NULL, '3', 'true', 'Scissors', '600', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/worker/harvest', 'HarvestRecord', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_112', 'estate_blocks', 'Block & Afdeling', 'INDUSTRY', NULL, '3', 'true', 'Grid', '610', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/worker/blocks', 'BlockManagement', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_113', 'estate_irrigation', 'Irigasi', 'INDUSTRY', NULL, '3', 'true', 'Droplets', '620', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/worker/irrigation', 'IrrigationPage', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_114', 'estate_nursery', 'Pembibitan', 'INDUSTRY', NULL, '3', 'true', 'Sprout', '630', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/worker/nursery', 'NurseryPage', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_115', 'estate_transport', 'Transport TBS', 'INDUSTRY', NULL, '3', 'true', 'Truck', '640', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/worker/transport', 'TransportTBS', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_116', 'estate_field', 'Aktivitas Lapangan', 'INDUSTRY', NULL, '3', 'true', 'MapPin', '650', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/worker/field', 'FacilityRequest', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_117', 'estate_yield', 'Produktivitas', 'INDUSTRY', NULL, '3', 'true', 'TrendingUp', '660', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/worker/yield', 'ProductionDaily', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_121', 'mill_boiler', 'Boiler Monitor', 'INDUSTRY', NULL, '3', 'true', 'Thermometer', '700', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/worker/boiler', 'BoilerMonitor', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_122', 'mill_press', 'Mesin Press', 'INDUSTRY', NULL, '3', 'true', 'Cpu', '710', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/worker/machines', 'MesinPress', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_123', 'mill_qc', 'QC Lab', 'INDUSTRY', NULL, '3', 'true', 'Flask', '720', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/worker/qc', 'QcLab', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_124', 'mill_packing', 'Packing', 'INDUSTRY', NULL, '3', 'true', 'Package', '730', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/worker/packing', 'PackingLog', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_125', 'mill_maintenance', 'Preventive Maintenance', 'INDUSTRY', NULL, '3', 'true', 'Wrench', '740', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/worker/maintenance', 'PreventiveMaintenance', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_126', 'mill_breakdown', 'Breakdown Report', 'INDUSTRY', NULL, '3', 'true', 'AlertTriangle', '750', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/worker/breakdown', 'BreakdownLog', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_127', 'mill_shift', 'Jadwal Shift', 'INDUSTRY', NULL, '3', 'true', 'Clock', '760', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/worker/shift', 'MillShiftSchedule', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_payroll', 'payroll_admin', 'Payroll', 'PLATFORM', 'Proses payroll & laporan gaji', '0', 'false', 'DollarSign', '210', 'true', '2026-09-07 16:53:42.100381+00'::timestamptz, '/admin/payroll', 'Payroll', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_budget', 'budget', 'Budget', 'GOVERNANCE', 'Perencanaan & monitoring anggaran', '0', 'false', 'Wallet', '211', 'true', '2026-09-07 16:53:42.100381+00'::timestamptz, '/admin/budget', 'BudgetPage', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_employees', 'employees', 'Data Karyawan', 'PLATFORM', 'Manajemen master data karyawan', '0', 'false', 'Users', '212', 'true', '2026-09-07 16:53:42.100381+00'::timestamptz, '/admin/employees', 'Employees', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_leave', 'leave_admin', 'Cuti', 'PLATFORM', 'Manajemen pengajuan cuti', '0', 'false', 'CalendarDays', '214', 'true', '2026-09-07 16:53:42.100381+00'::timestamptz, '/admin/leave', 'LeaveManagement', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_overtime', 'overtime_admin', 'Lembur', 'PLATFORM', 'Manajemen pengajuan lembur', '0', 'false', 'Clock', '215', 'true', '2026-09-07 16:53:42.100381+00'::timestamptz, '/admin/overtime', 'OvertimeManagement', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('worker_landing', 'worker_landing', 'Worker Home', 'CORE', NULL, '0', 'false', 'Home', '5', 'true', '2026-09-06 13:29:00.111314+00'::timestamptz, '/worker', NULL, 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_019', 'badges', 'Badges', 'CORE', NULL, '0', 'false', 'Award', '145', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/worker/badges', 'BadgesPage', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_017', 'engagement', 'Engagement', 'CORE', NULL, '0', 'false', 'Heart', '130', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/admin/engagement', 'SurveyPage', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_018', 'voice_ideas', 'Voice & Ideas', 'CORE', NULL, '0', 'false', 'MessageCircle', '140', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/admin/voice', 'VoiceIdeasPage', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_062', 'certifications', 'Sertifikasi', 'GOVERNANCE', NULL, '2', 'false', 'Award', '420', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/admin/certifications', 'CertificationsPage', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_021', 'ceo_dashboard', 'CEO Dashboard', 'CORE', NULL, '0', 'false', 'Layout', '200', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/dashboard', 'Dashboard', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('mod_022', 'analytics', 'Analytics', 'CORE', NULL, '0', 'false', 'PieChart', '210', 'true', '2026-09-03 03:02:54.273916+00'::timestamptz, '/admin/analytics', 'Analytics', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('worker_perf_notes', 'worker_perf_notes', 'Performance Notes', 'CORE', NULL, '0', 'false', 'FileText', '71', 'true', '2026-09-06 13:29:00.111314+00'::timestamptz, '/worker/performance-notes', 'PerformanceNotes', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('worker_okr', 'worker_okr', 'My OKR', 'CORE', NULL, '0', 'false', 'Target', '61', 'true', '2026-09-06 13:29:00.111314+00'::timestamptz, '/worker/okr', 'Okrs', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('worker_surveys', 'worker_surveys', 'Surveys', 'PLATFORM', NULL, '0', 'false', 'Clipboard', '131', 'true', '2026-09-06 13:29:00.111314+00'::timestamptz, '/worker/surveys', 'SurveyPage', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('worker_voice', 'worker_voice', 'Voice & Ideas', 'PLATFORM', NULL, '0', 'false', 'MessageCircle', '141', 'true', '2026-09-06 13:29:00.111314+00'::timestamptz, '/worker/voice', 'VoiceIdeasPage', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('worker_forum', 'worker_forum', 'Forum Diskusi', 'PLATFORM', NULL, '0', 'false', 'MessagesSquare', '151', 'true', '2026-09-06 13:29:00.111314+00'::timestamptz, '/worker/forum', 'ForumDiskusi', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('worker_perf_trend', 'worker_perf_trend', 'Performance Trend', 'CORE', NULL, '0', 'false', 'TrendingUp', '72', 'true', '2026-09-06 13:29:00.111314+00'::timestamptz, '/worker/perf-trend', 'PerformanceTrend', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_reset_pw', 'admin_reset_pw', 'Reset Password Worker', 'PLATFORM', NULL, '0', 'false', 'KeyRound', '997', 'true', '2026-09-06 13:29:00.313317+00'::timestamptz, '/admin/reset-password', 'ResetPassword', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_mfa', 'admin_mfa', 'MFA Setup Admin', 'PLATFORM', NULL, '0', 'false', 'Lock', '996', 'true', '2026-09-06 13:29:00.313317+00'::timestamptz, '/admin/mfa', 'MfaSetup', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_chain', 'admin_chain', 'Audit Chain', 'GOVERNANCE', NULL, '0', 'false', 'Link', '331', 'true', '2026-09-06 13:29:00.313317+00'::timestamptz, '/admin/chain', 'AuditChainPage', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_incentive', 'admin_incentive', 'Incentive Calc', 'CORE', NULL, '0', 'false', 'Coins', '62', 'true', '2026-09-06 13:29:00.313317+00'::timestamptz, '/admin/incentive', 'IncentiveCalc', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_okr', 'admin_okr', 'OKR Management', 'CORE', NULL, '0', 'false', 'Target', '63', 'true', '2026-09-06 13:29:00.313317+00'::timestamptz, '/admin/okr', 'Okrs', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_shift_swap', 'admin_shift_swap', 'Shift Swap', 'CORE', NULL, '0', 'false', 'ArrowLeftRight', '315', 'true', '2026-09-06 13:29:00.313317+00'::timestamptz, '/admin/shift-swap', 'ShiftSchedule', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_requests', 'admin_requests', 'Daftar Pengajuan', 'PLATFORM', NULL, '0', 'false', 'Inbox', '321', 'true', '2026-09-06 13:29:00.313317+00'::timestamptz, '/admin/requests', 'RequestsList', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_pipeline', 'admin_pipeline', 'Pipeline Kanban', 'CORE', NULL, '0', 'false', 'Columns', '112', 'true', '2026-09-06 13:29:00.313317+00'::timestamptz, '/admin/pipeline', 'PipelineKanban', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_screening', 'admin_screening', 'Screening', 'CORE', NULL, '0', 'false', 'Search', '113', 'true', '2026-09-06 13:29:00.313317+00'::timestamptz, '/admin/screening', 'ScreeningPage', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_approval_wf', 'admin_approval_wf', 'Approval Workflow', 'PLATFORM', NULL, '0', 'false', 'GitPullRequest', '322', 'true', '2026-09-06 13:29:00.313317+00'::timestamptz, '/admin/approval-workflow', 'ApprovalWorkflow', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_review360', 'admin_review360', 'Review 360', 'CORE', NULL, '0', 'false', 'Users', '86', 'true', '2026-09-06 13:29:00.313317+00'::timestamptz, '/admin/review-360', 'Review360', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_mining', 'admin_mining', 'Mining Dashboard', 'INDUSTRY', NULL, '0', 'true', 'HardHat', '501', 'true', '2026-09-06 13:29:00.515376+00'::timestamptz, '/admin/mining', 'MiningAdminDashboard', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_estate', 'admin_estate', 'Estate Dashboard', 'INDUSTRY', NULL, '0', 'true', 'TreePine', '601', 'true', '2026-09-06 13:29:00.515376+00'::timestamptz, '/admin/estate', 'EstateAdminDashboard', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_mill', 'admin_mill', 'Mill Dashboard', 'INDUSTRY', NULL, '0', 'true', 'Factory', '701', 'true', '2026-09-06 13:29:00.515376+00'::timestamptz, '/admin/mill', 'MillAdminDashboard', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_career', 'career_admin', 'Career Development', 'PLATFORM', 'Karir & pengembangan karyawan', '0', 'false', 'TrendingUp', '216', 'true', '2026-09-07 16:53:42.100381+00'::timestamptz, '/admin/career', 'CareerDevelopment', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('worker_kpi', 'kpi_worker', 'KPI Saya', 'CORE', 'KPI & performa individu', '0', 'false', 'Target', '70', 'true', '2026-09-07 16:53:42.100381+00'::timestamptz, '/worker/kpi', 'WorkerKpi', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('worker_activities', 'activities', 'Aktivitas', 'CORE', 'Log aktivitas workforce', '0', 'false', 'Activity', '71', 'true', '2026-09-07 16:53:42.100381+00'::timestamptz, '/worker/activities', 'WorkerActivities', 'worker');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('4f6a927e-8593-4ed9-8aee-816b83e2713e', 'career-path', 'career path', 'PLATFORM', NULL, '0', 'false', NULL, '0', 'true', '2026-09-11 15:11:32.702162+00'::timestamptz, '/admin/career-path', 'CareerPathPage', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('9fe90c7a-bf28-4517-b326-6c350a74553e', 'approval-center', 'approval center', 'PLATFORM', NULL, '0', 'false', NULL, '0', 'true', '2026-09-11 16:06:51.970079+00'::timestamptz, '/admin/approval-center', 'ApprovalCenter', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('067894c7-31f5-46bf-a685-3015d6baad8b', 'audit-chain', 'audit chain', 'PLATFORM', NULL, '0', 'false', NULL, '0', 'true', '2026-09-11 16:06:57.397672+00'::timestamptz, '/admin/audit-chain', 'AuditChainPage', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('cb187266-e4e9-443c-86ef-df94b7b6c4a2', 'audit-log', 'audit log', 'PLATFORM', NULL, '0', 'false', NULL, '0', 'true', '2026-09-11 16:06:56.986543+00'::timestamptz, '/admin/audit-log', 'AuditLog', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('9bf64a77-577a-4285-8aae-fe711666eb77', 'career-dev', 'career dev', 'PLATFORM', NULL, '0', 'false', NULL, '0', 'true', '2026-09-11 16:06:54.533845+00'::timestamptz, '/admin/career-dev', 'CareerDevelopment', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('f75a2054-f694-491b-8891-e79a682dbd6a', 'master-data', 'master data', 'PLATFORM', NULL, '0', 'false', NULL, '0', 'true', '2026-09-11 16:06:50.024648+00'::timestamptz, '/admin/master-data', 'MasterDataPage', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_landing', 'admin_landing', 'Admin Home', 'PLATFORM', NULL, '0', 'false', 'LayoutDashboard', '5', 'true', '2026-09-06 13:29:00.313317+00'::timestamptz, '/admin', NULL, 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_estate_harvest', 'EST_HARVEST_ADM', 'Estate Harvest', 'INDUSTRY', 'Harvest records for estate admin', '0', 'false', '??', '1', 'true', '2026-09-13 09:58:31.231611+00'::timestamptz, '/admin/estate/harvest', 'HarvestRecord', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_estate_blocks', 'EST_BLOCK_ADM', 'Estate Blocks', 'INDUSTRY', 'Block management for estate admin', '0', 'false', '???', '2', 'true', '2026-09-13 09:58:31.231611+00'::timestamptz, '/admin/estate/blocks', 'BlockManagement', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_estate_transport', 'EST_TRANSPORT_ADM', 'Estate Transport', 'INDUSTRY', 'Transport TBS for estate admin', '0', 'false', '??', '3', 'true', '2026-09-13 09:58:31.231611+00'::timestamptz, '/admin/estate/transport', 'TransportTBS', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_estate_nursery', 'EST_NURSERY_ADM', 'Estate Nursery', 'INDUSTRY', 'Nursery management for estate admin', '0', 'false', '??', '4', 'true', '2026-09-13 09:58:31.231611+00'::timestamptz, '/admin/estate/nursery', 'NurseryPage', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_estate_irrigation', 'EST_IRRIGATION_ADM', 'Estate Irrigation', 'INDUSTRY', 'Irrigation system for estate admin', '0', 'false', '??', '5', 'true', '2026-09-13 09:58:31.231611+00'::timestamptz, '/admin/estate/irrigation', 'IrrigationPage', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_estate_facility', 'EST_FACILITY_ADM', 'Estate Facility', 'INDUSTRY', 'Facility requests for estate admin', '0', 'false', '???', '6', 'true', '2026-09-13 09:58:31.231611+00'::timestamptz, '/admin/estate/facility', 'FacilityRequest', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_estate_medical', 'EST_MEDICAL_ADM', 'Estate Medical', 'INDUSTRY', 'Medical checkup for estate admin', '0', 'false', '??', '7', 'true', '2026-09-13 09:58:31.231611+00'::timestamptz, '/admin/estate/medical', 'MedicalCheckup', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_mining_simper', 'MINE_SIMPER_ADM', 'Mining SIMPER', 'INDUSTRY', 'SIMPER for mining admin', '0', 'false', '??', '1', 'true', '2026-09-13 09:59:31.775914+00'::timestamptz, '/admin/mining/simper', 'SimperPage', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_mining_heavy', 'MINE_HEAVY_ADM', 'Mining Heavy Equip', 'INDUSTRY', 'Heavy equipment for mining admin', '0', 'false', '??', '2', 'true', '2026-09-13 09:59:31.775914+00'::timestamptz, '/admin/mining/heavy-equip', 'HeavyEquipment', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_mining_fatigue', 'MINE_FATIGUE_ADM', 'Mining Fatigue', 'INDUSTRY', 'Fatigue monitor for mining admin', '0', 'false', '??', '3', 'true', '2026-09-13 09:59:31.775914+00'::timestamptz, '/admin/mining/fatigue', 'FatigueMonitor', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_mining_production', 'MINE_PROD_ADM', 'Mining Production', 'INDUSTRY', 'Production daily for mining admin', '0', 'false', '??', '4', 'true', '2026-09-13 09:59:31.775914+00'::timestamptz, '/admin/mining/production', 'ProductionDaily', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_mining_safety', 'MINE_SAFETY_ADM', 'Mining Safety K3', 'INDUSTRY', 'Safety K3 for mining admin', '0', 'false', '???', '5', 'true', '2026-09-13 09:59:31.775914+00'::timestamptz, '/admin/mining/safety', 'SafetyK3', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_mining_emergency', 'MINE_EMERGENCY_ADM', 'Mining Emergency', 'INDUSTRY', 'Emergency procedures for mining admin', '0', 'false', '??', '6', 'true', '2026-09-13 09:59:31.775914+00'::timestamptz, '/admin/mining/emergency', 'EmergencyProcedures', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_mining_jsa', 'MINE_JSA_ADM', 'Mining JSA', 'INDUSTRY', 'Job Safety Analysis for mining admin', '0', 'false', '??', '7', 'true', '2026-09-13 09:59:31.775914+00'::timestamptz, '/admin/mining/jsa', 'JobSafetyAnalysis', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_mill_boiler', 'MILL_BOILER_ADM', 'Mill Boiler', 'INDUSTRY', 'Pemantauan Boiler PKS (admin)', '0', 'false', '????', '1', 'true', '2026-09-13 10:08:25.70684+00'::timestamptz, '/admin/mill/boiler', 'BoilerMonitor', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_mill_press', 'MILL_PRESS_ADM', 'Mill Mesin Press', 'INDUSTRY', 'Mesin Press & Pemipahan (admin)', '0', 'false', '??????', '2', 'true', '2026-09-13 10:08:25.70684+00'::timestamptz, '/admin/mill/machines', 'MesinPress', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_mill_qc', 'MILL_QC_ADM', 'Mill QC Lab', 'INDUSTRY', 'QC Lab (admin)', '0', 'false', '????', '3', 'true', '2026-09-13 10:08:25.70684+00'::timestamptz, '/admin/mill/qc', 'QcLab', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_mill_packing', 'MILL_PACKING_ADM', 'Mill Packing', 'INDUSTRY', 'Packing Log (admin)', '0', 'false', '????', '4', 'true', '2026-09-13 10:08:25.70684+00'::timestamptz, '/admin/mill/packing', 'PackingLog', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_mill_maint', 'MILL_MAINT_ADM', 'Mill Maintenance', 'INDUSTRY', 'Preventive Maintenance (admin)', '0', 'false', '????', '5', 'true', '2026-09-13 10:08:25.70684+00'::timestamptz, '/admin/mill/maintenance', 'PreventiveMaintenance', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_mill_breakdown', 'MILL_BREAKDOWN_ADM', 'Mill Breakdown', 'INDUSTRY', 'Breakdown Log (admin)', '0', 'false', '????', '6', 'true', '2026-09-13 10:08:25.70684+00'::timestamptz, '/admin/mill/breakdown', 'BreakdownLog', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('admin_mill_shift', 'MILL_SHIFT_ADM', 'Mill Shift', 'INDUSTRY', 'Jadwal Shift Pabrik (admin)', '0', 'false', '????', '7', 'true', '2026-09-13 10:10:41.296155+00'::timestamptz, '/admin/mill/shift', 'MillShiftSchedule', 'admin');
  INSERT INTO public.module_definitions (id, module_code, module_name, module_group, description, minimum_tier_required, is_industry_module, menu_icon, menu_order, is_active, created_at, route_path, route_component, route_group) VALUES ('dashboard_landing', 'dashboard_landing', 'CEO Dashboard', 'INTELLIGENCE', NULL, '0', 'false', 'Layout', '201', 'false', '2026-09-06 13:29:00.313317+00'::timestamptz, '/dashboard', 'Dashboard', 'admin');
END $$;

-- ── config_categories (10 baris) ──
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.config_categories LIMIT 1) THEN
    RAISE NOTICE 'config_categories sudah berisi data — dilewati';
    RETURN;
  END IF;
  INSERT INTO public.config_categories (id, name, description, icon, sort_order) VALUES ('kpi', 'KPI & Performance', 'Threshold, bobot, band nilai', '📊', '1');
  INSERT INTO public.config_categories (id, name, description, icon, sort_order) VALUES ('salary', 'Gaji & Compensation', 'Salary bands, tunjangan, formula', '💰', '2');
  INSERT INTO public.config_categories (id, name, description, icon, sort_order) VALUES ('attendance', 'Absensi & Shift', 'Jam kerja, grace period, shift', '⏰', '3');
  INSERT INTO public.config_categories (id, name, description, icon, sort_order) VALUES ('leave', 'Cuti & Benefit', 'Kuota cuti, jenis cuti, benefit', '📅', '4');
  INSERT INTO public.config_categories (id, name, description, icon, sort_order) VALUES ('security', 'Keamanan', 'Lockout, OTP, password policy', '🔒', '5');
  INSERT INTO public.config_categories (id, name, description, icon, sort_order) VALUES ('approval', 'Approval Workflow', 'Chain approval, level', '✅', '6');
  INSERT INTO public.config_categories (id, name, description, icon, sort_order) VALUES ('industry', 'Industri', 'Status, threshold spesifik industri', '🏭', '7');
  INSERT INTO public.config_categories (id, name, description, icon, sort_order) VALUES ('scoring', 'Scoring & Formula', 'Bobot penilaian, rumus', '🧮', '8');
  INSERT INTO public.config_categories (id, name, description, icon, sort_order) VALUES ('display', 'Tampilan & Label', 'Label, warna, threshold UI', '🎨', '9');
  INSERT INTO public.config_categories (id, name, description, icon, sort_order) VALUES ('currency', 'Mata Uang & Rate', 'Exchange rate, format', '💱', '10');
END $$;

-- company_config: 2 baris identitas perusahaan TIDAK didump (owner_email, ceo_email)
--   → diisi oleh installer (--owner-email=...) atau OwnerDashboard.

-- ── company_config (82 baris) ──
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.company_config LIMIT 1) THEN
    RAISE NOTICE 'company_config sudah berisi data — dilewati';
    RETURN;
  END IF;
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('bbfe4d15-8244-4b68-a07b-027ce8e481a0', 'kpi', 'kpi_high_threshold', '{"value": 80}'::jsonb, 'number', 'KPI High Threshold', 'KPI score minimum untuk kategori High Performer', 50, 100, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('73ffa15e-581d-4244-a162-930a655b52d2', 'kpi', 'kpi_medium_threshold', '{"value": 60}'::jsonb, 'number', 'KPI Medium Threshold', 'KPI score minimum untuk kategori Medium', 30, 100, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('1c113f5e-8410-489f-89d4-d5dcb10a63a5', 'kpi', 'kpi_low_threshold', '{"value": 40}'::jsonb, 'number', 'KPI Low Threshold', 'KPI score minimum untuk kategori Low', 0, 100, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('ce47dfe8-b2ce-4ef6-8e17-cffaec6a0e38', 'kpi', 'flight_risk_kpi_threshold', '{"value": 70}'::jsonb, 'number', 'Flight Risk KPI', 'KPI di bawah ini = flight risk', 30, 100, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('53e7fb5f-fe6e-4b3b-9851-c5f4eb6b8503', 'kpi', 'flight_risk_late_threshold', '{"value": 5}'::jsonb, 'number', 'Flight Risk Late Count', 'Jumlah telat sebelum flight risk', 1, 30, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('fbe42d7e-77bc-4d4e-ae0f-dba9f0a9f0ed', 'kpi', 'badge_gold', '{"value": 85}'::jsonb, 'number', 'Badge Gold', 'KPI minimum untuk badge Gold', 50, 100, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('25f3452a-0a59-42c3-898b-16bf48343ddd', 'kpi', 'badge_silver', '{"value": 75}'::jsonb, 'number', 'Badge Silver', 'KPI minimum untuk badge Silver', 50, 100, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('87f30e8e-03fc-46a9-83d8-5c8d62f24ecc', 'kpi', 'badge_bronze', '{"value": 60}'::jsonb, 'number', 'Badge Bronze', 'KPI minimum untuk badge Bronze', 0, 100, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('3e3f339f-4c5c-4390-ae02-89e5f96fb31e', 'kpi', 'nps_promoter', '{"value": 9}'::jsonb, 'number', 'NPS Promoter', 'NPS score minimum untuk Promoter', 0, 10, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('6176c32f-61c2-4bda-917d-ff99e267bf7c', 'kpi', 'nps_detractor', '{"value": 6}'::jsonb, 'number', 'NPS Detractor', 'NPS score maksimum untuk Detractor', 0, 10, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('2fef67e3-ea7e-4aa7-9fa7-d212b3d01edc', 'scoring', 'performance_weights', '{"kpi": 0.4, "attitude": 0.05, "attendance": 0.3, "initiative": 0.05, "productivity": 0.2}'::jsonb, 'json', 'Performance Weights', 'Bobot komponen penilaian kinerja (total = 1.0)', NULL, NULL, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('34c3c7f6-202c-44bf-a093-b3ea9d4fdae3', 'scoring', 'health_score_defaults', '{"kpi": 70, "attendance": 90, "engagement": 75}'::jsonb, 'json', 'Health Score Defaults', 'Default values saat tidak ada data', NULL, NULL, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('869c4327-05bd-40d8-9a60-a661cfa6aa73', 'scoring', 'flight_risk_weights', '{"sp": 0.3, "kpi": 0.3, "lateness": 0.4}'::jsonb, 'json', 'Flight Risk Weights', 'Bobot komponen flight risk score', NULL, NULL, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('c82891eb-2415-48c1-991a-baf53867ceb0', 'scoring', 'engagement_highly_engaged', '{"value": 80}'::jsonb, 'number', 'Highly Engaged Threshold', 'Score minimum untuk Highly Engaged', 50, 100, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('e1f6f204-b9c2-4b55-b2b3-228a0f52eb44', 'scoring', 'engagement_engaged', '{"value": 60}'::jsonb, 'number', 'Engaged Threshold', 'Score minimum untuk Engaged', 0, 100, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('fb607051-134f-4cea-8561-5cb2b3b24e7a', 'scoring', 'review360_green', '{"value": 70}'::jsonb, 'number', 'Review 360 Green', 'Score minimum untuk warna hijau', 0, 100, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('1d690d7d-447e-409a-9212-5f1e5c91d47f', 'scoring', 'review360_yellow', '{"value": 50}'::jsonb, 'number', 'Review 360 Yellow', 'Score minimum untuk warna kuning', 0, 100, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('48753d21-e873-43f2-9975-daade99f1d46', 'scoring', 'turnover_risk_red', '{"value": 70}'::jsonb, 'number', 'Turnover Risk Red', 'Score di atas ini = risiko tinggi', 0, 100, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('d7938bcc-c769-4052-b85a-5f3f9a97c3f1', 'scoring', 'turnover_risk_yellow', '{"value": 40}'::jsonb, 'number', 'Turnover Risk Yellow', 'Score di atas ini = risiko sedang', 0, 100, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('e86e2448-6347-44be-9a31-482a0e383b55', 'scoring', 'penalty_matrix', '{"LOW": 1, "HIGH": 5, "MEDIUM": 3, "CRITICAL": 10}'::jsonb, 'json', 'Penalty Matrix', 'Poin penalti per tingkat keparahan', NULL, NULL, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('9607aadb-dfa8-4c6a-aed9-6b474f803269', 'salary', 'salary_bands', '{"L1": 7000000, "L2": 8000000, "L3": 12000000, "L4": 18000000, "L5": 25000000}'::jsonb, 'json', 'Salary Bands per Level', 'Gaji pokok per level (IDR)', NULL, NULL, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('cbba403f-0994-49ec-aa12-d3b0afb3425b', 'salary', 'currency_default', '{"value": "IDR"}'::jsonb, 'string', 'Default Currency', 'Mata uang default', NULL, NULL, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('b61f5918-6ff5-4c6d-a55c-450348d101e3', 'salary', 'exchange_rates', '{"AUD": 10200, "MYR": 3600, "SGD": 11800, "USD": 15800}'::jsonb, 'json', 'Exchange Rates', 'Kurs terhadap IDR', NULL, NULL, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('822027f7-5f30-4f46-9e6f-8f562c387354', 'salary', 'overtime_rate_multiplier', '{"value": 1.5}'::jsonb, 'number', 'Overtime Rate Multiplier', 'Pengali upah lembur', 1, 3, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('c0cc660b-38f0-4b0d-9989-340ae62fb55d', 'salary', 'holiday_rate_multiplier', '{"value": 2.0}'::jsonb, 'number', 'Holiday Rate Multiplier', 'Pengali upah hari libur', 1, 4, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('13c719dd-11cf-4148-8ca8-52d01cbeca31', 'attendance', 'work_hours_per_day', '{"value": 480}'::jsonb, 'number', 'Work Hours Per Day', 'Jam kerja standar (menit)', 240, 720, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('7054914e-07ae-4031-9ea8-79a5cc70aaf5', 'attendance', 'grace_period_minutes', '{"value": 10}'::jsonb, 'number', 'Grace Period', 'Toleransi keterlambatan (menit)', 0, 60, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('7a6de4d0-2969-43e4-9cd7-b4a867ea5e4d', 'attendance', 'work_days_per_week', '{"value": 5}'::jsonb, 'number', 'Work Days Per Week', 'Hari kerja per minggu', 1, 7, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('dbea22a0-01ed-4c5a-96ef-ad7196809215', 'attendance', 'shift_types', '{"value": ["PAGI", "SORE", "MALAM"]}'::jsonb, 'array', 'Shift Types', 'Jenis shift yang tersedia', NULL, NULL, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('5c993c8f-5cc2-492e-92da-f0736b32fc1f', 'attendance', 'attendance_statuses', '{"value": ["Hadir", "Telat", "Izin", "Sakit", "Alpha", "Cuti", "WFH", "Dinas Luar"]}'::jsonb, 'array', 'Attendance Statuses', 'Status kehadiran yang diizinkan', NULL, NULL, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('a2aa9a4f-8156-46e2-ac9c-06cff5cdcf62', 'leave', 'annual_leave_quota', '{"value": 12}'::jsonb, 'number', 'Annual Leave Quota', 'Kuota cuti tahunan (hari)', 0, 30, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('f202c1ec-7a27-40c0-91ed-1ff8c88314db', 'leave', 'sick_leave_quota', '{"value": 12}'::jsonb, 'number', 'Sick Leave Quota', 'Kuota cuti sakit (hari)', 0, 30, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('54a44342-1b45-4125-9a7b-ddcfc26ff733', 'leave', 'maternity_leave_quota', '{"value": 90}'::jsonb, 'number', 'Maternity Leave Quota', 'Kuota cuti melahirkan (hari)', 0, 180, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('75bcd0db-b879-4ed6-8dcc-d36b74cf166b', 'leave', 'leave_types', '{"value": ["Cuti Tahunan", "Cuti Sakit", "Cuti Melahirkan", "Izin Dinas", "Cuti Besar", "Cuti Penting"]}'::jsonb, 'array', 'Leave Types', 'Jenis cuti yang tersedia', NULL, NULL, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('cfc36caa-45a7-4f21-9ec3-8ecc8f0d008f', 'leave', 'benefit_types', '{"value": ["BPJS-KES", "BPJS-TK", "THP", "JHT", "JP", "Tunjangan Makan", "Tunjangan Transport"]}'::jsonb, 'array', 'Benefit Types', 'Jenis benefit karyawan', NULL, NULL, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('9db17ee6-d304-4261-bcb0-a59eded78fae', 'security', 'login_lockout_attempts', '{"value": 4}'::jsonb, 'number', 'Login Lockout Attempts', 'Jumlah gagal login sebelum lockout', 3, 10, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('4cf14902-5a40-442c-b003-f919b18c306f', 'security', 'login_lockout_duration_minutes', '{"value": 15}'::jsonb, 'number', 'Login Lockout Duration', 'Durasi lockout (menit)', 5, 1440, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('cbb9025f-eb9a-433c-bc40-01635e90e19b', 'security', 'otp_lockout_attempts', '{"value": 5}'::jsonb, 'number', 'OTP Lockout Attempts', 'Jumlah gagal OTP sebelum lockout', 3, 10, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('66bc67ae-d680-4423-9fce-6ce3fa126238', 'security', 'severe_lockout_attempts', '{"value": 10}'::jsonb, 'number', 'Severe Lockout Attempts', 'Jumlah gagal berat sebelum lockout lama', 5, 20, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('57fa8e21-523c-446f-ae63-e3425cdc7205', 'security', 'severe_lockout_duration_minutes', '{"value": 60}'::jsonb, 'number', 'Severe Lockout Duration', 'Durasi lockout berat (menit)', 15, 1440, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('33007878-0541-487e-9be9-2f8b2622446c', 'security', 'token_expiry_hours', '{"value": 24}'::jsonb, 'number', 'Token Expiry', 'Masa aktif token (jam)', 1, 168, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('534a91fd-9dc8-4f41-9253-416b2a4be3bf', 'security', 'cleanup_old_attempts_days', '{"value": 7}'::jsonb, 'number', 'Cleanup Attempts', 'Hapus data login gagal setelah (hari)', 1, 90, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('751c9509-3533-4fc7-9cfc-ae503ef6579b', 'industry', 'boiler_statuses', '{"value": ["RUNNING", "STANDBY", "MAINTENANCE", "OFFLINE"]}'::jsonb, 'array', 'Boiler Statuses', 'Status boiler yang diizinkan', NULL, NULL, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('6b392eb4-cc1f-4a45-ac03-a2c5cf20fd0f', 'industry', 'press_statuses', '{"value": ["RUNNING", "STANDBY", "MAINTENANCE", "OFFLINE"]}'::jsonb, 'array', 'Press Statuses', 'Status press yang diizinkan', NULL, NULL, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('baaf2440-aeab-41b7-8926-9941ce82aa88', 'industry', 'qc_result_statuses', '{"value": ["PASS", "REVIEW", "REJECT"]}'::jsonb, 'array', 'QC Result Statuses', 'Status hasil QC', NULL, NULL, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('6b43ea1a-0bad-4592-ad67-2a11fbc1eb14', 'industry', 'product_types', '{"value": ["CPO", "PK", "PKS", "OIL"]}'::jsonb, 'array', 'Product Types', 'Jenis produk sawit', NULL, NULL, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('6e4f864b-3fbe-4aa5-8132-937802f356ac', 'industry', 'packing_statuses', '{"value": ["PACKED", "LOADED", "DISPATCHED"]}'::jsonb, 'array', 'Packing Statuses', 'Status packing', NULL, NULL, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('f645a686-a7b1-4dd7-b45a-59033ca8839b', 'industry', 'maintenance_types', '{"value": ["PREVENTIVE", "PREDICTIVE", "CORRECTIVE"]}'::jsonb, 'array', 'Maintenance Types', 'Jenis maintenance', NULL, NULL, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('3efc8294-ee08-46fa-b084-b0e2e567c3ad', 'industry', 'maintenance_statuses', '{"value": ["SCHEDULED", "IN_PROGRESS", "COMPLETED", "OVERDUE"]}'::jsonb, 'array', 'Maintenance Statuses', 'Status maintenance', NULL, NULL, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('937dc877-f46e-4954-9daa-0a0bbde7783b', 'industry', 'breakdown_severities', '{"value": ["LOW", "MEDIUM", "HIGH", "CRITICAL"]}'::jsonb, 'array', 'Breakdown Severities', 'Tingkat keparahan breakdown', NULL, NULL, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('58ea0836-3927-4495-8e4a-35fce8fc833f', 'industry', 'breakdown_categories', '{"value": ["MECHANICAL", "ELECTRICAL", "INSTRUMENT", "PROCESS", "SAFETY"]}'::jsonb, 'array', 'Breakdown Categories', 'Kategori breakdown', NULL, NULL, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('d5e8d21d-5615-41f3-807a-c7c2a55e4964', 'industry', 'harvest_quality_grades', '{"value": ["A", "B", "C"]}'::jsonb, 'array', 'Harvest Quality Grades', 'Grade kualitas panen', NULL, NULL, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('ae7f26df-2457-43b1-9c14-8090de39dd79', 'display', 'kpi_color_bands', '{"teal": 60, "green": 80, "orange": 40}'::jsonb, 'json', 'KPI Color Bands', 'Threshold warna KPI di UI', NULL, NULL, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('5ab0ee11-c1ca-475c-8a0f-529ef1a35a7c', 'display', 'kpi_labels_id', '{"good": "Baik", "at_risk": "Perlu Perbaikan", "excellent": "Sangat Baik", "needs_improvement": "Cukup"}'::jsonb, 'json', 'KPI Labels (ID)', 'Label KPI Bahasa Indonesia', NULL, NULL, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('61aa0b56-087a-4f06-ade5-9adbbb1e8e0d', 'display', 'kpi_labels_en', '{"good": "Good", "at_risk": "At Risk", "excellent": "Excellent", "needs_improvement": "Needs Improvement"}'::jsonb, 'json', 'KPI Labels (EN)', 'KPI Labels English', NULL, NULL, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('0206974e-758a-4f88-8394-864462fa7845', 'approval', 'leave_approval_chain', '{"chain": ["atasan_langsung", "hr_manager"], "max_level": 2}'::jsonb, 'json', 'Leave Approval Chain', 'Approval chain untuk cuti', NULL, NULL, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('343e14b2-d0e4-4433-a490-41212fbd67de', 'approval', 'overtime_approval_chain', '{"chain": ["atasan_langsung"], "max_level": 1}'::jsonb, 'json', 'Overtime Approval Chain', 'Approval chain untuk lembur', NULL, NULL, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('bff5c49d-23ee-4b2e-9268-ffc5d866e480', 'approval', 'training_approval_chain', '{"chain": ["atasan_langsung", "hr_manager", "director"], "max_level": 3}'::jsonb, 'json', 'Training Approval Chain', 'Approval chain untuk training', NULL, NULL, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('4e8328c9-89b7-408b-b7dd-7c9687ff1867', 'industry', 'competency_levels', '{"value": ["Staff", "Senior", "Supervisor", "Manager", "Director"]}'::jsonb, 'array', 'Competency Levels', 'Level kompetensi', NULL, NULL, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('3336a699-8557-4999-b18f-1174db1c63a2', 'industry', 'succession_readiness', '{"value": [{"label": "Ready Now", "months": 3}, {"label": "Ready Soon", "months": 6}, {"label": "Future Ready", "months": 12}, {"label": "Not Ready", "months": 99}]}'::jsonb, 'array', 'Succession Readiness', 'Tingkat kesiapan suksesi', NULL, NULL, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('1943307c-6cb4-4441-a0cb-132509e7d66e', 'industry', 'fatigue_levels', '{"value": [1, 2, 3, 4, 5]}'::jsonb, 'array', 'Fatigue Levels', 'Level kelelahan', NULL, NULL, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('4b6e2bc3-2c2a-4444-835b-08831bca66af', 'industry', 'training_types', '{"value": ["SAFETY", "TECHNICAL", "SOFT_SKILL", "LEADERSHIP", "COMPLIANCE"]}'::jsonb, 'array', 'Training Types', 'Jenis pelatihan', NULL, NULL, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('fdfbc727-2303-4bc9-8c4c-002026498985', 'industry', 'training_priorities', '{"value": ["HIGH", "NORMAL", "LOW"]}'::jsonb, 'array', 'Training Priorities', 'Prioritas pelatihan', NULL, NULL, NULL, 'false', '2026-09-03 05:09:23.29477+00'::timestamptz, '2026-09-03 05:09:23.29477+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('fbbd77cc-3fa7-4a80-85a6-dbdac3b3bbe1', 'security', 'audit_log_retention_days', '{"value": 90}'::jsonb, 'number', 'Audit Log Retention', 'Hapus audit log lebih dari X hari. 0 = tidak ada auto-cleanup.', 0, 365, NULL, 'false', '2026-09-05 01:17:03.145361+00'::timestamptz, '2026-09-05 01:17:03.145361+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('c95e901c-cde7-4d00-b9d7-c12368168f59', 'security', 'ai_rate_limit_retention_days', '{"value": 30}'::jsonb, 'number', 'AI Rate Limit Retention', 'Hapus data rate limit lebih dari X hari.', 1, 90, NULL, 'false', '2026-09-05 01:17:03.145361+00'::timestamptz, '2026-09-05 01:17:03.145361+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('4a626770-05a8-493f-aaee-2b280e970018', 'security', 'session_retention_days', '{"value": 7}'::jsonb, 'number', 'Session Retention', 'Hapus session token expired setelah X hari.', 1, 30, NULL, 'false', '2026-09-05 01:17:03.145361+00'::timestamptz, '2026-09-05 01:17:03.145361+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('5f2c98da-e9f2-428c-b310-d05ffc52279e', 'security', 'login_attempt_retention_days', '{"value": 14}'::jsonb, 'number', 'Login Attempt Retention', 'Hapus data login gagal setelah X hari.', 1, 90, NULL, 'false', '2026-09-05 01:17:03.145361+00'::timestamptz, '2026-09-05 01:17:03.145361+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('b093d970-6919-4a08-8f01-cec7060b8b37', 'security', 'encryption_key', '{"value": "J8ouphvkzzob2Um5i8lmqcdb10+EwKXLjAFx2n8jZMo="}'::jsonb, 'string', 'Encryption Key for PII', 'Gunakan untuk enkripsi NIK/NPWP. JANGAN ubah setelah data terenkripsi!', NULL, NULL, NULL, 'false', '2026-09-05 01:36:13.702108+00'::timestamptz, '2026-09-05 01:36:13.702108+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('73672064-34f9-479b-9b40-ecb937b740de', 'salary', 'pph21_ter_enabled', '{"value": true}'::jsonb, 'boolean', 'PPh 21 TER Active', 'Aktifkan perhitungan PPh 21 METODE TER', NULL, NULL, NULL, 'false', '2026-09-05 07:12:25.09844+00'::timestamptz, '2026-09-05 07:12:25.09844+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('4bd92f6f-bb7f-4788-8e25-4a41e30fa95a', 'salary', 'pph21_ter_brackets', '{"single": {"0": 0, "5400000": 5, "10000000": 10, "15000000": 15, "20000000": 25, "30000000": 30, "50000000": 35}, "married_factor": 1.5}'::jsonb, 'json', 'PPh 21 TER Brackets', 'Tarif PPh 21 berdasarkan penghasilan bruto per bulan', NULL, NULL, NULL, 'false', '2026-09-05 07:12:25.09844+00'::timestamptz, '2026-09-05 07:12:25.09844+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('3b4e34ec-5e69-4960-b1ae-113e1ce9fe69', 'salary', 'tapera_enabled', '{"value": false}'::jsonb, 'boolean', 'Tapera Active', 'Aktifkan potongan Tapera (PP 21/2024)', NULL, NULL, NULL, 'false', '2026-09-05 07:12:25.09844+00'::timestamptz, '2026-09-05 07:12:25.09844+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('a976987c-7375-4844-9fd8-352dac1d1c65', 'salary', 'tapera_employee_rate', '{"value": 0.5}'::jsonb, 'number', 'Tapera Employee Rate', 'Potongan Tapera karyawan (%)', 0, 10, NULL, 'false', '2026-09-05 07:12:25.09844+00'::timestamptz, '2026-09-05 07:12:25.09844+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('270ac9ac-6f72-43c4-8b64-5191452616d1', 'salary', 'tapera_employer_rate', '{"value": 2.5}'::jsonb, 'number', 'Tapera Employer Rate', 'Iuran Tapera perusahaan (%)', 0, 10, NULL, 'false', '2026-09-05 07:12:25.09844+00'::timestamptz, '2026-09-05 07:12:25.09844+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('050f6297-e7cd-4bd9-b5d8-65b610c336ef', 'salary', 'bpjs_jht_enabled', '{"value": true}'::jsonb, 'boolean', 'BPJS JHT Active', 'Aktifkan Jaminan Hari Tua', NULL, NULL, NULL, 'false', '2026-09-05 07:12:25.09844+00'::timestamptz, '2026-09-05 07:12:25.09844+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('5f61111d-f16e-42f6-bcf0-dcc9a3b8eba8', 'salary', 'bpjs_jht_rate', '{"employee": 2, "employer": 3.7}'::jsonb, 'json', 'BPJS JHT Rate', 'JHT: Karyawan 2% + Perusahaan 3.7%', NULL, NULL, NULL, 'false', '2026-09-05 07:12:25.09844+00'::timestamptz, '2026-09-05 07:12:25.09844+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('e456cd44-6e49-47ce-8a0a-e4d10e739938', 'salary', 'bpjs_jp_rate', '{"employee": 1, "employer": 2}'::jsonb, 'json', 'BPJS JP Rate', 'JP: Karyawan 1% + Perusahaan 2%', NULL, NULL, NULL, 'false', '2026-09-05 07:12:25.09844+00'::timestamptz, '2026-09-05 07:12:25.09844+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('65578109-b4a0-41e0-aa20-1f86d600d88f', 'salary', 'bpjs_jkk_rate', '{"employer": 1.74}'::jsonb, 'json', 'BPJS JKK Rate', 'Jaminan Kecelakaan Kerja (perusahaan)', NULL, NULL, NULL, 'false', '2026-09-05 07:12:25.09844+00'::timestamptz, '2026-09-05 07:12:25.09844+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('d524bb6c-c9e3-4877-964e-b8100011e31a', 'salary', 'bpjs_jkm_rate', '{"employer": 0.3}'::jsonb, 'json', 'BPJS JKM Rate', 'Jaminan Kematian (perusahaan)', NULL, NULL, NULL, 'false', '2026-09-05 07:12:25.09844+00'::timestamptz, '2026-09-05 07:12:25.09844+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('27a76668-737f-49a4-9f67-aa86c1423307', 'salary', 'bpjs_jkp_rate', '{"employer": 0.2}'::jsonb, 'json', 'BPJS JKP Rate', 'Jaminan Kehilangan Pekerjaan (perusahaan)', NULL, NULL, NULL, 'false', '2026-09-05 07:12:25.09844+00'::timestamptz, '2026-09-05 07:12:25.09844+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('dce5f568-db20-4636-9835-c55585004dd0', 'salary', 'thr_enabled', '{"value": true}'::jsonb, 'boolean', 'THR Active', 'Aktifkan perhitungan THR otomatis', NULL, NULL, NULL, 'false', '2026-09-05 07:12:25.09844+00'::timestamptz, '2026-09-05 07:12:25.09844+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('6073f7ce-94f0-499b-a284-a67ebaa36b23', 'salary', 'thr_rate', '{"value": 1}'::jsonb, 'number', 'THR Rate', 'THR = N x gaji pokok (1 = 1 bulan gaji)', 0, 3, NULL, 'false', '2026-09-05 07:12:25.09844+00'::timestamptz, '2026-09-05 07:12:25.09844+00'::timestamptz);
  INSERT INTO public.company_config (id, category_id, config_key, config_value, data_type, label, description, min_value, max_value, options, is_system, created_at, updated_at) VALUES ('d6323350-cbb4-4993-89e9-9feec0068078', 'salary', 'thr_trigger_months', '{"value": ["12"]}'::jsonb, 'json', 'THR Trigger Months', 'Bulan pencairan THR (12=Desember)', NULL, NULL, NULL, 'false', '2026-09-05 07:12:25.09844+00'::timestamptz, '2026-09-05 07:12:25.09844+00'::timestamptz);
END $$;

-- ── business_unit_modules (61 baris) ──
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.business_unit_modules LIMIT 1) THEN
    RAISE NOTICE 'business_unit_modules sudah berisi data — dilewati';
    RETURN;
  END IF;
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('50b34345-5a54-433c-8f45-e50bf879643e', 'BU04', 'leave', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('cc48a341-329e-4db7-843c-18f92b13eb8e', 'BU04', 'overtime', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('61ae2f98-71be-49c0-9622-f396486c7100', 'BU04', 'payroll', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('930c50d8-1bb7-4f89-8456-8a7388de909a', 'BU04', 'self_service', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('120e6160-eba1-4e36-91f1-67168806e6f7', 'BU04', 'kpi', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('eb4fae9a-8234-420a-bd75-6675f37c8578', 'BU04', 'performance', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('c36cc601-13b2-451c-b191-5d0fb0e8adca', 'BU04', 'learning', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('2d6e6746-6e01-47bd-8857-aa843526e876', 'BU04', '360_review', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('dc251409-9097-49c1-ba06-8467c2878524', 'BU04', 'talent', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('3c376f05-66fc-4dab-9645-85074c7b0d1a', 'BU04', 'career_path', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('c99416a2-82f9-4bbe-8ea6-7cf9b4d42477', 'BU04', 'succession', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('b5a26b33-b17e-4008-b05e-7ccd8161008c', 'BU04', 'recruitment', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('ef669b8a-b1f8-44c6-b08f-02206227d37d', 'BU04', 'onboarding', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('eea479ec-8da9-4e29-9068-87409b4dce81', 'BU04', 'offboarding', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('18af4f9b-8ba2-4b4e-9a53-2dc429423e4d', 'BU04', 'engagement', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('582c052f-5e46-4273-ade7-92bba8fb3af9', 'BU04', 'voice_ideas', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('1e421392-9fb5-4a0b-8c91-8c9b28a32f10', 'BU04', 'badges', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('560ecedb-9b36-4d3f-aad7-d38090e547e3', 'BU04', 'referral', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('54378594-1ce4-4f73-b1be-9b3d993e1fd3', 'BU04', 'ceo_dashboard', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('79128312-c9c6-4233-9297-bb8c353df2ce', 'BU04', 'analytics', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('46a16217-1ea0-4dad-b51c-f22ea88697cd', 'BU04', 'workforce_planning', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('0ccd4302-f899-4dbf-a5c8-ee9d3dfe715b', 'BU04', 'simulation', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('ea5e57fa-e97e-44ba-89ca-f724ecc508c9', 'BU04', 'turnover', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('e7b3b9a7-f73d-41a4-9ff2-89763dca8e38', 'BU04', 'flight_risk', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('f9768df9-2032-4e33-9301-cd3082304c7d', 'BU04', 'narrative', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('74b7e358-50c4-43a1-ba1e-7804a6c858b3', 'BU04', 'org_structure', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('a9a19d0f-e0ec-4afc-a5ba-13f3c2fc3b75', 'BU04', 'divisions', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('1c737f93-033c-4a2a-85fb-d437e54d0223', 'BU04', 'approvals', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('2256e9fa-9968-4f99-9da5-bb59aa16d5ca', 'BU04', 'audit_log', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('75d80a34-38c2-48ae-b42e-22214e2322b7', 'BU04', 'settings', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('75782825-79f6-4634-aeb6-423212b27905', 'BU04', 'export_data', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('eef80a17-e655-4040-9ed3-05e2cf765814', 'BU04', 'announcements', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('ad54c4cc-8e5a-4916-b238-6640b301aca0', 'BU04', 'whistleblowing', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('d815d1ae-2ea3-41c8-9d9b-64960f990f7e', 'BU04', 'mfa', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('ff73b1b6-7800-4441-9a2f-ad508adda9a9', 'BU04', 'module_management', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('6403db79-8522-4bae-9233-6f6090546359', 'BU04', 'safety', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('35b38fe5-ea75-433f-8a47-008366203b49', 'BU04', 'qhse', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('e029f5c0-66e2-4ad8-be20-abdd223cfa44', 'BU04', 'certifications', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('790770ea-7c72-499c-b5eb-3a93266e2cc5', 'BU04', 'mining_simper', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('4f0e4b23-7030-48ce-a798-10e2a0e826b2', 'BU04', 'mining_equipment', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('9d8ac1c5-9b09-44c0-a2df-5f987811b207', 'BU04', 'mining_production', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('97f57abf-6916-4a47-a57b-45e653b9aa26', 'BU04', 'mining_fuel', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('381ad0ee-fcf8-4ff7-b3c9-0e0790eecaf1', 'BU04', 'mining_fatigue', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('d49ddebd-d306-4ed9-bcef-d4d2b7edc8a4', 'BU04', 'mining_safety', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('2ad966ba-3876-4ac8-9f1d-6e4d8090b7b2', 'BU04', 'mining_jsa', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('a73c1b05-9a11-4f18-98c3-f66d963c7023', 'BU04', 'estate_harvest', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('96e42f54-4332-4575-94ba-d63a1fe2f564', 'BU04', 'estate_blocks', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('ac48a184-50f7-4d2d-a9cc-8668777eb348', 'BU04', 'estate_irrigation', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('e730a47f-1d3e-4d56-a2b3-c8671c2a41ba', 'BU04', 'estate_nursery', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('f76ac0df-3101-4f75-8378-32473a1aaa47', 'BU04', 'estate_transport', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('a920dcdd-3379-4f4b-97de-24045db247be', 'BU04', 'estate_field', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('158eff22-1ea1-4767-878a-c59ad20e78e9', 'BU04', 'estate_yield', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('9731cd85-efea-4bb4-8ab6-4723b6510e7d', 'BU04', 'mill_boiler', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('64556e50-bb6b-40ee-88e4-b55b6968d915', 'BU04', 'mill_press', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('5644a49b-0b9a-47a6-8d85-9d5e0d11e8cb', 'BU04', 'mill_qc', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('d90acd8e-7602-4b43-b7a0-22b3fe5cb61c', 'BU04', 'mill_packing', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('a6d22f5e-cb8e-45f9-9ede-f0978136da53', 'BU04', 'mill_maintenance', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('9a1fc113-733f-40c9-af88-155c37991b8b', 'BU04', 'mill_breakdown', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('5f2b57f3-44a7-4695-a029-eb3b339643d7', 'BU04', 'mill_shift', 'true', NULL, NULL, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('4e8091f4-d701-44fd-9952-970ce81cf339', 'BU04', 'attendance', 'true', 'OWNER001', '2026-09-03 04:04:22.014143+00'::timestamptz, '2026-09-03 03:45:48.003651+00'::timestamptz);
  INSERT INTO public.business_unit_modules (id, business_unit_id, module_code, is_enabled, toggled_by, toggled_at, created_at) VALUES ('9f45545a-3a9a-4760-98f2-7680145a5698', 'BU04', 'profile', 'true', 'OWNER001', '2026-09-08 01:45:48.394609+00'::timestamptz, '2026-09-03 03:45:48.003651+00'::timestamptz);
END $$;

-- ── master_divisions (48 baris) ──
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.master_divisions LIMIT 1) THEN
    RAISE NOTICE 'master_divisions sudah berisi data — dilewati';
    RETURN;
  END IF;
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('1', 'CORP', 'Korporat/HQ', NULL, 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('2', 'HRD', 'Human Resources Development', 'CORP', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('3', 'GA', 'General Affairs', 'CORP', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('4', 'FIN', 'Finance', 'CORP', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('5', 'ACC', 'Accounting', 'FIN', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('6', 'TRE', 'Treasury', 'FIN', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('7', 'MKT', 'Marketing', 'CORP', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('8', 'SALES', 'Sales', 'CORP', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('9', 'OPS', 'Operational', 'CORP', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('10', 'PRD', 'Production', 'OPS', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('11', 'QC', 'Quality Control', 'OPS', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('12', 'ENG', 'Engineering', 'OPS', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('13', 'MAINT', 'Maintenance', 'OPS', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('14', 'WHS', 'Warehouse', 'OPS', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('15', 'LOG', 'Logistics', 'OPS', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('16', 'IT', 'Information Technology', 'CORP', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('17', 'SYS', 'System Administration', 'IT', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('18', 'DEV', 'Development', 'IT', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('19', 'SEC', 'Security', 'CORP', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('20', 'HSE', 'Health Safety Environment', 'OPS', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('21', 'LEG', 'Legal', 'CORP', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('22', 'COR', 'Corporate Secretary', 'CORP', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('23', 'ADM', 'Administration', 'CORP', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('24', 'PUR', 'Procurement', 'CORP', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('25', 'QHSE', 'Quality HSE', 'OPS', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('26', 'RND', 'Research & Development', 'CORP', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('27', 'CRM', 'Customer Relations', 'MKT', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('28', 'PRM', 'Public Relations', 'CORP', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('29', 'EDU', 'Education & Training', 'HRD', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('30', 'TRL', 'Training & Learning', 'HRD', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('31', 'CUL', 'Culture', 'HRD', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('32', 'BEN', 'Benefits', 'HRD', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('33', 'REC', 'Recruitment', 'HRD', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('34', 'CMP', 'Compensation', 'HRD', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('35', 'REL', 'Industrial Relations', 'HRD', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('36', 'MIN', 'Mining', 'OPS', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('37', 'EST', 'Estate/Plantation', 'OPS', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('38', 'MIL', 'Mill/Pabrik', 'OPS', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('39', 'PKL', 'Perkebunan', 'OPS', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('40', 'TRN', 'Transport', 'OPS', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('41', 'FLD', 'Field Operations', 'OPS', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('42', 'SPL', 'Supply Chain', 'OPS', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('43', 'CTO', 'CITO Office', 'CORP', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('44', 'BUS', 'Business Development', 'CORP', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('45', 'STR', 'Strategy', 'CORP', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('46', 'INT', 'Internal Audit', 'CORP', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('47', 'CSR', 'CSR', 'CORP', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_divisions (id, division_code, division_name, parent_division, is_active, created_at) VALUES ('48', 'DIG', 'Digital', 'IT', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
END $$;

-- ── master_positions (12 baris) ──
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.master_positions LIMIT 1) THEN
    RAISE NOTICE 'master_positions sudah berisi data — dilewati';
    RETURN;
  END IF;
  INSERT INTO public.master_positions (id, position_code, position_name, level_jabatan, is_active, created_at) VALUES ('1', 'MAG', 'Magang', 'Entry', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_positions (id, position_code, position_name, level_jabatan, is_active, created_at) VALUES ('2', 'STF', 'Staff', 'Entry', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_positions (id, position_code, position_name, level_jabatan, is_active, created_at) VALUES ('3', 'SST', 'Senior Staff', 'Entry', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_positions (id, position_code, position_name, level_jabatan, is_active, created_at) VALUES ('4', 'SPV', 'Supervisor', 'Mid', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_positions (id, position_code, position_name, level_jabatan, is_active, created_at) VALUES ('5', 'SPT', 'Senior Supervisor', 'Mid', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_positions (id, position_code, position_name, level_jabatan, is_active, created_at) VALUES ('6', 'MGR', 'Manager', 'Middle', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_positions (id, position_code, position_name, level_jabatan, is_active, created_at) VALUES ('7', 'SMGR', 'Senior Manager', 'Middle', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_positions (id, position_code, position_name, level_jabatan, is_active, created_at) VALUES ('8', 'DIR', 'Director', 'Top', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_positions (id, position_code, position_name, level_jabatan, is_active, created_at) VALUES ('9', 'SVP', 'Senior Vice President', 'Top', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_positions (id, position_code, position_name, level_jabatan, is_active, created_at) VALUES ('10', 'VP', 'Vice President', 'Top', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_positions (id, position_code, position_name, level_jabatan, is_active, created_at) VALUES ('11', 'CXX', 'C-Level (CEO/CFO/CTO)', 'Top', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
  INSERT INTO public.master_positions (id, position_code, position_name, level_jabatan, is_active, created_at) VALUES ('12', 'CEO', 'Chief Executive Officer', 'Top', 'true', '2026-09-05 09:13:48.806323+00'::timestamptz);
END $$;

-- ── master_locations (7 baris) ──
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.master_locations LIMIT 1) THEN
    RAISE NOTICE 'master_locations sudah berisi data — dilewati';
    RETURN;
  END IF;
  INSERT INTO public.master_locations (id, location_code, location_name, is_active) VALUES ('1', 'PUSAT', 'Kantor Pusat', 'true');
  INSERT INTO public.master_locations (id, location_code, location_name, is_active) VALUES ('2', 'CABANG', 'Kantor Cabang', 'true');
  INSERT INTO public.master_locations (id, location_code, location_name, is_active) VALUES ('3', 'SITE', 'Site/Field', 'true');
  INSERT INTO public.master_locations (id, location_code, location_name, is_active) VALUES ('4', 'MILL', 'Pabrik/Mill', 'true');
  INSERT INTO public.master_locations (id, location_code, location_name, is_active) VALUES ('5', 'ESTATE', 'Perkebunan/Estate', 'true');
  INSERT INTO public.master_locations (id, location_code, location_name, is_active) VALUES ('6', 'REMOTE', 'Remote/WFH', 'true');
  INSERT INTO public.master_locations (id, location_code, location_name, is_active) VALUES ('7', 'OTHER', 'Lainnya', 'true');
END $$;

-- ── master_employment_status (5 baris) ──
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.master_employment_status LIMIT 1) THEN
    RAISE NOTICE 'master_employment_status sudah berisi data — dilewati';
    RETURN;
  END IF;
  INSERT INTO public.master_employment_status (id, status_code, status_name, is_active) VALUES ('1', 'PKWTT', 'Pegawai dengan Perjanjian Kerja Waktu Tidak Tertentu', 'true');
  INSERT INTO public.master_employment_status (id, status_code, status_name, is_active) VALUES ('2', 'PKWT', 'Pegawai dengan Perjanjian Kerja Waktu Tertentu', 'true');
  INSERT INTO public.master_employment_status (id, status_code, status_name, is_active) VALUES ('3', 'PROBATION', 'Masa Percobaan', 'true');
  INSERT INTO public.master_employment_status (id, status_code, status_name, is_active) VALUES ('4', 'BHL', 'Bukan Hubungan Kerja (Outsourcing)', 'true');
  INSERT INTO public.master_employment_status (id, status_code, status_name, is_active) VALUES ('5', 'INTERN', 'Internship/Magang', 'true');
END $$;

-- ── role_page_access (48 baris) ──
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.role_page_access LIMIT 1) THEN
    RAISE NOTICE 'role_page_access sudah berisi data — dilewati';
    RETURN;
  END IF;
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('1', 'admin_pusat', '/admin/*', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('2', 'admin_hrd', '/admin/employees', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('3', 'admin_hrd', '/admin/recruitment', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('4', 'admin_hrd', '/admin/kpi', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('5', 'admin_hrd', '/admin/learning', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('6', 'admin_hrd', '/admin/talent', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('7', 'admin_hrd', '/admin/exit', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('8', 'admin_hrd', '/admin/requests', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('9', 'admin_hrd', '/admin/review-360', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('10', 'admin_hrd', '/admin/*', 'false', 'false', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('11', 'admin_finance', '/admin/payroll', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('12', 'admin_finance', '/admin/budget', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('13', 'admin_finance', '/admin/timesheet', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('14', 'admin_finance', '/admin/overtime', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('15', 'admin_finance', '/admin/export', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('16', 'admin_finance', '/admin/kpi', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('17', 'admin_finance', '/admin/*', 'false', 'false', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('18', 'admin_operasional', '/admin/requests', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('19', 'admin_operasional', '/admin/leave', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('20', 'admin_operasional', '/admin/overtime', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('21', 'admin_operasional', '/admin/timesheet', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('22', 'admin_operasional', '/admin/shift-swap', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('23', 'admin_operasional', '/admin/assets', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('24', 'admin_operasional', '/admin/*', 'false', 'false', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('25', 'admin_mining', '/worker/simper', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('26', 'admin_mining', '/worker/heavy-equip', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('27', 'admin_mining', '/worker/fatigue', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('28', 'admin_mining', '/worker/production', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('29', 'admin_mining', '/worker/safety', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('30', 'admin_mining', '/worker/emergency', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('31', 'admin_mining', '/worker/jsa', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('32', 'admin_mining', '/admin/*', 'false', 'false', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('33', 'admin_mill', '/worker/boiler', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('34', 'admin_mill', '/worker/machines', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('35', 'admin_mill', '/worker/qc', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('36', 'admin_mill', '/worker/packing', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('37', 'admin_mill', '/worker/maintenance', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('38', 'admin_mill', '/worker/breakdown', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('39', 'admin_mill', '/worker/shift', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('40', 'admin_mill', '/admin/*', 'false', 'false', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('41', 'admin_estate', '/worker/harvest', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('42', 'admin_estate', '/worker/blocks', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('43', 'admin_estate', '/worker/transport', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('44', 'admin_estate', '/worker/nursery', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('45', 'admin_estate', '/worker/irrigation', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('46', 'admin_estate', '/worker/facility', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('47', 'admin_estate', '/worker/medical', 'true', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz);
  INSERT INTO public.role_page_access (id, role_code, page_pattern, can_access, can_action, created_at) VALUES ('48', 'admin_estate', '/admin/*', 'false', 'false', '2026-09-03 14:49:48.795518+00'::timestamptz);
END $$;

-- ── role_permission_sets (26 baris) ──
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.role_permission_sets LIMIT 1) THEN
    RAISE NOTICE 'role_permission_sets sudah berisi data — dilewati';
    RETURN;
  END IF;
  INSERT INTO public.role_permission_sets (id, role_code, permission_set, created_at) VALUES ('1', 'worker', 'worker_basic', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.role_permission_sets (id, role_code, permission_set, created_at) VALUES ('2', 'supervisor', 'worker_basic', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.role_permission_sets (id, role_code, permission_set, created_at) VALUES ('3', 'supervisor', 'supervisor_ext', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.role_permission_sets (id, role_code, permission_set, created_at) VALUES ('4', 'manager', 'worker_basic', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.role_permission_sets (id, role_code, permission_set, created_at) VALUES ('5', 'manager', 'supervisor_ext', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.role_permission_sets (id, role_code, permission_set, created_at) VALUES ('6', 'manager', 'manager_ext', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.role_permission_sets (id, role_code, permission_set, created_at) VALUES ('7', 'admin_hrd', 'worker_basic', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.role_permission_sets (id, role_code, permission_set, created_at) VALUES ('8', 'admin_hrd', 'supervisor_ext', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.role_permission_sets (id, role_code, permission_set, created_at) VALUES ('9', 'admin_hrd', 'manager_ext', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.role_permission_sets (id, role_code, permission_set, created_at) VALUES ('10', 'admin_hrd', 'hrd_ops', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.role_permission_sets (id, role_code, permission_set, created_at) VALUES ('11', 'admin_finance', 'worker_basic', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.role_permission_sets (id, role_code, permission_set, created_at) VALUES ('12', 'admin_finance', 'supervisor_ext', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.role_permission_sets (id, role_code, permission_set, created_at) VALUES ('13', 'admin_finance', 'finance_ops', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.role_permission_sets (id, role_code, permission_set, created_at) VALUES ('14', 'admin_produksi', 'worker_basic', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.role_permission_sets (id, role_code, permission_set, created_at) VALUES ('15', 'admin_produksi', 'supervisor_ext', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.role_permission_sets (id, role_code, permission_set, created_at) VALUES ('16', 'admin_produksi', 'manager_ext', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.role_permission_sets (id, role_code, permission_set, created_at) VALUES ('17', 'admin_mining', 'worker_basic', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.role_permission_sets (id, role_code, permission_set, created_at) VALUES ('18', 'admin_mining', 'mining_ops', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.role_permission_sets (id, role_code, permission_set, created_at) VALUES ('19', 'admin_estate', 'worker_basic', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.role_permission_sets (id, role_code, permission_set, created_at) VALUES ('20', 'admin_estate', 'estate_ops', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.role_permission_sets (id, role_code, permission_set, created_at) VALUES ('21', 'admin_mill', 'worker_basic', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.role_permission_sets (id, role_code, permission_set, created_at) VALUES ('22', 'admin_mill', 'mill_ops', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.role_permission_sets (id, role_code, permission_set, created_at) VALUES ('23', 'admin_pusat', 'worker_basic', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.role_permission_sets (id, role_code, permission_set, created_at) VALUES ('24', 'admin_pusat', 'supervisor_ext', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.role_permission_sets (id, role_code, permission_set, created_at) VALUES ('25', 'admin_pusat', 'manager_ext', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.role_permission_sets (id, role_code, permission_set, created_at) VALUES ('26', 'admin_pusat', 'admin_pusat_all', '2026-09-04 10:00:41.03652+00'::timestamptz);
END $$;

-- ── permission_set_items (93 baris) ──
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.permission_set_items LIMIT 1) THEN
    RAISE NOTICE 'permission_set_items sudah berisi data — dilewati';
    RETURN;
  END IF;
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('1', 'worker_basic', 'profile.view', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('2', 'worker_basic', 'profile.edit_own', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('3', 'worker_basic', 'attendance.view_own', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('4', 'worker_basic', 'attendance.clock_in', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('5', 'worker_basic', 'attendance.clock_out', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('6', 'worker_basic', 'leave.view_own', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('7', 'worker_basic', 'leave.apply', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('8', 'worker_basic', 'overtime.view_own', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('9', 'worker_basic', 'overtime.apply', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('10', 'worker_basic', 'learning.view_own', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('11', 'worker_basic', 'learning.enroll', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('12', 'worker_basic', 'engagement.survey_respond', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('13', 'worker_basic', 'engagement.voice_submit', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('14', 'worker_basic', 'notification.view_own', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('15', 'supervisor_ext', 'team.view', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('16', 'supervisor_ext', 'team.attendance_view', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('17', 'supervisor_ext', 'leave.approve', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('18', 'supervisor_ext', 'overtime.approve', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('19', 'supervisor_ext', 'task.assign', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('20', 'supervisor_ext', 'task.approve', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('21', 'manager_ext', 'department.view', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('22', 'manager_ext', 'department.reports', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('23', 'manager_ext', 'kpi.view_team', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('24', 'manager_ext', 'kpi.set_targets', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('25', 'manager_ext', 'performance.review', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('26', 'manager_ext', 'coaching.assign', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('27', 'hrd_ops', 'employee.view_all', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('28', 'hrd_ops', 'employee.create', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('29', 'hrd_ops', 'employee.update', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('30', 'hrd_ops', 'employee.deactivate', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('31', 'hrd_ops', 'recruitment.view', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('32', 'hrd_ops', 'recruitment.approve', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('33', 'hrd_ops', 'payroll.view_all', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('34', 'hrd_ops', 'payroll.process', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('35', 'hrd_ops', 'training.manage', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('36', 'hrd_ops', 'talent.manage', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('37', 'hrd_ops', 'offboarding.manage', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('38', 'hrd_ops', 'compliance.manage', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('39', 'finance_ops', 'payroll.view_all', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('40', 'finance_ops', 'payroll.process', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('41', 'hrd_ops', 'payroll.export', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('42', 'finance_ops', 'budget.view', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('43', 'finance_ops', 'budget.approve', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('44', 'finance_ops', 'timesheet.approve', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('45', 'finance_ops', 'export.payroll', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('46', 'finance_ops', 'export_financial', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('47', 'mining_ops', 'mining.simper_view', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('48', 'mining_ops', 'mining.equipment_view', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('49', 'mining_ops', 'mining.production_view', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('50', 'mining_ops', 'mining.safety_view', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('51', 'mining_ops', 'mining.fatigue_view', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('52', 'mining_ops', 'mining.jsa_view', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('53', 'mining_ops', 'mining.block_model_view', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('54', 'estate_ops', 'estate.harvest_view', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('55', 'estate_ops', 'estate.blocks_view', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('56', 'estate_ops', 'estate.transport_view', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('57', 'estate_ops', 'estate.nursery_view', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('58', 'estate_ops', 'estate.irrigation_view', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('59', 'estate_ops', 'estate.field_view', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('60', 'estate_ops', 'estate.yield_view', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('61', 'mill_ops', 'mill.boiler_view', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('62', 'mill_ops', 'mill.press_view', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('63', 'mill_ops', 'mill.qc_view', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('64', 'mill_ops', 'mill.packing_view', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('65', 'mill_ops', 'mill.maintenance_view', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('66', 'mill_ops', 'mill.breakdown_view', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('67', 'mill_ops', 'mill.production_view', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('68', 'admin_pusat_all', 'employee.view_all', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('69', 'admin_pusat_all', 'employee.create', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('70', 'admin_pusat_all', 'employee.update', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('71', 'admin_pusat_all', 'employee.deactivate', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('72', 'admin_pusat_all', 'payroll.view_all', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('73', 'admin_pusat_all', 'payroll.process', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('74', 'admin_pusat_all', 'payroll.export', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('75', 'admin_pusat_all', 'budget.view', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('76', 'admin_pusat_all', 'budget.approve', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('77', 'admin_pusat_all', 'kpi.manage', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('78', 'admin_pusat_all', 'learning.manage', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('79', 'admin_pusat_all', 'recruitment.manage', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('80', 'admin_pusat_all', 'talent.manage', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('81', 'admin_pusat_all', 'timesheet.approve', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('82', 'admin_pusat_all', 'leave.approve', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('83', 'admin_pusat_all', 'overtime.approve', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('84', 'admin_pusat_all', 'compliance.manage', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('85', 'admin_pusat_all', 'audit.view', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('86', 'admin_pusat_all', 'mining.manage', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('87', 'admin_pusat_all', 'estate.manage', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('88', 'admin_pusat_all', 'mill.manage', '2026-09-04 10:00:41.03652+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('89', 'admin_pusat_all', 'shift.approve', '2026-09-08 12:16:50.312358+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('90', 'admin_pusat_all', 'facility.approve', '2026-09-08 12:16:50.312358+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('91', 'hrd_ops', 'shift.approve', '2026-09-08 12:16:50.312358+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('92', 'hrd_ops', 'facility.approve', '2026-09-08 12:16:50.312358+00'::timestamptz);
  INSERT INTO public.permission_set_items (id, permission_set, permission_code, created_at) VALUES ('93', 'supervisor_ext', 'shift.approve', '2026-09-08 12:16:50.312358+00'::timestamptz);
END $$;

-- ── admin_roles (7 baris) ──
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.admin_roles LIMIT 1) THEN
    RAISE NOTICE 'admin_roles sudah berisi data — dilewati';
    RETURN;
  END IF;
  INSERT INTO public.admin_roles (id, role_code, role_name, scope_type, scope_id, permissions, can_manage_users, can_manage_modules, is_active, created_at, created_by) VALUES ('1', 'admin_pusat', 'Admin Pusat', 'global', NULL, '["*"]'::jsonb, 'true', 'false', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz, NULL);
  INSERT INTO public.admin_roles (id, role_code, role_name, scope_type, scope_id, permissions, can_manage_users, can_manage_modules, is_active, created_at, created_by) VALUES ('2', 'admin_hrd', 'Admin HRD', 'function', 'hrd', '["employees.*", "recruitment.*", "kpi.*", "learning.*", "talent.*", "exit.*"]'::jsonb, 'false', 'false', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz, NULL);
  INSERT INTO public.admin_roles (id, role_code, role_name, scope_type, scope_id, permissions, can_manage_users, can_manage_modules, is_active, created_at, created_by) VALUES ('3', 'admin_finance', 'Admin Finance', 'function', 'finance', '["payroll.*", "budget.*", "timesheet.*", "overtime.*", "export.*", "kpi.*"]'::jsonb, 'false', 'false', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz, NULL);
  INSERT INTO public.admin_roles (id, role_code, role_name, scope_type, scope_id, permissions, can_manage_users, can_manage_modules, is_active, created_at, created_by) VALUES ('4', 'admin_operasional', 'Admin Operasional', 'function', 'operasional', '["requests.*", "leave.*", "overtime.*", "timesheet.*", "assets.*", "shift.*"]'::jsonb, 'false', 'false', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz, NULL);
  INSERT INTO public.admin_roles (id, role_code, role_name, scope_type, scope_id, permissions, can_manage_users, can_manage_modules, is_active, created_at, created_by) VALUES ('5', 'admin_mining', 'Admin Mining', 'industry', 'mining', '["mining.*"]'::jsonb, 'false', 'false', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz, NULL);
  INSERT INTO public.admin_roles (id, role_code, role_name, scope_type, scope_id, permissions, can_manage_users, can_manage_modules, is_active, created_at, created_by) VALUES ('6', 'admin_mill', 'Admin Mill', 'industry', 'mill', '["mill.*"]'::jsonb, 'false', 'false', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz, NULL);
  INSERT INTO public.admin_roles (id, role_code, role_name, scope_type, scope_id, permissions, can_manage_users, can_manage_modules, is_active, created_at, created_by) VALUES ('7', 'admin_estate', 'Admin Estate', 'industry', 'estate', '["estate.*"]'::jsonb, 'false', 'false', 'true', '2026-09-03 14:49:48.795518+00'::timestamptz, NULL);
END $$;

-- ── validation_rules (46 baris) ──
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.validation_rules LIMIT 1) THEN
    RAISE NOTICE 'validation_rules sudah berisi data — dilewati';
    RETURN;
  END IF;
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('1', 'nik', 'regex', '^[0-9]{16}$', 'NIK harus 16 digit angka', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('2', 'npwp', 'regex', '^[0-9]{15,16}$', 'NPWP harus 15-16 digit angka', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('3', 'nrp', 'min_length', '3', 'NRP minimal 3 karakter', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('4', 'nrp', 'max_length', '20', 'NRP maksimal 20 karakter', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('5', 'email', 'regex', '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$', 'Format email tidak valid', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('6', 'no_hp', 'regex', '^[0-9]{10,13}$', 'No HP harus 10-13 digit', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('7', 'tanggal_lahir', 'min_date', '1940-01-01', 'Tanggal lahir terlalu tua', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('8', 'tanggal_lahir', 'max_date', '-18 years', 'Karyawan harus minimal 18 tahun', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('9', 'tanggal_masuk', 'min_date', '2000-01-01', 'Tanggal masuk tidak valid', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('10', 'base_salary', 'min_value', '0', 'Gaji pokok tidak boleh negatif', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('11', 'base_salary', 'max_value', '500000000', 'Gaji pokok melebihi batas', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('12', 'kk', 'regex', '^[0-9]{16}$', 'Nomor KK harus 16 digit', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('13', 'nama', 'min_length', '2', 'Nama minimal 2 karakter', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('14', 'nama', 'max_length', '100', 'Nama maksimal 100 karakter', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('15', 'divisi', 'required', 'true', 'Divisi wajib diisi', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('16', 'posisi', 'required', 'true', 'Posisi wajib diisi', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('17', 'status_kerja', 'required', 'true', 'Status kerja wajib diisi', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('18', 'tanggal_masuk', 'required', 'true', 'Tanggal masuk wajib diisi', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('19', 'golongan_darah', 'enum', 'A,B,AB,O', 'Golongan darah harus A/B/AB/O', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('20', 'status_pernikahan', 'enum', 'Menikah,Belum,Cerai', 'Status pernikahan tidak valid', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('21', 'level_jabatan', 'enum', 'Entry,Mid,Middle,Top', 'Level jabatan tidak valid', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('22', 'ukuran_celana', 'min_value', '28', 'Ukuran celana minimal 28', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('23', 'ukuran_celana', 'max_value', '44', 'Ukuran celana maksimal 44', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('24', 'nik', 'regex', '^[0-9]{16}$', 'NIK harus 16 digit angka', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('25', 'npwp', 'regex', '^[0-9]{15,16}$', 'NPWP harus 15-16 digit angka', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('26', 'nrp', 'min_length', '3', 'NRP minimal 3 karakter', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('27', 'nrp', 'max_length', '20', 'NRP maksimal 20 karakter', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('28', 'email', 'regex', '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$', 'Format email tidak valid', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('29', 'no_hp', 'regex', '^[0-9]{10,13}$', 'No HP harus 10-13 digit', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('30', 'tanggal_lahir', 'min_date', '1940-01-01', 'Tanggal lahir terlalu tua', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('31', 'tanggal_lahir', 'max_date', '-18 years', 'Karyawan harus minimal 18 tahun', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('32', 'tanggal_masuk', 'min_date', '2000-01-01', 'Tanggal masuk tidak valid', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('33', 'base_salary', 'min_value', '0', 'Gaji pokok tidak boleh negatif', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('34', 'base_salary', 'max_value', '500000000', 'Gaji pokok melebihi batas', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('35', 'kk', 'regex', '^[0-9]{16}$', 'Nomor KK harus 16 digit', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('36', 'nama', 'min_length', '2', 'Nama minimal 2 karakter', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('37', 'nama', 'max_length', '100', 'Nama maksimal 100 karakter', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('38', 'divisi', 'required', 'true', 'Divisi wajib diisi', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('39', 'posisi', 'required', 'true', 'Posisi wajib diisi', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('40', 'status_kerja', 'required', 'true', 'Status kerja wajib diisi', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('41', 'tanggal_masuk', 'required', 'true', 'Tanggal masuk wajib diisi', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('42', 'golongan_darah', 'enum', 'A,B,AB,O', 'Golongan darah harus A/B/AB/O', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('43', 'status_pernikahan', 'enum', 'Menikah,Belum,Cerai', 'Status pernikahan tidak valid', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('44', 'level_jabatan', 'enum', 'Entry,Mid,Middle,Top', 'Level jabatan tidak valid', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('45', 'ukuran_celana', 'min_value', '28', 'Ukuran celana minimal 28', 'true');
  INSERT INTO public.validation_rules (id, field_name, rule_type, rule_value, error_message, is_active) VALUES ('46', 'ukuran_celana', 'max_value', '44', 'Ukuran celana maksimal 44', 'true');
END $$;

-- ── notification_config (12 baris) ──
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.notification_config LIMIT 1) THEN
    RAISE NOTICE 'notification_config sudah berisi data — dilewati';
    RETURN;
  END IF;
  INSERT INTO public.notification_config (id, event_type, label, email_enabled, push_enabled, template, created_at, updated_at) VALUES ('f470369f-2fcd-43f8-b1f0-20c932888c4f', 'leave_request', 'Cuti Diajukan', 'false', 'true', NULL, '2026-09-03 09:08:01.604563+00'::timestamptz, '2026-09-03 09:08:01.604563+00'::timestamptz);
  INSERT INTO public.notification_config (id, event_type, label, email_enabled, push_enabled, template, created_at, updated_at) VALUES ('7bc5b243-21f2-4015-b126-e46b35a236b0', 'leave_approved', 'Cuti Disetujui', 'false', 'true', NULL, '2026-09-03 09:08:01.604563+00'::timestamptz, '2026-09-03 09:08:01.604563+00'::timestamptz);
  INSERT INTO public.notification_config (id, event_type, label, email_enabled, push_enabled, template, created_at, updated_at) VALUES ('6b7fc596-34a8-4385-8665-1a9a77699d8a', 'leave_rejected', 'Cuti Ditolak', 'false', 'true', NULL, '2026-09-03 09:08:01.604563+00'::timestamptz, '2026-09-03 09:08:01.604563+00'::timestamptz);
  INSERT INTO public.notification_config (id, event_type, label, email_enabled, push_enabled, template, created_at, updated_at) VALUES ('06aa9b54-f080-4f91-b37d-c56d6a8ca469', 'overtime_request', 'Lembur Diajukan', 'false', 'true', NULL, '2026-09-03 09:08:01.604563+00'::timestamptz, '2026-09-03 09:08:01.604563+00'::timestamptz);
  INSERT INTO public.notification_config (id, event_type, label, email_enabled, push_enabled, template, created_at, updated_at) VALUES ('60929416-fe83-4aa7-89a8-46d4ac8117b4', 'overtime_approved', 'Lembur Disetujui', 'false', 'true', NULL, '2026-09-03 09:08:01.604563+00'::timestamptz, '2026-09-03 09:08:01.604563+00'::timestamptz);
  INSERT INTO public.notification_config (id, event_type, label, email_enabled, push_enabled, template, created_at, updated_at) VALUES ('4402609d-88df-4954-8cd4-24d3dab79a23', 'approval_needed', 'Menunggu Persetujuan', 'false', 'true', NULL, '2026-09-03 09:08:01.604563+00'::timestamptz, '2026-09-03 09:08:01.604563+00'::timestamptz);
  INSERT INTO public.notification_config (id, event_type, label, email_enabled, push_enabled, template, created_at, updated_at) VALUES ('2a58244e-b2a4-4030-a240-61381805cb16', 'announcement', 'Pengumuman Baru', 'false', 'true', NULL, '2026-09-03 09:08:01.604563+00'::timestamptz, '2026-09-03 09:08:01.604563+00'::timestamptz);
  INSERT INTO public.notification_config (id, event_type, label, email_enabled, push_enabled, template, created_at, updated_at) VALUES ('c9dcdad7-0230-4144-acf4-25645778414e', 'training_enrolled', 'Training Terdaftar', 'false', 'true', NULL, '2026-09-03 09:08:01.604563+00'::timestamptz, '2026-09-03 09:08:01.604563+00'::timestamptz);
  INSERT INTO public.notification_config (id, event_type, label, email_enabled, push_enabled, template, created_at, updated_at) VALUES ('73fa075b-cd18-4129-a80d-5161c5994122', 'kpi_updated', 'KPI Diperbarui', 'false', 'true', NULL, '2026-09-03 09:08:01.604563+00'::timestamptz, '2026-09-03 09:08:01.604563+00'::timestamptz);
  INSERT INTO public.notification_config (id, event_type, label, email_enabled, push_enabled, template, created_at, updated_at) VALUES ('bdd23f7e-eafb-4b86-a88e-5e905bb153a6', 'payslip_ready', 'Slip Gaji Tersedia', 'false', 'true', NULL, '2026-09-03 09:08:01.604563+00'::timestamptz, '2026-09-03 09:08:01.604563+00'::timestamptz);
  INSERT INTO public.notification_config (id, event_type, label, email_enabled, push_enabled, template, created_at, updated_at) VALUES ('a07011a9-628c-433b-9592-f4e99e8004c6', 'birthday', 'Ulang Tahun', 'false', 'true', NULL, '2026-09-03 09:08:01.604563+00'::timestamptz, '2026-09-03 09:08:01.604563+00'::timestamptz);
  INSERT INTO public.notification_config (id, event_type, label, email_enabled, push_enabled, template, created_at, updated_at) VALUES ('9fc31e2c-9bdc-420f-ba5b-dac5cf11e8c4', 'probation_expiring', 'Masa Percobaan Berakhir', 'false', 'true', NULL, '2026-09-03 09:08:01.604563+00'::timestamptz, '2026-09-03 09:08:01.604563+00'::timestamptz);
END $$;

-- ── hr_document_types (12 baris) ──
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.hr_document_types LIMIT 1) THEN
    RAISE NOTICE 'hr_document_types sudah berisi data — dilewati';
    RETURN;
  END IF;
  INSERT INTO public.hr_document_types (type, sub_type) VALUES ('BPJS_KETENAGAKERJAAN', 'Insurance');
  INSERT INTO public.hr_document_types (type, sub_type) VALUES ('TABUNGAN', 'Finance');
  INSERT INTO public.hr_document_types (type, sub_type) VALUES ('KK', 'Family');
  INSERT INTO public.hr_document_types (type, sub_type) VALUES ('BPJS_KESEHATAN', 'Insurance');
  INSERT INTO public.hr_document_types (type, sub_type) VALUES ('NPWP', 'Tax');
  INSERT INTO public.hr_document_types (type, sub_type) VALUES ('FOTO', 'Identity');
  INSERT INTO public.hr_document_types (type, sub_type) VALUES ('KTP', 'Identity');
  INSERT INTO public.hr_document_types (type, sub_type) VALUES ('SIM', 'License');
  INSERT INTO public.hr_document_types (type, sub_type) VALUES ('IJAZAH', 'Diploma');
  INSERT INTO public.hr_document_types (type, sub_type) VALUES ('SERTIFIKASI', 'Certificate');
  INSERT INTO public.hr_document_types (type, sub_type) VALUES ('LAINNYA', 'Other');
  INSERT INTO public.hr_document_types (type, sub_type) VALUES ('KET_ANAK_KULIAH', 'Family');
END $$;

-- ── tier_pricing (5 baris) ──
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.tier_pricing LIMIT 1) THEN
    RAISE NOTICE 'tier_pricing sudah berisi data — dilewati';
    RETURN;
  END IF;
  INSERT INTO public.tier_pricing (tier, nama, harga_idr, target_karyawan, industry_modules, support, update_policy, fitur, is_active, created_at, updated_at) VALUES ('0', 'GRATIS (Community)', 0, '1-25', 'Tidak ada', 'Community', 'Tidak ada', '["Database karyawan (100 row limit)", "Absensi mobile GPS", "Pengajuan cuti & izin", "ESS dasar", "2 user roles"]'::jsonb, 'true', '2026-09-05 10:20:56.366473+00'::timestamptz, '2026-09-05 10:20:56.366473+00'::timestamptz);
  INSERT INTO public.tier_pricing (tier, nama, harga_idr, target_karyawan, industry_modules, support, update_policy, fitur, is_active, created_at, updated_at) VALUES ('1', 'MINIMALIS', 9500000, '25-100', 'Tidak ada', '1 bulan', '1 tahun', '["Database unlimited", "Absensi + shift", "Cuti & izin multi-level", "Lembur dasar", "Laporan Excel/PDF", "5 roles", "Backup tool"]'::jsonb, 'true', '2026-09-05 10:20:56.366473+00'::timestamptz, '2026-09-05 10:20:56.366473+00'::timestamptz);
  INSERT INTO public.tier_pricing (tier, nama, harga_idr, target_karyawan, industry_modules, support, update_policy, fitur, is_active, created_at, updated_at) VALUES ('2', 'STANDAR', 35000000, '100-500', 'Tidak ada', '3 bulan', '2 tahun', '["Semua TIER 1", "Payroll otomatis + slip gaji", "KPI & OKR", "Performance review 360", "LMS", "Recruitment pipeline", "15+ roles", "Dashboard analytics"]'::jsonb, 'true', '2026-09-05 10:20:56.366473+00'::timestamptz, '2026-09-05 10:20:56.366473+00'::timestamptz);
  INSERT INTO public.tier_pricing (tier, nama, harga_idr, target_karyawan, industry_modules, support, update_policy, fitur, is_active, created_at, updated_at) VALUES ('3', 'PREMIUM', 95000000, '500-2.000', '1 Industry module (MINING/ESTATE/MILL)', '6 bulan + Dedicated CS', '3 tahun', '["Semua TIER 2", "Talent management", "Engagement survey & eNPS", "Badges & gamifikasi", "Workforce analytics", "Flight risk & turnover prediction", "Custom branding", "Full API access", "Webhooks", "MFA + SSO basic", "10 jam konsultasi"]'::jsonb, 'true', '2026-09-05 10:20:56.366473+00'::timestamptz, '2026-09-05 10:20:56.366473+00'::timestamptz);
  INSERT INTO public.tier_pricing (tier, nama, harga_idr, target_karyawan, industry_modules, support, update_policy, fitur, is_active, created_at, updated_at) VALUES ('4', 'ENTERPRISE', 295000000, '2.000+', 'ALL (21 module)', '24/7 1 tahun + Account Manager', 'Lifetime', '["Semua TIER 3", "AI Copilot + RAG", "Workforce simulation", "Multi-BU / multi-company", "Full source code + white-label", "Advanced SSO (SAML/OIDC)", "Audit trail immutable", "SLA 99.9%", "40 jam konsultasi", "On-site training 3 hari", "Lifetime update"]'::jsonb, 'true', '2026-09-05 10:20:56.366473+00'::timestamptz, '2026-09-05 10:20:56.366473+00'::timestamptz);
END $$;

-- ── branding (1 baris netral — GANTI lewat OwnerDashboard → 🎨 Branding) ──
-- Nama perusahaan di bawah diisi saat generate (--company-name="..."); logo & warna
-- sengaja dikosongkan agar tidak mewarisi aset DB sumber.
DO $$ BEGIN
  IF to_regclass('public.branding') IS NULL THEN RETURN; END IF;
  IF EXISTS (SELECT 1 FROM public.branding LIMIT 1) THEN
    RAISE NOTICE 'branding sudah berisi data — dilewati';
    RETURN;
  END IF;
  INSERT INTO public.branding (id, company_name, tagline, logo_url, logo_dark_url, primary_color, favicon_url, updated_at, updated_by) VALUES ('main', 'Perusahaan Anda', 'Workforce Intelligence Platform', NULL, NULL, '#3b82f6', NULL, NULL, NULL);
END $$;

-- ── CAP schema_migrations ────────────────────────────────────────
-- Semua berkas migrasi repo ditandai sebagai sudah diterapkan, dengan checksum
-- SHA-256 berkas dengan EOL CRLF->LF dinormalisasi lebih dulu — modul bersama
-- `supabase/scripts/migration-checksum.mjs`, sama seperti `apply-migration.mjs` —
-- supaya nilai checksum tidak bergantung gaya EOL checkout. Dengan begitu
-- `verify_migration_checksum` dan `check_migrations()` konsisten dan
-- migrasi baru (> versi tertinggi) berjalan incremental.
DO $$
DECLARE v_n INTEGER;
BEGIN
  IF to_regclass('public.schema_migrations') IS NULL THEN
    RAISE WARNING 'schema_migrations tidak ada — cap registry dilewati';
    RETURN;
  END IF;
  v_n := 0;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '000_pgcrypto.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('000', '000_pgcrypto.sql', '850462dc4269e234d315d2df57484c95cfccfe7f6d2eb3838b7bed15e969962b', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '001_init.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('001', '001_init.sql', '6eee3b3848d652812a8392fc102f86e5f08ea39821d1a894e178e257fec1aedd', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '003_fix_columns.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('003', '003_fix_columns.sql', 'ca302a4eb51ba9a43dfa02473614fc067416a4fbcd7a6c31c1977c8c64d1b364', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '005_fix_hash_bug.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('005', '005_fix_hash_bug.sql', '934bb841d435c9dfbda0f5c17d592c1902174caa20022e21a77699eeac4ad84a', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '006_cron_setup.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('006', '006_cron_setup.sql', 'd75bc7e035f4a389a27cf59ba9c4578d39313eba4f486636575fcf3d226abd08', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '007_pgvector_ai_copilot.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('007', '007_pgvector_ai_copilot.sql', '41c72ae4243f9be4b730e021a567a3880851ffb380bddd676b5e8fbedd5fed83', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '008_restore_missing_objects.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('008', '008_restore_missing_objects.sql', '1ee53500ad772e4a5b5e10dd576c9625992d0b8b552285a601cda18592ba2aa9', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '011_ULTIMATE.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('011', '011_ULTIMATE.sql', 'ed33e903a526d76b3df93cd8bc07015433d11f152e9d343e171be4511e48b0cc', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '018_new_25_tables.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('018', '018_new_25_tables.sql', 'cf07585c99dce7d7f55ba8873d7af89925645bd1021b38b8fcb725bff130274b', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '027_seed_remaining_tables.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('027', '027_seed_remaining_tables.sql', '242bea5f780d160b6e1adb2b9bfcdcb6eb129282f652eba6c442449e8dc1d92d', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '028_admin_worker_rpcs.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('028', '028_admin_worker_rpcs.sql', 'e8cd3a67d77078372cd96fd1236642575114760f5cb2c32b5bb253e79d453336', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '033_seed_ai_knowledge_base.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('033', '033_seed_ai_knowledge_base.sql', 'd0c692159e865c32baeef6dbdef2193b05126f055d7946939f0768495998eac7', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '034_wave_a_foundation.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('034', '034_wave_a_foundation.sql', 'b33bf525c84626da926202428b23f7d79fb775c75056a278d49b8485a8323d92', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '035_wave_b_connection_cache.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('035', '035_wave_b_connection_cache.sql', '1b2330bf556191dc9d5cd1f69c19003a46e5932bb8be5521699a93952e2781aa', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '038_fix_all_rpc_errors.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('038', '038_fix_all_rpc_errors.sql', 'd20ed23a20a4046d4c5f288395cfa54f80a23169b2b9370ab69102f2adfa3667', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '039_fix_worker_kpi_rpcs.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('039', '039_fix_worker_kpi_rpcs.sql', '6d11c9e18f4eeb5f6e5d8bf18889e5480b24c46a76df328c502fe19c368fb806', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '040_wave4_self_service.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('040', '040_wave4_self_service.sql', '70de59a8127e9d9df29605785d6be3d1fd7eb4c46e7d69a58969be5be5f95e7a', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '042_wave5_missing_rpcs.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('042', '042_wave5_missing_rpcs.sql', 'f18cd62b93f3ae6b69e61182f4e51bb335bc3f914b63a7e5fce74cc4fa28e4b7', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '043_fix_admin_worker_rpc_missing.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('043', '043_fix_admin_worker_rpc_missing.sql', '0bd4f6a99e36737c655013482cf3e9e52f6ecd294ce98f1858967a363eb539b4', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '044_push_subscriptions.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('044', '044_push_subscriptions.sql', '0c09217c498eef23ccb7fd5eb8aa3356c7bd5834dbd303899409b305f5357b57', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '045_wave8_integrations.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('045', '045_wave8_integrations.sql', '2a3309c709b345420f6b0278ab634d5ecdc5b11ca4c09f08e1b0789367eacf7c', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '047_optimized_seed.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('047', '047_optimized_seed.sql', 'c8968504f78bbbd1a051f357a517076c2f519a46502121f1fab2f9ef68db43f7', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '048_enable_rls_remaining.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('048', '048_enable_rls_remaining.sql', '6807cba04bce5e78c82c10b2c2e93a255f9d0868b5bb97c68724c64b5cb80275', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '050_wave_final_features.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('050', '050_wave_final_features.sql', '36479a301c45c3b1a203f47e6c972679d199bfcd5dae06008820b46e618c28ec', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '051_admin_2level_roles.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('051', '051_admin_2level_roles.sql', '4e246e4257ccfe8f772c055c60b6db76c967bf3f00c345445dde488fa2a14591', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '052_mill_modules.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('052', '052_mill_modules.sql', 'dac6f4e43f9ce2ec73e1e296f043624a99daec6c0297ff29600c2ff112c93940', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '053_seed_remaining_tables.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('053', '053_seed_remaining_tables.sql', '504ddf118bd38f3348ba8ad7f0584dcdbaad3cdedba56b31d8678ed8c0e6f6e1', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '054_audit_columns.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('054', '054_audit_columns.sql', '0cc96a02bbfc1eec2cfd54decdc33e933d571b7e83750289a99ab53635851a29', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '055_mining_estate_rpcs.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('055', '055_mining_estate_rpcs.sql', 'c41d88c10317038e09a1abe99cf9b609d36272b118d52685661ce5421530431e', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '057_mfa_totp.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('057', '057_mfa_totp.sql', 'da35119ab19b9c89dc35c6f512863c566112d8eeb72f82e40dd6f78ac7453c5f', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '058_duplicate_cleanup.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('058', '058_duplicate_cleanup.sql', '460346e40b9122bc442c1cd7f4f8dc11971b3d53397fadc1666f101086882a07', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '059_review360_rpc_fix.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('059', '059_review360_rpc_fix.sql', 'f2f7c2d9fe760f0ce72c2f377fbc2192d05dc0e38f334d8800342e6604641727', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '060_worker_views_rpcs.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('060', '060_worker_views_rpcs.sql', '9198f776e93d83c17ab6df7b50ccee93d219f7d063cf23af03f4efde76f9d9b5', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '061_data_governance.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('061', '061_data_governance.sql', 'ebcbc1f0c7e9206d57ede3808960b79effea1d6a045994d2374a55cf03690eb5', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '062_global_core.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('062', '062_global_core.sql', '6ac8b085ce723d210765fae124a235891a5d5ab6f0c2a84ebf5a5a1560abab38', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '063_performance_indexes.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('063', '063_performance_indexes.sql', 'db80803d7665304496c5b9f583345de2a8cff50ce639795750b5338535030765', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '065_estate_mining_rpcs.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('065', '065_estate_mining_rpcs.sql', '3f6aea6b737c721966123641236bd763c210ee6d791501deaa677c0628e7f56b', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '071_foundation.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('071', '071_foundation.sql', '72f7683d32bdd564d7c0159ccc20d9d1837c5f3c3dc30f071b94f955735ee7ab', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '072_rpc_gatekeepers.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('072', '072_rpc_gatekeepers.sql', 'a4a7359c67ccb7ef3dec140c1a9361a269e33280eb33241933766119fba2c4fe', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '073_industry_rpc_templates.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('073', '073_industry_rpc_templates.sql', 'b9a3b2b0d9f9004b5c5680248709774a52e905046e7e9ca6b800e6428f8c1d15', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '075_fix_industry_columns.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('075', '075_fix_industry_columns.sql', 'e2f9a308976022b3e1f01f00a30928d5b0055c5ce7e01f8a6a73919629ba100f', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '076_test_accounts.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('076', '076_test_accounts.sql', '731d34454acd08a1060f35b8b53ddb094842b832877ff566a790ede84b34ac2b', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '077_fix_seed_data.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('077', '077_fix_seed_data.sql', '37c97c834db2f2ee7df70ecbebbf82612c4210f98a65f179c0e2213aee8acb21', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '078_fix_role_check.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('078', '078_fix_role_check.sql', '1a562031fe32012f389c95b53de7a1a2a4984b4ff8f983a5451f3646f8ab8697', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '079_auth_lookup.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('079', '079_auth_lookup.sql', '042967dee924ddf2a27f1ca096d251ed72f465ed32c7f34cae68d0b5551eed53', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '080_owner_rpcs.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('080', '080_owner_rpcs.sql', '3c28af1e406bffc9107eeb9c00897dde7a00bec4fa62faa765468189b7fc3da0', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '081_fix_toggle_lock.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('081', '081_fix_toggle_lock.sql', 'e32adf8b0d122891af717f435b17a82864a62638918ef18e4ad2e2c59ce4f361', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '082_fix_role_overview.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('082', '082_fix_role_overview.sql', '2d19218cb219a6feda2658aea13118a0f7af5f911a3e699b09a9254898f6f71a', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '083_rls_hardening.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('083', '083_rls_hardening.sql', '4619e577b57855624090dc1d29ce764b08d5eb9c6fdc42212525272680ebb809', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '084_account_lockout.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('084', '084_account_lockout.sql', 'f6cf03fd70fa2cb363e88b6fe676495e6e81d9e7bfd3731332ca43262b315cff', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '086_branding.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('086', '086_branding.sql', 'c36053d79068dd0ffd9722ad1a46fa38ef4616391a24caa1844374aac2867606', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '087_fix_auth_lookup.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('087', '087_fix_auth_lookup.sql', '3aa466a1c64dac6c6708428cac284175fa61044b049f6fd4cbf2c2d9126977a6', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '088_fix_branding_rls_and_auth.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('088', '088_fix_branding_rls_and_auth.sql', 'acb976fc63746313fb07c7824c949282534441a84d4812d27fbd20c4470d7089', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '089_branding_full.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('089', '089_branding_full.sql', '9e5c4d6fd9e63398536b763816c21190854dd193c604171ffd03d353b0aebb4c', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '090_sync_auth_users.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('090', '090_sync_auth_users.sql', '5f41517211ac33999451e9aec6c2f0c9824f949cf126967911f38d6137252ae3', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '091_owner_not_employee.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('091', '091_owner_not_employee.sql', '4e3542fd9cb6291f431241384168b9aff3487eb44d97ffa3d3440ec3bc4a977e', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '092_owner_login.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('092', '092_owner_login.sql', '6e2a85b8b38fac0292b5ed8f49658028b147e1aeeb01c4f488ff78a8815c017c', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '093_fix_owner_context.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('093', '093_fix_owner_context.sql', '9b2fe62d05ce82a42ad5b5439a845f749b3f7523f7b86166a090692fa59cc927', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '095_company_config.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('095', '095_company_config.sql', 'a4bea5e500fa78ac00b42f6c2cd82e41bc97762f13fbfb610be78276efba2553', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '100_owner_wave1.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('100', '100_owner_wave1.sql', '2d3d8386bad99120672d8026fc6b7dc4ce02f40d5b7cbc4eedf178a7dc9a3d96', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '101_owner_wave2.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('101', '101_owner_wave2.sql', '1925855fb48f65fd40071e8a6fd577468ecec6650d2aa79cd4fcddc72c1dec08', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '102_owner_wave3.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('102', '102_owner_wave3.sql', 'd5e05e7e228cc0b27832fe5f145e6c547d08b8cd34f94aee13f9f17d8f4bba60', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '110_owner_admin_architecture.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('110', '110_owner_admin_architecture.sql', 'e0819fe8c266b4dfc6ef5da84df689aa3e5855bcd847f17ecab8917cf42327e2', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '111_owner_security_hardening.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('111', '111_owner_security_hardening.sql', '234e2176203fc9cf77fe1eb2894b2a740ce82af56fdb138f1f942b00473bb566', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '120_seed_admin_accounts.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('120', '120_seed_admin_accounts.sql', '78673b16e1248487c8bf8699851210e693fdd015ee081e250ae70c8488600a77', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '130_fix_missing_rpcs.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('130', '130_fix_missing_rpcs.sql', '32d33c2fb31c82862b73898597e2d87d24b8b6ef3de7c1a659d987b8cfc9af30', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '131_security_idor_fix.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('131', '131_security_idor_fix.sql', 'f8bc57398b4d1908bde94d35aec7a4efa364d9e73890027b132feaa64e9b4309', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '132_admin_bu_filter_and_owner_login.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('132', '132_admin_bu_filter_and_owner_login.sql', 'aad3f470848aafab1bff5de923b7a715ae6e595941c48970fc58c8a38de634a7', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '133_rls_tightening.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('133', '133_rls_tightening.sql', 'f94261797a8357846a3646e08ffe646263249c8aa7a22e1e83ca3250d704ecaa', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '134_authz_architecture_v2.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('134', '134_authz_architecture_v2.sql', 'f6ea8ba65ee72ef8989ef7acf17d1243d75c6a969772213f4886ccd11d6c0ee6', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '135_authz_seed_permissions.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('135', '135_authz_seed_permissions.sql', '8d3007e7f7e8ec4f0ce606e8c6747ae81ceb00d2f78be2cd8c502a1e03d1a358', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '136_authz_migrate_violations.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('136', '136_authz_migrate_violations.sql', '973f9226af44f4df161c73e53293ce478e42bc7d881c3d216c4454f59b47645b', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '137_rls_remaining_tables.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('137', '137_rls_remaining_tables.sql', 'a372f52148c4ee1214a3d3a8538f67b5a92a70ae638fba51497e61448ac6282c', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '138_admin_rls_hardening.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('138', '138_admin_rls_hardening.sql', '1062556e0c35aad10d08a57412021c0b6b062584bc2013ff6540994a36e6837e', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '139_admin_rbac_concurrent_session.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('139', '139_admin_rbac_concurrent_session.sql', '6df817ef34dca49635a5e4e119346d60f012ebbba0cf47e28215a2401636389d', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '140_fix_industry_schema.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('140', '140_fix_industry_schema.sql', '8fcbb7626f693a4513f249fdcb76b406fca3336eaf8aeed9dff6a3160f858428', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '141_153_CONSOLIDATED_.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('141', '141_153_CONSOLIDATED_.sql', '17989aa042163cf15fb08b8ba40680f6b8e931372ffa9b29dbbee79318dfbdab', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '154_pilar2_self_service.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('154', '154_pilar2_self_service.sql', '11ebf76e94fcb4c7511f8116ceda343271af69d6edd87dcf958c43204269a247', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '155_pilar3_platform.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('155', '155_pilar3_platform.sql', '8f50162f7f94bc77c1c84a679e74c913d624b7defa02f72270fdcdb245f790b0', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '156_pilar4_ai.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('156', '156_pilar4_ai.sql', 'cc1d129c006f72594c90107532c0854c9e41c00b95a8b89f2d7e796f4f6178b2', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '157_pilar5_flexibility.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('157', '157_pilar5_flexibility.sql', '822116ebdf2203c1e39341ccc7205ac27ab665dc96484be02a8de03c4b674bd8', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '158_fase1_employees_master_columns.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('158', '158_fase1_employees_master_columns.sql', 'f2bde36cdb49754aad88ecb9af0f9010c616f846ffe36e073a4006ba7f91008c', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '159_fase2_master_data.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('159', '159_fase2_master_data.sql', 'db4e48c2f8dc44d0df884bfd56eb15738cc39d935d37612cd0d7b8eda7ae7616', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '160_fase3_hr_engine.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('160', '160_fase3_hr_engine.sql', '0da6b286c071548dac2f970fa1a13c94691b499aacb92d107264e71113017b7d', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '161_fase4_narrative.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('161', '161_fase4_narrative.sql', 'a8be0d8e1e82e2aae13c39cc983354e7e21b70a6486477745daeaa417628a5ac', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '162_fase5_preview.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('162', '162_fase5_preview.sql', 'cf306ddb1655061ea92f645e3d302e07125643a7dd8fa4fdfaa716cfcb0e219f', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '163_fase6_simulation.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('163', '163_fase6_simulation.sql', '547263c97da8d4e5b8221de0a5e46ef264932ee98199ddac88fe4ed53f3fb85d', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '164_fase7_auth_flow.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('164', '164_fase7_auth_flow.sql', '93689419e61ec4df42f8af7cfd41826a02b06043ff242a52ae05845f15036496', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '165_fase8_bulk_edp_command.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('165', '165_fase8_bulk_edp_command.sql', '6784e49aa6c2e3f4abd77c5c19ae300bcbab1a3b7267059db3e501650a6508d9', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '166_fase9_infrastructure.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('166', '166_fase9_infrastructure.sql', 'a5f61c57cf725bc71e178aa23371bd04bd3d1bba63ced89f611d353bbc103832', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '167_pilar6_monetization.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('167', '167_pilar6_monetization.sql', '86fce1e30e761924e4fa550f2d1ea618c0a1de8a4ff74fa623cb3518c4c4b21d', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '168_fix_p0_p1.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('168', '168_fix_p0_p1.sql', '72d902eb5206c7736d85be71cb63dd0e221e5997291ce99f88c66f69b2b8a8d0', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '169_fix_auth_session_p0.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('169', '169_fix_auth_session_p0.sql', 'bb15bbd7849b6cde7e26e50022f4764f862d13684fb601228f0b9ce4ae867965', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '171_restore_db_only_functions.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('171', '171_restore_db_only_functions.sql', '0639e04b2510ccc0c6436f4fd5bdf0ca2d975d1d0b4d62e0deb4e7bdb56a71d7', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '172_hardening_grants.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('172', '172_hardening_grants.sql', '10f5cc7785cd548d7d52beee866e85ec20393a2ec8f98d8b13b7438de636ca25', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '173_force_rls_gradual.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('173', '173_force_rls_gradual.sql', '71f5cb3db83184abdff2620e3713cdeaeb144f055024d2e1f4122818f005cbc6', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '174_fix_search_path_204.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('174', '174_fix_search_path_204.sql', '989a071a1b8d65635683bf4a9198086f49528bcc6675c04700bc4f52116c67ab', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '175_smoke_tests.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('175', '175_smoke_tests.sql', '7c546c02c470f2424b811e990987170764ddfd29f6c06491beb1e2f3ad3e6213', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '176_fix_rownum_and_pgcrypto_path.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('176', '176_fix_rownum_and_pgcrypto_path.sql', 'b0d9bb4ab217424885a3a3c8a407baa16ba11b7a7d387c0c8743075675fa891e', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '176_fix_search_path_extensions.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('176', '176_fix_search_path_extensions.sql', 'a30ecacca8d24d31803e8a1978b985053d2bfc02e5d46b39e9ecf66fb38e6507', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '177_fix_preexisting_bugs.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('177', '177_fix_preexisting_bugs.sql', '1047548e978b8416e444a18d5900589603d184a91c1db65b259cfd73400e6266', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '178_fix_smoke_test_data.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('178', '178_fix_smoke_test_data.sql', '0e1dca02f57880a2858e344ffedc2b9b129faf0937a261a38c2eb373b7615a08', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '179_fix_payroll_groupby_and_smoke.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('179', '179_fix_payroll_groupby_and_smoke.sql', '1139a76b5377a23dabd9332e190c8479146e764602c4b2a2dcf5bc5be61c2235', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '180_estate_mill_functions.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('180', '180_estate_mill_functions.sql', '8ef15e6b6992a89309b703aef24537b185a9818f60e077c0d43fcc72cdf20058', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '181_fix_estate_mill_columns.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('181', '181_fix_estate_mill_columns.sql', '417ffca4decb5bc1d4e8c7e75a0cfd348ba260f5ae860a431a5cc19b9280b896', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '182_fix_mv_rls.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('182', '182_fix_mv_rls.sql', 'a9a65d38e83c3a6ff29a16f607059f7e80b21dbb7275be2e5cdb578a986f7d54', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '183_split_employees_master.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('183', '183_split_employees_master.sql', '0a85fedc669752705b71837b0570c37b4b5162f36f22e0f89c0d500c048c93bf', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '184_test_q1_q4_security.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('184', '184_test_q1_q4_security.sql', '62f5cb3019161861d67b419b74327c03bec006b87e60f03c887ba5b8d7c5cb43', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '185_dynamic_routes.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('185', '185_dynamic_routes.sql', '8aa0aa56adcb73d6871e36a16ace49c5e22bf98df3cde335137a20bec7c26830', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '186_add_missing_routes.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('186', '186_add_missing_routes.sql', '3713a01f25fe5545625c7115b769001fdbe302932e0fd2fb1e15698a4b7d44b5', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '186_enable_pg_cron_schedules.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('186', '186_enable_pg_cron_schedules.sql', '7495840673f7d524bd5b375731d47ad429efad7172e32029142bd71a01a8bb25', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '187_fix_dynamic_routes_rpc.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('187', '187_fix_dynamic_routes_rpc.sql', '71e806c84cf861f102dc86d38afe34ec1f1207668f88a7cc40f2c426e1dcc0c6', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '188_backfill_dynamic_routes.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('188', '188_backfill_dynamic_routes.sql', '5d11b4a6ee79e92846f3ae640c73ccd4b7f79a124a272cda6d2fffe7b51dcdc9', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '189_fix_admin_business_unit_id.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('189', '189_fix_admin_business_unit_id.sql', '47f12ea257f23b379dbbb9bb26159551fe0be4977755592f4ff4a11e2aa95b30', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '190_fix_admin_get_payroll.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('190', '190_fix_admin_get_payroll.sql', '58f2d4f6ff900be909ac35791b1dc767743f22db0bd794a35e1deba524ae9c93', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '191_fix_approve_rpcs_and_auth_hardening.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('191', '191_fix_approve_rpcs_and_auth_hardening.sql', '7ba063737707237b690b6fbd93726d8e94355932e93ae76e380cba70914a09c6', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '192_fix_auth_schema_drift.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('192', '192_fix_auth_schema_drift.sql', '1c9c6cd3cae39e5bfbc51c6f006a7d2b14e12f7eba3128be60abe6aa3f99667c', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '193_atomic_rate_limit.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('193', '193_atomic_rate_limit.sql', '70351146e40fb283b1e3c1db04e10f005f13a04d89d107cb4e1de7afd98d8c63', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '194_fix_trust_the_client_rpcs.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('194', '194_fix_trust_the_client_rpcs.sql', 'b1be0c8bac0c06a82ee7553e5e09dd61edf2a585d79bb7de72fd260813369ddf', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '195_fix_worker_passwords_reset_required.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('195', '195_fix_worker_passwords_reset_required.sql', 'a398bf9e4086cf347ce313d4344ff9dcf794ad64c4803cda30a96448f08d8e5c', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '196_fix_industrial_rpc_anon_grant.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('196', '196_fix_industrial_rpc_anon_grant.sql', '55898b181a5fc9102cfa50e0b0f6ecaf7ad4c2c9fee0052513dc64635ede7ddb', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '197_fix_route_components.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('197', '197_fix_route_components.sql', 'aef235c0379a6813f24b41f9c032dc731735d9da4ecd3113e99b45b2c737788d', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '198_branding_insightwip.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('198', '198_branding_insightwip.sql', 'ae91ad5f6cf30d241e8df3df9445361ef83d98772f609229d15bfc2d2bfddafb', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '199_auth_testing_override.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('199', '199_auth_testing_override.sql', '277f944ff9f243b08e731c1df2b19ddcb349f72dc08b8c0b893bd3f6345ad562', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '200_owner_testing_override_functions.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('200', '200_owner_testing_override_functions.sql', '979fbc121483eac0cd08f5e4f772b623567f04a1e058b28128bebcdc951711be', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '201_override_bypass_verify.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('201', '201_override_bypass_verify.sql', 'bacab7d41077c0fd1e6ac69c88fcbaafaee24d213098bf368c68a7e2fc71605d', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '202_fix_get_enabled_modules_search_path_and_area.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('202', '202_fix_get_enabled_modules_search_path_and_area.sql', 'b2fdaf6fabd9ae32d35c16e93df007c24a2dea5e82e7bfa6abe6604868130d1d', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '203_fix_admin_get_vacancies.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('203', '203_fix_admin_get_vacancies.sql', '7f5d3b4341f5af7bfa77380f1393965c98c328eab6bbff58bb40d391a20a7d9d', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '204_admin_mill_routes.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('204', '204_admin_mill_routes.sql', '0666c720be0b470838a55a8a55063a76d88edc39ca7176ac84e5c099b073a6a2', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '205_get_enabled_modules_legacy_rename.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('205', '205_get_enabled_modules_legacy_rename.sql', '9736cdebed755858f51a795a4bcfd4c9a385e1a5399f23b5127fb8250b45cd7f', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '206_nik_null_guard.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('206', '206_nik_null_guard.sql', 'fc3871b9de4359d11759661d41eb604b7db6e764fa71826f99af5b20600d206a', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '207_fix_search_path_strays.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('207', '207_fix_search_path_strays.sql', '6b5134c12382660231b0c020ad514cc30e6c094bef0bd0eee68bb11c824376eb', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '208_fix_groupby.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('208', '208_fix_groupby.sql', '43885c3740053ea3ca85bfe7f846b1116d7d9100b93180ab4085370761a52697', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '208_industry_tables_and_rpcs.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('208', '208_industry_tables_and_rpcs.sql', '13e6362f728a1da5de4e7bc9746eb2f668ac2447692f6439d2252cb3a91b79f6', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '209_dead_forms_handlers.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('209', '209_dead_forms_handlers.sql', 'a66cdde7849cfec47b721b3f9f31ab42f64b217293930e4143b10137befb32bd', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '210_revoke_anon_remaining.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('210', '210_revoke_anon_remaining.sql', 'd8a5da4e224b627e224b40b4366a0274df3b3a2f0e9ecf92bcf7e0d00b8cc58b', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '211_employees_master_write_trigger.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('211', '211_employees_master_write_trigger.sql', '3033711df3d88c75dfa2391fb1266bc7005bf47be3447b2674ac4e9e419dc57b', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '212_pg_cron_setup.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('212', '212_pg_cron_setup.sql', '463d906c92f9aa9cfab03321c6235ff496c7a684d291fca2f2867c23a6135e2b', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '213_registration_and_favicon.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('213', '213_registration_and_favicon.sql', 'ebf140c4e9b9cdad1ec3ad059c87d7f344040d2594afa50fef9c9be18b929cc7', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '214_f9_missing_rpcs.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('214', '214_f9_missing_rpcs.sql', 'e31a715a8ae1100a244959e6633c23c1ac61692277c6ad21a699659f1b72c8b7', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '215_ai_rag_access_and_rate_limits.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('215', '215_ai_rag_access_and_rate_limits.sql', '2a6e8e77f7f7a014ccee2a6a3855b728f247c9bc59792fd2e0d08dddfc735624', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '215_gap_employee_fields.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('215', '215_gap_employee_fields.sql', 'ff5a19f1caaf699aa1044c159dc3c7dcfc8283111f15ddfd39cf0387b5ff3da7', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '216_login_worker_by_email.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('216', '216_login_worker_by_email.sql', '93088c63117a6e7971ee3c51ff14ca3db3583c15f9da449ed6e468bda6f34fb8', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '217_drop_deprecated_login_admin.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('217', '217_drop_deprecated_login_admin.sql', '9eba8dbc2d2fa6127d01d09125a2ef977de4925f69151a2eb6544f679bf7a399', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '218_drop_legacy_tables.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('218', '218_drop_legacy_tables.sql', '7e3782266cd10b7a7ba1614b2ca885f43e4eca20253891092145547f0a577c16', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '219_schema_versioning.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('219', '219_schema_versioning.sql', 'f2eba4c350f00d6e37957539bebc441702eb8b445c94e4e1063d877253c5cebf', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '220_audit_hash_chain.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('220', '220_audit_hash_chain.sql', 'b5c499d286988b6b19294e93c5325149abccde58db5593f5592dc0a2cba94e73', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '221_revoke_anon_admin_grants.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('221', '221_revoke_anon_admin_grants.sql', 'e7dc3ef6d92e3890f6900ebdc68fc0cbfd94c176f9aa534debf0223af34170b8', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '222_worker_profile_rpc.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('222', '222_worker_profile_rpc.sql', 'e571ef86513517b9d2087d9d4e4d28774839d9fb0b78004a3a83e16ed2b576e7', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '223_fix_branding_anon_grant.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('223', '223_fix_branding_anon_grant.sql', '873d1b30f1ca07ab18dce601068e0ac3440211549cccc431e2240db35503bf09', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '224_fix_check_migrations_duplicate_rule.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('224', '224_fix_check_migrations_duplicate_rule.sql', '1996175927b31e872db403e4f7457c7e69112b5f12323058c332d3d87fd61c42', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '225_dynamic_attendance_partitions.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('225', '225_dynamic_attendance_partitions.sql', '5434f4be8e11a3e9fdac87abc36b56afa33dc2a60851dbd3207b19d4c7d85a07', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '226_revoke_anon_public_write_rpcs.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('226', '226_revoke_anon_public_write_rpcs.sql', 'b5eb77530030982247266c9a3c4235c7e8d78208f7dbaf9f384e44d1f5e5f40b', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '227_attendance_partition_rls_force.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('227', '227_attendance_partition_rls_force.sql', '05a4a435691a842542889776aec84b5f741ea64a94b1e904705b22a45472fa99', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '228_retire_dead_mv_cache_layer.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('228', '228_retire_dead_mv_cache_layer.sql', '165726179286bd6e050cbf6ee94fff511f91e3386ac89a9ef5ebdcce4fac9553', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '229_fresh_install_fk_repair.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('229', '229_fresh_install_fk_repair.sql', '8cf40c1f188c1f46a76e4862cc3b0467af347ca432b5efe2324a22213c9c6e25', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '230_owner_email_fail_closed.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('230', '230_owner_email_fail_closed.sql', 'd517f702bac351f0cbbee0aee39ba32d3caacf777dd7ef6ececeae1ba128b6e1', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '231_apply_missing_effects.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('231', '231_apply_missing_effects.sql', 'fa827ea4bcea3ba2601d81cf36615b255c806570b8f824de917ffa67c732d470', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '232_revoke_anon_inherited_grants.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('232', '232_revoke_anon_inherited_grants.sql', '0bd2492e5b1deaf82160a491745a9aeaf6822b79ac875951d77aeb2054603f54', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '233_reapply_226c_intended_revokes.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('233', '233_reapply_226c_intended_revokes.sql', '6136222403da8a9f9bd14266e98636555573f25f451aa76a76d25c3949a510da', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '236_sql04_fix_hr_okrs.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('236', '236_sql04_fix_hr_okrs.sql', '171e330ca070985c8b931531036c650d5c4df6cb02e9bc717aea481496032a4d', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '237_sql05_fix_rls_policies.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('237', '237_sql05_fix_rls_policies.sql', '26f9b0530ffc5cfe273eeaf14bff8cf21f9fcfdc2af7dcd5cc3220eb4c873824', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '238_sql07_fix_default_privileges.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('238', '238_sql07_fix_default_privileges.sql', '2b6200c74992da909982e2caa3f287d4ef18fff9e0dd2efd0caf2f4af187677e', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '239_sql09_fix_duplicate_create.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('239', '239_sql09_fix_duplicate_create.sql', 'e5ff565457f5da2e5f7a96b2375bb1fdc26e40efd489aabb7c960328f4c088b2', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '240_drop_hr_attendance_partitioned.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('240', '240_drop_hr_attendance_partitioned.sql', 'a3d394b75f82efd59cfa2d88a349a94af6059b914f28843223715a5bf2ede961', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '241_sql11_apply_missing_effects.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('241', '241_sql11_apply_missing_effects.sql', '203eca23160979640ade1044edf2e6f7e9c6be9ec3e5913a18beb8899c10510a', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '242_sql13_deactivate_dashboard_landing.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('242', '242_sql13_deactivate_dashboard_landing.sql', '64572d62bfd0fcdd840682b47c0268ae967143f3a60baaf2cc506807714d57f5', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '243_sql02_drop_legacy_functions.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('243', '243_sql02_drop_legacy_functions.sql', '2a5632ddba362f469d78ce779a875a497c65c784fd92f30197c3803e79e0704b', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '244_sql12_fix_coalesce.sql') THEN
    INSERT INTO public.schema_migrations (version, filename, checksum, description)
    VALUES ('244', '244_sql12_fix_coalesce.sql', 'b421600b1bb5e8c7ec60ffa2922493a9069bedc2f9f8bb096205ebbaf2adb10f', 'baseline install (schema dari DB live)');
    v_n := v_n + 1;
  END IF;
  RAISE NOTICE 'schema_migrations: % baris baru dicap', v_n;
END $$;

-- ── VERIFIKASI ──────────────────────────────────────────────────
--   select count(*) from information_schema.tables where table_schema='public';
--   select count(*) from public.module_definitions;        -- > 0 = menu hidup
--   select count(*) from public.schema_migrations;
--   select public.check_migrations();

