#!/usr/bin/env node
/**
 * rehearse-new-company.mjs — LATIHAN instalasi perusahaan baru, dari nol sampai
 * owner bisa masuk dan dashboard hidup.
 *
 * `verify-install-e2e.mjs` sudah membuktikan baseline menghasilkan skema yang
 * SAMA dengan live (9/9 metrik). Yang belum pernah dibuktikan: apakah perusahaan
 * baru benar-benar BISA DIPAKAI — yaitu (a) owner pertama bisa dibuat, (b) owner
 * bisa login lewat RPC `owner_login()`, (c) guard owner (`check_owner_identity()`)
 * menerima dia, dan (d) RPC dashboard benar-benar mengembalikan data (bukan error).
 *
 * Latihan ini menutup celah itu tanpa menyentuh DB live:
 *   1. buat database scratch kosong (nama WAJIB diawali `wos_replay_`);
 *   2. siapkan prereq platform (schema auth/extensions, stub cron, default privilege);
 *   3. pasang baseline lewat `install-baseline.mjs` (jalur yang sama dengan install nyata);
 *   4. buat "owner pertama" — langkah DB dari `supabase/baseline/first-owner.example.sql`;
 *   5. tiru sesi owner lewat GUC JWT yang dibaca stub `auth.uid()`/`auth.role()`,
 *      lalu panggil `owner_login()`, `check_owner_identity()`, dan RPC dashboard;
 *   6. cek isolasi: `anon` TIDAK boleh bisa memanggil RPC owner di instalasi baru.
 *
 * Pakai:
 *   node supabase/scripts/rehearse-new-company.mjs                       # jalankan latihan
 *   node supabase/scripts/rehearse-new-company.mjs --keep                # simpan DB scratch
 *   npm run db:rehearse-newco -- --keep
 *
 * Laporan: supabase/baseline/rehearse-new-company.md. Exit 1 bila ada langkah gagal.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import pg from 'pg';
import { PREREQS } from './platform-prereqs.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const argv = process.argv.slice(2);
const arg = (n, d) => {
  const hit = argv.find((a) => a.startsWith(`--${n}=`));
  return hit ? hit.slice(n.length + 3) : d;
};
const DBNAME = arg('db', 'wos_replay_newco');
const KEEP = argv.includes('--keep');
const COMPANY = arg('company', 'PT Uji Perusahaan Baru');
const OWNER_EMAIL = arg('owner-email', 'owner@perusahaan-baru.test');
const OWNER_PASSWORD_NOTE = '<dibuat di Auth project nyata lewat --create-owner>';

if (!/^wos_replay_/.test(DBNAME)) {
  console.error('menolak: nama database harus diawali "wos_replay_"');
  process.exit(2);
}

const URL = fs
  .readFileSync(path.join(ROOT, '.env.local'), 'utf8')
  .split(/\r?\n/)
  .find((l) => /^\s*DATABASE_URL\s*=/.test(l))
  .slice(13)
  .trim()
  .replace(/^["']|["']$/g, '');
const ADMIN_URL = URL.replace(/\/[^/?]+(\?|$)/, '/postgres$1');
const withDb = (db) => URL.replace(/\/[^/?]+(\?|$)/, `/${db}$1`);

const LOG = [];
const log = (s = '') => {
  LOG.push(s);
  console.log(s);
};
const failures = [];
const check = (ok, label, detail = '') => {
  log(`  ${ok ? 'OK  ' : 'GAGAL'} ${label}${detail ? ` — ${detail}` : ''}`);
  if (!ok) failures.push(`${label}${detail ? ` (${detail})` : ''}`);
  return ok;
};

// ── 0. buat database scratch kosong ─────────────────────────────────────────
const admin = new pg.Client({ connectionString: ADMIN_URL, ssl: { rejectUnauthorized: false } });
await admin.connect();
log(`=== latihan instalasi perusahaan baru: db=${DBNAME} ===`);
await admin.query(
  'select pg_terminate_backend(pid) from pg_stat_activity where datname = $1 and pid <> pg_backend_pid()',
  [DBNAME],
);
await admin.query(`drop database if exists ${DBNAME} with (force)`);
await admin.query(`create database ${DBNAME}`);
log('database scratch dibuat (kosong, seperti project Supabase baru)');

const scratchUrl = withDb(DBNAME);
const c = new pg.Client({ connectionString: scratchUrl, ssl: { rejectUnauthorized: false } });
await c.connect();
await c.query(PREREQS);
for (const ext of ['pgcrypto', 'uuid-ossp', 'vector']) {
  try {
    await c.query(`create extension if not exists "${ext}"`);
  } catch {
    /* extension tidak selalu tersedia di cluster ini */
  }
}
log('prereq platform disiapkan (auth/extensions, stub cron, default privilege)');

