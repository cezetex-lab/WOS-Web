#!/usr/bin/env node
/**
 * verify-acl-dependencies.mjs — guard P1-POST-HARDENING-AUDIT (Tahap 1).
 *
 * KENAPA ADA
 *   `172_hardening_grants.sql` me-REVOKE seluruh fungsi lalu GRANT balik hanya
 *   daftar putih. Fungsi yang lahir/berubah setelah itu bisa berakhir tanpa
 *   `EXECUTE` untuk role pemanggilnya — dan **tidak ada satu pun gate** yang
 *   berteriak. Akibat nyata (audit 2026-10-18): 9 fungsi yang dipanggil
 *   `src/` mengembalikan `42501` di produksi berbulan-bulan tanpa terdeteksi.
 *   Guard yang diam = guard palsu (§0.19), jadi ketergantungan ACL dijadikan
 *   exit code.
 *
 * APA YANG DIPERIKSA (rujukan → role yang WAJIB bisa EXECUTE)
 *   1. `src/**` yang memanggil RPC        → `authenticated`
 *      (literal nama fungsi di berkas yang memakai `.rpc(`/`rpc(`/`useRpcQuery`)
 *   2. `PRE_AUTH_RPCS` (pra-login)        → `anon` + `authenticated`
 *      Daftar eksplisit + alasan; diverifikasi juga bahwa namanya benar-benar
 *      muncul di src/ (kalau tidak, guard MERAH → daftar basi).
 *   3. `supabase/functions/**`            → `service_role`
 *   4. Policy RLS (`pg_policies.qual`/`with_check`)
 *                                        → `authenticated`
 *      Kelas asli "46 grant yatim": policy tertulis, tapi evaluasinya 42501
 *      untuk SEMUA user (kasus `is_admin_or_owner`, ditutup migrasi 263).
 *   5. Overload: cukup SATU overload yang bisa dieksekusi (pemanggil memilih
 *      signature lewat argumen), kecuali overload itu memang satu-satunya.
 *
 * TIDAK diperiksa (sengaja, dengan alasan)
 *   - Trigger: fungsi trigger dieksekusi oleh mesin dengan hak pemilik fungsi,
 *     bukan role pemanggil → `EXECUTE` role tidak relevan. Dilaporkan sebagai
 *     INFO saja.
 *   - Cron `cron.job`: berjalan sebagai pemilik job (postgres) yang sudah punya
 *     hak; dilaporkan INFO.
 *
 * EXIT CODE
 *   0 = bersih · 1 = ada pelanggaran · 2 = TIDAK BISA MEMVERIFIKASI
 *   (DATABASE_URL absen / koneksi gagal / katalog kosong). Exit 2 disengaja:
 *   guard tidak boleh hijau palsu saat datanya tidak ada (§0.24).
 *
 * PEMAKAIAN
 *   npm run verify:acl-dependencies
 *   node scripts/verify-acl-dependencies.mjs --json   # ringkasan JSON saja
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';
import pg from 'pg';

dotenv.config({ path: '.env.local' });

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const JSON_ONLY = process.argv.includes('--json');

/**
 * RPC yang dipanggil SEBELUM sesi Supabase ada. Wajib bisa dieksekusi `anon`.
 * Setiap entri WAJIB punya alasan + bukti lokasi; guard memverifikasi nama ini
 * benar-benar muncul di src/ supaya daftar tidak membusuk.
 */
const PRE_AUTH_RPCS = [
  {
    name: 'check_registration_status',
    reason: 'Home.tsx memanggilnya di form cek status pendaftaran sebelum login',
    evidence: 'src/pages/Home.tsx',
  },
];

function walk(dir, out = []) {
  if (!fs.existsSync(dir)) return out;
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else if (/\.(ts|tsx|js|mjs|cjs)$/.test(e.name)) out.push(p);
  }
  return out;
}

