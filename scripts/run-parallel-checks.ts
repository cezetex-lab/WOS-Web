#!/usr/bin/env node
/**
 * scripts/run-parallel-checks.ts — jalankan 4 gate dengan paralelisme BERTAHAP.
 *
 * Kenapa bertahap, bukan 4 sekaligus (AGENTS.md `ENVIRONMENT_TRAPS.md` §6.7):
 * `check:types` + `lint` ringan (bisa bersamaan), lalu `test` + `build` berat. Menyalakan
 * keempatnya sekaligus membuat pool runner vitest kehabisan CPU dan muncul
 * "Failed to start threads worker" — jumlah test turun TANPA satu pun baris error.
 * Kalau `test`/`build` masih melahirkan gejala itu di mesin ini, jalankan
 * `--heavy-serial` (tanpa mengubah konfigurasi tes, sesuai larangan §6.7).
 *
 * Deteksi flake otomatis: kalau gate `test` gagal dengan jejak worker-startup timeout,
 * ATAU jumlah tes yang dilaporkan turun tanpa satu pun baris "failed", runner ini
 * MENGULANG gate `test` sekali secara SERIAL setelah fase berat selesai (jadi tidak ada
 * kontensi CPU). Hasil retry-lah yang menentukan verdict — kegagalan kode baru diakui
 * kalau retry juga gagal. Jumlah tes sehat terakhir dicatat di
 * `test-results/.vitest-count.json` (gitignored) sebagai pembanding drop senyap.
 * Matikan dengan `--no-flake-retry`.
 *
 * Runner: Node >= 24 menjalankan `.ts` native (type stripping). `tsx`/`vite-node` tidak
 * dipakai di repo ini. Di Windows, `npm` adalah `npm.cmd` sehingga spawn butuh `shell`.
 *
 * Pemakaian:
 *   node scripts/run-parallel-checks.ts                 # light → heavy (default)
 *   node scripts/run-parallel-checks.ts --phase light    # hanya check:types + lint
 *   node scripts/run-parallel-checks.ts --heavy-serial   # test lalu build, berurutan
 *   node scripts/run-parallel-checks.ts --verbose        # streaming output penuh
 *   node scripts/run-parallel-checks.ts --no-flake-retry # tanpa retry serial otomatis
 *
 * Keluaran: `test-results/parallel-gate-report.md` (ringkasan) + `test-results/gate-*.log`
 * (output mentah per gate). Keduanya di dalam `test-results/` yang gitignored.
 * Exit code: 0 = semua gate hijau; 1 = ada yang gagal (atau fase berat dibatalkan).
 */
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import process from 'node:process';
import { writeFileSafe } from './safe-file-writer.ts';

const ROOT = process.cwd();
const RESULTS_DIR = path.join(ROOT, 'test-results');
const REPORT = path.join(RESULTS_DIR, 'parallel-gate-report.md');

const argv = process.argv.slice(2);
const VERBOSE = argv.includes('--verbose');
const HEAVY_SERIAL = argv.includes('--heavy-serial');
const NO_FLAKE_RETRY = argv.includes('--no-flake-retry');
const phaseIdx = argv.indexOf('--phase');
const PHASE = phaseIdx >= 0 ? argv[phaseIdx + 1] : 'all';
const PHASE_OK = ['all', 'light', 'heavy'].includes(PHASE);
if (!PHASE_OK) {
  // JANGAN pakai process.exit() di top-level ESM: di Windows itu memicu assertion libuv
  // (uv_async, exit 127). Pakai exitCode saja.
  console.error(`--phase harus 'all' | 'light' | 'heavy' (dapat: ${PHASE})`);
}

const IS_WIN = process.platform === 'win32';
const NPM = IS_WIN ? 'npm.cmd' : 'npm';

interface Gate {
  id: string;
  label: string;
  args: string[];
  timeoutMs: number;
  heavy: boolean;
}

const LIGHTWEIGHT: Gate[] = [
  { id: 'types', label: 'check:types', args: ['run', 'check:types'], timeoutMs: 300_000, heavy: false },
  { id: 'lint', label: 'lint', args: ['run', 'lint'], timeoutMs: 300_000, heavy: false },
];

