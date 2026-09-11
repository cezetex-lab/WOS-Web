/**
 * drawer-navigation.spec.js — AppDrawer regression spec.
 *
 * Promoted from the one-off click-through that verified the drawer refactor:
 * fallback constants de-duplicated, area filter centralized in
 * menu-builder.drawerPathInArea, exact-path handling for /admin, /worker,
 * /dashboard and /owner (the /dashboard + /owner fallbacks previously
 * produced EMPTY drawers).
 *
 * Covers the drawer's two render paths:
 *  1. FALLBACK groups — get_enabled_modules empty (or excluding the current
 *     role) → hardcoded "gate" groups per role/area.
 *  2. DYNAMIC menu — module_definitions rows flowing through buildMenu().
 *
 * Sessions are injected via sessionStorage 'wos_user' (SessionGuard's worker
 * RPC-token fallback contract) — no real credentials. Menu filtering is
 * COSMETIC by design; real access control stays in DynamicRoutes + RLS.
 */
import { test, expect } from '@playwright/test';
import { mockSupabase } from './helpers/mock-supabase';

// ── Fixtures ─────────────────────────────────────────────────────────

const EXP = '2099-01-01T00:00:00Z'; // far-future expiry for loadSessionCache

const SESSIONS = {
  admin_pusat: { token: 'mock', nrp: 'NRP001', nama: 'T Pusat', role: 'admin_pusat', role_level: 4, business_unit: 'HQ', tier: 9, expires_at: EXP },
  admin_hrd: { token: 'mock', nrp: 'NRP00H', nama: 'T HRD', role: 'admin_hrd', role_level: 3, business_unit: 'HQ', tier: 5, expires_at: EXP },
  admin_finance: { token: 'mock', nrp: 'NRP00F', nama: 'T Fin', role: 'admin_finance', role_level: 3, business_unit: 'HQ', tier: 5, expires_at: EXP },
  worker: { token: 'mock', nrp: 'NRP00W', nama: 'T Worker', role: 'worker', role_level: 1, business_unit: 'HQ', tier: 1, expires_at: EXP },
  manager: { token: 'mock', nrp: 'NRP00M', nama: 'T Manager', role: 'manager', role_level: 4, business_unit: 'HQ', tier: 6, expires_at: EXP },
};

// module_definitions row for the DB-driven /dashboard route (DynamicRoutes
// only renders /dashboard when such a row exists). role_access controls which
// role sees it in the MENU (buildMenu) without affecting the route itself.
function ceoDashboardRow(roleAccess, name = 'Dashboard', group = 'DASHBOARD') {
  return {
    module_code: 'ceo_dashboard', module_name: name, module_group: group,
    menu_icon: '📊', menu_order: 1, minimum_tier_required: 0,
    role_access: roleAccess, is_industry_module: false, required_business_unit: null,
    route_path: '/dashboard', route_component: 'Dashboard', route_group: 'dashboard',
  };
}

// ── Setup helpers ────────────────────────────────────────────────────

async function injectSession(page, session) {
  // mockSupabase answers get_current_user_context with { nrp: null } when no
  // Supabase-auth user exists. initSession treats ANY truthy payload as a
  // valid context, so SessionGuard would see nrp=null and bounce to '/'.
  // Fulfill literal null instead: initSession then falls through to the
  // worker RPC-token path (loadSessionCache) and restores wos_user below.
  await page.route('**/rest/v1/rpc/get_current_user_context*', (route) =>
    route.fulfill({ status: 200, contentType: 'application/json', body: 'null' })
  );
  await page.addInitScript((s) => {
    sessionStorage.setItem('wos_user', JSON.stringify(s));
  }, session);
}

// Override get_enabled_modules. Registered AFTER mockSupabase's generic RPC
// route — Playwright evaluates matching routes last-registered-first, so this
// wins for exactly this RPC while everything else stays mocked.
async function mockModules(page, rows) {
  await page.route('**/rest/v1/rpc/get_enabled_modules*', (route) =>
    route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(rows) })
  );
}

