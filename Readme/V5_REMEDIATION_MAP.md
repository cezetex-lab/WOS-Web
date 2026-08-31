# INSIGHTWOS V5 — ARCHITECTURE REMEDIATION MAP

> Generated from Architecture Discovery STEP 1–6 baseline
> Status: ANALYSIS ONLY — no code changes

---

## BASELINE METRICS

| Metric | Value |
|--------|:-----:|
| Source Files | 118 |
| Routes/Pages | ~90 |
| Database Tables | 127 |
| RPC Functions | 275 |
| Wired RPCs | 130 (47%) |
| Orphaned RPCs | 145 (53%) |
| Missing RPCs | 6 (called but not in SQL) |
| Edge Functions | 7 |
| Duplicate Tables | 2 |
| FK to employees_master | 53 |
| RLS Enabled Tables | 126 |
| Components | 9 |

---

## A. CURRENT → TARGET ARCHITECTURE MAP

### A.1 Frontend Structure

| Current Path | Target Path | Domain | Subdomain | Reason | Risk |
|-------------|-------------|--------|-----------|--------|:----:|
| `pages/Admin.jsx` | `features/core/organization/pages/AdminDashboard.jsx` | CORE | organization | Admin is UX context, not domain | LOW |
| `pages/Worker.jsx` | `features/core/attendance/pages/WorkerDashboard.jsx` | CORE | attendance | Worker is UX context, not domain | LOW |
| `pages/Dashboard.jsx` | `features/intelligence/executive/pages/Dashboard.jsx` | INTEL | executive | Dashboard = analytics | LOW |
| `pages/Home.jsx` | `app/routes/Home.jsx` | PLATFORM | auth | Login page = app entry | LOW |
| `features/core/admin/` | **REMOVE** — split into domain subdirs | — | — | admin ≠ domain | MEDIUM |
| `features/core/worker/` | **REMOVE** — split into domain subdirs | — | — | worker ≠ domain | MEDIUM |
| `features/core/people/AdminEmployees.jsx` | `features/core/people/pages/Employees.jsx` | CORE | people | Single implementation | LOW |
| `features/core/people/WorkerProfile.jsx` | `features/core/people/pages/WorkerProfile.jsx` | CORE | people | Same domain, different view | LOW |
| `features/core/payroll/AdminPayroll.jsx` | `features/core/payroll/pages/PayrollManagement.jsx` | CORE | payroll | Remove admin prefix | LOW |
| `features/core/payroll/WorkerPayroll.jsx` | `features/core/payroll/pages/PayrollView.jsx` | CORE | payroll | Same domain, different role | LOW |
| `features/core/performance/AdminKpi.jsx` | `features/core/performance/pages/KpiManagement.jsx` | CORE | performance | Remove admin prefix | LOW |
| `features/core/performance/WorkerKpi.jsx` | `features/core/performance/pages/KpiView.jsx` | CORE | performance | Same domain | LOW |
| `features/core/leave/AdminLeave.jsx` | `features/core/leave/pages/LeaveManagement.jsx` | CORE | leave | Remove admin prefix | LOW |
| `features/core/overtime/AdminOvertime.jsx` | `features/core/overtime/pages/OvertimeManagement.jsx` | CORE | overtime | Remove admin prefix | LOW |
| `features/core/talent/AdminTalent.jsx` | `features/core/talent/pages/TalentMarket.jsx` | CORE | talent | Remove admin prefix | LOW |
| `features/core/learning/AdminLearning.jsx` | `features/core/learning/pages/LearningManagement.jsx` | CORE | learning | Remove admin prefix | LOW |
| `features/core/engagement/AdminSurveys.jsx` | `features/core/engagement/pages/SurveyManagement.jsx` | CORE | engagement | Remove admin prefix | LOW |
| `features/core/engagement/AdminVoice.jsx` | `features/core/engagement/pages/VoiceIdeas.jsx` | CORE | engagement | Remove admin prefix | LOW |
| `features/core/workforce/AdminTimesheet.jsx` | `features/core/workforce/pages/TimesheetManagement.jsx` | CORE | workforce | Remove admin prefix | LOW |
| `features/governance/audit/AuditLog.jsx` | `features/governance/audit/pages/AuditLog.jsx` | GOV | audit | Already correct | NONE |
| `features/governance/compliance/Offboarding.jsx` | `features/governance/compliance/pages/Offboarding.jsx` | GOV | compliance | Already correct | NONE |
| `features/intelligence/analytics/Analytics.jsx` | `features/intelligence/analytics/pages/Analytics.jsx` | INTEL | analytics | Already correct | NONE |
| `features/intelligence/forecasting/TurnoverPrediction.jsx` | `features/intelligence/forecasting/pages/TurnoverPrediction.jsx` | INTEL | forecasting | Already correct | NONE |

