// TimesheetManagement.tsx — Manajemen timesheet (route /admin/timesheet).
//
// P2-F14-BH: guard in-file useAdminAuth 3-role = kontrak gate DB
// admin_get_timesheet (migrasi 275) + role_page_access /admin/timesheet.
// Parent guard TIDAK cukup: AdminRouteGuard dead code (0 import), DynamicRoutes
// tanpa cek role — probe live 2026-10-16: worker NRP002 menerima 99 route admin
// termasuk route ini.
//
// P2-F14-BB: input "Filter berdasarkan divisi" + param {p_divisi} DIHAPUS —
// admin_get_timesheet() tanpa argumen dan output-nya tanpa kolom divisi
// (keputusan user 2026-10-16): filter yang mustahil berfungsi hanya
// menyesatkan. Fitur filter divisi butuh extend RPC = pekerjaan terpisah.
//
// Kontrak LIVE admin_get_timesheet (275): {ok, data:[{nrp,date,check_in,
// check_out,status,hours}]} — konsumen membaca r.data (P2-F14-BI sekelas).
import { useRpcQuery } from '@/hooks/useRpcQuery';
import useAdminAuth from '@/hooks/useAdminAuth';
import { PageLayout, GlassCard, DataTable, LoadingSpinner, EmptyState } from '@/lib/design-system';
import { timesheetRows, type TimesheetRow } from './AdminAttendance';

const EMPTY: TimesheetRow[] = [];

export default function TimesheetManagement() {
  // P2-F14-BH: 3-role = kontrak TimesheetPage + gate DB 275 (owner/admin_pusat
  // bypass di dalam hook).
  useAdminAuth(['admin_pusat', 'admin_finance', 'admin_operasional']);
  // BB: tanpa params — RPC admin_get_timesheet() tidak punya argumen.
  const { data, isLoading: loading } = useRpcQuery<TimesheetRow[]>({
    fn: 'admin_get_timesheet',
    defaultValue: EMPTY,
    select: timesheetRows,
  });

  return (
    <PageLayout title="Manajemen Timesheet" subtitle="Kelola catatan jam kerja harian">
      <GlassCard>
        {loading ? <LoadingSpinner /> : data.length === 0 ? (
          <EmptyState title="Belum ada data timesheet" />
        ) : (
          <DataTable data={data} columns={[
            { key: 'nrp', label: 'NRP' },
            { key: 'date', label: 'Tanggal' },
            { key: 'check_in', label: 'Masuk' },
            { key: 'check_out', label: 'Keluar' },
            { key: 'status', label: 'Status' },
            { key: 'hours', label: 'Jam Kerja' },
            // TODO: kolom 'nama' + 'shift' + 'lembur' (menit_lembur) belum ada
            // di output admin_get_timesheet — lihat P2-F14-BJ.
          ]} />
        )}
      </GlassCard>
    </PageLayout>
  );
}
