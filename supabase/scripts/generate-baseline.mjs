#!/usr/bin/env node
/**
 * generate-baseline.mjs — membuat DDL skema `public` dari DB live.
 *
 * Latar belakang: repo ini TIDAK punya `pg_dump`/`psql` di lingkungan kerja, dan
 * rangkaian migrasi 000–228 bukan histori yang utuh (79 nomor versi tidak punya
 * berkas — lihat AGENTS.md §5.8 SQL-10). Untuk instalasi perusahaan baru, satu
 * baseline yang di-generate dari DB live jauh lebih aman daripada replay 150
 * berkas yang sebagian bergantung pada berkas yang sudah dihapus.
 *
 * Pemakaian:
 *   node supabase/scripts/generate-baseline.mjs --out supabase/baseline/000_baseline_schema.sql
 *   node supabase/scripts/generate-baseline.mjs --tables=a,b,c --functions=f1,f2 --out /tmp/subset.sql
 *
 * Read-only terhadap DB sumber. Urutan emisi mengikuti ketergantungan:
 * extensions → sequences → tables → constraints → indexes → keterikatan sequence →
 * functions → views → RLS → policies → triggers → comments → ACL → default privileges
 * → cron jobs → partisi absensi (dinamis).
 */
import fs from 'node:fs';
import path from 'node:path';
import pg from 'pg';

const argv = process.argv.slice(2);
const arg = (name, def = undefined) => {
  const hit = argv.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : def;
};
const OUT = arg('out', 'supabase/baseline/000_baseline_schema.sql');
const ONLY_TABLES = arg('tables') ? new Set(arg('tables').split(',').map((s) => s.trim()).filter(Boolean)) : null;
const ONLY_FUNCTIONS = arg('functions') ? new Set(arg('functions').split(',').map((s) => s.trim()).filter(Boolean)) : null;
const NO_PARTITION_CALL = argv.includes('--no-partition-call');

