/**
 * full-sweep.spec.js — Comprehensive login + route sweep for all roles.
 *
 * Tests every login tab (Worker, Admin, Dashboard/Owner) and sweeps
 * all routes after each successful login. Reports errors per route.
 *
 * Run: TEST_BASE_URL=https://insightwos-dp7cr9wl7-cezetex-lab.vercel.app npx playwright test tests/e2e/full-sweep.spec.js
 */
import { test, expect } from '@playwright/test';

const BASE = process.env.TEST_BASE_URL || 'http://localhost:5173';

// Credentials from live DB verification
const WORKER = { nrp: 'NRP002', nik: '3204000000000002', pass: '3204000000000002' };
const ADMIN = { email: 'pusat@insightwos.com', pass: 'Admin123!' };
const DASHBOARD = { nrp: 'NRP001', pass: 'CEO123!' };

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

async function acceptConsent(page) {
  // L-4: dialog renders async — poll instead of instant count() check
  const consent = page.locator('div[role="dialog"] button:has-text("Saya Setuju")');
  try {
    await consent.first().waitFor({ state: 'visible', timeout: 8000 });
    await consent.first().click();
    await page.waitForTimeout(500);
  } catch { /* no consent dialog — continue */ }
}

async function checkToken(page) {
  return page.evaluate(() => {
    try { return !!JSON.parse(sessionStorage.getItem('wos_user')); } catch { return false; }
  });
}

// L-4: poll for login completion instead of fixed wait (edge fallback can take >5s)
async function waitForLogin(page, pathPrefix, timeoutMs = 30000) {
  await page.waitForFunction(
    (prefix) => {
      try {
        const hasToken = !!JSON.parse(sessionStorage.getItem('wos_user'));
        const onPath = window.location.pathname.startsWith(prefix);
        return hasToken && onPath;
      } catch { return false; }
    },
    pathPrefix,
    { timeout: timeoutMs, polling: 500 }
  ).catch(() => {});
  await page.waitForTimeout(300); // settle
}

async function sweepRoutes(page, routes, role, errors) {
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
}


test.describe('Full Production Sweep', () => {

  test('Worker: login + route sweep', async ({ page }) => {
    const errors = [];
    await page.goto(BASE + '/', { waitUntil: 'domcontentloaded', timeout: 60000 });
    await page.waitForTimeout(1000);
    await acceptConsent(page);
    await page.locator('button', { hasText: 'Pekerja' }).click();
    await page.fill('input[placeholder*="NRP"]', WORKER.nrp);
    await page.fill('input[placeholder*="NIK"]', WORKER.nik);
    await page.fill('input[placeholder*="password"]', WORKER.pass);
    await page.click('button[type="submit"]');
    await waitForLogin(page, '/worker');
    const url = page.url();
    const hasToken = await checkToken(page);
    console.log('Worker login: url=' + url + ', token=' + hasToken);
    if (!hasToken && !url.includes('/worker')) {
      errors.push({ role: 'worker', route: '/', type: 'login-failed', msg: 'url=' + url });
    } else {
      await sweepRoutes(page, ROUTES.worker, 'worker', errors);
    }
    console.log('\n=== WORKER ERRORS (' + errors.length + ') ===');
    if (errors.length) console.log(JSON.stringify(errors, null, 2));
    else console.log('PASS No errors');
    await page.goto(BASE + '/', { waitUntil: 'domcontentloaded', timeout: 10000 }).catch(() => {});
  });

  test('Admin: login + route sweep', async ({ page }) => {
    const errors = [];
    await page.goto(BASE + '/', { waitUntil: 'domcontentloaded', timeout: 60000 });
    await page.waitForTimeout(1000);
    await acceptConsent(page);
    await page.locator('button', { hasText: 'Admin' }).click();
    await page.waitForTimeout(500);
    const emailSel = await page.locator('input[type="email"]').count()
      ? 'input[type="email"]' : 'input[placeholder*="email" i]';
    await page.fill(emailSel, ADMIN.email);
    await page.fill('input[placeholder*="password"]', ADMIN.pass);
    await page.click('button[type="submit"]');
    await waitForLogin(page, '/admin');
    const url = page.url();
    const hasToken = await checkToken(page);
    console.log('Admin login: url=' + url + ', token=' + hasToken);
    if (!hasToken && !url.includes('/admin')) {
      errors.push({ role: 'admin', route: '/', type: 'login-failed', msg: 'url=' + url });
    } else {
      await sweepRoutes(page, ROUTES.admin, 'admin', errors);
    }
    console.log('\n=== ADMIN ERRORS (' + errors.length + ') ===');
    if (errors.length) console.log(JSON.stringify(errors, null, 2));
    else console.log('PASS No errors');
    await page.goto(BASE + '/', { waitUntil: 'domcontentloaded', timeout: 10000 }).catch(() => {});
  });

  test('Dashboard/Owner: login + route sweep', async ({ page }) => {
    const errors = [];
    await page.goto(BASE + '/', { waitUntil: 'domcontentloaded', timeout: 60000 });
    await page.waitForTimeout(1000);
    await acceptConsent(page);
    await page.locator('button', { hasText: 'Dashboard' }).click();
    await page.waitForTimeout(500);
    await page.fill('input[placeholder*="NRP"]', DASHBOARD.nrp);
    await page.fill('input[placeholder*="password"]', DASHBOARD.pass);
    await page.click('button[type="submit"]');
    await waitForLogin(page, '/dashboard');
    const url = page.url();
    const hasToken = await checkToken(page);
    console.log('Dashboard login: url=' + url + ', token=' + hasToken);
    if (!hasToken && !url.includes('/dashboard')) {
      errors.push({ role: 'dashboard', route: '/', type: 'login-failed', msg: 'url=' + url });
    } else {
      await sweepRoutes(page, ROUTES.dashboard, 'dashboard', errors);
    }
    console.log('\n=== DASHBOARD ERRORS (' + errors.length + ') ===');
    if (errors.length) console.log(JSON.stringify(errors, null, 2));
    else console.log('PASS No errors');
    await page.goto(BASE + '/', { waitUntil: 'domcontentloaded', timeout: 10000 }).catch(() => {});
  });

});
