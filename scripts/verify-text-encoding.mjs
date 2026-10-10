#!/usr/bin/env node
/**
 * verify-text-encoding.mjs — guard UTF-8 untuk berkas teks ter-track (P2-F14-AJ).
 *
 * KENAPA ADA (akar masalah, terbukti 3× — bukan insiden tunggal):
 *   - agentsLogs_2026-09.md:1201  `.gitignore` byte 0x97 → U+FFFD
 *   - agentsLogs_2026-09.md:3232  `.env.example` byte 0x97 → U+FFFD
 *   - 2026-10-10 (L7 P2-F14-AH)   `DISASTER_RECOVERY.md` byte 0x97 → U+FFFD
 *   Semua terjadi karena editor lossy (str_replace / read-rewrite) membaca berkas
 *   sebagai UTF-8 LALU MENULIS ULANG SELURUH ISINYA. Byte CP1252 `0x97` (em-dash)
 *   bukan UTF-8 valid, jadi ia diam-diam berubah jadi `EF BF BD` (U+FFFD) —
 *   merusak konten tanpa error apa pun.
 *
 * CARA KERJA:
 *   - Daftar berkas = `git ls-files` lewat execFileSync TANPA shell (korpus identik
 *     lintas platform — pelajaran Fase-4a: cabang `process.platform` membuat korpus
 *     14 vs 26 antar OS).
 *   - Kelasifikasi ekstensi: biner diketahui → SKIP (PNG/wOFF/dkk bukan berkas teks).
 *   - Klasifikasi 'text' → `TextDecoder('utf-8', { fatal: true })`. Throw = MERAH.
 *   - Jaring pengaman NUL: berkas 'text' yang memuat byte 0x00 di 8 KB pertama
 *     dilaporkan sebagai SKIP biner (bukan MERAH) — berbiner yang salah kelas.
 *   - Tanpa Function()/eval/createRequire (keputusan user 2026-10-09).
 *
 * EXIT: 0 = semua berkas teks UTF-8 valid · 1 = ada berkas non-UTF8 · 2 = error.
 *
 * PEMAKAIAN:
 *   npm run verify:encoding
 *   node scripts/verify-text-encoding.mjs [--files=a.md,b.ts]
 */
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { execFileSync } from 'node:child_process';

const W = { pass: '\x1b[32m', fail: '\x1b[31m', warn: '\x1b[33m', dim: '\x1b[2m', off: '\x1b[0m' };

/** Ekstensi biner yang TIDAK PERNAH diperiksa (bukan berkas teks). */
const BINARY_EXT = new Set([
  '.png', '.jpg', '.jpeg', '.gif', '.ico', '.webp', '.avif', '.bmp', '.svgz',
  '.woff', '.woff2', '.ttf', '.otf', '.eot',
  '.pdf', '.zip', '.gz', '.tar', '.7z', '.rar', '.wasm', '.node', '.so', '.dll',
  '.mp3', '.mp4', '.webm', '.ogg', '.wav',
]);

/**
 * Ekstensi yang WAJIB berupa UTF-8 valid.
 * `.example` sengaja ada: `.env.example` → extname = `.example` (jebakan!) dan
 * itu berkas yang pernah rusak (agentsLogs_2026-09.md:3232).
 */
const TEXT_EXT = new Set([
  '.md', '.mdx', '.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs',
  '.json', '.jsonc', '.yml', '.yaml', '.toml', '.ini', '.cfg',
  '.sql', '.txt', '.text', '.csv',
  '.css', '.scss', '.less', '.html', '.htm', '.xml', '.svg',
  '.sh', '.bash', '.zsh', '.ps1', '.bat',
  '.example', '.template', '.sample', '.env', '.lock',
]);

/**
 * Kelasifikasi satu path relatif.
 * @returns {'text'|'binary-ext'}
 */
export function classify(filePath) {
  const base = path.basename(filePath);
  const ext = path.extname(base).toLowerCase();
  if (BINARY_EXT.has(ext)) return 'binary-ext';
  if (TEXT_EXT.has(ext)) return 'text';
  // Dotfile tanpa titik kedua (`.gitignore`, `.nvmrc`) dan berkas tanpa ekstensi
  // (Dockerfile, Makefile, LICENSE) = teks.
  if (base.startsWith('.env')) return 'text'; // .env, .env.local, .env.example
  if (ext === '') return 'text';
  return 'binary-ext';
}

