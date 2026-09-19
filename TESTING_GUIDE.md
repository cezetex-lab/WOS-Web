# TESTING_GUIDE.md — GATE, E2E, DAN DAFTAR KERJA PASCAAUDIT

> **Pecahan dari `AGENTS.md` (2026-09-19).** Isi di bawah ini dipindahkan apa adanya —
> nomor bagian lama (`§5.7`, `§6.4`, `§7.4`, …) sengaja DIPERTAHANKAN agar rujukan lama tetap
> bisa ditelusuri. Peta bacanya ada di `AGENTS.md` (Reading Map). Jangan menaruh riwayat
> pekerjaan selesai di berkas ini — itu milik `agentsLogs.md`.

> **Satu sumber untuk §5.7** (termasuk butir 11 tentang `schema_migrations`) —
> `MIGRATION_GUIDE.md` merujuk ke sini, bukan menyalin. Jebakan vitest/worker ada di
> `ENVIRONMENT_TRAPS.md` §6.7. Gate lintas-page (§0.5 G6) tetap di `AGENTS.md` karena ia
> bagian dari alur kerja wajib, bukan sekadar teknik tes.

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
