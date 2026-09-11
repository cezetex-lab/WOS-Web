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

          {/* PROTECTED — direct routes */}
          <Route path="/admin" element={withNav(Admin)} />
          <Route path="/worker" element={withNav(Worker)} />
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