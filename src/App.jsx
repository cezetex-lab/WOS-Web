// src/App.jsx — Lazy-loaded for code splitting
import React, { useState, lazy } from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { Layout } from './components/Layout';
import { AppDrawer } from './components/AppDrawer';
import { BottomNav } from './components/BottomNav';
import OfflineIndicator from './components/OfflineIndicator';
import LazyLoad from './components/LazyLoad';
import PrivacyConsent from './components/PrivacyConsent';

// Core pages (keep eager — loaded on every visit)
import Home from './pages/Home';

// Lazy-loaded pages — loaded only when route is visited
const Worker = lazy(() => import('./pages/Worker'));
const Admin = lazy(() => import('./pages/Admin'));
const Dashboard = lazy(() => import('./pages/Dashboard'));

// ── ADMIN KELOLA DATA ──
const Employees = lazy(() => import('./features/core/people/Employees'));
const OrgSubtree = lazy(() => import('./features/core/organization/OrgSubtree'));
const OrgChart = lazy(() => import('./features/core/organization/OrgChart'));
const DivisionsManagement = lazy(() => import('./features/core/organization/DivisionsManagement'));
const MasterDataPage = lazy(() => import('./features/core/organization/MasterDataPage'));
const RoleMatrixPage = lazy(() => import('./features/platform/authorization/RoleMatrixPage'));

// ── ADMIN OPERASIONAL ──
const RequestsList = lazy(() => import('./features/platform/workflow/RequestsList'));
const LeaveManagement = lazy(() => import('./features/core/leave/LeaveManagement'));
const OvertimeManagement = lazy(() => import('./features/core/overtime/OvertimeManagement'));
const Payroll = lazy(() => import('./features/core/payroll/Payroll'));
const TimesheetPage = lazy(() => import('./features/core/workforce/TimesheetPage'));
const ShiftSchedule = lazy(() => import('./features/core/workforce/ShiftSchedule'));
const ApprovalCenter = lazy(() => import('./features/platform/workflow/ApprovalCenter'));

// ── ADMIN TALENT & PERFORMANCE ──
const Kpi = lazy(() => import('./features/core/performance/Kpi'));
const IncentiveCalc = lazy(() => import('./features/core/payroll/IncentiveCalc'));
const Okrs = lazy(() => import('./features/core/performance/Okrs'));
const LearningManagement = lazy(() => import('./features/core/learning/LearningManagement'));
const CertificationsPage = lazy(() => import('./features/core/talent/CertificationsPage'));
const BadgesPage = lazy(() => import('./features/core/talent/BadgesPage'));
const TalentMarketPage = lazy(() => import('./features/core/talent/TalentMarketPage'));
const CareerPathPage = lazy(() => import('./features/core/talent/CareerPathPage'));

// ── ADMIN ASET ──
const AssetManagement = lazy(() => import('./features/industry/mill/AssetManagement'));

// ── ADMIN ENGAGEMENT ──
const SurveyPage = lazy(() => import('./features/core/engagement/SurveyPage'));
const VoiceIdeasPage = lazy(() => import('./features/core/engagement/VoiceIdeasPage'));
const WhistleblowingPage = lazy(() => import('./features/core/engagement/WhistleblowingPage'));

// ── ADMIN OFFBOARDING ──
const Offboarding = lazy(() => import('./features/core/people/Offboarding'));

// ── ADMIN SISTEM ──
const AuditLog = lazy(() => import('./features/governance/audit/AuditLog'));
const ExportPage = lazy(() => import('./features/platform/exports/ExportPage'));
const FeatureFlagsPage = lazy(() => import('./features/platform/settings/FeatureFlagsPage'));
const Settings = lazy(() => import('./features/platform/settings/Settings'));
const Analytics = lazy(() => import('./features/intelligence/analytics/Analytics'));
const AuditChainPage = lazy(() => import('./features/governance/audit/AuditChainPage'));

// ── ADMIN INTEGRASI & ANALYTICS ──
const Integrations = lazy(() => import('./features/platform/integrations/Integrations'));
const WorkforceSimulation = lazy(() => import('./features/intelligence/forecasting/WorkforceSimulation'));
const TurnoverPrediction = lazy(() => import('./features/intelligence/forecasting/TurnoverPrediction'));
const ResetPassword = lazy(() => import('./features/platform/auth/ResetPassword'));

