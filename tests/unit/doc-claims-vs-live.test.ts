// @vitest-environment node
/**
 * Klaim angka di dokumen vs kenyataan.
 *
 * `AGENTS.md` §7.1/§7.3/§7.4/§7.5 dan `FuturePlans.md` §1.3 memuat angka yang
 * seharusnya menggambarkan state nyata (tabel, fungsi, grant, migrasi, overload,
 * pg_cron, baris audit, jumlah berkas TS). Angka itu berulang kali basi karena
 * tidak ada yang memeriksanya — sebelum tes ini, §7.4 masih menulis 667 fungsi
 * (aktual 672), 129 grant (aktual 132), dan 169 baris audit (aktual 172).
 *
 * Tes ini membaca angkanya DARI dokumen (jadi tidak ada duplikasi angka di kode),
 * lalu membandingkannya dengan hasil query ke DB live. Kalau schema berubah
 * secara sah: perbarui dokumennya, tes akan ikut hijau.
 *
 * Angka yang hanya bertambah (mis. baris `audit_log`) diperiksa sebagai `>=`,
 * bukan sama persis.
 *
 * Butuh `DATABASE_URL` di `.env.local` (seperti E2E live-backend lain, tes
 * di-skip tanpa itu) supaya `npm test` tetap jalan tanpa kredensial.
 */

import { describe, expect, it } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';
import { Client } from 'pg';

const ROOT = path.resolve(import.meta.dirname, '..', '..');
const IGNORED_DIRS = new Set(['node_modules', '.git', 'dist', '.freebuff', '.vercel']);

function readDoc(rel: string): string {
  return fs.readFileSync(path.join(ROOT, rel), 'utf8');
}

/** Ambil angka dari grup regex; `undefined` berarti polanya tidak ketemu (klaim hilang). */
function grab(md: string, pattern: RegExp, group = 1): number | undefined {
  const match = pattern.exec(md);
  return match ? Number(match[group]) : undefined;
}

