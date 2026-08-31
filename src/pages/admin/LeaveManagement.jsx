// ============================================================
// LeaveManagement.jsx — Custom Admin Leave Page
// RPC: admin_get_leave
// ============================================================

import React, { useState, useEffect, useCallback } from 'react';
import { supabase, rpc } from '../../lib/supabase-browser';
import {
  PageLayout, MetricCard, GlassCard, DataTable, Badge,
  LoadingSpinner, Button, Avatar, Tabs
} from '../../lib/design-system';

export default function LeaveManagement() {
  const [loading, setLoading] = useState(true);
  const [leaveData, setLeaveData] = useState([]);
  const [activeTab, setActiveTab] = useState('all');
  const [selected, setSelected] = useState(null);

  const fetchLeave = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('admin_get_leave');
      const data = Array.isArray(result) ? result
        : result?.data && Array.isArray(result.data) ? result.data : [];
      setLeaveData(data);
    } catch (err) { console.error('Failed to load leave:', err); }
    setLoading(false);
  }, []);

  useEffect(() => { fetchLeave(); }, [fetchLeave]);

  // ── STATS ──
  const totalKuota = leaveData.reduce((s, r) => s + (r.kuota || 0), 0);
  const totalTerpakai = leaveData.reduce((s, r) => s + (r.terpakai || 0), 0);
  const totalSisa = leaveData.reduce((s, r) => s + (r.sisa || 0), 0);
  const habisCuti = leaveData.filter(r => (r.sisa || 0) <= 0).length;

  const statCards = [
    { icon: '👥', value: leaveData.length, label: 'Karyawan', trend: 'Aktif', color: 'blue' },
    { icon: '🌴', value: totalKuota, label: 'Total Kuota', trend: 'Tahun ini', color: 'teal' },
    { icon: '📊', value: totalTerpakai, label: 'Terpakai', trend: `${totalKuota > 0 ? ((totalTerpakai / totalKuota) * 100).toFixed(0) : 0}%`, color: 'orange' },
    { icon: '⚠️', value: habisCuti, label: 'Habis Kuota', trend: 'Perlu perhatian', color: habisCuti > 0 ? 'red' : 'green' },
  ];

  // ── FILTER ──
  const filtered = leaveData.filter(r => {
    if (activeTab === 'exhausted') return (r.sisa || 0) <= 0;
    if (activeTab === 'available') return (r.sisa || 0) > 0;
    return true;
  });

  // ── COLUMNS ──
  const columns = [
    {
      key: 'nama',
      label: 'Karyawan',
      render: (val, row) => (
        <div className="flex items-center gap-2">
          <Avatar name={val || row.nrp} size="sm" />
          <div className="min-w-0">
            <div className="text-xs font-semibold text-white truncate">{val}</div>
            <div className="text-[10px] text-slate-500">{row.nrp}</div>
          </div>
        </div>
      ),
    },
    {
      key: 'kuota',
      label: 'Kuota',
      render: (val) => <span className="text-xs font-semibold text-white">{val || 0} hari</span>,
    },
    {
      key: 'terpakai',
      label: 'Terpakai',
      render: (val, row) => {
        const pct = row.kuota > 0 ? ((val || 0) / row.kuota) * 100 : 0;
        return (
          <div className="flex items-center gap-2">
            <span className="text-xs text-orange-400">{val || 0} hari</span>
            <div className="w-12 h-1.5 bg-slate-700 rounded-full overflow-hidden">
              <div
                className="h-full rounded-full transition-all"
                style={{
                  width: `${Math.min(pct, 100)}%`,
                  backgroundColor: pct >= 90 ? '#f87171' : pct >= 60 ? '#fb923c' : '#34d399',
                }}
              />
            </div>
          </div>
        );
      },
    },
    {
      key: 'sisa',
      label: 'Sisa',
      render: (val) => {
        const v = val || 0;
        return (
          <Badge
            status={`${v} hari`}
            type={v <= 0 ? 'danger' : v <= 5 ? 'warning' : 'success'}
          />
        );
      },
    },
  ];

  if (loading) {
    return (
      <PageLayout backTo="/admin" title="Manajemen Cuti">
        <LoadingSpinner text="Memuat data cuti..." />
      </PageLayout>
    );
  }

  return (
    <PageLayout backTo="/admin" title="Manajemen Cuti" subtitle="Kuota & pemakaian cuti karyawan">
      {/* ── METRICS ── */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
        {statCards.map((s, i) => <MetricCard key={i} {...s} />)}
      </div>

      {/* ── USAGE CHART ── */}
      <GlassCard accent="teal" className="mb-4">
        <h3 className="text-sm font-bold text-white mb-3">📊 Ringkasan Pemakaian</h3>
        <div className="w-full bg-slate-700/50 rounded-full h-4 overflow-hidden">
          <div
            className="h-full rounded-full bg-gradient-to-r from-teal-500 to-sky-500 transition-all"
            style={{ width: `${totalKuota > 0 ? (totalTerpakai / totalKuota) * 100 : 0}%` }}
          />
        </div>
        <div className="flex justify-between mt-2 text-[10px] text-slate-400">
          <span>Dipakai: {totalTerpakai} hari</span>
          <span>Sisa: {totalSisa} hari</span>
          <span>Total: {totalKuota} hari</span>
        </div>
      </GlassCard>

      {/* ── TABS ── */}
      <div className="mb-4">
        <Tabs
          tabs={[
            { id: 'all', label: 'Semua', count: leaveData.length },
            { id: 'available', label: 'Ada Sisa', count: leaveData.filter(r => (r.sisa || 0) > 0).length },
            { id: 'exhausted', label: 'Habis', count: habisCuti },
          ]}
          active={activeTab}
          onChange={setActiveTab}
        />
      </div>

      {/* ── TABLE ── */}
      <GlassCard accent="blue">
        <DataTable
          columns={columns}
          data={filtered}
          searchPlaceholder="Cari nama, NRP..."
          onRowClick={(row) => setSelected(row)}
          emptyMessage="Tidak ada data cuti"
        />
      </GlassCard>

      {/* ── DETAIL MODAL ── */}
      {selected && (
        <>
          <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm" onClick={() => setSelected(null)} />
          <div className="fixed inset-x-0 bottom-0 z-50 max-h-[85vh] bg-slate-900 border-t border-white/10 rounded-t-3xl overflow-y-auto">
            <div className="flex justify-center pt-3 pb-1">
              <div className="w-10 h-1 rounded-full bg-slate-600" />
            </div>
            <div className="px-5 pb-8">
              <div className="flex items-center gap-3 mb-5">
                <Avatar name={selected.nama} size="lg" />
                <div>
                  <h2 className="text-lg font-bold text-white">{selected.nama}</h2>
                  <p className="text-xs text-slate-400">{selected.nrp}</p>
                </div>
              </div>

              <GlassCard accent="teal" className="mb-4">
                <div className="space-y-2">
                  {[
                    { label: 'Tahun', value: selected.tahun || '-' },
                    { label: 'Kuota Total', value: `${selected.kuota || 0} hari` },
                    { label: 'Sudah Dipakai', value: `${selected.terpakai || 0} hari` },
                    { label: 'Sisa Cuti', value: `${selected.sisa || 0} hari` },
                  ].map((row, i) => (
                    <div key={i} className="flex items-center justify-between py-2 border-b border-white/5 last:border-0">
                      <span className="text-xs text-slate-400">{row.label}</span>
                      <span className="text-sm font-bold text-white">{row.value}</span>
                    </div>
                  ))}
                </div>
              </GlassCard>

              <div className="flex justify-end">
                <Button color="ghost" size="sm" onClick={() => setSelected(null)}>✕ Tutup</Button>
              </div>
            </div>
          </div>
        </>
      )}
    </PageLayout>
  );
}
