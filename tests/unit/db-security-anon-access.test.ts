// @vitest-environment node
/**
 * db-security-anon-access.test.ts — P1-58-02, AKAR B ("hijau ≠ aman").
 *
 * AUDIT BILANG (FORENSIC-RAW-batch-06, P1-58-02):
 *   "Tidak ada test yang menguji akses `anon` — dua P0 lolos begitu saja.
 *    Test terdekat hanya memeriksa 'tabel punya RLS aktif' — bukan 'anon tidak
 *    bisa membaca'. Itu persis celah yang membiarkan P0-01-01 (view bocor ke
 *    anon) dan P0-03-01 (DML lewat authenticated) hidup di produksi.
 *    Test minimal yang akan menangkap: GET /rest/v1/employees_master?select=*
 *    dengan anon key → harus 401/0 baris."
 *
 * INI IMPLEMENTASI REKOMENDASI ITU — sepadan dengan yang dicatat audit, bukan
 * test properti. Semua request benar-benar pergi ke PostgREST produksi memakai
 * anon key, jadi tidak ada reimplementasi aturan yang bisa "lolos" sendiri.
 *
 * SUMBER DAFTAR TABEL (audit, bukan tebakan):
 *   employees_master — P0-01-01, FORENSIC-RAW-batch-01:24. `relkind='v'`
 *     (VIEW) → Postgres tidak terapkan RLS ke view, dieksekusi dengan hak
 *     pemilik yang bypass RLS di bawahnya. Terbaca anon 17 baris × 75 kolom
 *     sebelum migrasi 249 `REVOKE ALL`. Dipakai sebagai kasus utama.
 *   worker_passwords / login_attempts / audit_log — FORENSIC-RAW-batch-01:219-223,
 *     sudah terbukti 401 `42501 permission denied` saat audit. Dipakai sebagai
 *     regresi: kalau suatu saat berubah jadi 200, guard ini berteriak.
 *   mv_admin_summary — FORENSIC-RAW-batch-06 (materialized view), juga tercatat
 *     di `rpc-security.test.sql` L5.8 sebagai "MV anon NO SELECT".
 *
 * SKIP adalah perilaku yang benar: di runner CI tidak ada `.env.local`. Kalau
 * secret anon belum diset, test di-skip — bukan hijau palsu. Guard yang
 * AQUA liar lebih berbahaya daripada test yang tidak jalan.
 */
import { describe, it, expect } from 'vitest';
import {
  anonEnvReady,
  anonRpc,
  assertAnonCannotRead,
  assertAnonCannotWrite,
} from '../helpers/db';

describe.skipIf(!anonEnvReady())('P1-58-02: anon tidak boleh menyentuh data sensitif', () => {
  it('employees_master (view P0-01-01) tidak terbaca anon', async () => {
    await assertAnonCannotRead('employees_master');
  });

  it('employees_master kolom NIK tidak terbaca anon', async () => {
    // `nik` = identitas nasional, kolom PII paling sensitif pada view ini.
    // (`password_hash` TIDAK dipakai: kolom itu memang tidak ada di view
    // employees_master — diverifikasi ke live via information_schema.)
    await assertAnonCannotRead('employees_master', 'nik');
  });

  it('employees_master tidak bisa di-POST oleh anon', async () => {
    await assertAnonCannotWrite('POST', 'employees_master');
  });

  it('employees_master tidak bisa di-PATCH oleh anon', async () => {
    await assertAnonCannotWrite('PATCH', 'employees_master');
  });

  it('employees_master tidak bisa di-DELETE oleh anon', async () => {
    await assertAnonCannotWrite('DELETE', 'employees_master');
  });

  it('worker_passwords tidak terbaca anon', async () => {
    await assertAnonCannotRead('worker_passwords');
  });

  it('login_attempts tidak terbaca anon', async () => {
    await assertAnonCannotRead('login_attempts');
  });

  it('audit_log tidak terbaca anon', async () => {
    await assertAnonCannotRead('audit_log');
  });

  // Catatan: audit forensik menyebut `mv_admin_summary`, tapi live tidak punya MV
  // APAPUN di schema `public` (diverifikasi via `select matviewname from
  // pg_matviews where schemaname='public'` → kosong). Nama itu usang, berasal dari
  // `rpc-security.test.sql:72` yang tidak pernah dijalankan. Kalau MV memang
  // perlu dibuat, itu work queue terpisah — bukan test yang menggantung di sini.
});

describe.skipIf(!anonEnvReady())('P1-58-02: probe tidak boleh buta (self-check)', () => {
  /**
   * Kalau helper-nya sendiri yang rusak (mis. salah header atau salah jalur), seluruh
   * test di atas akan "lolos" karena semua request-nya ditolak karena alasan salah.
   * Test ini membuktikan request-nya benar-benar sampai ke PostgREST.
   *
   * `get_branding` adalah RPC (bukan tabel), jadi dipanggil via `/rest/v1/rpc/`.
   * Ia ada di PRE_AUTH_WHITELIST → harus bisa dipanggil pra-login dan mengembalikan
   * 200. Status 404 berarti endpoint-nya salah, dan test lain bisa hijau palsu.
   */
  it('RPC publik benar-benar terjangkau (bukan gagal karena salah endpoint)', async () => {
    const probe = await anonRpc('get_branding');
    expect(
      probe.status,
      `get_branding ada di PRE_AUTH_WHITELIST dan WAJIB bisa dipanggil pra-login, ` +
        `jadi harus 200. Status ${probe.status} berarti helper/salah endpoint, dan ` +
        `SEMUA test lain di berkas ini bisa "lolos" palsu karena request-nya ditolak ` +
        `karena alasan yang keliru. Body: ${probe.body}`,
    ).toBe(200);
  });
});
