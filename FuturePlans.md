# Future Plans - insightWOS

> **Created**: 2026-09-14  
> **Status**: Research & Planning Phase  
> **Based on**: Competitive analysis, user needs study, database forensic audit

---

## Executive Summary

insightWOS adalah HR/WMS (Workforce Management System) dengan fokus industri (mining, estate, mill) yang sedang bermigrasi dari Google Apps Script ke React + Supabase. Berdasarkan riset mendalam terhadap kompetitor (Workday, SAP SuccessFactors, UKG, ADP, Zellis) dan studi kebutuhan user (worker, admin, manager), berikut roadmap pengembangan untuk menjadikan insightWOS platform yang lengkap dan kompetitif.

---

## 1. Current State Analysis

### 1.1 Strengths (Keunggulan)
- ✅ Tier-based access model (FREE → ENTERPRISE) yang matang
- ✅ Role-based access (L1-L5) yang robust
- ✅ Mining-specific features (SIMPER, equipment, safety, estate, mill)
- ✅ AI Copilot foundation (askCopilot)
- ✅ Comprehensive HR modules (cuti, lembur, KPI, coaching, succession)
- ✅ RLS & security foundation yang kuat
- ✅ Database migration dari GAS sudah 95% complete
- ✅ Frontend React + Vite modern

### 1.2 Critical Gaps (Kekurangan Kritis)
- ❌ **Tidak ada native mobile app** - semua kompetitor punya (ADP, SAP, Workday)
- ❌ **Tidak ada GPS geofencing attendance** - time fraud risk
- ❌ **Offline mode belum teruji E2E** — PWA (`sw.js` v3, `manifest.json`, `PwaUpdater`, `OfflineIndicator`) sudah hidup dan DB `offline_sync` ada, tapi belum ada spec E2E (`pwa-offline-mode.spec.ts` baru dibuat, belum dijalankan live).
- ⚠️ **Payroll engine belum lengkap** — kalkulasi sudah ada (`calculate_payroll_components`, `calculate_all_payroll`, `process_payroll_batch`, `export_payroll`), tapi payslip PDF, tabel pajak, dan `payroll_periods` belum
- ❌ **Tidak ada auto-approval rules** - admin workload tinggi
- ❌ **Tidak ada bulk operations** - tidak scalable
- ❌ **Tidak ada payslip generation** - banyak email ke HR
- ⚠️ **Shift swap belum lengkap** — `shift_swaps`, `shift_assignments`, dan `admin_approve_shift_swap` sudah ada; bidding & auto-approve belum
- ❌ **Tidak ada anonymous reporting** - compliance risk
- ❌ **Tidak ada predictive AI** - hanya basic intelligence

### 1.3 Database State (from Forensic Audit)
- **Total Tables**: ~209 (live DB saat ini: 208 tabel non-partisi + 1 view; klaim 253/257 sudah ketinggalan)
- **Total Functions**: ~657 (live DB saat ini: 657 fungsi setelah migrasi 243 drop 13 legacy; klaim 617/667/670/672/673 sudah ketinggalan)
- **Search Path Violations**: 0 (migration `207` sudah fix semua — OBSOLETE, klaim "8 functions missing" salah)
- **pg_cron**: 3 jobs aktif (`cron.job`) 2026-09-18 (pasca-228: 3 job MV dipensiunkan)
- **Legacy Overloads**: 20 overloads masih ada tapi sudah di-rename ke `_legacy_*` (tidak semua di-drop — ini desain, bukan bug)
- **Audit Chain**: 44 rows (`verify_audit_chain()` = 0 issues); baris hanya bertambah, jadi angka ini bergerak
- **RLS**: Semua tabel force-enabled

---

## 2. User Needs Summary

### 2.1 Worker Needs (45+ needs)

**Critical:**
- GPS geofencing attendance
- Offline mode untuk remote sites
- Biometric authentication (fingerprint/face ID)
- One-tap actions (clock-in, leave request)
- Real-time leave balance
- Payslip access & download
- Shift swap & bidding
- Anonymous grievance reporting
- Safety incident reporting
- Push notifications

**High Priority:**
- Performance KPI view
- OKR tracking
- Training requests
- Learning recommendations
- Career path visibility
- Skill assessment
- Team chat
- Recognition system

**Medium Priority:**
- Document upload (KTP, sertifikat)
- Bank details management
- 360 reviews
- Mentorship programs
- Employee referral

### 2.2 Admin Needs (30+ needs)

**Critical:**
- Bulk operations (salary update, department move)
- Auto-approval rules configuration
- Payroll processing engine
- Payslip generation
- Timesheet approval
- Overtime approval
- Bulk request approval
- Onboarding workflow automation
- Offboarding workflow automation
- Custom report builder

**High Priority:**
- Scheduled reports
- Interactive dashboards
- Drill-down analytics
- Workflow configuration
- Approval rules UI
- Notification settings
- Integration settings

**Medium Priority:**
- SSO integration
- Data retention automation
- GDPR compliance tools
- Multi-language support

### 2.3 Manager Needs (25+ needs)

**Critical:**
- Team dashboard
- Quick approvals (from notification)
- Bulk approvals
- Team performance grid
- Performance review workflow
- Team schedule management
- Team attendance view
- Team analytics
- 1:1 meeting scheduling

