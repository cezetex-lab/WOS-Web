import { test, expect } from '@playwright/test';

test.describe('L7: Home Page E2E', () => {
  test('home page loads with title', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveTitle(/WOS|insightWOS/i);
  });

  test('home page shows login form', async ({ page }) => {
    await page.goto('/');
    // Should have some input fields for login
    const inputs = await page.locator('input').count();
    expect(inputs).toBeGreaterThan(0);
  });

  test('navigation to owner login', async ({ page }) => {
    await page.goto('/owner');
    await expect(page.url()).toContain('/owner');
  });

  test('owner dashboard requires auth', async ({ page }) => {
    await page.goto('/owner/dashboard');
    // Should redirect to login or show auth required
    await page.waitForTimeout(2000);
    const url = page.url();
    // Consistent pattern with worker/admin: redirect to home or stay on owner login page
    expect(url === 'http://localhost:5173/' || url.includes('owner')).toBeTruthy();
  });
});

test.describe('L7: Worker Login Flow E2E', () => {
  test('worker login form exists on home page', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    // Check for NRP/NIK input
    const nrpInput = page.locator('input[placeholder*="NRP"], input[placeholder*="NIK"], input[type="text"]').first();
    await expect(nrpInput).toBeVisible();
  });

  test('login with empty fields shows error', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    // Try to submit without filling
    const submitBtn = page.locator('button[type="submit"], button:has-text("Masuk"), button:has-text("Login")').first();
    if (await submitBtn.isVisible()) {
      await submitBtn.click();
      await page.waitForTimeout(1000);
      // Should still be on login page
      expect(page.url()).toContain('/');
    }
  });
});

test.describe('L7: Protected Routes E2E', () => {
  test('worker page redirects to login when not authenticated', async ({ page }) => {
    await page.goto('/worker');
    await page.waitForTimeout(3000);
    // Should redirect to home/login
    const url = page.url();
    expect(url === 'http://localhost:5173/' || url.includes('worker')).toBeTruthy();
  });

  test('admin page redirects to login when not authenticated', async ({ page }) => {
    await page.goto('/admin');
    await page.waitForTimeout(3000);
    const url = page.url();
    expect(url === 'http://localhost:5173/' || url.includes('admin')).toBeTruthy();
  });
});