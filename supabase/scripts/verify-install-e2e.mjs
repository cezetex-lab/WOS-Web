#!/usr/bin/env node
/**
 * verify-install-e2e.mjs — bukti end-to-end bahwa `install-baseline.mjs` benar-benar
 * bisa memasang perusahaan baru ke project KOSONG, memakai skrip yang dikirim ke
 * operator (bukan harness replay).
 *
 * Yang diuji:
 *   1. preflight installer pada project kosong LOLOS (tanpa --force)
 *   2. `--apply` menulis 2 berkas baseline dan keluar dengan kode 0
 *   3. metrik hasil = DB live (tabel/fungsi/policy/trigger/partisi/cron/cap migrasi)
 *   4. branding NETRAL (bukan merek kita) dan menu hidup (module_definitions > 0)
 *   5. menjalankan installer LAGI dengan --force sukses (idempoten)
 *
 * Pakai: node supabase/scripts/verify-install-e2e.mjs
 * Database scratch sekali pakai, namanya selalu diawali `wos_replay_`, dan di-drop
 * di akhir kecuali `--keep`.
 */
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import pg from 'pg';
import { PREREQS } from './platform-prereqs.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const argv = process.argv.slice(2);
const KEEP = argv.includes('--keep');
const DBNAME = 'wos_replay_install_e2e';
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

const METRICS = {
  tabel_non_partisi: `select count(*)::int as n from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind in ('r','p') and not c.relispartition`,
  partisi: `select count(*)::int as n from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relispartition`,
  view: `select count(*)::int as n from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='v'`,
  fungsi_project: `select count(*)::int as n from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prokind='f' and not exists (select 1 from pg_depend d where d.objid=p.oid and d.deptype='e')`,
  policy: `select count(*)::int as n from pg_policies where schemaname='public'`,
  trigger: `select count(*)::int as n from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and not t.tgisinternal`,
  sequence: `select count(*)::int as n from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='S'`,
  cron_job: `select count(*)::int as n from cron.job`,
  migration_cap: `select count(*)::int as n from public.schema_migrations`,
};

const admin = new pg.Client({ connectionString: ADMIN_URL, ssl: { rejectUnauthorized: false } });
await admin.connect();
log(`=== uji end-to-end installer baseline: db=${DBNAME} ===`);
await admin.query(
  `select pg_terminate_backend(pid) from pg_stat_activity where datname = $1 and pid <> pg_backend_pid()`,
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
    /* dilewati bila extension tidak tersedia di cluster ini */
  }
}
log('prereq platform disiapkan (schema auth/extensions, auth.*(), stub cron, default privilege)');

const installer = path.join(ROOT, 'supabase/scripts/install-baseline.mjs');
const failures = [];
const runInstaller = (extra) => {
  const r = spawnSync(process.execPath, [installer, '--target', scratchUrl, ...extra], {
    cwd: ROOT,
    encoding: 'utf8',
  });
  return { code: r.status, out: `${r.stdout || ''}${r.stderr || ''}` };
};

// 1) preflight pada project kosong: HARUS lolos tanpa --force
const dry = runInstaller([]);
log(`\n--- 1) dry run (project kosong) → exit ${dry.code}`);
log(`  ${dry.out.split('\n').find((l) => l.includes('tabel di public')) || '(baris preflight tidak ditemukan)'}`);
if (dry.code !== 0) {
  failures.push(`dry run pada project kosong gagal (exit ${dry.code})`);
  log(dry.out);
}

// 2) apply sungguhan, dengan identitas perusahaan seperti instalasi nyata
const UJI_NAMA = 'PT Uji Instalasi Otomatis';
const UJI_EMAIL = 'owner@uji-instalasi.test';
const apply = runInstaller(['--apply', '--company-name', UJI_NAMA, '--owner-email', UJI_EMAIL]);
log(`\n--- 2) --apply → exit ${apply.code}`);
for (const line of apply.out.split('\n').filter((l) => /^  |^---|^ok|SELESAI/.test(l))) log(line);
if (apply.code !== 0) failures.push(`--apply gagal (exit ${apply.code})`);

// 3) metrik vs live
const live = new pg.Client({ connectionString: URL, ssl: { rejectUnauthorized: false } });
await live.connect();
log('\n--- 3) metrik: live vs hasil instalasi lewat installer ---');
for (const [k, sql] of Object.entries(METRICS)) {
  const a = (await live.query(sql)).rows[0].n;
  const b = (await c.query(sql)).rows[0].n;
  log(`  ${a === b ? 'SAMA ' : 'BEDA '} ${k.padEnd(18)} live=${String(a).padStart(5)}  install=${String(b).padStart(5)}`);
  if (a !== b) failures.push(`metrik ${k} beda: live=${a} install=${b}`);
}