**High Priority:**
- Succession planning
- Team KPI dashboard
- Attendance trends
- Leave trends
- Overtime analysis
- Headcount analysis
- Attrition analysis

**Medium Priority:**
- Team chat
- Recognition system
- Feedback collection
- Goal setting

---

## 3. Roadmap Implementation

### Phase 1: Critical Foundation (3-6 bulan)

> ⚠️ **F3 — Tumpang Tindih Phase (Diperbaiki):** `Shift Swap` (1.7) diperlukan oleh worker sejak hulu (bukan hanya Phase 2); `Payslip` (1.6) bergantung pada `Payroll Engine` (1.5) — urutan harus: Engine → Payslip → Shift Swap. `Team Dashboard` (2.2) sudah ada sebagai `Dashboard`/`OwnerDashboard` — duplikasi, perlu konsolidasi. `Push Notifications` (2.1) seharusnya sebelum `Performance Grid` (2.2) karena notifikasi memprasyaratkan event-trigger.

#### 1.1 Native Mobile App (P0 - CRITICAL)
**Timeline**: 3-4 bulan  
**Tech Stack**: React Native / Flutter  
**Features**:
- iOS & Android native apps
- Biometric authentication (fingerprint/face ID)
- Push notifications (OneSignal/Firebase)
- Offline-first architecture
- GPS geofencing clock-in/out
- One-tap attendance
- Real-time leave balance
- Payslip view & download
- Shift view & swap request
- Anonymous reporting
- Team chat

**Required RPCs**:
- `mobile_clock_in(p_nrp, p_latitude, p_longitude, p_photo)`
- `mobile_clock_out(p_nrp, p_latitude, p_longitude)`
- `mobile_get_attendance_history(p_nrp, p_date_from, p_date_to)`
- `mobile_get_schedule(p_nrp, p_date_from, p_date_to)`
- `mobile_request_leave(p_nrp, p_type, p_from, p_to, p_reason)`
- `mobile_request_shift_swap(p_nrp, p_shift_id, p_target_nrp)`
- `mobile_get_payslip(p_nrp, p_month)`
- `mobile_submit_grievance(p_category, p_description, p_anonymous, p_attachments)`
- `mobile_sync_offline_data(p_device_id, p_data)`

**Required Tables**:
- `mobile_devices` (device_id, nrp, platform, os_version, last_active)
- `attendance_locations` (id, name, latitude, longitude, radius, business_unit_id)
- `offline_queue` (id, device_id, action_type, payload, created_at, synced_at)
- `grievances` (id, nrp, category, description, anonymous, status, created_at)
- `mobile_notifications` (id, nrp, type, title, message, data, read_at, created_at)

**Migration Files**:
- `230_mobile_devices.sql`
- `231_attendance_locations.sql`
- `232_offline_queue.sql`
- `233_grievances.sql`
- `234_mobile_notifications.sql`
- `235_mobile_rpc_functions.sql`

---

#### 1.2 GPS Geofencing Attendance (P0 - CRITICAL)
**Timeline**: 1-2 bulan  
**Tech Stack**: Native mobile + Supabase Realtime  
**Features**:
- Define geofence zones per site/location
- Verify worker location on clock-in/out
- Radius-based validation (e.g., 100m from site)
- Location history tracking
- Geofence violation alerts
- Multi-site support

**Required RPCs**:
- `create_geofence(p_name, p_latitude, p_longitude, p_radius, p_business_unit_id)`
- `update_geofence(p_id, p_latitude, p_longitude, p_radius)`
- `get_geofences(p_business_unit_id)`
- `verify_location(p_nrp, p_latitude, p_longitude, p_geofence_id)`
- `get_attendance_locations(p_nrp, p_date)`
- `check_geofence_violation(p_nrp, p_latitude, p_longitude)`

**Required Tables**:
- `geofences` (id, name, latitude, longitude, radius, business_unit_id, is_active)
- `attendance_locations_log` (id, nrp, latitude, longitude, accuracy, timestamp, geofence_id)
- `geofence_violations` (id, nrp, geofence_id, violation_type, timestamp)

**Migration Files**:
- `236_geofences.sql`
- `237_attendance_locations_log.sql`
- `238_geofence_violations.sql`
- `239_geofence_rpc_functions.sql`

---

#### 1.3 Auto-Approval Rules (P0 - CRITICAL)
**Timeline**: 1-2 bulan  
**Tech Stack**: Supabase RPC + UI configuration  
**Features**:
- Configure auto-approval rules per request type
- Threshold-based approval (e.g., leave < 3 days auto-approve)
- Net-staffing condition (approve only if staff >= X)
- Blackout period handling
- Date-specific rules (holiday season)
- Multi-level approval with auto-approval at lower levels
- Override capabilities

**Required RPCs**:
- `create_approval_rule(p_request_type, p_condition_type, p_condition_value, p_action, p_threshold)`
- `update_approval_rule(p_id, p_condition_type, p_condition_value, p_action, p_threshold)`
- `get_approval_rules(p_request_type)`
- `delete_approval_rule(p_id)`
- `evaluate_approval_rule(p_request_id)`
- `auto_approve_request(p_request_id, p_rule_id)`