/** Offset (0-based) byte UTF-8 invalid pertama; -1 bila tidak ditemukan. */
export function firstInvalidOffset(buf) {
  let i = 0;
  while (i < buf.length) {
    const c = buf[i];
    if (c < 0x80) { i++; continue; }
    const need = c >= 0xf0 ? 4 : c >= 0xe0 ? 3 : c >= 0xc0 ? 2 : 0;
    if (need === 0) return i; // continuation byte tanpa awal = selalu rusak
    if (i + need > buf.length) return i; // terpotong di akhir berkas
    try {
      new TextDecoder('utf-8', { fatal: true }).decode(buf.subarray(i, i + need));
      i += need;
    } catch {
      return i;
    }
  }
  return -1;
}

/**
 * Periksa satu berkas.
 * @returns {{file:string,status:'ok'|'invalid'|'skip-binary'|'skip-ext'|'missing',offset?:number,byte?:number}}
 */
export function scanFile(filePath) {
  const kind = classify(filePath);
  if (kind !== 'text') return { file: filePath, status: 'skip-ext' };

  let buf;
  try {
    buf = fs.readFileSync(filePath);
  } catch {
    return { file: filePath, status: 'missing' };
  }

  // Jaring pengaman: biner yang salah kelas (tanpa ekstensi dikenal tapi ada NUL).
  if (buf.subarray(0, 8192).includes(0)) return { file: filePath, status: 'skip-binary' };

  try {
    new TextDecoder('utf-8', { fatal: true }).decode(buf);
    return { file: filePath, status: 'ok' };
  } catch {
    const off = firstInvalidOffset(buf);
    return { file: filePath, status: 'invalid', offset: off, byte: off >= 0 ? buf[off] : null };
  }
}

/** Daftar berkas ter-track dari git (tanpa shell → identik lintas platform). */
export function listTrackedFiles() {
  const out = execFileSync('git', ['ls-files'], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  return out.split('\n').filter(Boolean);
}

/** Scan daftar path. @returns {{results:Array, checked:number, invalid:Array, skippedBin:number, skippedExt:number, missing:number}} */
export function scanAll(files) {
  const results = files.map(scanFile);
  return {
    results,
    checked: results.filter((r) => r.status === 'ok' || r.status === 'invalid').length,
    invalid: results.filter((r) => r.status === 'invalid'),
    skippedBin: results.filter((r) => r.status === 'skip-binary').length,
    skippedExt: results.filter((r) => r.status === 'skip-ext').length,
    missing: results.filter((r) => r.status === 'missing').length,
  };
}

function main() {
  const argv = process.argv.slice(2);
  const arg = argv.find((a) => a.startsWith('--files='));
  const override = arg ? arg.slice('--files='.length).split(',').map((s) => s.trim()).filter(Boolean) : null;

  let files;
  try {
    files = override ?? listTrackedFiles();
  } catch (e) {
    console.error(`${W.fail}FATAL${W.off} git ls-files gagal: ${e.message}`);
    process.exit(2);
  }
  if (files.length === 0) {
    // Anti hijau-palsu: korpus kosong = guard tidak memeriksa apa pun.
    console.error(`${W.fail}FATAL${W.off} korpus kosong — tidak ada berkas untuk diperiksa (guard akan hijau palsu).`);
    process.exit(2);
  }

  const s = scanAll(files);
  const total = files.length;
  console.log(`\n=== verify:encoding — guard UTF-8 (${total} berkas ter-track) ===\n`);

  for (const r of s.results) {
    if (r.status === 'skip-ext' || r.status === 'skip-binary') continue;
    if (r.status === 'missing') {
      console.log(`  ${W.warn}SKIP${W.off}  ${r.file.padEnd(56)} (tidak ada di worktree)`);
      continue;
    }
    if (r.status === 'ok') {
      console.log(`  ${W.pass}OK${W.off}    ${r.file}`);
    } else {
      const hex = r.byte === null ? '-' : '0x' + r.byte.toString(16).padStart(2, '0');
      console.log(
        `  ${W.fail}DRIFT${W.off} ${r.file.padEnd(56)} offset 0x${(r.offset ?? -1).toString(16)} byte ${hex} — bukan UTF-8 valid`
      );
    }
  }

  console.log(
    `\n=== RINGKASAN: ${s.invalid.length} file non-UTF8 · ${s.checked} file teks dicek · ` +
      `${s.skippedExt} biner (ekstensi) · ${s.skippedBin} biner (NUL) · ${s.missing} hilang ===\n`
  );

  if (s.invalid.length > 0) {
    console.log(`${W.fail}verify:encoding GAGAL${W.off} — ${s.invalid.length} file teks bukan UTF-8 valid.`);
    process.exit(1);
  }
  console.log(`${W.pass}verify:encoding OK${W.off} — semua file teks UTF-8 valid.`);
  process.exit(0);
}

// Jalankan main() HANYA bila dieksekusi langsung (bukan saat di-import test).
const DIRECT_RUN = Boolean(
  process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href
);
if (DIRECT_RUN) main();
