#!/usr/bin/env node
/**
 * supabase/scripts/seed-test-workers.mjs — seed data uji ke DB live (bukan baseline).
 *
 * Latar: baseline installer sengaja TIDAK memuat data karyawan/PII (kontrak header
 * 010_baseline_config_data.sql: "YANG SENGAJA TIDAK ADA"). Akibatnya pasca reset DB,
 * smoke OPS-01 gagal karena employees_extended kosong. Script ini menyiapkan data uji
 * TANPA menyentuh baseline — dipanggil manual atau oleh smoke runner (idempoten).
 *
 * Keputusan user 2026-09-22:
 *   (Y) password ditulis via crypt() langsung (bcrypt gen_salt('bf')) — BUKAN RPC
 *       admin_reset_worker_password (RPC punya gate authz yang menolak koneksi
 *       postgres langsung). Dev tooling, tidak butuh gate authz. Tidak ada plaintext.
 *   (e) exit tanpa rollback — user fix manual jika error.
 *
 * Pakai:  node supabase/scripts/seed-test-workers.mjs --dry | --apply
 * Password dibaca dari supabase/akun/akun.txt (gitignored) — TIDAK PERNAH dicetak.
 * Exit 0 = PASS, 1 = GAGAL, 2 = salah pemakaian.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const APPLY = process.argv.includes('--apply');
const DRY = process.argv.includes('--dry');
if (!APPLY && !DRY) {
  console.error('Pakai: node supabase/scripts/seed-test-workers.mjs --dry | --apply');
  process.exit(2);
}

/** Baca .env.local (pola sama dengan repair-worker-auth.mjs — tanpa dependensi baru). */
const env = {};
for (const line of fs.readFileSync(path.join(ROOT, '.env.local'), 'utf8').split(/\r?\n/)) {
  const m = /^([A-Za-z_0-9]+)=(.*)$/.exec(line.trim());
  if (m) env[m[1]] = m[2].trim().replace(/^["']|["']$/g, '');
}
if (!env.DATABASE_URL) { console.error('FATAL: DATABASE_URL tidak ada di .env.local'); process.exit(2); }

/** akun.txt kolom TAB — Section 1 admin: <email> <password> <nrp>; Section 2 worker: <nrp> <email> <password> <nik>. */
const ROLE_BY_PREFIX = {
  ceo: 'admin_pusat', pusat: 'admin_pusat', hrd: 'admin_hrd', finance: 'admin_finance',
  operasional: 'admin_operasional', mining: 'admin_mining', mill: 'admin_mill', estate: 'admin_estate',
};
const akun = [];
for (const raw of fs.readFileSync(path.join(ROOT, 'supabase', 'akun', 'akun.txt'), 'utf8').split(/\r?\n/)) {
  const f = raw.split('\t').map((v) => v.trim()).filter(Boolean);
  if (/^NRP\d+$/.test(f[0] ?? '')) {
    if (f[1]?.includes('@') && f[2]) akun.push({ nrp: f[0], email: f[1], password: f[2], role: 'worker' });
  } else if (f[0]?.includes('@') && /^NRP\d+$/.test(f[2] ?? '')) {
    akun.push({ nrp: f[2], email: f[0], password: f[1], role: ROLE_BY_PREFIX[f[0].split('@')[0]] ?? 'admin' });
  }
}
if (akun.length !== 17) {
  console.error(`FATAL: parsing akun.txt menghasilkan ${akun.length} akun (harus 17)`);
  process.exit(1);
}

const client = new pg.Client({ connectionString: env.DATABASE_URL, ssl: { rejectUnauthorized: false } });
await client.connect();
const tag = DRY ? '[DRY] ' : '';

// Kondisi awal (read-only) untuk rencana dry & pemisahan hitungan insert/update.
const awal = (await client.query(`
  SELECT (SELECT COUNT(*) FROM employees_core WHERE nrp LIKE 'NRP%') AS core,
         (SELECT COUNT(*) FROM employees_extended WHERE nrp LIKE 'NRP%') AS ext,
         (SELECT COUNT(*) FROM user_roles WHERE nrp LIKE 'NRP%') AS roles,
         (SELECT COUNT(*) FROM worker_passwords WHERE nrp LIKE 'NRP%') AS pw,
         (SELECT COUNT(*) FROM employees_core WHERE nrp LIKE 'NRP%' AND auth_id IS NOT NULL) AS auth_linked`)).rows[0];
const sudahAdaPw = new Set(
  (await client.query(`SELECT nrp FROM worker_passwords WHERE nrp LIKE 'NRP%'`)).rows.map((r) => r.nrp),
);

// 1) employees_extended — baris minimal (PK nrp) untuk semua NRP employees_core.
//    Dry = hitung yang belum ada (query saja); Apply = INSERT..SELECT idempoten.
const extKurang = Number(awal.core) - Number(awal.ext);
let nExt = 0;
if (DRY) nExt = extKurang;
else {
  nExt = (await client.query(
    `INSERT INTO employees_extended (nrp)
     SELECT nrp FROM employees_core WHERE nrp LIKE 'NRP%'
     ON CONFLICT (nrp) DO NOTHING`,
  )).rowCount;
}

// 2) user_roles — safety net: hanya NRP yang belum punya (live pasca reset sudah 17).
const adaRole = new Set((await client.query(`SELECT nrp FROM user_roles WHERE nrp LIKE 'NRP%'`)).rows.map((r) => r.nrp));
const kurangRole = akun.filter((a) => !adaRole.has(a.nrp));
let nRole = 0;
if (kurangRole.length) {
  if (DRY) nRole = kurangRole.length;
  else {
    nRole = (await client.query(
      `INSERT INTO user_roles (nrp, role, role_level, plan)
       SELECT a.nrp, a.role, 1, 'FREE' FROM unnest($1::text[], $2::text[]) AS a(nrp, role)
       ON CONFLICT (nrp) DO NOTHING`,
      [kurangRole.map((a) => a.nrp), kurangRole.map((a) => a.role)],
    )).rowCount;
  }
}

// 3) worker_passwords — KEPUTUSAN (Y): crypt() langsung, bukan RPC (gate authz menolak
//    koneksi postgres). Upsert idempoten per akun; password tidak pernah dicetak.
let pwBaru = 0, pwUpdate = 0;
for (const a of akun) {
  if (DRY) { sudahAdaPw.has(a.nrp) ? pwUpdate++ : pwBaru++; continue; }
  await client.query(
    `INSERT INTO worker_passwords (nrp, password_hash, is_active, reset_required, attempts)
     VALUES ($1, crypt($2, gen_salt('bf')), true, false, 0)
     ON CONFLICT (nrp) DO UPDATE SET
       password_hash = crypt($2, gen_salt('bf')),
       reset_required = false,
       attempts = 0`,
    [a.nrp, a.password],
  );
  sudahAdaPw.has(a.nrp) ? pwUpdate++ : pwBaru++;
}

// 4) Safety WAJIB: pastikan tidak ada reset_required tersisa true (RPC lama/bisa set TRUE).
let nRR = 0;
if (!DRY) {
  nRR = (await client.query(
    `UPDATE worker_passwords SET reset_required = false WHERE nrp LIKE 'NRP%' AND reset_required = true`,
  )).rowCount;
}

// 5) sync auth_id — hubungkan employees_core ke auth.users by email (yang belum).
let nAuth = 0;
if (!DRY) {
  nAuth = (await client.query(
    `UPDATE employees_core c SET auth_id = u.id FROM auth.users u
     WHERE c.auth_id IS NULL AND lower(u.email) = lower(c.email)`,
  )).rowCount;
}

// 6) VERIFY — tanpa nilai sensitif; exit tanpa rollback (keputusan (e)).
//    DRY: verdict dievaluasi atas PROYEKSI pasca-apply (dry tidak menulis apa pun).
let v;
if (DRY) {
  v = { core: awal.core, ext: Number(awal.ext) + nExt, roles: awal.roles, pw: Number(awal.pw) + pwBaru, rr_true: 0, auth_linked: awal.auth_linked };
} else {
  v = (await client.query(`
  SELECT (SELECT COUNT(*) FROM employees_core WHERE nrp LIKE 'NRP%') AS core,
         (SELECT COUNT(*) FROM employees_extended) AS ext,
         (SELECT COUNT(*) FROM user_roles WHERE nrp LIKE 'NRP%') AS roles,
         (SELECT COUNT(*) FROM worker_passwords) AS pw,
         (SELECT COUNT(*) FROM worker_passwords WHERE reset_required = true) AS rr_true,
         (SELECT COUNT(*) FROM employees_core WHERE nrp LIKE 'NRP%' AND auth_id IS NOT NULL) AS auth_linked`)).rows[0];
}
console.log(`${tag}extended=+${nExt}, roles=+${nRole}, pw=+${pwBaru} baru / ${pwUpdate} update, reset_required cleared=+${nRR}, auth_id sync=+${nAuth}`);
console.log(`${tag}VERIFY: core=${v.core} ext=${v.ext} roles=${v.roles} pw=${v.pw} rr_true=${v.rr_true} auth_linked=${v.auth_linked}`);
const ok = Number(v.core) === 17 && Number(v.ext) === 17 && Number(v.roles) === 17 &&
  Number(v.pw) >= 17 && Number(v.rr_true) === 0 && Number(v.auth_linked) === 17;
console.log(ok ? 'HASIL: PASS' : 'HASIL: GAGAL — periksa di atas (tanpa rollback, keputusan (e))');
await client.end();
process.exit(ok ? 0 : 1);
