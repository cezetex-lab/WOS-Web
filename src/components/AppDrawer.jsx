// src/components/AppDrawer.jsx
import React from 'react';
import { Link } from 'react-router-dom';
import { getSession } from '@/lib/supabase-browser';
import { BU_MODULES } from '@/lib/business-units';

const ADMIN_GROUPS = [
  {
    title: 'KELOLA DATA',
    items: [
      { icon: '👥', label: 'Karyawan', path: '/admin/employees' },
      { icon: '🏢', label: 'Organisasi', path: '/admin/org' },
      { icon: '📂', label: 'Divisi', path: '/admin/divisions' },
      { icon: '🗄️', label: 'Master Data', path: '/admin/master' },
      { icon: '🔑', label: 'Role Matrix', path: '/admin/roles' },
    ]
  },
  {
    title: 'OPERASIONAL HR',
    items: [
      { icon: '📝', label: 'Pengajuan', path: '/admin/requests' },
      { icon: '🌴', label: 'Cuti', path: '/admin/leave' },
      { icon: '⏰', label: 'Lembur', path: '/admin/overtime' },
      { icon: '💰', label: 'Payroll', path: '/admin/payroll' },
      { icon: '⏱️', label: 'Timesheet', path: '/admin/timesheet' },
      { icon: '🔄', label: 'Shift Swap', path: '/admin/shift-swap' },
    ]
  },
  {
    title: 'TALENT & PERFORMANCE',
    items: [
      { icon: '📊', label: 'KPI', path: '/admin/kpi' },
      { icon: '🎯', label: 'OKR', path: '/admin/okr' },
      { icon: '📚', label: 'Learning', path: '/admin/learning' },
      { icon: '📜', label: 'Sertifikasi', path: '/admin/certifications' },
      { icon: '🏅', label: 'Badge & Gamifikasi', path: '/admin/badges' },
      { icon: '🎯', label: 'Talent Market', path: '/admin/talent' },
      { icon: '🧭', label: 'Career Path', path: '/admin/career' },
    ]
  },
  {
    title: 'ASET & FASILITAS',
    items: [
      { icon: '🛠️', label: 'Inventaris', path: '/admin/assets' },
      { icon: '📦', label: 'Check-in/out', path: '/admin/asset-assign' },
      { icon: '🌳', label: 'Estate Blocks', path: '/admin/estate' },
      { icon: '🏗️', label: 'Facility Request', path: '/admin/facility' },
    ]
  },
  {
    title: 'ENGAGEMENT & BUDAYA',
    items: [
      { icon: '📋', label: 'Survei (eNPS)', path: '/admin/surveys' },
      { icon: '💡', label: 'Ide & Voice', path: '/admin/voice' },
      { icon: '🕊️', label: 'Whistleblowing', path: '/admin/whistleblower' },
    ]
  },
  {
    title: 'OFFBOARDING',
    items: [
      { icon: '🚪', label: 'Exit Interview', path: '/admin/exit' },
      { icon: '📄', label: 'Final Settlement', path: '/admin/settlement' },
      { icon: '✅', label: 'Clearance', path: '/admin/clearance' },
    ]
  },
  {
    title: 'SISTEM & KEAMANAN',
    items: [
      { icon: '📋', label: 'Audit Log', path: '/admin/audit' },
      { icon: '📤', label: 'Export Data', path: '/admin/export' },
      { icon: '⚙️', label: 'Feature Flags', path: '/admin/features' },
      { icon: '🔐', label: 'Pengaturan', path: '/admin/settings' },
      { icon: '🔗', label: 'Audit Chain', path: '/admin/chain' },
    ]
  },
  {
    title: 'PERENCANAAN',
    items: [
      { icon: '📊', label: 'Headcount Plan', path: '/admin/headcount' },
      { icon: '💰', label: 'Budget Allocation', path: '/admin/budget' },
      { icon: '🤝', label: 'Referral Program', path: '/admin/referral' },
    ]
  }
];

