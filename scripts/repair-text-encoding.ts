#!/usr/bin/env node
/**
 * scripts/repair-text-encoding.ts — perbaiki berkas teks yang ekornya ter-append dengan
 * encoding berbeda (gejala nyata: `agentsLogs.md` 2026-09-19 — 864 NULL byte).
 *
 * KASUS NYATA yang memunculkan skrip ini: append ke `agentsLogs.md` lewat redirection
 * shell di Windows menulis ekornya sebagai **UTF-16** (bukan UTF-8). Hasilnya berkas
 * campuran: awalnya UTF-8 normal, ekornya berpasangan byte dengan NULL di antaranya.
 * Teksnya TIDAK hilang (setiap karakter ASCII jadi `00 XX` atau `XX 00`), jadi bisa
 * dipulihkan — bukan alasan untuk `git checkout` yang akan membuang entri lain.
 *
 * Cara kerja:
 *   1. cari byte NULL pertama — di situlah encoding berubah;
 *   2. tebak titik awal payload dengan mencoba beberapa offset & dua urutan byte
 *      (BE/LE), lalu pilih yang rasio karakter tercetaknya paling tinggi;
 *   3. decode payload, gabungkan kembali dengan prefix UTF-8 yang TIDAK diubah;
 *   4. tulis lewat `safe-file-writer.ts` (UTF-8 ketat, EOL seragam, verifikasi baca-ulang).
 *
 * Jaminan: prefix UTF-8 dipertahankan apa adanya (hanya baris-kosong di perbatasan
 * yang dirapikan), dan skrip MENOLAK jalan kalau tidak menemukan payload yang masuk akal.
 *
 * Pemakaian:
 *   node scripts/repair-text-encoding.ts --file agentsLogs.md --dry-run
 *   node scripts/repair-text-encoding.ts --file agentsLogs.md
 */
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { writeFileSafe } from './safe-file-writer.ts';

const argv = process.argv.slice(2);
const fileArg = argv.includes('--file') ? argv[argv.indexOf('--file') + 1] : undefined;
const DRY = argv.includes('--dry-run');

if (!fileArg) {
  console.error('wajib: --file <path> [--dry-run]');
  process.exitCode = 1;
} else {
  process.exitCode = run(path.resolve(fileArg));
}

/** Rasio karakter "wajar" pada teks hasil decode — dipakai memilih offset & byte order. */
function printableRatio(text: string): number {
  let good = 0;
  let bad = 0;
  for (const ch of text) {
    const code = ch.codePointAt(0) ?? 0;
    if (code === 0xfffd) bad += 4;
    else if (code === 9 || code === 10 || code === 13) good += 1;
    else if (code >= 32 && code < 0x7f) good += 1;
    else if (code >= 0xa0 && code <= 0x2fff) good += 1;
    else bad += 1;
  }
  const total = good + bad;
  return total === 0 ? 0 : good / total;
}

/** Decode payload UTF-16 dengan urutan byte tertentu (Node hanya punya 'utf16le'). */
function decodeUtf16(bytes: Buffer, order: 'le' | 'be'): string {
  if (order === 'le') return bytes.toString('utf16le');
  const swapped = Buffer.from(bytes);
  for (let i = 0; i + 1 < swapped.length; i += 2) {
    const tmp = swapped[i];
    swapped[i] = swapped[i + 1];
    swapped[i + 1] = tmp;
  }
  return swapped.toString('utf16le');
}

