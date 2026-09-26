#!/usr/bin/env node
/**
 * verify-derived-artifacts.mjs — penjaga artefak turunan (Batch Fix #2).
 *
 * Menutup Akar A (P1-71-01): angka yang ditulis manual di ARCHITECTURE.md
 * (tabel/fungsi/migrasi/policy/grant) meluruh tiap ada migrasi, dan tidak ada
 * yang menangkapnya — job 88-audit hanya membandingkan unit test vs live,
 * tidak membandingkan dokumen vs live.
 *
 * Exit 1 bila ada drift, 0 bila sinkron.
 *
 * PENTING: angka file TS dihitung dengan metodologi IDENTIK dengan
 * tests/unit/doc-claims-vs-live.test.ts (berkas git ter-track), agar guard ini
 * dan test tersebut tidak saling bertentangan.
 */
import fs from 'node:fs';
import { execSync } from 'node:child_process';
import pg from 'pg';
import dotenv from 'dotenv';

dotenv.config({ path: '.env.local' });

const W = { pass: '\x1b[32m', fail: '\x1b[31m', warn: '\x1b[33m', dim: '\x1b[2m', off: '\x1b[0m' };
let failures = 0;
let warnings = 0;

function check(label, doc, live, { soft = false } = {}) {
  const ok = String(doc) === String(live);
  if (!ok) {
    if (soft) { warnings++; console.log(`  ${W.warn}WARN${W.off}  ${label.padEnd(20)} dok=${doc} live=${live}`); }
    else { failures++; console.log(`  ${W.fail}DRIFT${W.off} ${label.padEnd(20)} dok=${doc} live=${live}`); }
  } else {
    console.log(`  ${W.pass}OK${W.off}    ${label.padEnd(20)} ${live}`);
  }
  return ok;
}

