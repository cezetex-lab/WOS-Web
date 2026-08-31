# INSIGHTWOS V5 — ARCHITECTURE AUDIT (PHASE 0)

**Status:** DRAFT — Menunggu Approval
**Date:** 2026-08-31
**Auditor:** Buffy (AI Agent)

---

## CURRENT STATE INVENTORY

### File System
| Komponen | Jumlah |
|----------|:------:|
| Frontend Pages (.jsx) | 90 |
| React Components | 9 |
| Lib/Utility (.js) | 10 |
| SQL Migrations | 52 |
| Edge Functions | 7 |
| Total Source Files | 111 |

### Database
| Komponen | Jumlah | Keterangan |
|----------|:------:|------------|
| Tables | 127 | Dari 52 migrations |
| RPC Functions | 268 | Definisi di SQL |
| RPC Wired | 118 | 44% saja |
| RPC NOT Wired | 150 | 56% unused |
| Duplicate Tables | 2 | onboarding_tasks, webhook_logs |
| Duplicate Functions | 10+ | admin_approve_pending, admin_get_employees |

### Routes
| Role | Routes |
|------|:------:|
| Admin | 48 |
| Worker General | 16 |
| Worker Mining | 7 |
| Worker Estate | 7 |
| Worker Mill | 7 |
| Dashboard | 1 |
| Home | 1 |
| Total | 90 |

### Third-Party Services (FREE)
| # | Service | Status |
|---|---------|:------:|
| 1 | Supabase | Active |
| 2 | Google Gemini Flash | Active |
| 3 | PostHog | Active |
| 4 | Upstash Redis | Active |
| 5 | Vercel | Active |
| 6 | GitHub | Active |

---

## CURRENT ARCHITECTURE (V4) — FLAT / NO BOUNDARIES

- Presentation: React + Tailwind + design-system.jsx (single file)
- 90 pages ALL in src/pages/ flat structure
- No domain separation in file structure
- Service: supabase-browser.js (single RPC wrapper)
- No controller/service/repository separation
- Business logic MIXED in frontend components
- Data: 127 tables (NO clear ownership), 268 RPCs (mixed domains)
- RLS enabled but policies unclear
- Duplicate tables exist

---

## TARGET ARCHITECTURE (V5) — CLEAR DOMAINS

- Presentation: Feature-based file structure (core/, industry/, governance/, intel/)
- Controller: Feature-level hooks (useEmployee, usePayroll)
- Service: Domain services centralized, not in components
- Repository: RPC-only pattern, typed RPC client
- Platform: Auth, Authorization, Workflow, Notification, Document, Audit, Master Data, Integration
- Data: CORE tables, INDUSTRY tables, GOVERNANCE tables with clear ownership

---

## CRITICAL FINDINGS

1. 127 tables — no clear ownership → duplicate data risk
2. 268 RPCs — 150 not wired (56%) → dead code
3. 10+ duplicate RPC functions → inconsistent behavior
4. 2 duplicate tables → data inconsistency
5. Business logic in frontend → not testable, not reusable
6. Session in localStorage → XSS risk
7. No field-level access control → salary exposed
8. Flat file structure → cannot scale

## HIGH FINDINGS

1. Design system in single file → performance/maintainability
2. No controller/service layer → logic scattered
3. Indonesia hard-coded → cannot go global
4. No canonical Employee ID → NRP format inconsistent
5. No test suite → cannot verify changes
6. Payroll logic mixed with Employee → SRP violation
7. Mining/Estate/Mill in CORE pages → domain violation

## DUPLICATION

1. onboarding_tasks (018 + 050) → MERGE
2. webhook_logs (018 + 045) → MERGE
3. hr_okrs vs okrs (two OKR tables!) → MERGE
4. hr_surveys vs surveys (two survey tables!) → MERGE
5. review_360 vs reviews_360 (two 360 tables!) → MERGE
6. admin_get_employees (006 + 038) → MERGE
7. admin_approve_pending (003 + CLEAN) → MERGE

## SECURITY

1. Session in localStorage → HIGH: Move to HTTP-only cookie
2. No field-level permission → HIGH: Add column-level RLS
3. No account lockout → MEDIUM: Implement via rate-limiter
4. No CORS on Edge Functions → MEDIUM: Add headers

## PHASED MIGRATION PLAN

