/**
 * admin-payroll.spec.js — Q5 Flow 2: Admin login -> Payroll -> Filter
 *
 * 1. UI-only tests (always run) — admin form rendering, empty submit, redirects.
 * 2. Full admin login -> payroll -> filter flow with a mocked Supabase backend
 *    (runs by default): tab filters (Semua/Diproses/Pending/PKWT/PKWTT) and
 *    the table search box.
 *
 * Optional live admin tests: set TEST_ADMIN_EMAIL / TEST_ADMIN_PASS and run
 * with `--grep live`.
 */
import { test, expect } from '@playwright/test';
import { mockSupabase, loginAsAdmin } from './helpers/mock-supabase';

const ADMIN_EMAIL = process.env.TEST_ADMIN_EMAIL;
const ADMIN_PASS = process.env.TEST_ADMIN_PASS;
const hasCredentials = ADMIN_EMAIL && ADMIN_PASS;

test.describe('L7: Admin Login Form UI', () => {
  test.beforeEach(async ({ page }) => {
    await mockSupabase(page);
  });

  test('admin tab shows email and password inputs', async ({ page }) => {
    await page.goto('/');
    await page.locator('button', { hasText: 'Admin' }).click();
    await expect(page.locator('input[type="email"]')).toBeVisible();
    await expect(page.locator('input[placeholder*="password"]')).toBeVisible();
    await expect(page.locator('button[type="submit"]')).toBeVisible();
  });

  test('admin login with empty fields stays on login page', async ({ page }) => {
    await page.goto('/');
    await page.locator('button', { hasText: 'Admin' }).click();
    await page.locator('button[type="submit"]').click();
    expect(page.url()).toContain('/');
    await expect(page.locator('input[type="email"]')).toBeVisible();
  });
});

test.describe('L7: Admin Protected Route Redirects', () => {
  test.beforeEach(async ({ page }) => {
    await mockSupabase(page);
  });

  test('/admin redirects to home when not authenticated', async ({ page }) => {
    await page.goto('/admin');
    await expect(page.locator('input[placeholder*="NRP"]')).toBeVisible({ timeout: 15000 });
    expect(page.url()).toBe('http://localhost:5173/');
  });

  test('/admin/payroll redirects to home when not authenticated', async ({ page }) => {
    await page.goto('/admin/payroll');
    await expect(page.locator('input[placeholder*="NRP"]')).toBeVisible({ timeout: 15000 });
    expect(page.url()).toBe('http://localhost:5173/');
  });

  test('/owner/dashboard redirects to owner login when not authenticated', async ({ page }) => {
    await page.goto('/owner/dashboard');
    await expect(page.url()).toContain('/owner');
  });
});

test.describe('L7: Admin Login -> Payroll -> Filter (mocked backend)', () => {
  test.beforeEach(async ({ page }) => {
    await mockSupabase(page);
  });

  test('admin logs in and lands on admin dashboard with role badge', async ({ page }) => {
    await loginAsAdmin(page, 'admin_pusat');
    await expect(page.locator('body')).toContainText('Admin Pusat');
    await expect(page.getByRole('button', { name: /payroll/i }).first()).toBeVisible();
  });

  test('admin navigates to payroll and filters rows', async ({ page }) => {
    await loginAsAdmin(page, 'admin_pusat');

    // Open the Payroll module from the quick-access tiles.
    await page.getByRole('button', { name: /payroll/i }).first().click();
    await page.waitForURL('**/admin/payroll', { timeout: 15000 });

    // Page rendered with the payroll table (mock rows).
    await expect(page.locator('body')).toContainText('Detail Payroll');
    await expect(page.locator('body')).toContainText('Budi Santoso');
    await expect(page.locator('body')).toContainText('Andi Wijaya');

    // Filter tab "Pending" → only Pending/Draft rows remain.
    await page.getByRole('tab', { name: /pending/i }).click();
    await expect(page.locator('body')).toContainText('Andi Wijaya');
    await expect(page.locator('body')).toContainText('Deni Pratama');
    await expect(page.locator('body')).not.toContainText('Budi Santoso');

    // Filter tab "PKWT" → contract-type filter.
    await page.getByRole('tab', { name: 'PKWT' }).first().click();
    await expect(page.locator('body')).toContainText('Andi Wijaya');
    await expect(page.locator('body')).toContainText('Deni Pratama');
    await expect(page.locator('body')).not.toContainText('Cici Lestari');

    // Back to "Semua", then use the search box.
    await page.getByRole('tab', { name: /semua/i }).click();
    await page.getByPlaceholder(/cari nama/i).fill('Cici');
    await expect(page.locator('body')).toContainText('Cici Lestari');
    await expect(page.locator('body')).not.toContainText('Budi Santoso');
    await expect(page.locator('body')).not.toContainText('Deni Pratama');
  });
});

test.describe('L7: Live Admin Login (opt-in, needs real backend)', () => {
  test.skip(!hasCredentials, 'Skipping live admin login - set TEST_ADMIN_EMAIL, TEST_ADMIN_PASS');

  test('admin can login and access payroll', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    await page.locator('button', { hasText: 'Admin' }).click();
    await page.locator('input[type="email"]').fill(ADMIN_EMAIL);
    await page.locator('input[type="password"]').fill(ADMIN_PASS);
    await page.locator('button[type="submit"]').click();
    await page.waitForURL('**/admin', { timeout: 15000 });
    expect(page.url()).toContain('/admin');
    const body = await page.locator('body').textContent();
    expect(body.length).toBeGreaterThan(100);
  });
});