**Required Tables**:
- `approval_rules` (id, request_type, condition_type, condition_value, action, threshold, is_active, created_by, created_at)
- `approval_rule_conditions` (id, rule_id, field, operator, value)
- `approval_rule_history` (id, request_id, rule_id, action, actor, timestamp)

**Migration Files**:
- `240_approval_rules.sql`
- `241_approval_rule_conditions.sql`
- `242_approval_rule_history.sql`
- `243_approval_rule_rpc_functions.sql`

---

#### 1.4 Bulk Operations (P0 - CRITICAL)
**Timeline**: 1-2 bulan  
**Tech Stack**: Supabase RPC + UI batch actions  
**Features**:
- Bulk salary update (percentage/fixed amount)
- Bulk department move
- Bulk role assignment
- Bulk status change
- Bulk leave approval
- Bulk shift assignment
- Filter-based bulk actions

**Required RPCs**:
- `bulk_update_salary(p_filter, p_update_type, p_value)`
- `bulk_move_department(p_nrps, p_new_department_id)`
- `bulk_assign_role(p_nrps, p_role)`
- `bulk_change_status(p_nrps, p_status)`
- `bulk_approve_leave(p_request_ids)`
- `bulk_assign_shift(p_shift_assignments)`
- `get_bulk_operation_status(p_operation_id)`

**Required Tables**:
- `bulk_operations` (id, operation_type, actor, status, total_items, processed_items, failed_items, created_at, completed_at)
- `bulk_operation_items` (id, operation_id, item_id, item_type, status, error_message)
- `bulk_operation_filters` (id, operation_id, field, operator, value)

**Migration Files**:
- `244_bulk_operations.sql`
- `245_bulk_operation_items.sql`
- `246_bulk_operation_filters.sql`
- `247_bulk_operation_rpc_functions.sql`

---

#### 1.5 Payroll Engine (P0 - CRITICAL)
**Timeline**: 3-4 bulan  
**Tech Stack**: Supabase RPC + calculation engine  
**Features**:
- Gross pay calculation
- Overtime calculation (weekend, holiday rates)
- Allowance calculation (hazard pay, remote allowance)
- Deduction calculation (BPJS, PPh21, tax)
- Net pay calculation
- Payslip generation (PDF)
- Payroll review workflow
- Payroll export (CSV, Xero, MYOB)
- Tax reporting

**Required RPCs**:
- `calculate_payroll(p_payroll_period, p_business_unit_id)`
- `calculate_overtime(p_nrp, p_hours, p_rate, p_multiplier)`
- `calculate_allowances(p_nrp, p_allowance_type, p_amount)`
- `calculate_deductions(p_nrp, p_deduction_type, p_amount)`
- `calculate_tax(p_gross_pay, p_tax_status, p_ptkp)`
- `generate_payslip(p_nrp, p_payroll_period)`
- `review_payroll(p_payroll_period, p_business_unit_id)`
- `export_payroll(p_payroll_period, p_format)`
- `get_payroll_summary(p_payroll_period, p_business_unit_id)`

**Required Tables**:
- `payroll_periods` (id, period, start_date, end_date, status, processed_at)
- `payroll_calculations` (id, period_id, nrp, gross_pay, overtime, allowances, deductions, net_pay)
- `payslips` (id, nrp, period_id, pdf_url, generated_at)
- `payroll_rates` (id, role_level, business_unit_id, hourly_rate, daily_rate, monthly_rate)
- `allowance_types` (id, code, name, amount, is_taxable)
- `deduction_types` (id, code, name, percentage, is_taxable)
- `tax_tables` (id, range_start, range_end, rate)

**Migration Files**:
- `248_payroll_periods.sql`
- `249_payroll_calculations.sql`
- `250_payslips.sql`
- `251_payroll_rates.sql`
- `252_allowance_types.sql`
- `253_deduction_types.sql`
- `254_tax_tables.sql`
- `255_payroll_rpc_functions.sql`

---

#### 1.6 Payslip Generation (P0 - CRITICAL)
**Timeline**: 1-2 bulan  
**Tech Stack**: Supabase Storage + PDF generation  
**Features**:
- Digital payslip generation (PDF)
- Store payslip in Supabase Storage
- Secure payslip access
- Payslip history
- Email payslip (optional)
- MOM compliance (Singapore) - itemized payslip

**Required RPCs**:
- `generate_payslip_pdf(p_nrp, p_period)`
- `get_payslip_url(p_nrp, p_period)`
- `list_payslips(p_nrp)`
- `email_payslip(p_nrp, p_period)`
- `delete_payslip(p_nrp, p_period)`

**Required Tables**:
- `payslips` (id, nrp, period_id, pdf_url, storage_path, generated_at, emailed_at)
- `payslip_settings` (id, company_id, enable_email, email_template)

**Migration Files**:
- `256_payslips_storage.sql`
- `257_payslip_settings.sql`
- `258_payslip_rpc_functions.sql`

---

#### 1.7 Shift Swap Workflow (P1 - HIGH)
**Timeline**: 1-2 bulan  
**Tech Stack**: Supabase RPC + UI workflow  
**Features**:
- Shift swap request
- Shift bidding (for premium shifts)
- Swap approval workflow
- Auto-approve based on rules
- Notification to both parties
- Swap history

