#!/usr/bin/env node
/**
 * mcp-readonly-gate.mjs — Gate deteksi tool mutasi MCP (lapis kedua).
 *
 * Bagian dari AGENTS.md §0.28.8 (Pre-flight check wajib sebelum pakai MCP).
 *
 * BUKAN pengganti mode read-only konektor (§0.28.5). Mode read-only menyembunyikan
 * tool mutasi di sisi klien/server; skrip ini HANYA memeriksa dump enumerasi yang
 * sudah tersimpan di disk dan berteriak bila menemukan nama kategori B. Ia tidak
 * menegakkan apa pun sendiri — sesi tetap wajib menghormati exit code-nya
 * (§0.28.8 langkah 4: exit != 0 → STOP, jangan panggil tool MCP apa pun).
 *
 * Kontrak:
 *   node scripts/mcp-readonly-gate.mjs <dump.json>
 *   exit 0 — bersih,  cetak: OK — N tool read-only, 0 mutasi
 *   exit 1 — MERAH,  ada tool kategori B ATAU dump kosong (fail-closed)
 *   exit 2 — usage,  tanpa argumen / file tak terbaca / JSON rusak
 *
 * Tanpa dependensi, tanpa jaringan, tanpa memanggil MCP.
 * Node 20+.
 */

import fs from 'node:fs';

/* ------------------------------------------------------------------ *
 * Kategori B — allowlist LARANGAN (hardcode), disalin dari §0.28.2.
 * Union lintas konektor: nama yang sama boleh muncul di lebih dari satu
 * konektor (mis. create_project di Supabase dan Sentry).
 * ------------------------------------------------------------------ */

const BAN_BY_CONNECTOR = {
  supabase: [
    'apply_migration',
    'execute_sql',
    'create_branch',
    'rebase_branch',
    'merge_branch',
    'reset_branch',
    'delete_branch',
    'create_project',
    'pause_project',
    'restore_project',
    'deploy_edge_function',
  ],
  sentry: [
    'update_issue',
    'update_project',
    'update_alert_rule',
    'update_metric_monitor',
    'update_dsn',
    'delete_alert_rule',
    'delete_metric_monitor',
    'remove_team_from_project',
    'unlink_issue',
    'execute_sentry_tool',
    'create_alert_rule',
    'create_metric_monitor',
    'create_project',
    'create_dsn',
    'create_team',
    'add_team_to_project',
    'link_issue',
    'add_issue_note',
    'analyze_issue_with_seer',
  ],
  linear: [
    'save_project',
    'save_status_update',
    'delete_status_update',
    'create_issue_label',
  ],
};

/** Union seluruh nama terlarang. */
const BAN = new Set(Object.values(BAN_BY_CONNECTOR).flat());

/** Nama mana saja yang dilarang di konektor mana — untuk pesan error. */
function bannedUnder(name) {
  return Object.entries(BAN_BY_CONNECTOR)
    .filter(([, list]) => list.includes(name))
    .map(([connector]) => connector);
}

const USAGE = `Usage:
  node scripts/mcp-readonly-gate.mjs <dump.json>

<dump.json> = hasil enumerasi search_mcp_tools / search_sentry_tools dalam bentuk:
  [ {..}, {..} ]                         atau
  { "tools": [ {..} ] }                  atau
  { "supabase": { "tools": [ {..} ] },
    "sentry":    { "tools": [ {..} ] },
    "linear":    { "tools": [ {..} ] } }

Exit:
  0  bersih  -> "OK — N tool read-only, 0 mutasi"
  1  MERAH   -> ada tool kategori B, atau dump kosong (fail-closed)
  2  usage   -> tanpa argumen / file tak terbaca / JSON rusak

Gate §0.28.8 (AGENTS.md). BUKAN pengganti mode read-only konektor (§0.28.5).`;

/* ------------------------------------------------------------------ *
 * Normalisasi input
 * ------------------------------------------------------------------ */

/** Terima boolean apa pun: true/false atau "true"/"false". */
function boolVal(v) {
  if (typeof v === 'boolean') return v;
  if (v === 'true') return true;
  if (v === 'false') return false;
  return undefined; // tidak ada / tidak terbaca → dianggap tidak ada flag
}

/**
 * Ekstrak daftar tool dari dump, menormalkan tiga bentuk yang didokumentasikan
 * di USAGE. Mengembalikan [{ connector, tool }].
 */
