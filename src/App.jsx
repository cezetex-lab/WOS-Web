// src/App.jsx
import React, { useState } from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { Layout } from './components/Layout';
import { AppDrawer } from './components/AppDrawer';
import { BottomNav } from './components/BottomNav';
// Pages
import Home from './pages/Home';
import Worker from './pages/Worker';
import Admin from './pages/Admin';
import Dashboard from './pages/Dashboard';
import Employees from './pages/admin/Employees';
import Payroll from './pages/admin/Payroll';
import Kpi from './pages/admin/Kpi';
import Settings from './pages/admin/Settings';
import OrgSubtree from './pages/admin/OrgSubtree';
import OrgChart from './pages/admin/OrgChart';
import Analytics from './pages/admin/Analytics';
import AuditLog from './pages/admin/AuditLog';
import DetailPageFactory from './pages/admin/DetailPageFactory';
// Wave 2 — Worker Pages
import WorkerProfile from './pages/worker/WorkerProfile';
import WorkerOvertime from './pages/worker/WorkerOvertime';
import PerformanceTrend from './pages/worker/PerformanceTrend';
import CompensationIntel from './pages/worker/CompensationIntel';
import ContinuousPerf from './pages/worker/ContinuousPerf';
import TrainingForm from './pages/worker/TrainingForm';
// Wave 4 — Self-Service & Approval
import MultiStepRequest from './worker/MultiStepRequest';
import TaskBoard from './worker/TaskBoard';
import ShiftSchedule from './admin/ShiftSchedule';
import ApprovalCenter from './admin/ApprovalCenter';

function AppContent() {
  const [isDrawerOpen, setDrawerOpen] = useState(false);
  const toggleDrawer = () => setDrawerOpen(!isDrawerOpen);
  const closeDrawer = () => setDrawerOpen(false);

  const withNav = (Component, props) => (
    <Layout>
      <Component {...props} />
      <BottomNav onMenuClick={toggleDrawer} />
      <AppDrawer isOpen={isDrawerOpen} onClose={closeDrawer} />
    </Layout>
  );

  const adminPage = (key) => withNav(DetailPageFactory, { pageKey: key, isAdmin: true });
  const workerPage = (key) => withNav(DetailPageFactory, { pageKey: key, isAdmin: false });

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 text-white font-sans antialiased">
      <Routes>
        {/* LOGIN */}
        <Route path="/" element={<Home />} />

        {/* WORKER */}
        <Route path="/worker" element={withNav(Worker)} />
        <Route path="/worker/attendance" element={workerPage('attendance')} />
        <Route path="/worker/leave" element={workerPage('leave')} />
        <Route path="/worker/overtime" element={withNav(WorkerOvertime)} />
        <Route path="/worker/kpi" element={workerPage('kpi')} />
        <Route path="/worker/payroll" element={workerPage('payroll')} />
        <Route path="/worker/learning" element={workerPage('learning')} />
        <Route path="/worker/career" element={workerPage('career')} />
        <Route path="/worker/tasks" element={workerPage('tasks')} />
        <Route path="/worker/profile" element={withNav(WorkerProfile)} />
        <Route path="/worker/activities" element={workerPage('activities')} />
        <Route path="/worker/perf-trend" element={withNav(PerformanceTrend)} />
        <Route path="/worker/compensation" element={withNav(CompensationIntel)} />
        <Route path="/worker/continuous-perf" element={withNav(ContinuousPerf)} />
        <Route path="/worker/training" element={withNav(TrainingForm)} />
        <Route path="/worker/request" element={withNav(MultiStepRequest)} />
        <Route path="/worker/task-board" element={withNav(TaskBoard)} />

        {/* ADMIN — KELOLA DATA */}
        <Route path="/admin" element={withNav(Admin)} />
        <Route path="/admin/employees" element={withNav(Employees)} />
        <Route path="/admin/org" element={withNav(OrgChart)} />
        <Route path="/admin/org-subtree" element={withNav(OrgSubtree)} />
        <Route path="/admin/divisions" element={adminPage('divisions')} />
        <Route path="/admin/master" element={adminPage('master')} />
        <Route path="/admin/roles" element={adminPage('roles')} />

        {/* ADMIN — OPERASIONAL HR */}
        <Route path="/admin/requests" element={adminPage('requests')} />
        <Route path="/admin/leave" element={adminPage('leave')} />
        <Route path="/admin/overtime" element={adminPage('overtime')} />
        <Route path="/admin/payroll" element={withNav(Payroll)} />
        <Route path="/admin/timesheet" element={adminPage('timesheet')} />
        <Route path="/admin/shift-swap" element={withNav(ShiftSchedule)} />
        <Route path="/admin/approvals" element={withNav(ApprovalCenter)} />

        {/* ADMIN — TALENT & PERFORMANCE */}
        <Route path="/admin/kpi" element={withNav(Kpi)} />
        <Route path="/admin/okr" element={adminPage('okr')} />
        <Route path="/admin/learning" element={adminPage('learning')} />
        <Route path="/admin/certifications" element={adminPage('certifications')} />
        <Route path="/admin/badges" element={adminPage('badges')} />
        <Route path="/admin/talent" element={adminPage('talent')} />
        <Route path="/admin/career" element={adminPage('career')} />

        {/* ADMIN — ASET & FASILITAS */}
        <Route path="/admin/assets" element={adminPage('assets')} />
        <Route path="/admin/asset-assign" element={adminPage('asset-assign')} />
        <Route path="/admin/estate" element={adminPage('estate')} />
        <Route path="/admin/facility" element={adminPage('facility')} />

        {/* ADMIN — ENGAGEMENT & BUDAYA */}
        <Route path="/admin/surveys" element={adminPage('surveys')} />
        <Route path="/admin/voice" element={adminPage('voice')} />
        <Route path="/admin/whistleblower" element={adminPage('whistleblower')} />

        {/* ADMIN — OFFBOARDING */}
        <Route path="/admin/exit" element={adminPage('exit')} />
        <Route path="/admin/settlement" element={adminPage('settlement')} />
        <Route path="/admin/clearance" element={adminPage('clearance')} />

        {/* ADMIN — SISTEM & KEAMANAN */}
        <Route path="/admin/audit" element={withNav(AuditLog)} />
        <Route path="/admin/export" element={adminPage('export')} />
        <Route path="/admin/features" element={adminPage('features')} />
        <Route path="/admin/settings" element={withNav(Settings)} />
        <Route path="/admin/analytics" element={withNav(Analytics)} />
        <Route path="/admin/chain" element={adminPage('chain')} />

        {/* ADMIN — PERENCANAAN */}
        <Route path="/admin/headcount" element={adminPage('headcount')} />
        <Route path="/admin/budget" element={adminPage('budget')} />
        <Route path="/admin/referral" element={adminPage('referral')} />

        {/* DASHBOARD (Manager) — own internal tabs, no withNav */}
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
