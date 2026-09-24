# ARCHITECTURE.md — GRAND DESIGN insightWOS

> **Pecahan dari `AGENTS.md` (2026-09-19).** Isi di bawah ini dipindahkan apa adanya —
> nomor bagian lama (`§5.7`, `§6.4`, `§7.4`, …) sengaja DIPERTAHANKAN agar rujukan lama tetap
> bisa ditelusuri. Peta bacanya ada di `AGENTS.md` (Reading Map). Jangan menaruh riwayat
> pekerjaan selesai di berkas ini — itu milik `agentsLogs.md`.

> Angka di §7.1/§7.3/§7.4/§7.5 diverifikasi otomatis terhadap DB live + isi repo oleh
> `tests/unit/doc-claims-vs-live.test.ts`. Kalau schema/berkas berubah secara sah: perbarui
> angka DI SINI (bukan di `AGENTS.md`) — jangan melemahkan tesnya.

## 1. KONTEKS PROYEK (handoff)

- Aplikasi: insightWOS (WOS-Web) — HR/workforce + modul industri (mining/estate/mill).
  Migrasi Google Apps Script → Supabase.
- Frontend: React + Vite (:5173), deploy Vercel CLI (insightwos.vercel.app), repo GitHub
  `cezetex-lab/WOS-Web`, branch kerja `migrasi-vite`.
- Backend: Supabase `verwobaejumvpagwynae` (ap-northeast-1; keputusan migrasi ke
  ap-southeast-1/Singapore ada di `OPEN_WORK.md` §5.5).
- 17 worker seed (NRP001–NRP010 + NRP100–106); NRP001 = admin_pusat + worker.
- Arsitektur auth (JANGAN diubah tanpa keputusan user): worker login email+password →
  RPC `login_worker_by_email` → fast path `signInWithPassword` → fallback edge `worker-auth-sync`.
  Email sintetis = `lower(trim(nrp))@insightwos.internal`. Admin = email real `@insightwos.com`.
- UPDATE data karyawan **selalu ke `employees_core`** (base table); `employees_master` = VIEW
  non-updatable (dengan INSTEAD OF triggers).
- Verifikasi cepat sehat: login worker → `sb-verwobaejumvpagwynae-auth-token` ADA di Local
  Storage; Dashboard Auth → Last signed in terupdate.


## 2. PETA FILE PENTING

| File | Isi |
|---|---|
| `src/pages/Home.tsx` | Login semua tab; `provisionWorkerAuth` (fast path+fallback); `redirectAfterLogin(entry)` per-tab; OTP wajib admin/dashboard (edge) |
| `src/App.tsx` | BrowserRouter future flags v7; `/admin` `/worker` `/dashboard` dibungkus `RoleGuard` (`entry`+`allowedRoles`) — isolasi 3 page |
| `src/components/RoleGuard.tsx` | Role + login-entry check (`session.entry`); mismatch → redirect login |
| `src/pages/Admin.tsx` / `Worker.tsx` / `Dashboard.tsx` | Cek `session.entry` mismatch → redirect `/`; role-worker → "Akses Ditolak" |
| `src/components/DynamicRoutes.tsx` | Route dinamis dari `get_enabled_modules(p_area)`; `areaFromPath()` filter per-area |
| `src/lib/route-config.ts` | Map route_component → lazy component |
| `src/lib/menu-builder.ts` | `buildMenu(area)` + `areaFromPath` + filter per-area + dedup |
| `src/lib/supabase-browser.ts` | Session cache (`wos_user_v2`, wajib `expires_at`), `rpc()` rate-limited + kontrak `T \| RpcError` + guard `isRpcError()` |
| `src/lib/supabase-rpc.ts` | Typed wrappers RPC — delegasi ke `supabase-browser` (satu sumber kebenaran), hasil `T \| RpcError` |
| `src/hooks/useRpcQuery.ts` | Hook data-fetching: cancelled-flag, `isRpcError` guard, `T \| RpcError \| undefined` |
| `src/types/index.ts` | 25+ shared interfaces (Employee, Payroll, RPC, etc.) |
| `src/features/platform/auth/MfaSetup.tsx` | TOTP enroll/disable (ownership di edge `mfa-service`) |
| `supabase/functions/password-reset/index.ts` | `login_otp` (generate OTP langsung di edge) + `verify_login_otp` |
| `supabase/functions/worker-auth-sync/index.ts` | Edge v2 (provision/rotate) |
| `supabase/functions/ai-copilot/index.ts` | AI copilot dengan DOMPurify + role isolation |
| `supabase/scripts/provision-worker-auth.mjs` | Batch provisioning `--dry`/`--run` |
| `supabase/akun/akun.txt` | Plaintext kredensial (gitignored — NEVER commit) |
| `agentsLogs_YYYY-MM.md` | ONE SINGLE TRUTH — LOG riwayat pekerjaan selesai (per bulan) |
| `agentsLogs.md` | indeks bulan log — hanya penunjuk ke `agentsLogs_YYYY-MM.md` |


