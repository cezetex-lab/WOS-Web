# AGENTS.md — ATURAN KERJA AGENT (WAJIB) — ONE SINGLE TRUTH

> Diperbarui besar: **2026-09-15** (restrukturisasi ONE SINGLE TRUTH + grand design).
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
| `src/lib/supabase-browser.ts` | Session cache (sessionStorage `wos_user`), rpc() rate-limited |
| `src/lib/supabase-rpc.ts` | Typed RPC wrapper with function overloads |
| `src/lib/validation/schemas.ts` | Zod v4 schemas for all forms |
| `src/types/index.ts` | 25+ shared interfaces (Employee, Payroll, RPC, etc.) |
| `src/features/platform/auth/MfaSetup.tsx` | TOTP enroll/disable (ownership di edge `mfa-service`) |
| `supabase/functions/password-reset/index.ts` | `login_otp` (generate OTP langsung di edge) + `verify_login_otp` |
| `supabase/functions/worker-auth-sync/index.ts` | Edge v2 (provision/rotate) |
| `supabase/functions/ai-copilot/index.ts` | AI copilot dengan DOMPurify + role isolation |
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
11. **TypeScript wajib** — semua file `src/` harus `.ts`/`.tsx`. Jangan buat `.js`/`.jsx` baru.
    `tsc --noEmit` harus 0 error sebelum commit.

## 4. STATE OPEN — E2E Tests (Q5)

> 51/64 tests passed (13 skipped = live-backend tests yang butuh credentials).
> 6/7 items Q5 sudah ter-cover. Sisa: PWA offline mode.

- [x] Login → Dashboard load → Logout flow (`login-flow.spec.js`)
- [x] Admin login → Payroll view → Filter by BU (`admin-payroll.spec.js`)
- [x] Worker login → Check attendance → Request leave (`worker-attendance.spec.js`)
- [x] Role change → Verify new permissions active immediately (`role-change.spec.js`)
- [x] Concurrent session limit test (`concurrent-session.spec.js`)
- [x] Dashboard rendering tests (`full-sweep.spec.js`, `tab-click-test.spec.js`)
- [ ] **PWA offline mode tests** (Service Worker caching) — **belum ada spec**

## 5. STATE OPEN — UI Forms untuk Kolom Baru Karyawan

> DB sudah lengkap (migration 215): 14 kolom baru di `employees_core` + `employees_extended`.
> Yang belum: **UI input form** untuk kolom-kolom baru ini (pekerjaan terpisah, belum diputuskan).

Kolom yang butuh UI form:
- `agama`, `media_sosial` (JSONB), `jenjang_pendidikan`
- `no_bpjs_kesehatan`, `no_bpjs_ketenagakerjaan`
- `riwayat_penyakit`, `komorbid`, `alergi`
- `nama_bank`, `no_rekening`, `nama_rekening`
- `lokasi_penempatan`, `updated_by`, `status_kerja_internal`

**Butuh keputusan user**: apakah semua kolom ini perlu form input sekarang, atau fokus ke modul lain dulu?

## 6. JEBAKAN LINGKUNGAN (Windows / PowerShell / Supabase)

1. SQL Editor: hanya statement terakhir tampil → pecah blok multi-statement; agregat
   `pg_get_functiondef` error di `avg` → filter `prokind='f'`.
2. PowerShell: `$env:` untuk env; tanpa `< >` placeholder; hati-hati `[0]` pada single string
   (pakai `Select-Object -First 1`).
3. `npx` via PowerShell sering gagal stderr-as-error → jalankan via `cmd /c`, atau
   `Start-Process` untuk proses lama (vitest ~30–100s; jangan sync dalam timeout tool 30s).
4. `supabase db execute --db-url` bermasalah via PowerShell (npm notice stderr) → apply
   migration via python pg8000 (URL dari `.env.local`, JANGAN lewat argv agar tidak ter-log).
5. `.env.local` pernah pecah dotenv (blok SQL mentah) — cek parse sebelum deploy edge.
6. Apply migration live: pola `.freebuff/audit/apply_mig*.py` (split on `;`, per-statement
   OK/FAIL), lalu probe post-verify read-only.

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
│  DB: 253 tables, 617 functions, RLS on all tables          │
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
| TypeScript | ✅ DONE | — | Full .jsx→.tsx conversion (154 files, 0 tsc errors) |

### 7.4 Database Status (Live)

