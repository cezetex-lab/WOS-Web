// BadgesPage.jsx — Sistem penghargaan & poin (role-aware)
import React, { useState, useEffect, useCallback } from 'react';
import { rpc, getSession } from '../../../lib/supabase-browser';
import { PageLayout, GlassCard, MetricCard, DataTable, Badge, LoadingSpinner } from '../../../lib/design-system';
import useAdminAuth from '@/hooks/useAdminAuth';

export default function BadgesPage() {
  useAdminAuth(["admin_pusat", "admin_hrd"]);
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
        const result = await rpc('admin_get_badges');
        setData(Array.isArray(result) ? result : result?.data || []);
      } else {
        const result = await rpc('get_worker_badges', { p_nrp: nrp });
        setData(Array.isArray(result) ? result : result?.data || []);
      }
    } catch (e) { }
    setLoading(false);
  }, [isAdmin, nrp]);

  useEffect(() => { fetchData(); }, [fetchData]);

  const totalPoints = data.reduce((s, r) => s + (parseInt(r.points || r.poin || 0)), 0);

  const columns = isAdmin ? [
    { key: 'nrp', label: 'NRP', render: v => <span className="text-xs font-mono text-slate-400">{v}</span> },
    { key: 'nama', label: 'Nama', render: v => <span className="text-sm font-semibold text-white">{v || '-'}</span> },
    { key: 'badge_name', label: 'Badge', render: v => <span className="text-sm">🏅 {v || '-'}</span> },
    { key: 'category', label: 'Kategori', render: v => <Badge status={v || 'General'} type="info" /> },
    { key: 'points', label: 'Poin', render: v => <span className="text-sm font-bold text-yellow-400">{v || 0} pts</span> },
    { key: 'awarded_at', label: 'Tanggal', render: v => <span className="text-xs text-slate-300">{v ? new Date(v).toLocaleDateString('id-ID') : '-'}</span> },
  ] : [
    { key: 'badge_name', label: 'Badge', render: v => <span className="text-sm">🏅 {v || '-'}</span> },
    { key: 'badge_type', label: 'Tipe', render: v => <Badge status={v || 'General'} type="info" /> },
    { key: 'points', label: 'Poin', render: v => <span className="text-sm font-bold text-yellow-400">{v || 0} pts</span> },
    { key: 'awarded_at', label: 'Tanggal Diterima', render: v => <span className="text-xs text-slate-300">{v ? new Date(v).toLocaleDateString('id-ID') : '-'}</span> },
  ];

  if (loading) return <PageLayout backTo={isAdmin ? '/admin' : '/worker'} title="Badge"><LoadingSpinner text="Memuat badge..." /></PageLayout>;

  return (
    <PageLayout backTo={isAdmin ? '/admin' : '/worker'} title={isAdmin ? '🏅 Badge & Gamifikasi' : '🏅 Badge Saya'} subtitle={`${data.length} ${isAdmin ? 'badge terbit' : 'badge diterima'}`}>
      <div className="grid grid-cols-3 gap-3 mb-6">
        <MetricCard icon="🏅" value={data.length} label={isAdmin ? 'Total Badge' : 'Badge'} color="yellow" />
        <MetricCard icon="⭐" value={totalPoints} label="Total Poin" color="orange" />
        {isAdmin && <MetricCard icon="👥" value={new Set(data.map(r => r.nrp)).size} label="Penerima" color="blue" />}
      </div>
      <GlassCard accent="yellow">
        <DataTable columns={columns} data={data} searchPlaceholder="Cari badge..." emptyMessage="Tidak ada badge" />
      </GlassCard>
    </PageLayout>
  );
}
