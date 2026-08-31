// ReferralPage.jsx — Program rekomendasi karyawan
import React, { useState, useEffect, useCallback } from 'react';
import { rpc } from '../../../lib/supabase-browser';
import { PageLayout, GlassCard, MetricCard, DataTable, Badge, LoadingSpinner } from '../../../lib/design-system';

export default function ReferralPage() {
  const [loading, setLoading] = useState(true);
  const [data, setData] = useState([]);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('admin_get_referrals');
      setData(Array.isArray(result) ? result : result?.data || []);
    } catch (e) { console.error(e); }
    setLoading(false);
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const columns = [
    { key: 'referrant_nrp', label: 'Referrer', render: v => <span className="text-xs font-mono text-slate-400">{v}</span> },
    { key: 'referrant_name', label: 'Nama', render: v => <span className="text-sm font-semibold text-white">{v || '-'}</span> },
    { key: 'candidate_name', label: 'Kandidat', render: v => <span className="text-xs text-blue-300">{v || '-'}</span> },
    { key: 'position', label: 'Posisi', render: v => <span className="text-xs text-slate-300">{v || '-'}</span> },
    { key: 'status', label: 'Status', render: v => <Badge status={v || 'Pending'} type={v === 'Hired' ? 'success' : v === 'Interview' ? 'warning' : v === 'Rejected' ? 'danger' : 'info'} /> },
    { key: 'bonus', label: 'Bonus', render: v => v ? <span className="text-sm font-bold text-yellow-400">Rp {parseInt(v).toLocaleString('id-ID')}</span> : <span className="text-xs text-slate-500">-</span> },
  ];

  if (loading) return <PageLayout backTo="/admin" title="Referral"><LoadingSpinner text="Memuat referral..." /></PageLayout>;

  const hired = data.filter(r => r.status === 'Hired').length;

  return (
    <PageLayout backTo="/admin" title="🤝 Referral Program" subtitle={`${data.length} referral`}>
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