**Required RPCs**:
- `request_shift_swap(p_nrp, p_shift_id, p_target_nrp, p_reason)`
- `approve_shift_swap(p_swap_id, p_approver_nrp, p_note)`
- `reject_shift_swap(p_swap_id, p_approver_nrp, p_reason)`
- `cancel_shift_swap(p_swap_id, p_nrp)`
- `get_shift_swaps(p_nrp, p_status)`
- `get_available_swaps(p_shift_id)`
- `auto_approve_shift_swap(p_swap_id)`

**Required Tables**:
- `shift_swaps` (id, requester_nrp, original_shift_id, target_nrp, target_shift_id, status, reason, created_at, approved_at, approved_by)
- `shift_bids` (id, shift_id, nrp, bid_amount, status, created_at)

**Migration Files**:
- `259_shift_swaps.sql`
- `260_shift_bids.sql`
- `261_shift_swap_rpc_functions.sql`

---

#### 1.8 Anonymous Reporting (P0 - CRITICAL)
**Timeline**: 1-2 bulan  
**Tech Stack**: Supabase RPC + secure channel  
**Features**:
- Anonymous grievance reporting
- Category selection (bullying, discrimination, harassment, etc.)
- Evidence upload (photo/video)
- Two-way anonymous messaging
- Case tracking
- Escalation workflow
- SLA management

**Required RPCs**:
- `submit_grievance(p_category, p_description, p_anonymous, p_attachments)`
- `get_grievances(p_nrp, p_status)`
- `add_grievance_message(p_grievance_id, p_message, p_is_anonymous)`
- `get_grievance_messages(p_grievance_id)`
- `update_grievance_status(p_grievance_id, p_status, p_note)`
- `escalate_grievance(p_grievance_id, p_escalated_to)`

**Required Tables**:
- `grievances` (id, nrp, category, description, anonymous, status, created_at, updated_at, escalated_to)
- `grievance_messages` (id, grievance_id, sender_type, sender_id, message, created_at)
- `grievance_attachments` (id, grievance_id, file_url, file_name, created_at)
- `grievance_categories` (id, code, name, description)

**Migration Files**:
- `262_grievances.sql`
- `263_grievance_messages.sql`
- `264_grievance_attachments.sql`
- `265_grievance_categories.sql`
- `266_grievance_rpc_functions.sql`

---

### Phase 2: High Value Features (6-12 bulan)

#### 2.1 Push Notifications (P1 - HIGH)
**Timeline**: 1-2 bulan  
**Tech Stack**: OneSignal / Firebase Cloud Messaging  
**Features**:
- Push notifications for approvals
- Push notifications for deadlines
- Push notifications for schedule changes
- Push notifications for payslip ready
- In-app notification center
- Notification preferences

**Required RPCs**:
- `register_device(p_nrp, p_device_token, p_platform)`
- `send_notification(p_nrps, p_type, p_title, p_message, p_data)`
- `get_notifications(p_nrp, p_read)`
- `mark_notification_read(p_notification_id, p_nrp)`
- `update_notification_preferences(p_nrp, p_preferences)`

**Required Tables**:
- `notification_devices` (id, nrp, device_token, platform, os_version, registered_at)
- `notifications_sent` (id, device_id, type, title, message, data, sent_at, read_at)
- `notification_preferences` (id, nrp, notification_types, email_enabled, push_enabled)

**Migration Files**:
- `267_notification_devices.sql`
- `268_notifications_sent.sql`
- `269_notification_preferences.sql`
- `270_notification_rpc_functions.sql`

---

#### 2.2 Team Dashboard (P1 - HIGH)
**Timeline**: 2-3 bulan  
**Tech Stack**: React + Chart.js / Recharts  
**Features**:
- Team attendance view
- Team performance metrics
- Team leave utilization
- Team overtime analysis
- Team headcount
- Drill-down to individual level
- Real-time updates

**Required RPCs**:
- `get_team_dashboard(p_manager_nrp, p_date_from, p_date_to)`
- `get_team_attendance_summary(p_manager_nrp, p_date)`
- `get_team_performance_summary(p_manager_nrp, p_period)`
- `get_team_leave_utilization(p_manager_nrp, p_year)`
- `get_team_overtime_summary(p_manager_nrp, p_month)`
- `get_team_headcount(p_manager_nrp, p_as_of_date)`

**Migration Files**:
- Frontend dashboard component development
- RPC functions likely already exist, need aggregation layer

---

#### 2.3 Performance Grid UI (P1 - HIGH)
**Timeline**: 2-3 bulan  
**Tech Stack**: React + DataGrid  
**Features**:
- Team performance grid
- Rating system with scales
- Performance review workflow
- 360 review workflow
- Feedback collection
- Coaching session management
- KPI setting

**Required RPCs**:
- `get_performance_grid(p_manager_nrp, p_period)`
- `update_performance_rating(p_nrp, p_period, p_criteria, p_rating)`
- `initiate_performance_review(p_manager_nrp, p_employee_nrp, p_period)`
- `submit_performance_review(p_review_id, p_ratings, p_feedback)`
- `request_360_review(p_nrp, p_reviewees)`
- `submit_360_review(p_review_id, p_responses)`
- `schedule_coaching_session(p_manager_nrp, p_employee_nrp, p_date)`

