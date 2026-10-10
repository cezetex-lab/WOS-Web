/**
 * text-encoding-guard.test.ts — guard UTF-8 (P2-F14-AJ)
 *
 * Guard `scripts/verify-text-encoding.mjs` ada karena 3 insiden SERUPA yang sudah
 * terbukti (bukan tebakan):
 *   - agentsLogs_2026-09.md:1201  `.gitignore`       byte 0x97 → U+FFFD
 *   - agentsLogs_2026-09.md:3232  `.env.example`     byte 0x97 → U+FFFD
 *   - 2026-10-10 (L7 P2-F14-AH)   DISASTER_RECOVERY.md 0x97   → U+FFFD
 * Akarnya sama: editor lossy membaca berkas sebagai UTF-8 LALU MENULIS ULANG
 * seluruh isinya, sehingga byte CP1252 `0x97` (em-dash) diam-diam jadi `EF BF BD`.
 *
 * Test di sini memakai FIXTURE TEMP, bukan berkas repo — supaya tidak basi setelah
 * B2/B3 menormalisasi `DISASTER_RECOVERY.md` dan `.env.example`. (Kalau test
 * meng-assert kondisi repo saat ini, ia akan merah sendiri setelah file diperbaiki:
 * itu test yang salah, bukan guard yang rusak.)
 */
import { describe, expect, it } from 'vitest';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
// Deklarasi tipe ada di scripts/verify-text-encoding.d.mts (pola migration-checksum.d.mts).
import { classify, firstInvalidOffset, scanAll, scanFile } from '../../scripts/verify-text-encoding.mjs';

const ROOT = path.resolve(import.meta.dirname, '..', '..');
const GUARD = path.join(ROOT, 'scripts', 'verify-text-encoding.mjs');

