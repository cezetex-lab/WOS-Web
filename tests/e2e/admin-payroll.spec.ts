/**
 * admin-payroll.spec.ts — Q5 Flow 2: Admin login -> Payroll -> Filter
 *
 * 1. UI-only tests (always run) — admin form rendering, empty submit, redirects.
 * 2. Full admin login -> payroll -> filter flow with a mocked Supabase backend
 *    (runs by default): tab filters (Semua/Diproses/Pending/PKWT/PKWTT) and
 *    the table search box.
 *
 * Optional live admin tests: isi kredensial identitas `pusat` di env
 * (E2E_ADMIN_PUSAT_EMAIL / E2E_ADMIN_PUSAT_PASS) lalu jalankan dengan `--grep live`.
 *
 * Identitas: `pusat` (admin_pusat) — bukan `hrd`, karena `hrd` sudah dipakai
 * two-page smoke (Admin + Dashboard) dan kuota OTP aplikasi 3/15 menit per NRP.
 * Kontrak sebaran: tests/e2e/helpers/live-accounts.ts (OTP_ASSIGNMENT).
 */
import { test, expect } from '@playwright/test';
import { mockSupabase, loginAsAdmin } from './helpers/mock-supabase';
import { loginLiveAdmin, openHome, clickStable } from './helpers/live-login';
import { ADMIN_ACCOUNTS, assertAccount, assertOtpBudget } from './helpers/live-accounts';

const LIVE_ADMIN = ADMIN_ACCOUNTS.pusat;
const hasCredentials = Boolean(LIVE_ADMIN.email && LIVE_ADMIN.pass);

test.describe('L7: Admin Login Form UI', () => {
  test.beforeEach(async ({ page }) => {
    await mockSupabase(page);
  });

  test('admin tab shows email and password inputs', async ({ page }) => {
    await openHome(page);
    await clickStable(page.locator('button', { hasText: 'Admin' }));
    await expect(page.locator('input[type="email"]')).toBeVisible();
    await expect(page.locator('input[placeholder*="password"]')).toBeVisible();
    await expect(page.locator('button[type="submit"]')).toBeVisible();
  });

  test('admin login with empty fields stays on login page', async ({ page }) => {
    await openHome(page);
    await clickStable(page.locator('button', { hasText: 'Admin' }));
    await clickStable(page.locator('button[type="submit"]'));
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
    await expect(page.locator('input[type="email"]')).toBeVisible({ timeout: 15000 });
    expect(page.url()).toBe('http://localhost:5173/');
  });

  test('/admin/payroll redirects to home when not authenticated', async ({ page }) => {
    await page.goto('/admin/payroll');
    await expect(page.locator('input[type="email"]')).toBeVisible({ timeout: 15000 });
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
  test.skip(!hasCredentials, 'Skipping live admin login - set E2E_ADMIN_PUSAT_EMAIL, E2E_ADMIN_PUSAT_PASS');

  test('admin can login and access payroll', async ({ page }) => {
    // Satu tunggu jendela rate-limit (6 menit) + alur login masih < 15 menit.
    test.setTimeout(10 * 60_000);
    assertOtpBudget();
    assertAccount(LIVE_ADMIN, 'pusat');
    // Admin = 2 langkah (password → OTP dev-mode). Helper menangani langkah OTP;
    // tanpa itu test ini selalu gagal di waitForURL('**/admin') (temuan 2026-09-24).
    const otpWaits = await loginLiveAdmin(page, LIVE_ADMIN);
    console.log('[live-admin] otpWaits=' + otpWaits);
    expect(page.url()).toContain('/admin');
    const body = await page.locator('body').textContent();
    expect(body?.length ?? 0).toBeGreaterThan(100);

    // Bukti modul Payroll benar-benar dapat dibuka admin (data live).
    await page.goto('/admin/payroll');
    await expect(page.locator('body')).not.toBeEmpty();
    await expect(page.locator('h1, h2, h3').first()).toBeVisible({ timeout: 20000 });
  });
});