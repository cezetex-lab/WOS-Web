// src/pages/Admin.jsx
import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase, rpc, clearSession, getSession, signOutAuth } from '../lib/supabase-browser';
import { MetricCard, QuickTile, GlassCard, ActionItem, EmptyState, LoadingSpinner } from '../lib/design-system';

// Role badges
const ROLE_BADGES = {
  admin_pusat: { label: 'Admin Pusat', color: 'bg-red-500/20 text-red-400 border-red-500/30', icon: '👑' },
  admin_hrd: { label: 'Admin HRD', color: 'bg-blue-500/20 text-blue-400 border-blue-500/30', icon: '👥' },
  admin_finance: { label: 'Admin Finance', color: 'bg-green-500/20 text-green-400 border-green-500/30', icon: '💰' },
  admin_produksi: { label: 'Admin Produksi', color: 'bg-orange-500/20 text-orange-400 border-orange-500/30', icon: '⚙️' },
};

// Quick tiles per admin role
const ADMIN_TILES = {
  admin_pusat: [
    { icon: '📝', label: 'Pengajuan', color: 'blue', path: '/admin/requests' },
    { icon: '👥', label: 'Karyawan', color: 'slate', path: '/admin/employees' },
    { icon: '🏢', label: 'Organisasi', color: 'slate', path: '/admin/org' },
    { icon: '💰', label: 'Payroll', color: 'teal', path: '/admin/payroll' },
    { icon: '📊', label: 'KPI', color: 'purple', path: '/admin/kpi' },
    { icon: '📈', label: 'Analytics', color: 'orange', path: '/admin/analytics' },
    { icon: '📋', label: 'Audit', color: 'slate', path: '/admin/audit' },
    { icon: '🔑', label: 'Reset PW', color: 'red', path: '/admin/reset-password' },
    { icon: '⚙️', label: 'Pengaturan', color: 'slate', path: '/admin/settings' },
  ],
  admin_hrd: [
    { icon: '👥', label: 'Karyawan', color: 'blue', path: '/admin/employees' },
    { icon: '📋', label: 'Rekrutmen', color: 'teal', path: '/admin/recruitment' },
    { icon: '📝', label: 'Pengajuan', color: 'slate', path: '/admin/requests' },
    { icon: '📊', label: 'KPI', color: 'purple', path: '/admin/kpi' },
    { icon: '📚', label: 'Learning', color: 'orange', path: '/admin/learning' },
    { icon: '🎯', label: 'Talent', color: 'teal', path: '/admin/talent' },
    { icon: '🚪', label: 'Offboarding', color: 'red', path: '/admin/exit' },
    { icon: '🔑', label: 'Reset PW', color: 'red', path: '/admin/reset-password' },
    { icon: '⚙️', label: 'Pengaturan', color: 'slate', path: '/admin/settings' },
  ],
  admin_finance: [
    { icon: '💰', label: 'Payroll', color: 'teal', path: '/admin/payroll' },
    { icon: '💰', label: 'Budget', color: 'green', path: '/admin/budget' },
    { icon: '📊', label: 'KPI', color: 'purple', path: '/admin/kpi' },
    { icon: '⏱️', label: 'Timesheet', color: 'blue', path: '/admin/timesheet' },
    { icon: '⏰', label: 'Lembur', color: 'orange', path: '/admin/overtime' },
    { icon: '📤', label: 'Export', color: 'slate', path: '/admin/export' },
    { icon: '📋', label: 'Audit', color: 'slate', path: '/admin/audit' },
    { icon: '⚙️', label: 'Pengaturan', color: 'slate', path: '/admin/settings' },
  ],
  admin_produksi: [
    { icon: '⏱️', label: 'Timesheet', color: 'blue', path: '/admin/timesheet' },
    { icon: '🔄', label: 'Shift', color: 'teal', path: '/admin/shift-swap' },
    { icon: '⏰', label: 'Lembur', color: 'orange', path: '/admin/overtime' },
    { icon: '🛠️', label: 'Aset', color: 'slate', path: '/admin/assets' },
    { icon: '📊', label: 'KPI', color: 'purple', path: '/admin/kpi' },
    { icon: '📝', label: 'Pengajuan', color: 'blue', path: '/admin/requests' },
    { icon: '🏗️', label: 'Fasilitas', color: 'slate', path: '/admin/facility' },
    { icon: '⚙️', label: 'Pengaturan', color: 'slate', path: '/admin/settings' },
  ],
};

