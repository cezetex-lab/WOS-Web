// HeadcountPage.jsx — Perencanaan jumlah karyawan
import React, { useState, useEffect, useCallback } from 'react';
import { rpc } from '../../../lib/supabase-browser';
import { PageLayout, GlassCard, MetricCard, DataTable, Badge, LoadingSpinner } from '../../../lib/design-system';
import useAdminAuth from '@/hooks/useAdminAuth';

export default function HeadcountPage() {
  useAdminAuth(["admin_pusat"]);
  const [loading, setLoading] = useState(true);
  const [data, setData] = useState([]);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('get_workforce_planning');
      setData(Array.isArray(result) ? result : result?.data || []);
    } catch (e) { }
    setLoading(false);
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const columns = [
    { key: 'divisi', label: 'Divisi', render: v => <span className="text-sm font-semibold text-white">{v || '-'}</span> },
    { key: 'position', label: 'Posisi', render: v => <span className="text-xs text-slate-300">{v || '-'}</span> },
    { key: 'current_count', label: 'Saat Ini', render: v => <span className="text-sm font-bold text-blue-400">{v || 0}</span> },
    { key: 'target_count', label: 'Target', render: v => <span className="text-sm font-bold text-green-400">{v || 0}</span> },
    { key: 'gap', label: 'Gap', render: (v, row) => {
      const gap = (row.target_count || 0) - (row.current_count || 0);
      return <Badge status={gap > 0 ? `+${gap}` : gap < 0 ? `${gap}` : '0'} type={gap > 0 ? 'warning' : gap < 0 ? 'danger' : 'success'} />;
    }},
    { key: 'priority', label: 'Prioritas', render: v => <Badge status={v || 'Normal'} type={v === 'High' || v === 'Critical' ? 'danger' : v === 'Medium' ? 'warning' : 'info'} /> },
  ];

  if (loading) return <PageLayout backTo="/admin" title="Headcount"><LoadingSpinner text="Memuat headcount plan..." /></PageLayout>;

  const totalCurrent = data.reduce((s, r) => s + (r.current_count || 0), 0);
  const totalTarget = data.reduce((s, r) => s + (r.target_count || 0), 0);

  return (
    <PageLayout backTo="/admin" title="📊 Headcount Plan" subtitle={`${data.length} posisi terencana`}>
      <div className="grid grid-cols-3 gap-3 mb-6">
        <MetricCard icon="📊" value={totalCurrent} label="Total Saat Ini" color="blue" />
        <MetricCard icon="🎯" value={totalTarget} label="Total Target" color="green" />
        <MetricCard icon="📈" value={totalTarget - totalCurrent} label="Gap" color={totalTarget > totalCurrent ? 'orange' : 'teal'} />
      </div>
      <GlassCard accent="blue">
        <DataTable columns={columns} data={data} searchPlaceholder="Cari headcount..." emptyMessage="Tidak ada data headcount plan" />
      </GlassCard>
    </PageLayout>
  );
}
