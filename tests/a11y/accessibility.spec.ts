/**
 * accessibility.spec.ts — FASE 3 Stage 1: a11y scan (axe-core) 6 halaman
 * (Login, Worker, Admin, Dashboard, Owner, Owner Config).
 *
 * Auth: storageState 1x per role (.agents/logs/auth-{worker,admin,owner}.json)
 * — prinsip OPS-08, tanpa OTP ulang di suite (0 OTP/run; limiter
 * `pwreset_login_otp` 3/NRP/15 menit tidak lagi tersentuh suite ini).
 * Generator: node .agents/scripts/setup-auth-state.cjs (butuh dev server jalan);
 * kredensial E2E_* di .env.local hanya dipakai script generator itu, bukan di sini.
 *   TEST_BASE_URL — default http://localhost:5173
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { test, expect } from '@playwright/test';
import type { Page, TestInfo } from '@playwright/test';
import {
  scanA11y,
  seriousViolations,
  summarize,
  attachAxeReport,
  settle,
} from './helpers/axe-config';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const BASE = process.env.TEST_BASE_URL || 'http://localhost:5173';

const AUTH = {
  worker: path.join(ROOT, '.agents', 'logs', 'auth-worker.json'),
  admin: path.join(ROOT, '.agents', 'logs', 'auth-admin.json'),
  owner: path.join(ROOT, '.agents', 'logs', 'auth-owner.json'),
};
for (const [k, p] of Object.entries(AUTH)) {
  if (!fs.existsSync(p)) {
    throw new Error(`storageState ${k} hilang: ${p} — jalankan: node .agents/scripts/setup-auth-state.cjs`);
  }
}

/* ── Helper ─────────────────────────────────────────────────────────────── */

async function acceptConsent(page: Page): Promise<void> {
  const consent = page.locator('div[role="dialog"] button:has-text("Saya Setuju")').first();
  try {
    await consent.waitFor({ state: 'visible', timeout: 8000 });
    await consent.click();
    await page.waitForTimeout(300);
  } catch {
    /* dialog consent tidak muncul — lanjut */
  }
}

/* ── Core scan ──────────────────────────────────────────────────────────── */

async function scanAndAssert(page: Page, testInfo: TestInfo, label: string): Promise<void> {
  await settle(page);
  const results = await scanA11y(page);
  const serious = seriousViolations(results);

  if (serious.length > 0) {
    console.log(`[${label}] VIOLATION critical/serious:\n  ${summarize(results)}`);
    await attachAxeReport(page, testInfo, label, serious);
  } else {
    console.log(
      `[${label}] OK — 0 critical/serious. Total violation (semua impact): ${results.violations.length}` +
        (results.violations.length > 0 ? `\n  ${summarize(results)}` : ''),
    );
  }

  expect(
    serious,
    `[${label}] violation critical/serious:\n  ${summarize(results)}`,
  ).toHaveLength(0);
}

/* ── Suites ─────────────────────────────────────────────────────────────── */

test.describe('Login page (/)', () => {
  // Halaman login harus di luar sesi apa pun — state kosong eksplisit.
  test.use({ storageState: { cookies: [], origins: [] } });
  test('a11y: 0 violation critical/serious', async ({ page }, testInfo) => {
    await page.goto(BASE + '/');
    await acceptConsent(page);
    await scanAndAssert(page, testInfo, 'login');
  });
});

test.describe('Worker page (/worker)', () => {
  test.use({ storageState: AUTH.worker });
  test('a11y: storageState worker -> scan /worker', async ({ page }, testInfo) => {
    await page.goto(BASE + '/worker');
    await scanAndAssert(page, testInfo, 'worker');
  });
});

test.describe('Admin page (/admin)', () => {
  test.use({ storageState: AUTH.admin });
  test('a11y: storageState admin -> scan /admin', async ({ page }, testInfo) => {
    await page.goto(BASE + '/admin');
    await scanAndAssert(page, testInfo, 'admin');
  });
});

test.describe('Dashboard page (/dashboard)', () => {
  test.use({ storageState: AUTH.admin }); // dashboard login = kredensial admin (fallback, sama seperti sweep)
  test('a11y: storageState admin -> scan /dashboard', async ({ page }, testInfo) => {
    await page.goto(BASE + '/dashboard');
    await scanAndAssert(page, testInfo, 'dashboard');
  });
});

test.describe('Owner page (/owner/dashboard)', () => {
  test.use({ storageState: AUTH.owner });
  test('a11y: storageState owner -> scan /owner/dashboard', async ({ page }, testInfo) => {
    await page.goto(BASE + '/owner/dashboard');
    await scanAndAssert(page, testInfo, 'owner');
  });
});

test.describe('Owner Config page (/owner/dashboard/config)', () => {
  test.use({ storageState: AUTH.owner });
  test('a11y: storageState owner -> scan /owner/dashboard/config', async ({ page }, testInfo) => {
    await page.goto(BASE + '/owner/dashboard/config');
    await scanAndAssert(page, testInfo, 'owner-config');
  });
});
