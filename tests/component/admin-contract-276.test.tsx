/**
 * admin-contract-276.test.tsx — RED/GREEN kontrak konsumen vs RPC live
 * (P2-F14-BI MasterDataPage · P2-F14-BH guard 2 halaman · P2-F14-BB param).
 *
 * FIXTURE = SHAPE LIVE (bukan karangan): diambil dari probe 2026-10-16
 * (transaksi ROLLBACK, `.agents/logs/bi-bh-investigasi-20261016.log`):
 *   admin_get_master_data() -> {"ok":true,"roles":[{nrp,role,tier},…],"divisions":[{divisi},…]}
 *                              (TANPA key "data")
 *   admin_get_timesheet()   -> {"ok":true,"data":[{nrp,date,check_in,check_out,status,hours}]}
 *
 * Yang diuji:
 *   BI  — admin_pusat melihat baris roles+divisions (bukan "Tidak ada master data").
 *   BH  — worker (role di luar 3-role) di-redirect ke /admin di KEDUA halaman
 *         (useAdminAuth in-file; parent guard DynamicRoutes TIDAK memfilter role —
 *         probe live: worker menerima 99 route admin termasuk 2 route ini).
 *   BB  — TimesheetManagement memanggil rpc('admin_get_timesheet') TANPA argumen
 *         dan tidak lagi merender input "Filter berdasarkan divisi"
 *         (output RPC tanpa kolom divisi — filter mustahil berfungsi).
 *   + konsumsi {ok,data} kedua halaman attendance (kelas sama BI).
 *
 * rpc/getSession di-mock: tanpa DB, tanpa jaringan — menguji KONTRAK, bukan DB
 * (gate DB 42501 sudah dibuktikan GREEN 275; lihat AGENTS §5.8 AX).
 */
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import React from 'react';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import MasterDataPage from '@/features/core/organization/MasterDataPage';
import AdminAttendance from '@/features/core/attendance/AdminAttendance';
import TimesheetManagement from '@/features/core/attendance/TimesheetManagement';
import { rpc, getSession } from '@/lib/supabase-browser';
import type { UserSession } from '@/types';

vi.mock('@/lib/supabase-browser', () => ({
  rpc: vi.fn(),
  getSession: vi.fn(),
  isRpcError: () => false,
}));

const mockedRpc = vi.mocked(rpc);
const mockedGetSession = vi.mocked(getSession);

/** Shape live 2026-10-16 (probe ROLLBACK — lihat header). */
const MASTER_LIVE = {
  ok: true,
  roles: [
    { nrp: 'NRP001', role: 'admin_pusat', tier: 5 },
    { nrp: 'NRP002', role: 'worker', tier: 1 },
  ],
  divisions: [{ divisi: 'Accounting' }, { divisi: 'Mining' }],
};

const TIMESHEET_LIVE = {
  ok: true,
  data: [
    {
      nrp: 'NRP002',
      date: '2026-10-01',
      check_in: '2026-10-01 07:59:00+07',
      check_out: '2026-10-01 17:01:00+07',
      status: 'HADIR',
      hours: 8,
    },
  ],
};

const FUTURE = new Date(Date.now() + 3_600_000).toISOString();

function sess(role: string): UserSession {
  return {
    nrp: role === 'worker' ? 'NRP002' : 'NRP100',
    nama: 'Kontrak Test',
    role,
    role_level: role === 'worker' ? 1 : 3,
    business_unit_id: 'BU-HQ',
    entry: role === 'worker' ? 'worker' : 'admin',
    expires_at: FUTURE,
  } as UserSession;
}

/**
 * Render halaman di route-nya; "/admin" = tujuan redirect useAdminAuth.
 * Halaman tetap ter-mount via "*" sampai navigate('/admin') membongkarnya.
 */
function renderPage(Page: React.ComponentType) {
  return render(
    <MemoryRouter initialEntries={['/admin/kontrak-test']}>
      <Routes>
        <Route path="/admin" element={<div data-testid="admin-home">ADMIN_HOME</div>} />
        <Route path="*" element={<Page />} />
      </Routes>
    </MemoryRouter>,
  );
}

beforeEach(() => {
  vi.clearAllMocks();
  mockedRpc.mockImplementation((fn: string) =>
    Promise.resolve(fn === 'admin_get_master_data' ? MASTER_LIVE : TIMESHEET_LIVE),
  );
});

describe('P2-F14-BI — MasterDataPage kontrak admin_get_master_data', () => {
  it('admin_pusat: baris roles+divisions tampil (bukan "Tidak ada master data")', async () => {
    mockedGetSession.mockReturnValue(sess('admin_pusat'));
    renderPage(MasterDataPage);
    await waitFor(() => expect(screen.getByText('NRP001')).toBeInTheDocument());
    expect(screen.getByText('Accounting')).toBeInTheDocument();
    expect(screen.getByText('admin_pusat')).toBeInTheDocument();
    expect(screen.queryByText('Tidak ada master data')).toBeNull();
  });

  it('worker: di-redirect ke /admin (useAdminAuth in-file)', async () => {
    mockedGetSession.mockReturnValue(sess('worker'));
    renderPage(MasterDataPage);
    await waitFor(() => expect(screen.getByTestId('admin-home')).toBeInTheDocument());
  });
});

describe('P2-F14-BH — guard in-file 2 halaman attendance', () => {
  it('AdminAttendance: worker di-redirect ke /admin', async () => {
    mockedGetSession.mockReturnValue(sess('worker'));
    renderPage(AdminAttendance);
    await waitFor(() => expect(screen.getByTestId('admin-home')).toBeInTheDocument());
  });

  it('TimesheetManagement: worker di-redirect ke /admin', async () => {
    mockedGetSession.mockReturnValue(sess('worker'));
    renderPage(TimesheetManagement);
    await waitFor(() => expect(screen.getByTestId('admin-home')).toBeInTheDocument());
  });
});

describe('P2-F14-BH/BB — konsumsi admin_get_timesheet {ok,data} + tanpa param', () => {
  it('AdminAttendance (admin_pusat): baris dari r.data tampil', async () => {
    mockedGetSession.mockReturnValue(sess('admin_pusat'));
    renderPage(AdminAttendance);
    await waitFor(() => expect(screen.getByText('NRP002')).toBeInTheDocument());
    expect(screen.getByText('HADIR')).toBeInTheDocument();
    expect(screen.queryByText('Belum ada data kehadiran')).toBeNull();
  });

  it('TimesheetManagement (admin_pusat): baris tampil, TANPA input filter divisi, TANPA argumen RPC', async () => {
    mockedGetSession.mockReturnValue(sess('admin_finance'));
    renderPage(TimesheetManagement);
    await waitFor(() => expect(screen.getByText('NRP002')).toBeInTheDocument());
    expect(screen.getByText('HADIR')).toBeInTheDocument();
    // BB: RPC tanpa argumen — kolom divisi tidak ada di output (2026-10-16).
    // Catatan: useRpcQuery selalu mengirim `params ?? {}` (perilaku hook, bukan
    // halaman) — kontrak yang dijaga: TIDAK ADA argumen p_divisi sama sekali.
    expect(screen.queryByPlaceholderText('Filter berdasarkan divisi')).toBeNull();
    const calls = mockedRpc.mock.calls.filter((c) => c[0] === 'admin_get_timesheet');
    expect(calls.length).toBeGreaterThan(0);
    for (const [, params] of calls) {
      expect(params ?? {}).not.toHaveProperty('p_divisi');
    }
  });
});
