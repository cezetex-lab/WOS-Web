// AuditChainPage.jsx — Rantai audit transparan (hash-chain)
import React, { useState, useEffect, useCallback } from 'react';
import { rpc } from '../../../lib/supabase-browser';
import { PageLayout, GlassCard, MetricCard, DataTable, Badge, LoadingSpinner } from '../../../lib/design-system';

export default function AuditChainPage() {
  const [loading, setLoading] = useState(true);
  const [data, setData] = useState([]);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('admin_get_audit_chain');
      setData(Array.isArray(result) ? result : result?.data || []);
    } catch (e) { }
    setLoading(false);
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const columns = [
    { key: 'seq_number', label: '#', render: v => <span className="text-xs font-mono text-blue-400">#{v}</span> },
    { key: 'action', label: 'Aksi', render: v => <span className="text-sm font-semibold text-white">{v || '-'}</span> },
    { key: 'table_name', label: 'Tabel', render: v => <Badge status={v || '-'} type="info" /> },
    { key: 'record_id', label: 'Record', render: v => <span className="text-xs font-mono text-slate-400">{v || '-'}</span> },
    { key: 'prev_hash', label: 'Prev Hash', render: v => <span className="text-[10px] font-mono text-slate-500 truncate block max-w-[100px]">{v ? v.slice(0, 16) + '...' : 'genesis'}</span> },
    { key: 'hash', label: 'Hash', render: v => <span className="text-[10px] font-mono text-green-400 truncate block max-w-[100px]">{v ? v.slice(0, 16) + '...' : '-'}</span> },
    { key: 'created_at', label: 'Waktu', render: v => <span className="text-xs text-slate-300">{v ? new Date(v).toLocaleString('id-ID') : '-'}</span> },
  ];

  if (loading) return <PageLayout backTo="/admin" title="Audit Chain"><LoadingSpinner text="Memuat audit chain..." /></PageLayout>;

  return (
    <PageLayout backTo="/admin" title="🔗 Audit Chain" subtitle={`${data.length} entri tercatat`}>
      <div className="grid grid-cols-3 gap-3 mb-6">
        <MetricCard icon="🔗" value={data.length} label="Total Entri" color="blue" />
        <MetricCard icon="🔒" value="SHA-256" label="Hash Algo" color="green" />
        <MetricCard icon="🛡️" value="Immutable" label="Status" color="teal" />
      </div>
      <GlassCard accent="green" className="mb-4">
        <div className="flex items-center gap-2 text-xs text-green-400">
          <span>🔒</span>
          <span>Setiap entri terhubung via hash-chain — tidak dapat dimodifikasi tanpa memecah rantai</span>
        </div>
      </GlassCard>
      <GlassCard accent="blue">
        <DataTable columns={columns} data={data} searchPlaceholder="Cari audit..." emptyMessage="Tidak ada entri audit" />
      </GlassCard>
    </PageLayout>
  );
}
