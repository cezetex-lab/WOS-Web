/**
 * accessibility.spec.ts — FASE 3 Stage 1: a11y scan (axe-core) 6 halaman
 * (Login, Worker, Admin, Dashboard, Owner, Owner Config).
 *
 * Sumber alur login: replika persis dari tests/e2e/four-page-smoke.spec.ts
 * (catatan: tests/e2e/helpers/pages/ TIDAK ada di repo ini, jadi tidak ada POM
 * untuk di-import; helper di bawah meniru langkah smoke yang terbukti hijau).
 *
 * Aturan penilaian: violation impact `critical`/`serious` (tags wcag2a/wcag2aa)
 * WAJIB nol; violation impact `moderate`/`minor` hanya dilaporkan ke console.
 * Bukti kegagalan (screenshot + JSON) di-attach ke testInfo.
 *
 * Env (tanpa hardcode kredensial):
 *   E2E_WORKER_NRP / E2E_WORKER_PASS (+ TEST_* fallback) — worker
 *   E2E_ADMIN_EMAIL / E2E_ADMIN_PASS (+ TEST_* fallback) — admin & dashboard
 *   E2E_OWNER_EMAIL / E2E_OWNER_PASS (+ TEST_* fallback) — owner (skipIf kosong)
 *   TEST_BASE_URL — default http://localhost:5173
 */
import { test, expect } from '@playwright/test';
import type { Page, TestInfo } from '@playwright/test';
import {
  scanA11y,
  seriousViolations,
  summarize,
  attachAxeReport,
  settle,
} from './helpers/axe-config';

const BASE = process.env.TEST_BASE_URL || 'http://localhost:5173';

function envFirst(...keys: string[]): string {
  for (const key of keys) {
    const value = process.env[key];
    if (value && value.trim()) return value.trim();
  }
  return '';
}

const WORKER_NRP = envFirst('E2E_WORKER_NRP', 'TEST_WORKER_NRP');
const WORKER_NIK = envFirst('E2E_WORKER_NIK', 'TEST_WORKER_NIK');
const WORKER_PASS = envFirst('E2E_WORKER_PASS', 'TEST_WORKER_PASS');
const WORKER_EMAIL =
  envFirst('E2E_WORKER_EMAIL', 'TEST_WORKER_EMAIL') ||
  (WORKER_NRP && WORKER_NRP !== 'NRP001' ? `${WORKER_NRP.toLowerCase()}@insightwos.internal` : '');

const ADMIN_EMAIL = envFirst('E2E_ADMIN_EMAIL', 'TEST_ADMIN_EMAIL');
const ADMIN_PASS = envFirst('E2E_ADMIN_PASS', 'TEST_ADMIN_PASS');
const DASHBOARD_EMAIL = envFirst('E2E_DASHBOARD_EMAIL', 'TEST_DASHBOARD_EMAIL') || ADMIN_EMAIL;
const DASHBOARD_PASS = envFirst('E2E_DASHBOARD_PASS', 'TEST_DASHBOARD_PASS') || ADMIN_PASS;
const OWNER_EMAIL = envFirst('E2E_OWNER_EMAIL', 'TEST_OWNER_EMAIL');
const OWNER_PASS = envFirst('E2E_OWNER_PASS', 'TEST_OWNER_PASS');

const HAS_WORKER = Boolean(WORKER_PASS && (WORKER_EMAIL || (WORKER_NRP && WORKER_NIK)));
const HAS_ADMIN = Boolean(ADMIN_EMAIL && ADMIN_PASS);
const HAS_DASHBOARD = Boolean(DASHBOARD_EMAIL && DASHBOARD_PASS);
const HAS_OWNER = Boolean(OWNER_EMAIL && OWNER_PASS);

/* ── Helper login (replika four-page-smoke) ─────────────────────────────── */

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

async function fillEmail(page: Page, email: string): Promise<void> {
  await page.locator('form input[type="email"]').first().fill(email);
}

async function fillSecret(page: Page, secret: string, index = 1): Promise<void> {
  await page.locator('form input').nth(index).fill(secret);
}

async function waitForPath(page: Page, path: string): Promise<void> {
  await page.waitForURL((url) => url.pathname === path, { timeout: 30000 });
}

async function loginWorker(page: Page): Promise<void> {
  if (WORKER_EMAIL) {
    await fillEmail(page, WORKER_EMAIL);
    await fillSecret(page, WORKER_PASS);
  } else {
    await page.getByText('Masuk dengan NRP').click();
    await page.locator('input[placeholder*="NRP"]').fill(WORKER_NRP);
    await page.locator('input[placeholder*="NIK"]').fill(WORKER_NIK);
    await fillSecret(page, WORKER_PASS, 2);
  }
  await page.locator('form button[type="submit"]').first().click();
}

