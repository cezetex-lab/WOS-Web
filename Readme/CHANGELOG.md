# CHANGELOG - insightWOS

All notable changes (newest first).

---
## 07 Sep 2026 -- E2E TESTS, DYNAMIC ROUTING, PG_CRON SCHEDULES

### Q5: E2E Playwright Tests (L7 Gate)
- **login-flow.spec.js** -- Worker login form UI tests, tab switching, form state clearing; real login flow with env var credentials
- **admin-payroll.spec.js** -- Admin login form, protected route redirects, admin payroll access
- **worker-attendance.spec.js** -- Worker protected routes, attendance/leave navigation
- **role-change.spec.js** -- RBAC: owner auth required, worker/admin role restrictions
- **concurrent-session.spec.js** -- Session guard behavior, multi-tab loading, session lifecycle
- All tests pass without real credentials (UI-only); real flows skip gracefully via test.skip

### DynamicRoutes Re-enabled (App.jsx)
- Uncommented DynamicRoutes import from ./components/DynamicRoutes
- Added catch-all route for module-defined routes
- Static routes (Home, Owner, Admin, Worker) still take priority via React Router match order
- Module-defined routes from module_definitions table now active via get_enabled_modules RPC

### Migration 186: pg_cron Schedule Activation
- **refresh-all-mv**: Hourly at :05 -- calls refresh_all_materialized_views()
- **cleanup-expired-data**: Daily 02:00 UTC -- calls cleanup_expired_data() (migration 147)
- **cleanup-expired-sessions**: Daily 02:30 UTC -- calls cleanup_expired_sessions()
- **cleanup-rate-limits**: Daily 03:00 UTC -- calls cleanup_rate_limits()
- All jobs idempotent: unschedule-then-reschedule pattern
- Guarded with pg_extension check -- skips gracefully if pg_cron not installed

---

## 05 Sep 2026 — AUDIT REMEDIATION (FULL_EXTERNAL_AUDIT_V6)
### Migration 141: COMPREHENSIVE AUDIT FIX (B7, B8, H1, H2, M1, M2, O1, O2, O4, P2, P3, A4)
- **B7: Logout RPC** — worker_logout(), admin_logout(), owner_logout() created, GRANT to authenticated
- **B8: Session fixation fix** — login_worker now invalidates ALL old session_tokens before creating new
- **H1: Input validation** — NRP (3-20 chars), NIK (5-20 chars), password (6+ chars) checks on login_worker
- **H2: Error info leakage** — All critical RPCs wrapped in EXCEPTION WHEN OTHERS → generic "Terjadi kesalahan sistem"
- **M1/M2: Unbounded queries** — LIMIT added to training_catalog(50), coaching_catalog(20), compliance_catalog(20), benefit_catalog(20), document_types(20), talent_marketplace(20), people_search(20), list_ideas(50)
- **O1: Audit logging for role changes** — trg_audit_role_change trigger on user_roles UPDATE → audit_log
- **O2: Audit logging for payroll** — trg_audit_payroll_insert/update triggers on hr_payroll → audit_log
- **O4: Access denial logging** — log_access_denial(rpc, reason) RPC for frontend to report denials
- **P2: GDPR Right to Access** — export_my_data(NRP) returns profile, payroll, performance, attendance, leave, overtime, skills, benefits, learning, requests, safety as JSON
- **P3: GDPR Right to be Forgotten** — delete_my_data(NRP) anonymizes data (DELETED_ prefix) + logs to audit_log
- **A4: Dead code documented** — debug_ceo_auth.sql, 085_delete_all_data.sql, 064_deprecate_rpcs.sql
- **Auth check** — All catalog/training/commerce RPCs now require auth.uid() IS NOT NULL
- **IDOR fix** — get_worker_payroll, get_worker_engagement, get_worker_notifications, get_worker_learning all validate caller via authz_in_scope()
- **GRANT** — All 13 fixed functions granted to authenticated role
- ALL RPCs use SECURITY DEFINER SET search_path = public

### Migration 131-140: Security Architecture (Previous)
- Migration 131: IDOR fix — _get_caller_nrp(), _is_admin_or_owner_caller() helpers
- Migration 132: Admin BU filter + owner_login auth.uid() check
- Migration 133: RLS tightening — 13 sensitive tables with auth-based policies
- Migration 134: Authorization Architecture v2 — authz_current_nrp, authz_has_permission, authz_in_scope, authz_has_role, authz_get_scope, authz_get_bu, billing_module_enabled
- Migration 135: Seed permission sets — 70+ permissions across 12 permission sets
- Migration 136: Migrate hardcoded authz to permission-based helpers
- Migration 137: Fix remaining USING(true) RLS — 50+ tables
- Migration 138: Admin RBAC helper + RLS on 5 missing tables + audit protection
- Migration 139: Admin RPC role enforcement — 13 admin_* RPCs + concurrent session table
- Migration 140: Industry tables fix + RPC column name fixes

### Other
- Frontend: 0 console.log remaining (was 30)
- Frontend: 0 sessionStorage remaining (was storing tokens)
- Frontend: localStorage only for cache/theme/language (acceptable)

