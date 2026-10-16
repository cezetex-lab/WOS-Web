#!/usr/bin/env node
/* global __dirname, process, console */
/**
 * scripts/setup-auth-state.cjs — STAGE C LANGKAH 1: login via UI → storageState.
 *
 * Prinsip OPS-08: login 1x per role, sweep nanti reuse storageState (tanpa OTP ulang).
 * Alur login = replika persis tests/a11y/accessibility.spec.ts yang terbukti hijau 6/6:
 *   worker → tab Pekerja, email+password, langsung /worker (tanpa OTP)
 *   admin  → tab Admin, email+password, OTP dev-mode dibaca dari UI (Home.tsx + completeOtp)
 *   owner  → /owner, email+password, langsung /owner/dashboard (tanpa OTP)
 *   admin-mill → (OPS-10) tab Admin sebagai NRP105/admin_mill, OTP dev-mode, darurat ke /admin
 * Kredensial dari supabase/akun/akun.txt (TAB-separated) — TIDAK PERNAH dicetak.
 * Output: .agents/logs/auth-{worker,admin-hrd,owner,admin-mill}.json
 */
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('@playwright/test');

const ROOT = path.resolve(__dirname, '..');
const BASE = process.env.TEST_BASE_URL || 'http://localhost:5173';
const OUT = {
  worker: path.join(ROOT, '.agents', 'logs', 'auth-worker.json'),
  'admin-hrd': path.join(ROOT, '.agents', 'logs', 'auth-admin-hrd.json'),
  owner: path.join(ROOT, '.agents', 'logs', 'auth-owner.json'),
  // OPS-10: state khusus role admin_mill (NRP105) untuk route /admin/mill.
  'admin-mill': path.join(ROOT, '.agents', 'logs', 'auth-admin-mill.json'),
};

