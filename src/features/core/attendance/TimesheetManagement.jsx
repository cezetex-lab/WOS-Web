import { useState, useEffect } from 'react';
import { rpc } from '@/lib/supabase-browser';
import { PageLayout, GlassCard, DataTable, LoadingSpinner, EmptyState } from '@/lib/design-system';

export default function TimesheetManagement() {
  const [data, setData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('');

  useEffect(() => {
    const params = filter ? { p_divisi: filter } : {};
    rpc('admin_get_timesheet', params).then(r => {
      setData(Array.isArray(r) ? r : []);
      setLoading(false);
    }).catch(() => setLoading(false));
  }, [filter]);

  return (
    <PageLayout title="Manajemen Timesheet" subtitle="Kelola catatan jam kerja harian">
      <div className="mb-4">
        <input
          type="text"
          placeholder="Filter berdasarkan divisi..."
          value={filter}
          onChange={e => setFilter(e.target.value)}
          className="px-4 py-2 bg-white/5 border border-white/10 rounded-lg text-white text-sm w-64"
        />
      </div>
      <GlassCard>
        {loading ? <LoadingSpinner /> : data.length === 0 ? (
          <EmptyState message="Belum ada data timesheet" />
        ) : (
          <DataTable data={data} columns={[
            { key: 'nrp', label: 'NRP' },
            { key: 'nama', label: 'Nama' },
            { key: 'date', label: 'Tanggal' },
            { key: 'shift', label: 'Shift' },
            { key: 'clock_in', label: 'Masuk' },
            { key: 'clock_out', label: 'Keluar' },
            { key: 'overtime_hours', label: 'Lembur' },
            { key: 'status', label: 'Status' },
          ]} />
        )}
      </GlassCard>
    </PageLayout>
  );
}
