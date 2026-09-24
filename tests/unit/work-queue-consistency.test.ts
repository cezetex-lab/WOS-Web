// @vitest-environment node
/**
 * Guard — KONSISTENSI Work Queue §5.8 (AGENTS.md ↔ agentsLogs).
 *
 * Latar: 2026-09-19, forensik SQL-04/05/07/09 membeberkan "documentation drift" parcial:
 * sesi paralel pernah mengerjakan commit `ffeca8a` (4 file migrasi) + mencatat entry log
 * `## ... SQL-04/05/07/09 Migration Applied & Verified — DONE`, tapi **tidak pernah
 * menghapus item itu dari AGENTS.md §5.8** sebelum session TERMINATED. Entry log yang
 * mengklaim commit `63dd92a` ternyata KONTRAFAKSI (`git log --all` tidak memilikinya).
 *
 * Guard ini bersifat STATIS (tanpa DB) — ia memastikan tiga sumber kebenaran berada
 * konsisten, sehingga tidak bisa "mengklaim DONE" tanpa menyelaraskan status dokumen.
 * Aturan (lihat AGENTS.md §0.4):
 *   R1 — setiap item ✅ SELESAI di §5.8 WAJIB ada entry completion di agentsLogs.
 *   R2 — setiap item OPEN di §5.8 TIDAK BOLEH ada entry log yang klaim SELESAI/DONE.
 *   R3 — file migrasi no-op (hanya komentar) harus terdaftar di NO_OP_MIGRATION_EXEMPT.
 *  Catatan: R1/R2 tidak memverifikasi DB live — itu dilakukan probe terpisah.
 */

import { describe, expect, it } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(import.meta.dirname, '..', '..');
const AGENTS = path.join(ROOT, 'AGENTS.md');
const MIGRATIONS_DIR = path.join(ROOT, 'supabase/migrations');

// File migrasi yang diketahui hanya berisi komentar (no-op statis).
// Harus di-UPDATE bila ada file no-op baru. SQL-09 (file 239) adalah satu-satunya contoh;
// ia di-apply ke live (terdaftar di schema_migrations) tapi tidak melakukan perubahan.
// CATATAN 2026-09-20: 239 kini BUKAN no-op lagi (berisi assertion `DO $$` non-destruktif),
// jadi daftar ini boleh kosong. Enumerasi 239 di sini tidak lagi menyala — dipertahankan
// hanya supaya berkas ini tetap sah bila suatu saat ada migrasi komentar-saja lagi.
const NO_OP_MIGRATION_EXEMPT: ReadonlySet<string> = new Set([
  '239_sql09_fix_duplicate_create.sql', // SQL-09 (2026-09-20) ditutup via Opsi A: fix di berkas 141 + assertion di 239
]);

type WqItem = { id: string; prio: string; status: string; raw: string };

/** Parse tabel §5.8 Work Queue dari AGENTS.md. */
export function parseWorkQueue(agentsPath: string): WqItem[] {
  const text = fs.readFileSync(agentsPath, 'utf8');
  const lines = text.split(/\r?\n/);
    let tableStart = -1;
  for (let i = 0; i < lines.length; i++) {
    if (/ID/.test(lines[i]) && /Prio/.test(lines[i]) && /Status/.test(lines[i])) {
      tableStart = i;
      break;
    }
  }
  expect(tableStart, 'AGENTS.md: header tabel Work Queue §5.8 tidak ditemukan').toBeGreaterThanOrEqual(0);
  const items: WqItem[] = [];
  for (let i = tableStart + 2; i < lines.length; i++) {
    const line = lines[i];
    if (!line.trim()) break;
    if (!/^\|/.test(line)) break;
    const cells = line.split('|');
    const id = cells[1]?.trim() ?? '';
    const status = cells[cells.length - 2]?.trim() ?? '';
    if (!/^(SQL-|OPS-)/.test(id)) continue;
    items.push({ id, prio: cells[2]?.trim() ?? '', status, raw: line });
  }
  if (items.length === 0) {
    // Queue kosong SAH kalau semua item sudah dipangkas — tapi BUKAN kalau queue
    // sengaja dikosongkan tanpa jejak. Karena itu blok "Dipangkas <tanggal>" wajib
    // ada dan memuat ≥1 ID, sehingga R1/R2 tetap punya sumber kebenaran.
    const dipangkas = lines.filter((l) => /Dipangkas\s+\d{4}-\d{2}-\d{2}/iu.test(l));
    expect(
      dipangkas.length,
      'Work Queue §5.8 kosong tanpa blok "Dipangkas <tanggal>" di AGENTS.md — ' +
        'queue kosong hanya sah bila ada jejak item yang sudah selesai.',
    ).toBeGreaterThan(0);
    const ids = new Set<string>();
    for (const l of dipangkas) {
      for (const m of l.matchAll(/\*\*((?:SQL|OPS)-[0-9a-z]+)\*\*/giu)) ids.add(m[1]);
    }
    expect(
      [...ids],
      'Blok "Dipangkas" ada tapi tidak memuat ID item (SQL-*/OPS-*) — queue kosong tanpa bukti.',
    ).not.toHaveLength(0);
  }
  return items;
}

