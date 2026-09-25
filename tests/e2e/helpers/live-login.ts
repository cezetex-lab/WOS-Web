/**
 * live-login.ts — helper login BACKEND LIVE (bukan mock) untuk spec opt-in.
 *
 * Prinsip:
 *   * TIDAK menyimpan/mencetak kredensial — dibaca dari env (.env.local / akun.txt).
 *   * Admin/Dashboard login DUA LANGKAH (password → OTP). OTP dev-mode dibaca dari UI.
 *   * Tunggu `get_branding` selesai sebelum mengisi form. Ditemukan 2026-09-24:
 *     klik submit saat branding masih dimuat ditelan re-render → form ter-reset
 *     tanpa satu pun panggilan API (flaky ~50%).
 *   * OTP dibatasi aplikasi: 3 per 15 menit per NRP (edge `password-reset`
 *     → hitRateLimit('login_otp')). Sebaran identitas ada di helpers/live-accounts.ts
 *     (satu identitas per konsumen) — helper di sini HANYA menyediakan satu tunggu
 *     cadangan dan TIDAK pernah mengirim ulang submit berulang kali.
 *
 * PERUBAHAN 2026-09-25 (bukti RUN 1: `otp_edge` 4x tanpa satu pun `verify`):
 *   Versi lama meng-KLIK SUBMIT ULANG setiap siklus tunggu. Setiap klik membuat
 *   request OTP BARU → kuota 3/15 menit justru habis oleh helper sendiri, dan
 *   full-sweep Dashboard butuh 776 detik (12 menit menunggu) lalu tetap gagal.
 *   Versi baru: maksimum SATU tunggu (6 menit) + SATU kirim ulang, sisanya hanya
 *   menunggu input OTP muncul (kegagalan jadi cepat & jelas, bukan spam).
 */
import fs from 'node:fs';
import path from 'node:path';
import { expect } from '@playwright/test';
import type { Locator, Page } from '@playwright/test';
import type { LiveAccount } from './live-accounts';

const OTP_LIMIT_RE = /Terlalu banyak request OTP/i;
const OTP_WAIT_MS = 6 * 60_000;
const MAX_OTP_WAITS = 1;
const WAIT_LOG = path.join(process.cwd(), '.agents', 'logs', 'e2e-otp-wait.log');

function logOtpWait(message: string): void {
  const line = `[${new Date().toISOString()}] ${message}\n`;
  try {
    fs.mkdirSync(path.dirname(WAIT_LOG), { recursive: true });
    fs.appendFileSync(WAIT_LOG, line);
  } catch {
    /* logging tidak boleh menggagalkan test */
  }
  console.log(`[otp-wait] ${message}`);
}

/** Buka halaman login: tunggu branding settle + tangani dialog consent. */
export async function openHome(page: Page, timeout = 30_000): Promise<void> {
  // OPS-06b follow-up: pre-seed consent SEBELUM app mount (pola yang sama dipakai
  // mock-supabase.ts:409 dan `addInitScript` di helper a11y). Dialog PrivacyConsent
  // (z-[9999]) render ASYNC — menunggu dengan jendela tetap kalah saat dev server
  // lambat, lalu modal memblokir SETIAP klik (trace 2026-09-25:
  // "…aria-label='Persetujuan Privasi'… intercepts pointer events").
  await page.addInitScript(() => {
    try { localStorage.setItem('wos_privacy_consent', 'true'); } catch { /* ignore */ }
  });
  // Listener HARUS dipasang SEBELUM goto: kalau after, respons get_branding yang
  // sudah datang saat navigasi terlewat dan kita menunggu sia-sia (race).
  // Bukti trace 2026-09-25: 7,0 s terbuang hanya untuk waitForResponse ini.
  const branding = page.waitForResponse((r) => r.url().includes('/rpc/get_branding'), { timeout: 8_000 }).catch(() => null);
  await page.goto('/', { waitUntil: 'domcontentloaded' });
  await branding;
  const consent = page.locator('div[role="dialog"] button:has-text("Saya Setuju")').first();
  try {
    // Pre-seed consent kini andal → hanya tutup bila SUDAH terlihat (bukan tunggu 5 s
    // sia-sia; trace 2026-09-25: 5,0 s terbuang karena dialog tidak pernah muncul).
    await consent.waitFor({ state: 'visible', timeout: 1_000 });
    await consent.click();
  } catch {
    /* pre-seed sudah menutupnya — jaring pengaman saja */
  }
  // Sisa request (check_login_lockout, modul, dsb.) juga memicu re-render yang bisa
  // MENYAPU nilai form setelah diisi → server menerima password kosong dan membalas
  // 200 `ok:false "Password salah"` (penyebab FLAKY worker di RUN 2). Tunggu tenang
  // dulu; dibatasi supaya tidak menggantung.
  await page.waitForLoadState('networkidle', { timeout: 10_000 }).catch(() => {});
}