const HEAVYWEIGHT: Gate[] = [
  // `npm test` = `vitest run`; maxWorkers dibatasi di vitest.config.ts (2 per project, §6.7).
  { id: 'test', label: 'test', args: ['test'], timeoutMs: 600_000, heavy: true },
  { id: 'build', label: 'build', args: ['run', 'build'], timeoutMs: 600_000, heavy: true },
];

interface GateResult {
  gate: Gate;
  code: number | null;
  signal: NodeJS.Signals | null;
  timedOut: boolean;
  durationMs: number;
  output: string;
  summary: VitestSummary;
  /** Diisi hanya kalau gate ini dicurigai flake dan diulang serial. */
  flakeReason?: string;
  retry?: GateResult;
}

interface VitestSummary {
  files: number | null;
  total: number | null;
  passed: number | null;
  failed: number | null;
}

/**
 * vitest TETAP mewarnai output walau stdout-nya pipe (bukan TTY), jadi angka di baris
 * ringkasan terbungkus escape ANSI (mis. `\u001b[2m      Tests \u001b[22m ... (131)`).
 * Semua pembacaan output harus lewat `stripAnsi` dulu, kalau tidak regex ringkasan meleset.
 */
const ANSI_ESCAPE = /\u001b\[[0-9;]*[A-Za-z]/g;

function stripAnsi(text: string): string {
  return text.replace(ANSI_ESCAPE, '');
}

/** Jejak khas pool worker vitest kehabisan CPU (`ENVIRONMENT_TRAPS.md` §6.7) — bukan tes salah. */
const FLAKE_SIGNATURES: RegExp[] = [
  /Failed to start threads worker/i,
  /Failed to start forks worker/i,
  /Failed to start worker/i,
  /Timeout waiting for worker/i,
  /Timed out waiting for worker/i,
  /Vitest failed to start/i,
  /Unhandled error[\s\S]{0,80}worker/i,
  /spawn [^\n]*EAGAIN/i,
];

/** Baris ringkasan vitest: `      Tests  131 passed (131)` / `Test Files  19 passed (19)`. */
function parseVitestSummary(output: string): VitestSummary {
  const clean = stripAnsi(output).replace(/\r\n/g, '\n');
  const testsLine = clean.match(/^ *Tests +(.*)$/m);
  const filesLine = clean.match(/^ *Test Files +(.*)$/m);
  const num = (line: string | undefined, re: RegExp): number | null => {
    const m = line ? line.match(re) : null;
    return m ? Number(m[1]) : null;
  };
  const tests = testsLine?.[1];
  return {
    files: num(filesLine?.[1], /\((\d+)\) *$/),
    total: num(tests, /\((\d+)\) *$/),
    passed: num(tests, /(\d+) passed/),
    failed: testsLine ? (num(tests, /(\d+) failed/) ?? 0) : null,
  };
}

/** Pembanding "jumlah tes sehat terakhir" untuk menangkap drop senyap (tanpa baris error). */
const COUNT_FILE = path.join(RESULTS_DIR, '.vitest-count.json');

function readLastGoodCount(): number | null {
  try {
    const raw = fs.readFileSync(COUNT_FILE, 'utf8').replace(/\u0000/g, '');
    const parsed = JSON.parse(raw) as { total?: unknown };
    return typeof parsed.total === 'number' ? parsed.total : null;
  } catch {
    return null;
  }
}

function writeLastGoodCount(total: number): void {
  writeFileSafe(COUNT_FILE, `${JSON.stringify({ total, at: new Date().toISOString() }, null, 2)}\n`, {
    mode: 'overwrite',
    eol: 'lf',
  });
}

/**
 * Kembalikan alasan flake kalau hasil gate ini lebih masuk akal sebagai kontensi CPU
 * daripada sebagai kegagalan kode; `null` kalau bukan flake.
 */
function detectFlake(r: GateResult, lastGood: number | null): string | null {
  if (r.gate.id !== 'test') return null;
  const haystack = stripAnsi(r.output);
  const signature = FLAKE_SIGNATURES.find((re) => re.test(haystack));
  if (signature) return `jejak worker-startup timeout (${signature})`;
  if (r.timedOut) return `gate melewati batas ${Math.round(r.gate.timeoutMs / 1000)}s`;
  if (r.code !== 0 && (r.summary.failed ?? 0) === 0) {
    return r.summary.total === null
      ? 'exit ≠ 0 tapi vitest tidak pernah melaporkan ringkasan tes'
      : `exit ≠ 0 tanpa satu pun tes gagal (${r.summary.total} tes dilaporkan)`;
  }
  if (r.code === 0 && r.summary.total !== null && lastGood !== null && r.summary.total < lastGood) {
    return `jumlah tes turun senyap: ${r.summary.total} < ${lastGood} tersimpan`;
  }
  return null;
}

/** Apakah gate ini (termasuk hasil retry-nya) boleh dihitung sebagai lulus. */
function effectiveOk(r: GateResult): boolean {
  if (!r.retry) return r.code === 0 && !r.timedOut;
  if (r.retry.code !== 0 || r.retry.timedOut) return false;
  const before = r.summary.total;
  const after = r.retry.summary.total;
  // Retry lulus tapi menjalankan tes lebih sedikit daripada percobaan paralel = masih flaky.
  return before === null || after === null || after >= before;
}

function tail(text: string, maxLines: number): string {
  const lines = stripAnsi(text)
    .replace(/\r\n/g, '\n')
    .split('\n')
    .filter((l) => l.trim() !== '');
  return lines.slice(-maxLines).join('\n');
}

function runGate(gate: Gate): Promise<GateResult> {
  return new Promise((resolve) => {
    const started = Date.now();
    console.log(`▶ ${gate.label.padEnd(12)} mulai (timeout ${Math.round(gate.timeoutMs / 1000)}s)`);
    const child = spawn(NPM, gate.args, { cwd: ROOT, shell: IS_WIN, stdio: ['ignore', 'pipe', 'pipe'] });
    let output = '';
    let timedOut = false;
    const timer = setTimeout(() => {
      timedOut = true;
      child.kill();
    }, gate.timeoutMs);

    child.stdout.on('data', (chunk: Buffer) => {
      output += chunk.toString('utf8');
      if (VERBOSE) process.stdout.write(chunk);
    });
    child.stderr.on('data', (chunk: Buffer) => {
      output += chunk.toString('utf8');
      if (VERBOSE) process.stderr.write(chunk);
    });
    child.on('error', (error) => {
      output += `\nspawn error: ${String(error)}\n`;
    });
    child.on('close', (code, signal) => {
      clearTimeout(timer);
      const durationMs = Date.now() - started;
      const ok = !timedOut && code === 0;
      console.log(
        `${ok ? '✔' : '✘'} ${gate.label.padEnd(12)} ${ok ? 'PASS' : 'FAIL'} ` +
          `(exit=${code ?? (timedOut ? 'timeout' : 'null')}, ${(durationMs / 1000).toFixed(1)}s)`,
      );
      resolve({ gate, code, signal, timedOut, durationMs, output, summary: parseVitestSummary(output) });
    });
  });
}

/** Jalankan beberapa gate bersamaan, atau berurutan. */
async function runPhase(gates: Gate[], serial: boolean): Promise<GateResult[]> {
  if (serial) {
    const results: GateResult[] = [];
    for (const gate of gates) results.push(await runGate(gate));
    return results;
  }
  return Promise.all(gates.map((gate) => runGate(gate)));
}

function persistLogs(results: GateResult[]): void {
  for (const r of results) {
    writeFileSafe(path.join(RESULTS_DIR, `gate-${r.gate.id}.log`), r.output, { mode: 'overwrite', eol: 'lf' });
  }
}

function attemptVerdict(code: number | null, timedOut: boolean, timeoutMs: number): string {
  if (timedOut) return `TIMEOUT (> ${Math.round(timeoutMs / 1000)}s)`;
  return code === 0 ? 'PASS' : `FAIL (exit ${code})`;
}

function verdictOf(r: GateResult): string {
  const base = attemptVerdict(r.code, r.timedOut, r.gate.timeoutMs);
  if (!r.retry) return base;
  const retried = attemptVerdict(r.retry.code, r.retry.timedOut, r.retry.gate.timeoutMs);
  return `${base} → retry serial: ${retried}`;
}

function countLabel(r: GateResult): string {
  return r.summary.total === null ? '—' : `${r.summary.total} tes`;
}

/**
 * Ulangi gate `test` sekali secara serial kalau hasilnya bau flake (§6.7). Retry dijalankan
 * saat fase berat sudah selesai, jadi hanya satu proses berat yang hidup — itulah yang
 * membedakan "CPU rebutan" dari "tes gagal".
 */
async function maybeRetryFlake(result: GateResult, lastGood: number | null): Promise<void> {
  if (NO_FLAKE_RETRY) return;
  const reason = detectFlake(result, lastGood);
  if (!reason) return;
  result.flakeReason = reason;
  console.log(`\n⟳ gate 'test' dicurigai flake — ${reason}`);
  console.log('  mengulang SERIAL (tanpa gate lain berjalan)...');
  const retry = await runGate(result.gate);
  result.retry = retry;
  writeFileSafe(path.join(RESULTS_DIR, 'gate-test-retry.log'), retry.output, { mode: 'overwrite', eol: 'lf' });
  const retryOk = retry.code === 0 && !retry.timedOut;
  const before = result.summary.total;
  const after = retry.summary.total;
  if (!retryOk) {
    console.log('  ✘ retry serial juga gagal — ini kegagalan kode, bukan flake.');
  } else if (before !== null && after !== null && after < before) {
    console.log(`  ✘ retry serial LULUS tetapi hanya ${after} tes (paralel ${before}) —`);
    console.log('    jumlah tes tidak kembali utuh, jadi gate tetap GAGAL.');
  } else if (before === null || after === null) {
    console.log('  ✔ retry serial LULUS — flake terkonfirmasi, bukan kegagalan kode.');
  } else {
    console.log(`  ✔ retry serial LULUS dengan ${after} tes (paralel hanya ${before}) — flake terkonfirmasi.`);
  }
}

/**
 * Simpan jumlah tes sebagai patokan baru, tapi HANYA kalau angkanya bisa dipercaya: tanpa
 * anomali, atau dua percobaan sepakat. Kalau drop senyap tidak bisa direproduksi, patokan
 * lama (lebih tinggi) dipertahankan supaya drop berikutnya tetap tertangkap.
 */
function settleLastGoodCount(result: GateResult): void {
  const retry = result.retry;
  if (!retry) {
    // Percobaan lulus tanpa anomali: angkanya sah jadi patokan baru. Kalau percobaan itu
    // TIDAK melaporkan ringkasan, jangan tulis apa pun — patokan lama harus bertahan.
    if (result.code === 0 && !result.timedOut && result.summary.total !== null) {
      writeLastGoodCount(result.summary.total);
    }
    return;
  }
  // Ada retry: patokan diambil dari percobaan serial yang lulus — termasuk saat percobaan
  // paralel tidak melaporkan ringkasan sama sekali (crash worker), supaya run pertama yang
  // flaky tidak diam-diam menjadi patokan rendah.
  if (retry.code !== 0 || retry.timedOut || retry.summary.total === null) return;
  const before = result.summary.total;
  if (before === null || retry.summary.total >= before) writeLastGoodCount(retry.summary.total);
}

function buildReport(all: GateResult[], skipped: Gate[]): string {
  const now = new Date().toISOString();
  const lines: string[] = [];
  lines.push('# Parallel gate report', '');
  lines.push(`- Dijalankan: \`${now}\``);
  lines.push(`- Perintah: \`node scripts/run-parallel-checks.ts${argv.length ? ' ' + argv.join(' ') : ''}\``);
  lines.push(`- Node: \`${process.version}\` · platform: \`${process.platform}\` · cpus: ${os.cpus().length}`);
  lines.push(
    `- Mode: fase ringan (${LIGHTWEIGHT.map((g) => g.label).join(' + ')}) → fase berat ` +
      `(${HEAVYWEIGHT.map((g) => g.label).join(HEAVY_SERIAL ? ' → ' : ' + ')})`,
  );
  lines.push('');
  lines.push('| Gate | Perintah | Hasil | Tes | Durasi |');
  lines.push('|---|---|---|---|---|');
  for (const r of all) {
    const totalMs = r.durationMs + (r.retry?.durationMs ?? 0);
    lines.push(
      `| ${r.gate.label} | \`npm ${r.gate.args.join(' ')}\` | ${verdictOf(r)} | ${countLabel(r)} | ${(totalMs / 1000).toFixed(1)}s |`,
    );
  }
  for (const g of skipped) {
    lines.push(`| ${g.label} | \`npm ${g.args.join(' ')}\` | TIDAK DIJALANKAN (fase ringan gagal) | — | — |`);
  }
  lines.push('');

  const retried = all.filter((r) => r.retry !== undefined);
  const lastGood = readLastGoodCount();
  if (retried.length > 0 || lastGood !== null) {
    lines.push('## Deteksi flake (§6.7)', '');
    if (lastGood !== null) {
      lines.push(`- Patokan jumlah tes sehat: **${lastGood}** (\`test-results/.vitest-count.json\`)`);
    }
    for (const r of retried) {
      const retry = r.retry as GateResult;
      lines.push(`- \`${r.gate.label}\` — alasan diulang: ${r.flakeReason ?? '—'}`);
      lines.push(
        `  - paralel: ${countLabel(r)} → ${attemptVerdict(r.code, r.timedOut, r.gate.timeoutMs)}` +
          ` (\`test-results/gate-${r.gate.id}.log\`)`,
      );
      lines.push(
        `  - serial: ${countLabel(retry)} → ${attemptVerdict(retry.code, retry.timedOut, retry.gate.timeoutMs)}` +
          ` (\`test-results/gate-${r.gate.id}-retry.log\`)`,
      );
      lines.push(`  - verdict akhir: **${effectiveOk(r) ? 'LULUS' : 'GAGAL'}**`);
    }
    if (retried.length === 0) lines.push('- Tidak ada gate yang perlu diulang pada run ini.');
    lines.push('');
  }

  const failed = all.filter((r) => !effectiveOk(r));
  if (failed.length === 0) {
    lines.push('## Status: SEMUA GATE HIJAU', '');
    lines.push('Urutan bertahap dipakai karena alasan §6.7 (`ENVIRONMENT_TRAPS.md`): vitest punya');
    lines.push('timeout keras 60s untuk pool runner-nya, dan menyalakan 4 gate sekaligus di mesin');
    lines.push('ini membuat jumlah test turun tanpa baris error. Log mentah per gate:');
    lines.push(LIGHTWEIGHT.concat(HEAVYWEIGHT).map((g) => `\`test-results/gate-${g.id}.log\``).join(', ') + '.');
    if (retried.length > 0) {
      lines.push('');
      lines.push('Catatan: setidaknya satu gate sempat dicurigai flake lalu **LULUS** setelah diulang');
      lines.push('serial — rinciannya di bagian "Deteksi flake" di atas. Hasil retry-lah yang sah.');
    }
  } else {
    lines.push('## Status: ADA GATE GAGAL', '');
    for (const r of failed) {
      lines.push(`### ${r.gate.label} — ${verdictOf(r)}`, '');
      const retry = r.retry;
      const retryOk = retry !== undefined && retry.code === 0 && !retry.timedOut;
      const before = r.summary.total;
      const after = retry?.summary.total ?? null;
      if (retryOk && before !== null && after !== null && after < before) {
        lines.push('Retry serial LULUS tetapi jumlah tes tidak kembali utuh:');
        lines.push(`percobaan paralel melaporkan ${before} tes, retry serial ${after} tes.`);
        lines.push('Gate tetap GAGAL supaya flake yang menelan tes tidak pernah lolos hijau.', '');
      }
      lines.push('```');
      lines.push(tail(retry !== undefined && !retryOk ? retry.output : r.output, 40));
      lines.push('```', '');
      if (retry !== undefined) lines.push(`Log retry: \`test-results/gate-${r.gate.id}-retry.log\`.`, '');
    }
    if (retried.some((r) => !effectiveOk(r))) {
      lines.push('> Gate \`test\` sudah diulang **serial** karena bau flake dan tetap belum utuh.');
      lines.push('> Lihat bagian "Deteksi flake": perbedaan antara kegagalan kode nyata dan jumlah');
      lines.push('> tes yang tidak kembali utuh ada di sana (§6.7).');
      lines.push('');
    } else if (all.some((r) => r.gate.id === 'test' && FLAKE_SIGNATURES.some((re) => re.test(r.output)))) {
      lines.push('> Gejala kontensi CPU (§6.7) terdeteksi, tetapi retry serial otomatis belum hijau.');
      lines.push('> Coba lagi dengan `--heavy-serial`, atau selidiki output di atas.');
      lines.push('');
    }
  }
  return lines.join('\n') + '\n';
}

/** Pastikan `test-results/` benar-benar gitignored; kalau tidak, tambahkan (lewat safe writer). */
function ensureIgnored(): string {
  const gi = path.join(ROOT, '.gitignore');
  const existing = fs.existsSync(gi) ? fs.readFileSync(gi, 'utf8') : '';
  const already = existing.split(/\r?\n/).some((l) => l.trim() === 'test-results/' || l.trim() === 'test-results');
  if (already) return '.gitignore sudah memuat test-results/ (tidak diubah)';
  writeFileSafe(gi, '# Artefak gate (laporan + log mentah) — jangan commit\ntest-results/\n', { mode: 'append' });
  return '.gitignore DITAMBAHI test-results/';
}

function exitCodeFor(results: GateResult[]): number {
  return results.every(effectiveOk) ? 0 : 1;
}

// ── Alur utama ─────────────────────────────────────────────────────────
async function run(): Promise<number> {
  fs.mkdirSync(RESULTS_DIR, { recursive: true });
  const ignoreNote = ensureIgnored();
  console.log(`i ${ignoreNote}\n`);

  const all: GateResult[] = [];
  const skipped: Gate[] = [];
  const started = Date.now();

  if (PHASE === 'all' || PHASE === 'light') {
    console.log('── Fase ringan (paralel) ──');
    const light = await runPhase(LIGHTWEIGHT, false);
    all.push(...light);
    persistLogs(light);

    if (exitCodeFor(light) !== 0) {
      skipped.push(...HEAVYWEIGHT);
      console.log('\n✘ Fase ringan gagal — fase berat DIBATALKAN (sesuai protokol).');
      writeFileSafe(REPORT, `<!-- ${ignoreNote} -->\n` + buildReport(all, skipped), { mode: 'overwrite', eol: 'lf' });
      return 1;
    }
    console.log('✔ Fase ringan hijau\n');
  }

  if (PHASE === 'all' || PHASE === 'heavy') {
    console.log(`── Fase berat (${HEAVY_SERIAL ? 'berurutan' : 'paralel'}) ──`);
    const heavy = await runPhase(HEAVYWEIGHT, HEAVY_SERIAL);
    all.push(...heavy);
    persistLogs(heavy);

    // Retry flake SESUDAH fase berat selesai: saat itu hanya satu proses berat yang hidup,
    // jadi hasilnya benar-benar memisahkan kontensi CPU dari kegagalan kode (§6.7).
    const testResult = all.find((r) => r.gate.id === 'test');
    if (testResult) {
      const lastGood = readLastGoodCount();
      if (lastGood !== null) console.log(`i patokan jumlah tes sehat tersimpan: ${lastGood}`);
      await maybeRetryFlake(testResult, lastGood);
      settleLastGoodCount(testResult);
    }
  }

  const code = exitCodeFor(all);
  writeFileSafe(REPORT, `<!-- ${ignoreNote} -->\n` + buildReport(all, skipped), { mode: 'overwrite', eol: 'lf' });
  const totalS = ((Date.now() - started) / 1000).toFixed(1);
  console.log(`\n${code === 0 ? '✔ SEMUA GATE HIJAU' : '✘ ADA GATE GAGAL'} — total ${totalS}s`);
  console.log(`  laporan: test-results/parallel-gate-report.md`);
  if (all.some((r) => r.retry)) console.log('  log retry: test-results/gate-test-retry.log');
  return code;
}

process.exitCode = PHASE_OK ? await run() : 1;
