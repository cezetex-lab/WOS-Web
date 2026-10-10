/**
 * Deklarasi tipe untuk `verify-text-encoding.mjs`.
 *
 * Guard ditulis `.mjs` (ES module murni, dijalankan `node` langsung oleh CI dan
 * `npm run verify:encoding`), sedangkan tes memakai TypeScript. Tanpa berkas ini
 * `import { scanFile } from '../../scripts/verify-text-encoding.mjs'` gagal `tsc`
 * dengan TS7016 (implicit any) karena `tsconfig.json` memakai `strict: true` —
 * dan berarti guard P2-F14-AJ tidak bisa hidup di dalam suite TypeScript.
 * Pola yang sama dipakai `supabase/scripts/migration-checksum.d.mts`.
 */

/** Hasil pemeriksaan satu berkas. */
export interface ScanResult {
  file: string;
  /** `ok` = UTF-8 valid · `invalid` = bukan UTF-8 valid · `skip-*` = bukan berkas teks. */
  status: 'ok' | 'invalid' | 'skip-binary' | 'skip-ext' | 'missing';
  /** Offset (0-based) byte invalid pertama; hanya untuk `invalid`. */
  offset?: number;
  /** Nilai byte invalid pertama (desimal); hanya untuk `invalid`. */
  byte?: number;
}

/** Ringkasan satu batch pemeriksaan. */
export interface ScanSummary {
  results: ScanResult[];
  /** Jumlah berkas yang benar-benar diperiksa (`ok` + `invalid`). */
  checked: number;
  invalid: ScanResult[];
  /** Biner terdeteksi lewat byte NUL (jaring pengaman salah kelas). */
  skippedBin: number;
  /** Biner terdeteksi lewat ekstensi (PNG/dkk). */
  skippedExt: number;
  missing: number;
}

/** Kelasifikasi path: biner yang diketahui, atau kandidat berkas teks. */
export declare function classify(filePath: string): 'text' | 'binary-ext';

/** Offset (0-based) byte UTF-8 invalid pertama; -1 bila tidak ditemukan. */
export declare function firstInvalidOffset(buf: Buffer): number;

/** Periksa satu berkas di disk. */
export declare function scanFile(filePath: string): ScanResult;

/** Daftar semua berkas ter-track dari git (tanpa shell). */
export declare function listTrackedFiles(): string[];

/** Periksa banyak path sekaligus. */
export declare function scanAll(files: string[]): ScanSummary;
