/**
 * route-config.js — Maps route_component names (from module_definitions) to lazy-loaded React components.
 *
 * This is the SINGLE SOURCE OF TRUTH for which component renders at which route.
 * The DB (module_definitions.route_component) references component names defined here.
 *
 * To add a new module:
 * 1. Add the component lazy import below
 * 2. Add entry to COMPONENT_MAP
 * 3. INSERT into module_definitions with route_path + route_component
 *    → No App.jsx changes needed!
 */
import { lazy } from 'react';

// ── Lazy imports ──────────────────────────────────────────────

// Core pages
const WorkerProfile = lazy(() => import('../features/core/people/WorkerProfile'));
const WorkerAttendance = lazy(() => import('../features/core/attendance/WorkerAttendance'));
const WorkerLeave = lazy(() => import('../features/core/leave/WorkerLeave'));
const WorkerOvertime = lazy(() => import('../features/core/overtime/WorkerOvertime'));
const WorkerPayroll = lazy(() => import('../features/core/payroll/WorkerPayroll'));
const WorkerKpi = lazy(() => import('../features/core/performance/WorkerKpi'));
const WorkerLearning = lazy(() => import('../features/core/learning/WorkerLearning'));
const WorkerReview360 = lazy(() => import('../features/core/performance/WorkerReview360'));
const WorkerCareer = lazy(() => import('../features/core/talent/WorkerCareer'));
const WorkerActivities = lazy(() => import('../features/core/workforce/WorkerActivities'));
const TaskBoard = lazy(() => import('../features/core/workforce/TaskBoard'));

// Admin — Data
const Employees = lazy(() => import('../features/core/people/Employees'));
const OrgChart = lazy(() => import('../features/core/organization/OrgChart'));
const OrgSubtree = lazy(() => import('../features/core/organization/OrgSubtree'));
const DivisionsManagement = lazy(() => import('../features/core/organization/DivisionsManagement'));
const MasterDataPage = lazy(() => import('../features/core/organization/MasterDataPage'));
const RoleMatrixPage = lazy(() => import('../features/platform/authorization/RoleMatrixPage'));

// Admin — HR
const RequestsList = lazy(() => import('../features/platform/workflow/RequestsList'));
const LeaveManagement = lazy(() => import('../features/core/leave/LeaveManagement'));
const OvertimeManagement = lazy(() => import('../features/core/overtime/OvertimeManagement'));
const Payroll = lazy(() => import('../features/core/payroll/Payroll'));
const TimesheetPage = lazy(() => import('../features/core/workforce/TimesheetPage'));
const TimesheetManagement = lazy(() => import('../features/core/attendance/TimesheetManagement'));
const ShiftSchedule = lazy(() => import('../features/core/workforce/ShiftSchedule'));
const ApprovalCenter = lazy(() => import('../features/platform/workflow/ApprovalCenter'));

// Admin — Talent & Performance
const Kpi = lazy(() => import('../features/core/performance/Kpi'));
const IncentiveCalc = lazy(() => import('../features/core/payroll/IncentiveCalc'));
const Okrs = lazy(() => import('../features/core/performance/Okrs'));
const LearningManagement = lazy(() => import('../features/core/learning/LearningManagement'));
const CertificationsPage = lazy(() => import('../features/core/talent/CertificationsPage'));
const BadgesPage = lazy(() => import('../features/core/talent/BadgesPage'));
const TalentMarketPage = lazy(() => import('../features/core/talent/TalentMarketPage'));
const CareerPathPage = lazy(() => import('../features/core/career/CareerPathPage'));
const SuccessionPlanning = lazy(() => import('../features/core/career/SuccessionPlanning'));
const CareerDevelopment = lazy(() => import('../features/core/career/CareerDevelopment'));
const AdminAttendance = lazy(() => import('../features/core/attendance/AdminAttendance'));
const PerformanceTrend = lazy(() => import('../features/core/performance/PerformanceTrend'));
const CompensationIntel = lazy(() => import('../features/core/payroll/CompensationIntel'));
const ContinuousPerf = lazy(() => import('../features/core/performance/ContinuousPerf'));
const TrainingForm = lazy(() => import('../features/core/learning/TrainingForm'));
const PerformanceNotes = lazy(() => import('../features/core/performance/PerformanceNotes'));
const Review360 = lazy(() => import('../features/core/performance/Review360'));

