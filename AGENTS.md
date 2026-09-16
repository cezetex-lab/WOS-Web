# AGENTS.md — ATURAN KERJA AGENT (WAJIB) — ONE SINGLE TRUTH

> Diperbarui besar: **2026-09-15** (restrukturisasi ONE SINGLE TRUTH + grand design).
> **File ini = ATURAN + STATE AKTIF (plan/bug OPEN) SAJA.** Riwayat/hasil yang sudah selesai
> ada di `agentsLogs.md` (ONE SINGLE TRUTH — LOG). File ini TIDAK menyimpan history.
> Update **2026-09-16**: audit `Readme/upppp.txt` di-cross-check ke kode live → hasil & sisa
> OPEN ada di **§5.6** (termasuk catatan bahwa perbaikan audit masih uncommitted/belum deploy).

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
8. **Klaim "DONE" wajib terverifikasi dulu.** Status DONE baru sah bila: perubahan sudah
   **ter-commit** (+push/deploy untuk frontend), dan gate (`tsc`/lint/build/test) **dijalankan
   ulang pada tree saat itu** dan hijau. Perubahan yang masih ada di working tree = **PARTIAL/OPEN**,
   bukan DONE. Pelajaran 2026-09-16: kerja paralel beberapa helper meninggalkan ±22 file
   uncommitted + **7 error `tsc`** (`requireNrp` dipanggil tanpa import; `React` UMD di `main.tsx`)
   padahal dokumen sudah menandainya "DONE, 0 error".

## 0.5 GOLDEN RULES (WAJIB) — KETERKAITAN 4 PAGE: worker ⇄ admin ⇄ dashboard ⇄ owner

> **PRINSIP DASAR:** insightWOS = **SATU sistem terintegrasi**, bukan 4 aplikasi terpisah.
> Halaman **Worker**, **Admin**, **Dashboard**, dan **OwnerDashboard** memakai **DB, RPC, authz,
> session, menu/route, design system, dan types yang SAMA**. Karena itu **satu perubahan di
> halaman Worker HAMPIR SELALU berdampak ke Admin, Dashboard, dan Owner** (dan sebaliknya).
> Bekerjalah SELALU dengan asumsi keterkaitan erat ini.

**Rantai dampak data (hafalkan):**
```
Worker (input: absensi, izin, lembur, produksi, dokumen)
  → Admin (approval queue, koreksi, payroll run, master karyawan)
     → Dashboard (KPI agregat, monitoring, laporan)
        → Owner (analitik lintas-BU, branding, konfigurasi global, audit)
```

1. **G1 — Default asumsi: TERDAMPAK.** Setiap koding di salah satu page, anggap 4 page lain
   terdampak sampai dibuktikan sebaliknya. Dilarang menyimpulkan "ini hanya perubahan page
   worker" tanpa mengecek Admin/Dashboard/Owner.
2. **G2 — Perbaiki di lapisan bersama, bukan hack per-page.** Solusi harus di layer bersama
   (RPC/DB, `src/lib/*`, `src/types/index.ts`, `route-config.ts`, `menu-builder.ts`,
   `design-system/*`, authz). Jangan patch lokal per-page (mis. rename/override RPC hanya di
   Worker). Perbedaan kebutuhan antar-page = parameter/role, bukan duplikasi logika.
3. **G3 — Kontrak bersama = breaking change.** Perubahan pada nama/param/return RPC,
   `module_code`/`route_path`/`route_component`, bentuk `session`/`entry`, kolom tabel
   (`employees_core` dkk), prop design-system, atau interface di `src/types` → WAJIB grep semua
   pemakai di `src/` lalu verifikasi ke-4 page.
4. **G4 — Data worker = input rantai hilir.** Mengubah bentuk/validasi data tulisan worker
   (absensi, izin, lembur, item payroll) mengubah konsumennya (approval Admin → KPI Dashboard →
   analitik Owner). Cek pembaca hilir (VIEW/MV/report/RPC) SEBELUM mengubah penulis.
5. **G5 — Isolasi role JANGAN dilemahkan.** Perbaikan lintas-page tidak boleh melonggarkan
   `RoleGuard` + cek `session.entry` + authz DB (3 layer, §7.2). Membuka akses hanya jika
   user memutuskan.
