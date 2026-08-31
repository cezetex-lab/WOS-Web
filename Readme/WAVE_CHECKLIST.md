# 🚀 insightWOS v3.0 — Implementation Wave Checklist

> **Goal:** Dari 37.6% → 100% implementasi dalam 7 wave bertahap
> **Created:** 29 Agustus 2026 | **Branch:** migrasi-vite

---

## 📊 Status Awal

| Metrik | Sebelum | Target |
|--------|---------|--------|
| **Fitur Done** | 53/141 (37.6%) | 141/141 (100%) |
| **Fitur Partial** | 14/141 (9.9%) | 0 |
| **Fitur Belum** | 74/141 (52.5%) | 0 |
| **Tabel DB** | 57 | 82 (+25 baru) |
| **RPC Functions** | 65+ | 100+ |

---

## ⚡ WAVE 0: Database Setup (30 menit)
> **Prerequisite untuk semua wave lainnya**

### 0.1 Run Migrations di Supabase SQL Editor
- [ ] Buka https://supabase.com/dashboard → SQL Editor
- [ ] **Copy-paste & jalankan** `supabase/migrations/027_seed_remaining_tables.sql`
- [ ] **Copy-paste & jalankan** `supabase/migrations/028_admin_worker_rpcs.sql`
- [ ] **Verify:** Jalankan query di SQL Editor:
  ```sql
  SELECT 'hr_finance_kpi' as tbl, count(*) FROM hr_finance_kpi
  UNION ALL SELECT 'hr_kpi_config', count(*) FROM hr_kpi_config
  UNION ALL SELECT 'hr_skills', count(*) FROM hr_skills
  UNION ALL SELECT 'hr_tasks', count(*) FROM hr_tasks
  UNION ALL SELECT 'announcements', count(*) FROM announcements
  UNION ALL SELECT 'hr_overtime', count(*) FROM hr_overtime;
  ```
- [ ] **Verify RPC:** Jalankan test query:
  ```sql
  SELECT * FROM get_worker_attendance('NRP001');
  SELECT * FROM get_worker_tasks('NRP001');
  SELECT * FROM admin_get_budget();
  SELECT * FROM admin_get_timesheet();
  ```

### 0.2 Smoke Test Basic Login
- [ ] Login Worker: NRP001 / Password123 → /worker
- [ ] Login Admin: Admin123 → /admin
- [ ] Login Manager: NRP001 / Password123 → /dashboard
- [ ] Logout semua role berfungsi

**Wave 0 Done ✅** = Database sehat, login jalan

---

## 🔴 WAVE 1: Critical P1 Fixes (2-3 jam)
> **Fitur P1 yang belum ada — wajib sebelum go-live**

### 1.1 Ubah Password Admin (Fitur #120)
- [ ] Buat RPC `admin_change_password(p_old, p_new)`
- [ ] Buat form di `/admin/settings` (bukan static lagi)
- [ ] Update `worker_passwords` table untuk admin
- [ ] Test: Login admin → ganti password → login lagi dengan password baru

### 1.2 Reset Password Pekerja (Fitur #111)
- [ ] Buat RPC `admin_reset_worker_password(p_nrp, p_new_password)`
- [ ] Tambah tombol "Reset Password" di `/admin/employees` detail modal
- [ ] Test: Admin reset password NRP005 → worker login dengan password baru

### 1.3 Status Kerja PKWT Expiry Alert (Fitur #18)
- [ ] Buat RPC `get_pkwt_expiry_alert()`
- [ ] Query: `SELECT * FROM employees_master WHERE status_kerja='PKWT' AND tanggal_masuk + interval '2 years' < NOW() + interval '6 months'`
- [ ] Tambah alert di Admin Dashboard (metric card PKWT)
- [ ] Tambah notifikasi ke `hr_notifications` untuk PKWT yang akan habis
- [ ] Test: Cek admin dashboard menampilkan PKWT expiry count

### 1.4 Nonaktifkan Akses Sistem (Fitur #138)
- [ ] Buat RPC `admin_deactivate_worker(p_nrp)`
- [ ] Update `worker_passwords.is_active = false` + `user_roles` disable
- [ ] Tambah tombol "Deactivate" di employee detail
- [ ] Buat pg_cron schedule: `SELECT deactivate_expired_pkwt();`
- [ ] Test: Deactivate NRP028 → worker tidak bisa login

