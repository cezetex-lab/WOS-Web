#!/usr/bin/env node
/**
 * scripts/run-vitest-with-log.mjs — wrapper `vitest run` yang MENGARSIPKAN artefak
 * per run dengan nama unik, supaya trace kegagalan tidak tertimpa run berikutnya.
 *
 * Latar (2026-10-14): `tests/unit/db-audit-trail.test.ts:82` gagal 2× dengan
 * `STACK_TRACE_ERROR`, tapi trace utuh HILANG karena `--reporter=json` menulis ke
 * `.vitest/test-result.json` yang selalu di-overwrite oleh run berikutnya (ketiga
 * log console bahkan identik byte-per-byte). Instrumentasi ini hanya MENDUPLIKASI
 * artefak — bukan retry, bukan suppress, bukan fix.
 *
 * Perilaku:
 *   1. spawn `npx vitest run` (+ argumen tambahan yang diteruskan apa adanya);
 *      selalu menambah `--reporter=default --reporter=json
 *      --outputFile=.vitest/test-result.json` supaya JSON trace selalu terbit.
 *   2. stdout+stderr di-tee ke `.agents/logs/vitest-<ISO>-<pid>.log`.
 *   3. Setelah child selesai, `.vitest/test-result.json` (kalau ada) disalin ke
 *      `.agents/logs/vitest-<ISO>-exit<KODE>.json` — nama unik per run, jadi tidak
 *      saling menimpa. Kalau JSON itu lebih lama dari waktu spawn, salinan tetap
 *      dibuat tapi ditandai `STALE` di nama file (jejak provinsi, §0.24).
 *   4. Exit dengan kode exit child process (tidak ditelan).
 *
 * Pemakaian:
 *   npm run verify:test-logged                       # full suite
 *   npm run verify:test-logged -- tests/unit/foo.test.ts   # teruskan filter ke vitest
 */
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const ROOT = path.resolve(import.meta.dirname, '..');
const LOG_DIR = path.join(ROOT, '.agents', 'logs');
const JSON_SRC = path.join(ROOT, '.vitest', 'test-result.json');
const JSON_NAME = '.vitest/test-result.json';

// Kolon tidak valid di nama file Windows → ganti dengan strip.
const STAMP = new Date().toISOString().replace(/[:.]/g, '-');
const FORWARDED = process.argv.slice(2);

fs.mkdirSync(LOG_DIR, { recursive: true });
const logPath = path.join(LOG_DIR, `vitest-${STAMP}-${process.pid}.log`);
const logStream = fs.createWriteStream(logPath, { flags: 'w' });

const startedAt = Date.now();

// --reporter=json + outputFile dipaksa di depan argumen pengguna supaya JSON trace
// selalu terbit (itu inti instrumentasinya); argumen pengguna menyusul di belakang.
const args = [
  'vitest',
  'run',
  '--reporter=default',
  '--reporter=json',
  `--outputFile=${JSON_NAME}`,
  ...FORWARDED,
];

const child = spawn('npx', args, {
  cwd: ROOT,
  shell: process.platform === 'win32',
  stdio: ['ignore', 'pipe', 'pipe'],
});

child.stdout.on('data', (chunk) => {
  process.stdout.write(chunk);
  logStream.write(chunk);
});
child.stderr.on('data', (chunk) => {
  process.stderr.write(chunk);
  logStream.write(chunk);
});

child.on('error', (error) => {
  const msg = `spawn error: ${error.stack ?? String(error)}\n`;
  process.stderr.write(msg);
  logStream.write(msg);
  logStream.end(() => process.exit(1));
});

child.on('close', (code, signal) => {
  const exitCode = code ?? 1;
  const signalNote = signal ? ` (sinyal: ${signal})` : '';

  // Duplikasi artefak JSON dengan nama unik — jangan biarkan trace run ini
  // tertimpa oleh run berikutnya.
  let jsonNote;
  if (fs.existsSync(JSON_SRC)) {
    const mtime = fs.statSync(JSON_SRC).mtimeMs;
    const stale = mtime < startedAt - 2000; // toleransi 2s untuk clock fs
    const destName = `vitest-${STAMP}-exit${exitCode}${stale ? '-STALE' : ''}.json`;
    const dest = path.join(LOG_DIR, destName);
    fs.copyFileSync(JSON_SRC, dest);
    jsonNote = stale
      ? `PERINGATAN JSON STALE — ${dest} (mtime lebih lama dari spawn; kemungkinan sisa run sebelumnya)`
      : `${dest}`;
  } else {
    jsonNote = `tidak ada (vitest tidak menulis ${JSON_NAME})`;
  }

  const summary =
    `\n[run-vitest-with-log] log  : ${logPath}\n` +
    `[run-vitest-with-log] json : ${jsonNote}\n` +
    `[run-vitest-with-log] exit : ${exitCode}${signalNote}\n`;
  process.stdout.write(summary);
  logStream.write(summary);
  logStream.end(() => process.exit(exitCode));
});
