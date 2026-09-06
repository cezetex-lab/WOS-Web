-- ================================================================
-- 185_dynamic_routes.sql
-- Make routes fully dynamic from module_definitions (no hardcode)
-- Adds route_path + route_component columns, seeds all 61 modules
-- ================================================================

-- Step 1: Add columns
ALTER TABLE module_definitions ADD COLUMN IF NOT EXISTS route_path TEXT;
ALTER TABLE module_definitions ADD COLUMN IF NOT EXISTS route_component TEXT;
ALTER TABLE module_definitions ADD COLUMN IF NOT EXISTS route_group TEXT DEFAULT 'worker';
-- route_group: 'worker' | 'admin' | 'owner' | 'public'

-- Step 2: Seed route_path for all active modules
-- CORE
UPDATE module_definitions SET route_path='/worker/profile', route_component='WorkerProfile', route_group='worker' WHERE module_code='profile';
UPDATE module_definitions SET route_path='/worker/attendance', route_component='WorkerAttendance', route_group='worker' WHERE module_code='attendance';
UPDATE module_definitions SET route_path='/worker/leave', route_component='WorkerLeave', route_group='worker' WHERE module_code='leave';
UPDATE module_definitions SET route_path='/worker/overtime', route_component='WorkerOvertime', route_group='worker' WHERE module_code='overtime';
UPDATE module_definitions SET route_path='/worker/payroll', route_component='WorkerPayroll', route_group='worker' WHERE module_code='payroll';
UPDATE module_definitions SET route_path='/worker/tasks', route_component='TaskBoard', route_group='worker' WHERE module_code='self_service';
UPDATE module_definitions SET route_path='/worker/kpi', route_component='WorkerKpi', route_group='worker' WHERE module_code='kpi';
UPDATE module_definitions SET route_path='/worker/learning', route_component='WorkerLearning', route_group='worker' WHERE module_code='learning';
UPDATE module_definitions SET route_path='/worker/review-360', route_component='WorkerReview360', route_group='worker' WHERE module_code='360_review';
UPDATE module_definitions SET route_path='/worker/career', route_component='WorkerCareer', route_group='worker' WHERE module_code='career_path';
UPDATE module_definitions SET route_path='/worker/badges', route_component='BadgesPage', route_group='worker' WHERE module_code='badges';
UPDATE module_definitions SET route_path='/worker/referral', route_component='ReferralPage', route_group='worker' WHERE module_code='referral';

-- CORE — Admin routes
UPDATE module_definitions SET route_path='/admin/kpi', route_component='Kpi', route_group='admin' WHERE module_code='kpi';
UPDATE module_definitions SET route_path='/admin/performance', route_component='PerformanceNotes', route_group='admin' WHERE module_code='performance';
UPDATE module_definitions SET route_path='/admin/talent', route_component='TalentMarketPage', route_group='admin' WHERE module_code='talent';
UPDATE module_definitions SET route_path='/admin/succession', route_component='SuccessionPlanning', route_group='admin' WHERE module_code='succession';
UPDATE module_definitions SET route_path='/admin/recruitment', route_component='RecruitmentDashboard', route_group='admin' WHERE module_code='recruitment';
UPDATE module_definitions SET route_path='/admin/onboarding', route_component='OnboardingWorkflow', route_group='admin' WHERE module_code='onboarding';
UPDATE module_definitions SET route_path='/admin/exit', route_component='Offboarding', route_group='admin' WHERE module_code='offboarding';
UPDATE module_definitions SET route_path='/admin/engagement', route_component='SurveyPage', route_group='admin' WHERE module_code='engagement';
UPDATE module_definitions SET route_path='/admin/voice', route_component='VoiceIdeasPage', route_group='admin' WHERE module_code='voice_ideas';
UPDATE module_definitions SET route_path='/admin/certifications', route_component='CertificationsPage', route_group='admin' WHERE module_code='certifications';

-- INTELLIGENCE
UPDATE module_definitions SET route_path='/dashboard', route_component='Dashboard', route_group='admin' WHERE module_code='ceo_dashboard';
UPDATE module_definitions SET route_path='/admin/analytics', route_component='Analytics', route_group='admin' WHERE module_code='analytics';
UPDATE module_definitions SET route_path='/admin/workforce', route_component='HeadcountPage', route_group='admin' WHERE module_code='workforce_planning';
UPDATE module_definitions SET route_path='/admin/simulation', route_component='WorkforceSimulation', route_group='admin' WHERE module_code='simulation';
UPDATE module_definitions SET route_path='/admin/turnover', route_component='TurnoverPrediction', route_group='admin' WHERE module_code='turnover';
UPDATE module_definitions SET route_path='/admin/flight-risk', route_component='TurnoverPrediction', route_group='admin' WHERE module_code='flight_risk';
UPDATE module_definitions SET route_path='/admin/narrative', route_component='Analytics', route_group='admin' WHERE module_code='narrative';

