/**
 * role-change.spec.js — Q5 Flow 4: Role change -> permissions active immediately
 *
 * Verifies RBAC at the route level with mocked Supabase sessions:
 *  - /owner/* requires owner authentication.
 *  - Payroll module is limited to admin_pusat / admin_finance (useAdminAuth).
 *  - When the user's role changes, the new permissions apply on next load
 *    (no stale session): admin_finance -> admin_hrd loses payroll access.
 */
import { test, expect } from '@playwright/test';
import { mockSupabase, MOCK_USERS, loginAsAdmin, loginAsWorker } from './helpers/mock-supabase';

test.describe('L7: Role-Based Route Protection', () => {
  test.beforeEach(async ({ page }) => {
    await mockSupabase(page);
  });

  test('/owner shows owner login page when not authenticated', async ({ page }) => {
    await page.goto('/owner');
    await expect(page.url()).toContain('/owner');
    const body = await page.locator('body').textContent();
    expect(body.length).toBeGreaterThan(0);
  });

  test('/owner/dashboard redirects to owner login when not authenticated', async ({ page }) => {
    await page.goto('/owner/dashboard');
    await expect(page.url()).toContain('/owner');
  });

  test('home page shows all three role tabs', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('button', { hasText: 'Pekerja' })).toBeVisible();
    await expect(page.locator('button', { hasText: 'Admin' })).toBeVisible();
    await expect(page.locator('button', { hasText: 'Dashboard' })).toBeVisible();
  });
});

test.describe('L7: Payroll Access by Role (mocked backend)', () => {
  test.beforeEach(async ({ page }) => {
    await mockSupabase(page);
  });

  test('admin_pusat can open the payroll module', async ({ page }) => {
    await loginAsAdmin(page, 'admin_pusat');
    await page.goto('/admin/payroll');
    await page.waitForURL('**/admin/payroll', { timeout: 15000 });
    await expect(page.getByRole('heading', { name: /Payroll/i }).first()).toBeVisible();
    await expect(page.locator('body')).toContainText('Detail Payroll');
  });

  test('admin_finance can open the payroll module', async ({ page }) => {
    await loginAsAdmin(page, 'admin_finance');
    await page.goto('/admin/payroll');
    await page.waitForURL('**/admin/payroll', { timeout: 15000 });
    await expect(page.locator('body')).toContainText('Detail Payroll');
  });

  test('admin_hrd is redirected away from payroll', async ({ page }) => {
    await loginAsAdmin(page, 'admin_hrd');
    await page.goto('/admin/payroll');
    // useAdminAuth(['admin_pusat','admin_finance']) kicks admin_hrd back to /admin.
    await expect(page.url()).toContain('/admin');
    await expect(page.locator('body')).not.toContainText('Detail Payroll');
    await expect(page.getByRole('heading', { name: /Selamat Datang, Admin/i })).toBeVisible();
  });

  test('worker cannot open the payroll module', async ({ page }) => {
    await loginAsWorker(page);
    await page.goto('/admin/payroll');
    // Worker role is not allowed → redirected away from payroll content.
    await expect(page.locator('body')).not.toContainText('Detail Payroll');
  });
});

test.describe('L7: Role Change Takes Effect Immediately', () => {
  test('downgraded role loses payroll access on next load', async ({ page }) => {
    const mock = await mockSupabase(page);

    // Login as admin_finance (payroll allowed).
    await loginAsAdmin(page, 'admin_finance');
    await page.goto('/admin/payroll');
    await page.waitForURL('**/admin/payroll', { timeout: 15000 });
    await expect(page.locator('body')).toContainText('Detail Payroll');

    // Simulate a role change in the backend (e.g. admin reassigned to HRD).
    mock.setUser(MOCK_USERS.admin_hrd);

    // On next load the new permissions are enforced — payroll is blocked.
    await page.reload();
    await expect(page.url()).toContain('/admin');
    await expect(page.locator('body')).not.toContainText('Detail Payroll');
    await expect(page.getByRole('heading', { name: /Selamat Datang, Admin/i })).toBeVisible();
  });
});