// ============================================================
// DetailPageFactory.jsx — Factory untuk membuat halaman detail
// Satu komponen, 30+ halaman berbeda via config
// ============================================================

import { getSession } from '@/lib/supabase-browser';
import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase, rpc } from '../../../lib/supabase-browser';
import {
  PageLayout, MetricCard, GlassCard, DataTable, Badge,
  Tabs, LoadingSpinner, EmptyState, Button, Avatar, ActionItem, Divider
} from '../../../lib/design-system';

// ── PERMISSION CHECK ──
const APPROVE_ROLES = ['admin_pusat', 'admin_hrd', 'manager', 'director', 'owner'];
function canUserApprove(userRole) {
  return APPROVE_ROLES.includes(userRole);
}

// ──────────────────────────────────────────────────────────────
// PAGE CONFIGS — Definisi semua halaman admin
// ──────────────────────────────────────────────────────────────
export const ADMIN_PAGE_CONFIGS = {
  // KELOLA DATA
  org:          { title: 'Organisasi', desc: 'Struktur organisasi perusahaan', icon: '🏢', rpc: 'admin_get_org_structure', fallbackTable: 'hr_org' },
  divisions:    { title: 'Divisi', desc: 'Manajemen divisi & departemen', icon: '📂', rpc: 'admin_get_divisions', fallbackTable: 'employees_master' },
  master:       { title: 'Master Data', desc: 'Data referensi utama sistem', icon: '🗄️', rpc: 'admin_get_master_data', fallbackTable: 'master_data' },
  roles:        { title: 'Role Matrix', desc: 'Mapping role & permission', icon: '🔑', rpc: null, fallbackTable: 'user_roles' },

  // OPERASIONAL HR
  requests:     { title: 'Pengajuan', desc: 'Kelola semua pengajuan karyawan', icon: '📝', rpc: 'admin_get_pending_requests', fallbackTable: 'hr_requests', hasActions: true, statusField: 'status' },
  leave:        { title: 'Cuti', desc: 'Manajemen cuti karyawan', icon: '🌴', rpc: 'admin_get_leave', fallbackTable: 'leave_requests', hasActions: true, statusField: 'status' },
  overtime:     { title: 'Lembur', desc: 'Pengajuan & persetujuan lembur', icon: '⏰', rpc: 'get_overtime_data', fallbackTable: 'hr_overtime', hasActions: true, statusField: 'status' },
  timesheet:    { title: 'Timesheet', desc: 'Catatan jam kerja harian', icon: '⏱️', rpc: 'admin_get_timesheet', fallbackTable: 'timesheet' },
  'shift-swap': { title: 'Shift Swap', desc: 'Tukar jadwal shift', icon: '🔄', rpc: 'get_shift_schedule', fallbackTable: 'hr_shift_master', hasActions: true, statusField: 'status' },

  // TALENT & PERFORMANCE
  okr:          { title: 'OKR', desc: 'Objectives & Key Results', icon: '🎯', rpc: 'admin_get_okr', fallbackTable: 'okr' },
  learning:     { title: 'Learning', desc: 'Program pelatihan & kursus', icon: '📚', rpc: 'get_worker_learning', fallbackTable: 'hr_learning' },
  certifications: { title: 'Sertifikasi', desc: 'Sertifikasi profesional', icon: '📜', rpc: 'get_skills_intelligence', fallbackTable: 'hr_skills' },
  badges:       { title: 'Badge & Gamifikasi', desc: 'Sistem penghargaan & poin', icon: '🏅', rpc: 'admin_get_badges', fallbackTable: 'badges' },
  talent:       { title: 'Talent Market', desc: 'Marketplace internal talent', icon: '🎯', rpc: 'get_talent_marketplace', fallbackTable: 'hr_talent_catalog' },
  career:       { title: 'Career Path', desc: 'Jalur karir & promosi', icon: '🧭', rpc: 'get_career_path', fallbackTable: 'hr_skills' },

  // ASET & FASILITAS
  assets:       { title: 'Inventaris', desc: 'Inventaris aset perusahaan', icon: '🛠️', rpc: 'admin_get_assets', fallbackTable: 'assets' },
  'asset-assign': { title: 'Check-in/out', desc: 'Peminjaman & pengembalian aset', icon: '📦', rpc: 'admin_get_asset_assignments', fallbackTable: 'asset_assignments' },
  estate:       { title: 'Estate Blocks', desc: 'Blok perumahan & fasilitas', icon: '🌳', rpc: 'admin_get_estate_blocks', fallbackTable: 'estate_blocks' },
  facility:     { title: 'Facility Request', desc: 'Permintaan fasilitas kerja', icon: '🏗️', rpc: 'admin_get_facility_requests', fallbackTable: 'facility_requests', hasActions: true, statusField: 'status' },

  // ENGAGEMENT & BUDAYA
  surveys:      { title: 'Survei (eNPS)', desc: 'Employee Net Promoter Score', icon: '📋', rpc: 'get_worker_engagement', fallbackTable: 'hr_engagement' },
  voice:        { title: 'Ide & Voice', desc: 'Saran & masukan karyawan', icon: '💡', rpc: 'list_ideas', fallbackTable: 'hr_voice' },
  whistleblower: { title: 'Whistleblowing', desc: 'Laporan pelanggaran anonim', icon: '🕊️', rpc: null, fallbackTable: 'hr_safety' },

  // OFFBOARDING
  exit:         { title: 'Exit Interview', desc: 'Wawancara keluar karyawan', icon: '🚪', rpc: 'get_exit_clearance', fallbackTable: 'hr_exit_clearance' },
  settlement:   { title: 'Final Settlement', desc: 'Pelunasan hak karyawan', icon: '📄', rpc: 'admin_get_settlements', fallbackTable: 'settlements' },
  clearance:    { title: 'Clearance', desc: 'Checklist serah terima', icon: '✅', rpc: 'get_exit_clearance', fallbackTable: 'hr_exit_clearance' },

  // SISTEM & KEAMANAN
  audit:        { title: 'Audit Log', desc: 'Log aktivitas sistem', icon: '📋', rpc: null, fallbackTable: 'audit_log' },
  export:       { title: 'Export Data', desc: 'Ekspor data ke Excel/CSV', icon: '📤', rpc: null, static: true },
  features:     { title: 'Feature Flags', desc: 'Toggle fitur aktif/nonaktif', icon: '⚙️', rpc: 'admin_get_feature_flags', fallbackTable: 'feature_flags' },
  settings:     { title: 'Pengaturan', desc: 'Konfigurasi sistem', icon: '🔐', rpc: null, static: true },
  chain:        { title: 'Audit Chain', desc: 'Rantai audit transparan', icon: '🔗', rpc: 'admin_get_audit_chain', fallbackTable: 'audit_chain' },

  // PERENCANAAN
  headcount:    { title: 'Headcount Plan', desc: 'Perencanaan jumlah karyawan', icon: '📊', rpc: 'get_workforce_planning', fallbackTable: 'hr_talent_catalog' },
  budget:       { title: 'Budget Allocation', desc: 'Alokasi anggaran HR', icon: '💰', rpc: 'admin_get_budget', fallbackTable: 'budget_allocations' },
  referral:     { title: 'Referral Program', desc: 'Program rekomendasi karyawan', icon: '🤝', rpc: 'admin_get_referrals', fallbackTable: 'referrals' },
};

