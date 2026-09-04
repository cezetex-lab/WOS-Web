# GRAND DESIGN - insightWOS V6
## HR Analytics & Auto-Healing Platform
### Complete Architecture Blueprint (From NOL)
**Generated:** September 4, 2026 | **Classification:** MASTER REFERENCE

---

## 1. VISION
insightWOS adalah platform HRIS berbasis cloud untuk industri pertambangan, perkebunan, dan pabrik kelapa sawit.
Prinsip: Mobile-First -> Fast -> Simple -> Card Layout -> Bottom Nav -> No Sidebar

---

## 2. TECH STACK
| Layer | Technology | Free? |
|-------|-----------|:-----:|
| Frontend | React 18 + Vite + Tailwind CSS | Yes |
| Backend | Supabase (PostgreSQL + Edge Functions) | Yes |
| Auth | Supabase Auth (email/password) | Yes |
| Cache | Upstash Redis | Yes |
| Hosting | Vercel (auto-deploy) | Yes |
| Analytics | PostHog | Yes |
| AI | Gemini Flash (Google) | Yes |
| Push | Web Push (VAPID) | Yes |
| Email | Resend (100/day free) | Yes |
| Testing | Vitest | Yes |
| VCS | GitHub | Yes |

---

## 3. ARCHITECTURE
USER -> insightwos.vercel.app -> VERCEL EDGE (Session+RateLimit) -> SUPABASE (135+ Tables, 275+ RPCs)
READ: 80% Cache HIT < 50ms | WRITE: 20% Supabase -> Cache INVALIDATE

---

## 4. AUTHORIZATION
SYSTEM OWNER (1 specific account, auth_id bound) -> 18-tab Dashboard + Admin Backup
ADMIN PUSAT (L4-5) -> All admin pages
FUNCTIONAL (L3): admin_hrd, admin_finance, admin_produksi
INDUSTRY (L3): admin_mining, admin_mill, admin_estate
WORKER (L1) -> Self-service only

