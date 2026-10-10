/**
 * numeric-claims-guard.test.ts — guard perilaku meta-guard verify:numeric (Fase-3 Level B)
 *
 * Pendekatan (keputusan user B2): SPAWN guard NYATA via child_process dengan
 * fixture registry + fixture .md — bukan duplikasi logika scan, bukan hardcode
 * nilai live (live value dibaca dari extractor yang sama lewat spawn node).
 * Tanpa Function/eval; tsc-strict safe (tidak import modul .mjs dari TS).
 */

import { describe, it, expect, afterAll } from 'vitest';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const ROOT = path.resolve(import.meta.dirname, '..', '..');
const GUARD = path.join(ROOT, 'scripts', 'verify-numeric-claims.mjs');

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'numeric-guard-'));

afterAll(() => {
  try { fs.rmSync(tmpDir, { recursive: true, force: true }); } catch { /* best-effort */ }
});

function writeFixture(name: string, content: string): string {
  const p = path.join(tmpDir, name);
  fs.writeFileSync(p, content, 'utf8');
  return p;
}

/** Baca nilai live dari extractor guard yang SAMA (tanpa hardcode, tanpa duplikasi). */
function liveFromExtractor(name: string): number {
  // Node resolve import relatif dari cwd → pakai cwd ROOT + specifier './scripts/...'
  const r = spawnSync(
    'node',
    ['-e', `import('./scripts/numeric-extractors.mjs').then(m => console.log(m.extractors[${JSON.stringify(name)}]()))`],
    { encoding: 'utf8', cwd: ROOT, timeout: 30000, maxBuffer: 10 * 1024 * 1024 },
  );
  const out = (r.stdout as string).trim();
  const n = Number(out);
  if (!Number.isFinite(n)) throw new Error(`extractor ${name} tidak mengembalikan angka: ${out}`);
  return n;
}

/** Jalankan guard nyata; kembalikan { status, output }. Status != 0/1/2 = kegagalan tak terduga. */
/* FIX B2-harness 2026-10-09 (Opsi A): spawnSync — status eksplisit, tidak throw.
   exit 1 (drift) = hasil sah yang di-assert, bukan exception. stdout+stderr digabung
   karena guard mencetak FATAL via console.error. timeout 30s + maxBuffer 10MB. */
function runGuard(registryPath: string, files: string[]): { status: number; stdout: string } {
  const r = spawnSync('node', [GUARD, `--registry=${registryPath}`, `--files=${files.join(',')}`], {
    encoding: 'utf8',
    cwd: ROOT,
    timeout: 30000,
    maxBuffer: 10 * 1024 * 1024,
  });
  return { status: r.status ?? -1, stdout: (r.stdout as string) + (r.stderr as string) };
}

/** Registry fixture minimal dengan satu entry fs-walk (live = unit-files). */
function registryFixture(entries: unknown[], archiveFiles: string[] = []): string {
  return writeFixture(`reg-${Math.random().toString(36).slice(2)}.json`, JSON.stringify({ version: 2, archiveFiles, entries }));
}

describe('verify:numeric registry loader', () => {
  it('registry corrupt (tanpa source) → guard exit 2, bukan hijau diam', () => {
    const bad = writeFixture('reg-bad.json', JSON.stringify({
      version: 2,
      entries: [{ id: 'x', label: 'x', modes: ['eq'], claimPatterns: [{ regex: '(\\d+)' }], category: 'live-guarded', runIf: { needDb: false } }],
    }));
    const res = runGuard(bad, []);
    expect(res.status).toBe(2);
    expect(res.stdout).toContain('tidak valid');
  });

  it('registry nyata (scripts/numeric-claims-registry.json) tervalidasi shape-nya', () => {
    const real = path.join(ROOT, 'scripts', 'numeric-claims-registry.json');
    // file md apa pun boleh — validasi gagal = exit 2 sebelum scan
    const res = runGuard(real, [path.join(ROOT, 'ARCHITECTURE.md')]);
    expect([0, 1]).toContain(res.status); // valid = scan jalan (0 hijau / 1 drift)
    expect(res.stdout).not.toContain('tidak valid');
  });
});

