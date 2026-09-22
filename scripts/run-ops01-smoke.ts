#!/usr/bin/env node
/**
 * scripts/run-ops01-smoke.ts — SATU perintah untuk menutup item OPS-01.
 *
 * OPS-01 (AGENTS.md §5.8): "Smoke runtime WorkerProfile belum dijalankan" —
 * login worker → WorkerProfile → edit 1 kolom → simpan → reload. Grant
 * `EXECUTE TO authenticated` sudah termigrasi (222); yang kurang hanyalah
 * pembuktian runtime di browser.
 *
 * Perintah ini melakukan tiga hal sekaligus:
 *   1. mengambil kredensial worker (env, atau `supabase/akun/akun.txt` yang gitignored
 *      — kredensial TIDAK PERNAH masuk ke berkas yang di-commit maupun ke log);
 *   2. menjalankan Playwright HEADED (supaya Anda benar-benar melihat alurnya) pada
 *      `tests/e2e/worker-profile-smoke.spec.ts`;
 *   3. menulis hasilnya ke `agentsLogs_YYYY-MM.md` lewat `scripts/safe-file-writer.ts`,
 *      plus log mentah ke `.agents/logs/`.
 *
 * Pakai:
 *   npm run smoke:ops01                 # headed, catat hasil ke log
 *   npm run smoke:ops01 -- --check      # hanya cek prasyarat (tanpa browser, tanpa tulis log)
 *   npm run smoke:ops01 -- --headless   # tanpa jendela browser (mis. dari CI lokal)
 *   npm run smoke:ops01 -- --close      # bila LULUS: sekaligus tandai OPS-01 ✅ SELESAI
 *   OPS01_EMAIL=... OPS01_PASSWORD=... npm run smoke:ops01   # override kredensial
 *
 * Catatan kejujuran: runner ini TIDAK menutup OPS-01 secara default. Item itu
 * menunggu verifikasi user; `--close` hanya dipakai setelah Anda menyetujuinya.
 * Tanpa `--close`, judul entri log sengaja TIDAK memuat kata DONE/SELESAI supaya
 * guard `work-queue-consistency` tetap konsisten (item masih OPEN).
 */
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { writeFileSafe } from './safe-file-writer.ts';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const argv = process.argv.slice(2);
const HEADED = !argv.includes('--headless');
const CLOSE = argv.includes('--close');
const CHECK_ONLY = argv.includes('--check');

// Keputusan (c) 2026-09-22: smoke runner SELALU seed --apply dulu (idempoten —
// ON CONFLICT DO NOTHING), supaya pasca reset DB smoke self-sufficient.
if (!CHECK_ONLY) {
  const r = spawnSync('node', ['supabase/scripts/seed-test-workers.mjs', '--apply'], { stdio: 'inherit', cwd: ROOT });
  if (r.status !== 0) { console.error('seed-test-workers GAGAL — smoke dihentikan.'); process.exit(r.status ?? 1); }
}

interface Kredensial {
  nrp: string;
  email: string;
  password: string;
  sumber: string;
}

/**
 * Pilih baris akun dari akun.txt. Tanpa OPS01_NRP, akun dipilih dengan mencocokkan
 * role di DB live (WAJIB role='worker' + reset_required=false) — pelajaran 2026-09-20:
 * NRP002 ternyata admin_hrd sehingga pasca-reload app memantul ke /admin dan smoke
 * gagal walau alur simpannya sendiri benar.
 */
async function pilihBarisAkun(
  baris: { nrp: string; email: string; password: string }[],
): Promise<{ terpilih: (typeof baris)[number] | null; catatan: string }> {
  const diminta = process.env.OPS01_NRP;
  if (diminta) {
    const pilih = baris.find((b) => b.nrp === diminta);
    return {
      terpilih: pilih ?? null,
      catatan: pilih ? `dipilih eksplisit via OPS01_NRP=${diminta} (role TIDAK diverifikasi)` : '',
    };
  }

  try {
    const dotenv = await import('dotenv');
    dotenv.config({ path: path.join(ROOT, '.env.local'), quiet: true });
    const { Client } = await import('pg');
    const c = new Client({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });
    await c.connect();
    const r = await c.query(
      "select u.nrp from user_roles u join worker_passwords w on w.nrp = u.nrp " +
        "where u.role = 'worker' and w.reset_required = false order by u.nrp",
    );
    await c.end();
    const workerNrp = new Set<string>(r.rows.map((x: { nrp: string }) => x.nrp));
    const pilih = baris.find((b) => workerNrp.has(b.nrp));
    if (pilih) {
      return { terpilih: pilih, catatan: 'role=worker + reset_required=false terverifikasi ke DB live' };
    }
    return { terpilih: null, catatan: 'tidak ada akun role=worker di akun.txt yang cocok dengan DB' };
  } catch (error) {
    // DB tidak terjangkau — fallback perilaku lama (baris pertama) dengan peringatan.
    return {
      terpilih: baris[0] ?? null,
      catatan: `PERINGATAN: role tidak terverifikasi (gagal query DB: ${(error as Error).message})`,
    };
  }
}