**Required Tables**:
- `performance_reviews` (id, reviewer_nrp, employee_nrp, period, status, submitted_at, completed_at)
- `performance_ratings` (id, review_id, criteria, rating, weight)
- `360_reviews` (id, initiator_nrp, reviewee_nrp, period, status)
- `360_responses` (id, review_id, reviewer_nrp, question, rating, comment)
- `coaching_sessions` (id, manager_nrp, employee_nrp, date, status, notes, created_at)

**Migration Files**:
- `271_performance_reviews.sql`
- `272_performance_ratings.sql`
- `273_360_reviews.sql`
- `274_360_responses.sql`
- `275_coaching_sessions.sql`
- `276_performance_rpc_functions.sql`

---

#### 2.4 Onboarding Workflow (P1 - HIGH)
**Timeline**: 2-3 bulan  
**Tech Stack**: Supabase RPC + workflow engine  
**Features**:
- Automated onboarding checklist
- Document collection
- Task assignment
- Progress tracking
- Reminder automation
- Manager approval checkpoints

**Required RPCs**:
- `initiate_onboarding(p_nrp, p_manager_nrp, p_start_date)`
- `update_onboarding_task(p_onboarding_id, p_task_id, p_status, p_note)`
- `get_onboarding_progress(p_nrp)`
- `get_onboarding_checklist(p_business_unit_id)`
- `complete_onboarding(p_onboarding_id)`

**Required Tables**:
- `onboarding_sessions` (id, nrp, manager_nrp, start_date, status, completion_date)
- `onboarding_tasks` (id, session_id, task_id, task_name, status, due_date, completed_at)
- `onboarding_checklists` (id, business_unit_id, task_name, required)
- `onboarding_documents` (id, session_id, document_type, file_url, uploaded_at)

**Migration Files**:
- `277_onboarding_sessions.sql`
- `278_onboarding_tasks.sql`
- `279_onboarding_checklists.sql`
- `280_onboarding_documents.sql`
- `281_onboarding_rpc_functions.sql`

---

#### 2.5 Offboarding Workflow (P1 - HIGH)
**Timeline**: 2-3 bulan  
**Tech Stack**: Supabase RPC + workflow engine  
**Features**:
- Automated offboarding checklist
- Access revocation workflow
- Final settlement calculation
- Exit interview
- Clearance process
- Document return tracking

**Required RPCs**:
- `initiate_offboarding(p_nrp, p_manager_nrp, p_last_date, p_reason)`
- `update_offboarding_task(p_offboarding_id, p_task_id, p_status, p_note)`
- `get_offboarding_progress(p_nrp)`
- `calculate_final_settlement(p_nrp, p_last_date)`
- `complete_exit_interview(p_offboarding_id, p_responses)`
- `revoke_access(p_nrp, p_access_types)`

**Required Tables**:
- `offboarding_sessions` (id, nrp, manager_nrp, last_date, reason, status, completion_date)
- `offboarding_tasks` (id, session_id, task_id, task_name, status, due_date, completed_at)
- `final_settlements` (id, session_id, sisa_cuti, thr_prorata, pesangon, total, status)
- `exit_interviews` (id, nrp, satisfaction_score, reason, feedback, created_at)

**Migration Files**:
- `282_offboarding_sessions.sql`
- `283_offboarding_tasks.sql`
- `284_final_settlements.sql` (exists, need enhancement)
- `285_offboarding_rpc_functions.sql`

---

#### 2.6 SSO Integration (P1 - HIGH)
**Timeline**: 2-3 bulan  
**Tech Stack**: Supabase Auth + SAML/OAuth  
**Features**:
- Okta integration
- Azure AD integration
- Google Workspace integration
- Single sign-on
- User provisioning
- Just-in-time deprovisioning

**Required RPCs**:
- `link_sso_account(p_nrp, p_sso_provider, p_sso_id)`
- `sync_sso_user(p_sso_provider, p_sso_id)`
- `unlink_sso_account(p_nrp)`

**Required Tables**:
- `sso_accounts` (id, nrp, provider, provider_id, linked_at, last_synced)

**Migration Files**:
- `286_sso_accounts.sql`
- `287_sso_rpc_functions.sql`

---

### Phase 3: Competitive Edge (12-18 bulan)

#### 3.1 Predictive Analytics (P2 - MEDIUM)
**Timeline**: 4-6 bulan  
**Tech Stack**: Python + scikit-learn + Supabase  
**Features**:
- Flight risk prediction
- Workforce planning prediction
- Skill gap analysis
- Attrition prediction
- Performance prediction
- Anomaly detection

**Required RPCs**:
- `predict_flight_risk(p_nrp)`
- `predict_workforce_needs(p_business_unit_id, p_period)`
- `predict_skill_gaps(p_role_id)`
- `predict_attrition(p_department_id, p_period)`
- `detect_anomalies(p_metric, p_period)`

**Required Tables**:
- `ml_predictions` (id, model_type, entity_id, prediction_value, confidence, generated_at)
- `ml_models` (id, model_name, version, accuracy, trained_at, is_active)
- `ml_features` (id, model_id, feature_name, importance)

