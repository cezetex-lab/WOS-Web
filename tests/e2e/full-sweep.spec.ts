/**
 * full-sweep.spec.ts — Comprehensive login + route sweep for all roles.
 *
 * Tests every login tab (Worker, Admin, Dashboard/Owner) and sweeps
 * all routes after each successful login. Reports errors per route.
 *
 * Opt-in: `E2E_LIVE=1` (kredensial dari env/.env.local — TIDAK pernah dicetak).
 *
 * Asersi nyata (2026-09-24): tiap test membuktikan (a) form login ter-render,
 * (b) submit memanggil RPC login, (c) setelah login minimal SATU rute ter-render,
 * (d) halaman tidak blank. Sebelumnya spec ini hanya `console.log` (vacuous).
 */
import { test, expect } from '@playwright/test';
import type { Page } from '@playwright/test';
import { clickStable, fillAdminOtp, fillStable, openHome } from './helpers/live-login';
import { ADMIN_ACCOUNTS, assertAccount, assertOtpBudget } from './helpers/live-accounts';

// Live-backend diagnostic: uses real credentials against a running deployment.
// Opt in with E2E_LIVE=1 so the default suite stays hermetic (mocked) and green.
test.skip(!process.env.E2E_LIVE, 'Live diagnostic — set E2E_LIVE=1 and TEST_BASE_URL to run');

const BASE = process.env.TEST_BASE_URL || 'http://localhost:5173';

/** One route-sweep finding (mirrors the shape pushed by sweepRoutes). */
type SweepError = { role: string; route: string; type: string; msg: string };

// Kredensial: env dulu, fallback literal untuk akun diagnostik lama.
// Identitas worker KHUSUS full-sweep (E2E_WORKER_SWEEP_*, di-seed dari akun.txt).
// Nilai TIDAK punya fallback literal (tidak ada password di repo). Sebelumnya memakai
// E2E_WORKER_* (NRP008) yang dipakai 5 konsumen → login paralel beradu (temuan RUN 2).
const WORKER = {
  nrp: process.env.E2E_WORKER_SWEEP_NRP ?? '',
  nik: process.env.E2E_WORKER_SWEEP_NIK ?? '',
  pass: process.env.E2E_WORKER_SWEEP_PASS ?? '',
};
// Identitas admin DISEBAR supaya tiap NRP ≤2 OTP per run (limit aplikasi: 3/15 menit
// per NRP) — kontrak di helpers/live-accounts.ts (OTP_ASSIGNMENT).
// RUN 1: Dashboard memakai `hrd` yang juga dipakai diag-login + four-page → kuota
// habis → `otp_edge` tanpa `verify`. Sekarang Dashboard pakai `pusat` (admin_pusat,
// termasuk allowedRoles /dashboard di App.tsx:66).
const ADMIN = ADMIN_ACCOUNTS.operasional;
const DASHBOARD = ADMIN_ACCOUNTS.pusat;

const ROUTES = {
  worker: [
    '/worker', '/worker/profile', '/worker/attendance', '/worker/leave',
    '/worker/overtime', '/worker/payroll', '/worker/kpi', '/worker/activities',
    '/worker/tasks', '/worker/learning', '/worker/career', '/worker/review-360',
  ],
  admin: [
    '/admin', '/admin/employees', '/admin/org-chart', '/admin/divisions',
    '/admin/master-data', '/admin/role-matrix', '/admin/requests',
    '/admin/leave', '/admin/overtime', '/admin/payroll', '/admin/timesheet',
    '/admin/shift-schedule', '/admin/approval-center', '/admin/kpi',
    '/admin/incentive', '/admin/okrs', '/admin/learning',
    '/admin/certifications', '/admin/badges', '/admin/talent-market',
    '/admin/career-path', '/admin/succession', '/admin/career-dev',
    '/admin/attendance', '/admin/performance-trend', '/admin/settings',
    '/admin/feature-flants', '/admin/export', '/admin/integrations',
    '/admin/budget', '/admin/headcount', '/admin/audit-log',
    '/admin/audit-chain', '/admin/pipeline', '/admin/recruitment',
    '/admin/screening', '/admin/onboarding', '/admin/offboarding',
    '/admin/compensation-intel', '/admin/turnover', '/admin/simulation',
    '/admin/analytics',
  ],
  dashboard: [
    '/dashboard',
  ],
};

async function checkToken(page: Page) {
  return page.evaluate(() => {
    try { return !!JSON.parse(sessionStorage.getItem('wos_user_v2') || 'null'); } catch { return false; }
  });
}

/** Jumlah karakter body — penanda halaman benar-benar ter-render (bukan blank). */
async function bodyLen(page: Page) {
  return ((await page.textContent('body').catch(() => '')) ?? '').length;
}

// L-4: poll for login completion instead of fixed wait (edge fallback can take >5s)
async function waitForLogin(page: Page, pathPrefix: string, timeoutMs = 30000) {
  await page.waitForFunction(
    (prefix) => {
      try {
        const hasToken = !!JSON.parse(sessionStorage.getItem('wos_user_v2') || 'null');
        const onPath = window.location.pathname.startsWith(prefix);
        return hasToken && onPath;
      } catch { return false; }
    },
    pathPrefix,
    { timeout: timeoutMs, polling: 500 }
  ).catch(() => {});
  await page.waitForTimeout(300); // settle
}

