#!/usr/bin/env node
/**
 * verify-no-local-db-client.mjs — P2-F14-AV + P2-F14-AW: guard anti-koneksi-lokal.
 *
 * KENAPA ADA
 *   P2-F14-AS/AU memberantas pola "pg.Client per-test tanpa timeout" dari file test
 *   (akar flaky DB-live: STACK_TRACE_ERROR durasi ~5000ms). Fix-nya benar, tapi tidak
 *   ada gerbang yang mencegah pola itu muncul lagi — developer baru menulis
 *   `new Client(...)` atau `import { Client } dari 'pg'` di scope → tidak ada yang
 *   menangkap. Guard yang diam = guard palsu (§0.19), jadi pola itu dijadikan exit code.
 *
 * SCOPE — direktori, BUKAN exempt per-file (P2-F14-AW, keputusan desain user)
 *   Scan default: tests/unit/ + tests/integration/ (selama ada) — kelas flaky vitest.
 *   tests/e2e/, tests/a11y/, tests/performance/ KELUAR sepenuhnya dari scan
 *   (bukan WARN, bukan exempt): model eksekusinya beda (Playwright punya
 *   test-timeout runner sendiri; bench CLI = 1 koneksi per run), bukan kelas
 *   flaky vitest 5s. Argumen path = force check apapun lokasinya (audit terarah).
 *
 * DEFINISI PELANGGARAN (P2-F14-AW: bentuk member ikut di-hardening)
 *   1. `new Client(`, `new Pool(`, `new pg.Client(`, `new pg.Pool(` di scope —
 *      KECUALI tests/helpers/db.ts (rumah pool bersama, hasil fix P2-F14-AS).
 *   2. import bernama `{ Client }` / `{ Pool }` dari 'pg' di scope — KECUALI
 *      tests/helpers/db.ts.
 *   Deteksi per baris (parsing sederhana, tanpa regex rapuh): komentar blok/baris
 *   di-strip dulu, whitespace dinormalkan supaya `new  Client (` tetap ketahuan,
 *   import multi-baris diakumulasi sampai pernyataan lengkap (`from 'pg'` / `;`).
 *
 * CELAH SADAR — sengaja TIDAK dikejar (YAGNI; menambah kompleksitas tanpa nilai)
 *   - instansiasi multi-baris `new\nClient(` / `new\npg.Client(`
 *   - destructuring `const { Client } = pg` tanpa instansiasi
 *
 * PEMAKAIAN
 *   node scripts/verify-no-local-db-client.mjs                # scan tests/unit + tests/integration
 *   node scripts/verify-no-local-db-client.mjs <path> [...]   # force check path tertentu (file/dir)
 *   npm run verify:no-local-db-client
 *
 * Exit 1 = ada pelanggaran, 0 = bersih.
 */
import fs from 'node:fs';
import path from 'node:path';

const W = {
  pass: '\x1b[32m',
  fail: '\x1b[31m',
  warn: '\x1b[33m',
  dim: '\x1b[2m',
  off: '\x1b[0m',
};

/** Satu-satunya file di tests/ yang boleh memegang koneksi pg (rumah pool bersama). */
const ALLOWED = new Set(['tests/helpers/db.ts']);
const EXT = new Set(['.ts', '.tsx', '.mts', '.cts', '.js', '.jsx', '.mjs']);
const SKIP_DIRS = new Set(['node_modules', 'dist', '.git', '.vitest']);
/** Batas akumulasi statement import multi-baris sebelum dievaluasi/dibuang. */
const IMPORT_MAX_LINES = 12;

/**
 * Scope default = direktori kelas flaky vitest (P2-F14-AW). tests/e2e, tests/a11y,
 * tests/performance sengaja DI LUAR scan (bukan WARN, bukan exempt). tests/integration
 * ikut otomatis selama direktorinya ada (filter di bawah membuang yang tidak ada).
 */
const DEFAULT_DIRS = ['tests/unit', 'tests/integration'].filter((d) => fs.existsSync(d));
const argv = process.argv.slice(2);
// Argumen path = force check apapun lokasinya (audit terarah); tanpa argumen = scope direktori.
const roots = argv.length > 0 ? argv : DEFAULT_DIRS;

function collect(p, out = []) {
  const st = fs.statSync(p, { throwIfNoEntry: false });
  if (!st) {
    console.error(`${W.fail}FATAL${W.off} path tidak ada: ${p}`);
    process.exit(1);
  }
  if (st.isDirectory()) {
    for (const e of fs.readdirSync(p, { withFileTypes: true })) {
      if (e.isDirectory()) {
        if (!SKIP_DIRS.has(e.name)) collect(path.join(p, e.name), out);
      } else if (EXT.has(path.extname(e.name))) {
        out.push(path.join(p, e.name));
      }
    }
  } else {
    out.push(p);
  }
  return out;
}