-- PLATFORM
UPDATE module_definitions SET route_path='/admin/org', route_component='OrgChart', route_group='admin' WHERE module_code='org_structure';
UPDATE module_definitions SET route_path='/admin/divisions', route_component='DivisionsManagement', route_group='admin' WHERE module_code='divisions';
UPDATE module_definitions SET route_path='/admin/approvals', route_component='ApprovalCenter', route_group='admin' WHERE module_code='approvals';
UPDATE module_definitions SET route_path='/admin/audit', route_component='AuditLog', route_group='admin' WHERE module_code='audit_log';
UPDATE module_definitions SET route_path='/admin/settings', route_component='Settings', route_group='admin' WHERE module_code='settings';
UPDATE module_definitions SET route_path='/admin/export', route_component='ExportPage', route_group='admin' WHERE module_code='export_data';
UPDATE module_definitions SET route_path='/admin/announcements', route_component='SurveyPage', route_group='admin' WHERE module_code='announcements';
UPDATE module_definitions SET route_path='/worker/whistleblowing', route_component='WhistleblowingPage', route_group='worker' WHERE module_code='whistleblowing';
UPDATE module_definitions SET route_path='/admin/mfa', route_component='MfaSetup', route_group='admin' WHERE module_code='mfa';
UPDATE module_definitions SET route_path='/admin/modules', route_component='ModuleManagement', route_group='admin' WHERE module_code='module_management';

-- GOVERNANCE
UPDATE module_definitions SET route_path='/admin/safety', route_component='SafetyK3', route_group='admin' WHERE module_code='safety';
UPDATE module_definitions SET route_path='/admin/qhse', route_component='SafetyK3', route_group='admin' WHERE module_code='qhse';

-- MINING
UPDATE module_definitions SET route_path='/worker/simper', route_component='SimperPage', route_group='worker' WHERE module_code='mining_simper';
UPDATE module_definitions SET route_path='/worker/heavy-equip', route_component='HeavyEquipment', route_group='worker' WHERE module_code='mining_equipment';
UPDATE module_definitions SET route_path='/worker/production', route_component='ProductionDaily', route_group='worker' WHERE module_code='mining_production';
UPDATE module_definitions SET route_path='/worker/fuel', route_component='ProductionDaily', route_group='worker' WHERE module_code='mining_fuel';
UPDATE module_definitions SET route_path='/worker/fatigue', route_component='FatigueMonitor', route_group='worker' WHERE module_code='mining_fatigue';
UPDATE module_definitions SET route_path='/worker/safety', route_component='SafetyK3', route_group='worker' WHERE module_code='mining_safety';
UPDATE module_definitions SET route_path='/worker/jsa', route_component='JobSafetyAnalysis', route_group='worker' WHERE module_code='mining_jsa';

-- ESTATE
UPDATE module_definitions SET route_path='/worker/harvest', route_component='HarvestRecord', route_group='worker' WHERE module_code='estate_harvest';
UPDATE module_definitions SET route_path='/worker/blocks', route_component='BlockManagement', route_group='worker' WHERE module_code='estate_blocks';
UPDATE module_definitions SET route_path='/worker/irrigation', route_component='IrrigationPage', route_group='worker' WHERE module_code='estate_irrigation';
UPDATE module_definitions SET route_path='/worker/nursery', route_component='NurseryPage', route_group='worker' WHERE module_code='estate_nursery';
UPDATE module_definitions SET route_path='/worker/transport', route_component='TransportTBS', route_group='worker' WHERE module_code='estate_transport';
UPDATE module_definitions SET route_path='/worker/field', route_component='FacilityRequest', route_group='worker' WHERE module_code='estate_field';
UPDATE module_definitions SET route_path='/worker/yield', route_component='ProductionDaily', route_group='worker' WHERE module_code='estate_yield';

-- MILL
UPDATE module_definitions SET route_path='/worker/boiler', route_component='BoilerMonitor', route_group='worker' WHERE module_code='mill_boiler';
UPDATE module_definitions SET route_path='/worker/machines', route_component='MesinPress', route_group='worker' WHERE module_code='mill_press';
UPDATE module_definitions SET route_path='/worker/qc', route_component='QcLab', route_group='worker' WHERE module_code='mill_qc';
UPDATE module_definitions SET route_path='/worker/packing', route_component='PackingLog', route_group='worker' WHERE module_code='mill_packing';
UPDATE module_definitions SET route_path='/worker/maintenance', route_component='PreventiveMaintenance', route_group='worker' WHERE module_code='mill_maintenance';
UPDATE module_definitions SET route_path='/worker/breakdown', route_component='BreakdownLog', route_group='worker' WHERE module_code='mill_breakdown';
UPDATE module_definitions SET route_path='/worker/shift', route_component='MillShiftSchedule', route_group='worker' WHERE module_code='mill_shift';

-- Verify
SELECT module_code, route_path, route_component, route_group
FROM module_definitions WHERE is_active=true AND route_path IS NOT NULL
ORDER BY menu_order;