### 1.5 Session Token (Upstash) (Fitur #100) — P1 tapi bisa di-skip sementara
- [ ] **Note:** localStorage session sudah cukup untuk MVP
- [ ] **Skip untuk sekarang** — implementasi di Wave 6

### 1.6 RLS Policies (Fitur #101) — P1 tapi generic sudah cukup
- [ ] **Note:** Generic "Allow all for service role" sudah jalan
- [ ] **Skip untuk sekarang** — upgrade di Wave 6

**Wave 1 Done ✅** = Fitur kritis admin selesai, akses aman

---

## 🟡 WAVE 2: Fix Partial Features (2-3 jam)
> **14 fitur partial → fully functional**

### 2.1 Update Profil (Fitur #11)
- [ ] Buat RPC `worker_update_profile(p_nrp, p_nama, p_email, p_no_hp, p_alamat)`
- [ ] Tambah form edit di `/worker/profile`
- [ ] Tambah tombol "Edit Profil" → modal form
- [ ] Test: Worker update nama → cek di admin

### 2.2 Pengajuan Lembur (Fitur #21)
- [ ] Buat RPC `worker_submit_overtime(p_nrp, p_date, p_hours, p_reason)`
- [ ] Tambah form pengajuan di `/worker/overtime`
- [ ] Hitung rate: 1.5x (hari biasa), 2x (hari libur), 3x (malam)
- [ ] Test: Submit lembur → cek di admin overtime

### 2.3 Pengajuan Training (Fitur #24)
- [ ] Buat RPC `worker_request_training(p_nrp, p_code, p_reason)`
- [ ] Tambah form di `/worker/learning`
- [ ] Set status = 'REQUESTED' di `hr_learning`
- [ ] Test: Request training → cek di admin learning

### 2.4 Continuous Performance (Fitur #37)
- [ ] Pastikan `get_worker_kpi` mengembalikan data lengkap
- [ ] Tambah trend chart di `/worker/kpi` (periode sebelumnya)
- [ ] Tambah badge: Excellent/Good/Needs Improvement/At Risk
- [ ] Test: Buka /worker/kpi → ada chart + badge

### 2.5 Performance Trend Tim (Fitur #39)
- [ ] Pastikan `get_continuous_perf_team` berfungsi
- [ ] Tambah mini chart di Manager Dashboard
- [ ] Tambah tab "Team Performance" di /dashboard
- [ ] Test: Manager login → lihat trend tim

### 2.6 Compensation Intelligence (Fitur #42)
- [ ] Pastikan `get_my_compensation_intelligence` berfungsi
- [ ] Tambah komparasi: "Gaji Anda vs Rata-rata Tim"
- [ ] Test: Worker cek compensation → ada benchmark

### 2.7 Subtree View (Fitur #15)
- [ ] Pastikan `get_subtree_data` mengembalikan data lengkap
- [ ] Tambah visualisasi tree di `/admin/org`
- [ ] Test: Buka /admin/org → ada tree view

### 2.8 Pencarian Karyawan (Fitur #130)
- [ ] Pastikan DataTable search berfungsi di `/admin/employees`
- [ ] Tambah search by NRP, nama, divisi, posisi
- [ ] Tambah filter dropdown: divisi, status, posisi
- [ ] Test: Search "NRP005" → muncul hasil

**Wave 2 Done ✅** = Semua fitur partial fully functional

---

## 🟢 WAVE 3: Self-Service Forms (3-4 jam)
> **Worker self-service yang belum ada**

### 3.1 Pengajuan Izin (Fitur #22)
- [ ] Buat RPC `worker_submit_izin(p_nrp, p_date_from, p_date_to, p_reason)`
- [ ] Tambah form di `/worker/leave` (tab "Izin")
- [ ] Insert ke `hr_requests` dengan type='IZIN'
- [ ] Test: Submit izin 1 hari → cek admin requests

