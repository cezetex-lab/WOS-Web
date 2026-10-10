/**
 * numeric-extractors.mjs — logika ekstraksi nilai live berbasis REPO (Fase-3 Level B)
 *
 * Dipakai oleh scripts/verify-numeric-claims.mjs untuk entry registry dengan
 * source.type `git-ls-files` / `fs-walk`. Registry JSON = DATA STATIS; kode ada
 * DI SINI (keputusan user 2026-10-09: anti-pattern Function()/eval/string-code
 * dari sesi Solar Pro dihapus total — root cause loop require/Function/eval).
 *
 * Setiap fungsi mengembalikan ANGKA (number) atau NULL (bila artefak tidak ada).
 * Tidak ada DB di sini — entry db-live di-query langsung oleh guard.
 *
 * Metodologi dijaga IDENTIK dengan guard existing:
 *   - ts-total        → `git ls-files` + filter ekstensi (doc-claims-vs-live §7.3,
 *                       verify:artifacts §7.3) — berkas TER-TRACK, bukan disk.
 *   - unit-total      → `.vitest/test-result.json` (verify:test-count).
 *   - unit-files      → walk `tests/` untuk `*.test.{ts,tsx}` (verify:test-count).
 *   - migration-folder→ readdir ROOT `supabase/migrations` (verify:artifacts —
 *                       TIDAK memakai git glob yang ikut menghitung subfolder
 *                       `rollback/`; live root-level = 195, bukan 214).
 *   - rollback-scripts→ readdir `supabase/scripts/rollback`.
 */

import fs from 'node:fs';
import path from 'node:path';
import { execSync } from 'node:child_process';

/** Hitung berkas ter-track via `git ls-files` (metodologi doc-claims-vs-live). */
function gitLsFiles() {
  return execSync('git ls-files', { encoding: 'utf8' }).trim().split('\n').filter(Boolean);
}

export const extractors = {
  /** Jumlah file .sql di ROOT supabase/migrations (bukan subfolder). Angka: number. */
  'migration-folder-count': () =>
    fs.readdirSync('supabase/migrations').filter((f) => f.endsWith('.sql')).length,

  /** Jumlah file .sql rollback di supabase/scripts/rollback. Angka: number. */
  'rollback-scripts': () =>
    fs.readdirSync('supabase/scripts/rollback').filter((f) => f.endsWith('.sql')).length,

  /**
   * TS total (src + tests + config) dari berkas ter-track. Angka: number.
   * Metodologi identik doc-claims-vs-live §7.3 / verify:artifacts §7.3.
   */
  'ts-total': () => {
    const out = gitLsFiles();
    const cnt = (prefix, exts) => out.filter((f) => f.startsWith(prefix) && exts.some((e) => f.endsWith(e))).length;
    const src = cnt('src/', ['.ts', '.tsx']);
    const tests = cnt('tests/', ['.ts', '.tsx']);
    const config = out.filter((f) => !f.includes('/') && f.endsWith('.config.ts')).length;
    return src + tests + config;
  },

  /**
   * Total test dari JSON vitest resmi. Angka: number, atau NULL bila artefak
   * belum ada (guard melaporkan skip, bukan drift — runIf.needFilesystem).
   */
  'unit-total': () => {
    const jsonPath = path.resolve('.vitest/test-result.json');
    if (!fs.existsSync(jsonPath)) return null;
    const j = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
    return j.numTotalTests ?? null;
  },

  /** Jumlah berkas test `tests/**\/*.test.{ts,tsx}` (walk disk). Angka: number. */
  'unit-files': () => {
    const walk = (dir, out = []) => {
      if (!fs.existsSync(dir)) return out;
      for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
        const p = path.join(dir, e.name);
        if (e.isDirectory()) walk(p, out);
        else if (/\.test\.(ts|tsx)$/.test(e.name)) out.push(p);
      }
      return out;
    };
    return walk('tests').length;
  },
};