## 7. GRAND DESIGN — Arsitektur & Status Implementasi

### 7.1 Arsitektur Sistem

```
┌─────────────────────────────────────────────────────────────┐
│                    FRONTEND (React + Vite)                   │
│  src/pages/ (Home, Admin, Worker, Dashboard)                │
│  src/components/ (RoleGuard, DynamicRoutes, ChatCopilot)    │
│  src/features/ (core, industry, platform, intelligence)     │
│  src/lib/ (supabase-browser, rpc, validation, design-system)│
│  src/types/ (25+ shared interfaces)                         │
└──────────────────────────┬──────────────────────────────────┘
                           │ Supabase JS v2
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    SUPABASE BACKEND                          │
│  Auth: email+password + OTP + MFA TOTP                      │
│  DB: 208 tables, 658 functions, RLS on all tables          │
│  Edge Functions: password-reset, worker-auth-sync,          │
│                  ai-copilot, mfa-service                     │
│  Storage: employee documents, payslips (future)             │
│  Realtime: subscriptions (future: team chat)                │
└─────────────────────────────────────────────────────────────┘
```

### 7.2 Auth Architecture (3-Layer Isolation)

```
Layer 1: RoleGuard (route level)
  /admin  → allowedRoles: admin*, owner
  /worker → allowedRoles: worker
  /dashboard → allowedRoles: admin*, owner

Layer 2: Page useEffect (session.entry check)
  Admin.tsx  → if entry !== 'admin'  → redirect /
  Worker.tsx → if entry !== 'worker' → redirect /
  Dashboard.tsx → if entry !== 'dashboard' → redirect /

Layer 3: DB-level (authz functions)
  authz_current_nrp() → JWT-based NRP
  authz_check_admin() → role check
  authz_in_scope()    → BU scope check
```

**Kontrak sesi client (v2, 2026-09-16) — jangan diubah per-halaman, ini lapisan bersama:**
- Key sessionStorage `wos_user_v2` (skema lama `wos_user` sengaja ditinggalkan → user lama
  login ulang sekali; inilah yang menutup bypass sesi legacy).
- `UserSession` **tidak punya** `token` — token app-level tidak pernah dipersist.
- `expires_at` **wajib**; tanpa itu (atau tidak bisa diparse / sudah lewat) sesi DITOLAK.
  `setSession()` menstempel `entry` + `expires_at` di satu choke point.
- Edge `worker-auth-sync` menukar password internal menjadi SESI Supabase — password tidak
  pernah dikembalikan ke client.

### 7.3 Migration Status

