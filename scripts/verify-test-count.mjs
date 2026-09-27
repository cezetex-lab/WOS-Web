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
// "| Unit tests | ✅ 141 test total — 136 auto + 5 butuh DATABASE_URL | vitest (22 berkas: ...)"
// Angka yang dijaga = TOTAL, bukan `passed`. Lihat catatan di `check()` bawah:
// suite yang sama menghasilkan passed BERBEDA antar environment karena 5 test
// DB-live di-skip otomatis saat `.env.local` tidak ada (lokal 141, CI 136).
const m = /\|\s*Unit tests\s*\|[^|]*?(\d+)\s+test total[^|]*?\|\s*vitest\s*\((\d+) berkas/.exec(arch);
if (!m) {
  console.error(
    `${W.fail}FATAL${W.off} tidak bisa parsing baris "Unit tests" di ARCHITECTURE.md.\n` +
      `  Pola yang diharapkan:\n` +
      `    | Unit tests | ✅ <N> test total — … | vitest (<M> berkas: …`,
  );
  process.exit(1);
}
const doc = { total: m[1], files: m[2] };

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
    // `it.todo` TIDAK ikut terhitung di passed/pending/failed — ia punya field
    // sendiri. Tanpa ini sanity check akan melaporkan drift palsu begitu ada
    // satu `it.todo` saja di repo.
    todo: String(j.numTodoTests ?? 0),
    files: String(j.testResults?.length ?? '?'),
    success: j.success,
  };
}

console.log('  -- jumlah berkas test (repo vs dokumen) --');
check('test files', doc.files, String(repoFiles));

if (suite) {
  console.log('\n  -- hasil suite (dari vitest JSON) --');
  // TOTAL adalah angka yang stabil lintas environment. `passed` TIDAK: 5 test
  // DB-live memakai `describe.skipIf(!DB_URL)` dan membaca `.env.local` dari
  // FILE (bukan process.env), jadi di runner CI tanpa file itu mereka di-skip
  // → passed = 136 di CI vs 141 di lokal. Menjaga `passed` akan membuat guard
  // merah di CI hanya karena tidak punya kredensial — drift palsu.
  check('total tests', doc.total, suite.total);
  check('test files', doc.files, suite.files);

  // Sanity: tidak boleh ada test yang hilang dari accounting. `todo` ikut
  // dihitung karena vitest punya field terpisah untuknya.
  const accounted =
    Number(suite.passed) + Number(suite.pending) + Number(suite.failed) + Number(suite.todo);
  check('passed+pending+failed+todo', suite.total, String(accounted));

  // Gagal = FAIL keras. Ini bukan soal angka dokumen, ini test sungguhan merah.
  if (Number(suite.failed) > 0) {
    failures++;
    console.log(`  ${W.fail}DRIFT${W.off} ${'failed tests'.padEnd(18)} ${suite.failed} — test benar-benar gagal`);
  } else {
    console.log(`  ${W.pass}OK${W.off}    ${'failed tests'.padEnd(18)} 0`);
  }

  // Skipped = WARN. Reach ke DB live bukan untuk setiap push; di CI 5 test ini
  // sengaja di-skip. Melaporkannya sebagai drift akan menyuruh orang mengejar
  // masalah yang memang bukan masalah.
  if (Number(suite.pending) > 0) {
    warnings++;
    console.log(
      `  ${W.warn}WARN${W.off}  ${suite.pending} test di-skip ` +
        `(butuh DATABASE_URL / .env.local — normal di CI)`,
    );
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
