// @vitest-environment node
/**
 * Guard — ENFORCEMENT MEKANIS §0.28.8 (P2-F14-AO jalur b).
 *
 * Latar: gate `scripts/mcp-readonly-gate.mjs` tadinya hanya menahan agent yang
 * disiplin — ia ada di dokumen, tapi tidak ada satu pun gerbang yang memaksa
 * sesi benar-benar menjalankan pre-flight, dan tidak ada yang marah kalau
 * dump-nya hilang. Sebuah aturan tanpa gerbang = kelas bug "guard diam"
 * (§0.19/§0.24) yang sudah berulang di repo ini.
 *
 * Setelah diverifikasi 2026-10-12, mode read-only konektor TIDAK tersedia di
 * Freebuff (tidak ada setelan/tool-filter klien; `project.json`, `state.json`
 * dan `desktop-v2.db` tidak memuat kunci MCP apa pun). Karena itu gate inilah
 * SATU-SATUNYA pertahanan, dan ia wajib punya gigi mekanis.
 *
 * Dimensi §0.24 yang dipakai di sini:
 *   FRESHNESS    — SENGAJA TIDAK DI-ASSERT. Alasannya: git tidak mempertahankan
 *                  mtime, jadi satu-satunya sumber waktu yang tersedia adalah
 *                  `_meta.captured_at` yang DILAPORKAN SENDIRI oleh penulis
 *                  dump. Gate kesegaran yang bertumpu pada nilai swa-klaim
 *                  tidak bisa gagal = guard palsu. Lebih baik tidak ada
 *                  daripada guard yang mengklaim sesuatu yang tak terbukti.
 *   COMPLETENESS — di-assert: setiap konektor yang dinyatakan di
 *                  `_meta.connectors` wajib punya ≥1 tool di dump.
 *   SCHEMA       — di-assert: `_meta` wajib memuat field wajib, dan setiap
 *                  entri wajib punya nama + flag readOnly/destructive yang
 *                  bertipe boolean.
 *
 * BATAS KEJUJURAN (§0.16) — baca ini sebelum mengandalkan hijau-nya test ini:
 *   Test ini MENGUJI bahwa ritual pre-flight dijalankan dan buktinya ter-track.
 *   Test ini TIDAK menguji bahwa konektor bersih. Dump saat ini memuat 11 tool
 *   mutasi Supabase dan gate-nya MERAH — itu FAKTA, dibuktikan Test E di bawah,
 *   dan dijadikan merah-alami bukan kegagalan test melainkan kondisi yang harus
 *   tetap terbuka di Work Queue (P2-F14-AO). Kalau ada yang menutup P2-F14-AO
 *   padahal dump masih merah, Test E berteriak.
 */

import { describe, expect, it } from 'vitest';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const ROOT = path.resolve(import.meta.dirname, '..', '..');
const GATE = path.join(ROOT, 'scripts', 'mcp-readonly-gate.mjs');
const DUMP = path.join(ROOT, 'docs', 'forensic', 'mcp-preflight', 'latest.json');
const AGENTS = path.join(ROOT, 'AGENTS.md');

interface GateRun {
  status: number | null;
  out: string;
}

function runGate(args: string[] = []): GateRun {
  const r = spawnSync(process.execPath, [GATE, ...args], { encoding: 'utf8' });
  return { status: r.status, out: `${r.stdout ?? ''}${r.stderr ?? ''}` };
}

/** Tulis dump sementara lalu jalankan gate — fixture hidup di memori/disk sementara,
 *  BUKAN di `.agents/` (gitignored, jadi tak bisa dipakai CI). */