## 05 Sep 2026 � AUDIT REMEDIATION (v2: 5 bugs fixed inline)
### Migration 141: COMPREHENSIVE AUDIT FIX (v2)
- **BUG 1 (BLOCKER): get_training_catalog() truncated string** � rewritten with correct columns: category, provider, duration_hours
- **BUG 2 (CRITICAL): trigger functions missing SET search_path** � _audit_role_change + _audit_payroll_change now have SET search_path = public
- **BUG 3 (HIGH): delete_my_data() logic flaw** � split into self-delete (GDPR Art.17, no extra permission) vs admin-delete (requires employee.deactivate)
- **BUG 4 (HIGH): export_my_data() SELECT * exposed password_hash/salt** � profile now whitelists 14 safe columns only
- **BUG 5 (MEDIUM): logout jwt_note** � all 3 logout functions return jwt_note directing frontend to call supabase.auth.signOut()

## 05 Sep 2026 (Earlier)

- Role-based admin navigation: 7 ROLE_BADGES + 7 ADMIN_TILES
- useAdminAuth hook on all 50 admin pages
- BottomNav ROLE_CONFIG for all 7 admin roles
- Admin.jsx crash fixes: toArray + useEffect [session?.nrp]
- RoleGuard wrapping <Route> = invalid React Router v6 (fixed)
- Migration 120: 8 admin accounts seeded + auth_id linked
- Migration 130: Fix missing RPCs
- All 8 admin accounts tested and working
- WOS-Web-fresh cleanup: removed submodule, restored 14 migrations
- Rules of Hooks fixes: Payroll, IncentiveCalc, Kpi, TurnoverPrediction
- AppDrawer.jsx: missing useState import fixed
- Service Worker cache bumped v1 -> v2

## 04 Sep 2026
- Owner Dashboard Wave 4: Access Control Tab
- OwnerGuard + RoleGuard + Logout Fix
- 3 Industry Admin Dashboards (Mining, Estate, Mill)
- BU: MINING=Tambang, ESTATE=Perkebunan, MILL=Pabrik, HQ=Korporat

## 03 Sep 2026
- Owner = System Installer (NOT employee)
- system_owner_identity table + auth_id binding
- Owner Login via /owner
- Owner Dashboard: 18 tabs complete
- Migrations 100-102, 110-111 deployed
- 21 Industry tables + RPC templates + seed data
- Company Config: 63 items

## 02 Sep 2026
- V5 Remediation Complete (6 phases)
- Phase 1: Duplicate cleanup
- Phase 2: Domain boundary
- Phase 3: Security hardening (MFA, CSP, HSTS)
- Phase 4: Data governance
- Phase 5: Global core (currency, timezone, i18n)
- Phase 6: Performance (27 indexes, 7 RPCs deprecated)
- OWASP compliance: 73%

## 01 Sep 2026
- V5 Completion
- Migration 063: 27 performance indexes
- Migration 064: 39 high-value RPCs wired
- i18n skeleton (ID + EN)
- ErrorBoundary per-route

## 31 Aug 2026
- V5 Architecture Audit (Phase 0)
- 118 source files, 90 routes, 127 tables, 275 RPCs
- Remediation map created (8 phases)

## 30 Aug 2026
- Backend audit: 275 RPCs, 127 tables
- Industry audit, Navigation audit

## 29 Aug 2026
- V3.0 Handoff, Wave checklist

## 28 Aug 2026
- Grand Design V2.0
- Golden Triangle architecture
- 58 tables + 25 new, 65+ RPCs
- 7 implementation phases

## 27 Aug 2026
- Migration to Supabase + Vercel
- GAS backend complete (102 tests)

## [145] - 2026-09-05 — Comprehensive Gap Fixes

### Added
- **Audit Trail**: Generic trigger (_generic_audit_trigger) on 19 sensitive tables — captures INSERT/UPDATE/DELETE with old/new JSONB diffs
- **PDP Consent (Indonesia)**: user_consents table + grant_consent() + get_my_consents() RPCs for GDPR/PDP Art.15 compliance
- **API Rate Limiting**: api_keys + api_rate_limits tables + check_api_rate_limit() per-key rate enforcement + cleanup
- **Indexing**: 25+ new indexes on hr_attendance, hr_payroll, hr_leave, hr_overtime, hr_performance, user_roles, session_tokens, employees_master, audit_log (including GIN on audit_log.message)
- **MV Auto-Refresh**: 5 refresh functions + refresh_all_materialized_views() unified RPC (pg_cron schedules commented, enable via dashboard)
- **Data Retention**: apply_data_retention() auto-cleanup using data_retention_rules from migration 102
- **Dashboard Cache**: dashboard_cache table + get_cached() + set_cache() + get_dashboard_cached() with 5-min TTL
- **System Changelog**: Auto-populated entry for migration 145

### Tables Created
- user_consents (PDP consent management)
- api_keys (API key management)
- api_rate_limits (per-key rate tracking)
- dashboard_cache (query result cache)

