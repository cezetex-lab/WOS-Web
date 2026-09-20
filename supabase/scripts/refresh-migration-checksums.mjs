#!/usr/bin/env node
/**
 * refresh-migration-checksums.mjs — selaraskan checksum yang TERCATAT dengan
 * algoritma checksum yang berlaku sekarang (SQL-10).
 *
 * Kenapa perlu (temuan SQL-10, AGENTS.md §5.8)
 * --------------------------------------------
 * Dulu checksum dihitung dari BYTE MENTAH berkas kerja. Repo ini memakai
 * `.gitattributes: * text=auto eol=crlf`, jadi working tree bisa berisi CRLF
 * (66 dari 164 berkas migrasi saat temuan ini dibuat) maupun LF. Nilai yang
 * tercatat — cap di `supabase/baseline/010_baseline_config_data.sql` dan
 * registry `schema_migrations` — adalah campuran hash LF dan CRLF, sehingga:
 *
 *   * cap baseline tidak bisa direproduksi di checkout bergaya EOL berbeda;
 *   * `apply-migration.mjs` meminta `--restamp` tanpa sebab nyata.
 *
 * Sejak `supabase/scripts/migration-checksum.mjs`, EOL dinormalisasi CRLF→LF
 * sebelum hashing — checksum jadi bebas EOL. Akibatnya nilai yang tercatat
 * untuk berkas ber-CRLF perlu disegarkan SEKALI ke nilai baru.
 *
 * Dua kelas drift dibedakan (penting, jangan dicampur):
 *   1. EOL-only  — registry = hash byte berkas SEKARANG, hanya gaya EOL berbeda.
 *                  Murni definisi → aman & benar untuk disegarkan.
 *   2. KONTEN    — registry ≠ hash byte berkas sekarang, artinya berkas sudah
 *                  DIEDIT setelah diterapkan. Ini BUKAN urusan checksum: bisa
 *                  berarti live belum memuat perubahan itu. Skrip ini MENOLAK
 *                  menyentuhnya kecuali `--force-content`, dan hanya melaporkan.
 *
 * Pakai:
 *   node supabase/scripts/refresh-migration-checksums.mjs                  # DRY RUN (laporan saja)
 *   node supabase/scripts/refresh-migration-checksums.mjs --apply --db     # segarkan cap + restamp live
 *   node supabase/scripts/refresh-migration-checksums.mjs --apply          # hanya cap baseline
 *   node supabase/scripts/refresh-migration-checksums.mjs --apply --force-content --db
 *
 * Aturan aman: baseline TIDAK pernah ditulis tanpa `--apply`, dan setiap tulisan
 * lewat `scripts/safe-file-writer.ts` (baca-ulang diverifikasi).
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
import { Client } from 'pg';
import { legacyRawChecksum, migrationChecksum } from './migration-checksum.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const MIG_DIR = path.join(ROOT, 'supabase', 'migrations');
const BASELINE = path.join(ROOT, 'supabase', 'baseline', '010_baseline_config_data.sql');
const TMP = path.join(ROOT, '.agents', 'scripts', '010-refresh.tmp');

const args = process.argv.slice(2);
const apply = args.includes('--apply');
const withDb = args.includes('--db');
const forceContent = args.includes('--force-content');

if (args.includes('--force-content') && !apply) {
  console.log('(catatan: --force-content tanpa --apply hanya memengaruhi laporan)');
}

// ── 1. Kumpulkan berkas + hitung dua algoritma ───────────────────────────────
const files = fs.readdirSync(MIG_DIR).filter((f) => f.endsWith('.sql')).sort();
const hitung = new Map();
let berCrlf = 0;
for (const f of files) {
  const full = path.join(MIG_DIR, f);
  const buf = fs.readFileSync(full);
  if (buf.includes(0x0d)) berCrlf += 1;
  hitung.set(f, {
    baru: migrationChecksum(full),
    lama: legacyRawChecksum(buf),
  });
}
console.log(`berkas migrasi : ${files.length} (${berCrlf} ber-CRLF, ${files.length - berCrlf} LF)`);

// ── 2. Cap baseline ───────────────────────────────────────────────────────────
const capRegex = /(VALUES \('[^']*', ')([^']+)('[,]\s*')([0-9a-f]{64})(', 'baseline install)/g;
const baselineRaw = fs.readFileSync(BASELINE, 'utf8');
const capStale = [];
for (const m of baselineRaw.matchAll(capRegex)) {
  const nama = m[2];
  const lamaCap = m[4];
  const h = hitung.get(nama);
  if (!h) continue;
  if (h.baru !== lamaCap) {
    capStale.push({ nama, lamaCap, baru: h.baru, eolOnly: lamaCap === h.lama });
  }
}
console.log(`\ncap baseline perlu disegarkan : ${capStale.length}`);
const capKonten = capStale.filter((c) => !c.eolOnly);
console.log(`  di antaranya bukan EOL-only : ${capKonten.length}${capKonten.length ? ' → ' + capKonten.map((c) => c.nama).join(', ') : ''}`);

// ── 3. Registry live ─────────────────────────────────────────────────────────
let client;
let eolOnly = [];
let konten = [];
if (withDb) {
  const env = fs.readFileSync(path.join(ROOT, '.env.local'), 'utf8');
  const line = env.split(/\r?\n/).find((v) => /^\s*DATABASE_URL\s*=/.test(v));
  if (!line) throw new Error('DATABASE_URL tidak tersedia di .env.local');
  const connectionString = line.split('=').slice(1).join('=').trim().replace(/^["']|["']$/g, '');
  client = new Client({ connectionString, ssl: { rejectUnauthorized: false } });
  await client.connect();
  const rows = (await client.query('SELECT filename, checksum FROM schema_migrations')).rows;
  for (const r of rows) {
    const h = hitung.get(r.filename);
    if (!h || r.checksum === h.baru) continue;
    (r.checksum === h.lama ? eolOnly : konten).push(r.filename);
  }
  console.log(`\nregistry live — drift EOL-only : ${eolOnly.length}`);
  console.log(`registry live — drift KONTEN   : ${konten.length}`);
  if (konten.length > 0) {
    console.log('  (tidak disentuh tanpa --force-content; perlu audit terpisah:');
    for (const f of konten) console.log(`     - ${f}`);
    console.log('   )');
  }
} else {
  console.log('\n(--db tidak dipakai: registry live tidak diperiksa)');
}

if (!apply) {
  console.log('\nDRY RUN — tidak ada yang ditulis. Tambahkan --apply untuk mengeksekusi.');
  if (client) await client.end();
  process.exit(0);
}

// ── 4. Tulis baseline ────────────────────────────────────────────────────────
if (capStale.length > 0) {
  const baru = baselineRaw.replace(capRegex, (full, pre, nama, mid, lamaCap, post) => {
    const h = hitung.get(nama);
    if (!h || h.baru === lamaCap) return full;
    return `${pre}${nama}${mid}${h.baru}${post}`;
  });
  fs.writeFileSync(TMP, baru, 'utf8');
  execFileSync(
    'node',
    ['scripts/safe-file-writer.ts', '--file', BASELINE, '--content-file', TMP, '--mode', 'overwrite'],
    { cwd: ROOT, stdio: 'inherit' },
  );
  // Verifikasi pasca-tulis
  const sesudah = fs.readFileSync(BASELINE, 'utf8');
  let sisa = 0;
  for (const m of sesudah.matchAll(capRegex)) {
    const h = hitung.get(m[2]);
    if (h && h.baru !== m[4]) sisa += 1;
  }
  if (sisa > 0) throw new Error(`pasca-tulis: masih ada ${sisa} cap tidak cocok`);
  console.log(`\ncap baseline disegarkan: ${capStale.length} (0 sisa tidak cocok)`);
} else {
  console.log('\ncap baseline sudah konsisten — tidak ada yang ditulis');
}

// ── 5. Restamp registry live ─────────────────────────────────────────────────
if (client) {
  const target = forceContent ? [...eolOnly, ...konten] : eolOnly;
  const dilewati = forceContent ? [] : konten;
  for (const f of target) {
    const h = hitung.get(f);
    await client.query(
      `UPDATE schema_migrations
          SET checksum = $2,
              description = COALESCE(NULLIF(description, ''), 'restamped')
                            || ' | checksum disegarkan (SQL-10, EOL-normal) ${new Date().toISOString()}'
        WHERE filename = $1`,
      [f, h.baru],
    );
  }
  const cek = await client.query('SELECT verify_migration_checksum($1, $2) AS ok', [
    target[0] ?? 'x',
    target[0] ? hitung.get(target[0]).baru : 'y',
  ]);
  console.log(
    `registry disegarkan       : ${target.length}` +
      (dilewati.length ? ` · DILEWATI (drift konten): ${dilewati.length}` : ''),
  );
  console.log(`verify (contoh pertama)   : ${target.length ? cek.rows[0].ok : 'tidak ada target'}`);
  await client.end();
}
