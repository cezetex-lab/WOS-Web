// src/pages/Worker.jsx
import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase, clearSession, getSession } from '../lib/supabase-browser';
import { MetricCard, QuickTile, GlassCard, LoadingSpinner, SectionHeader, Badge, Button } from '../lib/design-system';
import { getUserModules, getBusinessUnit } from '../lib/business-units';

export default function Worker() {
  const navigate = useNavigate();
  const [nrp] = useState(() => getSession()?.nrp || 'NRP001');
  const modules = getUserModules();
  const bu = getBusinessUnit();
  const [loading, setLoading] = useState(true);

  function logout() { clearSession(); window.location.href = '/'; }
  const [status, setStatus] = useState({});
  const [narrative, setNarrative] = useState(null);
  const [announcements, setAnnouncements] = useState([]);

  useEffect(() => {
    const fetchData = async () => {
      setLoading(true);
      // 1. Status Worker
      const { data: statusData } = await supabase.rpc('get_worker_status', { p_nrp: nrp });
      setStatus(statusData || {});
      
      // 2. NARRATIVE ENGINE (get_worker_narrative)
      const { data: narrativeData } = await supabase.rpc('get_worker_narrative', { p_nrp: nrp });
      setNarrative(narrativeData);
      
      // 3. Pengumuman
      const { data: annData } = await supabase.rpc('get_announcements');
      setAnnouncements(annData?.data || []);
      setLoading(false);
    };
    fetchData();
  }, [nrp]);

  if (loading) return <LoadingSpinner text="Memuat data..." />;

  return (
    <div className="max-w-7xl mx-auto px-4 py-6 pb-28">
      {/* Header */}
      <div className="flex items-start justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-white tracking-tight">Ringkasan Hari Ini</h1>
          <div className="flex items-center gap-2 mt-1">
            <p className="text-slate-400 text-sm">{new Date().toLocaleDateString('id-ID', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })}</p>
            <Badge status={`${modules.icon} ${modules.label}`} type="info" />
          </div>
        </div>
        <button onClick={logout} className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-slate-800/80 hover:bg-red-500/20 border border-white/5 hover:border-red-500/30 text-slate-400 hover:text-red-400 transition-all text-sm" title="Logout">
          <span>🚪</span>
          <span className="hidden sm:inline text-xs font-medium">Keluar</span>
        </button>
      </div>

      {/* 1. METRIC CARDS */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
        <MetricCard icon="✅" value={`${status.attendance_hadir || 0}/${status.attendance_total || 0}`} label="Kehadiran" trend={`${status.attendance_total || 0} Hari`} color="teal" />
        <MetricCard icon="📋" value={status.pending_requests || 0} label="Pengajuan" trend="Menunggu" color="blue" />
        <MetricCard icon="⏳" value="0" label="Menunggu" trend="Approval" color="orange" />
        <MetricCard icon="🔔" value={status.unread_notifications || 2} label="Notifikasi" trend="Baru" color="purple" />
      </div>

      {/* 2. QUICK ACCESS — BU-SPECIFIC */}
      <div className="grid grid-cols-4 gap-2 mb-6 bg-slate-800/30 p-4 rounded-2xl border border-white/5">
        {modules.quickTiles.map((tile, i) => (
          <QuickTile key={i} icon={tile.icon} label={tile.label} color={tile.color} onClick={() => navigate(tile.path)} />
        ))}
      </div>

      {/* 3. INSIGHT (NARRATIVE ENGINE) - CORE DARI HARI INI */}
      <GlassCard title="Insight Hari Ini" icon="💬" accent="teal" className="mb-6">
        {narrative ? (
          <div className="space-y-2">
            <p className="text-base font-semibold text-white">{narrative.sapaan || 'Halo, selamat datang!'}</p>
            <p className="text-slate-300 leading-relaxed">{narrative.analisis || 'Silakan cek performa terbaru Anda.'}</p>
            {narrative.action_plan && (
              <div className="mt-3 p-3 bg-teal-500/10 border border-teal-500/20 rounded-xl">
                <p className="text-xs font-bold text-teal-400 uppercase tracking-wider">📌 Rekomendasi</p>
                <p className="text-sm text-white mt-1">{narrative.action_plan}</p>
              </div>
            )}
            <p className="text-xs text-slate-400 italic mt-2">{narrative.penutup || 'Tim HRD siap mendukung.'}</p>
            <div className="flex justify-between items-center mt-2 pt-2 border-t border-white/5">
              <span className="text-xs text-slate-500">KPI: <b className="text-white">{narrative.kpi_score}/{narrative.kpi_target}</b></span>
              <span className="text-xs bg-emerald-500/20 text-emerald-300 px-2 py-0.5 rounded-full">Live Data</span>
            </div>
          </div>
        ) : (
          <p className="text-slate-400">Data performa sedang dimuat...</p>
        )}
      </GlassCard>

      {/* 4. PENGUMUMAN */}
      <SectionHeader title="Pengumuman Terbaru" icon="📢" />
      <GlassCard accent="blue">
        {announcements.length === 0 ? (
          <p className="text-slate-400 text-sm text-center py-4">📭 Tidak ada pengumuman</p>
        ) : (
          announcements.slice(0, 2).map((item) => (
            <div key={item.id} className="p-3 bg-white/5 rounded-xl mb-2 last:mb-0 border border-white/5">
              <div className="flex items-center justify-between">
                <h4 className="text-sm font-bold text-white">{item.title}</h4>
                {item.priority === 'HIGH' && <span className="text-[10px] font-bold text-red-400 bg-red-500/20 px-2 py-0.5 rounded-full">Penting</span>}
              </div>
              <p className="text-xs text-slate-400 mt-1">{item.message}</p>
            </div>
          ))
        )}
        <button className="text-xs font-bold text-teal-400 hover:text-teal-300 transition-all mt-2 flex items-center gap-1">
          Lihat Semua →
        </button>
      </GlassCard>

      {/* 5. AKUN SAYA */}
      <SectionHeader title="Akun Saya" icon="👤" />
      <div className="grid grid-cols-2 gap-3">
        <button onClick={() => navigate('/worker/profile')}
          className="flex items-center gap-3 p-4 bg-slate-800/50 rounded-2xl border border-white/5 hover:border-teal-500/30 transition-all">
          <span className="text-2xl">👤</span>
          <div className="text-left">
            <p className="text-white text-sm font-semibold">Profil Saya</p>
            <p className="text-slate-400 text-[10px]">Lihat & edit data</p>
          </div>
        </button>
        <button onClick={() => navigate('/worker/change-password')}
          className="flex items-center gap-3 p-4 bg-slate-800/50 rounded-2xl border border-white/5 hover:border-red-500/30 transition-all">
          <span className="text-2xl">🔑</span>
          <div className="text-left">
            <p className="text-white text-sm font-semibold">Ganti Password</p>
            <p className="text-slate-400 text-[10px]">Ubah password akun</p>
          </div>
        </button>
      </div>
    </div>
  );
}