function loadEnvLocal() {
  const env = {};
  try {
    for (const line of fs.readFileSync(path.join(ROOT, '.env.local'), 'utf8').split(/\r?\n/)) {
      const m = /^([A-Za-z_0-9]+)=(.*)$/.exec(line.trim());
      if (m) env[m[1]] = m[2].trim().replace(/^["']|["']$/g, '');
    }
  } catch { /* abaikan */ }
  return env;
}

/** OPS-10: ambil kredensial NRP105/admin_mill dari akun.txt (key 'NRP105' atau 'mill@…'). */
function loadMillFromAkun() {
  try {
    const rows = fs.readFileSync(path.join(ROOT, 'supabase', 'akun', 'akun.txt'), 'utf8').split(/\r?\n/);
    for (const raw of rows) {
      const f = raw.split('\t').map((v) => v.trim()).filter(Boolean);
      if (f[0] === 'NRP105' && f[1]?.includes('@') && f[2]) return { email: f[1], password: f[2] };
      if (f[0]?.toLowerCase() === 'mill@insightwos.com' && f[1]) return { email: f[0], password: f[1] };
    }
  } catch { /* akun.txt tidak ada */ }
  return null;
}

function loadAkun() {
  const envLocal = loadEnvLocal();
  // Prioritas 1: E2E_* di .env.local (sumber yang dipakai suite a11y hijau 6/6).
  // Prioritas 2: supabase/akun/akun.txt (TAB-separated).
  // TIDAK PERNAH mencetak password.
  const worker = envLocal.E2E_WORKER_EMAIL && envLocal.E2E_WORKER_PASS
    ? { nrp: envLocal.E2E_WORKER_NRP || 'NRP002', email: envLocal.E2E_WORKER_EMAIL, password: envLocal.E2E_WORKER_PASS, sumber: '.env.local E2E_WORKER_*' }
    : null;
  const admin = envLocal.E2E_ADMIN_EMAIL && envLocal.E2E_ADMIN_PASS
    ? { email: envLocal.E2E_ADMIN_EMAIL, password: envLocal.E2E_ADMIN_PASS, sumber: '.env.local E2E_ADMIN_*' }
    : null;
  const ownerEnv = envLocal.E2E_OWNER_EMAIL && envLocal.E2E_OWNER_PASS
    ? { email: envLocal.E2E_OWNER_EMAIL, password: envLocal.E2E_OWNER_PASS, sumber: '.env.local E2E_OWNER_*' }
    : null;
  // OPS-10: admin_mill (NRP105) TIDAK punya E2E_* di .env.local — selalu dari akun.txt,
  // di kedua jalur return (env atau akun.txt penuh).
  const mill = loadMillFromAkun();
  if (worker && admin && ownerEnv) return { worker, admin, owner: ownerEnv, ownerKey: ownerEnv.email, mill };
  const rows = fs.readFileSync(path.join(ROOT, 'supabase', 'akun', 'akun.txt'), 'utf8').split(/\r?\n/);
  const out = {};
  for (const raw of rows) {
    const f = raw.split('\t').map((v) => v.trim()).filter(Boolean);
    if (/^NRP\d+$/.test(f[0] ?? '') && f[1]?.includes('@') && f[2]) {
      out[f[0]] = { email: f[1], password: f[2] };
    } else if (f[0]?.includes('@') && f[1]) {
      out[f[0]] = { email: f[0], password: f[1] };
    }
  }
  // Verifikasi keberadaan (tanpa mencetak password)
  const need = { NRP002: 'worker', 'pusat@insightwos.com': 'admin' };
  for (const [k, role] of Object.entries(need)) {
    if (!out[k]) { console.error(`FATAL: akun ${role} (${k}) tidak ada di akun.txt`); process.exit(1); }
  }
  // Owner: cari baris owner@…; fallback ceo@ (dipakai suite a11y yang hijau via E2E_OWNER_*)
  const ownerKey = Object.keys(out).find((k) => k.toLowerCase().startsWith('owner@')) || 'ceo@insightwos.com';
  if (!out[ownerKey]) { console.error('FATAL: akun owner/ceo tidak ada di akun.txt'); process.exit(1); }
  return { worker: { nrp: 'NRP002', ...out.NRP002 }, admin: out['pusat@insightwos.com'], owner: out[ownerKey], ownerKey, mill };
}

async function acceptConsent(page) {
  const consent = page.locator('div[role="dialog"] button:has-text("Saya Setuju")').first();
  try {
    await consent.waitFor({ state: 'visible', timeout: 8000 });
    await consent.click();
    await page.waitForTimeout(300);
  } catch { /* tidak muncul — lanjut */ }
}

async function readDisplayedOtp(page) {
  const body = await page.locator('body').innerText();
  const m = /(?:Kode OTP[^0-9]{0,160})(\d{6})/i.exec(body);
  if (!m) throw new Error('Kode OTP dev-mode tidak ditemukan di UI');
  return m[1];
}

(async () => {
  const akun = loadAkun();
  console.log(`akun ok: worker=NRP002 admin=${akun.admin.email} owner=${akun.ownerKey}${akun.mill ? ' admin-mill=NRP105' : ''} (password tidak dicetak)`);
  const browser = await chromium.launch({ headless: true });

  // ── WORKER ──
  {
    const ctx = await browser.newContext();
    const page = await ctx.newPage();
    await page.goto(BASE + '/');
    await acceptConsent(page);
    await page.getByRole('button', { name: /Pekerja/ }).click();
    await page.locator('form input[type="email"]').first().fill(akun.worker.email);
    await page.locator('form input').nth(1).fill(akun.worker.password);
    await page.locator('form button[type="submit"]').first().click();
    await page.waitForURL((u) => u.pathname === '/worker', { timeout: 30000 });
    await ctx.storageState({ path: OUT.worker });
    console.log(`worker OK → ${path.relative(ROOT, OUT.worker)} (${fs.statSync(OUT.worker).size} byte)`);
    await ctx.close();
  }

  // ── ADMIN (OTP dev-mode dari UI) ──
  {
    const ctx = await browser.newContext();
    const page = await ctx.newPage();
    await page.goto(BASE + '/');
    await acceptConsent(page);
    await page.getByRole('button', { name: /Admin/ }).click();
    await page.locator('form input[type="email"]').first().fill(akun.admin.email);
    await page.locator('form input').nth(1).fill(akun.admin.password);
    await page.locator('form button[type="submit"]').first().click();
    const otpInput = page.locator('input[placeholder="000000"]').first();
    await otpInput.waitFor({ state: 'visible', timeout: 30000 });
    await otpInput.fill(await readDisplayedOtp(page));
    await page.locator('form button[type="submit"]').first().click();
    await page.waitForURL((u) => u.pathname === '/admin', { timeout: 30000 });
    await ctx.storageState({ path: OUT['admin-hrd'] });
    console.log(`admin OK → ${path.relative(ROOT, OUT['admin-hrd'])} (${fs.statSync(OUT['admin-hrd']).size} byte`);
    await ctx.close();
  }

  // ── OWNER ──
  {
    const ctx = await browser.newContext();
    const page = await ctx.newPage();
    await page.goto(BASE + '/owner');
    await acceptConsent(page);
    await page.locator('form input[type="email"]').first().fill(akun.owner.email);
    await page.locator('form input').nth(1).fill(akun.owner.password);
    await page.locator('form button[type="submit"]').first().click();
    await page.waitForURL((u) => u.pathname === '/owner/dashboard', { timeout: 30000 });
    await ctx.storageState({ path: OUT.owner });
    console.log(`owner OK → ${path.relative(ROOT, OUT.owner)} (${fs.statSync(OUT.owner).size} byte)`);
    await ctx.close();
  }

  // ── ADMIN-MILL (NRP105, role admin_mill — OPS-10; OTP dev-mode dari UI) ──
  if (akun.mill) {
    const ctx = await browser.newContext();
    const page = await ctx.newPage();
    await page.goto(BASE + '/');
    await acceptConsent(page);
    await page.getByRole('button', { name: /Admin/ }).click();
    await page.locator('form input[type="email"]').first().fill(akun.mill.email);
    await page.locator('form input').nth(1).fill(akun.mill.password);
    await page.locator('form button[type="submit"]').first().click();
    const otpInput = page.locator('input[placeholder="000000"]').first();
    await otpInput.waitFor({ state: 'visible', timeout: 30000 });
    await otpInput.fill(await readDisplayedOtp(page));
    await page.locator('form button[type="submit"]').first().click();
    await page.waitForURL((u) => u.pathname === '/admin', { timeout: 30000 });
    await ctx.storageState({ path: OUT['admin-mill'] });
    console.log(`admin-mill OK → ${path.relative(ROOT, OUT['admin-mill'])} (${fs.statSync(OUT['admin-mill']).size} byte)`);
    await ctx.close();
  }

  await browser.close();
  console.log('STAGE C LANGKAH 1 SELESAI: storageState terbentuk (worker/admin/owner' + (akun.mill ? '/admin-mill' : '') + ').');
})().catch((e) => { console.error('FATAL:', e.message); process.exit(1); });
