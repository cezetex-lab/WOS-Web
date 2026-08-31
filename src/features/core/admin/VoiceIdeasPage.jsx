// VoiceIdeasPage.jsx — Ide & masukan karyawan
import React, { useState, useEffect, useCallback } from 'react';
import { rpc } from '../../../lib/supabase-browser';
import { PageLayout, GlassCard, MetricCard, DataTable, Badge, Button, LoadingSpinner, Tabs } from '../../../lib/design-system';

export default function VoiceIdeasPage() {
  const [loading, setLoading] = useState(true);
  const [data, setData] = useState([]);
  const [tab, setTab] = useState('all');
  const [selected, setSelected] = useState(null);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('list_ideas');
      setData(Array.isArray(result) ? result : result?.data || []);
    } catch (e) { console.error(e); }
    setLoading(false);
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const statuses = [...new Set(data.map(r => r.status || 'New'))];
  const filtered = tab === 'all' ? data : data.filter(r => (r.status || 'New') === tab);

  const handleStatusUpdate = async (idea, newStatus) => {
    try {
      await rpc('admin_update_idea_status', { p_idea_id: idea.id, p_status: newStatus });
      setData(data.map(r => r.id === idea.id ? { ...r, status: newStatus } : r));
      setSelected(null);
    } catch (e) { console.error(e); }
  };

  const columns = [
    { key: 'nrp', label: 'NRP', render: v => <span className="text-xs font-mono text-slate-400">{v}</span> },
    { key: 'title', label: 'Judul', render: v => <span className="text-sm font-semibold text-white">{v || '-'}</span> },
    { key: 'category', label: 'Kategori', render: v => <Badge status={v || 'Umum'} type="info" /> },
    { key: 'votes', label: 'Vote', render: v => <span className="text-sm font-bold text-yellow-400">👍 {v || 0}</span> },
    { key: 'status', label: 'Status', render: v => <Badge status={v || 'New'} type={v === 'Implemented' ? 'success' : v === 'Review' ? 'warning' : v === 'Rejected' ? 'danger' : 'info'} /> },
    { key: 'created_at', label: 'Tanggal', render: v => <span className="text-xs text-slate-300">{v ? new Date(v).toLocaleDateString('id-ID') : '-'}</span> },
  ];

  if (loading) return <PageLayout backTo="/admin" title="Voice"><LoadingSpinner text="Memuat ide..." /></PageLayout>;

  return (
    <PageLayout backTo="/admin" title="💡 Ide & Voice" subtitle={`${data.length} ide masuk`}>
      <div className="grid grid-cols-3 gap-3 mb-6">
        <MetricCard icon="💡" value={data.length} label="Total Ide" color="blue" />
        <MetricCard icon="⭐" value={data.reduce((s, r) => s + (r.votes || 0), 0)} label="Total Vote" color="yellow" />
        <MetricCard icon="✅" value={data.filter(r => r.status === 'Implemented').length} label="Diimplementasi" color="green" />
      </div>
      {statuses.length > 1 && (
        <div className="mb-4">
          <Tabs tabs={[{ id: 'all', label: 'Semua', count: data.length }, ...statuses.map(s => ({ id: s, label: s, count: data.filter(r => (r.status || 'New') === s).length }))]} active={tab} onChange={setTab} />
        </div>
      )}
      <GlassCard accent="blue">
        <DataTable columns={columns} data={filtered} searchPlaceholder="Cari ide..." onRowClick={setSelected} emptyMessage="Tidak ada ide" />
      </GlassCard>
      {selected && (
        <>
          <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm" onClick={() => setSelected(null)} />
          <div className="fixed inset-x-0 bottom-0 z-50 max-h-[85vh] bg-slate-900 border-t border-white/10 rounded-t-3xl overflow-y-auto p-5 pb-8">
            <div className="flex justify-center pt-3 pb-1"><div className="w-10 h-1 rounded-full bg-slate-600" /></div>
            <h2 className="text-lg font-bold text-white mb-2">{selected.title || 'Detail Ide'}</h2>
            <p className="text-xs text-slate-300 mb-4">{selected.description || selected.body || '-'}</p>
            <div className="flex flex-wrap gap-2 mb-4">
              {['New', 'Review', 'Approved', 'Implemented', 'Rejected'].map(s => (
                <Button key={s} size="sm" color={s === 'Implemented' ? 'green' : s === 'Rejected' ? 'red' : 'blue'} variant={selected.status === s ? 'solid' : 'outline'} onClick={() => handleStatusUpdate(selected, s)}>{s}</Button>
              ))}
            </div>
            <Button color="ghost" size="sm" className="w-full" onClick={() => setSelected(null)}>✕ Tutup</Button>
          </div>
        </>
      )}
    </PageLayout>
  );
}
