#!/usr/bin/env node
/**
 * install-baseline.mjs — pasang instalasi perusahaan BARU dari baseline (2 berkas).
 *
 * Kenapa ada: `supabase/migrations/` berisi 156 berkas HISTORI (1,6 MB, 77 nomor versi
 * kosong, ikut men-seed data demo). Jalur resmi untuk perusahaan baru adalah baseline
 * yang di-generate dari DB live — lihat `supabase/baseline/README.md`.
 *
 * PENGAMAN (sengaja kaku):
 *   * `--target` WAJIB. Skrip ini tidak pernah memakai DATABASE_URL milik repo ini,
 *     supaya tidak ada cara tidak sengaja menimpa DB live.
 *   * Menolak kalau target = DATABASE_URL repo (dicek string-nya).
 *   * Menolak kalau target sudah punya tabel di schema `public` (baseline dirancang
 *     untuk project KOSONG); pakai `--force` hanya kalau Anda benar-benar tahu.
 *   * Default = DRY RUN (hanya preflight + rencana). Eksekusi butuh `--apply`.
 *
 * Pakai:
 *   node supabase/scripts/install-baseline.mjs --target "<connection string project baru>"            # dry run
 *   node supabase/scripts/install-baseline.mjs --target "<connection string project baru>" --apply \
 *        --company-name "PT Contoh Tambang" --owner-email "owner@contoh.com"
 *   npm run install:baseline -- --target "<connection string project baru>" --apply
 *
 * Flag identitas (opsional, tapi --owner-email praktis wajib):
 *   --company-name "PT ..."   → mengisi branding.company_name (tanpa ini tetap 'Perusahaan Anda')
 *   --owner-email "..."       → mengisi company_config.owner_email; TANPA ini owner tidak bisa
 *                                login, karena get_owner_email() fail-closed sejak migrasi 230
 *
 * Auto-provision owner (opsional, butuh kredensial project):
 *   --create-owner            → buat user Auth + system_owner_identity + owner_email dalam satu perintah
 *   --owner-password "..."    → password user owner (wajib jika --create-owner)
 *
 * Catatan: auto-provision menggunakan Supabase Admin API dari env project:
 *   SUPABASE_URL + SUPABASE_SERVICE_KEY. Jangan jalankan --create-owner ke DB live.
 *
 * Urutan berkas: 000_baseline_schema.sql lalu 010_baseline_config_data.sql.
 * Berkas data men-CAP `schema_migrations` untuk seluruh berkas migrasi repo, jadi
 * migrasi baru (> versi tertinggi) tetap bisa menyusul lewat `npm run db:migrate`.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Client } from 'pg';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const BASELINE_DIR = path.join(ROOT, 'supabase', 'baseline');
const FILES = ['000_baseline_schema.sql', '010_baseline_config_data.sql'];

const args = process.argv.slice(2);
const argValue = (name) => {
  const withEq = args.find((a) => a.startsWith(`--${name}=`));
  if (withEq) return withEq.slice(name.length + 3);
  const idx = args.indexOf(`--${name}`);
  return idx >= 0 && args[idx + 1] && !args[idx + 1].startsWith('--') ? args[idx + 1] : null;
};
const target = argValue('target');
const apply = args.includes('--apply');
const force = args.includes('--force');
const createOwner = args.includes('--create-owner');
const ownerPassword = argValue('owner-password');
const companyName = argValue('company-name');
const ownerEmail = argValue('owner-email');
if (ownerEmail && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(ownerEmail)) {
  console.error(`GAGAL: --owner-email tidak terlihat seperti email: ${ownerEmail}`);
  process.exit(2);
}
if (createOwner && !ownerEmail) {
  console.error('GAGAL: --create-owner butuh --owner-email.');
  process.exit(2);
}
if (createOwner && !ownerPassword) {
  console.error('GAGAL: --create-owner butuh --owner-password.');
  process.exit(2);
}
if (ownerPassword && ownerPassword.length < 8) {
  console.error('GAGAL: --owner-password terlalu pendek (minimal 8 karakter).');
  process.exit(2);
}

const die = (msg) => {
  console.error(`GAGAL: ${msg}`);
  process.exit(2);
};

if (!target) {
  die('wajib pakai --target "<connection string project tujuan>".\n' +
    '      Skrip ini SENGAJA tidak memakai DATABASE_URL repo, agar DB live tidak mungkin tertimpa tak sengaja.');
}
if (!/^postgres(ql)?:\/\//.test(target)) {
  die('--target harus connection string PostgreSQL dari project Supabase tujuan.');
}

const repoTarget = (() => {
  const envPath = path.join(ROOT, '.env.local');
  if (!fs.existsSync(envPath)) return null;
  const line = fs
    .readFileSync(envPath, 'utf8')
    .split(/\r?\n/)
    .find((l) => /^\s*DATABASE_URL\s*=/.test(l));
  return line ? line.slice(line.indexOf('=') + 1).trim().replace(/^["']|["']$/g, '') : null;
})();
if (repoTarget && repoTarget === target) {
  die('target yang diberikan SAMA dengan DATABASE_URL repo ini (DB live). Instalasi baseline hanya untuk project kosong.');
}

const mask = (s) => String(s).replace(/:[^:@/]+@/, ':****@');
const sources = FILES.map((f) => {
  const p = path.join(BASELINE_DIR, f);
  if (!fs.existsSync(p)) die(`berkas baseline tidak ada: ${f} — jalankan dulu: npm run db:baseline`);
  return { file: f, sql: fs.readFileSync(p, 'utf8'), kb: (fs.statSync(p).size / 1024).toFixed(1) };
});

console.log('=== INSTALASI BASELINE ===');
console.log(`target   : ${mask(target)}`);
console.log(`mode     : ${apply ? 'APPLY (menulis)' : 'DRY RUN (tidak menulis)'}`);
for (const s of sources) console.log(`berkas   : ${s.file} (${s.kb} KB)`);
console.log(`branding : ${companyName ? `nama perusahaan → "${companyName}"` : 'dibiarkan netral (ganti lewat OwnerDashboard)'}`);
console.log(`owner    : ${ownerEmail ? `owner_email → ${ownerEmail}` : 'TIDAK diisi — owner belum bisa login sampai diisi'}`);
console.log(`provision owner : ${createOwner ? 'YA (Admin API)' : 'TIDAK'}`);

const c = new Client({ connectionString: target, ssl: { rejectUnauthorized: false } });
await c.connect();

const info = await c.query(`
  select current_user as usr,
         current_setting('server_version') as pg,
         (select count(*) from information_schema.tables
           where table_schema = 'public' and table_type = 'BASE TABLE') as tabel_public`);
const { usr, pg: pgver, tabel_public } = info.rows[0];
console.log(`\n--- PREFLIGHT ---`);
console.log(`  role   : ${usr}`);
console.log(`  postgres: ${pgver}`);
console.log(`  tabel di public: ${tabel_public}`);

if (Number(tabel_public) > 0 && !force) {
  await c.end();
  die(`target sudah berisi ${tabel_public} tabel di schema public. Baseline dirancang untuk project KOSONG.
      Kalau target memang project baru yang sudah pernah di-install, pakai --force (baseline idempoten,
      tapi pastikan bukan DB produksi yang sudah berisi data).`);
}
if (Number(tabel_public) > 0 && force) {
  console.log('  PERINGATAN: --force dipakai pada project yang sudah berisi tabel; baseline akan dijalankan ulang (idempoten).');
}

const roleCheck = await c.query(`select count(*)::int as n from pg_roles where rolname = 'anon'`);
if (roleCheck.rows[0].n === 0) {
  console.log("  catatan: role 'anon' tidak ada — kalau ini bukan project Supabase, GRANT ke anon akan dilewati otomatis.");
}

if (!apply) {
  console.log('\nDRY RUN selesai. Preflight lolos. Ulangi dengan --apply untuk memasang.');
  await c.end();
  process.exit(0);
}

for (const s of sources) {
  const t0 = Date.now();
  process.stdout.write(`\n--- APPLY ${s.file} ... `);
  try {
    await c.query(s.sql);
    console.log(`ok (${Date.now() - t0}ms)`);
  } catch (err) {
    console.log('GAGAL');
    console.error(`  ${err.message}`);
    await c.end();
    process.exit(1);
  }
}

// ── Identitas perusahaan (branding + owner_email) ──
// Sengaja dilakukan SESUDAH kedua berkas dan memakai parameter terikat ($1), bukan
// interpolasi string, supaya nilai dari operator tidak pernah masuk sebagai SQL mentah.
if (companyName || ownerEmail) {
  console.log('\n--- IDENTITAS PERUSAHAAN ---');
  if (companyName) {
    const r = await c.query(`update public.branding set company_name = $1 where company_name is distinct from $1`, [companyName]);
    console.log(`  branding.company_name → "${companyName}" (${r.rowCount} baris)`);
  }
  if (ownerEmail) {
    const ada = await c.query(`select 1 from public.company_config where config_key = 'owner_email'`);
    if (ada.rowCount) {
      await c.query(
        `update public.company_config
            set config_value = jsonb_set(config_value, '{value}', to_jsonb($1::text)), updated_at = now()
          where config_key = 'owner_email'`,
        [ownerEmail],
      );
      console.log(`  company_config.owner_email → ${ownerEmail} (baris diperbarui)`);
    } else {
      // data_type hanya boleh number/string/boolean/json/array (CHECK constraint),
      // dan category_id NOT NULL → pakai 'security' bila ada, kalau tidak kategori apa pun.
      const ins = await c.query(
        `insert into public.company_config (category_id, config_key, config_value, data_type, label, is_system)
         select coalesce((select id from public.config_categories where id = 'security'),
                         (select id from public.config_categories order by id limit 1)),
                'owner_email', jsonb_build_object('value', $1::text), 'string', 'Email Owner', false`,
        [ownerEmail],
      );
      console.log(`  company_config.owner_email → ${ownerEmail} (baris baru dibuat, ${ins.rowCount})`);
    }
  }
}

// ── Auto-provision owner via Supabase Admin API ──
// Hanya jalan jika --create-owner diberikan. Kredensial project diambil dari env repo:
// SUPABASE_URL + SUPABASE_SERVICE_KEY. Langkah ini membuat user Auth owner dan
// menulis system_owner_identity, sehingga baseline benar-benar siap login.
if (createOwner && ownerEmail && ownerPassword) {
  console.log('\n--- PROVISION OWNER (Admin API) ---');
  const serviceUrl = process.env.SUPABASE_URL?.replace(/\/$/, '') || null;
  const serviceKey = process.env.SUPABASE_SERVICE_KEY || null;
  if (!serviceUrl || !serviceKey) {
    console.error('  GAGAL: SUPABASE_URL atau SUPABASE_SERVICE_KEY belum di-set di env repo.');
    await c.end();
    process.exit(2);
  }
  if (serviceUrl.includes('verwobaejumvpagwynae')) {
    console.error('  GAGAL: SUPABASE_URL repo menunjuk ke DB live. --create-owner tidak diizinkan ke live.');
    await c.end();
    process.exit(2);
  }

  let authUser = null;
  try {
    const createRes = await fetch(`${serviceUrl}/auth/v1/admin/users`, {
      method: 'POST',
      headers: {
        'apikey': serviceKey,
        'Authorization': `Bearer ${serviceKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        email: ownerEmail,
        password: ownerPassword,
        email_confirm: true,
        user_metadata: { role: 'owner' },
      }),
    });
    const createJson = await createRes.json().catch(() => ({}));
    if (!createRes.ok) {
      const msg = createJson?.msg || createJson?.error_description || createRes.statusText || 'unknown';
      console.error(`  GAGAL membuat user owner: ${createRes.status} ${msg}`);
      await c.end();
      process.exit(2);
    }
    authUser = createJson;
    console.log(`  user Auth dibuat: ${authUser.email} (${authUser.id})`);
  } catch (err) {
    console.error(`  GAGAL memanggil Admin API: ${err.message}`);
    await c.end();
    process.exit(2);
  }

  try {
    const ins = await c.query(
      `insert into public.system_owner_identity (auth_id, owner_email, is_active)
       values ($1::uuid, $2, true)
       on conflict (auth_id) do update set owner_email = excluded.owner_email, is_active = true`,
      [authUser.id, ownerEmail],
    );
    console.log(`  system_owner_identity ditulis (${ins.rowCount} baris)`);
  } catch (err) {
    console.error(`  GAGAL menulis system_owner_identity: ${err.message}`);
    await c.end();
    process.exit(2);
  }
}

console.log('\n--- VERIFIKASI ---');
const checks = [
  ['tabel non-partisi', `select count(*)::int as n from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind in ('r','p') and not c.relispartition`],
  ['fungsi project', `select count(*)::int as n from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prokind='f' and not exists (select 1 from pg_depend d where d.objid=p.oid and d.deptype='e')`],
  ['policy RLS', `select count(*)::int as n from pg_policies where schemaname='public'`],
  ['trigger', `select count(*)::int as n from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and not t.tgisinternal`],
  ['partisi absensi', `select count(*)::int as n from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relispartition`],
  ['menu (module_definitions)', `select count(*)::int as n from public.module_definitions`],
  ['cap schema_migrations', `select count(*)::int as n from public.schema_migrations`],
  ['branding (nama perusahaan)', `select company_name from public.branding limit 1`],
  ['owner_email', `select config_value->>'value' as owner_email from public.company_config where config_key = 'owner_email'`],
];
for (const [label, sql] of checks) {
  try {
    const r = await c.query(sql);
    const v = r.rows[0];
    console.log(`  ${label.padEnd(26)}: ${Object.values(v).join(' | ')}`);
  } catch (err) {
    console.log(`  ${label.padEnd(26)}: (query gagal) ${err.message}`);
  }
}
try {
  const m = await c.query(`select * from public.check_migrations()`);
  console.log(`  check_migrations()        : ${m.rowCount === 0 ? 'bersih (0 issue)' : `${m.rowCount} issue`}`);
  for (const r of m.rows.slice(0, 10)) console.log(`        ${JSON.stringify(r)}`);
  if (m.rowCount > 10) console.log(`        ... dan ${m.rowCount - 10} lagi`);
} catch (err) {
  console.log(`  check_migrations()        : (tidak tersedia) ${err.message}`);
}

console.log(`\n--- SELESAI ---`);
console.log('Langkah berikutnya (WAJIB sebelum aplikasi bisa dipakai):');
if (!createOwner && ownerEmail) {
  console.log('  1. Buat akun OWNER pertama  → supabase/baseline/README.md §5');
  console.log('     (owner_email sudah diisi, tetapi system_owner_identity BELUM dibuat)');
} else if (!ownerEmail) {
  console.log('  1. Isi owner_email + buat akun owner → supabase/baseline/README.md §5');
} else {
  console.log('  1. Owner sudah siap (user Auth + system_owner_identity + owner_email).');
}
console.log('  2. Set nama/logo perusahaan → OwnerDashboard → tab 🎨 Branding');
console.log('  3. Isi business_units + pemetaan modul sesuai perusahaan');
console.log('  4. Arahkan frontend (env VITE_SUPABASE_*) ke project ini, lalu deploy');
await c.end();
