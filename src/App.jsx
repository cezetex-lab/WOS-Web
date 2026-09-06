// src/App.jsx — Dynamic routing from module_definitions
import React, { useState } from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';

import { Layout } from './components/Layout';
import { AppDrawer } from './components/AppDrawer';
import { BottomNav } from './components/BottomNav';
import OfflineIndicator from './components/OfflineIndicator';
import PrivacyConsent from './components/PrivacyConsent';
import SessionGuard from './components/SessionGuard';
import OwnerGuard from './components/OwnerGuard';
import SkipToContent from './components/SkipToContent';
import DynamicRoutes from './components/DynamicRoutes';

// Static pages (not from module_definitions)
import Home from './pages/Home';
import OwnerLogin from './pages/OwnerLogin';
import OwnerDashboard from './pages/OwnerDashboard';
import CompanyConfig from './pages/CompanyConfig';


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

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 text-white font-sans antialiased">
      <OfflineIndicator />
      <PrivacyConsent />
      <Routes>
        {/* PUBLIC — no auth needed */}
        <Route path="/" element={<Home />} />
        <Route path="/owner" element={<OwnerLogin />} />
        <Route path="/owner/dashboard" element={<OwnerGuard><OwnerDashboard /></OwnerGuard>} />
        <Route path="/owner/dashboard/config" element={<OwnerGuard><CompanyConfig /></OwnerGuard>} />

        {/* PROTECTED — all routes from module_definitions DB */}
        <Route path="/*" element={
          <SessionGuard>
            <Routes>
              <DynamicRoutes withNav={withNav} />
            </Routes>
          </SessionGuard>
        } />
      </Routes>
    </div>
  );
}


export default function App() {
  return (
    <BrowserRouter>
      <SkipToContent />
      <AppContent />
    </BrowserRouter>
  );
}
