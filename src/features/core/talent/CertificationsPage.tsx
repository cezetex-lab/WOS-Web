// CertificationsPage.jsx — Sertifikasi profesional (role-aware)
import React, { useState, useEffect, useCallback } from 'react';
import { rpc, getSession } from '@/lib/supabase-browser';
import { PageLayout, GlassCard, MetricCard, DataTable, Badge, LoadingSpinner } from '@/lib/design-system';
import useAdminAuth from '@/hooks/useAdminAuth';

export default function CertificationsPage() {
  useAdminAuth(["admin_pusat", "admin_hrd"]);
  const session = getSession();
  const role = session?.role || 'worker';
  const nrp = session?.nrp || '';
  const isAdmin = role.startsWith('admin_') || role === 'admin';

  const [loading, setLoading] = useState(true);
  const [data, setData] = useState<Record<string, unknown>[]>([]);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      if (isAdmin) {
        const result = await rpc('get_skills_intelligence') as Record<string, unknown>;
        setData(Array.isArray(result) ? result : (result?.data as Record<string, unknown>[]) || []);
      } else {
        const result = await rpc('get_worker_certifications', { p_nrp: nrp }) as Record<string, unknown>;
        setData(Array.isArray(result) ? result : (result?.data as Record<string, unknown>[]) || []);
      }
    } catch (e) { }
    setLoading(false);
  }, [isAdmin, nrp]);

  useEffect(() => { fetchData(); }, [fetchData]);

  const columns = isAdmin ? [
    { key: 'nrp', label: 'NRP', render: (v: unknown) => <span className="text-xs font-mono text-slate-400">{String(v ?? '')}</span> },
    { key: 'nama', label: 'Nama', render: (v: unknown) => <span className="text-sm font-semibold text-white">{(v as string) || '-'}</span> },
    { key: 'skill', label: 'Skill/Sertifikasi', render: (v: unknown) => <span className="text-xs text-slate-300">{(v as string) || '-'}</span> },
    { key: 'level', label: 'Level', render: (v: unknown) => <Badge status={`Level ${v || 1}`} type={(v as number) >= 4 ? 'success' : (v as number) >= 2 ? 'warning' : 'info'} /> },
    { key: 'certified', label: 'Certified', render: (v: unknown) => <Badge status={v ? 'Ya' : 'Tidak'} type={v ? 'success' : 'danger'} /> },
  ] : [
    { key: 'cert_name', label: 'Sertifikasi', render: (v: unknown) => <span className="text-sm font-semibold text-white">{(v as string) || '-'}</span> },
    { key: 'issuer', label: 'Penerbit', render: (v: unknown) => <span className="text-xs text-slate-300">{(v as string) || '-'}</span> },
    { key: 'issue_date', label: 'Tanggal', render: (v: unknown) => <span className="text-xs text-slate-300">{v ? new Date(v as string).toLocaleDateString('id-ID') : '-'}</span> },
    { key: 'expiry_date', label: 'Kadaluarsa', render: (v: unknown) => <span className="text-xs text-slate-300">{v ? new Date(v as string).toLocaleDateString('id-ID') : '-'}</span> },
    { key: 'status', label: 'Status', render: (v: unknown) => <Badge status={(v as string) || 'Active'} type={v === 'Active' ? 'success' : 'warning'} /> },
  ];

  const certified = isAdmin ? data.filter(r => r.certified).length : data.length;
  if (loading) return <PageLayout backTo={isAdmin ? '/admin' : '/worker'} title="Sertifikasi"><LoadingSpinner text="Memuat sertifikasi..." /></PageLayout>;

  return (
    <PageLayout backTo={isAdmin ? '/admin' : '/worker'} title={isAdmin ? '📜 Sertifikasi' : '📜 Sertifikasi Saya'} subtitle={`${data.length} ${isAdmin ? 'skill tercatat' : 'sertifikat'}`}>
      <div className="grid grid-cols-3 gap-3 mb-6">
        <MetricCard icon="📜" value={data.length} label={isAdmin ? 'Total Skill' : 'Sertifikat'} color="blue" />
        <MetricCard icon="✅" value={certified} label="Certified" color="green" />
        {isAdmin && <MetricCard icon="📈" value={data.length > 0 ? ((certified / data.length) * 100).toFixed(0) : 0} label="Coverage %" color="teal" />}
      </div>
      <GlassCard accent="blue">
        <DataTable columns={columns} data={data} searchPlaceholder="Cari sertifikasi..." emptyMessage="Tidak ada data sertifikasi" />
      </GlassCard>
    </PageLayout>
  );
}
