// scripts/provision-worker-auth.mjs
// Jalankan LOKAL (PowerShell, di root project):
//   $env:VITE_SUPABASE_URL="https://verwobaejumvpagwynae.supabase.co"
//   $env:SUPABASE_SERVICE_ROLE_KEY="<service key>"
//   node scripts/provision-worker-auth.mjs --dry   # lihat dulu, tidak menulis
//   node scripts/provision-worker-auth.mjs --run   # eksekusi
import { createClient } from '@supabase/supabase-js';
import { createHash, randomBytes } from 'node:crypto';
import { writeFileSync } from 'node:fs';

const url = process.env.VITE_SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
const DRY = process.argv.includes('--dry');
const RUN = process.argv.includes('--run');
const DOMAIN = '@insightwos.internal';

if (!url || !key) { console.error('Set VITE_SUPABASE_URL dan SUPABASE_SERVICE_ROLE_KEY dulu'); process.exit(1); }
if (!DRY && !RUN) { console.log('Gunakan --dry atau --run'); process.exit(1); }

const sb = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });

const emailNrp = (nrp) => String(nrp).toLowerCase().trim() + DOMAIN;
const sha256 = (pass, salt) => createHash('sha256').update(pass + salt).digest('hex');
const tempPass = () => randomBytes(12).toString('base64url');

async function existingEmails() {
  const out = new Set();
  let page = 1;
  for (;;) {
    const { data, error } = await sb.auth.admin.listUsers({ page, perPage: 1000 });
    if (error) throw error;
    (data.users || []).forEach(u => out.add(u.email?.toLowerCase()));
    if (!data.hasNextPage) break;
    page++;
  }
  return out;
}

async function main() {
  // 1. Calon = semua karyawan yang belum punya auth_id
  const { data: emps, error: e1 } = await sb.from('employees_core').select('nrp,nama').is('auth_id', null);
  if (e1) throw e1;

  // 2. Verifikasi duplikat NRP (case-insensitive) — berhenti jika ada
  const seen = new Map();
  let dups = 0;
  for (const x of emps) {
    const k = String(x.nrp).toLowerCase().trim();
    if (seen.has(k)) { console.warn('NRP DUPLIKAT:', seen.get(k), 'vs', x.nrp); dups++; }
    else seen.set(k, x.nrp);
  }
  if (dups > 0) { console.error('Ada duplikat NRP — perbaiki dulu, eksekusi dibatalkan.'); process.exit(1); }

  // 3. Email yang sudah terpakai di auth.users
  const existing = await existingEmails();
  const rows = [];

  if (DRY) {
    console.log('\n[DRY RUN] Akan diprovisi:', emps.length, 'karyawan');
    for (const emp of emps) {
      const mail = emailNrp(emp.nrp);
      console.log(' -', emp.nrp, '\t', mail, existing.has(mail) ? '(SUDAH ADA → akan di-skip)' : '');
    }
    return;
  }

  for (const emp of emps) {
    const mail = emailNrp(emp.nrp);
    if (existing.has(mail)) { console.log('Skip (sudah ada):', mail); continue; }

    const pass = tempPass();
    const salt = randomBytes(12).toString('hex');
    const legacyHash = sha256(pass, salt);

    const { data: created, error: ce } = await sb.auth.admin.createUser({
      email: mail,
      password: pass,
      email_confirm: true,
      user_metadata: { nrp: emp.nrp, nama: emp.nama }
    });
    if (ce && (ce.status === 422 || /already|registered/i.test(ce.message || ''))) {
      console.warn('Skip (auth user sudah ada):', mail); continue;
    }
    if (ce) { console.error('GAGAL createUser:', emp.nrp, ce.message); continue; }

    const { error: ue } = await sb.from('employees_core').update({ auth_id: created.user.id }).eq('nrp', emp.nrp);
    if (ue) { console.error('GAGAL link auth_id:', emp.nrp, ue.message); continue; }

    // Sinkronkan worker_passwords dengan password sementara yang SAMA
    // (login_worker masih dipakai UI → harus lolos dengan password yang sama)
    const { error: we } = await sb.from('worker_passwords').upsert({
      nrp: emp.nrp, password_hash: legacyHash, salt,
      is_active: true, reset_required: false, attempts: 0, blocked_until: null,
      updated_at: new Date().toISOString()
    }, { onConflict: 'nrp' });
    if (we) console.warn('GAGAL update worker_passwords:', emp.nrp, we.message);

    rows.push({ nrp: emp.nrp, email: mail, temp_password: pass });
    existing.add(mail);
  }

  if (rows.length) {
    const csv = 'nrp,email,temp_password\n' + rows.map(r => `${r.nrp},${r.email},${r.temp_password}`).join('\n');
    writeFileSync('provision-results.csv', csv + '\n');
    console.log('\nSelesai → provision-results.csv (BERISI PASSWORD — jangan di-commit, hapus setelah dibagikan)');
  } else {
    console.log('Tidak ada yang perlu diprovisi.');
  }
}

main().catch(err => { console.error(err); process.exit(1); });
