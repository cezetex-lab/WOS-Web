# Owner Dashboard — 16 Features Global Design Plan

## Context
- 2000 workers assumption
- Free tier: Supabase (500MB DB, 50K MAU), Vercel (100GB BW), Upstash (10K cmd/day)
- Architecture: unified, not piecemeal

---

## Free Tier Budget (2000 workers)

| Service | Limit | Est. Usage | Status |
|---|---|---|---|
| Supabase DB | 500MB | ~200MB (2000 users + logs) | ✅ Safe |
| Supabase MAU | 50,000 | 2,000 | ✅ Safe |
| Supabase Edge Fn | 500K/mo | ~50K | ✅ Safe |
| Vercel BW | 100GB/mo | ~30GB | ✅ Safe |
| Upstash | 10K/day | ~3K | ✅ Safe |
| PostHog | 1M events/mo | ~200K (if optimized) | ⚠️ Need manual tracking |
| Email (Resend) | 100/day free | ~50/day | ⚠️ Tight |

### If services need replacement:
| Current | Limit Issue | Alternative Free |
|---|---|---|
| PostHog | 1M events, session recording 5K | **Umami** (self-host, unlimited) or **Plausible** (1K/mo free) |
| Upstash Redis | 10K cmd/day | **Supabase Edge Function** caching (no extra service) |
| Resend Email | 100/day | **Brevo** (300/day free) or **EmailOctopus** (10K/mo free) |
| Vercel Hosting | 100GB BW | **Cloudflare Pages** (unlimited BW free) |

**Recommendation:** Current stack is sufficient for 2000 workers. No replacement needed unless PostHog session recording is enabled.

---

## Architecture: Unified Owner Dashboard

### Current Structure
```
/owner/dashboard          → Module Lock | Tier & Pricing | Role Overview
/owner/dashboard/config   → Company Config (63 items)
```

### Target Structure (16 new features)
```
/owner/dashboard
├── 📊 Overview (NEW - P0)          → System health, quick stats
├── 🔒 Module Lock (EXISTS)         → On/off per BU
├── 💰 Tier & Pricing (EXISTS)      → T0-T4 per BU
├── 👥 Roles (EXISTS)               → View/edit roles
├── 🏢 Business Units (NEW - P1)    → CRUD BU
├── 👤 Employees (NEW - P1)         → CRUD employee
├── 📋 Audit Log (NEW - P0)         → All owner actions
├── 🔐 Security (NEW - P0)          → Sessions, policies
├── 💬 Announcements (NEW - P1)     → Broadcast messages
├── 🔔 Notifications (NEW - P1)     → Config templates
├── ⚙️ Config (EXISTS)              → 63 constants
├── 📈 Activity (NEW - P2)          → Real-time metrics
├── 🔗 Integrations (NEW - P2)      → Webhooks, API keys
├── 🎨 Branding (NEW - P2)          → Logo, colors
├── 📦 Data Policy (NEW - P2)       → Retention, archive
├── 🔄 System Log (NEW - P2)        → Version, changelog
└── 🎫 Support (NEW - P2)           → Internal tickets
```

---

## Feature Specifications

### P0 — CRITICAL (Must have before production)

#### 1. 📊 Overview Dashboard
**Purpose:** At-a-glance system health for owner
**Components:**
- Total employees per BU (card)
- Active users today (card)
- Module usage breakdown (pie chart)
- Pending approvals count (card)
- System health: DB size, API latency, error rate
- Recent activity feed (last 10 actions)

**Data sources:**
- `employees_master` count per BU
- `audit_log_owner` for recent activity
- `pg_database_size()` for DB size
- `approval_requests` for pending count

**Free tier:** All queries, no extra services

---

#### 2. 📋 Audit Log Viewer
**Purpose:** Compliance — owner sees all system actions
**Components:**
- Filterable table: action type, target, date range
- Action types: TOGGLE_LOCK, SET_TIER, UPDATE_ROLE, UPDATE_CONFIG, LOGIN, etc.
- Export to CSV
- Pagination (50 per page)

