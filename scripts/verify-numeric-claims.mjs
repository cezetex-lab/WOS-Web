#!/usr/bin/env node
/**
 * verify-numeric-claims.mjs — meta-guard klaim angka di semua file .md tracked (Fase-3 Level B)
 *
 * REFACTOR 2026-10-09 (keputusan user PARTIAL-RECOVER):
 *   - HAPUS total pola Function()/eval/createRequire/string-code (root cause loop
 *     sesi Solar Pro). Registry JSON = DATA STATIS; logika ekstraksi repo-file
 *     ada di scripts/numeric-extractors.mjs (ES module murni).
 *   - Ikuti shape design doc §2.2: source.type (db-live|git-ls-files|fs-walk|
 *     external-snapshot), modes (eq|gte|skip), category, runIf, archiveFiles.
 *
 * CARA KERJA:
 *   - Load registry (default scripts/numeric-claims-registry.json; --registry=<path> override).
 *   - Scan file .md: `git ls-files '*.md'` TANPA shell (atau --files=a.md,b.md untuk fixture/test).
 *     FIX 2026-10-10 (cross-platform): korpus dibangun lewat execFileSync('git',['ls-files','*.md'])
 *     — sebelumnya `execSync('git ls-files *.md', { shell })` punya branch platform
 *     (`cmd.exe` vs `/bin/sh`). Di POSIX, `/bin/sh` meng-expand `*.md` LEBIH DULU sehingga
 *     git menerima 14 path eksplisit root-only → 12 berkas .md nested (antara lain
 *     docs/forensic/CONSTANTS-INVENTORY.md) TIDAK PERNAH dipindai di CI, sementara di
 *     Windows git menerima pathspec `*.md` dan mengembalikan 26. Tanpa shell, git yang
 *     menangani globbing → hasil identik lintas platform (Windows/Linux/macOS).
 *   - archiveFiles (registry top-level) = file yang TIDAK di-cross-check (arsip, design §3).
 *   - Per entry:
 *       * live-guarded/live-unguarded → ekstrak nilai live (SQL / extractor), cross-check
 *         klaim di SEMUA file .md non-archive. mode eq = sama persis; gte = live >= claim.
 *         Beda → DRIFT (exit 1).
 *       * external-snapshot → WARN saja (bukan drift).
 *       * ambiguous → WARN saja (bukan drift).
 *       * archive → skip.
 *   - Entry dengan runIf.needDb tapi tanpa DATABASE_URL → WARN skip (bukan drift).
 *   - Exit: 0 = 0 drift, 1 = ada drift, 2 = error tak terduga.
 *
 * JARAK DENGAN GUARD LAMA: tidak mengganti verify:artifacts/verify:test-count/
 * doc-claims-vs-live — berjalan paralel, additive.
 *
 * PEMAKAIAN:
 *   npm run verify:numeric
 *   node scripts/verify-numeric-claims.mjs [--registry=<path>] [--files=a.md,b.md]
 */

import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import pg from 'pg';
import dotenv from 'dotenv';
import { extractors } from './numeric-extractors.mjs';

dotenv.config({ path: '.env.local' });

const W = { pass: '\x1b[32m', fail: '\x1b[31m', warn: '\x1b[33m', dim: '\x1b[2m', off: '\x1b[0m' };

// --- CLI flags (testability B2: fixture registry + fixture corpus) ---
const argv = process.argv.slice(2);
const argVal = (name) => {
  const hit = argv.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : null;
};
const REGISTRY_PATH = argVal('registry') ?? 'scripts/numeric-claims-registry.json';
const FILES_OVERRIDE = argVal('files') ? argVal('files').split(',').map((s) => s.trim()).filter(Boolean) : null;

const VALID_SOURCE_TYPES = ['db-live', 'git-ls-files', 'fs-walk', 'external-snapshot'];
const VALID_CATEGORIES = ['live-guarded', 'live-unguarded', 'external-snapshot', 'ambiguous', 'archive'];
const VALID_MODES = ['eq', 'gte', 'skip'];

// STEP 4 (Fase-3, design §5.x): marker snapshot kanonik — global, bukan per-entry.
// Baris .md yang mengandung marker ini = kutipan historis → skip + log, bukan drift.
const SNAPSHOT_MARKER = /\[snapshot:[a-f0-9]{7,}\]/;