/** Ambil kredensial worker: env dulu, lalu `supabase/akun/akun.txt` (gitignored). */
async function resolveKredensial(): Promise<Kredensial | null> {
  const email = process.env.OPS01_EMAIL;
  const password = process.env.OPS01_PASSWORD;
  if (email && password) {
    return { nrp: process.env.OPS01_NRP ?? '(env)', email, password, sumber: 'env' };
  }

  const akun = path.join(ROOT, 'supabase', 'akun', 'akun.txt');
  if (!fs.existsSync(akun)) return null;
  const baris = fs.readFileSync(akun, 'utf8').split(/\r?\n/);
  // Tabel worker berbasis TAB dengan kolom variabel — baris nyata punya 5 kolom:
  //   nrp \t email \t temp_password \t (kosong) \t catatan
  // Jadi diparsing per kolom: kolom pertama = NRP, kolom berikut yang memuat '@'
  // = email, dan kolom SETELAH email = password. Catatan tambahan di kanan
  // (mis. "NRP002 (password = NIK)") tidak boleh membuat baris gagal parse.
  const terparse: { nrp: string; email: string; password: string }[] = [];
  for (const l of baris) {
    const kolom = l.split('\t').map((v) => v.trim());
    if (!/^NRP\d+$/.test(kolom[0] ?? '')) continue;
    const idxEmail = kolom.findIndex((v, i) => i > 0 && v.includes('@'));
    if (idxEmail < 0) continue;
    const password = kolom[idxEmail + 1];
    if (!password) continue;
    terparse.push({ nrp: kolom[0], email: kolom[idxEmail], password });
  }
  if (terparse.length === 0) return null;

  const { terpilih, catatan } = await pilihBarisAkun(terparse);
  if (catatan) console.log(`pemilihan  : ${catatan}`);
  if (!terpilih) return null;
  return { ...terpilih, sumber: 'supabase/akun/akun.txt' };
}

/** Berkas log bulan berjalan (pola agentsLogs_YYYY-MM.md), fallback indeks. */
function logBulanIni(): string {
  const d = new Date();
  const nama = `agentsLogs_${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}.md`;
  const full = path.join(ROOT, nama);
  return fs.existsSync(full) ? full : path.join(ROOT, 'agentsLogs.md');
}

