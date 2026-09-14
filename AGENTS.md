# AGENTS.md — ATURAN KERJA AGENT (WAJIB) — ONE SINGLE TRUTH

> Diperbarui besar: **2026-09-13** (restrukturisasi ONE SINGLE TRUTH).
> **File ini = ATURAN + STATE AKTIF (plan/bug OPEN) SAJA.** Riwayat/hasil yang sudah selesai
> ada di `agentsLogs.md` (ONE SINGLE TRUTH — LOG). File ini TIDAK menyimpan history.

## 0. ALUR KERJA WAJIB (PROSES)

1. **PAHAMI dulu, baru bertindak.** Verifikasi setiap temuan langsung ke DB live
   (`DATABASE_URL` di `.env.local`) atau kode live sebelum dikerjakan. Laporan audit lama
   terbukti banyak false positive.
2. **Ikuti analisa/arahan user** — jangan bikin rencana sendiri yang mengubah urutan tahap,
   jangan kerjakan item di luar daftar tanpa persetujuan.
3. **Setiap perubahan wajib: COMMIT → PUSH → DEPLOY** (deploy = `npx vercel --prod` untuk
   perubahan frontend, apply migration ke DB live untuk perubahan DB, redeploy edge function
   untuk perubahan edge).
4. **Setelah sukses: tulis hasilnya ke `agentsLogs.md`** (format entri ada di header file itu)
   dan **KELUARKAN dari AGENTS.md** — item selesai TIDAK tinggal di file ini.
5. Yang tinggal di AGENTS.md hanya: aturan kerja, aturan teknis keras, dan state OPEN
   (rencana/bug yang belum selesai).
6. **DILARANG commit artefak/rahasia**: audit scripts, test-results, CSV/plaintext password,
   `.env*`, arsip `Readme/` + `files/`. Cek `git status` sebelum `git add` — pakai `git add`
   spesifik, hindari `git add -A` buta. Secret scan pre-commit wajib
   (`postgresql://|SERVICE_ROLE|<password-lama>`).
7. **Rahasia**: kredensial akun ada di `supabase/akun/akun.txt` (gitignored, plaintext —
   bagikan per-orang lalu hapus). Tidak pernah commit kredensial apa pun.

## 1. KONTEKS PROYEK (handoff)

- Aplikasi: insightWOS (WOS-Web) — HR/workforce + modul industri (mining/estate/mill).
  Migrasi Google Apps Script → Supabase.
- Frontend: React + Vite (:5173), deploy Vercel CLI (insightwos.vercel.app), repo GitHub
  `cezetex-lab/WOS-Web`, branch kerja `migrasi-vite`.
- Backend: Supabase `verwobaejumvpagwynae` (ap-northeast-1).
- 17 worker seed (NRP001–NRP010 + NRP100–106); NRP001 = admin_pusat + worker.
- Arsitektur auth (JANGAN diubah tanpa keputusan user): worker login NRP+NIK+password →
  RPC `login_worker` → fast path `signInWithPassword({nrp}@insightwos.internal, password sama)`
  → fallback edge `worker-auth-sync` (verif ulang, rotate password auth). Email sintetis =
  SATU SUMBER: `lower(trim(nrp))@insightwos.internal`.
- UPDATE data karyawan **selalu ke `employees_core`** (base table); `employees_master` = VIEW
  non-updatable.
- Verifikasi cepat sehat: login worker → `sb-verwobaejumvpagwynae-auth-token` ADA di Local
  Storage; Dashboard Auth → Last signed in terupdate.

## 2. PETA FILE PENTING