6. **G6 — Gate verifikasi lintas-page.** Bukti minimal sebelum commit untuk perubahan
   fungsional: (a) `npm run check:types` 0 error, (b) unit test hijau, (c) `npm run build`
   EXIT 0, (d) smoke putar 4 page (worker → admin → dashboard → owner), (e) E2E
   `full-sweep`/`tab-click-test`/`role-change` bila menyentuh route/menu/role.
7. **G7 — Catat dampak di log.** Entri `agentsLogs.md` wajib memuat baris
   `Dampak lintas-page: worker → admin → dashboard → owner` berisi hasil pengecekan tiap page
   (termasuk "tidak terdampak" + alasannya).

## 1. KONTEKS PROYEK (handoff)

- Aplikasi: insightWOS (WOS-Web) — HR/workforce + modul industri (mining/estate/mill).
  Migrasi Google Apps Script → Supabase.
- Frontend: React + Vite (:5173), deploy Vercel CLI (insightwos.vercel.app), repo GitHub
  `cezetex-lab/WOS-Web`, branch kerja `migrasi-vite`.
- Backend: Supabase `verwobaejumvpagwynae` (ap-northeast-1; keputusan migrasi ke
  ap-southeast-1/Singapore ada di §5.5).
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
10. Verifikasi gate sebelum commit: `npm run check:types` (0 error), `npm run lint` (0 error),
    `npm test` (unit 100/100), `npm run build` (EXIT 0), secret scan. Untuk perubahan
    fungsional, tambah smoke lintas-page (§0.5 G6).
11. **TypeScript wajib untuk SEMUA kode** (aturan keras): `src/`, `tests/`, dan file konfigurasi
    (`vite/vitest/playwright/tailwind/postcss/eslint.config.ts`) harus `.ts`/`.tsx`/`.config.ts`.
    **DILARANG membuat file `.js`/`.jsx` baru** — termasuk test/E2E spec. `tsconfig.json` memakai
    `allowJs: false`, jadi file `.js` di `src/`/`tests/`/config menggagalkan gate tipe.
    Satu-satunya pengecualian: `public/sw.js` (Service Worker — di-serve apa adanya oleh browser).
    Skrip tooling DB di `supabase/**/*.mjs` (mis. `run_171.mjs`) di luar cakupan — dijalankan
    langsung oleh Node dan dikelola terpisah.
12. **Keterkaitan 4 page adalah hukum, bukan preferensi** — setiap perubahan pada satu page
    (worker/admin/dashboard/owner) WAJIB dievaluasi & diverifikasi lintas-page (§0.5 G1–G7).

## 4. STATE OPEN — E2E Tests (Q5)

> 51/64 tests passed (13 skipped = live-backend tests yang butuh credentials).
> 6/7 items Q5 sudah ter-cover. Sisa: PWA offline mode.

- [x] Login → Dashboard load → Logout flow (`login-flow.spec.ts`)
- [x] Admin login → Payroll view → Filter by BU (`admin-payroll.spec.ts`)
- [x] Worker login → Check attendance → Request leave (`worker-attendance.spec.ts`)
- [x] Role change → Verify new permissions active immediately (`role-change.spec.ts`)
- [x] Concurrent session limit test (`concurrent-session.spec.ts`)
- [x] Dashboard rendering tests (`full-sweep.spec.ts`, `tab-click-test.spec.ts`)
- [ ] **PWA offline mode tests** (Service Worker caching) — **belum ada spec**

## 5. STATE PARTIAL — UI Forms untuk Kolom Baru Karyawan (2026-09-16)

> DB sudah lengkap (migration 215): 14 kolom baru di `employees_core` + `employees_extended`.
> **Progress 2026-09-16:** UI + RPC + migration 222 sudah dikerjakan, frontend sudah deploy.
> Sisa: verifikasi grant `authenticated` + smoke test runtime.

