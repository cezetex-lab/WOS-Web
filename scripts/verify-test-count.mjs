#!/usr/bin/env node
/**
 * verify-test-count.mjs — penjaga angka "Unit tests" di ARCHITECTURE.md §7.5
 * (residual Batch Fix #2).
 *
 * KENAPA ADA
 *   `verify-derived-artifacts.mjs` menjaga angka tabel/fungsi/migrasi/policy/grant
 *   dan jumlah file TS, tapi TIDAK menjaga jumlah test. Akibatnya ARCHITECTURE.md
 *   sempat menulis "132/132 · 20 berkas" sementara repo sudah 141/141 · 22 berkas
 *   (angka 132 berasal dari commit `61bcc72`, 2026-09-19). Pola Akar A yang
 *   sama: angka meluruh tiap ada test baru, tak ada yang menangkap.
 *
 * CARA KERJA (PENTING — soal biaya CI)
 *   Script ini TIDAK menjalankan vitest sendiri. Ia membaca JSON yang sudah
 *   dihasilkan step `Unit test` di ci.yml. Jadi guard menambah ~0 detik.
 *   Kalau JSON tidak ada, fall back ke menghitung berkas test saja (tanpa
 *   menjalankan suite) — itu cukup menangkap kasus yang paling sering
 *   (test/berkas baru tapi dokumen tidak ditulis ulang).
 *
 * PEMAKAIAN
 *   node scripts/verify-test-count.mjs                       # baca .vitest/test-result.json
 *   node scripts/verify-test-count.mjs --json <path.json>    # path eksplisit
 *   node scripts/verify-test-count.mjs --offline             # hanya hitung berkas, tanpa JSON
 *
 * Exit 0 = sinkron, 1 = drift.
 */
import fs from 'node:fs';
import path from 'node:path';

const argv = process.argv.slice(2);
const arg = (n, d) => {
  const hit = argv.find((a) => a.startsWith(`--${n}=`));
  return hit ? hit.slice(n.length + 3) : d;
};
const OFFLINE = argv.includes('--offline');

const W = { pass: '\x1b[32m', fail: '\x1b[31m', warn: '\x1b[33m', dim: '\x1b[2m', off: '\x1b[0m' };
let failures = 0;
let warnings = 0;

function check(label, doc, live) {
  const ok = String(doc) === String(live);
  if (!ok) {
    failures++;
    console.log(`  ${W.fail}DRIFT${W.off} ${label.padEnd(18)} dok=${doc} live=${live}`);
  } else {
    console.log(`  ${W.pass}OK${W.off}    ${label.padEnd(18)} ${live}`);
  }
  return ok;
}

// --- angka dokumen ---
const arch = fs.readFileSync('ARCHITECTURE.md', 'utf8');
// "| Unit tests | ✅ 141/141 | vitest (22 berkas: ...)"
const m = /\|\s*Unit tests\s*\|\s*✅?\s*(\d+)\/(\d+)\s*\|[^|]*?\((\d+) berkas/.exec(arch);
if (!m) {
  console.error(
    `${W.fail}FATAL${W.off} tidak bisa parsing baris "Unit tests" di ARCHITECTURE.md.\n` +
      `  Pola yang diharapkan: | Unit tests | ✅ <pass>/<total> | vitest (<N> berkas: ...`,
  );
  process.exit(1);
}
const doc = { passed: m[1], total: m[2], files: m[3] };

// --- angka repo (berkas test) ---
function walk(dir, out = []) {
  if (!fs.existsSync(dir)) return out;
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else if (/\.test\.(ts|tsx)$/.test(e.name)) out.push(p);
  }
  return out;
}
const unitFiles = walk('tests/unit').length;
const componentFiles = walk('tests/component').length;
const repoFiles = unitFiles + componentFiles;

console.log(`\n=== verify:test-count — ARCHITECTURE.md §7.5 vs suite aktual ===\n`);

// --- angka suite (dari JSON hasil run, kalau ada) ---
const jsonPath = arg('json', '.vitest/test-result.json');
let suite = null;
if (!OFFLINE && fs.existsSync(jsonPath)) {
  const j = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
  suite = {
    total: String(j.numTotalTests),
    passed: String(j.numPassedTests),
    failed: String(j.numFailedTests),
    pending: String(j.numPendingTests),
    files: String(j.testResults?.length ?? '?'),
    success: j.success,
  };
}

console.log('  -- jumlah berkas test (repo vs dokumen) --');
check('test files', doc.files, String(repoFiles));

if (suite) {
  console.log('\n  -- hasil suite (dari vitest JSON) --');
  check('total tests', doc.total, suite.total);
  check('passed tests', doc.passed, suite.passed);
  check('test files', doc.files, suite.files);
  if (suite.failed !== '0' || suite.pending !== '0') {
    warnings++;
    console.log(`  ${W.warn}WARN${W.off}  ada ${suite.failed} gagal / ${suite.pending} pending`);
  }
} else {
  warnings++;
  console.log(
    `\n  ${W.warn}WARN${W.off}  JSON suite tidak ditemukan (${jsonPath}) — hanya berkas yang dicek.\n` +
      `         Di CI, step "Unit test" menulis JSON ke path itu sebelum guard ini jalan.\n` +
      `         Jalankan manual: npx vitest run --reporter=json --outputFile=.vitest/test-result.json`,
  );
}

console.log(`\n=== RINGKASAN: ${failures} drift, ${warnings} warning ===\n`);
if (failures > 0) {
  console.error(`${W.fail}verify:test-count GAGAL${W.off} — angka test di ARCHITECTURE.md tidak sinkron.`);
  console.error('  Perbarui ARCHITECTURE.md §7.5 dari `npx vitest run --reporter=json`.');
  process.exit(1);
}
console.log(`${W.pass}verify:test-count OK${W.off} — angka test sinkron.\n`);
process.exit(0);