| File | Isi |
|---|---|
| `src/pages/Home.jsx` | Login semua tab; `provisionWorkerAuth` (fast path+fallback); `redirectAfterLogin(entry)` per-tab; OTP wajib admin/dashboard (edge) |
| `src/App.jsx` | BrowserRouter future flags v7; `/admin` `/worker` `/dashboard` dibungkus `RoleGuard` (`entry`+`allowedRoles`) — isolasi 3 page |
| `src/components/RoleGuard.jsx` | Role + login-entry check (`session.entry`); mismatch → redirect login |
| `src/pages/Admin.jsx` / `Worker.jsx` / `Dashboard.jsx` | Cek `session.entry` mismatch → redirect `/`; role-worker → "Akses Ditolak" |
| `src/components/DynamicRoutes.jsx` | Route dinamis dari `get_enabled_modules(p_area)`; `areaFromPath()` filter per-area |
| `src/lib/route-config.js` | Map route_component → lazy component |
| `src/lib/menu-builder.js` | `buildMenu(area)` + `areaFromPath` + filter per-area + dedup |
| `src/lib/supabase-browser.js` | Session cache (sessionStorage `wos_user`), rpc() rate-limited |
| `src/features/platform/auth/MfaSetup.jsx` | TOTP enroll/disable (ownership di edge `mfa-service`) |
| `supabase/functions/password-reset/index.ts` | `login_otp` (generate OTP langsung di edge, TANPA RPC `generate_admin_otp`) + `verify_login_otp` |
| `supabase/functions/worker-auth-sync/index.ts` | Edge v2 (provision/rotate) |
| `supabase/scripts/provision-worker-auth.mjs` | Batch provisioning `--dry`/`--run` |
| `supabase/akun/akun.txt` | Plaintext kredensial (gitignored — NEVER commit) |
| `agentsLogs.md` | ONE SINGLE TRUTH — LOG riwayat pekerjaan selesai |

## 3. ATURAN TEKNIS KERAS (JANGAN dilanggar)

1. Identitas & authz **selalu dari JWT** (`authz_current_nrp()`, `authz_check_admin()`,
   `authz_in_scope()`) — **jangan pernah** percaya param client (`p_admin_nrp`, `p_nrp` bebas).
2. Password **tidak pernah plaintext** — bcrypt (`gen_salt('bf')` + `crypt()`), tanpa echo
   password di response.
3. `SECURITY DEFINER` wajib `SET search_path` (state: 0 pelanggaran — jangan tambah baru).
4. Jangan bikin overload fungsi dengan nama sama; bereskan legacy dengan RENAME `_legacy_*`,
   bukan DROP liar.
5. Fungsi sensitif: default fail-closed; REVOKE PUBLIC/anon untuk fungsi admin.
6. Klaim "sudah aman" dari sesi sebelumnya = belum terverifikasi sampai dicek ke DB live.
7. `SECURITY DEFINER` + edge service-role: `auth.uid()` = NULL — RPC yang butuh
   `auth.uid()` tidak boleh dipanggil dari edge (pelajaran: bug 500 login OTP).
8. Supabase JS v2: `.catch()` tidak tersedia di query builder — pakai
   `const { error } = await ...; if (error) {...}`.
9. Branding (nama/logo) = konfigurasi OWNER (`branding` table + `update_branding` owner-only).
   **Jangan hardcode di JS.** UI: tab 🎨 Branding OwnerDashboard.
10. Verifikasi gate sebelum commit: `npm run lint` (0 error), `npm test` (unit 100/100),
    `npm run build` (EXIT 0), secret scan.

## 4. STATE OPEN — Tahap 5 Cleanup (urutan dari handoff; KERJAKAN BERURUTAN)

| Tahap | Item | Catatan |
|---|---|---|
| — | ~~F-10~~ | ~~run_171.mjs dll. menerima URL DB via argv~~ → DONE: baca dari .env.local, --db-url override optional |


## 6. PLAN — Login Refactor (asal: docs/TundaPlanLogin.md; status: IN PROGRESS)

> Goal: Ubah login Worker + Dashboard ikut pola Admin (email + password). Tambah menu
> DAFTAR|CEK|MFA. OTP tetap ada. MFA optional=worker, wajib=admin/dashboard.

- **Kondisi saat ini:** Admin = Supabase Auth (email @insightwos.com) + `generate_admin_otp()`;
  Worker/Dashboard = `login_worker(nrp,nik,pass)` + fast path Supabase Auth.
- **Rintangan:** jangan ganti signature `login_worker` (dipakai edge+audit); `provisionWorkerAuth`
  wajib untuk auth.uid() di RLS; F-5: NRP002-004,006-008,010 sha256 di `worker_passwords`;
  E2E mock `loginAsWorker(NRP+NIK+pw)` perlu update.
- **Rencana bertahap:**
  - [x] (1) DB: RPC `login_worker_by_email(email,password)` — migration 216, return NIK untuk provisionWorkerAuth
  - [x] (2) UI: form email+password worker/dashboard + toggle "Masuk dengan NRP" (fallback)
  - [x] (3) E2E: mock `loginAsWorker` email mode + `loginAsWorkerByNrp` + handler `login_worker_by_email`
  - [x] (4) MFA: optional semua role — dashboard MFA form gap fixed, alert placeholder updated
  - [ ] (5) edge `worker-auth-sync` — tidak perlu ubah (Opsi A: NIK dari RPC)
  - [ ] (6) deploy: lint/test/build → `vercel --prod`
