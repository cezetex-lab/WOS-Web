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

/** Jalankan CLI guard; kembalikan exit code (0 segar, 1 stale). */
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
      
      // Tulis JSON KEMUDIAN (mtime baru)
      fs.writeFileSync(jsonPath, '{"numTotalTests":1,"numPassedTests":1,"numFailedTests":0,"numPendingTests":0,"numTodoTests":0,"testResults":[],"success":true}\n', 'utf8');
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
      fs.writeFileSync(jsonPath, '{"numTotalTests":1,"numPassedTests":1,"numFailedTests":0,"numPendingTests":0,"numTodoTests":0,"testResults":[],"success":true}\n', 'utf8');
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
});

describe('test-freshness-guard — source guard', () => {
  it('tanpa shell, tanpa Function/eval/createRequire', () => {
    const raw = fs.readFileSync(GUARD, 'utf8');
    // Komentar header MEMANG menjelaskan konsep — assertion hanya pada KODE.
    const code = raw.replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '');

    expect(code).toMatch(/execFileSync\('git', \['ls-files', 'tests\/\'\]/);
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