// The drawer panel: the only fixed element spanning all three edges
// top+left+bottom (BottomNav is left+bottom+right; ChatCopilot's panel is
// inset-x-0; the overlay is inset-0).
function drawer(page) {
  return page.locator('div.fixed.top-0.left-0.bottom-0');
}

async function openDrawer(page) {
  const toggle = page.getByRole('button', { name: 'Buka menu navigasi' });
  await expect(toggle).toBeVisible();
  await toggle.click();
  await expect(drawer(page)).toBeVisible();
}

async function drawerContent(page) {
  const titles = (await drawer(page).locator('h4').allInnerTexts()).map((t) => t.trim());
  const links = await drawer(page)
    .locator('a')
    .evaluateAll((els) =>
      els.map((e) => ({
        href: e.getAttribute('href') || '',
        // Label lives in its own span (the first span is the emoji icon).
        text: (e.querySelector('span:last-child')?.innerText || '').trim(),
      }))
    );
  return { titles, links };
}

const labelsOf = (links) => links.map((l) => l.text);
const hrefsOf = (links) => links.map((l) => l.href);

// ── Fallback path (the refactored constants + shared area filter) ────

test.describe('AppDrawer fallback per role/area (empty get_enabled_modules)', () => {
  test('admin_pusat sees the full admin gate menu at /admin', async ({ page }) => {
    await mockSupabase(page);
    await mockModules(page, []);
    await injectSession(page, SESSIONS.admin_pusat);
    await page.goto('/admin');

    await openDrawer(page);
    const { titles, links } = await drawerContent(page);

    expect(titles).toEqual(['MENU ADMIN']);
    for (const t of ['Karyawan', 'Pengajuan', 'Payroll', 'KPI', 'Organisasi', 'Audit Log', 'Pengaturan']) {
      expect(labelsOf(links)).toContain(t);
    }
    expect(links.length).toBeGreaterThanOrEqual(7);
    // Area isolation: no worker/dashboard items leak into the admin drawer.
    expect(hrefsOf(links).every((h) => !h.startsWith('/worker/') && !h.startsWith('/dashboard'))).toBe(true);
  });

  test('admin_hrd gets the HRD fallback (no Payroll)', async ({ page }) => {
    await mockSupabase(page);
    await mockModules(page, []);
    await injectSession(page, SESSIONS.admin_hrd);
    await page.goto('/admin');

    await openDrawer(page);
    const { titles, links } = await drawerContent(page);

    for (const g of ['KELOLA DATA', 'TALENT & PERFORMANCE', 'OPERASIONAL', 'SISTEM']) {
      expect(titles).toContain(g);
    }
    expect(labelsOf(links)).toContain('Karyawan');
    expect(labelsOf(links)).toContain('KPI');
    expect(labelsOf(links)).not.toContain('Payroll');
    expect(hrefsOf(links).every((h) => !h.startsWith('/worker/'))).toBe(true);
  });

  test('admin_finance gets the payroll-centric fallback', async ({ page }) => {
    await mockSupabase(page);
    await mockModules(page, []);
    await injectSession(page, SESSIONS.admin_finance);
    await page.goto('/admin');

    await openDrawer(page);
    const { titles, links } = await drawerContent(page);

    expect(titles).toContain('PAYROLL & KOMPENSASI');
    expect(titles).toContain('SISTEM');
    expect(labelsOf(links)).toContain('Payroll');
    expect(labelsOf(links)).toContain('Budget Allocation');
    expect(hrefsOf(links).every((h) => !h.startsWith('/worker/'))).toBe(true);
  });

  test('worker gets the self-service fallback at /worker', async ({ page }) => {
    await mockSupabase(page);
    await mockModules(page, []);
    await injectSession(page, SESSIONS.worker);
    await page.goto('/worker');

    await openDrawer(page);
    const { titles, links } = await drawerContent(page);

    for (const g of ['AKTIVITAS', 'PENGEMBANGAN DIRI', 'KOMPENSASI']) {
      expect(titles).toContain(g);
    }
    expect(labelsOf(links)).toContain('Kehadiran');
    expect(labelsOf(links)).toContain('Slip Gaji');
    expect(labelsOf(links)).toContain('Profil Saya');
    expect(hrefsOf(links).every((h) => !h.startsWith('/admin/'))).toBe(true);
  });

  test('manager fallback at /dashboard is no longer empty (regression)', async ({ page }) => {
    // /dashboard is DB-driven: DynamicRoutes needs a ceo_dashboard row to
    // render the page at all, but role_access EXCLUDES manager so buildMenu
    // yields an empty menu → the FALLBACK groups render. This is the exact
    // scenario that produced an empty drawer before the refactor (items were
    // exact '/dashboard' and the old area filter stripped them).
    await mockSupabase(page);
    await mockModules(page, [ceoDashboardRow(['admin_pusat', 'admin_hrd'])]);
    await injectSession(page, SESSIONS.manager);
    await page.goto('/dashboard');

    await openDrawer(page);
    const { titles, links } = await drawerContent(page);

    expect(titles).toContain('DASHBOARD');
    for (const t of ['Beranda', 'Tim Saya', 'Flight Risk', 'Exec Summary']) {
      expect(labelsOf(links)).toContain(t);
    }
    expect(links.length).toBeGreaterThanOrEqual(6);
    // Exact-path consistency: fallback items point at bare '/dashboard' and
    // must survive the area filter.
    expect(hrefsOf(links)).toContain('/dashboard');
    expect(hrefsOf(links).every((h) => !h.startsWith('/admin/') && !h.startsWith('/worker/'))).toBe(true);
  });
});

