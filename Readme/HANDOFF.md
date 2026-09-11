# HANDOFF.md - insightWOS V6

**Date:** September 5, 2026
**Author:** Buffy (Codebuff AI)
**Status:** Production-ready backend (migrations 000-164)

---

## 1. PROJECT OVERVIEW

insightWOS is an HR Management System (HRMS) built on:
- Backend: PostgreSQL via Supabase (PostgREST RPCs)
- Frontend: React (Vite) deployed on Vercel
- Auth: Supabase Auth + custom session_tokens + MFA (TOTP)
- AI: Gemini Flash (RAG for HR copilot)

### Architecture Layers
1. Owner - system_owner_identity (NOT an employee)
2. Admin - role-based (admin_hrd, admin_finance, etc.)
3. Worker - NRP + NIK + password/bcrypt, scoped to BU
4. Authorization Engine - authz_current_nrp(), authz_check_admin()
5. RLS - enforced on ALL tables, FORCE ROW LEVEL SECURITY

---

# MIGRATION RULES — insightWOS V6
**Last Updated:** September 4, 2026

## RULE 1: NEVER RUN CLEAN.sql
CLEAN.sql drops and recreates functions. It conflicts with 071-139.
If you need to reset, use specific DROP + CREATE statements.

## RULE 2: SEQUENTIAL ORDER ONLY
Migrations MUST run in numerical order: 000 → 001 → ... → 140.
Never skip. Never run out of order. Never run a subset.

## RULE 3: IDEMPOTENT MIGRATIONS
Every migration must use:
- CREATE TABLE IF NOT EXISTS
- CREATE OR REPLACE FUNCTION
- DROP FUNCTION IF EXISTS before CREATE
- DROP POLICY IF EXISTS before CREATE POLICY
- INSERT ... ON CONFLICT DO NOTHING

## RULE 4: SECURITY DEFINER + search_path
Every SECURITY DEFINER function MUST have:
SET search_path = public
This prevents SQL injection via search_path manipulation.

## RULE 5: AUTH via auth.uid()
Every RPC that accesses user data MUST:
1. Get NRP from auth.uid() via authz_current_nrp()
2. NEVER accept NRP from client parameter for identity
3. Check permission via authz_check_admin(permission_code)
4. Check scope via authz_in_scope(target_nrp)

## RULE 6: RLS on ALL tables
Every table MUST have:
- ENABLE ROW LEVEL SECURITY
- FORCE ROW LEVEL SECURITY
- At least one SELECT policy
- Never USING (true) — use auth.uid() IS NOT NULL minimum

## RULE 7: NO HARDCODED ROLES
Never use: role IN ('admin_hrd', 'admin_finance', ...)
Always use: authz_check_admin('permission.code')
Always use: authz_has_role('role_code')

## RULE 8: TIER = SUBSCRIPTION, NOT AUTHORIZATION
Tier/plan controls which modules are enabled for a BU.
Tier does NOT control what a user can do.
Authorization is via ROLE → PERMISSION → SCOPE.

## RULE 9: NO DUPLICATE FUNCTIONS
Before creating a new function, check if it already exists.
Use DROP FUNCTION IF EXISTS + CREATE OR REPLACE FUNCTION.

## RULE 10: TEST BEFORE PRODUCTION
Every migration must be tested on a fresh database.
Never apply untested migrations to production.

## URUTAN MIGRASI YANG BENAR

### Foundation (000-005)
000_pgcrypto → 001_init → 002_auth → 003_fix_columns → 004_seed → 005_fix_hash

### Core (011, 018)
011_ULTIMATE (core RPCs) → 018_new_25_tables

### Waves (033-048)
033 → 034 → 035 → 036 → 038 → 039 → 040 → 042 → 043 → 044 → 045 → 046 → 047 → 048

### Industry (050-065)
050 → 051 → 052 (Mill tables) → 053 → 054 → 055 → 057 (MFA) → 058 → 059 → 060 → 061 → 062 → 063 → 065

### Owner + Admin (071-095)
071 → 072 → 073 → 075 → 076 → 077 → 078 → 079 → 080 → 081 → 082 → 083 → 084 → 086 → 087 → 088 → 089 → 090 → 091 → 092 → 093 → 095

### Owner Dashboard (100-120)
100 → 101 → 102 → 110 → 111 → 120

### Security Hardening (130-140)
130 → 131 → 132 → 133 → 134 → 135 → 136 → 137 → 138 → 139 → 140

## FILE STATUS

