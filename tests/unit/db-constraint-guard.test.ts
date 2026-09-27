// @vitest-environment node
/**
 * db-constraint-guard.test.ts — P1-58-01 (Akar B: "test memeriksa properti,
 * bukan efek"; di sini: constraint yang hilang tanpa penjaga).
 *
 * AUDIT BILANG (FORENSIC-RAW-batch-06, P1-58-01):
 *   "Tidak ada satu pun test untuk CHECK/UNIQUE constraint.
 *    `git grep -E "CHECK constraint|UNIQUE|pg_constraint" -- tests/` → NOL.
 *    P1-27-01 (0 CHECK di payroll), P1-27-02 (0 UNIQUE di leave), P1-27-03
 *    (tanpa UNIQUE(nrp,date) di hr_attendance) — semuanya tanpa penjaga.
 *    Siapa pun bisa menambah migrasi yang menghapusnya dan tidak ada yang berteriak."
 *
 * STATUS NYATA (diverifikasi read-only ke live, 2026-09-27):
 *   hr_payroll     → 0 CHECK, 0 UNIQUE   ← P1-27-01 terkonfirmasi
 *   hr_attendance  → 0 CHECK, 0 UNIQUE   ← P1-27-03 terkonfirmasi
 *   hr_leave       → 0 CHECK, 0 UNIQUE   ← P1-27-02 terkonfirmasi
 *   employees_core → 2 CHECK (nik format, nik not null), 0 UNIQUE pada email
 *
 * Karena itu berkas ini MEMPUNGUI dua jenis test, dan itu disengaja:
 *   1. `it(...)` AKTIF — menjaga constraint yang SUDAH ADA. Kalau suatu migrasi
 *      menghapus CHECK nik, build langsung merah. Ini nilai nyata.
 *   2. `it.todo(...)` — mencatat yang BELUM ada. `todo` terlihat di laporan
 *      sebagai "belum dikerjakan" dan TIDAK mengarang hijau. Fix #6 yang akan
 *      mengisinya; begitu constraint ditambah, cukup pindahkan `it.todo` → `it`.
 *
 * Kenapa bukan `it.fails`: `it.fails` berarti "harus gagal", jadi begitu
 * constraint-nya benar ada, test itu justru jadi merah dan harus dihapus —
 * kebalikan dari yang kita mau, dan mudah terlupa. `it.todo` tidak punya jebak itu.
 */
import { describe, it, expect } from 'vitest';
import { Client } from 'pg';
import { readDatabaseUrl, hasDb } from '../helpers/db';

const DATABASE_URL = readDatabaseUrl();

async function withDb<T>(fn: (client: Client) => Promise<T>): Promise<T> {
  const client = new Client({ connectionString: DATABASE_URL, ssl: { rejectUnauthorized: false } });
  await client.connect();
  try {
    return await fn(client);
  } finally {
    await client.end();
  }
}

/** Ambil constraint CHECK/UNIQUE untuk satu tabel. */
async function constraintsFor(table: string) {
  return withDb(async (client) => {
    const r = await client.query<{ contype: string; conname: string; def: string }>(
      `select contype, conname, pg_get_constraintdef(c.oid) as def
         from pg_constraint c
        where c.connamespace = 'public'::regnamespace
          and c.conrelid = $1::regclass
          and c.contype in ('c','u')`,
      [table],
    );
    return r.rows;
  });
}

describe.skipIf(!hasDb())('P1-58-01: constraint yang ADA harus tetap ada', () => {
  it('employees_core punya CHECK pada nik (format + not-null)', async () => {
    // Hilangnya dua CHECK ini berarti NIK boleh null/kosong — identitas karyawan
    // runtuh dan login berbasis NIK bisa menabrak data rusak.
    const rows = await constraintsFor('employees_core');
    const checks = rows.filter((r) => r.contype === 'c');
    expect(
      checks.map((c) => c.conname),
      'employees_core kehilangan CHECK constraint pada nik — tidak ada yang lagi ' +
        'menjaga NIK terisi & formatnya benar',
    ).toEqual(expect.arrayContaining(['employees_core_nik_format', 'employees_core_nik_not_null']));
  });
});

describe.skipIf(!hasDb())('P1-58-01: constraint yang BELUM ADA (menunggu Fix #6)', () => {
  it.todo('hr_payroll punya CHECK nilai (P1-27-01) — belum ada, menunggu Fix #6');
  it.todo('hr_leave punya UNIQUE yang relevan (P1-27-02) — belum ada, menunggu Fix #6');
  it.todo('hr_attendance punya UNIQUE(nrp, date) (P1-27-03) — belum ada, menunggu Fix #6');
  it.todo('employees_core.email punya UNIQUE (P1-74-01) — belum ada, menunggu Fix #6');
});
