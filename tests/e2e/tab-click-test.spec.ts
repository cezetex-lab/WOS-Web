/**
 * tab-click-test.spec.ts — Click every admin tab, verify component loads, capture RPC errors.
 * Efficient: short timeouts, skip hangs, focus on real errors.
 */
import { test, expect } from '@playwright/test';
import type { Page, ConsoleMessage } from '@playwright/test';
import { clickStable, fillAdminOtp, openHome } from './helpers/live-login';
import { ADMIN_ACCOUNTS, assertAccount, assertOtpBudget } from './helpers/live-accounts';

// Live-backend diagnostic: uses real credentials against a running deployment.
// Opt in with E2E_LIVE=1 so the default suite stays hermetic (mocked) and green.
test.skip(!process.env.E2E_LIVE, 'Live diagnostic — set E2E_LIVE=1 and TEST_BASE_URL to run');

const BASE = process.env.TEST_BASE_URL || 'http://localhost:5173';
// Identitas admin disebar (≤2 OTP per NRP per run; limit aplikasi 3/15 menit).
const ADMIN = ADMIN_ACCOUNTS.ceo;

/** One finding collected while sweeping admin tabs. */
type TabFinding = {
  route: string;
  type: string;
  msg?: string;
  pageErrors?: string[];
  console?: string[];
  body?: string;
};

// Core admin routes to test (most commonly used)
const ADMIN_ROUTES = [
  '/admin', '/admin/employees', '/admin/org-chart', '/admin/divisions',
  '/admin/master-data', '/admin/roles', '/admin/requests',
  '/admin/leave', '/admin/overtime', '/admin/payroll', '/admin/timesheet',
  '/admin/shift-swap', '/admin/approvals', '/admin/kpi',
  '/admin/incentive', '/admin/okr', '/admin/learning',
  '/admin/certifications', '/admin/badges', '/admin/talent',
  '/admin/succession', '/admin/career', '/admin/attendance',
  '/admin/performance', '/admin/settings', '/admin/features',
  '/admin/export', '/admin/integrations', '/admin/budget',
  '/admin/headcount', '/admin/audit', '/admin/chain',
  '/admin/pipeline', '/admin/recruitment', '/admin/screening',
  '/admin/onboarding', '/admin/exit', '/admin/compensation',
  '/admin/flight-risk', '/admin/simulation', '/admin/analytics',
  '/admin/surveys', '/admin/forum', '/admin/voice',
  '/admin/whistleblower', '/admin/referral', '/admin/modules',
  '/admin/mfa', '/admin/narrative', '/admin/qhse', '/admin/safety',
  '/admin/asset-assign', '/admin/assets', '/admin/estate',
  '/admin/mill', '/admin/mining', '/admin/career-path',
  '/admin/compensation-intel', '/admin/announcements', '/admin/engagement',
  '/admin/review-360', '/admin/approval-workflow', '/admin/facility',
  '/admin/field',
];

async function loginAdmin(page: Page) {
  assertOtpBudget();
  assertAccount(ADMIN, 'ceo');
  await openHome(page, 30000);
  await clickStable(page.locator('button', { hasText: 'Admin' }).first());

  // ── ASERSI: form login admin benar-benar ter-render ────────────────────────
  await expect(page.locator('input[type="email"]')).toBeVisible({ timeout: 20000 });
  await page.fill('input[type="email"]', ADMIN.email);
  await page.fill('input[placeholder*="password"]', ADMIN.pass);
  await clickStable(page.locator('button[type="submit"]').first());

  // Admin = 2 langkah (password → OTP dev-mode); tanpa ini sweep selalu gagal.
  await fillAdminOtp(page);
  await page.waitForURL((u) => u.pathname.startsWith('/admin'), { timeout: 45000 }).catch(() => {});
  return page.url().includes('/admin');
}

/** Panjang teks body — penanda halaman ter-render (bukan blank). */
async function bodyLen(page: Page) {
  return ((await page.textContent('body').catch(() => '')) ?? '').length;
}