// ──────────────────────────────────────────────────────────────
// WORKER PAGE CONFIGS
// ──────────────────────────────────────────────────────────────
export const WORKER_PAGE_CONFIGS = {
  attendance:   { title: 'Kehadiran', desc: 'Riwayat kehadiran harian', icon: '📍', rpc: 'get_worker_attendance', fallbackTable: 'hr_attendance', paramField: 'p_nrp' },
  leave:        { title: 'Cuti', desc: 'Ajukan & lihat status cuti', icon: '🌴', rpc: 'get_worker_leave', fallbackTable: 'hr_leave', paramField: 'p_nrp' },
  overtime:     { title: 'Lembur', desc: 'Ajukan & lihat lembur', icon: '💼', rpc: 'get_worker_overtime', fallbackTable: 'hr_overtime', paramField: 'p_nrp' },
  kpi:          { title: 'KPI Saya', desc: 'Target & pencapaian performa', icon: '📊', rpc: 'get_worker_kpi', fallbackTable: 'hr_performance', paramField: 'p_nrp' },
  payroll:      { title: 'Slip Gaji', desc: 'Lihat slip gaji bulanan', icon: '💰', rpc: 'get_worker_payroll', fallbackTable: 'hr_payroll', paramField: 'p_nrp' },
  learning:     { title: 'Learning', desc: 'Kursus & pelatihan', icon: '📚', rpc: 'get_worker_learning', fallbackTable: 'hr_learning', paramField: 'p_nrp' },
  career:       { title: 'Karir', desc: 'Jalur karir & peluang', icon: '🚀', rpc: 'get_career_path', fallbackTable: 'hr_skills', paramField: 'p_nrp' },
  tasks:        { title: 'Tasks', desc: 'Daftar tugas harian', icon: '✅', rpc: 'get_worker_tasks', fallbackTable: 'hr_tasks', paramField: 'p_nrp' },
  profile:      { title: 'Profil Saya', desc: 'Data profil & pengaturan', icon: '👤', rpc: 'get_worker_profile', fallbackTable: 'employees_master', paramField: 'p_nrp' },
  activities:   { title: 'Aktivitas', desc: 'Riwayat aktivitas terkini', icon: '📋', rpc: 'get_worker_activities', fallbackTable: 'audit_log', paramField: 'p_nrp' },
};

