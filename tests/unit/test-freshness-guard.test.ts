/**
 * test-freshness-guard.test.ts — guard kesegaran .vitest/test-result.json (P2-F14-AE).
 *
 * Guard `scripts/verify-test-freshness.mjs` ada karena guard lain (`verify:test-count`,
 * `doc-claims-vs-live`) membaca `.vitest/test-result.json` cache. Di CI aman karena
 * step `Unit test` menulis JSON segar. Di LOKAL: JSON bisa BASI → guard hijau palsu.
 * Run pertama hijau walau suite sudah 201, karena JSON lama = 198; run kedua baru merah.
 * Kelas bug = "guard hijau palsu karena cache basi", identik dengan bundle AJ (P2-F14-AJ).
 *
 * Test di sini memakai FIXTURE TEMP + mtime eksplisit (fs.utimesSync), bukan kondisi
 * repo — supaya tidak basi setelah B5/C5 refresh JSON. (Kalau test meng-assert kondisi
 * repo saat ini, ia akan merah sendiri setelah JSON disegarkan: itu test yang salah,
 * bukan guard yang rusak.)
 *
 * BLIND SPOT 2026-10-11 (ditutup di sini): mtime segar BUKAN jaminan isi JSON lengkap. Run parsial
 * (1 berkas / 6 test) yang mtime-nya lebih baru tetap HIJAU, padahal verify:test-count
 * dan doc-claims-vs-live membaca JSON itu → 2 gate merah di sesi berikutnya. Guard kini
 * juga membandingkan jumlah berkas di JSON (`testResults`) dengan korpus test.
 * JEBAKAN: `numTotalTestSuites` di vitest = jumlah DESCRIBE-BLOCK (91 untuk 30 berkas),
 * bukan jumlah berkas — test di bawah menegakkan guard TIDAK memakainya.
 */
import { describe, expect, it } from 'vitest';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const ROOT = path.resolve(import.meta.dirname, '..', '..');
const GUARD = path.join(ROOT, 'scripts', 'verify-test-freshness.mjs');

