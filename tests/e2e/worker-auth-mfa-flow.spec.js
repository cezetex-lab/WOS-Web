/**
 * worker-auth-mfa-flow.spec.js — Worker login → MFA → route access (Q6).
 *
 * Covers the fixed auth flow end-to-end against a mocked backend:
 *  1. Plain worker login → lands on /worker → dynamic routes reachable
 *     (get_enabled_modules returns routes; DynamicRoutes no longer bounces).
 *  2. worker-auth-sync edge function is called with credentials after
 *     login (root-cause fix: provision auth.uid() anchor).
 *  3. MFA-enabled worker: login pauses on the MFA step; after correct
 *     TOTP the user proceeds to /worker and auth-sync runs with the
 *     real credentials (not the old fake 'mfa-sync-<nrp>' path).
 *  4. Wrong TOTP keeps the user on the MFA step with an error.
 *
 * All backend calls are intercepted (mock-supabase.js) — no real
 * credentials needed, deterministic in CI.
 */
import { test, expect } from '@playwright/test';
import {
  mockSupabase,
  loginAsWorker,
  WORKER_LOGIN,
  MOCK_USERS,
} from './helpers/mock-supabase';

const SUPA = process.env.VITE_SUPABASE_URL || 'https://placeholder.supabase.co';
const AUTH_SYNC_URL = `${SUPA}/functions/v1/worker-auth-sync`;

test.describe('L7: Worker login → auth-sync → route access', () => {
  test('plain worker login provisions auth account and dynamic routes stay reachable', async ({ page }) => {
    const authSyncCalls = [];
    // mockSupabase dulu, lalu unroute handler generic-nya dan pasang recorder.
    // Playwright mencocokkan route TERAKHIR yang terdaftar lebih dulu, jadi
    // recorder yang didaftarkan SEBELUM mockSupabase tidak pernah terpakai
    // (kontrak yang didokumentasikan di mock-supabase.js: unroute per-test).
    await mockSupabase(page);
    await page.unroute(AUTH_SYNC_URL);
    await page.route(AUTH_SYNC_URL, async (route) => {
      authSyncCalls.push(route.request().postDataJSON());
      // Provisioned: client signs in via Supabase Auth with temp password
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          ok: true,
          email: 'budi@insightwos.test',
          temp_password: 'mock-temp-pass-1234567890',
          auth_id: MOCK_USERS.worker.id,
        }),
      });
    });

    await loginAsWorker(page);

    // 1) Landed on /worker and dashboard rendered from the (mock) backend.
    await expect(page.getByRole('heading', { name: /Ringkasan Hari Ini/i })).toBeVisible();

    // 2) auth-sync was called exactly once with the login credentials.
    expect(authSyncCalls.length).toBe(1);
    expect(authSyncCalls[0]).toMatchObject({
      nrp: WORKER_LOGIN.nrp,
      nik: WORKER_LOGIN.nik,
    });
    // Password harus dikirim (edge function re-verifies via login_worker).
    expect(authSyncCalls[0].password).toBeTruthy();

    // 3) Dynamic route reachable — no bounce back to /.
    await page.goto('/worker/attendance');
    await expect(page).not.toHaveURL(/localhost:\d+\/$/);
  });

  test('auth-sync failure is non-fatal: login still completes', async ({ page }) => {
    await mockSupabase(page);
    // Ganti handler generic dengan 500 — didaftarkan SETELAH mockSupabase
    // (plus unroute) agar benar-benar menang, bukan ditimpa handler default.
    // Sebelum fix, test ini vacuous: handler generic sukses yang selalu menjawab.
    await page.unroute(AUTH_SYNC_URL);
    await page.route(AUTH_SYNC_URL, async (route) =>
      route.fulfill({ status: 500, contentType: 'application/json', body: JSON.stringify({ ok: false, msg: 'boom' }) })
    );

    await loginAsWorker(page);

    await expect(page.getByRole('heading', { name: /Ringkasan Hari Ini/i })).toBeVisible();
  });
});

test.describe('L7: Worker login with MFA enabled', () => {
  test('MFA-enabled worker pauses at MFA step, then proceeds after valid TOTP', async ({ page }) => {
    const authSyncCalls = [];
    // Sama seperti test pertama: recorder SETELAH mockSupabase (unroute dulu),
    // agar handler generic tidak menimpanya (last-registered-first).
    await mockSupabase(page);
    await page.unroute(AUTH_SYNC_URL);
    await page.route(AUTH_SYNC_URL, async (route) => {
      authSyncCalls.push(route.request().postDataJSON());
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          ok: true,
          email: 'budi@insightwos.test',
          temp_password: 'mock-temp-pass-1234567890',
          auth_id: MOCK_USERS.worker.id,
        }),
      });
    });

    // Enable MFA for this test: the mfa-service 'check' action reports enabled.
    await page.unroute(`${SUPA}/functions/v1/mfa-service`);
    await page.route(`${SUPA}/functions/v1/mfa-service`, async (route) => {
      const body = route.request().postDataJSON();
      if (body.action === 'check') {
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ ok: true, mfa_enabled: true, factor_id: 'f1', label: 'insightWOS' }),
        });
      }
      if (body.action === 'verify_login') {
        // Valid TOTP = '123456' (mock), anything else rejected.
        const ok = body.code === '123456';
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify(ok
            ? { ok: true, mfa_required: true, mfa_verified: true }
            : { ok: false, msg: 'Kode TOTP salah.' }),
        });
      }
      return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ ok: false, msg: 'unknown' }) });
    });

    // Navigate + login manually (loginAsWorker would wait for /worker).
    await page.goto('/');
    await page.locator('input[placeholder*="NRP"]').fill(WORKER_LOGIN.nrp);
    await page.locator('input[placeholder*="NIK"]').fill(WORKER_LOGIN.nik);
    await page.locator('input[placeholder*="password"]').fill(WORKER_LOGIN.password);
    await page.locator('button[type="submit"]').click();

    // MFA step appears (session stored, login paused).
    await expect(page.getByText(/Verifikasi MFA/i)).toBeVisible({ timeout: 15000 });

    // Wrong code → stays on MFA step with error.
    await page.locator('input[placeholder="000000"]').fill('000000');
    await page.getByRole('button', { name: /Verifikasi/i }).click();
    // Error renders in both the global error div and inline form error.
    await expect(page.getByText(/Kode TOTP salah/i).first()).toBeVisible({ timeout: 10000 });
    await expect(page).not.toHaveURL(/\/worker$/);

    // Correct code → proceeds to /worker.
    await page.locator('input[placeholder="000000"]').fill('123456');
    await page.getByRole('button', { name: /Verifikasi/i }).click();
    await page.waitForURL('**/worker', { timeout: 15000 });
    await expect(page.getByRole('heading', { name: /Ringkasan Hari Ini/i })).toBeVisible();

    // auth-sync ran with the real credentials (not the fake mfa-sync path).
    expect(authSyncCalls.length).toBe(1);
    expect(authSyncCalls[0]).toMatchObject({ nrp: WORKER_LOGIN.nrp, nik: WORKER_LOGIN.nik });
  });
});