| File | Status | Note |
|------|:------:|------|
| 000-005 | KEEP | Foundation |
| 011 | KEEP | Core RPCs (final) |
| 018 | KEEP | Additional tables |
| 033-048 | KEEP | Waves 1-8 |
| 050-065 | KEEP | Industry + MFA |
| 071-095 | KEEP | Owner + Admin |
| 100-120 | KEEP | Owner Dashboard |
| 130-140 | KEEP | Security hardening |
| 006-010, 012-013, 017, 019-032, 037, 056, 064, 074, 085, 094 | DELETED | Superseded |
| CLEAN.sql, debug_ceo_auth.sql | DELETED | Conflicts/Debug |

---
## 3. ADDITIONAL RULES

### RULE 11: CONFIG-DRIVEN
Business rules, rates, toggles go in company_config.
NEVER hardcode rates in functions. Read from config.

### RULE 12: ENCRYPTION KEY IN CONFIG
Key in company_config (security.encryption_key).
Key: <REDACTED>

### RULE 13: audit_log COLUMNS
Columns: id, action (TEXT), detail (TEXT), timestamp (TIMESTAMPTZ).
NOT: result, message, created_at - those do NOT exist.

---

## 4. MIGRATION STATUS

164 migrations complete. Run order:
Phase 1: Foundation 000-005
Phase 2: Core 011, 018
Phase 3: Waves 033-048
Phase 4: Industry 050-065
Phase 5: Owner/Admin 071-095
Phase 6: Owner Dash 100-120
Phase 7: Security 130-140
Phase 8: Audit Fix 141-153 (or CONSOLIDATED_141_153.sql)
Phase 9: GAS Plan 154-164

### GAS Plan Files
154: Pilar 2 Self-Service (4 tables, 14 RPCs)
155: Pilar 3 Platform (3 tables, 3 RPCs)
156: Pilar 4 AI (3 RPCs)
157: Pilar 5 Flexibility (4 tables, 3 RPCs)
158: Fase 1 Employees Master (33 columns)
159: Fase 2 Master Data (6 tables, 48 divisi)
160: Fase 3 HR Engine (6 functions)
161: Fase 4 Narrative Intelligence
162: Fase 5 Preview Data
163: Fase 6 Workforce Simulation
164: Fase 7 Auth Flow OTP

---

## 5. KEY DATABASE OBJECTS

### Auth Engine
authz_current_nrp() - Get caller NRP from auth.uid()
authz_check_admin(perm) - Check admin permission
authz_in_scope(target_nrp) - Check data scope
authz_has_role(role) - Check specific role

### Core Auth
login_worker(nrp, nik, password) - Returns token
worker_logout() - Invalidate session
request_password_reset(email) - Send OTP
reset_password(token, new_pass) - Reset with OTP
change_password(old, new) - Worker self-change

### Owner RPCs
owner_update_role, owner_set_tier, owner_force_logout

### Security Tables
system_owner_identity, admin_roles, role_permission_sets
session_tokens, worker_passwords, otp_store, mfa_factors
login_attempts, audit_log, api_keys, api_rate_limits

---

## 6. ENCRYPTION
Key: company_config security.encryption_key
Key value: <REDACTED>
Functions: encrypt_pii, decrypt_pii, mask_pii
Run once: SELECT encrypt_existing_pii()

---

## 7. PAYROLL COMPLIANCE
Config-driven: pph21, tapera, bpjs, thr rates in company_config
Functions: calculate_payroll_components, calculate_all_payroll

---

## 8. WHAT IS LEFT
- Run CONSOLIDATED_141_153.sql + 154-164
- Run SELECT encrypt_existing_pii()
- Sprint: Tests, TypeScript, E2E, Fase 8-9, Pilar 6

---

## 9. EMERGENCY PROCEDURES
Migration fail: re-run (idempotent)
RLS blocking: fix policy, NEVER use USING(true)
audit_log error: use columns (action, detail, timestamp)
Encryption break: key in company_config, backup first

---

## 10. FILE STRUCTURE
WOS-Web/Readme/ = documentation
WOS-Web/supabase/migrations/ = all SQL
WOS-Web/supabase/smoke/ = test files
WOS-Web/src/ = frontend

---

## 11. CREDENTIALS (Dev Only)
Owner: owner@insightwos.com
NRP001: NRP001/CEO123! (bcrypt)
Admin: NRP010/admin123! (bcrypt)
Worker: NRP002/password123 (sha256)

---

## 12. CONVENTIONS
Func: get_worker_payroll, admin_get_summary
Table: hr_payroll, employees_master
Params: p_nrp, p_period (p_ prefix)
Return: JSONB {ok: true/false}
Audit: INSERT INTO audit_log (action, detail, timestamp)
Security: SET search_path = public

---

Generated by Buffy (Codebuff AI) - September 5, 2026