// ──────────────────────────────────────────────────────────────
// DETAIL PAGE COMPONENT
// ═════════════════════════════════════════════════════════════
// ============================================================
export default function DetailPageFactory({ pageKey, isAdmin = true }) {
  const navigate = useNavigate();
  const config = isAdmin
    ? ADMIN_PAGE_CONFIGS[pageKey]
    : WORKER_PAGE_CONFIGS[pageKey];

  const [loading, setLoading] = useState(true);
  const [data, setData] = useState([]);
  const [stats, setStats] = useState({});
  const [selected, setSelected] = useState(null);
  const [activeTab, setActiveTab] = useState('all');

  // ── COMPUTED FIELDS ──
  const nrp = typeof window !== 'undefined'
    ? getSession()?.nrp || 'NRP001'
    : 'NRP001';

  const params = config?.paramField ? { [config.paramField]: nrp } : {};

  // ── FETCH DATA ──
  const fetchData = useCallback(async () => {
    if (!config || config.static) { setLoading(false); return; }
    setLoading(true);
    try {
      let result = null;
      if (config.rpc) {
        result = await rpc(config.rpc, params);
      }

      if (result?.ok !== false && Array.isArray(result)) {
        setData(result);
      } else if (result?.data && Array.isArray(result.data)) {
        setData(result.data);
      } else {
        setData([]);
      }
    } catch (err) { }
    setLoading(false);
  }, [pageKey, nrp]);

  useEffect(() => { fetchData(); }, [fetchData]);

  // ── AUTO-DETECT COLUMNS ──
  const columns = React.useMemo(() => {
    if (data.length === 0) return [];
    const sample = data[0];
    const keys = Object.keys(sample).filter(k => !k.startsWith('_') && k !== 'id');

    // Smart column ordering
    const priority = ['nrp', 'nama', 'name', 'title', 'type', 'status', 'divisi', 'division', 'jabatan', 'position', 'created_at', 'date'];
    const sorted = keys.sort((a, b) => {
      const ai = priority.findIndex(p => a.toLowerCase().includes(p));
      const bi = priority.findIndex(p => b.toLowerCase().includes(p));
      return (ai === -1 ? 99 : ai) - (bi === -1 ? 99 : bi);
    });

    return sorted.slice(0, 6).map(key => ({
      key,
      label: key.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase()),
      render: (val) => {
        if (val == null || val === '') return <span className="text-slate-500">-</span>;
        if (typeof val === 'boolean') return <Badge status={val ? 'Ya' : 'Tidak'} type={val ? 'success' : 'default'} />;
        if (key.toLowerCase().includes('status')) {
          const t = (val || '').toLowerCase();
          const badgeType = t === 'active' || t === 'approved' || t === 'completed' || t === 'paid' ? 'success'
            : t === 'pending' || t === 'draft' || t === 'requested' ? 'warning'
            : t === 'rejected' || t === 'cancelled' || t === 'inactive' ? 'danger' : 'info';
          return <Badge status={val} type={badgeType} />;
        }
        if (typeof val === 'number') return <span className="text-xs font-semibold text-white">{val.toLocaleString('id-ID')}</span>;
        if (String(val).length > 40) return <span className="text-xs text-slate-300 truncate block max-w-[150px]">{val}</span>;
        return <span className="text-xs text-slate-300">{String(val)}</span>;
      },
    }));
  }, [data]);

  // ── STAT CARDS ──
  const statCards = React.useMemo(() => {
    if (data.length === 0) return [];
    const total = data.length;
    const statusField = config?.statusField || 'status';

    // Count by status
    const statusCounts = {};
    data.forEach(row => {
      const s = (row[statusField] || 'Unknown').toString();
      statusCounts[s] = (statusCounts[s] || 0) + 1;
    });

    const statusColors = {
      active: 'green', approved: 'green', completed: 'green', paid: 'green',
      pending: 'orange', draft: 'orange', requested: 'orange',
      rejected: 'red', cancelled: 'red', inactive: 'red',
    };

    const cards = [{ icon: '📊', value: total, label: 'Total', trend: 'Semua', color: 'blue' }];

    Object.entries(statusCounts).slice(0, 3).forEach(([status, count]) => {
      const normalized = status.toLowerCase();
      cards.push({
        icon: normalized === 'pending' || normalized === 'draft' ? '⏳' : normalized === 'active' || normalized === 'approved' ? '✅' : '📋',
        value: count,
        label: status,
        trend: `${((count / total) * 100).toFixed(0)}%`,
        color: statusColors[normalized] || 'slate',
      });
    });

    return cards;
  }, [data, config]);

  // ── STATUSES FOR TABS ──
  const statuses = React.useMemo(() => {
    if (data.length === 0) return [];
    const statusField = config?.statusField || 'status';
    const set = new Set(data.map(r => r[statusField]).filter(Boolean));
    return Array.from(set);
  }, [data, config]);

  // ── FILTER ──
  const filtered = React.useMemo(() => {
    if (activeTab === 'all') return data;
    return data.filter(row => {
      const statusField = config?.statusField || 'status';
      return (row[statusField] || '').toLowerCase() === activeTab.toLowerCase();
    });
  }, [data, activeTab, config]);

  // ── STATIC PAGES ──
  if (config?.static) {
    return (
      <PageLayout backTo={isAdmin ? '/admin' : '/worker'} title={config.title} subtitle={config.desc}>
        <div className="flex flex-col items-center justify-center py-20 text-center animate-fade-in">
          <span className="text-6xl mb-4">{config.icon}</span>
          <h2 className="text-xl font-bold text-white mb-2">{config.title}</h2>
          <p className="text-sm text-slate-400 mb-6 max-w-xs">{config.desc}</p>
          <GlassCard accent="blue" className="w-full max-w-md">
            <div className="text-center py-4">
              <p className="text-sm text-slate-300 mb-4">Halaman ini menggunakan konfigurasi statis dan tidak memerlukan data dari database.</p>
              <Button color="teal" onClick={() => navigate(isAdmin ? '/admin' : '/worker')}>Kembali</Button>
            </div>
          </GlassCard>
        </div>
      </PageLayout>
    );
  }

  // ── LOADING ──
  if (loading) {
    return (
      <PageLayout backTo={isAdmin ? '/admin' : '/worker'} title={config?.title || pageKey} subtitle={config?.desc}>
        <LoadingSpinner text={`Memuat data ${config?.title || pageKey}...`} />
      </PageLayout>
    );
  }

  return (
    <PageLayout backTo={isAdmin ? '/admin' : '/worker'} title={config?.title || pageKey} subtitle={`${data.length} data`}>
      {/* ── METRICS ── */}
      {statCards.length > 0 && (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
          {statCards.map((s, i) => <MetricCard key={i} {...s} />)}
        </div>
      )}

      {/* ── FILTER TABS ── */}
      {statuses.length > 1 && (
        <div className="mb-4">
          <Tabs
            tabs={[
              { id: 'all', label: 'Semua', count: data.length },
              ...statuses.map(s => ({ id: s, label: s, count: data.filter(r => (r[config?.statusField || 'status'] || '') === s).length })),
            ]}
            active={activeTab}
            onChange={setActiveTab}
          />
        </div>
      )}

      {/* ── DATA TABLE ── */}
      <GlassCard accent="blue">
        <DataTable
          columns={columns}
          data={filtered}
          searchPlaceholder={`Cari ${config?.title?.toLowerCase() || pageKey}...`}
          onRowClick={(row) => setSelected(row)}
          emptyMessage={`Tidak ada data ${config?.title || pageKey}`}
        />
      </GlassCard>

      {/* ── DETAIL MODAL ── */}
      {selected && (
        <DetailModal
          data={selected}
          title={config?.title || pageKey}
          onClose={() => setSelected(null)}
          hasActions={config?.hasActions}
          onApprove={config?.hasActions && config.rpc ? async () => {
            const session = getSession();
            if (!canUserApprove(session?.role)) {
              alert('Anda tidak memiliki hak untuk approve data ini.');
              return;
            }
            if (!window.confirm('Yakin ingin mengapprove data ini?')) return;
            try {
              await rpc(`${config.rpc.replace('get', 'approve')}`, { p_id: selected.id, p_status: 'Approved' });
              setData(data.filter(r => r.id !== selected.id));
              setSelected(null);
            } catch (e) { }
          } : null}
          onReject={config?.hasActions ? async () => {
            try {
              await rpc(`${config.rpc.replace('get', 'approve')}`, { p_id: selected.id, p_status: 'Rejected' });
              setData(data.filter(r => r.id !== selected.id));
              setSelected(null);
            } catch (e) { }
          } : null}
        />
      )}
    </PageLayout>
  );
}

