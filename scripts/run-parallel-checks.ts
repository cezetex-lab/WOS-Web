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
 * Runner: Node >= 24 menjalankan `.ts` native (type stripping). `tsx`/`vite-node` tidak
 * dipakai di repo ini. Di Windows, `npm` adalah `npm.cmd` sehingga spawn butuh `shell`.
 *
 * Pemakaian:
 *   node scripts/run-parallel-checks.ts                 # light → heavy (default)
 *   node scripts/run-parallel-checks.ts --phase light    # hanya check:types + lint
 *   node scripts/run-parallel-checks.ts --heavy-serial   # test lalu build, berurutan
 *   node scripts/run-parallel-checks.ts --verbose        # streaming output penuh
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
}

function tail(text: string, maxLines: number): string {
  const lines = text.replace(/\r\n/g, '\n').split('\n').filter((l) => l.trim() !== '');
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
      resolve({ gate, code, signal, timedOut, durationMs, output });
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

function verdictOf(r: GateResult): string {
  if (r.timedOut) return `TIMEOUT (> ${Math.round(r.gate.timeoutMs / 1000)}s)`;
  return r.code === 0 ? 'PASS' : `FAIL (exit ${r.code})`;
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
  lines.push('| Gate | Perintah | Hasil | Durasi |');
  lines.push('|---|---|---|---|');
  for (const r of all) {
    lines.push(`| ${r.gate.label} | \`npm ${r.gate.args.join(' ')}\` | ${verdictOf(r)} | ${(r.durationMs / 1000).toFixed(1)}s |`);
  }
  for (const g of skipped) {
    lines.push(`| ${g.label} | \`npm ${g.args.join(' ')}\` | TIDAK DIJALANKAN (fase ringan gagal) | — |`);
  }
  lines.push('');

  const failed = all.filter((r) => r.code !== 0 || r.timedOut);
  if (failed.length === 0) {
    lines.push('## Status: SEMUA GATE HIJAU', '');
    lines.push('Urutan bertahap dipakai karena alasan §6.7 (`ENVIRONMENT_TRAPS.md`): vitest punya');
    lines.push('timeout keras 60s untuk pool runner-nya, dan menyalakan 4 gate sekaligus di mesin');
    lines.push('ini membuat jumlah test turun tanpa baris error. Log mentah per gate:');
    lines.push(LIGHTWEIGHT.concat(HEAVYWEIGHT).map((g) => `\`test-results/gate-${g.id}.log\``).join(', ') + '.');
  } else {
    lines.push('## Status: ADA GATE GAGAL', '');
    for (const r of failed) {
      lines.push(`### ${r.gate.label} — ${verdictOf(r)}`, '');
      lines.push('```');
      lines.push(tail(r.output, 40));
      lines.push('```', '');
    }
    if (all.some((r) => r.gate.id === 'test' && /Failed to start threads worker|Timeout waiting for worker/i.test(r.output))) {
      lines.push('> Gejala \`Failed to start threads worker\` / \`Timeout waiting for worker to respond\` =');
      lines.push('> kontensi CPU (§6.7), bukan tes yang salah. Jalankan ulang dengan `--heavy-serial`.');
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
  return results.every((r) => r.code === 0 && !r.timedOut) ? 0 : 1;
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
  }

  const code = exitCodeFor(all);
  writeFileSafe(REPORT, `<!-- ${ignoreNote} -->\n` + buildReport(all, skipped), { mode: 'overwrite', eol: 'lf' });
  const totalS = ((Date.now() - started) / 1000).toFixed(1);
  console.log(`\n${code === 0 ? '✔ SEMUA GATE HIJAU' : '✘ ADA GATE GAGAL'} — total ${totalS}s`);
  console.log(`  laporan: test-results/parallel-gate-report.md`);
  return code;
}

process.exitCode = PHASE_OK ? await run() : 1;