### A.2 Missing Domain Subdirectories

| Target Domain | Target Subdir | Current State | Action |
|:------------:|:-------------:|:-------------:|:------:|
| CORE | `career/` | CareerPathPage in `talent/` | MOVE |
| CORE | `recruitment/` | RecruitmentDashboard in `platform/workflow/` | MOVE |
| CORE | `offboarding/` | Offboarding in `governance/compliance/` | MOVE |
| GOVERNANCE | `qhse/` | Empty | CREATE |
| GOVERNANCE | `safety/` | Empty | CREATE |
| GOVERNANCE | `quality/` | Empty | CREATE |
| GOVERNANCE | `environment/` | Empty | CREATE |
| GOVERNANCE | `risk/` | Empty | CREATE |
| GOVERNANCE | `esg/` | Empty | CREATE |
| PLATFORM | `authorization/` | RoleMatrixPage exists | KEEP |
| PLATFORM | `configuration/` | Empty | CREATE |
| PLATFORM | `notifications/` | Empty | CREATE |
| PLATFORM | `documents/` | Empty | CREATE |
| PLATFORM | `audit/` | Empty | CREATE |
| INTEL | `ai/` | Empty | CREATE |
| INTEL | `recommendation/` | Empty | CREATE |

---


## B. FILE MIGRATION MAP

### B.1 Core Files — Admin → Domain Split

