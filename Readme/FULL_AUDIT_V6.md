# FULL AUDIT REPORT - insightWOS V6
**Generated:** September 4, 2026
**Overall Score: 66/100**

## SUMMARY SCORECARD

| Category | Score | Priority |
|----------|:-----:|:--------:|
| A. Architecture | 72% | WARNING |
| B. Authentication | 78% | WARNING |
| C. Owner Security | 88% | OK |
| D. Admin RBAC | 65% | CRITICAL |
| E. BU Isolation | 70% | CRITICAL |
| F. RLS | 80% | WARNING |
| G. SECURITY DEFINER | 68% | CRITICAL |
| H. RPC | 72% | WARNING |
| I. Database | 75% | WARNING |
| J. Data Sensitive | 70% | CRITICAL |
| K. Frontend | 68% | CRITICAL |
| L. Service Worker | 60% | WARNING |
| M. Performance | 55% | CRITICAL |
| N. AI / Intelligence | 50% | CRITICAL |
| O. Audit & Governance | 72% | WARNING |
| P. Privacy | 45% | CRITICAL |
| Q. Testing | 30% | CRITICAL |
| R. Deployment | 70% | WARNING |

## TOP 10 CRITICAL FIXES

| # | Issue | Score Impact |
|---|-------|:------------:|
| 1 | Admin RPCs have no role check - any authenticated user can call admin_* | D=65, G=68 |
| 2 | No password reset flow | B=78 |
| 3 | 5 tables without RLS (hr_audit_chain, hr_okr_results, hr_shift_swaps, hr_survey_responses, hr_task_board) | F=80 |
| 4 | admin_* RPCs grant to authenticated without role verification | G=68 |
| 5 | 30 console.log in production code | K=68 |
| 6 | No concurrent session control | B=78 |
| 7 | AI copilot still references service_role in code path | N=50 |
| 8 | employees_master God Table - 30+ columns | I=75 |
| 9 | No data export/deletion workflow (UU PDP) | P=45 |
| 10 | Test coverage 30% - no E2E, no auth tests | Q=30 |

## KEY METRICS

- Total migrations: 137 (18 numbers skipped)
- Total tables: 184
- Total RPCs: 767
- SECURITY DEFINER functions: 67+
- Frontend routes: 112
- Admin pages with useAdminAuth: 51
- console.log remaining: 30
- sessionStorage remaining: 0 (posthog fixed)
- localStorage remaining: 30+ (cache, theme, language - acceptable)
- USING(true) remaining: 1 (in comment only)
- RLS enabled tables: 174
- Tables without RLS: 5
- Test files: 15
- Test passing: 64/75 (85%)
