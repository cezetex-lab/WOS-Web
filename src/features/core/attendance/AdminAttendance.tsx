// AdminAttendance.tsx — Dashboard kehadiran (route /admin/attendance).
//
// P2-F14-BH: guard in-file useAdminAuth 3-role = kontrak gate DB
// admin_get_timesheet (migrasi 275) + role_page_access /admin/timesheet.
// Parent guard TIDAK cukup: AdminRouteGuard dead code (0 import), DynamicRoutes
// tanpa cek role — probe live 2026-10-16: worker NRP002 menerima 99 route admin
// termasuk route ini.
//
// Kontrak LIVE admin_get_timesheet (275): {ok, data:[{nrp,date,check_in,
// check_out,status,hours}]} — konsumen membaca r.data (P2-F14-BI sekelas).
import { useRpcQuery } from '@/hooks/useRpcQuery';
import useAdminAuth from '@/hooks/useAdminAuth';
import { PageLayout, GlassCard, DataTable, MetricCard, LoadingSpinner, EmptyState } from '@/lib/design-system';

/** Satu baris output admin_get_timesheet (alias AS dari jam_masuk/jam_keluar — 275). */
export interface TimesheetRow {
  nrp: string;
  date: string;
  check_in: string | null;
  check_out: string | null;
  status: string | null;
  hours: number | null;
}

/** Ambil array `data` dari envelope {ok,data}; selain itu → []. */
export function timesheetRows(raw: unknown): TimesheetRow[] {
  const r = raw as { data?: TimesheetRow[] } | TimesheetRow[] | null;
  if (Array.isArray(r)) return r;
  return Array.isArray(r?.data) ? r.data : [];
}

const EMPTY: TimesheetRow[] = [];

export default function AdminAttendance() {
  // P2-F14-BH: 3-role = kontrak TimesheetPage + gate DB 275 (owner/admin_pusat
  // bypass di dalam hook).
  useAdminAuth(['admin_pusat', 'admin_finance', 'admin_operasional']);
  const { data, isLoading: loading } = useRpcQuery<TimesheetRow[]>({
    fn: 'admin_get_timesheet',
    defaultValue: EMPTY,
    select: timesheetRows,
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
            { key: 'date', label: 'Tanggal' },
            { key: 'check_in', label: 'Masuk' },
            { key: 'check_out', label: 'Keluar' },
            { key: 'status', label: 'Status' },
            { key: 'hours', label: 'Jam Kerja' },
            // TODO: kolom 'nama' (join employees_master) belum ada di output
            // admin_get_timesheet — lihat P2-F14-BJ.
          ]} />
        )}
      </GlassCard>
    </PageLayout>
  );
}