type LogEntry = { title: string; body: string };

/** Ekstrak entry log (heading `## [YYYY-MM-DD] ...`) + isi bloknya. */
export function parseLogEntries(root: string): LogEntry[] {
  const files = fs.readdirSync(root).filter((f) => /^agentsLogs_\d{4}-\d{2}\.md$/.test(f));
  const entries: LogEntry[] = [];
  for (const f of files) {
    const text = fs.readFileSync(path.join(root, f), 'utf8');
    const lines = text.split(/\r?\n/);
    for (let i = 0; i < lines.length; i++) {
      const m = /^##\s*\[([\d-]+)\]\s*(.*)$/.exec(lines[i]);
      if (!m) continue;
      const title = `${m[1]}: ${m[2].trim()}`;
      const body: string[] = [];
      for (let j = i + 1; j < lines.length; j++) {
        if (/^##\s*\[/.test(lines[j])) break;
        body.push(lines[j]);
      }
      entries.push({ title, body: body.join('\n') });
    }
  }
  return entries;
}

const DONE_RE = /\bDONE\b/iu;
/**
 * `SELESAI` case-sensitive (butuh kapital) supaya kata sehari-hari "selesai" (huruf kecil)
 * di kalimat "belum selesai" tidak false-positive. Boleh juga pakai prefix ✅.
 */
const SELESAI_RE = /✅\s*SELESAI|\bSELESAI\b/u;

/**
 * Entry log "menyatakan completion" untuk sebuah ID jika:
 *   - title ATAU body mengandung DONE (case-insensitive) ATAU ✅ SELESAI / SELESAI (kapital), DAN
 *   - title ATAU body mengandung ID work-queue itu.
 * Konservatif — menghindari false positive pada entry yang hanya *membahas* sebuah item.
 */
export function logMentionsCompletion(entry: LogEntry, id: string): boolean {
  const blob = entry.title + '\n' + entry.body;
  if (!DONE_RE.test(blob) && !SELESAI_RE.test(blob)) return false;
  return blob.toLowerCase().includes(id.toLowerCase());
}

export function logHeadingClaimsCompletion(entry: LogEntry, id: string): boolean {
  if (!DONE_RE.test(entry.title) && !SELESAI_RE.test(entry.title)) return false;
  return entry.title.toLowerCase().includes(id.toLowerCase());
}

const SQL_COMMAND_RE = /\b(CREATE|ALTER|DROP|INSERT|UPDATE|DELETE|GRANT|REVOKE|SELECT|DO|BEGIN|COMMIT|PERFORM|RAISE|EXECUTE|SET)\b/iu;

/** Cek apakah file migrasi hanya berisi komentar (no SQL command). */
export function isNoOpMigration(filePath: string): boolean {
  const content = fs.readFileSync(filePath, 'utf8');
  const nonComment = content
    .split(/\r?\n/)
    .map((line) => {
      const idx = line.indexOf('--');
      return idx >= 0 ? line.slice(0, idx) : line;
    })
    .join('\n')
    .trim();
  return nonComment.length === 0 || !SQL_COMMAND_RE.test(nonComment);
}

describe('work-queue consistency guard', () => {
  it('Rule 1 — setiap item ✅ SELESAI di §5.8 punya entry completion di agentsLogs', () => {
    const items = parseWorkQueue(AGENTS);
    const completed = items.filter((it) => /✅.*SELESAI/iu.test(it.status));
    if (completed.length === 0) return;

    const entries = parseLogEntries(ROOT);
        const violations = completed
      .filter((it) => !entries.some((e) => logMentionsCompletion(e, it.id)))
      .map((it) => `${it.id} (${it.status})`);

    expect(
      violations,
      `Rule 1 GAGAL — item ber-status ✅ SELESAI tapi tidak ada entry completion di agentsLogs:\n  ` +
        violations.join('\n  '),
    ).toEqual([]);
  });

  it('Rule 2 — setiap item OPEN di §5.8 tidak boleh ada entry log yang klaim SELESAI/DONE', () => {
    const items = parseWorkQueue(AGENTS);
    const open = items.filter((it) => !/✅.*SELESAI/iu.test(it.status));

    const entries = parseLogEntries(ROOT);
        const violations = open
      .filter((it) => entries.some((e) => logHeadingClaimsCompletion(e, it.id)))
      .map((it) => `${it.id} (status: ${it.status})`);

    expect(
      violations,
      `Rule 2 GAGAL — item statusnya masih OPEN tapi ada entry log yang mengklaim SELESAI/DONE ` +
        `(false positive):\n  ` +
        violations.join('\n  '),
    ).toEqual([]);
  });

  it('Rule 3 — file migrasi no-op (hanya komentar) harus terdaftar di NO_OP_MIGRATION_EXEMPT', () => {
    const files = fs.readdirSync(MIGRATIONS_DIR).filter((f) => f.endsWith('.sql'));
    const noOps = files.filter((f) => isNoOpMigration(path.join(MIGRATIONS_DIR, f)));

    const unknown = noOps.filter((f) => !NO_OP_MIGRATION_EXEMPT.has(f));
    expect(
      unknown,
      `Rule 3 GAGAL — file migrasi berikut hanya berisi komentar (no-op) dan belum didokumentasikan di ` +
        `NO_OP_MIGRATION_EXEMPT:\n  ` +
        unknown.join('\n  '),
    ).toEqual([]);
  });

    it('detektor Rule 1 & 2 (guard-the-guard): membedakan completion vs diskusi', () => {
    // logMentionsCompletion (Rule 1, fleksibel: title+body):
    expect(logMentionsCompletion(
      { title: '2026-09-19: SQL-05 selesai', body: '- DONE' },
      'SQL-05',
    )).toBe(true);
    expect(logMentionsCompletion(
      { title: '2026-09-19: Audit SQL-04/05/07', body: '- SQL-04 masih dibahas, belum selesai.' },
      'SQL-04',
    )).toBe(false); // 'selesai' kecil tidak match SELESAI_RE; tidak ada DONE

    // logHeadingClaimsCompletion (Rule 2, restriktif: title-only):
    // Title harus eksplisit mengandung DONE/SELESAI + ID.
    expect(logHeadingClaimsCompletion(
      { title: '2026-09-19: SQL-05 selesai', body: '- DONE' },
      'SQL-05',
    )).toBe(false); // 'selesai' (huruf kecil) tidak match SELESAI_RE; body 'DONE' diabaikan
    expect(logHeadingClaimsCompletion(
      { title: '2026-09-18: Instalasi dari awal — DONE (SQL-01)', body: '- lihat catatan' },
      'SQL-01',
    )).toBe(true); // title punya DONE + SQL-01
    // Body bisa punya DONE/SELESAI tapi title tidak → tidak trigger Rule 2.
    expect(logHeadingClaimsCompletion(
      { title: '2026-09-19: Audit SQL-06', body: '- DONE' },
      'SQL-06',
    )).toBe(false); // title tidak punya DONE/SELESAI → tidak trigger
  });
});
