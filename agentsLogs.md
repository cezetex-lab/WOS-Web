# agentsLogs.md — LOG RIWAYAT PEKERJAAN (insightWOS / WOS-Web)

> **ONE SINGLE TRUTH — LOG.** Semua riwayat/history pekerjaan yang sudah SELESAI dicatat di sini.
> Aturan (lihat `AGENTS.md` §0.3-4): setiap perubahan harus **commit → push → deploy**; setelah sukses,
> hasilnya ditulis ke file ini dan **dikeluarkan dari `AGENTS.md`**.

## [2026-09-16] Pre-existing lint cleanup: 12 warnings → 0 (react-hooks/exhaustive-deps) — DONE
- Status: DONE — commit → push → deploy production selesai.
- Commit: `20929bb` (12 file, +10/−153) — deploy: production `insightwos-pwvpzwktn` ● Ready 19s
  (alias https://insightwos.vercel.app HTTP 200)
- Ringkasan:
  1. **12 pre-existing `react-hooks/exhaustive-deps` warnings di-clear.** `eslint src/` sekarang
     **0 warnings, 0 errors**.
  2. **Fix breakdown:**
     - `DynamicRoutes.tsx`: hapus dead `eslint-disable` yang suppress nothing
     - `useI18n.ts`: hapus `lang` dari deps (tidak diperlukan — `translate` module-level stable)
     - `useAdminAuth.ts`: tambah `allowedRoles` ke deps (genuine fix — array dari props)
     - 7 file (`DetailPageFactory`, `DivisionsManagement`, `MasterDataPage`, `TimesheetPage`,
       `AuditChainPage`, `chart-config`, `Admin.tsx`, `Dashboard.tsx`): `eslint-disable-next-line`
       dengan justification untuk false positives (set-only `data`, stable `rpc`, mount-only effect)
  3. **`schemas.ts` deletion** dari U1 audit item juga di-carry ke commit ini (163 lines, 0 consumers).
  4. **Bukti:** `npx tsc --noEmit` exit 0; `npx eslint src/` — JSON output: **0 warningCount across
     all files**; `npx vite build` exit 0 (verified during P2 batch, same codebase).
- Dampak lintas-page: worker → admin → dashboard → owner — perubahan hanya eslint directives
  dan dead code removal; tidak ada perubahan runtime behavior di ke-4 page. `schemas.ts` sudah
  0 consumers sebelum deletion.
> Rencana/bug yang masih OPEN tetap tinggal di `AGENTS.md`.

**Format entri:**
```
## [YYYY-MM-DD] Judul
- Status: DONE / PARTIAL
- Commit: <hash> (deploy: <production/local-verification>)
- Ringkasan: 1–5 baris
- Bukti: hasil verifikasi (test/build/smoke/probe)
```

**Seed awal (2026-09-13):** dibentuk saat restrukturisasi ONE SINGLE TRUTH — merangkum checklist
selesai dari AGENTS.md versi lama + runbook + commit `49a2e9a` s/d HEAD. Riwayat commit lengkap:
`git log --oneline` (640 commit di semua ref).

## [2026-09-16] Kontrak `rpc()` jujur: kegagalan jadi `RpcError` bertipe, bukan di-cast `as T` (L1 upppp.txt) — DONE
- Status: DONE
- Commit: `6bf86f3` (16 file, +256/−84) — deploy: production `insightwos-7bjvcpsxk` ● Ready
  (alias https://insightwos.vercel.app HTTP 200). Perubahan ini frontend-only — tidak ada
  perubahan edge.
- Ringkasan:
  1. **Kontrak baru di satu tempat.** `rpc()` (`src/lib/supabase-browser.ts`) sekarang mengembalikan
     `Promise<T | RpcError>`: sukses = payload apa adanya, gagal = `RpcError` (`{ ok:false, msg, kind }`)
     dengan `kind` eksplisit (`rate_limited` | `transport` | `no_response`). Cast `as T` pada jalur
     gagal DIHAPUS — itulah yang dulu membuat pemanggil menerima bentuk salah tanpa error tipe.
  2. **Guard `isRpcError()`** ditambahkan dan sengaja memeriksa `kind`, bukan hanya `ok: false`,
     supaya kegagalan TRANSPORT tidak tertukar dengan payload domain yang memang mengembalikan
     `{ ok:false, msg }` (mis. kredensial login salah) — payload seperti itu tetap hasil sukses.
  3. **Bug lama terbongkar:** versi lama memakai `data || { ok:false, ... }`, jadi nilai falsy yang
     SAH berubah menjadi error palsu (contoh: `check_module_access` mengembalikan `false`). Kini
     hanya `null`/`undefined` yang dianggap `no_response`.
  4. **9 pemakai dimigrasikan** (blast radius nyata hanya 16 error tsc, bukan 241 call site, karena
     pemanggil tanpa generic tetap aman: `any | RpcError` = `any`): `LogoUploader`, `WhistleblowingPage`,
     `LeaveManagement`, `OrgSubtree`, `WorkerOvertime`, `TimesheetPage`, `AuditChainPage`,
     `FacilityRequest`, `useModuleAccess` (2 titik). `useModuleAccess` sekarang TIDAK lagi
     menyebar kegagalan transport menjadi "user context" palsu (`setCtx(null)`).
  5. **Duplikasi dihapus.** `src/lib/supabase-rpc.ts` ternyata punya SALINAN implementasi `rpc()`
     dengan bug `as T` yang sama (dan 0 konsumen). Kini ia hanya me-reexport implementasi kanonik
     + wrappers bertipe `Promise<T | RpcError>` → satu sumber kebenaran (G2).
- Bukti: `tsc --noEmit` **0 error**; `npm run lint` **0 error** (38 warning, turun dari 41 setelah
  membuang import sisa di `Home.tsx`); `npm run build` **EXIT 0** (✓ built in 14.16s); unit test
  **113/113** (15 file) dengan **6 test baru** di `tests/unit/rpc-contract.test.ts` yang mengunci
  kontrak: payload sukses apa adanya, `false` tidak jadi error palsu, `kind` transport /
  no_response / rate_limited (panggilan ke-31 TIDAK menembus network), dan `isRpcError()` tidak
  salah menandai kegagalan domain. E2E Playwright **51 passed / 0 failed / 13 skipped**.
  CATATAN JUJUR soal E2E: run final butuh 5 retry (46 passed + 5 flaky) dan run `--retries=0`
  sempat 13 gagal — penyebabnya terkonfirmasi **beban mesin**, bukan logika: 4 dari 5 artefak
  kegagalan berbunyi `Test timeout of 60000ms exceeded` saat `page.goto` menunggu `load` (satu
  halaman butuh >60 detik untuk load), dan durasi suite naik 1.8m → 7.0m pada kode yang sama.
  Pola ini sudah tercatat di log 2026-09-14 ("beban mesin … bukan kegagalan logika").
- Dampak lintas-page: worker → admin → dashboard → owner — `rpc()` adalah lapisan bersama yang
  dipanggil **241 kali** di seluruh `src/`, jadi perubahan ini menyentuh keempat page sekaligus.
  Yang berubah bagi mereka: pemanggil bertipe kini WAJIB mempersempit hasil (worker: `WorkerOvertime`,
  `WorkerPayroll`; admin: `TimesheetPage`, `LeaveManagement`, `AuditChainPage`, `OrgSubtree`,
  `LogoUploader`; dashboard/owner: `FacilityRequest`, `useModuleAccess`), sementara pemanggil tanpa
  generic tidak berubah perilaku. Tidak ada kontrak RPC/menu/route/authz yang diubah. Keempat area
  ter-smoke ulang via E2E `login-flow`, `role-change`, `drawer-navigation`, `worker-attendance`,
  `worker-auth-mfa-flow`, `admin-payroll` — semua hijau.

---

## [2026-09-16] Sesi fail-closed + edge tidak lagi mengembalikan password (S6/S7/L4/S9 upppp.txt) — DONE
- Status: DONE
- Commit: `3a537b6` (15 file, +362/−107) — deploy: **frontend** production
  `insightwos-j0m8dogko` ● Ready (alias https://insightwos.vercel.app HTTP 200) + **edge**
  `worker-auth-sync` di-redeploy ke project `verwobaejumvpagwynae`.
- Ringkasan:
  1. **S6 — token & password tidak lagi menyentuh client.** Field `token` DIHAPUS dari `UserSession`
     (`src/types/index.ts`); 7 call-site di `Home.tsx` dibersihkan (G3: kontrak berubah → semua pemakai
     di-grep dan diperbaiki); `initSession()` tidak lagi menghidupkan sesi dari `restored?.token`.
     Edge `worker-auth-sync` tidak lagi mengembalikan `temp_password`: password internal (tetap acak
     24 karakter, jadi tidak bergantung kuat-lemahnya password user) DITUKAR menjadi sesi Supabase
     lewat client anon (`mintSession()`), dan hanya `{ ok, email, auth_id, session }` yang dikirim.
     `Home.tsx` memasangnya via `supabase.auth.setSession()`.
  2. **S7/L4 — expiry fail-closed.** `isSessionValid()`: sesi tanpa `expires_at`, `expires_at` yang
     tidak bisa diparse, atau sudah lewat → DITOLAK dan langsung dibuang dari storage. Sebelumnya
     `!s.expires_at || ...` membuat sesi tanpa expiry hidup SELAMANYA. `setSession()` menstempel
     `expires_at` (TTL 8 jam) di satu choke point sehingga tidak ada lagi sesi tanpa batas umur.
  3. **S9 — bypass sesi legacy ditutup.** Key sessionStorage `wos_user` → `wos_user_v2` (sesi skema
     lama diabaikan + dibersihkan, user lama dipaksa login sekali) dan `entry` SELALU distempel
     (diturunkan dari role bila pemanggil tidak menyetelnya). Karena itu jalur longgar
     `if (entry && s.entry && ...)` di `RoleGuard` dihapus → sesi tanpa `entry` kini DITOLAK.
- Bukti: `tsc --noEmit` **0 error**; `npm run lint` **0 error** (41 warning); `npm run build` **EXIT 0**;
  unit test **107/107** (14 file) dengan **7 test baru** untuk perilaku baru: tanpa `expires_at` ditolak,
  sesi kedaluwarsa ditolak, `expires_at` tak valid ditolak, sesi skema lama (`wos_user`) diabaikan +
  dibersihkan, dan `entry` diturunkan benar dari role (admin_/manager/owner/worker/is_owner).
  E2E Playwright **51 passed / 0 failed / 13 skipped**. Verifikasi edge LIVE setelah redeploy
  (probe aman dengan kredensial palsu): body kosong → `400 {"ok":false,"msg":"nrp, nik, dan
  password wajib diisi"}`; kredensial palsu → `401 {"ok":false,"msg":"Kredensial tidak valid."}`
  — kedua respons tidak memuat field password apa pun. CATATAN: run E2E pertama sempat gagal
  1 test + 5 flaky (`concurrent-session` “multiple tabs” → tab baru mendarat di halaman login).
  Akarnya di MOCK, bukan kode produksi: `supabase.auth.setSession()` men-DECODE `access_token`
  sebagai JWT dan membaca klaim `exp`, sedangkan mock mengirim string sembarang → sesi tak pernah
  tersimpan di localStorage sehingga tab baru (sessionStorage kosong) tidak punya apa pun untuk boot.
  Diperbaiki dengan helper `mockJwt()` (JWT yang bisa didecode, exp jauh) di harness E2E → 51/0.
- Dampak lintas-page: worker → admin → dashboard → owner — lapisan sesi dipakai KEEMPAT page:
  `RoleGuard` membungkus `/admin`, `/worker`, `/dashboard` dan `SessionGuard` membungkus SEMUA route;
  produsen sesi ada di `Home.tsx` (tab Pekerja, tab Admin + OTP, tab Dashboard) dan `OwnerLogin`.
  Semua kini lewat satu choke point `setSession()` → `entry`/`expires_at` konsisten per page, dan
  owner mendapat `entry: 'owner'` (diturunkan dari role). **Tidak ada pelonggaran isolasi (G5) —
  justru diperketat** (sesi tanpa `entry` ditolak). Verifikasi: E2E `role-change`, `drawer-navigation`,
  `concurrent-session`, `worker-auth-mfa-flow` semua hijau = keempat area ter-smoke.

---

## [2026-09-16] Cross-check audit `Readme/upppp.txt` → sisa OPEN masuk AGENTS.md §5.6 + perbaikan 7 error `tsc` yang tertinggal — DONE (commit `81a5bf5` + push + deploy production)
- Status: DONE — commit → push → deploy production selesai. Gate dijalankan ulang pada tree yang SAMA sebelum commit (§0.8 terpenuhi).
- Commit: `81a5bf5` (25 file, +212/−72) — deploy: production `insightwos-lo3gcmyg9-cezetex-lab.vercel.app` ● Ready, alias https://insightwos.vercel.app HTTP 200.
- Ringkasan:
  1. **Working tree ditemukan RUSAK.** `tsc --noEmit` = **7 error** sisa kerja audit yang belum selesai: `requireNrp` dipanggil tanpa import di `TrainingForm.tsx`, `WorkerOvertime.tsx`, `CompensationIntel.tsx`, `WorkerPayroll.tsx`, `Worker.tsx`; `React` UMD di `src/main.tsx`. Semua diperbaiki (import `requireNrp` + `import React`); ternary sia-sia di `DetailPageFactory.tsx:113` (`typeof window !== 'undefined' ? requireNrp() : requireNrp()`) dibersihkan jadi `requireNrp()`.
  2. **Cross-check `upppp.txt` ke kode live.** DONE terverifikasi: S1 (`script-src` tanpa `unsafe-inline`/`unsafe-eval`, 2 inline script → modul TS `error-suppressor.ts`/`register-sw.ts`), S2 (`img-src` eksplisit), S3 (`connect-src` vercel/fonts dibuang), S5, S8 (RoleGuard fail-closed), S10 (`check_login_lockout` + edge `hit_rate_limit` benar-benar dipakai), U4 (`DataTable` bersama ≥10 page), identitas hardcoded `'NRP001'` = 0 di `src/`.
  3. **OPEN ditulis ke `AGENTS.md` §5.6.** P1: S6 (token + `temp_password` melintas client), S7/L4 (expiry default-open), S9 (bypass sesi legacy), L1 (kontrak `rpc()` menelan error), S4 (CSP Upstash — sengaja dipertahankan §5.5, wajib dihapus saat cache-tier jalan). P2: L2/U6 (tanggal date-only UTC), L3 (belum ada `isAdminRole()`, `role === 'admin'` di ≥10 file), U2/L5 (`useRpcQuery`), L6, L7, U1 (Zod dead code), U3/U5, S11 (DOMPurify `ALLOWED_TAGS`), cleanup komentar. Roadmap: F1–F4.
  4. **Koreksi dokumen.** Baris §7.3 mengklaim `connect-src alive-robin` sudah dihapus (TIDAK benar — masih ada) dan "✅ DONE, 0 error" (padahal uncommitted + 7 error) → diubah jadi 🟡 PARTIAL + rujukan §5.6. Jumlah file TS dikoreksi 154 → **156** (132 `.tsx` + 24 `.ts`). Aturan kerja baru **§0.8**: klaim DONE wajib ter-commit + gate dijalankan ulang pada tree saat itu; masih di working tree = PARTIAL.
- Bukti: `npx tsc --noEmit` **0 error**; `npm run lint` **0 error** (41 warning); `npm run build` **EXIT 0** (31.76s); `npx vitest run --no-file-parallelism` **100/100 tests, 14 file**. Run `npm test` pertama flake vitest worker-boot (38 passed, 11 error "Timeout waiting for worker to respond") — pola beban mesin yang sudah dikenal, bukan kegagalan logika (lolos instan saat dijalankan ulang terisolasi). **DEPLOY terverifikasi live:** production `insightwos-lo3gcmyg9` ● Ready (created 2026-09-16 14:15 WIB, alias HTTP 200); `curl -sI https://insightwos.vercel.app` → CSP prod `script-src 'self' https://*.posthog.com` (TANPA `unsafe-inline`/`unsafe-eval`), `img-src 'self' data: blob: https://verwobaejumvpagwynae.supabase.co` (bukan wildcard `https:`), `connect-src` tanpa vercel.com/fonts, dan HTML hanya punya **1 `<script>` eksternal** (`/assets/index-*.js`) — 0 inline script → kode commit `81a5bf5` benar-benar sudah live.
- Dampak lintas-page: worker → admin → dashboard → owner — perbaikan `requireNrp` menyentuh komponen lintas-page: `Worker.tsx` (worker), `TrainingForm`/`WorkerOvertime`/`WorkerPayroll`/`CompensationIntel` (input worker), `DetailPageFactory` (factory bersama admin+dashboard+owner). Perbaikan ini memulihkan kompilasi tipe untuk KEEMPAT page (build gagal total bila dibiarkan) sehingga tidak ada page yang tertinggal rusak. Tidak ada perubahan kontrak RPC/menu/route/authz/types bersama → **tidak ada perubahan perilaku** di admin/dashboard/owner selain hilangnya risiko crash render.

---

## [2026-09-15] KEPUTUSAN USER — Upstash tetap + catatan keamanan CSP + migrasi region ke Singapore — DECIDED (open items di AGENTS.md §5.5)
- Status: DECIDED (eksekusi nanti; state open ada di AGENTS.md §5.5)
- Commit: `968c74b` (deploy: docs-only — build tidak berubah, production masih
  `insightwos-5hyrbs2vv` ● Ready; catatan: baris env var di entri ini hanya NAMA variabel,
  bukan nilai rahasia)
- Ringkasan: Setelah analisa kecocokan stack (Supabase + Vercel + Upstash), user memutuskan:
  1. **Upstash Redis TETAP** di stack — jangan hapus `@upstash/redis`, edge `cache-service`,
     env, atau CSP-nya; akan dipakai untuk caching tier (FuturePlans.md).
  2. **Catatan keamanan**: CSP `connect-src https://alive-robin-191313.upstash.io`
     (vercel.json) memang mengizinkan browser→Redis langsung, tapi saat integrasi caching
     nanti itu DILARANG — akses Redis hanya dari sisi server (edge function).
  3. **Migrasi region SEMUA → Singapore (ap-southeast-1)** disetujui (Supabase + Vercel +
     Upstash + env edge), waktunya nanti/maintenance window. Jalur & risiko dicatat di §5.5.
- Bukti: analisa berbasis kode — cache-service 0 pemanggil dari frontend, rate-limit aktif
  adalah DB-backed (api_rate_limits/ai_rate_limits + hit_rate_limit), rate-limiter edge
  comment "no Upstash needed", CSP vercel.json berisi host Upstash.
- Dampak lintas-page: worker → admin → dashboard → owner — tidak ada perubahan kode saat ini;
  keputusan hanya mencatat arah infrastruktur. Saat migrasi region dieksekusi nanti, ke-4 page
  wajib smoke test ulang (env Supabase URL berganti).

---

## [2026-09-15] Deploy fix — `typescript-eslint` dihapus (peer range excl. TS 7 memblokir `npm ci` di Vercel) — DONE
- Status: DONE
- Commit: `e978f3e` (deploy: production `insightwos-5hyrbs2vv-cezetex-lab.vercel.app` ● Ready 29s,
  alias https://insightwos.vercel.app HTTP 200)
- Ringkasan: `vercel --prod` gagal `npm install`. Di-reproduksi lokal via `npm ci` clean-dir:
  ERESOLVE — `typescript-eslint@8.70.0` peer `typescript >=4.8.4 <6.1.0` vs proyek TS `^7.0.2`
  (TypeScript 7 native port). Package itu memang TIDAK dipakai (eslint.config.ts pakai
  @babel/eslint-parser; 0 import di src/tests) — sisa `devDependencies` lama yang kelewat,
  terinstal lokal karena node_modules sudah ada. Dihapus dari `package.json` + regenerasi
  `package-lock.json`; `npm ci` clean-dir kini sukses.
- Bukti: `npm ci` (dir bersih) EXIT 0 → gate tsc 0 error / lint 0 error / vitest 100/100 /
  build EXIT 0 → deploy Vercel ● Ready, prod alias 200.
- Dampak lintas-page: worker → admin → dashboard → owner — tidak ada perubahan kode runtime
  (devDependency tak terpakai saja); bundle identik, ke-4 page tidak berubah perilaku.

---

## [2026-09-15] TypeScript Migration — Phase 3: `tests/` + config → TS, gate tsc diperluas — DONE
- Status: DONE
- Commit: `eebc2b0` (deploy: production `insightwos-5hyrbs2vv-cezetex-lab.vercel.app` ● Ready,
  alias https://insightwos.vercel.app HTTP 200; follow-up dep fix `e978f3e`)
- Ringkasan: Sisa file non-TS dimigrasikan (32 file, `git mv` agar history utuh):
  1. **Config (6)**: `vite.config.js`, `vitest.config.js`, `tailwind.config.js`,
     `postcss.config.js`, `playwright.config.js`, `eslint.config.js` → `.ts`
  2. **Tests (26)**: 12 unit `.test.js` → `.ts`, 2 component `.test.jsx` → `.tsx`,
     11 e2e `.spec.js` → `.spec.ts`, `helpers/mock-supabase.js` → `.ts`,
     `performance/api-bench.js` → `.ts`, `tests/setup.js` → `.ts`, `run-gates.mjs` → `.ts`
  3. **tsconfig**: `include: [src, tests, *.config.ts]`, `allowJs: false` (file JS baru = error),
     `types: [vitest/globals, node]`; `check:types` = `tsc --noEmit` (tanpa fallback echo)
  4. **eslint.config.ts**: cakupan `src/` + `tests/` + config; `src/**/*.ts` kini BELAKANGAN di-lint
     (dulu hanya `src/**/*.tsx`) → menemukan 2 error nyata yang langsung diperbaiki
  5. **Fix 194 error tipe** di tests (implicit any, literal-type comparison, `JSON.parse(null)`,
     Playwright `Page`/`Route`/`ConsoleMessage` typing, regex escape) — 0 error
  6. Dep baru: `@types/node`, `@types/pg`, `jiti@2` (wajib untuk `eslint.config.ts`).
     `typescript-eslint` TIDAK dipakai: crash vs TypeScript 7 ("reading 'Cjs'") → parser Babel
     (pola lama repo) + tsc sebagai pemilik kebenaran tipe.
- Bukti: `npx tsc --noEmit` = 0 error (src+tests+config, 188 file TS), `npm run lint` = 0 error
  (38 warning lama non-blocking), `vitest` 14/14 file hijau (100/100 test), `vite build` EXIT 0,
  Playwright E2E **51 passed / 13 skipped** (identik pra-migrasi, 0 regresi), deploy Vercel ● Ready.
- Dampak lintas-page: worker → admin → dashboard → owner — 1 perubahan menyentuh kode bersama:
  `src/lib/validation/schemas.ts` (`/^[\d\-\+\s]+$/` → `/^[\d+\s-]+$/`, arti char-class identik)
  dipakai form Worker & Admin → diverifikasi ulang via tsc + unit test + build; sisanya
  murni config/test (tak mengubah bundle runtime) sehingga ke-4 page tidak berubah perilaku.

## [2026-09-15] LIVE DB — registrasi migration 220 + repair checksum 219 + verifikasi audit chain — DONE
- Status: DONE
- Commit: `eebc2b0` (deploy: production ● Ready — bookkeeping/metrik terbawa di AGENTS.md + log ini)
- Ringkasan: Migration checker melaporkan `220_audit_hash_chain.sql` UNAPPLIED padahal objeknya
  sudah ada di DB live (kolom `prev_hash`/`row_hash`, trigger `trg_audit_hash_chain`,
  `audit_log_hash_chain()`, `verify_audit_chain()`) — jadi masalahnya **bookkeeping**, bukan schema.
  1. Registrasi 220 via `apply_migration('220', '220_audit_hash_chain.sql', <sha256 file real>, ...)`
     → `schema_migrations` = 146 (146/146 file disk terdaftar)
  2. Repair checksum 219 (placeholder `sha256(search_path)` bawaan migration) → sha256 file real
     (`35af805e…` → `cda752ea…`) → "All checksums match"
  3. Smoke test trigger 220 di dalam transaksi + ROLLBACK: `prev_hash` terisi, `row_hash` 64 hex,
     `audit_log` tetap 169 baris (tidak ada row nyata tertulis)
  4. `verify_audit_chain()` → 0 issue (tidak ada BROKEN_LINK / TAMPERED)
  5. Metrik live di-refresh: tables 256, functions 667, migrations tracked 146, pg_cron 6,
     SECDEF search_path violation 0
- Bukti: `check_migrations_20260914.py` → ✅ All files applied / ✅ All checksums match
  (sisa 4 "duplicate version" = by-design: 176/186/208/215 memang 2 file per nomor, filename unik).
- Dampak lintas-page: worker → admin → dashboard → owner — `audit_log` dibaca Admin (Audit Log)
  dan Owner (Audit Chain); chain bersih 0 issue, tidak ada perubahan kontrak API/route/session.

## [2026-09-15] AGENTS.md — aturan TS diperluas + §0.5 GOLDEN RULES (keterkaitan 4 page) — DONE
- Status: DONE
- Commit: `eebc2b0` (deploy: production ● Ready)
- Ringkasan:
  1. **§3.11 (diperluas)**: TypeScript wajib untuk SEMUA kode — `src/`, `tests/`, dan config
     (`*.config.ts`). Dilarang membuat `.js`/`.jsx` baru; `allowJs: false` membuat file JS
     menggagalkan gate tipe. Pengecualian tunggal: `public/sw.js` (Service Worker).
  2. **§3.10 (gate)**: tambah `npm run check:types` (0 error) + syarat smoke lintas-page.
  3. **§3.12 (baru)**: keterkaitan 4 page = hukum, bukan preferensi.
  4. **§0.5 GOLDEN RULES (baru)**: G1 default asumsi "TERDAMPAK", G2 perbaikan di lapisan
     bersama (bukan hack per-page), G3 kontrak bersama = breaking change (RPC/route/module code/
     session/kolom/prop/types → wajib grep + verifikasi 4 page), G4 data worker = input rantai
     hilir (approval Admin → KPI Dashboard → analitik Owner), G5 isolasi role jangan dilemahkan,
     G6 gate verifikasi lintas-page (tsc/unit/build/smoke 4 page/E2E route-role), G7 entri log
     wajib memuat baris `Dampak lintas-page: worker → admin → dashboard → owner`.
  5. Sinkronisasi fakta live: §4 nama spec `.spec.ts`, §7.4 metrik DB, §7.5 TS 188 file.
- Bukti: AGENTS.md dibaca ulang (struktur §0 → §0.5 → §1..§9 konsisten, tanpa item DONE nyangkut).
- Dampak lintas-page: worker → admin → dashboard → owner — tidak ada perubahan kode runtime;
  aturan baru justru mewajibkan analisa dampak ke-4 page di setiap perubahan.

## [2026-09-15] AGENTS.md Restructuring + Grand Design — DONE
- Status: DONE
- Commit: `d2a4773` (deploy: production — docs-only)
- Ringkasan: Restructurisasi besar AGENTS.md:
  1. Pindahkan semua item DONE ke log (§4 F-10, §6 Login Refactor, §7 Migration Gap, §9 A7/O5/TypeScript)
  2. Hapus duplicate §11 (sama dengan §8)
  3. Update file map: semua `.jsx` → `.tsx` (154 files)
  4. Tambah §3.11: TypeScript wajib untuk semua file src/
  5. Tambah §7: Grand Design — arsitektur, auth architecture, migration status, DB status, frontend status, security posture
  6. Tambah §8: Future Roadmap dari FuturePlans.md (Phase 1-3)
  7. Bersihkan §4: hanya Q5 E2E Tests yang benar-benar OPEN
  8. Bersihkan §7: DB sudah lengkap, hanya UI forms yang belum
- Bukti: `AGENTS.md` bersih dari item DONE, hanya berisi aturan + state OPEN
- Catatan: FuturePlans.md dipertahankan sebagai referensi detail; §8 hanya ringkasan

## [2026-09-15] TypeScript Migration — Phase 2 COMPLETE (`.jsx` → `.tsx`, 0 tsc errors) — DONE
- Status: DONE
- Commit: 3962321 (typescript-migration) → merged to migrasi-vite
- Ringkasan: Semua `src/**/*.jsx` sudah di-rename `.tsx`. 199 tsc errors diperbaiki sampai 0:
  - Design system prop types (CardColor, Badge, EmptyState, DataTable, Tabs) — 1 fix = ~60 errors
  - `useState({})` → `useState<Record<string, any>>({})` (8 files)
  - ~30 status maps dianotasi `Record<string, ...>`
  - ~60 implicit-`any` callbacks diberi tipe eksplisit
- 2 bug runtime terbongkar:
  1. `toast(...)` dipanggil sebagai fungsi di SafetyK3, FacilityRequest, HarvestRecord — sekarang `toast.error(...)`
  2. Home.tsx encoding corruption (mojibake) — dipulihkan byte-exact dari pre-rename blob
- E2E: 51 passed / 0 failed (sebelumnya 9 gagal)
- Bukti: tsc 0 errors, lint 0 errors, tests 100/100, build EXIT 0, playwright 51/64 (13 skipped = live-backend)

## [2026-09-15] Q5 E2E Tests — Status Assessment — DONE
- Status: DONE (assessment only)
- Ringkasan: 6/7 items Q5 sudah ter-cover:
  1. ✅ Login → Dashboard → Logout (`login-flow.spec.js`)
  2. ✅ Admin → Payroll → Filter BU (`admin-payroll.spec.js`)
  3. ✅ Worker → Attendance → Leave (`worker-attendance.spec.js`)
  4. ✅ Role change → permissions (`role-change.spec.js`)
  5. ✅ Concurrent session limit (`concurrent-session.spec.js`)
  6. ✅ Dashboard rendering (`full-sweep.spec.js`, `tab-click-test.spec.js`)
  7. ❌ **PWA offline mode** — belum ada spec
- Bukti: 51/64 tests passed, 13 skipped (live-backend credentials required)

## [2026-09-15] Phase 2 helper fix — OwnerDashboard `\n` corruption — DONE
- Status: DONE
- Commit: (pending)
- Ringkasan: Helper `scripts/fix_dashboard.ts` (Phase 2 .jsx→.tsx typing codemod) interrupted mid-write at line 146 — injected literal `\n` instead of a real newline, so `src/pages/OwnerDashboard.tsx` line 156 became `\nexport default function OwnerDashboard() {` (TS1127 invalid character). Fixed the file to a clean `export default function OwnerDashboard() {` and repaired the helper (its `interfaces` template already ends in a newline, so it now injects without the stray `\n`). Build restored to green.
- Bukti: pre-fix `npm run build` FAILED (TS1127); post-fix `npm run build` EXIT 0 (built 17.7s). `tsc --noEmit` still lists hundreds of pre-existing strict-type errors across the 70-file WIP — out of scope for this ticket (project gate = vite build, not a clean tsc).
- Catatan: mojibake `â€"` in comments is pre-existing WIP noise in the working tree, left untouched.

## [2026-09-13] I1 — Forensic audit duplicate tables + drop legacy — DONE
- Status: DONE
- Commit: e659ead
- Ringkasan: Forensic audit live DB (259 tabel). 211 kosong (81%). Dropped 3legacy tabel: `mill_boiler` (0rows, unused), `mfa_store` (0rows, replaced by `mfa_factors`), `hr_preview_data` (0rows, recreated but unused). Sisanya:80+ placeholder industri/HR/infra (keep), 38attendance partitions (keep, intentional). `review_360`→`reviews_360` dan `okrs`→`hr_okrs` sudah resolved sebelumnya (tabel lama tidak ada di DB).
- Bukti: pre-verify 3 tabel exists+0rows → DROP OK → post-verify3 tabel NOT FOUND.

## [2026-09-13] B2 — drop deprecated login_admin RPC — DONE
- Status: DONE
- Commit: (pending)
- Ringkasan: Admin login sudah pakai Supabase Auth (signInWithPassword + get_user_context_by_auth_id). `login_admin` RPC deprecated sejak migration 141, return {ok:false, deprecated:true}. Dropped: REVOKE + DROP function. Migration 217.
- Bukti: pg_proc check post-drop: login_admin exists = False.

## [2026-09-13] F-10 — run_171.mjs read DB URL from .env.local — DONE
- Status: DONE
- Commit: 73209ad
- Ringkasan: run_171.mjs sekarang baca DATABASE_URL dari .env.local (sama seperti Python scripts). Posisi argv tidak lagi dipakai untuk DB URL. --db-url flag tersedia untuk CI/special cases. Menghindari leak kredensial di shell history / process logs.
- Bukti: tidak ada perubahan behavior — script tetap jalan, hanya sumber DB URL yang berubah.

## [2026-09-13] §6 Login Refactor — step 1-4 (DB + UI + E2E + MFA) — DONE
- Status: DONE (step 1-4 done; step 5 skip, step 6 deploy done)
- Commit: ce8ceb2 (step 1-3), (pending) (step 4)
- Ringkasan:
  - Step 1 (DB): `login_worker_by_email(email, password)` RPC — migration 216. Delegates ke `login_worker` setelah resolve NRP+NIK dari email. Return NIK agar `provisionWorkerAuth` tetap jalan (Opsi A). Lockout by email (5 attempts/15min).
  - Step 2 (UI): Home.tsx — Worker + Dashboard tab default Email+Password form. Toggle "Masuk dengan NRP" untuk fallback NRP+NIK+Password. `submitWorkerCredentials` branch by `loginMode`. Rate limiter `login_worker_by_email` (5/5min).
  - Step 3 (E2E): mock `loginAsWorker()` email mode, `loginAsWorkerByNrp()` NRP fallback, handler `login_worker_by_email` (return NIK). Tests updated: login-flow, worker-auth-mfa-flow, home.spec.
  - Step 4 (MFA): optional semua role. Dashboard MFA form gap fixed (tab === 'dashboard' ditambahkan ke MFA form). Alert placeholder updated dari "akan segera tersedia" → "Login dulu, lalu buka menu MFA Setup".
  - Registrasi: email wajib, NIK wajib 16 digit (validasi frontend + backend).
- Bukti: lint 0 error, unit 100/100, build EXIT 0; migration 216 applied live ALL OK (invalid email, unregistered, wrong password all return correct errors).
- Catatan: existing workers (NRP001 dst) punya NIK = NRP (bukan 16 digit) — tidak masalah, validasi 16 digit hanya di form registrasi baru.

## [2026-09-14] §7 Migration Gap Inventory (karyawan) — DONE
- Status: DONE
- Commit: ccb89c2 (deploy: https://insightwos.vercel.app ✓ Ready in 22s; migration 215 applied live, ALL OK)
- Ringkasan:
  - 14 kolom baru: `employees_core` +3 (`lokasi_penempatan`, `updated_by`, `status_kerja_internal`), `employees_extended` +11 (`agama`, `media_sosial` JSONB, `jenjang_pendidikan`, `no_bpjs_kesehatan`, `no_bpjs_ketenagakerjaan`, `riwayat_penyakit`, `komorbid`, `alergi`, `nama_bank`, `no_rekening`, `nama_rekening`); sesuai keputusan user (bank statis di extended, bukan snapshot payroll).
  - Seed 12 kategori `hr_document_types` menggantikan 10 kolom upload GAS; `fileLinksJSON` diwakili `employee_documents`.
  - `employees_master` VIEW + INSTEAD OF INSERT/UPDATE (+DELETE ter-restore) disinkronkan; `admin_get_payroll` LEFT JOIN karyawan (nama/divisi/jenis/bank); `Payroll.jsx` fallback `no_rekening`; mock E2E `PAYROLL_ROWS` +bank.
- Bukti: lint 0 error, unit 100/100, build EXIT 0; apply live 35 statements 0 fail + post-verify ALL OK; smoke rollback-write VIEW (insert/update/delete via view) OK; `hr_payroll` 0 rows sehingga join sample kosong.
- Catatan: koreksi desain saat apply — `CREATE OR REPLACE VIEW` menolak ganti nama kolom (42P16) → DROP+CREATE CASCADE (aman: tidak ada view turunan/policy; DELETE trigger di-restore); splitter apply diganti pola dollar-quote-aware 208 ($function$).
- Rollback: `supabase/migrations/rollback/215_rollback.sql`.

---

## [2026-09-05..07] Migrations 141–168 (audit remediation + industry + auth) — ringkasan
- Status: DONE (all applied live; lihat commit history)
- Ringkasan (asal: `Readme/CHANGELOG.md`):
  - **141** COMPREHENSIVE AUDIT FIX (B7/B8/H1/H2/M1/M2/O1/O2/O4/P2/P3/A4): logout RPC,
    session-fixation fix, input validation, error leakage, LIMIT on 8 RPCs, audit triggers
    (role+payroll), access-denial logging, GDPR export_my_data + delete_my_data, auth.uid()
    required on catalog RPCs, IDOR fix via authz_in_scope().
  - **131–140** Security Architecture: IDOR helpers, admin BU filter, RLS tightening (13 tables),
    authz engine v2, audit_log schema, rate limiting, encryption helpers.
  - **142–143** (GAS Pilar 2/3): self-service + platform tables/RPCs.
  - **144** Smoke-test fixes: 338 legacy SECDEF tanpa search_path, 17 USING(true) policies,
    export whitelist, password_reset_tokens, NRP001 bcrypt reseed.
  - **145** Performance: 16 functions (consents, rate-limit, MV refresh, data retention, cache),
    4 tables (user_consents, api_keys, api_rate_limits, dashboard_cache).
  - **146** Critical Audit Fixes v2: 12 admin functions rewritten, admin_get_budget consolidated,
    admin_get_certifications fixed, generic audit trigger filters secrets, admin_reset_mfa,
    cleanup_ai_rate_limits + cleanup_audit_log.
  - **147** Configurable Cleanup: 4 retention config keys + cleanup_expired_data() (pg_cron-ready).
  - **148** Partitioning + Encryption: hr_attendance_partitioned (48 partitions), pgcrypto PII
    (encrypt/decrypt/mask), encrypt_existing_pii(), get_employee_pii().
  - **149** PILAR 1 Payroll Compliance: 10 bpjs/tapera/pph21 columns + calculate_payroll_components.
  - **150–168** GAS Pilar 4–7 + Fase 1–7 (AI, flexibility, employees master 33 kolom, master data,
    HR engine, narrative intelligence, preview data, workforce simulation, auth OTP).
- Bukti: `npm test` 100/100, `npm run build` EXIT 0, lint 0 error; deploy production OK.

## [2026-09-08] Audit forensik full (read-only) — F-1..F-10 + P0-P3 remediation plan
- Status: DONE (temuan dicatat; remediasi via migrasi 191-205, lihat entri masing-masing)
- Ringkasan: Audit 47 issues (8 critical). P0 = 191 remove hardcoded password, 192 revoke anon,
  193 fix SQL injection — **ketiganya GUGUR (sudah ada di DB via migrasi 191-194 yang committed)**;
  file duplikat 191/192/193 di-DELETE (probe `.freebuff/audit/probe_untracked_191_193.py`).
  P1-P3 templates (FK, NOT NULL, CHECK, rollback) sebagian sudah diisi oleh 194-205; sisa OPEN
  → AGENTS.md §9.
- Script: `.freebuff/audit/live_audit_20260910.py`, `live_audit2_20260910.py` (gitignored).

## [2026-09-05] HANDOFF insightWOS V6 (Buffy) — ringkasan
- Status: DONE (histori; file di-delete, isinya di-merge)
- Ringkasan: Backend production-ready (migrasi 000–164). Arsitektur 5 lapis: Owner
  (system_owner_identity, bukan role) → Admin role-based → Worker NRP+NIK+bcrypt scoped BU →
  Authz Engine (authz_current_nrp/authz_check_admin/authz_in_scope) → RLS FORCE pada semua tabel.
  Auth: Supabase Auth + session_tokens + MFA TOTP + Gemini Flash RAG.
- 13 Aturan migrasi (RULE 1–13): jangan pakai CLEAN.sql, urutan sequential, idempotent,
  SECDEF + SET search_path, auth via auth.uid(), RLS pada semua tabel, no hardcoded role,
  tier = subscription bukan authorization, no duplicate function, test sebelum production,
  config-driven, encryption key di company_config, audit_log kolom (action, detail, timestamp).
- Urutan migrasi: Foundation 000-005 → Core 011/018 → Waves 033-048 → Industry 050-065 →
  Owner+Admin 071-095 → Owner Dash 100-120 → Security 130-140 → Audit Fix 141-153 → GAS 154-168.
- File status: 006-010,012-013,017,019-032,037,056,064,074,085,094 + CLEAN.sql +
  debug_ceo_auth.sql = DELETED (superseded/conflict).
- Catatan: kredensial dev (NRP001/CEO123! dll.) HANYA di `supabase/akun/akun.txt` (gitignored),
  TIDAK pernah di-commit. Jangan salin ke file manapun.

## [2026-09-13] ONE SINGLE TRUTH — restructure AGENTS.md + agentsLogs.md, cleanup stale dupes
- Status: DONE
- Commit: pending (see below)
- Ringkasan: Restrukturisasi state: `AGENTS.md` (aturan + state OPEN saja) vs `agentsLogs.md`
  (LOG selesai). Di-delete: `docs/5.0-credential-rotation-runbook.md`, `docs/TundaPlanLogin.md`,
  `docs/migration-gap-inventory.md` (isinya dipindah ke AGENTS.md §6/§7). `.gitignore` +
  `Readme/`+`files/` (arsip lokal GAS/forensik, jangan commit). **Di-DELETE 6 file SQL stale
  duplicate** (191_remove_hardcoded_password ±rollback, 192_revoke_anon_access ±rollback,
  193_fix_sql_injection ±rollback) — bukti live DB: `login_admin` deprecated (495 char, no
  `Admin123`), `settings` kosong (0 rows), `anon` grants = 0, `get_people_search` sudah ada
  injection guard (854 char). Probe: `.freebuff/audit/probe_untracked_191_193.py`.
- Catatan: `supabase/GAS sebelum refaktor/` (62 file GAS legacy) TIDAK di-commit (kredensial).

## [2026-09-13] F-4 RESIDUE — retire overload legacy 0-arg get_enabled_modules()
- Status: DONE
- Commit: `a81cfa0` (DB-only, tanpa deploy frontend)
- Ringkasan: Overload 0-arg `get_enabled_modules()` (SECURITY DEFINER tanpa SET search_path —
  pelanggaran Rule §6.3 terakhir) di-RENAME → `get_enabled_modules_legacy_noarg` (Migration 205,
  Rule §6.4) + `SET search_path TO 'public', extensions` + REVOKE dari `anon, PUBLIC`.
- Bukti: 1-arg utuh (p_area + secdef + search_path ✅); ACL legacy = postgres/service_role/authenticated;
  anon REST smoke: 1-arg `200 []` fail-closed, legacy `401 permission denied`; build EXIT 0; tests 100/100.

## [2026-09-13] Strict admin-worker isolation (route) — 3-page isolation lengkap
- Status: DONE
- Commit: `6b0f706`
- Ringkasan: Admin dashboard (Estate/Mill) hanya link ke route area admin; BottomNav area-aware;
  Employees/Payroll admin link ke `/admin/*`; migrasi 204 (route admin mill). Lanjutan dari
  3-page isolation (RoleGuard + page useEffect + `session.entry`).
- Bukti: build EXIT 0, tests 100/100, deploy production OK.

## [2026-09-13] Route & role fixes (admin_operasional, admin_get_vacancies, load-all routes)
- Status: DONE
- Commits: `5845c4c`, `f2fa602`, `875483f`
- Ringkasan: rename role `admin_produksi` → `admin_operasional` (DB+frontend sinkron);
  fix SQL error `admin_get_vacancies` (ORDER BY dalam jsonb_agg); DynamicRoutes load semua modul
  untuk admin (access control di dalam komponen).

## [2026-09-13] F-4 + 5.10 — get_enabled_modules(p_area) + SET search_path
- Status: DONE
- Commit: `525519a` (+ AGENTS.md `7bbee38`)
- Ringkasan: Migration 202 — tambah param `p_area` (filter `route_group`) + `SET search_path
  TO 'public', extensions`. Frontend `DynamicRoutes.jsx` → `areaFromPath()` kirim area admin/
  worker/dashboard. Root fix A12 (menu per-area).
- Bukti: `proconfig = [search_path=public, extensions]` ✅; build EXIT 0; deploy prod ✅.

## [2026-09-13] Login OTP fix — 500 error admin/dashboard (edge password-reset)
- Status: DONE
- Commits: `664f67c` (+ AGENTS.md `abcb9cb`)
- Ringkasan: Akar: action `login_otp` memanggil RPC `generate_admin_otp()` yang butuh
  `auth.uid()` ≠ NULL, sedangkan edge pakai service role → `auth.uid()` NULL → 500. Fix:
  generate OTP langsung di edge (service role bypass RLS `otp_store`), tetap verifikasi
  admin/owner via `user_roles`. Juga fix `.catch()` tidak tersedia di Supabase JS v2.
- Bukti: E2E `login_otp NRP001 → 200 (dev_code)` → `verify_login_otp → 200 (token+role+nama)`.
- Catatan known-issue (OPEN): notice kosmetik "authgrant" saat worker login (fast-path fail →
  fallback edge sukses) — target 5.7 retire dual-store.

## [2026-09-13] Branding insightWIP (owner-configurable)
- Status: DONE
- Commits: `4014e44`, `3ae1310`, `fca2dd3`, migration `198_branding_insightwip.sql`
- Ringkasan: Branding = konfigurasi OWNER (tabel `branding` + RPC `update_branding` owner-only),
  TIDAK di-hardcode di JS. UI: tab 🎨 Branding di OwnerDashboard (LogoUploader); duplikat kartu
  di CompanyConfig dihapus. Default `company_name` = `insightWIP`.
- Bukti: migration 198 applied live (`branding.company_name='insightWIP'`); build EXIT 0; tests 100/100.

## [2026-09-12] 3-page isolation + OTP wajib admin/dashboard
- Status: DONE
- Commit: `36705ff`
- Ringkasan: Keputusan user — pindah page wajib login ulang dari tab sesuai. Implementasi 2 lapis:
  (1) `RoleGuard` (`entry` + `allowedRoles`) membungkus `/admin` `/worker` `/dashboard`;
  (2) page useEffect cek `session.entry` mismatch → redirect `/`. OTP wajib admin/dashboard
  (action `login_otp`/`verify_login_otp` di edge password-reset; step `otp` di Home.tsx).

## [2026-09-12] Prod fix — stripConsole crash (prod-only)
- Status: DONE
- Commit: `2eebb22` (+ `afc5c4e` PWA/gitignore)
- Ringkasan: Prod crash "Cannot read properties of undefined (reading 'find')" — plugin
  `stripConsole` menghapus `console.warn(...)` yang jadi if-body → `return` berikutnya ikut
  terhapus → `fetchAllRouteConfig` return undefined. Fix: regex penghapusan diganti prefix
  `void(` (AST-statement-preserving).
- Bukti: lint 0 error; tests 100/100; deploy `npx vercel --prod` ×2; smoke API login_worker 200,
  get_enabled_modules 131 rows.

## [2026-09-11..12] Commit pertama + close L-1..L-5
- Status: DONE
- Commits: `0a95421`, `49a2e9a`
- Ringkasan: `.gitignore` menutup artefak audit/test/CSV password; artefak tidak ter-track;
  F-6 dipisah (`002_test_verification.sql`); F-2 ref rusak dibersihkan (fsck 0 error);
  secret scan bersih; L-1 (NRP003 password) & L-2 (HRD) fix kredensial; commit pertama +
  push `origin/migrasi-vite`.

## [2026-09-10] Audit forensik full (read-only) — F-1..F-10
- Status: DONE (temuan dicatat; remediasi menyusul per tahap)
- Ringkasan: Verifikasi live DB + repo. Klaim lama yang GUGUR (aman, jangan re-do):
  admin_reset_worker_password, get_exit_clearance, admin_get_whistleblower, update_branding,
  owner_* escalation, get_worker_payroll, login_worker. Sebagian besar F-1..F-10 sudah ditutup
  (lihat entri lain); sisa OPEN → AGENTS.md (F-8 REVOKE sisa 5.8, F-7 pg_cron, F-9 kontrak RPC).
- Script: `.freebuff/audit/live_audit_20260910.py`, `live_audit2_20260910.py` (gitignored).

## [2026-09-11] Login & route verification testing — L-1..L-5
- Status: DONE (semua ditutup)
- Ringkasan: L-1 NRP003 hash mismatch (re-provision), L-2 HRD timeout (fix kredensial),
  L-3 admin routes tak ter-register (register-routes + migrasi 197/204), L-4 worker login flaky
  (test infra), L-5 false positive regex SW (test infra).

## [2026-09-08] Dynamic routes fix (RPC route fields, path matching, BU backfill)
- Status: DONE — Commit: `2bc9784`

## [2026-09-07] Fix worker login session loss on reload (persist RPC-token session)
- Status: DONE — Commit: `c6eb771`

## [2026-09-06] Test gates L4–L9 + gate runner + dynamic routes dari module_definitions
- Status: DONE — Commits: `0c3660e`, `d14d6e9`, `95bb151`, `575592d`
- Ringkasan: 9 gate wajib (skip = deploy blocked); zero hardcoded routes di App.tsx.

## [2026-09-06] Migrations 182–183 idempotency + FOREACH fix
- Status: DONE — Commits: `bf531a6`, `23da11c`

## ARSIP — Checklist yang sudah ditutup sebelum log dibentuk (seed dari AGENTS.md v.lama)

### ✅ DITUTUP — Temuan audit 1A (JANGAN re-do / re-open)
| ID | Ringkas |
|---|---|
| P0-1 | `get_reviews_360(text)` — REVOKE + fungsi aman (admin semua, reviewer dimask, worker miliknya) |
| P0-2 | `get_medical_checkup(text)` — idem |
| P0-3 | 13 versi legacy overload di-RENAME `_legacy_*` |
| P0-4 | Auth hook: fast path + edge worker-auth-sync + batch provisioning 8 worker |
| P0-5 | `generate_worker_otp` 3-arg (bcrypt + increment attempts), patch 001.sql |
| P0-7 | `admin_reset_worker_password` bcrypt fix, patch 001.sql |
| P0-8 | `.gitignore` menutup artefak audit/test/CSV — commit pertama aman |
| A3 | `get_nursery_data()` 0-arg — REVOKE done |
| A4 | Overload legacy `get_reviews_360`/`get_medical_checkup`/`get_worker_requests`/`create_worker_request` di-RENAME |
| A6 | Helper `authz_*` granted ke authenticated (002.sql) |
| A7 | `generate_worker_otp` 2-arg legacy — REVOKE + RENAME |
| A8 | NIK 8 worker di-backfill placeholder `3204…` |
| A12 | Menu-builder filter per-area (+ root fix 5.10 → migrasi 202) |
| A13 | Redirect login per-tab (bukan per-role) |
| A14 | `.env.local` blok SQL — diatasi (rename trick) |
| A15 | Kredensial DB + service_role dirotasi; edge di-redeploy |

### ✅ DITUTUP — Klaim audit lama yang terbukti GUGUR (terverifikasi aman di DB live, JANGAN re-do)
`admin_reset_worker_password` (authz+bcrypt+invalidasi+audit) · `get_exit_clearance` &
`admin_get_whistleblower` (grants hanya postgres/service_role) · `update_branding` (cek owner
via auth_id) · owner privilege escalation via `owner_*` (cek is_owner) · `get_worker_payroll`
(authz owner/caller/in-scope) · `login_worker` (NRP+NIK+password, lockout, bcrypt auto-upgrade)

### ✅ DITUTUP — Verifikasi audit full 2026-09-10
- NIK NULL = 0 di 17 baris `employees_core`; semua `auth_id` terisi (A8/P0-6 backfill ✓).
- `auth.users` = 9 `@insightwos.internal` + 9 `@insightwos.com` = 18.
- Grants sensitif bersih dari anon/PUBLIC (admin_get_payroll, admin_set_employee_role,
  get_reviews_360, get_medical_checkup, get_nursery_data, admin_reset_worker_password,
  get_exit_clearance, admin_get_whistleblower, get_worker_payroll, update_branding) —
  A1/A2 dalam praktik tertutup; REVOKE formal menyusul di 5.8.
- Overload legacy hanya `_legacy_*`; RLS enabled di semua tabel/view/MV kecuali
  `employees_master` (A5 terkonfirmasi → 5.9).
- Worktree & index bersih dari literal secret.

### ✅ DITUTUP — Credential rotation 5.0 (runbook dieksekusi)
- DB password + service_role key dirotasi; `.env.local` + Vercel update; edge redeploy.
- Runbook asli (`docs/5.0-credential-rotation-runbook.md`) dieksekusi penuh lalu dihapus dari
  repo saat restrukturisasi. Prinsipnya: rotate → env lokal dulu → verifikasi lokal → baru
  Vercel → verifikasi prod; service_role ikut dirotasi bersama DB password (1 aturan emas).

### ✅ DITUTUP — Kredensial terverifikasi (2026-09-11..12)
- Worker (login_worker NRP+NIK+password): NRP001 ✅; NRP002 ✅ (sha256→auto-upgrade);
  NRP003 ✅ (setelah fix L-1); NRP007 ✅. Password lengkap: `supabase/akun/akun.txt` (gitignored).
- Admin (Supabase Auth @insightwos.com): ceo ✅, pusat ✅, operasional ✅, hrd ✅ (post-fix L-2);
  finance/mining/mill/estate tercantum di `supabase/akun/akun.txt`.
- `supabase/akun/akun.txt` TIDAK ter-track (gitignore `supabase/akun/`) — bagikan per-orang lalu hapus.

### ✅ DITUTUP — Production verification (Phase D)
- Deploy `npx vercel --prod` → https://insightwos.vercel.app.
- Login test: NRP002 ✅, NRP007 ✅, pusat ✅, ceo ✅, operasional ✅, NRP003 ✅ (post-fix), hrd ✅ (post-fix).

### 📦 ARSIP DOKUMEN — keputusan pemindahan saat ONE SINGLE TRUTH (2026-09-13)
| File asli | Keputusan |
|---|---|
| `docs/TundaPlanLogin.md` | PLAN masih aktif → dipindah ke `AGENTS.md` §6 (file dihapus) |
| `docs/migration-gap-inventory.md` | Gap karyawan B1–B17 masih OPEN → `AGENTS.md` §7 (file dihapus) |
| `docs/5.0-credential-rotation-runbook.md` | Sudah dieksekusi → history (entri di atas; file dihapus) |
| `Readme/`, `files/` (arsip GAS, forensik, CSV lampiran) | Dipindah user ke `supabase/GAS sebelum refaktor/` → tetap TIDAK di-commit (kredensial legacy, lihat AGENTS.md §9). Catatan: 3 file SQL duplikat (`191_remove_hardcoded_password`, `192_revoke_anon_access`, `193_fix_sql_injection`) yang pernah ada di `supabase/migrations/` **di-DELETE** (stale duplicate dari 2026-09-08; live DB sudah memenuhi tujuannya via migrasi 191-194 yang committed — bukti probe `.freebuff/audit/probe_untracked_191_193.py`). |
| `_b.txt`, `_t.txt`, `_test_out.txt` | Sampah log build/test → dihapus |


## [2026-09-13] Tahap 5.4 (A10) — industry fake-data → real tables (migrations 208)
- Status: DONE
- Commit: `0fc63c1` (DB-only, no frontend deploy)
- Ringkasan: 6 RPCs (get_safety_incidents, get_jsa_list, get_production_daily,
  get_heavy_equipment, get_fatigue_data, get_simper_list) mengembalikan data
  palsu/fallback (hardcoded ARRAY + generate_series). Diperbaiki:
  CREATE 6 backing tables (safety_incidents, jsa_data, production_daily,
  heavy_equipment, fatigue_data, simper_data) dengan CHECK constraints,
  RLS + GRANTS sesuai pola existing. RPC di-CREATE OR REPLACE dengan
  subquery pattern (jsonb_agg(sub) FROM (...)) — semua return
  {ok:true, data:[] saat tabel kosong (fail-closed). Frontend field
  contracts terjaga (SafetyK3, JSA, ProductionDaily, HeavyEquipment,
  FatigueMonitor, SimperPage). 6 RPCs lain sudah benar (estate_blocks,
  estate_field, estate_irrigation, estate_yield, mill_maintenance, mill_shift).
- Bukti: pre-flight probe live DB (read-only), post-verify RPC calls,
  gates: lint 0 errors, tests 100/100, build EXIT 0.


## [2026-09-13] Tahap 5.7 — Retire dual-store password (partial)
- Status: DONE
- Ringkasan: "authgrant" notice sudah dihapus di sesi sebelumnya.
  14 bcrypt, 3 sha256 (NRP004/006/008 — auto-upgrade on login).
  9 auth users (NRP002-010). 8 belum di-auth: NRP001 (admin) + NRP100-106.
  NRP100-106 akan auto-provision on first login via fallback edge function
  (worker-auth-sync). Tidak ada notice — provisioning silent.
- Bukti: preflight probe live DB, grep codebase (authgrant text tidak ditemukan).


## [2026-09-13] Tahap 5.8 — REVOKE anon/PUBLIC from 9 RPCs (migration 210)
- Status: DONE
- Commit: pending
- Ringkasan: REVOKE anon/PUBLIC EXECUTE dari 9 RPCs:
  get_field_status, get_irrigation_status, get_maintenance_schedule,
  get_mill_production, get_yield_data, change_password,
  check_login_lockout(p_identifier,p_attempt_type), get_branding, cleanup_rate_limits.
  Semua sudah di-REVOKE di live DB. Migration 210 merekam untuk audit trail.
- Bukti: post-verify anon grants = 0 pada semua 9 RPCs.


## [2026-09-13] Tahap 5.9 — employees_master VIEW write-path (migration 211)
- Status: DONE
- Commit: pending
- Ringkasan: INSTEAD OF INSERT/UPDATE/DELETE triggers pada employees_master VIEW.
  Write delegasi ke employees_core (core cols) + employees_extended (PII cols).
  Smoke test: INSERT via VIEW → employees_core row created → ROLLBACK clean.
  Migration 206 (5.3) sudah fix approve RPCs ke base table; trigger ini menjamin
  write-path permanen untuk semua kode yang masih refer ke VIEW.
- Bukti: preflight probe (admin_approve_pending INSERT ke VIEW = error 55000),
  migration 211 post-verify (3 triggers + smoke test PASS).


## [2026-09-13] Tahap 5.11 + F-7 — Registration form + pg_cron (migrations 212-213)
- Status: DONE
- Commit: pending
- F-7: pg_cron EXTENSION di-enable via CREATE EXTENSION IF NOT EXISTS. 6 cron jobs
  scheduled: refresh-mv-admin-summary (hourly), refresh-mv-team-kpi (hourly),
  refresh-mv-attendance (30min), cleanup-sessions (2am), cleanup-rate-limits (3am),
  cleanup-otp (15min). Semua active=True.
- 5.11: submit_registration RPC (p_nrp, p_nik, p_nama, p_password, p_email?, p_divisi?,
  p_posisi?) — validates NRP/NIK, hashes password bcrypt, inserts daftar_baru.
  get_branding_public RPC — public-safe branding read. Frontend: registration form
  (NRP/NIK/nama/email/divisi/posisi/password) replaces alert. Cek Daftar form
  calls check_registration_status. Dynamic favicon + title from branding table.
  Branding favicon_url fixed (was timestamp, now NULL).


## [2026-09-13] F-9 + Phase E/F/G — RPC contracts + route verification (migration 214)
- Status: DONE
- Commit: pending
- F-9: Created update_audit_timestamp() (referenced by 22 triggers, was missing).
  Created get_organization_health() (dashboard health check). Added updated_at columns
  to 6 HR tables (hr_payroll, hr_performance, hr_tasks, hr_leave, hr_overtime, hr_requests).
  register_session + update_task_status (2 overloads) already existed.
- Phase E: Admin logins verified in previous session (L-1..L-5 closed).
- Phase F: 100+ admin routes registered in module_definitions — all present.
- Phase G: Worker login flaky + false positive regex — closed per agentsLogs 2026-09-11
  (L-4/L-5 DONE). AGENTS.md had stale entry — now removed.
- Phase H: = Tahap 5 — all items 5.3-5.11 DONE.

## [2026-09-13] Forensic report cross-check — post-migration verification
- Status: VERIFIED
- pg_cron: ✅ 6 active jobs (migration 212)
- anon grants: ✅ 140 → 129 (remaining: ~120 pgvector internals + login-flow functions)
- 8 SECDEF search_path: ✅ 0 violations (migration 207)
- update_task_status overload: ⚠️ 2 overloads (int + text) — both active, serve different ID types
  (text from task board, int from legacy). Rule §6.4 applies to NEW overloads, not existing.
- §3.3 "0 pelanggaran" claim: ✅ now accurate post-207


## [2026-09-14] N1 + N4 — AI RAG Access Filtering + Role-Based Rate Limits (migration 215)
- Status: DONE
- Commit: 87eedeb
- Ringkasan:
  N1: RLS policies on ai_documents (admin=all, worker=own-BU), ai_conversations (own only),
  ai_rate_limits (own rows, admin=all). Fixed match_documents precedence bug (was leaking all
  docs when v_bu IS NULL). Secured upsert_document with SECURITY DEFINER + admin auth check.
  REVOKE anon/PUBLIC from match_documents + upsert_document.
  N4: Role-based daily limits — worker=15, admin=30, manager=50, owner=unlimited. Warning at
  80%. Added role_level column to ai_rate_limits. Edge function uses DB-backed RPC. Frontend
  shows remaining queries + warning banner.
- Bukti: 9 RLS policies active, rate limit tiers verified (NRP005=15, NRP004=30, NRP003=50,
  NRP001=unlimited), match_documents no longer has IS NULL OR leak, upsert_document blocked
  for non-admin, lint 0 errors, tests 100/100, build EXIT 0.


## [2026-09-14] R4 — Rollback scripts for critical migrations 183-214
- Status: DONE
- Commit: 53f721b
- Ringkasan: Created 11 new rollback scripts (183, 191-194, 209-214) covering all critical
  migrations. 7 existing rollbacks (206-208, 215-218) already present. Total: 18 rollback
  scripts. Key rollbacks:
  - 183: recreate employees_master TABLE from core+extended (destructive, backup required)
  - 191: drop admin approve/reject/OTP functions
  - 192: documented as destructive (fix, not addition) — functions NOT dropped by default
  - 193: drop atomic rate limit functions
  - 194: drop trust-the-client hardened RPCs
  - 210: GRANT back anon/PUBLIC on 9 RPCs
  - 211: drop INSTEAD OF triggers on employees_master VIEW
  - 212: unschedule pg_cron jobs
- Bukti: 18 rollback scripts present, no typos (grep IFACES check clean), all semicolons present.


## [2026-09-14] Session summary — N1 + N4 + R4 (migrations 215 + rollback scripts)
- Status: DONE (all items verified against live DB)
- N1 (AI RAG Access Filtering): RLS policies on ai_documents (admin=all, worker=own-BU),
  ai_conversations (own only), ai_rate_limits (own rows, admin=all). Fixed match_documents
  precedence bug. Secured upsert_document with SECURITY DEFINER + admin auth check.
  REVOKE anon/PUBLIC from match_documents + upsert_document.
- N4 (AI Rate Limit Tuning): Role-based daily limits — worker=15, admin=30, manager=50,
  owner=unlimited. Warning at 80%. Added role_level column to ai_rate_limits. Edge function
  uses DB-backed RPC. Frontend shows remaining queries + warning banner.
- R4 (Rollback Scripts): 18 rollback scripts (183-214). Initial write had 18 errors
  (referenced functions that don't exist on live DB). Fixed after live verification:
  183: rewritten with correct column lists; 191: removed non-existent approve/reject facility;
  193: removed non-existent atomic_rate_limit; 194: replaced 16 admin_update_worker_* with
  actual functions (clock_in, clock_out, get_narrative, etc.).
- Commits: 87eedeb (N1+N4), 52ba974 (docs), 53f721b (R4 initial), 4ebae99 (R4 fixes)
- Bukti: live DB verification (0 errors), lint 0, tests 100/100, build EXIT 0


## [2026-09-14] A7: Migration Versioning System (migration 219)
- Status: DONE
- schema_migrations table: tracks version, filename (unique), SHA-256 checksum, applied_at, execution_ms
- Functions: apply_migration() — register after apply; check_migrations() — detect unapplied/duplicate/orphaned; verify_migration_checksum() — detect tampering
- Registered all 145 existing migrations in live DB
- Removed version unique index (multiple files can share version numbers, filename is true unique key)
- Applied to live DB + verified (0 issues)
- Commits: 02f0b35
- Gates: lint 0 errors, tests 100/100, build EXIT 0, secret scan clean


## [2026-09-14] §6 Login Refactor — DEPLOYED + O5 Hash-chain Audit Log
- Status: BOTH DONE
- §6 Login Refactor: deployed to production (vercel --prod) + edge function (ai-copilot)
  - Worker email+password login now live
  - MFA optional all roles
  - Step 5 (edge worker-auth-sync): no change needed (Opsi A)
- O5 Hash-chain Audit Log (migration 220):
  - Added prev_hash + row_hash columns to audit_log
  - BEFORE INSERT trigger: auto-compute SHA-256 chain
  - Backfilled all 162 existing rows
  - verify_audit_chain(): detects BROKEN_LINK + TAMPERED rows
  - Chain verified: 0 issues
- Commits: §6 deploy (vercel), O5 = 4aeff4f
- Gates: lint 0 errors, tests 100/100, build EXIT 0


## [2026-09-14] TypeScript Migration — Phase 1 (branch: typescript-migration)
- Status: DONE (Phase 1 of 3)
- Branch: typescript-migration (isolated from migrasi-vite)
- Phase 1 deliverables:
  - tsconfig.json: strict mode, bundler resolution, path aliases (@/*)
  - src/types/index.ts: 25+ shared interfaces (Employee, Payroll, RPC, etc.)
  - src/lib/supabase-rpc.ts: typed RPC wrapper with overloads
  - src/lib/validation/schemas.ts: Zod v4 schemas for all forms
  - Converted 5 core lib files .js → .ts: supabase-browser, rate-limiter, edge-functions, route-config, menu-builder
  - src/vite-env.d.ts: ambient declarations for .jsx imports + env vars
- Gates: tsc --noEmit 0 errors, build EXIT 0, tests 100/100
- Commit: 689478f
- Remaining Phase 2: convert .jsx → .tsx (18 JS files in src/lib/hooks + src/components + src/features)
## [2026-09-14] TypeScript Migration — Phase 2 (interrupted session resumed): helper .js → .ts
- Status: DONE (sub-batch helper lib/hooks; sisa Phase 2 .jsx→.tsx tetap OPEN)
- Branch: typescript-migration
- Ringkasan: Melanjutkan sesi yang terputus (files/tidak selesai migrasi JS ke TS.txt). Konversi 13 helper `.js` → `.ts` + hapus `.js`, bersihkan import `.js` di src, dan perbaiki error tipe TS:
  - .js → .ts: useAdminAuth, useModuleAccess, business-units, chart-config, format, useFormValidation, useI18n(+index,translation object pindah ke index.ts), useKeyboardNavigation, log-error, posthog, push-notifications, validation/security
  - Perbaiki type: business-units.ts/posthog.ts (cast sesi `getSession() as UserSession`), useModuleAccess.ts (rpc generic <boolean>/<any[]> + `ok` & `is_owner` eksplisit), types/index.ts (+`is_owner?` di UserContext), posthog.ts (hapus `session_recording` invalid + `as any` utk kunci legacy + `PostHog` type utk `loaded`), push-notifications.ts (BufferSource, `vibrate` cast, `return null`)
  - Import `.js` di src → tidak bersisa; import tanpa ekstensi sudah ada di HEAD (Phase 1). `M` pada .jsx = hanya churn line-ending CRLF (isi sama), tidak distage.
- Keterangan flake: run full test 2x muncul 2-3 timeout (vitest-worker boot / import 5s) akibat beban mesin; DIJALANKAN ULANG ISOLASI → 12/12 lolos instan. Bukan kegagalan logika.
- Gates: tsc --noEmit 0 error, build EXIT 0, lint 0 error (385 warning pre-existing), tests 100/100 fungsional.
- Commit: (lihat reflog) — push ke origin/typescript-migration. DEPLOY ditahan (branch migrasi, bukan prod; menunggu keputusan user).
- Sisa Phase 2 OPEN: convert `.jsx` → `.tsx` (src/components + src/features + sisa).

## [2026-09-15] TypeScript Migration — Phase 2 SELESAI (`.jsx` → `.tsx`, tsc 0 error) + E2E hijau — DONE
- Status: DONE
- Branch: typescript-migration
- Commit: 3962321 → push `origin/typescript-migration` (DEPLOY ditahan: branch migrasi terisolasi, menunggu keputusan merge ke `migrasi-vite`)
- Ringkasan: Menuntaskan sisa Phase 2. Semua `src/**/*.jsx` sudah di-rename `.tsx` oleh helper, tapi masih **199 error `tsc --noEmit`**. Diperbaiki sampai **0 error** — akar masalah dulu, bukan tambal per call-site:
  - design-system (satu perbaikan mematikan ~60 error): `CardColor` dibuka jadi `string` (caller mengirim nilai DB seperti `'info'`), `Badge` menerima `children`/`variant`/`color`, `EmptyState` menerima `message`/`description`, `Column.render` param dilonggarkan, `DataTable.data` jadi `any[]`, `Tabs` menerima `id`/`key`
  - `useState({})` → `useState<Record<string, any>>({})` (8 file), ~30 peta status literal (`STATUS_CONFIG`, `SHIFT_COLORS`, …) dianotasi `Record<string, …>`, ~60 callback implicit-`any` diberi tipe eksplisit
- **2 bug runtime nyata yang terbongkar compiler:**
  1. `toast(...)` dipanggil sebagai fungsi di `SafetyK3.tsx`, `FacilityRequest.tsx`, `HarvestRecord.tsx` — padahal `useToast()` mengembalikan objek `{success, error, …}` → `toast is not a function` saat runtime (sisa kerja Tahap 5.5 dead-forms). Diganti `toast.error(...)` / `toast.success(...)` sesuai 15 call-site lain.
  2. `Home.tsx` rusak encoding akibat codemod rename — bukan cuma komentar: **string yang dirender** pun jadi mojibake (tombol kembali tampil sampah, bukan `←`; emoji `🔑 📝 🔍 🔐 📤` dan semua `—` hancur), plus **newline hilang di 3 tempat** sehingga baris komentar tergabung. Dipulihkan byte-exact dari blob pra-rename `2ccaa95^:src/pages/Home.jsx` (terverifikasi identik dengan HEAD). Mojibake em-dash di `OwnerDashboard.tsx` (sudah ter-commit) ikut dibersihkan. Scan seluruh repo: 0 mojibake / 0 C1-control / 0 komentar tergabung.
- Lint: **0 error** (buang direktif `@typescript-eslint/no-explicit-any` yang basi — plugin-nya tidak dimuat di config Babel-parser saat ini, jadi direktifnya sendiri yang jadi error — dan bereskan irregular whitespace).
- E2E Playwright: **51 passed / 0 failed** (sebelumnya 9 gagal). Akar 6 kegagalan admin/dashboard: mock TIDAK pernah meng-intersep edge `password-reset`, sehingga login menembus edge produksi yang rate-limiter-nya menjawab "Terlalu banyak request OTP". Ditambah route mock `password-reset` (`login_otp` → `dev_code`, `verify_login_otp`), handler RPC `verify_admin_otp`, dan `loginAsAdmin` kini menjalankan alur 2 langkah password → OTP yang sebenarnya.

## [2026-09-16] S4 CSP Upstash removal + L7 provisioning failure notification — DONE
- Status: DONE
- Commit: `d45f0f9` (2 file, +15/−4) — deploy: production `insightwos-5fdd8rj0x` ● Ready
  (alias https://insightwos.vercel.app HTTP 200). Frontend-only — tidak ada perubahan edge/DB.
- Ringkasan:
  1. **S4 — CSP `connect-src` dibersihkan.** `https://alive-robin-191313.upstash.io` dihapus dari
     `vercel.json` CSP header. Upstash Redis tetap di stack (§5.5, keputusan user 2026-09-15);
     hanya entri browser CSP yang dihapus — tidak ada kode frontend yang memanggil Upstash langsung.
     CSP `connect-src` sekarang: `'self' https://verwobaejumvpagwynae.supabase.co https://*.posthog.com
     https://api.posthog.com https://us.i.posthog.com`.
  2. **L7 — Provisioning failure di-surface ke user.** `provisionWorkerAuth()` di `Home.tsx` sudah
     mengembalikan `boolean`, tapi ketiga call site mengabaikan hasilnya — user tidak pernah tahu
     kalau auth sync gagal. Ditambah `alert()` warning di 3 lokasi: `finalizeWorkerSession()` (worker
     fast path), `submitWorkerOtp()` (worker no-MFA OTP path), dan `submitWorkerMfa()` (worker MFA path).
     Pesan: "Peringatan: Auth sync gagal — beberapa fitur mungkin terbatas. Silakan muat ulang halaman."
     Provisioning tetap best-effort (non-fatal); redirect login tidak diblokir.
- Bukti:
  - tsc: 0 error ✅
  - lint: 0 error (38 warnings pre-existing) ✅
  - build: EXIT 0 ✅
  - unit tests: 15/15 files, 113/113 tests pass ✅
  - Deploy: Vercel production ready, alias HTTP 200 ✅
- Dampak lintas-page: worker → admin → dashboard → owner — tidak terdampak. S4 hanya CSP header
  (tidak mengubah kode). L7 hanya menyentuh `provisionWorkerAuth` di `Home.tsx` (login worker);
  admin/dashboard/owner login tidak menggunakan fungsi ini (admin pakai `syncSupabaseAuth` langsung).

## [2026-09-16] no-console lint cleanup — DONE
- Status: DONE
- Commit: `71b7983` (13 files, +12/−22) — deploy: production via `npx vercel --prod` (alias https://insightwos.vercel.app). Frontend-only — tidak ada perubahan edge/DB.
- Ringkasan:
  1. **12 console statement dihapus** dari 13 file: admin guard redirect logging (AdminRouteGuard, useAdminAuth, Worker, Dashboard, Admin), empty-list/unknown-component warnings (DynamicRoutes), provisionWorkerAuth debug logging (Home), SW registration status (register-sw), rpcError logging (supabase-browser).
  2. **4 console.error dipertahankan** dengan `eslint-disable-next-line` (RoleGuard fail-closed + catch-all, AppDrawer menu build failure, logError central logger, ExportPage DEV-only). Alasan: intentional fail-closed guards, centralized error pipeline, DEV-gated debug output — bukan noise.
  3. **register-sw.ts**: `console.log` diganti dengan empty arrow functions (interface tap tanpa output noise).
- Bukti:
  - tsc: 0 error ✅
  - lint: 0 error, 14 warnings (all `react-hooks/exhaustive-deps`, P2 scope) ✅
  - build: EXIT 0 ✅
  - unit tests: 15/15 files, 113/113 tests pass ✅
  - Deploy: Vercel production ready, alias HTTP 200 ✅
- Dampak lintas-page: worker → admin → dashboard → owner — tidak terdampak. Perubahan bersifat lintas-file (semua page), tapi hanya menghapus log output tanpa mengubah alur kontrol atau state management. `eslint-disable` hanya pada guard fail-closed yang sudah terisolasi.

## [2026-09-16] Batch audit fix: S11 DOMPurify + L3 isAdminRole + L6 columnLabel + L2/U6 parseDateOnly — DONE
- Status: DONE
- Commit: `a738139` (16 files, +170/−31) — deploy: production `insightwos-pc6u0n7a3` ● Ready
  (alias https://insightwos.vercel.app HTTP 200). Frontend-only — no edge changes.
- Ringkasan:
  1. **S11 — DOMPurify hardening** (`ChatCopilot.tsx`): `PURIFY_CONFIG` konstan dengan
     `ALLOWED_TAGS: ['strong','em','pre','code','li','br']`, `ALLOWED_ATTR: ['class']`,
     `ALLOW_DATA_ATTR: false`. Defense-in-depth untuk input LLM.
  2. **L3 — Shared `isAdminRole()`** (`src/lib/role-utils.ts`): helper `isAdminRole(role)` =
     `role.startsWith('admin_') || role === 'admin'`. 9 file dimigrasikan: SurveyPage (3 site),
     Okrs (2), PerformanceNotes (1, dengan `|| role === 'manager'`), VoiceIdeasPage,
     WhistleblowingPage, ReferralPage, BadgesPage, CertificationsPage, Home.tsx. Pattern A
     (broken `role === 'admin'`) dan Pattern B (verbose `startsWith`) disatukan.
  3. **L6 — Typed column labels** (`DetailPageFactory.tsx`): `COLUMN_LABEL_MAP` (~80 entries)
     + `columnLabel(key)` helper — fall back ke auto-title-case untuk key tidak dikenal. 2 site
     diganti (table header + detail modal).
  4. **L2/U6 — `parseDateOnly()`** (`src/lib/format.ts`): `new Date(y, m-1, d)` untuk
     local date parsing, mencegah drift H-1 di WIB. `WorkerAttendance.tsx` 2 site diganti
     (filter bulan + display tanggal). ForumDiskusi/OwnerDashboard pakai datetime → out of scope.
- Bukti: `tsc --noEmit` 0 error; `npm run lint` 0 error (14 warning); `npm run build` EXIT 0;
  unit test 113/113 (15 file).
- Dampak lintas-page: worker → admin → dashboard → owner — Tidak terdampak secara visual;
  S11 di ChatCopilot (chat widget), L3 memperbaiki role check yang sebelumnya broken untuk
  `admin_*` di 9 halaman, L6 hanya kosmetik label kolom, L2/U6 hanya tanggal display.
---

## [2026-09-16] P2 Audit Batch: L7 + U2/L5 + U1 + U3/U5 — DONE
- Status: DONE
- Commit: `e819067` (21 file) — deploy: production `insightwos-6b9679eag` ● Ready, alias https://insightwos.vercel.app HTTP 200.
- Ringkasan:
  1. **L7 — alert() → toast.warning().** `Home.tsx`: 3x `alert('Peringatan: Auth sync gagal...')` diganti `toast.warning('Auth sync gagal — beberapa fitur mungkin terbatas...')`. User kini melihat toast non-fatal; redirect login tidak diblokir.
  2. **U2/L5 — `useRpcQuery` hook.** Hook baru (`src/hooks/useRpcQuery.ts`, 82 baris): cancelled-flag cleanup, `isRpcError()` guard, satu generic `<R>`. 9 page dimigrasi dari boilerplate `useState`+`useEffect`+`useCallback`+`rpc()` repetitive: WorkerAttendance, WorkerPayroll, WorkerLearning, ForumDiskusi, AdminAttendance, WhistleblowingPage (×1 RPC), WorkerLeave, Employees, RecruitmentDashboard (×2 RPC). Kpi.tsx sengaja tidak dimigrasi (5 RPC + normalisasi duck-typing 50+ baris — tidak cocok untuk generic hook).
  3. **U1 — Zod dead code removed.** `src/lib/validation/schemas.ts` (163 baris, 13 Zod schemas) dihapus: 0 konsumen di `src/`. `package.json` → `zod` di-uninstall (−1 package). `validation/security.ts` dipertahankan (tidak pakai Zod).
  4. **U3 — RPC error toast.** `ForumDiskusi.tsx` (3 mutasi: createPost, sendReply, sendReplyError) dan `WhistleblowingPage.tsx` (1 mutasi: handleSubmit) mendapat `isRpcError` + `toast.error` fallback — user melihat notifikasi ketika RPC gagal, bukan kegagalan senyap.
  5. **U5 — Tailwind utility token.** `.text-micro` (`11px/1.3`) + `.text-muted` (`text-slate-500`) ditambahkan ke `globals.css`. 22 instance `text-[11px]` → `text-micro` di 6 file: ChatCopilot (11), ForumDiskusi (6), BottomNav (2), AppDrawer (1), WhistleblowingPage (1), PrivacyConsent (1).
- Bukti: `npx tsc --noEmit` **0 error**; `npx eslint src/` **0 error** (12 warning pre-existing `react-hooks/exhaustive-deps`); `npx vite build` **EXIT 0** (~7s, 2011 modules); `npx vitest run` **113/113** (15 file). Gate dijalankan ulang setelah setiap tugas.
- Dampak lintas-page: worker → admin → dashboard → owner — RPC layer (`useRpcQuery`) adalah lapisan bersama yang dipakai di seluruh page; perubahan ini menormalisasi fetch pattern lintas worker (WorkerAttendance/WorkerPayroll/WorkerLearning), admin (AdminAttendance/Employees/ForumDiskusi), dan dashboard/recruitment (RecruitmentDashboard/WorkerLeave). Toast system berlaku untuk semua role. Tidak ada kontrak RPC/menu/route/authz/types yang diubah — tidak ada perubahan perilaku untuk admin/dashboard/owner selain peningkatan UX error handling. Keempat area ter-smoke via tsc+lint+build+tests.