/** Validasi shape minimal registry (design §2.2 + L7). Lempar Error bila corrupt. */
export function validateRegistry(registry) {
  if (!registry || typeof registry !== 'object') throw new Error('registry bukan objek');
  if (!Array.isArray(registry.entries)) throw new Error('registry.entries tidak ada / bukan array');
  if (registry.archiveFiles !== undefined && !Array.isArray(registry.archiveFiles))
    throw new Error('registry.archiveFiles harus array bila ada');
  registry.entries.forEach((e, i) => {
    const at = `entry[${i}] (${e.id ?? '?'})`;
    if (!e.id) throw new Error(`entry[${i}] tanpa id`);
    if (!e.label) throw new Error(`${at} tanpa label`);
    if (!Array.isArray(e.modes) || e.modes.length === 0) throw new Error(`${at} tanpa modes`);
    e.modes.forEach((m) => { if (!VALID_MODES.includes(m)) throw new Error(`${at} mode tidak dikenal: ${m}`); });
    if (!VALID_CATEGORIES.includes(e.category)) throw new Error(`${at} category tidak dikenal: ${e.category}`);
    if (!e.source || !VALID_SOURCE_TYPES.includes(e.source.type)) throw new Error(`${at} source.type tidak dikenal: ${e.source?.type}`);
    if (e.source.type === 'db-live' && !e.source.query) throw new Error(`${at} db-live tanpa query`);
    if ((e.source.type === 'git-ls-files' || e.source.type === 'fs-walk')) {
      if (!e.source.extractorName) throw new Error(`${at} tanpa extractorName`);
      if (typeof extractors[e.source.extractorName] !== 'function')
        throw new Error(`${at} extractorName tidak ada di numeric-extractors.mjs: ${e.source.extractorName}`);
    }
    if (!Array.isArray(e.claimPatterns) || e.claimPatterns.length === 0) throw new Error(`${at} tanpa claimPatterns`);
    e.claimPatterns.forEach((cp) => { if (!cp.regex) throw new Error(`${at} claimPattern tanpa regex`); });
    if (!e.runIf || typeof e.runIf.needDb !== 'boolean') throw new Error(`${at} tanpa runIf.needDb`);
  });
  return registry;
}

/** Ambil semua match regex (global) dalam satu konten. */
function allMatches(content, pattern) {
  const re = new RegExp(pattern.source, 'g');
  const out = [];
  let m;
  while ((m = re.exec(content)) !== null) out.push(m);
  return out;
}

/** Baris (1-based) dari indeks karakter — untuk konteks file:baris. */
function lineOf(content, index) {
  return content.slice(0, index).split('\n').length;
}