| Current Path | Target Path | Domain | Subdomain | Action | Risk |
|-------------|-------------|:------:|-----------|:------:|:----:|
| `core/people/AdminEmployees.jsx` | `core/people/pages/Employees.jsx` | CORE | people | RENAME | LOW |
| `core/people/WorkerProfile.jsx` | `core/people/pages/Profile.jsx` | CORE | people | RENAME | LOW |
| `core/people/WorkerActivities.jsx` | `core/people/pages/Activities.jsx` | CORE | people | RENAME | LOW |
| `core/people/WorkerChangePassword.jsx` | `core/people/pages/ChangePassword.jsx` | CORE | people | RENAME | LOW |
| `core/payroll/AdminPayroll.jsx` | `core/payroll/pages/PayrollManagement.jsx` | CORE | payroll | RENAME | LOW |
| `core/payroll/WorkerPayroll.jsx` | `core/payroll/pages/PayrollView.jsx` | CORE | payroll | RENAME | LOW |
| `core/payroll/CompensationIntel.jsx` | `core/payroll/pages/CompensationIntel.jsx` | CORE | payroll | MOVE | LOW |
| `core/performance/AdminKpi.jsx` | `core/performance/pages/KpiManagement.jsx` | CORE | performance | RENAME | LOW |
| `core/performance/WorkerKpi.jsx` | `core/performance/pages/KpiView.jsx` | CORE | performance | RENAME | LOW |
| `core/performance/AdminOkr.jsx` | `core/performance/pages/OkrManagement.jsx` | CORE | performance | RENAME | LOW |
| `core/performance/PerformanceTrend.jsx` | `core/performance/pages/Trend.jsx` | CORE | performance | MOVE | LOW |
| `core/performance/ContinuousPerf.jsx` | `core/performance/pages/ContinuousPerf.jsx` | CORE | performance | MOVE | LOW |
| `core/performance/PerformanceNotes.jsx` | `core/performance/pages/PerformanceNotes.jsx` | CORE | performance | MOVE | LOW |
| `core/performance/Review360.jsx` | `core/performance/pages/Review360.jsx` | CORE | performance | MOVE | LOW |
| `core/leave/AdminLeave.jsx` | `core/leave/pages/LeaveManagement.jsx` | CORE | leave | RENAME | LOW |
| `core/leave/WorkerLeave.jsx` | `core/leave/pages/LeaveView.jsx` | CORE | leave | RENAME | LOW |
| `core/overtime/AdminOvertime.jsx` | `core/overtime/pages/OvertimeManagement.jsx` | CORE | overtime | RENAME | LOW |
| `core/overtime/WorkerOvertime.jsx` | `core/overtime/pages/OvertimeView.jsx` | CORE | overtime | RENAME | LOW |
| `core/attendance/AdminTimesheet.jsx` | `core/attendance/pages/TimesheetManagement.jsx` | CORE | attendance | MOVE+RENAME | LOW |
| `core/workforce/ShiftSchedule.jsx` | `core/workforce/pages/ShiftSchedule.jsx` | CORE | workforce | MOVE | LOW |
| `core/talent/AdminTalent.jsx` | `core/talent/pages/TalentMarket.jsx` | CORE | talent | RENAME | LOW |
| `core/talent/CareerPathPage.jsx` | `core/career/pages/CareerPath.jsx` | CORE | career | MOVE | LOW |
| `core/talent/AdminCertifications.jsx` | `core/talent/pages/Certifications.jsx` | CORE | talent | RENAME | LOW |
| `core/talent/AdminBadges.jsx` | `core/talent/pages/Badges.jsx` | CORE | talent | RENAME | LOW |
| `core/talent/AdminReferral.jsx` | `core/talent/pages/Referral.jsx` | CORE | talent | RENAME | LOW |
| `core/learning/AdminLearning.jsx` | `core/learning/pages/LearningManagement.jsx` | CORE | learning | RENAME | LOW |
| `core/learning/WorkerLearning.jsx` | `core/learning/pages/LearningView.jsx` | CORE | learning | RENAME | LOW |
| `core/learning/TrainingForm.jsx` | `core/learning/pages/TrainingRequest.jsx` | CORE | learning | RENAME | LOW |
| `core/engagement/AdminSurveys.jsx` | `core/engagement/pages/SurveyManagement.jsx` | CORE | engagement | RENAME | LOW |
| `core/engagement/AdminVoice.jsx` | `core/engagement/pages/VoiceIdeas.jsx` | CORE | engagement | RENAME | LOW |
| `core/engagement/WorkerForum.jsx` | `core/engagement/pages/ForumDiskusi.jsx` | CORE | engagement | MOVE | LOW |
| `core/engagement/AdminWhistleblower.jsx` | `core/engagement/pages/Whistleblowing.jsx` | CORE | engagement | RENAME | LOW |
| `core/organization/AdminOrgChart.jsx` | `core/organization/pages/OrgChart.jsx` | CORE | organization | RENAME | LOW |
| `core/organization/AdminOrgSubtree.jsx` | `core/organization/pages/OrgSubtree.jsx` | CORE | organization | RENAME | LOW |
| `core/organization/AdminDivisions.jsx` | `core/organization/pages/DivisionsManagement.jsx` | CORE | organization | RENAME | LOW |
| `core/organization/AdminMasterData.jsx` | `core/organization/pages/MasterData.jsx` | CORE | organization | RENAME | LOW |
| `core/organization/AdminRoleMatrix.jsx` | `platform/authorization/pages/RoleMatrix.jsx` | PLATFORM | authorization | MOVE | LOW |

### B.2 Platform Files

