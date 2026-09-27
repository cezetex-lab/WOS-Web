#!/usr/bin/env node
/**
 * verify-backup-artifact.mjs — penjaga artifact backup harian (P1-14-02 sebagian).
 *
 * KENAPA ADA
 *   Backup harian (`.github/workflows/supabase-backup.yml`) berjalan tanpa
 *   error, tapi "ada file .gz" BUKAN bukti backup bisa dipulihkan. Selama
 *   run #28-#32, dump berhasil dibuat & ter-upload,.restore selalu gagal
 *   karena target restore (Neon) tidak kompatibel. Tidak ada satu pun
 *   pemeriksaan yang menangkap itu otomatis.
 *
 *   Script ini menutup lubang paling murah: apakah artifact yang diupload
 *   itu benar-benar bisa dibuka dan isinya masuk akal?
 *
 * YANG DICEK (tanpa koneksi DB — bisa jalan di runner mana pun)
 *   1. File .gz ada dan tidak nol byte.
 *   2. Ukuran gzip di dalam ambang wajar (default 50 kB .. 10 MB).
 *   3. gzip -t lulus (integritas stream, bukan hanya magic byte).
 *   4. Isi decompres punya header pg_dump yang dikenali.
 *   5. Mengandung perintah CREATE yang berarti (bukan dump kosong).
 *
 * YANG SENGAJA TIDAK DICEK
 *   Restore ke DB sungguhan. Itu butuh target, kredensial, dan biaya —
 *   lihat `.github/workflows/restore-test.yml` (mingguan, replay-fresh-install).
 *   Script ini TIDAK boleh menulis ke DB mana pun.
 *
 * PEMAKAIAN
 *   node scripts/verify-backup-artifact.mjs backups/backup_2026-09-27_02-00-00.sql.gz
 *   node scripts/verify-backup-artifact.mjs --min-bytes 100000 --max-bytes 20000000 <file>
 *   exit 0 = lull, exit 1 = artifact rusak
 */
import fs from 'node:fs';
import zlib from 'node:zlib';

const argv = process.argv.slice(2);
const arg = (n, d) => {
  const hit = argv.find((a) => a.startsWith(`--${n}=`));
  return hit ? hit.slice(n.length + 3) : d;
};

const MIN = Number(arg('min-bytes', 50 * 1024));
const MAX = Number(arg('max-bytes', 10 * 1024 * 1024));

const file = argv.find((a) => !a.startsWith('--'));
const W = { pass: '\x1b[32m', fail: '\x1b[31m', warn: '\x1b[33m', dim: '\x1b[2m', off: '\x1b[0m' };
let failures = 0;

function check(label, ok, detail = '') {
  if (ok) {
    console.log(`  ${W.pass}PASS${W.off}  ${label}${detail ? ` (${detail})` : ''}`);
  } else {
    failures++;
    console.log(`  ${W.fail}FAIL${W.off}  ${label}${detail ? ` (${detail})` : ''}`);
  }
}

if (!file) {
  console.error('PEMAKAIAN: node scripts/verify-backup-artifact.mjs <file.sql.gz>');
  process.exit(2);
}

console.log(`\nVerifikasi artifact backup: ${file}`);
console.log(`${W.dim}ambang: ${MIN} B .. ${MAX} B${W.off}\n`);

// 1. Ada & tidak nol
if (!fs.existsSync(file)) {
  check('file ada', false, 'tidak ditemukan');
  console.error(`\n${W.fail}GAGAL${W.off} — artifact backup tidak ada. Backup harian mungkin tidak berjalan.`);
  process.exit(1);
}
const gzSize = fs.statSync(file).size;
check('file ada & tidak nol', gzSize > 0, `${gzSize} B`);

// 2. Ukuran dalam ambang
const inRange = gzSize >= MIN && gzSize <= MAX;
check(
  'ukuran dalam ambang',
  inRange,
  inRange
    ? `${(gzSize / 1024 / 1024).toFixed(2)} MiB`
    : `${(gzSize / 1024 / 1024).toFixed(2)} MiB di luar ${(MIN / 1024 / 1024).toFixed(2)}..${(MAX / 1024 / 1024).toFixed(2)} MiB`,
);

// 3. Integritas gzip — decompress penuh sekaligus jadi bukti tak korup
let sql = null;
try {
  sql = zlib.gunzipSync(fs.readFileSync(file)).toString('utf8');
  check('gzip -t / integritas stream', true, `${(sql.length / 1024 / 1024).toFixed(2)} MiB sql`);
} catch (e) {
  check('gzip -t / integritas stream', false, e.message);
}

// 4. Header dump dikenali
if (sql !== null) {
  const head = sql.slice(0, 4000);
  // Header yang mungkin muncul. pg_dump polos selalu menulis
  // "-- PostgreSQL database dump"; sisanya untuk dump dari tool lain
  // (pg_dumpall, dump baseline generator repo ini) supaya tidak salah
  // memblokir backup yang sebenarnya sehat.
  const KNOWN = [
    /PostgreSQL database dump/i,
    /BASELINE SKEMA/i,
    /Dumped (from|by) database/i,
  ];
  const headerOk = KNOWN.some((re) => re.test(head));
  // check() dengan ketegangan rendah: kegagalan header TIDAK menggagalkan
  // build. Bukti kuat sudah ada di integritas gzip + jumlah CREATE;
  // header hanya petunjuk tambahan. Menandainya fatal berisiko memblokir
  // backup yang sebenarnya utuh.
  if (headerOk) {
    console.log(`  ${W.pass}PASS${W.off}  header dump dikenali`);
  } else {
    console.log(
      `  ${W.warn}WARN${W.off}  header dump tidak dikenali ` +
        `${W.dim}(dicek: pg_dump / pg_dumpall / baseline generator)${W.off}`,
    );
  }

  // 5. Isi berarti, bukan dump kosong
  const creates = (sql.match(/^CREATE /gm) || []).length;
  check('mengandung CREATE yang berarti', creates > 0, `${creates} perintah CREATE`);

  // Info tambahan (tidak menggagalkan) — membantu diagnosis restore
  const schemas = [...new Set((sql.match(/SCHEMA [a-z_]+/gi) || []).map((s) => s.toUpperCase()))];
  const lines = sql.split('\n').length;
  console.log(`\n${W.dim}  info: ${lines} baris, ${creates} CREATE, schema disebut: ${schemas.join(', ') || 'n/a'}${W.off}`);
}

if (failures > 0) {
  console.error(`\n${W.fail}GAGAL${W.off} — ${failures} pemeriksaan gagal. Backup harian perlu diperiksa.`);
  process.exit(1);
}

console.log(`\n${W.pass}LULL${W.off} — artifact dapat dibuka & isinya masuk akal.\n`);
console.log(`${W.dim}Catatan: ini BUKAN bukti restore. Restore test mingguan ada di restore-test.yml.${W.off}\n`);
