# CHANGELOG - insightWOS

All notable changes (newest first).

---

## 05 Sep 2026
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

---

*Last updated: September 5, 2026*