// ── ADMIN PERENCANAAN ──
const HeadcountPage = lazy(() => import('./features/governance/compliance/HeadcountPage'));
const BudgetPage = lazy(() => import('./features/governance/compliance/BudgetPage'));
const ReferralPage = lazy(() => import('./features/core/people/ReferralPage'));

// ── WORKER ──
const WorkerProfile = lazy(() => import('./features/core/people/WorkerProfile'));
const WorkerOvertime = lazy(() => import('./features/core/overtime/WorkerOvertime'));
const WorkerAttendance = lazy(() => import('./features/core/attendance/WorkerAttendance'));
const WorkerLearning = lazy(() => import('./features/core/learning/WorkerLearning'));
const WorkerKpi = lazy(() => import('./features/core/performance/WorkerKpi'));
const WorkerPayroll = lazy(() => import('./features/core/payroll/WorkerPayroll'));
const WorkerCareer = lazy(() => import('./features/core/talent/WorkerCareer'));
const WorkerActivities = lazy(() => import('./features/core/workforce/WorkerActivities'));

// MILL/PKS Modules
const BoilerMonitor = lazy(() => import('./features/industry/mill/BoilerMonitor'));
const MesinPress = lazy(() => import('./features/industry/mill/MesinPress'));
const QcLab = lazy(() => import('./features/industry/mill/QcLab'));
const PackingLog = lazy(() => import('./features/industry/mill/PackingLog'));
const PreventiveMaintenance = lazy(() => import('./features/industry/mill/PreventiveMaintenance'));
const BreakdownLog = lazy(() => import('./features/industry/mill/BreakdownLog'));
const MillShiftSchedule = lazy(() => import('./features/industry/mill/ShiftSchedule'));
// MINING Modules
const SimperPage = lazy(() => import('./features/industry/mining/SimperPage'));
const HeavyEquipment = lazy(() => import('./features/industry/mining/HeavyEquipment'));
const FatigueMonitor = lazy(() => import('./features/industry/mining/FatigueMonitor'));
const ProductionDaily = lazy(() => import('./features/industry/mining/ProductionDaily'));
const SafetyK3 = lazy(() => import('./features/industry/mining/SafetyK3'));
const EmergencyProcedures = lazy(() => import('./features/industry/mining/EmergencyProcedures'));
const JobSafetyAnalysis = lazy(() => import('./features/industry/mining/JobSafetyAnalysis'));

// ESTATE Modules
const HarvestRecord = lazy(() => import('./features/industry/estate/HarvestRecord'));
const BlockManagement = lazy(() => import('./features/industry/estate/BlockManagement'));
const TransportTBS = lazy(() => import('./features/industry/estate/TransportTBS'));
const NurseryPage = lazy(() => import('./features/industry/estate/Nursery'));
const IrrigationPage = lazy(() => import('./features/industry/estate/Irrigation'));
const FacilityRequest = lazy(() => import('./features/industry/estate/FacilityRequest'));
const MedicalCheckup = lazy(() => import('./features/industry/estate/MedicalCheckup'));

const WorkerChangePassword = lazy(() => import('./features/platform/auth/WorkerChangePassword'));
const PerformanceTrend = lazy(() => import('./features/core/performance/PerformanceTrend'));
const CompensationIntel = lazy(() => import('./features/intelligence/analytics/CompensationIntel'));
const ContinuousPerf = lazy(() => import('./features/core/performance/ContinuousPerf'));
const TrainingForm = lazy(() => import('./features/core/learning/TrainingForm'));
const PerformanceNotes = lazy(() => import('./features/core/performance/PerformanceNotes'));

// ── WAVE 4 ──
const MultiStepRequest = lazy(() => import('./features/platform/workflow/MultiStepRequest'));
const TaskBoard = lazy(() => import('./features/core/workforce/TaskBoard'));
// ── WAVE FINAL — Recruitment, Approval, 360, Forum ──
const RecruitmentDashboard = lazy(() => import('./features/core/people/RecruitmentDashboard'));
const PipelineKanban = lazy(() => import('./features/core/people/PipelineKanban'));
const OnboardingWorkflow = lazy(() => import('./features/core/people/OnboardingWorkflow'));
const ScreeningPage = lazy(() => import('./features/core/people/ScreeningPage'));
const ApprovalWorkflow = lazy(() => import('./features/platform/workflow/ApprovalWorkflow'));
const Review360 = lazy(() => import('./features/core/performance/Review360'));
const ForumDiskusi = lazy(() => import('./features/core/engagement/ForumDiskusi'));

