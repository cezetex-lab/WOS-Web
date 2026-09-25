/**
 * live-accounts.ts — SATU sumber sebaran identitas admin untuk spec LIVE (opt-in).
 *
 * KENAPA ADA (temuan RUN 1, 2026-09-24)
 *   OTP admin dibatasi APLIKASI sendiri: edge `password-reset` → `hitRateLimit(nrp,
 *   'login_otp')` dengan LIMITS.login_otp = 3 per jendela 15 menit (plus jalur RPC
 *   `otp_attempts` 3/10 menit per NRP). RUN 1 memakai `hrd@` di TIGA konsumen
 *   (diag-login, full-sweep Dashboard, four-page Dashboard) → konsumen ke-3 selalu
 *   ditolak "Terlalu banyak request OTP. Coba lagi nanti." → 2 test FAIL + 1 retry
 *   yang ikut memakan OTP → total 24,4 menit (melewati batas 15 menit).
 *
 * ATURAN (jangan dilanggar) — konsumen OTP TIDAK boleh berbagi identitas:
 *   admin-payroll        → pusat        (ENTERPRISE; /admin/payroll terbukti RUN 1)
 *   full-sweep Dashboard → pusat        (2)  → /dashboard butuh admin_pusat/admin_hrd/
 *   full-sweep Admin     → operasional       admin_finance/admin_operasional (App.tsx:66)
 *   diag-login admin ×4  → mining, mill, estate, finance
 *   four-page Admin      → hrd
 *   four-page Dashboard  → hrd          (2)  → dipakai serial dalam satu berkas
 *   tab-click-test       → ceo
 *   → maksimum 2 login OTP per identitas per run ⇒ margin 1 dari limit 3.
 *   Divalidasi otomatis oleh assertOtpBudget() di bawah (fail-fast bila drift).
 *
 * KREDENSIAL: HANYA dari env (.env.local, gitignored). Tidak ada literal password di
 * repo — nilai di-seed oleh `.agents/scripts/seed-admin-otp-identities.mjs` yang membaca
 * `supabase/akun/akun.txt`. Karena itu modul ini TIDAK melempar saat impor (suite
 * hermetic default tetap hijau); spec live memvalidasi lewat assertAccount().
 */

export type IdentityKey = 'pusat' | 'ceo' | 'hrd' | 'operasional' | 'finance' | 'mining' | 'mill' | 'estate';
export type LiveAccount = { email: string; pass: string };

const ENV_SLUG: Record<IdentityKey, string> = {
  pusat: 'PUSAT',
  ceo: 'CEO',
  hrd: 'HRD',
  operasional: 'OPS',
  finance: 'FINANCE',
  mining: 'MINING',
  mill: 'MILL',
  estate: 'ESTATE',
};

/** Baca kredensial identitas dari env saja (tanpa fallback literal). */
function fromEnv(key: IdentityKey): LiveAccount {
  return {
    email: (process.env[`E2E_ADMIN_${ENV_SLUG[key]}_EMAIL`] ?? '').trim(),
    pass: (process.env[`E2E_ADMIN_${ENV_SLUG[key]}_PASS`] ?? '').trim(),
  };
}

export const ADMIN_ACCOUNTS: Record<IdentityKey, LiveAccount> = {
  pusat: fromEnv('pusat'),
  ceo: fromEnv('ceo'),
  hrd: fromEnv('hrd'),
  operasional: fromEnv('operasional'),
  finance: fromEnv('finance'),
  mining: fromEnv('mining'),
  mill: fromEnv('mill'),
  estate: fromEnv('estate'),
};

/**
 * Akun tab Dashboard (four-page-smoke). Env lama `E2E_DASHBOARD_*` dihormati; default
 * `hrd` (identitas yang sama dengan four-page Admin → 2 OTP, masih di bawah limit).
 */
export const DASHBOARD_ACCOUNT: LiveAccount = {
  email: (process.env.E2E_DASHBOARD_EMAIL ?? ADMIN_ACCOUNTS.hrd.email).trim(),
  pass: (process.env.E2E_DASHBOARD_PASS ?? ADMIN_ACCOUNTS.hrd.pass).trim(),
};

/** Batas aplikasi + target sebaran per run. */
export const OTP_LIMIT = { perIdentity: 3, windowMinutes: 15, maxPerRun: 2 } as const;

/**
 * Sebaran konsumen OTP → identitas. Ini KONTRAK: setiap spec wajib memakai slotnya
 * sendiri (bukan identitas pilihan bebas) supaya tidak ada dua spec yang berbagi NRP.
 */
export const OTP_ASSIGNMENT: Record<string, IdentityKey[]> = {
  'diag-login:admin': ['mining', 'mill', 'estate', 'finance'],
  'full-sweep:admin': ['operasional'],
  'full-sweep:dashboard': ['pusat'],
  'four-page:admin': ['hrd'],
  'four-page:dashboard': ['hrd'],
  'tab-click-test:admin': ['ceo'],
  'admin-payroll:admin': ['pusat'],
};

/** Laporkan pelanggaran anggaran OTP (dipanggil spec live + unit test). */
export function otpBudgetViolations(max = OTP_LIMIT.maxPerRun): string[] {
  const used = new Map<IdentityKey, number>();
  for (const [consumer, keys] of Object.entries(OTP_ASSIGNMENT)) {
    for (const k of keys) {
      if (!(k in ADMIN_ACCOUNTS)) return [`konsumen "${consumer}" menunjuk identitas tak dikenal: ${k}`];
      used.set(k, (used.get(k) ?? 0) + 1);
    }
  }
  return [...used.entries()]
    .filter(([, n]) => n > max)
    .map(([k, n]) => `identitas "${k}" dipakai ${n}x OTP per run (maks ${max}; limit aplikasi ${OTP_LIMIT.perIdentity}/${OTP_LIMIT.windowMinutes} menit)`);
}

/** Fail-fast: dipanggil saat suite LIVE benar-benar akan jalan. */
export function assertOtpBudget(): void {
  const v = otpBudgetViolations();
  if (v.length) throw new Error(`Sebaran OTP melanggar batas aplikasi:\n - ${v.join('\n - ')}`);
}

/** Fail-fast untuk kredensial identitas yang belum di-seed ke .env.local. */
export function assertAccount(acct: LiveAccount, key: IdentityKey): void {
  if (!acct.email || !acct.pass) {
    throw new Error(
      `Kredensial identitas "${key}" belum ada di env (E2E_ADMIN_${ENV_SLUG[key]}_EMAIL/PASS). ` +
        'Jalankan: node .agents/scripts/seed-admin-otp-identities.mjs',
    );
  }
}
