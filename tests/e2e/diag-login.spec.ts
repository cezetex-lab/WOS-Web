import { test, expect } from '@playwright/test';
import type { Page } from '@playwright/test';
import { clickStable, fillAdminOtp, fillStable, openHome } from './helpers/live-login';
import { ADMIN_ACCOUNTS, assertAccount, assertOtpBudget, type IdentityKey, type LiveAccount } from './helpers/live-accounts';

// Live-backend diagnostic: uses real credentials against a running deployment.
// Opt in with E2E_LIVE=1 so the default suite stays hermetic (mocked) and green.
test.skip(!process.env.E2E_LIVE, 'Live diagnostic — set E2E_LIVE=1 and TEST_BASE_URL to run');

const BASE = process.env.TEST_BASE_URL || 'http://localhost:5173';

/**
 * Kredensial: utamakan env (.env.local), fallback literal akun uji.
 * Nilai TIDAK PERNAH ditulis di nama test — dulu judul test memuat password
 * literal sehingga ikut tercetak ke reporter/log (diperbaiki 2026-09-24).
 */
// Nilai HANYA dari env — tidak ada password literal di repo (sebelumnya memuat
// password worker asli sehingga ikut ter-commit bila berkas ini di-stage).
// Identitas worker KHUSUS diag-login (E2E_WORKER_DIAG_*, di-seed dari akun.txt).
// Sebelumnya memakai E2E_WORKER_* (NRP008) yang dipakai 5 konsumen sekaligus →
// login paralel beradu pada satu NRP (temuan RUN 2).
const W_ENV = {
  label: 'diag (env)',
  nrp: process.env.E2E_WORKER_DIAG_NRP ?? '',
  nik: process.env.E2E_WORKER_DIAG_NIK ?? '',
  pass: process.env.E2E_WORKER_DIAG_PASS ?? '',
};
// Dua kasus JALUR GAGAL memakai NRP YANG TIDAK TERDAFTAR — bukan akun uji asli.
// Alasan (temuan 2026-09-25): percobaan password salah pada akun asli menaikkan
// `worker_passwords.attempts` sampai "Akun diblokir sementara" → efek samping ke DB
// live. Dengan NRP fiktif, RPC mengembalikan `{"ok":false,"msg":"NRP/NIK tidak
// ditemukan"}` TANPA menyentuh akun siapa pun.
const W_LEGACY = [
  { label: 'NRP tidak terdaftar (a)', nrp: 'NRP9991', nik: '9999000000000001', pass: 'not-a-secret' },
  { label: 'NRP tidak terdaftar (b)', nrp: 'NRP9992', nik: '9999000000000002', pass: 'not-a-secret' },
];

/**
 * Identitas admin disebar per konsumen (≤2 OTP per identitas per run) — kontraknya
 * ada di helpers/live-accounts.ts (OTP_ASSIGNMENT). Di sini dipakai identitas yang
 * TIDAK dipakai spec lain supaya hrd/pusat/ceo/operasional tidak kehabisan kuota:
 * diag-login:admin → mining, mill, estate, finance.
 */
const ADMIN_CASES: Array<{ key: IdentityKey; label: string; acct: LiveAccount }> = [
  { key: 'mining', label: 'mining', acct: ADMIN_ACCOUNTS.mining },
  { key: 'mill', label: 'mill', acct: ADMIN_ACCOUNTS.mill },
  { key: 'estate', label: 'estate', acct: ADMIN_ACCOUNTS.estate },
  { key: 'finance', label: 'finance', acct: ADMIN_ACCOUNTS.finance },
];

const bodyLen = async (page: Page) => ((await page.textContent('body').catch(() => '')) ?? '').length;

async function adaToken(page: Page) {
  return page.evaluate(() => {
    try {
      return !!JSON.parse(sessionStorage.getItem('wos_user_v2') || 'null');
    } catch {
      return false;
    }
  });
}