/**
 * Klik yang tahan terhadap re-render/animasi. Playwright menuntut elemen "stable"
 * (bounding box tetap 2 frame); saat halaman masih fade-in/mount ulang, satu klik
 * bisa menunggu melewati batas aksi lalu gagal — padahal percobaan berikutnya berhasil
 * (bukti RUN 5: `locator('button', { hasText: 'Pekerja' })` timeout 15 s, retry lolos).
 * Di sini klik dicoba ulang dalam anggaran waktu yang eksplisit.
 */
export async function clickStable(locator: Locator, timeout = 30_000): Promise<void> {
  const deadline = Date.now() + timeout;
  let lastErr: unknown = new Error('clickStable: tidak pernah dicoba');
  while (Date.now() < deadline) {
    try {
      await locator.click({ timeout: 8_000 });
      return;
    } catch (e) {
      lastErr = e;
      // Self-heal: consent modal (z-[9999]) memblokir klik — tutup dulu sebelum retry.
      const page = locator.page();
      if (page.isClosed()) throw lastErr; // context mati: retry buta tidak berguna
      const consent = page.locator('div[role="dialog"] button:has-text("Saya Setuju")').first();
      if (await consent.isVisible().catch(() => false)) {
        await consent.click({ timeout: 3_000 }).catch(() => {});
      }
      await page.waitForTimeout(400).catch(() => {});
    }
  }
  throw lastErr;
}

/**
 * Isi field sampai nilainya BENAR-BENAR menempel. `locator.fill()` sekali saja tidak
 * cukup bila form ter-render ulang (branding/consent/networkidle terlambat) — nilai
 * bisa hilang sebelum submit sehingga server menilai kredensial salah.
 */
export async function fillStable(locator: Locator, value: string, timeout = 20_000): Promise<void> {
  // `timeout` juga diberikan ke fill()/inputValue(): tanpa itu, actionTimeout bawaan
  // Playwright (0 = tanpa batas) membuat satu `fill()` pada elemen yang belum siap
  // menunggu sampai test timeout — lebih lama daripada timeout poll itu sendiri.
  const perAction = Math.max(2_000, Math.min(15_000, timeout));
  await expect
    .poll(
      async () => {
        await locator.fill(value, { timeout: perAction }).catch(() => {});
        return locator.inputValue({ timeout: perAction }).catch(() => '');
      },
      { timeout, message: `field tidak bisa diisi stabil (nilai "${value.length} chars" hilang terus)` },
    )
    .toBe(value);
}

/** Kode OTP 6 digit yang dirender dev-mode di UI (diisikan, tidak dicetak). */
export async function readOtpFromUi(page: Page, timeout = 30_000): Promise<string> {
  const body = page.locator('body');
  await expect
    .poll(async () => /Kode OTP[^0-9]{0,160}(\d{6})/i.test(await body.innerText().catch(() => '')), {
      timeout,
      message: 'Kode OTP dev-mode tidak muncul di UI',
    })
    .toBe(true);
  const m = /Kode OTP[^0-9]{0,160}(\d{6})/i.exec(await body.innerText());
  if (!m) throw new Error('Kode OTP dev-mode tidak ditemukan di UI');
  return m[1];
}

/**
 * Tunggu langkah OTP lalu isi. Bila yang muncul justru pesan rate-limit, tunggu
 * SATU jendela bersih (6 menit) dan kirim ulang TEPAT SEKALI — bukan tiap siklus,
 * karena setiap klik submit memesan OTP baru dan justru menghabiskan kuota.
 * Mengembalikan jumlah tunggu (untuk pelaporan).
 */
