# insightWOS V6 — Progress & TODO

## Status: Owner Dashboard 18/18 Tabs + Admin Route Guards COMPLETE ✅

- Owner login via Supabase Auth ✅
- 18 tabs operational (Wave 1-4) ✅
- 60+ RPCs backend ✅
- 11 new tables ✅
- OwnerGuard + RoleGuard route protection ✅
- 3 Industry Admin Dashboards (Mining/Estate/Mill) ✅
- Logout fix (signOutAuth) ✅

---

## Yang Sudah Selesai

### Database
- [x] `module_definitions` — 61 module (27 CORE + 10 PLATFORM + 3 GOVERNANCE + 21 INDUSTRY)
- [x] `business_units` — 1 BU (BU04, unit_code: HQ)
- [x] `business_unit_modules` — 61 module mapped ke BU04, semua is_enabled=TRUE
- [x] `user_roles` — OWNER001 role=owner (inserted via auth, bukan employees_master)
- [x] `get_current_user_context()` — owner dipisah dari employee, langsung cek auth.users
- [x] `owner_login(p_email)` — 1 parameter saja (email), tidak perlu password
- [x] `owner_toggle_lock(p_module_code, p_enable, p_bu_id)` — support semua module (bukan hanya industry)
- [x] `get_modules_for_owner()` — tanpa filter is_industry_module
- [x] `get_business_units_for_owner()`, `get_role_overview()`, `owner_set_tier()` ✅
- [x] `audit_log_owner` — mencatat toggle dan tier changes

### Frontend
- [x] OwnerLogin.jsx — signInWithPassword → rpc owner_login → sessionStorage → navigate
- [x] OwnerDashboard.jsx — Module Lock, Tier & Pricing, Role Overview
- [x] p_bu_id dikirim saat toggle (FIXED 03 Sep 2026)
- [x] ESLint v9 upgrade (package.json di D:\0insightWOS\WOS-Web)
- [x] AGENTS.md — coding standards

### Migrations (sudah run di Supabase SQL Editor)
- 071_foundation.sql — schema + seed module_definitions, business_units
- 080_owner_rpcs.sql — owner dashboard RPCs
- 081_fix_toggle_lock.sql — toggle support p_bu_id
- 093_fix_owner_context.sql — get_current_user_context untuk owner
- 094_owner_login.sql — owner_login single param

---

## Architecture

### Owner vs Employee
- Owner = SYSTEM INSTALLER, bukan pekerja, bukan manager
- Owner tidak ada di employees_master
- Owner tidak ada di user_roles (karena FK ke employees_master)
- Owner langsung dari auth.users + email check (owner@insightwos.com)
- role_level = 5 (tertinggi)

### Module System
| module_group | Jumlah | Keterangan |
|---|---|---|
| CORE | 27 | HR universal (profil, absensi, cuti, gaji, KPI, dll) |
| PLATFORM | 10 | Admin (org structure, approval, audit, settings, dll) |
| GOVERNANCE | 3 | Safety, QHSE, Sertifikasi |
| INDUSTRY | 21 | Mining(7) + Estate(7) + Mill(7) |
| INTELLIGENCE | 0 | Belum diisi (AI/ML predictive) |

### Industry Module Convention
- Prefix: `mining_*`, `estate_*`, `mill_*`
- `is_industry_module = TRUE`
- Toggle per BU oleh owner
- Akses dicek via `check_module_access()` → cek business_unit_modules.is_enabled

### Access Control Flow
1. Login → Supabase Auth (JWT)
2. RPC dipanggil → `get_current_user_context()` cek auth.uid()
3. Owner → bypass semua, lihat semua module
4. Employee → cek user_roles → role_level → tier BU → module access

---

## TODO — Prioritas

### DONE ✅
- [x] Owner login + dashboard
- [x] Module Lock (on/off per BU)
- [x] Tier & Pricing (T0-T4)
- [x] Role Overview (view + edit)
- [x] Company Config (63 items)
- [x] Arahtikural Role-Based Analysis
- [x] Route verification (mill/mining/estate admin)
- [x] Role-based access verification

