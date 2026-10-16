#!/usr/bin/env node
/* global process, console */
/**
 * scripts/seed-admin-otp-identities.mjs
 *
 * OTP admin dibatasi APLIKASI sendiri: edge `password-reset` → hitRateLimit(nrp,'login_otp')
 * dengan LIMITS.login_otp = 3 per jendela 15 menit (plus jalur RPC `otp_attempts` 3/10 menit).
 * Karena itu spec live TIDAK boleh berbagi identitas.
 *
 * Script ini membaca daftar akun admin dari `supabase/akun/akun.txt` (gitignored) dan
 * MENAMBAH (idempotent) key env untuk 8 identitas admin ke `.env.local`, supaya
 * `tests/e2e/helpers/live-accounts.ts` bisa memakai satu identitas per konsumen.
 *
 * Kredensial TIDAK PERNAH dicetak: hanya nama key + panjang nilai.
 */
import fs from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(import.meta.dirname, '..');
const ENV_FILE = path.join(ROOT, '.env.local');
const AKUN_FILE = path.join(ROOT, 'supabase', 'akun', 'akun.txt');

const envText = fs.readFileSync(ENV_FILE, 'utf8');
const eol = envText.includes('\r\n') ? '\r\n' : '\n';
const readEnv = (key) => {
  const m = new RegExp(`^${key}=(.*)$`, 'm').exec(envText);
  return m ? m[1].trim() : undefined;
};

// Baris admin di akun.txt: `<email>\t<password>\t<NRP>`
const akunText = fs.readFileSync(AKUN_FILE, 'utf8');
const accounts = new Map();
for (const line of akunText.split(/\r?\n/)) {
  const m = /^([\w.+-]+@insightwos\.com)\t+(\S+)\t+(NRP\d+)/.exec(line.trim());
  if (m) accounts.set(m[1], { pass: m[2], nrp: m[3] });
}

const required = [
  'pusat@insightwos.com',
  'ceo@insightwos.com',
  'hrd@insightwos.com',
  'operasional@insightwos.com',
  'finance@insightwos.com',
  'mining@insightwos.com',
  'mill@insightwos.com',
  'estate@insightwos.com',
];
const missing = required.filter((e) => !accounts.has(e));
if (missing.length) {
  console.error(`FATAL: akun admin tidak ditemukan di akun.txt: ${missing.join(', ')}`);
  process.exit(1);
}

/** slug → email (slug dipakai sebagai nama key env). */
const SLUGS = {
  PUSAT: 'pusat@insightwos.com',
  CEO: 'ceo@insightwos.com',
  HRD: 'hrd@insightwos.com',
  OPS: 'operasional@insightwos.com',
  FINANCE: 'finance@insightwos.com',
  MINING: 'mining@insightwos.com',
  MILL: 'mill@insightwos.com',
  ESTATE: 'estate@insightwos.com',
};

const plan = new Map();
for (const [slug, email] of Object.entries(SLUGS)) {
  const acc = accounts.get(email);
  plan.set(`E2E_ADMIN_${slug}_EMAIL`, email);
  plan.set(`E2E_ADMIN_${slug}_PASS`, acc.pass);
}
// Alias lama (dipakai four-page-smoke) tetap diarahkan ke hrd — sudah ada, jangan ditimpa.
plan.set('E2E_ADMIN_EMAIL', 'hrd@insightwos.com');
plan.set('E2E_ADMIN_PASS', accounts.get('hrd@insightwos.com').pass);

const added = [];
const present = [];
for (const [k, v] of plan) {
  if (readEnv(k) !== undefined) {
    present.push(k);
    continue;
  }
  added.push([k, v]);
}

if (added.length) {
  const base = envText.endsWith(eol) ? envText : envText + eol;
  fs.writeFileSync(ENV_FILE, base + added.map(([k, v]) => `${k}=${v}`).join(eol) + eol, 'utf8');
}

console.log(`ditanam : ${added.map(([k, v]) => `${k}(len=${v.length})`).join(', ') || '(tidak ada)'}`);
console.log(`ada     : ${present.join(', ') || '(tidak ada)'}`);
console.log('kredensial TIDAK dicetak — hanya panjang nilai.');
