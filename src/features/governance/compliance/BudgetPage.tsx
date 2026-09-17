// BudgetPage.tsx — Alokasi anggaran HR
import React, { useState, useEffect, useCallback } from 'react';
import { rpc } from '@/lib/supabase-browser';
import { PageLayout, GlassCard, MetricCard, DataTable, Badge, LoadingSpinner } from '@/lib/design-system';
import useAdminAuth from '@/hooks/useAdminAuth';

export default function BudgetPage() {
  useAdminAuth(["admin_pusat", "admin_finance"]);
  const [loading, setLoading] = useState(true);
  const [data, setData] = useState<Record<string, unknown>[]>([]);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('admin_get_budget');
      setData(Array.isArray(result) ? result : (result?.data as Record<string, unknown>[] || []));
    } catch (e) { /* ignore */ }
    setLoading(false);
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const totalBudget = data.reduce((s, r) => s + parseFloat(String(r.budget || r.amount || r.total || 0)), 0);
  const totalActual = data.reduce((s, r) => s + parseFloat(String(r.actual || r.used || 0)), 0);

  const columns = [
    { key: 'category', label: 'Kategori', render: (v: unknown) => <span className="text-sm font-semibold text-white">{String(v || '-')}</span> },
    { key: 'division', label: 'Divisi', render: (v: unknown) => <Badge status={String(v || '-')} type="info" /> },
    { key: 'budget', label: 'Budget', render: (v: unknown) => <span className="text-sm font-bold text-green-400">Rp {(parseFloat(String(v || 0))).toLocaleString('id-ID')}</span> },
    { key: 'actual', label: 'Realisasi', render: (v: unknown) => <span className="text-sm text-orange-400">Rp {(parseFloat(String(v || 0))).toLocaleString('id-ID')}</span> },
    { key: 'utilization', label: 'Utilisasi', render: (_v: unknown, row: Record<string, unknown>) => {
      const budget = Number(row.budget) || 0;
      const actual = Number(row.actual || row.used) || 0;
      const pct = budget > 0 ? (actual / budget * 100).toFixed(0) : '0';
      return (
        <div className="flex items-center gap-2">
          <div className="w-16 bg-slate-700 rounded-full h-1.5">
            <div className={`h-1.5 rounded-full ${Number(pct) > 90 ? 'bg-red-500' : Number(pct) > 70 ? 'bg-orange-500' : 'bg-green-500'}`} style={{ width: `${Math.min(Number(pct), 100)}%` }} />
          </div>
          <span className="text-[11px] text-slate-400">{pct}%</span>
        </div>
      );
    }},
  ];

  if (loading) return <PageLayout backTo="/admin" title="Budget"><LoadingSpinner text="Memuat budget..." /></PageLayout>;

  return (
    <PageLayout backTo="/admin" title="💰 Budget Allocation" subtitle={`Total budget: Rp ${totalBudget.toLocaleString('id-ID')}`}>
      <div className="grid grid-cols-3 gap-3 mb-6">
        <MetricCard icon="💰" value={`Rp ${(totalBudget / 1000000).toFixed(0)}M`} label="Total Budget" color="green" />
        <MetricCard icon="📤" value={`Rp ${(totalActual / 1000000).toFixed(0)}M`} label="Realisasi" color="orange" />
        <MetricCard icon="📊" value={`${totalBudget > 0 ? (totalActual / totalBudget * 100).toFixed(0) : 0}%`} label="Utilisasi" color="blue" />
      </div>
      <GlassCard accent="green">
        <DataTable columns={columns} data={data} searchPlaceholder="Cari budget..." emptyMessage="Tidak ada data budget" />
      </GlassCard>
    </PageLayout>
  );
}