### PHASE 1: ARCHITECTURE CLEANUP (Week 1)
1.1 Remove duplicate tables (onboarding_tasks, webhook_logs, okrs, surveys, review_360)
1.2 Remove 150+ orphaned RPC functions
1.3 Consolidate duplicate RPCs (10+ functions)
1.4 Split design-system.jsx into domain components
1.5 Restructure src/ into feature-based architecture
1.6 Create RPC type definitions

### PHASE 2: DOMAIN SEPARATION (Week 2)
2.1 Create domain directory structure (core/, industry/, governance/, platform/, intel/)
2.2 Move pages into correct domain directories
2.3 Tag all RPCs with domain ownership
2.4 Create domain-specific RPC wrappers
2.5 Extract business logic from components into hooks/services

### PHASE 3: SECURITY HARDENING (Week 3)
3.1 Move session from localStorage to HTTP-only cookie
3.2 Add field-level permission (salary, bank account, tax)
3.3 Add account lockout after failed attempts
3.4 Configure CORS on all Edge Functions
3.5 Remove all console.log from production
3.6 Add input validation on all RPC parameters

### PHASE 4: DATA GOVERNANCE (Week 4)
4.1 Create canonical master tables (Country, Currency, Timezone, Language)
4.2 Standardize Employee ID format (canonical NRP)
4.3 Add audit columns (created_by, updated_by, effective_from/to)
4.4 Create data classification system
4.5 Consolidate 52 migrations into clean schema

### PHASE 5: GLOBALIZE CORE (Week 5)
5.1 Abstract currency (remove hardcoded IDR)
5.2 Abstract timezone (remove hardcoded GMT+7)
5.3 Create i18n framework (ID + EN)
5.4 Make organization structure configurable
5.5 Abstract employment types (PKWTT/PKWT to Permanent/Fixed-term)

### PHASE 6: PERFORMANCE + RELIABILITY (Week 6)
6.1 Add error boundaries per feature module
6.2 Add loading/empty/error states to all pages
6.3 Implement retry with backoff on all RPC calls
6.4 Add optimistic updates for better UX
6.5 Set up Playwright E2E tests

### PHASE 7: INDUSTRY MODULES (Week 7)
7.1 Create RPC functions for Mining pages (7 RPCs)
7.2 Create RPC functions for Estate pages (5 RPCs)
7.3 Seed realistic data for all industry pages
7.4 Add ISO 45001 Safety compliance modules
7.5 Add ISO 14001 Environmental compliance modules
7.6 Add ISO 9001 Quality compliance modules

### PHASE 8: GOVERNANCE MODULES (Week 8)
8.1 Create unified Safety/Incident module (works for all BUs)
8.2 Create Environmental monitoring module
8.3 Create Compliance dashboard (all standards)
8.4 Create Risk register module
8.5 Create ESG tracking module

### PHASE 9: AI + ANALYTICS (Week 9)
9.1 Fix AI Copilot — ensure all context queries work
9.2 Create domain-specific AI insights (HR, Mining, Estate)
9.3 Create analytics metrics registry (define all KPIs)
9.4 Create executive dashboard with real-time data
9.5 Add predictive analytics (turnover, production)

### PHASE 10: ENTERPRISE SCALE (Week 10)
10.1 Set up Cloudflare CDN + WAF
10.2 Set up QStash async workers
10.3 Create backup automation (Cloudflare R2)
10.4 Set up monitoring (PostHog alerts)
10.5 Load testing with K6
10.6 Documentation site (Docusaurus)

---

## SUMMARY

| Metric | Current V4 | Target V5 |
|--------|:---------:|:---------:|
| Domain Boundaries | None | 5 clear domains |
| File Structure | Flat | Feature-based |
| Duplicate Tables | 2 | 0 |
| Duplicate RPCs | 10+ | 0 |
| Orphaned RPCs | 150 | 0 |
| Business Logic | In components | In services/hooks |
| Session Security | localStorage | HTTP-only cookie |
| Field-Level Permission | None | All sensitive fields |
| i18n Support | Indonesian only | ID + EN |
| Currency | Hardcoded IDR | Configurable |
| Timezone | Hardcoded GMT+7 | Configurable |
| Test Coverage | 0% | E2E + Unit |

---

## RECOMMENDATION

DO NOT CODE YET.

1. Approve this migration plan
2. Start Phase 1 — cleanup foundation
3. After Phase 4 complete, then Phase 5-10

Estimated: 10 weeks for V5 Enterprise
Or 3 weeks for MVP V5 (Phase 1-3 only)
