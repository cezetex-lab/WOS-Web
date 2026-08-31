// TalentMarketPage.jsx — Marketplace internal talent
import React, { useState, useEffect, useCallback } from 'react';
import { rpc } from '../../lib/supabase-browser';
import { PageLayout, GlassCard, MetricCard, DataTable, Badge, LoadingSpinner, Tabs } from '../../lib/design-system';

export default function TalentMarketPage() {
  const [loading, setLoading] = useState(true);
  const [data, setData] = useState([]);
  const [tab, setTab] = useState('all');

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('get_talent_marketplace');
      setData(Array.isArray(result) ? result : result?.data || []);
    } catch (e) { console.error(e); }
    setLoading(false);
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const statuses = [...new Set(data.map(r => r.status || 'Available'))];
  const filtered = tab === 'all' ? data : data.filter(r => (r.status || 'Available') === tab);

  const columns = [
    { key: 'nrp', label: 'NRP', render: v => <span className="text-xs font-mono text-slate-400">{v}</span> },
    { key: 'nama', label: 'Nama', render: v => <span className="text-sm font-semibold text-white">{v || '-'}</span> },
    { key: 'current_role', label: 'Posisi', render: v => <span className="text-xs text-slate-300">{v || '-'}</span> },
    { key: 'skills', label: 'Skills', render: v => <span className="text-xs text-blue-300">{v || '-'}</span> },
    { key: 'interest', label: 'Minat', render: v => <span className="text-xs text-teal-300">{v || '-'}</span> },
    { key: 'status', label: 'Status', render: v => <Badge status={v || 'Available'} type={v === 'Placed' ? 'success' : v === 'Available' ? 'info' : 'warning'} /> },
  ];

  if (loading) return <PageLayout backTo="/admin" title="Talent"><LoadingSpinner text="Memuat talent market..." /></PageLayout>;

  return (
    <PageLayout backTo="/admin" title="🎯 Talent Market" subtitle={`${data.length} talent tersedia`}>
      <div className="grid grid-cols-3 gap-3 mb-6">
        <MetricCard icon="🎯" value={data.length} label="Total" color="blue" />
        <MetricCard icon="✅" value={data.filter(r => r.status === 'Available').length} label="Available" color="green" />
        <MetricCard icon="🔄" value={data.filter(r => r.status === 'Placed').length} label="Placed" color="teal" />
      </div>
      {statuses.length > 1 && (
        <div className="mb-4">
          <Tabs tabs={[{ id: 'all', label: 'Semua', count: data.length }, ...statuses.map(s => ({ id: s, label: s, count: data.filter(r => (r.status || 'Available') === s).length }))]} active={tab} onChange={setTab} />
        </div>
      )}
      <GlassCard accent="teal">
        <DataTable columns={columns} data={filtered} searchPlaceholder="Cari talent..." emptyMessage="Tidak ada talent" />
      </GlassCard>
    </PageLayout>
  );
}
