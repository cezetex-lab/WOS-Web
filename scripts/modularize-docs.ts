#!/usr/bin/env node
/**
 * scripts/modularize-docs.ts — pecah `AGENTS.md` menjadi berkas terpisah (P0, 2026-09-19).
 *
 * Kenapa satu skrip, bukan sunting manual: 57 KB dokumen dipindah ke berkas-berkas baru.
 * Menyalin potongan lewat shell/editor adalah kelas kerusakan yang sama dengan yang ditutup
 * `safe-file-writer.ts`. Di sini potongannya diambil LANGSUNG dari berkas sumber (tidak ada
 * teks yang diketik ulang) dan setiap penulisan lewat `writeFileSafe`.
 *
 * Jaminan terpenting: **no-loss check**. Semua baris isi `AGENTS.md` (dari §0 sampai EOF, di
 * luar baris pemisah `---`) harus muncul di salah satu berkas keluaran — termasuk berkas yang
 * keluar dari `AGENTS.md` karena DONE (§5 → `agentsLogs.md`). Satu-satunya pengecualian adalah
 * baris yang SENGAJA ditulis ulang (daftar `REWRITTEN_MARKERS`) — mis. rujukan `§7.4` yang
 * kini hidup di `ARCHITECTURE.md`. Kalau ada baris lain yang hilang, skrip GAGAL dan tidak
 * menulis apa pun.
 *
 * Idempoten: berkas keluaran ditulis mode `overwrite`; entri `agentsLogs.md` di-append hanya
 * kalau judulnya belum ada.
 *
 * Jalankan: node scripts/modularize-docs.ts [--dry-run]
 */
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { execFileSync } from 'node:child_process';
import { writeFileSafe } from './safe-file-writer.ts';

const ROOT = process.cwd();
const AGENTS = path.join(ROOT, 'AGENTS.md');
/**
 * Target log = berkas BULAN BERJALAN kalau ada (`agentsLogs_YYYY-MM.md`), karena sejak
 * 2026-09-19 `agentsLogs.md` hanya INDEKS (lihat `scripts/split-agents-logs.ts`).
 * Tanpa ini, entri §5 ditulis ke berkas penunjuk sehingga riwayatnya tidak lagi ada di
 * berkas yang benar-benar dibaca orang.
 */
function resolveLog(): string {
  const now = new Date();
  const monthFile = path.join(
    ROOT,
    `agentsLogs_${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}.md`,
  );
  return fs.existsSync(monthFile) ? monthFile : path.join(ROOT, 'agentsLogs.md');
}
const LOG = resolveLog();
const DRY = process.argv.includes('--dry-run');
/**
 * `--only-log` — hanya append entri §5 ke `agentsLogs.md`, tanpa menulis ulang berkas
 * mana pun. Dipakai SETELAH pemisahan utama selesai: penulisan log-nya sempat tertunda
 * karena `agentsLogs.md` rusak (UTF-16) dan harus diperbaiki lebih dulu.
 */
const ONLY_LOG = process.argv.includes('--only-log');
/**
 * `--source worktree|head|<path>` — dari mana isi `AGENTS.md` dibaca. `head` diperlukan
 * bersama `--only-log`: begitu `AGENTS.md` ditulis ulang, §5 sudah tidak ada lagi di
 * working tree, sehingga sumbernya harus diambil dari revisi yang sudah di-commit.
 */
const SOURCE = process.argv.includes('--source')
  ? (process.argv[process.argv.indexOf('--source') + 1] ?? 'worktree')
  : 'worktree';

function readSource(): string {
  if (SOURCE === 'worktree') return fs.readFileSync(AGENTS, 'utf8');
  if (SOURCE === 'head') return execFileSync('git', ['show', 'HEAD:AGENTS.md'], { cwd: ROOT, encoding: 'utf8' });
  return fs.readFileSync(path.resolve(SOURCE), 'utf8');
}

