// LearningManagement.jsx — Program pelatihan & kursus admin view
import React, { useState, useEffect, useCallback } from 'react';
import { rpc } from '../../../lib/supabase-browser';
import { PageLayout, GlassCard, MetricCard, DataTable, Badge, LoadingSpinner, Tabs } from '../../../lib/design-system';

export default function LearningManagement() {
  const [loading, setLoading] = useState(true);
  const [data, setData] = useState([]);
  const [tab, setTab] = useState('all');

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('get_worker_learning');
      setData(Array.isArray(result) ? result : result?.data || []);
    } catch (e) { }
    setLoading(false);
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const statuses = [...new Set(data.map(r => r.status || 'Enrolled'))];
  const filtered = tab === 'all' ? data : data.filter(r => (r.status || 'Enrolled') === tab);

  const columns = [
    { key: 'nrp', label: 'NRP', render: v => <span className="text-xs font-mono text-slate-400">{v}</span> },
    { key: 'nama', label: 'Nama', render: v => <span className="text-sm font-semibold text-white">{v || '-'}</span> },
    { key: 'program', label: 'Program', render: v => <span className="text-xs text-slate-300">{v || '-'}</span> },
    { key: 'category', label: 'Kategori', render: v => <Badge status={v || 'General'} type="info" /> },
    { key: 'progress', label: 'Progress', render: v => (
      <div className="w-full bg-slate-700 rounded-full h-2">
        <div className="bg-blue-500 h-2 rounded-full transition-all" style={{ width: `${v || 0}%` }} />
      </div>
    )},
    { key: 'status', label: 'Status', render: v => <Badge status={v || 'Enrolled'} type={v === 'Completed' ? 'success' : v === 'In Progress' ? 'warning' : 'info'} /> },
  ];

  const completed = data.filter(r => r.status === 'Completed').length;
  const inProgress = data.filter(r => r.status === 'In Progress').length;

  if (loading) return <PageLayout backTo="/admin" title="Learning"><LoadingSpinner text="Memuat data learning..." /></PageLayout>;

  return (
    <PageLayout backTo="/admin" title="📚 Learning Management" subtitle={`${data.length} peserta`}>
      <div className="grid grid-cols-3 gap-3 mb-6">
        <MetricCard icon="📚" value={data.length} label="Total" color="blue" />
        <MetricCard icon="✅" value={completed} label="Selesai" color="green" />
        <MetricCard icon="📖" value={inProgress} label="Berlangsung" color="orange" />
      </div>
      {statuses.length > 1 && (
        <div className="mb-4">
          <Tabs tabs={[{ id: 'all', label: 'Semua', count: data.length }, ...statuses.map(s => ({ id: s, label: s, count: data.filter(r => (r.status || 'Enrolled') === s).length }))]} active={tab} onChange={setTab} />
        </div>
      )}
      <GlassCard accent="blue">
        <DataTable columns={columns} data={filtered} searchPlaceholder="Cari learning..." emptyMessage="Tidak ada data learning" />
      </GlassCard>
    </PageLayout>
  );
}
