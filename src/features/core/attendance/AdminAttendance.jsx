import { useState, useEffect } from 'react';
import { rpc } from '@/lib/supabase-browser';
import { PageLayout, GlassCard, DataTable, MetricCard, LoadingSpinner, EmptyState } from '@/lib/design-system';

export default function AdminAttendance() {
  const [data, setData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [stats, setStats] = useState({});

  useEffect(() => {
    rpc('admin_get_timesheet', {}).then(r => {
      setData(Array.isArray(r) ? r : []);
      setStats({ total: Array.isArray(r) ? r.length : 0 });
      setLoading(false);
    }).catch(() => setLoading(false));
  }, []);

  return (
    <PageLayout title="Dashboard Kehadiran" subtitle="Monitoring kehadiran seluruh karyawan">
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
        <MetricCard title="Total Karyawan" value={stats.total || 0} icon="👥" />
        <MetricCard title="Hadir Hari Ini" value="-" icon="✅" />
        <MetricCard title="Terlambat" value="-" icon="⏰" />
        <MetricCard title="Tidak Hadir" value="-" icon="❌" />
      </div>
      <GlassCard>
        {loading ? <LoadingSpinner /> : data.length === 0 ? (
          <EmptyState message="Belum ada data kehadiran" />
        ) : (
          <DataTable data={data} columns={[
            { key: 'nrp', label: 'NRP' },
            { key: 'nama', label: 'Nama' },
            { key: 'date', label: 'Tanggal' },
            { key: 'clock_in', label: 'Masuk' },
            { key: 'clock_out', label: 'Keluar' },
            { key: 'status', label: 'Status' },
            { key: 'hours_worked', label: 'Jam Kerja' },
          ]} />
        )}
      </GlassCard>
    </PageLayout>
  );
}
