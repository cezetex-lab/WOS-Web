#!/usr/bin/env node
/**
 * generate-baseline-data.mjs — data REFERENSI + cap registry untuk instalasi baru.
 *
 * Skema saja tidak cukup untuk perusahaan baru: tanpa `module_definitions` tidak ada
 * menu/route (DynamicRoutes + menu-builder membaca tabel itu), tanpa `admin_roles` /
 * `role_page_access` / `permission_set_items` tidak ada authz. Tapi data karyawan,
 * PII, dan transaksi TIDAK boleh ikut.
 *
 * Karena itu whitelist di bawah bersifat eksplisit: hanya tabel konfigurasi/referensi.
 * Semua tabel lain (employees_*, audit_log, sessions, forum_*, hr_okrs, dll.)
 * sengaja TIDAK didump — pemasangan di perusahaan baru mulai dari data kosong.
 *
 * Berkas keluaran juga men-CAP `schema_migrations` untuk SELURUH berkas migrasi repo,
 * supaya operator tidak pernah tergoda me-replay 000..NNN di atas baseline (itu akan
 * hancur — lihat AGENTS.md §5.8 SQL-01) dan supaya migrasi BARU (>228) berjalan
 * incremental lewat `npm run db:migrate`.
 *
 * Pemakaian:
 *   node supabase/scripts/generate-baseline-data.mjs
 *   node supabase/scripts/generate-baseline-data.mjs --out /tmp/data.sql
 */
import fs from 'node:fs';
import path from 'node:path';
import { migrationChecksum } from './migration-checksum.mjs';
import pg from 'pg';

const argv = process.argv.slice(2);
const arg = (name, def) => {
  const hit = argv.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : def;
};
const OUT = arg('out', 'supabase/baseline/010_baseline_config_data.sql');
// Nama perusahaan untuk baris `branding`. TIDAK diambil dari DB sumber: branding adalah
// konfigurasi OWNER (AGENTS.md §3.9), jadi perusahaan baru tidak boleh mewarisi merek
// kita. Ganti di sini saat generate, atau nanti lewat OwnerDashboard → 🎨 Branding.
const COMPANY_NAME = arg('company-name', 'Perusahaan Anda');

// Baris yang JANGAN diwariskan ke perusahaan baru, per tabel.
//
// `company_config.owner_email` dan `ceo_email` berisi alamat email PERUSAHAAN SUMBER.
// Bahayanya bukan sekadar kosmetik: `owner_login()` menerima hanya email yang sama
// dengan `get_owner_email()`, jadi perusahaan baru yang mewarisi baris ini menuntut
// email kita untuk masuk ke OwnerDashboard-nya sendiri. Nilainya diisi operator lewat
// `--owner-email=` pada installer (atau OwnerDashboard) setelah instalasi.
const EXCLUDED_ROWS = {
  company_config: { kolom: 'config_key', nilai: ['owner_email', 'ceo_email'] },
};

// Urutan sudah memenuhi FK: business_units & module_definitions & config_categories
// harus lebih dulu daripada business_unit_modules / company_config.
const CONFIG_TABLES = [
  'business_units',
  'module_definitions',
  'config_categories',
  'company_config',
  'business_unit_modules',
  'master_divisions',
  'master_positions',
  'master_locations',
  'master_employment_status',
  'role_page_access',
  'role_permission_sets',
  'permission_set_items',
  'admin_roles',
  'validation_rules',
  'notification_config',
  'hr_document_types',
  'tier_pricing',
  // 'branding' SENGAJA tidak ikut: barisnya di-emit terpisah dengan nilai netral
  // (lihat blok "branding" di bawah) supaya merek DB sumber tidak menular ke
  // perusahaan baru.
];