| Phase | Status | Migrations | Notes |
|---|---|---|---|
| Foundation | ✅ DONE | 000-005 | Tables, RLS, core functions |
| Core HR | ✅ DONE | 011-068 | Employees, attendance, payroll, leave |
| Industry | ✅ DONE | 050-065 | Mining, estate, mill modules |
| Owner/Admin | ✅ DONE | 071-095 | Dashboards, config, branding |
| Security | ✅ DONE | 130-140 | IDOR, authz, audit, rate-limit |
| Audit Fix | ✅ DONE | 141-153 | Comprehensive security remediation |
| GAS Migration | ✅ DONE | 154-168 | Google Apps Script → Supabase |
| Cleanup | ✅ DONE | 191-220 | Dead forms, REVOKE, search_path, versioning |
| Worker Profile RPC | ✅ DONE | 222 | `get_worker_profile` + `worker_update_profile` (14 kolom baru, legacy renamed `_legacy_*`) |
| TypeScript | ✅ DONE | — | 207 file TS total (157 `src` + 42 `tests` + 8 config), 0 tsc errors — `tsconfig` mencakup `src`+`tests`+`*.config.ts`, `allowJs: false` |
| Partisi dinamis + ACL RPC penulis | ✅ DONE | 225-227 | `ensure_attendance_partitions()` (idempoten) menggantikan loop hardcoded `2024..2027`; cron bulanan; `overtime_approved` diselaraskan. Migration 226 mencabut anon/PUBLIC dari 4 RPC penulis (`worker_update_profile` + 3 trigger), dan PUBLIC dari 7 RPC alur login (anon dipertahankan). Penjaga: `tests/unit/db-security-and-partition-guard.test.ts` |
| Instalasi perusahaan baru (baseline) | ✅ DONE | `supabase/baseline/` (2 berkas) | Jalur RESMI untuk project kosong: `npm run install:baseline -- --target ... --company-name "PT X" --owner-email "..." --apply`. Diverifikasi `verify-install-e2e.mjs`: 9/9 metrik = live, ACL 0 selisih, `check_migrations()` 0 issue, idempoten. Runbook: `supabase/baseline/README.md`; templat akun owner: `first-owner.example.sql`. Rantai migrasi tetap dipelihara sebagai histori + gerbang regresi (`db:replay --mode=chain` = 160/160) |
| Audit 2026-09-16 | ✅ DONE (`81a5bf5`, deployed — sisa OPEN audit di §5.6) | — | Ringkasan: helper `requireNrp()`/`requireSession` di `src/lib/supabase-browser.ts` menggantikan fallback `'NRP001'` di 13 komponen; RoleGuard fail-closed (allowedRoles=0 ditolak); CSP `script-src` ditarik `unsafe-inline`/`unsafe-eval` via modul TS (error-suppressor & SW register); index.html inline script dipindah ke `src/main.tsx`; `vercel.json` CSP diperbaiki (`unsafe-eval` + `img-src https:` wildcard dibuang; entri `connect-src alive-robin` **sengaja dipertahankan** sesuai §5.5) — ⚠ file-file ini masih UNCOMMITTED; `tsc` sempat 7 error (import `requireNrp` hilang di 5 file + `React` UMD di `main.tsx`), sudah diperbaiki → tsc 0 error. COMMIT `81a5bf5` → push → deploy production `insightwos-lo3gcmyg9` ● Ready (alias HTTP 200; CSP prod + 0 inline script terverifikasi via curl); sinkronisasi `areaFromPath`/`menu-builder`; 12 file `format.ts` dibersihkan komentar histori; build EXIT 0, lint 0 error, tsc 0 error, E2E 51/51 hijau. Detail: hardcode identitas `|| 'NRP001'` dihapus dari Worker.tsx, ForumDiskusi, TrainingForm, WorkerOvertime, CompensationIntel, WorkerPayroll, WorkerProfile, ContinuousPerf, PerformanceTrend, WorkerKpi, WorkerCareer, WorkerActivities. Branding FreeBuff sudah bersih di UI aktif. Komentar histori/banner dikompaktankan (jaga RoleGuard/DynamicRoutes/vite.config). Dampak lintas-page: worker→admin→dashboard→owner — semua component identitas sekarang melalui layer bersama, tidak ada patch per-page. |

### 7.4 Database Status (Live)

