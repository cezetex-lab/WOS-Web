// ApprovalWorkflow.jsx — Dynamic multi-level approval workflow
import React, { useState, useEffect, useCallback } from 'react';
import { rpc } from '../../lib/supabase-browser';
import { PageLayout, GlassCard, MetricCard, Badge, Button, LoadingSpinner, EmptyState } from '../../lib/design-system';

const WORKFLOW_STEPS = [
  { level: 1, label: 'Supervisor', icon: '👨‍💼', desc: 'Approval langsung' },
  { level: 2, label: 'Manager', icon: '🧑‍💼', desc: 'Review departemen' },
  { level: 3, label: 'HRD', icon: '🏢', desc: 'Kebijakan perusahaan' },
  { level: 4, label: 'Direktur', icon: '👔', desc: 'Keputusan akhir' },
];

export default function ApprovalWorkflow() {
  const [loading, setLoading] = useState(true);
  const [requests, setRequests] = useState([]);
  const [selected, setSelected] = useState(null);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('get_worker_requests');
      setRequests(Array.isArray(result) ? result : result?.data || []);
    } catch (e) { console.error(e); }
    setLoading(false);
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const pending = requests.filter(r => (r.status || '').toLowerCase() === 'pending' || (r.status || '').toLowerCase() === 'requested');
  const approved = requests.filter(r => (r.status || '').toLowerCase() === 'approved');

  const getRequiredLevel = (days) => {
    if (days > 14) return 4;
    if (days > 7) return 3;
    if (days > 3) return 2;
    return 1;
  };

  const handleApprove = async (req) => {
    try {
      await rpc('process_request', { p_request_id: req.id, p_action: 'approve' });
      setRequests(requests.map(r => r.id === req.id ? { ...r, status: 'Approved' } : r));
      setSelected(null);
    } catch (e) { console.error(e); }
  };

  const handleReject = async (req) => {
    try {
      await rpc('process_request', { p_request_id: req.id, p_action: 'reject' });
      setRequests(requests.map(r => r.id === req.id ? { ...r, status: 'Rejected' } : r));
      setSelected(null);
    } catch (e) { console.error(e); }
  };

  if (loading) return <PageLayout backTo="/admin" title="Approval"><LoadingSpinner text="Memuat approval..." /></PageLayout>;

  return (
    <PageLayout backTo="/admin" title="📨 Dynamic Approval" subtitle={`${pending.length} menunggu approval`}>
      <div className="grid grid-cols-2 gap-3 mb-6">
        <MetricCard icon="⏳" value={pending.length} label="Pending" color="orange" />
        <MetricCard icon="✅" value={approved.length} label="Approved" color="green" />
      </div>

      {/* Workflow Levels */}
      <GlassCard accent="blue" className="mb-4">
        <h3 className="text-xs font-bold text-white mb-3">🔄 Approval Flow</h3>
        <div className="flex items-center gap-1">
          {WORKFLOW_STEPS.map((step, i) => (
            <React.Fragment key={step.level}>
              <div className="flex-1 text-center p-2 rounded-lg bg-slate-800/50 border border-white/5">
                <span className="text-xl">{step.icon}</span>
                <p className="text-[10px] text-white font-semibold mt-1">{step.label}</p>
                <p className="text-[9px] text-slate-400">{step.desc}</p>
              </div>
              {i < WORKFLOW_STEPS.length - 1 && <span className="text-slate-500">→</span>}
            </React.Fragment>
          ))}
        </div>
      </GlassCard>

      {/* Pending Requests */}
      <GlassCard accent="orange">
        <h3 className="text-xs font-bold text-white mb-3">⏳ Menunggu Approval</h3>
        <div className="space-y-2">
          {pending.map(req => {
            const days = req.duration_days || 1;
            const level = getRequiredLevel(days);
            return (
              <div key={req.id} className="flex items-center gap-3 py-3 border-b border-white/5 last:border-0 cursor-pointer" onClick={() => setSelected(req)}>
                <div className="flex-1">
                  <div className="flex items-center gap-2">
                    <p className="text-sm font-semibold text-white">{req.type || req.request_type || '-'}</p>
                    <Badge status={`Level ${level}`} type={level >= 3 ? 'danger' : level >= 2 ? 'warning' : 'info'} />
                  </div>
                  <p className="text-[10px] text-slate-400 mt-1">{req.nrp} • {days} hari</p>
                </div>
                <Badge status={req.status || 'Pending'} type="warning" />
              </div>
            );
          })}
          {pending.length === 0 && <EmptyState title="Tidak ada yang menunggu" icon="✅" />}
        </div>
      </GlassCard>

      {/* Detail Modal */}
      {selected && (
        <>
          <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm" onClick={() => setSelected(null)} />
          <div className="fixed inset-x-0 bottom-0 z-50 max-h-[85vh] bg-slate-900 border-t border-white/10 rounded-t-3xl overflow-y-auto p-5 pb-8">
            <div className="flex justify-center pt-3 pb-1"><div className="w-10 h-1 rounded-full bg-slate-600" /></div>
            <h2 className="text-lg font-bold text-white mb-4">Detail Pengajuan</h2>
            <div className="space-y-1 mb-4">
              {Object.entries(selected).filter(([k]) => !k.startsWith('_') && k !== 'id').map(([key, val]) => (
                <div key={key} className="flex justify-between py-2 border-b border-white/5">
                  <span className="text-xs text-slate-400 capitalize">{key.replace(/_/g, ' ')}</span>
                  <span className="text-xs font-semibold text-white">{val == null ? '-' : String(val)}</span>
                </div>
              ))}
            </div>
            <div className="flex gap-2">
              <Button color="green" size="sm" className="flex-1" onClick={() => handleApprove(selected)}>✓ Approve</Button>
              <Button color="red" size="sm" variant="outline" className="flex-1" onClick={() => handleReject(selected)}>✕ Reject</Button>
            </div>
            <Button color="ghost" size="sm" className="mt-3 w-full" onClick={() => setSelected(null)}>✕ Tutup</Button>
          </div>
        </>
      )}
    </PageLayout>
  );
}
