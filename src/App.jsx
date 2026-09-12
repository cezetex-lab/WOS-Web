// src/App.jsx — Dynamic routing from module_definitions
// Rewritten 2026-09-11: removed unused `import React` (JSX auto-runtime).
// Behavior unchanged vs. App.jsx.bak (kept beside this file).
import { useState } from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';

import { Layout } from './components/Layout';
import { AppDrawer } from './components/AppDrawer';
import { BottomNav } from './components/BottomNav';
import OfflineIndicator from './components/OfflineIndicator';
import PrivacyConsent from './components/PrivacyConsent';
import SessionGuard from './components/SessionGuard';
import OwnerGuard from './components/OwnerGuard';
import RoleGuard from './components/RoleGuard';
import SkipToContent from './components/SkipToContent';
import ErrorBoundary from './components/ErrorBoundary';
import DynamicRoutes from './components/DynamicRoutes';

// Static pages (not from module_definitions)
import Home from './pages/Home';
import OwnerLogin from './pages/OwnerLogin';
import OwnerDashboard from './pages/OwnerDashboard';
import CompanyConfig from './pages/CompanyConfig';
import Admin from './pages/Admin';
import Worker from './pages/Worker';
import Dashboard from './pages/Dashboard';

function AppContent() {
  const [isDrawerOpen, setDrawerOpen] = useState(false);
  const toggleDrawer = () => setDrawerOpen(!isDrawerOpen);
  const closeDrawer = () => setDrawerOpen(false);

  const withNav = (Component, props) => (
    <Layout>
      <ErrorBoundary fallbackName={Component.name || 'Page'}>
        <Component {...props} />
      </ErrorBoundary>
      <BottomNav onMenuClick={toggleDrawer} />
      <AppDrawer isOpen={isDrawerOpen} onClose={closeDrawer} />
    </Layout>
  );

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 text-white font-sans antialiased">
      <OfflineIndicator />
      <PrivacyConsent />
      <SessionGuard>
        <Routes>
          {/* PUBLIC — no auth needed */}
          <Route path="/" element={<Home />} />
          <Route path="/owner" element={<OwnerLogin />} />
          <Route path="/owner/dashboard" element={<OwnerGuard><OwnerDashboard /></OwnerGuard>} />
          <Route path="/owner/dashboard/config" element={<OwnerGuard><CompanyConfig /></OwnerGuard>} />

          {/* PROTECTED — role-isolated: worker / admin / dashboard punya guard sendiri.
              SessionGuard hanya cek login; RoleGuard cek role + login-entry.
              Worker yang login via tab lain TIDAK bisa buka /admin atau /dashboard tanpa login ulang. */}
          <Route path="/admin" element={<RoleGuard allowedRoles={['admin_pusat','admin_hrd','admin_finance','admin_produksi','admin_mining','admin_mill','admin_estate','owner']} entry="admin" redirectTo="/">{withNav(Admin)}</RoleGuard>} />
          <Route path="/worker" element={<RoleGuard allowedRoles={['worker','owner']} entry="worker" redirectTo="/">{withNav(Worker)}</RoleGuard>} />
          <Route path="/dashboard" element={<RoleGuard allowedRoles={['manager','admin_pusat','admin_hrd','admin_finance','admin_produksi','owner']} entry="dashboard" redirectTo="/">{withNav(Dashboard)}</RoleGuard>} />
          {/* DYNAMIC ROUTES from module_definitions */}
          <Route path="/*" element={<DynamicRoutes withNav={withNav} />} />
        </Routes>
      </SessionGuard>
    </div>
  );
}

export default function App() {
  return (
    <BrowserRouter future={{ v7_startTransition: true, v7_relativeSplatPath: true }}>
      <SkipToContent />
      <AppContent />
    </BrowserRouter>
  );
}