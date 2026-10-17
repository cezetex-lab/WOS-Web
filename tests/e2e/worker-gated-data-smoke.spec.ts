/**
 * worker-gated-data-smoke.spec.ts — Validasi pasca-migrasi 276 (scope-by-NRP).
 *
 * TUJUAN (Work Queue P2-F14-BQ pasca-CLOSED, keputusan user 2026-10-17)
 *   Migrasi 276 mengubah skoping data 12 RPC worker (get_career_path,
 *   get_worker_kpi, get_performance_notes, ...) + RLS SELECT harvest_records.
 *   Smoke ini membuktikan di BROWSER LIVE bahwa 4 halaman worker yang memakai
 *   RPC ter-scope tetap ter-render tanpa crash / error SQL / "Akses ditolak".
 *
 *   Ini spec LIVE (bukan mock) — satu-satunya cara menangkap regresi SQL/API
 *   dari 276; mock backend tidak akan pernah melihat error RPC sebenarnya.
 *
 * KREDENSIAL (§0.6/§0.7 — tidak ada literal di repo)
 *   Dibaca dari env (SMOKE_WORKER_EMAIL/SMOKE_WORKER_PASSWORD) atau auto-resolve
 *   dari supabase/akun/akun.txt (gitignored) dengan parser kolom-sesudah-email
 *   (pola scripts/run-ops01-smoke.ts). Role DIVERIFIKASI ke DB live: WAJIB
 *   role='worker' + reset_required=false — pelajaran 2026-09-20 (akun yang
 *   ternyata admin dipantul ke /admin oleh RoleGuard pasca-reload).
 *
 * ASERSI (kejujuran desain — difokuskan pada "tidak rusak", bukan "ada data"):
 *   1. Heading halaman ter-render (loading selesai, DOM hidup).
 *   2. Tidak ada teks "Akses ditolak" (gerbang RoleGuard/authz tidak memantul).
 *   3. nol pageerror (React crash / uncaught exception).
 *   4. nol respons RPC ` /rest/v1/rpc/*` gagal (status >= 400 — di sinilah
 *      SQLSTATE 42501/42703/42883 dari migrasi akan muncul).
 *   Data boleh kosong ([]) — halaman menampilkan EmptyState = PASS, sesuai
 *   keputusan user: "cek DOM terender tanpa error, bukan cek ada 5 baris".
 *
 * Jalankan:
 *   npx playwright test tests/e2e/worker-gated-data-smoke.spec.ts
 *   SMOKE_WORKER_EMAIL=... SMOKE_WORKER_PASSWORD=... npx playwright test ...
 */
import { test, expect } from '@playwright/test';
import type { Page, TestInfo } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';
import dotenv from 'dotenv';

dotenv.config({ path: '.env.local', quiet: true });

const NRP_DIMINTA = process.env.SMOKE_WORKER_NRP ?? 'NRP002';

/** 4 halaman worker yang RPC-nya di-scope migrasi 276 (konsumen diverifikasi 2026-10-17). */
const HALAMAN = [
  { route: '/worker/career', judul: /Karir/, rpc: 'get_career_path' },
  { route: '/worker/kpi', judul: /KPI Saya/, rpc: 'get_worker_kpi' },
  { route: '/worker/performance-notes', judul: /Catatan Kinerja/, rpc: 'get_performance_notes' },
  { route: '/worker/harvest', judul: /Record Panen/, rpc: 'get_harvest_records (RLS)' },
] as const;

type Kredensial = { nrp: string; email: string; password: string };

/**
 * Parser akun.txt — baris TAB: nrp \t email \t kandidat1 \t kandidat2 \t ... .
 * Kolom pertama = NRP, kolom yang memuat '@' = email, SEMUA kolom lain = kandidat password.
 * Temuan 2026-10-17: format akun.txt bervariasi per baris — NRP002 memakai kolom ke-5
 * ("xVg1…"), NRP005/007 memakai NIK (kolom setelah email). Karena itu kandidat TIDAK
 * ditebak dari posisi: semua dicoba, lalu yang MATCH diverifikasi ke hash live via
 * crypt() — resolusi kredensial live-verified, tanpa literal di repo.
 */