### DONE ✅
- [x] **Owner Dashboard 18 Features** — ALL WAVES COMPLETE
  - Wave 1 (P0): Overview, Audit Log, Security, BU Management ✅
  - Wave 2 (P1): Employee Mgmt, Announcements, Notification, System Announcements ✅
  - Wave 3 (P2): Activity, Integrations, Data Retention, System Log, Support, Analytics ✅
  - Wave 4 (P3): Access Control (Admin Roles CRUD, Assign User) ✅
- [x] **Migration 100** — Wave 1 RPCs (12 functions)
- [x] **Migration 101** — Wave 2 RPCs (13 functions) + 2 tables
- [x] **Migration 102** — Wave 3 RPCs (11 functions) + 5 tables
- [x] **Migration 110** — Owner Identity + Admin Roles + Role Page Access (8 RPCs)
- [x] **Migration 111** — Security Hardening (check_action_permission, log_owner_override, admin_pusat_manage_admin, get_industry_admin_stats)
- [x] **Frontend** — OwnerDashboard.jsx 18 tabs, 1096 lines
- [x] **OwnerGuard** — Protects /owner/* routes via check_owner_identity() RPC
- [x] **RoleGuard** — Protects admin routes, checks role against allowedRoles
- [x] **RoleGuard wired** — ALL admin routes wrapped with RoleGuard (7 admin roles + owner bypass)
- [x] **3 Industry Admin Dashboards** — /admin/mining, /admin/estate, /admin/mill
- [x] **Logout fix** — All 5 logout functions now call signOutAuth()
- [x] **Empty state rule** — Added to AGENTS.md Section 13
- [x] **Architecture V6 doc** — OWNER_ADMIN_ARCHITECTURE_V6.md

### MEDIUM (Next priorities)

- [ ] **Dynamic Route/Frontend** — App.jsx & menu-builder.js masih hardcoded
  - Saat ini: setiap module harus manual tambah route di App.jsx + path di menu-builder.js
  - Target: route generate dari module_definitions + role employee
  - Tidak urgent karena owner hanya install, employee yang pakai route

- [ ] **Module Page per Industri** — halaman untuk module_industry belum ada
  - Mining: SIMPER, Heavy Equipment, Produksi, dll → perlu page/form/table
  - Estate: Panen, Block, Irigasi, dll
  - Mill: Boiler, Press, QC, dll
  - Prioritas: buat template factory (PageFactory) supaya tinggal registrasi module

### MEDIUM

- [ ] **Seed Logic** — 071_foundation.sql pakai prefix matching
  - Untuk industri baru (automotive, retail, dll): harus manual INSERT
  - Solusi: buat RPC `register_industry(p_prefix, p_modules[])` supaya owner bisa tambah industri dari dashboard

- [ ] **Module Management Page** — owner bisa tambah/hapus module dari dashboard
  - Sekarang: harus SQL manual
  - Target: owner dashboard → tab Module Management → form tambah module baru

- [ ] **Multi-BU Support** — saat ini hanya 1 BU (HQ)
  - Tambah BU baru: INSERT business_units + business_unit_modules
  - Owner dashboard harus bisa toggle per-BU

### LOW

- [ ] **INTELLIGENCE module_group** — belum ada module
  - Ideas: AI narrative, predictive analytics, flight risk scoring
  - Database sudah support (CHECK constraint ada 'INTELLIGENCE')

- [ ] **ModuleRouteGuard & CoreDataWrapper** — sudah dibuat tapi belum dipakai
  - Component sudah ada di codebase
  - Perlu diintegrasikan ke App.jsx routes

- [ ] **Export Page** — hardcoded export types
  - Perlu dynamic export berdasarkan module yang aktif

- [ ] **DetailPageFactory** — hardcoded detail config
  - Perlu dynamic berdasarkan module_definitions

---

## Known Issues

1. ~~Owner toggle tidak work~~ → FIXED: p_bu_id tidak dikirim, sekarang sudah dikirim
2. ~~Duplicate key insert~~ → Hapus dulu sebelum insert
3. ~~SQL Editor tidak bisa test RPC owner~~ → Wajar, tidak ada auth context
4. ~~business_unit_modules 0 baris~~ → Seed manual karena prefix tidak match (HQ bukan MINING/ESTATE/MILL)
5. Supabase client tidak exposed ke global scope → wajar, test dari SQL Editor saja

---

## Penting

- Working directory: `D:\0insightWOS\WOS-Web` (INI YANG DI-DEPLOY)
- Deploy: `npx vercel deploy --prod`
- Supabase project: `verwobaejumvpagwynae`
- Owner auth UID: `a8a77284-ed50-4642-b393-4bccb448e0c8`
- Owner email: `owner@insightwos.com`
- Vercel: `https://insightwos.vercel.app`
- SQL migrations: run langsung di Supabase SQL Editor (tidak perlu deploy)
- Frontend changes: perlu `npx vercel deploy --prod`

---

## Log

### 04 Sep 2026
- **Wave 1 Complete** — Migration 100: 12 RPCs + OwnerDashboard 7 tabs
  - Fix: get_modules_for_owner() now returns ALL modules (not just industry)
  - Overview: 8 stat cards + employee by BU bar chart
  - Module Lock: toggle ON/OFF per module per BU
  - Tier & Pricing: T0-T4 pricing preview + set tier per BU
  - Roles: table per BU + edit modal
  - Audit Log: filterable table + pagination (50/page)
  - Security: login stats + active sessions + force logout + security policy
  - Business Units: CRUD with create/edit/delete modals
- **Wave 2 Complete** — Migration 101: 13 RPCs + 2 tables + 4 tabs
  - Employees: search/filter/pagination, create, edit, deactivate
  - Announcements: create with priority/target, delete
  - Notifications: toggle email/push per event type (12 events)
  - System Banner: create info/warning/critical banners
- **Wave 3 Complete** — Migration 102: 11 RPCs + 5 tables + 6 tabs
  - Activity: stats cards + top actions bar chart
  - Integrations: CRUD with status badges
  - Data Retention: table with edit
  - System Log: changelog display
  - Support: ticket list with status dropdown
  - Analytics: daily actions bar chart + action distribution
- **Fixes**: RPC naming mismatch, duplicate SQL declarations, missing empty states
- **Rules**: Added empty state rule to AGENTS.md Section 13
- **Total**: 50+ RPCs, 9 new tables, 17 tabs, 977 lines

### 03 Sep 2026
- Owner login fixed (get_current_user_context bypass employees_master)
- owner_login RPC reduced to 1 param (p_email)
- ESLint upgraded to v9
- AGENTS.md created
- Module Lock fixed (p_bu_id missing → added)
- All 61 modules loaded to business_unit_modules for BU04
- Toggle on/off working
- Confirmed: SQL Editor cannot test owner RPCs (no auth context)
- User deleted D:\000WOSweb DEVIN\WOS-Web — single source: D:\0insightWOS\WOS-Web
- Owner Dashboard: Module Lock grouped by category (Core/Platform/Governance/Industry)
- Owner Dashboard: Tier & Pricing with preview cards + status per BU
- Role Overview: edit role/level via modal, grouped by BU
- BUs created: BU01(Mining), BU02(Estate), BU03(Mill), BU04(HQ)
- Dummy employees + user_roles inserted (10 employees across 4 BUs)
- `owner_update_role` RPC for editing roles
- `095_company_config.sql` — 63 config items across 10 categories (KPI, Scoring, Salary, Attendance, Leave, Security, Approval, Industry, Display, Currency)
- Company Config page at `/owner/dashboard/config` with search, accordion, edit modal
- TODO #4 (Konstanta) — DONE for now, waiting for further development
