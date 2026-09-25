/**
 * four-page-smoke.spec.ts — smoke test empat halaman inti.
 *
 * Skenario: Worker, Admin, Dashboard, dan Owner. Kredensial HANYA dibaca dari
 * environment variable (tidak di-hardcode). Setiap skenario otomatis skip bila
 * kredensial live untuk role tersebut belum tersedia, sehingga default suite
 * tetap hijau tanpa rahasia.
 *
 * Env yang dipakai:
 *   E2E_WORKER_FOURPAGE_EMAIL / _NRP / _NIK + _PASS
 *   E2E_ADMIN_EMAIL + E2E_ADMIN_PASS
 *   E2E_DASHBOARD_EMAIL + E2E_DASHBOARD_PASS (fallback: kredensial admin)
 *   E2E_OWNER_EMAIL + E2E_OWNER_PASS
 *   TEST_BASE_URL (opsional; default http://localhost:5173)
 */
import { test, expect } from '@playwright/test';
import type { Page } from '@playwright/test';
import { clickStable, fillAdminOtp, fillStable, openHome } from './helpers/live-login';
import { ADMIN_ACCOUNTS, DASHBOARD_ACCOUNT, assertOtpBudget } from './helpers/live-accounts';

const BASE = process.env.TEST_BASE_URL || 'http://localhost:5173';
const LIVE = Boolean(process.env.E2E_LIVE);

function envFirst(...keys: string[]): string {
  for (const key of keys) {
    const value = process.env[key];
    if (value && value.trim()) return value.trim();
  }
  return '';
}

// Identitas worker KHUSUS four-page (E2E_WORKER_FOURPAGE_*) — bukan E2E_WORKER_*
// (NRP008) yang dipakai 5 konsumen sehingga login paralel beradu (temuan RUN 2).
const WORKER_NRP = envFirst('E2E_WORKER_FOURPAGE_NRP');
const WORKER_NIK = envFirst('E2E_WORKER_FOURPAGE_NIK');
const WORKER_PASS = envFirst('E2E_WORKER_FOURPAGE_PASS');
const WORKER_EMAIL = envFirst('E2E_WORKER_FOURPAGE_EMAIL');

// Identitas dari kontrak bersama (env-only, tanpa literal password) — sebaran OTP:
// Admin = hrd, Dashboard = hrd ⇒ 2 OTP / identitas / run (limit aplikasi 3 per 15 menit).
const ADMIN = ADMIN_ACCOUNTS.hrd;
const DASHBOARD = DASHBOARD_ACCOUNT;
const OWNER_EMAIL = envFirst('E2E_OWNER_EMAIL', 'TEST_OWNER_EMAIL');
const OWNER_PASS = envFirst('E2E_OWNER_PASS', 'TEST_OWNER_PASS');

// Saat E2E_LIVE=1 jangan pernah skip: kredensial yang hilang harus terlihat GAGAL,
// supaya klaim "0 skip" pada run LIVE benar-benar terukur.
const HAS_WORKER = LIVE || Boolean(WORKER_PASS && (WORKER_EMAIL || (WORKER_NRP && WORKER_NIK)));
const HAS_ADMIN = LIVE || Boolean(ADMIN.email && ADMIN.pass);
const HAS_DASHBOARD = LIVE || Boolean(DASHBOARD.email && DASHBOARD.pass);
const HAS_OWNER = LIVE || Boolean(OWNER_EMAIL && OWNER_PASS);

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

// fillStable: re-render (branding/consent/sisa request) bisa MENYAPU nilai form setelah
// `fill()` sehingga server menilai kredensial salah → FLAKY (temuan RUN 2).
async function fillEmail(page: Page, email: string): Promise<void> {
  await fillStable(page.locator('form input[type="email"]').first(), email);
}

async function fillSecret(page: Page, secret: string, index = 1): Promise<void> {
  await fillStable(page.locator('form input').nth(index), secret);
}

async function waitForPath(page: Page, path: string): Promise<void> {
  await page.waitForURL((url) => url.pathname === path, { timeout: 45000 });
}

async function loginWorker(page: Page): Promise<void> {
  if (WORKER_EMAIL) {
    await fillEmail(page, WORKER_EMAIL);
    await fillSecret(page, WORKER_PASS);
  } else {
    await clickStable(page.getByText('Masuk dengan NRP').first());
    await fillStable(page.locator('input[placeholder*="NRP"]'), WORKER_NRP);
    await fillStable(page.locator('input[placeholder*="NIK"]'), WORKER_NIK);
    await fillSecret(page, WORKER_PASS, 2);
  }
  await clickStable(page.locator('form button[type="submit"]').first());
}