function parseAkunTxt(): { nrp: string; email: string; kandidat: string[] }[] {
  const akun = path.join(process.cwd(), 'supabase', 'akun', 'akun.txt');
  if (!fs.existsSync(akun)) return [];
  const hasil: { nrp: string; email: string; kandidat: string[] }[] = [];
  for (const l of fs.readFileSync(akun, 'utf8').split(/\r?\n/)) {
    const kolom = l.split('\t').map((v) => v.trim());
    if (!/^NRP\d+$/.test(kolom[0] ?? '')) continue;
    const email = kolom.find((v, i) => i > 0 && v.includes('@'));
    if (!email) continue;
    const kandidat = kolom.slice(1).filter((v) => v && !v.includes('@'));
    if (kandidat.length === 0) continue;
    hasil.push({ nrp: kolom[0], email, kandidat });
  }
  return hasil;
}

/** Verifikasi ke DB live: akun benar-benar worker + tidak dalam reset_required. */
async function verifikasiRoleWorker(nrp: string): Promise<{ ok: boolean; alasan: string }> {
  if (!process.env.DATABASE_URL) return { ok: false, alasan: 'DATABASE_URL tidak ada di .env.local' };
  try {
    const { default: pg } = await import('pg');
    const c = new pg.Client({ connectionString: process.env.DATABASE_URL });
    await c.connect();
    const u = await c.query('SELECT role FROM user_roles WHERE nrp = $1', [nrp]);
    const w = await c.query('SELECT reset_required FROM worker_passwords WHERE nrp = $1', [nrp]);
    await c.end();
    const roles = u.rows.map((r: { role: string }) => r.role);
    if (!roles.includes('worker')) return { ok: false, alasan: `role live = [${roles.join(',')}] bukan worker` };
    if (w.rows.length === 0) return { ok: false, alasan: 'tidak ada baris worker_passwords' };
    if (w.rows[0].reset_required !== false) return { ok: false, alasan: 'reset_required = true' };
    return { ok: true, alasan: `role=worker + reset_required=false (live)` };
  } catch (e) {
    return { ok: false, alasan: `DB live tidak terjangkau: ${(e as Error).message}` };
  }
}

async function resolveKredensial(): Promise<Kredensial | null> {
  const email = process.env.SMOKE_WORKER_EMAIL;
  const password = process.env.SMOKE_WORKER_PASSWORD;
  if (email && password) return { nrp: NRP_DIMINTA, email, password };

  const pilih = parseAkunTxt().find((b) => b.nrp === NRP_DIMINTA);
  if (!pilih || !process.env.DATABASE_URL) return null;
  // Verifikasi live: kandidat mana yang cocok dengan password_hash bcrypt worker_passwords.
  const { default: pg } = await import('pg');
  const c = new pg.Client({ connectionString: process.env.DATABASE_URL });
  await c.connect();
  try {
    const h = await c.query('SELECT password_hash FROM worker_passwords WHERE nrp = $1', [pilih.nrp]);
    if (h.rows.length === 0) return null;
    const hash: string = h.rows[0].password_hash;
    for (const k of pilih.kandidat) {
      const m = await c.query('SELECT (crypt($1, $2) = $2) AS match', [k, hash]);
      if (m.rows[0].match) return { nrp: pilih.nrp, email: pilih.email, password: k };
    }
    return null;
  } finally {
    await c.end();
  }
}

/**
 * Login worker via Home.tsx (email + password, tanpa OTP).
 * Pola identik worker-profile-smoke (consent dialog dulu — modal z-[9999]
 * menghalangi klik submit kalau tidak disetujui).
 */
