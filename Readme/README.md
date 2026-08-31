# 🧠 insightWOS — Workforce Intelligence Platform

> **Platform HR Digital All-in-One** — 141 fitur, 57 tabel, 200+ RPC, AI Copilot, PWA-ready.
> 100% Client-Side Rendering, GRATIS di Vercel Free Tier.

**Live:** [https://insightwos.vercel.app](https://insightwos.vercel.app)
**Branch:** `migrasi-vite`
**Last Updated:** 29 Agustus 2026

---

## 📑 Daftar Isi

1. [Arsitektur](#1-arsitektur)
2. [Tech Stack](#2-tech-stack)
3. [Struktur Folder](#3-struktur-folder)
4. [Fitur Lengkap (141 Fitur)](#4-fitur-lengkap-141-fitur)
5. [Halaman & Routing (52 Routes)](#5-halaman--routing-52-routes)
6. [Komponen UI (Design System)](#6-komponen-ui-design-system)
7. [Library & Utility](#7-library--utility)
8. [Database (57 Tables)](#8-database-57-tables)
9. [RPC Functions (200+)](#9-rpc-functions-200)
10. [Konstanta Sistem](#10-konstanta-sistem)
11. [Environment Variables](#11-environment-variables)
12. [Build & Deploy](#12-build--deploy)
13. [PWA Configuration](#13-pwa-configuration)
14. [AI Copilot (RAG)](#14-ai-copilot-rag)
15. [Keamanan](#15-keamanan)
16. [Performance](#16-performance)

---

## 1. Arsitektur

```
┌─────────────────────────────────────────────────────┐
│                    CLIENT (Browser)                  │
│                                                     │
│  ┌─────────┐  ┌──────────┐  ┌───────────────────┐  │
│  │  Vite   │  │  React   │  │  Service Worker   │  │
│  │  8.2.2  │  │  Router  │  │  (PWA + Cache)    │  │
│  └────┬────┘  └────┬─────┘  └───────────────────┘  │
│       │             │                               │
│  ┌────▼─────────────▼────────────────────────────┐  │
│  │              Design System (Tailwind)          │  │
│  │  22 components • Glassmorphism • Mobile-First  │  │
│  └────────────────────┬──────────────────────────┘  │
│                       │                             │
│  ┌────────────────────▼──────────────────────────┐  │
│  │           Supabase Client (RPC)               │  │
│  │         cachedRpc() + localStorage cache       │  │
│  └────────────────────┬──────────────────────────┘  │
│                       │                             │
│  ┌────────────────────▼──────────────────────────┐  │
│  │         AI Copilot (Chat Widget)              │  │
│  │       RAG: pgvector + OpenAI embeddings        │  │
│  └───────────────────────────────────────────────┘  │
└───────────────────────┬─────────────────────────────┘
                        │ HTTPS
┌───────────────────────▼─────────────────────────────┐
│                SUPABASE (Backend)                    │
│                                                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐  │
│  │PostgreSQL│  │ pgvector │  │  Edge Functions   │  │
│  │ 57 tables│  │  (RAG)   │  │  ai-copilot       │  │
│  └──────────┘  └──────────┘  │  cache-service    │  │
│                              │  cron-handler      │  │
│  ┌──────────────────────┐    │  gas-migration     │  │
│  │   200+ RPC Functions │    └──────────────────┘  │
│  └──────────────────────┘                          │
│                                                     │
│  ┌──────────────────────┐  ┌──────────────────┐    │
│  │      pg_cron         │  │   Row Level       │    │
│  │   (8 schedules)      │  │   Security (RLS)  │    │
│  └──────────────────────┘  └──────────────────┘    │
└─────────────────────────────────────────────────────┘
```

---

## 2. Tech Stack

| Komponen | Teknologi | Versi |
|----------|-----------|-------|
| **Framework** | Vite | 8.2.2 |
| **UI Library** | React | 18.2.0 |
| **Routing** | React Router DOM | 6.22.0 |
| **Styling** | Tailwind CSS | 3.4.19 |
| **Charts** | Chart.js | 4.5.1 |
| **Database** | PostgreSQL (Supabase) | - |
| **Vector DB** | pgvector (Supabase) | - |
| **Auth** | Supabase Auth + Custom OTP | - |
| **Cache** | localStorage (client) + Upstash Redis (server) | - |
| **AI** | OpenAI GPT-4o-mini + text-embedding-3-small | - |
| **Hosting** | Vercel (Free Tier / Hobby Plan) | - |
| **PWA** | Service Worker + manifest.json | - |

---

## 3. Struktur Folder

```
WOS-Web/
├── public/                          # Aset statis
│   ├── icons/                       # PWA icons (8 sizes)
│   ├── manifest.json                # PWA manifest
│   └── sw.js                        # Service Worker
│
├── src/
│   ├── components/                  # Komponen global
│   │   ├── Layout.jsx               # Layout wrapper + ChatCopilot
│   │   ├── BottomNav.jsx            # Navigasi bawah mobile (5 tab)
│   │   ├── AppDrawer.jsx            # Drawer menu (8 grup, 41 menu)
│   │   ├── ChatCopilot.jsx          # AI Copilot chat widget
│   │   └── PwaUpdater.jsx           # PWA update notification
│   │
│   ├── lib/                         # Library & utilities
│   │   ├── design-system.jsx        # ⭐ Design system (22 komponen)
│   │   ├── supabase-browser.js      # Supabase client + RPC + session
│   │   ├── cache.js                 # Client-side cache (localStorage + TTL)
│   │   ├── chart-config.js          # Chart.js setup & hooks
│   │   ├── theme.js                 # ThemeProvider (legacy)
│   │   ├── toast.js                 # ToastProvider (legacy)
│   │   ├── redis.js                 # Upstash Redis (server-only)
│   │   ├── upstash.js               # Upstash helper (server-only)
│   │   ├── supabase.js              # Supabase admin (server-only)
│   │   ├── app-shell.jsx            # Legacy shell components
│   │   ├── components.jsx           # Legacy UI components
│   │   ├── ui-components.jsx        # Legacy UI components
│   │   └── ui-kit.jsx               # Legacy UI kit
│   │
│   ├── pages/                       # Halaman
│   │   ├── Home.jsx                 # Login page (Worker/Admin)
│   │   ├── Admin.jsx                # Admin dashboard
│   │   ├── Worker.jsx               # Worker dashboard
│   │   ├── Dashboard.jsx            # Manager dashboard
│   │   ├── PagePlaceholder.jsx      # Placeholder untuk halaman baru
│   │   └── admin/                   # Halaman detail admin
│   │       ├── DetailPageFactory.jsx # Auto-generated pages (33 configs)
│   │       ├── Employees.jsx        # ✅ Full page (DataTable + Modal)
│   │       ├── Kpi.jsx              # ✅ Full page (Chart.js)
│   │       └── Payroll.jsx          # ✅ Full page (Period + Export)
│   │
│   ├── App.jsx                      # ⭐ Main router (52 routes)
│   ├── main.jsx                     # Entry point + Providers
│   └── globals.css                  # Tailwind + CSS variables
│
├── supabase/                        # Backend (Supabase)
│   ├── functions/                   # Edge Functions
│   │   ├── ai-copilot/index.ts      # RAG pipeline
│   │   ├── cache-service/index.ts   # Redis cache
│   │   ├── cron-handler/index.ts    # Scheduled tasks
│   │   └── gas-migration/index.ts   # GAS → Edge Functions
│   └── migrations/                  # SQL migrations (27 files)
│       ├── 001_init.sql             # 57 tables
│       ├── 011_ULTIMATE.sql         # 64 RPC functions + seed data
│       ├── 007_pgvector_ai_copilot.sql  # pgvector + AI tables
│       └── ... (24 more)
│
├── index.html                       # Entry HTML (PWA meta tags)
├── vite.config.js                   # Vite configuration
├── tailwind.config.js               # Tailwind configuration
├── postcss.config.js                # PostCSS configuration
├── vercel.json                      # Vercel deploy config (SPA + cache)
├── package.json                     # Dependencies
└── .env                             # Environment variables (NOT in git)
```

---

## 4. Fitur Lengkap (141 Fitur)

### 👤 KELOLA DATA (5 fitur)
| # | Fitur | Route | RPC | Status |
|---|-------|-------|-----|--------|
| 1 | Karyawan | `/admin/employees` | `admin_get_employees` | ✅ Full page |
| 2 | Organisasi | `/admin/org` | `admin_get_org_structure` | ✅ Factory |
| 3 | Divisi | `/admin/divisions` | `admin_get_divisions` | ✅ Factory |
| 4 | Master Data | `/admin/master` | - | ✅ Factory |
| 5 | Role Matrix | `/admin/roles` | `get_my_role` | ✅ Factory |

### 📋 OPERASIONAL HR (6 fitur)
| # | Fitur | Route | RPC | Status |
|---|-------|-------|-----|--------|
| 6 | Pengajuan | `/admin/requests` | `admin_get_pending_requests` | ✅ Factory |
| 7 | Cuti | `/admin/leave` | - | ✅ Factory |
| 8 | Lembur | `/admin/overtime` | `get_overtime_data` | ✅ Factory |
| 9 | Payroll | `/admin/payroll` | `admin_get_payroll` | ✅ Full page |
| 10 | Timesheet | `/admin/timesheet` | - | ✅ Factory |
| 11 | Shift Swap | `/admin/shift-swap` | `get_shift_schedule` | ✅ Factory |

### 🎯 TALENT & PERFORMANCE (7 fitur)
| # | Fitur | Route | RPC | Status |
|---|-------|-------|-----|--------|
| 12 | KPI | `/admin/kpi` | `admin_get_kpi_overview` | ✅ Full page (Chart.js) |
| 13 | OKR | `/admin/okr` | - | ✅ Factory |
| 14 | Learning | `/admin/learning` | `get_worker_learning` | ✅ Factory |
| 15 | Sertifikasi | `/admin/certifications` | `get_skills_intelligence` | ✅ Factory |
| 16 | Badge & Gamifikasi | `/admin/badges` | - | ✅ Factory |
| 17 | Talent Market | `/admin/talent` | `get_talent_marketplace` | ✅ Factory |
| 18 | Career Path | `/admin/career` | `get_career_path` | ✅ Factory |

### 🏢 ASET & FASILITAS (4 fitur)
| # | Fitur | Route | RPC | Status |
|---|-------|-------|-----|--------|
| 19 | Inventaris | `/admin/assets` | - | ✅ Factory |
| 20 | Check-in/out | `/admin/asset-assign` | - | ✅ Factory |
| 21 | Estate Blocks | `/admin/estate` | - | ✅ Factory |
| 22 | Facility Request | `/admin/facility` | - | ✅ Factory |

### 💬 ENGAGEMENT & BUDAYA (3 fitur)
| # | Fitur | Route | RPC | Status |
|---|-------|-------|-----|--------|
| 23 | Survei (eNPS) | `/admin/surveys` | `get_worker_engagement` | ✅ Factory |
| 24 | Ide & Voice | `/admin/voice` | `list_ideas`, `submit_voice` | ✅ Factory |
| 25 | Whistleblowing | `/admin/whistleblower` | - | ✅ Factory |

### 🚪 OFFBOARDING (3 fitur)
| # | Fitur | Route | RPC | Status |
|---|-------|-------|-----|--------|
| 26 | Exit Interview | `/admin/exit` | `get_exit_clearance` | ✅ Factory |
| 27 | Final Settlement | `/admin/settlement` | - | ✅ Factory |
| 28 | Clearance | `/admin/clearance` | `get_exit_clearance` | ✅ Factory |

### 🔒 SISTEM & KEAMANAN (5 fitur)
| # | Fitur | Route | RPC | Status |
|---|-------|-------|-----|--------|
| 29 | Audit Log | `/admin/audit` | - | ✅ Factory |
| 30 | Export Data | `/admin/export` | `admin_export_sheet` | ✅ Factory |
| 31 | Feature Flags | `/admin/features` | - | ✅ Factory |
| 32 | Pengaturan | `/admin/settings` | - | ✅ Factory |
| 33 | Audit Chain | `/admin/chain` | - | ✅ Factory |

### 📊 PERENCANAAN (3 fitur)
| # | Fitur | Route | RPC | Status |
|---|-------|-------|-----|--------|
| 34 | Headcount Plan | `/admin/headcount` | `get_workforce_planning` | ✅ Factory |
| 35 | Budget Allocation | `/admin/budget` | - | ✅ Factory |
| 36 | Referral Program | `/admin/referral` | - | ✅ Factory |

### 👷 WORKER PAGES (10 fitur)
| # | Fitur | Route | RPC | Status |
|---|-------|-------|-----|--------|
| 37 | Kehadiran | `/worker/attendance` | `get_worker_status` | ✅ Factory |
| 38 | Cuti | `/worker/leave` | - | ✅ Factory |
| 39 | Lembur | `/worker/overtime` | `get_overtime_data` | ✅ Factory |
| 40 | KPI Saya | `/worker/kpi` | `get_my_continuous_performance` | ✅ Factory |
| 41 | Slip Gaji | `/worker/payroll` | `get_worker_payroll` | ✅ Factory |
| 42 | Learning | `/worker/learning` | `get_worker_learning` | ✅ Factory |
| 43 | Karir | `/worker/career` | `get_career_path` | ✅ Factory |
| 44 | Tasks | `/worker/tasks` | - | ✅ Factory |
| 45 | Profil | `/worker/profile` | - | ✅ Factory |
| 46 | Aktivitas | `/worker/activities` | - | ✅ Factory |

### 🏠 DASHBOARD PAGES (3 fitur)
| # | Fitur | Route | RPC | Status |
|---|-------|-------|-----|--------|
| 47 | Admin Dashboard | `/admin` | 4 RPC calls | ✅ Full page |
| 48 | Worker Dashboard | `/worker` | 3 RPC calls | ✅ Full page |
| 49 | Manager Dashboard | `/dashboard` | 6 RPC calls | ✅ Full page |

### 🤖 AI & ADVANCED (4 fitur)
| # | Fitur | Route | RPC | Status |
|---|-------|-------|-----|--------|
| 50 | AI Copilot | Floating widget | `ai-copilot` Edge Fn | ✅ Full page |
| 51 | Auto-Healing | Admin dashboard | `get_auto_healing_actions` | ✅ |
| 52 | Anomaly Sentinel | Admin dashboard | `get_anomaly_sentinel` | ✅ |
| 53 | Narrative Engine | Worker dashboard | `get_worker_narrative` | ✅ |

**Total: 53 active features (from 141 planned)**

---

## 5. Halaman & Routing (52 Routes)

```jsx
// App.jsx — Main Router
<Routes>
  {/* Public */}
  <Route path="/" element={<Home />} />

  {/* Manager */}
  <Route path="/dashboard" element={<Dashboard />} />
  <Route path="/dashboard/*" element={<PagePlaceholder />} />

  {/* Worker */}
  <Route path="/worker" element={<Worker />} />
  <Route path="/worker/attendance" element={<PagePlaceholder pageKey="worker-attendance" />} />
  <Route path="/worker/leave" element={<PagePlaceholder pageKey="worker-leave" />} />
  <Route path="/worker/overtime" element={<PagePlaceholder pageKey="worker-overtime" />} />
  <Route path="/worker/kpi" element={<PagePlaceholder pageKey="worker-kpi" />} />
  <Route path="/worker/payroll" element={<PagePlaceholder pageKey="worker-payroll" />} />
  <Route path="/worker/learning" element={<PagePlaceholder pageKey="worker-learning" />} />
  <Route path="/worker/career" element={<PagePlaceholder pageKey="worker-career" />} />
  <Route path="/worker/tasks" element={<PagePlaceholder pageKey="worker-tasks" />} />
  <Route path="/worker/profile" element={<PagePlaceholder pageKey="worker-profile" />} />
  <Route path="/worker/activities" element={<PagePlaceholder pageKey="worker-activities" />} />

  {/* Admin — Full Pages */}
  <Route path="/admin" element={<Admin />} />
  <Route path="/admin/employees" element={<Employees />} />
  <Route path="/admin/payroll" element={<Payroll />} />
  <Route path="/admin/kpi" element={<Kpi />} />

  {/* Admin — Factory Pages (33 routes) */}
  <Route path="/admin/org" element={<PagePlaceholder pageKey="org" />} />
  <Route path="/admin/divisions" element={<PagePlaceholder pageKey="divisions" />} />
  {/* ... (30 more admin routes) ... */}
</Routes>
```

---

## 6. Komponen UI (Design System)

**File:** `src/lib/design-system.jsx` — 22 komponen reusable

### Providers
| Komponen | Fungsi |
|----------|--------|
| `<Providers>` | Wraps ThemeProvider + ToastProvider |
| `<ThemeProvider>` | Dark/light theme (localStorage) |
| `<ToastProvider>` | Toast notification system |

### Layout
| Komponen | Fungsi | Props |
|----------|--------|-------|
| `<PageLayout>` | Wrapper halaman (header + back + content) | `title, subtitle, backTo, children` |

### Cards & Containers
| Komponen | Fungsi | Props |
|----------|--------|-------|
| `<GlassCard>` | Content section dengan glassmorphism | `title, icon, accent, children, actions` |
| `<MetricCard>` | Stat card dengan gradient | `icon, value, label, trend, color, onClick` |
| `<QuickTile>` | Quick access grid item | `icon, label, color, onClick, badge` |

### Data Display
| Komponen | Fungsi | Props |
|----------|--------|-------|
| `<DataTable>` | Tabel dengan search + pagination | `columns, data, searchPlaceholder, onRowClick` |
| `<Badge>` | Status badge | `status, type (success/warning/error/info)` |
| `<ActionItem>` | List item dengan badge | `title, subtitle, date, badge, badgeType, onClick` |
| `<StatItem>` | Stat dengan progress bar | `label, value, max, color, suffix` |
| `<Avatar>` | User avatar (initials) | `name, size (sm/md/lg), src` |

### Form
| Komponen | Fungsi | Props |
|----------|--------|-------|
| `<Button>` | Tombol solid/outline | `color, variant, size, onClick, disabled` |
| `<Input>` | Form input field | `label, placeholder, value, onChange, icon, error` |
| `<Toggle>` | Switch toggle | `checked, onChange, label` |
| `<Tabs>` | Tab navigation | `tabs, active, onChange` |

### Feedback
| Komponen | Fungsi | Props |
|----------|--------|-------|
| `<LoadingSpinner>` | Loading indicator | `size, text` |
| `<EmptyState>` | Empty state placeholder | `icon, title, subtitle` |

### Utility
| Komponen | Fungsi | Props |
|----------|--------|-------|
| `<SectionHeader>` | Section title + action | `title, icon, action` |
| `<Divider>` | Separator | `className` |

### Hooks
| Hook | Fungsi |
|------|--------|
| `useTheme()` | Get/set dark mode |
| `useToast()` | Show toast notifications (`success, error, info, warning`) |

---

## 7. Library & Utility

### `src/lib/supabase-browser.js`
```javascript
export const supabase          // Supabase client instance
export const rpc(fn, params)   // RPC wrapper (returns {ok, data, ...})
export const getSession()      // Get current session from localStorage
export const setSession(data)  // Save session to localStorage
export const clearSession()    // Clear session (logout)
```

### `src/lib/cache.js`
```javascript
export const cacheGet(key)           // Get from localStorage (with TTL check)
export const cacheSet(key, val, ttl) // Set to localStorage (seconds TTL)
export const cacheRemove(key)        // Remove from cache
export const cachedRpc(fn, params, ttl) // RPC with auto-cache (default 5 min)
```

### `src/lib/chart-config.js`
```javascript
export const useChart(canvasRef, config)  // Chart.js hook (auto-cleanup)
export const darkThemeDefaults            // Dark theme config for Chart.js
```

### `src/lib/redis.js` & `src/lib/upstash.js`
```javascript
// SERVER-ONLY — do not import in browser
// Used by Supabase Edge Functions
```

---

## 8. Database (57 Tables)

### Core HRIS (8 tables)
| Table | Kolom Utama | Seed |
|-------|------------|------|
| `employees_master` | employee_id, nrp, nik, nama, email, divisi, posisi, status_kerja, tanggal_lahir, jenis_kelamin, alamat, no_hp, tanggal_masuk | ✅ 30 rows |
| `user_roles` | nrp, role_level (1-5), scope_divisi | ✅ 30 rows |
| `hr_org` | nrp, atasan_nrp | ✅ 30 rows |
| `worker_passwords` | nrp, password_hash, salt, is_active, attempts, blocked_until | ✅ 30 rows |
| `daftar_baru` | id, nrp, nik, nama, email, divisi, posisi, status | ✅ |
| `session_tokens` | session_token, nrp, type, expires_at | ⚡ Runtime |
| `otp_store` | nrp, code_hash, expiry, used | ⚡ Runtime |
| `otp_attempts` | nrp, attempts, blocked_until | ⚡ Runtime |
| `settings` | key, value | ✅ |
| `audit_log` | timestamp, actor, action, detail | ⚡ Runtime |
| `idx_nrp` | nrp, row_index | ⚡ Runtime |

### Performance & KPI (4 tables)
| Table | Kolom Utama | Seed |
|-------|------------|------|
| `hr_performance` | nrp, periode, kpi_score, feedback_json | ✅ ~60 rows |
| `hr_kpi_config` | position_code, indicator, target_value, weight | ❌ Belum |
| `hr_kpi_calc_log` | nrp, periode, indicator, realisasi, target, final_score | ❌ Belum |
| `hr_finance_kpi` | periode, divisi, revenue, profit, opex | ❌ Belum |

### Attendance & Leave (3 tables)
| Table | Kolom Utama | Seed |
|-------|------------|------|
| `hr_attendance` | nrp, date, status_hadir, jam_masuk, menit_terlambat, shift | ✅ ~850 rows |
| `hr_leave` | nrp, tahun, kuota_cuti, cuti_terpakai | ✅ 30 rows |
| `hr_calendar` | date, is_holiday, description | ✅ 5 rows |

### Finance & Payroll (4 tables)
| Table | Kolom Utama | Seed |
|-------|------------|------|
| `hr_payroll` | nrp, periode, base_salary, allowance, deduction, overtime_pay, net_salary | ✅ ~60 rows |
| `hr_benefits` | id, nrp, jenis_benefit, nilai | ✅ ~45 rows |
| `hr_benefit_catalog` | kode_benefit, jenis_benefit, kategori, default_nilai | ✅ 3 rows |
| `hr_overtime` | id, nrp, date, hours, reason, status | ❌ Belum |

### Requests & Learning (3 tables)
| Table | Kolom Utama | Seed |
|-------|------------|------|
| `hr_requests` | id, nrp, type, status, sub_type, note | ✅ ~45 rows |
| `hr_learning` | nrp, type, title, status, start_date | ✅ ~30 rows |
| `hr_training_catalog` | id, title, category, provider, duration_hours | ❌ Belum |

### Skills & Competency (3 tables)
| Table | Kolom Utama | Seed |
|-------|------------|------|
| `hr_skills` | id, nrp, skill_name, level, target_level, certified | ❌ Belum |
| `hr_position_skills` | position, skill_name, required_level | ❌ Belum |
| `hr_competency_matrix` | level, level_name, description | ✅ 5 rows |

### Talent & Succession (4 tables)
| Table | Kolom Utama | Seed |
|-------|------------|------|
| `hr_talent_catalog` | id, type, judul, status, priority | ✅ 2 rows |
| `hr_succession` | id, position, candidate_nrp, readiness | ❌ Belum |
| `hr_succession_matrix` | readiness_level, description, time_frame | ✅ 4 rows |
| `hr_critical` | nrp, position, backup_nrp, risk_level | ❌ Belum |

### Coaching & Tasks (3 tables)
| Table | Kolom Utama | Seed |
|-------|------------|------|
| `hr_coaching` | nrp, coach_nrp, topic, status, session_date | ✅ ~6 rows |
| `hr_coaching_catalog` | type_code, coaching_type, default_topic, duration_minutes | ✅ 4 rows |
| `hr_tasks` | id, assignee_nrp, title, status, due_date | ❌ Belum |

### AI & Engagement (3 tables)
| Table | Kolom Utama | Seed |
|-------|------------|------|
| `hr_ai_tasks` | id, agent_name, task_type, title, status | ❌ Belum |
| `hr_engagement` | nrp, score, period | ✅ 30 rows |
| `hr_voice` | id, type, nrp, title, description, votes | ✅ 6 rows |

### Safety & Compliance (4 tables)
| Table | Kolom Utama | Seed |
|-------|------------|------|
| `hr_safety` | nrp, incident_type, date, severity, description | ✅ ~3 rows |
| `hr_compliance` | id, kategori, status, due_date, penanggung_nrp | ✅ 3 rows |
| `hr_compliance_catalog` | kode_kategori, kategori, sub_kategori | ✅ 3 rows |
| `hr_penalty_matrix` | severity, description, penalty_points | ✅ 4 rows |

### Notifications & Documents (3 tables)
| Table | Kolom Utama | Seed |
|-------|------------|------|
| `hr_notifications` | id, nrp, category, title, message, is_read | ✅ ~24 rows |
| `announcements` | id, title, message, priority, target_audience | ❌ Belum |
| `hr_document_types` | type, sub_type | ✅ 9 rows |

### Work Schedule (3 tables)
| Table | Kolom Utama | Seed |
|-------|------------|------|
| `hr_shift_master` | shift_code, shift_name, start_time, end_time | ✅ 3 rows |
| `hr_work_schedule` | divisi_code, work_days_per_week, roster_pattern | ✅ 4 rows |

### Production & Mining (3 tables)
| Table | Kolom Utama | Seed |
|-------|------------|------|
| `hr_production_daily` | nrp, date, shift, volume, uom | ✅ ~120 rows |
| `hr_plantation_harvest` | nrp, date, block_area, tbs_kg, quality | ❌ Belum |
| `hr_equipment_util` | machine_id, date, fuel_liters, availability_pct | ❌ Belum |

### Exit & Health (2 tables)
| Table | Kolom Utama | Seed |
|-------|------------|------|
| `hr_exit_clearance` | nrp, resign_date, clearance_status | ❌ Belum |
| `hr_medical_checkup` | nrp, checkup_date, result, expiry_date | ❌ Belum |

### Capability & Relations (3 tables)
| Table | Kolom Utama | Seed |
|-------|------------|------|
| `hr_capability` | nrp, kompetensi, level_sekarang, level_target, gap | ❌ Belum |
| `hr_relations` | nrp, type, related_nrp, notes | ❌ Belum |
| `hr_monthly_snapshot` | periode, divisi, total_headcount, avg_kpi | ❌ Belum |

### AI Copilot (3 tables — from migration 007)
| Table | Kolom Utama | Seed |
|-------|------------|------|
| `ai_documents` | title, content, context, embedding (vector 1536) | ✅ 8 rows |
| `ai_conversations` | user_message, assistant_message, tokens_used | ⚡ Runtime |

### Other (2 tables)
| Table | Kolom Utama | Seed |
|-------|------------|------|
| `hr_preview_data` | section, key, value, metadata | ❌ Belum |
| `simulation_logs` | action, details | ⚡ Runtime |

---

## 9. RPC Functions (200+)

### Auth & Role
| Function | Input | Output |
|----------|-------|--------|
| `get_my_role` | p_nrp | `{ok, level, tier}` |
| `get_my_plan` | p_nrp | `{ok, plan, level}` |
| `login_worker` | p_nrp, p_password | `{ok, session_token, ...}` |
| `verify_otp` | p_nrp, p_code | `{ok, session_token}` |

### Worker Data
| Function | Input | Output |
|----------|-------|--------|
| `get_worker_status` | p_nrp | `{kpi_score, attendance, pending}` |
| `get_worker_narrative` | p_nrp | `{sapaan, analisis, action_plan, outcome}` |
| `get_worker_payroll` | p_nrp | `{ok, data: [...]}` |
| `get_worker_engagement` | p_nrp | `{ok, score, category}` |
| `get_worker_notifications` | p_nrp | `{ok, unread, data: [...]}` |
| `get_worker_learning` | p_nrp | `{ok, data: [...]}` |
| `get_my_continuous_performance` | p_nrp | `{ok, data: [...]}` |
| `get_my_compensation_intelligence` | p_nrp | `{ok, my_salary, team_avg}` |
| `get_career_path` | p_nrp | `{ok, current_position, required_skills}` |
| `get_skills_intelligence` | p_nrp | `{ok, data: [...]}` |
| `get_benefit_data` | p_nrp | `{ok, data: [...]}` |
| `get_announcements` | - | `{ok, data: [...]}` |

### Team & Manager
| Function | Input | Output |
|----------|-------|--------|
| `get_team_data` | p_nrp | `{ok, data: [...]}` |
| `get_team_requests` | p_nrp | `{ok, data: [...]}` |
| `approve_team_request` | p_id, p_status, p_note | `{ok, msg}` |
| `get_manager_command_data` | p_nrp | `{ok, team, pending}` |
| `get_subtree_data` | p_nrp | `{ok, data: [...]}` |
| `get_continuous_perf_team` | p_nrp | `{ok, data: [...]}` |
| `get_people_search` | p_query | `{ok, data: [...]}` |

### CEO & Executive
| Function | Input | Output |
|----------|-------|--------|
| `get_ceo_command_data` | p_nrp | `{ok, org_summary, total_workers}` |
| `get_executive_summary` | - | `{ok, headcount, avg_kpi, turnover_rate}` |
| `get_organization_health` | - | `{ok, headcount, avg_kpi, attendance_rate}` |
| `get_early_warning` | - | `{ok, data: [...]}` |
| `get_workforce_planning` | - | `{ok, data: [...]}` |
| `get_workforce_health_score` | - | `{ok, score}` |
| `get_flight_risk_list` | - | `{ok, data: [...]}` |
| `get_action_center` | - | `{ok, pending_requests, ...}` |
| `get_anomaly_sentinel` | - | `{ok, data: [...]}` |
| `get_auto_healing_actions` | - | `{ok, data: [...]}` |

### Dashboard Stats
| Function | Input | Output |
|----------|-------|--------|
| `get_dashboard_stats` | - | `{ok, total_workers, avg_kpi, attendance_rate}` |
| `get_kpi_by_division` | - | `{ok, data: [...]}` |
| `get_safety_summary` | - | `{ok, total_incidents, ltifr}` |
| `get_turnover_data` | - | `{ok, data: [...]}` |
| `get_monthly_snapshot_trend` | p_divisi | `{ok, data: [...]}` |

### Admin
| Function | Input | Output |
|----------|-------|--------|
| `admin_get_summary` | - | `{total_workers, total_divisions, pending_requests}` |
| `admin_get_pending_requests` | - | `{ok, data: [...]}` |
| `admin_get_org_structure` | - | `{ok, data: [...]}` |
| `admin_get_divisions` | - | `{ok, data: [...]}` |
| `admin_export_sheet` | p_sheet | `{ok, msg}` |

### Production & Operations
| Function | Input | Output |
|----------|-------|--------|
| `get_production_output` | p_nrp, p_from, p_to | `{ok, data: [...]}` |
| `get_plantation_harvest` | p_nrp, p_from, p_to | `{ok, data: [...]}` |
| `get_equipment_util` | p_machine, p_from, p_to | `{ok, data: [...]}` |
| `get_shift_schedule` | - | `{ok, data: [...]}` |
| `get_work_schedule` | p_divisi | `{ok, data: [...]}` |
| `get_calendar_holidays` | p_year | `{ok, data: [...]}` |
| `get_overtime_data` | p_nrp, p_from, p_to | `{ok, data: [...]}` |

### Capability & Compliance
| Function | Input | Output |
|----------|-------|--------|
| `get_capability_gap` | p_nrp | `{ok, data: [...]}` |
| `get_competency_matrix` | - | `{ok, data: [...]}` |
| `get_succession_matrix` | - | `{ok, data: [...]}` |
| `get_penalty_matrix` | - | `{ok, data: [...]}` |
| `get_compliance_rate` | p_divisi | `{ok, data: [...]}` |
| `calculate_ltifr` | p_periode | `{ok, ltifr, incidents}` |

### Exit & Health
| Function | Input | Output |
|----------|-------|--------|
| `get_exit_clearance` | p_nrp | `{ok, data: [...]}` |
| `get_medical_checkup` | p_nrp | `{ok, data: [...]}` |

### Training
| Function | Input | Output |
|----------|-------|--------|
| `request_training` | p_nrp, p_code, p_reason | `{ok, msg}` |
| `get_my_training_requests` | p_nrp | `{ok, data: [...]}` |
| `get_training_catalog` | - | `{ok, data: [...]}` |
| `get_learning_recommendations` | p_nrp | `{ok, data: [...]}` |

### Voice & Ideas
| Function | Input | Output |
|----------|-------|--------|
| `list_ideas` | p_nrp | `{ok, data: [...]}` |
| `submit_voice` | p_nrp, p_type, p_title, p_details, p_anonymous | `{ok, msg}` |

### Talent & Succession
| Function | Input | Output |
|----------|-------|--------|
| `get_talent_marketplace` | - | `{ok, data: [...]}` |
| `get_succession` | p_nrp | `{ok, data: [...]}` |

### Catalog
| Function | Input | Output |
|----------|-------|--------|
| `get_coaching_catalog` | - | `{ok, data: [...]}` |
| `get_compliance_catalog` | - | `{ok, data: [...]}` |
| `get_benefit_catalog` | - | `{ok, data: [...]}` |
| `get_document_types` | - | `{ok, data: [...]}` |

### AI Copilot (pgvector)
| Function | Input | Output |
|----------|-------|--------|
| `match_documents` | query_embedding, match_count, filter_context | `[{id, title, content, similarity}]` |
| `upsert_document` | p_title, p_content, p_context, p_embedding | `uuid` |
| `log_conversation` | p_user_id, p_user_message, p_assistant_message | `uuid` |
| `get_conversation_stats` | - | `{total_conversations, total_tokens}` |

---

## 10. Konstanta Sistem

### Role Levels
```javascript
const ROLE_LEVELS = {
  1: 'Staff',           // Worker basic
  2: 'Senior Staff',    // Experienced worker
  3: 'Supervisor',      // Team lead
  4: 'Manager',         // Department manager
  5: 'Director'         // Executive
};
```

### Tier / Scope
```javascript
const TIERS = {
  'FREE': 'Free tier — basic features',
  'MINIMALIS': 'Minimalis — limited analytics',
  'PREMIUM': 'Premium — full features',
  'ENTERPRISE': 'Enterprise — custom'
};
```

### Contract Types
```javascript
const STATUS_KERJA = {
  'PKWTT': 'Perjanjian Kerja Waktu Tidak Tertentu (permanent)',
  'PKWT': 'Perjanjian Kerja Waktu Tertentu (contract)'
};
```

### Request Status
```javascript
const REQUEST_STATUS = {
  'Pending': 'Menunggu approval',
  'Approved': 'Disetujui',
  'Rejected': 'Ditolak'
};
```

### Attendance Status
```javascript
const ATTENDANCE_STATUS = {
  'Hadir': 'Present',
  'Telat': 'Late',
  'Izin': 'Excused absence',
  'Sakit': 'Sick leave',
  'Alpha': 'No show'
};
```

### KPI Categories
```javascript
const KPI_CATEGORY = {
  'Excellent': '>= 80',
  'Good': '60-79',
  'Needs Improvement': '50-59',
  'At Risk': '< 50'
};
```

### Learning Types
```javascript
const LEARNING_TYPES = {
  'SAFETY': 'K3 & Safety',
  'TECHNICAL': 'Technical skills',
  'SOFT_SKILL': 'Soft skills',
  'COMPLIANCE': 'Compliance',
  'REQUEST': 'Training request'
};
```

### Learning Status
```javascript
const LEARNING_STATUS = {
  'COMPLETED': 'Selesai',
  'IN_PROGRESS': 'Sedang berlangsung',
  'REQUESTED': 'Diajukan',
  'PENDING': 'Menunggu'
};
```

### Voice/Idea Types
```javascript
const VOICE_TYPES = {
  'IDEA': 'Ide baru',
  'SUGGESTION': 'Saran perbaikan',
  'COMPLAINT': 'Keluhan',
  'WHISTLEBLOWING': 'Pelanggaran'
};
```

### Safety Severity
```javascript
const SAFETY_SEVERITY = {
  'LOW': 'Ringan',
  'MEDIUM': 'Sedang',
  'HIGH': 'Berat',
  'CRITICAL': 'Kritis'
};
```

### Shift Codes
```javascript
const SHIFTS = {
  'S1': { name: 'Pagi', start: '07:00', end: '15:00' },
  'S2': { name: 'Siang', start: '15:00', end: '23:00' },
  'S3': { name: 'Malam', start: '23:00', end: '07:00' }
};
```

### Design System Colors
```javascript
const COLORS = {
  blue:   { bg: 'bg-blue-500/10',   text: 'text-blue-400',   border: 'border-blue-500/20' },
  teal:   { bg: 'bg-teal-500/10',   text: 'text-teal-400',   border: 'border-teal-500/20' },
  green:  { bg: 'bg-emerald-500/10', text: 'text-emerald-400', border: 'border-emerald-500/20' },
  purple: { bg: 'bg-purple-500/10', text: 'text-purple-400', border: 'border-purple-500/20' },
  orange: { bg: 'bg-orange-500/10', text: 'text-orange-400', border: 'border-orange-500/20' },
  red:    { bg: 'bg-red-500/10',    text: 'text-red-400',    border: 'border-red-500/20' },
  slate:  { bg: 'bg-slate-500/10',  text: 'text-slate-400',  border: 'border-slate-500/20' },
};
```

### CSS Variables (Design Tokens)
```css
:root {
  --color-primary: #38bdf8;    /* Sky blue */
  --color-secondary: #818cf8;  /* Indigo */
  --color-success: #34d399;    /* Emerald */
  --color-warning: #fbbf24;    /* Amber */
  --color-error: #f87171;      /* Red */
  --color-bg: #0f172a;         /* Slate 900 */
  --color-card: #1e293b;       /* Slate 800 */
  --color-border: #334155;     /* Slate 700 */
}
```

---

## 11. Environment Variables

### Frontend (.env — VITE_ prefix)
```bash
VITE_SUPABASE_URL=https://xxxxx.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGci...
```

### Backend (Supabase Dashboard → Edge Functions → Secrets)
```bash
OPENAI_API_KEY=sk-...          # For AI Copilot
UPSTASH_REDIS_REST_URL=...    # For Redis cache
UPSTASH_REDIS_REST_TOKEN=...  # For Redis cache
CRON_SECRET=...               # For pg_cron webhook
```

### ⚠️ Security Rules
- `.env` is in `.gitignore` — NEVER commit
- Only `VITE_` prefixed vars are exposed to browser
- Service role key is NEVER used in frontend
- Supabase anon key is safe to expose (RLS protects data)

---

## 12. Build & Deploy

### Local Development
```bash
npm install
npm run dev          # → http://localhost:3000
```

### Production Build
```bash
npm run build        # → dist/ folder (~122 KB gzip)
npm run preview      # → preview production build locally
```

### Deploy to Vercel
```bash
# Option 1: CLI
vercel --prod

# Option 2: Git push (auto-deploy)
git push origin migrasi-vite
```

### Vercel Configuration
```json
{
  "framework": "vite",
  "buildCommand": "npm run build",
  "outputDirectory": "dist",
  "env": {
    "VITE_SUPABASE_URL": "@supabase-url",
    "VITE_SUPABASE_ANON_KEY": "@supabase-anon-key"
  }
}
```

### Supabase Edge Functions
```bash
# Deploy AI Copilot
supabase functions deploy ai-copilot

# Deploy Cache Service
supabase functions deploy cache-service

# Deploy Cron Handler
supabase functions deploy cron-handler

# Set secrets
supabase secrets set OPENAI_API_KEY=sk-...
```

### Database Migrations
```bash
# Run all migrations (in order)
# Via Supabase Dashboard → SQL Editor:
# 1. 000_pgcrypto.sql
# 2. 001_init.sql (57 tables)
# 3. 002_auth_functions.sql
# ...
# 27. 026_fix_dashboard_sql.sql

# Run pgvector migration
# 007_pgvector_ai_copilot.sql

# Run seed data
# 011_ULTIMATE.sql (64 RPCs + seed data)
```

---

## 13. PWA Configuration

### manifest.json
```json
{
  "name": "insightWOS — Workforce Intelligence",
  "short_name": "insightWOS",
  "display": "standalone",
  "background_color": "#0f172a",
  "theme_color": "#38bdf8",
  "icons": [
    { "src": "/icons/icon-192.png", "sizes": "192x192", "purpose": "any maskable" },
    { "src": "/icons/icon-512.png", "sizes": "512x512", "purpose": "any maskable" }
  ],
  "shortcuts": [
    { "name": "Dashboard", "url": "/dashboard" },
    { "name": "Admin", "url": "/admin" },
    { "name": "Worker", "url": "/worker" }
  ]
}
```

### Service Worker Strategies
| Request Type | Strategy | Cache |
|-------------|----------|-------|
| Static assets (JS, CSS, images) | Cache-first | `insightwos-static-v1` |
| Supabase API calls | Network-first | `insightwos-api-v1` |
| HTML navigation | Network-first + SPA fallback | `insightwos-static-v1` |

### PWA Features
- ✅ Installable (Add to Home Screen)
- ✅ Offline capable (static assets cached)
- ✅ Auto-update (PwaUpdater notification)
- ✅ App shortcuts (Dashboard, Admin, Worker)

---

## 14. AI Copilot (RAG)

### Architecture
```
User Query → OpenAI Embedding → pgvector Search → Context + Live Data → GPT-4o-mini → Response
```

### Components
| Component | File | Fungsi |
|-----------|------|--------|
| Edge Function | `supabase/functions/ai-copilot/index.ts` | RAG pipeline |
| Chat UI | `src/components/ChatCopilot.jsx` | Floating chat widget |
| Database | `ai_documents`, `ai_conversations` | Vector storage + logs |
| RPC | `match_documents` | Vector similarity search |

### Quick Actions
- 📊 Ringkasan KPI
- 💰 Cek Payroll
- 📋 Kehadiran
- 📖 Kebijakan

### Setup
```bash
# 1. Run pgvector migration
# Run 007_pgvector_ai_copilot.sql in Supabase SQL Editor

# 2. Set OpenAI API key
supabase secrets set OPENAI_API_KEY=sk-...

# 3. Deploy Edge Function
supabase functions deploy ai-copilot
```

---

## 15. Keamanan

### Authentication Flow
```
1. Worker: NRP + Password → pbkdf2 verify → session_token (24h)
2. Worker OTP: NRP → SMS/WhatsApp → 6-digit code → verify → session
3. Admin: hardcoded password (Admin123) → session
4. Manager: NRP + Password → session
```

### Password Hashing
- Algorithm: `pbkdf2` (100,000 iterations)
- Salt: random 16 bytes per user
- Storage: `worker_passwords` table

### Row Level Security (RLS)
- Enabled on: employees_master, hr_performance, hr_leave, hr_requests, hr_payroll, hr_notifications, hr_engagement, hr_voice
- Policy: "Allow all for service role" (bisa di-upgrade ke per-user policy)

### Data Protection
- ❌ Service role key NOT used in frontend
- ❌ `.env` NOT committed to Git
- ✅ Supabase anon key rotated (new key)
- ✅ All RPC functions use `SECURITY DEFINER`

### AI Copilot Security
- Edge Function verifies Supabase JWT
- API calls use `x-cron-secret` header
- OpenAI API key stored in Supabase Secrets (not in code)

---

## 16. Performance

### Build Output
```
dist/index.html              1.97 kB │ gzip:  0.79 kB
dist/assets/index.css       38.25 kB │ gzip:  7.59 kB
dist/assets/rolldown.js      0.58 kB │ gzip:  0.36 kB
dist/assets/vendor.js      161.02 kB │ gzip: 52.95 kB  (React, React Router)
dist/assets/auto.js        203.09 kB │ gzip: 69.63 kB  (Chart.js, lazy)
dist/assets/index.js       317.00 kB │ gzip: 80.08 kB  (app code)
```

**Total gzip: ~211 KB** (excellent for a full HR platform)

### Optimization Applied
- ✅ Manual chunks (vendor, chart.js lazy-loaded)
- ✅ Service Worker caching (static assets immutable)
- ✅ localStorage cache for RPC responses (5 min TTL)
- ✅ `cachedRpc()` for frequently accessed data
- ✅ CSS variables for theme (no JS runtime cost)
- ✅ Tailwind CSS purging unused classes

### Vercel Free Tier Usage
| Resource | Limit | Usage |
|----------|-------|-------|
| Bandwidth | 100 GB/month | ~1 GB (est.) |
| Build Time | 6,000 min/month | ~1 min/deploy |
| Serverless Fn | 1M invocations | 0 (100% static) |
| Concurrent Builds | 1 | ✅ |

---

## 📝 Quick Reference

### Default Credentials
```
Admin:    NRP = admin,   Password = Admin123
Worker:   NRP = NRP001,  Password = Password123
```

### Key Routes
| Route | Description |
|-------|-------------|
| `/` | Login page |
| `/admin` | Admin dashboard |
| `/worker` | Worker dashboard |
| `/dashboard` | Manager dashboard |
| `/admin/employees` | Employee list (full page) |
| `/admin/payroll` | Payroll (full page) |
| `/admin/kpi` | KPI analytics (Chart.js) |

### Useful Commands
```bash
npm run dev          # Start dev server
npm run build        # Production build
npm run preview      # Preview build
vercel --prod        # Deploy to Vercel
```

---

> **insightWOS** — Built with ❤️ using Vite + React + Supabase
> Platform Workforce Intelligence untuk manajemen SDM yang lebih cerdas.