function readDatabaseUrl(): string | undefined {
  const envPath = path.join(ROOT, '.env.local');
  if (!fs.existsSync(envPath)) return undefined;
  const line = fs
    .readFileSync(envPath, 'utf8')
    .split(/\r?\n/)
    .find((l) => /^\s*DATABASE_URL\s*=/.test(l));
  if (!line) return undefined;
  const value = line.slice(line.indexOf('=') + 1).trim().replace(/^["']|["']$/g, '');
  return value.length > 0 ? value : undefined;
}

interface Claim {
  /** Nama manusia untuk pesan gagal. */
  label: string;
  doc: 'AGENTS.md' | 'FuturePlans.md';
  pattern: RegExp;
  group?: number;
  /** `gte` untuk metrik yang hanya bertambah (mis. baris audit_log). */
  mode?: 'eq' | 'gte';
  sql: string;
}

const FUNCTIONS_SQL =
  "SELECT count(*) AS n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public'";

const OVERLOADS_SQL = `SELECT count(*) AS n FROM (
    SELECT proname FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' GROUP BY proname HAVING count(*) > 1) t`;

const DB_CLAIMS: Claim[] = [
  {
    label: 'AGENTS.md §7.4 Tables',
    doc: 'AGENTS.md',
    pattern: /^\| Tables \| (\d+) \|/m,
    sql: "SELECT count(*) AS n FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE'",
  },
  {
    label: 'AGENTS.md §7.4 Functions',
    doc: 'AGENTS.md',
    pattern: /^\| Functions \| (\d+) \|/m,
    sql: FUNCTIONS_SQL,
  },
  {
    label: 'AGENTS.md §7.4 Functions — jumlah overload',
    doc: 'AGENTS.md',
    pattern: /^\| Functions \| \d+ \| (\d+) overloads/m,
    sql: OVERLOADS_SQL,
  },
  {
    label: 'AGENTS.md §7.4 Migrations tracked',
    doc: 'AGENTS.md',
    pattern: /^\| Migrations tracked \| (\d+) \|/m,
    sql: 'SELECT count(*) AS n FROM schema_migrations',
  },
  {
    label: 'AGENTS.md §7.4 anon/PUBLIC grants',
    doc: 'AGENTS.md',
    pattern: /^\| anon\/PUBLIC grants \| (\d+) \|/m,
    sql: `SELECT count(*) AS n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
          WHERE n.nspname = 'public' AND has_function_privilege('anon', p.oid, 'EXECUTE')`,
  },
  {
    label: 'AGENTS.md §7.4 SECDEF search_path violations',
    doc: 'AGENTS.md',
    pattern: /^\| SECDEF search_path \| (\d+) violations? \|/m,
    sql: `SELECT count(*) AS n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
          WHERE n.nspname = 'public' AND p.prosecdef
            AND (p.proconfig IS NULL OR NOT EXISTS (
              SELECT 1 FROM unnest(p.proconfig) AS c WHERE c LIKE 'search_path=%'))`,
  },
  {
    label: 'AGENTS.md §7.4 pg_cron jobs',
    doc: 'AGENTS.md',
    pattern: /^\| pg_cron jobs \| (\d+) \|/m,
    sql: 'SELECT count(*) AS n FROM cron.job',
  },
  {
    label: 'AGENTS.md §7.4 Audit chain rows',
    doc: 'AGENTS.md',
    pattern: /^\| Audit chain \| (\d+) rows \|/m,
    mode: 'gte',
    sql: 'SELECT count(*) AS n FROM audit_log',
  },
  {
    label: 'AGENTS.md §7.1 diagram — tables',
    doc: 'AGENTS.md',
    pattern: /DB: (\d+) tables, \d+ functions/,
    sql: "SELECT count(*) AS n FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE'",
  },
  {
    label: 'AGENTS.md §7.1 diagram — functions',
    doc: 'AGENTS.md',
    pattern: /DB: \d+ tables, (\d+) functions/,
    sql: FUNCTIONS_SQL,
  },
  {
    label: 'FuturePlans.md §1.3 Total Tables',
    doc: 'FuturePlans.md',
    pattern: /\*\*Total Tables\*\*: ~(\d+)/,
    sql: "SELECT count(*) AS n FROM information_schema.tables WHERE table_schema = 'public'",
  },
  {
    label: 'FuturePlans.md §1.3 Total Functions',
    doc: 'FuturePlans.md',
    pattern: /\*\*Total Functions\*\*: ~(\d+)/,
    sql: FUNCTIONS_SQL,
  },
  {
    label: 'FuturePlans.md §1.3 Legacy Overloads',
    doc: 'FuturePlans.md',
    pattern: /\*\*Legacy Overloads\*\*: (\d+) overloads/,
    sql: OVERLOADS_SQL,
  },
  {
    label: 'FuturePlans.md §1.3 Audit Chain rows',
    doc: 'FuturePlans.md',
    pattern: /\*\*Audit Chain\*\*: (\d+) rows/,
    mode: 'gte',
    sql: 'SELECT count(*) AS n FROM audit_log',
  },
];

const DB_URL = readDatabaseUrl();

describe.skipIf(!DB_URL)('angka dokumen vs DB live', () => {
  it('setiap klaim cocok dengan hasil query', async () => {
    const docs: Record<Claim['doc'], string> = {
      'AGENTS.md': readDoc('AGENTS.md'),
      'FuturePlans.md': readDoc('FuturePlans.md'),
    };

    const client = new Client({
      connectionString: DB_URL,
      ssl: { rejectUnauthorized: false },
    });
    await client.connect();

    const drift: string[] = [];
    try {
      for (const claim of DB_CLAIMS) {
        const claimed = grab(docs[claim.doc], claim.pattern, claim.group ?? 1);
        if (claimed === undefined) {
          drift.push(`${claim.label}: angka tidak ditemukan di ${claim.doc} — pola/regex sudah basi`);
          continue;
        }
        const { rows } = await client.query<{ n: string }>(claim.sql);
        const live = Number(rows[0].n);
        const ok = claim.mode === 'gte' ? live >= claimed : live === claimed;
        if (!ok) {
          const op = claim.mode === 'gte' ? '>=' : '=';
          drift.push(`${claim.label}: dokumen=${claimed} tapi live=${live} (harus ${op})`);
        }
      }
    } finally {
      await client.end();
    }

    expect(
      drift,
      `Angka di dokumen sudah tidak cocok dengan kenyataan. Perbarui dokumennya:\n  ${drift.join('\n  ')}`,
    ).toEqual([]);
  }, 60_000);
});

/** Hitung berkas rekursif berdasarkan ekstensi. */
function countFiles(dir: string, exts: string[]): number {
  let total = 0;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      if (IGNORED_DIRS.has(entry.name)) continue;
      total += countFiles(path.join(dir, entry.name), exts);
    } else if (exts.some((e) => entry.name.endsWith(e))) {
      total += 1;
    }
  }
  return total;
}

