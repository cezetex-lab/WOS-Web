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
9. **Temuan audit WAJIB jadi tugas, bukan catatan.** Setiap temuan dari audit/inspeksi apa pun
   harus masuk **WORK QUEUE** (§5.8 untuk temuan SQL) sebagai item bernomor dengan
   **Prioriitas + Bukti + Definition of Done**; item hanya boleh ✅ bila DoD-nya **dibuktikan
   dengan perintah/query + hasil**. Dilarang menutup temuan sebagai prosa, ringkasan, atau
   "sudah dicatat". Kalau sebuah temuan ternyata **bukan masalah**, pindahkan ke tabel
   *"Sudah diverifikasi BUKAN masalah"* beserta alasannya — supaya tidak diinvestigasi ulang,
   dan jangan tinggalkan sebagai item OPEN palsu.
10. **Butuh keputusan user? Tulis sebagai item + tanyakan, jangan diam.** Item yang menunggu
   keputusan (mis. risiko `FORCE ROW LEVEL SECURITY` terhadap SQL Editor) tetap tinggal di
   WORK QUEUE dengan penanda **"butuh keputusan user"** beserta opsi + risikonya, agar tidak
   hilang dari pandangan.

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
    `npm test` (unit 119/119), `npm run build` (EXIT 0), secret scan. Untuk perubahan
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
13. **Angka metrik di dokumen tidak boleh dikarang.** Klaim kuantitatif di `AGENTS.md` (§7.1, §7.3, §7.4, §7.5) dan `FuturePlans.md` (§1.3) diverifikasi otomatis oleh `tests/unit/doc-claims-vs-live.test.ts` terhadap DB live + isi repo. Kalau schema/berkas berubah secara sah: **perbarui dokumennya** — JANGAN melemahkan/menghapus tesnya. Angka yang hanya bertambah (mis. baris `audit_log`) diperiksa sebagai `>=`. Tes itu di-skip bila `DATABASE_URL` tidak ada, jadi `npm test` tanpa kredensial tetap jalan. Aturan yang sama berlaku untuk klaim kapabilitas roadmap di `FuturePlans.md` (tabel/RPC/berkas yang diklaim sudah ada atau belum ada).
14. **Migrasi tidak boleh masuk DB live tanpa tercatat.** Migrasi 221/222/223 pernah diterapkan lewat SQL Editor sehingga `schema_migrations` tertinggal (§5.7 no.11). Sejak 2026-09-17 jalurnya satu: `npm run db:migrate -- <berkas>.sql --apply` (§6.4). Klaim "DONE" untuk migrasi baru wajib menyertakan bukti `verify_migration_checksum` PASS dan `check_migrations()` bersih.
15. **Instalasi perusahaan baru = baseline, bukan rantai migrasi.** `supabase/migrations/` (157 berkas) adalah HISTORI + gerbang regresi, bukan jalur instalasi: ia membawa data seed/demo dan tidak memuat objek yang hanya hidup di DB live. Jalur resmi: `npm run install:baseline -- --target ... --apply` (runbook: `supabase/baseline/README.md`). Setelah setiap migrasi yang mengubah schema, **wajib regenerasi** `npm run db:baseline` lalu buktikan dengan `npm run db:verify-install` — baseline yang tertinggal dari live akan memasang perilaku lama ke perusahaan baru (kejadian nyata 2026-09-18: perbaikan `get_owner_email()` di migrasi 230 belum ter-dump sehingga instalasi baru masih mewarisi email owner kita).
16. **Identitas perusahaan tidak boleh diwariskan lewat baseline.** Nama/logo (`branding`), email owner (`company_config.owner_email`/`ceo_email`), dan `system_owner_identity` adalah milik tiap perusahaan: dilarang berada di dump data, dan dilarang menjadi nilai default di fungsi DB bersama (mis. `COALESCE(..., 'owner@insightwos.com')`) — fungsi seperti itu wajib **fail-closed**. Generator baseline sudah memblokirnya (`EXCLUDED_ROWS` + pemindai domain) dan `verify-install-e2e.mjs` menegakkannya setiap kali dijalankan.

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

## 5. STATE DONE — UI Forms untuk Kolom Baru Karyawan (2026-09-16)

> DB sudah lengkap (migration 215): 14 kolom baru di `employees_core` + `employees_extended`.
> **Selesai 2026-09-16:** UI + RPC + migration 222 + deploy production. Lihat `agentsLogs.md` [2026-09-16].

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