// ──────────────────────────────────────────────────────────────
// DETAIL MODAL
// ──────────────────────────────────────────────────────────────
function DetailModal({ data, title, onClose, hasActions, onApprove, onReject }) {
  if (!data) return null;

  return (
    <>
      <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm animate-fade-in" onClick={onClose} />
      <div className="fixed inset-x-0 bottom-0 z-50 max-h-[85vh] bg-slate-900 border-t border-white/10 rounded-t-3xl overflow-y-auto animate-slide-up">
        <div className="flex justify-center pt-3 pb-1">
          <div className="w-10 h-1 rounded-full bg-slate-600" />
        </div>
        <div className="px-5 pb-8">
          <h2 className="text-lg font-bold text-white mb-4">{title} — Detail</h2>

          <div className="space-y-1 mb-5">
            {Object.entries(data).filter(([k]) => !k.startsWith('_') && k !== 'id').map(([key, val]) => (
              <div key={key} className="flex items-center justify-between py-2 border-b border-white/3">
                <span className="text-xs text-slate-400 capitalize">{key.replace(/_/g, ' ')}</span>
                <span className="text-xs font-semibold text-white text-right max-w-[60%] break-words">
                  {val == null ? '-' : typeof val === 'boolean' ? (val ? 'Ya' : 'Tidak') : String(val)}
                </span>
              </div>
            ))}
          </div>

          {hasActions && (
            <div className="flex gap-2">
              <Button color="green" size="sm" className="flex-1" onClick={onApprove}>✓ Approve</Button>
              <Button color="red" size="sm" variant="outline" className="flex-1" onClick={onReject}>✕ Reject</Button>
            </div>
          )}

          <div className="mt-4 flex justify-end">
            <Button color="ghost" size="sm" onClick={onClose}>✕ Tutup</Button>
          </div>
        </div>
      </div>
    </>
  );
}
