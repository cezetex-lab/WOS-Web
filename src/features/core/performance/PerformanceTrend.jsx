// ============================================================
// PerformanceTrend.jsx — #39 Performance Trend Tim (Chart.js)
// Menampilkan grafik KPI per periode untuk manager & worker
// ============================================================

import React, { useState, useEffect, useRef, useCallback } from 'react';
import { supabase, rpc, getSession } from '../../../lib/supabase-browser';
import {
  PageLayout, GlassCard, Badge, LoadingSpinner, EmptyState, StatItem, SectionHeader
} from '../../../lib/design-system';
import { useChart, CHART_DEFAULTS, COLORS as THEME_COLORS } from '../../../lib/chart-config';

const COLORS = {
  blue: '#38bdf8',
  teal: '#2dd4bf',
  green: '#34d399',
  orange: '#fb923c',
  purple: '#a78bfa',
  red: '#f87171',
};

export default function PerformanceTrend() {
  const nrp = getSession()?.nrp || 'NRP001';
  const role = getSession()?.role || 'worker';
  const [loading, setLoading] = useState(true);
  const [perfData, setPerfData] = useState([]);
  const [teamData, setTeamData] = useState([]);

  // Chart refs
  const trendCanvas = useRef(null);
  const barCanvas = useRef(null);
  const radarCanvas = useRef(null);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      if (role === 'manager') {
        const [perf, team] = await Promise.all([
          rpc('get_continuous_perf_team', { p_nrp: nrp }),
          rpc('get_team_data', { p_nrp: nrp }),
        ]);
        setPerfData(perf?.data || perf || []);
        setTeamData(team?.data || team || []);
      } else {
        const perf = await rpc('get_worker_kpi', { p_nrp: nrp });
        setPerfData(perf?.data || perf || []);
      }
    } catch (err) { }
    setLoading(false);
  }, [nrp, role]);

  useEffect(() => { fetchData(); }, [fetchData]);

  // ── CHART 1: Trend Line ──
  const trendData = React.useMemo(() => {
    if (!perfData.length) return null;
    const sorted = [...perfData].sort((a, b) => (a.periode || '').localeCompare(b.periode || ''));
    const labels = sorted.map(d => d.periode || '-');
    const scores = sorted.map(d => Number(d.kpi_score || d.kpi_scor || 0));
    return { labels, scores };
  }, [perfData]);

  useChart(trendData ? (Chart) => ({
    type: 'line',
    data: {
      labels: trendData.labels,
      datasets: [{
        label: 'KPI Score',
        data: trendData.scores,
        borderColor: COLORS.teal,
        backgroundColor: COLORS.teal + '33',
        fill: true,
        tension: 0.4,
        pointRadius: 4,
        pointBackgroundColor: COLORS.teal,
      }],
    },
    options: {
      ...CHART_DEFAULTS,
      plugins: { ...CHART_DEFAULTS.plugins, title: { display: true, text: 'Tren KPI', color: '#fff' } },
      scales: {
        y: { ...CHART_DEFAULTS.scales?.y, min: 0, max: 100, title: { display: true, text: 'Score', color: '#94a3b8' } },
      },
    },
  }) : null, [trendData]);

  // ── CHART 2: Team Bar (manager only) ──
  useChart(teamData.length > 0 ? (Chart) => ({
    type: 'bar',
    data: {
      labels: teamData.map(d => d.nama || d.nrp || '-'),
      datasets: [{
        label: 'KPI Tim',
        data: teamData.map(d => Number(d.kpi_score || d.kpi_scor || 0)),
        backgroundColor: teamData.map((_, i) => [COLORS.teal, COLORS.blue, COLORS.green, COLORS.purple, COLORS.orange][i % 5] + '99'),
        borderRadius: 8,
      }],
    },
    options: {
      ...CHART_DEFAULTS,
      plugins: { ...CHART_DEFAULTS.plugins, title: { display: true, text: 'KPI per Anggota Tim', color: '#fff' } },
      scales: {
        y: { ...CHART_DEFAULTS.scales?.y, min: 0, max: 100 },
      },
    },
  }) : null, [teamData]);

  // ── CHART 3: Radar (individual breakdown) ──
  const radarData = React.useMemo(() => {
    if (!perfData.length) return null;
    const latest = perfData[perfData.length - 1];
    return {
      labels: ['KPI Score', 'Attendance', 'Tasks', 'Engagement', 'Learning'],
      datasets: [{
        label: latest?.periode || 'Latest',
        data: [
          Number(latest?.kpi_score || latest?.kpi_scor || 0),
          Math.min(100, (latest?.hadir || 20) / 25 * 100),
          Math.min(100, (latest?.tasks_done || 10) / 15 * 100),
          Math.min(100, (latest?.engagement || 70)),
          Math.min(100, (latest?.learning_hours || 10) / 20 * 100),
        ],
        backgroundColor: COLORS.teal + '33',
        borderColor: COLORS.teal,
        pointBackgroundColor: COLORS.teal,
      }],
    };
  }, [perfData]);

  useChart(radarData ? (Chart) => ({
    type: 'radar',
    data: radarData,
    options: {
      ...CHART_DEFAULTS,
      plugins: { ...CHART_DEFAULTS.plugins, title: { display: true, text: 'Breakdown Performa', color: '#fff' } },
      scales: {
        r: {
          min: 0, max: 100,
          grid: { color: 'rgba(255,255,255,0.1)' },
          ticks: { display: false },
          pointLabels: { color: '#94a3b8', font: { size: 10 } },
        },
      },
    },
  }) : null, [radarData]);

  if (loading) return <PageLayout backTo={role === 'manager' ? '/dashboard' : '/worker'} title="Performance Trend"><LoadingSpinner text="Memuat data performa..." /></PageLayout>;

  const latest = perfData[perfData.length - 1] || {};

  return (
    <PageLayout backTo={role === 'manager' ? '/dashboard' : '/worker'} title="Performance Trend" subtitle={`${perfData.length} periode`}>
      {/* ── STAT CARDS ── */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
        <StatItem label="KPI Score" value={latest.kpi_score || latest.kpi_scor || 0} max={100} color={COLORS.teal} suffix="%" />
        <StatItem label="Attendance" value={`${latest.hadir || 0}/${latest.total_hari || 25}`} color={COLORS.blue} />
        <StatItem label="Tasks Done" value={latest.tasks_done || 0} max={15} color={COLORS.green} />
        <StatItem label="Periode" value={latest.periode || '-'} color={COLORS.purple} />
      </div>

      {/* ── TREND CHART ── */}
      <GlassCard title="Tren KPI" icon="📈" accent="teal" className="mb-4">
        <div className="h-64">
          <canvas ref={trendCanvas} />
        </div>
        {perfData.length === 0 && <EmptyState icon="📊" title="Belum ada data performa" />}
      </GlassCard>

      {/* ── RADAR CHART ── */}
      <GlassCard title="Breakdown Performa" icon="🎯" accent="blue" className="mb-4">
        <div className="h-64">
          <canvas ref={radarCanvas} />
        </div>
      </GlassCard>

      {/* ── TEAM BAR CHART (Manager only) ── */}
      {role === 'manager' && teamData.length > 0 && (
        <GlassCard title="KPI Tim" icon="👥" accent="purple" className="mb-4">
          <div className="h-64">
            <canvas ref={barCanvas} />
          </div>
        </GlassCard>
      )}

      {/* ── HISTORY TABLE ── */}
      <GlassCard title="Riwayat Performa" icon="📋" accent="slate">
        <div className="space-y-2">
          {perfData.length === 0 ? (
            <EmptyState icon="📭" title="Tidak ada riwayat" />
          ) : (
            [...perfData].reverse().map((item, i) => (
              <div key={i} className="flex items-center justify-between p-3 bg-slate-900/40 rounded-xl border border-white/5">
                <div>
                  <p className="text-xs font-bold text-white">{item.periode || '-'}</p>
                  <p className="text-[11px] text-slate-500">KPI: {item.kpi_score || item.kpi_scor || 0}</p>
                </div>
                <Badge
                  status={Number(item.kpi_score || item.kpi_scor || 0) >= 80 ? 'Excellent' : Number(item.kpi_score || item.kpi_scor || 0) >= 60 ? 'Good' : 'Needs Improvement'}
                  type={Number(item.kpi_score || item.kpi_scor || 0) >= 80 ? 'success' : Number(item.kpi_score || item.kpi_scor || 0) >= 60 ? 'warning' : 'danger'}
                />
              </div>
            ))
          )}
        </div>
      </GlassCard>
    </PageLayout>
  );
}
