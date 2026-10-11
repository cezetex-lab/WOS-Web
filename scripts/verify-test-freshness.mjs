#!/usr/bin/env node
/**
 * verify-test-freshness.mjs — guard kesegaran .vitest/test-result.json (P2-F14-AE).
 *
 * KENAPA ADA
 *   Guard verify:test-count dan doc-claims-vs-live membaca .vitest/test-result.json
 *   yang dihasilkan step Unit test di CI. Di CI aman — step Unit test menulis JSON
 *   SEGAR sebelum guard ini jalan. Tapi di LOKAL: JSON bisa BASI (dari run lama),
 *   sehingga guard hijau palsu (run pertama hijau walau suite sudah 201, karena
 *   JSON lama = 198; run kedua baru merah setelah JSON disegarkan).
 *   Kelas bug = guard hijau palsu karena cache basi, identik dengan bundle AJ.
 *
 * CARA KERJA (P20 — GUARD SEBELUM NORMALISASI)
 *   1. Baca mtime .vitest/test-result.json. Kalau tidak ada → WARN + exit 0
 *      (belum dijalankan, bukan error).
 *   2. Walk tests/ via git ls-files, filter .test.ts / .test.tsx.
 *   3. Cari mtime terbaru dari semua test file.
 *   4. Bandingkan: json_mtime < test_mtime - TOLERANCE → MERAH (exit 1).
 *      json_mtime >= test_mtime - TOLERANCE → lanjut langkah 5.
 *   5. KELENGKAPAN (blind spot 2026-10-11): mtime segar TIDAK menjamin isi JSON
 *      lengkap. Run parsial (mis. 1 berkas / 6 test) yang mtime-nya lebih baru
 *      dari test file tetap HIJAU di langkah 4 — padahal guard lain
 *      (verify:test-count, doc-claims-vs-live) membaca JSON itu sebagai sumber
 *      angka dan jadi hijau palsu. Jadi: jumlah berkas di JSON (`testResults`)
 *      WAJIB sama dengan jumlah berkas test yang diperiksa. Beda → MERAH (exit 1).
 *   6. Toleransi default 5 detik untuk hindari false-positive flake I/O.
 *
 * JEBAKAN VITEST (jangan dipakai): field `numTotalTestSuites` BUKAN jumlah berkas
 *   — di vitest ia menghitung describe-block (terbukti 2026-10-11: 91 untuk 30
 *   berkas). Proksi kelengkapan yang benar adalah panjang array `testResults`
 *   (satu entri per berkas test yang diproses). 91 juga berbeda tiap suite baru,
 *   sedangkan jumlah berkas stabil. Karena itu kode ini sengaja TIDAK menyentuh
 *   `numTotalTestSuites` sama sekali — ditegakkan oleh test di tests/unit/.
 *
 * PEMAKAIAN
 *   npm run verify:test-freshness
 *   node scripts/verify-test-freshness.mjs [--json <path>] [--tolerance <seconds>] [--offline]
 *
 * Exit 0 = segar + lengkap (atau tidak ada JSON / offline), 1 = basi ATAU tidak lengkap, 2 = error.
 */
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

const W = {
  pass: '\x1b[32m',
  fail: '\x1b[31m',
  warn: '\x1b[33m',
  dim: '\x1b[2m',
  off: '\x1b[0m'
};

const argv = process.argv.slice(2);
const arg = (n, d) => {
  const hit = argv.find((a) => a.startsWith(`--${n}=`));
  return hit ? hit.slice(n.length + 3) : d;
};
const OFFLINE = argv.includes('--offline');
const TOLERANCE_MS = Number(arg('tolerance', '5')) * 1000; // default 5 detik

const JSON_PATH = arg('json', '.vitest/test-result.json');
const FILES_ARG = arg('files', '');