async function main(): Promise<number> {
  const kredensial = await resolveKredensial();
  if (!kredensial) {
    console.error(
      'GAGAL: kredensial worker tidak ditemukan.\n' +
        '  Set OPS01_EMAIL + OPS01_PASSWORD, atau pastikan supabase/akun/akun.txt ada\n' +
        '  dengan tabel worker "<NRP> <email> <password>".',
    );
    return 2;
  }

  console.log(`=== OPS-01 smoke WorkerProfile ===`);
  console.log(`worker  : ${kredensial.nrp} (${kredensial.sumber})`);
  console.log(`mode    : ${HEADED ? 'headed (browser terlihat)' : 'headless'}`);

  // --check: verifikasi prasyarat TANPA menjalankan browser dan TANPA menulis
  // log. Berguna sebelum smoke sungguhan yang menyentuh profil di DB live.
  if (CHECK_ONLY) {
    const spec = path.join(ROOT, 'tests', 'e2e', 'worker-profile-smoke.spec.ts');
    const versi = spawnSync('npx', ['playwright', '--version'], {
      cwd: ROOT,
      encoding: 'utf8',
      shell: true,
    });
    const daftar = spawnSync('npx', ['playwright', 'test', '--list'], {
      cwd: ROOT,
      encoding: 'utf8',
      shell: true,
    });
    const daftarKeluar = `${daftar.stdout ?? ''}${daftar.stderr ?? ''}`;
    const terdaftar = /worker-profile-smoke\.spec\.ts/.test(daftarKeluar);
    console.log(`spec    : ${fs.existsSync(spec) ? 'ada' : 'TIDAK ADA'} (${path.relative(ROOT, spec)})`);
    console.log(`playwright : ${(versi.stdout ?? '').trim() || '(tidak terdeteksi)'}`);
    console.log(`test terdaftar : ${terdaftar ? 'ya' : 'TIDAK'} (npx playwright test --list)`);
    if (!terdaftar) console.log(daftarKeluar.split('\n').slice(0, 12).join('\n'));
    console.log(
      '\n--check selesai: prasyarat diperiksa, browser TIDAK dijalankan dan log TIDAK ditulis.',
    );
    return terdaftar ? 0 : 1;
  }

  const args = [
    'playwright',
    'test',
    'tests/e2e/worker-profile-smoke.spec.ts',
    '--project=chromium',
    ...(HEADED ? ['--headed'] : []),
  ];
  const mulai = Date.now();
  const hasil = spawnSync('npx', args, {
    cwd: ROOT,
    encoding: 'utf8',
    shell: true, // npx adalah .cmd di Windows (ENVIRONMENT_TRAPS §6.3)
    env: {
      ...process.env,
      OPS01_EMAIL: kredensial.email,
      OPS01_PASSWORD: kredensial.password,
      OPS01_NRP: kredensial.nrp,
    },
    timeout: 10 * 60 * 1000,
  });
  const keluaran = `${hasil.stdout ?? ''}${hasil.stderr ?? ''}`;
  const durasi = ((Date.now() - mulai) / 1000).toFixed(1);
  const exitCode = hasil.status ?? -1;
  const lulus = exitCode === 0;

  process.stdout.write(keluaran);

  // Log mentah (gitignored) — sumber bukti lengkap bila perlu diperiksa.
  const stempel = new Date().toISOString().replace(/[:.]/g, '-');
  const logMentah = path.join(ROOT, '.agents', 'logs', `ops01-smoke-${stempel}.log`);
  fs.mkdirSync(path.dirname(logMentah), { recursive: true });
  writeFileSafe(logMentah, `exit=${exitCode} durasi=${durasi}s headed=${HEADED}\n\n${keluaran}`, {
    mode: 'overwrite',
  });

  // ── Pemulihan residu (SQL-12) ───────────────────────────────────────────────
  // Bila nilai asli field kosong, UI tidak bisa mengosongkannya kembali
  // (RPC worker_update_profile memakai COALESCE — lihat spec smoke). Spec
  // menulis penanda residu; nilai asli dipulihkan di sini via SQL langsung.
  let pemulihanInfo: string | null = null;
  const penanda = path.join(ROOT, '.agents', 'logs', 'ops01-residue.json');
  if (fs.existsSync(penanda)) {
    try {
      const residu = JSON.parse(fs.readFileSync(penanda, 'utf8')) as {
        nrp: string;
        tabel: string;
        field: string;
        original: string | null;
      };
      const FIELD_AMAN = new Set([
        'agama', 'no_hp', 'alamat', 'media_sosial', 'jenjang_pendidikan',
        'no_bpjs_kesehatan', 'no_bpjs_ketenagakerjaan', 'riwayat_penyakit',
        'komorbid', 'alergi', 'nama_bank', 'no_rekening', 'nama_rekening',
        'lokasi_penempatan',
      ]);
      if (
        residu.tabel === 'employees_extended' &&
        FIELD_AMAN.has(residu.field) &&
        /^NRP\d+$/.test(residu.nrp)
      ) {
        const dotenv = await import('dotenv');
        dotenv.config({ path: path.join(ROOT, '.env.local'), quiet: true });
        const { Client } = await import('pg');
        const c = new Client({
          connectionString: process.env.DATABASE_URL,
          ssl: { rejectUnauthorized: false },
        });
        await c.connect();
        await c.query(`update ${residu.tabel} set ${residu.field} = $1 where nrp = $2`, [
          residu.original,
          residu.nrp,
        ]);
        const ver = await c.query(`select ${residu.field} as v from ${residu.tabel} where nrp = $1`, [
          residu.nrp,
        ]);
        await c.end();
        pemulihanInfo =
          `${residu.tabel}.${residu.field} ${residu.nrp} dipulihkan ke ` +
          `${JSON.stringify(ver.rows[0]?.v)} via SQL (SQL-12: UI tidak bisa mengosongkan field)`;
        console.log(`pemulihan  : ${pemulihanInfo}`);
      }
    } catch (error) {
      pemulihanInfo = `GAGAL — periksa manual: ${(error as Error).message}`;
      console.error('pemulihan residu GAGAL:', (error as Error).message);
    } finally {
      fs.rmSync(penanda, { force: true });
    }
  }

  if (/Executable doesn't exist|Please run the following command to download/i.test(keluaran)) {
    console.error('\nBrowser Playwright belum terpasang. Jalankan: npx playwright install chromium');
  }

  // ── Catat ke agentsLogs (judul tanpa DONE kecuali --close) ────────────────
  const tanggal = new Date().toISOString().slice(0, 10);
  const judul = CLOSE && lulus
    ? `## [${tanggal}] OPS-01 smoke WorkerProfile (worker ${kredensial.nrp}) — DONE`
    : `## [${tanggal}] OPS-01 smoke WorkerProfile (worker ${kredensial.nrp}) — hasil: ${
        lulus ? 'LULUS' : 'GAGAL'
      }`;
  const catatan = [
    '',
    judul,
    `- Dijalankan: \`npm run smoke:ops01${HEADED ? '' : ' -- --headless'}\` · exit **${exitCode}** · ${durasi}s`,
    `- Worker uji: \`${kredensial.nrp}\` (kredensial dari \`${kredensial.sumber}\`, tidak pernah ditulis ke repo/log).`,
    `- Alur yang dibuktikan: login worker → \`/worker/profile\` → Edit → ubah kolom **Agama** → Simpan →`,
    '  reload → nilai PERSIST → pemulihan nilai asli (via UI, atau via SQL oleh runner bila aslinya kosong).',
    ...(pemulihanInfo ? [`- Pemulihan residu: ${pemulihanInfo}.`] : []),
    `- Log mentah: \`.agents/logs/${path.basename(logMentah)}\` (gitignored).`,
    lulus
      ? CLOSE
        ? '- Status AGENTS.md §5.8: OPS-01 ditandai **✅ SELESAI** oleh runner ini (`--close`).'
        : '- Status AGENTS.md §5.8: OPS-01 **masih OPEN** — jalankan ulang dengan `-- --close` setelah Anda menyetujui hasilnya.'
      : '- Status AGENTS.md §5.8: OPS-01 tetap OPEN (smoke GAGAL — lihat log mentah).',
    '',
  ].join('\n');

  const berkasLog = logBulanIni();
  writeFileSafe(berkasLog, catatan, { mode: 'append' });
  console.log(`\nentri log   : ${path.relative(ROOT, berkasLog)} (+${catatan.length} byte)`);
  console.log(`log mentah  : ${path.relative(ROOT, logMentah)}`);

  // ── Opsi --close: tandai OPS-01 ✅ (hanya bila LULUS) ─────────────────────
  if (CLOSE && lulus) {
    const agents = path.join(ROOT, 'AGENTS.md');
    const isi = fs.readFileSync(agents, 'utf8');
    // Ganti SEL STATUS (sel terakhir), bukan menambah kolom: potong pada pipe
    // kedua-dari-belakang, lalu tulis ulang sel terakhirnya. \r? — AGENTS.md
    // bisa ber-EOL CRLF, dan tanpa itu regex gagal cocok.
    const adaBaris = /^\| OPS-01 \|.*\|\r?$/m.test(isi);
    const baru = isi.replace(/^\| OPS-01 \|.*\|\r?$/m, (baris) => {
      const akhir = baris.lastIndexOf('|');
      const sebelumStatus = baris.lastIndexOf('|', akhir - 1);
      const prefix = baris.slice(0, sebelumStatus).trimEnd();
      return (
        `${prefix} | ✅ SELESAI (smoke \`npm run smoke:ops01\` LULUS untuk worker ` +
        `${kredensial.nrp}; bukti di entri log ${tanggal}) |`
      );
    });
    if (!adaBaris) {
      console.error('PERINGATAN: baris OPS-01 tidak ketemu di AGENTS.md §5.8 — status TIDAK diubah.');
    } else if (baru === isi) {
      // Baris sudah berisi status yang persis sama (idempoten) — bukan kegagalan.
      console.log('status      : baris OPS-01 di §5.8 sudah berisi status ini — tanpa perubahan.');
    } else {
      writeFileSafe(agents, baru, { mode: 'overwrite' });
      console.log('status      : OPS-01 ditandai ✅ SELESAI di AGENTS.md §5.8 (--close)');
      console.log('              (setelah yakin, pindahkan ke agentsLogs & hapus dari §5.8 — §0.4)');
    }
  } else if (!lulus) {
    console.log('\nSmoke GAGAL — OPS-01 tetap OPEN. Periksa log mentah di atas.');
  } else {
    console.log(
      '\nLULUS. Bila Anda menyetujuinya, tutup item dengan: npm run smoke:ops01 -- --close',
    );
  }

  return lulus ? 0 : 1;
}

process.exitCode = 1;
void main().then((code) => {
  process.exitCode = code;
});
