import { useRpcQuery } from '@/hooks/useRpcQuery';
import { PageLayout, GlassCard, DataTable, MetricCard, LoadingSpinner, EmptyState } from '@/lib/design-system';

export default function AdminAttendance() {
  const { data, isLoading: loading } = useRpcQuery<any[]>({
    fn: 'admin_get_timesheet',
    defaultValue: [],
    select: (r) => Array.isArray(r) ? r : [],
  });
  const stats = { total: data.length };

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
