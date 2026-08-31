# 🔍 AUDIT v4 → v5 — insightWOS
**Tanggal: 31 Agustus 2026**
**Status: v4.0 Complete → v5.0 Planning**

---

## 📊 RINGKASAN EKSEKUTIF

| Metrik | Nilai |
|--------|:-----:|
| Total Custom Pages | 76 |
| Total Routes | 76 |
| Total RPC Functions (SQL) | 268 |
| RPC Called from Frontend | 100 |
| **RPC BELUM di-wire** | **168** |
| Migration Files | 51 |
| Seed Data | 2000+ karyawan |
| Business Units | 4 (MINING/ESTATE/MILL/HQ) |
| Admin Roles | 4 (Pusat/HRD/Finance/Produksi) |
| Third-Party Services | 6 aktif + 9 planned |

---

## 🔴 KRITIS — Yang BELUM Dikerjakan

### #1: 168 RPC belum di-wire ke frontend
**Dampak:** Banyak halaman ada tapi data kosong/tidak berfungsi
**Estimasi:** 2-3 hari

**Prioritas Wiring (berdasarkan frekuensi pakai):**

| Prioritas | RPC | Dipanggil dari | Status |
|:---------:|-----|----------------|:------:|
| P1 | `get_worker_leave` | WorkerLeave | ⚠️ |
| P1 | `get_worker_overtime` | WorkerOvertime | ⚠️ |
| P1 | `get_worker_learning` | WorkerLearning | ⚠️ |
| P1 | `get_worker_attendance` | WorkerAttendance | ⚠️ |
| P1 | `get_worker_benefits` | WorkerPayroll | ⚠️ |
| P1 | `get_worker_career` | WorkerCareer | ⚠️ |
| P1 | `get_worker_skills` | WorkerSkills | ❌ |
| P1 | `get_worker_capability` | WorkerCapability | ❌ |
| P1 | `get_worker_exit` | WorkerExit | ❌ |
| P1 | `get_worker_engagement` | WorkerEngagement | ❌ |
| P1 | `get_worker_medical` | WorkerMedical | ❌ |
| P1 | `get_worker_relations` | WorkerRelations | ❌ |
| P1 | `get_worker_critical` | WorkerCritical | ❌ |
| P2 | `get_shift_schedule` | ShiftSchedule | ⚠️ |
| P2 | `get_shift_swaps` | ShiftSwap | ⚠️ |
| P2 | `get_timesheets` | Timesheet | ⚠️ |
| P2 | `get_task_board` | TaskBoard | ⚠️ |
| P2 | `get_my_tasks` | WorkerTasks | ⚠️ |
| P2 | `get_my_requests` | WorkerRequests | ⚠️ |
| P2 | `get_my_training_requests` | WorkerTraining | ⚠️ |
| P2 | `get_my_okrs` | WorkerOKR | ⚠️ |
| P2 | `get_my_continuous_performance` | ContinuousPerf | ⚠️ |
| P2 | `get_performance_notes` | PerformanceNotes | ⚠️ |
| P2 | `get_compensation_intelligence` | CompIntel | ⚠️ |
| P2 | `get_benefit_data` | WorkerBenefits | ⚠️ |
| P2 | `get_benefit_catalog` | BenefitCatalog | ❌ |
| P2 | `get_capability_gap` | CapabilityGap | ❌ |
| P2 | `get_career_path` | CareerPath | ❌ |
| P2 | `get_coaching_catalog` | CoachingCatalog | ❌ |
| P2 | `get_competency_matrix` | CompetencyMatrix | ❌ |
| P2 | `get_certifications` | Certifications | ❌ |
| P2 | `get_badges` | Badges | ❌ |
| P2 | `get_badges_leaderboard` | BadgeLeaderboard | ❌ |
| P3 | `get_talent_marketplace` | TalentMarket | ❌ |
| P3 | `get_succession` | Succession | ❌ |
| P3 | `get_succession_matrix` | SuccessionMatrix | ❌ |
| P3 | `get_learning_recommendations` | LearningRecs | ❌ |
| P3 | `get_narrative` | NarrativeIntel | ❌ |
| P3 | `get_enps_score` | eNPS | ❌ |
| P3 | `get_survey_results` | SurveyResults | ❌ |
| P3 | `get_active_surveys` | ActiveSurveys | ❌ |
| P3 | `get_whistleblowers` | Whistleblower | ❌ |
| P3 | `get_forum_posts` | ForumDiskusi | ⚠️ |
| P3 | `get_worker_notifications` | Notifications | ⚠️ |
| P3 | `get_realtime_notifications` | RealtimeNotif | ❌ |
| P3 | `get_realtime_alerts` | RealtimeAlerts | ❌ |
| P3 | `get_calendar_holidays` | CalendarHolidays | ❌ |
| P3 | `get_document_types` | DocumentTypes | ❌ |
| P3 | `get_employee_documents` | EmployeeDocs | ❌ |
| P3 | `get_employee_mutations` | Mutations | ❌ |
| P3 | `get_legal_documents` | LegalDocs | ❌ |
| P3 | `get_disciplinary_records` | Disciplinary | ❌ |
| P3 | `get_compliance_catalog` | Compliance | ❌ |
| P3 | `get_compliance_rate` | ComplianceRate | ❌ |
| P3 | `get_penalty_matrix` | PenaltyMatrix | ❌ |
| P3 | `get_near_miss_data` | NearMiss | ❌ |
| P3 | `get_safety_summary` | SafetySummary | ❌ |
| P3 | `get_plantation_harvest` | HarvestData | ❌ |
| P3 | `get_production_output` | ProductionOutput | ❌ |
| P3 | `get_equipment_util` | EquipmentUtil | ❌ |
| P3 | `get_overtime_data` | OvertimeData | ❌ |
| P3 | `get_action_center` | ActionCenter | ❌ |
| P3 | `get_approval_config` | ApprovalConfig | ❌ |
| P3 | `get_assets` | Assets | ❌ |
| P3 | `get_audit_chain` | AuditChain | ⚠️ |
| P3 | `get_budget_allocation` | BudgetAllocation | ❌ |
| P3 | `get_ceo_command_data` | CEOCommand | ❌ |
| P3 | `get_corporate_licenses` | CorporateLicenses | ❌ |
| P3 | `get_cost_per_unit` | CostPerUnit | ❌ |
| P3 | `get_disciplinary_records` | Disciplinary | ❌ |
| P3 | `get_executive_brief` | ExecutiveBrief | ❌ |
| P3 | `get_executive_summary` | ExecSummary | ❌ |
| P3 | `get_exit_clearance` | ExitClearance | ❌ |
| P3 | `get_exit_interviews` | ExitInterviews | ❌ |
| P3 | `get_final_settlement` | FinalSettlement | ❌ |
| P3 | `get_financial_stats` | FinancialStats | ❌ |
| P3 | `get_financial_trend` | FinancialTrend | ❌ |
| P3 | `get_flight_risk_details` | FlightRiskDetail | ❌ |
| P3 | `get_flight_risk_list` | FlightRiskList | ❌ |
| P3 | `get_headcount_plans` | HeadcountPlans | ❌ |
| P3 | `get_incentives` | Incentives | ⚠️ |
| P3 | `get_kpi_by_division` | KPIByDivision | ⚠️ |
| P3 | `get_kpi_calc_log` | KPICalcLog | ❌ |
| P3 | `get_kpi_config_all` | KPIConfig | ❌ |
| P3 | `get_legal_documents` | LegalDocs | ❌ |
| P3 | `get_manager_command_data` | ManagerCommand | ❌ |
| P3 | `get_medical_checkup` | MedicalCheckup | ❌ |
| P3 | `get_org_health` | OrgHealth | ❌ |
| P3 | `get_organization_health` | OrgHealthV2 | ❌ |
| P3 | `get_people_search` | PeopleSearch | ❌ |
| P3 | `get_referrals` | Referrals | ❌ |
| P3 | `get_salary_adjustments` | SalaryAdjust | ❌ |
| P3 | `get_turnover_data` | TurnoverData | ❌ |
| P3 | `get_turnover_prediction` | TurnoverPred | ❌ |
| P3 | `get_workforce_health_score` | WorkforceHealth | ❌ |
| P3 | `get_workforce_planning` | WorkforcePlanning | ❌ |
| P3 | `get_anomaly_details` | AnomalyDetails | ❌ |
| P3 | `get_monthly_snapshot_trend` | MonthlySnapshot | ❌ |
| P3 | `get_conversation_stats` | ConversationStats | ❌ |
| P3 | `get_document_types` | DocumentTypes | ❌ |