**Sudah dikerjakan (commit `5102f64` → push → deploy production `insightwos-3xiqo8p64` ● Ready):**
- `src/features/core/people/WorkerProfile.tsx`: 14 kolom baru masuk ke form edit + info rows + payload save
- `src/lib/supabase-rpc.ts`: typed wrapper `rpcGetWorkerProfile` + `rpcWorkerUpdateProfile`
- `supabase/migrations/222_worker_profile_rpc.sql`: `get_worker_profile` + `worker_update_profile`
- Legacy `worker_update_profile` (update `employees_master` only) di-rename ke `worker_update_profile_legacy`

Kolom yang sudah masuk UI form:
- `agama`, `media_sosial` (JSONB), `jenjang_pendidikan`
- `no_bpjs_kesehatan`, `no_bpjs_ketenagakerjaan`
- `riwayat_penyakit`, `komorbid`, `alergi`
- `nama_bank`, `no_rekening`, `nama_rekening`
- `lokasi_penempatan`, `updated_by`, `status_kerja_internal`

**Sisa OPEN:**
- [ ] Grant `EXECUTE ... TO authenticated` untuk `get_worker_profile` + `worker_update_profile` (SQL Editor)
- [ ] Smoke test runtime: login worker → WorkerProfile → edit 1 kolom → simpan → reload

## 5.5 STATE OPEN — Infrastruktur: Upstash Redis + Migrasi Region ke Singapore (keputusan 2026-09-15)

> Keputusan user (2026-09-15): **Upstash TETAP dipertahankan** (tidak dihapus), sampai nanti
> dipakai untuk caching tier (FuturePlans.md). Migrasi region: disetujui, waktunya nanti.

- [x] **Upstash Redis tetap di stack** — `@upstash/redis` (deps), edge `cache-service`, env
      `UPSTASH_REDIS_REST_URL`/`UPSTASH_REDIS_REST_TOKEN`, CSP `connect-src` tidak diubah/dihapus.
      Status sekarang: underutilized (cache-service belum pernah di-invoke dari frontend).
- [ ] **Catatan keamanan (wajib diingat saat integrasi nanti):** CSP `connect-src
      https://alive-robin-191313.upstash.io` (vercel.json) mengizinkan browser akses Redis
      LANGSUNG — ini DILARANG saat dipakai nanti. Upstash URL+token hanya boleh hidup di
      sisi server (edge function); frontend harus tetap lewat Supabase/edge, JANGAN
      client-to-Redis. Cek juga region instance `alive-robin-191313` (kalau bukan Tokyo/
      Singapore, tiap cache hit bayar RTT lintas-region).
- [ ] **Migrasi region → Singapore (ap-southeast-1), SEMUA sekaligus** (keputusan user;
      belum dijadwalkan): Supabase project `verwobaejumvpagwynae` (sekarang
      ap-northeast-1/Tokyo) + Vercel region/functions + Upstash Redis instance + env edge
      functions. Alasan: user utama Indonesia (RTT ke Tokyo ~60–100ms/RPC). CATATAN BESAR:
      bukan 1x klik — Supabase TIDAK mendukung pindah region in-place. Jalur: project baru
      ap-southeast-1 → apply 146 migrations + restore data (pg_dump/PITR) → update env
      (Vercel + `.env.local` + edge) → smoke 4 page → cutover domain. Jadwalkan di
      maintenance window; RPO/RTO §9 tetap berlaku.

## 5.6 STATE OPEN — Cross-check audit `Readme/upppp.txt` (diverifikasi ke kode live 2026-09-16)

> Sumber: `Readme/upppp.txt` (audit report pada commit `d2a4773`). SETIAP temuan di bawah
> sudah dicek ulang langsung ke kode live — bukan mengutip laporan. ✅ = sudah beres & terverifikasi;
> `[ ]` = masih OPEN (belum dikerjakan).
>
> **STATUS PROSES:** perbaikan audit 2026-09-16 (CSP, RoleGuard fail-closed, `requireNrp`) sudah
> **COMMIT `81a5bf5` → PUSH → DEPLOY production** (`insightwos-lo3gcmyg9` ● Ready, alias HTTP 200,
> CSP prod + 0 inline script terverifikasi live) — bukti lengkap di `agentsLogs.md` entri
> `[2026-09-16] Cross-check audit`. Sebelum commit, tree ini SEMPAT rusak: `tsc --noEmit` =
> **7 error** (`requireNrp` dipanggil tanpa import di 5 file + `React` UMD di `src/main.tsx`);
> sudah diperbaiki → `tsc` 0 error, lint 0 error, build EXIT 0.

