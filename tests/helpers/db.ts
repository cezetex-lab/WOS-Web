/**
 * db.ts — helper bersama untuk test keamanan yang benar-benar menyentuh DB.
 *
 * KENAPA ADA
 *   `security-negative.test.ts` (34 test) menguji ulang logika DI DALAM file
 *   test itu sendiri — menghapus seluruh 549 RPC dari DB tidak akan membuatnya
 *   merah. Itu akar "hijau ≠ aman" (Akar B). Test keamanan nyata harus
 *   membaca efek: HTTP ke PostgREST dengan anon key, dan katalog Postgres.
 *
 * ENV
 *   Urutan pembacaan: `process.env` dulu, lalu fallback ke `.env.local`.
 *   Fallback wajib karena runner CI tidak punya `.env.local` (gitignored) —
 *   dan test DB SENGAJA di-skip di sana, bukan dipaksa hijau.
 *
 * TIDAK menambah dependency apa pun: hanya `node:fs`, `node:path`, dan
 * `fetch` bawaan Node 18+.
 */
import fs from 'node:fs';
import path from 'node:path';
import { Client } from 'pg';
import { expect } from 'vitest';

const ROOT = path.resolve(import.meta.dirname, '..', '..');

/** Baca satu variabel dari `.env.local` (fallback bila process.env kosong). */
function fromEnvFile(name: string): string | undefined {
  const envPath = path.join(ROOT, '.env.local');
  if (!fs.existsSync(envPath)) return undefined;
  const line = fs
    .readFileSync(envPath, 'utf8')
    .split(/\r?\n/)
    .find((l) => new RegExp(`^\\s*${name}\\s*=`).test(l));
  if (!line) return undefined;
  const value = line.slice(line.indexOf('=') + 1).trim().replace(/^["']|["']$/g, '');
  return value.length > 0 ? value : undefined;
}

function env(name: string): string | undefined {
  return process.env[name] || fromEnvFile(name);
}

/** Connection string DB (service/role) — untuk katalog Postgres. */
export function readDatabaseUrl(): string | undefined {
  return env('DATABASE_URL');
}

export function hasDb(): boolean {
  return readDatabaseUrl() !== undefined;
}

/** URL + anon key PostgREST — untuk membuktikan anon benar-benar ditolak. */
export function readAnonEnv(): { url: string; anonKey: string } | undefined {
  const url = env('VITE_SUPABASE_URL');
  const anonKey = env('VITE_SUPABASE_ANON_KEY');
  if (!url || !anonKey) return undefined;
  return { url: url.replace(/\/+$/, ''), anonKey };
}

export function anonEnvReady(): boolean {
  return readAnonEnv() !== undefined;
}

export interface AnonProbe {
  status: number;
  rows: unknown[] | null;
  body: string;
}

/**
 * Kirim request apa adanya ke PostgREST memakai anon key.
 * Tidak pernah melempar error HTTP — status-nya dikembalikan supaya
 * assertion bisa menjelaskan apa yang sebenarnya terjadi.
 */
export async function anonFetch(
  method: 'GET' | 'POST' | 'PATCH' | 'DELETE',
  table: string,
  opts: { column?: string; filter?: string; body?: unknown } = {},
): Promise<AnonProbe> {
  const cfg = readAnonEnv();
  if (!cfg) throw new Error('anon env belum siap — test seharusnya di-skip');
  const { url, anonKey } = cfg;

  let path_ = `${url}/rest/v1/${table}`;
  const q: string[] = [`select=${opts.column || '*'}`];
  if (opts.filter) q.push(opts.filter);
  path_ += `?${q.join('&')}`;

  const res = await fetch(path_, {
    method,
    headers: {
      apikey: anonKey,
      Authorization: `Bearer ${anonKey}`,
      'Content-Type': 'application/json',
      Prefer: 'return=representation',
    },
    body: opts.body ? JSON.stringify(opts.body) : undefined,
  });

  const body = await res.text();
  let rows: unknown[] | null = null;
  try {
    const parsed = JSON.parse(body);
    rows = Array.isArray(parsed) ? parsed : null;
  } catch {
    rows = null; // body non-JSON (mis. pesan error PostgREST)
  }
  return { status: res.status, rows, body: body.slice(0, 300) };
}

/**
 * P1-72-01: fail-fast kalau objek yang dijaga hilang.
 *
 * Tanpa ini guard bisa "vakuit diam-diam": kalau tabelnya di-rename atau di-drop,
 * query di dalamnya ikut mengembalikan nol dan guard melapor "aman" padahal tidak
 * sedang memeriksa apa pun. `to_regclass()` adalah cara Postgres yang idiomatis
 * untuk mendeteksi objek hilang TANPA error — persis yang diminta audit di
 * FORENSIC-RAW-batch-08: "Guard tidak pernah fail-fast saat target tidak ada".
 */
export async function assertObjectExists(client: Client, objectName: string): Promise<void> {
  const r = await client.query<{ t: string | null }>(`select to_regclass($1)::text as t`, [
    objectName,
  ]);
  expect(
    r.rows[0]?.t,
    `objek ${objectName} tidak ada — guard ini jadi vakuit dan tidak lagi memeriksa ` +
      `apa pun (P1-72-01).`,
  ).toBeTruthy();
}

/**
 * Buktikan `anon` TIDAK bisa membaca `table`. Ini menutup P1-58-02.
 *
 * Dua hasil yang sama-sama benar:
 *   - status 401/403  → PostgREST menolak di lapisan grant/RLS
 *   - status 200 + []  → grant ada tapi policy RLS menyaring semua baris
 * Status 200 dengan isi = kebocoran, dan itu harus menggagalkan build.
 */
export async function assertAnonCannotRead(table: string, column?: string): Promise<void> {
  const probe = await anonFetch('GET', table, { column });

  if (probe.status === 401 || probe.status === 403) {
    return; // ditolak di server — ini hasil yang diharapkan
  }
  if (probe.status === 200) {
    if (Array.isArray(probe.rows) && probe.rows.length === 0) {
      return; // RLS menyaring semua baris — juga aman
    }
    const n = Array.isArray(probe.rows) ? probe.rows.length : '?';
    throw new Error(
      `anon BISA membaca ${table}${column ? `.${column}` : ''} — ` +
        `HTTP 200 dengan ${n} baris. Ini kebocoran data (P1-58-02). ` +
        `Cuplikan body: ${probe.body}`,
    );
  }
  throw new Error(
    `status tak terduga ${probe.status} untuk GET /rest/v1/${table}` +
      `${column ? `?select=${column}` : ''}. Body: ${probe.body}`,
  );
}

/** Buktikan `anon` TIDAK bisa menulis dengan request yang VALID. */
export async function assertAnonCannotWrite(
  method: 'POST' | 'PATCH' | 'DELETE',
  table: string,
  filter = 'nrp=eq.P0_GUARD_DUMMY',
): Promise<void> {
  // Body harus valid supaya 4xx berarti "anon ditolak", bukan "JSON rusak"
  // (PGRST102). Kalau request-nya sendiri rusak, test ini mengukur hal yang
  // salah dan bisa "lolos" tanpa benar-benar menguji apa pun.
  const probe = await anonFetch(method, table, {
    filter,
    body: { nama: 'P0_GUARD_DUMMY', nrp: 'P0_GUARD_DUMMY' },
  });
  if (probe.status === 401 || probe.status === 403) return;
  if (probe.status === 404) return; // objek tidak ada — juga tidak bisa ditembus
  throw new Error(
    `anon BISA ${method} ke ${table} — HTTP ${probe.status} (harusnya 401/403/404). ` +
      `Body: ${probe.body}`,
  );
}

/** Panggil sebuah RPC lewat PostgREST dengan anon key (body JSON valid). */
export async function anonRpc(fn: string, payload: unknown = {}): Promise<AnonProbe> {
  const cfg = readAnonEnv();
  if (!cfg) throw new Error('anon env belum siap — test seharusnya di-skip');
  const res = await fetch(`${cfg.url}/rest/v1/rpc/${fn}`, {
    method: 'POST',
    headers: {
      apikey: cfg.anonKey,
      Authorization: `Bearer ${cfg.anonKey}`,
      'Content-Type': 'application/json',
      Prefer: 'return=representation',
    },
    body: JSON.stringify(payload),
  });
  const body = await res.text();
  return { status: res.status, rows: null, body: body.slice(0, 300) };
}