const source = readSource().replace(/\r\n/g, '\n');
const lines = source.split('\n');
const BODY_START = lines.indexOf('## 0. ALUR KERJA WAJIB (PROSES)');
if (BODY_START < 0) throw new Error('AGENTS.md tidak memuat "## 0. ALUR KERJA WAJIB (PROSES)" — struktur berubah');

function lineOf(exact: string): number {
  const idx = lines.indexOf(exact);
  if (idx < 0) throw new Error(`heading tidak ditemukan di AGENTS.md: ${JSON.stringify(exact)}`);
  return idx;
}

/** Buang baris kosong/pemisah di ekor potongan. */
function clean(section: string): string {
  const out = section.split('\n');
  while (out.length > 0) {
    const last = (out.at(-1) ?? '').trim();
    if (last === '' || last === '---') out.pop();
    else break;
  }
  return out.join('\n') + '\n';
}

function slice(fromHeading: string, toHeading?: string): string {
  const from = lineOf(fromHeading);
  const to = toHeading === undefined ? lines.length : lineOf(toHeading);
  if (to <= from) throw new Error(`urutan heading salah: ${fromHeading} >= ${toHeading}`);
  return clean(lines.slice(from, to).join('\n'));
}

// ── Heading persis seperti di AGENTS.md (jangan disunting di sini) ───────────────
const H = {
  s0: '## 0. ALUR KERJA WAJIB (PROSES)',
  s05: '## 0.5 GOLDEN RULES (WAJIB) — KETERKAITAN 4 PAGE: worker ⇄ admin ⇄ dashboard ⇄ owner',
  s1: '## 1. KONTEKS PROYEK (handoff)',
  s2: '## 2. PETA FILE PENTING',
  s3: '## 3. ATURAN TEKNIS KERAS (JANGAN dilanggar)',
  s4: '## 4. STATE OPEN — E2E Tests (Q5)',
  s5: '## 5. STATE DONE — UI Forms untuk Kolom Baru Karyawan (2026-09-16)',
  s55: '## 5.5 STATE OPEN — Infrastruktur: Upstash Redis + Migrasi Region ke Singapore (keputusan 2026-09-15)',
  s56: '## 5.6 STATE OPEN — Cross-check audit `Readme/upppp.txt` (diverifikasi ke kode live 2026-09-16)',
  s6: '## 6. JEBAKAN LINGKUNGAN (Windows / PowerShell / Supabase)',
  s7: '## 7. GRAND DESIGN — Arsitektur & Status Implementasi',
  s76: '### 7.6 Security Posture',
  s8: '## 8. FUTURE ROADMAP (dari FuturePlans.md)',
  s9: '## 9. DISASTER RECOVERY',
  s57: '## 5.7 STATE OPEN — POSTPONED / TUNDA (2026-09-17 — Perintah User)',
  s57b: '## 5.7B STATE OPEN — INSTALLER BASELINE: AUTO-PROVISION OWNER (2026-09-18)',
  s58: '## 5.8 STATE OPEN — WORK QUEUE: Temuan Audit SQL (WAJIB DISELESAIKAN)',
};

/**
 * Baris yang SENGAJA ditulis ulang: substring lama yang diganti agar rujukan menunjuk
 * berkas barunya. Baris yang memuat salah satu marker ini dikecualikan dari no-loss check.
 * Setiap penggantian diverifikasi ada (`replaceIn` gagal keras kalau polanya tak ditemukan),
 * jadi daftar ini tidak bisa diam-diam menjadi no-op.
 */
const REWRITTEN_MARKERS: string[] = [];

function replaceIn(text: string, from: string, to: string, label: string): string {
  if (!text.includes(from)) {
    throw new Error(`REWRITE GAGAL (${label}): pola tidak ditemukan → ${JSON.stringify(from.slice(0, 70))}`);
  }
  REWRITTEN_MARKERS.push(from);
  return text.split(from).join(to);
}