**Sisa:**
- [ ] Smoke test runtime: login worker → WorkerProfile → edit 1 kolom → simpan → reload
  (dilakukan user secara manual di browser; environment ini tidak bisajangkau app live).
  Grant `EXECUTE TO authenticated` sudah termigrasi dalam migration 222 (baris 79 + 150-152),
  jadi tidak perlu langkah terpisah di SQL Editor.

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
4. **Apply migrasi ke DB live WAJIB lewat wrapper**, bukan SQL Editor / pg8000 manual:
   `npm run db:migrate -- <berkas>.sql --apply` (`supabase/scripts/apply-migration.mjs`). Wrapper itu
   menjalankan SQL DAN mendaftarkannya ke `schema_migrations` dalam **SATU transaksi** — kalau
   pendaftaran gagal, SQL-nya ikut ROLLBACK, jadi mustahil berakhir "sudah jalan tapi tidak tercatat"
   (penyebab drift 221/222/223, §5.7 no.11). Ia juga menolak jalan kalau nomor versi sudah dipakai
   berkas lain, dan mendeteksi berkas yang diubah setelah diterapkan (checksum beda). Default = dry run.
5. `.env.local` pernah pecah dotenv (blok SQL mentah) — cek parse sebelum deploy edge.
6. **Post-verify read-only setelah apply**: pakai script python pg8000 yang membaca `DATABASE_URL` dari
   `.env.local` (jangan lewat argv agar tidak ter-log) untuk memastikan efek migrasi benar di DB live.
7. **"Timeout waiting for worker to respond" bukan masalah konfigurasi tes.** Vitest memakai timeout keras **60s** untuk pool runner-nya (`START_TIMEOUT` di `node_modules/vitest/dist`) yang TIDAK bisa dikonfigurasi, sementara default worker = satu per core. Di mesin 12 core pool runner kalah rebutan CPU → sebagian berkas "passed" tapi ada puluhan error dan jumlah test jauh di bawah 119. `vitest.config.ts` membatasi `maxWorkers` (2 per project; suite dipecah jadi project `node` + `jsdom`). Gejala ini pernah dicatat sebagai "flaky Windows" — akarnya konkret, jangan di-workaround dengan `--no-file-parallelism`.
   **Anomali teramati sekali (2026-09-17):** tepat setelah split jadi 2 project, satu run melaporkan `Test Files 15 passed (15) / Tests 100 passed (100)` — persis kehilangan `session.test.ts` (11) + `supabase-browser.test.ts` (8) — **tanpa satu pun baris error**, saat mesin sedang berat (run 94s, setup 24.6s). Tidak terulang dalam 9 run berikutnya (semuanya 17/119). Kalau suatu saat jumlah test < 119 tapi tidak ada error, curigai ini dulu: jalankan ulang, dan cek `npm run check:types` masih 0 error.

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
│  DB: 208 tables, 667 functions, RLS on all tables          │
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
| TypeScript | ✅ DONE | — | 197 file TS total (157 `src` + 34 `tests` + 6 config), 0 tsc errors — `tsconfig` mencakup `src`+`tests`+`*.config.ts`, `allowJs: false` |
| Partisi dinamis + ACL RPC penulis | ✅ DONE | 225-227 | `ensure_attendance_partitions()` (idempoten) menggantikan loop hardcoded `2024..2027`; cron bulanan; `overtime_approved` diselaraskan. Migration 226 mencabut anon/PUBLIC dari 4 RPC penulis (`worker_update_profile` + 3 trigger), dan PUBLIC dari 7 RPC alur login (anon dipertahankan). Penjaga: `tests/unit/db-security-and-partition-guard.test.ts` |
| Instalasi perusahaan baru (baseline) | ✅ DONE | `supabase/baseline/` (2 berkas) | Jalur RESMI untuk project kosong: `npm run install:baseline -- --target ... --company-name "PT X" --owner-email "..." --apply`. Diverifikasi `verify-install-e2e.mjs`: 9/9 metrik = live, ACL 0 selisih, `check_migrations()` 0 issue, idempoten. Runbook: `supabase/baseline/README.md`; templat akun owner: `first-owner.example.sql`. Rantai migrasi tetap dipelihara sebagai histori + gerbang regresi (`db:replay --mode=chain` = 157/157) |
| Audit 2026-09-16 | ✅ DONE (`81a5bf5`, deployed — sisa OPEN audit di §5.6) | — | Ringkasan: helper `requireNrp()`/`requireSession` di `src/lib/supabase-browser.ts` menggantikan fallback `'NRP001'` di 13 komponen; RoleGuard fail-closed (allowedRoles=0 ditolak); CSP `script-src` ditarik `unsafe-inline`/`unsafe-eval` via modul TS (error-suppressor & SW register); index.html inline script dipindah ke `src/main.tsx`; `vercel.json` CSP diperbaiki (`unsafe-eval` + `img-src https:` wildcard dibuang; entri `connect-src alive-robin` **sengaja dipertahankan** sesuai §5.5) — ⚠ file-file ini masih UNCOMMITTED; `tsc` sempat 7 error (import `requireNrp` hilang di 5 file + `React` UMD di `main.tsx`), sudah diperbaiki → tsc 0 error. COMMIT `81a5bf5` → push → deploy production `insightwos-lo3gcmyg9` ● Ready (alias HTTP 200; CSP prod + 0 inline script terverifikasi via curl); sinkronisasi `areaFromPath`/`menu-builder`; 12 file `format.ts` dibersihkan komentar histori; build EXIT 0, lint 0 error, tsc 0 error, E2E 51/51 hijau. Detail: hardcode identitas `|| 'NRP001'` dihapus dari Worker.tsx, ForumDiskusi, TrainingForm, WorkerOvertime, CompensationIntel, WorkerPayroll, WorkerProfile, ContinuousPerf, PerformanceTrend, WorkerKpi, WorkerCareer, WorkerActivities. Branding FreeBuff sudah bersih di UI aktif. Komentar histori/banner dikompaktankan (jaga RoleGuard/DynamicRoutes/vite.config). Dampak lintas-page: worker→admin→dashboard→owner — semua component identitas sekarang melalui layer bersama, tidak ada patch per-page. |

