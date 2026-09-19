# OPEN_WORK.md — STATE OPEN NON-SQL (WAJIB DITUTUP ATAU DIBUANG SECARA EKSPLISIT)

> **Pecahan dari `AGENTS.md` (2026-09-19).** Isi di bawah ini dipindahkan apa adanya —
> nomor bagian lama (`§5.7`, `§6.4`, `§7.4`, …) sengaja DIPERTAHANKAN agar rujukan lama tetap
> bisa ditelusuri. Peta bacanya ada di `AGENTS.md` (Reading Map). Jangan menaruh riwayat
> pekerjaan selesai di berkas ini — itu milik `agentsLogs.md`.

> Work Queue temuan SQL tinggal di `AGENTS.md` §5.8. Berkas ini memuat state OPEN yang
> bukan temuan SQL: infrastruktur (Upstash/region SG), audit `Readme/upppp.txt`, dan
> installer baseline. Aturan yang sama berlaku: setiap item butuh **bukti** dan
> **Definition of Done**; item yang ternyata bukan masalah dipindah ke tabel "bukan
> masalah", bukan dibiarkan sebagai OPEN palsu.

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
      maintenance window; RPO/RTO `DISASTER_RECOVERY.md` tetap berlaku.


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
- [ ] **F2 item infra belum masuk roadmap** (`ROADMAP.md`): Upstash cache tier (§5.5), migrasi region SG (§5.5),
      UI form 14 kolom karyawan (§5), PWA offline tests (§4), hardening CSP (S4/S11).
- [ ] **F3 tumpang tindih antar phase:** Shift Swap (Phase 1 vs worker needs), Payslip (Phase 1 vs
      export Xero/MYOB Phase 2), Team Dashboard 2.2 vs Dashboard/OwnerDashboard yang sudah ada,
      Push Notifications ditempatkan SETELAH item yang memprasyaratkannya.
- [ ] **F4 urutan + item obsolete.** Payroll Engine + Payslip lebih dulu (worker = hulu; output
      langsung dirasakan worker via web/PWA yang sudah ada), mobile app bukan blocker. FuturePlans
      baris 42 & 940 masih menyuruh "fix 8 functions missing search_path (migration 176)" —
      OBSOLETE (`SECURITY.md` §7.6: 0 violations, pg_cron 6 jobs aktif).


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