const PROVENANCE =
  '> **Pecahan dari `AGENTS.md` (2026-09-19).** Isi di bawah ini dipindahkan apa adanya —\n' +
  '> nomor bagian lama (`§5.7`, `§6.4`, `§7.4`, …) sengaja DIPERTAHANKAN agar rujukan lama tetap\n' +
  '> bisa ditelusuri. Peta bacanya ada di `AGENTS.md` (Reading Map). Jangan menaruh riwayat\n' +
  '> pekerjaan selesai di berkas ini — itu milik `agentsLogs.md`.';

function page(title: string, extra: string, ...bodies: string[]): string {
  return ['# ' + title, '', PROVENANCE, extra === '' ? '' : '\n' + extra, ...bodies.map((b) => '\n' + b)]
    .join('\n')
    .replace(/\n{4,}/g, '\n\n\n');
}

// ── Potongan mentah ────────────────────────────────────────────────────────────
const s0 = slice(H.s0, H.s05);

let s05 = slice(H.s05, H.s1);
s05 = replaceIn(
  s05,
  '(3 layer, §7.2)',
  '(3 layer, `ARCHITECTURE.md` §7.2)',
  '§0.5 G5 → ARCHITECTURE',
);

let s1 = slice(H.s1, H.s2);
s1 = replaceIn(s1, 'ada di §5.5)', 'ada di `OPEN_WORK.md` §5.5)', '§1 → OPEN_WORK');

let s3 = slice(H.s3, H.s4);
s3 = replaceIn(
  s3,
  'Klaim kuantitatif di `AGENTS.md` (§7.1, §7.3, §7.4, §7.5)',
  'Klaim kuantitatif di `ARCHITECTURE.md` (§7.1, §7.3, §7.4, §7.5)',
  '§3.13 → ARCHITECTURE',
);
s3 = replaceIn(s3, 'tertinggal (§5.7 no.11)', 'tertinggal (`TESTING_GUIDE.md` §5.7 no.11)', '§3.14 → TESTING_GUIDE');
s3 = replaceIn(s3, ' --apply` (§6.4)', ' --apply` (`ENVIRONMENT_TRAPS.md` §6.4)', '§3.14 → ENVIRONMENT_TRAPS');

let s55 = slice(H.s55, H.s56);
s55 = replaceIn(s55, 'RPO/RTO §9 tetap berlaku', 'RPO/RTO `DISASTER_RECOVERY.md` tetap berlaku', '§5.5 → DR');

let s56 = slice(H.s56, H.s6);
s56 = replaceIn(s56, 'belum masuk roadmap** (§8)', 'belum masuk roadmap** (`ROADMAP.md`)', '§5.6 F2 → ROADMAP');
s56 = replaceIn(s56, '(§7.6: 0 violations', '(`SECURITY.md` §7.6: 0 violations', '§5.6 F4 → SECURITY');

const s6 = slice(H.s6, H.s7);
const s57b = slice(H.s57b, H.s58);
const s8 = slice(H.s8, H.s9);

// ── Keluaran ───────────────────────────────────────────────────────────────────
const outputs: { file: string; content: string }[] = [];

