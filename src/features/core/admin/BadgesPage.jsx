// BadgesPage.jsx — Sistem penghargaan & poin
import React, { useState, useEffect, useCallback } from 'react';
import { rpc } from '../../../lib/supabase-browser';
import { PageLayout, GlassCard, MetricCard, DataTable, Badge, LoadingSpinner } from '../../../lib/design-system';

export default function BadgesPage() {
  const [loading, setLoading] = useState(true);
  const [data, setData] = useState([]);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('admin_get_badges');
      setData(Array.isArray(result) ? result : result?.data || []);
    } catch (e) { console.error(e); }
    setLoading(false);
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const totalPoints = data.reduce((s, r) => s + (parseInt(r.points || r.poin || 0)), 0);

  const columns = [
    { key: 'nrp', label: 'NRP', render: v => <span className="text-xs font-mono text-slate-400">{v}</span> },
    { key: 'nama', label: 'Nama', render: v => <span className="text-sm font-semibold text-white">{v || '-'}</span> },
    { key: 'badge_name', label: 'Badge', render: v => <span className="text-sm">🏅 {v || '-'}</span> },
    { key: 'category', label: 'Kategori', render: v => <Badge status={v || 'General'} type="info" /> },
    { key: 'points', label: 'Poin', render: v => <span className="text-sm font-bold text-yellow-400">{v || 0} pts</span> },
    { key: 'awarded_at', label: 'Tanggal', render: v => <span className="text-xs text-slate-300">{v ? new Date(v).toLocaleDateString('id-ID') : '-'}</span> },
  ];

  if (loading) return <PageLayout backTo="/admin" title="Badge"><LoadingSpinner text="Memuat badge..." /></PageLayout>;

  return (
    <PageLayout backTo="/admin" title="🏅 Badge & Gamifikasi" subtitle={`${data.length} badge terbit`}>
      <div className="grid grid-cols-3 gap-3 mb-6">
        <MetricCard icon="🏅" value={data.length} label="Total Badge" color="yellow" />
        <MetricCard icon="⭐" value={totalPoints} label="Total Poin" color="orange" />
        <MetricCard icon="👥" value={new Set(data.map(r => r.nrp)).size} label="Penerima" color="blue" />
      </div>
      <GlassCard accent="yellow">
        <DataTable columns={columns} data={data} searchPlaceholder="Cari badge..." emptyMessage="Tidak ada badge" />
      </GlassCard>
    </PageLayout>
  );
}
