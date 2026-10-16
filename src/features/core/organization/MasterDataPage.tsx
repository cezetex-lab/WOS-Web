// MasterDataPage.tsx — Data Referensi Utama Sistem
import React, { useState, useEffect, useCallback } from 'react';
import { rpc } from '@/lib/supabase-browser';
import { PageLayout, GlassCard, MetricCard, DataTable, Badge, LoadingSpinner, Tabs } from '@/lib/design-system';
import useAdminAuth from '@/hooks/useAdminAuth';

// Kontrak LIVE admin_get_master_data (migrasi 275, diverifikasi probe 2026-10-16):
// {ok, roles:[{nrp,role,tier}], divisions:[{divisi}]} — TANPA key "data".
// P2-F14-BI: konsumen menyamakan shape ini (bukan mengubah RPC).
interface MasterDataRole { nrp: string; role: string; tier: number }
interface MasterDataDivision { divisi: string }
interface MasterDataResponse {
  ok?: boolean;
  roles?: MasterDataRole[];
  divisions?: MasterDataDivision[];
}

/** Baris tampilan tabel — hasil pemetaan roles + divisions ke kolom DataTable. */
interface MasterDataRow {
  type: string;
  name: string;
  code: string;
  description: string;
  status: string;
}

/** Peta RPC → baris tabel: roles jadi tipe "Role", divisions jadi tipe "Divisi". */
export function mapMasterData(raw: unknown): MasterDataRow[] {
  const r = (Array.isArray(raw) ? undefined : raw) as MasterDataResponse | undefined;
  const roleRows: MasterDataRow[] = (r?.roles ?? []).map((x) => ({
    type: 'Role',
    name: x.role,
    code: x.nrp,
    description: `Tier ${x.tier}`,
    status: 'active',
  }));
  const divRows: MasterDataRow[] = (r?.divisions ?? []).map((x) => ({
    type: 'Divisi',
    name: x.divisi,
    code: '-',
    description: '-',
    status: 'active',
  }));
  return [...roleRows, ...divRows];
}

export default function MasterDataPage() {
  useAdminAuth(["admin_pusat"]);
  const [loading, setLoading] = useState(true);
  const [data, setData] = useState<MasterDataRow[]>([]);
  const [tab, setTab] = useState('all');

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc<MasterDataResponse>('admin_get_master_data');
      setData(mapMasterData(result));
    } catch (e) { }
    setLoading(false);
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  // Group by type
  const types = React.useMemo(() => {
    const set = new Set(data.map(r => r.type || 'other'));
    return Array.from(set);
  }, [data]);

  const filtered = React.useMemo(() => {
    if (tab === 'all') return data;
    return data.filter(r => (r.type || 'other') === tab);
  }, [data, tab]);

  const columns = [
    { key: 'type', label: 'Tipe', render: (v: string) => <Badge status={v || 'data'} type="info" /> },
    { key: 'name', label: 'Nama', render: (v: string) => <span className="text-sm font-semibold text-white">{v || '-'}</span> },
    { key: 'code', label: 'Kode', render: (v: string) => <span className="text-xs font-mono text-slate-400">{v || '-'}</span> },
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
          <Tabs tabs={[{ id: 'all', label: 'Semua', count: data.length }, ...types.map(t => ({ id: t, label: t, count: data.filter(r => r.type === t).length }))]} active={tab} onChange={setTab} />
        </div>
      )}
      <GlassCard accent="blue">
        <DataTable columns={columns} data={filtered} searchPlaceholder="Cari master data..." emptyMessage="Tidak ada master data" />
      </GlassCard>
    </PageLayout>
  );
}