function extractTools(input) {
  const out = [];

  if (Array.isArray(input)) {
    for (const tool of input) out.push({ connector: null, tool });
    return out;
  }

  if (!input || typeof input !== 'object') return out;

  // Bentuk { tools: [...] } — connector tidak diketahui dari dump itu sendiri.
  if (Array.isArray(input.tools)) {
    for (const tool of input.tools) out.push({ connector: null, tool });
    return out;
  }

  // Bentuk { <connector>: { tools: [...] } } — juga { <connector>: [...] }.
  for (const [connector, val] of Object.entries(input)) {
    if (Array.isArray(val)) {
      for (const tool of val) out.push({ connector, tool });
    } else if (val && typeof val === 'object' && Array.isArray(val.tools)) {
      for (const tool of val.tools) out.push({ connector, tool });
    }
  }
  if (out.length > 0) return out;

  // Fallback: { <toolName>: <descriptor> }.
  for (const [name, val] of Object.entries(input)) {
    if (val && typeof val === 'object') out.push({ connector: null, tool: { ...val, name } });
  }
  if (out.length > 0) return out;

  // Fallback terakhir: satu tool descriptor tunggal { name, readOnly, ... }.
  if (typeof input.name === 'string' || typeof input.toolName === 'string') {
    out.push({ connector: null, tool: input });
  }
  return out;
}

function toolName(tool) {
  if (typeof tool === 'string') return tool;
  if (!tool || typeof tool !== 'object') return null;
  const raw = tool.name ?? tool.toolName ?? tool.id;
  return typeof raw === 'string' && raw.trim() ? raw.trim() : null;
}

/**
 * Deteksi per tool → null (lolos) atau { name, sources[] }.
 * Dua jalur deteksi:
 *   hardcode — nama ada di allowlist larangan §0.28.2
 *   flag     — readOnly===false ATAU destructive===true (menangkap tool baru
 *              yang belum masuk hardcode). Membaca kedua ejaan: `readOnly`/
 *              `destructive` (katalog Supabase) dan `readOnlyHint`/
 *              `destructiveHint` (katalog Sentry, MCP annotation).
 */
function detect(connector, tool) {
  const name = toolName(tool);
  if (!name) {
    return { name: '<tanpa-nama>', sources: ['flag (entri tak terbaca — fail-closed)'] };
  }

  const sources = [];

  if (BAN.has(name)) {
    const under = bannedUnder(name);
    const scope = under.length ? ` [${under.join(', ')}]` : '';
    sources.push(`hardcode (§0.28.2${scope})`);
  }

  if (tool && typeof tool === 'object') {
    const readOnly = boolVal(tool.readOnly ?? tool.readOnlyHint);
    const destructive = boolVal(tool.destructive ?? tool.destructiveHint);
    const flags = [];
    if (readOnly === false) flags.push('readOnly=false');
    if (destructive === true) flags.push('destructive=true');
    if (flags.length > 0) sources.push(`flag (${flags.join(', ')})`);
  } else if (typeof tool !== 'string') {
    sources.push('flag (entri bukan objek — tidak bisa diverifikasi)');
  }

  if (sources.length === 0) return null;
  return { name, connector, sources };
}

/* ------------------------------------------------------------------ *
 * Main
 * ------------------------------------------------------------------ */

function main() {
  const file = process.argv[2];

  if (!file) {
    console.error(USAGE);
    process.exit(2);
  }

  let raw;
  try {
    raw = fs.readFileSync(file, 'utf8');
  } catch (err) {
    console.error(`Tidak bisa membaca dump: ${file}\n  ${err.message}\n\n${USAGE}`);
    process.exit(2);
  }

  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch (err) {
    console.error(`JSON rusak di ${file}\n  ${err.message}\n\n${USAGE}`);
    process.exit(2);
  }

  const entries = extractTools(parsed);

  // Fail-closed: dump kosong TIDAK membuktikan ketiadaan tool mutasi.
  // Bukti nyata: query search_mcp_tools pernah mengembalikan {"tools":[]}
  // (§0.28.6) padahal tool mutasinya ada. Dump kosong = hijau palsu.
  if (entries.length === 0) {
    console.error(
      `MERAH — dump kosong / bentuk tidak dikenali: ${file}\n` +
        `  0 tool terbaca, jadi ketiadaan tool mutasi TIDAK terbukti (fail-closed).\n` +
        `  Exit != 0 → STOP. Jangan panggil tool MCP apa pun di sesi ini (§0.28.8 langkah 4).`,
    );
    process.exit(1);
  }

  const hits = [];
  for (const { connector, tool } of entries) {
    const hit = detect(connector, tool);
    if (hit) hits.push(hit);
  }

  if (hits.length === 0) {
    console.log(`OK — ${entries.length} tool read-only, 0 mutasi`);
    process.exit(0);
  }

  const width = Math.max(...hits.map((h) => h.name.length), 4);
  console.error(`MERAH — ${hits.length} tool mutasi terdeteksi di ${file}:`);
  for (const hit of hits) {
    const where = hit.connector ? ` (${hit.connector})` : '';
    console.error(`  - ${hit.name.padEnd(width)}${where}  sumber: ${hit.sources.join(' + ')}`);
  }
  console.error('');
  console.error(`  ${hits.length} dari ${entries.length} tool ditolak.`);
  console.error('  Exit != 0 → STOP. Jangan panggil tool MCP apa pun di sesi ini (§0.28.8 langkah 4).');
  console.error('  Laporkan nama tool yang bocor ke Work Queue (P2-F14-AO).');
  process.exit(1);
}

main();