function run(file: string): number {
  if (!fs.existsSync(file)) {
    console.error(`berkas tidak ada: ${file}`);
    return 1;
  }
  const raw = fs.readFileSync(file);
  const firstNul = raw.indexOf(0);
  const leadingBoms = raw.toString('utf8').match(/^\uFEFF+/)?.[0].length ?? 0;

  if (firstNul < 0) {
    if (leadingBoms <= 1) {
      console.log(`bersih: ${file} tidak memuat NULL byte — tidak ada yang dikerjakan.`);
      return 0;
    }
    // Kasus kedua yang ditemukan di berkas yang sama: BOM berlipat di awal.
    console.log(`berkas        : ${file}`);
    console.log(`NULL byte     : 0 — tetapi BOM di awal berlipat ${leadingBoms}×`);
    const fixed = raw.toString('utf8').replace(/^\uFEFF+/, '');
    if (DRY) {
      console.log(`DRY RUN — akan dirapikan menjadi satu BOM (${raw.length} → ${Buffer.byteLength(fixed, 'utf8')} byte).`);
      return 0;
    }
    const r = writeFileSafe(file, fixed, { mode: 'overwrite' });
    console.log(`DIPERBAIKI: ${r.bytesBefore} → ${r.bytesAfter} byte, BOM dirapikan: ${r.bomsCollapsed}`);
    return 0;
  }
  const totalNul = raw.filter((b) => b === 0).length;
  console.log(`berkas        : ${file}`);
  console.log(`NULL byte     : ${totalNul} (pertama di offset ${firstNul} dari ${raw.length})`);

  // Cari titik awal payload terbaik di sekitar NULL pertama.
  // PENTING: satu byte meleset menggeser seluruh pasangan UTF-16 dan menyisipkan karakter
  // sampah di awal (gejala nyata: `഍` dari tiga byte 0d liar). Karena itu offset yang
  // menghasilkan awal "wajar" (CR/LF/tab/ASCII tercetak) diutamakan, bukan sekadar skor
  // rasio — dan kalau seri, offset TERBESAR yang dipilih supaya byte liar tak ikut masuk.
  let best: { start: number; order: 'le' | 'be'; rank: number; score: number; text: string } | null = null;
  for (let delta = 4; delta >= -3; delta -= 1) {
    const start = firstNul + delta;
    // `start > firstNul` berarti ada NULL byte yang tertinggal di dalam prefix UTF-8 yang
    // "dipertahankan" — persis yang membuat perbaikan pertama saya ditolak mesin ini.
    if (start <= 0 || start >= raw.length || start > firstNul) continue;
    const payload = raw.subarray(start);
    for (const order of ['le', 'be'] as const) {
      let text: string;
      try {
        text = decodeUtf16(payload, order);
      } catch {
        continue;
      }
      const score = printableRatio(text);
      const startsClean = /^[\r\n\t\x20-\x7e]/.test(text) ? 1 : 0;
      const rank = startsClean * 2 + score;
      if (best === null || rank > best.rank) best = { start, order, rank, score, text };
    }
  }

  if (best === null || best.score < 0.5) {
    console.error(`GAGAL: tidak menemukan payload UTF-16 yang masuk akal (skor terbaik ${best?.score ?? 0}).`);
    console.error('Periksa berkasnya manual — jangan ditimpa.');
    return 1;
  }

  const prefixText = raw.subarray(0, best.start).toString('utf8');
  const payloadText = best.text;
  console.log(`payload       : mulai offset ${best.start}, byte order ${best.order.toUpperCase()}, skor ${best.score.toFixed(3)}`);
  console.log(`  prefix UTF-8: ${best.start} byte (${prefixText.length} karakter)`);
  console.log(`  payload     : ${raw.length - best.start} byte → ${payloadText.length} karakter`);

  // Rapikan hanya perbatasan: baris baru berlebih di ekor prefix & di awal payload.
  const cleanPrefix = prefixText.replace(/[\r\n]+$/, '');
  const cleanPayload = payloadText.replace(/^[\r\n]+/, '').replace(/[\r\n]+$/, '');
  const eol = prefixText.includes('\r\n') ? '\r\n' : '\n';
  const repaired = cleanPrefix + eol + eol + cleanPayload + eol;

  // Sanity: teks hasil harus benar-benar menyusut NUL-nya dan memuat payload yang terbaca.
  if (repaired.includes('\u0000')) {
    console.error('GAGAL: hasil perbaikan masih memuat NULL — payload bukan UTF-16 murni.');
    return 1;
  }
  if (!repaired.startsWith(cleanPrefix.slice(0, 200))) {
    console.error('GAGAL: prefix UTF-8 tidak utuh setelah perbaikan.');
    return 1;
  }

  const tailLines = cleanPayload.split(/\r?\n/).filter((l) => l.trim() !== '');
  console.log(`\n--- 12 baris terakhir yang DIPULIHKAN ---`);
  for (const l of tailLines.slice(0, 12)) console.log('  | ' + l.slice(0, 120));

  if (DRY) {
    console.log(`\nDRY RUN — tidak ditulis. Hasil akan: ${raw.length} → ${Buffer.byteLength(repaired, 'utf8')} byte.`);
    return 0;
  }

  const report = writeFileSafe(file, repaired, {
    mode: 'overwrite',
    // Satu-satunya tempat yang boleh menimpa berkas ber-NULL: berkas INI memang yang
    // sedang diperbaiki. Peringatannya tetap dicetak oleh safe-file-writer.
    allowOverwritingCorrupt: true,
    corruptReason: `repair-text-encoding: memulihkan ${totalNul} NULL byte / payload UTF-16`, 
  });
  const after = fs.readFileSync(file);
  const nulAfter = after.filter((b) => b === 0).length;
  console.log(`\nDIPERBAIKI: ${report.bytesBefore} → ${report.bytesAfter} byte, eol=${report.eol}, NULL sekarang ${nulAfter}`);
  if (nulAfter !== 0) {
    console.error('PERINGATAN: masih ada NULL byte — periksa manual.');
    return 1;
  }
  console.log(`baris terakhir berkas: ${report.lastLine}`);
  return 0;
}
