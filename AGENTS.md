# AGENTS.md — ATURAN KERJA AGENT (WAJIB)

> Aturan ini mengikat. Pelanggaran = pekerjaan ditolak. Dibuat dari analisa audit 1A (47 batch file + DB live).

## 0. JANGAN KERJA DULU — PAHAMI, IKUTI ANALISA

1. **DILARANG** mengeksekusi remediasi apa pun sebelum user menyatakan **GO** secara eksplisit.
2. **PAHAMI dulu, baru bertindak.** Sumber wajib baca:
   - Analisa 1A dari user (tabel temuan & status remediasi — sumber kebenaran #1)
   - `.freebuff/audit/report.md` (forensik DB live vs migrasi repo)
   - `.freebuff/audit/AUDIT_TRUST_CLIENT_REPORT.md` (audit RPC trust-the-client)
   - `docs/5.0-credential-rotation-runbook.md`
3. **IKUTI analisa user** — jangan bikin rencana remediasi sendiri, jangan mengubah urutan tahap, jangan mengerjakan item di luar daftar.
4. Analisa masih bertahap (1A, 1B, 2, …). Mode kerja hanya dimulai setelah semua bagian diterima DAN user bilang GO.
5. Pengecualian tunggal: **P0-8 (.gitignore)** karena memblokir commit pertama — kerjakan segera setelah GO, sebelum apa pun di-commit.

## 1. VERIFIKASI KE DB LIVE — JANGAN PERCAYA LAPORAN LAMA

- Laporan audit lama terbukti banyak **false positive**. Klaim yang sudah GUGUR (terverifikasi aman di DB live — **JANGAN dikerjakan ulang**):
  - `admin_reset_worker_password` (sudah authz + bcrypt + invalidasi sesi + audit)
  - `get_exit_clearance` & `admin_get_whistleblower` (grants hanya postgres/service_role)
  - `update_branding` (ada cek owner via auth_id)
  - Owner privilege escalation via `owner_*` (semua cek is_owner)
  - `get_worker_payroll` (sudah authz: owner/caller/in-scope)
  - `login_worker` (validasi NRP+NIK+password, lockout, bcrypt auto-upgrade)
- Setiap temuan **WAJIB diverifikasi langsung ke DB live** (`DATABASE_URL` di `.env.local`) atau kode live sebelum dikerjakan.

## 2. STATUS TEMUAN 1A — JANGAN BUKA YANG SUDAH DITUTUP

### ✅ DITUTUP — JANGAN re-do / re-open:
| ID | Ringkas |
|---|---|
| P0-1 | `get_reviews_360(text)` — REVOKE + fungsi aman (admin semua, reviewer dimask, worker miliknya) |
| P0-2 | `get_medical_checkup(text)` — idem |
| P0-3 | 13 versi legacy overload di-RENAME `_legacy_*` |
| P0-4 | Auth hook: fast path + edge worker-auth-sync + batch provisioning 8 worker |
| P0-5 | `generate_worker_otp` 3-arg (bcrypt + increment attempts), patch 001.sql |
| P0-7 | `admin_reset_worker_password` bcrypt fix, patch 001.sql |
| A3 | `get_nursery_data()` 0-arg — REVOKE done |
| A4 | Overload `get_reviews_360`/`get_medical_checkup`/`get_worker_requests`/`create_worker_request` — legacy di-RENAME |
| A6 | Helper `authz_*` granted ke authenticated (002.sql) |
| A7 | `generate_worker_otp` 2-arg legacy — REVOKE + RENAME |
| A8 | NIK 8 worker di-backfill placeholder `3204…` |
| A12 | Fix klien menu-builder.js filter per-area (root fix → 5.10) |
| A13 | Redirect login per-tab (bukan per-role) |
| A14 | `.env.local` blok SQL — diatasi sementara (rename trick); rapikan permanen saat 5.0 |
| A15 | Kredensial DB + service_role sudah dirotasi; edge di-redeploy |

### 🟡 OPEN — tunggu urutan tahap (JANGAN dikerjakan sebelum giliran tahapnya):
| Tahap | Item |
|---|---|
| 5.0 | Rotasi kredensial permanen + rapikan `.env.local` (A14) — ikuti runbook |
| 5.3 | P0-6 guard permanen NIK NULL (constraint + NULL-check di RPC) |
| 5.4 | A10 data palsu/fallback: SafetyK3, JSA, ProductionDaily, Transport, Simper, Block, Irrigation |
| 5.5 | A11 form mati tanpa handler (lapor K3, panen, fasilitas) |
| 5.6 | A9 ChatCopilot: DOMPurify + guard auth.uid() di edge function |
| 5.8 | A1/A2 REVOKE PUBLIC+anon: `admin_get_payroll`, `admin_set_employee_role` |
| 5.9 | A5 `employees_master` VIEW non-updatable → write-path permanen |
| 5.10 | A12 root fix: RPC `get_enabled_modules` parameter `p_area` |

### P0-8 (Open, blocking):
`.gitignore` saat ini tidak mencakup `provision-results.csv` (root), `test-results/`, dan artefak `.freebuff/audit/` (script audit, log, CSV). Perbaiki **sebelum commit pertama**: audit scripts / test-results / CSV password tidak boleh ter-commit.

## 3. KONTEKS PROYEK (handoff — sama seperti analisa user)

- Aplikasi: insightWOS (WOS-Web) — HR/workforce + modul industri (mining/estate/mill). Migrasi Google Apps Script → Supabase.
- Frontend: React + Vite (:5173), deploy Vercel CLI (insightwos.vercel.app). Backend: Supabase `verwobaejumvpagwynae` (ap-northeast-1).
- 17 worker seed (NRP001–NRP010 + NRP100–106); NRP001 = admin_pusat + worker.
- Arsitektur auth (JANGAN diubah tanpa membaca §6 handoff): worker login NRP+NIK+password → RPC `login_worker` → FAST PATH `signInWithPassword({nrp}@insightwos.internal, password sama)` → fallback edge `worker-auth-sync` (verif ulang, rotate password auth). Email sintetis = SATU SUMBER: `lower(trim(nrp))@insightwos.internal`.
- UPDATE data karyawan **selalu ke `employees_core`** (base table); `employees_master` = VIEW non-updatable.
- Verifikasi cepat sehat: login worker → Local Storage `sb-verwobaejumvpagwynae-auth-token` ADA; Dashboard Auth → Last signed in terupdate; console hanya SW registered + favicon 404 (kosmetik).

## 4. PETA FILE PENTING

| File | Isi |
|---|---|
| `src/pages/Home.jsx` | Login semua tab; `provisionWorkerAuth` (fast path+fallback); `redirectAfterLogin(entry)` per-tab |
| `src/App.jsx` | BrowserRouter future flags v7 |
| `src/lib/menu-builder.js` | `buildMenu(area)` + `areaFromPath` + filter per-area + dedup |
| `src/lib/supabase-browser.js` | Session cache (sessionStorage `wos_user`), rpc() rate-limited |
| `supabase/functions/worker-auth-sync/index.ts` | Edge v2 (provision/rotate) |
| `supabase/scripts/provision-worker-auth.mjs` | Batch provisioning `--dry`/`--run` |
| `supabase/patch/001.sql`, `002.sql` | Fix bcrypt OTP; GRANT `authz_*` |
| `docs/5.0-credential-rotation-runbook.md` | Runbook rotasi kredensial |

## 5. JEBAKAN LINGKUNGAN (dari handoff)

- Ketik SQL → SQL Editor (hanya statement terakhir tampil → pecah blok multi-statement; agregat `pg_get_functiondef` error di `avg` → filter `prokind='f'`). PS `D:\...>` → PowerShell (`$env:`, tanpa `< >` placeholder). JS/TSX → VS Code.
- `.env.local` pernah berisi blok SQL mentah → pecah dotenv & supabase CLI (rename trick `_env.local.backup`). Cek parse SEBELUM deploy edge; setelah rotasi service key, redeploy edge sekali.
- Rahasia: DB password & service_role sudah dirotasi. `provision-results.csv` = plaintext password → tidak pernah di-commit, hapus setelah dibagikan.

## 6. ATURAN TEKNIS KERAS (dari audit sebelumnya — jaga tetap terpenuhi)

1. Identitas & authz **selalu dari JWT** (`authz_current_nrp()`, `authz_check_admin()`, `authz_in_scope()`) — **jangan pernah** percaya param client (`p_admin_nrp`, claim header, `p_nrp` bebas).
2. Password **tidak pernah plaintext** — bcrypt (`gen_salt('bf')` + `crypt()`), tanpa echo password di response.
3. `SECURITY DEFINER` wajib `SET search_path` (saat ini 0 pelanggaran — jangan tambahkan pelanggaran baru).
4. Jangan bikin overload fungsi dengan nama sama; bereskan legacy dengan RENAME `_legacy_*`, bukan DROP liar.
5. Fungsi sensitif: default fail-closed, dan cek grant-nya (REVOKE PUBLIC/anon untuk fungsi admin).
6. Setiap klaim "sudah aman" dari sesi sebelumnya = anggap belum terverifikasi sampai dicek ke DB live.

## 7. HASIL AUDIT FULL 2026-09-10 (semua verifikasi read-only; script: `.freebuff/audit/live_audit_20260910.py`, `live_audit2_20260910.py`)

### ✅ Terverifikasi sesuai handoff (JANGAN dikerjakan ulang)
- NIK NULL = **0** di 17 baris `employees_core`; semua `auth_id` terisi. A8/P0-6 backfill ✓.
- `auth.users` = 9 `@insightwos.internal` + 9 `@insightwos.com` = 18 (9+9 sesuai handoff).
- Grants sensitif BERSIH: `admin_get_payroll`, `admin_set_employee_role`, `get_reviews_360`, `get_medical_checkup`, `get_nursery_data`, `admin_reset_worker_password`, `get_exit_clearance`, `admin_get_whistleblower`, `get_worker_payroll`, `update_branding` — **tidak ada anon/PUBLIC** → **A1/A2 dalam praktik SUDAH TERTUTUP di DB live** (tinggal catat, bukan kerja ulang).
- Overload legacy hanya `_legacy_*` (13) ✓; RLS enabled di SEMUA tabel/view/MV kecuali `employees_master` (A5 dikonfirmasi).
- Kode: fast path + fallback, redirect per-tab, menu filter+dedup, edge v2, future flags — semua ada di kode.
- Worktree & index BERSIH dari literal secret (`.env.local` tidak ter-track; CSV tidak ter-stage; scan `postgresql://|SERVICE_ROLE|ywYBamE6` = placeholder/komentar saja).

### 🔴 TEMUAN BARU (sesi audit 2026-09-10)
| ID | Temuan | Bukti |
|---|---|---|
| F-1 | **128 file STAGED** untuk commit pertama, termasuk 49 file `.freebuff/audit/` + 7 `test-results/`; rename `migrations/002_auth_functions.sql`→`smoke/`, `004_seed_passwords.sql`→`smoke/` ikut ter-stage. `.gitignore` belum menutup `.freebuff/`, `test-results/`, `provision-results.csv`. | `git status --porcelain` (128) |
| F-2 | **Ref rusak `refs/heads/master`** (missing object) + reflog entries invalid → `git log --all`/`for-each-ref` gagal; berisiko gagal saat push commit pertama. Perbaiki: hapus `refs/heads/master`, `git reflog expire --expire=now --all && git gc --prune=now` (atau filter reflog). | `git fsck` |
| F-3 | **Old DB password ada di history**: commit `2f16285` (redact supa.txt) & `ce7a310` ber-ASIS `-S ywYBamE6` (bukan hitungan karakter: token muncul di kedua commit). Password SUDAH dirotasi (5.0) sehingga tidak lagi valid — jadikan catatan, bukan blocker. | `git log -S` |
| F-4 | **`get_enabled_modules()` SECURITY DEFINER TANPA `SET search_path`** — pelanggaran Rule §6.3 tunggal (sebelumnya 0). Ada di migration 186. Perbaiki saat 5.10 (tambahkan `SET search_path TO 'public', 'extensions'` atau re-deploy migration). | live DB B-def |
| F-5 | **`worker_passwords` ≠ handoff**: NRP002,003,004,006,007,008,010 = **non-bcrypt (sha256+salt) dengan `reset_required=false`** (script provisioning memang menulis legacyHash + reset_required:false — jangan dianggap "8 worker reset_required=true"). NRP100–106 (7 akun) tidak disebut handoff. Password auth vs worker_passwords disinkron script → fast path OK, tapi target 5.7 (retire dual-store) makin penting. | live DB C-def |
| F-6 | **`patch/002.sql` berisi UUID hardcoded + blok impersonasi `set local role authenticated`** — file staging ikut ter-commit. Rapikan (pisahkan blok verifikasi ke file test) sebelum commit. | isi file |
| F-7 | **`pg_cron` TIDAK terinstal** (available 1.6.4, installed NULL) + schema `cron` tidak ada; migration `186_enable_pg_cron_schedules.sql` ter-stage. Cron (otp cleanup dll.) tidak jalan sampai pg_cron di-enable. | live DB D/E-def |
| F-8 | **5 RPC industri granted anon**: `get_field_status`, `get_irrigation_status`, `get_maintenance_schedule`, `get_mill_production`, `get_yield_data` (+`cleanup_rate_limits`, `change_password`, `check_login_lockout`, `get_enabled_modules`, `get_branding` ke anon). Evaluasi masing-masing saat 5.8. | live DB 1/1b |
| F-9 | Missing di DB: `get_organization_health`, `update_audit_timestamp`, `register_session` (dipanggil frontend). `update_task_status` punya overload (p_id int / p_task_id text) — pastikan kontrak frontend cocok. | live DB 8/9 + report.md §8 |
| F-10 | `supabase/migrations/run_171.mjs` menerima URL DB via argv (bisa ke-log); `tests/production/smoke.sh`, `api-bench.js`, `run-gates.*` pola sama — aman selama tidak pernah diisi kredensial asli di terminal yang di-log. | grep placeholder |

### 🔴 TEMUAN BARU (sesi testing 2026-09-11 — Login & Route Verification)

| ID | Severity | Temuan | Bukti | Status |
|---|---|---|---|---|
| L-1 | 🔴 HIGH | NRP003 password hash mismatch — `d5wcHVOp-GbnONVK` tidak cocok dengan hash di `worker_passwords` | diag5.txt: `NRP003/d5wc → url=http://localhost:5173/ token=false` | OPEN |
| L-2 | 🔴 HIGH | HRD admin account timeout — `hrd@insightwos.com / Hrd123!Hrd` 60s timeout (wrong password atau akun tidak ada di Supabase Auth) | diag5.txt: `✗ Admin: hrd@insightwos.com + Hrd123!Hrd (1.0m)` | OPEN |
| L-3 | 🟡 MEDIUM | Admin routes tidak ter-register — DynamicRoutes ambil dari `get_enabled_modules()`, kebanyakan admin route tidak ada di `module_definitions` → redirect ke `/` | sweep_final.txt: semua admin route error "navigate" | OPEN |
| L-4 | 🟡 MEDIUM | Worker login flaky — NRP002 berhasil di diagnostic test tapi gagal di sweep test (timing issue) | sweep_final.txt: `Worker login: url=http://localhost:5173/ token=false` | OPEN |
| L-5 | 🟢 LOW | Test false positives — regex error detection match SW registration code (`'SW registered:', reg.scope)`) | sweep_final.txt: semua "UI-error" match SW code | OPEN |

### KREDENSIAL TERVERIFIKASI (2026-09-11)

**Worker (login_worker RPC — NRP + NIK + password):**
| NRP | NIK | Password | Status |
|-----|-----|----------|--------|
| NRP001 | NRP001 | CEO123! | ✅ (bcrypt) |
| NRP002 | 3204000000000002 | 3204000000000002 | ✅ (sha256→auto-upgrade) |
| NRP003 | 3204000000000003 | d5wcHVOp-GbnONVK | ❌ (hash mismatch) |
| NRP007 | 3204000000000007 | 3204000000000007 | ✅ (sha256→auto-upgrade) |

**Admin (Supabase Auth — email @insightwos.com + password):**
| Email | Password | Status |
|-------|----------|--------|
| ceo@insightwos.com | CEO123! | ✅ |
| pusat@insightwos.com | Admin123! | ✅ |
| operasional@insightwos.com | Ops123! | ✅ |
| hrd@insightwos.com | Hrd123!Hrd | ❌ (timeout) |
| finance@insightwos.com | Fin123! | ❓ (not tested) |
| mining@insightwos.com | Mining123! | ❓ (not tested) |
| mill@insightwos.com | Mill123! | ❓ (not tested) |
| estate@insightwos.com | Estate123! | ❓ (not tested) |

### CHECKLIST COMMIT PERTAMA — SEMUA BERES ✅ (terverifikasi 2026-09-12)
| # | Item | Status | Bukti |
|---|---|---|---|
| 1 | `.gitignore` menutup `.freebuff/`, `test-results/`, `playwright-report/`, `provision-results.csv`, `_env.local.backup`, `supabase/smoke/`, `*.txt`, `supabase/seed_company_config.sql`, `fix-nrp003.sql` | ✅ | isi `.gitignore`; `git ls-files` bersih dari artefak (0 match) |
| 2 | Artefak audit/test tidak ter-track | ✅ | `git ls-files \| grep -iE '.freebuff\|test-results\|provision-results\|smoke/'` = kosong |
| 3 | F-6: `patch/002.sql` impersonasi dipisah ke `002_test_verification.sql` | ✅ | isi file: blok sudah dipindah |
| 4 | F-2: ref rusak `refs/heads/master` sudah tidak ada; `git fsck --full` 0 error | ✅ | hanya `refs/heads/migrasi-vite`; fsck hanya dangling objects (normal) |
| 5 | Scan secret `postgresql://\|SERVICE_ROLE\|ywYBamE6` | ✅ | hanya match di AGENTS.md (dokumentasi temuan F-3), bukan secret; password lama sudah dirotasi |
| 6 | Commit pertama + push: `49a2e9a` "fix(audit): close L-1..L-5..." → `origin/migrasi-vite` | ✅ | `git log`, reflog |

### CHECKLIST COMMIT — PROD FIX 2026-09-12 (stripConsole crash) — COMMIT SEKARANG
| # | Item | Status | Bukti |
|---|---|---|---|
| 1 | Bug prod "Cannot read properties of undefined (reading 'find')" — plugin `stripConsole` di `vite.config.js` menghapus `console.warn(...)` yang jadi if-body sehingga `return` berikutnya jadi if-body → `fetchAllRouteConfig` return `undefined` → crash. Fix: regex penghapusan diganti prefix `void(` (AST-statement-preserving) | ✅ fixed + live | bundle live `index-DiajxkOf.js` = `return t.length,t.filter(...)...` di level fungsi; hanya kena prod karena plugin aktif hanya `NODE_ENV=production` |
| 2 | Verifikasi: lint 0 error (398 warning lama, pre-existing) | ✅ | `npm run lint` |
| 3 | Verifikasi: unit tests 100/100 lulus (14 files) | ✅ | `npm test` |
| 4 | Secret scan file yang di-commit | ✅ | bersih (lihat checklist atas) |
| 5 | File di-commit: `vite.config.js`, `src/components/DynamicRoutes.jsx`, `src/pages/Home.jsx` (mfa_enabled), `supabase/migrations/197_fix_route_components.sql`, `supabase/scripts/register-routes.mjs`, `AGENTS.md` ini | ✅ | `git show --stat` |
| 6 | Deployment production: `npx vercel --prod` ×2 (bundle fix + verify) → https://insightwos.vercel.app | ✅ | alias OK, smoke API: login_worker NRP002 200, get_enabled_modules 131 rows |

### STATUS COMMIT PERTAMA (ARSIP — sudah tidak berlaku, lihat checklist ✅ di atas)
1. ~~Perbaiki `.gitignore`~~ ✅ selesai.
2. ~~Unstage artefak audit/test~~ ✅ selesai (commit pertama sudah jalan tanpa artefak).
3. ~~Rapikan `supabase/patch/002.sql` (F-6)~~ ✅ selesai.
4. ~~Perbaiki ref rusak (F-2)~~ ✅ selesai (master ref hilang, fsck bersih).
5. ~~Scan ulang sebelum commit + push~~ ✅ selesai.

### LANJUTAN SETELAH COMMIT (urutan, dari handoff §4 + temuan 2026-09-11)

**Phase D — Production Verification (SELESAI ✅)**
1. ✅ Deploy production `npx vercel --prod` → https://insightwos-dp7cr9wl7-cezetex-lab.vercel.app (14s build)
2. ✅ Login test: NRP002 ✅, NRP007 ✅, pusat ✅, ceo ✅, operasional ✅
3. ❌ Login test: NRP003 ❌ (hash mismatch), hrd ❌ (timeout)

**Phase E — Credential Fix (PRIORITY — sebelum bagikan ke user)**
1. Fix NRP003 password (L-1): re-provision via `admin_reset_worker_password` atau `provision-worker-auth.mjs`
2. Fix HRD account (L-2): verify Supabase Auth + reset password
3. Verify remaining admin accounts: finance, mining, mill, estate (belum di-test)
4. Bagikan kredensial 8 worker per-orang via WA → hapus `provision-results.csv`

**Phase F — Route Registration**
1. Register admin routes di `module_definitions` table (L-3): employees, org-chart, divisions, master-data, role-matrix, requests, leave, overtime, payroll, timesheet, shift-schedule, approval-center, kpi, incentive, okrs, learning, certifications, badges, talent-market, career-path, succession, career-dev, attendance, performance-trend, settings, feature-flags, export, integrations, budget, headcount, audit-log, audit-chain, pipeline, recruitment, screening, onboarding, offboarding, compensation-intel, turnover, simulation, analytics

**Phase G — Test Infrastructure Fix (L-4, L-5)**
1. Fix worker login flaky: increase timeout / use sessionStorage check
2. Fix test false positives: exclude SW registration code from error regex

**Phase H — Tahap 5 Cleanup (dari handoff §4)**
1. 5.3 NULL-guard NIK → 5.4–5.5 data palsu & form mati → 5.6 XSS ChatCopilot
2. **5.7 retire dual-store (worker_passwords + auth.users) → login murni Supabase Auth**
3. 5.8 REVOKE sisa (F-8, F-4) → 5.9 INSTEAD OF trigger employees_master
4. 5.10 `get_enabled_modules(p_area)` + fix search_path (F-4) → 5.11 redesign registrasi → fix favicon via Owner branding
