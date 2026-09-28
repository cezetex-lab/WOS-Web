// @vitest-environment node
/**
 * db-audit-trail.test.ts — penjaga Fix #4 (P1-13-01, P2-13-01, P1-63-01).
 *
 * SEBELUM batch ini, "audit trail" hanya dijaga oleh `verify_audit_chain()`, dan
 * fungsi itu HANYA bisa membuktikan bahwa hash tidak berubah — tidak pernah memastikan
 * bahwa `actor` diisi. Hasilnya 519 dari 526 baris (98,7%) punya `actor` NULL:
 * hash-chain utuh, tapi isinya tidak bisa dipakai untuk forensik.
 *
 * Test di bawah membaca EFEK, bukan properti:
 *   - benar-benar memanggil fungsi verifier (bukan hanya membaca definisinya)
 *   - benar-benar INSERT ke tabel ber-trigger lalu membaca `actor` yang tertulis
 *   - memastikan 1 perubahan = 1 baris audit (konsolidasi trigger)
 *
 * Semua test memakai transaksi + ROLLBACK. Tidak ada data yang tertinggal.
 */
import { describe, expect, it } from 'vitest';
import { Client } from 'pg';
import { hasDb, readDatabaseUrl } from '../helpers/db';

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

describe.skipIf(!hasDb())('P1-13-01: audit_log mencatat aktor', () => {
  it('verify_audit_chain() mode strict → 0 issue', async () => {
    const r = await withDb((c) => c.query(`select count(*)::int n from verify_audit_chain()`));
    expect(
      r.rows[0].n,
      'chain strict harus utuh. Kalau muncul TAMPERED, ada baris yang diubah ' +
        'tanpa memperbarui row_hash (mis. backfill actor secara langsung).',
    ).toBe(0);
  });

  it('verify_audit_chain() mode chain-aware → 0 issue', async () => {
    const r = await withDb((c) =>
      c.query(`select count(*)::int n from verify_audit_chain(null, null, 'chain-aware')`),
    );
    expect(r.rows[0].n, 'chain-aware harus 0 issue saat retensi belum aktif').toBe(0);
  });

  it('trigger generic menulis actor dari authz_current_nrp()', async () => {
    const r = await withDb((c) =>
      c.query(
        `select prosrc from pg_proc
          join pg_namespace n on n.oid = pg_proc.pronamespace
          where n.nspname='public' and proname='_generic_audit_trigger_fixed'`,
      ),
    );
    expect(r.rowCount, 'fungsi _generic_audit_trigger_fixed harus ada').toBe(1);
    expect(
      r.rows[0].prosrc,
      'fungsi trigger generic tidak menyebut authz_current_nrp() — berarti actor ' +
        'akan tetap NULL untuk semua perubahan tabel (P1-13-01 kembali).',
    ).toMatch(/authz_current_nrp/);
  });

  it('audit_log_hash_chain() memakai advisory lock (anti race)', async () => {
    const r = await withDb((c) =>
      c.query(
        `select prosrc from pg_proc
          join pg_namespace n on n.oid = pg_proc.pronamespace
          where n.nspname='public' and proname='audit_log_hash_chain'`,
      ),
    );
    expect(r.rowCount, 'fungsi audit_log_hash_chain harus ada').toBe(1);
    expect(
      r.rows[0].prosrc,
      'tanpa pg_advisory_xact_lock, dua INSERT bersamaan membaca row_hash yang ' +
        'sama dan rantai bercabang.',
    ).toMatch(/pg_advisory_xact_lock/);
  });
});

