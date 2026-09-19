#!/usr/bin/env node
/**
 * replay-fresh-install.mjs — membuktikan instalasi dari awal benar-benar jalan.
 *
 * Membuat DATABASE sekali pakai di cluster yang sama, menyiapkan prasyarat yang
 * disediakan platform Supabase (schema `extensions` + `auth`, auth.uid()/role()/jwt(),
 * auth.users, stub `cron`), lalu menjalankan:
 *   --mode=baseline  : seluruh berkas `supabase/baseline/*.sql` berurutan
 *   --mode=chain     : seluruh migrasi `supabase/migrations/*.sql` berurutan (000..NNN)
 *
 * Tiap berkas dijalankan dalam BEGIN/COMMIT sendiri supaya satu error TIDAK
 * menghentikan sisanya — yang kita ingin adalah daftar LENGKAP pelanggar.
 *
 * Setelah itu metrik dan ACL hasil replay DIBANDINGKAN dengan DB live; untuk ACL
 * perbandingannya per objek+grantee sehingga hak untuk PUBLIC ikut terperiksa.
 *
 * Catatan pg_cron: `CREATE EXTENSION pg_cron` hanya boleh di database `postgres`
 * pada cluster Supabase, jadi di database scratch ini selalu gagal. Migrasi 186/212
 * sudah dibungkus guard `EXCEPTION`; harness ini menyediakan stub `cron.schedule/
 * unschedule` supaya berkas yang menjadwalkan job tetap bisa dijalankan.
 *
 * Pakai:
 *   node supabase/scripts/replay-fresh-install.mjs --mode=chain
 *   node supabase/scripts/replay-fresh-install.mjs --mode=baseline --twice
 *   node supabase/scripts/replay-fresh-install.mjs --mode=chain --keep
 *
 * Exit code 1 bila ada berkas yang GAGAL — aman dipakai sebagai gate CI.
 * Laporan: supabase/baseline/replay-<mode>.md
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';
import { PREREQS as PREREQS_SQL } from './platform-prereqs.mjs';

const argv = process.argv.slice(2);
const arg = (n, d = undefined) => {
  const hit = argv.find((a) => a.startsWith(`--${n}=`));
  return hit ? hit.slice(n.length + 3) : d;
};
const MODE = arg('mode', 'chain');
const DBNAME = arg('db', `wos_replay_${MODE}`);
const UPTO = Number(arg('upto', '0')) || 0;
const KEEP = argv.includes('--keep');
const TWICE = argv.includes('--twice');

if (!['chain', 'baseline'].includes(MODE)) {
  console.error('mode harus "chain" atau "baseline"');
  process.exit(2);
}
if (!/^wos_replay_/.test(DBNAME)) {
  console.error('menolak: nama database harus diawali "wos_replay_" (pengaman anti-salah-target)');
  process.exit(2);
}

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
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

// ────────────────────────────────────────────────────────────────
// Prasyarat yang disediakan platform Supabase (tidak ada di DB kosong).
// PENTING: schema `extensions` dibuat LEBIH DULU — kalau tidak,
// `CREATE EXTENSION ... WITH SCHEMA extensions` gagal dan mematikan berkas awal.
// ────────────────────────────────────────────────────────────────
const PREREQS = PREREQS_SQL;


const METRICS = `
  select 'tabel_non_partisi' k, count(*)::text v from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind in ('r','p') and not c.relispartition
  union all select 'partisi', count(*)::text from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relispartition
  union all select 'view', count(*)::text from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind='v'
  union all select 'fungsi_project', count(*)::text from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and not exists (select 1 from pg_depend d where d.objid=p.oid and d.deptype='e')
  union all select 'policy', count(*)::text from pg_policies where schemaname='public'
  union all select 'trigger', count(*)::text from pg_trigger t join pg_class c on c.oid=t.tgrelid
    join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and not t.tgisinternal
  union all select 'rls_enabled', count(*)::text from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind in ('r','p') and c.relrowsecurity
  union all select 'rls_forced', count(*)::text from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind in ('r','p') and c.relforcerowsecurity
  union all select 'sequence', count(*)::text from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind='S'
  union all select 'index', count(*)::text from pg_indexes where schemaname='public'
  union all select 'cron_job', count(*)::text from cron.job
  union all select 'migration_cap', count(*)::text from schema_migrations
`;
const metrics = async (client) =>
  Object.fromEntries((await client.query(METRICS)).rows.map((r) => [r.k, Number(r.v)]));

// ACL per objek+grantee; left join + coalesce('PUBLIC') supaya hak PUBLIC ikut terbaca.
const ACLQ = `
  select 'rel:' || c.relname || ':' || coalesce(g.rolname,'PUBLIC') obj,
         string_agg(distinct a.privilege_type, ',' order by a.privilege_type) privs
    from pg_class c join pg_namespace n on n.oid=c.relnamespace
    cross join lateral aclexplode(c.relacl) a
    left join pg_roles g on g.oid=a.grantee
   where n.nspname='public' and c.relkind in ('r','p','v','S')
   group by 1
  union all
  select 'fn:' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || '):' || coalesce(g.rolname,'PUBLIC'),
         string_agg(distinct a.privilege_type, ',' order by a.privilege_type)
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    cross join lateral aclexplode(p.proacl) a
    left join pg_roles g on g.oid=a.grantee
   where n.nspname='public' and not exists (select 1 from pg_depend d where d.objid=p.oid and d.deptype='e')
   group by 1
`;
const aclOf = async (client) => {
  const m = new Map();
  for (const r of (await client.query(ACLQ)).rows) m.set(r.obj, r.privs);
  return m;
};

// ────────────────────────────────────────────────────────────────
// Jalankan di database sekali pakai
// ────────────────────────────────────────────────────────────────
const admin = new pg.Client({ connectionString: ADMIN_URL, ssl: { rejectUnauthorized: false } });
await admin.connect();
log(`=== replay instalasi dari awal: mode=${MODE} db=${DBNAME} ===`);
await admin.query(
  `select pg_terminate_backend(pid) from pg_stat_activity where datname = $1 and pid <> pg_backend_pid()`,
  [DBNAME],
);
await admin.query(`drop database if exists ${DBNAME} with (force)`);
await admin.query(`create database ${DBNAME}`);
log(`database scratch dibuat: ${DBNAME} (database kosong, tanpa objek apa pun)`);

const c = new pg.Client({ connectionString: withDb(DBNAME), ssl: { rejectUnauthorized: false } });
await c.connect();

// PREREQ DULU (schema extensions + auth), baru extension — urutan ini penting:
// `CREATE EXTENSION ... WITH SCHEMA extensions` gagal bila schema belum ada.
await c.query(PREREQS);
log('prereq platform: schema extensions+auth, auth.uid()/role()/email()/jwt(), auth.users, stub cron, default privilege Supabase — OK');

for (const ext of ['pgcrypto', 'uuid-ossp', 'vector']) {
  try {
    await c.query(`create extension if not exists "${ext}"`);
    log(`extension ${ext}: OK`);
  } catch (e) {
    log(`extension ${ext}: dilewati (${String(e.message).split('\n')[0]})`);
  }
}

async function applyFile(label, sql) {
  const started = Date.now();
  try {
    await c.query('BEGIN');
    await c.query(sql);
    await c.query('COMMIT');
    return { label, ok: true, ms: Date.now() - started };
  } catch (e) {
    try {
      await c.query('ROLLBACK');
    } catch {
      /* diabaikan: koneksi sudah tidak dalam transaksi */
    }
    return { label, ok: false, ms: Date.now() - started, error: (e.message || String(e)).split('\n')[0].slice(0, 220) };
  }
}

