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
 *   padahal dump masih merah TANPA jalur sah (lihat `verdictAoClosed`:
 *   `_meta.connector_state === "disabled"` + frasa bukti "konektor dimatikan"
 *   di baris dokumen), Test E berteriak. Test G membuktikan state "disabled"
 *   saja — tanpa bukti di dokumen — TIDAK cukup untuk menutup item.
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

/** Kolom Bukti baris tabel Work Queue §5.8: `| ID | Prio | Masalah | Bukti | DoD | Status |`.
 *  Split '|' → [0]='' [1]=ID [2]=Prio [3]=Masalah [4]=Bukti [5]=DoD [6]=Status [7]=''.
 *  HANYA kolom Bukti yang dihitung — kolom Status sengaja TIDAK di-union: frasa
 *  bukti wajib hidup di kolom Bukti, bukan berpindah antar kolom sesuai kenyamanan. */
function kolomBukti(row: string): string {
  return row.split('|')[4] ?? '';
}

interface AoVerdict {
  allowed: boolean;
  reason: string;
}

/**
 * Aturan pasangan dump pre-flight ↔ baris Work Queue P2-F14-AO
 * (satu sumber kebenaran untuk Test E dan Test G):
 *
 *  - dump bersih (gate exit 0)      → baris WAJIB CLOSED (Work Queue basi kalau tidak);
 *  - dump merah (gate exit 1) + baris terbuka → sah, konsisten;
 *  - dump merah + baris CLOSED      → HANYA sah jika KEDUANYA terpenuhi:
 *      (1) `_meta.connector_state === "disabled"` — field eksplisit pada JSON
 *          hasil parse; string-match kata "disabled" di teks sembarang TIDAK dihitung;
 *      (2) kolom Bukti baris memuat frasa bukti "konektor dimatikan".
 *    Selain itu = MERAH ("centang hijau yang membuka pintu").
 *
 * Kolom Status TIDAK di-union: frasa bukti wajib hidup di kolom Bukti
 * (keputusan 2026-10-12 — sebelumnya guard juga membaca Status karena frasa
 * itu sempat hanya ada di sana; kini frasa sudah dipindah ke kolom Bukti).
 */