async function main() {
  const sh = (cmd) => { try { return execSync(cmd, { encoding: 'utf8', shell: 'cmd.exe', maxBuffer: 16e6 }).trim(); } catch { return ''; } };

  const url = process.env.DATABASE_URL;
  if (!url) { console.error(`${W.fail}FATAL${W.off} DATABASE_URL tidak ada (.env.local). Cannot verify live.`); process.exit(1); }

  const c = new pg.Client({ connectionString: url });
  await c.connect();
  const one = async (s) => (await c.query(s)).rows[0];

  const live = {
    tables: (await one(`select count(*)::int n from pg_tables where schemaname='public'`)).n,
    functions: (await one(`select count(*)::int n from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'`)).n,
    migrationRows: (await one(`select count(*)::int n from schema_migrations`)).n,
    maxVersion: Number((await one(`select coalesce(max(version::int),0) v from schema_migrations`)).v),
    policies: (await one(`select count(*)::int n from pg_policies where schemaname='public'`)).n,
    notForceRls: (await one(`select count(*)::int n from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and c.relrowsecurity and not c.relforcerowsecurity`)).n,
    // PENTING: TANPA filter prokind — definisi ini WAJIB identik dengan
    // tests/unit/doc-claims-vs-live.test.ts. Menambahkan `prokind='f'` membuat
    // hitungan 126 (4 aggregate/procedure terlewat) dan menganggap angka dokumen
    // 130 sebagai drift — itu SALAH: angka dokumen sudah benar sejak awal.
    anonGrants: (await one(`select count(*)::int n from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and has_function_privilege('anon',p.oid,'EXECUTE')`)).n,
    cronJobs: (await one(`select count(*)::int n from cron.job`)).n,
  };

  // grant pra-login WAJIB utuh — ini guard keamanan, bukan sekadar angka dokumen
  const lockout = (await one(`select coalesce(bool_or(has_function_privilege('anon',p.oid,'EXECUTE')),false) ok from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='check_login_lockout'`))?.ok;
  await c.end();

  // --- repo (metodologi identik doc-claims-vs-live.test.ts) ---
  const tracked = sh('git ls-files').split('\n').filter(Boolean);
  const cnt = (p, e) => tracked.filter((f) => f.startsWith(p) && e.some((x) => f.endsWith(x))).length;
  const repo = {
    src: cnt('src/', ['.ts', '.tsx']),
    tests: cnt('tests/', ['.ts', '.tsx']),
    config: tracked.filter((f) => !f.includes('/') && f.endsWith('.config.ts')).length,
  };
  repo.total = repo.src + repo.tests + repo.config;

  const migFiles = fs.readdirSync('supabase/migrations').filter((f) => f.endsWith('.sql'));
  const migVersions = migFiles.map((f) => parseInt(f, 10));
  const lastVersion = Math.max(...migVersions);
  const sharedVersions = [...new Set(migVersions.filter((v, i) => migVersions.indexOf(v) !== i))].sort((a, b) => a - b);

  // --- dokumen ---
  const arch = fs.readFileSync('ARCHITECTURE.md', 'utf8');
  const doc = {
    tables: /\| Tables \| (\d+) \|/.exec(arch)?.[1],
    functions: /\| Functions \| (\d+) \|/.exec(arch)?.[1],
    migrations: /\| Migrations tracked \| (\d+) \|/.exec(arch)?.[1],
    policies: /\| RLS policies \| All tables \((\d+)\)/.exec(arch)?.[1],
    notForce: /\| RLS policies \| All tables \(\d+\) \|[^|]*?(\d+) tabel belum FORCE/.exec(arch)?.[1],
    anon: /\| anon\/PUBLIC grants \| (\d+) \|/.exec(arch)?.[1],
    cron: /\| pg_cron jobs \| (\d+) \|/.exec(arch)?.[1],
  };
  const ts = /(\d+) file TS total \((\d+) `src` \+ (\d+) `tests` \+ (\d+) config\)/.exec(arch);

  console.log(`\n=== verify:artifacts — cek artefak turunan (doc vs live) ===\n`);

  console.log('  -- ARCHITECTURE.md §7.4 vs DB live --');
  check('Tables', doc.tables, live.tables);
  check('Functions', doc.functions, live.functions);
  check('Migrations tracked', doc.migrations, live.migrationRows);
  check('RLS policies', doc.policies, live.policies);
  check('No-FORCE RLS', doc.notForce, live.notForceRls);
  check('anon grants', doc.anon, live.anonGrants);
  check('pg_cron jobs', doc.cron, live.cronJobs);

  console.log('\n  -- ARCHITECTURE.md §7.3 vs isi repo --');
  check('TS total', ts?.[1], repo.total);
  check('TS src', ts?.[2], repo.src);
  check('TS tests', ts?.[3], repo.tests);
  check('TS config', ts?.[4], repo.config);

  console.log('\n  -- registry schema_migrations (P1-31-01) --');
  check('migration rows', migFiles.length, live.migrationRows);
  check('max(version)', lastVersion, live.maxVersion);
  console.log(`  ${W.dim}info${W.off}   nomor versi dipakai >1 file: ${sharedVersions.length ? sharedVersions.join(', ') : 'tidak ada'} (sah — komentar migrasi 219)`);

  console.log('\n  -- guard keamanan (bukan angka dokumen) --');
  if (lockout === true) console.log(`  ${W.pass}OK${W.off}    check_login_lockout granting ke anon (pra-login)`);
  else { failures++; console.log(`  ${W.fail}DRIFT${W.off} check_login_lockout TIDAK granting ke anon — alur lockout pra-login fail-open!`); }

  console.log('\n  -- baseline installer (P1-68-01 → Fix #9, infosional) --');
  const bPath = 'supabase/baseline/000_baseline_schema.sql';
  if (fs.existsSync(bPath)) {
    const bCommit = sh(`git log -1 --format=%cI -- ${bPath}`);
    warnings++;
    console.log(`  ${W.warn}WARN${W.off}  baseline commit ${bCommit}; regenerasi = Fix #9 (di luar scope batch ini)`);
  } else {
    console.log(`  ${W.dim}info${W.off}   ${bPath} tidak ada`);
  }

  console.log(`\n=== RINGKASAN: ${failures} drift, ${warnings} warning ===\n`);
  if (failures > 0) {
    console.error(`${W.fail}verify:artifacts GAGAL${W.off} — ${failures} artefak turunan tidak sinkron dengan live.`);
    console.error('  Perbarui ARCHITECTURE.md §7.3/§7.4 ke angka live, atau jalankan migrasi yang sesuai.');
    process.exit(1);
  }
  console.log(`${W.pass}verify:artifacts OK${W.off} — artefak turunan sinkron dengan live.`);
  process.exit(0);
}

main().catch((e) => { console.error(`${W.fail}FATAL${W.off}`, e.message); process.exit(1); });
