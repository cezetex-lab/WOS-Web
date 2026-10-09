import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import React from 'react';
import { MemoryRouter, Routes, Route, useLocation } from 'react-router-dom';
import RoleGuard from '@/components/RoleGuard';
import useAdminAuth from '@/hooks/useAdminAuth';
import { getSession } from '@/lib/supabase-browser';
import type { UserSession } from '@/types';

// 270C — uji dual-accept RoleGuard (permission branch) dan useAdminAuth
// (array mode legacy ATAU { permission } mode). getSession di-mock supaya
// skenario sesi lama (permissions === undefined) bisa disimulasikan tanpa DB.
vi.mock('@/lib/supabase-browser', () => ({ getSession: vi.fn() }));

const mockedGetSession = vi.mocked(getSession);

const FUTURE = new Date(Date.now() + 3_600_000).toISOString();

function sess(partial: Partial<UserSession>): UserSession {
  return {
    nrp: 'NRP100', nama: 'Test Admin', role: 'admin_hrd', role_level: 3,
    business_unit_id: 'BU-HQ', entry: 'admin', expires_at: FUTURE, ...partial,
  };
}

function LocationProbe() {
  const loc = useLocation();
  return <div data-testid="loc">{loc.pathname}</div>;
}

/** Render RoleGuard di /protected; halaman "/" = tujuan redirect (redirectTo default '/'). */
function renderRoleGuard(opts: { session: UserSession | null; permission?: string; allowedRoles?: string[] }) {
  mockedGetSession.mockReturnValue(opts.session);
  return render(
    <MemoryRouter initialEntries={['/protected']}>
      <LocationProbe />
      <Routes>
        <Route path="/" element={<div data-testid="login">LOGIN</div>} />
        <Route
          path="/protected"
          element={
            <RoleGuard allowedRoles={opts.allowedRoles ?? []} permission={opts.permission}>
              <div data-testid="child">CHILD</div>
            </RoleGuard>
          }
        />
      </Routes>
    </MemoryRouter>,
  );
}

/** Konsumen useAdminAuth di /admin/payroll; "/admin" = tujuan redirect hook. */
function AdminConsumer({ arg }: { arg: string[] | { permission: string } }) {
  const { role, isAllowed } = useAdminAuth(arg);
  return (
    <>
      <div data-testid="role">{role}</div>
      <div data-testid="allowed">{String(isAllowed)}</div>
      <div data-testid="child">ADMIN_PAGE</div>
    </>
  );
}

function renderUseAdminAuth(opts: { session: UserSession | null; arg: string[] | { permission: string } }) {
  mockedGetSession.mockReturnValue(opts.session);
  return render(
    <MemoryRouter initialEntries={['/admin/payroll']}>
      <LocationProbe />
      <Routes>
        {/* Consumer di KEDUA route: bounce '/admin/payroll' → '/admin' tetap terpantau
            (isAllowed/role harus tetap terbaca setelah redirect). */}
        <Route path="/admin" element={<AdminConsumer arg={opts.arg} />} />
        <Route path="/admin/payroll" element={<AdminConsumer arg={opts.arg} />} />
      </Routes>
    </MemoryRouter>,
  );
}