function verdictAoClosed(
  row: string,
  meta: Record<string, unknown> | undefined,
  gateStatus: number | null,
): AoVerdict {
  const closed = /✅|CLOSED/iu.test(row);

  if (gateStatus === 0) {
    return closed
      ? { allowed: true, reason: 'dump bersih + baris CLOSED' }
      : {
          allowed: false,
          reason: 'dump sudah bersih tapi P2-F14-AO masih terbuka — Work Queue basi',
        };
  }

  if (!closed) {
    return { allowed: true, reason: 'dump merah + baris terbuka — konsisten' };
  }

  if (meta?.connector_state !== 'disabled') {
    return {
      allowed: false,
      reason:
        'P2-F14-AO ditutup padahal dump pre-flight masih memuat tool mutasi dan ' +
        '_meta.connector_state bukan "disabled" — persis "centang hijau yang membuka pintu" ' +
        'yang jadi alasan item ini ada',
    };
  }

  if (!/konektor dimatikan/iu.test(kolomBukti(row))) {
    return {
      allowed: false,
      reason:
        'connector_state="disabled" tapi kolom Bukti baris P2-F14-AO tidak memuat frasa bukti ' +
        '"konektor dimatikan" — state dump saja tanpa bukti dokumen ' +
        'tidak cukup untuk menutup item',
    };
  }

  return { allowed: true, reason: 'connector_state="disabled" + frasa bukti di dokumen' };
}

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
  it('Test E — verdict dump ↔ Work Queue: CLOSED hanya sah lewat dump bersih ATAU (disabled + bukti dokumen)', () => {
    const run = runGate([DUMP]);
    const dump = JSON.parse(fs.readFileSync(DUMP, 'utf8')) as Record<string, unknown>;
    const meta = dump._meta as Record<string, unknown> | undefined;
    const agents = fs.readFileSync(AGENTS, 'utf8');
    const row = /^\| \*\*P2-F14-AO\*\*.*$/mu.exec(agents)?.[0] ?? '';

    expect(row, 'baris P2-F14-AO hilang dari tabel Work Queue §5.8 AGENTS.md').not.toBe('');

    // Gate exit 2 = usage/JSON rusak; atas file ter-track yang valid itu mustahil,
    // tapi kalau terjadi jangan biarkan verdictAoClosed memakainya sebagai "merah".
    expect(run.status, `gate atas dump ter-track tidak boleh exit 2:\n${run.out}`).not.toBe(2);

    const verdict = verdictAoClosed(row, meta, run.status);
    expect(
      verdict.allowed,
      `${verdict.reason} (gate exit=${run.status})\n${run.out}`,
    ).toBe(true);

    // Skenario regresi: dump merah + CLOSED tanpa jalur sah — dipaksa merah.
    const sintetis = verdictAoClosed(row, { ...meta, connector_state: undefined }, run.status);
    expect(
      sintetis.allowed,
      'regresi: CLOSED tanpa _meta.connector_state="disabled" harus MERAH',
    ).toBe(false);
  });

  it("Test G — connector_state \"disabled\" TANPA frasa bukti di kolom Bukti → CLOSED tetap MERAH", () => {
    // Membuktikan state di dump tidak bisa dipakai sendirian: kolom Bukti baris
    // disintetis TANPA frasa "konektor dimatikan", dengan connector_state="disabled"
    // → tetap ditolak. Kolom Status DIBIARKAN masih memuat frasa ( "(2026-10-12,
    // konektor dimatikan)" ) — jadi kalau verdictAoClosed masih membaca Status
    // (union), test ini akan gagal di kontrol: fixture justru diizinkan CLOSED.
    // Kehijauan test ini = bukti Status TIDAK di-union.
    const run = runGate([DUMP]);
    const dump = JSON.parse(fs.readFileSync(DUMP, 'utf8')) as Record<string, unknown>;
    const meta = dump._meta as Record<string, unknown> | undefined;
    expect(
      meta?.connector_state,
      'dump ter-track harus berisi _meta.connector_state="disabled" (fixture Test G)',
    ).toBe('disabled');

    const agents = fs.readFileSync(AGENTS, 'utf8');
    const realRow = /^\| \*\*P2-F14-AO\*\*.*$/mu.exec(agents)?.[0] ?? '';
    expect(realRow, 'baris P2-F14-AO hilang dari tabel Work Queue §5.8 AGENTS.md').not.toBe('');

    // Sintesis baris: hapus frasa bukti HANYA dari kolom Bukti (index 4);
    // kolom lain (termasuk Status) dibiarkan utuh.
    const cells = realRow.split('|');
    expect(cells[4], 'sanity: kolom Bukti baris AO harus memuat frasa bukti').toMatch(
      /konektor dimatikan/iu,
    );
    cells[4] = (cells[4] ?? '').replace(/konektor dimatikan/giu, 'konektor NONAKTIF');
    const rowBuktiTanpaFrasa = cells.join('|');

    expect(rowBuktiTanpaFrasa, 'sanity: fixture harus tetap CLOSED').toMatch(/✅|CLOSED/iu);
    expect(
      cells[4],
      'sanity: kolom Bukti fixture harus tanpa frasa (yang dicek hanya kolom Bukti)',
    ).not.toMatch(/konektor dimatikan/iu);
    // Status masih memuat frasa — sengaja, membuktikan Status tidak di-union.
    expect(rowBuktiTanpaFrasa, 'sanity: kolom Status fixture MASIH memuat frasa').toMatch(
      /CLOSED[^|]*konektor dimatikan/iu,
    );

    const verdict = verdictAoClosed(rowBuktiTanpaFrasa, meta, run.status);
    expect(
      verdict.allowed,
      'Test G: connector_state="disabled" saja tanpa frasa bukti di kolom Bukti HARUS tetap merah',
    ).toBe(false);
    expect(verdict.reason).toContain('konektor dimatikan');

    // Kontrol positif: baris asli (Bukti berfrasa) + state disabled → sah.
    // Tanpa ini, Test G akan lolos juga kalau verdictAoClosed salah menolak
    // baris yang benar (guard yang selalu merah = guard rusak).
    const kontrol = verdictAoClosed(realRow, meta, run.status);
    expect(
      kontrol.allowed,
      `kontrol positif Test G gagal: baris asli + state disabled seharusnya sah (${kontrol.reason})`,
    ).toBe(true);
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