async function main() {
  // --- 1. Load + validasi registry ---
  let registry;
  try {
    registry = JSON.parse(fs.readFileSync(REGISTRY_PATH, 'utf8'));
  } catch (e) {
    console.error(`${W.fail}FATAL${W.off} tidak bisa baca/parse registry: ${REGISTRY_PATH} (${e.message})`);
    process.exit(2);
  }
  try {
    validateRegistry(registry);
  } catch (e) {
    console.error(`${W.fail}FATAL${W.off} registry tidak valid: ${e.message}`);
    process.exit(2);
  }
  const archiveFiles = new Set(registry.archiveFiles ?? []);

  // --- 2. Corpus .md ---
  let corpus;
  if (FILES_OVERRIDE) {
    corpus = FILES_OVERRIDE;
  } else {
    // FIX 2026-10-10: TANPA shell — lihat header. execFileSync mencegah ekspansi glob
    // oleh shell (penyebab korpus 14 vs 26 antar platform).
    try {
      corpus = execFileSync('git', ['ls-files', '*.md'], { encoding: 'utf8' })
        .trim()
        .split('\n')
        .filter(Boolean);
    } catch (e) {
      console.error(`${W.fail}FATAL${W.off} git ls-files '*.md' gagal: ${e.message}`);
      process.exit(2);
    }
    // Anti-hijau-palsu: korpus kosong = guard tidak memeriksa apa pun.
    if (corpus.length === 0) {
      console.error(`${W.fail}FATAL${W.off} korpus .md kosong — tidak ada berkas untuk dipindai (guard akan hijau palsu).`);
      process.exit(2);
    }
  }

  // --- 3. Koneksi DB hanya bila ada entry db-live yang perlu ---
  const needDb = registry.entries.some((e) => e.source.type === 'db-live');
  let db = null;
  if (needDb) {
    if (!process.env.DATABASE_URL) {
      console.log(`${W.warn}WARN${W.off} DATABASE_URL tidak ada — semua entry db-live di-skip (bukan drift).`);
    } else {
      db = new pg.Client({ connectionString: process.env.DATABASE_URL });
      await db.connect();
    }
  }

  console.log(`\n=== verify:numeric — meta-guard klaim angka (registry ${registry.entries.length} entry) ===\n`);
  console.log(`  -- lintas ${corpus.length} file .md vs live value --\n`);

  let failures = 0, warnings = 0, checked = 0;
  // STEP 4 (Fase-3, keputusan user): marker snapshot kanonik — baris ber-marker
  // = kutipan historis, di-skip dari drift-check TAPI dilaporkan (bukan silent).
  const skippedBySnapshot = [];

  for (const entry of registry.entries) {
    // category archive → skip entry
    if (entry.category === 'archive') {
      console.log(`  ${W.dim}skip${W.off}  ${entry.id.padEnd(24)} (category archive)`);
      continue;
    }

    // --- 3a. Resolusi live value ---
    let live = null;
    if (entry.source.type === 'db-live') {
      if (!db) {
        console.log(`  ${W.warn}WARN${W.off}  ${entry.id.padEnd(24)} butuh DATABASE_URL — skip (bukan drift)`);
        warnings++;
        continue;
      }
      const row = (await db.query(entry.source.query)).rows[0];
      live = row?.n ?? (row ? Object.values(row)[0] : null);
    } else if (entry.source.type === 'git-ls-files' || entry.source.type === 'fs-walk') {
      try {
        live = extractors[entry.source.extractorName]();
      } catch (e) {
        console.log(`  ${W.warn}WARN${W.off}  ${entry.id.padEnd(24)} extractor gagal: ${e.message}`);
        warnings++;
        continue;
      }
      if (live === null || live === undefined) {
        console.log(`  ${W.warn}WARN${W.off}  ${entry.id.padEnd(24)} artefak tidak ada (runIf.needFilesystem) — skip`);
        warnings++;
        continue;
      }
    } // else: external-snapshot → live = null, hanya WARN

    // --- 3b. Cross-check klaim di corpus ---
    for (const file of corpus) {
      if (archiveFiles.has(file)) continue; // arsip: tidak di-cross-check (design §3)
      let content;
      try {
        content = fs.readFileSync(file, 'utf8');
      } catch { continue; }

      for (const cp of entry.claimPatterns) {
        const group = cp.group ?? 1;
        for (const m of allMatches(content, new RegExp(cp.regex, 'g'))) {
          const claim = group === 0 ? m[0] : m[group];
          if (claim === undefined) continue;
          const ctx = `${file}:${lineOf(content, m.index)}`;

          // STEP 4: baris ber-marker snapshot → skip + catat (bukan drift, bukan silent).
          // Line = teks baris penuh tempat match ditemukan.
          const lineStart = content.lastIndexOf('\n', m.index - 1) + 1;
          const lineEnd = content.indexOf('\n', m.index);
          const lineText = content.slice(lineStart, lineEnd === -1 ? undefined : lineEnd);
          const markerHit = SNAPSHOT_MARKER.exec(lineText);
          if (markerHit) {
            skippedBySnapshot.push({ file, line: lineOf(content, m.index), marker: markerHit[0], entry: entry.id, claim: String(claim) });
            console.log(`  ${W.dim}SKIPPED${W.off} ${entry.id.padEnd(24)} claim="${claim}" ${ctx} (snapshot ${markerHit[0]} — kutipan historis)`);
            continue;
          }

          if (entry.category === 'external-snapshot' || entry.category === 'ambiguous' || entry.modes.includes('skip')) {
            console.log(`  ${W.warn}WARN${W.off}  ${entry.id.padEnd(24)} claim="${claim}" ${ctx} (kategori ${entry.category} — bukan drift)`);
            warnings++;
            checked++;
            continue;
          }

          checked++;
          const eq = String(claim) === String(live);
          const gte = Number.isFinite(Number(claim)) && Number(live) >= Number(claim);
          const ok = entry.modes.includes('gte') ? gte : eq;
          if (ok) {
            console.log(`  ${W.pass}OK${W.off}    ${entry.id.padEnd(24)} ${live} ${ctx}`);
          } else {
            failures++;
            console.log(`  ${W.fail}DRIFT${W.off} ${entry.id.padEnd(24)} claim=${claim} live=${live} ${ctx}`);
          }
        }
      }
    }
  }

  if (db) await db.end();

  console.log(`\n=== RINGKASAN: ${failures} drift, ${warnings} warning, ${checked} klaim dicek ===\n`);
  // STEP 4: skip-marker WAJIB dilaporkan (anti silent-skip, pelajaran P14).
  // Tidak mempengaruhi exit code — hanya kutipan historis yang dikecualikan.
  if (skippedBySnapshot.length > 0) {
    console.log(`--- SKIPPED (snapshot marker): ${skippedBySnapshot.length} baris ---`);
    for (const s of skippedBySnapshot) {
      console.log(`  SKIPPED ${s.entry.padEnd(24)} claim="${s.claim}" ${s.file}:${s.line} (${s.marker})`);
    }
    console.log('');
  }
  if (failures > 0) {
    console.error(`${W.fail}verify:numeric GAGAL${W.off} — ${failures} klaim angka tidak sinkron dengan live.`);
    process.exit(1);
  }
  console.log(`${W.pass}verify:numeric OK${W.off} — klaim angka sinkron (atau hanya WARN pada kategori yang diizinkan).`);
  process.exit(0);
}

main().catch((e) => {
  console.error(`${W.fail}FATAL${W.off}`, e.message);
  process.exit(2);
});
