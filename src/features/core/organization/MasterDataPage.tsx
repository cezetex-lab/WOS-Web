// MasterDataPage.jsx — Data Referensi Utama Sistem
import React, { useState, useEffect, useCallback } from 'react';
import { rpc } from '@/lib/supabase-browser';
import { PageLayout, GlassCard, MetricCard, DataTable, Badge, LoadingSpinner, Tabs } from '@/lib/design-system';
import useAdminAuth from '@/hooks/useAdminAuth';

interface MasterDataRow {
  type?: string;
  category?: string;
  tipe?: string;
  name?: string;
  nama?: string;
  label?: string;
  code?: string;
  kode?: string;
  description?: string;
  status?: string;
}

export default function MasterDataPage() {
  useAdminAuth(["admin_pusat"]);
  const [loading, setLoading] = useState(true);
  const [data, setData] = useState<MasterDataRow[]>([]);
  const [tab, setTab] = useState('all');

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc<{ data?: MasterDataRow[] }>('admin_get_master_data');
      const r = result as { ok?: boolean; data?: MasterDataRow[] } | MasterDataRow[];
      setData(Array.isArray(r) ? r : r?.data || []);
    } catch (e) { }
    setLoading(false);
    // eslint-disable-next-line react-hooks/exhaustive-deps -- rpc is stable; data is only set, not read
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  // Group by type
  const types = React.useMemo(() => {
    const set = new Set(data.map(r => r.type || r.category || r.tipe || 'other'));
    return Array.from(set);
  }, [data]);

  const filtered = React.useMemo(() => {
    if (tab === 'all') return data;
    return data.filter(r => (r.type || r.category || r.tipe || 'other') === tab);
  }, [data, tab]);

  const columns = [
    { key: 'type', label: 'Tipe', render: (v: string) => <Badge status={v || 'data'} type="info" /> },
    { key: 'name', label: 'Nama', render: (v: string, row: MasterDataRow) => <span className="text-sm font-semibold text-white">{v || row.nama || row.label || '-'}</span> },
    { key: 'code', label: 'Kode', render: (v: string, row: MasterDataRow) => <span className="text-xs font-mono text-slate-400">{v || row?.kode || '-'}</span> },
    { key: 'description', label: 'Deskripsi', render: (v: string) => <span className="text-xs text-slate-300 truncate max-w-[200px] block">{v || '-'}</span> },
    { key: 'status', label: 'Status', render: (v: string) => <Badge status={v || 'active'} type={v === 'active' ? 'success' : 'default'} /> },
  ];

  const statCards = [
    { icon: '🗄️', value: data.length, label: 'Total Master Data', color: 'blue' as const },
    { icon: '📂', value: types.length, label: 'Kategori', color: 'teal' as const },
    { icon: '✅', value: data.filter(r => r.status === 'active').length, label: 'Aktif', color: 'green' as const },
  ];

  if (loading) return <PageLayout backTo="/admin" title="Master Data"><LoadingSpinner text="Memuat master data..." /></PageLayout>;

  return (
    <PageLayout backTo="/admin" title="🗄️ Master Data" subtitle={`${data.length} data referensi`}>
      <div className="grid grid-cols-3 gap-3 mb-6">
        {statCards.map((s, i) => <MetricCard key={i} {...s} />)}
      </div>
      {types.length > 0 && (
        <div className="mb-4">
          <Tabs tabs={[{ id: 'all', label: 'Semua', count: data.length }, ...types.map(t => ({ id: t, label: t, count: data.filter(r => (r.type || r.category || r.tipe) === t).length }))]} active={tab} onChange={setTab} />
        </div>
      )}
      <GlassCard accent="blue">
        <DataTable columns={columns} data={filtered} searchPlaceholder="Cari master data..." emptyMessage="Tidak ada master data" />
      </GlassCard>
    </PageLayout>
  );
}