**Total: 100+ RPCs perlu di-wire**

---

### #2: Testing 0%
**Dampak:** Tidak ada jaminan kualitas
**Estimasi:** 1 minggu

| Jenis Test | Tool | Target |
|------------|------|:------:|
| Unit (Frontend) | Vitest + React Testing Library | 50% coverage |
| Unit (Backend) | pgTAP (PostgreSQL testing) | RPC coverage |
| Integration | Supabase Test Harness | Critical paths |
| E2E | Playwright | 10 smoke tests |
| Load | K6 | 100 concurrent users |

---

### #3: ISO 45001 (K3) Compliance
**Dampak:** Wajib untuk tambang/kebun — regulatory
**Estimasi:** 1 minggu

| Control | Requirement | Status |
|---------|-------------|:------:|
| 4.1 | Context understanding | ✅ |
| 4.2 | Worker consultation | ✅ Forum |
| 5.1 | Leadership commitment | 🔶 |
| 5.4 | OH&S roles | ✅ |
| 6.1 | Hazard identification | 🔶 Safety K3 |
| 6.1.2 | Risk assessment | 🆕 |
| 6.1.4 | Control measures | 🆕 |
| 6.2 | OH&S objectives | 🔶 |
| 7.2 | Competence | ✅ Training |
| 7.3 | Awareness | 🆕 |
| 7.4 | Communication | ✅ |
| 7.5 | Documented info | ✅ |
| 8.1.2 | Hazard control | 🆕 PPE |
| 8.1.4 | Procurement | 🆕 |
| 8.2 | Emergency preparedness | 🔶 |
| 8.3 | Incident reporting | 🔶 |
| 9.1 | Monitoring | 🔶 |
| 9.1.2 | Compliance evaluation | 🆕 |
| 10.1 | Incident investigation | 🆕 5-Why |
| 10.2 | Corrective action | 🆕 CAPA |
| 10.3 | Continual improvement | 🔶 |