function AppContent() {
  const [isDrawerOpen, setDrawerOpen] = useState(false);
  const toggleDrawer = () => setDrawerOpen(!isDrawerOpen);
  const closeDrawer = () => setDrawerOpen(false);

  const withNav = (Component, props) => (
    <Layout>
      <LazyLoad>
        <Component {...props} />
      </LazyLoad>
      <BottomNav onMenuClick={toggleDrawer} />
      <AppDrawer isOpen={isDrawerOpen} onClose={closeDrawer} />
    </Layout>
  );

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 text-white font-sans antialiased">
      <OfflineIndicator />
      <PrivacyConsent />
      <Routes>
        {/* LOGIN */}
        <Route path="/" element={<Home />} />

        {/* ═══════════ WORKER ═══════════ */}
        <Route path="/worker" element={withNav(Worker)} />
        <Route path="/worker/attendance" element={withNav(WorkerAttendance)} />
        <Route path="/worker/leave" element={withNav(WorkerLearning)} />
        <Route path="/worker/overtime" element={withNav(WorkerOvertime)} />
        <Route path="/worker/kpi" element={withNav(WorkerKpi)} />
        <Route path="/worker/payroll" element={withNav(WorkerPayroll)} />
        <Route path="/worker/learning" element={withNav(WorkerLearning)} />
        <Route path="/worker/career" element={withNav(WorkerCareer)} />
        <Route path="/worker/tasks" element={withNav(TaskBoard)} />
        <Route path="/worker/profile" element={withNav(WorkerProfile)} />
        <Route path="/worker/activities" element={withNav(WorkerActivities)} />
        <Route path="/worker/perf-trend" element={withNav(PerformanceTrend)} />
        <Route path="/worker/compensation" element={withNav(CompensationIntel)} />
        <Route path="/worker/continuous-perf" element={withNav(ContinuousPerf)} />
        <Route path="/worker/training" element={withNav(TrainingForm)} />
        <Route path="/worker/request" element={withNav(MultiStepRequest)} />
        <Route path="/worker/task-board" element={withNav(TaskBoard)} />
        <Route path="/worker/performance-notes" element={withNav(PerformanceNotes)} />
        <Route path="/worker/change-password" element={withNav(WorkerChangePassword)} />
        <Route path="/worker/forum" element={withNav(ForumDiskusi)} />

        {/* MILL/PKS Routes */}
        <Route path="/worker/boiler" element={withNav(BoilerMonitor)} />
        <Route path="/worker/machines" element={withNav(MesinPress)} />
        <Route path="/worker/qc" element={withNav(QcLab)} />
        <Route path="/worker/packing" element={withNav(PackingLog)} />
        <Route path="/worker/maintenance" element={withNav(PreventiveMaintenance)} />
        <Route path="/worker/breakdown" element={withNav(BreakdownLog)} />
        <Route path="/worker/shift" element={withNav(MillShiftSchedule)} />

        {/* MINING Modules */}
        <Route path="/worker/simper" element={withNav(SimperPage)} />
        <Route path="/worker/heavy-equip" element={withNav(HeavyEquipment)} />
        <Route path="/worker/fatigue" element={withNav(FatigueMonitor)} />
        <Route path="/worker/production" element={withNav(ProductionDaily)} />
        <Route path="/worker/safety" element={withNav(SafetyK3)} />
        <Route path="/worker/emergency" element={withNav(EmergencyProcedures)} />
        <Route path="/worker/jsa" element={withNav(JobSafetyAnalysis)} />

        {/* ESTATE Modules */}
        <Route path="/worker/harvest" element={withNav(HarvestRecord)} />
        <Route path="/worker/blocks" element={withNav(BlockManagement)} />
        <Route path="/worker/transport" element={withNav(TransportTBS)} />
        <Route path="/worker/nursery" element={withNav(NurseryPage)} />
        <Route path="/worker/irrigation" element={withNav(IrrigationPage)} />
        <Route path="/worker/facility" element={withNav(FacilityRequest)} />
        <Route path="/worker/medical" element={withNav(MedicalCheckup)} />

        {/* ═══════════ ADMIN — REKRUTMEN ═══════════ */}
        <Route path="/admin/recruitment" element={withNav(RecruitmentDashboard)} />
        <Route path="/admin/pipeline" element={withNav(PipelineKanban)} />
        <Route path="/admin/onboarding" element={withNav(OnboardingWorkflow)} />
        <Route path="/admin/screening" element={withNav(ScreeningPage)} />
        <Route path="/admin/approval-workflow" element={withNav(ApprovalWorkflow)} />
        <Route path="/admin/review-360" element={withNav(Review360)} />

        {/* ═══════════ ADMIN — KELOLA DATA ═══════════ */}
        <Route path="/admin" element={withNav(Admin)} />
        <Route path="/admin/employees" element={withNav(Employees)} />
        <Route path="/admin/org" element={withNav(OrgChart)} />
        <Route path="/admin/org-subtree" element={withNav(OrgSubtree)} />
        <Route path="/admin/divisions" element={withNav(DivisionsManagement)} />
        <Route path="/admin/master" element={withNav(MasterDataPage)} />
        <Route path="/admin/roles" element={withNav(RoleMatrixPage)} />

        {/* ═══════════ ADMIN — OPERASIONAL HR ═══════════ */}
        <Route path="/admin/requests" element={withNav(RequestsList)} />
        <Route path="/admin/leave" element={withNav(LeaveManagement)} />
        <Route path="/admin/overtime" element={withNav(OvertimeManagement)} />
        <Route path="/admin/payroll" element={withNav(Payroll)} />
        <Route path="/admin/timesheet" element={withNav(TimesheetPage)} />
        <Route path="/admin/shift-swap" element={withNav(ShiftSchedule)} />
        <Route path="/admin/approvals" element={withNav(ApprovalCenter)} />

        {/* ═══════════ ADMIN — TALENT & PERFORMANCE ═══════════ */}
        <Route path="/admin/kpi" element={withNav(Kpi)} />
        <Route path="/admin/incentive" element={withNav(IncentiveCalc)} />
        <Route path="/admin/okr" element={withNav(Okrs)} />
        <Route path="/admin/learning" element={withNav(LearningManagement)} />
        <Route path="/admin/certifications" element={withNav(CertificationsPage)} />
        <Route path="/admin/badges" element={withNav(BadgesPage)} />
        <Route path="/admin/talent" element={withNav(TalentMarketPage)} />
        <Route path="/admin/career" element={withNav(CareerPathPage)} />

        {/* ═══════════ ADMIN — ASET & FASILITAS ═══════════ */}
        <Route path="/admin/assets" element={withNav(AssetManagement)} />

        {/* ═══════════ ADMIN — ENGAGEMENT & BUDAYA ═══════════ */}
        <Route path="/admin/surveys" element={withNav(SurveyPage)} />
        <Route path="/admin/voice" element={withNav(VoiceIdeasPage)} />
        <Route path="/admin/whistleblower" element={withNav(WhistleblowingPage)} />

        {/* ═══════════ ADMIN — OFFBOARDING ═══════════ */}
        <Route path="/admin/exit" element={withNav(Offboarding)} />

        {/* ═══════════ ADMIN — SISTEM & KEAMANAN ═══════════ */}
        <Route path="/admin/audit" element={withNav(AuditLog)} />
        <Route path="/admin/export" element={withNav(ExportPage)} />
        <Route path="/admin/features" element={withNav(FeatureFlagsPage)} />
        <Route path="/admin/settings" element={withNav(Settings)} />
        <Route path="/admin/analytics" element={withNav(Analytics)} />
        <Route path="/admin/integrations" element={withNav(Integrations)} />
        <Route path="/admin/simulation" element={withNav(WorkforceSimulation)} />
        <Route path="/admin/turnover" element={withNav(TurnoverPrediction)} />
        <Route path="/admin/reset-password" element={withNav(ResetPassword)} />
        <Route path="/admin/chain" element={withNav(AuditChainPage)} />

        {/* ═══════════ ADMIN — PERENCANAAN ═══════════ */}
        <Route path="/admin/headcount" element={withNav(HeadcountPage)} />
        <Route path="/admin/budget" element={withNav(BudgetPage)} />
        <Route path="/admin/referral" element={withNav(ReferralPage)} />

        {/* ═══════════ DASHBOARD (Manager) ═══════════ */}
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/dashboard/*" element={<Dashboard />} />
      </Routes>
    </div>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <AppContent />
    </BrowserRouter>
  );
}
