// WorkerKpi.jsx — Target & pencapaian performa karyawan
import { getSession } from '@/lib/supabase-browser';
import React, { useState, useEffect, useCallback } from 'react';
import { rpc } from '../../../lib/supabase-browser';
import { PageLayout, GlassCard, MetricCard, Badge, LoadingSpinner, EmptyState } from '../../../lib/design-system';

export default function WorkerKpi() {
  const [loading, setLoading] = useState(true);
  const [data, setData] = useState([]);
  const [profile, setProfile] = useState({});

    const nrp = getSession()?.nrp || 'NRP001';

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('get_worker_kpi', { p_nrp: nrp });
      setData(Array.isArray(result) ? result : result?.data || []);
      if (result?.profile) setProfile(result.profile);
    } catch (e) { console.error(e); }
    setLoading(false);
  }, [nrp]);

  useEffect(() => { fetchData(); }, [fetchData]);

  const latest = data.length > 0 ? data[0] : null;
  const avgScore = data.length > 0 ? (data.reduce((s, r) => s + (parseFloat(r.kpi_score || r.overall_score || 0)), 0) / data.length).toFixed(1) : 0;

  const getScoreColor = (score) => {
    if (score >= 80) return 'green';
    if (score >= 60) return 'teal';
    if (score >= 40) return 'orange';
    return 'red';
  };

  const getScoreLabel = (score) => {
    if (score >= 90) return '⭐ Sangat Baik';
    if (score >= 75) return '✅ Baik';
    if (score >= 60) return '⚠️ Cukup';
    return '❌ Perlu Perbaikan';
  };

  if (loading) return <PageLayout backTo="/worker" title="KPI Saya"><LoadingSpinner text="Memuat data KPI..." /></PageLayout>;

  return (
    <PageLayout backTo="/worker" title="📊 KPI Saya" subtitle={profile.nama || nrp}>
      <div className="grid grid-cols-2 gap-3 mb-6">
        <MetricCard icon="📊" value={`${avgScore}`} label="Rata-rata KPI" color={getScoreColor(parseFloat(avgScore))} />
        <MetricCard icon="📅" value={data.length} label="Periode Tercatat" color="blue" />
      </div>

      {/* Latest Score Card */}
      {latest && (
        <GlassCard accent="blue" className="mb-6">
          <div className="text-center py-4">
            <p className="text-xs text-slate-400 mb-2">Skor Terakhir</p>
            <div className="text-6xl font-bold text-white mb-2">{latest.kpi_score || latest.overall_score || 0}</div>
            <Badge status={getScoreLabel(latest.kpi_score || latest.overall_score || 0)} type={getScoreColor(latest.kpi_score || latest.overall_score || 0)} />
            <p className="text-xs text-slate-400 mt-2">{latest.period || latest.periode || '-'}</p>
          </div>
        </GlassCard>
      )}

      {/* Breakdown */}
      {latest && (
        <GlassCard accent="teal" className="mb-4">
          <h3 className="text-sm font-bold text-white mb-3">📋 Rincian Skor</h3>
          <div className="space-y-3">
            {[
              { label: 'Kehadiran', value: latest.attendance_score, max: 100, color: 'bg-green-500' },
              { label: 'Produktivitas', value: latest.productivity_score, max: 100, color: 'bg-blue-500' },
              { label: 'Sikap Kerja', value: latest.attitude_score, max: 100, color: 'bg-teal-500' },
              { label: 'Inisiatif', value: latest.initiative_score, max: 100, color: 'bg-purple-500' },
            ].map((item, i) => (
              <div key={i}>
                <div className="flex justify-between text-xs mb-1">
                  <span className="text-slate-300">{item.label}</span>
                  <span className="text-white font-semibold">{item.value || 0}/{item.max}</span>
                </div>
                <div className="w-full bg-slate-700 rounded-full h-2">
                  <div className={`${item.color} h-2 rounded-full transition-all`} style={{ width: `${((item.value || 0) / item.max) * 100}%` }} />
                </div>
              </div>
            ))}
          </div>
        </GlassCard>
      )}

      {/* History */}
      <GlassCard accent="blue">
        <h3 className="text-sm font-bold text-white mb-3">📈 Riwayat KPI</h3>
        {data.length > 0 ? (
          <div className="space-y-2">
            {data.slice(0, 12).map((row, i) => (
              <div key={i} className="flex items-center justify-between py-2 border-b border-white/5">
                <div>
                  <p className="text-xs text-white">{row.period || row.periode || `Periode ${i + 1}`}</p>
                  <p className="text-[10px] text-slate-400">Kehadiran: {row.attendance_score || 0} • Prod: {row.productivity_score || 0}</p>
                </div>
                <Badge status={`${row.kpi_score || row.overall_score || 0}`} type={getScoreColor(row.kpi_score || row.overall_score || 0)} />
              </div>
            ))}
          </div>
        ) : (
          <EmptyState title="Belum ada data KPI" subtitle="KPI akan muncul setelah evaluasi periodik" icon="📊" />
        )}
      </GlassCard>
    </PageLayout>
  );
}
