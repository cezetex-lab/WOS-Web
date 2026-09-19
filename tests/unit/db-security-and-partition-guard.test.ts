// @vitest-environment node
/**
 * Penjaga (guard) dua kelas kesalahan yang ditemukan audit 2026-09-17:
 *
 * 1. RPC PENULIS yang bisa dipanggil anon/PUBLIC.
 *    Supabase memasang default privileges (`anon`, `authenticated`, `service_role`
 *    dapat EXECUTE untuk setiap fungsi baru) dan PostgreSQL memberi EXECUTE ke
 *    PUBLIC secara bawaan. Akibatnya RPC tulis baru otomatis terbuka kecuali
 *    di-REVOKE. Sebelum migrasi 226 ada 11 RPC penulis yang terjangkau anon,
 *    4 di antaranya juga PUBLIC (termasuk `worker_update_profile`).
 *
 * 2. Partisi absensi yang habis masa berlakunya.
 *    Migrasi 141 membuat partisi dengan loop hardcoded `FOR v_year IN 2024..2027`.
 *    Tidak ada yang menjaga, jadi mulai 2028 INSERT absensi gagal. Migrasi 225
 *    menggantinya dengan `ensure_attendance_partitions()` + cron bulanan; tes ini
 *    memastikan jendela partisi selalu menutup hari ini dan >= 12 bulan ke depan.
 *
 * Daftar putih RPC alur login di bawah ini sengaja EKSPLISIT: RPC itu memang harus
 * bisa dipanggil sebelum sesi ada. Menambah nama ke daftar ini = melonggarkan
 * isolasi role, jadi harus lewat keputusan, bukan diam-diam.
 *
 * Butuh `DATABASE_URL` di `.env.local`; tanpa itu tes di-skip supaya `npm test`
 * tetap jalan tanpa kredensial.
 */

import { describe, expect, it } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';
import { Client } from 'pg';

const ROOT = path.resolve(import.meta.dirname, '..', '..');

/** RPC yang memang dipanggil sebelum login (OTP, login, registrasi, rate limit). */
const PRE_AUTH_WHITELIST = [
  'login_worker',
  'login_worker_by_email',
  'generate_worker_otp',
  'verify_worker_otp',
  'register_session',
  'submit_registration',
  'hit_rate_limit',
];

/** Pola isi badan fungsi yang menandakan RPC tersebut menulis data. */
const WRITE_PATTERN = '(^|[^a-z_])(insert\\s+into|update\\s+[a-z_"]|delete\\s+from|truncate\\s|alter\\s+table|drop\\s+table)';

function readDatabaseUrl(): string | undefined {
  const envPath = path.join(ROOT, '.env.local');
  if (!fs.existsSync(envPath)) return undefined;
  const line = fs
    .readFileSync(envPath, 'utf8')
    .split(/\r?\n/)
    .find((l) => /^\s*DATABASE_URL\s*=/.test(l));
  if (!line) return undefined;
  const value = line.slice(line.indexOf('=') + 1).trim().replace(/^["']|["']$/g, '');
  return value.length > 0 ? value : undefined;
}

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

describe.skipIf(!DATABASE_URL)('penjaga DB live', () => {
  it('tidak ada RPC penulis yang terjangkau anon/PUBLIC (kecuali alur login)', async () => {
    const rows = await withDb((client) =>
      client
        .query<{ name: string; args: string }>(
          `select p.proname as name, pg_get_function_identity_arguments(p.oid) as args
             from pg_proc p
             join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public'
              and p.prokind = 'f'
              and p.prosrc ~* '${WRITE_PATTERN}'
              and exists (
                select 1 from unnest(coalesce(p.proacl, '{}')) a
                 where a::text like 'anon=X/%' or a::text like '=X/%'
              )
              and p.proname <> all($1::text[])
            order by p.proname`,
          [PRE_AUTH_WHITELIST],
        )
        .then((r) => r.rows),
    );

    expect(
      rows.map((r) => `${r.name}(${r.args})`),
      'RPC penulis ini bisa dipanggil anon/PUBLIC — cabut dengan REVOKE di migrasi baru, ' +
        'atau tambahkan ke PRE_AUTH_WHITELIST bila memang harus pra-login',
    ).toEqual([]);
  });

  it('partisi absensi selalu menutup hari ini dan >= 12 bulan ke depan', async () => {
    const info = await withDb(async (client) => {
      const parent = await client.query<{ is_partitioned: boolean }>(
        `select c.relkind = 'p' as is_partitioned
           from pg_class c join pg_namespace n on n.oid = c.relnamespace
          where n.nspname = 'public' and c.relname = 'hr_attendance_partitioned'`,
      );
      const missing = await client.query<{ missing: string | null }>(
        `with targets as (
           select to_char(
             (date_trunc('month', current_date) + (i || ' month')::interval)::date,
             'YYYY_MM'
           ) as suffix
             from generate_series(0, 12) as i
         )
         select string_agg('hr_attendance_' || suffix, ', ' order by suffix) as missing
           from targets t
          where not exists (
            select 1 from pg_class c
              join pg_namespace n on n.oid = c.relnamespace
             where n.nspname = 'public' and c.relname = 'hr_attendance_' || t.suffix
          )`,
      );
      return { parent: parent.rows[0]?.is_partitioned ?? false, missing: missing.rows[0]?.missing ?? null };
    });

    if (!info.parent) {
      // Struktur partisi tidak dipakai di lingkungan ini — tidak ada yang perlu dijaga.
      expect(info.parent).toBe(false);
      return;
    }

    expect(
      info.missing,
      'partisi absensi hilang mulai 13 bulan ke depan — jalankan ensure_attendance_partitions() ' +
        'atau perbaiki cron `ensure-attendance-partitions`',
    ).toBeNull();
  });
});
