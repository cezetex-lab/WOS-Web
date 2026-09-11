# Architecture — insightWOS V6

## Entity Relationship Diagram (Simplified)

```
┌─────────────────────┐     ┌──────────────────┐     ┌───────────────────┐
│   employees_master   │────<│    user_roles     │     │ system_owner_     │
│─────────────────────│     │──────────────────│     │   identity        │
│ nrp (PK)            │     │ nrp (FK)          │     │───────────────────│
│ nama                │     │ role              │     │ auth_id (FK)      │
│ auth_id (FK)        │     │ role_level        │     │ is_active         │
│ business_unit_id(FK)│     │ business_unit_id  │     └───────────────────┘
│ email               │     └──────────────────┘
│ status              │
└────────┬────────────┘
         │
         ├────< hr_payroll        (nrp, periode, net_salary, base_salary)
         ├────< hr_attendance     (nrp, date, status_hadir, shift)
         ├────< hr_leave          (nrp, tahun, annual_used)
         ├────< hr_overtime       (nrp, date, hours, status)
         ├────< hr_performance    (nrp, periode, kpi_score)
         ├────< hr_requests       (nrp, type, status)
         ├────< hr_safety         (nrp, incident_type, severity)
         ├────< hr_skills         (nrp, skill_name, level)
         ├────< hr_benefits       (nrp, benefit_type)
         ├────< hr_learning       (nrp, title, status, score)
         ├────< hr_engagement     (nrp, score, period)
         ├────< hr_tasks          (nrp, title, status)
         ├────< hr_notifications  (nrp, title, is_read)
         ├────< certifications    (nrp, cert_name, expiry_date)
         ├────< badges            (nrp, badge_name, points)
         ├────< okrs              (nrp, objective, key_result)
         ├────< surveys           (id, title, survey_type)
         ├────< survey_responses  (survey_id FK, nrp, score)
         ├────< referrals         (referrer_nrp FK, candidate_name)
         ├────< exit_interviews   (nrp, satisfaction_score)
         ├────< final_settlements (nrp, total_settlement)
         ├────< assets            (id, asset_name, assigned_to FK)
         ├────< asset_assignments (asset_id FK, nrp FK)
         ├────< estate_blocks     (id, block_name, area_hectare)
         ├────< whistleblowers    (id, category, status)
         ├────< headcount_plans   (divisi, year, planned_hc)
         └────< budget_allocation (divisi, year, gaji_budget)

┌──────────────────┐     ┌──────────────────┐     ┌───────────────────┐
│ business_units   │────<│ employees_master  │     │ config_categories │
│──────────────────│     │ business_unit_id  │     │───────────────────│
│ id (PK)          │     └──────────────────┘     │ id (PK)           │
│ code             │                               │ name              │
│ name             │     ┌──────────────────┐     └────────┬──────────┘
│ type (BU/INDUSTRY)    │ company_config    │              │
└──────────────────┘     │──────────────────│              │
                         │ category_id (FK) │<─────────────┘
                         │ config_key       │
                         │ config_value     │
                         └──────────────────┘

┌──────────────────┐     ┌──────────────────┐     ┌───────────────────┐
│ session_tokens   │     │ worker_passwords  │     │ login_attempts    │
│──────────────────│     │──────────────────│     │───────────────────│
│ nrp              │     │ nrp (PK)          │     │ identifier        │
│ token            │     │ password_hash     │     │ attempt_time      │
│ expires_at       │     │ salt              │     │ success           │
│ is_used          │     │ attempts          │     └───────────────────┘
└──────────────────┘     └──────────────────┘

┌──────────────────┐     ┌──────────────────┐     ┌───────────────────┐
│ audit_log        │     │ api_keys          │     │ api_rate_limits   │
│──────────────────│     │──────────────────│     │───────────────────│
│ action           │     │ key_name          │     │ api_key_id (FK)   │
│ result           │     │ key_hash          │     │ window_start      │
│ message          │     │ scope             │     │ request_count     │
│ created_at       │     │ is_active         │     └───────────────────┘
└──────────────────┘     └──────────────────┘

┌──────────────────┐     ┌──────────────────┐     ┌───────────────────┐
│ dashboard_cache  │     │ user_consents     │     │ otp_store         │
│──────────────────│     │──────────────────│     │───────────────────│
│ cache_key        │     │ nrp               │     │ nrp               │
│ cache_data       │     │ consent_type      │     │ code_hash         │
│ cached_at        │     │ consent_given     │     │ expiry            │
│ hit_count        │     └──────────────────┘     │ used              │
└──────────────────┘                               └───────────────────┘

┌──────────────────┐     ┌──────────────────┐
│ mfa_factors      │     │ data_retention_   │
│──────────────────│     │   rules           │
│ nrp              │     │──────────────────│
│ totp_secret      │     │ table_name        │
│ enabled          │     │ retention_days    │
└──────────────────┘     └──────────────────┘

┌──────────────────┐     ┌──────────────────┐
│ system_changelog │     │ ai_rate_limits    │
│──────────────────│     │──────────────────│
│ id               │     │ nrp               │
│ version          │     │ query_count       │
│ title            │     │ tokens_used       │
│ description      │     │ window_start      │
└──────────────────┘     └──────────────────┘
```

