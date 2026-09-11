/**
 * worker-attendance.spec.js — Q5 Flow 3: Worker login -> Attendance -> Leave
 *
 * 1. Protected-route redirects for /worker and sub-routes (always run).
 * 2. Full worker flow with a mocked Supabase backend: login, open the
 *    attendance calendar, then open the leave (cuti) page.
 */
import { test, expect } from '@playwright/test';
import { mockSupabase, loginAsWorker } from './helpers/mock-supabase';

test.describe('L7: Worker Protected Route Redirects', () => {
  test.beforeEach(async ({ page }) => {
    await mockSupabase(page);
  });

  test('/worker redirects to home when not authenticated', async ({ page }) => {
    await page.goto('/worker');
    await expect(page.locator('input[placeholder*="NRP"]')).toBeVisible({ timeout: 15000 });
    expect(page.url()).toBe('http://localhost:5173/');
  });

  test('/worker sub-routes redirect to home when not authenticated', async ({ page }) => {
    for (const route of ['/worker/attendance', '/worker/payroll', '/worker/leave']) {
      await page.goto(route);
      await expect(page.locator('input[placeholder*="NRP"]')).toBeVisible({ timeout: 15000 });
      expect(page.url(), `expected redirect to home after visiting ${route}`).toBe('http://localhost:5173/');
    }
  });
});

test.describe('L7: Worker Login -> Attendance -> Leave (mocked backend)', () => {
  test.beforeEach(async ({ page }) => {
    await mockSupabase(page);
  });

  test('worker opens attendance calendar and sees records', async ({ page }) => {
    await loginAsWorker(page);

    // Open the Kehadiran module from the quick-access tiles.
    await page.getByRole('button', { name: /kehadiran/i }).first().click();
    await page.waitForURL('**/worker/attendance', { timeout: 15000 });

    // Attendance page rendered with calendar + records from the mock backend.
    await expect(page.getByRole('heading', { name: /Kehadiran/i }).first()).toBeVisible();
    await expect(page.locator('body')).toContainText('Kalender');
    await expect(page.locator('body')).toContainText('Riwayat Kehadiran');
    await expect(page.locator('body')).toContainText('Hadir');
  });

  test('worker opens leave page and sees quota', async ({ page }) => {
    await loginAsWorker(page);

    // Open the Cuti module from the quick-access tiles.
    await page.getByRole('button', { name: /cuti/i }).first().click();
    await page.waitForURL('**/worker/leave', { timeout: 15000 });

    // Leave page rendered with quota + request history from the mock backend.
    await expect(page.getByRole('heading', { name: /Cuti Saya/i })).toBeVisible();
    await expect(page.locator('body')).toContainText('3/12 hari');
    await expect(page.locator('body')).toContainText('Cuti Tahunan');
  });
});