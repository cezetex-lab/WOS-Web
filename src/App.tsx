// src/App.tsx — Dynamic routing from module_definitions
// Rewritten 2026-09-11: removed unused `import React` (JSX auto-runtime).
// Behavior unchanged since the .jsx → .tsx entrypoint migration.
import { lazy, Suspense, useState } from 'react';
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
// OPS-03c: Home + OwnerLogin tetap STATIS (jalur login harus instant);
// OwnerDashboard/CompanyConfig/Admin/Worker di-lazy() supaya tidak membebani
// main bundle (pola yang sama dengan Dashboard yang sudah lazy).
import Home from './pages/Home';
import OwnerLogin from './pages/OwnerLogin';
const OwnerDashboard = lazy(() => import('./pages/OwnerDashboard'));
const CompanyConfig = lazy(() => import('./pages/CompanyConfig'));
const Admin = lazy(() => import('./pages/Admin'));
const Worker = lazy(() => import('./pages/Worker'));
const Dashboard = lazy(() => import('./pages/Dashboard'));

function AppContent() {
  const [isDrawerOpen, setDrawerOpen] = useState(false);
  const toggleDrawer = () => setDrawerOpen(!isDrawerOpen);
  const closeDrawer = () => setDrawerOpen(false);

  const withNav = (Component: any, props?: any) => (
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
        {/* OPS-03c: boundary Suspense untuk seluruh Routes — wajib karena
            OwnerDashboard/CompanyConfig/Admin/Worker/Dashboard kini lazy(). */}
        <Suspense fallback={<div className="min-h-screen flex items-center justify-center" role="status" aria-live="polite"><span className="text-slate-400 text-sm">Memuat…</span></div>}>
        <Routes>
          {/* PUBLIC — no auth needed */}
          <Route path="/" element={<Home />} />
          <Route path="/owner" element={<OwnerLogin />} />
          <Route path="/owner/dashboard" element={<OwnerGuard><OwnerDashboard /></OwnerGuard>} />
          <Route path="/owner/dashboard/config" element={<OwnerGuard><CompanyConfig /></OwnerGuard>} />

          {/* PROTECTED — role-isolated: worker / admin / dashboard punya guard sendiri.
              SessionGuard hanya cek login; RoleGuard cek role + login-entry.
              Worker yang login via tab lain TIDAK bisa buka /admin atau /dashboard tanpa login ulang. */}
          <Route path="/admin" element={<RoleGuard allowedRoles={['admin_pusat','admin_hrd','admin_finance','admin_operasional','admin_mining','admin_mill','admin_estate','owner']} entry="admin" redirectTo="/">{withNav(Admin)}</RoleGuard>} />
          <Route path="/worker" element={<RoleGuard allowedRoles={['worker','owner']} entry="worker" redirectTo="/">{withNav(Worker)}</RoleGuard>} />
          <Route path="/dashboard" element={<RoleGuard allowedRoles={['manager','admin_pusat','admin_hrd','admin_finance','admin_operasional','owner']} entry="dashboard" redirectTo="/">{withNav(Dashboard)}</RoleGuard>} />
          {/* DYNAMIC ROUTES from module_definitions */}
          <Route path="/*" element={<DynamicRoutes withNav={withNav} />} />
        </Routes>
        </Suspense>
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
