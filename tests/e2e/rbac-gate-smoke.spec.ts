/**
 * rbac-gate-smoke.spec.ts — smoke E2E matriks RBAC pasca-migrasi 276–279.
 *
 * Tujuan: buktikan TIDAK ada regresi blank-screen setelah gate in-body 278/279
 * (17 RPC) + konversi 5 fungsi `LANGUAGE sql` → plpgsql, dan matriks role
 * berjalan sesuai kontrak `useAdminAuth` per halaman:
 *
 *   1. admin_pusat  (NRP100) → /admin/budget (admin_get_budget),
 *                              /admin/kpi     (admin_get_kpi_trend)  — render
 *   2. admin_hrd    (NRP101) → /admin/employees (admin_get_employees),
 *                              /admin/leave     (admin_get_leave)    — render
 *   3. admin_finance(NRP102) → /admin/budget                        — render
 *   4. worker       (NRP008) → /worker/career   (get_career_path — scope-by-NRP 276)
 *                              /worker/facility (admin_get_facility_requests —
 *                              RPC KARANTINA P2-F14-BU, TANPA gate: worker HARUS
 *                              tetap bisa akses, tidak 42501)
 *
 * IDENTITAS: storage state hasil `.agents/scripts/m280-gen-states.cjs`
 * (login UI sekali, di luar spec — kuota OTP 1x per identitas admin; limit
 * aplikasi 3/15 menit per NRP). Worker = NRP008 (E2E_WORKER_* resmi; NRP002
 * password akun.txt basi — deviasi tercatat di entri log).
 *
 * PENTING — baseURL: config Playwright memakai 5173, tapi port itu kini diisi
 * dev server proyek LAIN (D:\0-SSW). Spec ini selalu `goto(BASE + path)` dengan
 * BASE dari TEST_BASE_URL (default 5174 saat run smoke ini) supaya tidak pernah
 * mendarat di aplikasi lain. Jalankan:
 *   TEST_BASE_URL=http://localhost:5174 npx playwright test tests/e2e/rbac-gate-smoke.spec.ts
 */
import { test, expect, type Page } from '@playwright/test';

const BASE = process.env.TEST_BASE_URL || 'http://localhost:5173';

const STATE = {
  pusat: '.agents/logs/auth-rbac-pusat.json',
  hrd: '.agents/logs/auth-rbac-hrd.json',
  finance: '.agents/logs/auth-rbac-finance.json',
  worker: '.agents/logs/auth-rbac-worker.json',
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

/** Buka halaman + pastikan tidak blank, tidak error boundary, tidak "Akses ditolak". */
async function expectRender(page: Page, path: string, marker: RegExp): Promise<void> {
  await page.goto(BASE + path);
  await dismissConsent(page);
  // Marker halaman terbaca (bukan blank screen).
  await expect(page.getByText(marker).first(), `marker ${marker} di ${path}`).toBeVisible({ timeout: 45000 });
  // Tidak ada penolakan authz yang bocor ke UI.
  await expect(page.getByText('Akses ditolak'), `Akses ditolak di ${path}`).toHaveCount(0);
  // Tidak ada crash ErrorBoundary.
  await expect(page.getByText(/Something went wrong|Terjadi kesalahan/i)).toHaveCount(0);
}

// ────────────────────────────────────────────────────────────────────────────
// 1 — admin_pusat (NRP100): budget + kpi lolos gate 278 (role target pusat)
// ────────────────────────────────────────────────────────────────────────────
test.describe.serial('1 admin_pusat — /admin/budget + /admin/kpi render', () => {
  test.use({ storageState: STATE.pusat });

  test('budget (admin_get_budget) render dengan subtotal budget', async ({ page }) => {
    await expectRender(page, '/admin/budget', /Budget Allocation/);
    await expect(page.getByText(/Total budget:/)).toBeVisible({ timeout: 20000 });
  });

  test('kpi (admin_get_kpi_trend) render judul KPI', async ({ page }) => {
    await expectRender(page, '/admin/kpi', /^\s*KPI\s*$/);
  });
});

// ────────────────────────────────────────────────────────────────────────────
// 2 — admin_hrd (NRP101): employees + leave lolos gate (role target hrd)
// ────────────────────────────────────────────────────────────────────────────
test.describe.serial('2 admin_hrd — /admin/employees + /admin/leave render', () => {
  test.use({ storageState: STATE.hrd });

  test('employees (admin_get_employees 273) render daftar karyawan', async ({ page }) => {
    await expectRender(page, '/admin/employees', /Kelola data seluruh karyawan/);
  });

  test('leave (admin_get_leave 278, plpgsql) render Manajemen Cuti', async ({ page }) => {
    await expectRender(page, '/admin/leave', /Manajemen Cuti/);
  });
});

// ────────────────────────────────────────────────────────────────────────────
// 3 — admin_finance (NRP102): budget lolos gate (role target finance)
// ────────────────────────────────────────────────────────────────────────────
test.describe.serial('3 admin_finance — /admin/budget render', () => {
  test.use({ storageState: STATE.finance });

  test('budget (admin_get_budget) render — finance termasuk role target', async ({ page }) => {
    await expectRender(page, '/admin/budget', /Budget Allocation/);
  });
});

// ────────────────────────────────────────────────────────────────────────────
// 4 — worker: career (scope-by-NRP 276) + facility (karantina BU — TANPA gate)
// ────────────────────────────────────────────────────────────────────────────
test.describe.serial('4 worker — /worker/career + /worker/facility render', () => {
  test.use({ storageState: STATE.worker });

  test('career (get_career_path, scope-by-NRP 276) render data miliknya', async ({ page }) => {
    await expectRender(page, '/worker/career', /Karir Saya/);
  });

  test('facility (admin_get_facility_requests — karantina BU) tetap TERBUKA utk worker', async ({ page }) => {
    // RPC karantina TIDAK digate 278/279 — worker HARUS tetap bisa memuat halaman
    // ini tanpa 42501 (bukti UI dari probe DB: worker NRP002/NRP008 → ok:true).
    const rpcErrors: number[] = [];
    page.on('response', (r) => {
      if (r.url().includes('admin_get_facility_requests') && r.status() >= 400) rpcErrors.push(r.status());
    });
    await expectRender(page, '/worker/facility', /Ajukan Request/);
    expect(rpcErrors, 'admin_get_facility_requests tidak boleh error HTTP utk worker').toEqual([]);
  });
});