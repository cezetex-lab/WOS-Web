/**
 * concurrent-session.spec.js — Q5 Flow 5: Concurrent session handling
 *
 * With a mocked Supabase backend:
 *  - SessionGuard registers a session per page load (multi-tab → multi-session).
 *  - Session survives full page reloads (session persistence).
 *  - Clearing the stored session redirects back to the login page.
 *  - When the backend reports a session-limit violation on login, the error is
 *    surfaced in the UI and the user stays on the login page.
 */
import { test, expect } from '@playwright/test';
import { mockSupabase, loginAsWorker } from './helpers/mock-supabase';

test.describe('L7: Session Guard Behavior', () => {
  test('fresh visit has no stored auth session', async ({ page }) => {
    await mockSupabase(page);
    await page.goto('/');
    const stored = await page.evaluate(() => Object.keys(localStorage).filter((k) => k.includes('auth-token')));
    expect(stored.length).toBe(0);
  });

  test('multiple tabs each register a session', async ({ page, context }) => {
    const mock = await mockSupabase(page);

    // Tab 1: full login → SessionGuard registers a session.
    await loginAsWorker(page);
    const afterFirst = mock.state.registeredSessions.size;
    expect(afterFirst).toBeGreaterThanOrEqual(1);

    // Tab 2 (same browser context → same auth storage, shared mock state):
    // SessionGuard registers ANOTHER session server-side.
    const page2 = await context.newPage();
    await mockSupabase(page2, { state: mock.state });
    await page2.goto('/worker');
    await expect(page2.getByRole('heading', { name: /Ringkasan Hari Ini/i })).toBeVisible();
    await expect.poll(() => mock.state.registeredSessions.size).toBeGreaterThan(afterFirst);

    await page2.close();
  });
});

test.describe('L7: Session Lifecycle', () => {
  test('session persists across full page reload', async ({ page }) => {
    await mockSupabase(page);
    await loginAsWorker(page);

    await page.reload();
    await expect(page.getByRole('heading', { name: /Ringkasan Hari Ini/i })).toBeVisible();
    expect(page.url()).toContain('/worker');
  });

  test('clearing the stored session redirects to login', async ({ page }) => {
    await mockSupabase(page);
    await loginAsWorker(page);

    // Simulate an expired/logged-out session: clear Supabase auth storage AND
    // the app's own wos_user session. Hanya membersihkan localStorage tidak
    // cukup: setelah provisionWorkerAuth, initSession() menimpa wos_user dengan
    // context tanpa token (dari get_current_user_context). Boot berikutnya
    // SessionGuard menolak restore tanpa token (→ '/') sementara Home.getSession()
    // masih menerima entri tanpa token itu (→ '/worker') = loop redirect tak berujung.
    await page.evaluate(() => {
      Object.keys(localStorage)
        .filter((k) => k.includes('auth-token'))
        .forEach((k) => localStorage.removeItem(k));
      sessionStorage.removeItem('wos_user');
    });

    await page.reload();
    await expect(page.locator('input[placeholder*="NRP"]')).toBeVisible({ timeout: 15000 });
    expect(page.url()).toBe('http://localhost:5173/');
  });

  test('logout clears session and returns to login', async ({ page }) => {
    await mockSupabase(page);
    await loginAsWorker(page);

    await page.getByRole('button', { name: /keluar|logout/i }).first().click();
    await page.waitForURL('http://localhost:5173/', { timeout: 15000 });
    await expect(page.locator('input[placeholder*="NRP"]')).toBeVisible();

    // Stored auth session must be gone after logout.
    const stored = await page.evaluate(() => Object.keys(localStorage).filter((k) => k.includes('auth-token')));
    expect(stored.length).toBe(0);
  });
});

test.describe('L7: Concurrent Session Limit', () => {
  test('login rejected when session limit is reached', async ({ page, context }) => {
    const mock = await mockSupabase(page, { maxSessions: 1 });

    // First session (tab 1) registers fine.
    await loginAsWorker(page);

    // Second login attempt (shared mock state) hits the limit → error surfaced.
    const page2 = await context.newPage();
    await mockSupabase(page2, { state: mock.state });
    // This is a fresh device: no stored session (otherwise Home would
    // auto-redirect to /worker because the shared context is logged in).
    await page2.addInitScript(() => {
      Object.keys(localStorage)
        .filter((k) => k.includes('auth-token'))
        .forEach((k) => localStorage.removeItem(k));
    });
    await page2.goto('/');
    await page2.locator('input[placeholder*="NRP"]').fill('NRP001');
    await page2.locator('input[placeholder*="NIK"]').fill('1234567890');
    await page2.locator('input[placeholder*="password"]').fill('Test123!');
    await page2.locator('button[type="submit"]').click();

    await expect(page2.locator('body')).toContainText('melebihi batas');
    expect(page2.url()).toContain('/');

    await page2.close();
  });
});