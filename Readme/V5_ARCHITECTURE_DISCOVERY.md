# INSIGHTWOS V5 — ARCHITECTURE DISCOVERY (STEP 1-5)

**Status:** READ-ONLY AUDIT  
**Date:** 2026-08-31

---

# STEP 1: INVENTARISASI FILE & FUNCTION

## 1.1 File System

| Komponen | Jumlah | Lokasi |
|----------|:------:|--------|
| Frontend Pages | 90 | src/features/ |
| React Components | 9 | src/components/ |
| Lib/Utility | 10 | src/lib/ |
| Design System | 7 | src/lib/design-system/ |
| SQL Migrations | 52 | supabase/migrations/ |
| Edge Functions | 7 | supabase/functions/ |
| Total | 180 | |

## 1.2 Directory Structure

```
src/
├── features/core/admin/     (45 files)
├── features/core/worker/    (15 files)
├── features/industry/mining/ (7 files)
├── features/industry/estate/ (7 files)
├── features/industry/mill/   (7 files)
├── components/              (9 files)
├── lib/design-system/       (7 files)
├── lib/                     (10 files)
├── pages/                   (5 files)
└── App.jsx, main.jsx
```

## 1.3 Edge Functions

| Function | Purpose | Status |
|----------|---------|:------:|
| ai-copilot | AI Chatbot (Gemini) | Active |
| cache-service | Redis cache | Active |
| cron-handler | Scheduled tasks | Active |
| push-subscriber | Web push | Active |
| rate-limiter | OTP limiting | Active |
| gas-migration | GAS migration | Active |
| test-gemini | Test API | Active |

## 1.4 Key Lib Files

| File | Purpose | Domain |
|------|---------|:------:|
| supabase-browser.js | RPC wrapper | PLATFORM |
| posthog.js | Analytics | PLATFORM |
| push-notifications.js | Web push | PLATFORM |
| cache.js | localStorage | PLATFORM |
| business-units.js | BU menus | CORE |
| chart-config.js | Charts | INTEL |

---

# STEP 2: TABLE & RELATIONSHIP MAP

## 2.1 Table Count by Domain

| Domain | Tables | Key Tables |
|--------|:------:|------------|
| CORE | 45 | employees_master, hr_org, hr_attendance, hr_payroll, hr_performance |
| INDUSTRY | 15 | mill_boiler, mill_press, hr_production_daily, hr_safety |
| GOVERNANCE | 12 | audit_log, hr_compliance, whistleblowers, budget_allocation |
| PLATFORM | 20 | user_roles, worker_passwords, session_tokens, settings |
| INTELLIGENCE | 8 | ai_documents, hr_okrs, simulations, hr_surveys |
| SELF-SERVICE | 10 | travel_requests, reimbursements, performance_notes |
| RECRUITMENT | 5 | vacancies, candidate_pipeline, onboarding_tasks |
| OFFBOARDING | 3 | exit_interviews, final_settlements, offboarding_checklist |
| **Total** | **127** | |

## 2.2 Key Relationships

```
employees_master (53 FK references)
├── user_roles (1:1)
├── worker_passwords (1:1)
├── hr_org (1:1)
├── hr_attendance (1:N)
├── hr_leave (1:N)
├── hr_overtime (1:N)
├── hr_payroll (1:N)
├── hr_performance (1:N)
├── hr_skills (1:N)
├── hr_learning (1:N)
├── hr_okrs (1:N)
├── certifications (1:N)
├── badges (1:N)
├── travel_requests (1:N)
├── forum_posts (1:N)
├── shift_assignments (1:N)
└── 35+ more tables

business_units
├── sites (1:N)
└── bu_divisions (1:N)

vacancies
└── candidate_pipeline (1:N)

hr_surveys
└── hr_survey_responses (1:N)

hr_okrs
└── hr_okr_results (1:N)

webhook_configs
└── webhook_logs (1:N)

hr_compliance_catalog
└── hr_compliance (1:N)
```

## 2.3 Most Referenced Tables

| Table | Referenced By (RPCs) | Domain |
|-------|:-------------------:|:------:|
| employees_master | 316 | CORE |
| hr_performance | 190 | CORE |
| hr_payroll | 77 | CORE |
| hr_requests | 66 | CORE |
| worker_passwords | 65 | PLATFORM |
| user_roles | 65 | PLATFORM |
| hr_attendance | 53 | CORE |
| daftar_baru | 29 | CORE |
| hr_engagement | 25 | CORE |
| hr_compliance | 25 | GOV |

---

# STEP 3: FEATURE & UI MENU MAP

## 3.1 Route Count by Domain

| Domain | Routes | Percentage |
|--------|:------:|:----------:|
| CORE | 55 | 61% |
| INDUSTRY | 21 | 23% |
| GOVERNANCE | 5 | 6% |
| PLATFORM | 6 | 7% |
| INTELLIGENCE | 3 | 3% |
| **Total** | **90** | **100%** |