| Metric | Count | Notes |
|---|---|---|
| Tables | 208 | 208 base table **non-partisi**; 209 kalau view dihitung. Partisi absensi (kini **57**) TIDAK dihitung karena dibuat otomatis oleh `ensure_attendance_partitions()` (migration 225) |
| Functions | 658 | 20 overloads (legacy renamed `_legacy_*`); +1 `ensure_attendance_partitions` (migration 225). LIVE 2026-09-19: 667 → 670. 2026-09-21 (SQL-02): migrasi 243 DROP 13 fungsi legacy tanpa sumber migrasi → **657**. 2026-09-24 (OPS-14b): migrasi `247` menambah `authz_is_owner()` → **658** |
| Migrations tracked | 173 | Via `schema_migrations` (migration 219); 221–227 didaftarkan 2026-09-17 (§5.7 no.11); `008` + `229` + `230` diterapkan 2026-09-18 (`DITERAPKAN + terdaftar + checksum terverifikasi`). `231`–`233` diterapkan + terdaftar 2026-09-19. Rename sesi paralel 232–235 → 236–239 sudah terdaftar di live (236–239; nomor 232/233 dipakai file grant yang sudah ada). 2026-09-21 (SQL-11): migrasi `240` dipulihkan ke repo (restamp checksum `a3d394b7…`) + migrasi `241` diterapkan. 2026-09-21 (SQL-13): migrasi `242` (nonaktifkan `dashboard_landing`). 2026-09-21 (SQL-02): migrasi `243` (drop 13 fungsi legacy tanpa sumber). 2026-09-21 (SQL-12): migrasi `244` (semantik `worker_update_profile`: NULL = jangan ubah, '' = kosongkan; signature sama) — live 169 baris. 2026-09-21 (OPS-05): migrasi `245` (grant `EXECUTE` `check_login_lockout` ke `anon` — cek lockout pra-login sebelumnya selalu 401 permission denied → fail-open). 2026-09-24 (OPS-14): migrasi `246` (seed ulang `user_role_assignments` 17 baris + permission set `admin_operasional` + `setval` sequence) — live 170 baris. 2026-09-24 (OPS-14b): migrasi `247` (helper `authz_is_owner()` + owner bypass di `admin_reset_worker_password`) — live 171 baris. 2026-09-24 (OPS-07): migrasi `248` (rate-limit `login_lockout_record` + cron `cleanup-login-attempts` + **pulihkan grant anon `check_login_lockout` yang hilang** pasca reset DB 2026-09-22) **+ restamp 245** (baris `245_ops05_grant_anon_lockout.sql` hilang dari registry meski efeknya sudah ada — kelas bug yang sama seperti SQL-11) — live **173** baris = jumlah file repo |
| RLS policies | All tables | Enabled di semua tabel tanpa USING(true); **9 tabel belum FORCE** (`employees_core`, `employees_extended`, `fatigue_data`, `heavy_equipment`, `jsa_data`, `production_daily`, `safety_incidents`, `schema_migrations`, `simper_data`) — pemilik tabel masih melewati RLS |
| SECDEF search_path | 0 violations | Fixed via migration 207 |
| anon/PUBLIC grants | 130 | **119 internal pgvector** + 3 RPC baca yang memang pra-login (`get_branding`, `get_branding_public`, `get_enabled_modules`) + 7 entry pra-login. Turun 132 → 129 lewat 226 lalu 232/233 (grant warisan RENAME + default privilege yang lolos karena guard `to_regprocedure` 226C). 2026-09-21 (OPS-05): +1 = `check_login_lockout` (grant `EXECUTE` ke `anon`, migrasi `245`) — wajib pra-login, badan fungsinya menulis audit `login_attempts` sehingga ikut `PRE_AUTH_WHITELIST` di `db-security-and-partition-guard.test.ts`. 2026-09-24 (OPS-07): grant `check_login_lockout` **hilang** di live (regresi pasca reset DB 2026-09-22 — baseline lama tidak memuat grant) → dipulihkan migrasi `248` bersama rate-limit penulisan `login_attempts` → **130** |
| pg_cron jobs | 4 | LIVE 2026-09-18 (pasca-228 pensiun 3 job MV gagal/setiap jam): `cleanup-sessions`, `cleanup-rate-limits`, `cleanup-otp`, `ensure-attendance-partitions`. 2026-09-24 (OPS-07): +1 = `cleanup-login-attempts` (03:30 UTC, `SELECT cleanup_login_attempts()` retensi 7 hari — fungsi sudah ada sejak lama tapi belum pernah dijadwalkan) |
| Audit chain | 44 rows | Hash-chain live, `verify_audit_chain()` = 0 issues (migration 220); baris hanya bertambah |

### 7.5 Frontend Status

| Component | Status | Notes |
|---|---|---|
| TypeScript | ✅ 157 .ts/.tsx files (132 `.tsx` + 25 `.ts`) | 0 tsc errors (re-verifikasi 2026-09-17), strict mode, `allowJs: false` |
| Unit tests | ✅ 132/132 | vitest (20 berkas; 2 project: `node` + `jsdom`) — termasuk penjaga rekonsiliasi data dummy live (`dummy-reconciliation-guard.test.ts`) |
| E2E tests | ✅ 4/4 passed (four-page live smoke) | `tests/e2e/four-page-smoke.spec.ts` (Worker/Admin/Dashboard/Owner, kredensial live via env); 13 live-backend lain tetap opt-in |
| Lint | ✅ 0 errors | eslint |
| Build | ✅ EXIT 0 | vite |
| Design system | ✅ Typed | cards, data, forms, providers |
| Auth flow | ✅ Email+password | Worker + admin + OTP + MFA |
| ChatCopilot | ✅ Role-isolated | DOMPurify + rate limit |