const basename = MODE === 'baseline' ? 'BASELINE' : 'MIGRATION';
const dir = path.join(ROOT, MODE === 'baseline' ? 'supabase/baseline' : 'supabase/migrations');
const files = fs
  .readdirSync(dir)
  // HANYA berkas instalasi berpola `NNN_nama.sql`. Tanpa batasan ini, berkas bantu
  // seperti `first-owner.example.sql` ikut dieksekusi dan menggagalkan instalasi.
  .filter((f) => /^\d+_.*\.sql$/.test(f))
  .filter((f) => (UPTO ? (parseInt(f, 10) || 0) <= UPTO : true))
  .sort((a, b) => (parseInt(a, 10) || 0) - (parseInt(b, 10) || 0) || a.localeCompare(b));
if (UPTO) log(`--upto=${UPTO} → hanya ${files.length} berkas dijalankan`);

const results = [];
for (const f of files) {
  results.push(await applyFile(`${basename} ${f}`, fs.readFileSync(path.join(dir, f), 'utf8')));
}

const failed = results.filter((r) => !r.ok);
log(`\n=== HASIL: ${results.length - failed.length}/${results.length} berkas sukses, ${failed.length} GAGAL ===`);
if (failed.length) {
  log('\n--- DAFTAR GAGAL (urut) ---');
  for (const f of failed) log(`ERROR  ${f.label}\n       ${f.error}`);
}
log('\n--- DAFTAR SUKSES ---');
for (const r of results.filter((x) => x.ok)) log(`ok     ${r.label} (${r.ms}ms)`);

