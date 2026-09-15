// ============================================================
// Kpi.jsx — Halaman KPI / Performance
// RPC: admin_get_kpi_overview, admin_get_kpi_by_division, admin_get_kpi_trend
// ============================================================

import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase, rpc } from '@/lib/supabase-browser';
import useAdminAuth from '@/hooks/useAdminAuth';
import {
  PageLayout, MetricCard, GlassCard, Badge,
  Tabs, LoadingSpinner, EmptyState, Button, StatItem, Avatar, Divider
} from '@/lib/design-system';
type CardColor = 'blue' | 'teal' | 'orange' | 'red' | 'purple' | 'green' | 'slate';
import {
  useChart, buildBarChart, buildDoughnutChart, buildLineChart, COLORS
} from '@/lib/chart-config';
import { getCurrentPeriod, getPeriodLabel } from '@/lib/format';

// ──────────────────────────────────────────────────────────────
// HELPERS

// ──────────────────────────────────────────────────────────────

function getKpiColor(score: number) {
  if (score >= 90) return COLORS.success;
  if (score >= 75) return COLORS.primary;
  if (score >= 60) return COLORS.warning;
  return COLORS.error;
}

function getKpiLabel(score: number) {
  if (score >= 90) return 'Excellent';
  if (score >= 75) return 'Good';
  if (score >= 60) return 'Needs Improvement';
  return 'At Risk';
}

function getKpiBadgeType(score: number) {
  if (score >= 90) return 'success';
  if (score >= 75) return 'info';
  if (score >= 60) return 'warning';
  return 'danger';
}

// ──────────────────────────────────────────────────────────────
// MAIN COMPONENT
// ──────────────────────────────────────────────────────────────
interface KpiOverview {
  avg_kpi?: number;
  avg_score?: number;
  excellent_count?: number;
  good_count?: number;
  improve_count?: number;
  risk_count?: number;
  total_evaluated?: number;
  [key: string]: unknown;
}

interface DivisionData {
  divisi?: string;
  division?: string;
  avg_kpi?: number;
  avg_score?: number;
  total?: number;
  total_employees?: number;
  [key: string]: unknown;
}

interface TrendData {
  period?: string;
  month?: string;
  avg_kpi?: number;
  avg_score?: number;
  [key: string]: unknown;
}

interface PerformerData {
  nama?: string;
  name?: string;
  nrp?: string;
  divisi?: string;
  division?: string;
  kpi_score?: number;
  score?: number;
  [key: string]: unknown;
}

