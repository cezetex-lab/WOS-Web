/**
 * admin-gated-pages-smoke.spec.ts — smoke E2E 4 halaman admin ter-gate
 * (verifikasi end-to-end migrasi 274 — P1-F14-AA Tahap 1).
 *
 * Tujuan ganda:
 *   A (positif) — admin_pusat TIDAK regresi: halaman render dengan data
 *                 (>0), tanpa "Akses ditolak".
 *   B (negatif) — worker TIDAK membocorkan data: redirect keluar dari route,
 *                 ATAU halaman render dengan data nol. Data (593 entri audit /
 *                 17 node org / 5 divisi) tidak boleh ada di DOM.
 *
 * Route asli diverifikasi ke `module_definitions` LIVE (2026-10-15) — route
 * di-mount dinamis oleh DynamicRoutes, bukan hardcode. Ada alias ganda; path
 * yang dipakai menu/AdminRouteGuard dipilih:
 *   AuditChainPage      -> /admin/chain        (alias: /admin/audit-chain)
 *   OrgChart            -> /admin/org          (alias: /admin/org-chart; menu-builder:132)
 *   OrgSubtree          -> /admin/org-subtree
 *   DivisionsManagement -> /admin/divisions
 *
 * IDENTITAS SKENARIO A — kegagalan run pertama (2026-10-15) TERDIAGNOSIS bukan
 * regresi 274: `.agents/logs/auth-admin-hrd.json` berisi `hrd@insightwos.com`
 * (NRP101, `admin_hrd`) → `useAdminAuth(["admin_pusat"])` redirect ke Home
 * admin. Kontrak halaman butuh `admin_pusat`, jadi skenario A login LIVE
 * sebagai `ADMIN_ACCOUNTS.pusat` (E2E_ADMIN_PUSAT_*) — pola persis
 * admin-payroll.spec.ts. Kuota OTP aplikasi 3/15 menit per NRP → login
 * DILAKUKAN SEKALI di test setup (describe.serial), state di-share ke 4 test.
 *
 * Storage state worker: hasil `setup-auth-state.cjs` (kredensial existing —
 * TIDAK ada kredensial baru). Playwright DI LUAR suite vitest — tidak
 * mengubah hitungan .vitest/test-result.json.
 */
import { test, expect, type Page, type BrowserContext } from '@playwright/test';
import { loginLiveAdmin } from './helpers/live-login';
import { ADMIN_ACCOUNTS, assertAccount, assertOtpBudget } from './helpers/live-accounts';

const BASE = process.env.TEST_BASE_URL || 'http://localhost:5173';
const WORKER_STATE = '.agents/logs/auth-worker.json';
const LIVE_ADMIN = ADMIN_ACCOUNTS.pusat;

const ROUTE = {
  audit: '/admin/chain',
  org: '/admin/org',
  subtree: '/admin/org-subtree',
  divisions: '/admin/divisions',
} as const;

/** Dialog consent bisa muncul bila state tidak memuat wos_privacy_consent. */
async function dismissConsent(page: Page): Promise<void> {
  const consent = page.locator('div[role="dialog"] button:has-text("Saya Setuju")').first();
  try {
    await consent.waitFor({ state: 'visible', timeout: 5000 });
    await consent.click();
    await page.waitForTimeout(300);
  } catch {
    /* tidak muncul — lanjut */
  }
}