const WORKER_GROUPS = [
  {
    title: 'AKTIVITAS',
    items: [
      { icon: '📍', label: 'Kehadiran', path: '/worker/attendance' },
      { icon: '🌴', label: 'Cuti', path: '/worker/leave' },
      { icon: '💼', label: 'Lembur', path: '/worker/overtime' },
      { icon: '✅', label: 'Task Saya', path: '/worker/tasks' },
      { icon: '📋', label: 'Aktivitas', path: '/worker/activities' },
    ]
  },
  {
    title: 'PENGEMBANGAN DIRI',
    items: [
      { icon: '📚', label: 'Learning', path: '/worker/learning' },
      { icon: '🚀', label: 'Karir', path: '/worker/career' },
      { icon: '📊', label: 'KPI Saya', path: '/worker/kpi' },
    ]
  },
  {
    title: 'KOMPENSASI',
    items: [
      { icon: '💰', label: 'Slip Gaji', path: '/worker/payroll' },
      { icon: '👤', label: 'Profil Saya', path: '/worker/profile' },
    ]
  },
];

const MANAGER_GROUPS = [
  {
    title: 'DASHBOARD',
    items: [
      { icon: '🏠', label: 'Beranda', path: '/dashboard' },
      { icon: '👥', label: 'Tim Saya', path: '/dashboard' },
      { icon: '📈', label: 'KPI Divisi', path: '/dashboard' },
      { icon: '💰', label: 'Keuangan', path: '/dashboard' },
    ]
  },
  {
    title: 'RISK & ANALYTICS',
    items: [
      { icon: '⚠️', label: 'Flight Risk', path: '/dashboard' },
      { icon: '🔄', label: 'Turnover', path: '/dashboard' },
      { icon: '🏢', label: 'Exec Summary', path: '/dashboard' },
      { icon: '🏗️', label: 'Health Score', path: '/dashboard' },
    ]
  },
];

const ROLE_MAP = { admin: ADMIN_GROUPS, manager: MANAGER_GROUPS };

// Convert BU modules sidebarGroups to AppDrawer format
function getWorkerGroups(bu) {
  const modules = BU_MODULES[bu] || BU_MODULES.HQ;
  return modules.sidebarGroups || WORKER_GROUPS;
}

export function AppDrawer({ isOpen, onClose }) {
  if (!isOpen) return null;
  const session = getSession();
  const role = session?.role || 'worker';
  const bu = session?.business_unit || 'HQ';
  const groups = role === 'worker' ? getWorkerGroups(bu) : (ROLE_MAP[role] || WORKER_GROUPS);
  return (
    <>
      {/* Overlay */}
      <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm" onClick={onClose} />
      {/* Drawer */}
      <div className="fixed top-0 left-0 bottom-0 z-50 w-[85%] max-w-sm bg-slate-900 border-r border-white/10 shadow-2xl overflow-y-auto pb-20">
        <div className="sticky top-0 z-10 bg-slate-900/95 backdrop-blur-md p-4 border-b border-white/10 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <span className="text-2xl">📊</span>
            <span className="font-bold text-white tracking-tight text-lg">insightWOS</span>
          </div>
          <button onClick={onClose} className="p-2 hover:bg-white/10 rounded-xl text-slate-400">
            <span className="text-2xl">✕</span>
          </button>
        </div>

        <div className="p-4 space-y-6">
          {groups.map((group, idx) => (
            <div key={idx}>
              <h4 className="text-[10px] font-bold text-teal-400 tracking-widest mb-2">{group.title}</h4>
              <div className="space-y-1">
                {group.items.map((item, i) => (
                  <Link
                    key={i}
                    to={item.path}
                    onClick={onClose}
                    className="flex items-center gap-3 p-2.5 rounded-xl hover:bg-white/5 text-slate-300 hover:text-white transition-all group"
                  >
                    <span className="text-lg w-8 text-center">{item.icon}</span>
                    <span className="text-sm font-medium">{item.label}</span>
                  </Link>
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>
    </>
  );
}