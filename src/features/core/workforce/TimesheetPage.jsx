// TimesheetPage.jsx — Catatan jam kerja harian
import React, { useState, useEffect, useCallback } from 'react';
import { rpc } from '../../../lib/supabase-browser';
import { PageLayout, GlassCard, MetricCard, DataTable, Badge, LoadingSpinner } from '../../../lib/design-system';
import useAdminAuth from '@/hooks/useAdminAuth';

export default function TimesheetPage() {
  useAdminAuth(["admin_pusat", "admin_finance", "admin_produksi"]);
  const [loading, setLoading] = useState(true);
  const [data, setData] = useState([]);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('admin_get_timesheet');
      setData(Array.isArray(result) ? result : result?.data || []);
    } catch (e) { }
    setLoading(false);
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const totalHours = data.reduce((s, r) => s + (parseFloat(r.total_hours || r.jam_kerja || 0)), 0);
  const avgHours = data.length > 0 ? (totalHours / data.length).toFixed(1) : 0;

  const columns = [
    { key: 'nrp', label: 'NRP', render: (v) => <span className="text-xs font-mono text-slate-400">{v}</span> },
    { key: 'nama', label: 'Nama', render: (v) => <span className="text-sm font-semibold text-white">{v || '-'}</span> },
    { key: 'date', label: 'Tanggal', render: (v) => <span className="text-xs text-slate-300">{v ? new Date(v).toLocaleDateString('id-ID') : '-'}</span> },
    { key: 'clock_in', label: 'Masuk', render: (v) => <span className="text-xs text-green-400">{v || '-'}</span> },
    { key: 'clock_out', label: 'Keluar', render: (v) => <span className="text-xs text-red-400">{v || '-'}</span> },
    { key: 'total_hours', label: 'Jam', render: (v) => <span className="text-xs font-bold text-blue-400">{v ? `${v}h` : '-'}</span> },
    { key: 'status', label: 'Status', render: (v) => <Badge status={v || 'Hadir'} type={v?.toLowerCase() === 'alpha' ? 'danger' : v?.toLowerCase() === 'late' || v?.toLowerCase() === 'terlambat' ? 'warning' : 'success'} /> },
  ];

  if (loading) return <PageLayout backTo="/admin" title="Timesheet"><LoadingSpinner text="Memuat timesheet..." /></PageLayout>;

  return (
    <PageLayout backTo="/admin" title="⏱️ Timesheet" subtitle={`${data.length} catatan`}>
      <div className="grid grid-cols-3 gap-3 mb-6">
        <MetricCard icon="📋" value={data.length} label="Total Entry" color="blue" />
        <MetricCard icon="🕐" value={`${totalHours.toFixed(1)}h`} label="Total Jam" color="green" />
        <MetricCard icon="📊" value={`${avgHours}h`} label="Rata-rata/Hari" color="teal" />
      </div>
      <GlassCard accent="blue">
        <DataTable columns={columns} data={data} searchPlaceholder="Cari timesheet..." emptyMessage="Tidak ada data timesheet" />
      </GlassCard>
    </PageLayout>
  );
}
