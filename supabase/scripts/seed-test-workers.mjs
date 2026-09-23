#!/usr/bin/env node
/**
 * supabase/scripts/seed-test-workers.mjs — seed data uji ke DB live (bukan baseline).
 *
 * Latar: baseline installer sengaja TIDAK memuat data karyawan/PII (kontrak header
 * 010_baseline_config_data.sql: "YANG SENGAJA TIDAK ADA"). Akibatnya pasca reset DB,
 * smoke OPS-01 gagal karena employees_extended kosong. Script ini menyiapkan data uji
 * TANPA menyentuh baseline — dipanggil manual atau oleh smoke runner (idempoten).
 *
 * Keputusan user 2026-09-22:
 *   (Y) password ditulis via crypt() langsung (bcrypt gen_salt('bf')) — BUKAN RPC
 *       admin_reset_worker_password (RPC punya gate authz yang menolak koneksi
 *       postgres langsung). Dev tooling, tidak butuh gate authz. Tidak ada plaintext.
 *   (e) exit tanpa rollback — user fix manual jika error.
 *
 * Pakai:  node supabase/scripts/seed-test-workers.mjs --dry | --apply
 * Password dibaca dari supabase/akun/akun.txt (gitignored) — TIDAK PERNAH dicetak.
 * Exit 0 = PASS, 1 = GAGAL, 2 = salah pemakaian.
 *
 * Realign 2026-09-22 (pasca reset baseline kedua): seed juga (a) mengisi 4 baris `sites`
 * (HQ/MINING/ESTATE/MILL — persis backup pre-nuke 2026-09-22 07:17, idempoten per id) dan
 * (b) menyelaraskan employees_core NRP001–NRP010 ke kontrak `dummy-reconciliation-guard.test.ts`
 * (business_unit_id/business_unit/divisi/divisi_code/site_id per NRP). VERIFY baru: sites_ok
 * (sites ACTIVE untuk BU kontrak) dan recon_bad (baris NRP001–010 yang masih melanggar kontrak).
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const APPLY = process.argv.includes('--apply');
const DRY = process.argv.includes('--dry');
if (!APPLY && !DRY) {
  console.error('Pakai: node supabase/scripts/seed-test-workers.mjs --dry | --apply');
  process.exit(2);
}

/** Baca .env.local (pola sama dengan repair-worker-auth.mjs — tanpa dependensi baru). */
const env = {};
for (const line of fs.readFileSync(path.join(ROOT, '.env.local'), 'utf8').split(/\r?\n/)) {
  const m = /^([A-Za-z_0-9]+)=(.*)$/.exec(line.trim());
  if (m) env[m[1]] = m[2].trim().replace(/^["']|["']$/g, '');
}
if (!env.DATABASE_URL) { console.error('FATAL: DATABASE_URL tidak ada di .env.local'); process.exit(2); }

/** akun.txt kolom TAB — Section 1 admin: <email> <password> <nrp>; Section 2 worker: <nrp> <email> <password> <nik>. */
const ROLE_BY_PREFIX = {
  ceo: 'admin_pusat', pusat: 'admin_pusat', hrd: 'admin_hrd', finance: 'admin_finance',
  operasional: 'admin_operasional', mining: 'admin_mining', mill: 'admin_mill', estate: 'admin_estate',
};
const akun = [];
for (const raw of fs.readFileSync(path.join(ROOT, 'supabase', 'akun', 'akun.txt'), 'utf8').split(/\r?\n/)) {
  const f = raw.split('\t').map((v) => v.trim()).filter(Boolean);
  if (/^NRP\d+$/.test(f[0] ?? '')) {
    if (f[1]?.includes('@') && f[2]) akun.push({ nrp: f[0], email: f[1], password: f[2], role: 'worker' });
  } else if (f[0]?.includes('@') && /^NRP\d+$/.test(f[2] ?? '')) {
    akun.push({ nrp: f[2], email: f[0], password: f[1], role: ROLE_BY_PREFIX[f[0].split('@')[0]] ?? 'admin' });
  }
}
if (akun.length !== 17) {
  console.error(`FATAL: parsing akun.txt menghasilkan ${akun.length} akun (harus 17)`);
  process.exit(1);
}

const client = new pg.Client({ connectionString: env.DATABASE_URL, ssl: { rejectUnauthorized: false } });
await client.connect();
const tag = DRY ? '[DRY] ' : '';

// Kondisi awal (read-only) untuk rencana dry & pemisahan hitungan insert/update.
const awal = (await client.query(`
  SELECT (SELECT COUNT(*) FROM employees_core WHERE nrp LIKE 'NRP%') AS core,
         (SELECT COUNT(*) FROM employees_extended WHERE nrp LIKE 'NRP%') AS ext,
         (SELECT COUNT(*) FROM user_roles WHERE nrp LIKE 'NRP%') AS roles,
         (SELECT COUNT(*) FROM worker_passwords WHERE nrp LIKE 'NRP%') AS pw,
         (SELECT COUNT(*) FROM employees_core WHERE nrp LIKE 'NRP%' AND auth_id IS NOT NULL) AS auth_linked,
         (SELECT COUNT(*) FROM sites WHERE business_unit IN ('HQ','MINING','ESTATE','MILL') AND status = 'ACTIVE') AS sites_all`)).rows[0];
const sudahAdaPw = new Set(
  (await client.query(`SELECT nrp FROM worker_passwords WHERE nrp LIKE 'NRP%'`)).rows.map((r) => r.nrp),
);

// 1) employees_extended — baris minimal (PK nrp) untuk semua NRP employees_core.
//    Dry = hitung yang belum ada (query saja); Apply = INSERT..SELECT idempoten.
const extKurang = Number(awal.core) - Number(awal.ext);
let nExt = 0;
if (DRY) nExt = extKurang;
else {
  nExt = (await client.query(
    `INSERT INTO employees_extended (nrp)
     SELECT nrp FROM employees_core WHERE nrp LIKE 'NRP%'
     ON CONFLICT (nrp) DO NOTHING`,
  )).rowCount;
}

// 2) user_roles — safety net: hanya NRP yang belum punya (live pasca reset sudah 17).
const adaRole = new Set((await client.query(`SELECT nrp FROM user_roles WHERE nrp LIKE 'NRP%'`)).rows.map((r) => r.nrp));
const kurangRole = akun.filter((a) => !adaRole.has(a.nrp));
let nRole = 0;
if (kurangRole.length) {
  if (DRY) nRole = kurangRole.length;
  else {
    nRole = (await client.query(
      `INSERT INTO user_roles (nrp, role, role_level, plan)
       SELECT a.nrp, a.role, 1, 'FREE' FROM unnest($1::text[], $2::text[]) AS a(nrp, role)
       ON CONFLICT (nrp) DO NOTHING`,
      [kurangRole.map((a) => a.nrp), kurangRole.map((a) => a.role)],
    )).rowCount;
  }
}

// 3) worker_passwords — KEPUTUSAN (Y): crypt() langsung, bukan RPC (gate authz menolak
//    koneksi postgres). Upsert idempoten per akun; password tidak pernah dicetak.
let pwBaru = 0, pwUpdate = 0;
for (const a of akun) {
  if (DRY) { sudahAdaPw.has(a.nrp) ? pwUpdate++ : pwBaru++; continue; }
  await client.query(
    `INSERT INTO worker_passwords (nrp, password_hash, is_active, reset_required, attempts)
     VALUES ($1, crypt($2, gen_salt('bf')), true, false, 0)
     ON CONFLICT (nrp) DO UPDATE SET
       password_hash = crypt($2, gen_salt('bf')),
       reset_required = false,
       attempts = 0`,
    [a.nrp, a.password],
  );
  sudahAdaPw.has(a.nrp) ? pwUpdate++ : pwBaru++;
}

// 4) Safety WAJIB: pastikan tidak ada reset_required tersisa true (RPC lama/bisa set TRUE).
let nRR = 0;
if (!DRY) {
  nRR = (await client.query(
    `UPDATE worker_passwords SET reset_required = false WHERE nrp LIKE 'NRP%' AND reset_required = true`,
  )).rowCount;
}

// 5) sync auth_id — hubungkan employees_core ke auth.users by email (yang belum).
let nAuth = 0;
if (!DRY) {
  nAuth = (await client.query(
    `UPDATE employees_core c SET auth_id = u.id FROM auth.users u
     WHERE c.auth_id IS NULL AND lower(u.email) = lower(c.email)`,
  )).rowCount;
}

// 6) sites — 4 baris geofence (HQ/MINING/ESTATE/MILL), upsert DO UPDATE (self-heal drift):
//    baris lama dengan id sama tapi site_name/business_unit/status/geo salah IKUT diperbaiki —
//    ON CONFLICT DO NOTHING akan melewatkannya (celah ditutup atas review 2026-09-23).
//    Sumber nilai: backup pre-nuke 2026-09-22 07:17 (= data yang dulu lolos guard rekonsiliasi).
const SITES = [
  { id: 'SITE-HQ-01', site_name: 'Kantor Pusat Jakarta', location: 'Jakarta Selatan', business_unit: 'HQ', lat: -6.2088, lng: 106.8456, radius: 250 },
  { id: 'SITE-MINING-01', site_name: 'Site Tambang Sangatta', location: 'Kalimantan Timur', business_unit: 'MINING', lat: 0.0617, lng: 117.4186, radius: 500 },
  { id: 'SITE-ESTATE-01', site_name: 'Kebun Sawit Riau', location: 'Riau', business_unit: 'ESTATE', lat: 0.5071, lng: 101.4478, radius: 400 },
  { id: 'SITE-MILL-01', site_name: 'Pabrik CPO Riau', location: 'Riau', business_unit: 'MILL', lat: 0.4893, lng: 101.421, radius: 300 },
];
// Drift = id sudah ada TAPI ada kolom seed yang tidak sesuai kontrak (null-safe via
// IS NOT DISTINCT FROM). Parameterized VALUES — tanpa interpolasi string ke SQL.
const sitesParams = SITES.flatMap((s) => [s.id, s.site_name, s.location, s.business_unit, s.lat, s.lng, s.radius]);
const sitesVals = SITES.map((_, i) => {
  const b = i * 7;
  return `($${b + 1},$${b + 2},$${b + 3},$${b + 4},$${b + 5}::numeric,$${b + 6}::numeric,$${b + 7}::int)`;
}).join(',');
const sitesDrift = Number((await client.query(
  `SELECT COUNT(*)::int AS n
     FROM (VALUES ${sitesVals}) AS v(id, site_name, location, business_unit, lat, lng, radius)
    WHERE NOT EXISTS (SELECT 1 FROM sites s
                       WHERE s.id = v.id
                         AND s.site_name IS NOT DISTINCT FROM v.site_name
                         AND s.location IS NOT DISTINCT FROM v.location
                         AND s.business_unit = v.business_unit
                         AND s.latitude IS NOT DISTINCT FROM v.lat
                         AND s.longitude IS NOT DISTINCT FROM v.lng
                         AND s.radius_meters IS NOT DISTINCT FROM v.radius
                         AND s.status = 'ACTIVE')`,
  sitesParams,
)).rows[0].n);
let nSites = 0;
if (DRY) nSites = sitesDrift;
else if (sitesDrift) {
  // Upsert menyentuh seluruh 4 baris seed; nSites dilaporkan = jumlah baris yang drift/belum ada
  // ( rowCount DO UPDATE akan menghitung semua baris yang di-touch, termasuk yang tidak drift).
  await client.query(
    `INSERT INTO sites (id, site_name, location, business_unit, latitude, longitude, radius_meters, status)
     SELECT s.id, s.site_name, s.location, s.business_unit, s.lat, s.lng, s.radius, 'ACTIVE'
     FROM unnest($1::text[], $2::text[], $3::text[], $4::text[], $5::numeric[], $6::numeric[], $7::int[]) AS s(id, site_name, location, business_unit, lat, lng, radius)
     ON CONFLICT (id) DO UPDATE SET
       site_name = EXCLUDED.site_name,
       location = EXCLUDED.location,
       business_unit = EXCLUDED.business_unit,
       latitude = EXCLUDED.latitude,
       longitude = EXCLUDED.longitude,
       radius_meters = EXCLUDED.radius_meters,
       status = 'ACTIVE'`,
    [SITES.map((s) => s.id), SITES.map((s) => s.site_name), SITES.map((s) => s.location),
     SITES.map((s) => s.business_unit), SITES.map((s) => s.lat), SITES.map((s) => s.lng), SITES.map((s) => s.radius)],
  );
  nSites = sitesDrift;
}

// 7) employees_core realign NRP001–NRP010 → kontrak dummy-reconciliation-guard (NUll-safe:
//    selalu tulis ulang 5 kolom, jangan biarkan NULL sisa baseline). Hanya NRP001–010;
//    NRP100–106 (admin) dibiarkan apa adanya.
const CORE_MAP = {
  NRP001: ['BU04', 'HQ', 'KORPORAT', 'CORP', 'SITE-HQ-01'],
  NRP002: ['BU04', 'HQ', 'HRD', 'HRD', 'SITE-HQ-01'],
  NRP003: ['BU01', 'MINING', 'MINING', 'MIN', 'SITE-MINING-01'],
  NRP004: ['BU01', 'MINING', 'MINING', 'MIN', 'SITE-MINING-01'],
  NRP005: ['BU01', 'MINING', 'MINING', 'MIN', 'SITE-MINING-01'],
  NRP006: ['BU02', 'ESTATE', 'ESTATE', 'EST', 'SITE-ESTATE-01'],
  NRP007: ['BU02', 'ESTATE', 'ESTATE', 'EST', 'SITE-ESTATE-01'],
  NRP008: ['BU03', 'MILL', 'MILL', 'MIL', 'SITE-MILL-01'],
  NRP009: ['BU03', 'MILL', 'MILL', 'MIL', 'SITE-MILL-01'],
  NRP010: ['BU04', 'HQ', 'HRD', 'HRD', 'SITE-HQ-01'],
};
const coreRows = (await client.query(
  `SELECT nrp, business_unit_id, business_unit, divisi, divisi_code, site_id
     FROM employees_core WHERE nrp LIKE 'NRP%' ORDER BY nrp`,
)).rows;
const coreMisaligned = coreRows.filter((r) => {
  const m = CORE_MAP[r.nrp];
  if (!m) return false; // NRP100–106 admin: tidak bagian kontrak guard
  return r.business_unit_id !== m[0] || (r.business_unit ?? '').toUpperCase() !== m[1]
    || (r.divisi ?? '').toUpperCase() !== m[2] || (r.divisi_code ?? '').toUpperCase() !== m[3]
    || r.site_id !== m[4];
});
// Apply hanya meng-UPDATE baris yang benar-benar mismatch (bukan tulis-ulang 10 baris):
// nCore = jumlah baris yang benar-benar diperbaiki; baris sudah-kontrak tidak disentuh.
let nCore = 0;
if (DRY) nCore = coreMisaligned.length;
else {
  for (const r of coreMisaligned) {
    const m = CORE_MAP[r.nrp];
    nCore += (await client.query(
      `UPDATE employees_core
          SET business_unit_id = $2, business_unit = $3, divisi = $4, divisi_code = $5, site_id = $6
        WHERE nrp = $1`,
      [r.nrp, m[0], m[1], m[2], m[3], m[4]],
    )).rowCount;
  }
}
const coreGuardAda = coreRows.filter((r) => CORE_MAP[r.nrp]).length;
// Baris NRP001–010 yang hilang sama sekali = juga pelanggaran (dihitung di recon_bad;
// realign hanya bisa memperbaiki yang ADA — verifikasi akhir tetap kunci 10/10 hadir).
const coreHilang = 10 - coreGuardAda;

// 8) VERIFY — tanpa nilai sensitif; exit tanpa rollback (keputusan (e)).
//    DRY: verdict dievaluasi atas PROYEKSI pasca-apply (dry tidak menulis apa pun).
let v;
if (DRY) {
  v = {
    core: awal.core,
    ext: Number(awal.ext) + nExt,
    roles: awal.roles,
    pw: Number(awal.pw) + pwBaru,
    rr_true: 0,
    auth_linked: awal.auth_linked,
    // DRY: baris VERIFY menampilkan STATE LIVE (belum ada yang ditulis) — inilah alasan
    // run diperlukan. Verdict di bawah tetap dievaluasi atas PROYEKSI pasca-apply.
    sites_ok: Number(awal.sites_all),
    recon_bad: coreMisaligned.length + coreHilang,
  };
} else {
  v = (await client.query(`
  SELECT (SELECT COUNT(*) FROM employees_core WHERE nrp LIKE 'NRP%') AS core,
         (SELECT COUNT(*) FROM employees_extended) AS ext,
         (SELECT COUNT(*) FROM user_roles WHERE nrp LIKE 'NRP%') AS roles,
         (SELECT COUNT(*) FROM worker_passwords) AS pw,
         (SELECT COUNT(*) FROM worker_passwords WHERE reset_required = true) AS rr_true,
         (SELECT COUNT(*) FROM employees_core WHERE nrp LIKE 'NRP%' AND auth_id IS NOT NULL) AS auth_linked,
         (SELECT COUNT(*) FROM sites WHERE business_unit IN ('HQ','MINING','ESTATE','MILL') AND status = 'ACTIVE') AS sites_ok,
         (SELECT COUNT(*) FROM employees_core c
           WHERE c.nrp IN ('NRP001','NRP002','NRP003','NRP004','NRP005','NRP006','NRP007','NRP008','NRP009','NRP010')
             AND NOT (c.business_unit_id = (CASE c.nrp
                     WHEN 'NRP001' THEN 'BU04' WHEN 'NRP002' THEN 'BU04' WHEN 'NRP003' THEN 'BU01'
                     WHEN 'NRP004' THEN 'BU01' WHEN 'NRP005' THEN 'BU01' WHEN 'NRP006' THEN 'BU02'
                     WHEN 'NRP007' THEN 'BU02' WHEN 'NRP008' THEN 'BU03' WHEN 'NRP009' THEN 'BU03'
                     ELSE 'BU04' END)
                   AND upper(coalesce(c.business_unit,'')) = (CASE c.nrp
                     WHEN 'NRP003' THEN 'MINING' WHEN 'NRP004' THEN 'MINING' WHEN 'NRP005' THEN 'MINING'
                     WHEN 'NRP006' THEN 'ESTATE' WHEN 'NRP007' THEN 'ESTATE' WHEN 'NRP008' THEN 'MILL'
                     WHEN 'NRP009' THEN 'MILL' WHEN 'NRP010' THEN 'HQ' ELSE 'HQ' END)
                   AND upper(coalesce(c.divisi,'')) = (CASE c.nrp
                     WHEN 'NRP002' THEN 'HRD' WHEN 'NRP003' THEN 'MINING' WHEN 'NRP004' THEN 'MINING'
                     WHEN 'NRP005' THEN 'MINING' WHEN 'NRP006' THEN 'ESTATE' WHEN 'NRP007' THEN 'ESTATE'
                     WHEN 'NRP008' THEN 'MILL' WHEN 'NRP009' THEN 'MILL' WHEN 'NRP010' THEN 'HRD'
                     ELSE 'KORPORAT' END)
                   AND upper(coalesce(c.divisi_code,'')) = (CASE c.nrp
                     WHEN 'NRP002' THEN 'HRD' WHEN 'NRP003' THEN 'MIN' WHEN 'NRP004' THEN 'MIN'
                     WHEN 'NRP005' THEN 'MIN' WHEN 'NRP006' THEN 'EST' WHEN 'NRP007' THEN 'EST'
                     WHEN 'NRP008' THEN 'MIL' WHEN 'NRP009' THEN 'MIL' WHEN 'NRP010' THEN 'HRD'
                     ELSE 'CORP' END)
                   AND c.site_id = (CASE c.nrp
                     WHEN 'NRP003' THEN 'SITE-MINING-01' WHEN 'NRP004' THEN 'SITE-MINING-01'
                     WHEN 'NRP005' THEN 'SITE-MINING-01' WHEN 'NRP006' THEN 'SITE-ESTATE-01'
                     WHEN 'NRP007' THEN 'SITE-ESTATE-01' WHEN 'NRP008' THEN 'SITE-MILL-01'
                     WHEN 'NRP009' THEN 'SITE-MILL-01' ELSE 'SITE-HQ-01' END))) AS recon_bad,
         (SELECT 10 - COUNT(*) FROM employees_core
           WHERE nrp IN ('NRP001','NRP002','NRP003','NRP004','NRP005','NRP006','NRP007','NRP008','NRP009','NRP010')) AS recon_missing`)).rows[0];
  v.recon_bad = Number(v.recon_bad) + Number(v.recon_missing);
}
console.log(`${tag}extended=+${nExt}, roles=+${nRole}, pw=+${pwBaru} baru / ${pwUpdate} update, reset_required cleared=+${nRR}, auth_id sync=+${nAuth}, sites=+${nSites}, core realign=+${nCore}`);
console.log(`${tag}VERIFY: core=${v.core} ext=${v.ext} roles=${v.roles} pw=${v.pw} rr_true=${v.rr_true} auth_linked=${v.auth_linked} sites_ok=${v.sites_ok} recon_bad=${v.recon_bad}`);
// Verdict: DRY memproyeksikan sites/recon ke kondisi pasca-apply (sites + yang akan di-insert;
// recon_bad = baris NRP001–010 yang hilang — semua yang ADA pasti di-realign). APPLY = live.
const sitesOkFinal = DRY ? Number(awal.sites_all) + nSites : Number(v.sites_ok);
const reconBadFinal = DRY ? coreHilang : Number(v.recon_bad);
const ok = Number(v.core) === 17 && Number(v.ext) === 17 && Number(v.roles) === 17 &&
  Number(v.pw) >= 17 && Number(v.rr_true) === 0 && Number(v.auth_linked) === 17 &&
  sitesOkFinal === 4 && reconBadFinal === 0;
console.log(ok ? 'HASIL: PASS' : 'HASIL: GAGAL — periksa di atas (tanpa rollback, keputusan (e))');
await client.end();
process.exit(ok ? 0 : 1);
