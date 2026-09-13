# Tunda Plan: Login Refactor — GAS → Supabase Auth Pattern

> **Status:** PLAN (Tertunda) — Dibuat 2026-09-12
> **Goal:** Ubah login Worker + Dashboard ikut pola Admin (email + password). Tambah menu DAFTAR|CEK|MFA. OTP tetap ada. MFA optional=worker, wajib=admin/dashboard.

---

## 1. Analisis Kondisi Login Saat Ini

| | Admin | Worker | Dashboard |
|---|---|---|---|
| **Auth** | Supabase Auth (email @insightwos.com) | login_worker RPC + fast path Supabase Auth | Sama |
| **OTP** | generate_admin_otp() | generate_worker_otp(nrp,nik,pass) | Sama |
| **MFA** | mfa-service edge | Sama | Sama |

**Flow login worker saat ini (Home.jsx):**
NRP + NIK + Password → login_worker → reset_required/MFA/provisionWorkerAuth → redirect

**Flow login admin:**
Email + Password → syncSupabaseAuth → get_user_context_by_auth_id → MFA → redirect

---

## 2. Yang Ingin Diubah
1. Worker + Dashboard login → email + password (ikut admin)
2. Menu DAFTAR|CEK|MFA link di bawah login form
3. Admin + Dashboard: MFA wajib jika aktif (optional)
4. OTP tetap tersedia
5. MFA optional=worker, wajib jika sudah di-aktifkan

---

## 3. Rintangan Teknis
- login_worker(nrp, nik, password) dipakai edge+audit — jangan ganti signature
- provisionWorkerAuth wajib untuk auth.uid() di RLS
- F-5: NRP002-004,006-008,010 sha256 di worker_passwords
- E2E test hardcode loginAsWorker(NRP+NIK+pw) — update mock pakai helper

---

## 4. Rencana (Phased)

### Phase 1: DB
- Buat RPC `login_worker_by_email(email, password)` — lookup nrp → call login_worker
- Helper `get_nrp_by_email(email)`

### Phase 2: UI
- Home.jsx: ganti credential form worker+dashboard → Email+Password
- Tambah menu DAFTAR(/daftar)|CEK(/cek-status)|MFA(/mfa-setup)
- Flow: email+pw → login_worker_by_email → reset/MFA → provisionWorkerAuth → redirect per-tab

### Phase 3: OTP
- Link "Masuk OTP" di Home.jsx
- Flow tetap pakai NRP+NIK+password → generate_worker_otp → verify_worker_otp

### Phase 4: MFA
- Admin: sudah ada MFA check di submitAdminCredentials (Home.jsx:236-246)
- Worker/Dashboard: sudah ada di finalizeWorkerSession (Home.jsx:116-138)

### Phase 5: Edge Sync
- Update worker-auth-sync/index.ts → provisioning via email

### Phase 6: Tests
- Update mock-supabase.js loginAsWorker → email+pw
- Tambah handler login_worker_by_email di handleRpc()

### Phase 7: Deploy
1. supabase db push
2. deploy edge worker-auth-sync
3. npm run lint+test+build
4. npx playwright test
5. npx vercel --prod

---

## 5. Email Mapping
- Worker: `lower(trim(nrp))@insightwos.internal` (sintetis — konsisten dengan worker-auth-sync)
- Admin: `email@insightwos.com` (real, di auth.users)

---

## 6. Files yang Perlu Diubah
1. `supabase/migrations/XXX_login_worker_by_email.sql` — RPC baru
2. `supabase/functions/worker-auth-sync/index.ts` — path email+password
3. `src/pages/Home.jsx` — credential form + menu links + flow
4. `tests/e2e/helpers/mock-supabase.js` — update loginAsWorker
5. `src/components/MfaSetup.jsx` — TOTP enroll/disable page (baru)