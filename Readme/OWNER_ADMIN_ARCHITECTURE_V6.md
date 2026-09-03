# INSIGHTWOS V6 - OWNER vs ADMIN ARCHITECTURE

## Complete Authorization & Access Control Design

**Generated:** September 3, 2026
**Classification:** CONFIDENTIAL - Architecture Decision Record
**Status:** APPROVED FOR IMPLEMENTATION

---

## 1. ARCHITECTURE OVERVIEW

### 1.1 Authorization Hierarchy

SYSTEM OWNER (1 Specific Account, Bound to auth.users.id)
  -> OWNER CONTROL (System Config, Security, Modules, Pricing, Roles, BU CRUD)
  -> ADMIN BACKUP (Can remotely operate Admin functions, logged as OWNER_OVERRIDE)
     -> ADMIN_PUSAT (all operational)
     -> FUNCTIONAL ADMINS: HRD, Finance, Operasional
     -> INDUSTRY ADMINS: Mining, Mill, Estate (Dynamic)

### 1.2 Key Design Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | Owner = 1 specific account, NOT role-based | Prevent privilege escalation |
| 2 | Admin roles are dynamic | Owner can add new industries without code changes |
| 3 | Owner can access /admin/* as backup | Remote capability, logged as OWNER_OVERRIDE |
| 4 | Admin CANNOT become Owner | Backend rejects non-Owner from /owner |
| 5 | Visibility != Permission | Module can appear but buttons disabled |
| 6 | Least privilege | Each admin scoped to its function |

---

## 2. SECURITY MODEL

### 2.1 Owner Identity Binding

NOT role-based. The Owner is identified by a specific auth_id:

CREATE TABLE system_owner_identity (
  id SERIAL PRIMARY KEY,
  auth_id UUID UNIQUE NOT NULL,
  owner_email TEXT UNIQUE NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

Server-side check:
SELECT EXISTS (SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = TRUE) INTO v_is_owner;
If v_is_owner = FALSE then DENY immediately.

### 2.2 Owner-Only Features (Backend Enforced)

| RPC | Purpose | Owner Only |
|-----|---------|:----------:|
| owner_toggle_lock | Module Lock ON/OFF | YES |
| owner_set_tier | Tier and Pricing | YES |
| owner_create_bu | Business Unit CRUD | YES |
| owner_update_bu | Business Unit CRUD | YES |
| owner_delete_bu | Business Unit CRUD | YES |
| owner_force_logout | Force Logout | YES |
| owner_update_role | Role Management | YES |
| owner_create_admin_role | Admin Role Management | YES |
| owner_delete_admin_role | Admin Role Management | YES |
| owner_get_admin_roles | Admin Role Management | YES |
| owner_assign_admin_user | Admin Role Management | YES |
| owner_update_security_settings | Security Policy | YES |

### 2.3 Access Denial Matrix

| Role | /owner | /admin/* | Toggle Lock | Set Tier | Create Admin Role |
|------|:------:|:--------:|:-----------:|:--------:|:-----------------:|
| SYSTEM OWNER | YES | YES | YES | YES | YES |
| admin_pusat | NO | YES | NO | NO | NO |
| admin_hrd | NO | YES (limited) | NO | NO | NO |
| admin_finance | NO | YES (limited) | NO | NO | NO |
| admin_operasional | NO | YES (limited) | NO | NO | NO |
| admin_mining | NO | NO | NO | NO | NO |
| admin_mill | NO | NO | NO | NO | NO |
| admin_estate | NO | NO | NO | NO | NO |
| worker | NO | NO | NO | NO | NO |

### 2.4 Owner Override Logging

When Owner operates admin function, audit trail records OWNER_OVERRIDE.
Frontend shows: Owner Override Active badge when Owner is in admin mode.

---
## 3. DYNAMIC ADMIN ROLE SYSTEM

### 3.1 Table: admin_roles

CREATE TABLE admin_roles (
  id SERIAL PRIMARY KEY,
  role_code TEXT UNIQUE NOT NULL,
  role_name TEXT NOT NULL,
  scope_type TEXT NOT NULL,        -- industry, function, global
  scope_id TEXT,                   -- mining, mill, estate, NULL for global
  permissions JSONB DEFAULT []
  can_manage_users BOOLEAN DEFAULT FALSE,
  can_manage_modules BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by TEXT
);

### 3.2 Scope Types

| scope_type | scope_id | Description | Example |
|------------|----------|-------------|---------|
| global | NULL | All operational pages | admin_pusat |
| function | hrd | HR functions only | admin_hrd |
| function | finance | Finance functions only | admin_finance |
| function | operasional | Operations only | admin_operasional |
| industry | mining | Mining module only | admin_mining |
| industry | mill | Mill module only | admin_mill |
| industry | estate | Estate module only | admin_estate |
| industry | plantation | Future - Owner adds from dashboard | admin_plantation |

### 3.3 Seed Default Roles

INSERT INTO admin_roles (role_code, role_name, scope_type, scope_id, permissions) VALUES
("admin_pusat", "Admin Pusat", "global", NULL, ["*"]),
("admin_hrd", "Admin HRD", "function", "hrd", ["employees.*", "recruitment.*", "kpi.*"]),
("admin_finance", "Admin Finance", "function", "finance", ["payroll.*", "budget.*"]),
("admin_operasional", "Admin Operasional", "function", "operasional", ["requests.*", "leave.*"]),
("admin_mining", "Admin Mining", "industry", "mining", ["mining.*"]),
("admin_mill", "Admin Mill", "industry", "mill", ["mill.*"]),
("admin_estate", "Admin Estate", "industry", "estate", ["estate.*"]);

### 3.4 Owner Can Add New Roles from Dashboard

1. Owner opens Access Control tab
2. Clicks Add Industry Module
3. System auto-creates module + admin role
4. Owner assigns admin user
5. No code changes needed

---

## 4. OWNER DASHBOARD - ACCESS CONTROL SECTION

### 4.1 New Tab: Access Control (Owner-Only)

Owner Dashboard tabs:
- Overview, Module Lock, Tier and Pricing, Roles, Audit Log, Security
- Business Units, Employees, Announcements, Notifications, System Banner
- Activity, Integrations, Data Retention, System Log, Support, Analytics
- **Access Control (NEW)**
  - Admin Roles (list, create, edit, enable/disable)
  - Industry Modules (list, add new, enable/disable)
  - Admin Accounts (list, create, assign role, deactivate)

### 4.2 RPCs for Access Control

| RPC | Purpose | Owner Only |
|-----|---------|:----------:|
| owner_get_admin_roles | List all admin roles | YES |
| owner_create_admin_role | Create new admin role | YES |
| owner_update_admin_role | Edit admin role | YES |
| owner_delete_admin_role | Deactivate admin role | YES |
| owner_assign_admin_user | Assign admin user to role | YES |
| owner_get_admin_accounts | List all admin accounts | YES |
| owner_create_admin_account | Create new admin account | YES |

---
## 5. FRONTEND COMPONENTS

### 5.1 RoleGuard.jsx

Wraps routes - checks role against allowed roles.
Owner always passes (identity verified at login).
If role not in allowedRoles, redirect to /admin.

### 5.2 OwnerGuard.jsx

Wraps /owner routes - checks Owner identity.
If not is_owner or no auth_id, redirect to /.

### 5.3 OwnerOperatingBadge.jsx

Shows Owner Override Active badge when Owner is in admin mode.
Fixed position top-right, amber styling.

---

## 6. IMPLEMENTATION PHASES

### Phase 1: Database (Migration 110)
- system_owner_identity table
- admin_roles table
- role_page_access table
- Update user_roles_role_check constraint
- Seed default admin roles + permissions
- RPCs: check_owner_identity(), check_admin_access()

### Phase 2: Backend Security (Migration 111)
- Update ALL existing Owner RPCs to use identity check
- Add OWNER_OVERRIDE logging
- RPCs: owner_create_admin_role(), owner_delete_admin_role(), owner_get_admin_roles(), owner_assign_admin_user()

### Phase 3: Frontend Guards + Owner Access (2 hrs)
- RoleGuard.jsx, OwnerGuard.jsx, OwnerOperatingBadge.jsx
- role-config.js - role definitions
- Update SessionGuard.jsx - Owner bypass for /admin
- Update App.jsx - add guards to routes

### Phase 4: Admin Menu Filtering (1 hr)
- Dynamic menu based on admin role
- Role-specific menu items

### Phase 5: Owner Dashboard Access Control (2 hrs)
- New Access Control tab
- Admin role CRUD
- Industry module management
- Admin account management

### Phase 6: Build + Test + Commit

---

## 7. FILES TO CREATE/MODIFY

| File | Action | Purpose |
|------|:------:|---------|
| supabase/migrations/110_owner_admin_architecture.sql | CREATE | Core tables + RPCs |
| supabase/migrations/111_owner_security_hardening.sql | CREATE | Update existing RPCs |
| src/components/RoleGuard.jsx | CREATE | Route-level role check |
| src/components/OwnerGuard.jsx | CREATE | Owner identity check |
| src/components/OwnerOperatingBadge.jsx | CREATE | Override indicator |
| src/lib/role-config.js | CREATE | Role definitions |
| src/pages/OwnerDashboard.jsx | MODIFY | Add Access Control tab |
| src/components/SessionGuard.jsx | MODIFY | Owner bypass for /admin |
| src/pages/Admin.jsx | MODIFY | Dynamic menu per role |
| src/App.jsx | MODIFY | Add RoleGuard to routes |

---

## 8. NON-FUNCTIONAL REQUIREMENTS

| Requirement | Standard |
|-------------|----------|
| Security | OWASP Top 10 - all auth server-side |
| Performance | RPCs < 200ms |
| Audit | All Owner actions logged to audit_log_owner |
| Scalability | Dynamic roles = no code change for new industries |
| Principle | Least privilege - each admin scoped to function |
| Identity | Owner = 1 specific account, not role-based |

---

## 9. CRITICAL SECURITY RULES

1. **Owner identity is fixed.** Only 1 account can access /owner.
2. **Admin roles are flexible.** Owner can add new roles from dashboard.
3. **Adding a new admin role never creates Owner access.**
4. **Admin CANNOT become Owner.** Backend rejects any non-Owner from /owner.
5. **All Owner interventions are audited** as OWNER_OVERRIDE.
6. **Backend enforces authorization.** Not just CSS hiding.
7. **Owner can remotely control/backup Admin functions.**
8. **Visibility != Permission.** Module can appear but buttons disabled.

---

## 10. OPEN QUESTIONS

| # | Question | Status |
|---|----------|:------:|
| 1 | Should admin_pusat be able to create other admin accounts? | PENDING |
| 2 | When Owner overrides, should original admin receive notification? | PENDING |
| 3 | Should industry admins have their own mini-dashboard? | PENDING |
| 4 | Permission granularity: per-page or per-action? | PENDING |

---

*Document generated by Architecture Review Process*
*Next review: After Phase 1-2 implementation*
---

## 10. OPEN QUESTIONS — RESOLVED

| # | Question | Decision |
|---|----------|----------|
| 1 | Should admin_pusat be able to create other admin accounts? | YES - within Admin-level authority only. Cannot create/modify Owner. |
| 2 | When Owner overrides, should original admin receive notification? | YES - mandatory audit log + admin notification. Critical overrides = high-priority notification. |
| 3 | Should industry admins have their own mini-dashboard? | YES - /admin/mining, /admin/mill, /admin/estate scoped dashboards. |
| 4 | Permission granularity: per-page or per-action? | BOTH - per-page for access, per-action for operations. Per-action is final backend security layer. |

### 10.1 admin_pusat Admin Creation Rules

admin_pusat MAY create/edit/disable:
- admin_hrd
- admin_finance
- admin_operasional
- admin_mining
- admin_mill
- admin_estate
- future industry admins

admin_pusat CANNOT:
- create or modify Owner
- grant Owner/Superuser privileges
- modify Owner identity
- modify Tier and Pricing
- modify System Config
- change authorization architecture

admin_pusat cannot grant permission higher than its own authority.

### 10.2 Owner Override Notification Rules

Every Owner intervention must be:
1. Recorded in audit_log_owner
2. Visible to affected Admin
3. Notified when intervention affects operational function

Critical/security-related overrides generate high-priority notification.
Owner intervention must NEVER be silently hidden.

### 10.3 Industry Admin Mini-Dashboard

Structure:
- /admin/mining -> Mining Admin Dashboard
- /admin/mill -> Mill Admin Dashboard
- /admin/estate -> Estate Admin Dashboard

Each mini-dashboard contains:
- Industry Dashboard (overview stats)
- Industry Workers
- Industry Operations
- Industry Requests / Approvals
- Industry Monitoring
- Industry Reports
- Industry-specific modules

Industry admins access worker-side pages for supervision/operation.
Future industries use same dynamic architecture.

### 10.4 Permission Model: Per-Page + Per-Action

Hierarchical permission system:

ROLE -> SCOPE -> PAGE/MODULE ACCESS -> ACTION PERMISSION

Example:
- admin_operasional at /admin/leave:
  VIEW: YES, CREATE: YES, EDIT: YES, APPROVE: YES, DELETE: NO, EXPORT: YES

- Another admin at same page:
  VIEW: YES, CREATE: NO, EDIT: NO, APPROVE: YES, DELETE: NO

Page permission = whether module is accessible.
Action permission = what user can do on that page.
Per-action is the FINAL backend security layer.

Backend MUST enforce action permission even if UI hides buttons.

---

*Document updated with Section 10 final decisions*
*Architecture review COMPLETE - ready for implementation*