export default function Admin() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const session = getSession();
  const adminRole = session?.role || 'admin_pusat';
  const badge = ROLE_BADGES[adminRole] || ROLE_BADGES.admin_pusat;

  async function logout() { clearSession(); try { await signOutAuth(); } catch(e) {} window.location.href = '/'; }
  const [stats, setStats] = useState({});
  const [pending, setPending] = useState([]);
  const [autoHealing, setAutoHealing] = useState([]);
  const [anomalies, setAnomalies] = useState([]);

  useEffect(() => {
    console.log('[Admin Dashboard] Session data:', session);
    console.log('[Admin Dashboard] Admin role:', adminRole);
    
    if (!session || !session.nrp) {
      console.error('[Admin Dashboard] No valid session found, redirecting to login');
      window.location.href = '/';
      return;
    }

    const fetchData = async () => {
      setLoading(true);
      try {
        console.log('[Admin Dashboard] Starting data fetch...');
        const [s, p, h, a] = await Promise.allSettled([
          rpc('get_dashboard_stats'),
          rpc('admin_get_pending_requests'),
          rpc('get_auto_healing_actions'),
          rpc('get_anomaly_sentinel'),
        ]);
        
        console.log('[Admin Dashboard] RPC results:', { 
          stats: s.status, 
          pending: p.status, 
          autoHealing: h.status, 
          anomalies: a.status 
        });
        
        if (s.status === 'fulfilled' && s.value) {
          console.log('[Admin Dashboard] Stats data:', s.value);
          setStats(s.value.ok !== false ? s.value : {});
        } else {
          console.warn('[Admin Dashboard] Stats RPC failed:', s.reason);
        }
        
        if (p.status === 'fulfilled' && p.value) {
          console.log('[Admin Dashboard] Pending requests data:', p.value);
          setPending(p.value?.data || p.value || []);
        } else {
          console.warn('[Admin Dashboard] Pending requests RPC failed:', p.reason);
        }
        
        if (h.status === 'fulfilled' && h.value) {
          console.log('[Admin Dashboard] Auto-healing data:', h.value);
          setAutoHealing(h.value?.data || h.value || []);
        } else {
          console.warn('[Admin Dashboard] Auto-healing RPC failed:', h.reason);
        }
        
        if (a.status === 'fulfilled' && a.value) {
          console.log('[Admin Dashboard] Anomalies data:', a.value);
          setAnomalies(a.value?.data || a.value || []);
        } else {
          console.warn('[Admin Dashboard] Anomalies RPC failed:', a.reason);
        }
      } catch (e) { 
        console.error('[Admin Dashboard] Data fetch error:', e); 
      }
      setLoading(false);
    };
    fetchData();
  }, [session]);

  if (loading) return <LoadingSpinner text="Memuat data admin..." />;

  const quickTiles = ADMIN_TILES[adminRole] || ADMIN_TILES.admin_pusat;

  return (
    <div className="max-w-7xl mx-auto px-4 py-6 pb-28">
      {/* Header */}
      <div className="flex items-start justify-between mb-6">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <h1 className="text-2xl font-bold text-white tracking-tight">Selamat Datang, Admin</h1>
            <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[11px] font-bold border ${badge.color}`}>
              {badge.icon} {badge.label}
            </span>
          </div>
          <p className="text-slate-400 text-sm">{new Date().toLocaleDateString('id-ID', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })}</p>
        </div>
        <button onClick={logout} className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-slate-800/80 hover:bg-red-500/20 border border-white/5 hover:border-red-500/30 text-slate-400 hover:text-red-400 transition-all text-sm" title="Logout">
          <span>🚪</span>
          <span className="hidden sm:inline text-xs font-medium">Keluar</span>
        </button>
      </div>

      {/* 1. METRIC CARDS */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
        <MetricCard icon="👤" value={stats.total_workers || 0} label="Karyawan" trend="Aktif" color="blue" />
        <MetricCard icon="🏢" value={stats.total_divisions || 0} label="Divisi" trend="Struktural" color="teal" />
        <MetricCard icon="📋" value={stats.pending_requests || 0} label="Pengajuan" trend="Pending" color="orange" />
        <MetricCard icon="📄" value={stats.pkwt_count || 0} label="PKWT" trend={`${stats.retiring_soon || 0} Segera Habis`} color="red" />
      </div>

      {/* 2. QUICK ACCESS GRID — role-aware */}
      <div className="grid grid-cols-4 gap-2 mb-6 bg-slate-800/30 p-4 rounded-2xl border border-white/5">
        {quickTiles.map((tile, i) => (
          <QuickTile key={i} icon={tile.icon} label={tile.label} color={tile.color} onClick={() => navigate(tile.path)} />
        ))}
      </div>

      {/* 3. INSIGHT UTAMA + HREngine */}
      <div className="grid md:grid-cols-2 gap-4 mb-6">
        <GlassCard title="Insight Utama" icon="💡" accent="blue">
          <div className="flex justify-between items-center p-2 bg-black/20 rounded-xl mt-2">
            <span className="text-slate-300">PKWTT</span>
            <span className="text-white font-bold text-lg">{stats.pkwtt_count || 0}</span>
          </div>
          <div className="flex justify-between items-center p-2 bg-black/20 rounded-xl mt-1">
            <span className="text-slate-300">PKWT</span>
            <span className="text-white font-bold text-lg">{stats.pkwt_count || 0}</span>
          </div>
          <div className="flex justify-between items-center p-2 bg-black/20 rounded-xl mt-1">
            <span className="text-slate-300">Pensiun (6 bln)</span>
            <span className="text-white font-bold text-lg">{stats.retiring_soon || 0}</span>
          </div>
        </GlassCard>

        {/* Auto-Healing (HREngine) */}
        <GlassCard title="⚡ Auto-Healing AI" icon="🤖" accent="teal">
          {autoHealing.length === 0 ? (
            <p className="text-slate-400 text-sm">✅ Tidak ada aksi otomatis.</p>
          ) : (
            autoHealing.slice(0, 3).map((item, i) => (
              <div key={i} className="flex items-center gap-2 p-2 bg-red-500/10 border border-red-500/20 rounded-xl mt-1">
                <span className="text-red-400 text-lg">🔴</span>
                <div className="flex-1 min-w-0">
                  <p className="text-xs font-bold text-white truncate">{item.title}</p>
                  <p className="text-[11px] text-slate-400">{item.type}</p>
                </div>
                <span className="text-[11px] font-bold text-orange-300 bg-orange-500/20 px-2 py-0.5 rounded-full">Proses</span>
              </div>
            ))
          )}
        </GlassCard>
      </div>

      {/* 4. PERLU TINDAKAN (Pending + Anomali) */}
      <div className="space-y-4">
        <GlassCard title="Perlu Tindakan" icon="⚠️" accent="red">
          {pending.length === 0 ? (
            <EmptyState icon="✅" title="Semua request sudah diproses" />
          ) : (
            pending.map((req) => (
              <ActionItem 
                key={req.id} 
                title={`Request: ${req.type}`} 
                subtitle={req.note || req.nama} 
                date={req.created_at} 
                badge={req.status} 
                badgeType={req.status === 'Pending' ? 'warning' : 'success'} 
              />
            ))
          )}
          {/* Anomali dari HREngine */}
          {pending.length === 0 && anomalies.length > 0 && (
            anomalies.slice(0, 3).map((anom, i) => (
              <div key={i} className="flex items-center gap-3 p-3 bg-amber-500/10 border border-amber-500/20 rounded-xl mt-2">
                <span className="text-amber-400">⚠️</span>
                <div>
                  <p className="text-sm font-semibold text-white">{anom.title}</p>
                  <p className="text-xs text-slate-400">{anom.type} • {anom.priority}</p>
                </div>
              </div>
            ))
          )}
        </GlassCard>

        {/* 5. NOTIFIKASI */}
        <GlassCard title="Notifikasi" icon="🔔" accent="info">
          <p className="text-slate-400 text-sm">📭 Tidak ada notifikasi baru</p>
        </GlassCard>
      </div>
    </div>
  );
}