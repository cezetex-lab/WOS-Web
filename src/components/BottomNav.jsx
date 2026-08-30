// src/components/BottomNav.jsx
import React from 'react';
import { Link, useLocation } from 'react-router-dom';
import { getSession } from '@/lib/supabase-browser';
import { getUserModules } from '@/lib/business-units';

// BU-specific worker nav items
const WORKER_NAV = {
  MINING: [
    { to: '/worker', icon: '🏠', label: 'Beranda' },
    { to: '/worker/simper', icon: '⛏️', label: 'SIMPER' },
    { to: '/worker/tasks', icon: '📋', label: 'Tasks' },
    { to: '/worker/profile', icon: '👤', label: 'Saya' },
  ],
  ESTATE: [
    { to: '/worker', icon: '🏠', label: 'Beranda' },
    { to: '/worker/harvest', icon: '🌾', label: 'Panen' },
    { to: '/worker/tasks', icon: '📋', label: 'Tasks' },
    { to: '/worker/profile', icon: '👤', label: 'Saya' },
  ],
  MILL: [
    { to: '/worker', icon: '🏠', label: 'Beranda' },
    { to: '/worker/shift', icon: '🔄', label: 'Shift' },
    { to: '/worker/tasks', icon: '📋', label: 'Tasks' },
    { to: '/worker/profile', icon: '👤', label: 'Saya' },
  ],
  HQ: [
    { to: '/worker', icon: '🏠', label: 'Beranda' },
    { to: '/worker/activities', icon: '📋', label: 'Aktivitas' },
    { to: '/worker/payroll', icon: '💰', label: 'Gaji' },
    { to: '/worker/profile', icon: '👤', label: 'Saya' },
  ],
};

const ROLE_CONFIG = {
  admin: {
    home: '/admin',
    items: [
      { to: '/admin', icon: '🏠', label: 'Beranda' },
      { to: '/admin/employees', icon: '👥', label: 'Karyawan' },
      { to: '/admin/requests', icon: '📝', label: 'Pengajuan' },
      { to: '/admin/payroll', icon: '💰', label: 'Payroll' },
    ],
  },
  manager: {
    home: '/dashboard',
    items: [
      { to: '/dashboard', icon: '🏠', label: 'Beranda' },
      { to: '/dashboard', icon: '👥', label: 'Tim' },
      { to: '/dashboard', icon: '📊', label: 'KPI' },
      { to: '/dashboard', icon: '📈', label: 'Analytics' },
    ],
  },
};

export function BottomNav({ onMenuClick }) {
  const location = useLocation();
  const session = getSession();
  const role = session?.role || 'worker';
  const config = role === 'worker'
    ? { home: '/worker', items: WORKER_NAV[session?.business_unit || 'HQ'] || WORKER_NAV.HQ }
    : ROLE_CONFIG[role] || ROLE_CONFIG.worker;
  const isActive = (path) => location.pathname === path;

  return (
    <div className="fixed bottom-0 left-0 right-0 z-50 bg-slate-900/90 backdrop-blur-xl border-t border-white/10 px-2 pb-safe">
      <div className="max-w-7xl mx-auto flex items-center justify-around h-16">
        {config.items.map((item) => (
          <NavItem key={item.to} to={item.to} icon={item.icon} label={item.label} active={isActive(item.to)} />
        ))}
        <button onClick={onMenuClick} className="flex flex-col items-center justify-center w-14 h-14 rounded-2xl text-slate-400 hover:text-white transition-all active:scale-95">
          <span className="text-2xl">📌</span>
          <span className="text-[9px] font-medium">Menu</span>
        </button>
      </div>
    </div>
  );
}

function NavItem({ to, icon, label, active }) {
  return (
    <Link to={to} className={`flex flex-col items-center justify-center w-14 h-14 rounded-2xl transition-all ${active ? 'text-teal-400 bg-teal-400/10' : 'text-slate-400 hover:text-white'}`}>
      <span className="text-2xl">{icon}</span>
      <span className="text-[9px] font-medium">{label}</span>
    </Link>
  );
}