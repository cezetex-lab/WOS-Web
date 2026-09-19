#!/usr/bin/env node
/**
 * scripts/split-agents-logs.ts — pecah `agentsLogs.md` menjadi berkas per bulan.
 *
 * Kenapa ada: `agentsLogs.md` sudah >140 KB, dan agent diminta MEMBACA log untuk konteks —
 * berkas sebesar itu boros token setiap kali dibuka. Setelah dipisah:
 *   - `agentsLogs_YYYY-MM.md`  memuat entri satu bulan (ber-track, ini yang dibaca/di-append)
 *   - `agentsLogs.md`          hanya penunjuk kecil berisi indeks bulan (ber-track)
 *
 * ATURAN PENTING (dan kenapa skrip ini menolak jalan dua kali):
 * berkas ber-git-track TIDAK BOLEH pindah ke `.agents/` — folder itu gitignored, jadi
 * memindahkannya sama dengan menghapusnya dari version control. Arsip lokal (`--snapshot`)
 * hanya SALINAN CADANGAN, bukan pengganti berkas ber-track.
 *
 * Jaminan tanpa kehilangan: setiap baris berkas asli (sebelum dipisah) harus muncul di
 * salah satu berkas bulan. Kalau tidak, skrip GAGAL dan tidak menulis apa pun.
 *
 * Pemakaian:
 *   node scripts/split-agents-logs.ts --dry-run                  # periksa, tidak menulis
 *   node scripts/split-agents-logs.ts                            # tulis berkas bulan + penunjuk
 *   node scripts/split-agents-logs.ts --snapshot                 # + salinan arsip lokal
 *   node scripts/split-agents-logs.ts --snapshot --dry-run       # periksa termasuk jalur arsip
 *   node scripts/split-agents-logs.ts --index-only               # tulis ulang penunjuk saja
 *
 * Exit code: 0 sukses; 1 tidak ada yang perlu dipisah / argumen salah; 2 gagal verifikasi.
 */
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { writeFileSafe } from './safe-file-writer.ts';

const ROOT = process.cwd();
const LOG = path.join(ROOT, 'agentsLogs.md');
const SNAPSHOT = path.join(ROOT, '.agents/archive/logs/agentsLogs_archive.md');

const argv = process.argv.slice(2);
const DRY = argv.includes('--dry-run');
const WANT_SNAPSHOT = argv.includes('--snapshot');
const BOM = '\uFEFF';

/** `## [2026-09-18] Judul entri` — hanya bentuk ini yang dianggap awal entri. */
const ENTRY_HEADING = /^## \[(\d{4})-(\d{2})/;

interface MonthFile {
  key: string; // 2026-09
  file: string; // agentsLogs_2026-09.md
  entries: number;
  lines: string[];
}

function monthFileName(key: string): string {
  return `agentsLogs_${key}.md`;
}

function buildPointer(months: MonthFile[]): string {
  const rows = months
    .map((m) => `| ${m.key} | \`${m.file}\` | ${m.entries} |`)
    .join('\n');
  // JANGAN menaruh BOM di sini: `writeFileSafe` mempertahankan BOM berkas tujuan sendiri,
  // jadi BOM di konten menghasilkan BOM BERLIPAT dan verifikasinya menolak menulis.
  return [
    '# agentsLogs.md — INDEKS LOG (LOG DIPISAH PER BULAN)',
    '',
    '> **Log dipisah per bulan.** Berkas ini hanya **penunjuk**. Entri pekerjaan yang sudah',
    '> selesai ada di `agentsLogs_YYYY-MM.md` untuk bulan berjalan.',
    '>',
    '> Header asli dipindahkan apa adanya ke tiap berkas bulan — tidak ada baris yang hilang.',
    '',
    '| Bulan | Berkas | Entri |',
    '|---|---|---|',
    rows,
    '',
    '## Cara mencatat pekerjaan baru',
    '',
    '1. Tulis ke berkas bulan berjalan (`agentsLogs_<YYYY-MM>.md`). Kalau belum ada, buat dengan',
    '   menyalin header dari bulan sebelumnya, lalu tambahkan barisnya ke tabel indeks di atas.',
    '2. **Jangan tulis lewat shell** (`echo >`, `cat <<EOF`, `Add-Content`) — itu pernah merusak',
    '   berkas ini (864 NULL byte). Pakai:',
    '   `node scripts/safe-file-writer.ts --file agentsLogs_<YYYY-MM>.md --content-file <sumber> --mode append`',
    '3. Entri selesai **dikeluarkan** dari `AGENTS.md` (§0.4) — log adalah satu-satunya tempat riwayat.',
    '',
    '> Riwayat lama tidak dihapus dan tidak masuk `.agents/` (folder itu gitignored). Kalau ada',
    '> bulan-bulan lama, berkasnya tetap ber-track di root supaya ikut ter-commit.',
    '',
  ].join('\n');
}

/**
 * `--index-only` — hanya tulis ulang penunjuk `agentsLogs.md` dari berkas bulan yang ada.
 * Dipakai kalau indeks melenceng (mis. bulan baru dibuat manual, atau penunjuk perlu diperbaiki)
 * tanpa mengulang pemisahan berkas — jalur utama menolak jalan dua kali.
 */