**Migration Files**:
- `288_ml_predictions.sql`
- `289_ml_models.sql`
- `290_ml_features.sql`
- `291_ml_rpc_functions.sql`

---

#### 3.2 Team Chat (P2 - MEDIUM)
**Timeline**: 2-3 bulan  
**Tech Stack**: Supabase Realtime + WebSocket  
**Features**:
- Team chat rooms
- Direct messaging
- File sharing
- Read receipts
- Online status
- Message search

**Required RPCs**:
- `send_chat_message(p_from_nrp, p_to_nrp, p_message, p_type)`
- `get_chat_history(p_from_nrp, p_to_nrp, p_limit)`
- `create_chat_room(p_name, p_participants)`
- `send_room_message(p_room_id, p_from_nrp, p_message)`
- `get_room_messages(p_room_id, p_limit)`

**Required Tables**:
- `chat_messages` (id, from_nrp, to_nrp, room_id, message, type, read_at, created_at)
- `chat_rooms` (id, name, type, created_by, created_at)
- `chat_room_participants` (id, room_id, nrp, joined_at)

**Migration Files**:
- `292_chat_messages.sql`
- `293_chat_rooms.sql`
- `294_chat_room_participants.sql`
- `295_chat_rpc_functions.sql`

---

#### 3.3 Recognition System (P2 - MEDIUM)
**Timeline**: 2-3 bulan  
**Tech Stack**: Supabase RPC + UI  
**Features**:
- Peer recognition
- Points/badges system
- Recognition feed
- Leaderboard
- Manager recognition
- Gamification

**Required RPCs**:
- `give_recognition(p_from_nrp, p_to_nrp, p_type, p_message, p_points)`
- `get_recognitions(p_nrp, p_period)`
- `get_leaderboard(p_period, p_type)`
- `award_badge(p_nrp, p_badge_id)`
- `get_points_balance(p_nrp)`

**Required Tables**:
- `recognitions` (id, from_nrp, to_nrp, type, message, points, created_at)
- `badges` (id, code, name, description, icon, points_required)
- `user_badges` (id, nrp, badge_id, awarded_at)
- `points` (id, nrp, balance, earned, spent)

**Migration Files**:
- `296_recognitions.sql`
- `297_badges.sql`
- `298_user_badges.sql`
- `299_points.sql`
- `300_recognition_rpc_functions.sql`

---

#### 3.4 LMS Integration (P2 - MEDIUM)
**Timeline**: 3-4 bulan  
**Tech Stack:**
- External LMS integration (Moodle, Docebo, etc.)
- OR build basic LMS

**Features**:
- Course catalog
- Enrollment
- Progress tracking
- Certificates
- Offline learning download
- AI learning recommendations

**Required RPCs**:
- `get_courses(p_category)`
- `enroll_course(p_nrp, p_course_id)`
- `get_learning_progress(p_nrp)`
- `update_learning_progress(p_nrp, p_course_id, p_progress)`
- `get_recommended_courses(p_nrp)`
- `download_course_content(p_course_id, p_module_id)`

**Required Tables**:
- `courses` (id, code, title, category, description, duration, is_active)
- `enrollments` (id, nrp, course_id, enrolled_at, completed_at, progress)
- `course_modules` (id, course_id, title, content, duration, order)
- `course_progress` (id, enrollment_id, module_id, status, completed_at)

**Migration Files**:
- `301_courses.sql`
- `302_enrollments.sql`
- `303_course_modules.sql`
- `304_course_progress.sql`
- `305_lms_rpc_functions.sql`

---

## 4. Technical Implementation Guide

### 4.1 Database Schema Standards

**Naming Conventions:**
- Tables: snake_case (e.g., `mobile_devices`)
- Columns: snake_case (e.g., `device_token`)
- Functions: snake_case (e.g., `mobile_clock_in`)
- Indexes: `idx_table_column` or unique constraint
- Foreign keys: `fkey_table_column`

**Common Columns:**
- `id` - primary key (UUID or serial)
- `created_at` - timestamp with time zone, default now()
- `updated_at` - timestamp with time zone, default now()
- `created_by` - nrp who created
- `updated_by` - nrp who updated
- `is_active` - boolean, default true

**RLS Policies:**
- All tables must have RLS enabled
- Row-level security based on `auth.uid()` or `authz_current_nrp()`
- Separate policies for SELECT, INSERT, UPDATE, DELETE
- Service role bypass for admin operations

**Security:**
- All SECURITY DEFINER functions must have `SET search_path = public, extensions`
- REVOKE PUBLIC/anon from sensitive functions
- Use bcrypt for passwords (`gen_salt('bf')` + `crypt()`)
- Never echo password in response

### 4.2 RPC Function Standards

**Function Signature:**
```sql
CREATE OR REPLACE FUNCTION function_name(p_param1 type, p_param2 type)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  -- variables
BEGIN
  -- logic
  RETURN jsonb_build_object('ok', true, 'data', ...);
END;
$$;
```

**Error Handling:**
- Use `EXCEPTION WHEN OTHERS` for graceful error handling
- Return structured error: `jsonb_build_object('ok', false, 'msg', error_message)`
- Log errors to `audit_log`