---

### #4: ISO 14001 (Lingkungan) Compliance
**Dampak:** Wajib untuk perkebunan/PKS
**Estimasi:** 1 minggu

| Control | Requirement | Status |
|---------|-------------|:------:|
| 4.1 | Environmental context | ✅ |
| 4.2 | Interested parties | 🆕 |
| 4.3 | Scope | 🆕 |
| 5.1 | Leadership | 🆕 |
| 6.1.2 | Environmental aspects | 🆕 Carbon |
| 6.1.3 | Compliance obligations | 🆕 |
| 6.2 | Objectives | 🆕 |
| 7.2 | Competence | 🔶 |
| 7.5 | Documentation | 🆕 |
| 8.1 | Operational control | 🆕 Waste |
| 8.2 | Emergency | 🆕 |
| 9.1 | Monitoring | 🆕 |
| 9.1.2 | Compliance evaluation | 🆕 |
| 10.1 | Nonconformity | 🆕 |
| 10.2 | Corrective action | 🆕 |

---

### #5: QStash Async Workers
**Dampak:** PDF generation, email blast, ML pipeline tidak jalan
**Estimasi:** 3 hari

| Worker | Fungsi | Tool |
|--------|--------|------|
| PDF Generator | Generate slip gaji, laporan | @react-pdf/renderer |
| Email Blast | Notifikasi massal | Resend (free 100/day) |
| ML Pipeline | Turnover prediction, anomaly | Scikit-learn |
| Report Scheduler | Laporan berkala | pg_cron |
| Notification Worker | Push notification | Web Push API |

---

### #6: Offline PWA
**Dampak:** Worker di lapangan tidak bisa akses tanpa sinyal
**Estimasi:** 3 hari

| Komponen | Tool | Status |
|----------|------|:------:|
| Service Worker | Workbox | 🔶 |
| IndexedDB Cache | idb | 🆕 |
| Background Sync | SyncManager | 🆕 |
| Offline Indicator | Custom component | 🆕 |
| Conflict Resolution | Last-write-wins | 🆕 |

---

## 🟡 PENTING — Yang Perlu Diperbaiki

### #7: Vercel Edge Middleware
**Detail:** Session check + rate limiting di edge
**Estimasi:** 1 hari

### #8: Materialized Views Refresh
**Detail:** `mv_admin_summary`, `mv_team_kpi`, `mv_payroll_monthly`, `mv_attendance_daily`, `mv_flight_risk` perlu cron refresh
**Estimasi:** 1 hari

### #9: 9 Tabel Akses `.from()` Langsung
**Detail:** Seharusnya semua via RPC (security best practice)
**Estimasi:** 1 hari

### #10: npm Audit
**Detail:** Known vulnerabilities check
**Estimasi:** 30 menit

### #11: Manager Dashboard Custom
**Detail:** Masih pakai placeholder, perlu custom page
**Estimasi:** 1 hari

### #12: Worker Navigation Lengkap
**Detail:** Worker modul (Safety, Fatigue, Harvest, etc.) belum ada page
**Estimasi:** 2 hari

---

## 🟢 RENDAH — Nice to Have