describe('270C: RoleGuard permission branch', () => {
  beforeEach(() => vi.clearAllMocks());

  it('permissions ADA + cocok → authorized (allowedRoles diabaikan)', async () => {
    renderRoleGuard({ session: sess({ permissions: ['payroll.view'] }), permission: 'payroll.view', allowedRoles: ['admin_finance'] });
    await waitFor(() => expect(screen.getByTestId('child')).toBeTruthy());
    expect(screen.getByTestId('loc').textContent).toBe('/protected');
  });

  it('permissions ADA tapi TIDAK cocok → redirect (fail-closed)', async () => {
    renderRoleGuard({ session: sess({ permissions: ['other.perm'] }), permission: 'payroll.view', allowedRoles: ['admin_hrd'] });
    await waitFor(() => expect(screen.getByTestId('loc').textContent).toBe('/'));
    expect(screen.queryByTestId('child')).toBeNull();
  });

  it('permissions = [] (fetch sukses kosong) → redirect (fail-closed)', async () => {
    renderRoleGuard({ session: sess({ permissions: [] }), permission: 'payroll.view', allowedRoles: ['admin_hrd'] });
    await waitFor(() => expect(screen.getByTestId('loc').textContent).toBe('/'));
    expect(screen.queryByTestId('child')).toBeNull();
  });

  it('permissions undefined (sesi lama) → FALLBACK ke allowedRoles', async () => {
    renderRoleGuard({ session: sess({}), permission: 'payroll.view', allowedRoles: ['admin_hrd'] });
    await waitFor(() => expect(screen.getByTestId('child')).toBeTruthy());
    expect(screen.getByTestId('loc').textContent).toBe('/protected');
  });

  it('permissions undefined + role tidak di allowedRoles → redirect (fallback tetap fail-closed)', async () => {
    renderRoleGuard({ session: sess({}), permission: 'payroll.view', allowedRoles: ['admin_finance'] });
    await waitFor(() => expect(screen.getByTestId('loc').textContent).toBe('/'));
    expect(screen.queryByTestId('child')).toBeNull();
  });
});

describe('270C: useAdminAuth dual mode', () => {
  beforeEach(() => vi.clearAllMocks());

  it('mode { permission }: permissions cocok → tetap di halaman, isAllowed true', async () => {
    renderUseAdminAuth({ session: sess({ permissions: ['payroll.view'] }), arg: { permission: 'payroll.view' } });
    await waitFor(() => expect(screen.getByTestId('child')).toBeTruthy());
    expect(screen.getByTestId('loc').textContent).toBe('/admin/payroll');
    expect(screen.getByTestId('allowed').textContent).toBe('true');
  });

  it('mode { permission }: permissions tidak cocok → bounce ke /admin, isAllowed false', async () => {
    renderUseAdminAuth({ session: sess({ permissions: ['other'] }), arg: { permission: 'payroll.view' } });
    await waitFor(() => expect(screen.getByTestId('loc').textContent).toBe('/admin'));
    expect(screen.getByTestId('allowed').textContent).toBe('false');
  });

  it('mode { permission }: permissions undefined (sesi lama) → fallback longgar (270C–D), isAllowed true', async () => {
    renderUseAdminAuth({ session: sess({}), arg: { permission: 'payroll.view' } });
    await waitFor(() => expect(screen.getByTestId('child')).toBeTruthy());
    expect(screen.getByTestId('allowed').textContent).toBe('true');
  });

  it('mode array (legacy): role cocok → tetap, isAllowed true', async () => {
    renderUseAdminAuth({ session: sess({ role: 'admin_hrd' }), arg: ['admin_hrd'] });
    await waitFor(() => expect(screen.getByTestId('child')).toBeTruthy());
    expect(screen.getByTestId('allowed').textContent).toBe('true');
  });

  it('mode array (legacy): role tidak cocok → bounce ke /admin, isAllowed false', async () => {
    renderUseAdminAuth({ session: sess({ role: 'admin_finance' }), arg: ['admin_hrd'] });
    await waitFor(() => expect(screen.getByTestId('loc').textContent).toBe('/admin'));
    expect(screen.getByTestId('allowed').textContent).toBe('false');
  });

  it('mode array kosong (legacy gate murni) → tetap diizinkan', async () => {
    renderUseAdminAuth({ session: sess({ role: 'admin_finance' }), arg: [] });
    await waitFor(() => expect(screen.getByTestId('child')).toBeTruthy());
    expect(screen.getByTestId('allowed').textContent).toBe('true');
  });

  it('owner bypass tetap berlaku di kedua mode', async () => {
    renderUseAdminAuth({ session: sess({ role: 'owner', permissions: [] }), arg: { permission: 'payroll.view' } });
    await waitFor(() => expect(screen.getByTestId('child')).toBeTruthy());
    expect(screen.getByTestId('allowed').textContent).toBe('true');
    expect(screen.getByTestId('role').textContent).toBe('owner');
  });
});