### ✅ Sudah dikerjakan → DIPINDAH ke `agentsLogs.md` (aturan §0.4)

> Temuan yang sudah beres beserta bukti & commit-nya ada di entri log
> **`[2026-09-16] Cross-check audit Readme/upppp.txt`** (commit `81a5bf5`):
> S1 (`script-src` tanpa `unsafe-inline`/`unsafe-eval`, inline script → modul TS), S2 (`img-src`
> eksplisit), S3 (`connect-src` vercel/fonts dibuang), S5, S8 (RoleGuard fail-closed),
> S10 (`check_login_lockout` + `hit_rate_limit` server-side), `'NRP001'` hardcoded = 0 di `src/`,
> U4 (`DataTable` bersama ≥10 page), gate `tsc`/lint/build hijau.
> Ditambah entri log **`[2026-09-16] Sesi fail-closed`**: S6 (token app-level tidak dipersist +
> edge tidak mengembalikan password), S7/L4 (expiry wajib, fail-closed), S9 (key `wos_user_v2`,
> sesi legacy dipaksa login ulang).
> Ditambah entri log **`[2026-09-16] Kontrak rpc() jujur`**: L1 (`rpc()` mengembalikan
> `T | RpcError` dengan `kind` eksplisit + guard `isRpcError()`, 9 pemakai dimigrasikan, dan
> salinan implementasi `rpc()` di `supabase-rpc.ts` disatukan ke satu sumber kebenaran).
> Ditambah entri log **`[2026-09-16] S4 CSP Upstash + L7 provisioning warning`**: S4
> (`connect-src https://alive-robin-191313.upstash.io` dihapus dari `vercel.json`; Upstash
> infra tetap di stack per §5.5, hanya CSP browser dibersihkan), L7 (`provisionWorkerAuth()`
> gagal kini menampilkan `alert()` warning ke user di 3 call site: `finalizeWorkerSession`,
> `submitWorkerOtp`, `submitWorkerMfa`).
> Yang tersisa (masih OPEN) ada di daftar di bawah — jangan dihapus dari file ini sampai selesai.

### ✅ Sudah dikerjakan (2026-09-16) — S4 dan L7