/** Sweep rute; mengembalikan JUMLAH rute yang benar-benar ter-render. */
async function sweepRoutes(page: Page, routes: string[], role: string, errors: SweepError[]): Promise<number> {
  let rendered = 0;
  for (const r of routes) {
    const before = errors.length;
    try {
      await page.goto(BASE + r, { waitUntil: 'networkidle', timeout: 20000 });
    } catch (e) {
      errors.push({ role, route: r, type: 'navigate', msg: String(e).slice(0, 300) });
      continue;
    }
    await page.waitForTimeout(1200);
    const body = (await page.textContent('body').catch(() => '')) || '';
    if (body.trim().length > 0) rendered += 1;
    const errMatch = body.match(/(Error|error message|gagal|failed|exception|crash|tidak ditemukan|not found|undefined is not|Cannot read)/i);
    if (errMatch) {
      const idx = body.indexOf(errMatch[0]);
      const snippet = body.slice(Math.max(0, idx - 80), idx + 120);
      errors.push({ role, route: r, type: 'UI-error', msg: snippet.replace(/\s+/g, ' ').slice(0, 300) });
    }
    const url = page.url();
    if (!url.includes(r) && url.replace(BASE, '') === '/') {
      errors.push({ role, route: r, type: 'redirect-to-root', msg: `at ${url}` });
    }
    if (errors.length > before) console.log(`  [!] ${role} ${r}: +${errors.length - before} error(s)`);
  }
  return rendered;
}