const blocks: { file: string; content: string }[] = [
  {
    file: 'ARCHITECTURE.md',
    content: page(
      'ARCHITECTURE.md — GRAND DESIGN insightWOS',
      '> Angka di §7.1/§7.3/§7.4/§7.5 diverifikasi otomatis terhadap DB live + isi repo oleh\n' +
        '> `tests/unit/doc-claims-vs-live.test.ts`. Kalau schema/berkas berubah secara sah: perbarui\n' +
        '> angka DI SINI (bukan di `AGENTS.md`) — jangan melemahkan tesnya.',
      s1,
      slice(H.s2, H.s3),
      slice(H.s7, H.s76),
    ),
  },
  {
    file: 'SECURITY.md',
    content: page(
      'SECURITY.md — ATURAN TEKNIS KERAS + SECURITY POSTURE',
      '> §3 adalah aturan yang **tidak boleh dilanggar**, dirujuk dari banyak tempat sebagai\n' +
        '> `§3.11` (TypeScript only), `§3.13` (angka dokumen tidak boleh dikarang), `§3.15`/`§3.16`\n' +
        '> (instalasi baseline) — nomornya sengaja tidak diubah.',
      s3,
      slice(H.s76, H.s8),
    ),
  },
  {
    file: 'ENVIRONMENT_TRAPS.md',
    content: page(
      'ENVIRONMENT_TRAPS.md — JEBAKAN LINGKUNGAN (Windows / PowerShell / Supabase)',
      '> **Satu sumber untuk seluruh §6.** Berkas lain merujuk ke sini alih-alih menyalin\n' +
        '> (mencegah teks kembar yang menyimpang): `MIGRATION_GUIDE.md` → §6.4,\n' +
        '> `TESTING_GUIDE.md` → §6.7.',
      s6,
    ),
  },
  {
    file: 'MIGRATION_GUIDE.md',
    content: page(
      'MIGRATION_GUIDE.md — JALUR MIGRASI & INSTALASI PERUSAHAAN BARU',
      '> Aturan kerasnya tinggal di `SECURITY.md` §3.14–§3.16. Di sini yang operasional: perintah,\n' +
        '> urutan, dan bukti. Jebakan CLI/DB yang menyertainya: `ENVIRONMENT_TRAPS.md` §6.4.\n' +
        '> Daftar kerja pascaaudit (termasuk butir registry/checksum): `TESTING_GUIDE.md` §5.7.',
      `## 0. Jalur resmi — satu perintah, satu transaksi

Migrasi ke DB live **tidak boleh** lewat SQL Editor / pg8000 manual:

    npm run db:migrate -- <berkas>.sql --apply      # supabase/scripts/apply-migration.mjs

Wrapper itu menjalankan SQL **DAN** mendaftarkannya ke \`schema_migrations\` dalam **satu
transaksi** — kalau pendaftaran gagal, SQL-nya ikut ROLLBACK, jadi mustahil berakhir
"sudah jalan tapi tidak tercatat". Tanpa \`--apply\` = dry run. Ia menolak berkas yang nomor
versinya sudah dipakai berkas lain, dan mendeteksi berkas yang diubah setelah diterapkan
(checksum beda). Detail jebakannya: \`ENVIRONMENT_TRAPS.md\` §6.4.

Invariant yang mengikat (rujuk, jangan gandakan): \`SECURITY.md\` §3.14 (semua migrasi
tercatat), §3.15 (baseline vs rantai), §3.16 (identitas perusahaan tidak diwariskan).

## 1. Registry & checksum drift

Yang **bukan** masalah: \`DUPLICATE\` untuk versi yang memang dipakai beberapa berkas
(176/186/208/215) — migration 219 mengizinkannya dan migration 224 menyempitkan aturannya.
Yang **selalu** masalah: \`UNAPPLIED\` dan \`VERSION_MISMATCH\`.

Kasus nyata (migrasi 221/222/223 diterapkan lewat SQL Editor sehingga registry tertinggal,
dan 21 migrasi historis yang diperbaiki untuk jalur instalasi sehingga checksum registry tidak
lagi cocok) ada di \`TESTING_GUIDE.md\` §5.7 butir 11 beserta catatannya — satu sumber, JANGAN
disalin ke sini.

Aturan praktis: setiap migrasi yang mengubah schema **wajib** langsung diregenerasi ke baseline
(\`npm run db:baseline\`) dan dibuktikan (\`npm run db:verify-install\`), karena baseline yang
tertinggal akan memasang perilaku lama ke perusahaan baru.

## 2. Instalasi perusahaan baru (baseline, BUKAN rantai migrasi)

\`supabase/migrations/\` adalah **histori + gerbang regresi**, bukan jalur instalasi: ia membawa
data seed/demo dan tidak memuat objek yang hanya hidup di DB live. Jalur resmi:

    npm run install:baseline -- --target "<connection string project Supabase baru>" --company-name "PT X" --owner-email "owner@x.com" --apply

Runbook lengkap: \`supabase/baseline/README.md\`. Pengamannya kaku: \`--target\` wajib (skrip
TIDAK pernah memakai \`DATABASE_URL\` repo), target yang sama dengan DB live ditolak, project
yang sudah berisi tabel ditolak tanpa \`--force\`, default dry run.

Kelas bug yang sudah pernah terjadi dan **tidak boleh kembali** (semuanya kini dijaga generator
+ \`verify-install-e2e.mjs\`): merek perusahaan sumber ikut ter-dump; email owner diwariskan
sementara \`owner_login()\` mewajibkan email itu (owner baru tidak bisa login); versi registry
ditulis \`parseInt\` sehingga muncul 59 \`VERSION_MISMATCH\`; partisi absensi mewarisi hak \`anon\`;
trigger \`INSTEAD OF\` di view \`employees_master\` hilang sehingga view tulis jadi read-only
tanpa error.

## 3. Bukti yang wajib disertakan sebelum klaim DONE

\`verify_migration_checksum\` PASS untuk migrasi yang baru diterapkan, \`check_migrations()\` tanpa
\`UNAPPLIED\`/\`VERSION_MISMATCH\`, dan \`npm run db:verify-install\` PASS setiap kali baseline
diregenerasi. Status OPEN yang belum ditutup tinggal di \`AGENTS.md\` §5.8.`,
    ),
  },
  {
    file: 'TESTING_GUIDE.md',
    content: page(
      'TESTING_GUIDE.md — GATE, E2E, DAN DAFTAR KERJA PASCAAUDIT',
      '> **Satu sumber untuk §5.7** (termasuk butir 11 tentang \`schema_migrations\`) —\n' +
        '> `MIGRATION_GUIDE.md` merujuk ke sini, bukan menyalin. Jebakan vitest/worker ada di\n' +
        '> `ENVIRONMENT_TRAPS.md` §6.7. Gate lintas-page (§0.5 G6) tetap di `AGENTS.md` karena ia\n' +
        '> bagian dari alur kerja wajib, bukan sekadar teknik tes.',
      slice(H.s4, H.s5),
      slice(H.s57, H.s57b),
    ),
  },
  {
    file: 'ROADMAP.md',
    content: page(
      'ROADMAP.md — FUTURE ROADMAP',
      '> Detail lengkap per fase: `FuturePlans.md`. Klaim kapabilitas di `FuturePlans.md`\n' +
        '> (tabel/RPC/berkas yang diklaim sudah ada atau belum ada) diverifikasi otomatis oleh\n' +
        '> `tests/unit/doc-claims-vs-live.test.ts` terhadap DB live.',
      s8,
    ),
  },
  {
    file: 'DISASTER_RECOVERY.md',
    content: page('DISASTER_RECOVERY.md — BACKUP, RPO/RTO, MONITORING', '', slice(H.s9, H.s57)),
  },
  {
    file: 'OPEN_WORK.md',
    content: page(
      'OPEN_WORK.md — STATE OPEN NON-SQL (WAJIB DITUTUP ATAU DIBUANG SECARA EKSPLISIT)',
      '> Work Queue temuan SQL tinggal di `AGENTS.md` §5.8. Berkas ini memuat state OPEN yang\n' +
        '> bukan temuan SQL: infrastruktur (Upstash/region SG), audit `Readme/upppp.txt`, dan\n' +
        '> installer baseline. Aturan yang sama berlaku: setiap item butuh **bukti** dan\n' +
        '> **Definition of Done**; item yang ternyata bukan masalah dipindah ke tabel "bukan\n' +
        '> masalah", bukan dibiarkan sebagai OPEN palsu.',
      s55,
      s56,
      s57b,
    ),
  },
];
if (!ONLY_LOG) outputs.push(...blocks);

