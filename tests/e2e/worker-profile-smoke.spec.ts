/**
 * OPS-01 — smoke runtime WorkerProfile: login worker → Edit → ubah 1 kolom →
 * Simpan → reload → nilai PERSIST → kembalikan nilai asli.
 *
 * Ini menutup item OPS-01 (AGENTS.md §5.8), yang satu-satunya bagian tersisa
 * adalah pembuktian runtime di browser: grant `EXECUTE TO authenticated` sudah
 * termigrasi (222), tetapi alur simpan profil belum pernah dibuktikan end-to-end.
 *
 * KENAPA BERKAS INI BEDA DARI E2E LAIN
 *   * Kredensial TIDAK boleh ada di berkas ini (§0.6/§0.7) — dibaca dari env yang
 *     diisi `scripts/run-ops01-smoke.ts` (dari `supabase/akun/akun.txt`, gitignored).
 *   * Smoke ini MENULIS ke database live (satu field profil), jadi ia WAJIB
 *     mengembalikan nilai aslinya di akhir dan melaporkan bila pemulihan gagal.
 *
 * Jalankan lewat `npm run smoke:ops01` (headed, hasil terekam ke agentsLogs).
 */
import { test, expect, type Page } from '@playwright/test';
import { openHome, clickStable, fillStable } from './helpers/live-login';
import fs from 'node:fs';
import path from 'node:path';
import dotenv from 'dotenv';
import pg from 'pg';

const EMAIL = process.env.OPS01_EMAIL;
const PASSWORD = process.env.OPS01_PASSWORD;
const NRP = process.env.OPS01_NRP; // nrp worker uji (untuk bukti DB di test SQL-12)
const NILAI_UJI = process.env.OPS01_TEST_VALUE ?? 'Islam';
const TANDA = `smoke-${Date.now()}`;

/**
 * Login worker (email + password) memakai helper bersama.
 *
 * SEBELUMNYA kedua test menulis blok login sendiri: `page.goto('/')` + tunggu
 * dialog consent 8 s + `button[type="submit"]').click()` MENTAH. Blok itu tidak
 * memakai `openHome` (pre-seed consent) maupun `clickStable` (retry + self-heal
 * overlay), jadi punya jalur berbeda dari spec lain — dan itulah sumber flaky-nya:
 * Run 1/3 2026-09-25 `worker-profile-smoke` gagal dengan
 * `locator.click: Timeout 15000ms exceeded` pada `button[type="submit"]`
 * (tombol ter-resolve tapi klik tidak sampai), lalu lulus di attempt kedua.
 */
async function loginWorker(page: Page): Promise<void> {
  await openHome(page);
  await expect(page.locator('input[type="email"]')).toBeVisible({ timeout: 20_000 });
  await fillStable(page.locator('input[type="email"]'), EMAIL!);
  await fillStable(page.locator('input[type="password"]').first(), PASSWORD!);
  await clickStable(page.locator('button[type="submit"]').first());
  await page.waitForURL(/\/worker/, { timeout: 30_000 });
}

