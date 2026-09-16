// BadgesPage.jsx — Sistem penghargaan & poin (role-aware)
import React, { useState, useEffect, useCallback } from 'react';
import { rpc, getSession } from '@/lib/supabase-browser';
import { PageLayout, GlassCard, MetricCard, DataTable, Badge, LoadingSpinner } from '@/lib/design-system';
import useAdminAuth from '@/hooks/useAdminAuth';
import { isAdminRole } from '@/lib/role-utils';

/** Extract array from RPC result (handles both direct array and {data: []} shape) */
function toArray(result: unknown): Record<string, unknown>[] {
  if (Array.isArray(result)) return result as Record<string, unknown>[];
  const r = result as Record<string, unknown> | null;
  if (r?.data && Array.isArray(r.data)) return r.data as Record<string, unknown>[];
  return [];
}

export default function BadgesPage() {
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
        const result = await rpc('admin_get_badges');
        setData(toArray(result));
      } else {
        const result = await rpc('get_worker_badges', { p_nrp: nrp });
        setData(toArray(result));
      }
    } catch (_e) { /* ignore */ }
    setLoading(false);
  }, [isAdmin, nrp]);

  useEffect(() => { fetchData(); }, [fetchData]);

  const totalPoints = data.reduce((s: number, r: Record<string, unknown>) => s + (parseInt(String(r.points || r.poin || 0))), 0);

  const columns = isAdmin ? [
    { key: 'nrp', label: 'NRP', render: (v: unknown) => <span className="text-xs font-mono text-slate-400">{v as string}</span> },
    { key: 'nama', label: 'Nama', render: (v: unknown) => <span className="text-sm font-semibold text-white">{(v as string) || '-'}</span> },
    { key: 'badge_name', label: 'Badge', render: (v: unknown) => <span className="text-sm">🏅 {(v as string) || '-'}</span> },
    { key: 'category', label: 'Kategori', render: (v: unknown) => <Badge status={(v as string) || 'General'} type="info" /> },
    { key: 'points', label: 'Poin', render: (v: unknown) => <span className="text-sm font-bold text-yellow-400">{(v as number) || 0} pts</span> },
    { key: 'awarded_at', label: 'Tanggal', render: (v: unknown) => <span className="text-xs text-slate-300">{v ? new Date(v as string).toLocaleDateString('id-ID') : '-'}</span> },
  ] : [
    { key: 'badge_name', label: 'Badge', render: (v: unknown) => <span className="text-sm">🏅 {(v as string) || '-'}</span> },
    { key: 'badge_type', label: 'Tipe', render: (v: unknown) => <Badge status={(v as string) || 'General'} type="info" /> },
    { key: 'points', label: 'Poin', render: (v: unknown) => <span className="text-sm font-bold text-yellow-400">{(v as number) || 0} pts</span> },
    { key: 'awarded_at', label: 'Tanggal Diterima', render: (v: unknown) => <span className="text-xs text-slate-300">{v ? new Date(v as string).toLocaleDateString('id-ID') : '-'}</span> },
  ];

  if (loading) return <PageLayout backTo={isAdmin ? '/admin' : '/worker'} title="Badge"><LoadingSpinner text="Memuat badge..." /></PageLayout>;

  return (
    <PageLayout backTo={isAdmin ? '/admin' : '/worker'} title={isAdmin ? '🏅 Badge & Gamifikasi' : '🏅 Badge Saya'} subtitle={`${data.length} ${isAdmin ? 'badge terbit' : 'badge diterima'}`}>
      <div className="grid grid-cols-3 gap-3 mb-6">
        <MetricCard icon="🏅" value={data.length} label={isAdmin ? 'Total Badge' : 'Badge'} color="orange" />
        <MetricCard icon="⭐" value={totalPoints} label="Total Poin" color="orange" />
        {isAdmin && <MetricCard icon="👥" value={new Set(data.map((r: Record<string, unknown>) => r.nrp)).size} label="Penerima" color="blue" />}
      </div>
      <GlassCard accent="orange">
        <DataTable columns={columns} data={data} searchPlaceholder="Cari badge..." emptyMessage="Tidak ada badge" />
      </GlassCard>
    </PageLayout>
  );
}
