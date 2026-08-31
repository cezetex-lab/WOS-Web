// CareerPathPage.jsx — Jalur karir & promosi
import React, { useState, useEffect, useCallback } from 'react';
import { rpc } from '../../lib/supabase-browser';
import { PageLayout, GlassCard, MetricCard, DataTable, Badge, LoadingSpinner } from '../../lib/design-system';

export default function CareerPathPage() {
  const [loading, setLoading] = useState(true);
  const [data, setData] = useState([]);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('get_worker_career');
      setData(Array.isArray(result) ? result : result?.data || []);
    } catch (e) { console.error(e); }
    setLoading(false);
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const levels = [...new Set(data.map(r => r.level || r.target_level || 'L1'))];

  const columns = [
    { key: 'nrp', label: 'NRP', render: v => <span className="text-xs font-mono text-slate-400">{v}</span> },
    { key: 'nama', label: 'Nama', render: v => <span className="text-sm font-semibold text-white">{v || '-'}</span> },
    { key: 'current_position', label: 'Posisi Saat Ini', render: v => <span className="text-xs text-slate-300">{v || '-'}</span> },
    { key: 'target_position', label: 'Target', render: v => <span className="text-xs text-blue-300 font-semibold">{v || '-'}</span> },
    { key: 'progress', label: 'Progress', render: v => (
      <div className="flex items-center gap-2">
        <div className="w-16 bg-slate-700 rounded-full h-1.5">
          <div className="bg-blue-500 h-1.5 rounded-full" style={{ width: `${v || 0}%` }} />
        </div>
        <span className="text-[10px] text-slate-400">{v || 0}%</span>
      </div>
    )},
    { key: 'status', label: 'Status', render: v => <Badge status={v || 'Active'} type={v === 'Promoted' ? 'success' : 'info'} /> },
  ];

  if (loading) return <PageLayout backTo="/admin" title="Career"><LoadingSpinner text="Memuat career path..." /></PageLayout>;

  return (
    <PageLayout backTo="/admin" title="🧭 Career Path" subtitle={`${data.length} jalur karir`}>
      <div className="grid grid-cols-3 gap-3 mb-6">
        <MetricCard icon="🧭" value={data.length} label="Total" color="blue" />
        <MetricCard icon="🎯" value={levels.length} label="Level" color="teal" />
        <MetricCard icon="🚀" value={data.filter(r => r.status === 'Promoted').length} label="Promoted" color="green" />
      </div>
      <GlassCard accent="blue">
        <DataTable columns={columns} data={data} searchPlaceholder="Cari career path..." emptyMessage="Tidak ada data career path" />
      </GlassCard>
    </PageLayout>
  );
}