test.describe('OPS-01 smoke WorkerProfile', () => {
  test.skip(
    !EMAIL || !PASSWORD,
    'OPS01_EMAIL/OPS01_PASSWORD tidak diset — jalankan lewat `npm run smoke:ops01`',
  );

  test('login worker → edit Agama → Simpan → reload → persist → pulihkan', async ({ page }) => {
    // ── 1. LOGIN WORKER (email + password, Home.tsx) ──────────────────────────
    await loginWorker(page);
    console.log(`[OPS-01] login berhasil sebagai ${EMAIL}`);

    // ── 2. BUKA /worker/profile dan masuk mode Edit ───────────────────────────
    await page.goto('/worker/profile');
    await page.waitForLoadState('domcontentloaded');

    // Label tombol: '✏️ Edit' / '✕ Batal' (WorkerProfile.tsx) — jangan pakai /^edit$/.
    const tombolEdit = page.getByRole('button', { name: /edit/i }).first();
    await expect(tombolEdit).toBeVisible({ timeout: 20_000 });
    await tombolEdit.click();

    // Input memakai htmlFor=label.toLowerCase() → getByLabel aman (forms.tsx:56).
    const agama = page.getByLabel('Agama', { exact: true });
    await expect(agama).toBeVisible({ timeout: 10_000 });
    const nilaiAsli = await agama.inputValue();
    console.log(`[OPS-01] nilai Agama sebelum: "${nilaiAsli}"`);

    // ── 3. UBAH 1 KOLOM + SIMPAN ──────────────────────────────────────────────
    await agama.fill(NILAI_UJI);
    const tombolSimpan = page.getByRole('button', { name: /simpan/i }).first();
    await expect(tombolSimpan).toBeVisible({ timeout: 10_000 });
    await tombolSimpan.click();
    // Tunggu form KELUAR dari mode edit (handleSave sukses → setEditing(false) →
    // tombol '✏️ Edit' muncul lagi). JANGAN menunggu tombol Simpan "aktif kembali":
    // saat simpan cepat, form langsung tertutup dan tombolnya hilang dari DOM.
    await expect(page.getByRole('button', { name: /edit/i }).first()).toBeVisible({
      timeout: 20_000,
    });

    // ── 4. RELOAD → bukti nilai PERSIST ───────────────────────────────────────
    await page.reload();
    await page.waitForLoadState('domcontentloaded');
    await page.getByRole('button', { name: /edit/i }).first().click();
    const agamaSetelah = page.getByLabel('Agama', { exact: true });
    await expect(agamaSetelah).toHaveValue(NILAI_UJI, { timeout: 15_000 });
    console.log(`[OPS-01] nilai Agama sesudah reload: "${NILAI_UJI}" → PERSIST`);

    // ── 5. PULIHKAN NILAI ASLI (smoke menulis ke DB live) ─────────────────────
    if (nilaiAsli === '') {
      // Nilai asli KOSONG: RPC `worker_update_profile` KINI (migrasi 244, SQL-12)
      // memakai semantik NULL = jangan ubah / '' = kosongkan, sehingga clear/pulihkan
      // via UI sudah mungkin — alurnya dibuktikan test kedua di bawah. (Sebelum
      // 244: simpan '' sukses di UI tapi DB tetap berisi nilai lama — terbukti
      // 2026-09-20.) Persist SUDAH terbukti di langkah 4, jadi
      // smoke boleh lulus; penanda residu ditulis agar runner memulihkan
      // nilai asli via SQL setelah browser ditutup.
      console.log('[OPS-01] nilai asli kosong — pemulihan diserahkan ke runner via SQL (SQL-12)');
      fs.writeFileSync(
        path.join(process.cwd(), '.agents', 'logs', 'ops01-residue.json'),
        JSON.stringify({
          nrp: process.env.OPS01_NRP,
          tabel: 'employees_extended',
          field: 'agama',
          original: null,
        }),
      );
      return;
    }
    await agamaSetelah.fill(nilaiAsli);
    await page.getByRole('button', { name: /simpan/i }).first().click();
    await expect(page.getByRole('button', { name: /edit/i }).first()).toBeVisible({
      timeout: 20_000,
    });
    // Buktikan pemulihan benar-benar persist sebelum smoke dinyatakan lulus.
    await page.reload();
    await page.waitForLoadState('domcontentloaded');
    await page.getByRole('button', { name: /edit/i }).first().click();
    await expect(page.getByLabel('Agama', { exact: true })).toHaveValue(nilaiAsli, {
      timeout: 15_000,
    });
    console.log(`[OPS-01] nilai Agama dipulihkan ke "${nilaiAsli}" (${TANDA})`);
  });

  test('SQL-12: kosongkan Agama ("") → simpan → reload → tetap kosong + DB NULL → pulihkan', async ({ page }) => {
    // ── 1. LOGIN WORKER (sama seperti test pertama) ───────────────────────────
    await loginWorker(page);

    // ── 2. BUKA /worker/profile, mode Edit, catat nilai asli ──────────────────
    await page.goto('/worker/profile');
    await page.waitForLoadState('domcontentloaded');
    await page.getByRole('button', { name: /edit/i }).first().click();
    const agama = page.getByLabel('Agama', { exact: true });
    await expect(agama).toBeVisible({ timeout: 10_000 });
    const nilaiAsli = await agama.inputValue();

    // ── 3. KOSONGKAN + SIMPAN (UI kirim '' apa adanya) ────────────────────────
    await agama.fill('');
    await page.getByRole('button', { name: /simpan/i }).first().click();
    await expect(page.getByRole('button', { name: /edit/i }).first()).toBeVisible({
      timeout: 20_000,
    });

    // ── 4. RELOAD → bukti UI: field TETAP KOSONG ──────────────────────────────
    await page.reload();
    await page.waitForLoadState('domcontentloaded');
    await page.getByRole('button', { name: /edit/i }).first().click();
    await expect(page.getByLabel('Agama', { exact: true })).toHaveValue('', {
      timeout: 15_000,
    });

    // ── 5. BUKTI DB: employees_extended.agama = NULL (read-only) ──────────────
    const adaNrp = !!NRP && /^NRP\d+$/.test(NRP ?? '');
    dotenv.config({ path: '.env.local', quiet: true });
    const buka = () =>
      new pg.Client({
        connectionString: process.env.DATABASE_URL,
        ssl: { rejectUnauthorized: false },
      });
    if (!adaNrp) {
      console.log('[SQL-12] OPS01_NRP tidak tersedia/valid — bukti DB dilewati (bukti UI tetap jalan)');
    } else {
      const c = buka();
      await c.connect();
      const db = await c.query('select agama from employees_extended where nrp = $1', [NRP]);
      await c.end();
      expect(db.rows[0]?.agama, `DB agama ${NRP} harus NULL setelah clear via UI`).toBeNull();
      console.log(`[SQL-12] DB agama ${NRP} = NULL → '' benar-benar mengosongkan field (migrasi 244)`);
    }

    // ── 6. PULIHKAN NILAI ASLI via UI ('' kini bisa dikirim apa adanya) ───────
    await page.getByLabel('Agama', { exact: true }).fill(nilaiAsli);
    await page.getByRole('button', { name: /simpan/i }).first().click();
    await expect(page.getByRole('button', { name: /edit/i }).first()).toBeVisible({
      timeout: 20_000,
    });
    await page.reload();
    await page.waitForLoadState('domcontentloaded');
    await page.getByRole('button', { name: /edit/i }).first().click();
    await expect(page.getByLabel('Agama', { exact: true })).toHaveValue(nilaiAsli, {
      timeout: 15_000,
    });
    // Buktikan pemulihan juga di level DB (nilai asli '' kini benar-benar NULL lagi).
    if (adaNrp) {
      const c2 = buka();
      await c2.connect();
      const db2 = await c2.query('select agama from employees_extended where nrp = $1', [NRP]);
      await c2.end();
      expect(db2.rows[0]?.agama ?? '').toBe(nilaiAsli || null);
      console.log(`[SQL-12] pemulihan: DB agama ${NRP} = ${JSON.stringify(db2.rows[0]?.agama ?? null)}`);
    }
  });
});
