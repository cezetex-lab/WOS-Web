# 🏛️ GRAND DESIGN BLUEPRINT — insightWOS
## HR Analytics & Auto-Healing Platform
### Version: 2.0 | Date: 28 August 2026

---

## 1. VISION & MISSION

**insightWOS** adalah platform HRIS (Human Resource Information System) berbasis cloud yang dirancang untuk industri pertambangan dan perkebunan. Platform ini tidak sekadar mengelola data, tetapi **menganalisis, memprediksi, dan mengambil tindakan otomatis** untuk meningkatkan produktivitas dan kesejahteraan karyawan.

### Prinsip Desain:
```
Mobile-First → Fast → Simple → Card Layout → Bottom Nav → No Sidebar → No Horizontal Scroll
```

---

## 2. ARCHITECTURE OVERVIEW

### 2.1 The Golden Triangle

```
┌─────────────────────────────────────────────────────────┐
│                    USER (Browser/HP)                     │
│                   insightwos.vercel.app                  │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│              VERCEL EDGE MIDDLEWARE                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────────┐  │
│  │ Session  │  │   Rate   │  │   Bot Protection &   │  │
│  │ Check    │  │  Limiting │  │     Geo-Routing      │  │
│  │ (Upstash)│  │ (Upstash)│  │                      │  │
│  └────┬─────┘  └────┬─────┘  └──────────┬───────────┘  │
│       │              │                   │              │
│  ┌────▼──────────────▼───────────────────▼───────────┐  │
│  │              CACHE LAYER (Upstash Redis)          │  │
│  │  Tier 1: Session, OTP (24h TTL)                  │  │
│  │  Tier 2: Master Data (1h TTL)                    │  │
│  │  Tier 3: Reports (24h TTL, background refresh)   │  │
│  └───────────────────┬───────────────────────────────┘  │
└──────────────────────┼──────────────────────────────────┘
                       │ (20% cache miss)
┌──────────────────────▼──────────────────────────────────┐
│              SUPABASE POSTGRESQL                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────────┐  │
│  │  RLS     │  │    MV    │  │   Connection Pool    │  │
│  │  Policies│  │  (10 MV) │  │   (PgBouncer)       │  │
│  └──────────┘  └──────────┘  └──────────────────────┘  │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │          58+ Tables + 25 New Tables              │   │
│  │    Indexes, Triggers, Functions, Views           │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│              UPSTASH QSTASH (Async Worker)                │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────────┐  │
│  │  PDF     │  │  Email   │  │   ML/NLP Pipeline    │  │
│  │ Generate │  │  Blast   │  │   (Turnover, NLP)    │  │
│  └──────────┘  └──────────┘  └──────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### 2.2 Data Flow

```
READ (80% request):
  User → Vercel Edge → Upstash Cache HIT → Return (< 50ms)
  User → Vercel Edge → Upstash Cache MISS → Supabase → Cache SET → Return (< 150ms)

WRITE (20% request):
  User → Vercel Edge → Supabase (write) → Upstash Cache INVALIDATE → Return

ASYNC (tugas berat):
  User → Vercel API → QStash Queue → Worker → Supabase Storage → Notify User
```

---

## 3. DATABASE ARCHITECTURE

### 3.1 Current Tables (58 tables — from 001_init.sql)

```
CORE HRIS:
├── employees_master (30 rows, 15 cols) — Data karyawan
├── user_roles (30 rows, 3+1 cols) — Level L1-L5 + Plan
├── hr_org (29 rows, 2 cols) — Hierarki atasan-bawahan
├── worker_passwords (30 rows, 8 cols) — Auth + hash
├── daftar_baru (5 rows, 10 cols) — Pendaftaran pending
├── idx_nrp (30 rows, 2 cols) — Index lookup
├── session_tokens — Sesi aktif
├── otp_store — OTP codes
├── otp_attempts — Rate limiting
├── settings (7 rows, 2 cols) — Konfigurasi
├── audit_log (10 rows, 4 cols) — Log aktivitas