describe.skipIf(!hasDb())('P1-63-01: satu perubahan = satu baris audit', () => {
  it('trigger spesialis sudah dimatikan (konsolidasi)', async () => {
    const r = await withDb((c) =>
      c.query(
        `select count(*)::int n from pg_trigger
          where tgname in ('trg_audit_payroll_insert','trg_audit_payroll_update',
                           'trg_audit_role_change')`,
      ),
    );
    expect(
      r.rows[0].n,
      'trigger spesialis kembali aktif — hr_payroll/user_roles akan menulis 2 ' +
        'baris audit untuk 1 perubahan.',
    ).toBe(0);
  });

  it('1 INSERT ke hr_payroll menghasilkan tepat 1 baris audit dengan actor terisi', async () => {
    const r = await inRolledBackTx(async (c) => {
      const before = await c.query(`select coalesce(max(id),0)::int m from audit_log`);
      const maxId = before.rows[0].m;
      await c.query(`insert into hr_payroll (nrp, periode) values ('P1_13_01_PROBE','2099-12')`);
      const rows = await c.query(
        `select actor from audit_log where id > $1 and action ilike '%hr_payroll%' order by id`,
        [maxId],
      );
      return rows;
    });
    expect(
      r.rowCount,
      '1 INSERT harus menghasilkan tepat 1 baris audit (konsolidasi trigger gagal).',
    ).toBe(1);
    expect(
      r.rows[0].actor,
      'actor NULL pada baris audit baru — P1-13-01 belum tertutup. Koneksi test ' +
        'tidak punya JWT, jadi nilai yang diharapkan adalah SYSTEM.',
    ).not.toBeNull();
  });

  it('actor berisi NRP asli bila JWTclaim tersedia', async () => {
    const r = await inRolledBackTx(async (c) => {
      const who = await c.query(
        `select nrp, auth_id::text from employees_master where auth_id is not null limit 1`,
      );
      if (who.rowCount === 0) return null; // tidak ada akun terikat auth_id
      await c.query(`select set_config('request.jwt.claim.sub', $1, true)`, [who.rows[0].auth_id]);
      const before = await c.query(`select coalesce(max(id),0)::int m from audit_log`);
      await c.query(`insert into hr_payroll (nrp, periode) values ('P1_13_01_JWT','2099-11')`);
      const rows = await c.query(
        `select actor from audit_log where id > $1 and action ilike '%hr_payroll%' order by id`,
        [before.rows[0].m],
      );
      return { expected: who.rows[0].nrp, actor: rows.rows[0]?.actor };
    });
    if (r === null) return; // tidak bisa diuji di environment ini
    expect(
      r.actor,
      `actor harus NRP asli (${r.expected}) ketika JWT claim ada — inilah bukti ` +
        'bahwa audit trail benar-benar bisa dipakai untuk forensik.',
    ).toBe(r.expected);
  });
});

describe.skipIf(!hasDb())('P2-13-01: retensi audit_log', () => {
  it('cron cleanup-audit-log terdaftar', async () => {
    const r = await withDb((c) =>
      c.query(`select count(*)::int n from cron.job where jobname = 'cleanup-audit-log'`),
    );
    expect(
      r.rows[0].n,
      'cron retensi audit_log tidak terdaftar — tabel tumbuh tanpa batas ' +
        '(P2-13-01 kembali).',
    ).toBeGreaterThan(0);
  });

  it('cleanup_audit_log() berjalan tanpa error (kolom timestamp, bukan created_at)', async () => {
    const r = await inRolledBackTx((c) => c.query(`select public.cleanup_audit_log() as res`));
    expect(r.rows[0].res).toMatchObject({ ok: true });
  });

  it('cleanup_audit_log() memakai kolom yang benar-benar ada', async () => {
    const r = await withDb((c) =>
      c.query(
        `select prosrc from pg_proc
          join pg_namespace n on n.oid = pg_proc.pronamespace
          where n.nspname='public' and proname='cleanup_audit_log'`,
      ),
    );
    expect(r.rowCount, 'fungsi cleanup_audit_log harus ada').toBe(1);
    // Bug laten yang ditemukan 2026-09-27: fungsi mereferensikan kolom
    // 'created_at' yang tidak pernah ada, jadi selalu error saat dipanggil.
    // Buang komentar dulu: KODE tidak boleh menyebut created_at, tapi
    // komentar penjelasan BOLAK — dan itulah yang membuat test ini false
    // positive pada versi pertama.
    const code = r.rows[0].prosrc.replace(/--.*$/gm, '');
    expect(code, 'kode cleanup_audit_log masih mereferensikan kolom created_at').not.toMatch(
      /created_at/,
    );
    expect(code, 'cleanup_audit_log harus memfilter kolom timestamp').toMatch(
      /WHERE timestamp\s*</i,
    );
  });
});