### 3.2 Pengajuan Sakit (Fitur #23)
- [ ] Buat RPC `worker_submit_sakit(p_nrp, p_date, p_note, p_mcu_attachment)`
- [ ] Tambah form di `/worker/leave` (tab "Sakit")
- [ ] Insert ke `hr_requests` dengan type='SAKIT'
- [ ] Test: Submit sakit → cek admin requests

### 3.3 Multi-step Form (Fitur #28)
- [ ] Buat komponen `MultiStepForm.jsx`
- [ ] Steps: Pilih Type → Isi Detail → Upload Bukti → Review → Submit
- [ ] Untuk pengajuan cuti/lembur/izin/sakit
- [ ] Test: Submit cuti via multi-step → success

### 3.4 Dynamic Approval Workflow (Fitur #29)
- [ ] Buat tabel `approval_config` (create table)
- [ ] Buat RPC `get_approval_config(p_type)` — siapa yang approve
- [ ] Update `approve_team_request` — auto-assign ke atasan
- [ ] Test: Submit request → otomatis assign ke atasan NRP002

### 3.5 Bulk Approve/Reject (Fitur #3)
- [ ] Tambah checkbox multi-select di `/admin/requests`
- [ ] Tambah tombol "Approve All" / "Reject All"
- [ ] Buat RPC `admin_bulk_approve(p_ids, p_status)`
- [ ] Test: Select 3 requests → approve semua → status berubah

**Wave 3 Done ✅** = Worker bisa submit semua jenis pengajuan

---

## 🔵 WAVE 4: Admin Features (3-4 jam)
> **Admin power features yang belum ada**

### 4.1 Import Universal (Fitur #113)
- [ ] Buat komponen `ImportExcel.jsx`
- [ ] Support CSV + XLSX (gunakan library xlsx)
- [ ] Auto-map columns ke tabel target
- [ ] Buat RPC `admin_import_data(p_table, p_data_json)`
- [ ] Test: Import 5 employees dari CSV → muncul di /admin/employees

### 4.2 Backup Now (Fitur #114)
- [ ] Buat RPC `admin_backup_now()` → export semua tables ke JSON
- [ ] Download sebagai file
- [ ] Test: Click "Backup" → download JSON file

### 4.3 Reset Password Pekerja (sudah di Wave 1)
- [ ] Sudah selesai di Wave 1

### 4.4 Org Chart Interaktif (Fitur #16)
- [ ] Buat komponen `OrgChart.jsx` dengan tree visualization
- [ ] Drag-and-drop untuk reorganize
- [ ] Replace factory page di `/admin/org`
- [ ] Test: Buka /admin/org → ada interactive tree

### 4.5 Riwayat Mutasi (Fitur #17)
- [ ] Buat tabel `employee_mutations`
- [ ] Buat RPC `get_employee_mutations(p_nrp)`
- [ ] Tambah tab "Mutasi" di employee detail
- [ ] Test: Lihat riwayat mutasi karyawan

### 4.6 Manajemen Lowongan (Fitur #5)
- [ ] Buat tabel `vacancies`
- [ ] Buat RPC `admin_get_vacancies()`
- [ ] Buat page `/admin/vacancies`
- [ ] Test: Create vacancy → muncul di list

### 4.7 Pipeline Pelamar (Fitur #6)
- [ ] Buat tabel `candidate_pipeline`
- [ ] Buat RPC `admin_get_pipeline()`
- [ ] Buat page `/admin/pipeline` dengan kanban view
- [ ] Test: Add candidate → drag ke stage berikutnya

**Wave 4 Done ✅** = Admin bisa manage data secara lengkap

---

## 🟣 WAVE 5: Advanced Analytics (2-3 jam)
> **Charts, AI insights, dan analytics yang belum ada**

### 5.1 Analytics Dashboard Charts (Fitur #122 — extend)
- [ ] Tambah chart di `/admin/payroll` (pie chart distribusi gaji)
- [ ] Tambah chart di `/admin/learning` (bar chart completion)
- [ ] Tambah chart di `/admin/surveys` (gauge eNPS score)
- [ ] Tambah chart di `/dashboard` (trend line KPI)
- [ ] Test: Buka setiap halaman → ada chart

### 5.2 Sentimen NLP (Fitur #62) — P3, skip sementara
- [ ] **Skip** — butuh OpenAI + NLP processing

