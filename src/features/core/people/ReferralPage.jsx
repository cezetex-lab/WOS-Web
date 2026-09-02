// ReferralPage.jsx — Program rekomendasi karyawan (role-aware)
import React, { useState, useEffect, useCallback } from 'react';
import { rpc, getSession } from '../../../lib/supabase-browser';
import { PageLayout, GlassCard, MetricCard, DataTable, Badge, LoadingSpinner } from '../../../lib/design-system';

export default function ReferralPage() {
  const session = getSession();
  const role = session?.role || 'worker';
  const nrp = session?.nrp || '';
  const isAdmin = role.startsWith('admin_') || role === 'admin';

  const [loading, setLoading] = useState(true);
  const [data, setData] = useState([]);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      if (isAdmin) {
        const result = await rpc('admin_get_referrals');
        setData(Array.isArray(result) ? result : result?.data || []);
      } else {
        const result = await rpc('get_worker_referrals', { p_nrp: nrp });
        setData(Array.isArray(result) ? result : result?.data || []);
      }
    } catch (e) { }
    setLoading(false);
  }, [isAdmin, nrp]);

  useEffect(() => { fetchData(); }, [fetchData]);

  const columns = isAdmin ? [
    { key: 'referrant_nrp', label: 'Referrer', render: v => <span className="text-xs font-mono text-slate-400">{v}</span> },
    { key: 'referrant_name', label: 'Nama', render: v => <span className="text-sm font-semibold text-white">{v || '-'}</span> },
    { key: 'candidate_name', label: 'Kandidat', render: v => <span className="text-xs text-blue-300">{v || '-'}</span> },
    { key: 'position', label: 'Posisi', render: v => <span className="text-xs text-slate-300">{v || '-'}</span> },
    { key: 'status', label: 'Status', render: v => <Badge status={v || 'Pending'} type={v === 'Hired' ? 'success' : v === 'Interview' ? 'warning' : v === 'Rejected' ? 'danger' : 'info'} /> },
    { key: 'bonus', label: 'Bonus', render: v => v ? <span className="text-sm font-bold text-yellow-400">Rp {parseInt(v).toLocaleString('id-ID')}</span> : <span className="text-xs text-slate-500">-</span> },
  ] : [
    { key: 'candidate_name', label: 'Kandidat', render: v => <span className="text-sm font-semibold text-white">{v || '-'}</span> },
    { key: 'position', label: 'Posisi', render: v => <span className="text-xs text-slate-300">{v || '-'}</span> },
    { key: 'status', label: 'Status', render: v => <Badge status={v || 'Pending'} type={v === 'Hired' ? 'success' : v === 'Interview' ? 'warning' : v === 'Rejected' ? 'danger' : 'info'} /> },
    { key: 'created_at', label: 'Tanggal', render: v => <span className="text-xs text-slate-300">{v ? new Date(v).toLocaleDateString('id-ID') : '-'}</span> },
  ];

  const hired = data.filter(r => r.status === 'Hired').length;
  if (loading) return <PageLayout backTo={isAdmin ? '/admin' : '/worker'} title="Referral"><LoadingSpinner text="Memuat referral..." /></PageLayout>;

  return (
    <PageLayout backTo={isAdmin ? '/admin' : '/worker'} title={isAdmin ? '🤝 Referral Program' : '🤝 Referral Saya'} subtitle={`${data.length} referral`}>
      <div className="grid grid-cols-3 gap-3 mb-6">
        <MetricCard icon="🤝" value={data.length} label="Total Referral" color="blue" />
        <MetricCard icon="✅" value={hired} label="Hired" color="green" />
        <MetricCard icon="🏆" value={`${data.length > 0 ? (hired / data.length * 100).toFixed(0) : 0}%`} label="Conversion" color="teal" />
      </div>
      <GlassCard accent="blue">
        <DataTable columns={columns} data={data} searchPlaceholder="Cari referral..." emptyMessage="Tidak ada referral" />
      </GlassCard>
    </PageLayout>
  );
}
