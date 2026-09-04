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