- **Keputusan desain:** Opsi A — `login_worker_by_email` return NIK, sehingga `provisionWorkerAuth(nrp,nik,pass)` tetap berfungsi tanpa ubah edge function. Email wajib di registrasi, NIK wajib 16 digit.
- **Email mapping:** worker `lower(trim(nrp))@insightwos.internal` (sintetis), admin
  `email@insightwos.com` (real, auth.users).
- **Files:** migration 216_login_worker_by_email.sql; Home.jsx; rate-limiter.js; mock-supabase.js; login-flow.spec.js; worker-auth-mfa-flow.spec.js; home.spec.js;
  tests/e2e/helpers/mock-supabase.js; src/components/MfaSetup.jsx.

## 7. STATE OPEN — Migration Gap Inventory (karyawan; asal: docs/migration-gap-inventory.md)

> Verifikasi read-only live DB (610 RPC, 253 tabel) + 62 file GAS. Ini GAP fitur/field
> (bukan bug/keamanan). 58 sheet GAS vs live: semua ada kecuali `login_tokens` (diganti
> `active_sessions` + JWT — keputusan desain benar). Frontend RPC: 206 dipakai, 0 tanpa padanan DB.

**B. Employee Master — field GAS yang belum ada di DB** (GAS 69 kolom = `employees_core` 23 +
`employees_extended` 39; sisa gap):

| # | Field (GAS) | Status | Notes |
|---|---|---|---|
| 1 | Agama Pekerja | ❌ Missing | |
| 2 | Akun Media Sosial | ❌ Missing | |
| 3 | Pendidikan Terakhir (jenjang) | ⚠️ Partial | hanya jurusan/institusi/tahun_lulus |
| 4 | Lokasi Penempatan (teks) | ⚠️ Partial | hanya site_id/business_unit_id |
| 5 | Nama Bank | ❌ Missing | hr_payroll tanpa kolom bank |
| 6 | Nomor Rekening | ❌ Missing | hr_payroll tanpa no. rekening |
| 7 | Nama Rekening | ❌ Missing | hr_payroll tanpa nama rekening |
| 8 | No BPJS Kesehatan | ❌ Missing | hr_payroll hanya nominal BPJS |
| 9 | No BPJS Ketenagakerjaan | ❌ Missing | hr_payroll hanya nominal BPJS |
| 10 | Riwayat Penyakit Khusus | ❌ Missing | |
| 11 | Komorbid | ❌ Missing | |
| 12 | Alergi | ❌ Missing | |
| 13 | 10 kolom upload (foto, KK+KTP, BPJS, ijazah, sertifikasi, tabungan, NPWP, SIM, ket anak kuliah, lainnya) | ⚠️ Replaced | generic `employee_documents` (kosong 0 rows); `hr_document_types` belum diisi |
| 14 | lastUpdatedBy | ❌ Missing | |
| 15 | statusKerjaInternal | ❌ Missing | |
| 16 | fileLinksJSON | ❌ Missing | |
| 17 | Pernyataan kebenaran data | ✅ Present | `consents` table |

**Butuh keputusan user** sebelum dikerjakan: mana yang jadi kolom `employees_extended` /
`hr_payroll`, mana ke `employee_documents`.

> **KEPUTUSAN 2026-09-14 (locked, DONE via migration 215):**
> bank/BPJS keanggotaan = kolom statis di `employees_extended`
> (rekomendasi terpilih; `Payroll.jsx` baca dari join karyawan).
> Mapping lengkap: §7 → core: `lokasi_penempatan`, `updated_by`, `status_kerja_internal`;
> extended: +11 kolom (`agama`, `media_sosial` JSONB, `jenjang_pendidikan`,
> `no_bpjs_kesehatan`, `no_bpjs_ketenagakerjaan`, `riwayat_penyakit`, `komorbid`,
> `alergi`, `nama_bank`, `no_rekening`, `nama_rekening`); upload → seed 12
> `hr_document_types` + `employee_documents`; `fileLinksJSON` = join;
> pernyataan kebenaran = `user_consents`. Sisa OPEN: tidak ada (UI input form
> kolom baru = pekerjaan terpisah, belum diputuskan).

## 8. JEBAKAN LINGKUNGAN (Windows / PowerShell / Supabase)

1. SQL Editor: hanya statement terakhir tampil → pecah blok multi-statement; agregat
   `pg_get_functiondef` error di `avg` → filter `prokind='f'`.