// Admin — Assets
const AssetManagement = lazy(() => import('../features/industry/mill/AssetManagement'));

// Admin — Engagement
const SurveyPage = lazy(() => import('../features/core/engagement/SurveyPage'));
const VoiceIdeasPage = lazy(() => import('../features/core/engagement/VoiceIdeasPage'));
const WhistleblowingPage = lazy(() => import('../features/core/engagement/WhistleblowingPage'));
const ForumDiskusi = lazy(() => import('../features/core/engagement/ForumDiskusi'));

// Admin — Offboarding
const Offboarding = lazy(() => import('../features/core/offboarding/Offboarding'));

// Admin — System
const AuditLog = lazy(() => import('../features/governance/audit/AuditLog'));
const AuditChainPage = lazy(() => import('../features/governance/audit/AuditChainPage'));
const ExportPage = lazy(() => import('../features/platform/exports/ExportPage'));
const FeatureFlagsPage = lazy(() => import('../features/platform/settings/FeatureFlagsPage'));
const Settings = lazy(() => import('../features/platform/settings/Settings'));
const ModuleManagement = lazy(() => import('../features/platform/configuration/pages/ModuleManagement'));
const Analytics = lazy(() => import('../features/intelligence/analytics/Analytics'));
const Integrations = lazy(() => import('../features/platform/integrations/Integrations'));
const WorkforceSimulation = lazy(() => import('../features/intelligence/forecasting/WorkforceSimulation'));
const TurnoverPrediction = lazy(() => import('../features/intelligence/forecasting/TurnoverPrediction'));
const ResetPassword = lazy(() => import('../features/platform/auth/ResetPassword'));
const MfaSetup = lazy(() => import('../features/platform/auth/MfaSetup'));
const RecruitmentDashboard = lazy(() => import('../features/core/recruitment/RecruitmentDashboard'));
const PipelineKanban = lazy(() => import('../features/core/recruitment/PipelineKanban'));
const OnboardingWorkflow = lazy(() => import('../features/core/recruitment/OnboardingWorkflow'));
const ScreeningPage = lazy(() => import('../features/core/recruitment/ScreeningPage'));
const ApprovalWorkflow = lazy(() => import('../features/platform/workflow/ApprovalWorkflow'));
const MultiStepRequest = lazy(() => import('../features/platform/workflow/MultiStepRequest'));

// Admin — Planning
const HeadcountPage = lazy(() => import('../features/governance/compliance/HeadcountPage'));
const BudgetPage = lazy(() => import('../features/governance/compliance/BudgetPage'));
const ReferralPage = lazy(() => import('../features/core/people/ReferralPage'));

// Industry — Mill
const BoilerMonitor = lazy(() => import('../features/industry/mill/BoilerMonitor'));
const MesinPress = lazy(() => import('../features/industry/mill/MesinPress'));
const QcLab = lazy(() => import('../features/industry/mill/QcLab'));
const PackingLog = lazy(() => import('../features/industry/mill/PackingLog'));
const PreventiveMaintenance = lazy(() => import('../features/industry/mill/PreventiveMaintenance'));
const BreakdownLog = lazy(() => import('../features/industry/mill/BreakdownLog'));
const MillShiftSchedule = lazy(() => import('../features/industry/mill/ShiftSchedule'));

// Industry — Mining
const SimperPage = lazy(() => import('../features/industry/mining/SimperPage'));
const HeavyEquipment = lazy(() => import('../features/industry/mining/HeavyEquipment'));
const FatigueMonitor = lazy(() => import('../features/industry/mining/FatigueMonitor'));
const ProductionDaily = lazy(() => import('../features/industry/mining/ProductionDaily'));
const SafetyK3 = lazy(() => import('../features/industry/mining/SafetyK3'));
const EmergencyProcedures = lazy(() => import('../features/industry/mining/EmergencyProcedures'));
const JobSafetyAnalysis = lazy(() => import('../features/industry/mining/JobSafetyAnalysis'));

