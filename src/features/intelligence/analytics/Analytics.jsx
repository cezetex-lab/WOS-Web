// ============================================================
// Analytics.jsx — #81 Analytics Dashboard
// Multi-chart dashboard: KPI, Attendance, Payroll, Headcount
// ============================================================

import React, { useState, useEffect, useRef, useCallback } from 'react';
import { supabase, rpc } from '../../../lib/supabase-browser';
import {
  PageLayout, GlassCard, LoadingSpinner, EmptyState, StatItem,
  Tabs, SectionHeader
} from '../../../lib/design-system';
import { useChart, CHART_DEFAULTS, COLORS } from '../../../lib/chart-config';

const BU_COLORS = {
  MINING: '#f87171',
  ESTATE: '#34d399',
  MILL: '#fb923c',
  HQ: '#38bdf8',
};

export default function Analytics() {
  const [loading, setLoading] = useState(true);
  const [summary, setSummary] = useState(null);
  const [teamKpi, setTeamKpi] = useState([]);
  const [payroll, setPayroll] = useState([]);
  const [attendance, setAttendance] = useState([]);
  const [activeTab, setActiveTab] = useState('overview');

  // Chart refs
  const kpiChartRef = useRef(null);
  const headcountChartRef = useRef(null);
  const payrollChartRef = useRef(null);
  const attendanceChartRef = useRef(null);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const [s, k, p, a] = await Promise.all([
        rpc('get_dashboard_stats'),
        rpc('get_kpi_by_division'),
        rpc('admin_get_payroll'),
        rpc('get_worker_attendance'),
      ]);
      if (s) setSummary(s);
      setTeamKpi(k?.data || k || []);
      setPayroll(p?.data || p || []);
      setAttendance(a?.data || a || []);
    } catch (err) { }
    setLoading(false);
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  // ── CHART: KPI by Division ──
  const kpiData = React.useMemo(() => {
    if (!teamKpi.length) return null;
    const divs = [...new Set(teamKpi.map(d => d.divisi || d.division || 'Unknown'))];
    const avgs = divs.map(div => {
      const items = teamKpi.filter(d => (d.divisi || d.division) === div);
      return items.reduce((s, i) => s + Number(i.avg_kpi || i.kpi_score || 0), 0) / (items.length || 1);
    });
    return { labels: divs.slice(0, 8), data: avgs.slice(0, 8) };
  }, [teamKpi]);

  useChart(kpiData ? (Chart) => ({
    type: 'bar',
    data: {
      labels: kpiData.labels,
      datasets: [{
        label: 'Avg KPI',
        data: kpiData.data,
        backgroundColor: [COLORS.primary, COLORS.success, COLORS.warning, COLORS.error, COLORS.secondary, '#f472b6', '#a78bfa', '#38bdf8'].slice(0, kpiData.labels.length).map(c => c + '99'),
        borderRadius: 8,
      }],
    },
    options: { ...CHART_DEFAULTS, plugins: { ...CHART_DEFAULTS.plugins, title: { display: true, text: 'KPI per Divisi', color: '#fff' } } },
  }) : null, [kpiData]);

  // ── CHART: Headcount by Business Unit ──
  const headcountData = React.useMemo(() => {
    if (!summary) return null;
    return {
      labels: ['MINING', 'ESTATE', 'MILL', 'HQ'],
      data: [summary.mining_count || 0, summary.estate_count || 0, summary.mill_count || 0, summary.hq_count || 0],
    };
  }, [summary]);

  useChart(headcountData ? (Chart) => ({
    type: 'doughnut',
    data: {
      labels: headcountData.labels,
      datasets: [{
        data: headcountData.data,
        backgroundColor: Object.values(BU_COLORS),
        borderColor: '#1e293b',
        borderWidth: 3,
      }],
    },
    options: {
      responsive: true, maintainAspectRatio: false,
      plugins: {
        legend: { position: 'bottom', labels: { color: '#94a3b8', font: { size: 11 }, padding: 12 } },
        title: { display: true, text: 'Headcount per Unit', color: '#fff' },
      },
    },
  }) : null, [headcountData]);

  // ── CHART: Payroll Trend ──
  const payrollData = React.useMemo(() => {
    if (!payroll.length) return null;
    const byBu = {};
    payroll.forEach(p => {
      const bu = p.business_unit || 'HQ';
      byBu[bu] = (byBu[bu] || 0) + Number(p.net_salary || p.gaji_bersih || 0);
    });
    return { labels: Object.keys(byBu), data: Object.values(byBu) };
  }, [payroll]);

  useChart(payrollData ? (Chart) => ({
    type: 'bar',
    data: {
      labels: payrollData.labels,
      datasets: [{
        label: 'Total Payroll (Rp)',
        data: payrollData.data,
        backgroundColor: payrollData.labels.map(l => (BU_COLORS[l] || COLORS.muted) + '99'),
        borderRadius: 8,
      }],
    },
    options: { ...CHART_DEFAULTS, indexAxis: 'y', plugins: { ...CHART_DEFAULTS.plugins, title: { display: true, text: 'Payroll per Unit', color: '#fff' } } },
  }) : null, [payrollData]);

  if (loading) return <PageLayout backTo="/admin" title="Analytics"><LoadingSpinner text="Memuat analytics..." /></PageLayout>;

  const s = summary || {};

  return (
    <PageLayout backTo="/admin" title="Analytics Dashboard" subtitle="Insights & Reports">
      {/* ── STAT CARDS ── */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
        <StatItem label="Total Karyawan" value={s.total_employees || 0} color="#38bdf8" />
        <StatItem label="High Performers" value={s.high_performers || 0} color="#34d399" />
        <StatItem label="Low Performers" value={s.low_performers || 0} color="#f87171" />
        <StatItem label="Pending Requests" value={s.pending_requests || 0} color="#fb923c" />
      </div>

      {/* ── TABS ── */}
      <Tabs
        tabs={[
          { id: 'overview', label: 'Overview' },
          { id: 'kpi', label: 'KPI' },
          { id: 'payroll', label: 'Payroll' },
          { id: 'headcount', label: 'Headcount' },
        ]}
        active={activeTab}
        onChange={setActiveTab}
        className="mb-4"
      />

      {/* ── CHARTS ── */}
      {activeTab === 'overview' && (
        <div className="space-y-4">
          <GlassCard title="Headcount" icon="👥" accent="blue">
            <div className="h-64"><canvas ref={headcountChartRef} /></div>
          </GlassCard>
          <GlassCard title="KPI per Divisi" icon="📊" accent="teal">
            <div className="h-64"><canvas ref={kpiChartRef} /></div>
          </GlassCard>
        </div>
      )}

      {activeTab === 'kpi' && (
        <GlassCard title="KPI Analysis" icon="📊" accent="teal">
          <div className="h-80"><canvas ref={kpiChartRef} /></div>
          {teamKpi.length === 0 && <EmptyState icon="📊" title="Belum ada data KPI" />}
        </GlassCard>
      )}

      {activeTab === 'payroll' && (
        <GlassCard title="Payroll Analysis" icon="💰" accent="green">
          <div className="h-80"><canvas ref={payrollChartRef} /></div>
          {payroll.length === 0 && <EmptyState icon="💰" title="Belum ada data payroll" />}
        </GlassCard>
      )}

      {activeTab === 'headcount' && (
        <GlassCard title="Headcount Distribution" icon="👥" accent="purple">
          <div className="h-80"><canvas ref={headcountChartRef} /></div>
        </GlassCard>
      )}
    </PageLayout>
  );
}
