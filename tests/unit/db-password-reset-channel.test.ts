// @vitest-environment node
/**
 * db-password-reset-channel.test.ts — penjaga Fix #5 (P1-46-01, P1-74-01).
 *
 * KENAPA ADA
 *   Sebelum Fix #5, edge `password-reset` selalu menjawab
 *   "Jika email terdaftar, link reset sudah dikirim." — padahal TIDAK ADA
 *   provider email sama sekali (nol kode SMTP/Resend; `pg_net` tidak terpasang).
 *   Token 6-digit dibuat, di-hash ke `otp_store`, lalu dibuang. Pengguna diberi
 *   tahu surat sedang jalan, padahal tidak ada surat. Ini kebohongan yang
 *   tampak sebagai fitur.
 *
 *   Fix #5 memindahkan keputusan pesan ke setting `password_reset_channel`
 *   (migrasi 254): `'admin'` = pesan jujur ("hubungi admin"), `'email'` =
 *   pesan anti-enumerasi lama — hanya benar setelah provider benar-benar ada.
 *
 * CARA TEST INI BEKERJA (membaca EFEK, bukan janji)
 *   - membaca setting di DB + membuktikan hanya `service_role` yang bisa
 *     membacanya (FORCE RLS, tanpa policy SELECT) — klaim desain di header 254
 *   - membaca SUMBER edge: helper `getResetMessage()` benar-benar ada, membaca
 *     key yang benar, dan literal pesan lama TIDAK lagi muncul di `return`
 *   - membuktikan UNIQUE(email) benar-benar MENOLAK duplikat (error 23505),
 *     bukan sekadar ada di katalog
 *
 * Bagian DB di-skip otomatis tanpa `DATABASE_URL` (lihat `tests/helpers/db`);
 * bagian sumber edge selalu jalan, termasuk di CI.
 */
import { describe, expect, it } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';
import { Client } from 'pg';
import { hasDb, readDatabaseUrl } from '../helpers/db';

const ROOT = path.resolve(import.meta.dirname, '..', '..');
const EDGE_SRC = path.join(ROOT, 'supabase', 'functions', 'password-reset', 'index.ts');

const DATABASE_URL = readDatabaseUrl();

async function withDb<T>(fn: (c: Client) => Promise<T>): Promise<T> {
  const c = new Client({ connectionString: DATABASE_URL, ssl: { rejectUnauthorized: false } });
  await c.connect();
  try {
    return await fn(c);
  } finally {
    await c.end();
  }
}

/** Transaksi yang selalu ROLLBACK, untuk test yang menulis. */
async function inRolledBackTx<T>(fn: (c: Client) => Promise<T>): Promise<T> {
  const c = new Client({ connectionString: DATABASE_URL, ssl: { rejectUnauthorized: false } });
  await c.connect();
  try {
    await c.query('BEGIN');
    try {
      return await fn(c);
    } finally {
      await c.query('ROLLBACK');
    }
  } finally {
    await c.end();
  }
}

describe.skipIf(!hasDb())('P1-74-01: email unik di employees_core', () => {
  it('constraint employees_core_email_unique ada dan bertipe UNIQUE', async () => {
    const r = await withDb((c) =>
      c.query(
        `select contype, pg_get_constraintdef(oid) as def
           from pg_constraint
          where conrelid = 'public.employees_core'::regclass
            and conname = 'employees_core_email_unique'`,
      ),
    );
    expect(
      r.rowCount,
      'constraint employees_core_email_unique hilang — dua karyawan bisa berbagi email, ' +
        'dan alur reset password berbasis email jadi ambigu (P1-74-01 kembali).',
    ).toBe(1);
    expect(r.rows[0].contype, 'constraint harus UNIQUE (contype = u)').toBe('u');
    expect(r.rows[0].def, 'definisi constraint harus UNIQUE (email)').toMatch(/UNIQUE \(email\)/i);
  });

  it('nol baris dengan email NULL atau kosong (prasyarat UNIQUE)', async () => {
    const r = await withDb((c) =>
      c.query(
        `select count(*)::int n from public.employees_core where email is null or btrim(email) = ''`,
      ),
    );
    expect(
      r.rows[0].n,
      'ada karyawan tanpa email — UNIQUE mengizinkan banyak NULL, jadi baris begini ' +
        'lolos masuk dan tidak pernah bisa dipakai untuk reset password.',
    ).toBe(0);
  });

  it('INSERT email duplikat DITOLAK dengan 23505 (efeknya, bukan katalognya)', async () => {
    const result = await inRolledBackTx(async (c) => {
      const src = await c.query<{ email: string }>(
        `select email from public.employees_core where email is not null order by nrp limit 1`,
      );
      if (src.rowCount === 0) return null;
      try {
        await c.query(
          `insert into public.employees_core (nrp, nama, nik, email)
           values ('F05_DUPLICATE_PROBE', 'Probe Fix 5', 'F05_DUPLICATE_PROBE', $1)`,
          [src.rows[0].email],
        );
        return { inserted: true, code: '', constraint: '' };
      } catch (e) {
        return {
          inserted: false,
          code: (e as { code?: string }).code ?? '',
          constraint: (e as { constraint?: string }).constraint ?? '',
        };
      }
    });

    if (result === null) return; // tabel kosong — tidak ada yang bisa diuji
    expect(
      result.inserted,
      'dua baris berbagi email yang sama BERHASIL dimasukkan — UNIQUE(email) tidak ' +
        'benar-benar berlaku (P1-74-01 belum tertutup).',
    ).toBe(false);
    expect(result.code, 'pelanggaran UNIQUE harus muncul sebagai SQLSTATE 23505').toBe('23505');
    expect(result.constraint).toBe('employees_core_email_unique');
  });
});