> Commit `d45f0f9` → push → deploy production `insightwos-5fdd8rj0x` ● Ready
> (alias https://insightwos.vercel.app). tsc 0 error, lint 0 error (38 warnings pre-existing),
> build EXIT 0, 113/113 unit tests pass.
> - **S4**: `connect-src https://alive-robin-191313.upstash.io` dihapus dari `vercel.json` CSP.
>   Upstash infra tetap di stack (§5.5); hanya CSP browser dibersihkan.
> - **L7**: `provisionWorkerAuth()` gagal kini menampilkan `toast.warning()` ke user di
>   3 call site: `finalizeWorkerSession` (line ~172), `submitWorkerOtp` worker no-MFA (line ~413),
>   `submitWorkerMfa` (line ~449). Pesan: "Auth sync gagal — beberapa fitur mungkin terbatas."
>   Provisioning tetap best-effort (non-fatal); redirect login tidak diblokir.

> **P2 batch selesai (2026-09-16).** L7, U2/L5, U1, U3/U5 — semua dikerjakan + ter-commit + ter-deploy.
> Sisa: Cleanup komentar historis (Home/Kpi/Payroll/Employees/DetailPageFactory/AppDrawer) bisa P3.
> Lihat entri log `agentsLogs.md` 2026-09-16 P2 Audit Batch.

### [ ] OPEN — FuturePlans.md (temuan F1–F4)

- [ ] **F1 klaim FuturePlans sudah tidak akurat.** §1.2 bilang "tidak ada offline mode" padahal PWA
      sudah hidup (`public/sw.js`, `public/manifest.json`, `PwaUpdater`); `ai_detect_anomalies` /
      `ai_flight_risk` sudah ada di DB tapi Phase 3.1 masih ditandai belum. Perbaiki penandaannya.
- [ ] **F2 item infra belum masuk roadmap** (§8): Upstash cache tier (§5.5), migrasi region SG (§5.5),
      UI form 14 kolom karyawan (§5), PWA offline tests (§4), hardening CSP (S4/S11).
- [ ] **F3 tumpang tindih antar phase:** Shift Swap (Phase 1 vs worker needs), Payslip (Phase 1 vs
      export Xero/MYOB Phase 2), Team Dashboard 2.2 vs Dashboard/OwnerDashboard yang sudah ada,
      Push Notifications ditempatkan SETELAH item yang memprasyaratkannya.
- [ ] **F4 urutan + item obsolete.** Payroll Engine + Payslip lebih dulu (worker = hulu; output
      langsung dirasakan worker via web/PWA yang sudah ada), mobile app bukan blocker. FuturePlans
      baris 42 & 940 masih menyuruh "fix 8 functions missing search_path (migration 176)" —
      OBSOLETE (§7.6: 0 violations, pg_cron 6 jobs aktif).

---

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
| TypeScript | ✅ DONE | — | 188 file TS total (154 `src` + 28 `tests` + 6 config), 0 tsc errors — `tsconfig` mencakup `src`+`tests`+`*.config.ts`, `allowJs: false` |
| Audit 2026-09-16 | ✅ DONE (`81a5bf5`, deployed — sisa OPEN audit di §5.6) | — | Ringkasan: helper `requireNrp()`/`requireSession` di `src/lib/supabase-browser.ts` menggantikan fallback `'NRP001'` di 13 komponen; RoleGuard fail-closed (allowedRoles=0 ditolak); CSP `script-src` ditarik `unsafe-inline`/`unsafe-eval` via modul TS (error-suppressor & SW register); index.html inline script dipindah ke `src/main.tsx`; `vercel.json` CSP diperbaiki (`unsafe-eval` + `img-src https:` wildcard dibuang; entri `connect-src alive-robin` **sengaja dipertahankan** sesuai §5.5) — ⚠ file-file ini masih UNCOMMITTED; `tsc` sempat 7 error (import `requireNrp` hilang di 5 file + `React` UMD di `main.tsx`), sudah diperbaiki → tsc 0 error. COMMIT `81a5bf5` → push → deploy production `insightwos-lo3gcmyg9` ● Ready (alias HTTP 200; CSP prod + 0 inline script terverifikasi via curl); sinkronisasi `areaFromPath`/`menu-builder`; 12 file `format.ts` dibersihkan komentar histori; build EXIT 0, lint 0 error, tsc 0 error, E2E 51/51 hijau. Detail: hardcode identitas `|| 'NRP001'` dihapus dari Worker.tsx, ForumDiskusi, TrainingForm, WorkerOvertime, CompensationIntel, WorkerPayroll, WorkerProfile, ContinuousPerf, PerformanceTrend, WorkerKpi, WorkerCareer, WorkerActivities. Branding FreeBuff sudah bersih di UI aktif. Komentar histori/banner dikompaktankan (jaga RoleGuard/DynamicRoutes/vite.config). Dampak lintas-page: worker→admin→dashboard→owner — semua component identitas sekarang melalui layer bersama, tidak ada patch per-page. |

### 7.4 Database Status (Live)

| Metric | Count | Notes |
|---|---|---|
| Tables | 256 | Including 38 attendance partitions |
| Functions | 667 | 28 overloads (legacy renamed `_legacy_*`) |
| Migrations tracked | 146 | Via `schema_migrations` (migration 219); 220 terdaftar 2026-09-15 |
| RLS policies | All tables | Force-enabled, no USING(true) |
| SECDEF search_path | 0 violations | Fixed via migration 207 |
| anon/PUBLIC grants | 129 | Remaining: pgvector internals + login-flow |
| pg_cron jobs | 6 | Active: MV refresh, cleanup, OTP |
| Audit chain | 169 rows | Hash-chain live, `verify_audit_chain()` = 0 issues (migration 220) |

### 7.5 Frontend Status

| Component | Status | Notes |
|---|---|---|
| TypeScript | ✅ 156 .ts/.tsx files (132 `.tsx` + 24 `.ts`) | 0 tsc errors (re-verifikasi 2026-09-16), strict mode, `allowJs: false` |
| Unit tests | ✅ 113/113 | vitest |
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