export async function fillAdminOtp(page: Page, timeout = 45_000): Promise<number> {
  const otpInput = page.locator('input[placeholder="000000"]').first();
  const limiter = page.getByText(OTP_LIMIT_RE).first();
  const submit = page.locator('form button[type="submit"]').first();
  let otpWaits = 0;

  for (let cycle = 0; cycle <= MAX_OTP_WAITS; cycle++) {
    // Tunggu salah satu: input OTP muncul ATAU pesan limiter. (Bukan sleep+klik.)
    const outcome = await Promise.race([
      otpInput
        .waitFor({ state: 'visible', timeout })
        .then(() => 'otp' as const)
        .catch(() => 'none' as const),
      limiter
        .waitFor({ state: 'visible', timeout })
        .then(() => 'limit' as const)
        .catch(() => 'none' as const),
    ]);

    if (outcome === 'otp') {
      await otpInput.fill(await readOtpFromUi(page, timeout));
      await submit.click();
      return otpWaits;
    }

    if (outcome === 'limit') {
      if (otpWaits >= MAX_OTP_WAITS) break;
      otpWaits += 1;
      logOtpWait(
        `rate limit OTP (siklus ${cycle + 1}) → tunggu ${OTP_WAIT_MS / 60_000} menit lalu kirim ulang SEKALI`,
      );
      await page.waitForTimeout(OTP_WAIT_MS);
      await submit.click().catch(() => {});
      continue;
    }

    // Bukan OTP & bukan limiter: klik submit pertama kemungkinan hilang saat
    // re-render branding. Kirim ulang TEPAT SEKALI (bukan berulang).
    if (cycle === 0) {
      await submit.click().catch(() => {});
      continue;
    }
    break;
  }

  const body = await page.locator('body').innerText().catch(() => '');
  if (OTP_LIMIT_RE.test(body)) {
    throw new Error(
      `OTP admin tetap rate-limited setelah ${otpWaits} tunggu — kuota aplikasi ` +
        `3/15 menit per NRP habis. Periksa sebaran identitas (helpers/live-accounts.ts) ` +
        `dan .agents/logs/e2e-otp-wait.log`,
    );
  }
  await expect(
    otpInput,
    'langkah OTP admin tidak pernah muncul (lihat .agents/logs/e2e-otp-wait.log)',
  ).toBeVisible({ timeout });
  await otpInput.fill(await readOtpFromUi(page, timeout));
  await submit.click();
  return otpWaits;
}

/** Tab login yang memakai alur password → OTP. Owner bukan salah satunya (tanpa OTP). */
export type OtpLoginTab = 'Admin' | 'Dashboard';

/**
 * Login tab Admin/Dashboard sampai form benar-benar terkirim. Mengembalikan
 * jumlah tunggu rate-limit (untuk pelaporan). Kredensial TIDAK pernah dicetak.
 */
export async function loginLiveAccount(
  page: Page,
  tab: OtpLoginTab,
  acct: LiveAccount,
  timeout = 45_000,
): Promise<number> {
  expect(acct.email, `kredensial tab ${tab} tidak diset di env`).toBeTruthy();
  expect(acct.pass, `kredensial tab ${tab} tidak diset di env`).toBeTruthy();
  await openHome(page, timeout);
  await clickStable(page.locator('button', { hasText: tab }).first());
  const emailInput = page.locator('form input[type="email"]').first();
  await expect(emailInput).toBeVisible({ timeout: 20_000 });
  await emailInput.fill(acct.email);
  await page
    .locator('form input[type="password"], form input[placeholder*="password"]')
    .first()
    .fill(acct.pass);
  await page.locator('form button[type="submit"]').first().click();
  return fillAdminOtp(page, timeout);
}

/** Login admin lengkap (password → OTP) sampai halaman /admin benar-benar render. */
export async function loginLiveAdmin(
  page: Page,
  acct: LiveAccount,
  timeout = 45_000,
): Promise<number> {
  const otpWaits = await loginLiveAccount(page, 'Admin', acct, timeout);
  await page.waitForURL((u) => u.pathname.startsWith('/admin'), { timeout });
  await expect(page.locator('body')).not.toBeEmpty();
  return otpWaits;
}
