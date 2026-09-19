// @vitest-environment node
/**
 * Penjaga INSTALASI PERUSAHAAN BARU (baseline).
 *
 * Latar: 2026-09-18, saat menyiapkan instalasi satu-perintah, ditemukan bahwa
 * baseline yang di-generate dari DB live MEWARISKAN identitas perusahaan sumber:
 *   * `branding.company_name` → perusahaan baru memakai merek kita;
 *   * `company_config.owner_email` / `ceo_email` → dan `get_owner_email()` punya
 *     fallback hardcoded `'owner@insightwos.com'`, sehingga owner perusahaan baru
 *     hanya bisa login dengan email kita (atau tidak bisa login sama sekali);
 *   * `schema_migrations.version` ditulis `parseInt` → 59 VERSION_MISMATCH;
 *   * ACL partisi lolos dari revoke → instalasi baru lebih terbuka dari live;
 *   * 3 trigger INSTEAD OF di view `employees_master` tidak ikut ter-emit.
 *
 * Tes ini adalah penjaga STATIS (tanpa DB): ia membaca berkas yang dikirim ke
 * operator, jadi ia tetap berjalan di CI tanpa `DATABASE_URL`. Uji perilaku
 * sebenarnya ada di `npm run db:verify-install` (metrik + ACL vs live).
 */

import { describe, expect, it } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(import.meta.dirname, '..', '..');
const BASELINE = path.join(ROOT, 'supabase/baseline');
const read = (p: string) => fs.readFileSync(path.join(ROOT, p), 'utf8');

const schemaSql = read('supabase/baseline/000_baseline_schema.sql');
const dataSql = read('supabase/baseline/010_baseline_config_data.sql');
const installer = read('supabase/scripts/install-baseline.mjs');
const harness = read('supabase/scripts/replay-fresh-install.mjs');
const generator = read('supabase/scripts/generate-baseline-data.mjs');

describe('baseline instalasi perusahaan baru', () => {
  it('tidak mewariskan email owner/CEO perusahaan sumber', () => {
    // Baris identitas ini HARUS tidak ada di dump; diisi operator lewat --owner-email.
    expect(dataSql).not.toMatch(/'owner_email'/);
    expect(dataSql).not.toMatch(/'ceo_email'/);
  });

  it('dump data tidak memuat alamat email domain perusahaan sumber', () => {
    // Nama berkas migrasi (mis. 198_branding_insightwip.sql) boleh menyebut merek,
    // jadi yang diperiksa adalah ALAMAT EMAIL, bukan sembarang kata.
    const emails = dataSql.match(/[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}/gi) ?? [];
    expect(emails).toEqual([]);
  });

  it('get_owner_email() fail-closed — tanpa domain perusahaan mana pun', () => {
    const m = /CREATE OR REPLACE FUNCTION public\.get_owner_email\(\)[\s\S]*?\$function\$;/.exec(schemaSql);
    expect(m, 'definisi get_owner_email() tidak ditemukan di baseline').toBeTruthy();
    const body = m![0];
    // Tidak boleh ada alamat email literal di dalam fungsi bersama.
    expect(body.match(/[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}/gi) ?? []).toEqual([]);
    // Dan harus ada jalan keluar fail-closed.
    expect(body).toMatch(/v_email IS NULL/);
    expect(body).toMatch(/RETURN NULL/);
  });

  it('branding di baseline netral, bukan merek DB sumber', () => {
    const m = /INSERT INTO public\.branding \([^)]*\) VALUES \(([^;]*)\);/.exec(dataSql);
    expect(m, 'blok branding tidak ditemukan di baseline').toBeTruthy();
    expect(m![1]).toContain('Perusahaan Anda');
  });

  it('versi registry memakai prefiks ber-padding (bukan parseInt)', () => {
    expect(generator).toMatch(/\(\/\^\(\\d\+\)\/\.exec\(f\) \|\| \['0'\]\)\[0\]/);
    expect(generator).not.toMatch(/String\(parseInt\(f, 10\) \|\| 0\)/);
  });

  it('generator memblokir baris identitas + memindai kebocoran domain', () => {
    expect(generator).toMatch(/EXCLUDED_ROWS/);
    expect(generator).toMatch(/owner_email/);
    expect(generator).toMatch(/PERINGATAN KEBOCORAN/);
  });

  it('installer menolak berjalan tanpa --target dan tidak pernah memakai DATABASE_URL repo', () => {
    expect(installer).toMatch(/wajib pakai --target/);
    // Instalasi hanya boleh menulis ke target eksplisit; tidak ada fallback ke .env.local.
    expect(installer).not.toMatch(/process\.env\.DATABASE_URL/);
    // DATABASE_URL repo hanya dibaca untuk MEMBANDINGKAN (menolak target = DB live).
    expect(installer).toMatch(/SAMA dengan DATABASE_URL repo/);
  });

  it('harness hanya menjalankan berkas instalasi berpola NNN_*.sql', () => {
    expect(harness).toMatch(/\^\\d\+_\.\*\\\.sql\$/);
    expect(harness).toMatch(/first-owner\.example\.sql/);
  });

  it('berkas instalasi & runbook ada dan tidak kosong', () => {
    for (const f of ['README.md', 'first-owner.example.sql', 'replay-baseline.md', 'verify-install-e2e.md']) {
      const p = path.join(BASELINE, f);
      expect(fs.existsSync(p), `${f} tidak ada`).toBe(true);
      expect(fs.statSync(p).size).toBeGreaterThan(200);
    }
    expect(schemaSql.length).toBeGreaterThan(500_000);
    expect(dataSql.length).toBeGreaterThan(50_000);
  });

  it('runbook menyebut langkah wajib identitas & perintah resmi', () => {
    const readme = fs.readFileSync(path.join(BASELINE, 'README.md'), 'utf8');
    for (const needle of ['install:baseline', '--owner-email', 'system_owner_identity', 'db:verify-install', 'db:baseline']) {
      expect(readme, `README baseline tidak menyebut ${needle}`).toContain(needle);
    }
  });
});
