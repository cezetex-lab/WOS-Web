// WorkerLeave.jsx — Worker Leave Page
import { useState, useEffect } from 'react';
import { rpc, getSession } from '@/lib/supabase-browser';
import { GlassCard, Badge, LoadingSpinner, EmptyState } from '@/lib/design-system';

export default function WorkerLeave() {
  const nrp = getSession()?.nrp;
  const [loading, setLoading] = useState(true);
  const [leaveData, setLeaveData] = useState(null);
  const [requests, setRequests] = useState([]);

  useEffect(() => { loadData(); }, []);

  async function loadData() {
    setLoading(true);
    try {
      const [leaveRes, reqRes] = await Promise.all([
        rpc('get_worker_leave', { p_nrp: nrp }),
        rpc('get_worker_requests', { p_nrp: nrp, p_type: 'CUTI' }),
      ]);
      if (leaveRes?.ok) setLeaveData(leaveRes);
      if (reqRes?.ok) setRequests(reqRes.data || []);
    } catch (e) { }
    setLoading(false);
  }

  if (loading) return <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 flex items-center justify-center"><LoadingSpinner text="Memuat data cuti..." /></div>;

  const quota = leaveData?.kuota_cuti || 12;
  const used = leaveData?.cuti_terpakai || 0;
  const remaining = quota - used;
  const pct = quota > 0 ? Math.round((used / quota) * 100) : 0;

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 pb-24">
      <div className="max-w-7xl mx-auto px-4 py-4">
        <h1 className="text-xl font-bold text-white mb-1">🏖️ Cuti Saya</h1>
        <p className="text-xs text-slate-400 mb-4">Kuota cuti & riwayat pengajuan</p>

        {/* Quota Card */}
        <GlassCard className="p-4 mb-4">
          <div className="flex items-center justify-between mb-3">
            <span className="text-sm text-slate-300">Kuota Tahunan</span>
            <span className="text-sm font-bold text-white">{used}/{quota} hari</span>
          </div>
          <div className="w-full bg-slate-700 rounded-full h-2.5 mb-2">
            <div className="h-2.5 rounded-full bg-emerald-500 transition-all" style={{ width: Math.min(pct, 100) + "%" }} />
          </div>
          <div className="flex justify-between text-[11px] text-slate-500">
            <span>{pct}% terpakai</span>
            <span>{remaining} hari tersisa</span>
          </div>
        </GlassCard>

        {/* Leave History */}
        <h2 className="text-sm font-semibold text-white mb-2">Riwayat Pengajuan</h2>
        {requests.length === 0 ? (
          <EmptyState icon="🏖️" title="Belum ada pengajuan" subtitle="Ajukan cuti melalui menu Self-Service" />
        ) : (
          <div className="space-y-2">
            {requests.map((r, i) => (
              <GlassCard key={r.id || i} className="p-3">
                <div className="flex items-center justify-between mb-1">
                  <span className="text-sm text-white font-medium">{r.sub_type || r.type}</span>
                  <Badge variant={r.status === 'Approved' ? 'success' : r.status === 'Rejected' ? 'danger' : 'warning'}>
                    {r.status}
                  </Badge>
                </div>
                <p className="text-[11px] text-slate-400">{r.details_json || r.note || '-'}</p>
                <p className="text-[11px] text-slate-500 mt-1">{r.created_at ? new Date(r.created_at).toLocaleDateString('id-ID') : '-'}</p>
              </GlassCard>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