const ROOT = process.cwd();
const URL = fs
  .readFileSync(path.join(ROOT, '.env.local'), 'utf8')
  .split(/\r?\n/)
  .find((l) => /^\s*DATABASE_URL\s*=/.test(l))
  .slice(13)
  .trim()
  .replace(/^["']|["']$/g, '');

const c = new pg.Client({ connectionString: URL, ssl: { rejectUnauthorized: false } });
await c.connect();
const q = async (sql, p = []) => (await c.query(sql, p)).rows;
const ident = (n) => (/^[a-z_][a-z0-9_]*$/.test(n) ? n : `"${n.replace(/"/g, '""')}"`);
const lit = (s) => `'${String(s).replace(/'/g, "''")}'`;

// Nilai dikembalikan sebagai teks oleh SQL, jadi formatnya deterministik.
const TEXTY = new Set(['text', 'character varying', 'character', 'name', 'uuid', 'jsonb', 'json', 'date', 'timestamp with time zone', 'timestamp without time zone']);
const NUMERICY = new Set(['integer', 'bigint', 'smallint', 'numeric', 'double precision', 'real']);
const BOOLY = new Set(['boolean']);

function fmt(value, udt) {
  if (value === null || value === undefined) return 'NULL';
  if (BOOLY.has(udt)) return value === 't' ? 'true' : 'false';
  if (NUMERICY.has(udt)) return value;
  if (udt === 'jsonb' || udt === 'json') return `${lit(value)}::${udt}`;
  if (udt === 'date') return `${lit(value)}::date`;
  if (udt.startsWith('timestamp')) return `${lit(value)}::timestamptz`;
  return lit(value);
}

const out = [];
const emit = (s = '') => out.push(s);

emit(`-- ================================================================`);
emit(`-- BASELINE DATA REFERENSI + CAP REGISTRY MIGRASI`);
emit(`-- ================================================================`);
emit(`--`);
// Sama seperti generator skema: connection string DB sumber tidak ikut ditulis ke
// artefak yang akan dipasang di perusahaan lain (§3.16), sekaligus menjaga secret scan
// tetap bersih di jalur pre-commit §0.6.
emit('-- Sumber    : DB live (host, project ref & password sengaja TIDAK ditulis)');
emit(`-- Generator : supabase/scripts/generate-baseline-data.mjs`);
emit(`--`);
emit(`-- JALANKAN SETELAH 000_baseline_schema.sql, sebagai role \`postgres\`.`);
emit(`--`);
emit(`-- ISI`);
emit(`--   * Baris tabel konfigurasi/referensi (menu, route, role, permission, config).`);
emit(`--   * Cap \`schema_migrations\` untuk seluruh berkas migrasi repo.`);
emit(`--`);
emit(`--   * Branding asli        : baris \`branding\` di-emit NETRAL (nama dari`);
emit(`--     \`--company-name\`, logo & warna dikosongkan) — merek DB sumber tidak menular.`);
emit(`--`);
emit(`-- YANG SENGAJA TIDAK ADA`);
emit(`--   * Data karyawan / PII  : employees_core, employees_extended, user_roles,`);
emit(`--     user_role_assignments, worker_passwords.`);
emit(`--   * Data transaksi       : attendance, payroll, overtime, audit_log, hr_okrs,`);
emit(`--     reviews_360, sessions, login_attempts, forum_*.`);
emit(`--   Perusahaan baru mulai dari data kosong lalu onboarding karyawannya sendiri.`);
emit(`--`);
emit(`-- KENAPA ADA CAP schema_migrations`);
emit(`--   Tanpa cap, operator akan mengira migrasi 000..NNN belum jalan lalu`);

const MIG_DIR = path.join(ROOT, 'supabase/migrations');
const migFiles = fs
  .readdirSync(MIG_DIR)
  .filter((f) => f.endsWith('.sql'))
  .sort((a, b) => (parseInt(a, 10) || 0) - (parseInt(b, 10) || 0) || a.localeCompare(b));

emit(`--   me-replay-nya di atas baseline. Replay itu HANCUR (86 berkas gagal — akar:`);
emit(`--   tidak ada migrasi yang men-seed karyawan, sehingga seed anak melanggar FK).`);
emit(`--`);
emit(`-- IDEMPOTEN: tiap tabel hanya diisi bila masih kosong.`);
emit('');
emit(`set client_min_messages = warning;`);
emit('');

let totalRows = 0;
for (const t of CONFIG_TABLES) {
  const exists = await q(`select 1 from information_schema.tables where table_schema='public' and table_name=$1`, [t]);
  if (!exists.length) {
    emit(`-- ${t}: dilewati (tabel tidak ada di DB sumber)`);
    emit('');
    continue;
  }
  const cols = await q(
    `select column_name, udt_name, is_generated
       from information_schema.columns
      where table_schema='public' and table_name=$1 and is_generated <> 'ALWAYS'
      order by ordinal_position`,
    [t],
  );
  const names = cols.map((x) => x.column_name);
  if (!names.length) continue;
  const selectList = cols.map((x) => {
    const udt = x.udt_name;
    if (BOOLY.has(udt) || NUMERICY.has(udt) || TEXTY.has(udt)) return `${ident(x.column_name)}::text as ${ident(x.column_name)}`;
    return `${ident(x.column_name)}::text as ${ident(x.column_name)}`;
  }).join(', ');
  let rows = await q(`select ${selectList} from public.${ident(t)}`);
  const excl = EXCLUDED_ROWS[t];
  const dibuang = [];
  if (excl) {
    for (const r of rows) {
      if (excl.nilai.includes(r[excl.kolom])) dibuang.push(r[excl.kolom]);
    }
    rows = rows.filter((r) => !excl.nilai.includes(r[excl.kolom]));
  }
  if (dibuang.length) {
    emit(`-- ${t}: ${dibuang.length} baris identitas perusahaan TIDAK didump (${dibuang.join(', ')})`);
    emit(`--   → diisi oleh installer (--owner-email=...) atau OwnerDashboard.`);
    emit('');
  }
  if (!rows.length) {
    emit(`-- ${t}: 0 baris, tidak ada yang didump`);
    emit('');
    continue;
  }
  totalRows += rows.length;
  emit(`-- ── ${t} (${rows.length} baris) ──`);
  emit(`DO $$ BEGIN`);
  emit(`  IF EXISTS (SELECT 1 FROM public.${ident(t)} LIMIT 1) THEN`);
  emit(`    RAISE NOTICE '${t} sudah berisi data — dilewati';`);
  emit(`    RETURN;`);
  emit(`  END IF;`);
  const colList = cols.map((x) => ident(x.column_name)).join(', ');
  for (const r of rows) {
    const vals = cols.map((x) => fmt(r[x.column_name], x.udt_name)).join(', ');
    emit(`  INSERT INTO public.${ident(t)} (${colList}) VALUES (${vals});`);
  }
  emit(`END $$;`);
  emit('');
}

// ── branding: baris netral, BUKAN salinan merek DB sumber (AGENTS.md §3.9) ──
//
// Kenapa khusus: `branding` adalah konfigurasi owner. Kalau ikut ter-dump generic,
// setiap perusahaan baru akan memakai nama/logo kita sampai owner menggantinya.
// Di sini hanya kolom yang memang harus diisi yang diberi nilai; kolom nullable
// dikosongkan eksplisit sehingga tidak ada apa pun yang diwarisi dari DB sumber.
const brandingCols = await q(
  `select column_name, is_nullable, column_default
     from information_schema.columns
    where table_schema='public' and table_name='branding' and is_generated <> 'ALWAYS'
    order by ordinal_position`,
);
if (!brandingCols.length) {
  emit(`-- branding: dilewati (tabel tidak ada di DB sumber)`);
  emit('');
} else {
  const NILAI = {
    id: `'main'`,
    company_name: lit(COMPANY_NAME),
    tagline: `'Workforce Intelligence Platform'`,
    primary_color: `'#3b82f6'`,
  };
  const dipakai = [];
  const tidakBisaDiisi = [];
  for (const col of brandingCols) {
    if (col.column_name in NILAI) dipakai.push([col.column_name, NILAI[col.column_name]]);
    else if (col.is_nullable === 'YES' || col.column_default !== null) dipakai.push([col.column_name, 'NULL']);
    else tidakBisaDiisi.push(col.column_name);
  }
  if (tidakBisaDiisi.length) {
    console.warn(`PERINGATAN: kolom branding NOT NULL tanpa default tidak diisi: ${tidakBisaDiisi.join(', ')}`);
  }
  totalRows += 1;
  emit(`-- ── branding (1 baris netral — GANTI lewat OwnerDashboard → 🎨 Branding) ──`);
  emit(`-- Nama perusahaan di bawah diisi saat generate (--company-name="..."); logo & warna`);
  emit(`-- sengaja dikosongkan agar tidak mewarisi aset DB sumber.`);
  emit(`DO $$ BEGIN`);
  emit(`  IF to_regclass('public.branding') IS NULL THEN RETURN; END IF;`);
  emit(`  IF EXISTS (SELECT 1 FROM public.branding LIMIT 1) THEN`);
  emit(`    RAISE NOTICE 'branding sudah berisi data — dilewati';`);
  emit(`    RETURN;`);
  emit(`  END IF;`);
  emit(
    `  INSERT INTO public.branding (${dipakai.map(([n]) => ident(n)).join(', ')}) VALUES (${dipakai.map(([, v]) => v).join(', ')});`,
  );
  emit(`END $$;`);
  emit('');
}

// ── cap registry migrasi ──
emit(`-- ── CAP schema_migrations ────────────────────────────────────────`);
emit(`-- Semua berkas migrasi repo ditandai sebagai sudah diterapkan, dengan checksum`);
emit(`-- SHA-256 berkas dengan EOL CRLF->LF dinormalisasi lebih dulu — modul bersama`);
emit(`-- \`supabase/scripts/migration-checksum.mjs\`, sama seperti \`apply-migration.mjs\` —`);
emit(`-- supaya nilai checksum tidak bergantung gaya EOL checkout. Dengan begitu`);
emit(`-- \`verify_migration_checksum\` dan \`check_migrations()\` konsisten dan`);
emit(`-- migrasi baru (> versi tertinggi) berjalan incremental.`);
emit(`DO $$`);
emit(`DECLARE v_n INTEGER;`);
emit(`BEGIN`);
emit(`  IF to_regclass('public.schema_migrations') IS NULL THEN`);
emit(`    RAISE WARNING 'schema_migrations tidak ada — cap registry dilewati';`);
emit(`    RETURN;`);
emit(`  END IF;`);
emit(`  v_n := 0;`);
for (const f of migFiles) {
  // Versi = prefiks angka BER-PADDING apa adanya ('000', '219'), sama persis dengan
  // yang ditulis apply-migration.mjs (/^(\d+)/ pada nama berkas). Memakai parseInt
  // menghasilkan '0' dan membuat check_migrations() melaporkan VERSION_MISMATCH
  // untuk hampir semua berkas — terukur 59 issue pada instalasi baru 2026-09-18.
  const version = (/^(\d+)/.exec(f) || ['0'])[0];
  // Modul bersama: sha256 dengan EOL CRLF→LF dinormalisasi (temuan SQL-10), supaya
  // cap di sini dan registry dari apply-migration.mjs memakai definisi yang sama di
  // checkout LF maupun CRLF.
  const checksum = migrationChecksum(path.join(MIG_DIR, f));
  emit(`  IF NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = ${lit(f)}) THEN`);
  emit(`    INSERT INTO public.schema_migrations (version, filename, checksum, description)`);
  emit(`    VALUES (${lit(version)}, ${lit(f)}, ${lit(checksum)}, 'baseline install (schema dari DB live)');`);
  emit(`    v_n := v_n + 1;`);
  emit(`  END IF;`);
}
emit(`  RAISE NOTICE 'schema_migrations: % baris baru dicap', v_n;`);
emit(`END $$;`);
emit('');
emit(`-- ── VERIFIKASI ──────────────────────────────────────────────────`);
emit(`--   select count(*) from information_schema.tables where table_schema='public';`);
emit(`--   select count(*) from public.module_definitions;        -- > 0 = menu hidup`);
emit(`--   select count(*) from public.schema_migrations;`);
emit(`--   select public.check_migrations();`);
emit('');

// ── PEMINDAI KEBOCORAN IDENTITAS ──
// Satu pemeriksaan terakhir sebelum berkas ditulis: kalau domain perusahaan sumber
// masih muncul di mana pun, instalasi baru akan mewarisinya. Lebih baik gagal-sadar
// (peringatan besar) di sini daripada ditemukan setelah perusahaan baru live.
const isi = out.join('\n');
const domainSumber = (() => {
  try {
    const e = (isi.match(/[a-z0-9._%+-]+@([a-z0-9.-]+\.[a-z]{2,})/i) || [])[1];
    return e ? e.toLowerCase() : null;
  } catch {
    return null;
  }
})();
const jejak = domainSumber ? (isi.match(new RegExp(`@${domainSumber.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}`, 'gi')) || []).length : 0;
if (jejak) {
  console.warn(`PERINGATAN KEBOCORAN: ${jejak} kemunculan domain @${domainSumber} masih ada di dump data.`);
  console.warn('  Tambahkan baris terkait ke EXCLUDED_ROWS supaya tidak diwariskan ke perusahaan baru.');
}

const dest = path.join(ROOT, OUT);
fs.mkdirSync(path.dirname(dest), { recursive: true });
fs.writeFileSync(dest, out.join('\n') + '\n');
const stat = fs.statSync(dest);
console.log(`ditulis: ${OUT}`);
console.log(`  tabel referensi : ${CONFIG_TABLES.length}`);
console.log(`  baris data      : ${totalRows}`);
console.log(`  cap migrasi     : ${migFiles.length}`);
console.log(`  ukuran          : ${(stat.size / 1024).toFixed(1)} KB`);
await c.end();
