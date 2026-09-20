/**
 * migration-checksum.mjs — SATU-SATUNYA cara menghitung checksum berkas migrasi.
 *
 * Kenapa berkas ini ada (temuan SQL-10, AGENTS.md §5.8)
 * ----------------------------------------------------
 * Checksum migrasi dihitung dari byte BERKAS KERJA. Repo ini memakai
 * `.gitattributes: * text=auto eol=crlf` — artinya blob di repo memakai LF,
 * tetapi working tree di Windows di-checkout sebagai CRLF. Akibatnya nilai
 * checksum bergantung pada mesin/checkout:
 *
 *   * cap `schema_migrations` di baseline dihitung dari berkas LF;
 *   * `apply-migration.mjs` di checkout CRLF menghitung nilai berbeda;
 *   * hasilnya registry "tidak cocok" padahal isi berkasnya identik, dan
 *     operator diminta `--restamp` tanpa sebab.
 *
 * Perbaikan: EOL dinormalisasi CRLF→LF **sebelum** di-hash, sehingga checksum
 * hanya bergantung pada ISI berkas, bukan gaya EOL checkout. Terukur 2026-09-20
 * pada `141_153_CONSOLIDATED_.sql` (berkas migrasi terbesar):
 *
 * | Algoritma | checkout LF | checkout CRLF |
 * |---|---|---|
 * | lama (byte mentah) | `17989aa042163cf1…` | `7a7f0b9a5d5c83e1…` |
 * | baru (EOL normal) | `17989aa042163cf1…` | `17989aa042163cf1…` |
 *
 * Nilai baru identik dengan yang sudah ada di `schema_migrations` dan di cap
 * baseline, jadi perbaikan ini tidak menuntut restamp apa pun.
 *
 * Kompatibilitas: pada checkout LF (kondisi repo ini) normalisasi tidak mengubah
 * satu byte pun, jadi seluruh checksum yang sudah tercatat di `schema_migrations`
 * dan di baseline TETAP sah — tidak perlu restamp massal. Diverifikasi dengan
 * menjalankan `apply-migration.mjs` tanpa `--restamp`: hasilnya "checksum cocok".
 *
 * Implementasi: operasi dilakukan pada byte (round-trip `latin1`) supaya byte
 * mentah tidak pernah ditafsirkan ulang sebagai UTF-8 — BOM dan byte non-ASCII
 * apa pun tetap apa adanya, sementara CRLF (0x0D 0x0A) menjadi LF (0x0A).
 */
import fs from 'node:fs';
import { createHash } from 'node:crypto';

/** Normalisasi urutan CRLF menjadi LF pada byte (tanpa menyentuh byte lain). */
export function normalizeEolBytes(buffer) {
  return Buffer.from(buffer.toString('latin1').replace(/\r\n/g, '\n'), 'latin1');
}

/** sha256 atas byte yang sudah dinormalisasi EOL-nya. */
export function sha256OfNormalized(buffer) {
  return createHash('sha256').update(normalizeEolBytes(buffer)).digest('hex');
}

/**
 * Checksum migrasi: sha256 byte berkas dengan EOL CRLF→LF dinormalisasi.
 * Dipakai `apply-migration.mjs` dan `generate-baseline-data.mjs` supaya cap
 * baseline dan registry selalu memakai definisi yang sama.
 */
export function migrationChecksum(filePath) {
  return sha256OfNormalized(fs.readFileSync(filePath));
}

/** Checksum algoritma LAMA (byte mentah) — hanya untuk membuktikan perbedaannya. */
export function legacyRawChecksum(buffer) {
  return createHash('sha256').update(buffer).digest('hex');
}