function runGateOnDump(obj: unknown): GateRun {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'mcp-gate-'));
  const file = path.join(dir, 'dump.json');
  fs.writeFileSync(file, JSON.stringify(obj), 'utf8');
  try {
    return runGate([file]);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

/** Bentuk asli `search_mcp_tools`: [{ server, tool, readOnly, destructive }]. */
const RO = (server: string, tool: string) => ({ server, tool, readOnly: true, destructive: false });
const MUT = (server: string, tool: string) => ({ server, tool, readOnly: false, destructive: true });

describe('§0.28.8 enforcement — dump pre-flight wajib ada', () => {
  it('Test A — dump pre-flight ter-track ada; tanpa itu pre-flight bisa dilewatkan diam-diam', () => {
    expect(
      fs.existsSync(DUMP),
      `Dump pre-flight MCP tidak ada: ${path.relative(ROOT, DUMP)}\n` +
        `Pre-flight §0.28.8 belum pernah dijalankan/di-commit, jadi tidak ada bukti\n` +
        `konektor pernah diperiksa. Jalankan langkah 1-3 §0.28.8 lalu commit dump-nya.`,
    ).toBe(true);
  });

  it('Test B — SCHEMA: _meta wajib lengkap dan setiap entri wajib punya nama + flag boolean', () => {
    const dump = JSON.parse(fs.readFileSync(DUMP, 'utf8')) as Record<string, unknown>;
    const meta = dump._meta as Record<string, unknown> | undefined;

    for (const key of ['schema', 'captured_at', 'source', 'scope', 'connectors', 'method']) {
      expect(meta?.[key], `_meta.${key} hilang di ${path.relative(ROOT, DUMP)}`).toBeDefined();
    }
    expect(Array.isArray(meta?.connectors), '_meta.connectors harus array').toBe(true);

    const tools = Object.values(dump).flatMap((v) => {
      const bucket = v as { tools?: unknown[] } | undefined;
      return Array.isArray(bucket?.tools) ? bucket.tools : [];
    });

    expect(tools.length, 'dump tidak memuat satu pun tool').toBeGreaterThan(0);

    const bad = tools.filter((t) => {
      const e = t as Record<string, unknown>;
      const name = e.name ?? e.tool ?? e.toolName ?? e.id;
      const named = typeof name === 'string' && name.trim().length > 0;
      const flag =
        typeof e.readOnly === 'boolean' ||
        typeof e.readOnlyHint === 'boolean' ||
        typeof e.destructive === 'boolean' ||
        typeof e.destructiveHint === 'boolean';
      return !named || !flag;
    });
    expect(
      bad,
      'entri dump tanpa nama atau tanpa flag readOnly/destructive — bentuk ini membuat gate gagal membaca',
    ).toEqual([]);
  });

  it('Test C — COMPLETENESS: setiap konektor yang dinyatakan wajib benar-benar muncul', () => {
    const dump = JSON.parse(fs.readFileSync(DUMP, 'utf8')) as Record<string, unknown>;
    const declared = (dump._meta as { connectors: string[] }).connectors;
    const empty = declared.filter((c) => {
      const bucket = dump[c] as { tools?: unknown[] } | undefined;
      return !Array.isArray(bucket?.tools) || bucket.tools.length === 0;
    });
    expect(
      empty,
      'konektor dinyatakan di _meta.connectors tapi tidak ada isinya — dump palsu lengkap',
    ).toEqual([]);
  });
});

describe('§0.28.8 enforcement — kontrak gate', () => {
  it('Test D — exit code: 2 tanpa argumen, 0 bersih, 1 mutasi, 1 kosong, 1 entri tak terbaca', () => {
    expect(runGate([]).status, 'tanpa argumen harus exit 2 (usage)').toBe(2);
    expect(runGate([path.join(ROOT, 'tidak-ada.json')]).status, 'file hilang harus exit 2').toBe(2);

    expect(runGateOnDump([RO('supabase', 'list_projects'), RO('linear', 'list_issues')]).status).toBe(0);
    expect(runGateOnDump([MUT('supabase', 'execute_sql')]).status).toBe(1);
    expect(runGateOnDump({ tools: [] }).status, 'dump kosong harus fail-closed exit 1').toBe(1);
    expect(
      runGateOnDump([{ server: 'supabase', tool: 'some_future_tool', readOnly: false }]).status,
      'nama baru tak dikenal harus tetap tertangkap jalur flag',
    ).toBe(1);
  });

  it('Test D2 — bentuk asli search_mcp_tools terbaca: bersih -> 0, mutasi -> 1', () => {
    // Regresi nyata: gate sempat mencari `tool.name`, padahal keluaran asli
    // memakai `{ server, tool }` — semua entri jatuh ke <tanpa-nama> dan gate
    // berbunyi MERAH pada dump yang sebetulnya bersih (false alarm).
    const clean = runGateOnDump([
      RO('supabase', 'list_projects'),
      RO('supabase', 'list_tables'),
      RO('sentry', 'find_projects'),
      RO('linear', 'list_projects'),
    ]);
    expect(clean.status, `dump bersih salah dituduh mutasi:\n${clean.out}`).toBe(0);
    expect(clean.out).toContain('0 mutasi');

    const dirty = runGateOnDump([
      RO('supabase', 'list_projects'),
      MUT('supabase', 'execute_sql'),
      MUT('supabase', 'apply_migration'),
    ]);
    expect(dirty.status).toBe(1);
    expect(dirty.out).toContain('execute_sql');
    expect(dirty.out).toContain('apply_migration');
  });
});

describe('§0.28.8 enforcement — dokumen ↔ realita', () => {
  it('Test E — verdict dump merah WAJIB berpasangan dengan Work Queue yang masih terbuka', () => {
    const run = runGate([DUMP]);
    const agents = fs.readFileSync(AGENTS, 'utf8');
    const row = /^\| \*\*P2-F14-AO\*\*.*$/mu.exec(agents)?.[0] ?? '';

    expect(row, 'baris P2-F14-AO hilang dari tabel Work Queue §5.8 AGENTS.md').not.toBe('');

    if (run.status === 0) {
      // Dump bersih: exposure sudah tertutup. Baris harus sudah ditutup juga.
      expect(row, 'dump sudah bersih tapi P2-F14-AO masih terbuka — Work Queue basi').toMatch(
        /✅|CLOSED/iu,
      );
      return;
    }

    // Dump merah: exposure masih nyata. Barisnya HARUS terbuka, jangan ditutup
    // sebelum bukti ulang membuktikan konektor bersih.
    expect(run.status, `gate atas dump ter-track harus exit 1:\n${run.out}`).toBe(1);
    expect(
      row,
      'P2-F14-AO ditutup padahal dump pre-flight masih memuat tool mutasi — ' +
        'persis "centang hijau yang membuka pintu" yang jadi alasan item ini ada',
    ).not.toMatch(/✅|CLOSED/iu);
  });

  it('Test F — §0.28.8 tetap ada dan tetap menunjuk gate + dump ter-track', () => {
    const agents = fs.readFileSync(AGENTS, 'utf8');
    const section = /### §0\.28\.8[\s\S]*?(?=\r?\n#{2,3} )/.exec(agents)?.[0] ?? '';
    expect(section, 'bagian §0.28.8 tidak ditemukan di AGENTS.md').not.toBe('');
    expect(section, '§0.28.8 tidak lagi menunjuk skrip gate').toContain('scripts/mcp-readonly-gate.mjs');
    expect(section, '§0.28.8 tidak lagi menunjuk dump ter-track').toContain(
      'docs/forensic/mcp-preflight/latest.json',
    );
  });
});