Key Decisions:
1. Owner = 1 specific account (NOT role-based) -> Prevent privilege escalation
2. Admin roles are dynamic -> Owner can add industries without code changes
3. Owner can access /admin/* as backup -> Logged as OWNER_OVERRIDE
4. Admin CANNOT become Owner -> Backend rejects non-Owner from /owner
5. Visibility != Permission -> Module visible but buttons disabled
6. Least privilege -> Each admin scoped to its function

Owner Identity: system_owner_identity table (auth_id binding, NOT role-based)
Owner-Only RPCs: owner_toggle_lock, owner_set_tier, owner_create_bu, owner_force_logout, owner_update_role, owner_create_admin_role, owner_assign_admin_user, owner_update_security_settings

Tier System: TIER 0 (Profile+Absen) -> TIER 1 (+Cuti+Lembur+Gaji) -> TIER 2 (+KPI+Learning) -> TIER 3 (+Talent+Rekrutmen) -> TIER 4 (SEMUA)
Role Level: L1 Staff -> L2 Supervisor -> L3 Manager -> L4 Director -> L5 CEO/Owner
Industry Lock: ON=visible, OFF=blocked (even CEO). Only Owner toggles.

---

## 5. DATABASE (135+ tables)
CORE: employees_master, user_roles, admin_roles, role_page_access, worker_passwords, hr_org, session_tokens, otp_store, audit_log, announcements
MODULE: module_definitions (61 modules), business_units (4 BU), business_unit_modules
CONFIG: system_owner_identity, company_config (63 items), branding
INDUSTRY (21): mining_simper, mining_equipment, mining_production, mining_fatigue, mining_safety, mining_jsa, mining_block_model, estate_harvest, estate_blocks, estate_transport, estate_nursery, estate_irrigation, estate_field, estate_yield, mill_boiler, mill_press, mill_qc_results, mill_packing, mill_maintenance, mill_breakdown, mill_production
PERFORMANCE: hr_performance, hr_kpi_config, hr_kpi_calc_log, hr_okrs
ATTENDANCE: hr_attendance, hr_leave, hr_overtime, hr_shift_master, hr_calendar
FINANCE: hr_payroll, hr_finance_kpi, team_budgets
RECRUITMENT: vacancies, candidate_pipeline, onboarding_tasks
TALENT: hr_talent_catalog, hr_succession, hr_critical, hr_skills
LEARNING: hr_learning, hr_training_catalog, certifications
ENGAGEMENT: hr_engagement, hr_voice, surveys, whistleblowers
SAFETY: hr_safety, hr_compliance, hr_compliance_catalog, hr_penalty_matrix

Key Relations: employees_master.nrp<-user_roles.nrp | employees_master.auth_id<-auth.users.id | business_unit_modules.module_id->module_definitions.id

---

## 6. FRONTEND
src/features/core/ - people, attendance, payroll, performance, leave, talent, learning, engagement, recruitment, career, finance, workforce, tasks
src/features/governance/ - compliance, audit, safety, QHSE
src/features/industry/ - Mining (7), Estate (7), Mill (7)
src/features/intelligence/ - analytics, forecasting, executive
src/features/platform/ - configuration, authorization, notifications
src/pages/ - Home, Admin, Worker, Dashboard, OwnerLogin, OwnerDashboard
src/components/ - SessionGuard, OwnerGuard, ErrorBoundary, LazyLoad, Layout, BottomNav, AppDrawer, Design System
src/hooks/ - useAdminAuth (50 pages), useModuleAccess
src/lib/ - supabase-browser, i18n, security, cache, rate-limiter, circuit-breaker

Routes (101): / -> Home | /owner -> OwnerLogin | /owner/dashboard -> OwnerDashboard (18 tabs) | /admin -> Admin (tiles per role) | /admin/* -> 50+ pages | /worker -> Worker | /dashboard -> Dashboard
Owner Dashboard Tabs: Overview, Module Lock, Tier & Pricing, Roles, Business Units, Employees, Audit Log, Security, Announcements, Notifications, Config, Activity, Integrations, Branding, Data Policy, System Log, Support, Access Control

---

## 7. BUSINESS LOGIC
KPI: L1-2 Monthly, L3 Daily Detection, L4-5 Financial, L6 Workforce Planning, L7 Auto-Healing
Payroll: Gaji Pokok + Tunjangan - Potongan (BPJS 6%) - PPh 21 = THP
Attendance: Pagi/Siang/Malam shifts, 15min grace, >15min late, >8hr overtime (L2+ approve)
Leave: 12hr/yr annual, 3mo sick full pay + 3mo 75%, 90hr maternity, L1->L2->L3 approval

---

## 8. INDUSTRY
Mining: SIMPER, Heavy Equipment, Fatigue, Production, Safety, JSA, Block Model
Estate: Harvest, Block, Transport TBS, Nursery, Irrigation, Field, Yield
Mill: Boiler, Press, QC Lab, Packing, Maintenance, Breakdown, Production

---

## 9. SECURITY
Layer 1: Vercel Edge (Session+RateLimit+BotProtection)
Layer 2: Supabase RLS (135+ tables, SECURITY DEFINER)
Layer 3: App (bcrypt, 24h tokens, OTP, audit_log)
OWASP: 73% | WCAG: Partial | GDPR: Partial

---

## 10. MIGRATIONS
001-034 Base | 056-057 MFA+CSP | 058 Cleanup | 061-064 Governance+Perf | 071-077 Industry | 079-095 Owner+Config | 100-102 Owner Waves | 110-111 Architecture | 120 Admin accounts | 130 Fix RPCs

---

## 11. SERVICES
Supabase 500MB/50K MAU | Vercel 100GB BW | Upstash 10K/day | PostHog 1M events | Resend 100/day

---

## 12. DEPLOYMENT
Vercel: https://insightwos.vercel.app | Supabase: verwobaejumvpagwynae | git push = auto-deploy

---

## 13. CODING STANDARDS
Components: PascalCase | Hooks: useXxx | Utils: camelCase | SQL: sequential
Rules: Functional only, const, no console.log, try-catch, auth.uid()

---

## 14. PHASES
1:Foundation | 2:Core HR | 3:Intelligence | 4:Security | 5:V5 Remediation | 6:Performance | **7:Industry (IN PROGRESS)** | 8:Governance | 9:Global Core | 10:Testing

---

## 15. KNOWN ISSUES
1. 168 RPCs not wired (Phase 7) | 2. signOutAuth errors silent | 3. sessionStorage

---

*Last updated: September 4, 2026*