// ────────────────────────────────────────────────────────────────────────────
// A — admin_pusat (positif): tidak regresi karena migrasi 274
// Login LIVE sekali (kuota OTP 3/15 menit per NRP) → state di-share.
// ────────────────────────────────────────────────────────────────────────────
test.describe.serial('A admin_pusat — 4 halaman ter-gate tidak regresi', () => {
  let adminState: Awaited<ReturnType<BrowserContext['storageState']>> | undefined;

  test('setup: login admin_pusat sekali (password → OTP dev)', async ({ browser }) => {
    test.setTimeout(10 * 60_000);
    assertOtpBudget();
    assertAccount(LIVE_ADMIN, 'pusat');
    const ctx = await browser.newContext();
    const page = await ctx.newPage();
    try {
      const otpWaits = await loginLiveAdmin(page, LIVE_ADMIN);
      console.log(`[A setup] login admin_pusat ok, otpWaits=${otpWaits}`);
      expect(new URL(page.url()).pathname).toContain('/admin');
      adminState = await ctx.storageState();
    } finally {
      await ctx.close();
    }
    expect(adminState, 'storage state admin_pusat harus ter-capture').toBeTruthy();
  });

  test('audit chain (/admin/chain): data tampil, tanpa Akses ditolak', async ({ browser }) => {
    expect(adminState, 'setup login harus lulus dulu (describe.serial)').toBeTruthy();
    const ctx = await browser.newContext({ storageState: adminState });
    const page = await ctx.newPage();
    try {
      await page.goto(BASE + ROUTE.audit);
      const sub = page.getByText(/\d+ entri tercatat/).first();
      await expect(sub).toBeVisible({ timeout: 45000 });
      const m = (await sub.innerText()).match(/(\d+) entri tercatat/);
      expect(m, 'subtitle "N entri tercatat" harus terbaca').not.toBeNull();
      expect(Number(m![1]), 'entri audit > 0').toBeGreaterThan(0);
      await expect(page.locator('table tbody tr').first()).toBeVisible({ timeout: 20000 });
      await expect(page.getByText('Akses ditolak')).toHaveCount(0);
      console.log(`[A audit] ${m![1]} entri tercatat, table rows > 0, tanpa Akses ditolak`);
    } finally {
      await ctx.close();
    }
  });

  test('org chart (/admin/org): tree tampil dengan karyawan > 0', async ({ browser }) => {
    expect(adminState, 'setup login harus lulus dulu (describe.serial)').toBeTruthy();
    const ctx = await browser.newContext({ storageState: adminState });
    const page = await ctx.newPage();
    try {
      await page.goto(BASE + ROUTE.org);
      const sub = page.getByText(/^\s*\d+\s+karyawan\s*$/).first();
      await expect(sub).toBeVisible({ timeout: 45000 });
      const m = (await sub.innerText()).match(/(\d+)\s+karyawan/);
      expect(m, 'subtitle "N karyawan" harus terbaca').not.toBeNull();
      expect(Number(m![1]), 'karyawan org > 0').toBeGreaterThan(0);
      await expect(page.getByText('Tidak ada data organisasi')).toHaveCount(0);
      await expect(page.getByText('Akses ditolak')).toHaveCount(0);
      console.log(`[A org] ${m![1]} karyawan, tree tampil, tanpa Akses ditolak`);
    } finally {
      await ctx.close();
    }
  });

  test('org subtree (/admin/org-subtree): node tampil > 0', async ({ browser }) => {
    expect(adminState, 'setup login harus lulus dulu (describe.serial)').toBeTruthy();
    const ctx = await browser.newContext({ storageState: adminState });
    const page = await ctx.newPage();
    try {
      await page.goto(BASE + ROUTE.subtree);
      const sub = page.getByText(/^\s*\d+\s+node\s*$/).first();
      await expect(sub).toBeVisible({ timeout: 45000 });
      const m = (await sub.innerText()).match(/(\d+)\s+node/);
      expect(m, 'subtitle "N node" harus terbaca').not.toBeNull();
      expect(Number(m![1]), 'node org > 0').toBeGreaterThan(0);
      await expect(page.getByText('Tidak ada data organisasi')).toHaveCount(0);
      await expect(page.getByText('Akses ditolak')).toHaveCount(0);
      console.log(`[A subtree] ${m![1]} node, tree tampil, tanpa Akses ditolak`);
    } finally {
      await ctx.close();
    }
  });

  test('divisions (/admin/divisions): divisi + karyawan tampil > 0', async ({ browser }) => {
    expect(adminState, 'setup login harus lulus dulu (describe.serial)').toBeTruthy();
    const ctx = await browser.newContext({ storageState: adminState });
    const page = await ctx.newPage();
    try {
      await page.goto(BASE + ROUTE.divisions);
      const sub = page.getByText(/\d+\s+divisi,\s+\d+\s+karyawan/).first();
      await expect(sub).toBeVisible({ timeout: 45000 });
      const m = (await sub.innerText()).match(/(\d+)\s+divisi,\s+(\d+)\s+karyawan/);
      expect(m, 'subtitle "X divisi, Y karyawan" harus terbaca').not.toBeNull();
      expect(Number(m![1]), 'jumlah divisi > 0').toBeGreaterThan(0);
      expect(Number(m![2]), 'jumlah karyawan > 0').toBeGreaterThan(0);
      await expect(page.getByText('Akses ditolak')).toHaveCount(0);
      console.log(`[A divisions] ${m![1]} divisi, ${m![2]} karyawan, tanpa Akses ditolak`);
    } finally {
      await ctx.close();
    }
  });
});

