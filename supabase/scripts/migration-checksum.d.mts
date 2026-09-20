/**
 * Deklarasi tipe untuk `migration-checksum.mjs`.
 *
 * Skrip di `supabase/scripts/` memakai `.mjs` (konvensi folder ini, dijalankan
 * `node` langsung), sedangkan tes/`src` memakai TypeScript. Tanpa berkas ini,
 * `import { migrationChecksum } from '../../supabase/scripts/migration-checksum.mjs'`
 * gagal `tsc` dengan TS7016 (implicit any) — dan itu berarti guard SQL-10 tidak
 * bisa hidup di dalam suite TypeScript.
 */

/** Normalisasi urutan CRLF menjadi LF pada byte (tanpa menyentuh byte lain). */
export declare function normalizeEolBytes(buffer: Buffer): Buffer;

/** sha256 atas byte yang sudah dinormalisasi EOL-nya. */
export declare function sha256OfNormalized(buffer: Buffer): string;

/** Checksum migrasi: sha256 byte berkas dengan EOL CRLF→LF dinormalisasi. */
export declare function migrationChecksum(filePath: string): string;

/** Checksum algoritma LAMA (byte mentah) — hanya untuk membuktikan perbedaannya. */
export declare function legacyRawChecksum(buffer: Buffer): string;