// ── 1. pasang baseline (jalur install yang sebenarnya) ──────────────────────
const installer = path.join(ROOT, 'supabase/scripts/install-baseline.mjs');
const install = spawnSync(
  process.execPath,
  [
    installer,
    '--target',
    scratchUrl,
    '--apply',
    '--company-name',
    COMPANY,
    '--owner-email',
    OWNER_EMAIL,
  ],
  { cwd: ROOT, encoding: 'utf8' },
);
log(`\n--- 1) install-baseline --apply → exit ${install.status}`);
for (const l of `${install.stdout || ''}${install.stderr || ''}`
  .split('\n')
  .filter((l) => /^  |^---|^ok|SELESAI|GAGAL/.test(l))) {
  log(l);
}
check(install.status === 0, 'baseline terpasang', `exit ${install.status}`);

const tabel = (await c.query(
  `select count(*)::int as n from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind in ('r','p') and not c.relispartition`,
)).rows[0].n;
const menu = (await c.query(`select count(*)::int as n from public.module_definitions`)).rows[0].n;
check(tabel > 0 && menu > 0, 'skema + menu hidup', `${tabel} tabel, ${menu} menu`);

// ── 2. owner pertama: langkah DB dari first-owner.example.sql ───────────────
log('\n--- 2) owner pertama (langkah DB dari first-owner.example.sql)');
const ownerAuthId = randomUUID();
await c.query(`insert into auth.users (id, email) values ($1, $2) on conflict (id) do nothing`, [
  ownerAuthId,
  OWNER_EMAIL,
]);
await c.query(
  `insert into public.system_owner_identity (auth_id, owner_email, is_active)
   values ($1, $2, true)
   on conflict (auth_id) do update set owner_email = excluded.owner_email, is_active = true`,
  [ownerAuthId, OWNER_EMAIL],
);
const cfgEmail = (await c.query(
  `select config_value->>'value' as v from public.company_config where config_key='owner_email'`,
)).rows[0]?.v;
check(cfgEmail === OWNER_EMAIL, 'company_config.owner_email terisi', String(cfgEmail));
check(
  (await c.query(`select public.get_owner_email() as v`)).rows[0].v === OWNER_EMAIL,
  'get_owner_email() = email owner',
);

// ── 3. tiru sesi owner, lalu uji jalur login + dashboard ────────────────────
log('\n--- 3) sesi owner (SET LOCAL role + klaim JWT yang dibaca stub auth.*)');
await c.query('begin');
await c.query(`set local role authenticated`);
await c.query(`select set_config('request.jwt.claim.sub', $1, true)`, [ownerAuthId]);
await c.query(`select set_config('request.jwt.claim.role', 'authenticated', true)`);
await c.query(`select set_config('request.jwt.claim.email', $1, true)`, [OWNER_EMAIL]);

check((await c.query(`select auth.uid() as v`)).rows[0].v === ownerAuthId, 'auth.uid() = auth_id owner');
check(
  (await c.query(`select public.check_owner_identity() as v`)).rows[0].v === true,
  'check_owner_identity() = true (OwnerGuard lolos)',
);

