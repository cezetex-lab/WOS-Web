# ================================================================
# Migrasi Region Singapore (ap-southeast-1) — Runbook
# Keputusan user: 2026-09-15 (§5.5 AGENTS.md) — SEMUA sekaligus.
# Project live: verwobaejumvpagwynae (ap-northeast-1 / Tokyo saat ini)
# ================================================================

## Konteks
- Alasan: user utama Indonesia → RTT Tokyo ~60-100ms; target Singapore <30ms.
- Scope: Supabase project + Vercel functions/region + Upstash Redis + env.
- Ini BUKAN 1x klik — Supabase TIDAK mendukung pindah region in-place.

## Langkah (urutan wajib, jangan skip):

### 1. Persiapan (NON-DISRUPTIVE — bisa sekarang)
- [ ] Verifikasi Upstash instance region (`alive-robin-191313`) — apakah Tokyo atau Singapore?
  - Jika bukan Singapore: buat instance baru di Singapore; simpan URL+token baru.
- [ ] Backup DB: `pg_dump` core tables (pg_cron, employees_core, audit_log) → arsip lokal/gitignored.
  - RPO 24h / RTO 4h (§9 DR) tetap berlaku.
- [ ] Catat semua env: `.env.local`, Vercel env vars (Dashboard → Settings → Environment Variables).

### 2. Buat Project Baru (Singapore)
- [ ] Buat project Supabase baru di `ap-southeast-1` (Singapore) via dashboard.
- [ ] Salin `anon` / `service_role` keys baru → `.env.local.sg` (sementara).

### 3. Apply Migrations + Restore Data
- [ ] Apply 146 migrations (`supabase/migrations/*.sql`) ke DB baru (urutan: `schema_migrations` tracking).
  - Gunakan script `.freebuff/audit/apply_mig*.py` (pola split `;` per statement).
- [ ] Restore data: `pg_dump` dari Tokyo → `pg_restore` ke Singapore (PITR jika tersedia).
- [ ] Post-verify: `SELECT count(*) FROM employees_core; SELECT count(*) FROM schema_migrations;`

### 4. Update Environment
- [ ] `.env.local`: `DATABASE_URL`, `SUPABASE_URL`, `UPSTASH_REDIS_REST_URL`/`TOKEN`.
- [ ] `.env.local`: `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`.
- [ ] Vercel env vars: update ke key baru (Dashboard atau `vercel env add`).
- [ ] Edge functions env (`vercel.json` atau dashboard): `UPSTASH_*`, `SUPABASE_*`.

### 5. Deploy Frontend (Smoke Test)
- [ ] `npm run build` → `npx vercel --prod` (alias domain `insightwos.vercel.app`).
- [ ] Smoke 4 pages: worker → admin → dashboard → owner (§0.5 G6).
- [ ] E2E: `full-sweep`, `tab-click-test`, `role-change`.

### 6. Cutover Domain / Switch Traffic
- [ ] Update domain (jika menggunakan custom domain, bukan `vercel.app`) → arahkan ke deployment baru.
- [ ] Atau jika tetap `vercel.app`: alias sudah otomatis (tidak perlu cutover terpisah).

### 7. Monitoring Post-Migrasi
- [ ] Backup status baru (Supabase automated daily) — verifikasi 1 hari pertama.
- [ ] Audit_log growth — verifikasi `audit_chain` hash tetap valid (`verify_audit_chain()`).
- [ ] Session count — verifikasi tidak ada anomali (login spike karena user login ulang).

## Catatan Keamanan / Jebakan (§5.5)
- CSP `connect-src alive-robin-191313.upstash.io`: jika instance baru Singapore punya URL berbeda, update `vercel.json` CSP.
- Edge `worker-auth-sync`: pastikan `UPSTASH_*` benar sebelum deploy, karena provisioning bergantung pada cache (meski saat ini underutilized).
- Password `postgres.verwobaejumvpagwynae` di `.env.local`: JANGAN pernah commit `.env*` (gitignored sudah benar).

## Status Saat Ini
- [x] Konfirmasi region saat ini: Tokyo (`ap-northeast-1`)
- [x] Konfirmasi scope: SEMUA (Supabase + Vercel + Upstash + env)
- [x] Konfirmasi user decision: 2026-09-15 (§5.5) — belum dijadwalkan
- [ ] Eksekusi: belum dimulai (tunggu persetujuan user untuk langkah 1)
