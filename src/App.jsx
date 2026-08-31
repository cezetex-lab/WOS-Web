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
const Employees = lazy(() => import('./pages/admin/Employees'));
const OrgSubtree = lazy(() => import('./pages/admin/OrgSubtree'));
const OrgChart = lazy(() => import('./pages/admin/OrgChart'));
const DivisionsManagement = lazy(() => import('./pages/admin/DivisionsManagement'));
const MasterDataPage = lazy(() => import('./pages/admin/MasterDataPage'));
const RoleMatrixPage = lazy(() => import('./pages/admin/RoleMatrixPage'));

// ── ADMIN OPERASIONAL ──
const RequestsList = lazy(() => import('./pages/admin/RequestsList'));
const LeaveManagement = lazy(() => import('./pages/admin/LeaveManagement'));
const OvertimeManagement = lazy(() => import('./pages/admin/OvertimeManagement'));
const Payroll = lazy(() => import('./pages/admin/Payroll'));
const TimesheetPage = lazy(() => import('./pages/admin/TimesheetPage'));
const ShiftSchedule = lazy(() => import('./admin/ShiftSchedule'));
const ApprovalCenter = lazy(() => import('./admin/ApprovalCenter'));

// ── ADMIN TALENT & PERFORMANCE ──
const Kpi = lazy(() => import('./pages/admin/Kpi'));
const IncentiveCalc = lazy(() => import('./pages/admin/IncentiveCalc'));
const Okrs = lazy(() => import('./pages/admin/Okrs'));
const LearningManagement = lazy(() => import('./pages/admin/LearningManagement'));
const CertificationsPage = lazy(() => import('./pages/admin/CertificationsPage'));
const BadgesPage = lazy(() => import('./pages/admin/BadgesPage'));
const TalentMarketPage = lazy(() => import('./pages/admin/TalentMarketPage'));
const CareerPathPage = lazy(() => import('./pages/admin/CareerPathPage'));

// ── ADMIN ASET ──
const AssetManagement = lazy(() => import('./pages/admin/AssetManagement'));

// ── ADMIN ENGAGEMENT ──
const SurveyPage = lazy(() => import('./pages/admin/SurveyPage'));
const VoiceIdeasPage = lazy(() => import('./pages/admin/VoiceIdeasPage'));
const WhistleblowingPage = lazy(() => import('./pages/admin/WhistleblowingPage'));

// ── ADMIN OFFBOARDING ──
const Offboarding = lazy(() => import('./pages/admin/Offboarding'));

// ── ADMIN SISTEM ──
const AuditLog = lazy(() => import('./pages/admin/AuditLog'));
const ExportPage = lazy(() => import('./pages/admin/ExportPage'));
const FeatureFlagsPage = lazy(() => import('./pages/admin/FeatureFlagsPage'));
const Settings = lazy(() => import('./pages/admin/Settings'));
const Analytics = lazy(() => import('./pages/admin/Analytics'));
const AuditChainPage = lazy(() => import('./pages/admin/AuditChainPage'));

// ── ADMIN INTEGRASI & ANALYTICS ──
const Integrations = lazy(() => import('./pages/admin/Integrations'));
const WorkforceSimulation = lazy(() => import('./pages/admin/WorkforceSimulation'));
const TurnoverPrediction = lazy(() => import('./pages/admin/TurnoverPrediction'));
const ResetPassword = lazy(() => import('./pages/admin/ResetPassword'));

// ── ADMIN PERENCANAAN ──
const HeadcountPage = lazy(() => import('./pages/admin/HeadcountPage'));
const BudgetPage = lazy(() => import('./pages/admin/BudgetPage'));
const ReferralPage = lazy(() => import('./pages/admin/ReferralPage'));

// ── WORKER ──
const WorkerProfile = lazy(() => import('./pages/worker/WorkerProfile'));
const WorkerOvertime = lazy(() => import('./pages/worker/WorkerOvertime'));
const WorkerAttendance = lazy(() => import('./pages/worker/WorkerAttendance'));
const WorkerLearning = lazy(() => import('./pages/worker/WorkerLearning'));
const WorkerKpi = lazy(() => import('./pages/worker/WorkerKpi'));
const WorkerPayroll = lazy(() => import('./pages/worker/WorkerPayroll'));
const WorkerCareer = lazy(() => import('./pages/worker/WorkerCareer'));
const WorkerActivities = lazy(() => import('./pages/worker/WorkerActivities'));
const WorkerChangePassword = lazy(() => import('./pages/worker/WorkerChangePassword'));
const PerformanceTrend = lazy(() => import('./pages/worker/PerformanceTrend'));
const CompensationIntel = lazy(() => import('./pages/worker/CompensationIntel'));
const ContinuousPerf = lazy(() => import('./pages/worker/ContinuousPerf'));
const TrainingForm = lazy(() => import('./pages/worker/TrainingForm'));
const PerformanceNotes = lazy(() => import('./pages/worker/PerformanceNotes'));

// ── WAVE 4 ──
const MultiStepRequest = lazy(() => import('./worker/MultiStepRequest'));
const TaskBoard = lazy(() => import('./worker/TaskBoard'));

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