## 3.2 Admin Pages (48 routes)

### CORE Admin (35 pages)
- Employee Directory, Org Chart, Org Subtree, Divisions, Master Data, Role Matrix
- Payroll, Leave Mgmt, Overtime Mgmt, Timesheet, Shift Swap
- KPI, OKR, Incentive, Learning, Certifications, Badges
- Talent Market, Career Path, Surveys, Voice & Ideas, Whistleblowing
- Requests, Approvals, Approval Workflow, Recruitment, Pipeline
- Onboarding, Screening, 360 Review, Offboarding, Referral

### INDUSTRY Admin (2 pages)
- Asset Management, Budget

### GOVERNANCE Admin (5 pages)
- Audit Log, Audit Chain, Headcount, Exit, Settings

### PLATFORM Admin (6 pages)
- Integrations, Feature Flags, Export, Reset Password, Settings, Worker KPI

## 3.3 Worker Pages (36 routes)

### General Worker (16 pages)
- Dashboard, Profile, Attendance, Leave, Overtime, KPI, Payroll
- Learning, Career, Tasks, Task Board, Activities
- Multi-step Request, Forum, Training, Change Password

### Mining Worker (7 pages)
- SIMPER, Heavy Equipment, Fatigue Monitor, Production Daily
- Safety K3, Emergency, JSA

### Estate Worker (7 pages)
- Harvest Record, Block Management, Transport TBS
- Nursery, Irrigation, Facility, Medical

### Mill Worker (7 pages)
- Boiler Monitor, Mesin Press, QC Lab, Packing
- Maintenance, Breakdown, Shift Schedule

## 3.4 Shared Pages (6 routes)
- Home (Login), Manager Dashboard
- Worker KPI (Admin view), Compensation Intel
- Performance Trend, Performance Notes, Continuous Perf

---

# STEP 4: DEPENDENCY MAP

## 4.1 Module Dependency Graph

```
PLATFORM (Foundation)
├── Auth (OTP, session, passwords)
├── Authorization (RLS, roles)
├── Audit Trail
├── Notification
├── Configuration
├── Integration (webhooks, SSO)
└── Master Data (business_units, sites)
    ↓
CORE (Business Logic)
├── Organization
├── Employee
├── Attendance
├── Leave / Overtime
├── Payroll
├── Performance
├── Talent / Learning / Career
├── Engagement
├── Self-Service
└── Recruitment / Offboarding
    ↓
INDUSTRY (Domain-Specific)
├── Mining
├── Estate
├── Mill
├── Asset
└── Maintenance
    ↓
GOVERNANCE (Cross-Industry)
├── Safety/K3
├── Quality
├── Compliance
├── Risk
└── ESG (missing)
    ↓
INTELLIGENCE (Analytics + AI)
├── AI Copilot
├── Analytics
├── Executive
└── Predictive
```

## 4.2 Cross-Module Dependencies

| From | To | Dependency | Required? |
|------|----|------------|:---------:|
| CORE | PLATFORM | Auth, RLS, Audit | Yes |
| INDUSTRY | CORE | Employee data | Yes |
| INDUSTRY | PLATFORM | Auth | Yes |
| GOVERNANCE | CORE | Employee data | Yes |
| GOVERNANCE | INDUSTRY | Safety data | Optional |
| INTELLIGENCE | CORE | All core data | Yes |
| INTELLIGENCE | INDUSTRY | Production data | Optional |
| INTELLIGENCE | GOVERNANCE | Compliance data | Optional |

## 4.3 RPC Dependency Map (Top 10)

| RPC | Tables Used | Called From |
|-----|-------------|------------|
| admin_get_employees | employees_master | 15 pages |
| get_worker_attendance | hr_attendance, employees_master | 5 pages |
| get_worker_kpi | hr_performance, employees_master | 3 pages |
| get_worker_payroll | hr_payroll, employees_master | 2 pages |
| get_dashboard_stats | employees_master, hr_attendance, hr_performance | 3 pages |
| get_team_data | employees_master, hr_org | 1 page |
| get_executive_summary | employees_master, hr_performance, hr_payroll | 1 page |
| get_early_warning | hr_critical, employees_master | 1 page |
| ask_copilot | ai_documents, ai_conversations | 1 component |
| admin_get_payroll | hr_payroll, employees_master | 2 pages |

---

# STEP 5: DOMAIN CLASSIFICATION

## 5.1 CORE (Human Resources) — 55 routes, 45 tables

