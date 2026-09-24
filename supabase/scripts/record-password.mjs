#!/usr/bin/env node
/**
 * record-password.mjs — update kolom password aktif di supabase/akun/akun.txt per NRP.
 * OPS-06 Part 2: setelah ganti/reset password, akun.txt harus ikut dicatat (satu sumber
 * kredensial plaintext repo — gitignored).
 *
 * Format section worker (baris berawalan NRPxxx):
 *   kol0=NRP | kol1=email | kol2=NIK atau password lama | kol3=kosong | kol4=PASSWORD AKTIF
 * Password aktif = kolom non-kosong TERAKHIR yang bukan email (scan kanan→kiri).
 *
 * Pemakaian:
 *   node supabase/scripts/record-password.mjs --nrp NRP002 --pass "passwordBaru"
 *   node supabase/scripts/record-password.mjs --nrp NRP002 --from-env E2E_WORKER_PASS
 *   (--from-env membaca nilai dari .env.local — password TIDAK masuk argv / output shell)
 *
 * Aturan: TIDAK mencetak password ke stdout/stderr. Exit 0 sukses, exit 1 NRP tidak ketemu.
 */
import fs from 'node:fs';
import path from 'node:path';

const FILE = path.resolve('supabase/akun/akun.txt');
const args = process.argv.slice(2);
function argOf(name) {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] ? args[i + 1] : null;
}
const nrp = (argOf('--nrp') || '').toUpperCase().trim();
const fromEnv = argOf('--from-env');
const pass = fromEnv
  ? (() => {
      const raw = fs.readFileSync(path.resolve('.env.local'), 'utf8');
      const m = new RegExp('^' + fromEnv + '=(.+)$', 'm').exec(raw);
      return m ? m[1].trim().replace(/^["']|["']$/g, '') : null;
    })()
  : argOf('--pass');

if (!nrp || !pass) {
  console.error('Pemakaian: node supabase/scripts/record-password.mjs --nrp NRPxxx (--pass "password" | --from-env NAMA_VARIABEL)');
  process.exit(1);
}

const raw = fs.readFileSync(FILE, 'utf8');
let eol = '\n';
if (raw.includes('\r\n')) eol = '\r\n';
else if (raw.includes('\r')) eol = '\r';
const hadTrailing = /\r?\n$/.test(raw);
const lines = raw.split(/\r?\n/);
if (lines.length && lines[lines.length - 1] === '') lines.pop();

let hit = 0;
const out = lines.map((line) => {
  if (!line.trim()) return line;
  const f = line.split('\t');
  if ((f[0] || '').toUpperCase().trim() !== nrp) return line;
  hit++;
  // Password aktif = kolom non-kosong TERAKHIR yang bukan email (kol4 pada format saat ini).
  let idx = -1;
  for (let j = f.length - 1; j >= 1; j--) {
    const t = (f[j] || '').trim();
    if (t && !t.includes('@')) { idx = j; break; }
  }
  if (idx < 0) idx = f.length - 1;
  f[idx] = pass;
  return f.join('\t');
});

if (hit === 0) {
  console.error(`FATAL: NRP ${nrp} tidak ditemukan — tidak ada baris section worker dengan kol0=${nrp}`);
  process.exit(1);
}

fs.writeFileSync(FILE, out.join(eol) + (hadTrailing ? eol : ''), { encoding: 'utf8' });
console.log(`OK: password ${nrp} diperbarui di ${path.relative(process.cwd(), FILE)} (kolom password aktif; password tidak dicetak)`);
