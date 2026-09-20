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
import { test, expect } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';

const EMAIL = process.env.OPS01_EMAIL;
const PASSWORD = process.env.OPS01_PASSWORD;
const NILAI_UJI = process.env.OPS01_TEST_VALUE ?? 'Islam';
const TANDA = `smoke-${Date.now()}`;

test.describe('OPS-01 smoke WorkerProfile', () => {
  test.skip(
    !EMAIL || !PASSWORD,
    'OPS01_EMAIL/OPS01_PASSWORD tidak diset — jalankan lewat `npm run smoke:ops01`',
  );

  test('login worker → edit Agama → Simpan → reload → persist → pulihkan', async ({ page }) => {
    // ── 1. LOGIN WORKER (email + password, Home.tsx) ──────────────────────────
    await page.goto('/');

    // Modal consent privasi (z-[9999]) muncul async dan menghalangi klik submit.
    const consent = page.locator('div[role="dialog"] button:has-text("Saya Setuju")');
    try {
      await consent.first().waitFor({ state: 'visible', timeout: 8_000 });
      await consent.first().click();
    } catch {
      /* tidak ada dialog consent — lanjut */
    }

    await expect(page.locator('input[type="email"]')).toBeVisible({ timeout: 20_000 });
    await page.locator('input[type="email"]').fill(EMAIL!);
    await page.locator('input[type="password"]').first().fill(PASSWORD!);
    await page.locator('button[type="submit"]').click();
    await page.waitForURL(/\/worker/, { timeout: 30_000 });
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
      // Nilai asli KOSONG: RPC `worker_update_profile` memakai pola
      // `COALESCE(p_agama, agama)` di sisi DB — NULL berarti "jangan ubah" —
      // sehingga field TIDAK BISA dikosongkan lewat UI (temuan SQL-12,
      // AGENTS.md §5.8; terbukti 2026-09-20: simpan '' sukses di UI tapi DB
      // tetap berisi nilai lama). Persist SUDAH terbukti di langkah 4, jadi
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
});
