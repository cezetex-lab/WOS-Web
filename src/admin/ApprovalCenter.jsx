// ============================================================
// ApprovalCenter.jsx — #29 Dynamic Approval Workflow
// View pending requests, approve/reject, bulk operations
// ============================================================

import React, { useState, useEffect, useCallback } from 'react';
import { supabase, getSession } from '../lib/supabase-browser';
import { PageLayout, GlassCard, LoadingSpinner, Badge, Button, Tabs } from '../lib/design-system';

const STATUS_COLORS = {
  Pending: 'warning',
  Approved: 'success',
  Rejected: 'danger',
};

const TYPE_ICONS = {
  Cuti: '✈️', Izin: '📌', Sakit: '🏥', Lembur: '⏰',
  Training: '🎓', Dinas: '🚗', default: '📋',
};

export default function ApprovalCenter() {
  const nrp = getSession()?.nrp;
  const [loading, setLoading] = useState(true);
  const [requests, setRequests] = useState([]);
  const [activeTab, setActiveTab] = useState('pending');
  const [selectedRequest, setSelectedRequest] = useState(null);
  const [processing, setProcessing] = useState(false);

  const fetchRequests = useCallback(async () => {
    setLoading(true);
    try {
      // Fetch all requests (admin can see all)
      const { data } = await supabase.rpc('get_worker_requests');
      setRequests(data || []);
    } catch (err) { console.error(err); }
    setLoading(false);
  }, []);

  useEffect(() => { fetchRequests(); }, [fetchRequests]);

  const handleApprove = async (requestId) => {
    setProcessing(true);
    try {
      await supabase.rpc('process_request', {
        p_request_id: requestId,
        p_action: 'approve',
        p_approver: nrp,
      });
      fetchRequests();
      setSelectedRequest(null);
    } catch (err) { console.error(err); }
    setProcessing(false);
  };

  const handleReject = async (requestId, note) => {
    setProcessing(true);
    try {
      await supabase.rpc('process_request', {
        p_request_id: requestId,
        p_action: 'reject',
        p_approver: nrp,
        p_note: note || 'Ditolak oleh admin',
      });
      fetchRequests();
      setSelectedRequest(null);
    } catch (err) { console.error(err); }
    setProcessing(false);
  };

  const filtered = requests.filter(r => {
    if (activeTab === 'pending') return r.status === 'Pending';
    if (activeTab === 'approved') return r.status === 'Approved';
    if (activeTab === 'rejected') return r.status === 'Rejected';
    return true;
  });

  if (loading) return <PageLayout backTo="/admin" title="Approval Center"><LoadingSpinner /></PageLayout>;

  const pendingCount = requests.filter(r => r.status === 'Pending').length;

  return (
    <PageLayout backTo="/admin" title="Approval Center" subtitle={`${pendingCount} menunggu approval`}>
      {/* ── STATS ── */}
      <div className="grid grid-cols-3 gap-2 mb-4">
        <div className="p-3 rounded-xl bg-amber-500/10 border border-amber-500/20 text-center">
          <p className="text-lg font-bold text-amber-400">{pendingCount}</p>
          <p className="text-[10px] text-slate-400">Pending</p>
        </div>
        <div className="p-3 rounded-xl bg-green-500/10 border border-green-500/20 text-center">
          <p className="text-lg font-bold text-green-400">{requests.filter(r => r.status === 'Approved').length}</p>
          <p className="text-[10px] text-slate-400">Approved</p>
        </div>
        <div className="p-3 rounded-xl bg-red-500/10 border border-red-500/20 text-center">
          <p className="text-lg font-bold text-red-400">{requests.filter(r => r.status === 'Rejected').length}</p>
          <p className="text-[10px] text-slate-400">Rejected</p>
        </div>
      </div>

      {/* ── TABS ── */}
      <div className="mb-4">
        <Tabs
          tabs={[
            { id: 'pending', label: 'Pending', count: pendingCount },
            { id: 'approved', label: 'Approved', count: requests.filter(r => r.status === 'Approved').length },
            { id: 'rejected', label: 'Rejected', count: requests.filter(r => r.status === 'Rejected').length },
            { id: 'all', label: 'Semua', count: requests.length },
          ]}
          active={activeTab}
          onChange={setActiveTab}
        />
      </div>

      {/* ── REQUEST LIST ── */}
      <div className="space-y-2">
        {filtered.length === 0 ? (
          <GlassCard>
            <p className="text-sm text-slate-400 text-center py-4">Tidak ada request</p>
          </GlassCard>
        ) : (
          filtered.map(req => {
            const icon = TYPE_ICONS[req.type] || TYPE_ICONS.default;
            const isPending = req.status === 'Pending';
            return (
              <div
                key={req.id}
                className={`p-3 rounded-xl border transition-all ${
                  isPending ? 'bg-white/5 border-amber-500/20 hover:border-amber-500/40' : 'bg-white/3 border-white/5'
                }`}
              >
                <div className="flex items-center gap-3">
                  <span className="text-xl">{icon}</span>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                      <p className="text-sm font-semibold text-white truncate">{req.nama || req.nrp}</p>
                      <Badge status={req.type} type="info" />
                    </div>
                    <p className="text-[10px] text-slate-500">
                      {req.divisi || '-'} • {new Date(req.created_at).toLocaleDateString('id-ID')}
                    </p>
                  </div>
                  <Badge status={req.status} type={STATUS_COLORS[req.status] || 'default'} />
                </div>

                {req.details_json && (
                  <p className="text-xs text-slate-400 mt-2 ml-9 line-clamp-2">
                    {typeof req.details_json === 'string' ? req.details_json.slice(0, 100) : JSON.stringify(req.details_json).slice(0, 100)}
                  </p>
                )}

                {isPending && (
                  <div className="flex gap-2 mt-3 ml-9">
                    <Button
                      color="green"
                      size="sm"
                      onClick={() => handleApprove(req.id)}
                      disabled={processing}
                    >
                      ✅ Approve
                    </Button>
                    <Button
                      color="red"
                      size="sm"
                      variant="outline"
                      onClick={() => handleReject(req.id)}
                      disabled={processing}
                    >
                      ❌ Reject
                    </Button>
                  </div>
                )}
              </div>
            );
          })
        )}
      </div>
    </PageLayout>
  );
}
