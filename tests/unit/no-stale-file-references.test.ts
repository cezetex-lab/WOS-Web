// @vitest-environment node
/**
 * Guard — komentar tidak boleh menyebut berkas yang sudah tidak ada.
 *
 * Latar: migrasi TypeScript (§7.3, aturan keras 11) mengganti nama seluruh
 * berkas menjadi TypeScript, tapi ratusan komentar header masih menyebut nama
 * lama. Drift seperti ini tidak pernah ketahuan lewat tsc/lint/build karena
 * komentar tidak diproses tool apa pun. Commit `e20c420` membersihkan 89 berkas
 * secara manual; test ini memastikan tidak terulang.
 *
 * Dua aturan, hanya pada baris komentar (baris kode tidak diperiksa, karena
 * `import('...')` di test memang memakai gaya resolusi ekstensi lama):
 *
 *   R1 (drift ekstensi) — komentar menyebut berkas dengan ekstensi lama,
 *      sementara versi TypeScript dari berkas itu ada di repo.
 *   R2 (hilang) — komentar menyebut nama berkas yang tidak ada di repo sama
 *      sekali, dan bukan nama pustaka pihak ketiga.
 */

import { describe, expect, it } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(import.meta.dirname, '..', '..');
const SCAN_DIRS = ['src', 'tests'];
const SCANNED_EXT = new Set(['.ts', '.tsx']);

const IGNORED_DIRS = new Set([
  'node_modules', '.git', 'dist', 'coverage',
  'playwright-report', 'test-results', '.freebuff', '.vercel',
]);

/** Baris komentar: `// …`, `/* …`, atau lanjutan JSDoc `* …`. */
const COMMENT_LINE = /^\s*(\/\/|\/\*|\*)/;

/**
 * Token nama berkas utuh (boleh mengandung titik, mis. berkas spec E2E),
 * tanpa jalur folder.
 * Alternatif ekstensi diurutkan terpanjang dulu supaya `js` tidak menang
 * atas `jsx`.
 */
const FILE_REF = /[A-Za-z0-9_-][A-Za-z0-9_.-]*\.(jsx|tsx|js|ts)\b/g;

/** Nama yang memang tidak merujuk berkas proyek (pustaka pihak ketiga). */
const ALLOWED_REFERENCES = new Set([
  'Chart.js',
]);

export interface RepoIndex {
  /** stem -> ekstensi TypeScript-nya, mis. `supabase-browser` -> `ts`. */
  typedStems: Map<string, string>;
  /** Semua nama berkas yang benar-benar ada di repo. */
  basenames: Set<string>;
}

export interface Violation {
  line: number;
  hit: string;
}

function walk(dir: string, out: string[] = []): string[] {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      if (IGNORED_DIRS.has(entry.name)) continue;
      walk(path.join(dir, entry.name), out);
    } else {
      out.push(path.join(dir, entry.name));
    }
  }
  return out;
}

/** Deteksi referensi berkas usang di satu baris komentar. */
export function detectStaleRefs(commentLine: string, index: RepoIndex): string[] {
  const text = commentLine.replace(/https?:\/\/\S+/g, ' ');
  const found: string[] = [];

  for (const ref of text.match(FILE_REF) ?? []) {
    if (ALLOWED_REFERENCES.has(ref)) continue;

    const dot = ref.lastIndexOf('.');
    const stem = ref.slice(0, dot);
    const ext = ref.slice(dot + 1);

    if (ext === 'ts' || ext === 'tsx') {
      if (!index.basenames.has(ref)) found.push(`${ref} (tidak ada di repo)`);
      continue;
    }

    const typed = index.typedStems.get(stem);
    if (typed) found.push(`${ref} → sekarang ${stem}.${typed}`);
    else if (!index.basenames.has(ref)) found.push(`${ref} (tidak ada di repo)`);
  }

  return found;
}

/** Jalankan detektor hanya pada baris komentar; baris kode dilewati. */
export function scanText(text: string, index: RepoIndex): Violation[] {
  const out: Violation[] = [];
  text.split(/\r?\n/).forEach((line, i) => {
    if (!COMMENT_LINE.test(line)) return;
    for (const hit of detectStaleRefs(line, index)) out.push({ line: i + 1, hit });
  });
  return out;
}

function buildIndex(files: string[]): RepoIndex {
  const typedStems = new Map<string, string>();
  const basenames = new Set<string>();

  for (const file of files) {
    const base = path.basename(file);
    basenames.add(base);
    const match = /^(.+)\.(tsx?)$/.exec(base);
    if (match) typedStems.set(match[1], match[2]);
  }

  return { typedStems, basenames };
}

describe('komentar tidak menyebut berkas usang', () => {
  it('tidak ada referensi berkas yang sudah tidak ada di src/ dan tests/', () => {
    const allFiles = walk(ROOT);
    const index = buildIndex(allFiles);

    const targets = allFiles.filter((file) => {
      const inScope = SCAN_DIRS.some((dir) => file.startsWith(path.join(ROOT, dir) + path.sep));
      return inScope && SCANNED_EXT.has(path.extname(file));
    });

    const violations: string[] = [];
    for (const file of targets) {
      for (const { line, hit } of scanText(fs.readFileSync(file, 'utf8'), index)) {
        violations.push(`${path.relative(ROOT, file).replace(/\\/g, '/')}:${line} → ${hit}`);
      }
    }

    expect(
      violations,
      `Komentar menyebut berkas yang tidak ada (perbaiki nama/ekstensinya):\n  ${violations.join('\n  ')}`,
    ).toEqual([]);
  });

  it('detektornya sendiri benar-benar menangkap drift (guard the guard)', () => {
    const index: RepoIndex = {
      typedStems: new Map([
        ['LegacyWidget', 'tsx'],
        ['widget.spec', 'ts'],
      ]),
      basenames: new Set(['LegacyWidget.tsx', 'widget.spec.ts', 'Chart.js']),
    };

    // R1: ekstensi lama, versi TypeScript-nya ada.
    expect(detectStaleRefs('// LegacyWidget.jsx — halaman contoh', index))
      .toEqual(['LegacyWidget.jsx → sekarang LegacyWidget.tsx']);

    // Nama bertitik tidak boleh terpotong oleh alternatif ekstensi.
    expect(detectStaleRefs(' * widget.spec.js — alur MFA', index))
      .toEqual(['widget.spec.js → sekarang widget.spec.ts']);

    // Nama benar dan pustaka pihak ketiga: bersih.
    expect(detectStaleRefs(' * widget.spec.ts — alur MFA', index)).toEqual([]);
    expect(detectStaleRefs('// pakai Chart.js untuk grafik', index)).toEqual([]);

    // R2: benar-benar tidak ada di repo.
    expect(detectStaleRefs('// Ghost.tsx tidak ada di repo', index))
      .toEqual(['Ghost.tsx (tidak ada di repo)']);

    // Filter komentar ada di scanText, bukan di detektor: baris kode dilewati.
    const mixed = [
      '// LegacyWidget.jsx — usang',
      "const m = await import('./legacy.js');",
      'export default function LegacyWidget() {}',
    ].join('\n');
    expect(scanText(mixed, index))
      .toEqual([{ line: 1, hit: 'LegacyWidget.jsx → sekarang LegacyWidget.tsx' }]);
  });
});