async function readDisplayedOtp(page: Page): Promise<string> {
  const body = await page.locator('body').innerText();
  const match = /(?:Kode OTP[^0-9]{0,160})(\d{6})/i.exec(body);
  if (!match) throw new Error('Kode OTP dev-mode tidak ditemukan di UI — edge password-reset tidak mengirim dev_code');
  return match[1];
}

async function completeOtp(page: Page): Promise<void> {
  const otpInput = page.locator('input[placeholder="000000"]').first();
  await expect(otpInput).toBeVisible({ timeout: 30000 });
  await otpInput.fill(await readDisplayedOtp(page));
  await page.locator('form button[type="submit"]').first().click();
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
  test('a11y: 0 violation critical/serious', async ({ page }, testInfo) => {
    await page.goto(BASE + '/');
    await acceptConsent(page);
    await scanAndAssert(page, testInfo, 'login');
  });
});

test.describe('Worker page (/worker)', () => {
  test.skip(() => !HAS_WORKER, 'Kredensial worker belum diisi di environment (E2E_WORKER_*)');
  test('a11y: login worker -> scan /worker', async ({ page }, testInfo) => {
    await page.goto(BASE + '/');
    await acceptConsent(page);
    await page.getByRole('button', { name: /Pekerja/ }).click();
    await loginWorker(page);
    await waitForPath(page, '/worker');
    await scanAndAssert(page, testInfo, 'worker');
  });
});

test.describe('Admin page (/admin)', () => {
  test.skip(() => !HAS_ADMIN, 'Kredensial admin belum diisi di environment (E2E_ADMIN_*)');
  test('a11y: login admin -> scan /admin', async ({ page }, testInfo) => {
    await page.goto(BASE + '/');
    await acceptConsent(page);
    await page.getByRole('button', { name: /Admin/ }).click();
    await fillEmail(page, ADMIN_EMAIL);
    await fillSecret(page, ADMIN_PASS);
    await page.locator('form button[type="submit"]').first().click();
    await completeOtp(page);
    await waitForPath(page, '/admin');
    await scanAndAssert(page, testInfo, 'admin');
  });
});

test.describe('Dashboard page (/dashboard)', () => {
  test.skip(() => !HAS_DASHBOARD, 'Kredensial dashboard belum diisi di environment (E2E_DASHBOARD_*/E2E_ADMIN_*)');
  test('a11y: login via tab Dashboard -> scan /dashboard', async ({ page }, testInfo) => {
    await page.goto(BASE + '/');
    await acceptConsent(page);
    await page.getByRole('button', { name: /Dashboard/ }).click();
    await fillEmail(page, DASHBOARD_EMAIL);
    await fillSecret(page, DASHBOARD_PASS);
    await page.locator('form button[type="submit"]').first().click();
    await completeOtp(page);
    await waitForPath(page, '/dashboard');
    await scanAndAssert(page, testInfo, 'dashboard');
  });
});

test.describe('Owner page (/owner/dashboard)', () => {
  test.skip(() => !HAS_OWNER, 'Owner creds not set (E2E_OWNER_EMAIL/E2E_OWNER_PASS kosong)');
  test('a11y: login owner -> scan /owner/dashboard', async ({ page }, testInfo) => {
    await page.goto(BASE + '/owner');
    await acceptConsent(page);
    await fillEmail(page, OWNER_EMAIL);
    await fillSecret(page, OWNER_PASS);
    await page.locator('form button[type="submit"]').first().click();
    await waitForPath(page, '/owner/dashboard');
    await scanAndAssert(page, testInfo, 'owner');
  });
});

test.describe('Owner Config page (/owner/dashboard/config)', () => {
  test.skip(() => !HAS_OWNER, 'Owner creds not set (E2E_OWNER_EMAIL/E2E_OWNER_PASS kosong)');
  test('a11y: login owner -> scan /owner/dashboard/config', async ({ page }, testInfo) => {
    await page.goto(BASE + '/owner');
    await acceptConsent(page);
    await fillEmail(page, OWNER_EMAIL);
    await fillSecret(page, OWNER_PASS);
    await page.locator('form button[type="submit"]').first().click();
    await waitForPath(page, '/owner/dashboard');
    await page.goto(BASE + '/owner/dashboard/config');
    await page.waitForURL((url) => url.pathname === '/owner/dashboard/config', { timeout: 30000 });
    await scanAndAssert(page, testInfo, 'owner-config');
  });
});