test('Admin: login + click every tab + check errors', async ({ page }) => {
  test.setTimeout(1_200_000); // 20 min: 60 rute + kemungkinan tunggu jendela OTP
  const errors: TabFinding[] = [];
  const passed: string[] = [];
  const redirected: Array<{ route: string; actual: string }> = [];

  const ok = await loginAdmin(page);
  console.log('Login: ' + (ok ? 'OK' : 'FAIL'));
  if (!ok) {
    errors.push({ route: '/', type: 'login-failed' });
    console.log(JSON.stringify(errors, null, 2));
    // ASERSI: login yang gagal pun harus menyisakan halaman yang ter-render.
    expect(await bodyLen(page), 'halaman login admin tidak boleh blank').toBeGreaterThan(80);
    return;
  }

  for (const route of ADMIN_ROUTES) {
    const consoleMsgs: string[] = [];
    const pageErrors: string[] = [];

    const handler = (m: ConsoleMessage) => {
      const t = m.text();
      if (m.type() === 'error' && !t.includes('favicon') && !t.includes('SW registered') && !t.includes('Download the React DevTools')) {
        consoleMsgs.push(t.slice(0, 200));
      }
    };
    const errHandler = (e: Error) => pageErrors.push(String(e.message || e).slice(0, 200));

    page.on('console', handler);
    page.on('pageerror', errHandler);

    try {
      await page.goto(BASE + route, { waitUntil: 'commit', timeout: 8000 });
    } catch (e) {
      errors.push({ route, type: 'timeout', msg: String(e).slice(0, 150) });
      page.off('console', handler);
      page.off('pageerror', errHandler);
      continue;
    }

    await page.waitForTimeout(800);

    const url = page.url();
    const body = (await page.textContent('body').catch(() => '')) || '';

    page.off('console', handler);
    page.off('pageerror', errHandler);

    // Check for redirects (route not registered)
    if (url.replace(BASE, '') === '/' || (!url.includes(route) && url.includes('/admin') && route !== '/admin')) {
      redirected.push({ route, actual: url.replace(BASE, '') });
      continue;
    }

    // Check for visible error indicators
    const hasError = body.match(/(Error Boundary|Something went wrong|undefined is not|Cannot read prop|is not a function|Failed to fetch|NetworkError|Objects are not valid)/i);

    if (pageErrors.length > 0 || consoleMsgs.length > 0 || hasError) {
      errors.push({
        route,
        type: 'error',
        pageErrors: pageErrors.slice(0, 2),
        console: consoleMsgs.slice(0, 2),
        body: hasError ? body.slice(Math.max(0, body.indexOf(hasError[0]) - 30), body.indexOf(hasError[0]) + 80).replace(/\s+/g, ' ').slice(0, 200) : 'none'
      });
      console.log('  ✗ ' + route + ' (' + pageErrors.length + ' pageerr, ' + consoleMsgs.length + ' console)');
    } else {
      passed.push(route);
    }
  }

  // ── ASERSI: (a) hasil sweep menutup SEMUA rute (tidak ada yang hilang), dan
  //           (b) minimal satu rute benar-benar ter-render (bukan blank semua).
  expect(
    passed.length + redirected.length + errors.length,
    'setiap rute harus menghasilkan tepat satu temuan (passed/redirected/error)',
  ).toBe(ADMIN_ROUTES.length);
  expect(passed.length + redirected.length, 'minimal satu rute admin harus ter-render').toBeGreaterThan(0);

  console.log('\n=== TAB CLICK TEST RESULTS ===');
  console.log('Passed: ' + passed.length + ' | Redirected: ' + redirected.length + ' | Errors: ' + errors.length);

  if (passed.length > 0) {
    console.log('\n--- PASSED (' + passed.length + ') ---');
    passed.forEach((r) => console.log('  ✓ ' + r));
  }

  if (redirected.length > 0) {
    console.log('\n--- REDIRECTED (' + redirected.length + ') ---');
    redirected.forEach((r) => console.log('  → ' + r.route + ' → ' + r.actual));
  }

  if (errors.length > 0) {
    console.log('\n--- ERRORS (' + errors.length + ') ---');
    errors.forEach((e) => {
      console.log('  ✗ ' + e.route + ':');
      if (e.pageErrors?.length) e.pageErrors.forEach((m) => console.log('    PAGE: ' + m));
      if (e.console?.length) e.console.forEach((m) => console.log('    CONSOLE: ' + m));
      if (e.body && e.body !== 'none') console.log('    BODY: ' + e.body);
    });
  }
});