// ────────────────────────────────────────────────────────────────
// Bandingkan hasil replay dengan DB live
// ────────────────────────────────────────────────────────────────
const live = new pg.Client({ connectionString: URL, ssl: { rejectUnauthorized: false } });
await live.connect();
const liveM = await metrics(live);
const scratchM = await metrics(c);
log('\n--- METRIK: live vs hasil replay ---');
for (const k of Object.keys(liveM)) {
  const a = liveM[k];
  const b = scratchM[k] ?? 0;
  log(`  ${a === b ? 'SAMA ' : 'BEDA '} ${k.padEnd(18)} live=${String(a).padStart(5)}  replay=${String(b).padStart(5)}`);
}

const liveAcl = await aclOf(live);
const scrAcl = await aclOf(c);
const missing = [...liveAcl.keys()].filter((k) => !scrAcl.has(k));
const extra = [...scrAcl.keys()].filter((k) => !liveAcl.has(k));
const differing = [...liveAcl.keys()].filter((k) => scrAcl.has(k) && scrAcl.get(k) !== liveAcl.get(k));
log('\n--- BANDING ACL (live vs replay) ---');
log(`  entri ACL live=${liveAcl.size} replay=${scrAcl.size}`);
log(`  HILANG di replay : ${missing.length}`);
for (const k of missing.slice(0, 25)) log(`     - ${k} [${liveAcl.get(k)}]`);
log(`  BERLEBIH di replay: ${extra.length}`);
for (const k of extra.slice(0, 25)) log(`     + ${k} [${scrAcl.get(k)}]`);
log(`  BEDA hak          : ${differing.length}`);
for (const k of differing.slice(0, 25)) log(`     ~ ${k} live=[${liveAcl.get(k)}] replay=[${scrAcl.get(k)}]`);

// Uji eksplisit: RPC yang dicabut anon/PUBLIC harus sama di replay.
const execRolesQ = `
  select distinct coalesce(g.rolname,'PUBLIC') g
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    cross join lateral aclexplode(p.proacl) a
    left join pg_roles g on g.oid=a.grantee
   where n.nspname='public' and p.proname=$1 and a.privilege_type='EXECUTE' order by 1`;
log('\n  uji revoke anon/PUBLIC (harus MATCH dengan live):');
for (const fn of ['worker_update_profile', 'admin_get_payroll', 'get_worker_profile', 'login_worker_by_email']) {
  const s = (await c.query(execRolesQ, [fn])).rows.map((r) => r.g);
  const l = (await live.query(execRolesQ, [fn])).rows.map((r) => r.g);
  log(`     ${fn.padEnd(24)} live=[${l.join(',')}] replay=[${s.join(',')}] ${JSON.stringify(l) === JSON.stringify(s) ? 'MATCH' : 'BEDA'}`);
}
await live.end();

// ────────────────────────────────────────────────────────────────
// Uji idempotensi (khusus baseline): jalankan ulang di DB yang sama
// ────────────────────────────────────────────────────────────────
let rerunFailed = 0;
if (MODE === 'baseline' && TWICE) {
  log('\n--- UJI IDEMPOTENSI: baseline dijalankan ULANG di database yang sama ---');
  for (const f of files) {
    const r = await applyFile(`RE-RUN ${f}`, fs.readFileSync(path.join(dir, f), 'utf8'));
    if (!r.ok) rerunFailed += 1;
    log(`  ${r.ok ? 'ok  ' : 'GAGAL'} ${f}${r.ok ? ` (${r.ms}ms)` : '\n       ' + r.error}`);
  }
  log(`  hasil: ${files.length - rerunFailed}/${files.length} berkas idempoten`);
}

// ────────────────────────────────────────────────────────────────
// Laporan + bersih-bersih
// ────────────────────────────────────────────────────────────────
const report = path.join(ROOT, `supabase/baseline/replay-${MODE}.md`);
fs.mkdirSync(path.dirname(report), { recursive: true });
fs.writeFileSync(
  report,
  ['```', ...LOG, '```', ''].join('\n'),
);
log(`\nlaporan: ${path.relative(ROOT, report).replace(/\\/g, '/')}`);

await c.end();
if (!KEEP) {
  await admin.query(
    `select pg_terminate_backend(pid) from pg_stat_activity where datname = $1 and pid <> pg_backend_pid()`,
    [DBNAME],
  );
  await admin.query(`drop database if exists ${DBNAME} with (force)`);
  console.log(`database scratch ${DBNAME} di-drop (pakai --keep untuk menyimpannya)`);
}
await admin.end();

process.exit(failed.length > 0 || rerunFailed > 0 ? 1 : 0);