// ── AGENTS.md baru: Reading Map + §0 + §0.5 + §5.8 ─────────────────────────────
const readingMap = `# AGENTS.md — ATURAN KERJA AGENT (WAJIB) — ONE SINGLE TRUTH

> **Restrukturisasi 2026-09-19 (P0): berkas ini DIPECAH.** Sejak sekarang ia hanya memuat
> (a) alur kerja wajib §0, (b) Golden Rules §0.5, dan (c) Work Queue §5.8 — plus peta bacaan
> di bawah. Semua isi lain pindah ke berkas terpisah supaya agent tidak memuat 57 KB hanya
> untuk membaca satu aturan, dan supaya aturan tidak lagi bercampur dengan status proyek.
>
> **Reading Map — BACA berkas yang relevan SEBELUM mulai kerja:**
>
> | Kalau tugasnya menyentuh… | Baca dulu |
> |---|---|
> | arsitektur, halaman/route, auth 3-layer, kontrak sesi client, status DB/frontend, konteks proyek, peta file penting | \`ARCHITECTURE.md\` |
> | aturan teknis keras §3 (authz dari JWT, bcrypt, \`SECURITY DEFINER\`, TypeScript-only, angka dokumen tidak boleh dikarang) + security posture §7.6 | \`SECURITY.md\` |
> | menjalankan migrasi, registry/checksum drift, instalasi perusahaan baru (baseline), identitas perusahaan | \`MIGRATION_GUIDE.md\` |
> | gate (tsc/lint/build/test), E2E, daftar kerja pascaaudit §5.7, jebakan vitest | \`TESTING_GUIDE.md\` |
> | Windows/PowerShell/SQL Editor, \`npx\`, timeout proses, jebakan DB | \`ENVIRONMENT_TRAPS.md\` |
> | state OPEN non-SQL: Upstash/region SG, audit \`Readme/upppp.txt\` (F1–F4), installer baseline | \`OPEN_WORK.md\` |
> | roadmap fitur (Workday/SAP/ADP) | \`ROADMAP.md\` |
> | backup, RPO/RTO, DR drill, eskalasi insiden | \`DISASTER_RECOVERY.md\` |
> | riwayat pekerjaan yang SUDAH selesai | \`agentsLogs_YYYY-MM.md\` (indeks bulan: \`agentsLogs.md\`) — JANGAN taruh history di sini |
>
> Nomor bagian lama tidak diubah di berkas barunya (\`§3.11\`, \`§5.7\`, \`§6.4\`, \`§7.4\`, \`§9\`, …),
> jadi rujukan lama tetap bisa ditelusuri lewat tabel di atas.`;