| # | Gap | Tool | Estimasi |
|---|-----|------|:--------:|
| 13 | Documentation | Docusaurus | 3 hari |
| 14 | Load Testing | K6 | 1 hari |
| 15 | E2E Testing | Playwright | 2 hari |
| 16 | Monitoring | Prometheus + Grafana | 1 hari (butuh VPS) |
| 17 | Workflow Automation | N8N | 2 hari (butuh VPS) |
| 18 | ATS Recruitment | OpenCATS | 3 hari (butuh VPS) |

---

## 📋 LAYANAN PIHAK KETIGA — Status

### Aktif (v4.0)

| # | Layanan | Fungsi | Free Tier | Biaya |
|---|---------|--------|:---------:|:-----:|
| 1 | **Supabase** | DB + Auth + Storage + Edge Functions | 500MB DB, 50K MAU | $0 |
| 2 | **Google Gemini Flash** | AI Copilot (RAG) | Rate limited | $0 |
| 3 | **PostHog** | Analytics + Error Tracking + Feature Flags | 1M events/mo | $0 |
| 4 | **Upstash Redis** | Cache + Session + Rate Limiting | 10K cmd/day | $0 |
| 5 | **Vercel** | Hosting + CI/CD + Edge Middleware | 100GB bandwidth | $0 |
| 6 | **GitHub** | Source Code + Actions CI/CD | Unlimited repos | $0 |

### Planned (v5.0)

| # | Layanan | Fungsi | Free Tier | Biaya |
|---|---------|--------|:---------:|:-----:|
| 7 | **Cloudflare** | CDN + WAF + Edge Workers + Rate Limiting | 10K req/day | $0 |
| 8 | **QStash** | Async Workers (PDF, Email, ML) | 500 msg/day | $0 |
| 9 | **Cloudflare R2** | File Backup (S3-compatible) | 10GB storage | $0 |
| 10 | **Playwright** | E2E Testing | Unlimited | $0 |
| 11 | **K6** | Load Testing | Unlimited | $0 |
| 12 | **Docusaurus** | Documentation Site | Unlimited | $0 |
| 13 | **N8N** | Workflow Automation (self-host) | Unlimited | $0 (VPS $20/mo) |
| 14 | **OpenCATS** | ATS Recruitment (self-host) | Unlimited | $0 (VPS) |
| 15 | **Prometheus + Grafana** | Monitoring (self-host) | Unlimited | $0 (VPS) |

### Total Biaya

```
v4.0 (saat ini): $0/bulan (100% free tier)
v5.0 (target):   $0-20/bulan (free tier + optional VPS)

VS Enterprise: $50,000-200,000/tahun
SAVINGS: 99%+
```

---

## 🗺️ ROADMAP v4 → v5

### Phase 1: Wire RPC (Minggu 1)
```
□ Wire 100+ RPC ke frontend pages
□ Priority: Worker pages (leave, overtime, learning, attendance)
□ Priority: Admin pages (payroll, KPI, requests)
□ Test semua halaman di browser
```

### Phase 2: Compliance (Minggu 2)
```
□ ISO 45001: Safety K3 module (incident, risk, JSA, emergency, CAPA)
□ ISO 14001: Environmental module (carbon, waste, audit)
□ ISO 9001: QC module (upgrade existing)
```

### Phase 3: Infrastructure (Minggu 3)
```
□ QStash async workers
□ Offline PWA (IndexedDB + Background Sync)
□ Vercel Edge Middleware
□ Materialized Views refresh cron
□ Fix 9 tabel direct .from() access
```

### Phase 4: Quality (Minggu 4)
```
□ npm audit + fix vulnerabilities
□ Unit tests (Vitest)
□ E2E smoke tests (Playwright)
□ Manager Dashboard custom
□ Worker Navigation complete
```

### Phase 5: v5 Launch (Minggu 5)
```
□ Cloudflare CDN + WAF setup
□ Cloudflare R2 backup
□ Docusaurus documentation
□ K6 load testing
□ Final audit + deploy
```

---

## 📊 PROGRESS TRACKER

| Phase | Target | Status | Progress |
|-------|--------|:------:|:--------:|
| Phase 1: Wire RPC | 100+ RPC | 🔲 | 0% |
| Phase 2: Compliance | ISO 45001 + 14001 | 🔲 | 0% |
| Phase 3: Infrastructure | QStash + PWA + Edge | 🔲 | 0% |
| Phase 4: Quality | Testing + Docs | 🔲 | 0% |
| Phase 5: v5 Launch | Cloudflare + Final | 🔲 | 0% |

---

**v4.0 → v5.0 Target: 4-5 minggu full-time development**
**Current: 60% complete → Target: 85% complete (enterprise ready)**