### 7.4 Database Status (Live)

| Metric | Count | Notes |
|---|---|---|
| Tables | 208 | 208 base table **non-partisi**; 209 kalau view dihitung. Partisi absensi (kini **57**) TIDAK dihitung karena dibuat otomatis oleh `ensure_attendance_partitions()` (migration 225) |
| Functions | 667 | 20 overloads (legacy renamed `_legacy_*`); +1 `ensure_attendance_partitions` (migration 225). LIVE 2026-09-18 (pasca-228 pensiun 6 fungsi refresh MV): 673−6 |
| Migrations tracked | 157 | Via `schema_migrations` (migration 219); 221–227 didaftarkan 2026-09-17 (§5.7 no.11); `008` + `229` + `230` diterapkan 2026-09-18 (`DITERAPKAN + terdaftar + checksum terverifikasi`). Rantai 000→230 replay bersih **157/157** |
| RLS policies | All tables | Enabled di semua tabel tanpa USING(true); **9 tabel belum FORCE** (`employees_core`, `employees_extended`, `fatigue_data`, `heavy_equipment`, `jsa_data`, `production_daily`, `safety_incidents`, `schema_migrations`, `simper_data`) — pemilik tabel masih melewati RLS |
| SECDEF search_path | 0 violations | Fixed via migration 207 |
| anon/PUBLIC grants | 128 | Turun dari 132 lewat migration 226 (RPC penulis dicabut); sisanya internal pgvector + alur login |
| pg_cron jobs | 4 | LIVE 2026-09-18 (pasca-228 pensiun 3 job MV gagal/setiap jam): `cleanup-sessions`, `cleanup-rate-limits`, `cleanup-otp`, `ensure-attendance-partitions` |
| Audit chain | 172 rows | Hash-chain live, `verify_audit_chain()` = 0 issues (migration 220); baris hanya bertambah |

### 7.5 Frontend Status

| Component | Status | Notes |
|---|---|---|
| TypeScript | ✅ 157 .ts/.tsx files (132 `.tsx` + 25 `.ts`) | 0 tsc errors (re-verifikasi 2026-09-17), strict mode, `allowJs: false` |
| Unit tests | ✅ 131/131 | vitest (19 berkas; 2 project: `node` + `jsdom`) — termasuk penjaga instalasi baseline (`baseline-install-guard.test.ts`) |
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

---

## 5.7 STATE OPEN — POSTPONED / TUNDA (2026-09-17 — Perintah User)

> **Keputusan user (2026-09-17):** Migrasi region Singapore (`ap-southeast-1`) **DITUNDA** sampai diminta; mungkin **TIDAK DIPERLUKAN** (`FuturePlans.md` F2 item infra belum masuk roadmap — hanya catatan, bukan blocker). `FuturePlans.md` sudah diperbarui (`6d066b8`).
>
> Status SG migration: `supabase/scripts/migrasi-region-sg-plan.md` sudah dibuat (runbook lengkap: backup, apply migrations, restore, env update, smoke 4 page, cutover), tapi **BELUM DIEKSEKUSI** — user menunda.

### TO-DO LIST BERURUTAN (Aman — dari Ringkasan Status Terbaru)