**Validation:**
- Validate input parameters at function start
- Check permissions using `authz_check_admin()` or `authz_in_scope()`
- Validate business rules (e.g., leave balance, shift availability)

**Grants:**
- Grant EXECUTE to `authenticated` for user-facing functions
- Grant EXECUTE to `service_role` for admin functions
- Grant EXECUTE to `anon` only for pre-auth functions (login, OTP)
- REVOKE from PUBLIC

### 4.3 Migration File Standards

**Naming:**
- 3-digit sequential number: `000_`, `001_`, `002_`, etc.
- Descriptive name: `feature_description.sql`
- No duplicate numbers
- Rollback files: `feature_description_rollback.sql`

**Structure:**
```sql
-- ============================================================
-- XXX_feature_description.sql
-- ============================================================
-- Description
-- Dependencies: requires migration YYY
-- ============================================================

-- Comments explaining the migration

-- SQL statements

-- Verification queries (SELECT 1 AS success)
```

**Idempotent:**
- Use `CREATE OR REPLACE` for functions
- Use `CREATE TABLE IF NOT EXISTS` for tables
- Use `INSERT ... ON CONFLICT DO NOTHING` for data
- Use `ALTER TABLE ... IF EXISTS` for alters

### 4.4 Frontend Standards

**Component Structure:**
- Atomic components (small, focused)
- Composition over inheritance
- Custom hooks for business logic
- Type-safe props with TypeScript

**State Management:**
- Use React Context for global state
- Use React Query / SWR for server state
- Use Zustand / Redux for complex client state

**API Calls:**
- Use Supabase client from `supabase-browser.js`
- Use RPC calls: `supabase.rpc('function_name', { param: value })`
- Error handling: `const { data, error } = await ...; if (error) { ... }`

**Styling:**
- Use design system from `lib/design-system.js`
- Follow minimalist-ui skill principles
- No hardcoded colors/branding (use from branding table)

**Performance:**
- Lazy load routes with React.lazy()
- Code splitting with dynamic imports
- Optimize images and assets
- Use React.memo for expensive components

### 4.5 Testing Standards

**Unit Tests:**
- Test business logic functions
- Test RPC functions with mocked database
- Test custom hooks
- Test utility functions

**Integration Tests:**
- Test API endpoints
- Test database migrations
- Test edge functions

**E2E Tests:**
- Test critical user flows (login, dashboard, requests)
- Test multi-role scenarios
- Test mobile responsiveness

**Test Coverage:**
- Aim for 80%+ coverage for critical paths
- 100% coverage for security-critical functions

---

## 5. Ecosystem Integration

### 5.1 Current Integrations

**Supabase:**
- Database (PostgreSQL)
- Auth (Supabase Auth)
- Storage (file storage)
- Realtime (real-time subscriptions)
- Edge Functions (serverless)

**Vercel:**
- Frontend deployment
- Edge functions deployment

**Upstash Redis:**
- Cache for Level 3-5 (tier-based caching)

### 5.5 Proposed Integrations

**Phase 1:**
- OneSignal (push notifications)
- Firebase Storage (alternative file storage)
- pg_cron (scheduled jobs)

**Phase 2:**
- Okta / Azure AD (SSO)
- Xero / MYOB (payroll export)
- Google Workspace (email/calendar)

**Phase 3:**
- Moodle / Docebo (LMS)
- Slack / Microsoft Teams (team chat)
- Power BI / Metabase (analytics)

---

## 6. Migration Sequence

### 6.1 Immediate (Fix Critical Issues from Forensic Audit) — UPDATED

> ⚠️ **Revisi 2026-09-16:** Klaim "8 functions missing search_path" sudah **OBSOLETE** (`AGENTS.md` §5.6, `futureplans_vs_live.py`: 0 violations; migration `207` sudah fix). `pg_cron` sudah aktif (`6` jobs). `20 overloads` sudah di-rename ke `_legacy_*` (bukan bug operasional).

1. ~~Fix 8 functions missing 'extensions' in search_path~~ → **OBSOLETE** (0 violations, `§7.6`)
2. ~~Install pg_cron~~ → **SUDAH AKTIF** (`cron.job`: 6 jobs; `§7.4`)
3. Resolve 20 function overloads → **PARTIAL** (`_legacy_*` rename sudah; sisa drop bisa P3)
4. Apply migration `171` (sync DB-only functions) → masih berlaku jika belum

### 6.2 Phase 1 (3-6 bulan)

Migration sequence:
1. 230-235: Mobile app foundation
2. 236-239: GPS geofencing
3. 240-243: Auto-approval rules
4. 244-247: Bulk operations
5. 248-255: Payroll engine
6. 256-258: Payslip generation
7. 259-261: Shift swap
8. 262-266: Anonymous reporting

### 6.3 Phase 2 (6-12 bulan)

Migration sequence:
1. 267-270: Push notifications
2. 271-276: Performance grid
3. 277-281: Onboarding workflow
4. 282-285: Offboarding workflow
5. 286-287: SSO integration

### 6.4 Phase 3 (12-18 bulan)

Migration sequence:
1. 288-291: Predictive analytics
2. 292-295: Team chat
3. 296-300: Recognition system
4. 301-305: LMS integration

---

## 7. Success Metrics