2. PowerShell: `$env:` untuk env; tanpa `< >` placeholder; hati-hati `[0]` pada single string
   (pakai `Select-Object -First 1`).
3. `npx` via PowerShell sering gagal stderr-as-error → jalankan via `cmd /c`, atau
   `Start-Process` untuk proses lama (vitest ~30–100s; jangan sync dalam timeout tool 30s).
4. `supabase db execute --db-url` bermasalah via PowerShell (npm notice stderr) → apply
   migration via python pg8000 (URL dari `.env.local`, JANGAN lewat argv agar tidak ter-log).
5. JS/TSX → VS Code; `.env.local` pernah pecah dotenv (blok SQL mentah) — cek parse sebelum
   deploy edge.
6. Apply migration live: pola `.freebuff/audit/apply_mig*.py` (split on `;`, per-statement
   OK/FAIL), lalu probe post-verify read-only.

## 9. STATE OPEN — TODO backlog (asal: `Readme/TODO.md`, di-merge 2026-09-13)

> Semua item di bawah masih OPEN (bukan blocker untuk deploy). Diurutkan prioritas.

### Q5: E2E Tests (Playwright) — HIGH
- [ ] Login → Dashboard load → Logout flow
- [ ] Admin login → Payroll view → Filter by BU
- [ ] Worker login → Check attendance → Request leave
- [ ] Role change → Verify new permissions active immediately
- [ ] Concurrent session limit test
- [ ] Dashboard rendering tests (stats, charts, tables)
- [ ] PWA offline mode tests (Service Worker caching)

### A7: Migration Versioning System
- [ ] Add `schema_migrations` table tracking version + checksum
- [ ] Each migration file gets `-- VERSION: xxx` header
- [ ] Startup check: detect unapplied / duplicate migrations
- [ ] Rollback scripts for critical migrations (131–143)

### TypeScript Migration
- [ ] Convert SQL RPCs to TypeScript edge functions (Supabase Edge Functions)
- [ ] Type-safe RPC calls with generated Supabase types
- [ ] Shared validation library (Zod) for input validation
- [ ] Remove raw SQL from frontend, use typed client

### Other TODOs (OPEN)
- [x] **B2**: `login_admin` migration to Supabase Auth — DONE: admin already uses Supabase Auth; deprecated `login_admin` RPC dropped (migration 217)
- [x] **N1**: AI RAG document access filtering (extend to all modules) — DONE: migration 215, RLS on ai_* tables, fixed match_documents precedence bug
- [x] **N4**: AI query rate limit tuning — DONE: migration 215, role-based (worker=15, admin=30, manager=50, owner=unlimited), warning at 80%
- [x] **I1**: Resolve duplicate tables — DONE: forensic audit (259 tables, 211 empty). Dropped3legacy: `mill_boiler`, `mfa_store`, `hr_preview_data` (migration 218). `review_360`→`reviews_360`, `okrs`→`hr_okrs` sudah resolved sebelumnya.
- [ ] **O5**: Hash-chain audit log (tamper-evident chain with prev_hash)
- [ ] **R4**: Write rollback scripts for all critical migrations

### DONE (catat di agentsLogs.md, jangan di sini)
- [x] **I5**: Split `employees_master` God Table → `employees_core` + `employees_extended` (migration 183)
- [x] **P1**: Data retention cleanup job (pg_cron) — migration 186
- [x] **M3**: Auto-refresh materialized view (035) via pg_cron — migration 186
- [x] Q1–Q4: Automated RPC / IDOR / RLS / PrivEsc tests (migration 184, 47/47 pass)
- [x] E2E setup: Playwright config + login-flow.spec.js + role-change.spec.js

## 10. STATE OPEN — Disaster Recovery (operasi; asal: `Readme/DR_PLAN.md`)

- Backup: Supabase automated daily (30d retention Pro), pg_dump weekly core tables (90d), git = permanent.
- **RPO 24h / RTO 4h.** Scenario: data corruption → PITR; mass delete → PITR; full restore → new project + migrations + backup; security breach → force logout all + rotate api_keys.
- Monitoring: backup status daily, RLS policies weekly, audit_log growth weekly, failed login spikes daily, session count anomaly daily.
- Testing: smoke test after each migration, backup restore monthly, DR drill quarterly, security audit bi-annually.
- Escalation: P1 1hr / P2 4hr / P3 24hr / P4 1wk.

## 11. JEBAKAN LINGKUNGAN (Windows / PowerShell / Supabase)