describe('verify:numeric perilaku terhadap drift (guard TIDAK DIAM)', () => {
  const entryUnitFiles = {
    id: 'fixture-unit-files',
    label: 'Fixture unit files',
    modes: ['eq'],
    claimPatterns: [{ regex: '\\| Fixture \\| (\\d+) \\|', group: 1 }],
    source: { type: 'fs-walk', extractorName: 'unit-files' },
    scope: { scanAllTracked: true },
    category: 'live-unguarded',
    existingGuard: [],
    verifyAfter: 'post-test',
    runIf: { needDb: false, needGit: false, needFilesystem: true },
  };

  it('klaim live-unguarded TIDAK cocok live → exit 1 + DRIFT (bukan diam)', () => {
    const live = liveFromExtractor('unit-files');
    const md = writeFixture('drift.md', `| Fixture | ${live + 999} |`);
    const reg = registryFixture([entryUnitFiles]);
    const res = runGuard(reg, [md]);
    expect(res.status).toBe(1);
    expect(res.stdout).toContain('DRIFT');
    expect(res.stdout).toContain(`claim=${live + 999}`);
  });

  it('klaim live-unguarded SINKRON dengan live → exit 0 (hijau)', () => {
    const live = liveFromExtractor('unit-files');
    const md = writeFixture('sync.md', `| Fixture | ${live} |`);
    const reg = registryFixture([entryUnitFiles]);
    const res = runGuard(reg, [md]);
    expect(res.status).toBe(0);
    expect(res.stdout).toContain('OK');
    expect(res.stdout).not.toContain('DRIFT');
  });

  it('file dalam archiveFiles TIDAK di-drift-check (arsip = skip)', () => {
    const live = liveFromExtractor('unit-files');
    const mdAbs = path.join(tmpDir, 'arsip-snapshot.md');
    const md = writeFixture('arsip-snapshot.md', `| Fixture | ${live + 999} |`);
    // Guard membandingkan string path corpus vs archiveFiles apa adanya → daftarkan path absolut identik.
    const reg = registryFixture([entryUnitFiles], [mdAbs]);
    const res = runGuard(reg, [md]);
    expect(res.status).toBe(0);
    expect(res.stdout).not.toContain('DRIFT');
  });

  it('klaim external-snapshot → WARN (bukan drift), exit 0', () => {
    const entry = {
      id: 'fixture-e2e',
      label: 'Fixture E2E',
      modes: ['skip'],
      claimPatterns: [{ regex: 'E2E[^|]*(\\d+)/(\\d+)\\s*passed', group: 1 }],
      source: { type: 'external-snapshot' },
      scope: { scanAllTracked: true },
      category: 'external-snapshot',
      existingGuard: [],
      verifyAfter: 'post-test',
      runIf: { needDb: false, needGit: false, needFilesystem: false },
    };
    const md = writeFixture('e2e.md', 'E2E 99/99 passed');
    const reg = registryFixture([entry]);
    const res = runGuard(reg, [md]);
    expect(res.status).toBe(0);
    expect(res.stdout).toContain('WARN');
    expect(res.stdout).not.toContain('DRIFT');
  });

  it('klaim ambiguous → WARN (bukan drift), exit 0', () => {
    const entry = {
      id: 'fixture-ambiguous',
      label: 'Fixture ambiguous',
      modes: ['skip'],
      claimPatterns: [{ regex: '\\| Ambig \\| (\\d+) \\|', group: 1 }],
      source: { type: 'external-snapshot' },
      scope: { scanAllTracked: true },
      category: 'ambiguous',
      existingGuard: [],
      verifyAfter: 'git-add',
      runIf: { needDb: false, "needGit": false, needFilesystem: false },
    };
    const md = writeFixture('ambig.md', '| Ambig | 12345 |');
    const reg = registryFixture([entry]);
    const res = runGuard(reg, [md]);
    expect(res.status).toBe(0);
    expect(res.stdout).toContain('WARN');
    expect(res.stdout).toContain('ambiguous');
    expect(res.stdout).not.toContain('DRIFT');
  });

  it('mode gte: claim <= live → OK; claim > live → DRIFT', () => {
    const live = liveFromExtractor('unit-files');
    const entry = {
      id: 'fixture-gte',
      label: 'Fixture gte',
      modes: ['gte'],
      claimPatterns: [{ regex: '\\| Gte \\| (\\d+) \\|', group: 1 }],
      source: { type: 'fs-walk', extractorName: 'unit-files' },
      scope: { scanAllTracked: true },
      category: 'live-unguarded',
      existingGuard: [],
      verifyAfter: 'git-add',
      runIf: { needDb: false, needGit: false, needFilesystem: true },
    };
    const okMd = writeFixture('gte-ok.md', `| Gte | ${live - 1 < 0 ? live : live - 1} |`);
    const badMd = writeFixture('gte-bad.md', `| Gte | ${live + 999} |`);
    const reg = registryFixture([entry]);
    expect(runGuard(reg, [okMd]).status).toBe(0);
    expect(runGuard(reg, [badMd]).status).toBe(1);
  });

  it('baris ber-marker [snapshot:<hash>] di-skip + tercatat (bukan drift, bukan silent)', () => {
    const live = liveFromExtractor('unit-files');
    const entry = {
      id: 'fixture-snapshot',
      label: 'Fixture snapshot',
      modes: ['eq'],
      claimPatterns: [{ regex: '\\| Snap \\| (\\d+) \\|', group: 1 }],
      source: { type: 'fs-walk', extractorName: 'unit-files' },
      scope: { scanAllTracked: true },
      category: 'live-unguarded',
      existingGuard: [],
      verifyAfter: 'git-add',
      runIf: { needDb: false, needGit: false, needFilesystem: true },
    };
    // Nilai sengaja beda dari live — tanpa marker ini DRIFT; dengan marker → skip.
    const md = writeFixture('snap.md', `| Snap | ${live + 999} | [snapshot:abc1234]`);
    const reg = registryFixture([entry]);
    const res = runGuard(reg, [md]);
    expect(res.status).toBe(0);
    expect(res.stdout).not.toContain('DRIFT');
    expect(res.stdout).toContain('SKIPPED');
    expect(res.stdout).toContain('[snapshot:abc1234]');
  });
});