let s58 = slice(H.s58);
const opsRow =
  '| OPS-01 | **P2** | **Smoke runtime WorkerProfile belum dijalankan** (pindahan `§5` STATE DONE) |' +
  ' `§5` hanya menyisakan satu item OPEN: login worker → WorkerProfile → edit 1 kolom → simpan → reload.' +
  ' Grant `EXECUTE TO authenticated` sudah termigrasi di `222` (baris 79 + 150-152) — tidak ada langkah SQL tersisa.' +
  ' Lingkungan agent tidak bisa menjangkau app live | User menjalankan smoke di browser lalu hasilnya ditulis ke `agentsLogs_YYYY-MM.md` | OPEN |';
const sql13Line = s58.split('\n').find((l) => l.startsWith('| SQL-13 |'));
if (sql13Line === undefined) throw new Error('§5.8: baris SQL-13 tidak ditemukan, tidak bisa menyisipkan OPS-01');
s58 = s58.replace(sql13Line + '\n', sql13Line + '\n' + opsRow + '\n');
s58 = replaceIn(
  s58,
  '### Sudah diverifikasi **BUKAN masalah** — jangan diinvestigasi ulang',
  '> Baris ber-ID `OPS-*` adalah temuan operasional non-SQL yang tetap wajib ditutup seperti item lain.\n\n' +
    '### Sudah diverifikasi **BUKAN masalah** — jangan diinvestigasi ulang',
  '§5.8 footnote OPS',
);