| No | Item | Prioritas | Status | Catatan Aman |
|---|---|---|---|---|
| 1 | **PWA offline spec live test** (`pwa-offline-mode.spec.ts`) | P0 (kecil) | OPEN — spec dibuat + asersi ditambah, dijalankan tapi timeout 30s (environment) | Non-disruptive — hanya verifikasi live |
| 2 | **Edit `FuturePlans.md`** (F1/F3/F4) | P0 (kecil) | ✅ SELESAI (`6d066b8`) — F1 (offline sudah hidup), F3 (tumpang tindih diperbaiki), F4 (obsolete dihapus) | Non-disruptive — dokumentasi |
| 3 | **Audit P3 cleanup sisa** — komentar header yang menyebut nama berkas basi | P3 (kecil) | ✅ SELESAI (`e20c420`) — scope terkoreksi: **89 berkas**, bukan 5 (86 header `src/` masih menyebut `.jsx`; 5 berkas yang terdaftar justru tidak punya komentar historis). `AppDrawer.tsx` lebih dulu (`6d66072`) | Non-disruptive — kosmetik |
| 4 | **Verifikasi deploy `7f1bf08` (`loop redirect`) dan `3b6a698` (`branding` + `loop`) ke production** | P1 | ✅ SELESAI (terverifikasi 2026-09-17) — sha256 3 aset produksi identik dengan build lokal `dist/`; redirect berbasis `entry` ada di bundle produksi; `get_branding` granted ke `anon` | Tidak perlu deploy ulang |
| 5 | **SG Migration — Langkah 1: Verifikasi region Upstash** (`alive-robin-191313`) | P1 (besar — TUNDA) | TUNDA — user belum meminta | Non-disruptive — hanya verifikasi |
| 6 | **SG Migration — Langkah 2: Backup DB (`pg_dump`)** | P1 (besar — TUNDA) | TUNDA | Non-disruptive — hanya backup |
| 7 | **SG Migration — Langkah 3: Buat project SG (`ap-southeast-1`)** | P1 (besar — TUNDA) | TUNDA | Perlu persetujuan user (keputusan 2026-09-15 sudah dibuat, tapi belum dieksekusi) |
| 8 | **FuturePlans.md — Revisi `§3` Phase 1 Roadmap** (tambahkan catatan `Shift Swap` harus lebih awal / `Payroll Engine` → `Payslip` dependency) | P2 | PARTIAL — F3 overlap sudah dicatat, tapi urutan `§3.1` belum diubah sepenuhnya | Non-disruptive — dokumentasi |
| 9 | **PWA Offline — Jalankan spec live (`pwa-offline-mode.spec.ts`) secara lokal** | P0 | OPEN — sudah dibuat, belum berhasil di environment ini | User bisa jalankan: `npx playwright test .freebuff/audit/live-smoke/pwa-offline-mode.spec.ts --config=.freebuff/audit/live-smoke/playwright.live.config.ts` |
| 10 | **Audit log `agentsLogs.md`** — tambahkan entri `2026-09-17` (PWA + SG tunda + FuturePlans revisi) | P4 | ✅ SELESAI — entri `[2026-09-17] P3 header .jsx→.tsx + guard anti-drift + vitest stabil + verifikasi production` | Non-disruptive — hanya dokumentasi log |
| 11 | **`schema_migrations` tertinggal** — migrasi **221/222/223 diterapkan ke DB live tapi tidak tercatat** | P2 | ✅ SELESAI (2026-09-17) — ketiganya didaftarkan via `apply_migration()` dengan checksum SHA-256 byte mentah (algoritma divalidasi 6/6 terhadap baris lama); `verify_migration_checksum` PASS untuk ketiganya; `UNAPPLIED` 3 → 0; tabel 146 → **149 baris** = 149 berkas repo saat itu (kini 152 baris = 152 berkas setelah migrasi 224/225/226). Sisa 4 entri `DUPLICATE` (v176/186/208/215) **bukan bug**: dua berkas berbeda memang berbagi nomor versi — lihat catatan §5.7 di bawah | — |

---

> **Catatan penting:** Item 1–4 ter-commit + push (`6d066b8`, `3b6a698`, `7f1bf08`). Item **3 selesai** di commit `e20c420` (89 berkas; scope terkoreksi dari 5) + `b3b7d98` (guard anti-drift + vitest stabil), dan item **4 sudah terverifikasi** 2026-09-17 (sha256 aset produksi = build lokal `dist/`; redirect berbasis `entry` ada di bundle produksi) — catatan lama "deploy gagal di environment agent" tidak berlaku lagi. Item **10 selesai**.
> Item 5–7 (`SG Migration`) **DITUNDA** per instruksi user (*tunda sampai saya minta; mungkin tidak perlu*). Item 9 (`PWA spec`) sudah siap — hanya butuh eksekusi lokal user. Item **11** (drift tracking migrasi 221/222/223) **SELESAI** 2026-09-17.
>
> **Catatan §5.7 no.11 — `check_migrations()` tidak akan pernah sepenuhnya bersih.** Fungsi itu melaporkan `DUPLICATE` untuk setiap `version` yang dipakai lebih dari satu berkas, padahal migration 219 sendiri menyatakan (dalam komentarnya) bahwa beberapa berkas boleh berbagi nomor versi: v176 (`176_fix_rownum_and_pgcrypto_path` + `176_fix_search_path_extensions`), v186, v208 (`208_fix_groupby` + `208_industry_tables_and_rpcs`), v215 (`215_ai_rag_access_and_rate_limits` + `215_gap_employee_fields`). Jadi 4 `DUPLICATE` itu ekspektasi, bukan drift. Yang benar-benar menandakan masalah adalah `UNAPPLIED` (sekarang 0).
>
> **Diperbaiki 2026-09-17 (migration 224).** Aturan `DUPLICATE` kini hanya menyala untuk duplikasi sungguh-sungguhan (versi **dan** slug sama), dan ditambah `VERSION_MISMATCH` (baris yang `version`-nya tidak cocok dengan prefiks nomor `filename` — kelas kesalahan yang muncul saat pendaftaran manual dan tidak terlihat oleh versi lama fungsi). Hasil: `check_migrations()` mengembalikan **0 issue** untuk berkas repo (150 saat itu; **152** setelah migrasi 225/226). `CREATE OR REPLACE` mempertahankan ACL, jadi REVOKE dari anon/PUBLIC (migration 221) tetap berlaku.
> Menurut §0.4–5 baris yang sudah selesai seharusnya KELUAR dari tabel ini; saat ini baris 2/3/4/10 dibiarkan bertanda ✅ agar jejaknya terlihat lebih dulu di `agentsLogs.md`, siap dipangkas pada pembersihan berikutnya.