// ────────────────────────────────────────────────────────────────────────────
// B — worker (negatif): tidak ada data yang bocor ke DOM
// Skenario diterima bila SALAH SATU: (1) redirect keluar dari route, atau
// (2) halaman render dengan data nol (marker "0 …" / empty state).
// ────────────────────────────────────────────────────────────────────────────
test.describe('B worker — tidak ada kebocoran data di 4 halaman', () => {
  test.use({ storageState: WORKER_STATE });

  /**
   * Menunggu halaman menetap: redirect keluar dari `route`, atau tetap di
   * route. Mengembalikan path akhir + body text bila masih di route target.
   */
  async function settleAtOrAway(page: Page, route: string): Promise<{ path: string; body: string }> {
    let path = new URL(page.url()).pathname;
    if (path === route) {
      try {
        await page.waitForURL((u) => new URL(u).pathname !== route, { timeout: 25000 });
      } catch {
        /* tetap di route — biarkan pengecekan data di bawah yang menilai */
      }
      path = new URL(page.url()).pathname;
    }
    const body = path === route ? await page.locator('body').innerText() : '';
    return { path, body };
  }

  test('audit chain: redirect ATAU 0 entri — 593 baris tidak boleh di DOM', async ({ page }) => {
    await dismissConsent(page);
    await page.goto(BASE + ROUTE.audit);
    const { path } = await settleAtOrAway(page, ROUTE.audit);
    if (path === ROUTE.audit) {
      // Halaman render: data wajib nol (loading selesai → subtitle/empty state).
      await expect(
        page.getByText(/0 entri tercatat/).or(page.getByText('Tidak ada entri audit'))
      ).toBeVisible({ timeout: 45000 });
      const settled = await page.locator('body').innerText();
      expect(settled, 'angka entri audit > 0 BOCOR di DOM').not.toMatch(/[1-9]\d*\s+entri tercatat/);
      console.log('[B audit] tetap di route, 0 entri — tidak bocor');
    } else {
      expect(path, 'worker di-redirect keluar dari route audit').not.toBe(ROUTE.audit);
      console.log(`[B audit] redirect ke ${path} — tidak bocor`);
    }
  });

  test('org chart: redirect ATAU 0 karyawan — 17 nama tidak boleh di DOM', async ({ page }) => {
    await dismissConsent(page);
    await page.goto(BASE + ROUTE.org);
    const { path } = await settleAtOrAway(page, ROUTE.org);
    if (path === ROUTE.org) {
      await expect(
        page.getByText(/0\s+karyawan/).or(page.getByText('Tidak ada data organisasi'))
      ).toBeVisible({ timeout: 45000 });
      const settled = await page.locator('body').innerText();
      expect(settled, 'subtitle karyawan > 0 BOCOR di DOM').not.toMatch(/(^|\s)[1-9]\d*\s+karyawan/m);
      console.log('[B org] tetap di route, 0 karyawan — tidak bocor');
    } else {
      expect(path, 'worker di-redirect keluar dari route org').not.toBe(ROUTE.org);
      console.log(`[B org] redirect ke ${path} — tidak bocor`);
    }
  });

  test('org subtree: redirect ATAU 0 node — 17 node tidak boleh di DOM', async ({ page }) => {
    await dismissConsent(page);
    await page.goto(BASE + ROUTE.subtree);
    const { path } = await settleAtOrAway(page, ROUTE.subtree);
    if (path === ROUTE.subtree) {
      await expect(
        page.getByText(/\b0\s+node\b/).or(page.getByText('Tidak ada data organisasi'))
      ).toBeVisible({ timeout: 45000 });
      const settled = await page.locator('body').innerText();
      expect(settled, 'subtitle node > 0 BOCOR di DOM').not.toMatch(/(^|\s)[1-9]\d*\s+node\b/m);
      console.log('[B subtree] tetap di route, 0 node — tidak bocor');
    } else {
      expect(path, 'worker di-redirect keluar dari route subtree').not.toBe(ROUTE.subtree);
      console.log(`[B subtree] redirect ke ${path} — tidak bocor`);
    }
  });

  test('divisions: redirect ATAU 0 divisi/0 karyawan — 5 divisi tidak boleh di DOM', async ({ page }) => {
    await dismissConsent(page);
    await page.goto(BASE + ROUTE.divisions);
    const { path } = await settleAtOrAway(page, ROUTE.divisions);
    if (path === ROUTE.divisions) {
      await expect(
        page.getByText('0 divisi, 0 karyawan').or(page.getByText(/0\s+divisi/))
      ).toBeVisible({ timeout: 45000 });
      const settled = await page.locator('body').innerText();
      expect(settled, 'subtitle karyawan > 0 BOCOR di DOM').not.toMatch(/(^|\s)[1-9]\d*\s+karyawan/m);
      // kartu divisi "karyawan • N departemen" = penanda data
      await expect(page.getByText(/karyawan\s+•\s+\d+\s+departemen/)).toHaveCount(0);
      console.log('[B divisions] tetap di route, 0 divisi/0 karyawan — tidak bocor');
    } else {
      expect(path, 'worker di-redirect keluar dari route divisions').not.toBe(ROUTE.divisions);
      console.log(`[B divisions] redirect ke ${path} — tidak bocor`);
    }
  });
});