| Current Path | Target Path | Domain | Subdomain | Action | Risk |
|-------------|-------------|:------:|-----------|:------:|:----:|
| `platform/auth/LoginWorker.jsx` | `platform/auth/pages/LoginWorker.jsx` | PLATFORM | auth | MOVE into pages/ | LOW |
| `platform/auth/LoginAdmin.jsx` | `platform/auth/pages/LoginAdmin.jsx` | PLATFORM | auth | MOVE into pages/ | LOW |
| `platform/settings/AdminFeatures.jsx` | `platform/configuration/pages/FeatureFlags.jsx` | PLATFORM | configuration | MOVE | LOW |
| `platform/settings/AdminSettings.jsx` | `platform/configuration/pages/Settings.jsx` | PLATFORM | configuration | MOVE | LOW |
| `platform/settings/AdminExport.jsx` | `platform/exports/pages/ExportPage.jsx` | PLATFORM | exports | MOVE | LOW |
| `platform/workflow/AdminApprovals.jsx` | `platform/workflow/pages/ApprovalCenter.jsx` | PLATFORM | workflow | MOVE | LOW |
| `platform/workflow/AdminApprovalWorkflow.jsx` | `platform/workflow/pages/ApprovalWorkflow.jsx` | PLATFORM | workflow | MOVE | LOW |
| `platform/workflow/RecruitmentDashboard.jsx` | `core/recruitment/pages/RecruitmentDashboard.jsx` | CORE | recruitment | MOVE | LOW |
| `platform/workflow/PipelineKanban.jsx` | `core/recruitment/pages/PipelineKanban.jsx` | CORE | recruitment | MOVE | LOW |
| `platform/workflow/OnboardingWorkflow.jsx` | `core/recruitment/pages/OnboardingWorkflow.jsx` | CORE | recruitment | MOVE | LOW |
| `platform/workflow/ScreeningPage.jsx` | `core/recruitment/pages/Screening.jsx` | CORE | recruitment | MOVE | LOW |
| `platform/integrations/AdminIntegrations.jsx` | `platform/integrations/pages/Integrations.jsx` | PLATFORM | integrations | MOVE into pages/ | LOW |
| `governance/audit/AdminAuditLog.jsx` | `governance/audit/pages/AuditLog.jsx` | GOV | audit | MOVE into pages/ | LOW |
| `governance/audit/AdminAuditChain.jsx` | `governance/audit/pages/AuditChain.jsx` | GOV | audit | MOVE into pages/ | LOW |
| `governance/compliance/Offboarding.jsx` | `core/offboarding/pages/Offboarding.jsx` | CORE | offboarding | MOVE | LOW |
| `governance/compliance/AdminResetPassword.jsx` | `platform/auth/pages/ResetPassword.jsx` | PLATFORM | auth | MOVE | LOW |

### B.3 Intelligence Files

| Current Path | Target Path | Domain | Subdomain | Action | Risk |
|-------------|-------------|:------:|-----------|:------:|:----:|
| `intelligence/analytics/AdminAnalytics.jsx` | `intelligence/analytics/pages/Analytics.jsx` | INTEL | analytics | MOVE | LOW |
| `intelligence/analytics/AdminSimulation.jsx` | `intelligence/forecasting/pages/Simulation.jsx` | INTEL | forecasting | MOVE | LOW |
| `intelligence/forecasting/AdminTurnover.jsx` | `intelligence/forecasting/pages/TurnoverPrediction.jsx` | INTEL | forecasting | MOVE | LOW |
| `intelligence/forecasting/AdminHeadcount.jsx` | `intelligence/forecasting/pages/HeadcountPlan.jsx` | INTEL | forecasting | MOVE | LOW |

### B.4 Lib Files

