// @vitest-environment node
/**
 * Guard — checksum migrasi TIDAK boleh bergantung pada EOL checkout (SQL-10).
 *
 * Latar (AGENTS.md §5.8, item SQL-10): `.gitattributes` memakai
 * `* text=auto eol=crlf`, jadi blob repo LF tetapi working tree Windows CRLF.
 * Selama checksum dihitung dari byte mentah berkas kerja, nilai yang sama
 * berkasnya bisa menghasilkan dua angka berbeda hanya karena gaya EOL checkout —
 * cap `schema_migrations` di baseline (dihitung dari LF) lalu "tidak cocok"
 * dengan registry di mesin CRLF, dan `apply-migration.mjs` meminta `--restamp`
 * tanpa sebab nyata.
 *
 * Tes ini menjaga tiga hal:
 *  1. algoritma baru memberi nilai IDENTIK untuk berkas LF dan CRLF;
 *  2. algoritma LAMA memang berbeda (bukti masalahnya nyata, bukan teoretis);
 *  3. nilai algoritma baru sama dengan checksum yang sudah tercap di baseline —
 *     membuktikan perbaikan ini tidak membuat perlu restamp massal.
 */

import { describe, expect, it } from 'vitest';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {
  legacyRawChecksum,
  migrationChecksum,
  normalizeEolBytes,
  sha256OfNormalized,
} from '../../supabase/scripts/migration-checksum.mjs';

const ROOT = path.resolve(import.meta.dirname, '..', '..');
const MIGRATIONS_DIR = path.join(ROOT, 'supabase', 'migrations');
const BASELINE_CAP = path.join(ROOT, 'supabase', 'baseline', '010_baseline_config_data.sql');

/** Berkas migrasi terbesar — representatif dan pasti punya banyak baris. */
function biggestMigration(): string {
  const files = fs
    .readdirSync(MIGRATIONS_DIR)
    .filter((f) => f.endsWith('.sql'))
    .map((f) => ({ f, size: fs.statSync(path.join(MIGRATIONS_DIR, f)).size }))
    .sort((a, b) => b.size - a.size);
  return files[0]!.f;
}

function withTempCopies(sourcePath: string, fn: (lf: string, crlf: string) => void): void {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'wos-eol-'));
  try {
    const text = fs.readFileSync(sourcePath, 'utf8').replace(/\r\n/g, '\n');
    const lf = path.join(dir, 'lf.sql');
    const crlf = path.join(dir, 'crlf.sql');
    fs.writeFileSync(lf, text, 'utf8');
    fs.writeFileSync(crlf, text.replace(/\n/g, '\r\n'), 'utf8');
    fn(lf, crlf);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

describe('checksum migrasi bebas EOL (SQL-10)', () => {
  it('normalisasi CRLF→LF tidak menyentuh byte lain (termasuk BOM & non-ASCII)', () => {
    const asli = Buffer.from([0xef, 0xbb, 0xbf, 0x41, 0x0d, 0x0a, 0xc3, 0xa9, 0x0a]);
    const hasil = normalizeEolBytes(asli);
    expect([...hasil]).toEqual([0xef, 0xbb, 0xbf, 0x41, 0x0a, 0xc3, 0xa9, 0x0a]);
  });

  it('berkas LF dan CRLF memberi checksum IDENTIK pada algoritma baru', () => {
    const nama = biggestMigration();
    withTempCopies(path.join(MIGRATIONS_DIR, nama), (lf, crlf) => {
      expect(migrationChecksum(lf)).toBe(migrationChecksum(crlf));
    });
  });

  it('algoritma LAMA memang berbeda antar EOL (bukti masalahnya nyata)', () => {
    const nama = biggestMigration();
    withTempCopies(path.join(MIGRATIONS_DIR, nama), (lf, crlf) => {
      const lamaLf = legacyRawChecksum(fs.readFileSync(lf));
      const lamaCrlf = legacyRawChecksum(fs.readFileSync(crlf));
      expect(lamaLf).not.toBe(lamaCrlf);
    });
  });

  it('checksum baru = checksum yang sudah tercap di baseline (tidak perlu restamp massal)', () => {
    const baseline = fs.readFileSync(BASELINE_CAP, 'utf8');
    const caps = [...baseline.matchAll(/VALUES \('[^']*', '([^']+)', '([0-9a-f]{64})', 'baseline install/g)];
    expect(caps.length, 'cap baseline tidak ditemukan').toBeGreaterThan(0);

    const beda: string[] = [];
    for (const [, filename, checksum] of caps) {
      const filePath = path.join(MIGRATIONS_DIR, filename!);
      if (!fs.existsSync(filePath)) continue;
      if (migrationChecksum(filePath) !== checksum) beda.push(filename!);
    }
    expect(beda, `cap baseline tidak cocok untuk: ${beda.join(', ')}`).toEqual([]);
  });

  it('seluruh berkas migrasi: LF dan CRLF memberi checksum sama', () => {
    const files = fs
      .readdirSync(MIGRATIONS_DIR)
      .filter((f) => f.endsWith('.sql'))
      .sort();
    const tidakStabil: string[] = [];
    for (const f of files) {
      const asli = fs.readFileSync(path.join(MIGRATIONS_DIR, f));
      // PENTING: normalisasi ke LF DULU, baru bentangkan ke CRLF. Kalau langsung
      // mengganti '\n' pada berkas yang sudah CRLF, hasilnya '\r\r\n' — itu bukan
      // skenario checkout CRLF dan membuat tes gagal palsu.
      const lf = normalizeEolBytes(asli);
      const crlf = Buffer.from(lf.toString('latin1').replace(/\n/g, '\r\n'), 'latin1');
      if (sha256OfNormalized(crlf) !== sha256OfNormalized(asli)) tidakStabil.push(f);
    }
    expect(tidakStabil, `checksum tidak stabil terhadap EOL: ${tidakStabil.join(', ')}`).toEqual([]);
  });
});