describe.skipIf(!hasDb())('P1-46-01: kanal reset password di public.settings', () => {
  it('setting password_reset_channel ada dan berisi kanal yang dikenal', async () => {
    const r = await withDb((c) =>
      c.query<{ value: string }>(
        `select value from public.settings where key = 'password_reset_channel'`,
      ),
    );
    expect(
      r.rowCount,
      "setting 'password_reset_channel' tidak ada — edge akan jatuh ke default 'admin' " +
        '(pesan jujur), tapi migrasi 254 seharusnya menanamnya secara eksplisit.',
    ).toBe(1);
    expect(
      ['admin', 'email'],
      `nilai '${r.rows[0].value}' tidak dikenal. Edge hanya mengenal 'email' (pesan ` +
        "anti-enumerasi) dan selainnya = 'admin' (pesan jujur), jadi nilai lain " +
        'menyembunyikan niat yang tidak terduga.',
    ).toContain(r.rows[0].value);
  });

  it('settings FORCE RLS tanpa policy SELECT — hanya service_role yang bisa baca', async () => {
    const rel = await withDb((c) =>
      c.query<{ relrowsecurity: boolean; relforcerowsecurity: boolean }>(
        `select relrowsecurity, relforcerowsecurity
           from pg_class
          where relname = 'settings' and relnamespace = 'public'::regnamespace`,
      ),
    );
    expect(rel.rowCount).toBe(1);
    expect(rel.rows[0].relrowsecurity, 'RLS harus aktif di settings').toBe(true);
    expect(
      rel.rows[0].relforcerowsecurity,
      'FORCE RLS mati — pemilik tabel (dan role lain) bisa membaca settings tanpa policy, ' +
        'padahal edge mengandalkan "hanya service_role" sebagai jaminan.',
    ).toBe(true);

    const pol = await withDb((c) =>
      c.query<{ n: number }>(
        `select count(*)::int n from pg_policies
          where schemaname = 'public' and tablename = 'settings' and cmd = 'SELECT'`,
      ),
    );
    expect(
      pol.rows[0].n,
      'muncul policy SELECT di settings — artinya authenticated bisa membaca flag kanal ' +
        'reset password langsung dari klien, memperluas permukaan yang tadinya service_role saja.',
    ).toBe(0);
  });
});

describe('P1-46-01: sumber edge password-reset memakai flag kanal', () => {
  const src = fs.readFileSync(EDGE_SRC, 'utf8');

  it('edge punya helper getResetMessage() yang membaca password_reset_channel', () => {
    expect(
      src,
      'edge kehilangan helper getResetMessage() — pesan lupa-password kembali hardcoded.',
    ).toMatch(/async function getResetMessage\(/);
    expect(src, 'helper harus membaca key yang benar').toMatch(/password_reset_channel/);
    expect(
      src,
      "helper harus membaca lewat adminClient (service_role) dari tabel settings — " +
        'tanpa itu RLS menolak dan pesan jatuh ke default.',
    ).toMatch(/\.from\("settings"\)/);
  });

  it('ketiga return action=request memakai resetMsg, bukan literal', () => {
    const literalInReturn =
      src.split('msg: "Jika email terdaftar, link reset sudah dikirim."').length - 1;
    expect(
      literalInReturn,
      'masih ada RETURN yang memakai literal pesan lama — pengguna tanpa provider email ' +
        'diberi tahu "link sudah dikirim". Literal itu hanya boleh hidup di konstanta ' +
        'RESET_MSG_EMAIL, yang cuma dipakai saat kanal benar-benar = email.',
    ).toBe(0);

    // Kedua konstanta wajib tetap ada: tanpa RESET_MSG_ADMIN, kanal default
    // kehilangan pesan jujurnya dan fix-nya tidak bermakna.
    expect(src, 'konstanta RESET_MSG_EMAIL hilang (pesan kanal email)').toMatch(
      /const RESET_MSG_EMAIL =\s*\n?\s*"Jika email terdaftar, link reset sudah dikirim\."/,
    );
    expect(src, 'konstanta RESET_MSG_ADMIN hilang (pesan jujur kanal default)').toMatch(
      /const RESET_MSG_ADMIN =\s*\n?\s*"Reset mandiri belum aktif\. Hubungi admin untuk reset password\."/,
    );

    const uses = src.split('msg: resetMsg').length - 1;
    expect(
      uses,
      'jumlah return action=request yang memakai resetMsg berubah. Kalau ada return baru, ' +
        'pastikan ia juga memakai resetMsg supaya pesannya jujur.',
    ).toBe(3);
  });
});