/** Folder temp per-test; dihapus lagi supaya tidak meninggalkan sampah. */
function withTmp<T>(fn: (dir: string) => T): T {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'fresh-guard-'));
  try {
    return fn(dir);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

/** Bentuk JSON vitest minimal, dengan `testResults` sepanjang jumlah berkas yang diminta. */
function jsonFixture(fileCount: number): string {
  const testResults = Array.from({ length: fileCount }, (_, i) => ({ name: `file-${i}.test.ts` }));
  return (
    JSON.stringify({
      numTotalTests: fileCount,
      numPassedTests: fileCount,
      numFailedTests: 0,
      numPendingTests: 0,
      numTodoTests: 0,
      testResults,
      success: true,
    }) + '\n'
  );
}

/**
 * Buat berkas test palsu (isi tidak dijalankan) dan kembalikan path-nya.
 * mtime-nya digeser 10 detik ke BELAKANG supaya cek mtime deterministik saat
 * `--tolerance=0`: tanpa itu, berkas yang lahir ~0,4 ms SETELAH JSON dianggap
 * "lebih baru" dan memicu STALE palsu — race presisi utimesSync, bukan logika guard.
 */
function writeFakeTestFile(dir: string, rel: string): string {
  const p = path.join(dir, rel);
  fs.mkdirSync(path.dirname(p), { recursive: true });
  fs.writeFileSync(p, 'import { it } from "vitest"; it("x", () => {});\n', 'utf8');
  const past = (Date.now() - 10000) / 1000;
  fs.utimesSync(p, past, past);
  return p;
}

/** Jalankan CLI guard; kembalikan exit code (0 segar+lengkap, 1 stale/incomplete). */
function runGuard(jsonPath: string, testFiles: string[]): number {
  try {
    const args = [GUARD, `--json=${jsonPath}`, `--tolerance=0`];
    if (testFiles.length > 0) {
      args.push(`--files=${testFiles.join(',')}`);
    }
    execFileSync(process.execPath, args, { encoding: 'utf8' });
    return 0;
  } catch (e) {
    return (e as { status?: number }).status ?? -1;
  }
}

describe('test-freshness-guard — unit', () => {
  it('(a) JSON baru + test file lama → HIJAU (exit 0)', () => {
    withTmp((dir) => {
      const jsonPath = path.join(dir, 'test-result.json');
      const testPath = path.join(dir, 'tests', 'unit', 'a.test.ts');
      fs.mkdirSync(path.dirname(testPath), { recursive: true });
      
      // Tulis test file DULU (mtime lama)
      fs.writeFileSync(testPath, 'import { it } from "vitest"; it("a", () => {});\n', 'utf8');
      const testMtime = Date.now() - 10000; // 10 detik lalu
      fs.utimesSync(testPath, testMtime / 1000, testMtime / 1000);
      
      // Tulis JSON KEMUDIAN (mtime baru) — lengkap: 1 berkas di JSON, 1 berkas diperiksa
      fs.writeFileSync(jsonPath, jsonFixture(1), 'utf8');
      const jsonMtime = Date.now();
      fs.utimesSync(jsonPath, jsonMtime / 1000, jsonMtime / 1000);
      
      // JSON lebih baru dari test file → HIJAU
      expect(runGuard(jsonPath, [testPath])).toBe(0);
    });
  });

  it('(b) JSON lama + test file baru → MERAH (exit 1) — inject fixture mtime', () => {
    withTmp((dir) => {
      const jsonPath = path.join(dir, 'test-result.json');
      const testPath = path.join(dir, 'tests', 'unit', 'b.test.ts');
      fs.mkdirSync(path.dirname(testPath), { recursive: true });
      
      // Tulis JSON DULU (mtime lama)
      fs.writeFileSync(jsonPath, jsonFixture(1), 'utf8');
      const jsonMtime = Date.now() - 10000; // 10 detik lalu
      fs.utimesSync(jsonPath, jsonMtime / 1000, jsonMtime / 1000);
      
      // Tulis test file KEMUDIAN (mtime baru)
      fs.writeFileSync(testPath, 'import { it } from "vitest"; it("b", () => {});\n', 'utf8');
      const testMtime = Date.now();
      fs.utimesSync(testPath, testMtime / 1000, testMtime / 1000);
      
      // JSON lebih lama dari test file → MERAH (stale)
      expect(runGuard(jsonPath, [testPath])).toBe(1);
    });
  });

  it('(c) JSON tidak ada → WARN + exit 0', () => {
    withTmp((dir) => {
      const jsonPath = path.join(dir, 'does-not-exist.json');
      const testPath = path.join(dir, 'tests', 'unit', 'c.test.ts');
      fs.mkdirSync(path.dirname(testPath), { recursive: true });
      fs.writeFileSync(testPath, 'import { it } from "vitest"; it("c", () => {});\n', 'utf8');
      
      // JSON tidak ada → exit 0 (WARN tapi tidak MERAH)
      expect(runGuard(jsonPath, [testPath])).toBe(0);
    });
  });

  it('(d) JSON segar + LENGKAP (semua berkas ada di JSON) → HIJAU (exit 0)', () => {
    withTmp((dir) => {
      const jsonPath = path.join(dir, 'test-result.json');
      const testPaths = ['d1', 'd2', 'd3'].map((n) => writeFakeTestFile(dir, `tests/unit/${n}.test.ts`));

      // 3 berkas test di JSON, 3 berkas diperiksa → lengkap
      fs.writeFileSync(jsonPath, jsonFixture(3), 'utf8');
      const now = Date.now();
      fs.utimesSync(jsonPath, now / 1000, now / 1000);

      expect(runGuard(jsonPath, testPaths)).toBe(0);
    });
  });

  it('(e) JSON segar tapi PARSIAL (1 berkas dari 3) → MERAH (exit 1) — blind spot 2026-10-11', () => {
    withTmp((dir) => {
      const jsonPath = path.join(dir, 'test-result.json');
      const testPaths = ['e1', 'e2', 'e3'].map((n) => writeFakeTestFile(dir, `tests/unit/${n}.test.ts`));

      // JSON dari run parsial: mtime SEGAR, tapi hanya 1 berkas dari 3.
      // Di guard lama (hanya mtime) ini HIJAU — hijau palsu yang menutupi run parsial.
      fs.writeFileSync(jsonPath, jsonFixture(1), 'utf8');
      const now = Date.now();
      fs.utimesSync(jsonPath, now / 1000, now / 1000);

      expect(runGuard(jsonPath, testPaths)).toBe(1);
    });
  });
});

describe('test-freshness-guard — source guard', () => {
  it('tanpa shell, tanpa Function/eval/createRequire', () => {
    const raw = fs.readFileSync(GUARD, 'utf8');
    // Komentar header MEMANG menjelaskan konsep — assertion hanya pada KODE.
    const code = raw.replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '');

    expect(code).toMatch(/execFileSync\('git', \['ls-files', 'tests\/'\]/);
    expect(code).not.toMatch(/process\.platform/);
    expect(code).not.toMatch(/\bshell\s*:/);
    expect(code).not.toMatch(/\bFunction\s*\(/);
    expect(code).not.toMatch(/\beval\s*\(/);
    expect(code).not.toMatch(/createRequire/);

    // Wajib membandingkan mtime JSON vs test file.
    expect(code).toMatch(/statSync/);
    expect(code).toMatch(/mtimeMs/);

    // Anti hijau-palsu: korpus kosong harus FATAL, bukan exit 0.
    expect(code).toMatch(/korpus kosong/);
    expect(code).toMatch(/process\.exit\(2\)/);

    // Kelengkapan (blind spot 2026-10-11): mtime segar bukan berarti isi lengkap.
    // Guard WAJIB membandingkan jumlah berkas di JSON dengan korpus test.
    expect(code).toMatch(/readJsonTestFileCount/);
    expect(code).toMatch(/testResults/);
    expect(code).toMatch(/INCOMPLETE/);
    expect(code).toMatch(/jsonFileCount !== expectedFileCount/);

    // JEBAKAN vitest: `numTotalTestSuites` = jumlah describe-block (91 untuk 30 berkas),
    // bukan jumlah berkas → DILARANG dipakai sebagai proksi kelengkapan.
    expect(code).not.toMatch(/numTotalTestSuites/);
  });

  it('wired ke package.json sebagai verify:test-freshness', () => {
    const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, 'package.json'), 'utf8'));
    expect(pkg.scripts['verify:test-freshness']).toBe('node scripts/verify-test-freshness.mjs');
  });

  it('wired ke CI setelah step Verify test count', () => {
    const yml = fs.readFileSync(path.join(ROOT, '.github', 'workflows', 'ci.yml'), 'utf8');
    expect(yml).toMatch(/- name: Verify test freshness/);
    expect(yml).toMatch(/run: npm run verify:test-freshness/);
    const iTestCount = yml.indexOf('Verify test count');
    const iFresh = yml.indexOf('Verify test freshness');
    const iBuild = yml.indexOf('- name: Build');
    expect(iTestCount).toBeGreaterThan(-1);
    expect(iFresh).toBeGreaterThan(iTestCount); // setelah verify:test-count
    expect(iBuild).toBeGreaterThan(iFresh); // sebelum Build
  });
});