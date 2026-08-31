// src/pages/Admin.jsx
import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase, clearSession } from '../lib/supabase-browser';
import { MetricCard, QuickTile, GlassCard, ActionItem, EmptyState, LoadingSpinner } from '../lib/design-system';

export default function Admin() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);

  function logout() { clearSession(); window.location.href = '/'; }
  const [stats, setStats] = useState({});
  const [pending, setPending] = useState([]);
  const [autoHealing, setAutoHealing] = useState([]);
  const [anomalies, setAnomalies] = useState([]);

  useEffect(() => {
    const fetchData = async () => {
      setLoading(true);
      // 1. Statistik Admin
      const { data: statsData } = await supabase.rpc('admin_get_summary');
      setStats(statsData || {});
      
      // 2. Pending Requests (dari UI Fix 022)
      const { data: pendingData } = await supabase.rpc('admin_get_pending_requests');
      setPending(pendingData?.data || []);
      
      // 3. HREngine: Auto Healing Actions
      const { data: healingData } = await supabase.rpc('get_auto_healing_actions');
      setAutoHealing(healingData?.data || []);
      
      // 4. HREngine: Anomaly Sentinel
      const { data: anomalyData } = await supabase.rpc('get_anomaly_sentinel');
      setAnomalies(anomalyData?.data || []);
      
      setLoading(false);
    };
    fetchData();
  }, []);

  if (loading) return <LoadingSpinner text="Memuat data admin..." />;

  return (
    <div className="max-w-7xl mx-auto px-4 py-6 pb-28">
      {/* Header */}
      <div className="flex items-start justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-white tracking-tight">Selamat Datang, Admin</h1>
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

      {/* 2. QUICK ACCESS GRID */}
      <div className="grid grid-cols-4 gap-2 mb-6 bg-slate-800/30 p-4 rounded-2xl border border-white/5">
        <QuickTile icon="📝" label="Pengajuan" color="blue" onClick={() => navigate('/admin/requests')} />
        <QuickTile icon="👥" label="Karyawan" color="slate" onClick={() => navigate('/admin/employees')} />
        <QuickTile icon="🏢" label="Organisasi" color="slate" onClick={() => navigate('/admin/org')} />
        <QuickTile icon="💰" label="Payroll" color="teal" onClick={() => navigate('/admin/payroll')} />
        <QuickTile icon="📊" label="KPI" color="purple" onClick={() => navigate('/admin/kpi')} />
        <QuickTile icon="📈" label="Analytics" color="orange" onClick={() => navigate('/admin/analytics')} />
        <QuickTile icon="📋" label="Audit" color="slate" onClick={() => navigate('/admin/audit')} />
        <QuickTile icon="🔑" label="Reset PW" color="red" onClick={() => navigate('/admin/reset-password')} />
        <QuickTile icon="⚙️" label="Pengaturan" color="slate" onClick={() => navigate('/admin/settings')} />
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
                  <p className="text-[10px] text-slate-400">{item.type}</p>
                </div>
                <span className="text-[10px] font-bold text-orange-300 bg-orange-500/20 px-2 py-0.5 rounded-full">Proses</span>
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