---

## 5.7B STATE OPEN — INSTALLER BASELINE: AUTO-PROVISION OWNER (2026-09-18)

> Perubahan terbaru pada `supabase/scripts/install-baseline.mjs`: menambahkan mode
> auto-provision owner via Supabase Admin API agar instalasi baseline benar-benar
> satu perintah dari project kosong sampai bisa login owner.
>
> **Status saat ini:** kode sudah diubah + gate `check:types` 0 error + `lint` 0 error.
> **Belum dilakukan:** `npm run build`, `npm test`, dokumentasi README, commit/push/deploy,
> dan verifikasi smoke ke project kosong.

| No | Item | Prioritas | Status | Catatan |
|---|---|---|---|---|
| 1 | Jalankan `npm run build` + `npm test` untuk perubahan `install-baseline.mjs` | P1 | OPEN | `check:types` + `lint` sudah hijau; build + test belum dijalankan |
| 2 | Dokumentasi flag baru di `supabase/baseline/README.md` | P1 | OPEN | Tambahkan contoh pakai `--create-owner` + `--owner-password` + catatan keamanan |
| 3 | Verifikasi smoke installer dengan `--create-owner` ke project kosong | P1 | OPEN | Butuh project Supabase baru + env `SUPABASE_URL`/`SUPABASE_SERVICE_KEY` project baru |
| 4 | Commit + push + deploy perubahan installer | P1 | OPEN | Perubahan belum di-commit; §0.3 wajib commit→push→deploy |
| 5 | Catat hasil ke `agentsLogs.md` + pindahkan item selesai dari AGENTS.md | P2 | OPEN | Setelah verifikasi smoke + deploy |

### Catatan keamanan auto-provision
- `--create-owner` **ditolak** jika `SUPABASE_URL` repo menunjuk ke DB live (`verwobaejumvpagwynae`).
- Kredensial project (`SUPABASE_URL` + `SUPABASE_SERVICE_KEY`) diambil dari env repo, **bukan** dari argumen CLI.
- Password owner dikirim via Admin API; tidak masuk log/argumen setelah use.
- Hanya berlaku untuk project **baru/kosong**; installer tetap menolak project yang sudah berisi tabel tanpa `--force`.

## 5.8 STATE OPEN — WORK QUEUE: Temuan Audit SQL (WAJIB DISELESAIKAN)

> **Sumber:** audit menyeluruh 2026-09-17 — 150+ migrasi diparsing lalu **setiap temuan
> diverifikasi ke DB live** (read-only; satu probe tulis di dalam transaksi yang di-`ROLLBACK`).
> Laporan + data mentah: `agentsLogs.md` entri `[2026-09-17] Audit kesiapan instalasi`.
>
> **ATURAN WORK QUEUE (jangan dilanggar):**
> 1. Setiap temuan audit **WAJIB** jadi item bernomor di tabel ini dengan **Bukti** dan
>    **Definition of Done**. **Dilarang** menutup temuan sebagai komentar/prosa saja.
> 2. Item hanya boleh ditandai ✅ bila **DoD-nya terbukti** (perintah/query + hasil), bukan
>    karena "sudah dikerjakan".
> 3. Item ✅ hanya boleh **dihapus dari file ini setelah** hasilnya tertulis di `agentsLogs.md` (§0.4).
> 4. Dilarang menambah item "catatan" tanpa aksi; kalau tidak ada aksi, bukan item.
> 5. Item P0 wajib dikerjakan sebelum migrasi/fitur besar berikutnya.
>
> **Status di bawah diverifikasi ulang 2026-09-17** (bukan salinan catatan lama).

