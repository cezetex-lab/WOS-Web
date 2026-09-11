/**
 * tab-click-test.spec.js — Click every admin tab, verify component loads, capture RPC errors.
 * Efficient: short timeouts, skip hangs, focus on real errors.
 */
import { test, expect } from '@playwright/test';

const BASE = process.env.TEST_BASE_URL || 'http://localhost:5173';
const ADMIN = { email: 'pusat@insightwos.com', pass: 'Admin123!' };

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

async function loginAdmin(page) {
  await page.goto(BASE + '/', { waitUntil: 'domcontentloaded', timeout: 15000 });
  await page.waitForTimeout(1000);
  const consent = page.locator('button:has-text("Saya Setuju")');
  if (await consent.count()) {
    try { await consent.first().click({ timeout: 3000 }); } catch { /* overlay may block, continue */ }
  }
  await page.waitForTimeout(300);
  await page.locator('button', { hasText: 'Admin' }).click({ timeout: 8000 });
  await page.waitForTimeout(300);
  await page.fill('input[type="email"]', ADMIN.email);
  await page.fill('input[placeholder*="password"]', ADMIN.pass);
  await page.click('button[type="submit"]');
  await page.waitForTimeout(5000);
  return page.url().includes('/admin');
}

test('Admin: login + click every tab + check errors', async ({ page }) => {
  test.setTimeout(600000); // 10 min for 60 routes
  const errors = [];
  const passed = [];
  const redirected = [];

  const ok = await loginAdmin(page);
  console.log('Login: ' + (ok ? 'OK' : 'FAIL'));
  if (!ok) {
    errors.push({ route: '/', type: 'login-failed' });
    console.log(JSON.stringify(errors, null, 2));
    return;
  }

  for (const route of ADMIN_ROUTES) {
    const consoleMsgs = [];
    const pageErrors = [];

    const handler = (m) => {
      const t = m.text();
      if (m.type() === 'error' && !t.includes('favicon') && !t.includes('SW registered') && !t.includes('Download the React DevTools')) {
        consoleMsgs.push(t.slice(0, 200));
      }
    };
    const errHandler = (e) => pageErrors.push(String(e.message || e).slice(0, 200));

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