export default function Kpi() {
  useAdminAuth(["admin_pusat", "admin_hrd", "admin_finance", "admin_operasional"]);
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [overview, setOverview] = useState<KpiOverview>({});
  const [byDivision, setByDivision] = useState<DivisionData[]>([]);
  const [trend, setTrend] = useState<TrendData[]>([]);
  const [topPerformers, setTopPerformers] = useState<PerformerData[]>([]);
  const [lowPerformers, setLowPerformers] = useState<PerformerData[]>([]);
  const [activeTab, setActiveTab] = useState('overview');

  // ── CHART REFS ──
  const divisionChartRef = useChart(
    (Chart) => buildBarChart(
      byDivision.map(d => d.divisi || d.division || '-'),
      byDivision.map(d => d.avg_kpi || d.avg_score || 0),
      COLORS.primary
    ),
    [byDivision]
  );

  const distributionChartRef = useChart(
    (Chart) => buildDoughnutChart(
      ['Excellent (90+)', 'Good (75-89)', 'Needs Improvement (60-74)', 'At Risk (<60)'],
      [
        overview.excellent_count || 0,
        overview.good_count || 0,
        overview.improve_count || 0,
        overview.risk_count || 0,
      ],
      [COLORS.success, COLORS.primary, COLORS.warning, COLORS.error]
    ),
    [overview]
  );

  const trendChartRef = useChart(
    (Chart) => buildLineChart(
      trend.map(t => t.period || t.month || '-'),
      [{ label: 'Avg KPI', data: trend.map(t => t.avg_kpi || t.avg_score || 0) }]
    ),
    [trend]
  );

  // ── FETCH DATA ──
  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const [overviewResult, divisionResult, trendResult, topResult, lowResult] = await Promise.all([
        rpc('admin_get_kpi_overview'),
        rpc('get_kpi_by_division'),
        rpc('admin_get_kpi_trend'),
        rpc('admin_get_top_performers'),
        rpc('admin_get_low_performers'),
      ]);

      // Overview
      const ov = overviewResult as KpiOverview | { data?: KpiOverview; ok?: boolean } | null;
      if (ov && typeof ov === 'object' && (ov as { ok?: boolean }).ok !== false && !('data' in ov)) {
        setOverview(ov as KpiOverview);
      } else if (ov && typeof ov === 'object' && 'data' in ov && ov.data) {
        setOverview(ov.data as KpiOverview);
      }

      // By Division
      const dv = divisionResult as DivisionData[] | { data?: DivisionData[]; ok?: boolean } | null;
      if (dv && Array.isArray(dv)) {
        setByDivision(dv);
      } else if (dv && typeof dv === 'object' && 'data' in dv && Array.isArray(dv.data)) {
        setByDivision(dv.data);
      } else {
        setByDivision([]);
      }

      // Trend
      const tv = trendResult as TrendData[] | { data?: TrendData[]; ok?: boolean } | null;
      if (tv && Array.isArray(tv)) {
        setTrend(tv);
      } else if (tv && typeof tv === 'object' && 'data' in tv && Array.isArray(tv.data)) {
        setTrend(tv.data);
      }

      // Top performers
      const tp = topResult as PerformerData[] | { data?: PerformerData[]; ok?: boolean } | null;
      if (tp && Array.isArray(tp)) {
        setTopPerformers(tp);
      } else if (tp && typeof tp === 'object' && 'data' in tp && Array.isArray(tp.data)) {
        setTopPerformers(tp.data);
      }

      // Low performers
      const lp = lowResult as PerformerData[] | { data?: PerformerData[]; ok?: boolean } | null;
      if (lp && Array.isArray(lp)) {
        setLowPerformers(lp);
      } else if (lp && typeof lp === 'object' && 'data' in lp && Array.isArray(lp.data)) {
        setLowPerformers(lp.data);
      }
    } catch (err) { }
    setLoading(false);
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  // ── STAT CARDS ──
  const avgKpi = overview.avg_kpi || overview.avg_score || 0;
  const statCards: { icon: string; value: number | string; label: string; trend: string; color: CardColor }[] = [
    {
      icon: '📊',
      value: typeof avgKpi === 'number' ? avgKpi.toFixed(1) : String(avgKpi),
      label: 'Rata-rata KPI',
      trend: getKpiLabel(avgKpi),
      color: avgKpi >= 75 ? 'green' : avgKpi >= 60 ? 'orange' : 'red',
    },
    {
      icon: '🏆',
      value: overview.excellent_count || 0,
      label: 'Excellent',
      trend: '90+',
      color: 'green',
    },
    {
      icon: '⚠️',
      value: overview.risk_count || 0,
      label: 'At Risk',
      trend: '<60',
      color: 'red',
    },
    {
      icon: '👥',
      value: overview.total_evaluated || 0,
      label: 'Dievaluasi',
      trend: getPeriodLabel(getCurrentPeriod()),
      color: 'blue',
    },
  ];

  // ── TABS ──
  const tabs = [
    { id: 'overview', label: 'Overview' },
    { id: 'division', label: 'Per Divisi' },
    { id: 'performers', label: 'Performers' },
  ];

  // ── LOADING ──
  if (loading) {
    return (
      <PageLayout backTo="/admin" title="KPI" subtitle="Key Performance Indicator">
        <LoadingSpinner text="Memuat data KPI..." />
      </PageLayout>
    );
  }

  return (
    <PageLayout backTo="/admin" title="KPI" subtitle={`Performa ${getPeriodLabel(getCurrentPeriod())}`}>
      {/* ── METRICS ── */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
        {statCards.map((s, i) => (
          <MetricCard key={i} {...s} />
        ))}
      </div>

      {/* ── TABS ── */}
      <div className="mb-4">
        <Tabs tabs={tabs} active={activeTab} onChange={setActiveTab} />
      </div>

      {/* ── OVERVIEW TAB ── */}
      {activeTab === 'overview' && (
        <div className="space-y-4">
          {/* Distribution Chart */}
          <GlassCard title="Distribusi KPI" icon="🍩" accent="purple">
            <div className="h-[220px]">
              <canvas ref={distributionChartRef} />
            </div>
            <div className="grid grid-cols-2 gap-2 mt-4">
              <StatItem label="Excellent (90+)" value={overview.excellent_count || 0} color={COLORS.success} />
              <StatItem label="Good (75-89)" value={overview.good_count || 0} color={COLORS.primary} />
              <StatItem label="Improve (60-74)" value={overview.improve_count || 0} color={COLORS.warning} />
              <StatItem label="At Risk (<60)" value={overview.risk_count || 0} color={COLORS.error} />
            </div>
          </GlassCard>

          {/* Trend Chart */}
          <GlassCard title="Trend KPI" icon="📈" accent="teal">
            <div className="h-[200px]">
              <canvas ref={trendChartRef} />
            </div>
          </GlassCard>
        </div>
      )}

      {/* ── DIVISION TAB ── */}
      {activeTab === 'division' && (
        <div className="space-y-4">
          {/* Bar Chart */}
          <GlassCard title="KPI per Divisi" icon="📊" accent="blue">
            <div className="h-[250px]">
              <canvas ref={divisionChartRef} />
            </div>
          </GlassCard>

          {/* Division List */}
          <GlassCard title="Detail Divisi" icon="📋" accent="teal">
            {byDivision.length === 0 ? (
              <EmptyState icon="📊" title="Belum ada data divisi" />
            ) : (
              <div className="space-y-2">
                {byDivision.map((d, i) => {
                  const score = d.avg_kpi || d.avg_score || 0;
                  return (
                    <div
                      key={i}
                      className="flex items-center justify-between p-3 bg-slate-900/40 rounded-xl border border-white/5"
                    >
                      <div className="flex-1 min-w-0">
                        <div className="text-sm font-semibold text-white">{d.divisi || d.division || '-'}</div>
                        <div className="text-[11px] text-slate-500">{d.total || d.total_employees || 0} karyawan</div>
                      </div>
                      <div className="flex items-center gap-2">
                        <Badge status={getKpiLabel(score)} type={getKpiBadgeType(score)} />
                        <span className="text-sm font-bold text-white">{typeof score === 'number' ? score.toFixed(1) : score}</span>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </GlassCard>
        </div>
      )}

      {/* ── PERFORMERS TAB ── */}
      {activeTab === 'performers' && (
        <div className="space-y-4">
          {/* Top Performers */}
          <GlassCard title="🏆 Top Performers" icon="🌟" accent="green">
            {topPerformers.length === 0 ? (
              <EmptyState icon="🏆" title="Belum ada data top performers" />
            ) : (
              <div className="space-y-2">
                {topPerformers.slice(0, 10).map((p, i) => (
                  <div
                    key={i}
                    className="flex items-center gap-3 p-3 bg-slate-900/40 rounded-xl border border-white/5"
                  >
                    <div className="flex items-center justify-center w-8 h-8 rounded-full bg-emerald-500/20 text-emerald-400 text-sm font-bold">
                      #{i + 1}
                    </div>
                    <Avatar name={p.nama || p.name} size="sm" />
                    <div className="flex-1 min-w-0">
                      <div className="text-sm font-semibold text-white truncate">{p.nama || p.name || '-'}</div>
                      <div className="text-[11px] text-slate-500">{p.nrp || '-'} • {p.divisi || p.division || '-'}</div>
                    </div>
                    <div className="text-right">
                      <div className="text-sm font-bold text-emerald-400">{p.kpi_score || p.score || 0}</div>
                      <div className="text-[11px] text-slate-500">KPI</div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </GlassCard>

          <Divider className="my-2" />

          {/* Low Performers */}
          <GlassCard title="⚠️ Need Attention" icon="📉" accent="red">
            {lowPerformers.length === 0 ? (
              <EmptyState icon="✅" title="Tidak ada karyawan berisiko" subtitle="Semua karyawan dalam rentang aman" />
            ) : (
              <div className="space-y-2">
                {lowPerformers.slice(0, 10).map((p, i) => (
                  <div
                    key={i}
                    className="flex items-center gap-3 p-3 bg-red-500/5 rounded-xl border border-red-500/10"
                  >
                    <div className="flex items-center justify-center w-8 h-8 rounded-full bg-red-500/20 text-red-400 text-sm font-bold">
                      !
                    </div>
                    <Avatar name={p.nama || p.name} size="sm" />
                    <div className="flex-1 min-w-0">
                      <div className="text-sm font-semibold text-white truncate">{p.nama || p.name || '-'}</div>
                      <div className="text-[11px] text-slate-500">{p.nrp || '-'} • {p.divisi || p.division || '-'}</div>
                    </div>
                    <div className="text-right">
                      <div className="text-sm font-bold text-red-400">{p.kpi_score || p.score || 0}</div>
                      <div className="text-[11px] text-slate-500">KPI</div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </GlassCard>
        </div>
      )}
    </PageLayout>
  );
}

