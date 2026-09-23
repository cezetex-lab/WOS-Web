/**
 * accessibility-full-sweep.spec.ts — STAGE C LANGKAH 2: sweep 154 route module_definitions + 4 shell.
 *
 * Sumber route: .agents/logs/sweep-routes.json (dump DB live 2026-09-22:
 * worker=52, admin=102). Shell statis: / (login, no-auth), /worker, /admin,
 * /dashboard, /owner/dashboard, /owner/dashboard/config.
 * Auth: storageState 1x per role (.agents/logs/auth-{worker,admin,owner,admin-mill}.json)
 * — prinsip OPS-08, tanpa OTP ulang. /admin/mill memakai state admin-mill (NRP105,
 * role admin_mill — OPS-10; akun admin lain di-redirect oleh useAdminAuth).
 * Aturan: HANYA laporkan violation. Timeout per test 20s (spesifikasi Stage C).
 */
import { test, expect } from '@playwright/test';
import type { Page } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { scanA11y, seriousViolations, summarize, attachAxeReport, settle } from '../a11y/helpers/axe-config';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const BASE = process.env.TEST_BASE_URL || 'http://localhost:5173';

interface RouteRow { route_group: string; route_path: string; module_code: string }
const ROUTES: RouteRow[] = JSON.parse(
  fs.readFileSync(path.join(ROOT, '.agents', 'logs', 'sweep-routes.json'), 'utf8'),
);

const AUTH = {
  worker: path.join(ROOT, '.agents', 'logs', 'auth-worker.json'),
  admin: path.join(ROOT, '.agents', 'logs', 'auth-admin.json'),
  owner: path.join(ROOT, '.agents', 'logs', 'auth-owner.json'),
  'admin-mill': path.join(ROOT, '.agents', 'logs', 'auth-admin-mill.json'), // OPS-10
};
for (const [k, p] of Object.entries(AUTH)) {
  if (!fs.existsSync(p)) throw new Error(`storageState ${k} hilang: ${p} — jalankan LANGKAH 1 dulu`);
}

// Area mapping: route_group worker→worker, admin→admin; shell khusus per area.
const SHELL: { path: string; area: 'worker' | 'admin' | 'dashboard' | 'owner' }[] = [
  { path: '/worker', area: 'worker' },
  { path: '/admin', area: 'admin' },
  { path: '/dashboard', area: 'admin' }, // dashboard login = kredensial admin (suite hijau Stage 1)
  { path: '/owner/dashboard', area: 'owner' },
  { path: '/owner/dashboard/config', area: 'owner' },
];

// Dedup: DB live punya 2 duplikat route_path (/admin/mfa, /admin/voice) + shell
// yang overlap dengan route DB — Playwright menolak judul test ganda.
function dedup(paths: string[]): string[] {
  return [...new Set(paths)];
}

const byArea = {
  worker: dedup(ROUTES.filter((r) => r.route_group === 'worker').map((r) => r.route_path)),
  admin: dedup(ROUTES.filter((r) => r.route_group === 'admin').map((r) => r.route_path)),
};

async function scanRoute(page: Page, testInfo: { attach: (name: string, options: { body: string | Buffer; contentType: string }) => Promise<void> }, label: string, route: string) {
  await page.goto(BASE + route);
  await settle(page);
  // Halaman benar-benar render: bukan blank — minimal 1 heading ATAU main content ATAU teks > 50 char.
  const rendered = await page.evaluate(() => {
    const h = document.querySelector('h1,h2,h3,[role="heading"]');
    const main = document.querySelector('main,#root');
    const textLen = (document.body?.innerText ?? '').trim().length;
    return { hasHeading: !!h, bodyLen: textLen, hasMain: !!main };
  });
  const isBlank = !rendered.hasHeading && rendered.bodyLen < 50;
  const results = await scanA11y(page);
  const serious = seriousViolations(results);
  if (!isBlank && serious.length > 0) {
    console.log(`[${label}] VIOLATION ${route}:\n  ${summarize(results)}`);
    await attachAxeReport(page, testInfo, `${label}-${route.replace(/\//g, '_')}`, serious);
  } else if (!isBlank) {
    console.log(`[${label}] OK ${route} — 0 critical/serious (total ${results.violations.length})`);
  } else {
    console.log(`[${label}] RENDER-GAGAL ${route} — blank (heading=${rendered.hasHeading} bodyLen=${rendered.bodyLen})`);
  }
  expect(isBlank, `[${label}] ${route} render blank`).toBe(false);
  expect(serious, `[${label}] ${route} violation critical/serious:\n  ${summarize(results)}`).toHaveLength(0);
}

test.describe('STAGE C sweep — worker (52 route + shell)', () => {
  test.use({ storageState: AUTH.worker });
  for (const route of dedup(['/worker', ...byArea.worker])) {
    test(`worker ${route}`, async ({ page }, testInfo) => {
      test.setTimeout(20000);
      await scanRoute(page, testInfo, 'worker', route);
    });
  }
});

test.describe('STAGE C sweep — admin (route + shell + dashboard; rute pabrik di describe terpisah)', () => {
  test.use({ storageState: AUTH.admin });
  for (const route of dedup(['/admin', '/dashboard', ...byArea.admin]).filter((r) => r !== '/admin/mill')) {
    test(`admin ${route}`, async ({ page }, testInfo) => {
      test.setTimeout(20000);
      await scanRoute(page, testInfo, 'admin', route);
    });
  }
});

// OPS-10: /admin/mill butuh role admin_mill (NRP105) — akun admin_hrd di-redirect
// ke /admin oleh useAdminAuth, sehingga test-nya timeout (spinner selamanya + churn network).
test.describe('STAGE C sweep — admin-mill (/admin/mill, role admin_mill)', () => {
  test.use({ storageState: AUTH['admin-mill'] });
  test('admin /admin/mill', async ({ page }, testInfo) => {
    test.setTimeout(20000);
    await scanRoute(page, testInfo, 'admin', '/admin/mill');
  });
});

test.describe('STAGE C sweep — owner shell', () => {
  test.use({ storageState: AUTH.owner });
  for (const route of ['/owner/dashboard', '/owner/dashboard/config']) {
    test(`owner ${route}`, async ({ page }, testInfo) => {
      test.setTimeout(20000);
      await scanRoute(page, testInfo, 'owner', route);
    });
  }
});
