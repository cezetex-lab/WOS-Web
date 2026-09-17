// ReferralPage.tsx — Program rekomendasi karyawan (role-aware)
import React, { useState, useEffect, useCallback } from 'react';
import { rpc, getSession } from '@/lib/supabase-browser';
import { PageLayout, GlassCard, MetricCard, DataTable, Badge, LoadingSpinner } from '@/lib/design-system';
import useAdminAuth from '@/hooks/useAdminAuth';
import { isAdminRole } from '@/lib/role-utils';

export default function ReferralPage() {
  useAdminAuth(["admin_pusat", "admin_hrd"]);
  const session = getSession();
  const role = session?.role || 'worker';
  const nrp = session?.nrp || '';
  const isAdmin = isAdminRole(role);

  const [loading, setLoading] = useState(true);
  const [data, setData] = useState<Record<string, unknown>[]>([]);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      if (isAdmin) {
        const result = await rpc('admin_get_referrals') as Record<string, unknown>;
        setData(Array.isArray(result) ? result : (result?.data as Record<string, unknown>[]) || []);
      } else {
        const result = await rpc('get_worker_referrals', { p_nrp: nrp }) as Record<string, unknown>;
        setData(Array.isArray(result) ? result : (result?.data as Record<string, unknown>[]) || []);
      }
    } catch (e) { }
    setLoading(false);
  }, [isAdmin, nrp]);

  useEffect(() => { fetchData(); }, [fetchData]);

  const columns = isAdmin ? [
    { key: 'referrant_nrp', label: 'Referrer', render: (v: unknown) => <span className="text-xs font-mono text-slate-400">{String(v ?? '')}</span> },
    { key: 'referrant_name', label: 'Nama', render: (v: unknown) => <span className="text-sm font-semibold text-white">{(v as string) || '-'}</span> },
    { key: 'candidate_name', label: 'Kandidat', render: (v: unknown) => <span className="text-xs text-blue-300">{(v as string) || '-'}</span> },
    { key: 'position', label: 'Posisi', render: (v: unknown) => <span className="text-xs text-slate-300">{(v as string) || '-'}</span> },
    { key: 'status', label: 'Status', render: (v: unknown) => <Badge status={(v as string) || 'Pending'} type={v === 'Hired' ? 'success' : v === 'Interview' ? 'warning' : v === 'Rejected' ? 'danger' : 'info'} /> },
    { key: 'bonus', label: 'Bonus', render: (v: unknown) => v ? <span className="text-sm font-bold text-yellow-400">Rp {parseInt(v as string).toLocaleString('id-ID')}</span> : <span className="text-xs text-slate-500">-</span> },
  ] : [
    { key: 'candidate_name', label: 'Kandidat', render: (v: unknown) => <span className="text-sm font-semibold text-white">{(v as string) || '-'}</span> },
    { key: 'position', label: 'Posisi', render: (v: unknown) => <span className="text-xs text-slate-300">{(v as string) || '-'}</span> },
    { key: 'status', label: 'Status', render: (v: unknown) => <Badge status={(v as string) || 'Pending'} type={v === 'Hired' ? 'success' : v === 'Interview' ? 'warning' : v === 'Rejected' ? 'danger' : 'info'} /> },
    { key: 'created_at', label: 'Tanggal', render: (v: unknown) => <span className="text-xs text-slate-300">{v ? new Date(v as string).toLocaleDateString('id-ID') : '-'}</span> },
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