const usesRpc = (txt) => /\.rpc\s*\(|\brpc\s*\(|useRpc(Query|Mutation)?\s*\(/.test(txt);

/** Kumpulkan literal nama fungsi dari berkas yang memakai jalur RPC. */
function collectLiterals(files, dbNames) {
  const hits = new Map(); // name → Set(relPath)
  for (const f of files) {
    const txt = fs.readFileSync(f, 'utf8');
    if (!usesRpc(txt)) continue;
    const rel = path.relative(ROOT, f).replace(/\\/g, '/');
    const lines = txt.split(/\r?\n/);
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const t = line.trim();
      if (t.startsWith('//') || t.startsWith('*')) continue;
      for (const name of dbNames) {
        if (line.includes(`'${name}'`) || line.includes(`"${name}"`) || line.includes('`' + name + '`')) {
          if (!hits.has(name)) hits.set(name, new Set());
          hits.get(name).add(`${rel}:${i + 1}`);
        }
      }
    }
  }
  return hits;
}

async function main() {
  const url = process.env.DATABASE_URL;
  if (!url) {
    console.error('verify:acl-dependencies — FATAL: DATABASE_URL tidak ada (tidak bisa diverifikasi).');
    process.exit(2);
  }

  const client = new pg.Client({ connectionString: url });
  try {
    await client.connect();
  } catch (e) {
    console.error('verify:acl-dependencies — FATAL: koneksi DB gagal:', e.message);
    process.exit(2);
  }

  try {
    const fns = await client.query(`
      SELECT p.oid, p.proname,
             has_function_privilege('authenticated', p.oid, 'EXECUTE') AS auth_exec,
             has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_exec,
             has_function_privilege('service_role', p.oid, 'EXECUTE') AS svc_exec
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public'`);

    if (fns.rowCount === 0) {
      console.error('verify:acl-dependencies — FATAL: katalog fungsi kosong (schema public).');
      process.exit(2);
    }

    const byName = new Map();
    for (const r of fns.rows) {
      if (!byName.has(r.proname)) byName.set(r.proname, []);
      byName.get(r.proname).push(r);
    }

    const dbNames = [...byName.keys()];
    const srcFiles = walk(path.join(ROOT, 'src'));
    const edgeFiles = walk(path.join(ROOT, 'supabase', 'functions'));

    const srcHits = collectLiterals(srcFiles, dbNames);
    const edgeHits = collectLiterals(edgeFiles, dbNames);

    // Policy RLS → nama fungsi di qual/with_check
    const pol = await client.query(
      `SELECT tablename, policyname, qual, with_check FROM pg_policies WHERE schemaname='public'`
    );
    const polText = pol.rows.map((r) => ({
      label: `${r.tablename}.${r.policyname}`,
      text: `${r.qual || ''} ${r.with_check || ''}`,
    }));

    const violations = [];
    const infos = [];

    // ── Aturan 1: src → authenticated ────────────────────────────────────────
    for (const [name, locs] of srcHits) {
      const overloads = byName.get(name) || [];
      if (overloads.length === 0) continue; // literal yang bukan nama fungsi DB
      if (!overloads.some((o) => o.auth_exec)) {
        violations.push({
          rule: 'src→authenticated',
          name,
          detail: `EXECUTE authenticated=false untuk semua ${overloads.length} overload`,
          evidence: [...locs].slice(0, 3),
        });
      }
    }

    // ── Aturan 2: PRE_AUTH → anon ───────────────────────────────────────────
    for (const p of PRE_AUTH_RPCS) {
      const overloads = byName.get(p.name) || [];
      if (overloads.length === 0) {
        violations.push({
          rule: 'pre-auth-listed-but-missing',
          name: p.name,
          detail: 'terdaftar di PRE_AUTH_RPCS tapi tidak ada di DB (daftar basi)',
          evidence: [p.evidence],
        });
        continue;
      }
      if (!srcHits.has(p.name)) {
        violations.push({
          rule: 'pre-auth-listed-but-unused',
          name: p.name,
          detail: 'terdaftar di PRE_AUTH_RPCS tapi namanya tidak muncul di berkas pemanggil RPC src/',
          evidence: [p.evidence],
        });
      }
      if (!overloads.some((o) => o.anon_exec)) {
        violations.push({
          rule: 'pre-auth→anon',
          name: p.name,
          detail: `EXECUTE anon=false (${p.reason})`,
          evidence: [p.evidence],
        });
      }
      if (!overloads.some((o) => o.auth_exec)) {
        violations.push({
          rule: 'pre-auth→authenticated',
          name: p.name,
          detail: 'EXECUTE authenticated=false (sesudah login tetap harus bisa)',
          evidence: [p.evidence],
        });
      }
    }

    // ── Aturan 3: edge → service_role ───────────────────────────────────────
    for (const [name, locs] of edgeHits) {
      const overloads = byName.get(name) || [];
      if (overloads.length === 0) continue;
      if (!overloads.some((o) => o.svc_exec)) {
        violations.push({
          rule: 'edge→service_role',
          name,
          detail: 'EXECUTE service_role=false untuk semua overload',
          evidence: [...locs].slice(0, 3),
        });
      }
    }

    // ── Aturan 4: policy RLS → authenticated ────────────────────────────────
    const rlsSeen = new Set();
    for (const [name, overloads] of byName) {
      const re = new RegExp(`\\b${name}\\s*\\(`, 'i');
      const refs = polText.filter((p) => re.test(p.text));
      if (refs.length === 0) continue;
      if (rlsSeen.has(name)) continue;
      rlsSeen.add(name);
      if (!overloads.some((o) => o.auth_exec)) {
        violations.push({
          rule: 'rls→authenticated',
          name,
          detail: `dirujuk policy RLS (${refs.map((r) => r.label).join(', ')}) tapi EXECUTE authenticated=false`,
          evidence: refs.slice(0, 3).map((r) => r.label),
        });
      }
    }

    // ── INFO: trigger & cron (tidak butuh EXECUTE role) ─────────────────────
    const trg = await client.query(`
      SELECT t.tgfoid AS oid, rel.relname AS tbl, t.tgname
      FROM pg_trigger t JOIN pg_class rel ON rel.oid = t.tgrelid
      WHERE NOT t.tgisinternal`);
    const trgNames = new Set();
    for (const r of trg.rows) {
      const f = fns.rows.find((x) => x.oid === r.oid);
      if (f) trgNames.add(f.proname);
    }
    if (trgNames.size) infos.push(`trigger functions (INFO, dieksekusi mesin): ${[...trgNames].join(', ')}`);

    let cronInfo = 'cron.job tidak terbaca (diabaikan, INFO)';
    try {
      const cron = await client.query('SELECT jobname, command FROM cron.job');
      cronInfo = `cron jobs (INFO, jalan sebagai postgres): ${cron.rows.length}`;
    } catch { /* cron schema tidak ada → INFO */ }
    infos.push(cronInfo);

    const summary = {
      generated_at: new Date().toISOString(),
      checked: {
        db_functions: fns.rowCount,
        src_rpc_names: srcHits.size,
        edge_rpc_names: edgeHits.size,
        rls_referenced_functions: rlsSeen.size,
        policies: pol.rows.length,
        src_files: srcFiles.length,
        edge_files: edgeFiles.length,
      },
      violations,
      infos,
    };

    if (JSON_ONLY) {
      console.log(JSON.stringify(summary, null, 2));
    } else {
      console.log('=== verify:acl-dependencies — P1-POST-HARDENING-AUDIT (Tahap 1) ===');
      console.log(
        `\n  fungsi DB        : ${summary.checked.db_functions}\n` +
          `  RPC dari src/    : ${srcHits.size} nama\n` +
          `  RPC dari edge    : ${edgeHits.size} nama\n` +
          `  fungsi di RLS    : ${rlsSeen.size}\n` +
          `  policy RLS       : ${pol.rows.length}`
      );
      for (const i of infos) console.log(`  INFO ${i}`);
      if (violations.length === 0) {
        console.log('\n=== RINGKASAN: 0 pelanggaran ===');
        console.log('verify:acl-dependencies OK — setiap fungsi yang dirujuk RLS/src/edge bisa dieksekusi role pemanggilnya.');
      } else {
        console.log(`\n=== PELANGGARAN: ${violations.length} ===`);
        for (const v of violations) {
          console.log(`  VIOLATION [${v.rule}] ${v.name} — ${v.detail}`);
          for (const e of v.evidence) console.log(`      ${e}`);
        }
        console.log('\n=== RINGKASAN: ' + violations.length + ' pelanggaran ===');
        console.log('verify:acl-dependencies MERAH — tambahkan GRANT (dan gate/scope bila perlu) atau perbaiki rujukannya.');
      }
    }

    await client.end();
    process.exit(violations.length === 0 ? 0 : 1);
  } catch (e) {
    console.error('verify:acl-dependencies — FATAL:', e.message);
    try { await client.end(); } catch { /* ignore */ }
    process.exit(2);
  }
}

main();