/** Worker NRP-mode: asersi form + asersi RPC login benar-benar dipanggil. */
async function diagWorker(
  page: Page,
  cred: { label: string; nrp: string; nik: string; pass: string },
  expectSuccess: boolean,
) {
  const rpc: string[] = [];
  // Diagnosa aman: hanya `ok` + `msg` aplikasi yang dicatat (TIDAK pernah token).
  let rpcMsg: string | null = null;
  let rpcMsgText = '';
  page.on('response', async (r) => {
    if (!r.url().includes('/rpc/login_worker')) return;
    rpc.push(String(r.status()));
    if (rpcMsg === null) {
      try {
        const j = (await r.json()) as { ok?: boolean; msg?: string };
        rpcMsgText = String(j?.msg ?? '');
        rpcMsg = j?.ok === true ? 'ok' : `ok=false msg="${rpcMsgText.slice(0, 120)}"`;
      } catch {
        rpcMsg = 'body-non-json';
      }
    }
  });

  await openHome(page, 60000);
  await clickStable(page.locator('button', { hasText: 'Pekerja' }).first());

  // Tab Pekerja default = mode EMAIL; field NRP muncul setelah toggle ini.
  await expect(page.locator('input[placeholder*="email"]')).toBeVisible({ timeout: 20000 });
  await clickStable(page.getByText('Masuk dengan NRP').first());

  // ── ASERSI 1: form NRP (NRP + NIK + password) benar-benar dirender ───────────
  await expect(page.locator('input[placeholder*="NRP"]')).toBeVisible({ timeout: 20000 });
  await expect(page.locator('input[placeholder*="NIK"]')).toBeVisible();
  await expect(page.locator('input[placeholder*="password"]')).toBeVisible();

  // fillStable: re-render bisa menyapu nilai form setelah `fill()` → server menilai
  // kredensial salah. Isi ulang sampai nilainya benar-benar menempel.
  await fillStable(page.locator('input[placeholder*="NRP"]'), cred.nrp);
  await fillStable(page.locator('input[placeholder*="NIK"]'), cred.nik);
  await fillStable(page.locator('input[placeholder*="password"]'), cred.pass);
  await clickStable(page.locator('button[type="submit"]').first());

  // ── ASERSI 2: submit benar-benar memanggil RPC login_worker ─────────────────
  await expect
    .poll(() => rpc.length, { timeout: 30000, message: 'submit harus memanggil RPC login_worker' })
    .toBeGreaterThan(0);
  await page.waitForTimeout(1500);

  const url = page.url();
  const hasToken = await adaToken(page);
  console.log(
    `[diag] worker ${cred.label}: url=${url} token=${hasToken} rpc=${rpc.join('/')} msg=${rpcMsg ?? '-'}`,
  );

  // ── ASERSI 3: halaman tetap ter-render (bukan blank / ErrorBoundary) ────────
  expect(await bodyLen(page), 'halaman tidak boleh blank').toBeGreaterThan(80);

  if (expectSuccess) {
    expect(hasToken, `login ${cred.label} (kredensial env) harus berhasil`).toBe(true);
    expect(url).toContain('/worker');
  } else {
    // ── ASERSI 3b: jalur GAGAL benar-benar terlihat (bukan senyap) ────────────
    expect(rpc, 'submit tetap harus memanggil RPC login_worker').toContain('200');
    expect(hasToken, 'kredensial tidak valid tidak boleh menghasilkan sesi').toBe(false);
    // Home.tsx:220 menampilkan `d.msg` dari RPC apa adanya → asersi ini mengikat
    // UI ke alasan yang benar-benar dikembalikan server (bukan redaksi tertentu).
    expect(rpcMsgText, 'RPC harus mengembalikan alasan kegagalan').not.toBe('');
    await expect(page.locator('body')).toContainText(rpcMsgText);
  }
}

/** Admin 2 langkah: password → OTP dev-mode → /admin. */
async function diagAdmin(page: Page, label: string, acct: LiveAccount) {
  assertAccount(acct, label as IdentityKey);
  const rpc: string[] = [];
  page.on('response', (r) => {
    // OTP admin dibuat lewat EDGE password-reset (bukan RPC generate_admin_otp).
    if (r.url().includes('/functions/v1/password-reset')) rpc.push('otp_edge');
    if (r.url().includes('/rpc/verify_admin_otp')) rpc.push('verify');
    if (r.url().includes('/auth/v1/token')) rpc.push('auth' + r.status());
  });

  await openHome(page, 60000);
  await clickStable(page.locator('button', { hasText: 'Admin' }).first());

  // ── ASERSI 1: form admin ter-render ────────────────────────────────────────
  await expect(page.locator('input[type="email"]')).toBeVisible({ timeout: 20000 });
  await page.locator('input[type="email"]').fill(acct.email);
  await page.locator('form input').nth(1).fill(acct.pass);
  await clickStable(page.locator('form button[type="submit"]').first());

  // Helper menunggu langkah OTP; bila aplikasi menjawab "Terlalu banyak request OTP",
  // ia menunggu SATU jendela bersih lalu mengirim ulang SEKALI (bukan spam).
  const otpWaits = await fillAdminOtp(page, 45000);
  await page
    .waitForFunction(() => window.location.pathname.startsWith('/admin'), undefined, { timeout: 30000 })
    .catch(() => {});

  const url = page.url();
  const hasToken = await adaToken(page);
  console.log(
    `[diag] admin ${label}: url=${url} token=${hasToken} otpWaits=${otpWaits} rpc=${rpc.join('/')}`,
  );

  // ── ASERSI 2: OTP benar ⇒ sesi admin aktif di /admin ───────────────────────
  expect(rpc, 'OTP admin harus dibuat via edge password-reset').toContain('otp_edge');
  expect(rpc, 'verify_admin_otp harus terpanggil').toContain('verify');
  expect(hasToken, `OTP ${label} harus menghasilkan sesi`).toBe(true);
  expect(url).toContain('/admin');
  expect(await bodyLen(page)).toBeGreaterThan(80);
}

test.beforeAll(() => {
  // Kontrak sebaran OTP: gagal cepat bila ada identitas yang dipakai >2x per run.
  assertOtpBudget();
});

test('Worker login NRP-mode (env) — form NRP tampil + login berhasil', async ({ page }) => {
  // Anggaran lebih longgar dari 90 s bawaan: pada dev-server yang melambat, langkah
  // openHome + pengisian aman tetap perlu ruang (RUN 4: test ini kena 90 s).
  test.setTimeout(150_000);
  await diagWorker(page, W_ENV, true);
});

for (const cred of W_LEGACY) {
  test(`Worker ${cred.label} — form NRP tampil + alasan gagal dari server`, async ({ page }) => {
    test.setTimeout(150_000);
    await diagWorker(page, cred, false);
  });
}

for (const { key, label, acct } of ADMIN_CASES) {
  test(`Admin ${label} — password → OTP → /admin`, async ({ page }) => {
    // Satu tunggu jendela rate-limit (6 menit) + alur login masih di bawah 15 menit.
    test.setTimeout(10 * 60_000);
    await diagAdmin(page, key, acct);
  });
}
