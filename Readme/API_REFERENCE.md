# API Reference — insightWOS V6

All RPCs are called via `supabase.rpc('function_name', { params })`.

---

## Authentication

| Function | Params | Auth | Description |
|----------|--------|:----:|-------------|
| `generate_worker_otp` | `p_nrp, p_nik, p_password` | Public | Step 1: Validate worker credentials, return OTP |
| `verify_worker_otp` | `p_nrp, p_code` | Public | Step 2: Verify OTP, return session token |
| `login_worker` | `p_nrp, p_nik, p_password` | Public | Direct login (returns mfa_required if MFA enabled) |
| `worker_logout` | — | Auth | Clear session token |
| `check_login_lockout` | `p_identifier, p_attempt_type` | Public | Check if account is locked |
| `request_password_reset` | `p_nrp` | Public | Request password reset (sends email) |
| `reset_password` | `p_nrp, p_token, p_new_password` | Public | Reset password with token |

## MFA

| Function | Params | Auth | Description |
|----------|--------|:----:|-------------|
| `check_mfa_status` | `p_nrp` | Public | Check if MFA is enabled |
| `mfa_verify_login` | `p_nrp, p_code` | Public | Verify TOTP code during login |
| `mfa_setup_start` | `p_nrp` | Auth | Start MFA setup (returns TOTP secret) |
| `mfa_setup_verify` | `p_nrp, p_code` | Auth | Complete MFA setup |
| `mfa_disable` | `p_nrp, p_code` | Auth | Disable MFA (requires current code) |
| `admin_reset_mfa` | `p_nrp` | Admin | Admin resets worker's MFA |

## Worker RPCs

| Function | Params | Auth | Description |
|----------|--------|:----:|-------------|
| `get_worker_payroll` | `p_nrp` | Auth | Get worker payroll data |
| `get_worker_engagement` | `p_nrp` | Auth | Get engagement/survey data |
| `get_worker_notifications` | `p_nrp` | Auth | Get worker notifications |
| `get_worker_learning` | `p_nrp` | Auth | Get learning/training data |
| `get_worker_certifications` | `p_nrp` | Auth | Get certifications |
| `get_worker_skills` | `p_nrp` | Auth | Get skills matrix |
| `get_worker_leave_balance` | `p_nrp` | Auth | Get leave balance |
| `get_worker_overtime` | `p_nrp` | Auth | Get overtime data |

## GDPR / PDP

| Function | Params | Auth | Description |
|----------|--------|:----:|-------------|
| `export_my_data` | `p_nrp` | Auth | Export all personal data as JSON |
| `delete_my_data` | `p_nrp` | Auth | Anonymize personal data (self) |
| `grant_consent` | `p_nrp, p_type, p_given` | Auth | Grant/revoke consent |
| `get_my_consents` | `p_nrp` | Auth | Get consent status |

## Admin RPCs

| Function | Params | Auth | Description |
|----------|--------|:----:|-------------|
| `admin_get_summary` | — | Admin | Dashboard summary stats |
| `admin_get_payroll` | — | Admin(Finance) | Payroll list |
| `admin_get_training_catalog` | — | Admin | Training catalog |
| `admin_get_coaching_catalog` | — | Admin | Coaching catalog |
| `admin_get_compliance_catalog` | — | Admin | Compliance catalog |
| `admin_get_benefits_catalog` | — | Admin | Benefits catalog |
| `admin_get_document_types` | — | Admin | Document types |
| `admin_get_talent_marketplace` | — | Admin | Talent marketplace |
| `admin_get_people_search` | — | Admin | People search |
| `admin_get_badges` | — | Admin | Badge achievements |
| `admin_get_okr` | — | Admin | OKR objectives |
| `admin_get_assets` | — | Admin | Asset inventory |
| `admin_get_asset_assignments` | — | Admin | Asset assignments |
| `admin_get_estate_blocks` | — | Admin | Estate blocks |
| `admin_get_surveys` | — | Admin | Survey results |
| `admin_get_whistleblower` | — | Admin | Whistleblower reports |
| `admin_get_exit_interviews` | — | Admin | Exit interviews |
| `admin_get_settlements` | — | Admin | Final settlements |
| `admin_get_referrals` | — | Admin | Employee referrals |
| `admin_get_headcount_plan` | — | Admin | Headcount planning |
| `admin_get_budget` | — | Admin | Budget allocation |
| `admin_get_certifications` | — | Admin | All certifications |
| `admin_get_audit_log` | — | Admin | Audit log viewer |
| `admin_reset_mfa` | `p_nrp` | Admin | Reset worker MFA |
| `admin_update_employee` | `p_nrp, p_*` | Admin | Update employee data |
| `admin_create_employee` | `p_*` | Admin | Create new employee |

## Owner RPCs

| Function | Params | Auth | Description |
|----------|--------|:----:|-------------|
| `owner_login` | `p_email` | Owner | Owner authentication |
| `owner_force_logout` | `p_nrp` | Owner | Force logout a user |
| `owner_update_role` | `p_nrp, p_role, p_level` | Owner | Update user role |
| `owner_set_tier` | `p_nrp, p_tier` | Owner | Set employee tier (0-4) |
| `owner_update_bu` | `p_nrp, p_bu_id` | Owner | Change business unit |
| `owner_override` | `p_nrp, p_action, p_reason` | Owner | Override system action |
| `owner_get_retention_rules` | — | Owner | Get data retention rules |
| `owner_get_security_settings` | — | Owner | Get security settings |
| `log_owner_override` | `p_target, p_action, p_reason` | Owner | Log owner override |

## AI / Intelligence

| Function | Params | Auth | Description |
|----------|--------|:----:|-------------|
| `match_documents` | `p_query, p_context, p_limit` | Auth | RAG document search |
| `ai_check_rate_limit` | `p_nrp, p_limit, p_tokens` | Auth | Check AI rate limit |
| `ai_record_query` | `p_nrp, p_tokens` | Auth | Record AI query usage |

## System

| Function | Params | Auth | Description |
|----------|--------|:----:|-------------|
| `get_user_context` | `p_nrp` | Auth | Get user context (role, BU, etc.) |
| `get_user_context_by_auth_id` | `p_auth_id` | Public | Get user context by Supabase auth_id |
| `get_active_sessions` | — | Owner | Get all active sessions |
| `get_login_attempt_stats` | — | Owner | Get login attempt statistics |
| `log_access_denial` | `p_rpc, p_reason` | Auth | Log access denial |
| `cleanup_expired_data` | — | Auth | Run configurable data cleanup |
| `refresh_all_materialized_views` | — | Auth | Refresh all materialized views |
| `get_dashboard_cached` | — | Auth | Get cached dashboard stats |

---

## Auth Roles

| Role | Level | Scope |
|------|:-----:|-------|
| `worker` | 0 | Own data only |
| `admin_mining` | 1 | Mining BU |
| `admin_estate` | 1 | Estate BU |
| `admin_mill` | 1 | Mill BU |
| `admin_hrd` | 2 | HR data all BU |
| `admin_finance` | 2 | Finance data all BU |
| `admin_operasional` | 2 | Operations all BU |
| `admin_pusat` | 3 | All modules global |
| `admin_ceo` | 4 | Full access |

---

*Last updated: September 5, 2026*
