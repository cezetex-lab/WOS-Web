// WhistleblowingPage.tsx — Laporan pelanggaran anonim (role-aware)
import React, { useState } from 'react';
import { getSession, rpc, isRpcError } from '@/lib/supabase-browser';
import { useRpcQuery } from '@/hooks/useRpcQuery';
import { PageLayout, GlassCard, MetricCard, DataTable, Badge, Button, LoadingSpinner, Tabs, Input, useToast } from '@/lib/design-system';
import useAdminAuth from '@/hooks/useAdminAuth';
import { isAdminRole } from '@/lib/role-utils';

interface WhistleblowRow {
  id?: string | number;
  category?: string;
  severity?: string;
  description?: string;
  status?: string;
  created_at?: string;
  detail?: string;
  [key: string]: unknown;
}

export default function WhistleblowingPage() {
  const toast = useToast();
  useAdminAuth(["admin_pusat", "admin_hrd"]);
  const session = getSession();
  const role = session?.role || 'worker';
  const isAdmin = isAdminRole(role);

  const [tab, setTab] = useState('all');
  const [selected, setSelected] = useState<WhistleblowRow | null>(null);
  const [showSubmit, setShowSubmit] = useState(false);
  const [newCategory, setNewCategory] = useState('Etika');
  const [newDesc, setNewDesc] = useState('');

  const { data, isLoading: loading, refetch: refetchData } = useRpcQuery<WhistleblowRow[]>({
    fn: 'get_whistleblowers',
    defaultValue: [],
  });

  const statuses = [...new Set(data.map(r => r.status || 'Open'))];
  const filtered = tab === 'all' ? data : data.filter(r => (r.status || 'Open') === tab);

  const handleSubmit = async () => {
    if (!newDesc.trim()) return;
    try {
      const res = await rpc('submit_whistleblower', { p_category: newCategory, p_desc: newDesc });
      if (isRpcError(res)) { toast.error(res.msg || 'Gagal mengirim laporan'); return; }
      setNewDesc(''); setShowSubmit(false);
      refetchData();
    } catch (e: unknown) { toast.error('Gagal mengirim laporan'); }
  };

  const columns = [
    { key: 'id', label: 'ID', render: (v: string | number) => <span className="text-xs font-mono text-slate-400">#{String(v).slice(-4)}</span> },
    { key: 'category', label: 'Kategori', render: (v: string) => <Badge status={v || 'Lainnya'} type={v === 'Korupsi' ? 'danger' : v === 'Etika' ? 'warning' : 'info'} /> },
    { key: 'severity', label: 'Tingkat', render: (v: string) => <Badge status={v || 'Medium'} type={v === 'High' || v === 'Critical' ? 'danger' : v === 'Medium' ? 'warning' : 'info'} /> },
    { key: 'description', label: 'Deskripsi', render: (v: string) => <span className="text-xs text-slate-300 truncate max-w-[200px] block">{v || '-'}</span> },
    { key: 'status', label: 'Status', render: (v: string) => <Badge status={v || 'Open'} type={v === 'Closed' ? 'success' : v === 'Investigating' ? 'warning' : 'danger'} /> },
    { key: 'created_at', label: 'Tanggal', render: (v: string) => <span className="text-xs text-slate-300">{v ? new Date(v).toLocaleDateString('id-ID') : '-'}</span> },
  ];

  if (loading) return <PageLayout backTo={isAdmin ? '/admin' : '/worker'} title="Whistleblowing"><LoadingSpinner text="Memuat laporan..." /></PageLayout>;

  return (
    <PageLayout backTo={isAdmin ? '/admin' : '/worker'} title="🕊️ Whistleblowing" subtitle={`${data.length} laporan anonim`}>
      <div className="grid grid-cols-3 gap-3 mb-6">
        <MetricCard icon="🕊️" value={data.length} label="Total Laporan" color="red" />
        <MetricCard icon="🔍" value={data.filter(r => r.status === 'Investigating').length} label="Investigasi" color="yellow" />
        <MetricCard icon="✅" value={data.filter(r => r.status === 'Closed').length} label="Selesai" color="green" />
      </div>

      {!isAdmin && (
        <Button color="red" className="mb-4" onClick={() => setShowSubmit(true)}>🕊️ Kirim Laporan Anonim</Button>
      )}

      {showSubmit && (
        <GlassCard accent="red" className="mb-4">
          <h3 className="text-sm font-bold text-white mb-3">🔒 Kirim Laporan Anonim</h3>
          <p className="text-xs text-slate-400 mb-3">Identitas Anda TIDAK akan disimpan. Laporan bersifat rahasia.</p>
          <select value={newCategory} onChange={e => setNewCategory(e.target.value)} className="w-full p-2 rounded-lg bg-slate-800 border border-slate-600 text-white text-sm mb-2">
            <option>Etika</option><option>Korupsi</option><option>Penyalahgunaan</option><option>Keselamatan</option><option>Lainnya</option>
          </select>
          <Input label="Deskripsi" value={newDesc} onChange={setNewDesc} placeholder="Jelaskan laporan Anda secara detail" />
          <div className="flex gap-2 mt-3">
            <Button color="green" onClick={handleSubmit}>Kirim Anonim</Button>
            <Button color="ghost" onClick={() => setShowSubmit(false)}>Batal</Button>
          </div>
        </GlassCard>
      )}

      {statuses.length > 1 && (
        <div className="mb-4">
          <Tabs tabs={[{ id: 'all', label: 'Semua', count: data.length }, ...statuses.map(s => ({ id: s, label: s, count: data.filter(r => (r.status || 'Open') === s).length }))]} active={tab} onChange={setTab} />
        </div>
      )}

      <GlassCard accent="red">
        <DataTable columns={columns} data={filtered} searchPlaceholder="Cari laporan..." onRowClick={setSelected} emptyMessage="Tidak ada laporan" />
      </GlassCard>

      {selected && (
        <>
          <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm" onClick={() => setSelected(null)} />
          <div className="fixed inset-x-0 bottom-0 z-50 max-h-[85vh] bg-slate-900 border-t border-white/10 rounded-t-3xl overflow-y-auto p-5 pb-8">
            <div className="flex justify-center pt-3 pb-1"><div className="w-10 h-1 rounded-full bg-slate-600" /></div>
            <h2 className="text-lg font-bold text-white mb-2">🕊️ Laporan #{String(selected.id).slice(-4)}</h2>
            <p className="text-xs text-slate-300 mb-4">{selected.description || selected.detail || '-'}</p>
            <div className="space-y-1 mb-4">
              {Object.entries(selected).filter(([k]) => !k.startsWith('_') && k !== 'id' && k !== 'description' && k !== 'detail').map(([key, val]) => (
                <div key={key} className="flex justify-between py-2 border-b border-white/5">
                  <span className="text-xs text-slate-400 capitalize">{key.replace(/_/g, ' ')}</span>
                  <span className="text-xs font-semibold text-white">{val == null ? '-' : String(val)}</span>
                </div>
              ))}
            </div>
            <p className="text-micro text-slate-500 text-center mb-3">🔒 Identitas pelapor dilindungi</p>
            <button className="w-full py-2 text-xs text-slate-400 border border-white/10 rounded-lg" onClick={() => setSelected(null)}>✕ Tutup</button>
          </div>
        </>
      )}
    </PageLayout>
  );
}