/**
 * Langkah OTP memakai helper bersama: menunggu input OTP ATAU pesan rate-limit,
 * dan TIDAK mengirim ulang submit berulang (setiap klik memesan OTP baru sehingga
 * justru menghabiskan kuota 3/15 menit — temuan RUN 1 2026-09-25).
 * Mengembalikan jumlah tunggu rate-limit untuk pelaporan.
 */
async function completeOtp(page: Page): Promise<number> {
  return fillAdminOtp(page, 45000);
}

async function logout(page: Page, owner = false): Promise<void> {
  // timeout eksplisit pada click(): tanpa itu, tombol yang belum bisa diklik menunggu
  // sampai test timeout (temuan RUN 4: 605,9 s hanya untuk langkah logout).
  if (owner) {
    await clickStable(page.getByRole('button', { name: /^Logout$/i }).first(), 20000);
    await page.waitForURL((url) => url.pathname === '/owner', { timeout: 20000 });
  } else {
    await clickStable(page.locator('button[title="Logout"]').first(), 20000);
    await page.waitForURL((url) => url.pathname === '/', { timeout: 20000 });
  }
}

test.describe('four-page live smoke (opt-in via env kredensial)', () => {
  test.beforeAll(() => {
    assertOtpBudget(); // gagal cepat bila sebaran identitas OTP menyimpang
  });

  test('Worker: login -> /worker -> logout', async ({ page }) => {
    test.skip(!HAS_WORKER, 'Kredensial worker belum diisi di environment');
    // openHome menunggu get_branding selesai (klik submit saat re-render hilang).
    await openHome(page, 30000);
    await clickStable(page.getByRole('button', { name: /Pekerja/ }).first());
    await loginWorker(page);
    await waitForPath(page, '/worker');
    await expect(page.getByRole('heading', { name: /Ringkasan Hari Ini/i })).toBeVisible();
    await logout(page);
  });

  test('Admin: login -> /admin -> logout', async ({ page }) => {
    test.skip(!HAS_ADMIN, 'Kredensial admin belum diisi di environment');
    test.setTimeout(10 * 60_000); // satu tunggu jendela OTP (6 menit) + alur login
    await openHome(page, 30000);
    await clickStable(page.getByRole('button', { name: /Admin/ }).first());
    await fillEmail(page, ADMIN.email);
    await fillSecret(page, ADMIN.pass);
    await clickStable(page.locator('form button[type="submit"]').first());
    console.log('[four-page] Admin otpWaits=' + (await completeOtp(page)));
    await waitForPath(page, '/admin');
    await expect(page.getByRole('heading', { name: /Selamat Datang, Admin/i })).toBeVisible();
    await logout(page);
  });

  test('Dashboard: login via tab Dashboard -> /dashboard -> logout', async ({ page }) => {
    test.skip(!HAS_DASHBOARD, 'Kredensial dashboard belum diisi di environment');
    test.setTimeout(10 * 60_000); // satu tunggu jendela OTP (6 menit) + alur login
    await openHome(page, 30000);
    await clickStable(page.getByRole('button', { name: /Dashboard/ }).first());
    await fillEmail(page, DASHBOARD.email);
    await fillSecret(page, DASHBOARD.pass);
    await clickStable(page.locator('form button[type="submit"]').first());
    console.log('[four-page] Dashboard otpWaits=' + (await completeOtp(page)));
    await waitForPath(page, '/dashboard');
    await expect(page.getByRole('button', { name: /Beranda/ })).toBeVisible();
    await logout(page);
  });

  test('Owner: login -> /owner/dashboard -> logout', async ({ page }) => {
    test.skip(!HAS_OWNER, 'Kredensial owner belum diisi di environment');
    await page.goto(BASE + '/owner');
    await acceptConsent(page);
    await fillEmail(page, OWNER_EMAIL);
    await fillSecret(page, OWNER_PASS);
    await clickStable(page.locator('form button[type="submit"]').first());
    await waitForPath(page, '/owner/dashboard');
    await expect(page.getByRole('heading', { name: /Owner Dashboard/i })).toBeVisible();
    await logout(page, true);
  });
});