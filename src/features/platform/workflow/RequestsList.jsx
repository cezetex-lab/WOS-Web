// ============================================================
// RequestsList.jsx — Custom Admin Requests Page
// RPC: admin_get_pending_requests, process_request
// ============================================================

import React, { useState, useEffect, useCallback } from 'react';
import { supabase, rpc } from '../../../lib/supabase-browser';
import {
  PageLayout, MetricCard, GlassCard, DataTable, Badge,
  Tabs, LoadingSpinner, EmptyState, Button, Avatar
} from '../../../lib/design-system';

const TYPE_ICONS = {
  Cuti: '✈️', Izin: '📌', Sakit: '🏥', Lembur: '⏰',
  Training: '🎓', Dinas: '🚗', Reimbursement: '💰',
};

const STATUS_COLORS = {
  Pending: 'warning', Approved: 'success', Rejected: 'danger',
};

export default function RequestsList() {
  const nrp = JSON.parse(sessionStorage.getItem('wos_user') || '{}')?.nrp || 'ADMIN001';
  const [loading, setLoading] = useState(true);
  const [requests, setRequests] = useState([]);
  const [activeTab, setActiveTab] = useState('all');
  const [selected, setSelected] = useState(null);
  const [processing, setProcessing] = useState(false);
  const [rejectNote, setRejectNote] = useState('');
  const [showRejectInput, setShowRejectInput] = useState(false);

  const fetchRequests = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('get_worker_requests');
      const data = Array.isArray(result) ? result
        : result?.data && Array.isArray(result.data) ? result.data : [];
      setRequests(data);
    } catch (err) { console.error('Failed to load requests:', err); }
    setLoading(false);
  }, []);

  useEffect(() => { fetchRequests(); }, [fetchRequests]);

  const handleApprove = async (requestId) => {
    setProcessing(true);
    try {
      await rpc('process_request', {
        p_request_id: requestId,
        p_action: 'approve',
        p_approver: nrp,
      });
      setSelected(null);
      fetchRequests();
    } catch (err) { console.error(err); }
    setProcessing(false);
  };

  const handleReject = async (requestId) => {
    setProcessing(true);
    try {
      await rpc('process_request', {
        p_request_id: requestId,
        p_action: 'reject',
        p_approver: nrp,
        p_note: rejectNote || 'Ditolak oleh admin',
      });
      setSelected(null);
      setRejectNote('');
      setShowRejectInput(false);
      fetchRequests();
    } catch (err) { console.error(err); }
    setProcessing(false);
  };

  const filtered = requests.filter(r => {
    if (activeTab === 'all') return true;
    return (r.status || '').toLowerCase() === activeTab;
  });

  // ── STATS ──
  const pendingCount = requests.filter(r => (r.status || '').toLowerCase() === 'pending').length;
  const approvedCount = requests.filter(r => (r.status || '').toLowerCase() === 'approved').length;
  const rejectedCount = requests.filter(r => (r.status || '').toLowerCase() === 'rejected').length;

  const statCards = [
    { icon: '⏳', value: pendingCount, label: 'Pending', trend: 'Perlu diproses', color: 'orange' },
    { icon: '✅', value: approvedCount, label: 'Approved', trend: 'Selesai', color: 'green' },
    { icon: '❌', value: rejectedCount, label: 'Rejected', trend: 'Ditolak', color: 'red' },
    { icon: '📋', value: requests.length, label: 'Total', trend: 'Semua', color: 'blue' },
  ];

  // ── TABLE COLUMNS ──
  const columns = [
    {
      key: 'nama',
      label: 'Karyawan',
      render: (val, row) => (
        <div className="flex items-center gap-2">
          <Avatar name={val || row.nrp} size="sm" />
          <div className="min-w-0">
            <div className="text-xs font-semibold text-white truncate">{val || row.nrp}</div>
            <div className="text-[10px] text-slate-500">{row.nrp}</div>
          </div>
        </div>
      ),
    },
    {
      key: 'type',
      label: 'Jenis',
      render: (val) => (
        <div className="flex items-center gap-1.5">
          <span>{TYPE_ICONS[val] || '📋'}</span>
          <span className="text-xs text-slate-300">{val}</span>
        </div>
      ),
    },
    {
      key: 'divisi',
      label: 'Divisi',
      render: (val) => <span className="text-xs text-slate-400">{val || '-'}</span>,
    },
    {
      key: 'status',
      label: 'Status',
      render: (val) => (
        <Badge status={val} type={STATUS_COLORS[val] || 'default'} />
      ),
    },
    {
      key: 'created_at',
      label: 'Tanggal',
      render: (val) => (
        <span className="text-[10px] text-slate-500">
          {val ? new Date(val).toLocaleDateString('id-ID') : '-'}
        </span>
      ),
    },
  ];

  if (loading) {
    return (
      <PageLayout backTo="/admin" title="Pengajuan" subtitle="Kelola semua pengajuan karyawan">
        <LoadingSpinner text="Memuat data pengajuan..." />
      </PageLayout>
    );
  }

  return (
    <PageLayout backTo="/admin" title="Pengajuan" subtitle={`${pendingCount} menunggu approval`}>
      {/* ── METRICS ── */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
        {statCards.map((s, i) => <MetricCard key={i} {...s} />)}
      </div>

      {/* ── TABS ── */}
      <div className="mb-4">
        <Tabs
          tabs={[
            { id: 'all', label: 'Semua', count: requests.length },
            { id: 'pending', label: 'Pending', count: pendingCount },
            { id: 'approved', label: 'Approved', count: approvedCount },
            { id: 'rejected', label: 'Rejected', count: rejectedCount },
          ]}
          active={activeTab}
          onChange={setActiveTab}
        />
      </div>

      {/* ── TABLE ── */}
      <GlassCard accent="blue">
        <DataTable
          columns={columns}
          data={filtered}
          searchPlaceholder="Cari nama, NRP, jenis..."
          onRowClick={(row) => { setSelected(row); setShowRejectInput(false); setRejectNote(''); }}
          emptyMessage="Tidak ada pengajuan"
        />
      </GlassCard>

      {/* ── DETAIL MODAL ── */}
      {selected && (
        <>
          <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm" onClick={() => setSelected(null)} />
          <div className="fixed inset-x-0 bottom-0 z-50 max-h-[85vh] bg-slate-900 border-t border-white/10 rounded-t-3xl overflow-y-auto">
            <div className="flex justify-center pt-3 pb-1">
              <div className="w-10 h-1 rounded-full bg-slate-600" />
            </div>
            <div className="px-5 pb-8">
              {/* Header */}
              <div className="flex items-center gap-3 mb-5">
                <span className="text-3xl">{TYPE_ICONS[selected.type] || '📋'}</span>
                <div className="flex-1">
                  <h2 className="text-lg font-bold text-white">{selected.type} — {selected.nama || selected.nrp}</h2>
                  <p className="text-xs text-slate-400">{selected.nrp} • {selected.divisi || '-'}</p>
                </div>
                <Badge status={selected.status} type={STATUS_COLORS[selected.status] || 'default'} />
              </div>

              {/* Details */}
              <GlassCard accent="blue" className="mb-4">
                <div className="space-y-1">
                  {[
                    { label: 'Jenis', value: `${TYPE_ICONS[selected.type] || '📋'} ${selected.type}` },
                    { label: 'Status', value: selected.status },
                    { label: 'Catatan', value: selected.note || selected.details_json || '-' },
                    { label: 'Diajukan', value: selected.created_at ? new Date(selected.created_at).toLocaleString('id-ID') : '-' },
                    { label: 'Approver', value: selected.approver_nrp || '-' },
                  ].map((row, i) => (
                    <div key={i} className="flex items-center justify-between py-2 border-b border-white/5 last:border-0">
                      <span className="text-xs text-slate-400">{row.label}</span>
                      <span className="text-xs font-semibold text-white text-right max-w-[60%] break-words">{row.value}</span>
                    </div>
                  ))}
                </div>
              </GlassCard>

              {/* Actions */}
              {selected.status === 'Pending' && (
                <div className="space-y-3">
                  {showRejectInput ? (
                    <div className="space-y-2">
                      <textarea
                        value={rejectNote}
                        onChange={(e) => setRejectNote(e.target.value)}
                        placeholder="Alasan penolakan..."
                        className="w-full bg-slate-800/50 border border-red-500/30 rounded-xl px-4 py-3 text-sm text-white placeholder-slate-500 focus:outline-none resize-none"
                        rows={2}
                      />
                      <div className="flex gap-2">
                        <Button color="red" size="sm" className="flex-1" onClick={() => handleReject(selected.id)} disabled={processing}>
                          {processing ? '...' : '❌ Tolak'}
                        </Button>
                        <Button color="ghost" size="sm" onClick={() => setShowRejectInput(false)}>Batal</Button>
                      </div>
                    </div>
                  ) : (
                    <div className="flex gap-2">
                      <Button color="green" size="sm" className="flex-1" onClick={() => handleApprove(selected.id)} disabled={processing}>
                        ✅ Setuju
                      </Button>
                      <Button color="red" size="sm" variant="outline" className="flex-1" onClick={() => setShowRejectInput(true)}>
                        ❌ Tolak
                      </Button>
                    </div>
                  )}
                </div>
              )}

              <div className="mt-4 flex justify-end">
                <Button color="ghost" size="sm" onClick={() => setSelected(null)}>✕ Tutup</Button>
              </div>
            </div>
          </div>
        </>
      )}
    </PageLayout>
  );
}