/** Daftar berkas test ter-track dari git (tanpa shell → identik lintas platform). */
function listTrackedTestFiles() {
  try {
    const out = execFileSync('git', ['ls-files', 'tests/'], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
    return out
      .split('\n')
      .filter(Boolean)
      .filter((f) => /\.test\.(ts|tsx)$/.test(f));
  } catch (e) {
    console.error(`${W.fail}FATAL${W.off} git ls-files tests/ gagal: ${e.message}`);
    process.exit(2);
  }
}

/**
 * Jumlah berkas test yang tercatat DI DALAM JSON = panjang `testResults`
 * (satu entri per berkas test yang diproses vitest).
 * Kembalikan null kalau JSON tidak terbaca / tidak punya array itu.
 */
function readJsonTestFileCount(jsonPath) {
  try {
    const parsed = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
    if (!Array.isArray(parsed.testResults)) return null;
    return parsed.testResults.length;
  } catch {
    // JSON rusak / hilang di tengah jalan → diperlakukan sebagai "tidak lengkap".
    return null;
  }
}

/** Ambil mtime terbaru dari array path. */
function getNewestMtime(files) {
  let newest = 0;
  for (const f of files) {
    try {
      const stat = fs.statSync(f);
      if (stat.mtimeMs > newest) newest = stat.mtimeMs;
    } catch {
      // file tidak ada di worktree (mis. dihapus tapi belum di-commit) → abaikan
    }
  }
  return newest;
}

function main() {
  console.log(`\n=== verify:test-freshness — mtime .vitest/test-result.json vs tests/ ===\n`);

  // 1. Cek JSON ada?
  if (!fs.existsSync(JSON_PATH)) {
    console.log(
      `  ${W.warn}WARN${W.off}  ${JSON_PATH} tidak ditemukan — belum ada run vitest (atau path salah).\n` +
      `         Di CI, step "Unit test" menulis JSON ke path itu sebelum guard ini jalan.\n` +
      `         Jalankan manual: npx vitest run --reporter=json --outputFile=.vitest/test-result.json`
    );
    console.log(`\n=== RINGKASAN: 0 stale, 1 warning (JSON missing) ===\n`);
    console.log(`${W.pass}verify:test-freshness OK${W.off} — JSON tidak ada, tidak bisa divalidasi.`);
    process.exit(0);
  }

  const jsonStat = fs.statSync(JSON_PATH);
  const jsonMtime = jsonStat.mtimeMs;

  // 2. Offline mode = hanya cek JSON ada, tidak bandingkan mtime
  if (OFFLINE) {
    console.log(`  ${W.pass}OK${W.off}    JSON ditemukan (offline mode — tidak bandingkan mtime)`);
    console.log(`\n=== RINGKASAN: 0 stale, 0 warning (offline) ===\n`);
    console.log(`${W.pass}verify:test-freshness OK${W.off} — offline mode.`);
    process.exit(0);
  }

  // 3. Cari test file terbaru
  let testFiles;
  if (FILES_ARG) {
    testFiles = FILES_ARG.split(',').map((f) => f.trim()).filter(Boolean);
    console.log(`  Mode: files dari --files (${testFiles.length} berkas)`);
  } else {
    testFiles = listTrackedTestFiles();
    console.log(`  Mode: git ls-files (${testFiles.length} berkas)`);
  }
  if (testFiles.length === 0) {
    console.error(`${W.fail}FATAL${W.off} korpus kosong — tidak ada berkas test untuk diperiksa (guard akan hijau palsu).`);
    process.exit(2);
  }

  const newestTestMtime = getNewestMtime(testFiles);
  const diffMs = newestTestMtime - jsonMtime;

  console.log(`  JSON path:      ${JSON_PATH}`);
  console.log(`  JSON mtime:     ${new Date(jsonMtime).toISOString()} (${jsonMtime} ms)`);
  console.log(`  Test files:     ${testFiles.length} berkas`);
  console.log(`  Newest test:    ${newestTestMtime > 0 ? new Date(newestTestMtime).toISOString() : 'N/A'} (${newestTestMtime} ms)`);
  console.log(`  Selisih:        ${diffMs >= 0 ? '+' : ''}${diffMs} ms (test - JSON)`);
  console.log(`  Toleransi:      ${TOLERANCE_MS} ms`);

  if (diffMs > TOLERANCE_MS) {
    // JSON lebih lama dari test file terbaru → STALE (MERAH)
    const diffSec = (diffMs / 1000).toFixed(1);
    console.log(
      `\n  ${W.fail}STALE${W.off} ${'test-result.json'.padEnd(18)} JSON basi ${diffSec}s dari test file terbaru`
    );
    console.log(
      `\n  ${W.dim}Perbaiki:${W.off} jalankan npx vitest run --reporter=json --outputFile=.vitest/test-result.json`
    );
    console.log(`\n=== RINGKASAN: 1 stale, 0 warning ===\n`);
    console.error(`${W.fail}verify:test-freshness GAGAL${W.off} — JSON basi (stale).`);
    process.exit(1);
  }

  // JSON segar atau sama (dalam toleransi) → lanjut cek KELENGKAPAN
  console.log(`  ${W.pass}OK${W.off}    ${'test-result.json'.padEnd(18)} JSON segar (selisih ${diffMs >= 0 ? '+' : ''}${(diffMs / 1000).toFixed(1)}s)`);

  // 5. Kelengkapan: mtime segar tidak berarti isi JSON lengkap.
  const jsonFileCount = readJsonTestFileCount(JSON_PATH);
  const expectedFileCount = testFiles.length;
  console.log(
    `  Berkas di JSON: ${jsonFileCount === null ? 'N/A' : jsonFileCount} (diharapkan ${expectedFileCount})`
  );

  if (jsonFileCount === null) {
    console.error(
      `${W.fail}FATAL${W.off} ${JSON_PATH} tidak punya array "testResults" — skema JSON tidak dikenal.`
    );
    process.exit(2);
  }

  if (jsonFileCount !== expectedFileCount) {
    // JSON tidak mewakili korpus test → guard lain akan hijau palsu (MERAH).
    const sebab =
      jsonFileCount < expectedFileCount
        ? `run PARSIAL: JSON hanya memuat ${jsonFileCount} dari ${expectedFileCount} berkas test (tidak lengkap)`
        : `JSON memuat ${jsonFileCount} berkas, lebih banyak dari ${expectedFileCount} berkas test yang diperiksa`;
    console.log(`\n  ${W.fail}INCOMPLETE${W.off} ${'test-result.json'.padEnd(12)} ${sebab}`);
    console.log(
      `\n  ${W.dim}Perbaiki:${W.off} jalankan SUITE PENUH — npx vitest run --reporter=json --outputFile=.vitest/test-result.json`
    );
    console.log(`\n=== RINGKASAN: 0 stale, 1 incomplete ===\n`);
    console.error(
      `${W.fail}verify:test-freshness GAGAL${W.off} — JSON segar tapi TIDAK LENGKAP (isinnya bukan seluruh korpus test).`
    );
    process.exit(1);
  }

  console.log(
    `  ${W.pass}OK${W.off}    ${'test-result.json'.padEnd(18)} lengkap (${jsonFileCount}/${expectedFileCount} berkas)`
  );
  console.log(`\n=== RINGKASAN: 0 stale, 0 warning ===\n`);
  console.log(`${W.pass}verify:test-freshness OK${W.off} — JSON segar + lengkap.`);
  process.exit(0);
}

// Jalankan main() HANYA bila dieksekusi langsung (bukan saat di-import test).
const DIRECT_RUN = Boolean(
  process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href
);
if (DIRECT_RUN) main();

export { listTrackedTestFiles, getNewestMtime, readJsonTestFileCount, main };