/** Evaluasi satu pernyataan import lengkap — kembalikan nama banned bila import bernama Client/Pool dari 'pg'. */
function importBannedName(text) {
  if (!/from\s+['"`]pg['"`]/.test(text)) return null;
  const o = text.indexOf('{');
  const c = text.lastIndexOf('}');
  if (o === -1 || c === -1 || c < o) return null;
  for (const rawName of text.slice(o + 1, c).split(',')) {
    const words = rawName.trim().split(/\s+/).filter(Boolean);
    if (words[0] === 'type') words.shift();
    if (words[0] === 'Client' || words[0] === 'Pool') return words[0];
  }
  return null;
}

function pushImportHit(hits, imp, raw) {
  const banned = importBannedName(imp.text);
  if (banned) {
    hits.push({
      line: imp.start,
      kind: 'violation',
      raw,
      why: `import { ${banned} } dari 'pg' — koneksi lokal per-test (hanya tests/helpers/db.ts yang diizinkan)`,
    });
  }
}

function scanFile(file) {
  const lines = fs.readFileSync(file, 'utf8').split(/\r?\n/);
  const hits = [];
  let inBlock = false;
  let imp = null;

  for (let i = 0; i < lines.length; i++) {
    let line = lines[i];

    // 1) komentar blok multi-baris — sisa baris yang berada di dalam blok dibuang
    if (inBlock) {
      const end = line.indexOf('*/');
      if (end === -1) line = '';
      else {
        line = line.slice(end + 2);
        inBlock = false;
      }
    }
    const open = line.indexOf('/*');
    if (open !== -1) {
      const close = line.indexOf('*/', open + 2);
      if (close === -1) {
        inBlock = true;
        line = line.slice(0, open);
      } else {
        line = line.slice(0, open) + ' ' + line.slice(close + 2);
      }
    }

    // 2) komentar baris — '//' hanya di posisi awal / setelah whitespace
    //    (pola '://' dalam URL TIDAK dianggap komentar)
    for (let j = 0; j < line.length - 1; j++) {
      if (line[j] === '/' && line[j + 1] === '/' && (j === 0 || /\s/.test(line[j - 1]))) {
        line = line.slice(0, j);
        break;
      }
    }

    const t = line.trim();

    // 3) instansiasi — 4 bentuk (plain + member pg.); whitespace dinormalkan: `new  Client (` → `new Client(`
    const norm = t.replace(/\s+/g, ' ').replace(/\s+\(/g, '(');
    if (norm.includes('new Client(')) {
      hits.push({
        line: i,
        kind: 'violation',
        raw: t,
        why: 'new Client( — koneksi lokal per-test (hanya tests/helpers/db.ts yang diizinkan)',
      });
    } else if (norm.includes('new Pool(')) {
      hits.push({
        line: i,
        kind: 'violation',
        raw: t,
        why: 'new Pool( — koneksi lokal per-test (hanya tests/helpers/db.ts yang diizinkan)',
      });
    } else if (norm.includes('new pg.Client(')) {
      hits.push({
        line: i,
        kind: 'violation',
        raw: t,
        why: 'new pg.Client( — bentuk member, koneksi lokal per-test (hanya tests/helpers/db.ts yang diizinkan)',
      });
    } else if (norm.includes('new pg.Pool(')) {
      hits.push({
        line: i,
        kind: 'violation',
        raw: t,
        why: 'new pg.Pool( — bentuk member, koneksi lokal per-test (hanya tests/helpers/db.ts yang diizinkan)',
      });
    }

    // 4) akumulasi import multi-baris → evaluasi saat pernyataan lengkap
    if (imp) {
      imp.text += ' ' + t;
      const done =
        /from\s+['"`]pg['"`]/.test(imp.text) || imp.text.includes(';') || t === '';
      if (done || i - imp.start > IMPORT_MAX_LINES) {
        pushImportHit(hits, imp, imp.text);
        imp = null;
      }
      continue;
    }
    if (/^import\b/.test(t)) {
      imp = { start: i, text: t };
      const done = /from\s+['"`]pg['"`]/.test(imp.text) || imp.text.includes(';');
      if (done) {
        pushImportHit(hits, imp, t);
        imp = null;
      }
    }
  }
  return hits;
}

console.log(
  `\n=== verify:no-local-db-client — P2-F14-AV/AW (anti koneksi DB lokal per-test) ===\n`,
);
console.log(`  scope : ${roots.join(', ')}`);

const files = [];
for (const r of roots) collect(r, files);

let checked = 0;
let allowedCount = 0;
let violations = 0;

for (const f of files) {
  const rel = path.relative(process.cwd(), f).split(path.sep).join('/');
  if (ALLOWED.has(rel)) {
    allowedCount++;
    console.log(`  ${W.dim}SKIP${W.off}  ${rel} — diizinkan (rumah pool bersama, fix P2-F14-AS)`);
    continue;
  }
  checked++;
  const hits = scanFile(f);
  for (const h of hits) {
    const loc = `${rel}:${h.line + 1}`;
    violations++;
    console.log(`  ${W.fail}PELANGGARAN${W.off} ${loc}`);
    console.log(`              isi: ${h.raw}`);
    console.log(`              ${h.why}`);
  }
}

console.log(
  `\n=== RINGKASAN: ${violations} pelanggaran (${checked} file dicek, ${allowedCount} diizinkan) ===`,
);
if (violations > 0) {
  console.error(
    `${W.fail}verify:no-local-db-client GAGAL${W.off} — ada pola koneksi lokal per-test ` +
      `(new Client/new Pool/new pg.Client/new pg.Pool/import {Client,Pool} dari 'pg'). ` +
      `Pindahkan ke withDb bersama (tests/helpers/db.ts).`,
  );
  process.exit(1);
}
console.log(
  `${W.pass}verify:no-local-db-client OK${W.off} — tidak ada new Client/new Pool/` +
    `new pg.Client/new pg.Pool/import {Client,Pool} dari 'pg' di luar tests/helpers/db.ts.\n`,
);
process.exit(0);


