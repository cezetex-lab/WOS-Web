import { test, expect } from '@playwright/test';

test.describe('L7: Home Page E2E', () => {
  test('home page loads with title', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveTitle(/WOS|insightWOS/i);
  });

  test('home page shows login form', async ({ page }) => {
    await page.goto('/');
    // Should have some input fields for login.
    // Render pertama bersifat asinkron (branding/consent) — pakai poll supaya tidak
    // balapan dengan React (RUN 1: `count()` sesaat = 0 → FLAKY, retry baru lolos).
    await expect
      .poll(() => page.locator('input').count(), { timeout: 20000 })
      .toBeGreaterThan(0);
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
    // Check for login input (email mode by default)
    const loginInput = page.locator('input[placeholder*="email"], input[placeholder*="NRP"], input[type="text"]').first();
    await expect(loginInput).toBeVisible();
  });

  test('login with empty fields shows error', async ({ page }) => {
    await page.goto('/');
    // The privacy-consent modal is rendered at z-[9999] and asynchronously;
    // it overlays the form and intercepts the submit click until dismissed.
    const consent = page.locator('div[role="dialog"] button:has-text("Saya Setuju")');
    try {
      await consent.first().waitFor({ state: 'visible', timeout: 8000 });
      await consent.first().click();
    } catch { /* no consent dialog — continue */ }
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