PERFORMANCE & KPI:
├── hr_performance (120 rows, 4 cols) — Skor KPI per bulan
├── hr_kpi_config (10 rows, 8 cols) — Target & bobot
├── hr_kpi_calc_log (2 rows, 8 cols) — History kalkulasi

ATTENDANCE & LEAVE:
├── hr_attendance (900 rows, 10 cols) — Absensi harian
├── hr_leave (30 rows, 11 cols) — Kuota cuti
├── hr_overtime (10 rows, 6 cols) — Data lembur

FINANCE:
├── hr_finance_kpi (4 rows, 11 cols) — Revenue/profit per divisi
├── hr_payroll (60 rows, 8 cols) — Gaji per karyawan

REQUESTS & LEARNING:
├── hr_requests (15 rows, 22 cols) — Pengajuan karyawan
├── hr_learning (45 rows, 14 cols) — Training & sertifikasi
├── hr_training_catalog (8 rows, 6 cols) — Katalog training

SKILLS & COMPETENCY:
├── hr_skills (75 rows, 14 cols) — Skill karyawan
├── hr_position_skills (9 rows, 3 cols) — Standar posisi
├── hr_competency_matrix (5 rows, 3 cols) — Level kompetensi
├── hr_capability (22 rows, 7 cols) — Gap analysis

TALENT & SUCCESSION:
├── hr_talent_catalog (4 rows, 9 cols) — Posisi terbuka
├── hr_succession (3 rows, 6 cols) — Kandidat pengganti
├── hr_succession_matrix (4 rows, 3 cols) — Readiness levels
├── hr_critical (3 rows, 6 cols) — Posisi kritis

COACHING & TASKS:
├── hr_coaching (2 rows, 7 cols) — Sesi coaching
├── hr_coaching_catalog (4 rows, 5 cols) — Tipe coaching
├── hr_tasks (5 rows, 5 cols) — Tugas karyawan

AI & ENGAGEMENT:
├── hr_ai_tasks (4 rows, 9 cols) — Tugas AI
├── hr_engagement (30 rows, 7 cols) — Skor engagement
├── hr_voice (5 rows, 13 cols) — Suara karyawan

SAFETY & COMPLIANCE:
├── hr_safety (2 rows, 16 cols) — Insiden K3
├── hr_compliance (3 rows, 7 cols) — Status kepatuhan
├── hr_compliance_catalog (4 rows, 5 cols) — Kategori
├── hr_penalty_matrix (4 rows, 4 cols) — Sanksi

BENEFITS:
├── hr_benefits (15 rows, 7 cols) — Benefit karyawan
├── hr_benefit_catalog (5 rows, 5 cols) — Katalog benefit

SCHEDULE:
├── hr_shift_master (3 rows, 5 cols) — Master shift
├── hr_calendar (18 rows, 3 cols) — Hari libur
├── hr_work_schedule (4 rows, 3 cols) — Pola kerja

PRODUCTION & OPS:
├── hr_production_daily (120 rows, 7 cols) — Produksi harian
├── hr_plantation_harvest (120 rows, 6 cols) — Panen sawit
├── hr_equipment_util (75 rows, 6 cols) — Utilisasi alat

OFFBOARDING & HEALTH:
├── hr_exit_clearance (2 rows, 6 cols) — Serah terima
├── hr_medical_checkup (3 rows, 5 cols) — MCU

RELATIONS & OTHER:
├── hr_relations (2 rows, 15 cols) — Hubungan kerja
├── hr_monthly_snapshot (4 rows, 16 cols) — Snapshot bulanan
├── hr_preview_data (16 rows, 5 cols) — Data preview tier rendah
├── announcements (3 rows, 11 cols) — Pengumuman
├── hr_document_types (9 rows, 2 cols) — Tipe dokumen
├── simulation_logs — Log simulasi
```

### 3.2 New Tables Needed (25 tables — for 141 features)

```
RECRUITMENT (A):
├── vacancies — Lowongan kerja
├── candidate_pipeline — Pipeline pelamar
├── onboarding_tasks — Checklist onboarding
├── employee_documents — Dokumen pra-kerja