function indexOnly(): number {
  const months: MonthFile[] = [];
  for (const f of fs.readdirSync(ROOT).sort()) {
    const m = f.match(/^agentsLogs_(\d{4}-\d{2})\.md$/);
    if (!m) continue;
    const content = fs.readFileSync(path.join(ROOT, f), 'utf8');
    months.push({ key: m[1], file: f, entries: (content.match(/^## \[(\d{4})-(\d{2})/gm) ?? []).length, lines: [] });
  }
  if (months.length === 0) {
    console.error('TIDAK ADA berkas `agentsLogs_YYYY-MM.md` di root — tidak ada yang bisa diindeks.');
    return 1;
  }
  const pointer = buildPointer(months);
  console.log(`i indeks ulang dari ${months.length} berkas bulan:`);
  for (const m of months) console.log(`  ${m.file.padEnd(24)} ${String(m.entries).padStart(3)} entri`);
  if (DRY) {
    console.log('\n(dry run — penunjuk tidak ditulis)');
    return 0;
  }
  const report = writeFileSafe(LOG, pointer, { mode: 'overwrite', eol: 'crlf' });
  console.log(
    `  agentsLogs.md            ${String(report.bytesAfter).padStart(7)} byte  ` +
      `nul=${report.nullBytesStripped}  bom=${report.bomPreserved}  bomsCollapsed=${report.bomsCollapsed}`,
  );
  return 0;
}

function main(): number {
  if (argv.includes('--index-only')) return indexOnly();

  if (!fs.existsSync(LOG)) {
    console.error(`tidak ada ${LOG}`);
    return 1;
  }

  const raw = fs.readFileSync(LOG, 'utf8');
  const hadBom = raw.startsWith(BOM);
  const text = raw.replace(/^\uFEFF/, '').replace(/\r\n/g, '\n');
  const lines = text.split('\n');

  const firstEntry = lines.findIndex((l) => ENTRY_HEADING.test(l));
  if (firstEntry === -1) {
    console.error(
      'TIDAK ADA entri `## [YYYY-MM` di agentsLogs.md.\n' +
        'Kemungkinan berkas ini sudah berupa penunjuk (split sudah pernah jalan) — berhenti.',
    );
    return 1;
  }

  const preamble = lines.slice(0, firstEntry);
  const months: MonthFile[] = [];
  let current: MonthFile | null = null;

  for (const line of lines.slice(firstEntry)) {
    const m = line.match(ENTRY_HEADING);
    if (m) {
      // Bulan harus DIPAKAI ULANG, bukan dibuat baru per entri — entri satu bulan bisa
      // puluhan, dan membuat bucket baru tiap entri menghasilkan 69 berkas "bulan" palsu.
      const key = `${m[1]}-${m[2]}`;
      let bucket = months.find((x) => x.key === key);
      if (bucket === undefined) {
        bucket = { key, file: monthFileName(key), entries: 0, lines: [] };
        months.push(bucket);
      }
      current = bucket;
    }
    if (current === null) {
      // Baris sebelum entri pertama — tidak mungkin (firstEntry menandai awalnya), tapi jangan hilang.
      preamble.push(line);
      continue;
    }
    current.lines.push(line);
    if (m) current.entries += 1;
  }

  // ── Verifikasi tanpa kehilangan ───────────────────────────────────────────────────────
  // Setiap baris non-kosong berkas asli harus muncul di salah satu berkas bulan.
  const emitted = new Set(months.flatMap((m) => [...preamble, ...m.lines]));
  const missing = lines.filter((l) => l.trim() !== '' && !emitted.has(l));
  if (missing.length > 0) {
    console.error(`GAGAL — ${missing.length} baris asli tidak masuk berkas bulan mana pun:`);
    for (const l of missing.slice(0, 10)) console.error(`  ${l.slice(0, 120)}`);
    return 2;
  }

  const pointer = buildPointer(months);

  const totalEntries = months.reduce((n, m) => n + m.entries, 0);
  console.log(`i ${LOG.replace(ROOT + path.sep, '')}: ${totalEntries} entri, ${months.length} bulan`);
  console.log(`  BOM di berkas asli: ${hadBom ? 'ada (dipertahankan)' : 'tidak ada'}`);
  for (const m of months) {
    console.log(`  ${m.file.padEnd(24)} ${String(m.entries).padStart(3)} entri  ${m.lines.length} baris`);
  }
  console.log(`  agentsLogs.md            penunjuk (${pointer.split('\n').length} baris)`);
  console.log(`  tanpa kehilangan: ${lines.length} baris asli semuanya terpetakan`);

  if (DRY) {
    console.log('\n(dry run — tidak ada berkas yang ditulis)');
    return 0;
  }

  if (WANT_SNAPSHOT) {
    fs.mkdirSync(path.dirname(SNAPSHOT), { recursive: true });
    fs.writeFileSync(SNAPSHOT, raw, 'utf8');
    console.log(`  snapshot arsip lokal  ${SNAPSHOT.replace(ROOT + path.sep, '')} (${raw.length} byte)`);
  }

  for (const m of months) {
    const content = [...preamble, ...m.lines].join('\n');
    const report = writeFileSafe(path.join(ROOT, m.file), content, { mode: 'overwrite', eol: 'crlf' });
    console.log(
      `  ${m.file.padEnd(24)} ${String(report.bytesAfter).padStart(7)} byte  ` +
        `nul=${report.nullBytesStripped}  bom=${report.bomPreserved}`,
    );
  }
  const report = writeFileSafe(LOG, pointer, { mode: 'overwrite', eol: 'crlf' });
  console.log(
    `  agentsLogs.md            ${String(report.bytesAfter).padStart(7)} byte  ` +
      `nul=${report.nullBytesStripped}  bom=${report.bomPreserved}`,
  );
  return 0;
}

process.exitCode = main();