test.describe('Full Production Sweep', () => {

  test.beforeAll(() => {
    assertOtpBudget(); // gagal cepat bila dua spec berbagi identitas OTP
  });

  test('Worker: login + route sweep', async ({ page }) => {
    const errors: SweepError[] = [];
    const rpc: string[] = [];
    page.on('response', (r) => { if (r.url().includes('/rpc/login_worker')) rpc.push(String(r.status())); });

    await openHome(page, 60000);
    await clickStable(page.locator('button', { hasText: 'Pekerja' }).first());

    // Tab Pekerja default = mode EMAIL; field NRP muncul setelah toggle ini.
    await expect(page.locator('input[placeholder*="email"]')).toBeVisible({ timeout: 20000 });
    await clickStable(page.getByText('Masuk dengan NRP').first());

    // ASERSI: form NRP ter-render
    await expect(page.locator('input[placeholder*="NRP"]')).toBeVisible({ timeout: 20000 });

    // fillStable: re-render bisa menyapu nilai form setelah `fill()` (temuan RUN 2).
    await fillStable(page.locator('input[placeholder*="NRP"]'), WORKER.nrp);
    await fillStable(page.locator('input[placeholder*="NIK"]'), WORKER.nik);
    await fillStable(page.locator('input[placeholder*="password"]'), WORKER.pass);
    await clickStable(page.locator('button[type="submit"]').first());
    await waitForLogin(page, '/worker');

    const url = page.url();
    const hasToken = await checkToken(page);
    console.log('Worker login: url=' + url + ', token=' + hasToken);
    expect(rpc.length, 'submit worker harus memanggil RPC login_worker').toBeGreaterThan(0);

    let rendered = 0;
    if (!hasToken && !url.includes('/worker')) {
      errors.push({ role: 'worker', route: '/', type: 'login-failed', msg: 'url=' + url });
      expect(await bodyLen(page), 'halaman login tidak boleh blank').toBeGreaterThan(80);
    } else {
      rendered = await sweepRoutes(page, ROUTES.worker, 'worker', errors);
      expect(rendered, 'login worker harus me-render ≥1 rute').toBeGreaterThan(0);
    }

    console.log('\n=== WORKER ERRORS (' + errors.length + ') ===');
    if (errors.length) console.log(JSON.stringify(errors, null, 2));
    else console.log('PASS No errors');
    // ASERSI: login gagal ⇔ tepat 1 finding login-failed (konsistensi diagnostik)
    expect(errors.filter((e) => e.type === 'login-failed')).toHaveLength(hasToken ? 0 : 1);
    await page.goto(BASE + '/', { waitUntil: 'domcontentloaded', timeout: 10000 }).catch(() => {});
  });

  test('Admin: login + route sweep', async ({ page }) => {
    // OTP bisa menunggu jendela rate-limit (2 x 6 menit) + sweep 42 rute.
    test.setTimeout(20 * 60_000);
    assertAccount(ADMIN, 'operasional');
    const errors: SweepError[] = [];
    const rpc: string[] = [];
    page.on('response', (r) => {
      // OTP admin dibuat lewat EDGE password-reset (bukan RPC generate_admin_otp).
      if (r.url().includes('/functions/v1/password-reset')) rpc.push('otp_edge');
      if (r.url().includes('/rpc/verify_admin_otp')) rpc.push('verify');
    });

    await openHome(page, 60000);
    await clickStable(page.locator('button', { hasText: 'Admin' }).first());
    await expect(page.locator('input[type="email"]')).toBeVisible({ timeout: 20000 });

    await page.locator('input[type="email"]').fill(ADMIN.email);
    await page.locator('input[placeholder*="password"]').first().fill(ADMIN.pass);
    await clickStable(page.locator('button[type="submit"]').first());

    // Admin = 2 langkah (password → OTP dev-mode). Tanpa langkah ini sweep admin
    // selalu berhenti di halaman OTP (temuan 2026-09-24).
    const otpWaits = await fillAdminOtp(page);
    await waitForLogin(page, '/admin');

    const url = page.url();
    const hasToken = await checkToken(page);
    console.log('Admin login: url=' + url + ', token=' + hasToken + ', otpWaits=' + otpWaits);
    expect(rpc, 'alur admin harus membuat OTP (edge) + verify_admin_otp').toContain('otp_edge');
    expect(rpc).toContain('verify');

    let rendered = 0;
    if (!hasToken && !url.includes('/admin')) {
      errors.push({ role: 'admin', route: '/', type: 'login-failed', msg: 'url=' + url });
      expect(await bodyLen(page), 'halaman login tidak boleh blank').toBeGreaterThan(80);
    } else {
      rendered = await sweepRoutes(page, ROUTES.admin, 'admin', errors);
      expect(rendered, 'login admin harus me-render ≥1 rute').toBeGreaterThan(0);
    }

    console.log('\n=== ADMIN ERRORS (' + errors.length + ') ===');
    if (errors.length) console.log(JSON.stringify(errors, null, 2));
    else console.log('PASS No errors');
    expect(errors.filter((e) => e.type === 'login-failed')).toHaveLength(hasToken ? 0 : 1);
    await page.goto(BASE + '/', { waitUntil: 'domcontentloaded', timeout: 10000 }).catch(() => {});
  });

  test('Dashboard/Owner: login + route sweep', async ({ page }) => {
    test.setTimeout(20 * 60_000);
    assertAccount(DASHBOARD, 'pusat');
    const errors: SweepError[] = [];
    const rpc: string[] = [];
    // Tab Dashboard TIDAK memverifikasi OTP lewat RPC `verify_admin_otp`
    // (itu jalur tab Admin, Home.tsx:404). Tab Dashboard memakai EDGE
    // `password-reset` untuk kirim (login_otp) DAN verifikasi (verify_login_otp)
    // — Home.tsx:425-428. Jadi yang diamati adalah aksi di body request, bukan
    // nama RPC. (Asersi lama `toContain('verify')` salah menurut konstruksi —
    // itulah penyebab kegagalan RUN 2, bukan rate limit.)
    page.on('request', (r) => {
      if (!r.url().includes('/functions/v1/password-reset')) return;
      const body = r.postData() ?? '';
      if (body.includes('verify_login_otp')) rpc.push('otp_verify');
      else if (body.includes('login_otp')) rpc.push('otp_send');
    });

    await openHome(page, 60000);
    await clickStable(page.locator('button', { hasText: 'Dashboard' }).first());

    // Tab Dashboard = mode EMAIL + OTP (sama seperti four-page-smoke yang hijau).
    await expect(page.locator('input[type="email"]')).toBeVisible({ timeout: 20000 });
    await page.locator('input[type="email"]').fill(DASHBOARD.email);
    await page.locator('input[placeholder*="password"]').first().fill(DASHBOARD.pass);
    await clickStable(page.locator('button[type="submit"]').first());
    const otpWaits = await fillAdminOtp(page);
    await waitForLogin(page, '/dashboard');

    const url = page.url();
    const hasToken = await checkToken(page);
    console.log(
      'Dashboard login: url=' + url + ', token=' + hasToken + ', otpWaits=' + otpWaits + ', rpc=' + rpc.join('/'),
    );
    expect(rpc, 'alur dashboard harus mengirim OTP via edge').toContain('otp_send');
    expect(rpc, 'alur dashboard harus memverifikasi OTP via edge verify_login_otp').toContain('otp_verify');

    let rendered = 0;
    if (!hasToken && !url.includes('/dashboard')) {
      errors.push({ role: 'dashboard', route: '/', type: 'login-failed', msg: 'url=' + url });
      expect(await bodyLen(page), 'halaman login tidak boleh blank').toBeGreaterThan(80);
    } else {
      rendered = await sweepRoutes(page, ROUTES.dashboard, 'dashboard', errors);
      expect(rendered, 'login dashboard harus me-render ≥1 rute').toBeGreaterThan(0);
    }

    console.log('\n=== DASHBOARD ERRORS (' + errors.length + ') ===');
    if (errors.length) console.log(JSON.stringify(errors, null, 2));
    else console.log('PASS No errors');
    expect(errors.filter((e) => e.type === 'login-failed')).toHaveLength(hasToken ? 0 : 1);
    await page.goto(BASE + '/', { waitUntil: 'domcontentloaded', timeout: 10000 }).catch(() => {});
  });

});