### 7.1 Phase 1 Metrics

- **Mobile App Adoption**: 80% of workers download and use app within 3 months
- **GPS Geofencing Coverage**: 100% of sites have geofence zones defined
- **Auto-Approval Reduction**: 60% reduction in manual approvals
- **Bulk Operations Usage**: 90% of admin operations use bulk actions
- **Payroll Automation**: 80% of payroll processed automatically
- **Payslip Self-Service**: 95% of employees access payslips via app
- **Shift Swap Response Time**: < 24 hours from request to resolution
- **Anonymous Reporting Usage**: 50% of grievances reported anonymously

### 7.2 Phase 2 Metrics

- **Push Notification Open Rate**: 70% open rate
- **Team Dashboard Usage**: 90% of managers use dashboard weekly
- **Performance Review Cycle Time**: Reduced from 4 weeks to 2 weeks
- **Onboarding Completion**: 95% complete onboarding within 1 month
- **Offboarding Compliance**: 100% compliance with offboarding checklist
- **SSO Adoption**: 100% of enterprise clients use SSO

### 7.3 Phase 3 Metrics

- **Flight Risk Prediction Accuracy**: 80% accuracy
- **Workforce Planning Accuracy**: 75% accuracy
- **Team Chat Adoption**: 70% of teams use team chat
- **Recognition Participation**: 60% of employees give/receive recognition
- **LMS Completion Rate**: 80% course completion rate

---

## 8. Risks & Mitigations

### 8.1 Phase 1 Risks

**Risk**: Mobile app development delay  
**Mitigation**: Start with MVP core features, iterate quickly

**Risk**: GPS geofencing false positives  
**Mitigation**: Configure adequate radius, allow manual override

**Risk**: Auto-approval rules too permissive  
**Mitigation**: Start conservative, require manager approval for > X days

**Risk**: Payroll calculation errors  
**Mitigation**: Extensive testing, manual review mode for first 3 periods

**Risk**: Bulk operations data loss  
**Mitigation**: Transaction rollback, dry-run mode, confirmation prompts

### 8.2 Phase 2 Risks

**Risk**: Push notification fatigue  
**Mitigation**: Smart scheduling, digest notifications, user preferences

**Risk**: Performance grid data overload  
**Mitigation**: Pagination, filtering, caching

**Risk**: Onboarding/offboarding workflow gaps  
**Mitigation**: Checklist templates, manager reminders

**Risk**: SSO integration complexity  
**Mitigation**: Start with one provider (Okta), expand later

### 8.3 Phase 3 Risks

**Risk**: ML model accuracy issues  
**Mitigation**: Continuous monitoring, fallback to manual processes

**Risk**: Team chat message overload  
**Mitigation**: Channel organization, mute options, summary mode

**Risk**: Recognition system gaming  
**Mitigation**: Manager approval, anti-gaming rules

**Risk**: LMS integration complexity  
**Mitigation**: Start with basic LMS, expand to advanced features

---

## 9. Resource Requirements

### 9.1 Phase 1 Resources

**Team:**
- 1 Mobile Developer (React Native/Flutter)
- 1 Backend Developer (RPC functions, migrations)
- 1 Frontend Developer (React, dashboards)
- 1 QA Engineer
- 1 Product Manager (part-time)

**Timeline:** 3-6 months

**Infrastructure:**
- Supabase Pro (already have)
- OneSignal (push notifications)
- Additional Supabase storage for payslips

### 9.2 Phase 2 Resources

**Team:**
- 1 Backend Developer (continued)
- 1 Frontend Developer (continued)
- 1 DevOps Engineer (SSO, integrations)
- 1 QA Engineer (continued)

**Timeline:** 6-12 months

**Infrastructure:**
- Okta/Azure AD (SSO)
- Xero/MYOB (payroll export - optional)

### 9.3 Phase 3 Resources

**Team:**
- 1 Data Scientist (ML models)
- 1 Backend Developer (ML integration)
- 1 Frontend Developer (advanced features)
- 1 DevOps Engineer (LMS integration)

**Timeline:** 12-18 months

**Infrastructure:**
- Python ML environment
- External LMS (Moodle/Docebo - optional)
- Real-time messaging server (for team chat)

---

## 10. Conclusion

insightWOS has strong foundation with tier-based access, role-based permissions, and mining-specific features. However, critical gaps exist in mobile experience, automation, and advanced analytics.

**Immediate Priority:**
1. Build native mobile app with GPS geofencing
2. Implement auto-approval rules and bulk operations
3. Build payroll engine with payslip generation
4. Implement shift swap and anonymous reporting workflows

**Long-term Vision:**
- Compete with Workday, SAP, ADP in the mining/industrial segment
- Become the #1 HR/WMS for Indonesian mining/estate/mill companies
- Expand to other industries (construction, manufacturing, F&B)

**Success Criteria:**
- 80% mobile app adoption within 3 months
- 60% reduction in manual admin workload
- 95% employee self-service adoption
- Positive user feedback (NPS > 50)

---

**Next Steps:**
1. Review and approve this roadmap
2. Prioritize Phase 1 features
3. Allocate resources
4. Start with mobile app MVP
5. Apply critical database fixes (8 functions missing extensions, pg_cron installation)