STRUCTURE (B):
├── employee_mutations — Riwayat mutasi

SELF-SERVICE (C):
├── approval_config — Konfigurasi approval
├── travel_requests — Perjalanan dinas
├── reimbursements — Reimbursement

PERFORMANCE (D):
├── performance_notes — Catatan kinerja
├── okrs — Objectives & Key Results
├── incentives — Insentif otomatis

TALENT (E):
├── badges — Sistem gamifikasi
├── certifications — Sertifikasi profesional
├── job_descriptions — Library JD

ENGAGEMENT (F):
├── surveys + survey_responses — Survei eNPS
├── whistleblowers — Whistleblowing

TEAM (G):
├── timesheets — Time tracking
├── shift_swaps — Tukar shift
├── team_budgets — Anggaran tim

INTEGRATION (I):
├── webhook_logs — Webhook events

ADMIN (K):
├── feature_flags — Toggle fitur

ASSET (M):
├── assets + asset_assignments — Inventaris

OFFBOARDING (N):
├── exit_interviews + final_settlements — Keluar

PLANNING (O):
├── headcount_plans + budget_allocation — Perencanaan
```

---

## 4. FUNCTION CATALOG (RPC Functions)

### 4.1 Auth Layer (CLEAN.sql)
| Function | Params | Return | Description |
|----------|--------|--------|-------------|
| `login_worker` | p_nrp, p_password | JSONB (ok, nrp, nama, level, tier) | Login + auto hash upgrade |
| `login_admin` | p_password | JSONB (ok, token) | Admin login |
| `get_my_role` | p_nrp | JSONB (level, tier) | Role saat ini |
| `get_my_plan` | p_nrp | JSONB (plan, level) | Plan tier |

### 4.2 Worker Functions (20 functions)
| Function | Min Tier | Description |
|----------|----------|-------------|
| `get_worker_profile` | MINIMALIS | Profil lengkap |
| `get_worker_status` | MINIMALIS | KPI + kehadiran |
| `get_worker_requests` | MINIMALIS | Riwayat request |
| `create_worker_request` | MINIMALIS | Buat request |
| `get_worker_leave` | MINIMALIS | Kuota cuti |
| `get_worker_payroll` | STANDAR | Slip gaji |
| `get_worker_learning` | MINIMALIS | Training |
| `get_worker_engagement` | PREMIUM | Skor engagement |
| `get_worker_notifications` | FREE | Notifikasi |
| `get_worker_benefits` | MINIMALIS | Benefit |
| `get_worker_skills` | PREMIUM | Skills + gap |
| `get_worker_medical` | MINIMALIS | MCU |
| `get_worker_overtime` | MINIMALIS | Lembur |
| `get_worker_exit` | MINIMALIS | Exit clearance |
| `get_worker_capability` | MINIMALIS | Capability gap |
| `get_worker_relations` | STANDAR | Hubungan kerja |
| `get_worker_critical` | STANDAR | Posisi kritis |
| `get_worker_narrative` | MINIMALIS | Evaluasi narasi |
| `get_skills_intelligence` | PREMIUM | Skills radar |
| `get_benefit_data` | MINIMALIS | Total benefit |

### 4.3 Engagement & Talent (12 functions)
| Function | Description |
|----------|-------------|
| `list_ideas` | List semua ide |
| `submit_voice` | Kirim ide/anonim |
| `vote_idea` | Upvote ide |
| `get_career_path` | Jalur karir |
| `get_talent_marketplace` | Posisi terbuka |
| `get_succession` | Kandidat pengganti |
| `get_learning_recommendations` | Rekomendasi training |
| `request_training` | Ajukan training |
| `get_my_training_requests` | Riwayat training |
| `get_training_catalog` | Katalog training |
| `get_announcements` | Pengumuman |
| `get_competency_matrix` | Matrix kompetensi |

### 4.4 Catalogs & Matrices (7 functions)
| Function | Description |
|----------|-------------|
| `get_coaching_catalog` | Katalog coaching |
| `get_compliance_catalog` | Katalog compliance |
| `get_benefit_catalog` | Katalog benefit |
| `get_document_types` | Tipe dokumen |
| `get_penalty_matrix` | Matrix sanksi |
| `get_succession_matrix` | Matrix succession |
| `get_competency_matrix` | Matrix kompetensi |

### 4.5 Team & Manager (8 functions)
| Function | Min Level | Description |
|----------|-----------|-------------|
| `get_team_data` | L2+ | Anggota tim |
| `get_team_requests` | L2+ | Request pending tim |
| `approve_team_request` | L2+ | Approve/reject |
| `get_team_narrative` | L2+ | Narasi tim |
| `get_manager_command_data` | L3+ | Dashboard manager |
| `get_subtree_data` | L3+ | Seluruh bawahan |
| `get_continuous_perf_team` | L3+ | Performance trend |
| `get_people_search` | L2+ | Search karyawan |

### 4.6 CEO & Executive (10 functions)
| Function | Min Level | Description |
|----------|-----------|-------------|
| `get_ceo_command_data` | L5 | Dashboard CEO |
| `get_organization_health` | L5 | Kesehatan org |
| `get_early_warning` | L5 | Peringatan dini |
| `get_executive_summary` | L3+ | Ringkasan eksekutif |
| `get_workforce_planning` | L5 | Perencanaan SDM |
| `get_workforce_health_score` | L5 | Skor kesehatan |
| `get_anomaly_sentinel` | L5 | Deteksi anomali |
| `get_anomaly_details` | L5 | Detail anomali |
| `get_auto_healing_actions` | L5 | Auto-healing |
| `get_flight_risk_details` | L5 | Detail flight risk |

### 4.7 Dashboard Stats (10 functions)
| Function | Description |
|----------|-------------|
| `get_dashboard_stats` | Statistik umum |
| `get_kpi_by_division` | KPI per divisi |
| `get_safety_summary` | Status K3 |
| `get_turnover_data` | Turnover rate |
| `get_flight_risk_list` | Daftar flight risk |
| `get_action_center` | Pusat aksi |
| `get_financial_stats` | Keuangan per divisi |
| `get_financial_trend` | Trend keuangan |
| `get_cost_per_unit` | Biaya per unit |
| `get_monthly_snapshot_trend` | Snapshot trend |

### 4.8 Production & Ops (6 functions)
| Function | Description |
|----------|-------------|
| `get_production_output` | Produksi harian |
| `get_plantation_harvest` | Panen sawit |
| `get_equipment_util` | Utilisasi alat |
| `get_shift_schedule` | Jadwal shift |
| `get_calendar_holidays` | Hari libur |
| `get_work_schedule` | Pola kerja |
| `get_overtime_data` | Data lembur |

### 4.9 Safety & Compliance (5 functions)
| Function | Description |
|----------|-------------|
| `calculate_ltifr` | Hitung LTIFR |
| `get_compliance_rate` | Rate kepatuhan |
| `get_exit_clearance` | Exit clearance |
| `get_medical_checkup` | MCU data |
| `get_capability_gap` | Gap analysis |

### 4.10 Admin (8 functions)
| Function | Description |
|----------|-------------|
| `admin_get_summary` | Ringkasan admin |
| `admin_get_pending` | Pendaftaran pending |
| `admin_approve_pending` | Setujui pendaftar |
| `admin_reject_pending` | Tolak pendaftar |
| `admin_get_audit_log` | Log audit |
| `admin_get_org_structure` | Struktur org |
| `admin_get_divisions` | Daftar divisi |
| `export_employees` | Export CSV |

### 4.11 Platform (4 functions)
| Function | Description |
|----------|-------------|
| `export_payroll` | Export payroll |
| `get_realtime_notifications` | Notifikasi real-time |
| `get_kpi_config_all` | Semua config KPI |
| `get_kpi_calc_log` | Log kalkulasi |

---

## 5. ACCESS CONTROL MATRIX

### 5.1 Tier System
```
FREE (1)      → Data preview/dummy saja
MINIMALIS (2) → Basic features (profil, status, request)
STANDAR (3)   → Team features (tim, request, coaching)
PREMIUM (4)   → Advanced (financial, talent, career)
ENTERPRISE (5) → Semua fitur (AI, executive, simulation)
```

### 5.2 Level System
```
Level 1: Staff/Officer     → Akses diri sendiri
Level 2: Senior/Supervisor → Akses tim langsung
Level 3: Manager/Kabag     → Akses departemen
Level 4: Senior Manager    → Akses semua divisi
Level 5: Director/CEO      → Akses penuh
```

### 5.3 Access Rules
```
Rule 1: Jika level >= min_level → AKSES
Rule 2: Jika tier >= min_tier → AKSES
Rule 3: Jika salah satu → AKSES
Rule 4: Jika tidak ada → BLOCKED
```

---

## 6. HREngine — AUTO-HEALING LEVELS

### Level 1-2: KPI Bulanan (Monthly Cron — Tanggal 1, 03:00 WIB)
```
Input:  hr_production_daily, hr_attendance, hr_safety
Config: hr_kpi_config (target, weight, formula)
Output: hr_performance (kpi_score per karyawan)
Formula: SKOR = (Bobot_Prod × Skor_Prod + Bobot_Dis × Skor_Dis + ...) / Total_Bobot
```

### Level 3: Deteksi Dini (Daily Cron — 02:00 WIB)
```
1. Anomali Produksi: MA3 < MA30 × 0.8 → Alert
2. Flight Risk: (Telat × 0.3) + (SP × 0.4) + ((100-Engagement) × 0.3) > 70 → Alert
3. Sertifikat Kadaluarsa: valid_until - TODAY <= 30 hari → Auto-enroll training
4. Compliance Overdue: due_date < TODAY → Alert
```

### Level 4-5: Finansial & Korelasi (Monthly Cron — 04:00 WIB)
```
1. Cost Per Ton = Total_Biaya_Lembur / Total_Produksi
2. ROI Pelatihan = (ΔProduksi × Harga_Jual) / Biaya_Pelatihan
3. Korelasi Lembur-Insiden: Avg_lemur_saat_insiden > 1.5 × Avg_normal → Alert
```

### Level 6: Perencanaan Tenaga Kerja (Monthly)
```
1. Talent Gap = Desired_HC - (Current_HC + Pipeline)
2. Simulasi Pensiun: Usia > 55 → predict pensiun 5 tahun
```

### Level 7: Auto-Healing (Trigger-Based)
```
Event: KPI < 60 (2 bulan berturut)
Action: INSERT INTO hr_coaching (PIP)

