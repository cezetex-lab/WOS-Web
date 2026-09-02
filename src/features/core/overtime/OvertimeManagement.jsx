// OvertimeManagement.jsx — Admin view for overtime approvals
import React, { useState, useEffect, useCallback } from 'react';
import { rpc } from '../../../lib/supabase-browser';
import { PageLayout, GlassCard, MetricCard, DataTable, Badge, Button, LoadingSpinner, EmptyState } from '../../../lib/design-system';

export default function OvertimeManagement() {
  const [loading, setLoading] = useState(true);
  const [data, setData] = useState([]);
  const [selected, setSelected] = useState(null);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('admin_get_overtime');
      setData(Array.isArray(result) ? result : result?.data || []);
    } catch (e) { }
    setLoading(false);
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const handleApprove = async (row) => {
    try {
      await rpc('admin_approve_request', { p_request_id: row.id, p_type: 'overtime' });
      setData(data.map(r => r.id === row.id ? { ...r, status: 'Approved' } : r));
      setSelected(null);
    } catch (e) { }
  };

  const handleReject = async (row) => {
    try {
      await rpc('admin_reject_request', { p_request_id: row.id, p_type: 'overtime' });
      setData(data.map(r => r.id === row.id ? { ...r, status: 'Rejected' } : r));
      setSelected(null);
    } catch (e) { }
  };

  const totalHours = data.reduce((s, r) => s + (parseFloat(r.hours || r.jam || 0)), 0);
  const pending = data.filter(r => (r.status || '').toLowerCase() === 'pending' || (r.status || '').toLowerCase() === 'requested');

  const columns = [
    { key: 'nrp', label: 'NRP', render: (v) => <span className="text-xs font-mono text-slate-400">{v}</span> },
    { key: 'nama', label: 'Nama', render: (v) => <span className="text-sm font-semibold text-white">{v || '-'}</span> },
    { key: 'hours', label: 'Jam', render: (v) => <span className="text-sm font-bold text-orange-400">{v || '-'}h</span> },
    { key: 'date', label: 'Tanggal', render: (v) => <span className="text-xs text-slate-300">{v ? new Date(v).toLocaleDateString('id-ID') : '-'}</span> },
    { key: 'reason', label: 'Alasan', render: (v) => <span className="text-xs text-slate-300 truncate max-w-[150px] block">{v || '-'}</span> },
    { key: 'status', label: 'Status', render: (v) => <Badge status={v} type={v?.toLowerCase() === 'approved' ? 'success' : v?.toLowerCase() === 'pending' || v?.toLowerCase() === 'requested' ? 'warning' : 'danger'} /> },
  ];

  if (loading) return <PageLayout backTo="/admin" title="Lembur"><LoadingSpinner text="Memuat data lembur..." /></PageLayout>;

  return (
    <PageLayout backTo="/admin" title="⏰ Lembur" subtitle={`${data.length} pengajuan`}>
      <div className="grid grid-cols-3 gap-3 mb-6">
        <MetricCard icon="⏰" value={data.length} label="Total" color="orange" />
        <MetricCard icon="⏳" value={pending.length} label="Pending" color="yellow" />
        <MetricCard icon="🕐" value={`${totalHours.toFixed(1)}h`} label="Total Jam" color="blue" />
      </div>
      <GlassCard accent="orange">
        <DataTable columns={columns} data={data} searchPlaceholder="Cari lembur..." onRowClick={setSelected} emptyMessage="Tidak ada pengajuan lembur" />
      </GlassCard>
      {selected && (
        <>
          <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm" onClick={() => setSelected(null)} />
          <div className="fixed inset-x-0 bottom-0 z-50 max-h-[85vh] bg-slate-900 border-t border-white/10 rounded-t-3xl overflow-y-auto p-5 pb-8">
            <div className="flex justify-center pt-3 pb-1"><div className="w-10 h-1 rounded-full bg-slate-600" /></div>
            <h2 className="text-lg font-bold text-white mb-4">Detail Lembur</h2>
            <div className="space-y-1 mb-5">
              {Object.entries(selected).filter(([k]) => !k.startsWith('_') && k !== 'id').map(([key, val]) => (
                <div key={key} className="flex justify-between py-2 border-b border-white/5">
                  <span className="text-xs text-slate-400 capitalize">{key.replace(/_/g, ' ')}</span>
                  <span className="text-xs font-semibold text-white">{val == null ? '-' : String(val)}</span>
                </div>
              ))}
            </div>
            {(!selected.status || selected.status.toLowerCase() === 'pending' || selected.status.toLowerCase() === 'requested') && (
              <div className="flex gap-2">
                <Button color="green" size="sm" className="flex-1" onClick={() => handleApprove(selected)}>✓ Approve</Button>
                <Button color="red" size="sm" variant="outline" className="flex-1" onClick={() => handleReject(selected)}>✕ Reject</Button>
              </div>
            )}
            <Button color="ghost" size="sm" className="mt-3 w-full" onClick={() => setSelected(null)}>✕ Tutup</Button>
          </div>
        </>
      )}
    </PageLayout>
  );
}
