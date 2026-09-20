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
    // 'Menyimpan...' → tombol kembali aktif, lalu mode edit tertutup.
    await expect(tombolSimpan).toBeEnabled({ timeout: 20_000 });
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
    await agamaSetelah.fill(nilaiAsli);
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
    console.log(`[OPS-01] nilai Agama dipulihkan ke "${nilaiAsli}" (${TANDA})`);
  });
});