const agentsNew = readingMap + '\n\n' + s0 + '\n' + s05 + '\n' + s58;
if (!ONLY_LOG) outputs.push({ file: 'AGENTS.md', content: agentsNew });

// ── STATE DONE §5 → agentsLogs.md (aturan §0.4) ────────────────────────────────
const logHeading = '## [2026-09-19] STATE DONE pindah ke log: UI Forms 14 kolom karyawan (dari AGENTS.md §5)';
const logEntry = [
  logHeading,
  '',
  '> Dipindahkan dari `AGENTS.md` §5 saat restrukturisasi dokumen 2026-09-19 (aturan §0.4:',
  '> item selesai keluar dari `AGENTS.md`). Satu item OPEN-nya (smoke runtime manual) tetap',
  '> hidup sebagai `OPS-01` di `AGENTS.md` §5.8.',
  '',
  slice(H.s5, H.s55),
  '',
].join('\n');

if (ONLY_LOG && (!logEntry.includes(H.s5) || logEntry.length < 500)) {
  throw new Error(
    `--only-log: potongan §5 tidak ditemukan / terlalu pendek (${logEntry.length} byte) — ` +
      `periksa --source (sekarang "${SOURCE}")`,
  );
}

// ── No-loss check ──────────────────────────────────────────────────────────────
const universe = outputs.map((o) => o.content).join('\n') + '\n' + logEntry;
const strays: string[] = [];
const rewritten: string[] = [];
for (let i = BODY_START; i < lines.length; i += 1) {
  const raw = (lines[i] ?? '').trim();
  if (raw === '' || raw === '---') continue;
  if (universe.includes(raw)) continue;
  if (REWRITTEN_MARKERS.some((m) => raw.includes(m))) {
    rewritten.push(`${i + 1}: ${raw.slice(0, 90)}`);
    continue;
  }
  strays.push(`${i + 1}: ${raw.slice(0, 110)}`);
}
if (strays.length > 0 && !ONLY_LOG) {
  console.error(`NO-LOSS CHECK GAGAL — ${strays.length} baris tidak ditemukan di berkas keluaran:`);
  for (const s of strays.slice(0, 40)) console.error('  ' + s);
  console.error('\nTidak ada berkas yang ditulis.');
  process.exit(1);
}

// ── Tulis ─────────────────────────────────────────────────────────────────────
for (const out of outputs) {
  if (DRY) {
    console.log(
      `${out.file.padEnd(22)} ${String(Buffer.byteLength(out.content, 'utf8')).padStart(7)} byte  (dry-run, tidak ditulis)`,
    );
    continue;
  }
  const report = writeFileSafe(path.join(ROOT, out.file), out.content, { mode: 'overwrite', eol: 'crlf' });
  console.log(
    `${out.file.padEnd(22)} ${String(report.bytesAfter).padStart(7)} byte  (${report.bytesBefore} → ${report.bytesAfter})  nul=${report.nullBytesStripped}`,
  );
}

const logExists = DRY || fs.readFileSync(LOG, 'utf8').includes(logHeading);
if (logExists) {
  console.log(`${path.basename(LOG).padEnd(22)} entri §5 sudah ada — append dilewati (idempoten)`);
} else {
  const report = writeFileSafe(LOG, logEntry, { mode: 'append' });
  console.log(
    `${path.basename(LOG).padEnd(22)} +${report.bytesWritten} byte  (${report.bytesBefore} → ${report.bytesAfter})  eol=${report.eol}  bom=${report.bomPreserved}`,
  );
}

console.log(
  `\nno-loss check: OK — ${lines.length - BODY_START} baris sumber terpetakan` +
    ` (${rewritten.length} baris sengaja ditulis ulang, rujukan pindah berkas).\n` +
    `AGENTS.md baru: ${Buffer.byteLength(agentsNew, 'utf8')} byte (dari ${Buffer.byteLength(source, 'utf8')} byte).`,
);
for (const r of rewritten) console.log('  rewrite: ' + r);