| ID | Prio | Masalah | Bukti (terverifikasi) | Definition of Done | Status |
|---|---|---|---|---|---|
| SQL-01 | ✅ | **Instalasi dari awal SUDAH JALAN** (dulu berhenti di `047:220`; replay pertama hari ini `136/156 sukses, 20 GAGAL`) | 20 berkas gagal saat replay pertama (000→229, 156 berkas). Akarnya: `047` bentrok bentuk `webhook_logs` vs `045`; `083` policy untuk tabel buatan `141`; `091` FK `user_roles_nrp_fkey` bertentangan dengan desain Owner; `062`/`206` constraint dipasang sebelum data dinormalkan; `172` GRANT ke fungsi yang belum ada; `175/176/178` skrip smoke memanggil RPC dengan data demo; `180/181` OVERLOAD fungsi industri + kolom `harvest_date` vs `date`; `183` `DROP VIEW` pada objek TABLE + `npwp_encrypted` tak ada; `199` `ura.role_id` tak ada; `201` ubah return type `jsonb`→`boolean`; `208_fix_groupby` jalan sebelum tabelnya dibuat; `221` REVOKE fungsi buatan `215` | **TERBUKTI 2026-09-18:** `node supabase/scripts/replay-fresh-install.mjs --mode=chain` → **156/156 berkas sukses, 0 GAGAL** (log: `supabase/baseline/replay-chain.md`). `140` kini pakai `'COAL'` (6 kutip ganda dibuang); `210`/`221`/`226` pakai guard `to_regprocedure`; `229` tanpa FK integer→text; `073` → `_legacy_get_estate_blocks_paged` | ✅ SELESAI — boleh dipangkas setelah entri `agentsLogs.md` ditulis |
| SQL-02 | **P2** (turun dari P1) | **25 tabel + 14 fungsi live tanpa sumber migrasi** — sekarang **tercakup**: ke-25 tabel ada di baseline (di-generate dari katalog live, bukan dari rantai), jadi instalasi perusahaan baru tidak kehilangan apa pun | Tabel: `ai_rate_limits`, `api_keys`, `api_rate_limits`, `dashboard_cache`, `user_consents`, `hr_shift_swaps`, `hr_audit_chain`, `hr_okr_results`, `hr_survey_responses`, `hr_task_board`, `safety_incidents`, `webhook_logs`, 5×`mining_*`, 5×`estate_*`, 3×`mill_*` — dipulihkan `008_restore_missing_objects.sql`. Fungsi: 13×`_legacy_*` + `worker_update_profile_legacy` — tidak dibuat rerantai, dan itu aman sekarang karena `172`/`210`/`221`/`226` memakai guard (`to_regprocedure`) sehingga ketidakhadirannya tidak menggagalkan apa pun. Terbukti: replay 156/156 dengan 14 fungsi itu tetap absen | **TERBUKTI 2026-09-18:** baseline memuat seluruh objek live — `verify-install-e2e.mjs` memasang ke project kosong dan mencocokkan **9/9 metrik** dengan live (208 tabel, 549 fungsi, 223 policy, 27 trigger, 285 partisi, 95 sequence, 4 cron job, cap 157). Sisa satu keputusan kecil: 14 `_legacy_*` di DB live dibuat ulang atau dihapus | OPEN (dampak instalasi sudah nol) |
| SQL-03 | ✅ | **5 materialized view hilang + 3 cron gagal setiap jam** | `pg_matviews` public = 0; 3 job refresh gagal 94/94/189× | **TERBUKTI 2026-09-18:** migration `228_retire_dead_mv_cache_layer.sql` men-drop 3 job + fungsi refresh `mv_*` (5 MV terbukti tidak dibaca siapa pun — 0 referensi di `src/`, `dashboard_cache` yang dipakai). Live: **4 cron job aktif, 0 kegagalan**; ke-4 job sudah diuji jalan bersih di transaksi yang di-ROLLBACK | ✅ SELESAI — boleh dipangkas setelah entri `agentsLogs.md` ditulis |
| SQL-04 | **P1** | **`hr_okrs` beda skema: live 6 kolom vs migrasi 141 (10 kolom)** | live: `id,nrp,periode,objective,status,created_at`; `141:545` mendefinisikan +`key_result,target_value,current_value,updated_at,created_by,updated_by`. `IF NOT EXISTS` → no-op di live | Satu definisi disepakati sebagai benar; `information_schema.columns` = definisi migrasi (atau migrasi diperbaiki bila live yang benar) | OPEN |
| SQL-05 | **P1** | **3 RLS policy tanpa sumber migrasi** | `candidate_pipeline.admin_read_candidate_pipeline`, `dashboard_cache.dc_admin`, `vacancies.admin_read_vacancies` (ada di live, 0 `CREATE POLICY` di migrasi, tidak ada generator loop) | Ketiganya dibuat di migrasi baru (atau dibuang bila tidak dipakai) | OPEN |
| SQL-06 | **P1** | **9 tabel RLS enabled tapi TIDAK forced** | `employees_core`, `employees_extended`, `fatigue_data`, `heavy_equipment`, `jsa_data`, `production_daily`, `safety_incidents`, `schema_migrations`, `simper_data` | Keputusan user (FORCE membuat **pemilik** tunduk policy → berisiko ke SQL Editor/dashboard); bila disetujui → `FORCE ROW LEVEL SECURITY` + verifikasi 0 tersisa | OPEN — **butuh keputusan user** |
| SQL-07 | **P1** | **Default privilege Supabase bocor ke `anon`** (fungsi baru dapat EXECUTE, tabel baru dapat ALL) | `pg_default_acl`: objtype `f` → anon/authenticated/service_role; objtype `r` → anon/authenticated/service_role. Akibat nyata: 4 RPC penulis terbuka (sudah ditutup migrasi 226); `anon` EXECUTE live = **128** fungsi | `ALTER DEFAULT PRIVILEGES` mencabut `anon` dari fungsi/tabel baru + daftar putih login eksplisit; tes penjaga tetap hijau | OPEN |
| SQL-08 | **P2** | **`hr_attendance_partitioned` = struktur mati** (0 baris) dan `RENAME` masih dikomentari | Kedua tabel absensi **0 baris**; `141:1403` masih `-- ALTER TABLE hr_attendance_partitioned RENAME TO hr_attendance`; hanya fungsi 225/227 yang menyentuh namanya | Keputusan adopsi (jalankan RENAME + pindahkan penulis data) **atau** dibuang (drop partisi + index + cron 225); tidak ada dua tabel absensi paralel | OPEN — **butuh keputusan user** |
| SQL-09 | **P2** | **Duplikat `CREATE` dalam satu berkas** (dead code, bukan konflik) | `141:545` & `141:1911` `hr_okrs`; `141:558` & `141:1924` `hr_surveys` (definisi **identik**, diverifikasi); `183` view `employees_master` 2× | Duplikat dihapus tanpa mengubah hasil replay | OPEN |
| SQL-10 | **P2** | **79 nomor versi tanpa berkas** — repo bukan histori lengkap | Nomor kosong per audit 2026-09-17: 2,4,8–26,29–32,36,37,41,46,49,56,64,66–70,**74**,85,94,96–99,103–109,112–119,121–129,142–153,170 (2026-09-18: nomor **008** kini terisi `008_restore_missing_objects.sql`, nomor **229** terisi `229_fresh_install_fk_repair.sql` — keduanya berkas perbaikan fresh-install, bukan nomor versi yang hilang. Sisa 77 nomor tetap kosong — histori tetap tidak utuh). `140:2` menyebut *"…were in 074 (deleted)"* | Ada pernyataan resmi di dokumen bahwa `000–230` bukan histori utuh + jalur instalasi resmi menggantikannya. | **TERBUKTI 2026-09-18:** (a) rantai `000→230` replay bersih **157/157**; (b) baseline replay bersih **2/2 + idempoten 2/2** dan lolos `verify-install-e2e` (metrik & ACL = live); (c) pernyataan resmi **sudah ditulis** di `supabase/baseline/README.md` §1 (dua jalur + kapan pakai yang mana). Tidak ada lagi yang bisa dituntut dari item ini | ✅ SELESAI — boleh dipangkas setelah entri `agentsLogs.md` ditulis |
| SQL-11 | **P0** | **`schema_migrations` menandai berkas yang efeknya TIDAK ada di live** — registry bukan bukti penerapan | 20 dari 21 berkas yang gagal di replay pertama hari ini JUGA terdaftar sebagai "sudah diterapkan". Diverifikasi ke live 2026-09-18: `verify_mfa`/`verify_worker_otp`/`verify_admin_otp` masih `jsonb` (201 minta `boolean`); `auth_testing_override` **tidak punya policy** (199 dulu gagal di `role_id`); `get_estate_blocks` hanya versi nol-argumen (180/181 minta `p_bu_id`/`p_site_code`); `user_role_assignments` tidak punya `role_id`; `attributes`/`forum_posts` tidak punya kolom audit `054`; `employees_core` tidak ada saat 189/206/214/215 dijalankan | Putuskan & jalankan salah satu: (a) terapkan ulang **versi yang sudah diperbaiki** ke live, atau (b) tandai eksplisit di `schema_migrations`/dokumen sebagai "tidak diterapkan / superseded" supaya label "sudah diterapkan" tidak menyesatkan. Sebelum itu, jangan percaya registry sebagai bukti | OPEN — **butuh keputusan user** |
| SQL-12 | **P2** | **Kolom tabel industri & beberapa tabel lain masih beda antara rantai dan live** | Diukur `diff_chain_vs_live_columns.mjs` (2026-09-18, database scratch hasil replay vs live): `estate_harvest` `harvest_date` vs `date` (**sudah diperbaiki di 180**); sisa `mining_equipment` (rantai: `category/fuel_level/hours_run/location/next_maintenance` vs live: `operator_nama/operator_nrp/type`) dan `mining_simper` (rantai: `applicant_name/area_hectare/commodity/company/issue_date/notes/simper_no` vs live: `issued_date/nama/nrp/simper_type/site`); `assets` & `forum_posts` punya kolom berlebih di rantai (`created_by`, `updated_at`, `updated_by`) | Kolom disamakan (rename/add) ATAU perbedaan dinyatakan resmi beserta alasannya; jalankan `node .freebuff/audit/diff_chain_vs_live_columns.mjs` sebagai bukti ulang | OPEN |
| SQL-14 | ✅ | **Baseline instalasi mewarisi identitas perusahaan sumber + 3 bug generator** (ditemukan 2026-09-18 saat menyiapkan instalasi satu-perintah) | (1) `branding.company_name` ikut ter-dump → perusahaan baru memakai merek kita; (2) `company_config.owner_email`/`ceo_email` ikut ter-dump, dan `get_owner_email()` punya fallback hardcoded `'owner@insightwos.com'` → owner perusahaan baru **tidak bisa login** selain dengan email kita; (3) `schema_migrations.version` ditulis `parseInt` → `check_migrations()` melaporkan **59 VERSION_MISMATCH** di instalasi baru; (4) ACL: `tables` memakai `not relispartition` sehingga 48 partisi mewarisi hak `anon` (instalasi baru lebih terbuka dari live); (5) trigger hanya diiterasi untuk tabel → 3 trigger `INSTEAD OF` di view `employees_master` hilang, membuat view itu read-only tanpa error | **TERBUKTI 2026-09-18:** migrasi `230` fail-closed (`get_owner_email()` → NULL, `owner_login` beri pesan tindak-lanjut); uji dalam transaksi yang di-ROLLBACK: owner sah `ok:true`, email lain ditolak, config kosong → tidak ada email diterima. Generator: `EXCLUDED_ROWS` + branding netral + pemindai kebocoran domain; harness hanya menjalankan berkas `NNN_*.sql`. Bukti akhir: `verify-install-e2e` → **PASS**, 9/9 metrik = live, `check_migrations()` 0 issue, trigger 27/27, ACL 0 selisih, idempoten | ✅ SELESAI — boleh dipangkas setelah entri `agentsLogs.md` ditulis |
| SQL-13 | **P1** | **21 migrasi historis diperbaiki untuk jalur instalasi dari awal → checksum registry tidak lagi cocok dengan berkasnya** | Berkas yang diubah 2026-09-18: `062, 073, 083, 091, 140, 172, 175, 176, 178, 180, 181, 183, 199, 201, 206, 208_fix_groupby, 221, 226` (+ `008/229` dari sesi sebelumnya). Perbaikannya menyentuh JALUR INSTALASI (guard/urutan/idempotensi), **bukan** objek live — live tidak diubah sama sekali hari ini. `check_migrations()` tetap **0 issue** karena ia tidak membandingkan checksum berkas; `verify_migration_checksum` akan melaporkan BEDA | Putuskan: (a) re-stamp checksum berkas-berkas itu di `schema_migrations` (dengan catatan tanggal+alasan), atau (b) tambahkan mode `--restamp` pada `apply-migration.mjs` + daftar "diperbaiki maju" yang ditinjau manual. Bukti: `select filename from schema_migrations where filename in (...)` + `verify_migration_checksum` per berkas | OPEN — **butuh keputusan user** |

