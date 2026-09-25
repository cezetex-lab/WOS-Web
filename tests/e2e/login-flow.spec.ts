/**
 * login-flow.spec.ts — Q5 Flow 1: Login -> Dashboard -> Logout
 *
 * Two layers:
 *  1. UI-only tests (always run) — form rendering, tab switching, validation.
 *  2. Full worker login -> dashboard -> logout with a mocked Supabase backend
 *     (runs by default, no credentials needed, deterministic in CI).
 *
 * Optional live tests against a real backend: isi E2E_WORKER_LOGINFLOW_NRP,
 * E2E_WORKER_LOGINFLOW_NIK, E2E_WORKER_LOGINFLOW_PASS (di-seed dari akun.txt)
 * lalu jalankan dengan `--grep live`.
 */
import { test, expect } from '@playwright/test';
import { mockSupabase, loginAsWorker } from './helpers/mock-supabase';
import { clickStable, fillStable, openHome } from './helpers/live-login';

// Identitas worker KHUSUS login-flow (E2E_WORKER_LOGINFLOW_*) — bukan TEST_WORKER_*
// (NRP008) yang dipakai 5 konsumen sehingga login paralel beradu (temuan RUN 2).
const WORKER_NRP = process.env.E2E_WORKER_LOGINFLOW_NRP;
const WORKER_NIK = process.env.E2E_WORKER_LOGINFLOW_NIK;
const WORKER_PASS = process.env.E2E_WORKER_LOGINFLOW_PASS;
// Saat E2E_LIVE=1 jangan skip: kredensial hilang harus terlihat GAGAL (0 skip terukur).
const hasCredentials = Boolean(process.env.E2E_LIVE) || Boolean(WORKER_NRP && WORKER_NIK && WORKER_PASS);

test.describe('L7: Login Flow UI', () => {
  test.beforeEach(async ({ page }) => {
    await mockSupabase(page);
  });

  test('home page renders login form with worker tab active (email mode)', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('h1')).toContainText('insightWOS');
    const workerTab = page.locator('button', { hasText: 'Pekerja' });
    await expect(workerTab).toBeVisible();
    await expect(page.locator('input[placeholder*="email"]')).toBeVisible();
    await expect(page.locator('input[placeholder*="password"]')).toBeVisible();
    await expect(page.locator('button[type="submit"]')).toBeVisible();
    // NRP/NIK inputs hidden by default (email mode)
    await expect(page.locator('input[placeholder*="NRP"]')).not.toBeVisible();
  });

  test('worker login with empty fields stays on login page', async ({ page }) => {
    await page.goto('/');
    await clickStable(page.locator('button[type="submit"]').first());
    await expect(page.locator('input[placeholder*="email"]')).toBeVisible();
    expect(page.url()).toContain('/');
  });

  test('admin tab shows admin login form', async ({ page }) => {
    await openHome(page);
    await clickStable(page.locator('button', { hasText: 'Admin' }));
    await expect(page.locator('input[type="email"]')).toBeVisible();
    await expect(page.locator('input[placeholder*="password"]')).toBeVisible();
  });

  test('dashboard tab shows dashboard login form (email mode)', async ({ page }) => {
    await openHome(page);
    await clickStable(page.locator('button', { hasText: 'Dashboard' }));
    await expect(page.locator('input[placeholder*="email"]')).toBeVisible();
  });

  test('tab switching clears form state', async ({ page }) => {
    await openHome(page);
    await page.locator('input[placeholder*="email"]').fill('test@example.com');
    await page.locator('input[placeholder*="password"]').fill('secret123');
    await clickStable(page.locator('button', { hasText: 'Admin' }));
    await expect(page.locator('input[type="email"]')).toBeVisible();
    await clickStable(page.locator('button', { hasText: 'Pekerja' }));
    await expect(page.locator('input[placeholder*="email"]')).toHaveValue('');
  });
});

test.describe('L7: Worker Login -> Dashboard -> Logout (mocked backend)', () => {
  test.beforeEach(async ({ page }) => {
    await mockSupabase(page);
  });

  test('worker logs in, lands on dashboard with live data, then logs out', async ({ page }) => {
    await loginAsWorker(page);

    // Dashboard rendered the narrative + announcements from the (mock) backend.
    await expect(page.locator('body')).toContainText('Halo, Budi!');
    await expect(page.locator('body')).toContainText('Hari Libur Nasional');

    // Logout returns to the login screen.
    await page.getByRole('button', { name: /keluar|logout/i }).first().click();
    await page.waitForURL('http://localhost:5173/', { timeout: 15000 });
    await expect(page.locator('input[placeholder*="email"]')).toBeVisible();
  });

  test('wrong credentials show an error and stay on login page', async ({ page }) => {
    // Override the login_worker_by_email mock to simulate rejected credentials.
    await page.route('**/rest/v1/rpc/login_worker_by_email', (route) =>
      route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ ok: false, msg: 'Email atau password salah' }),
      })
    );

    await page.goto('/');
    await page.locator('input[placeholder*="email"]').fill('wrong@test.com');
    await page.locator('input[placeholder*="password"]').fill('wrongpass');
    await clickStable(page.locator('button[type="submit"]').first());

    await expect(page.locator('body')).toContainText('Email atau password salah');
    expect(page.url()).toContain('/');
  });
});

test.describe('L7: Live Worker Login (opt-in, needs real backend)', () => {
  test.skip(!hasCredentials, 'Skipping live login - set E2E_WORKER_LOGINFLOW_NRP, E2E_WORKER_LOGINFLOW_NIK, E2E_WORKER_LOGINFLOW_PASS');

  test('complete worker login flow (NRP mode)', async ({ page }) => {
    // openHome menunggu `get_branding` selesai + menutup dialog consent sebelum form
    // disentuh. Sebelumnya `goto` + klik `text=Masuk dengan NRP` balapan dengan
    // re-render branding sehingga klik tidak stabil (RUN 1: 2x timedOut 90 s).
    await openHome(page, 30000);
    // Tab Pekerja default = mode EMAIL; tunggu form benar-benar ter-render dulu.
    await expect(page.locator('input[placeholder*="email"]')).toBeVisible({ timeout: 20000 });
    // Switch to NRP mode for NRP+NIK login
    await clickStable(page.getByText('Masuk dengan NRP').first());
    await expect(page.locator('input[placeholder*="NRP"]')).toBeVisible({ timeout: 20000 });
    await fillStable(page.locator('input[placeholder*="NRP"]'), WORKER_NRP!);
    await fillStable(page.locator('input[placeholder*="NIK"]'), WORKER_NIK!);
    await fillStable(page.locator('input[type="password"]'), WORKER_PASS!);
    await clickStable(page.locator('button[type="submit"]').first());
    await page.waitForURL('**/worker', { timeout: 30000 });
    expect(page.url()).toContain('/worker');
    await page.waitForLoadState('networkidle');
    const body = await page.locator('body').textContent();
    expect(body?.length ?? 0).toBeGreaterThan(100);
  });
});