async function loginWorker(page: Page, k: Kredensial): Promise<void> {
  // Setujui consent SEBELUM load via init script (key sama dengan PrivacyConsent.tsx).
  // Race yang terbukti 2026-10-17: dialog muncul via useEffect async — dengan cold
  // Vite compile ia bisa muncul SETELAH jendela tunggu 8s lalu meng-intercept klik
  // submit ("subtree intercepts pointer events"). Init script menghilangkan race-nya.
  await page.addInitScript(() => {
    try { localStorage.setItem('wos_privacy_consent', 'true'); } catch { /* non-blocking */ }
  });
  await page.goto('/');
  // Fallback defensif: kalau dialog tetap muncul (mis. key berganti), klik saja.
  const dialog = page.getByRole('dialog', { name: /Persetujuan Privasi/i });
  try {
    await dialog.waitFor({ state: 'visible', timeout: 10_000 });
    await dialog.getByRole('button', { name: /Saya Setuju/i }).click();
    await dialog.waitFor({ state: 'hidden', timeout: 5_000 });
  } catch {
    /* tidak ada dialog consent — lanjut */
  }
  await expect(page.locator('input[type="email"]')).toBeVisible({ timeout: 20_000 });
  await page.locator('input[type="email"]').fill(k.email);
  await page.locator('input[type="password"]').first().fill(k.password);
  await page.locator('button[type="submit"]').click();
  await page.waitForURL(/\/worker/, { timeout: 30_000 });
}

test.describe('Validasi pasca-276: worker gated-data smoke (LIVE)', () => {
  let kredensial: Kredensial | null = null;

  test.beforeAll(async () => {
    kredensial = await resolveKredensial();
  });

  test('login worker NRP002 → buka 4 halaman scope-276: DOM terender, 0 RPC error, 0 crash', async ({
    page,
  }, testInfo) => {
    test.skip(
      !kredensial,
      `kredensial worker ${NRP_DIMINTA} tidak tersedia (set SMOKE_WORKER_EMAIL/PASSWORD atau isi supabase/akun/akun.txt)`,
    );
    test.setTimeout(240_000); // cold Vite compile per halaman worker + login live

    const v = await verifikasiRoleWorker(kredensial!.nrp);
    test.skip(!v.ok, `akun ${kredensial!.nrp} bukan worker live: ${v.alasan}`);
    console.log(`[smoke-276] login sebagai ${kredensial!.nrp} — ${v.alasan}`);

    // ── Listener global: crash + RPC gagal, dikumpulkan sepanjang test ──────
    const pageErrors: string[] = [];
    const rpcGagal: string[] = [];
    page.on('pageerror', (err) => pageErrors.push(`pageerror: ${err.message}`));
    page.on('response', (res) => {
      if (res.url().includes('/rest/v1/rpc/') && res.status() >= 400) {
        rpcGagal.push(`HTTP ${res.status()} ${res.url().split('/rest/v1/rpc/')[1]}`);
      }
    });

    await loginWorker(page, kredensial!);
    console.log(`[smoke-276] login OK -> ${page.url()}`);

    for (const h of HALAMAN) {
      // Reset penghitung per halaman supaya kegagalan menunjuk halaman persisnya.
      pageErrors.length = 0;
      rpcGagal.length = 0;

      await page.goto(h.route);
      await page.waitForLoadState('domcontentloaded');
      await expect(page.getByText(h.judul).first()).toBeVisible({ timeout: 30_000 });

      // 1) Tidak dipantul / tidak ditolak authz (auth.uid() masih valid pasca-276).
      await expect(page.locator('body')).not.toContainText('Akses ditolak');
      // 2) Tidak ada React crash.
      expect(pageErrors, `pageerror di ${h.route}`).toEqual([]);
      // 3) Tidak ada RPC gagal (SQLSTATE 42501/42703/42883 tampil di sini).
      expect(rpcGagal, `respons RPC gagal di ${h.route}`).toEqual([]);

      console.log(`[smoke-276] ${h.route} (${h.rpc}) — DOM terender, 0 RPC error, 0 crash`);
      await testInfo.attach(`post-276 smoke ${h.route}`, {
        body: `judul=${h.judul}\nrpc=${h.rpc}\nrpcGagal=${rpcGagal.length}\npageErrors=${pageErrors.length}`,
        contentType: 'text/plain',
      });
    }
  });
});
