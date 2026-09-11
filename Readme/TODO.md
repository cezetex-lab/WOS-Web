# TODO.md — insightWOS V6

> Remaining tasks yang butuh dedicated sprint. Bukan blocker untuk deploy.

---

## Q1–Q5: Test Coverage (Priority: HIGH)

### Q1: Automated RPC Tests ✅ (migration 184, 47/47 pass)
- [x] Test `login_worker` — exists + SECDEF verified
- [x] Test `worker_change_password` — exists
- [x] Test `get_worker_payroll_secure` — exists + SECDEF
- [x] Test `admin_get_employees` — exists
- [x] Test `export_my_data` — exists (GDPR)
- [x] Test `grant_consent` — exists (privacy)
- [x] Test `register_session` — exists
- [x] Test `check_login_lockout` — exists
- [x] All 8 RPC cron functions — exist
- [x] All 7 Estate + 7 Mill functions — exist

### Q2: IDOR Tests ✅ (migration 184)
- [x] decrypt_pii is SECURITY DEFINER
- [x] get_worker_payroll_secure is SECDEF
- [x] login_worker is SECDEF

### Q3: RLS Tests ✅ (migration 184)
- [x] employees_core RLS enabled
- [x] employees_extended RLS enabled
- [x] hr_payroll RLS enabled
- [x] hr_attendance RLS enabled
- [x] system_owner_identity FORCE RLS
- [x] RLS coverage count verified
- [x] decrypt_pii NOT granted to anon

### Q4: Privilege Escalation Tests ✅ (migration 184)
- [x] admin_change_password is SECDEF
- [x] admin_reset_worker_password is SECDEF
- [x] all admin_* functions are SECDEF
- [x] all export_* functions are SECDEF
- [x] all owner_* functions are SECDEF
- [x] decrypt_pii is SECDEF
- [x] rls_auto_enable is SECDEF

### Q5: E2E Tests (Playwright)
- [ ] Login → Dashboard load → Logout flow
- [ ] Admin login → Payroll view → Filter by BU
- [ ] Worker login → Check attendance → Request leave
- [ ] Role change → Verify new permissions active immediately
- [ ] Concurrent session limit test

---

## A7: Migration Versioning System
- [ ] Add `schema_migrations` table tracking version + checksum
- [ ] Each migration file gets `-- VERSION: xxx` header
- [ ] Startup check: detect unapplied / duplicate migrations
- [ ] Rollback scripts for critical migrations (131–143)

---

## TypeScript Migration
- [ ] Convert SQL RPCs to TypeScript edge functions (Supabase Edge Functions)
- [ ] Type-safe RPC calls with generated Supabase types
- [ ] Shared validation library (Zod) for input validation
- [ ] Remove raw SQL from frontend, use typed client

---

## E2E Testing (Playwright)
- [x] Setup Playwright config for Supabase local
- [x] Auth flow tests (login, logout, session expiry) -- login-flow.spec.js
- [ ] Dashboard rendering tests (stats, charts, tables)
- [x] RBAC navigation tests (admin sees correct menu, worker sees correct menu) -- role-change.spec.js
- [ ] PWA offline mode tests (Service Worker caching)

---

## Other TODOs
- [ ] **B2**: `login_admin` migration to Supabase Auth (bcrypt via `auth.users`)
- [ ] **N1**: AI RAG document access filtering (extend to all modules)
- [ ] **N4**: AI query rate limit tuning (currently 50/day, adjust based on usage)
- [x] **I5**: Split `employees_master` God Table into `employees_core` + `employees_extended` (migration 183)
- [ ] **I1**: Resolve duplicate tables (mill_boiler 052 vs 074, okrs vs hr_okrs)
- [x] **P1**: Implement data retention cleanup job (pg_cron) -- migration 186
- [ ] **O5**: Hash-chain audit log (tamper-evident chain with prev_hash)
- [x] **M3**: Auto-refresh materialized view (035) via pg_cron -- migration 186
- [ ] **R4**: Write rollback scripts for all critical migrations

---

*Last updated: 2026-09-07*
*Migration 186 deployed (pg_cron), DynamicRoutes enabled, E2E tests written*
