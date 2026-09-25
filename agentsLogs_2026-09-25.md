# agentsLogs_2026-09-25.md — log harian 2026-09-25 (WIB)

## [2026-09-25] E2E DONE ALL — 3-run stabil, 0 fail/flaky/skip

- **Status:** suite E2E live selesai — 3 run berturut (RUN 6, 7, 8) **70/70 pass, 0 fail, 0 flaky, 0 skip**.
- **Fix 4 lapis (flake E2E):**
  1. **OTP identity spread** — 8 akun admin, maks 2 OTP per identitas per run (melewati limit `pwreset_login_otp` 3/15 mnt).
  2. **Helper tunggu OTP / limiter** — 1 wait + 1 retry sebelum submit.
  3. **`fillStable` + `openHome` networkidle** — men scapego re-render React yang menyapu form (`Server menerima password kosong → 200 "Password salah"`).
  4. **`actionTimeout` 15000 + `navigationTimeout` 45000 + `clickStable`**.
- **Helper baru (2):** `tests/e2e/helpers/live-accounts.ts` (OTP_ASSIGNMENT + `assertOtpBudget()` fail-fast bila drift) dan `tests/e2e/helpers/live-login.ts` (login live 2 langkah password→OTP, admin/dashboard/owner/worker).
  **Kredensial HANYA dari env** (`.env.local`, gitignored) — nol literal password di kedua file.
- **15 spec opt-in LIVE** kini aktif dengan assertion nyata (bukan mock).
- **Cleanup DB live:** `worker_passwords` attempts/blocked_until direset → `NRP002=0, NRP003=0, NRP007=0` (sebelumnya NRP003=5 & NRP007=5 dengan `blocked_until` aktif).
- **Gate (tree saat commit):** `check:types` EXIT 0 (12,1 s) · `lint` EXIT 0 (71,6 s) · secret scan: 0 hit `postgresql://|SERVICE_ROLE|api_key` · password literal baru: 0.
- **Commit:** `3b46f69` — `test(e2e): DONE ALL — 0 fail/flaky/skip, 3-run stable, OTP identity spread + stable fill + clickStable` (10 file, +813/−249: 8 spec + `playwright.config.ts` + 2 helper baru).
- **Catatan:** literal `Test123!`/`Admin123!` yang masih ada di `tests/e2e/helpers/mock-supabase.ts` bersifat **pre-existing** (file tidak diubah commit ini) dan hanya dipakai harness mock — bukan kredensial nyata.
- **Dampak lintas-page: worker → admin → dashboard → owner** — semua role kini ter-test login live end-to-end (worker NRP+NIK, admin & dashboard password→OTP, owner password) dengan jalur yang sama seperti production.