**Data source:** `audit_log_owner` table (already logging)
**RPC:** `get_audit_log_owner(p_action, p_from, p_to, p_limit, p_offset)`

**Free tier:** Query only, no extra services

---

#### 3. 🔐 Security Management
**Purpose:** Owner controls security policies
**Components:**
- Active sessions list (who's logged in now)
- Force logout per user
- Password policy display (from company_config)
- MFA enforcement toggle
- Login attempt stats (last 24h)

**Data sources:**
- `session_tokens` or Supabase Auth admin API
- `company_config` for security settings
- `login_attempts` for stats

**Free tier:** Supabase Auth has session management built-in

---

#### 4. 🏢 Business Unit Management
**Purpose:** CRUD BU from dashboard (no SQL needed)
**Components:**
- BU list with stats (employee count, tier, modules)
- Add new BU form (unit_code, unit_name, description)
- Edit BU (name, description, tier)
- Delete BU (with confirmation + cascade warning)
- Clone BU config to new BU

**Data source:** `business_units` + `business_unit_modules`
**RPCs:** `owner_create_bu`, `owner_update_bu`, `owner_delete_bu`

**Free tier:** Direct DB operations

---

### P1 — IMPORTANT (Before scaling)

#### 5. 👤 Employee Management
**Purpose:** Owner manages employees across all BUs
**Components:**
- Employee list with search/filter by BU, role, status
- Add employee form (nrp, nama, bu, divisi, posisi, role)
- Edit employee
- Deactivate employee (soft delete)
- Bulk import (CSV)
- Employee profile view

**Data sources:** `employees_master`, `user_roles`
**RPCs:** `owner_create_employee`, `owner_update_employee`, `owner_deactivate_employee`

**Free tier:** Direct DB operations

---

#### 6. 💬 Announcement System
**Purpose:** Owner broadcasts messages to all/specific users
**Components:**
- Create announcement (title, body, target: all/BU/role)
- Announcement list (active, draft, expired)
- Schedule announcement (start/end date)
- Priority levels (info, warning, critical)
- User sees announcement on dashboard

**New table:** `announcements` (id, title, body, target_type, target_value, priority, start_at, end_at, created_by, created_at)
**RPCs:** `owner_create_announcement`, `owner_get_announcements`, `owner_delete_announcement`

**Free tier:** Direct DB, no email sending (in-app only)

---

#### 7. 🔔 Notification Config
**Purpose:** Configure which events trigger notifications
**Components:**
- Event list (leave_request, overtime_request, approval_needed, etc.)
- Toggle per event (email on/off, push on/off)
- Email template preview
- Notification history

**New table:** `notification_config` (event_type, email_enabled, push_enabled, template)
**RPCs:** `get_notification_config`, `update_notification_config`

**Free tier:** In-app notifications only, email later when Brevo integrated

---

#### 8. 🔐 Security Policy UI
**Purpose:** Visual security policy management (reads from company_config)
**Components:**
- Password policy (min length, complexity, expiry)
- Session timeout config
- IP whitelist (future)
- MFA enforcement per role
- Login lockout settings

**Data source:** `company_config` (security category)
**No new tables needed** — just UI for existing config

---

#### 9. 📢 System Announcements (Platform-wide)
**Purpose:** Maintenance notices, version updates
**Components:**
- Banner at top of all pages
- Dismissible per user
- Scheduled display
- Version changelog display

**New table:** `system_announcements` (id, message, type, dismissible, start_at, end_at)
**Free tier:** Direct DB

---

### P2 — NICE TO HAVE (Before enterprise)

#### 10. 📈 Activity Dashboard
**Purpose:** Real-time usage metrics
**Components:**
- Daily active users chart
- Module usage heatmap
- Approval queue status
- Peak usage hours
- Error rate trend

**Data sources:** `audit_log_owner`, `attendance_master`, custom counters
**Free tier:** SQL queries only, charts in frontend

---

#### 11. 🔗 Integration Management
**Purpose:** Manage third-party connections
**Components:**
- Webhook config (URL, events, status)
- API key management (generate, revoke)
- Integration status (connected/disconnected)
- Test webhook button

**New table:** `integrations` (id, name, type, config, status, api_key)
**Free tier:** Direct DB, no external calls until needed

---

#### 12. 🎨 Branding
**Purpose:** White-label per BU
**Components:**
- Upload logo per BU
- Primary/secondary color picker
- Company name display
- Login page customization preview

**New table:** `branding_config` (bu_id, logo_url, primary_color, secondary_color, company_name)
**Free tier:** Supabase Storage for logos (1GB free)

---

#### 13. 📦 Data Retention Policy
**Purpose:** Auto-cleanup old data
**Components:**
- Retention rules per table (audit_log, login_attempts, etc.)
- Archive old data to cold storage
- Manual purge button
- Storage usage display

**New table:** `data_retention_rules` (table_name, retention_days, archive_enabled)
**RPC:** `run_data_retention` (pg_cron or manual trigger)
**Free tier:** SQL functions + pg_cron (if available)

---

#### 14. 🔄 System Update Log
**Purpose:** Version tracking and rollback
**Components:**
- Current version display
- Changelog (markdown rendered)
- Migration history
- Rollback capability (future)

**Data source:** `schema_migrations` + new `system_changelog` table
**Free tier:** Direct DB

---

#### 15. 🎫 Support/Ticketing
**Purpose:** Internal ticket system user → admin
**Components:**
- Create ticket (subject, description, priority)
- Ticket list (open, in-progress, resolved)
- Comment thread per ticket
- Assignment to admin
- Status tracking

**New table:** `support_tickets` (id, creator_nrp, subject, description, priority, status, assigned_to, created_at, updated_at)
**New table:** `ticket_comments` (id, ticket_id, commenter_nrp, comment, created_at)
**Free tier:** Direct DB

---

#### 16. 📊 Usage Analytics
**Purpose:** Understand how platform is used
**Components:**
- Feature adoption rate
- User engagement score
- Module popularity ranking
- Time spent per module
- Export report

**Data source:** `audit_log_owner` + custom event tracking
**Free tier:** SQL aggregation queries

---

## Database Schema Summary

### New Tables Needed
```sql
-- P0
announcements (already exists in module_definitions, need actual table)

-- P1
support_tickets
ticket_comments
notification_config

-- P2
system_announcements
integrations
branding_config
data_retention_rules
system_changelog
```

### Modified Tables
```sql
audit_log_owner → already has enough columns
company_config → already has 63 items
```

---

## Implementation Order

### Wave 1: P0 (Week 1)
1. Overview Dashboard (stats cards + health)
2. Audit Log Viewer (query audit_log_owner)
3. Security Management (sessions + policies)
4. BU Management (CRUD business_units)

### Wave 2: P1 (Week 2)
5. Employee Management (CRUD employees_master)
6. Announcement System (create + display)
7. Notification Config (toggle events)
8. Security Policy UI (reads company_config)
9. System Announcements (banner)

### Wave 3: P2 (Week 3)
10. Activity Dashboard (charts)
11. Integration Management (webhooks)
12. Branding (logo + colors)
13. Data Retention (auto-cleanup)
14. System Update Log (versioning)
15. Support/Ticketing (internal tickets)
16. Usage Analytics (reports)

---

## RPC Count Estimate

| Wave | New RPCs | Total |
|---|---|---|
| Wave 1 | 6 | 6 |
| Wave 2 | 8 | 14 |
| Wave 3 | 10 | 24 |

All RPCs use `SECURITY DEFINER` + owner check pattern.

---

## Free Tier Risk Assessment

| Risk | Impact | Mitigation |
|---|---|---|
| Audit log grows fast | DB size | Auto-cleanup > 6 months |
| Session table grows | DB size | Cleanup expired sessions |
| Announcements table | Negligible | Max 100 active |
| Support tickets | Low volume | Max 500 open |
| Branding logos | Storage | Max 5MB per logo |

**All within free tier limits for 2000 workers.**