| Sub-Domain | Features | Routes | Tables | Status |
|------------|----------|:------:|:------:|:------:|
| Organization | Org Chart, Divisions, Sites, Roles | 6 | 5 | 100% |
| Employee | Directory, Profile, Registration, Mutations | 4 | 3 | 85% |
| Attendance | Clock In/Out, Timesheet, Heatmap | 3 | 2 | 80% |
| Leave & Overtime | Request, Approve, History | 4 | 3 | 100% |
| Payroll | Data, Slip, Benefits, Salary | 3 | 4 | 75% |
| Performance | KPI, OKR, 360, Notes, Trend | 6 | 6 | 90% |
| Talent | Skills, Certifications, Badges, Career | 4 | 5 | 70% |
| Learning | Records, Catalog, Training | 3 | 3 | 80% |
| Engagement | Surveys, Voice, Forum, Whistleblowing | 4 | 5 | 85% |
| Self-Service | Multi-step, Travel, Reimbursement | 3 | 4 | 60% |
| Recruitment | Vacancies, Pipeline, Onboarding, Screening | 5 | 5 | 100% |
| Offboarding | Exit, Settlement, Handover | 2 | 3 | 75% |
| Workforce | Shift, Schedule | 2 | 2 | 80% |

## 5.2 INDUSTRY — 21 routes, 15 tables

| Sub-Domain | Features | Routes | Tables | Status |
|------------|----------|:------:|:------:|:------:|
| Mining | SIMPER, Heavy Equipment, Fatigue, Production, Safety, Emergency, JSA | 7 | 3 | 100% |
| Estate | Harvest, Blocks, Transport, Nursery, Irrigation, Facility, Medical | 7 | 3 | 100% |
| Mill | Boiler, Press, QC, Packing, Maintenance, Breakdown, Shift | 7 | 7 | 100% |
| Asset | Inventory, Assignments, Facility | 1 | 3 | 60% |

## 5.3 GOVERNANCE — 5 routes, 12 tables

| Sub-Domain | Features | Routes | Tables | Status |
|------------|----------|:------:|:------:|:------:|
| Safety/K3 | Incidents, Near-miss, JSA | 1 | 2 | 40% |
| Quality | Compliance, QC | 0 | 2 | 20% |
| Compliance | Audit Trail, Chain | 2 | 3 | 60% |
| Risk | Whistleblowing, Critical | 1 | 2 | 40% |
| Budget/Finance | Budget, Headcount | 2 | 2 | 60% |
| ESG | — | 0 | 0 | 0% |

## 5.4 PLATFORM — 6 routes, 20 tables

| Sub-Domain | Features | Routes | Tables | Status |
|------------|----------|:------:|:------:|:------:|
| Auth | Login (Worker/Admin), OTP | 1 | 4 | 100% |
| Authorization | Roles, RLS, Division Access | 1 | 2 | 70% |
| Configuration | Settings, Feature Flags | 2 | 2 | 80% |
| Integration | Webhooks, SSO, External Notif | 1 | 5 | 60% |
| Notification | Push, Internal | 0 | 2 | 40% |
| Export | CSV, Sheet | 1 | 0 | 50% |

## 5.5 INTELLIGENCE — 3 routes, 8 tables

| Sub-Domain | Features | Routes | Tables | Status |
|------------|----------|:------:|:------:|:------:|
| AI | Copilot (RAG) | 0 (FAB) | 3 | 80% |
| Analytics | Finance KPI, Dashboard | 1 | 2 | 60% |
| Executive | CEO Dashboard, Early Warning | 1 (shared) | 1 | 70% |
| Predictive | Turnover, Simulation, Flight Risk | 2 | 2 | 70% |

## 5.6 Coverage Summary

| Domain | Features Defined | Implemented | Coverage |
|--------|:----------------:|:-----------:|:--------:|
| CORE | 65 | 55 | 85% |
| INDUSTRY | 25 | 21 | 84% |
| GOVERNANCE | 15 | 5 | 33% |
| PLATFORM | 15 | 6 | 40% |
| INTELLIGENCE | 10 | 3 | 30% |
| **Total** | **130** | **90** | **69%** |

## 5.7 MISSING Features (Priority)

| # | Feature | Domain | Impact | Effort |
|---|---------|:------:|:------:|:------:|
| 1 | ISO 45001 Safety Module | GOVERNANCE | HIGH | 1 week |
| 2 | ISO 14001 Environmental | GOVERNANCE | HIGH | 1 week |
| 3 | ESG Tracking | GOVERNANCE | HIGH | 3 days |
| 4 | Field-Level Permissions | PLATFORM | HIGH | 2 days |
| 5 | Announcements CRUD | PLATFORM | MEDIUM | 1 day |
| 6 | Asset Handover Workflow | INDUSTRY | MEDIUM | 1 day |
| 7 | Training Catalog CRUD | CORE | MEDIUM | 1 day |
| 8 | Succession Matrix UI | CORE | LOW | 1 day |
| 9 | Attendance Heatmap | CORE | LOW | 1 day |
| 10 | Compliance Dashboard | GOVERNANCE | MEDIUM | 2 days |

---

**END OF ARCHITECTURE DISCOVERY**
