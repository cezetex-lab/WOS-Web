// src/components/AppDrawer.jsx
// Drawer navigasi: sumber utama = menu dinamis dari module_definitions
// (buildMenu, A12). Konstanta di bawah HANYA fallback saat menu dinamis
// gagal/belum termuat — cukup "gerbang" ke area, bukan salinan penuh menu.
// Otoritas akses sesungguhnya tetap di DynamicRoutes guard + RLS database.
import React, { useState, useEffect } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { rpc, getSession } from '@/lib/supabase-browser';
import { buildMenu, areaFromPath, drawerPathInArea } from '@/lib/menu-builder';

// ── Grup fallback bersama (dipakai ulang antar role — mengakhiri copy-paste) ──
const G_OPS = {
  title: 'OPERASIONAL',
  items: [
    { icon: '⏱️', label: 'Timesheet', path: '/admin/timesheet' },
    { icon: '🔄', label: 'Shift Swap', path: '/admin/shift-swap' },
    { icon: '⏰', label: 'Lembur', path: '/admin/overtime' },
    { icon: '📝', label: 'Pengajuan', path: '/admin/requests' },
  ],
};

const G_PERF = {
  title: 'KINERJA & ASET',
  items: [
    { icon: '📊', label: 'KPI', path: '/admin/kpi' },
    { icon: '🛠️', label: 'Inventaris', path: '/admin/assets' },
    { icon: '📦', label: 'Check-in/out', path: '/admin/asset-assign' },
  ],
};

const G_SYS = {
  title: 'SISTEM',
  items: [
    { icon: '📋', label: 'Audit Log', path: '/admin/audit' },
    { icon: '🔐', label: 'Pengaturan', path: '/admin/settings' },
  ],
};

// Fallback admin "gerbang": inti navigasi admin. Saat menu dinamis hidup,
// grup ini selalu tertimpa daftar lengkap dari module_definitions.
const ADMIN_FALLBACK_GROUPS = [
  {
    title: 'MENU ADMIN',
    items: [
      { icon: '👥', label: 'Karyawan', path: '/admin/employees' },
      { icon: '📝', label: 'Pengajuan', path: '/admin/requests' },
      { icon: '💰', label: 'Payroll', path: '/admin/payroll' },
      { icon: '📊', label: 'KPI', path: '/admin/kpi' },
      { icon: '🏢', label: 'Organisasi', path: '/admin/org' },
      { icon: '📋', label: 'Audit Log', path: '/admin/audit' },
      { icon: '🔐', label: 'Pengaturan', path: '/admin/settings' },
    ],
  },
];

// Fallback per-role admin (menu dinamis gagal). Grup bersama direferensikan,
// bukan disalin. Item /worker/* di sini akan disaring oleh inArea di area admin.
const ADMIN_HRD_GROUPS = [
  {
    title: 'KELOLA DATA',
    items: [
      { icon: '👥', label: 'Karyawan', path: '/admin/employees' },
      { icon: '🏢', label: 'Organisasi', path: '/admin/org' },
      { icon: '📂', label: 'Divisi', path: '/admin/divisions' },
    ],
  },
  {
    title: 'TALENT & PERFORMANCE',
    items: [
      { icon: '📊', label: 'KPI', path: '/admin/kpi' },
      { icon: '🎯', label: 'OKR', path: '/admin/okr' },
      { icon: '📚', label: 'Learning', path: '/admin/learning' },
    ],
  },
  G_OPS,
  G_SYS,
];

const ADMIN_FINANCE_GROUPS = [
  {
    title: 'PAYROLL & KOMPENSASI',
    items: [
      { icon: '💰', label: 'Payroll', path: '/admin/payroll' },
      { icon: '🎁', label: 'Insentif', path: '/admin/incentive' },
      { icon: '💰', label: 'Budget Allocation', path: '/admin/budget' },
    ],
  },
  G_OPS,
  G_SYS,
];

const ADMIN_PRODUKSI_GROUPS = [G_OPS, G_PERF, G_SYS];

const ADMIN_MINING_GROUPS = [G_OPS, G_PERF, G_SYS];

const ADMIN_MILL_GROUPS = [G_OPS, G_PERF, G_SYS];

const ADMIN_ESTATE_GROUPS = [G_OPS, G_PERF, G_SYS];

const ADMIN_ROLE_MAP = {
  admin_hrd: ADMIN_HRD_GROUPS,
  admin_finance: ADMIN_FINANCE_GROUPS,
  admin_produksi: ADMIN_PRODUKSI_GROUPS,
  admin_mining: ADMIN_MINING_GROUPS,
  admin_mill: ADMIN_MILL_GROUPS,
  admin_estate: ADMIN_ESTATE_GROUPS,
};

// Fallback worker (self-service pribadi)
const WORKER_GROUPS = [
  {
    title: 'AKTIVITAS',
    items: [
      { icon: '📍', label: 'Kehadiran', path: '/worker/attendance' },
      { icon: '🌴', label: 'Cuti', path: '/worker/leave' },
      { icon: '💼', label: 'Lembur', path: '/worker/overtime' },
      { icon: '✅', label: 'Task Saya', path: '/worker/tasks' },
      { icon: '📋', label: 'Aktivitas', path: '/worker/activities' },
    ],
  },
  {
    title: 'PENGEMBANGAN DIRI',
    items: [
      { icon: '📚', label: 'Learning', path: '/worker/learning' },
      { icon: '🚀', label: 'Karir', path: '/worker/career' },
      { icon: '📊', label: 'KPI Saya', path: '/worker/kpi' },
    ],
  },
  {
    title: 'KOMPENSASI',
    items: [
      { icon: '💰', label: 'Slip Gaji', path: '/worker/payroll' },
      { icon: '👤', label: 'Profil Saya', path: '/worker/profile' },
    ],
  },
];