/** Folder temp per-test; dihapus lagi supaya tidak meninggalkan sampah. */
function withTmp<T>(fn: (dir: string) => T): T {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'enc-guard-'));
  try {
    return fn(dir);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

/** Jalankan CLI guard; kembalikan exit code (0 bersih, 1 non-UTF8). */
function runGuard(files: string[]): number {
  try {
    execFileSync(process.execPath, [GUARD, `--files=${files.join(',')}`], { encoding: 'utf8' });
    return 0;
  } catch (e) {
    return (e as { status?: number }).status ?? -1;
  }
}

describe('text-encoding-guard — unit', () => {
  it('(a) file UTF-8 bersih (termasuk em-dash U+2014) → ok, guard hijau', () => {
    withTmp((dir) => {
      const f = path.join(dir, 'clean.md');
      // Sengaja memuat karakter non-ASCII yang SAH: BOM-free UTF-8 multi-byte.
      fs.writeFileSync(f, 'judul — dash — ✔ §0.18 ñ é 中文\n', 'utf8');
      const r = scanFile(f);
      expect(r.status).toBe('ok');
      expect(r.offset).toBeUndefined();
      expect(scanAll([f]).invalid).toHaveLength(0);
      expect(runGuard([f])).toBe(0);
    });
  });

  it('(b) file dengan byte 0x97 (CP1252) → invalid + offset tepat, guard MERAH', () => {
    withTmp((dir) => {
      const f = path.join(dir, 'bad.md');
      // Replika persis pola nyata: "instalasi <0x97> lihat" (DISASTER_RECOVERY.md:83).
      const buf = Buffer.from('bukan jalur instalasi ', 'utf8');
      const tail = Buffer.from(' lihat supabase.', 'utf8');
      fs.writeFileSync(f, Buffer.concat([buf, Buffer.from([0x97]), tail]));

      const r = scanFile(f);
      expect(r.status).toBe('invalid');
      expect(r.offset).toBe(buf.length); // offset byte 0x97
      expect(r.byte).toBe(0x97);
      expect(firstInvalidOffset(buf)).toBe(-1); // sebelum byte rusak → bersih

      const s = scanAll([f]);
      expect(s.invalid).toHaveLength(1);
      expect(s.checked).toBe(1);
      expect(runGuard([f])).toBe(1); // MERAH — guard tidak diam
    });
  });

  it('(c) file biner (PNG) → di-skip, TIDAK MERAH', () => {
    withTmp((dir) => {
      const f = path.join(dir, 'icon.png');
      // Signature PNG + badan acak yang pasti bukan UTF-8.
      const png = Buffer.concat([
        Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
        Buffer.from(Array.from({ length: 64 }, (_, i) => (i * 37) % 256)),
      ]);
      fs.writeFileSync(f, png);

      expect(classify(f)).toBe('binary-ext');
      const r = scanFile(f);
      expect(r.status).toBe('skip-ext');
      expect(scanAll([f]).invalid).toHaveLength(0);
      expect(runGuard([f])).toBe(0); // biner tidak memblokir
    });
  });

  it('jaring pengaman: file tanpa ekstensi tapi memuat NUL → skip-binary, bukan MERAH', () => {
    withTmp((dir) => {
      const f = path.join(dir, 'blob'); // tanpa ekstensi → terklasifikasi 'text'
      fs.writeFileSync(f, Buffer.from([0x41, 0x42, 0x00, 0x43]));
      expect(classify(f)).toBe('text');
      expect(scanFile(f).status).toBe('skip-binary');
      expect(scanAll([f]).invalid).toHaveLength(0);
    });
  });

  it('beberapa file rusak sekaligus → semua tercatat, exit 1', () => {
    withTmp((dir) => {
      const a = path.join(dir, 'a.md');
      const b = path.join(dir, 'b.md');
      const c = path.join(dir, 'c.txt'); // bersih
      fs.writeFileSync(a, Buffer.from([0x68, 0x69, 0x97])); // 0x97 tunggal = rusak
      // Sekeuens 3-byte yang TERPOTONG di akhir berkas (0xE2 menunggu 2 continuation).
      fs.writeFileSync(b, Buffer.from([0x68, 0x69, 0xe2, 0x82]));
      fs.writeFileSync(c, 'bersih — ✓\n', 'utf8');

      const s = scanAll([a, b, c]);
      expect(s.checked).toBe(3);
      expect(s.invalid.map((r) => path.basename(r.file))).toEqual(['a.md', 'b.md']);
      expect(runGuard([a, b, c])).toBe(1);
    });
  });

  it('TRAP false-positive: E2 82 97 adalah UTF-8 VALID (U+2097) — tidak boleh dinyatakan rusak', () => {
    // Guard yang memindai "apakah ada byte 0x97?" akan SALAH pada sekuens sah ini.
    // Karena itu guard harus DECODE, bukan scan byte. Test ini mengunci perilaku itu.
    withTmp((dir) => {
      const f = path.join(dir, 'trap.md');
      fs.writeFileSync(f, Buffer.from([0xe2, 0x82, 0x97]));
      expect(Buffer.from([0xe2, 0x82, 0x97]).toString('utf8')).toBe('\u2097');
      expect(scanFile(f).status).toBe('ok');
      expect(runGuard([f])).toBe(0);
    });
  });
});

describe('text-encoding-guard — source guard', () => {
  it('tanpa shell, tanpa branch platform, tanpa Function/eval/createRequire', () => {
    const raw = fs.readFileSync(GUARD, 'utf8');
    // Komentar header MEMANG menjelaskan 0x97/U+FFFD — assertion hanya pada KODE.
    const code = raw.replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '');

    expect(code).toMatch(/execFileSync\('git', \['ls-files'\]/);
    expect(code).not.toMatch(/process\.platform/);
    expect(code).not.toMatch(/\bshell\s*:/);
    expect(code).not.toMatch(/\bFunction\s*\(/);
    expect(code).not.toMatch(/\beval\s*\(/);
    expect(code).not.toMatch(/createRequire/);

    // Wajib memakai decoder fatal — inilah yang membuat guard bisa MERAH.
    expect(raw).toMatch(/TextDecoder\('utf-8',\s*\{\s*fatal:\s*true\s*\}\)/);
    // Anti hijau-palsu: korpus kosong harus FATAL, bukan exit 0.
    expect(raw).toMatch(/korpus kosong/);
    expect(raw).toMatch(/process\.exit\(2\)/);
  });

  it('wired ke package.json sebagai verify:encoding', () => {
    const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, 'package.json'), 'utf8'));
    expect(pkg.scripts['verify:encoding']).toBe('node scripts/verify-text-encoding.mjs');
  });

  it('wired ke CI setelah step Verify numeric claims', () => {
    const yml = fs.readFileSync(path.join(ROOT, '.github', 'workflows', 'ci.yml'), 'utf8');
    expect(yml).toMatch(/- name: Verify text encoding/);
    expect(yml).toMatch(/run: npm run verify:encoding/);
    const iNum = yml.indexOf('Verify numeric claims');
    const iEnc = yml.indexOf('Verify text encoding');
    const iTest = yml.indexOf('- name: Unit test');
    expect(iNum).toBeGreaterThan(-1);
    expect(iEnc).toBeGreaterThan(iNum); // setelah verify:numeric
    expect(iTest).toBeGreaterThan(iEnc); // sebelum Unit test
  });
});