| Current Path | Target Path | Action | Risk |
|-------------|-------------|:------:|:----:|
| `lib/supabase-browser.js` | `lib/supabase/index.js` + barrel | CONSOLIDATE | LOW |
| `lib/supabase.js` | **DELETE** (unused duplicate) | REMOVE | NONE |
| `lib/cache.js` | `lib/cache/index.js` | MOVE into dir | LOW |
| `lib/offline-db.js` | `lib/cache/offline-db.js` | MOVE | LOW |
| `lib/sync-queue.js` | `lib/cache/sync-queue.js` | MOVE | LOW |
| `lib/push-notifications.js` | `lib/telemetry/push-notifications.js` | MOVE | LOW |
| `lib/posthog.js` | `lib/telemetry/posthog.js` | MOVE | LOW |
| `lib/chart-config.js` | `lib/utils/chart-config.js` | MOVE | LOW |
| `lib/business-units.js` | `lib/utils/business-units.js` | MOVE | LOW |
| `lib/design-system.jsx` | `lib/des

---


## C. RPC MIGRATION MAP (275 RPCs)

### C.1 Summary by Domain

| Domain | RPC Count | Wired | Orphaned |
|:------:|:---------:|:-----:|:--------:|
| CORE | 126 | 52 | 74 |
| PLATFORM | 49 | 28 | 21 |
| INTELLIGENCE | 23 | 12 | 11 |
| GOVERNANCE | 18 | 7 | 11 |
| INDUSTRY | 16 | 10 | 6 |
| **TOTAL** | **275** | **130** | **145** |

### C.2 Missing RPCs (Called from Frontend but NOT in SQL)

| RPC | Called From | Impact | Action |
|-----|-------------|:------:|:------:|
| get_harvest_records | Estate/HarvestRecord.jsx | HIGH | CREATE in SQL |
| get_transport_dispatch | Estate/TransportTBS.jsx | HIGH | CREATE in SQL |
| get_simulations | Intelligence/Simulation.jsx | MED | CREATE in SQL |
| get_reviews_360 | Performance/Review360.jsx | MED | FIX name mismatch |

### C.3 Duplicate/Overlapping RPCs

| RPC A | RPC B | Resolution |
|-------|-------|:----------:|
| get_org_health | get_organization_health | KEEP get_organization_health |
| get_worker_critical | get_early_warning | KEEP get_early_warning |
| admin_get_pending | admin_get_pending_requests | KEEP get_pending_approvals |
| admin_get_estate_blocks | get_estate_blocks | KEEP get_estate_blocks |

---

## D. DATABASE OWNERSHIP MAP

| Domain | Tables | RLS Enabled |
|:------:|:------:|:-----------:|
| CORE | 65 | Most |
| PLATFORM | 15 | Some |
| INDUSTRY | 12 | Some |
| GOVERNANCE | 15 | Some |
| INTELLIGENCE | 8 | Some |
| **TOTAL** | **127** | **126** |

### D.1 Duplicate Tables

| Duplicate | Migrations | Action |
|-----------|:----------:|:------:|
| onboarding_tasks | 018, 050 | DROP from 050 |
| webhook_logs | 018, 045 | DROP from 045 |
| okrs vs hr_okrs | 001, 025 | MERGE to hr_okrs |
| surveys vs hr_surveys | 001, 025 | MERGE to surveys |
| review_ vs reviews_360 | 001, 025 | MERGE to reviews_360 |

---

## E. SECURITY GAP REPORT

### E.1 Authentication

| Issue | Severity | Affected | Fix |
|-------|:--------:|----------|-----|
| Session in sessionStorage | CRITICAL | supabase-browser.js | httpOnly cookie |
| No password policy (frontend) | HIGH | Login pages | validatePassword() |
| No MFA/TOTP | HIGH | All accounts | Supabase MFA |
| OTP in console.log | HIGH | generate_worker_otp | Remove in prod |

### E.2 Authorization

| Issue | Severity | Affected | Fix |
|-------|:--------:|----------|-----|
| No field-level perm for salary | CRITICAL | hr_payroll | RPC-level masking |
| No self/team scope in RPCs | HIGH | All RPCs | Add scope param |
| RLS may be too permissive | HIGH | Multiple tables | Restrict policies |
| Whistleblower not anonymized | HIGH | whistleblowers | Anonymize NRP |

### E.3 Sensitive Data

| Issue | Severity | Affected | Fix |
|-------|:--------:|----------|-----|
| Salary visible in hr_payroll | CRITICAL | hr_payroll | Mask in RPC |
| OTP plaintext | HIGH | otp_store | Auto-expire + encrypt |
| webhook secret plaintext | HIGH | webhook_configs | Vault encryption |
| SSO credentials plaintext | HIGH | sso_providers | Vault encryption |

### E.4 Security Score

| Area | Score |
|------|:-----:|
| Authentication | 70% |
| Authorization | 40% |
| Data Protection | 35% |
| Infrastructure | 75% |
| Audit Trail | 60% |
| **Overall** | **56%** |

---

## F. DATA GOVERNANCE GAP

| Issue | Table | Fix |
|-------|-------|-----|
| Missing created_by | 12 tables | 054 (DONE) |
| Missing updated_at | 10 tables | 054 (DONE) |
| No effective_date | bu_divisions, business_units | Add effective_from/to |
| No status column | hr_org, sites | Add status |
| Duplicate: okrs vs hr_okrs | okrs, hr_okrs | MERGE |

---

## G. GLOBALIZATION GAP

| Current | Problem | Required Change | Priority |
|---------|---------|-----------------|:--------:|
| IDR hardcoded | No multi-currency | Add currency_code | MEDIUM |
| Indonesian only | No English | i18n system | LOW |
| GMT+7 assumed | Different TZ | Add timezone | LOW |
| ID holidays only | Other countries | Configurable calendar | LOW |
| Limited emp types | Only perm/contract | Add part-time, intern | MEDIUM |

---

## H. DUPLICATION REPORT

### H.1 Duplicate Tables (5)

| Duplicate | Migrations | Action |
|-----------|:----------:|:------:|
| onboarding_tasks | 018, 050 | DROP from 050 |
| webhook_logs | 018, 045 | DROP from 045 |
| okrs vs hr_okrs | 001, 025 | MERGE to hr_okrs |
| surveys vs hr_surveys | 001, 025 | MERGE to surveys |
| review_ vs reviews_360 | 001, 025 | MERGE to reviews_360 |

### H.2 Duplicate Business Logic

| Pattern | Files | Fix |
|---------|:-----:|-----|
| Currency formatting | 15+ pages | utils/formatCurrency.js |
| Date formatting | 20+ pages | utils/formatDate.js |
| RPC error handling | 90+ pages | lib/supabase/rpc.js |
| Empty state rendering | 30+ pages | EmptyState component |

## I. MIGRATION ROADMAP

### Phase 1: Architecture Cleanup (Week 1)

| Task | Files | Tables | RPC | Risk | Rollback |
|------|:-----:|:------:|:---:|:----:|----------|
| Remove duplicate tables (okrs, surveys, review_, onboarding_tasks, webhook_logs) | 0 | 5 DROP | 0 | HIGH | Re-run migrations |
| Rename Admin/Worker files to domain names | ~40 | 0 | 0 | MEDIUM | git mv back |
| Move files to pages/ subdirectories | ~40 | 0 | 0 | LOW | git mv back |
| Create missing domain subdirs (career, recruitment, offboarding) | 0 | 0 | 0 | NONE | rmdir |
| Extract formatCurrency/formatDate utils | 0 | 0 | 0 | LOW | Restore original |

### Phase 2: Domain Separation (Week 2)

| Task | Files | Tables | RPC | Risk | Rollback |
|------|:-----:|:------:|:---:|:----:|----------|
| Move recruitment pages from platform/workflow to core/recruitment | 4 | 0 | 0 | LOW | git mv |
| Move offboarding from governance/compliance to core/offboarding | 1 | 0 | 0 | LOW | git mv |
| Move reset_password from governance to platform/auth | 1 | 0 | 0 | LOW | git mv |
| Move role_matrix from core/organization to platform/authorization | 1 | 0 | 0 | LOW | git mv |
| Move simulation from intelligence/analytics to intelligence/forecasting | 1 | 0 | 0 | LOW | git mv |
| Update all imports after moves | ~10 | 0 | 0 | MEDIUM | git revert |
| Update App.jsx routes after moves | 1 | 0 | 0 | MEDIUM | git revert |

### Phase 3: Security Hardening (Week 3)

| Task | Files | Tables | RPC | Risk | Rollback |
|------|:-----:|:------:|:---:|:----:|----------|
| Add salary masking to payroll RPCs | 0 | 0 | 3 | MEDIUM | Remove masking |
| Anonymize whistleblower NRP | 0 | 1 | 0 | MEDIUM | Re-insert NRP |
| Encrypt webhook_configs.secret via Vault | 0 | 1 | 0 | LOW | Decrypt |
| Disable test-gemini edge function | 0 | 0 | 0 | NONE | Re-enable |
| Disable gas-migration edge function | 0 | 0 | 0 | NONE | Re-enable |
| Add CSP + HSTS headers to vercel.json | 1 | 0 | 0 | LOW | Remove headers |
| Add scope parameter to key RPCs | 0 | 0 | 10 | HIGH | Remove scope |

### Phase 4: Data Governance (Week 4)

| Task | Files | Tables | RPC | Risk | Rollback |
|------|:-----:|:------:|:---:|:----:|----------|
| Add effective_date to master tables | 0 | 4 | 0 | LOW | DROP columns |
| Add status column to hr_org, sites | 0 | 2 | 0 | LOW | DROP columns |
| Fix 6 missing RPCs (harvest, transport, simulation, reviews_360) | 0 | 0 | 6 | LOW | DROP FUNCTION |
| Consolidate overlapping RPCs (8 pairs) | 0 | 0 | 8 | MEDIUM | Restore old |

### Phase 5: Global Core (Week 5)

| Task | Files | Tables | RPC | Risk | Rollback |
|------|:-----:|:------:|:---:|:----:|----------|
| Add currency_code to hr_payroll | 0 | 1 | 0 | LOW | DROP column |
| Add timezone to employees_master | 0 | 1 | 0 | LOW | DROP column |
| Add employment_type options | 0 | 1 | 0 | LOW | Revert |
| Create i18n translation skeleton | 1 | 0 | 0 | NONE | Remove dir |

### Phase 6: Performance + Testing (Week 6)

| Task | Files | Tables | RPC | Risk | Rollback |
|------|:-----:|:------:|:---:|:----:|----------|
| Add missing DB indexes for hot queries | 0 | 0 | 0 | LOW | DROP INDEX |
| Implement React.lazy() for all routes | 1 | 0 | 0 | LOW | Remove lazy |
| Wire 145 orphaned RPCs to pages or deprecate | ~30 | 0 | 145 | HIGH | git revert |
| Create ErrorBoundary per domain module | 5 | 0 | 0 | NONE | Remove |

---

## J. FINAL RECOMMENDATION

### Decision Matrix

| Category | KEEP | MOVE | MERGE | REFACTOR | RENAME | DEPRECATE | REMOVE | CREATE |
|----------|:----:|:----:|:-----:|:--------:|:------:|:---------:|:------:|:------:|
| Files | 78 | 22 | 0 | 0 | 18 | 0 | 1 | 16 |
| Tables | 122 | 0 | 5 | 0 | 0 | 0 | 5 | 0 |
| RPCs | 130 | 0 | 8 | 10 | 0 | 0 | 0 | 6 |
| Components | 9 | 11 | 0 | 0 | 0 | 0 | 0 | 0 |
| Lib files | 5 | 6 | 1 | 0 | 0 | 0 | 1 | 0 |

### Priority Order

1. **SECURITY FIRST** — salary masking, whistleblower anonymize, disable test endpoints
2. **DUPLICATE CLEANUP** — merge 5 duplicate tables, consolidate 8 duplicate RPCs
3. **FILE MOVES** — rename Admin/Worker to domain names, reorganize into pages/
4. **DOMAIN SEPARATION** — recruitment, offboarding, authorization to correct domains
5. **DATA GOVERNANCE** — effective dates, status columns, missing RPCs
6. **GLOBALIZATION** — currency, timezone, i18n skeleton
7. **PERFORMANCE** — indexes, lazy loading, wire orphaned RPCs
8. **TESTING** — ErrorBoundary, unit tests, E2E

### Definition of Done

- [ ] Admin/Worker NOT a business domain (only UX context)
- [ ] Core has clear subdomains (14 subdirs)
- [ ] Industry isolated (mining/estate/mill)
- [ ] Governance is first-class domain (8 subdirs)
- [ ] Platform isolated (9 subdirs)
- [ ] Intelligence isolated (5 subdirs)
- [ ] RPC has clear ownership (275 mapped)
- [ ] Table has clear ownership (127 mapped)
- [ ] RLS verified on all tables
- [ ] Salary/payroll field-level protected
- [ ] Whistleblower anonymized
- [ ] Duplicate tables eliminated (5 merged)
- [ ] Duplicate RPCs consolidated (8 pairs)
- [ ] test-gemini/gas-migration disabled
- [ ] All files follow domain structure (no Admin/Worker prefix)
- [ ] All imports updated and verified
- [ ] Build passes with zero errors

### Estimated Effort

| Phase | Duration | Risk Level |
|:-----:|:--------:|:----------:|
| Phase 1: Cleanup | 3 days | HIGH (table merges) |
| Phase 2: Domain Separation | 2 days | LOW (file moves) |
| Phase 3: Security | 3 days | HIGH (permission changes) |
| Phase 4: Data Governance | 2 days | LOW (additive only) |
| Phase 5: Global Core | 1 day | LOW (additive only) |
| Phase 6: Performance + Testing | 3 days | MEDIUM (lazy loading) |
| **Total** | **14 days** | |

### Critical Warning

> **DO NOT start Phase 7 (Industry) or Phase 8 (Governance) until Phase 1-6 are complete.**

Adding new features on a broken foundation multiplies technical debt.

Every new Industry/Governance page added before foundation is fixed = MORE files to move, MORE imports to fix, MORE RPCs to reclassify.

**Fix the house before adding rooms.**