### Score Impact
| Category | Before | After |
|## [146] - 2026-09-05 — Critical Audit Fixes (External Review)

### Fixed (CRITICAL)
- **1.1**: RLS policy `authz_in_scope(NULL)` blocked ALL access to industry tables — replaced with proper auth check (authz_in_scope + authz_check_admin + owner)
- **1.2**: Duplicate password_reset_tokens table dropped — consolidated to otp_store from migration 143
- **1.3**: login_admin gracefully deprecated — returns error message instead of crashing callers
- **1.4**: request_password_reset no longer leaks token in API response — token only sent via email

### Fixed (IMPORTANT)
- **2.1**: 12 admin functions rewritten to query correct tables (badges, okrs, assets, estate_blocks, surveys, whistleblowers, exit_interviews, final_settlements, referrals, headcount_plans, budget_allocation, asset_assignments)
- **2.2**: admin_get_budget consolidated (028/043 -> 146)
- **2.3**: admin_get_certifications now uses certifications table (was hr_skills)

### Fixed (ODD)
- **3.1**: Generic audit trigger now filters password_hash, salt, auth_id, token, token_hash, code_hash

### Added
- **5.1**: admin_reset_mfa(nrp) — admin can reset worker MFA with authz check
- **5.2**: cleanup_ai_rate_limits() + cleanup_audit_log(days) — auto-cleanup functions

### Migration Order
141 -> 143 -> 144 -> 145 -> 146 (sequential)

## [147] - 2026-09-05 — Configurable Cleanup

### Added
- **4 config keys** in company_config (security category): audit_log_retention_days (90), ai_rate_limit_retention_days (30), session_retention_days (7), login_attempt_retention_days (14)
- **cleanup_expired_data()** — reads retention from company_config dynamically, cleans audit_log + api_rate_limits + session_tokens + login_attempts + otp_store
- pg_cron schedule (commented out, enable via dashboard)
- Manual trigger: SELECT cleanup_expired_data()

### Migration Order
141 -> 143 -> 144 -> 145 -> 146 -> 147 (sequential)

## [148] - 2026-09-05 — Partitioning + Encryption

### Added
- **B1**: hr_attendance_partitioned — declarative partitioning by date range (48 monthly partitions 2024-2027)
- **B2**: pgcrypto column-level encryption — nik_encrypted, npwp_encrypted, alamat_encrypted, no_hp_encrypted
- **encrypt_pii() / decrypt_pii() / mask_pii()** — encryption helper functions
- **encrypt_existing_pii()** — one-time migration to encrypt all existing PII data
- **get_employee_pii(nrp)** — admin sees decrypted, worker sees masked (e.g. 08****34)

### Documentation
- API_REFERENCE.md — 70+ RPCs documented with params, auth, descriptions
- ARCHITECTURE.md — ERD, auth flow, 8 security layers, migration history
- DR_PLAN.md — Backup strategy, 4 recovery scenarios, RTO/RPO, monitoring

### Migration Order
141 -> 143 -> 144 -> 145 -> 146 -> 147 -> 148 (sequential)

## [149] - 2026-09-05 — PILAR 1: Payroll Compliance Engine

### Added
- **10 compliance columns** on hr_payroll: bpjs_jht, bpjs_jp, bpjs_jkk, bpjs_jkm, bpjs_jkp, tapera_employee, tapera_employer, pph21_ter, thr_amount, gross_salary
- **14 config keys** (salary category): PPh 21 TER, Tapera, BPJS JHT/JP/JKK/JKM/JKP, THR rates + toggles
- **calculate_payroll_components(nrp, period)** — config-driven engine, reads all rates from company_config
- **calculate_all_payroll(period)** — batch calculate for all employees

### Fixed
- 145: get_dashboard_cached() now queries net_salary instead of non-existent gross_salary

----------|:------:|:-----:|
| Audit Trail | 75% | **85%** |
| PDP/Privacy | 60% | **80%** |
| API Security | 40% | **75%** |
| Indexing | 70% | **85%** |
| Performance | 70% | **88%** |
| Compliance | 70% | **80%** |
| Governance | 80% | **85%** |

### Migration Order
141 -> 143 -> 144 -> 145 (sequential)

---

*Last updated: September 5, 2026*

## [144] - 2026-09-04 — Smoke Test FAILures Fix

### Fixed
- **CRITICAL**: 338 legacy SECURITY DEFINER functions missing SET search_path — bulk ALTER via DO block
- **CRITICAL**: 17 USING(true) RLS policies on sensitive tables — DROP + recreate with proper auth
- **HIGH**: export_my_data used SELECT * on payroll/attendance/etc — whitelist 11 sub-queries
- **HIGH**: password_reset_tokens table missing — created with RLS
- **MEDIUM**: NRP001 test account password mismatch — re-seeded with bcrypt CEO123!
- **MEDIUM**: Smoke test credentials wrong (NIK_TEST/Password123!) — corrected to NRP001/CEO123!

### Changed
- smoke_test_backend.sql: credentials fixed
- smoke_test_frontend.js: credentials fixed

### Migration Order
141 -> 143 -> 144 (sequential)