Event: Gap Skill > 0 & mandatory
Action: Auto-enroll training

Event: Budget Lembur > 90%
Action: Auto-reject all pending lembur

Event: Posisi Kritis Kosong
Action: Promote backup candidate
```

---

## 7. UI/UX DESIGN

### 7.1 Login Page (3 Tabs)
```
┌─────────────────────────────┐
│    📊 insightWOS            │
│    Workforce Intelligence   │
│                             │
│  [👷 Pekerja] [🛡️ Admin] [📊 Dashboard] │
│                             │
│  NRP: [NRP001          ]    │
│  Pass: [••••••••••      ]   │
│                             │
│  [    Login    ]            │
│                             │
│  © 2026 insightWOS          │
└─────────────────────────────┘
```

### 7.2 Worker Page (5 Tabs)
```
┌─────────────────────────────┐
│ Selamat pagi, NRP001 👋     │
│ Level 5 · ENTERPRISE        │
├─────────────────────────────┤
│ 📊 Status Hari Ini          │
│ ┌─────┐ ┌─────┐ ┌─────┐   │
│ │ KPI │ │Hadir│ │Telat│   │
│ │ 85  │ │ 22  │ │  2  │   │
│ └─────┘ └─────┘ └─────┘   │
│                             │
│ 📝 Evaluasi Performa        │
│ Halo NRP001, performa...    │
│                             │
│ 📢 Pengumuman               │
│ • Training K3 mandatory     │
│                             │
├─────────────────────────────┤
│ 🏠  │ 📋  │ 💰  │ 📈  │ 👤  │
│Beranda│Aktiv│Gaji │Profil│     │
└─────────────────────────────┘
```

### 7.3 Dashboard Page (5 Tabs)
```
┌─────────────────────────────┐
│ 📊 Dashboard        Keluar  │
├─────────────────────────────┤
│ 📊 Ringkasan                │
│ ┌──────┐ ┌──────┐          │
│ │  30  │ │ 82.5 │          │
│ │Pekerja│ │Avg KPI│          │
│ └──────┘ └──────┘          │
│                             │
│ ⚡ Action Center            │
│ ┌──────┐ ┌──────┐          │
│ │   4  │ │   0  │          │
│ │Request│ │Daftar│          │
│ └──────┘ └──────┘          │
│                             │
│ 📈 KPI per Divisi           │
│ HRD    ████████████ 82      │
│ IT     ██████████████ 88    │
│ OPS    ███████████ 72       │
│                             │
├─────────────────────────────┤
│📊│👥│📈│🛡️│🏢│             │
│Ringkas│Tim│Analit│K3│Exec│  │
└─────────────────────────────┘
```

### 7.4 Admin Page (4 Tabs)
```
┌─────────────────────────────┐
│ 🛡️ Admin Panel      Keluar │
├─────────────────────────────┤
│ 📊 Ringkasan                │
│ ┌──────┐ ┌──────┐          │
│ │  30  │ │   4  │          │
│ │Pekerja│ │Divisi│          │
│ └──────┘ └──────┘          │
│                             │
│ 📥 Pendaftaran Pending (4)  │
│ ┌─────────────────────┐    │
│ │ Ahmad Riski          │    │
│ │ NRP: NRP031          │    │
│ │ [✅ Setujui] [❌ Tolak] │    │
│ └─────────────────────┘    │
│                             │
├─────────────────────────────┤
│📊│📥│👥│🔧│                │
│Ringkas│Pending│Kelola│Tools│ │
└─────────────────────────────┘
```

---

## 8. COLOR & BRAND

```
Primary:    Navy (#1e3a8a / navy-800/900)
Secondary:  Teal (#0d9488 / teal-600)
Accent:     Sky Blue (#38bdf8)
Background: Dark (#0f172a)
Card:       Dark Blue (#1e293b)
Border:     Slate (#334155)
Text:       Light (#e2e8f0)
Muted:      Slate (#94a3b8)
Success:    Green (#34d399)
Warning:    Amber (#fbbf24)
Error:      Red (#f87171)

Font: Inter (Google Fonts)
CSS: Tailwind CSS (CDN)
Charts: Chart.js v4
```

---

## 9. IMPLEMENTATION PHASES

### Phase 1: Foundation Fix (Week 1-2)
```
□ Deploy CLEAN.sql
□ Test all 65 RPC functions
□ Fix all SQL errors
□ Add Chart.js to all pages
□ Add Toast Notifications
□ Add Dark Mode toggle
□ Add Search + Filter
```

### Phase 2: Essential Features (Week 3-4)
```
□ Multi-step Request Form
□ Dynamic Approval Workflow
□ Task Management (To Do/Doing/Done)
□ Performance Notes
□ Training Cancel + Budget Check
□ Bulk Approve/Reject
□ Update Profil form
```

### Phase 3: Architecture Upgrade (Week 5-6)
```
□ Upstash Redis session store
□ Edge Middleware (session + rate limit)
□ Cache-Aside pattern (3-Tier)
□ Materialized Views (10 MVP)
□ Composite Indexes
□ Circuit Breaker
```

### Phase 4: Advanced Features (Week 7-8)
```
□ QStash async (PDF, email)
□ OKRs module
□ Engagement Survey (eNPS)
□ Manajemen Aset
□ Offboarding workflow
□ Manajemen Lowongan
□ Pipeline Pelamar
```

### Phase 5: Integration (Week 9-10)
```
□ Webhooks
□ SSO (OAuth2)
□ Slack/Teams notification
□ Push notification (Web Push)
□ PWA (manifest + service worker)
□ Sinkronisasi Mesin Absensi
```

### Phase 6: AI & Analytics (Week 11-12)
```
□ AI Copilot (RAG + Supabase Vector)
□ Flight Risk ML model
□ Sentiment Analysis (NLP)
□ Workforce Simulation
□ Prediksi Turnover
□ Narrative Intelligence v2
□ Anomaly Detection Real-Time
```

---

## 10. SECURITY LAYERS

### Layer 1: Vercel Edge
```
- Session check via Upstash Redis (< 5ms)
- Rate limiting: 100 req/min per user
- Login rate limit: 5 req/15 min per NRP
- Bot protection & geo-routing
```

### Layer 2: Supabase RLS
```
- Level 1: Own data only
- Level 2: Team data
- Level 3: Department data
- Level 4: All company data
- Level 5: All + admin functions
```

### Layer 3: Application Layer
```
- Password hash: 1000x SHA256 + salt
- Session token: 24h expiry
- OTP: 5 attempts per 15 min
- Audit log: immutable, hash-chained
```

---

## 11. MONITORING & ALERTING

```
Every Day 06:00 WIB:
  - Ping Supabase (SELECT 1)
  - Ping Upstash (PING)
  - Check latency < 200ms
  - If fail → Alert to Slack/Telegram

Every Hour:
  - Refresh Materialized Views
  - Update cache Tier 3
  - Check certificate expiry

Every Month (Tgl 1):
  - Run KPI calculation (Level 1-2)
  - Run Financial analysis (Level 4-5)
  - Run Workforce planning (Level 6)
  - Refresh talent catalog
```

---

## 12. PERFORMANCE TARGETS

| Metric | Target | Current |
|--------|--------|---------|
| Login response | < 200ms | ~500ms |
| Dashboard load | < 1s | ~3s |
| API response | < 100ms | ~300ms |
| Cache hit rate | > 95% | 0% |
| DB query | < 50ms | ~200ms |
| Edge response | < 50ms | N/A |
| Uptime | 99.9% | Unknown |

---

## 13. COST ESTIMATE (Monthly)

| Service | Tier | Cost |
|---------|------|------|
| Vercel | Pro | $20/mo |
| Supabase | Pro | $25/mo |
| Upstash | Pay-as-you-go | ~$10/mo |
| Domain | .com | ~$1/mo |
| **TOTAL** | | **~$56/mo** |

---

## 14. REFERENSI

- `001_init.sql` — Database schema (58 tables)
- `CLEAN.sql` — All RPC functions (65+ functions)
- `TIER_ACCESS_MATRIX.md` — Access control matrix
- `DESAIN_FRONTEND.md` — Frontend design spec
- `GRAND_DESIGN.md` — This document
- `SYSTEM_AUDIT.md` — 141 features audit

---

## 15. CHANGELOG

| Date | Version | Description |
|------|---------|-------------|
| 2026-08-24 | 1.0 | Initial design |
| 2026-08-26 | 1.5 | GAS backend complete (102 tests) |
| 2026-08-27 | 2.0 | Migration to Supabase + Vercel |
| 2026-08-28 | 2.1 | Grand Design + 141 features audit |