// ── Dynamic path (module_definitions rows through buildMenu) ─────────

test.describe('AppDrawer dynamic menu (get_enabled_modules rows)', () => {
  test('worker sees dynamic groups instead of fallback constants', async ({ page }) => {
    await mockSupabase(page);
    await mockModules(page, [
      {
        module_code: 'attendance', module_name: 'Modul Dinamis A', module_group: 'MENU DINAMIS E2E',
        menu_icon: '🧪', menu_order: 1, minimum_tier_required: 0, role_access: ['worker'],
        is_industry_module: false, required_business_unit: null,
        route_path: '/worker/attendance', route_component: 'WorkerAttendance', route_group: 'worker',
      },
    ]);
    await injectSession(page, SESSIONS.worker);
    await page.goto('/worker/attendance');

    await openDrawer(page);
    await expect(drawer(page).locator('h4', { hasText: 'MENU DINAMIS E2E' })).toBeVisible();
    const { titles, links } = await drawerContent(page);

    expect(titles).toContain('MENU DINAMIS E2E');
    expect(titles).not.toContain('AKTIVITAS'); // fallback replaced by dynamic menu
    expect(labelsOf(links)).toContain('Modul Dinamis A');
    expect(hrefsOf(links)).toContain('/worker/attendance');
  });

  test('manager sees a dynamic dashboard module when role has access', async ({ page }) => {
    await mockSupabase(page);
    await mockModules(page, [ceoDashboardRow(['manager'], 'Dashboard Eksekutif', 'MENU DINAMIS E2E')]);
    await injectSession(page, SESSIONS.manager);
    await page.goto('/dashboard');

    await openDrawer(page);
    // Strict-mode-safe: the drawer panel is the only h4 container in a
    // fixed top+left+bottom element (BottomNav also matches left+bottom).
    const heading = drawer(page).locator('h4', { hasText: 'MENU DINAMIS E2E' });
    await expect(heading).toBeVisible();
    const { titles, links } = await drawerContent(page);

    expect(titles).not.toContain('DASHBOARD'); // fallback replaced by dynamic menu
    expect(labelsOf(links)).toContain('Dashboard Eksekutif');
    expect(hrefsOf(links)).toContain('/dashboard');
  });
});

// ── Area mounting ────────────────────────────────────────────────────

test.describe('AppDrawer area mounting', () => {
  test('owner area mounts no drawer navigation (by design)', async ({ page }) => {
    await mockSupabase(page);
    await page.goto('/owner');
    await expect(page.getByRole('button', { name: 'Buka menu navigasi' })).toHaveCount(0);
  });
});