### Sudah diverifikasi **BUKAN masalah** — jangan diinvestigasi ulang

> Semua di bawah ini awalnya terlihat seperti drift/kerusakan, lalu **terbukti salah** setelah
> dicek ke kode/DB. Dicatat supaya tidak memakan waktu agent berikutnya.

| Yang tampak rusak | Kenapa ternyata bukan masalah |
|---|---|
| 18 "ACL mismatch" migrasi vs live | `172_hardening_grants.sql:13-15` melakukan `REVOKE EXECUTE ON ALL FUNCTIONS ... FROM PUBLIC, anon, authenticated` lalu re-grant daftar putih; `141:2599-2611` melakukan hal sama secara dinamis. Live = hasil yang dimaksud |
| 19 trigger `trg_audit_*` "tanpa sumber" | Dibuat dinamis oleh loop `141:2332` (`trig_name := 'trg_audit_' || tbl`) |
| 102 dari 105 policy "tanpa sumber" | Dibuat dinamis: `141:607` (`rls_authz_`), `141:2218/2333` (`rls_%I_read/_write/_select`), `208` (`select_auth`, `all_service`) |
| 87 dari 95 sequence "tanpa CREATE" | Sequence implisit dari kolom `SERIAL` — tidak pernah ditulis eksplisit |
| 4 versi migrasi `DUPLICATE` (176/186/208/215) | Sah per komentar migrasi 219 (beberapa berkas boleh berbagi nomor versi) |
| `get_enabled_modules_legacy_noarg` "tanpa sumber" | Di-rename oleh migrasi **205** (`ALTER FUNCTION ... RENAME TO`) |
| `review_360` di-drop `058:137` lalu dirujuk `083:240` | Rujukan itu dibungkus `IF EXISTS (information_schema.tables)` → aman |
| 272 grant tabel ke `anon` | Terverifikasi **0 tabel** dengan grant anon tapi RLS mati, dan **0 tabel** RLS tanpa policy → tertutup RLS |
| 240 "partisi" | Angka itu termasuk **index** partisi (`relispartition` juga benar untuk index); partisi nyata = 57 |