let login = null;
try {
  login = (await c.query(`select public.owner_login($1) as r`, [OWNER_EMAIL])).rows[0].r;
  check(login?.ok === true, 'owner_login() = ok', JSON.stringify(login).slice(0, 120));
} catch (e) {
  check(false, 'owner_login() tidak error', e.message);
}

const DASHBOARD = [
  ['get_owner_overview_stats', `select public.get_owner_overview_stats() as r`],
  ['get_modules_for_owner', `select public.get_modules_for_owner() as r`],
  ['get_business_units_for_owner', `select public.get_business_units_for_owner() as r`],
  ['get_dashboard_stats', `select public.get_dashboard_stats() as r`],
];
log('\n  RPC dashboard (perusahaan baru: datanya boleh kosong, yang penting tidak error)');
for (const [nama, sql] of DASHBOARD) {
  try {
    const r = (await c.query(sql)).rows[0].r;
    const bentuk = Array.isArray(r) ? `${r.length} baris` : typeof r === 'object' && r ? `${Object.keys(r).length} field` : String(r);
    log(`    OK    ${nama} → ${bentuk}`);
  } catch (e) {
    check(false, `${nama} tidak error`, e.message);
  }
}
await c.query('rollback');

// ── 4. isolasi: anon tidak boleh menembus jalur owner ──────────────────────
log('\n--- 4) isolasi anon pada instalasi baru');
await c.query('begin');
await c.query('set local role anon');
let anonHasil = 'tidak diuji';
try {
  const r = (await c.query(`select public.check_owner_identity() as v`)).rows[0].v;
  anonHasil = `check_owner_identity() = ${r}`;
  check(r === false || r === null, 'anon tidak dianggap owner', anonHasil);
} catch (e) {
  anonHasil = `ditolak: ${e.message}`;
  check(true, 'anon ditolak saat memanggil RPC owner', anonHasil);
}
await c.query('rollback');

// ── 5. laporan ──────────────────────────────────────────────────────────────
const report = [
  '```',
  `=== latihan instalasi perusahaan baru: db=${DBNAME} ===`,
  ...LOG,
  '',
  `=== HASIL: ${failures.length === 0 ? 'PASS — perusahaan baru siap dipakai' : `${failures.length} MASALAH`} ===`,
  ...failures.map((f) => `  ✗ ${f}`),
  '',
  'Catatan penting:',
  `  * owner_auth_id di atas dibuat di tabel stub auth.users database scratch.`,
  `    Di project Supabase nyata, user Auth dibuat lewat --create-owner`,
  `    (butuh SUPABASE_URL + service key) atau Dashboard → Authentication. ${OWNER_PASSWORD_NOTE}`,
  '  * Latihan ini TIDAK menyentuh database live, dan DB scratch di-drop di akhir',
  '    kecuali dijalankan dengan --keep.',
  '```',
  '',
].join('\n');

const reportPath = path.join(ROOT, 'supabase', 'baseline', 'rehearse-new-company.md');
fs.writeFileSync(reportPath, report, 'utf8');
console.log(`\n=== HASIL: ${failures.length === 0 ? 'PASS' : `${failures.length} MASALAH`} ===`);
for (const f of failures) console.log(`  ✗ ${f}`);
console.log(`laporan: supabase/baseline/rehearse-new-company.md`);

await c.end();
await admin.query(
  'select pg_terminate_backend(pid) from pg_stat_activity where datname = $1 and pid <> pg_backend_pid()',
  [DBNAME],
);
if (!KEEP) {
  await admin.query(`drop database if exists ${DBNAME} with (force)`);
  console.log(`database scratch ${DBNAME} di-drop (pakai --keep untuk menyimpannya)`);
} else {
  console.log(`database scratch ${DBNAME} DISIMPAN (--keep)`);
}
await admin.end();
process.exitCode = failures.length === 0 ? 0 : 1;