## Industry Tables (BU-scoped)

```
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ mining_*         │  │ estate_*        │  │ mill_*          │
│─────────────────│  │─────────────────│  │─────────────────│
│ equipment        │  │ blocks          │  │ boiler          │
│ production       │  │ harvest         │  │ production      │
│ fuel             │  │ irrigation      │  │ quality         │
│ fatigue          │  │ nursery         │  │ maintenance     │
│ safety           │  │ harvesting      │  └─────────────────┘
│ jsa              │  └─────────────────┘
│ simper           │
└─────────────────┘
All have: id, business_unit_id, date, created_at
```

## Auth Flow

```
Worker Login:
  1. check_login_lockout → locked? → reject
  2. generate_worker_otp → validate NRP/NIK/password → return OTP
  3. verify_worker_otp → validate OTP → return session token
  4. check_mfa_status → MFA enabled? → show TOTP input
  5. mfa_verify_login → validate TOTP → create session
  6. Sync Supabase Auth (for gatekeeper RPCs)

Admin Login:
  1. check_login_lockout → locked? → reject
  2. Supabase Auth (email + password → bcrypt)
  3. get_user_context_by_auth_id → get role/BU
  4. check_mfa_status → MFA enabled? → show TOTP input
  5. mfa_verify_login → validate TOTP → create session

Owner Login:
  1. owner_login → verify via system_owner_identity
  2. create session with owner role
```

## Security Layers

```
Layer 1: Supabase Auth (bcrypt, JWT tokens)
Layer 2: RLS Policies (authz_in_scope, authz_check_admin)
Layer 3: RPC Auth Checks (auth.uid(), authz_current_nrp)
Layer 4: RBAC (role_permission_sets, permission checks)
Layer 5: BU Isolation (business_unit_id filtering)
Layer 6: Audit Trail (generic trigger on 19 tables)
Layer 7: Rate Limiting (login attempts, API keys, AI queries)
Layer 8: Configurable Retention (cleanup_expired_data)
```

## Migration History

| Range | Purpose |
|-------|---------|
| 001-010 | Core tables + auth functions |
| 011-030 | Worker/Admin RPCs |
| 031-050 | Auth fixes + wave migrations |
| 051-070 | RBAC + industry tables |
| 071-100 | Foundation + performance indexes |
| 100-110 | Owner system + company config |
| 111-130 | Owner wave 3 + RPC fixes |
| 131-140 | Security architecture (IDOR, RLS, authz) |
| 141-147 | Audit remediation + gap fixes + cleanup |

---

*Last updated: September 5, 2026*