const ROOT = process.cwd();
const envPath = path.join(ROOT, '.env.local');
const URL = fs
  .readFileSync(envPath, 'utf8')
  .split(/\r?\n/)
  .find((l) => /^\s*DATABASE_URL\s*=/.test(l))
  .slice(13)
  .trim()
  .replace(/^["']|["']$/g, '');

const c = new pg.Client({ connectionString: URL, ssl: { rejectUnauthorized: false } });
await c.connect();
const q = async (sql, params = []) => (await c.query(sql, params)).rows;

const out = [];
const emit = (s = '') => out.push(s);
const ident = (n) => (/^[a-z_][a-z0-9_]*$/.test(n) ? n : `"${n.replace(/"/g, '""')}"`);
const rel = (n) => `public.${ident(n)}`;
// PUBLIC adalah pseudo-role bawaan SQL: ditulis TANPA kutip. Kalau di-ident() ia menjadi
// "PUBLIC" dan PostgreSQL mencarinya sebagai role biasa -> ERROR: role "PUBLIC" does not
// exist (bug yang membuat seluruh baseline gagal sebelum 2026-09-18).
const rolename = (n) => (n === 'PUBLIC' ? 'PUBLIC' : ident(n));
const lit = (s) => `'${String(s).replace(/'/g, "''")}'`;

// ────────────────────────────────────────────────────────────────
// EXTENSIONS
// ────────────────────────────────────────────────────────────────
const extensions = await q(`
  select extname, n.nspname as schema
  from pg_extension e join pg_namespace n on n.oid = e.extnamespace
  where extname not in ('plpgsql')
  order by extname`);
const PROJECT_EXTENSIONS = ['vector', 'pgcrypto', 'uuid-ossp', 'pg_cron', 'pg_stat_statements'];

// ────────────────────────────────────────────────────────────────
// SEQUENCES
// ────────────────────────────────────────────────────────────────
const sequences = await q(`
  select s.schemaname, s.sequencename, s.start_value, s.increment_by, s.min_value,
         s.max_value, s.cache_size, s.cycle,
         (select c.relowner::regrole::text from pg_class c
            join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = s.schemaname and c.relname = s.sequencename) as owner
  from pg_sequences s
  where s.schemaname = 'public'
    -- Lewati sequence yang menjadi kolom IDENTITY. Kolomnya dibuat ulang oleh bagian
    -- TABLES (GENERATED ... AS IDENTITY), jadi menuliskannya lagi di sini membuat
    -- Postgres memilih nama kedua (mis. auth_testing_override_id_seq1) dan instalasi
    -- berakhir dengan 1 sequence LEBIH BANYAK daripada live. Terbukti lewat
    -- verify-install-e2e 2026-09-19 (sequence live=96 vs install=97) setelah migrasi
    -- 231 membuat tabel identity pertama di skema ini.
    and not exists (
      select 1 from pg_depend d
        join pg_class c on c.oid = d.objid
        join pg_namespace n on n.oid = c.relnamespace
       where n.nspname = s.schemaname
         and c.relname = s.sequencename
         and d.deptype = 'i'
    )
  order by sequencename`);
const seqOwners = await q(`
  select s.relname as seq, t.relname as tbl, a.attname as col
  from pg_class s
  -- deptype 'a' = sequence milik kolom SERIAL (butuh ALTER ... OWNED BY eksplisit).
  -- deptype 'i' = sequence IDENTITY: keterikatannya lahir dari kolom GENERATED ... AS IDENTITY,
  -- dan ALTER SEQUENCE ... OWNED BY pada sequence identity DITOLAK PostgreSQL
  -- ("cannot change ownership of identity sequence") → jangan pernah dikeluarkan.
  join pg_depend d on d.objid = s.oid and d.deptype = 'a'
  join pg_class t on t.oid = d.refobjid
  join pg_attribute a on a.attrelid = t.oid and a.attnum = d.refobjsubid
  join pg_namespace n on n.oid = s.relnamespace
  where n.nspname = 'public' and s.relkind = 'S'
  order by s.relname`);

// ────────────────────────────────────────────────────────────────
// TABLES (non-partition children)
// ────────────────────────────────────────────────────────────────
let tables = await q(`
  select c.relname, c.relkind::text as kind, pg_get_userbyid(c.relowner) as owner,
         c.relrowsecurity as rls, c.relforcerowsecurity as force,
         case when c.relkind = 'p' then pg_get_partkeydef(c.oid) else null end as partkey,
         obj_description(c.oid, 'pg_class') as comment
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('r','p') and not c.relispartition
  order by c.relname`);
if (ONLY_TABLES) tables = tables.filter((t) => ONLY_TABLES.has(t.relname));

const columnsOf = async (name) =>
  q(
    `select a.attname, format_type(a.atttypid, a.atttypmod) as type, a.attnotnull,
            pg_get_expr(d.adbin, d.adrelid) as dflt, a.attidentity, a.attgenerated,
            col_description(a.attrelid, a.attnum) as comment
       from pg_attribute a
       left join pg_attrdef d on d.adrelid = a.attrelid and d.adnum = a.attnum
      where a.attrelid = $1::regclass and a.attnum > 0 and not a.attisdropped
      order by a.attnum`,
    [rel(name)],
  );

const constraintsOf = async (name) =>
  q(
    `select conname, contype::text as typ, pg_get_constraintdef(oid) as def
       from pg_constraint where conrelid = $1::regclass
      order by case contype when 'p' then 1 when 'u' then 2 when 'c' then 3 when 'f' then 4 else 5 end, conname`,
    [rel(name)],
  );

const indexesOf = async (name) =>
  q(
    `select i.indexrelid::regclass::text as idxname, pg_get_indexdef(i.indexrelid) as def,
            (select count(*) from pg_constraint c where c.conindid = i.indexrelid) as is_constraint
       from pg_index i where i.indrelid = $1::regclass order by 1`,
    [rel(name)],
  );

// ────────────────────────────────────────────────────────────────
// FUNCTIONS
// ────────────────────────────────────────────────────────────────
let functions = await q(`
  select p.proname, p.prokind::text as kind, pg_get_function_identity_arguments(p.oid) as args,
         pg_get_functiondef(p.oid) as def, obj_description(p.oid, 'pg_proc') as comment,
         p.prosecdef as secdef,
         coalesce(array_to_string(p.proconfig, ','), '') as config
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
  order by p.proname, args`);
if (ONLY_FUNCTIONS) functions = functions.filter((f) => ONLY_FUNCTIONS.has(f.proname));
const aggregates = functions.filter((f) => f.kind === 'a');
functions = functions.filter((f) => f.kind === 'f' || f.kind === 'p');

// ────────────────────────────────────────────────────────────────
// VIEWS
// ────────────────────────────────────────────────────────────────
const views = await q(`
  select c.relname, pg_get_viewdef(c.oid, true) as def, pg_get_userbyid(c.relowner) as owner
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'v' order by c.relname`);

// ────────────────────────────────────────────────────────────────
// TRIGGERS
// ────────────────────────────────────────────────────────────────
const triggersFor = async (name) =>
  q(
    `select t.tgname, pg_get_triggerdef(t.oid, true) as def
       from pg_trigger t where t.tgrelid = $1::regclass and not t.tgisinternal order by 1`,
    [rel(name)],
  );

// ────────────────────────────────────────────────────────────────
// POLICIES
// ────────────────────────────────────────────────────────────────
const policiesFor = async (name) =>
  q(
    `select pol.polname, pol.polcmd::text as cmd, pol.polpermissive as permissive,
            (select string_agg(coalesce(r.rolname, 'PUBLIC'), ', ')
               from unnest(pol.polroles) ro
               left join pg_roles r on r.oid = ro) as roles,
            pg_get_expr(pol.polqual, pol.polrelid) as qual,
            pg_get_expr(pol.polwithcheck, pol.polrelid) as withcheck
       from pg_policy pol where pol.polrelid = $1::regclass order by pol.polname`,
    [rel(name)],
  );

// ────────────────────────────────────────────────────────────────
// ACL
// ────────────────────────────────────────────────────────────────
// CATATAN: `left join pg_roles` + coalesce('PUBLIC') itu WAJIB. Dengan `join`,
// baris grantee = 0 (PUBLIC) hilang dari hasil — dan baseline kehilangan
// kemampuan mencerminkan pencabutan hak dari PUBLIC.
const relationAcl = await q(`
  select c.relname, c.relkind::text as kind, coalesce(g.rolname, 'PUBLIC') as grantee, a.privilege_type
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  cross join lateral aclexplode(c.relacl) a
  left join pg_roles g on g.oid = a.grantee
  where n.nspname = 'public' and c.relkind in ('r','p','v','S','m')
  order by c.relname, grantee, privilege_type`);
const functionAcl = await q(`
  select p.proname, pg_get_function_identity_arguments(p.oid) as args, coalesce(g.rolname, 'PUBLIC') as grantee, a.privilege_type
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  cross join lateral aclexplode(p.proacl) a
  left join pg_roles g on g.oid = a.grantee
  where n.nspname = 'public'
    and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
  order by p.proname, args, grantee`);
const defaultAcl = await q(`
  select d.defaclobjtype::text as objtype, g.rolname as grantee, a.privilege_type
  from pg_default_acl d
  join pg_namespace n on n.oid = d.defaclnamespace
  cross join lateral aclexplode(d.defaclacl) a
  join pg_roles g on g.oid = a.grantee
  where n.nspname = 'public'
  order by objtype, grantee, privilege_type`);

// ────────────────────────────────────────────────────────────────
// EMIT
// ────────────────────────────────────────────────────────────────
const scopeLabel = ONLY_TABLES || ONLY_FUNCTIONS ? 'SUBSET' : 'FULL';
emit(`-- ================================================================`);
emit(`-- BASELINE SKEMA — di-generate dari DB live`);
emit(`-- ================================================================`);
emit(`--`);
// Identitas DB sumber SENGAJA tidak ditulis ke artefak: baseline ini dipasang di
// perusahaan LAIN, jadi host/project ref/password DB sumber tidak boleh menular (§3.16).
// Konsekuensi praktis: berkas hasil generate tidak lagi memuat connection string,
// sehingga tidak memicu secret scan di jalur pre-commit §0.6.
emit('-- Sumber     : DB live (host, project ref & password sengaja TIDAK ditulis)');
emit(`-- Generator  : supabase/scripts/generate-baseline.mjs (${scopeLabel})`);
emit(`-- Objek      : ${tables.length} tabel, ${functions.length} fungsi, ${views.length} view,`);
emit(`--               ${sequences.length} sequence, ${triggersFor ? '' : ''}trigger/policy sesuai tabel`);
emit(`--`);
emit(`-- JANGAN disunting tangan. Regenerate dengan generator di atas.`);
emit(`--`);
emit(`-- URUTAN PASANG (lihat supabase/baseline/README.md):`);
emit(`--   1. Buat project Supabase kosong (region sesuai keputusan user).`);
emit(`--   2. Jalankan berkas ini sebagai role \`postgres\`.`);
emit(`--   3. Tandai migrasi 000–228 sebagai sudah diterapkan di \`schema_migrations\``);
emit(`--      (supaya migrasi BARU (>228) berjalan incremental, bukan mengulang).`);
emit(`--`);
emit(`-- CATATAN PENTING`);
emit(`--   * Berkas ini menggantikan replay 000–228 karena rangkaian migrasi repo`);
emit(`--     BUKAN histori utuh (79 nomor versi tanpa berkas — AGENTS.md §5.8 SQL-10)`);
emit(`--     dan 23 tabel + 14 fungsi live tidak punya sumber migrasi (SQL-02).`);
emit(`--   * hr_attendance kini TABEL BIASA (SQL-08, migrasi 240: drop`);
emit(`--     hr_attendance_partitioned + ensure_attendance_partitions), jadi tidak ada`);
emit(`--     blok partisi dinamis di baseline — generator tidak lagi memanggilnya.`);
emit(`--   * Schema/objek milik Supabase (\`auth\`, \`storage\`, \`vault\`, role`);
emit(`--     anon/authenticated/service_role) TIDAK dibuat di sini — sudah disediakan`);
emit(`--     platform. RLS memakai \`auth.uid()\` dari sana.`);
emit('');
emit(`set client_min_messages = warning;`);
emit(`-- check_function_bodies = off: badan fungsi diperiksa saat DIPANGGIL, bukan saat`);
emit('-- dibuat. Tanpa ini, urutan pembuatan menjadi rapuh: fungsi LANGUAGE sql');
emit('-- yang membaca objek yang belum dibuat akan menggagalkan seluruh instalasi.');
emit(`-- Isi fungsi berasal dari DB live yang sudah terbukti jalan; kebenaran hasil`);
emit(`-- instalasi diverifikasi dengan membandingkan metrik + ACL ke DB live.`);
emit(`set check_function_bodies = off;`);
emit('');
emit(`-- ── EXTENSIONS ──────────────────────────────────────────────────`);
emit(`-- Schema \`extensions\` disediakan platform Supabase; dibuat di sini agar`);
emit(`-- baseline tetap bisa dipasang pada project yang belum memilikinya.`);
emit(`CREATE SCHEMA IF NOT EXISTS extensions;`);
emit(`-- Tiap extension dibungkus exception-handler. Bila platform tidak mengizinkan`);
emit(`-- (mis. pg_cron hanya bisa dibuat di database \`postgres\`, atau tier tanpa`);
emit(`-- extension itu), instalasi LANJUT dengan WARNING — tidak menggagalkan seluruh`);
emit(`-- baseline. Aktifkan manual lewat Dashboard → Database → Extensions bila perlu.`);
for (const e of extensions) {
  if (!PROJECT_EXTENSIONS.includes(e.extname)) continue;
  const schema = e.schema === 'public' ? '' : ` WITH SCHEMA ${ident(e.schema)}`;
  emit(`DO $$ BEGIN`);
  emit(`  CREATE EXTENSION IF NOT EXISTS ${ident(e.extname)}${schema};`);
  emit(`EXCEPTION WHEN OTHERS THEN`);
  emit(`  RAISE WARNING 'extension ${e.extname} dilewati: %', SQLERRM;`);
  emit(`END $$;`);
}
const skippedExt = extensions.filter((e) => !PROJECT_EXTENSIONS.includes(e.extname));
if (skippedExt.length) {
  emit(`-- (dikelola platform, tidak dibuat di sini: ${skippedExt.map((e) => e.extname).join(', ')})`);
}
emit('');
emit(`-- ── SEQUENCES ───────────────────────────────────────────────────`);
for (const s of sequences) {
  emit(
    `CREATE SEQUENCE IF NOT EXISTS ${rel(s.sequencename)}` +
      ` AS bigint START WITH ${s.start_value} INCREMENT BY ${s.increment_by}` +
      ` MINVALUE ${s.min_value} MAXVALUE ${s.max_value} CACHE ${s.cache_size}` +
      (s.cycle ? ' CYCLE' : ' NO CYCLE') +
      ';',
  );
}
emit('');
emit(`-- ── TABLES ──────────────────────────────────────────────────────`);
for (const t of tables) {
  const cols = await columnsOf(t.relname);
  emit(`CREATE TABLE IF NOT EXISTS ${rel(t.relname)} (`);
  const lines = cols.map((col) => {
    let line = `  ${ident(col.attname)} ${col.type}`;
    if (col.attgenerated === 's') line = `  ${ident(col.attname)} ${col.type} GENERATED ALWAYS AS (${col.dflt}) STORED`;
    else if (col.dflt) line += ` DEFAULT ${col.dflt}`;
    if (col.attidentity) line += ` GENERATED ${col.attidentity === 'a' ? 'ALWAYS' : 'BY DEFAULT'} AS IDENTITY`;
    if (col.attnotnull) line += ' NOT NULL';
    return line;
  });
  emit(lines.join(',\n'));
  emit(`)${t.partkey ? ` PARTITION BY ${t.partkey}` : ''};`);
  emit('');
}
emit(`-- ── CONSTRAINTS (PK/UNIQUE/CHECK) ───────────────────────────────`);
const fkStatements = [];
for (const t of tables) {
  const cons = await constraintsOf(t.relname);
  for (const k of cons) {
    if (k.typ === 'f') {
      fkStatements.push(
        `DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = ${lit(k.conname)} AND conrelid = ${lit(rel(t.relname))}::regclass) THEN ALTER TABLE ${rel(t.relname)} ADD CONSTRAINT ${ident(k.conname)} ${k.def}; END IF; END $$;`,
      );
      continue;
    }
    emit(
      `DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = ${lit(k.conname)} AND conrelid = ${lit(rel(t.relname))}::regclass) THEN ALTER TABLE ${rel(t.relname)} ADD CONSTRAINT ${ident(k.conname)} ${k.def}; END IF; END $$;`,
    );
  }
}
emit('');
emit(`-- ── FOREIGN KEYS (setelah semua tabel ada) ──────────────────────`);
if (!fkStatements.length) emit(`-- (tidak ada)`);
for (const s of fkStatements) emit(s);
emit('');
emit(`-- ── INDEXES (non-constraint) ────────────────────────────────────`);
for (const t of tables) {
  const idx = await indexesOf(t.relname);
  for (const i of idx) {
    if (Number(i.is_constraint) > 0) continue;
    // pg_get_indexdef tidak punya IF NOT EXISTS → bungkus guard
    const def = i.def.replace(/^CREATE (UNIQUE )?INDEX /i, (m, u) => `CREATE ${u || ''}INDEX IF NOT EXISTS `);
    emit(def + ';');
  }
}
emit('');
emit(`-- ── SEQUENCE OWNERSHIP ──────────────────────────────────────────`);
for (const o of seqOwners) {
  if (ONLY_TABLES && !ONLY_TABLES.has(o.tbl)) continue;
  emit(`ALTER SEQUENCE ${rel(o.seq)} OWNED BY ${rel(o.tbl)}.${ident(o.col)};`);
}
emit('');
emit(`-- ── VIEWS ───────────────────────────────────────────────────────`);
emit('-- DULU daripada FUNCTIONS: fungsi LANGUAGE sql divalidasi saat dibuat, jadi');
emit('-- view (mis. employees_master) harus sudah ada sebelum fungsi yang membacanya.');
for (const v of views) {
  emit(`CREATE OR REPLACE VIEW ${rel(v.relname)} AS\n${String(v.def).trim()};`);
}
emit('');
emit(`-- ── FUNCTIONS ───────────────────────────────────────────────────`);
if (aggregates.length) emit(`-- dilewati (agregat milik extension): ${aggregates.map((a) => a.proname).join(', ')}`);
for (const f of functions) {
  emit(`-- ${f.proname}(${f.args})`);
  emit(String(f.def).trim().replace(/\r\n/g, '\n') + ';');
}
emit('');
emit(`-- ── CATATAN PARTISI ABSENSI ─────────────────────────────────────`);
emit(`-- Sejak SQL-08 (migrasi 240) hr_attendance adalah TABEL BIASA: partisi`);
emit(`-- hr_attendance_YYYY_MM dan fungsi ensure_attendance_partitions() sudah di-drop.`);
emit(`-- Tidak ada pemanggilan apa pun di sini; ACL hr_attendance tercakup blok per-tabel`);
emit(`-- di bawah seperti tabel lain.`);
emit(`-- ── ROW LEVEL SECURITY ──────────────────────────────────────────`);
for (const t of tables) {
  if (!t.rls) continue;
  emit(`ALTER TABLE ${rel(t.relname)} ENABLE ROW LEVEL SECURITY;`);
  if (t.force) emit(`ALTER TABLE ${rel(t.relname)} FORCE ROW LEVEL SECURITY;`);
}
emit('');
emit(`-- ── POLICIES ────────────────────────────────────────────────────`);
for (const t of tables) {
  const pols = await policiesFor(t.relname);
  for (const p of pols) {
    const cmd = { r: 'SELECT', a: 'INSERT', w: 'UPDATE', d: 'DELETE', '*': 'ALL' }[p.cmd] || 'ALL';
    let s = `DROP POLICY IF EXISTS ${ident(p.polname)} ON ${rel(t.relname)};\n`;
    s += `CREATE POLICY ${ident(p.polname)} ON ${rel(t.relname)}`;
    if (!p.permissive) s += ' AS RESTRICTIVE';
    s += ` FOR ${cmd}`;
    if (p.roles) s += ` TO ${p.roles.split(', ').map((r) => (r === 'PUBLIC' ? 'PUBLIC' : ident(r))).join(', ')}`;
    if (p.qual) s += ` USING (${p.qual})`;
    if (p.withcheck) s += ` WITH CHECK (${p.withcheck})`;
    emit(s + ';');
  }
}
emit('');
emit(`-- ── TRIGGERS ────────────────────────────────────────────────────`);
// VIEW ikut diiterasi, bukan hanya tabel: `employees_master` adalah VIEW dengan 3
// trigger INSTEAD OF (insert/update/delete) yang menjadi jalur tulis view tersebut.
// Sebelum diperbaiki, baseline hanya meng-emit 24 dari 27 trigger live — instalasi baru
// akan membuat `employees_master` MENJADI READ-ONLY tanpa terlihat gagal.
for (const t of [...tables, ...views]) {
  const trs = await triggersFor(t.relname);
  for (const tr of trs) {
    emit(`DROP TRIGGER IF EXISTS ${ident(tr.tgname)} ON ${rel(t.relname)};`);
    emit(String(tr.def).trim() + ';');
  }
}
emit('');
emit(`-- ── COMMENTS ────────────────────────────────────────────────────`);
for (const t of tables) {
  if (t.comment) emit(`COMMENT ON TABLE ${rel(t.relname)} IS ${lit(t.comment)};`);
}
for (const f of functions) {
  if (f.comment) emit(`COMMENT ON FUNCTION ${rel(f.proname)}(${f.args}) IS ${lit(f.comment)};`);
}
emit('');
emit(`-- ── ACL: NORMALISASI (revoke dulu, baru grant persis seperti DB live) ──`);
emit(`-- MENGAPA REVOKE DULU: platform Supabase memberi anon/authenticated hak bawaan`);
emit(`-- pada SETIAP objek baru di schema public. Kalau baseline hanya mengeluarkan`);
emit(`-- GRANT, maka semua REVOKE dari migrasi 172/221/226 HILANG pada instalasi baru`);
emit(`-- — artinya perusahaan baru mendapat DB yang LEBIH TERBUKA daripada DB live.`);
emit(`-- Pola revoke-lalu-grant di bawah membuat ACL instalasi baru = ACL live,`);
emit(`-- apa pun bawaan platform.`);
const ALL_ROLES = 'PUBLIC, anon, authenticated, service_role';
const relNames = new Set([...tables.map((t) => t.relname), ...views.map((v) => v.relname)]);
for (const n of relNames) emit(`REVOKE ALL ON TABLE ${rel(n)} FROM ${ALL_ROLES};`);
for (const s of sequences) emit(`REVOKE ALL ON SEQUENCE ${rel(s.sequencename)} FROM ${ALL_ROLES};`);
for (const f of functions) emit(`REVOKE ALL ON FUNCTION ${rel(f.proname)}(${f.args}) FROM ${ALL_ROLES};`);
emit('');
emit(`-- SAPUAN SCHEMA-WIDE (wajib): tanpa ini objek apa pun yang luput didaftar`);
emit(`-- (mis. tabel baru hasil generator) mewarisi hak bawaan platform (anon ALL)`);
emit(`-- → DB perusahaan baru LEBIH TERBUKA daripada DB live.`);
emit(`-- Sejak SQL-08 tidak ada lagi partisi dinamis hr_attendance_* saat instalasi;`);
emit(`-- sapuan tetap dipertahankan sebagai jaring pengaman ACL.`);
emit(`REVOKE ALL ON ALL TABLES IN SCHEMA public FROM ${ALL_ROLES};`);
emit(`REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM ${ALL_ROLES};`);
emit(`REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM ${ALL_ROLES};`);
emit(`-- Sapuan di atas MENGHAPUS semua hak, lalu blok GRANT di bawah mengembalikannya`);
emit(`-- persis seperti DB live (per objek). Urutan ini tidak boleh dibalik.`);
emit('');
const aclByRel = new Map();
for (const a of relationAcl) {
  const key = `${a.relname}|${a.grantee}`;
  if (!aclByRel.has(key)) aclByRel.set(key, { relname: a.relname, grantee: a.grantee, privs: [] });
  aclByRel.get(key).privs.push(a.privilege_type);
}
for (const v of aclByRel.values()) {
  if (ONLY_TABLES && !ONLY_TABLES.has(v.relname)) continue;
  const privs = v.privs.includes('ALL') ? 'ALL' : v.privs.join(', ');
  emit(`GRANT ${privs} ON TABLE ${rel(v.relname)} TO ${rolename(v.grantee)};`);
}
emit('');
emit(`-- ── ACL: FUNGSI ─────────────────────────────────────────────────`);
const aclByFn = new Map();
for (const a of functionAcl) {
  const key = `${a.proname}|${a.args}|${a.grantee}`;
  if (!aclByFn.has(key)) aclByFn.set(key, { ...a, privs: [] });
  aclByFn.get(key).privs.push(a.privilege_type);
}
for (const v of aclByFn.values()) {
  if (ONLY_FUNCTIONS && !ONLY_FUNCTIONS.has(v.proname)) continue;
  emit(`GRANT ${v.privs.join(', ')} ON FUNCTION ${rel(v.proname)}(${v.args}) TO ${rolename(v.grantee)};`);
}
emit('');
emit(`-- ── DEFAULT PRIVILEGES — SENGAJA TIDAK DI-EMIT ──────────────────`);
emit(`-- Hak istimewa bawaan ini DIPASANG OLEH PLATFORM Supabase pada project baru,`);
emit(`-- bukan oleh proyek ini. Kalau daftar di bawah di-emit sebagai GRANT, ada dua`);
emit(`-- akibat buruk: (a) mubazir bila bawaan platform sama, dan (b) bila kelak`);
emit(`-- Supabase memperketat bawaannya, baseline ini justru MELEMAHKAN project baru.`);
emit(`-- Membiarkannya = project baru berperilaku persis seperti DB live.`);
emit(`-- Baris di bawah hanya DOKUMENTASI keadaan live (AGENTS.md §5.8 SQL-07 masih OPEN):`);
const dpByObj = new Map();
for (const d of defaultAcl) {
  const key = d.objtype;
  if (!dpByObj.has(key)) dpByObj.set(key, new Map());
  const byGrantee = dpByObj.get(key);
  if (!byGrantee.has(d.grantee)) byGrantee.set(d.grantee, []);
  byGrantee.get(d.grantee).push(d.privilege_type);
}
for (const [objtype, byGrantee] of dpByObj) {
  const kind = { f: 'FUNCTIONS', r: 'TABLES', S: 'SEQUENCES' }[objtype];
  if (!kind) continue;
  for (const [grantee, privs] of byGrantee) {
    emit(`--   (live) DEFAULT PRIVILEGES ... ${privs.join(', ')} ON ${kind} TO ${grantee};`);
  }
}
emit('');
emit(`-- ── CRON JOBS ───────────────────────────────────────────────────`);
let cronJobs = await q(`select jobname, schedule, command from cron.job order by jobid`);
if (NO_PARTITION_CALL) cronJobs = cronJobs.filter((j) => j.jobname !== 'ensure-attendance-partitions');
for (const j of cronJobs) {
  emit(`DO $$ BEGIN`);
  emit(`  -- Guard memakai keberadaan fungsi, bukan baris pg_extension: lebih tahan banting`);
  emit(`  -- dan tetap benar bila pg_cron dipasang dengan cara lain.`);
  emit(`  IF to_regprocedure('cron.schedule(text,text,text)') IS NULL THEN`);
  emit(`    RAISE NOTICE 'cron.schedule tidak tersedia — job ${j.jobname} dilewati'; RETURN;`);
  emit(`  END IF;`);
  emit(`  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = ${lit(j.jobname)}) THEN PERFORM cron.unschedule(${lit(j.jobname)}); END IF;`);
  emit(`  PERFORM cron.schedule(${lit(j.jobname)}, ${lit(j.schedule)}, ${lit(j.command)});`);
  emit(`END $$;`);
}
emit('');
emit(`-- Catatan: sejak SQL-08 hr_attendance tabel biasa — tidak ada partisi dinamis`);
emit(`-- yang perlu dibuat saat instalasi (blok "PARTISI ABSENSI" dihapus).`);
emit('');
emit(`-- ── SELESAI. Verifikasi: ────────────────────────────────────────`);
emit(`--   select count(*) from information_schema.tables where table_schema='public';`);
emit(`--   select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public';`);
emit(`--   select jobname from cron.job order by jobid;`);

await c.end();

const dest = path.join(ROOT, OUT);
fs.mkdirSync(path.dirname(dest), { recursive: true });
fs.writeFileSync(dest, out.join('\n') + '\n');
const stat = fs.statSync(dest);
console.log(`wrote ${OUT}`);
console.log(`  ${(stat.size / 1024).toFixed(1)} KB, ${out.length} baris`);
console.log(`  tabel ${tables.length} | fungsi ${functions.length} | view ${views.length} | sequence ${sequences.length} | cron ${cronJobs.length}`);
if (ONLY_TABLES || ONLY_FUNCTIONS) console.log(`  filter aktif: tables=${ONLY_TABLES ? ONLY_TABLES.size : 'all'} functions=${ONLY_FUNCTIONS ? ONLY_FUNCTIONS.size : 'all'}`);