| Metric | Count | Notes |
|---|---|---|
| Tables | 253 | Including 38 attendance partitions |
| Functions | 617 | 28 overloads (legacy renamed `_legacy_*`) |
| Migrations tracked | 145 | Via `schema_migrations` table (migration 219) |
| RLS policies | All tables | Force-enabled, no USING(true) |
| SECDEF search_path | 0 violations | Fixed via migration 207 |
| anon/PUBLIC grants | 129 | Remaining: pgvector internals + login-flow |
| pg_cron jobs | 6 | Active: MV refresh, cleanup, OTP |
| Audit chain | 162 rows | Hash-chain verified (migration 220) |

### 7.5 Frontend Status

| Component | Status | Notes |
|---|---|---|
| TypeScript | ✅ 154 .ts/.tsx files | 0 tsc errors, strict mode |
| Unit tests | ✅ 100/100 | vitest |
| E2E tests | ✅ 51/64 passed | 13 skipped (live-backend) |
| Lint | ✅ 0 errors | eslint |
| Build | ✅ EXIT 0 | vite |
| Design system | ✅ Typed | cards, data, forms, providers |
| Auth flow | ✅ Email+password | Worker + admin + OTP + MFA |
| ChatCopilot | ✅ Role-isolated | DOMPurify + rate limit |

### 7.6 Security Posture

| Check | Status | Migration |
|---|---|---|
| JWT-based authz | ✅ | 131-140 |
| bcrypt passwords | ✅ | 141 |
| SECDEF search_path | ✅ | 207 |
| RLS all tables | ✅ | 131-140 |
| REVOKE anon/PUBLIC | ✅ | 210 |
| Audit log | ✅ | 141, 220 (hash-chain) |
| Rate limiting | ✅ | 141, 215 |
| MFA TOTP | ✅ | 150 |
| NIK NULL guard | ✅ | 206 |
| Migration versioning | ✅ | 219 |
| Rollback scripts | ✅ | 18 scripts (183-214) |

## 8. FUTURE ROADMAP (dari FuturePlans.md)

> Phase 1-3 roadmap untuk kompetisi dengan Workday/SAP/ADP di segmen mining/industri.
> Detail lengkap: `FuturePlans.md`

### Phase 1: Critical Foundation (3-6 bulan)
- [ ] **Native Mobile App** (React Native/Flutter) — GPS geofencing, offline mode, biometric
- [ ] **GPS Geofencing Attendance** — define zones, verify location, radius validation
- [ ] **Auto-Approval Rules** — threshold-based, net-staffing condition, multi-level
- [ ] **Bulk Operations** — salary update, department move, leave approval
- [ ] **Payroll Engine** — gross/net calculation, tax, BPJS, payslip PDF
- [ ] **Payslip Generation** — PDF, storage, email, MOM compliance
- [ ] **Shift Swap Workflow** — request, bidding, auto-approve
- [ ] **Anonymous Reporting** — grievance, evidence upload, two-way messaging

### Phase 2: High Value Features (6-12 bulan)
- [ ] **Push Notifications** — OneSignal/FCM, notification center
- [ ] **Team Dashboard** — attendance, performance, leave, overtime
- [ ] **Performance Grid** — 360 review, coaching, KPI
- [ ] **Onboarding/Offboarding Workflow** — checklist, document, settlement
- [ ] **SSO Integration** — Okta, Azure AD, Google Workspace

### Phase 3: Competitive Edge (12-18 bulan)
- [ ] **Predictive Analytics** — flight risk, attrition, skill gap
- [ ] **Team Chat** — Supabase Realtime, file sharing
- [ ] **Recognition System** — peer recognition, badges, gamification
- [ ] **LMS Integration** — course catalog, enrollment, certificates

## 9. DISASTER RECOVERY

- Backup: Supabase automated daily (30d retention Pro), pg_dump weekly core tables (90d), git = permanent.
- **RPO 24h / RTO 4h.** Scenario: data corruption → PITR; mass delete → PITR; full restore → new project + migrations + backup; security breach → force logout all + rotate api_keys.
- Monitoring: backup status daily, RLS policies weekly, audit_log growth weekly, failed login spikes daily, session count anomaly daily.
- Testing: smoke test after each migration, backup restore monthly, DR drill quarterly, security audit bi-annually.
- Escalation: P1 1hr / P2 4hr / P3 24hr / P4 1wk.
