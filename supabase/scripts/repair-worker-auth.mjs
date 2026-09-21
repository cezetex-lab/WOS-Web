#!/usr/bin/env node
/**
 * supabase/scripts/repair-worker-auth.mjs — OPS-04 (B1d′)
 *
 * Latar: edge `worker-auth-sync` v2 lama SELALU merotasi `auth.users.password` ke
 * `randomPassword()` yang tidak diketahui siapa pun → `auth.users.password` divergen
 * permanen dari `worker_passwords` → fast path `signInWithPassword` (dipakai
 * `Home.tsx:21`) selalu 400 `invalid_credentials` → setiap login wajib lewat edge
 * (10–13 s) yang di-abort klien pada 5 s (OPS-04).
 *
 * Script ini menyembuhkan akun yang terlanjur divergen TANPA menerbitkan kredensial
 * baru: password dibaca dari `supabase/akun/akun.txt` (gitignored) — password yang
 * SAMA yang sudah terbukti valid di `worker_passwords` (login aplikasi 200) — lalu
 * `auth.admin.updateUserById(auth_id, { password })` menyamakan sisi Supabase Auth.
 *
 * PERINGATAN: GoTrue mencabut SEMUA sesi akun itu saat password diubah (probe
 * 2026-09-21: access token → 403 `session_not_found`, refresh → 400). Karena itu
 * script ini hanya dijalankan sebagai perbaikan sekali-jalan, dan `--dry` wajib
 * dijalankan lebih dulu (default tanpa flag = menolak jalan).
 *
 * Pakai:
 *   node supabase/scripts/repair-worker-auth.mjs --dry     # daftar DIVERGEN, tanpa menulis
 *   node supabase/scripts/repair-worker-auth.mjs --apply   # perbaiki + verifikasi ulang
 *
 * Keluaran: tabel per NRP `SEBELUM → SESUDAH`. Password TIDAK PERNAH dicetak.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createClient } from '@supabase/supabase-js';
import pg from 'pg';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const APPLY = process.argv.includes('--apply');
const DRY = process.argv.includes('--dry');
if (!APPLY && !DRY) {
  console.error('Pakai: node supabase/scripts/repair-worker-auth.mjs --dry | --apply');
  process.exit(2);
}

/** Baca .env.local (tanpa dotenv agar skrip ini tidak menambah dependensi). */
function readEnv() {
  const env = {};
  const p = path.join(ROOT, '.env.local');
  if (!fs.existsSync(p)) return env;
  for (const line of fs.readFileSync(p, 'utf8').split(/\r?\n/)) {
    const m = /^([A-Za-z_0-9]+)=(.*)$/.exec(line.trim());
    if (m) env[m[1]] = m[2].trim().replace(/^["']|["']$/g, '');
  }
  return env;
}

const env = readEnv();
const URL_SUPA = env.SUPABASE_URL || env.VITE_SUPABASE_URL;
const ANON = env.VITE_SUPABASE_ANON_KEY;
const SERVICE = env.SUPABASE_SERVICE_KEY;
for (const [nama, nilai] of [['SUPABASE_URL', URL_SUPA], ['VITE_SUPABASE_ANON_KEY', ANON], ['SUPABASE_SERVICE_KEY', SERVICE], ['DATABASE_URL', env.DATABASE_URL]]) {
  if (!nilai) {
    console.error(`FATAL: ${nama} tidak ada di .env.local`);
    process.exit(2);
  }
}

/** akun.txt: kolom TAB — <NRP> <email> <password> … (password dipakai, tidak dicetak). */
const AKUN = path.join(ROOT, 'supabase', 'akun', 'akun.txt');
if (!fs.existsSync(AKUN)) {
  console.error(`FATAL: ${AKUN} tidak ada (gitignored — sediakan manual)`);
  process.exit(2);
}
const kredensial = new Map();
for (const raw of fs.readFileSync(AKUN, 'utf8').split(/\r?\n/)) {
  const kolom = raw.split('\t').map((v) => v.trim());
  if (!/^NRP\d+$/.test(kolom[0] ?? '')) continue;
  const idxEmail = kolom.findIndex((v, i) => i > 0 && v.includes('@'));
  if (idxEmail < 0 || !kolom[idxEmail + 1]) continue;
  kredensial.set(kolom[0], kolom[idxEmail + 1]);
}
if (kredensial.size === 0) {
  console.error('FATAL: tidak ada baris NRP yang bisa diparsing dari akun.txt');
  process.exit(2);
}

const client = new pg.Client({ connectionString: env.DATABASE_URL, ssl: { rejectUnauthorized: false } });
await client.connect();
const daftar = (
  await client.query(
    `select nrp, auth_id from employees_core
      where nrp like 'NRP%' and auth_id is not null
      order by nrp`,
  )
).rows;
await client.end();

const buatAnon = () =>
  createClient(URL_SUPA, ANON, { auth: { persistSession: false, autoRefreshToken: false } });
const admin = createClient(URL_SUPA, SERVICE, { auth: { persistSession: false, autoRefreshToken: false } });

/** Probe fast path persis seperti Home.tsx: signInWithPassword(email sintetis, password worker). */
async function probe(nrp) {
  const email = `${String(nrp).toLowerCase().trim()}@insightwos.internal`;
  const c = buatAnon();
  const { data, error } = await c.auth.signInWithPassword({ email, password: kredensial.get(nrp) });
  await c.auth.signOut().catch(() => {});
  if (!error && data.session) return 'SINKRON';
  if (error && (error.code === 'invalid_credentials' || error.status === 400)) return 'DIVERGEN';
  return `LAIN(${error?.code ?? '?'}/${error?.status ?? '?'})`;
}

console.log('== repair-worker-auth (OPS-04 / B1d′) ==');
console.log(`mode      : ${APPLY ? '--apply' : '--dry'}`);
console.log(`akun.txt  : ${kredensial.size} baris NRP terbaca (password TIDAK dicetak)`);
console.log(`kandidat  : ${daftar.length} NRP punya auth_id\n`);

const hasil = [];
for (const r of daftar) {
  if (!kredensial.has(r.nrp)) {
    hasil.push({ nrp: r.nrp, sebelum: 'TANPA_PW_AKUN', sesudah: '-' });
    console.log(`  ${r.nrp}  TANPA_PW_AKUN (tidak ada baris di akun.txt) → dilewati`);
    continue;
  }
  const sebelum = await probe(r.nrp);
  let sesudah = sebelum;
  if (sebelum === 'DIVERGEN' && APPLY) {
    const { error } = await admin.auth.admin.updateUserById(r.auth_id, {
      password: kredensial.get(r.nrp),
    });
    if (error) {
      sesudah = `GAGAL_SYNC(${error.message})`;
      console.log(`  ${r.nrp}  repair GAGAL: ${error.message}`);
    } else {
      console.log(`  ${r.nrp}  repair OK (updateUserById; sesi lama akun ini dicabut)`);
      sesudah = await probe(r.nrp);
    }
  }
  hasil.push({ nrp: r.nrp, sebelum, sesudah });
  console.log(`  ${r.nrp}  sebelum=${sebelum} → sesudah=${sesudah}`);
}

const sebelumDiv = hasil.filter((h) => h.sebelum === 'DIVERGEN').length;
const sesudahDiv = hasil.filter(
  (h) => h.sesudah === 'DIVERGEN' || String(h.sesudah).startsWith('GAGAL_SYNC'),
).length;
const teruji = hasil.filter((h) => h.sesudah !== '-').length;
const sinkron = hasil.filter((h) => h.sesudah === 'SINKRON').length;

console.log('\n== ringkasan ==');
console.log(`DIVERGEN sebelum = ${sebelumDiv} → sesudah = ${sesudahDiv}`);
console.log(`SINKRON sesudah  = ${sinkron} / ${teruji} akun teruji (TANPA_PW_AKUN dilewati)`);
if (!APPLY && sebelumDiv > 0) {
  console.log(`\nDRY RUN — ${sebelumDiv} akun DIVERGEN siap diperbaiki. Jalankan ulang dengan --apply.`);
}
if (APPLY && sesudahDiv > 0) {
  console.error(`\nGAGAL: masih ada ${sesudahDiv} akun DIVERGEN setelah --apply.`);
  process.exit(1);
}
if (APPLY) console.log('\nOK — tidak ada akun DIVERGEN tersisa.');