### 5.3 Simulasi What-If (Fitur #90) — P3, skip sementara
- [ ] **Skip** — butuh ML model

### 5.4 Prediksi Turnover ML (Fitur #89) — P3, skip sementara
- [ ] **Skip** — butuh training data + ML

### 5.5 Team Analytics (Fitur #68)
- [ ] Buat page `/dashboard/team-analytics`
- [ ] Chart: team performance, attendance, skills matrix
- [ ] Test: Manager login → lihat team analytics

**Wave 5 Done ✅** = Semua dashboard ada charts

---

## 🟠 WAVE 6: Integration & Security (3-4 jam)
> **Backend hardening dan integrasi**

### 6.1 Webhooks (Fitur #94)
- [ ] Buat tabel `webhook_logs`
- [ ] Buat RPC `admin_create_webhook(p_url, p_events)`
- [ ] Buat Edge Function `webhook-dispatcher`
- [ ] Test: Create webhook → trigger event → log muncul

### 6.2 SSO (Fitur #95) — P3
- [ ] **Skip** — butuh OAuth2 provider setup

### 6.3 Audit Log Immutable (Fitur #102)
- [ ] Buat tabel `audit_chain` dengan hash chain
- [ ] Setiap insert: `hash = sha256(prev_hash + data)`
- [ ] Buat RPC `verify_audit_chain()`
- [ ] Test: Insert audit → verify chain intact

### 6.4 GDPR / UU PDP (Fitur #104)
- [ ] Buat tabel `privacy_requests`
- [ ] Buat RPC `worker_request_data_export(p_nrp)`
- [ ] Buat RPC `worker_request_data_deletion(p_nrp)`
- [ ] Test: Worker request data export → download JSON

### 6.5 Perpanjangan Kontrak (Fitur #106)
- [ ] Buat tabel `contract_renewals`
- [ ] Buat pg_cron: cek PKWT expiry 30 hari lagi
- [ ] Auto-create renewal request
- [ ] Test: PKWT expiring → auto notification

### 6.6 Sinkronisasi Absensi (Fitur #93)
- [ ] Buat tabel `attendance_sync`
- [ ] Buat Edge Function `sync-attendance`
- [ ] Test: Sync dari file CSV → data masuk hr_attendance

### 6.7 Notifikasi Slack/Teams (Fitur #97)
- [ ] Buat Edge Function `send-notification`
- [ ] Support Slack webhook + Teams webhook
- [ ] Trigger: new request, approval, anomaly
- [ ] Test: Submit request → notif muncul di Slack

**Wave 6 Done ✅** = Backend aman dan terintegrasi

---

## 🔴 WAVE 7: Advanced Platform (2-3 jam)
> **Platform features yang nice-to-have**

### 7.1 Push Notifikasi Real-time (Fitur #127)
- [ ] Setup Web Push API + Service Worker
- [ ] Subscribe: `navigator.serviceWorker.ready.pushManager.subscribe()`
- [ ] Kirim push saat ada new request/approval
- [ ] Test: Subscribe → submit request → push notif muncul

### 7.2 QR Code Presensi (Fitur #128)
- [ ] Generate QR code per shift (ubah tiap jam)
- [ ] Worker scan QR → attendance check-in
- [ ] Validasi: QR harus fresh + GPS dalam radius
- [ ] Test: Scan QR → attendance tercatat

### 7.3 Scheduled Reports (Fitur #117)
- [ ] Buat tabel `scheduled_reports`
- [ ] Buat pg_cron: weekly report generation
- [ ] Email report via Edge Function
- [ ] Test: Setup weekly report → email terkirim

### 7.4 Peringatan & Sanksi (Fitur #108)
- [ ] Buat tabel `disciplinary_records`
- [ ] Buat RPC `admin_add_disciplinary(p_nrp, p_type, p_desc)`
- [ ] Tambah di employee detail
- [ ] Test: Add warning → muncul di profile

### 7.5 Dokumen & TTE (Fitur #103) — P3
- [ ] **Skip** — butuh digital signature provider

### 7.6 Arsip Hukum (Fitur #107) — P3
- [ ] **Skip** — butuh storage + legal review

**Wave 7 Done ✅** = Platform production-ready

---

