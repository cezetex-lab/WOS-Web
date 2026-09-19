// @vitest-environment node
/**
 * Penjaga konsistensi data dummy hasil rekonsiliasi live (fitur login email worker).
 *
 * Data dummy TIDAK punya kolom marker `is_dummy`/`is_test` (sudah diverifikasi
 * 2026-09-19). Karena itu penjaga ini mengunci kontrak data yang disepakati saat
 * rekonsiliasi: NRP001–NRP010 harus punya email unik, divisi/site yang konsisten
 * dengan BU-nya, dan `worker_passwords.reset_required = false` agar login langsung
 * bisa dipakai.
 *
 * Query di bawah ini HANYA SELECT (read-only). Butuh `DATABASE_URL` di `.env.local`;
 * tanpa itu tes di-skip supaya `npm test` tetap hijau tanpa kredensial.
 */

import { describe, expect, it } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';
import { Client } from 'pg';

const ROOT = path.resolve(import.meta.dirname, '..', '..');
const WORKER_NRPS = Array.from({ length: 10 }, (_, index) => `NRP${String(index + 1).padStart(3, '0')}`);

/** Kontrak rekonsiliasi: NRP → (BU id, BU code, divisi_code, site_id). */
const EXPECTED = [
  { nrp: 'NRP001', buId: 'BU04', bu: 'HQ', divisi: 'KORPORAT', divisiCode: 'CORP', siteId: 'SITE-HQ-01' },
  { nrp: 'NRP002', buId: 'BU04', bu: 'HQ', divisi: 'HRD', divisiCode: 'HRD', siteId: 'SITE-HQ-01' },
  { nrp: 'NRP003', buId: 'BU01', bu: 'MINING', divisi: 'MINING', divisiCode: 'MIN', siteId: 'SITE-MINING-01' },
  { nrp: 'NRP004', buId: 'BU01', bu: 'MINING', divisi: 'MINING', divisiCode: 'MIN', siteId: 'SITE-MINING-01' },
  { nrp: 'NRP005', buId: 'BU01', bu: 'MINING', divisi: 'MINING', divisiCode: 'MIN', siteId: 'SITE-MINING-01' },
  { nrp: 'NRP006', buId: 'BU02', bu: 'ESTATE', divisi: 'ESTATE', divisiCode: 'EST', siteId: 'SITE-ESTATE-01' },
  { nrp: 'NRP007', buId: 'BU02', bu: 'ESTATE', divisi: 'ESTATE', divisiCode: 'EST', siteId: 'SITE-ESTATE-01' },
  { nrp: 'NRP008', buId: 'BU03', bu: 'MILL', divisi: 'MILL', divisiCode: 'MIL', siteId: 'SITE-MILL-01' },
  { nrp: 'NRP009', buId: 'BU03', bu: 'MILL', divisi: 'MILL', divisiCode: 'MIL', siteId: 'SITE-MILL-01' },
  { nrp: 'NRP010', buId: 'BU04', bu: 'HQ', divisi: 'HRD', divisiCode: 'HRD', siteId: 'SITE-HQ-01' },
] as const;

interface WorkerRow {
  nrp: string;
  nik: string | null;
  email: string | null;
  divisi: string | null;
  divisi_code: string | null;
  business_unit: string | null;
  business_unit_id: string | null;
  site_id: string | null;
  site_business_unit: string | null;
  site_status: string | null;
  unit_code: string | null;
}

interface PasswordRow {
  nrp: string;
  reset_required: boolean | null;
}

function readDatabaseUrl(): string | undefined {
  const envPath = path.join(ROOT, '.env.local');
  if (!fs.existsSync(envPath)) return undefined;
  const line = fs
    .readFileSync(envPath, 'utf8')
    .split(/\r?\n/)
    .find((candidate) => /^\s*DATABASE_URL\s*=/.test(candidate));
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

describe.skipIf(!DATABASE_URL)('penjaga rekonsiliasi data dummy (live DB, read-only)', () => {
  it('NRP001–NRP010: email unik, divisi/site sesuai BU, dan reset_required=false', async () => {
    const data = await withDb(async (client) => {
      const workers = (
        await client.query<WorkerRow>(
          `select e.nrp, e.nik, e.email, e.divisi, e.divisi_code, e.business_unit,
                  e.business_unit_id, e.site_id,
                  s.business_unit as site_business_unit, s.status as site_status,
                  b.unit_code as unit_code
             from public.employees_core e
             left join public.sites s on s.id = e.site_id
             left join public.business_units b on b.id = e.business_unit_id
            where e.nrp = any($1::text[])
            order by e.nrp`,
          [WORKER_NRPS],
        )
      ).rows;

      const selectedFlags = (
        await client.query<PasswordRow>(
          `select nrp, reset_required
             from public.worker_passwords
            where nrp = any($1::text[])
            order by nrp`,
          [WORKER_NRPS],
        )
      ).rows;

      const allWorkerFlags = (
        await client.query<PasswordRow>(
          `select nrp, reset_required
             from public.worker_passwords
            where nrp ~ '^NRP[0-9]{3}$'
            order by nrp`,
        )
      ).rows;

      return { workers, selectedFlags, allWorkerFlags };
    });

    expect(data.workers.map((row) => row.nrp)).toEqual(WORKER_NRPS);

    const emails = data.workers.map((row) => (row.email ?? '').trim().toLowerCase());
    expect(emails.every((email) => email.length > 0)).toBe(true);
    expect(new Set(emails).size).toBe(emails.length);

    for (const expected of EXPECTED) {
      const row = data.workers.find((candidate) => candidate.nrp === expected.nrp);
      expect(row).toBeTruthy();
      if (!row) continue;

      expect(row.business_unit_id).toBe(expected.buId);
      expect((row.business_unit ?? '').toUpperCase()).toBe(expected.bu);
      expect(row.unit_code).toBe(expected.bu);
      expect((row.divisi ?? '').toUpperCase()).toBe(expected.divisi);
      expect((row.divisi_code ?? '').toUpperCase()).toBe(expected.divisiCode);
      expect(row.site_id).toBe(expected.siteId);
      expect(row.site_business_unit).toBe(expected.bu);
      expect(row.site_status).toBe('ACTIVE');
    }

    const nrp005 = data.workers.find((row) => row.nrp === 'NRP005');
    expect(nrp005?.nik).toBe('3204000000000005');

    expect(data.selectedFlags).toHaveLength(WORKER_NRPS.length);
    for (const row of data.selectedFlags) {
      expect(row.reset_required).toBe(false);
    }
    expect(data.allWorkerFlags.length).toBeGreaterThanOrEqual(17);
    for (const row of data.allWorkerFlags) {
      expect(row.reset_required).toBe(false);
    }
  });
});