// Fallback manager/dashboard. Item menunjuk '/dashboard' (bukan '/dashboard/x')
// agar lolos filter inArea — dahulu fallback ini menghasilkan drawer kosong.
const MANAGER_GROUPS = [
  {
    title: 'DASHBOARD',
    items: [
      { icon: '🏠', label: 'Beranda', path: '/dashboard' },
      { icon: '👥', label: 'Tim Saya', path: '/dashboard' },
      { icon: '📈', label: 'KPI Divisi', path: '/dashboard' },
      { icon: '💰', label: 'Keuangan', path: '/dashboard' },
      { icon: '⚠️', label: 'Flight Risk', path: '/dashboard' },
      { icon: '🏢', label: 'Exec Summary', path: '/dashboard' },
    ],
  },
];

// Fallback area owner — menu lengkap owner datang dari module_definitions.
const OWNER_FALLBACK_GROUPS = ADMIN_FALLBACK_GROUPS;

export function AppDrawer({ isOpen, onClose }) {
  const location = useLocation();
  const [brand, setBrand] = useState({ company_name: 'insightWOS', logo_url: '' });
  const [dynamicGroups, setDynamicGroups] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    rpc('get_branding', {}).then(d => {
      if (d && d.company_name) setBrand(d);
    }).catch(() => {});
  }, []);

  useEffect(() => {
    if (!isOpen) return;
    const drawerArea = areaFromPath(location.pathname);
    buildMenu(drawerArea).then(menu => {
      // Group dynamic menu items by module_group
      const grouped = {};
      menu.forEach(item => {
        const group = item.group || 'LAINNYA';
        if (!grouped[group]) grouped[group] = [];
        grouped[group].push({ icon: item.icon, label: item.name, path: item.path });
      });

      // Convert to AppDrawer format
      const groups = Object.entries(grouped).map(([title, items]) => ({ title, items }));
      setDynamicGroups(groups);
      setLoading(false);
    }).catch(err => {
      console.error('[AppDrawer] Failed to build menu:', err);
      setLoading(false);
    });
  }, [isOpen, location.pathname]);

  if (!isOpen) return null;
  const session = getSession();
  const role = session?.role || 'worker';
  const path = location.pathname;
  const isOwner = session?.is_owner || role === 'owner';

  // Use dynamic menu if available, otherwise fallback to hardcoded
  let groups = dynamicGroups;

  // Fallback to hardcoded groups if dynamic menu empty or still loading
  if (!groups.length || loading) {
    if (path.startsWith('/dashboard')) {
      groups = MANAGER_GROUPS;
    } else if (path.startsWith('/owner')) {
      groups = OWNER_FALLBACK_GROUPS;
    } else if (path.startsWith('/admin')) {
      // Owner (GOD mode) dan admin_pusat dapat fallback admin lengkap;
      // menu penuh mereka tetap datang dari module_definitions.
      if (isOwner || role === 'admin_pusat') {
        groups = ADMIN_FALLBACK_GROUPS;
      } else {
        groups = ADMIN_ROLE_MAP[role] || ADMIN_FALLBACK_GROUPS;
      }
    } else {
      // Semua user di area worker hanya melihat self-service pribadi.
      // Role admin/direktur tidak mengubah isi drawer worker.
      groups = WORKER_GROUPS;
    }
  }

  // Safety net: item di luar area aktif dibuang, grup kosong disembunyikan.
  // Memakai drawerPathInArea() dari menu-builder.js — satu implementasi filter
  // area yang sama dengan buildMenu (plus klausa dashboard-di-area-worker).
  const area = areaFromPath(path);
  const inArea = (p) => drawerPathInArea(p, area);
  groups = groups
    .map(g => ({ ...g, items: g.items.filter(i => inArea(i.path)) }))
    .filter(g => g.items.length > 0);

  return (
    <>
      {/* Overlay */}
      <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm" onClick={onClose} />
      {/* Drawer */}
      <div className="fixed top-0 left-0 bottom-0 z-50 w-[85%] max-w-sm bg-slate-900 border-r border-white/10 shadow-2xl overflow-y-auto pb-20">
        <div className="sticky top-0 z-10 bg-slate-900/95 backdrop-blur-md p-4 border-b border-white/10 flex items-center justify-between">
          <div className="flex items-center gap-2">
            {brand.logo_url ? (
              <img src={brand.logo_url} alt="Logo" className="h-8 w-8 object-contain rounded" />
            ) : (
              <span className="text-2xl">📊</span>
            )}
            <span className="font-bold text-white tracking-tight text-lg">{brand.company_name || 'insightWOS'}</span>
          </div>
          <button onClick={onClose} className="p-2 hover:bg-white/10 rounded-xl text-slate-400">
            <span className="text-2xl">✕</span>
          </button>
        </div>

        <div className="p-4 space-y-6">
          {groups.map((group, idx) => (
            <div key={idx}>
              <h4 className="text-[11px] font-bold text-teal-400 tracking-widest mb-2">{group.title}</h4>
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