describe('jumlah berkas TypeScript di dokumen', () => {
  const srcTsx = countFiles(path.join(ROOT, 'src'), ['.tsx']);
  const srcTs = countFiles(path.join(ROOT, 'src'), ['.ts']);
  const testFiles = countFiles(path.join(ROOT, 'tests'), ['.ts', '.tsx']);
  const configFiles = fs.readdirSync(ROOT).filter((f) => f.endsWith('.config.ts')).length;
  const agents = readDoc('AGENTS.md');

  it('§7.3 (total/src/tests/config) cocok dengan isi repo', () => {
    const live = {
      src: srcTsx + srcTs,
      tests: testFiles,
      config: configFiles,
      total: srcTsx + srcTs + testFiles + configFiles,
    };
    const match = /\((\d+) `src` \+ (\d+) `tests` \+ (\d+) config\)/.exec(agents);
    const claimedTotal = grab(agents, /(\d+) file TS total \(/);

    const drift: string[] = [];
    if (!match || claimedTotal === undefined) {
      drift.push('pola "file TS total (...)" tidak ketemu di AGENTS.md');
    } else {
      const claimed = { src: Number(match[1]), tests: Number(match[2]), config: Number(match[3]) };
      if (claimedTotal !== live.total) drift.push(`total dokumen=${claimedTotal} live=${live.total}`);
      if (claimed.src !== live.src) drift.push(`src dokumen=${claimed.src} live=${live.src}`);
      if (claimed.tests !== live.tests) drift.push(`tests dokumen=${claimed.tests} live=${live.tests}`);
      if (claimed.config !== live.config) drift.push(`config dokumen=${claimed.config} live=${live.config}`);
    }

    expect(
      drift,
      `Baris §7.3 "file TS total" di AGENTS.md perlu diperbarui (aktual: ${live.src} src + ${live.tests} tests + ${live.config} config = ${live.total}).`,
    ).toEqual([]);
  });

  it('§7.5 (src .tsx/.ts) cocok dengan isi repo', () => {
    const match = /(\d+) \.ts\/\.tsx files \((\d+) `\.tsx` \+ (\d+) `\.ts`\)/.exec(agents);
    const drift: string[] = [];

    if (!match) {
      drift.push('pola "N .ts/.tsx files (A .tsx + B .ts)" tidak ketemu di AGENTS.md');
    } else {
      if (Number(match[1]) !== srcTsx + srcTs) drift.push(`total dokumen=${match[1]} live=${srcTsx + srcTs}`);
      if (Number(match[2]) !== srcTsx) drift.push(`.tsx dokumen=${match[2]} live=${srcTsx}`);
      if (Number(match[3]) !== srcTs) drift.push(`.ts dokumen=${match[3]} live=${srcTs}`);
    }

    expect(
      drift,
      `Baris §7.5 TypeScript di AGENTS.md perlu diperbarui (aktual: src ${srcTsx + srcTs} = ${srcTsx} .tsx + ${srcTs} .ts).`,
    ).toEqual([]);
  });
});