// 4) identitas perusahaan + menu hidup + tidak mewarisi identitas DB sumber
const brand = (await c.query(`select company_name from public.branding`)).rows;
const menu = (await c.query(`select count(*)::int as n from public.module_definitions`)).rows[0].n;
const liveBrand = (await live.query(`select company_name from public.branding`)).rows[0]?.company_name ?? null;
const ownerCfg = (await c.query(`select config_value->>'value' as v from public.company_config where config_key='owner_email'`)).rows[0]?.v ?? null;
const ownerFn = (await c.query(`select public.get_owner_email() as v`)).rows[0]?.v ?? null;
const ceoCfg = (await c.query(`select count(*)::int as n from public.company_config where config_key='ceo_email'`)).rows[0].n;
log('\n--- 4) identitas perusahaan hasil instalasi ---');
log(`  branding.company_name   : ${JSON.stringify(brand[0]?.company_name ?? null)}  (dari --company-name)`);
log(`  company_config.owner_email : ${JSON.stringify(ownerCfg)}  (dari --owner-email)`);
log(`  get_owner_email()        : ${JSON.stringify(ownerFn)}  (harus sama dengan owner_email)`);
log(`  ceo_email (tidak diwariskan) : ${ceoCfg} baris`);
log(`  module_definitions       : ${menu}`);
log(`  merek DB sumber (tidak boleh muncul) : ${JSON.stringify(liveBrand)}`);
if (!brand.length) failures.push('baris branding tidak ada di hasil instalasi');
else if (brand[0].company_name !== UJI_NAMA) {
  failures.push(`branding tidak memakai --company-name (didapat ${JSON.stringify(brand[0].company_name)})`);
}
if (!brand.length || (liveBrand && brand[0].company_name === liveBrand)) {
  failures.push(`branding instalasi MEWARISI merek DB sumber (${liveBrand})`);
}
if (ownerCfg !== UJI_EMAIL) failures.push(`owner_email tidak terisi dari --owner-email (didapat ${JSON.stringify(ownerCfg)})`);
if (ownerFn !== UJI_EMAIL) failures.push(`get_owner_email() tidak sama dengan owner_email (didapat ${JSON.stringify(ownerFn)})`);
if (ceoCfg !== 0) failures.push(`ceo_email DB sumber masih ikut terwarisi (${ceoCfg} baris)`);
if (!menu) failures.push('module_definitions kosong — menu/route tidak akan muncul');
await live.end();

// 5) idempoten (dihitung SEBELUM run ulang, supaya perbandingannya bermakna)
const beforeRerun = (await c.query(METRICS.tabel_non_partisi)).rows[0].n;
const beforeCap = (await c.query(METRICS.migration_cap)).rows[0].n;
const again = runInstaller(['--apply', '--force', '--company-name', UJI_NAMA, '--owner-email', UJI_EMAIL]);
log(`\n--- 5) jalankan ulang dengan --force (uji idempoten) → exit ${again.code}`);
const okLines = again.out.split('\n').filter((l) => l.includes('ok ('));
for (const l of okLines) log(`    ${l.trim()}`);
if (again.code !== 0) failures.push(`run ulang gagal (exit ${again.code})`);
const afterRerun = (await c.query(METRICS.tabel_non_partisi)).rows[0].n;
const afterCap = (await c.query(METRICS.migration_cap)).rows[0].n;
log(`  tabel non-partisi : sebelum=${beforeRerun} sesudah=${afterRerun} (harus sama)`);
log(`  cap migrasi       : sebelum=${beforeCap} sesudah=${afterCap} (harus sama)`);
if (afterRerun !== beforeRerun) failures.push(`run ulang mengubah jumlah tabel (${beforeRerun} → ${afterRerun})`);
if (afterCap !== beforeCap) failures.push(`run ulang mengubah cap migrasi (${beforeCap} → ${afterCap})`);

await c.end();
if (!KEEP) {
  await admin.query(
    `select pg_terminate_backend(pid) from pg_stat_activity where datname = $1 and pid <> pg_backend_pid()`,
    [DBNAME],
  );
  await admin.query(`drop database if exists ${DBNAME} with (force)`);
  log(`\ndatabase scratch ${DBNAME} di-drop (pakai --keep untuk menyimpannya)`);
}
await admin.end();

log(`\n=== HASIL: ${failures.length === 0 ? 'PASS — installer siap dipakai' : `${failures.length} MASALAH`} ===`);
for (const f of failures) log(`  ✗ ${f}`);

const report = path.join(ROOT, 'supabase/baseline/verify-install-e2e.md');
fs.mkdirSync(path.dirname(report), { recursive: true });
fs.writeFileSync(report, '```\n' + LOG.join('\n') + '\n```\n');
console.log(`laporan: supabase/baseline/verify-install-e2e.md`);
process.exit(failures.length === 0 ? 0 : 1);
