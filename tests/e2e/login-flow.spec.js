/**
 * login-flow.spec.js — Q5 Flow 1: Login -> Dashboard -> Logout
 *
 * Two layers:
 *  1. UI-only tests (always run) — form rendering, tab switching, validation.
 *  2. Full worker login -> dashboard -> logout with a mocked Supabase backend
 *     (runs by default, no credentials needed, deterministic in CI).
 *
 * Optional live tests against a real backend: set TEST_WORKER_NRP,
 * TEST_WORKER_NIK, TEST_WORKER_PASS and run with `--grep live`.
 */
import { test, expect } from '@playwright/test';
import { mockSupabase, loginAsWorker } from './helpers/mock-supabase';

const WORKER_NRP = process.env.TEST_WORKER_NRP;
const WORKER_NIK = process.env.TEST_WORKER_NIK;
const WORKER_PASS = process.env.TEST_WORKER_PASS;
const hasCredentials = WORKER_NRP && WORKER_NIK && WORKER_PASS;

test.describe('L7: Login Flow UI', () => {
  test.beforeEach(async ({ page }) => {
    await mockSupabase(page);
  });

  test('home page renders login form with worker tab active', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('h1')).toContainText('insightWOS');
    const workerTab = page.locator('button', { hasText: 'Pekerja' });
    await expect(workerTab).toBeVisible();
    await expect(page.locator('input[placeholder*="NRP"]')).toBeVisible();
    await expect(page.locator('input[placeholder*="NIK"]')).toBeVisible();
    await expect(page.locator('input[placeholder*="password"]')).toBeVisible();
    await expect(page.locator('button[type="submit"]')).toBeVisible();
  });

  test('worker login with empty fields stays on login page', async ({ page }) => {
    await page.goto('/');
    await page.locator('button[type="submit"]').click();
    await expect(page.locator('input[placeholder*="NRP"]')).toBeVisible();
    expect(page.url()).toContain('/');
  });

  test('admin tab shows admin login form', async ({ page }) => {
    await page.goto('/');
    await page.locator('button', { hasText: 'Admin' }).click();
    await expect(page.locator('input[type="email"]')).toBeVisible();
    await expect(page.locator('input[placeholder*="password"]')).toBeVisible();
  });

  test('dashboard tab shows dashboard login form', async ({ page }) => {
    await page.goto('/');
    await page.locator('button', { hasText: 'Dashboard' }).click();
    await expect(page.locator('input[placeholder*="NRP"]')).toBeVisible();
  });

  test('tab switching clears form state', async ({ page }) => {
    await page.goto('/');
    await page.locator('input[placeholder*="NRP"]').fill('TEST123');
    await page.locator('input[placeholder*="NIK"]').fill('1234567890');
    await page.locator('button', { hasText: 'Admin' }).click();
    await expect(page.locator('input[type="email"]')).toBeVisible();
    await page.locator('button', { hasText: 'Pekerja' }).click();
    await expect(page.locator('input[placeholder*="NRP"]')).toHaveValue('');
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
    await expect(page.locator('input[placeholder*="NRP"]')).toBeVisible();
  });

  test('wrong credentials show an error and stay on login page', async ({ page }) => {
    // Override the login_worker mock to simulate rejected credentials.
    await page.route('**/rest/v1/rpc/login_worker', (route) =>
      route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ ok: false, msg: 'NRP, NIK, atau password salah' }),
      })
    );

    await page.goto('/');
    await page.locator('input[placeholder*="NRP"]').fill('NRP999');
    await page.locator('input[placeholder*="NIK"]').fill('0000000000');
    await page.locator('input[placeholder*="password"]').fill('wrongpass');
    await page.locator('button[type="submit"]').click();

    await expect(page.locator('body')).toContainText('NRP, NIK, atau password salah');
    expect(page.url()).toContain('/');
  });
});

test.describe('L7: Live Worker Login (opt-in, needs real backend)', () => {
  test.skip(!hasCredentials, 'Skipping live login - set TEST_WORKER_NRP, TEST_WORKER_NIK, TEST_WORKER_PASS');

  test('complete worker login flow', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    await page.locator('input[placeholder*="NRP"]').fill(WORKER_NRP);
    await page.locator('input[placeholder*="NIK"]').fill(WORKER_NIK);
    await page.locator('input[type="password"]').fill(WORKER_PASS);
    await page.locator('button[type="submit"]').click();
    await page.waitForURL('**/worker', { timeout: 15000 });
    expect(page.url()).toContain('/worker');
    await page.waitForLoadState('networkidle');
    const body = await page.locator('body').textContent();
    expect(body.length).toBeGreaterThan(100);
  });
});