// CertificationsPage.jsx — Sertifikasi profesional
import React, { useState, useEffect, useCallback } from 'react';
import { rpc } from '../../lib/supabase-browser';
import { PageLayout, GlassCard, MetricCard, DataTable, Badge, LoadingSpinner } from '../../lib/design-system';

export default function CertificationsPage() {
  const [loading, setLoading] = useState(true);
  const [data, setData] = useState([]);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('get_skills_intelligence');
      setData(Array.isArray(result) ? result : result?.data || []);
    } catch (e) { console.error(e); }
    setLoading(false);
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const columns = [
    { key: 'nrp', label: 'NRP', render: v => <span className="text-xs font-mono text-slate-400">{v}</span> },
    { key: 'nama', label: 'Nama', render: v => <span className="text-sm font-semibold text-white">{v || '-'}</span> },
    { key: 'skill', label: 'Skill/Sertifikasi', render: v => <span className="text-xs text-slate-300">{v || '-'}</span> },
    { key: 'level', label: 'Level', render: v => <Badge status={`Level ${v || 1}`} type={v >= 4 ? 'success' : v >= 2 ? 'warning' : 'info'} /> },
    { key: 'certified', label: 'Certified', render: v => <Badge status={v ? '✅ Ya' : '❌ Tidak'} type={v ? 'success' : 'danger'} /> },
  ];

  const certified = data.filter(r => r.certified).length;
  if (loading) return <PageLayout backTo="/admin" title="Sertifikasi"><LoadingSpinner text="Memuat sertifikasi..." /></PageLayout>;

  return (
    <PageLayout backTo="/admin" title="📜 Sertifikasi" subtitle={`${data.length} skill tercatat`}>
      <div className="grid grid-cols-3 gap-3 mb-6">
        <MetricCard icon="📜" value={data.length} label="Total Skill" color="blue" />
        <MetricCard icon="✅" value={certified} label="Certified" color="green" />
        <MetricCard icon="📈" value={data.length > 0 ? ((certified / data.length) * 100).toFixed(0) : 0} label="Coverage %" color="teal" />
      </div>
      <GlassCard accent="blue">
        <DataTable columns={columns} data={data} searchPlaceholder="Cari sertifikasi..." emptyMessage="Tidak ada data sertifikasi" />
      </GlassCard>
    </PageLayout>
  );
}
