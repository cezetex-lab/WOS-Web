#!/usr/bin/env node
/**
 * apply-migration.mjs — jalankan migrasi DAN daftarkannya ke `schema_migrations`
 * dalam SATU transaksi.
 *
 * Kenapa ada: migrasi 221/222/223 pernah diterapkan ke DB live lewat SQL Editor
 * tanpa tercatat, sehingga `schema_migrations` berhenti di 220 sementara repo
 * sudah punya 149 berkas (lihat AGENTS.md §5.7 no.11). Wrapper ini menutup celah
 * itu secara struktural: kalau pendaftaran gagal, SQL-nya ikut di-ROLLBACK —
 * jadi mustahil berakhir dengan migrasi "sudah jalan tapi tidak tercatat".
 *
 * Pakai:
 *   node supabase/scripts/apply-migration.mjs 224_nama_migrasi.sql          # dry run
 *   node supabase/scripts/apply-migration.mjs 224_nama_migrasi.sql --apply
 *
 * Atau via npm:
 *   npm run db:migrate -- 224_nama_migrasi.sql --apply
 *
 * Kredensial dibaca dari DATABASE_URL (env) atau `.env.local`.
 */
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Client } from 'pg';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const MIGRATIONS_DIR = path.join(ROOT, 'supabase', 'migrations');

const args = process.argv.slice(2);
const apply = args.includes('--apply');
const filename = args.find((a) => !a.startsWith('--'));

if (!filename) {
  console.error('Pakai: node supabase/scripts/apply-migration.mjs <file.sql> [--apply]');
  process.exit(2);
}

const filePath = path.join(MIGRATIONS_DIR, path.basename(filename));
if (!fs.existsSync(filePath)) {
  console.error(`Berkas tidak ada: ${filePath}`);
  process.exit(2);
}

function readDatabaseUrl() {
  if (process.env.DATABASE_URL) return process.env.DATABASE_URL;
  const envPath = path.join(ROOT, '.env.local');
  if (!fs.existsSync(envPath)) {
    console.error('DATABASE_URL tidak ada di env maupun .env.local');
    process.exit(2);
  }
  const line = fs
    .readFileSync(envPath, 'utf8')
    .split(/\r?\n/)
    .find((l) => /^\s*DATABASE_URL\s*=/.test(l));
  if (!line) {
    console.error('DATABASE_URL tidak ditemukan di .env.local');
    process.exit(2);
  }
  return line.slice(line.indexOf('=') + 1).trim().replace(/^["']|["']$/g, '');
}

const shortName = path.basename(filePath);
const sql = fs.readFileSync(filePath, 'utf8');
const checksum = createHash('sha256').update(fs.readFileSync(filePath)).digest('hex');
const version = /^(\d+)/.exec(shortName)?.[1];

if (!version) {
  console.error(`Nama berkas harus diawali nomor versi: ${shortName}`);
  process.exit(2);
}

if (/^\s*(BEGIN|COMMIT|ROLLBACK)\s*;/im.test(sql)) {
  console.warn('PERINGATAN: berkas berisi kontrol transaksi sendiri; wrapper juga membungkusnya.');
}

const client = new Client({
  connectionString: readDatabaseUrl(),
  ssl: { rejectUnauthorized: false },
});
await client.connect();

let exitCode = 0;
try {
  const tracked = await client.query(
    'SELECT filename, checksum FROM schema_migrations WHERE filename = $1',
    [shortName],
  );
  const versionOwner = await client.query(
    'SELECT filename FROM schema_migrations WHERE version = $1 AND filename <> $2',
    [version, shortName],
  );

  console.log(`berkas    : ${shortName}`);
  console.log(`versi     : ${version}`);
  console.log(`checksum  : ${checksum}`);

  if (tracked.rows.length > 0) {
    const same = tracked.rows[0].checksum === checksum;
    console.log(`status    : SUDAH terdaftar (checksum ${same ? 'cocok' : 'BERBEDA'})`);
    if (!same) {
      console.error('Checksum berbeda — berkas berubah setelah diterapkan. Tidak ada yang dijalankan.');
      exitCode = 1;
    }
  } else if (versionOwner.rows.length > 0) {
    // Kalau dibiarkan, apply_migration() akan menolak (RETURN FALSE) padahal SQL
    // sudah jalan → persis bug 221/222/223. Jadi dihentikan sebelum mengeksekusi.
    console.error(
      `Versi ${version} sudah dipakai oleh ${versionOwner.rows[0].filename}. ` +
        'Pilih nomor versi lain; SQL TIDAK dijalankan.',
    );
    exitCode = 1;
  } else if (!apply) {
    console.log('status    : belum terdaftar');
    console.log('\nDRY RUN — tidak ada yang dijalankan. Tambahkan --apply untuk menerapkan.');
  } else {
    const started = Date.now();
    await client.query('BEGIN');
    try {
      await client.query(sql);
      const registered = await client.query(
        'SELECT apply_migration($1, $2, $3, $4, $5) AS ok',
        [version, shortName, checksum, `Applied via apply-migration.mjs (${shortName})`, Date.now() - started],
      );
      if (registered.rows[0].ok !== true) {
        throw new Error('apply_migration() menolak mendaftarkan migrasi ini');
      }
      const verified = await client.query(
        'SELECT verify_migration_checksum($1, $2) AS ok',
        [shortName, checksum],
      );
      if (verified.rows[0].ok !== true) {
        throw new Error('verify_migration_checksum() gagal setelah pendaftaran');
      }
      await client.query('COMMIT');
      console.log(`status    : DITERAPKAN + terdaftar + checksum terverifikasi (${Date.now() - started}ms)`);
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    }
  }
} catch (err) {
  console.error(`GAGAL: ${err.message}`);
  exitCode = 1;
} finally {
  await client.end();
}

process.exit(exitCode);