// Industry — Estate
const HarvestRecord = lazy(() => import('../features/industry/estate/HarvestRecord'));
const BlockManagement = lazy(() => import('../features/industry/estate/BlockManagement'));
const TransportTBS = lazy(() => import('../features/industry/estate/TransportTBS'));
const NurseryPage = lazy(() => import('../features/industry/estate/Nursery'));
const IrrigationPage = lazy(() => import('../features/industry/estate/Irrigation'));
const FacilityRequest = lazy(() => import('../features/industry/estate/FacilityRequest'));
const MedicalCheckup = lazy(() => import('../features/industry/estate/MedicalCheckup'));

// Industry — Admin Dashboards
const MiningAdminDashboard = lazy(() => import('../features/industry/mining/MiningAdminDashboard'));
const EstateAdminDashboard = lazy(() => import('../features/industry/estate/EstateAdminDashboard'));
const MillAdminDashboard = lazy(() => import('../features/industry/mill/MillAdminDashboard'));

// Dashboard
const Dashboard = lazy(() => import('../pages/Dashboard'));


// ── Component Map ─────────────────────────────────────────────
// Keys match module_definitions.route_component values in DB.

export const COMPONENT_MAP = {
  // Core — Worker
  WorkerProfile,
  WorkerAttendance,
  WorkerLeave,
  WorkerOvertime,
  WorkerPayroll,
  WorkerKpi,
  WorkerLearning,
  WorkerReview360,
  WorkerCareer,
  WorkerActivities,
  TaskBoard,

  // Core — Admin
  Employees,
  OrgChart,
  OrgSubtree,
  DivisionsManagement,
  MasterDataPage,
  RoleMatrixPage,
  RequestsList,
  LeaveManagement,
  OvertimeManagement,
  Payroll,
  TimesheetPage,
  TimesheetManagement,
  ShiftSchedule,
  ApprovalCenter,

  // Talent & Performance
  Kpi,
  IncentiveCalc,
  Okrs,
  LearningManagement,
  CertificationsPage,
  BadgesPage,
  TalentMarketPage,
  CareerPathPage,
  SuccessionPlanning,
  CareerDevelopment,
  AdminAttendance,
  PerformanceTrend,
  CompensationIntel,
  ContinuousPerf,
  TrainingForm,
  PerformanceNotes,
  Review360,

  // Assets
  AssetManagement,

  // Engagement
  SurveyPage,
  VoiceIdeasPage,
  WhistleblowingPage,
  ForumDiskusi,

  // Offboarding
  Offboarding,

  // System
  AuditLog,
  AuditChainPage,
  ExportPage,
  FeatureFlagsPage,
  Settings,
  ModuleManagement,
  Analytics,
  Integrations,
  WorkforceSimulation,
  TurnoverPrediction,
  ResetPassword,
  MfaSetup,
  RecruitmentDashboard,
  PipelineKanban,
  OnboardingWorkflow,
  ScreeningPage,
  ApprovalWorkflow,
  MultiStepRequest,

  // Planning
  HeadcountPage,
  BudgetPage,
  ReferralPage,

  // Industry — Mill
  BoilerMonitor,
  MesinPress,
  QcLab,
  PackingLog,
  PreventiveMaintenance,
  BreakdownLog,
  MillShiftSchedule,

  // Industry — Mining
  SimperPage,
  HeavyEquipment,
  FatigueMonitor,
  ProductionDaily,
  SafetyK3,
  EmergencyProcedures,
  JobSafetyAnalysis,

  // Industry — Estate
  HarvestRecord,
  BlockManagement,
  TransportTBS,
  NurseryPage,
  IrrigationPage,
  FacilityRequest,
  MedicalCheckup,

  // Industry — Admin Dashboards
  MiningAdminDashboard,
  EstateAdminDashboard,
  MillAdminDashboard,

  // Dashboard
  Dashboard,
};

/**
 * Get component by name from DB route_component field.
 * Returns null if not found (falls back to 404 or default page).
 */
export function getComponent(name) {
  return COMPONENT_MAP[name] || null;
}