## 📋 MASTER CHECKLIST (Ringkasan)

### Wave 0 — Database (30 min)
- [ ] Run migration 027 (seed 17 tables)
- [ ] Run migration 028 (28 RPCs)
- [ ] Verify all data
- [ ] Smoke test login

### Wave 1 — Critical P1 (2-3 hrs)
- [ ] #120 Ubah Password Admin
- [ ] #111 Reset Password Pekerja
- [ ] #18 PKWT Expiry Alert
- [ ] #138 Nonaktifkan Akses
- [ ] ~~#100 Upstash Session~~ (skip)
- [ ] ~~#101 RLS Upgrade~~ (skip)

### Wave 2 — Fix Partial (2-3 hrs)
- [ ] #11 Update Profil
- [ ] #21 Pengajuan Lembur
- [ ] #24 Pengajuan Training
- [ ] #37 Continuous Performance
- [ ] #39 Performance Trend Tim
- [ ] #42 Compensation Intelligence
- [ ] #15 Subtree View
- [ ] #130 Pencarian Karyawan

### Wave 3 — Self-Service (3-4 hrs)
- [ ] #22 Pengajuan Izin
- [ ] #23 Pengajuan Sakit
- [ ] #28 Multi-step Form
- [ ] #29 Dynamic Approval
- [ ] #3 Bulk Approve/Reject

### Wave 4 — Admin Features (3-4 hrs)
- [ ] #113 Import Universal
- [ ] #114 Backup Now
- [ ] #16 Org Chart Interaktif
- [ ] #17 Riwayat Mutasi
- [ ] #5 Manajemen Lowongan
- [ ] #6 Pipeline Pelamar

### Wave 5 — Analytics (2-3 hrs)
- [ ] #122 Extend Charts
- [ ] #68 Team Analytics
- [ ] ~~#62 Sentimen NLP~~ (skip P3)
- [ ] ~~#90 Simulasi What-If~~ (skip P3)
- [ ] ~~#89 Prediksi Turnover~~ (skip P3)

### Wave 6 — Integration (3-4 hrs)
- [ ] #94 Webhooks
- [ ] #102 Audit Immutable
- [ ] #104 GDPR / UU PDP
- [ ] #106 Perpanjangan Kontrak
- [ ] #93 Sinkronisasi Absensi
- [ ] #97 Notifikasi Slack/Teams
- [ ] ~~#95 SSO~~ (skip P3)

### Wave 7 — Platform (2-3 hrs)
- [ ] #127 Push Notifikasi
- [ ] #128 QR Presensi
- [ ] #117 Scheduled Reports
- [ ] #108 Peringatan & Sanksi
- [ ] ~~#103 Dokumen TTE~~ (skip P3)
- [ ] ~~#107 Arsip Hukum~~ (skip P3)

---

## ⏱️ Estimasi Total

| Wave | Durasi | Fitur |
|------|--------|-------|
| Wave 0 | 30 min | Setup |
| Wave 1 | 2-3 hrs | 4 critical fixes |
| Wave 2 | 2-3 hrs | 8 partial fixes |
| Wave 3 | 3-4 hrs | 5 self-service |
| Wave 4 | 3-4 hrs | 6 admin features |
| Wave 5 | 2-3 hrs | 2 analytics |
| Wave 6 | 3-4 hrs | 6 integrations |
| Wave 7 | 2-3 hrs | 4 platform |
| **TOTAL** | **16-24 hrs** | **~35 features** |

> **Note:** Sisa 39 fitur adalah P3 (nice-to-have) yang bisa di-skip untuk MVP.
> Dengan menyelesaikan Wave 0-7, coverage naik dari **37.6% → ~75%** (106/141 fitur).

---

## 🎯 Recommended Order

**Hari ini (Wave 0 + 1):**
1. ✅ Jalankan migration di Supabase
2. ✅ Fix 4 fitur P1 kritis
3. ✅ Smoke test

**Besok (Wave 2 + 3):**
1. ✅ Fix 8 fitur partial
2. ✅ Tambah self-service forms

**Minggu depan (Wave 4-7):**
1. ✅ Admin power features
2. ✅ Analytics charts
3. ✅ Integration & security
4. ✅ Advanced platform
