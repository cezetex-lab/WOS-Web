# 📊 DATA STRATEGY — insightWOS
**Optimasi Data untuk Free Tier + Performa**

---

## 🎯 FREE TIER BUDGET

| Resource | Limit | Current Usage | Remaining |
|----------|-------|---------------|-----------|
| Database Storage | 500 MB | ~27 MB | **473 MB (94.6%)** ✅ |
| API Requests | Unlimited | - | ✅ |
| Edge Functions | 500K/month | ~10K | 490K ✅ |
| Auth MAU | 50,000 | 2,000 | 48,000 ✅ |
| Realtime | 200 connections | ~10 | 190 ✅ |

---

## ⏱️ DATA FRESHNESS CLASSIFICATION

### 🔴 INSTANT (Real-time, < 1 detik)
| Data | Table | Refresh | RPC |
|------|-------|---------|-----|
| Login/Session | `session_tokens` | On login | `login_worker` |
| Task Status | `hr_tasks` | On change | `update_task_status` |
| Request Submit | `hr_requests` | On submit | `submit_request` |
| Approval | `approval_instances` | On approve | `process_request` |
| Idea Vote | `hr_voice` | On vote | `vote_idea` |
| Shift Swap | `hr_shift_swaps` | On request | `request_shift_swap` |
| Push Subscribe | `push_subscriptions` | On subscribe | POST endpoint |

### 🟡 HOURLY (Setiap jam)
| Data | Table | Refresh | RPC |
|------|-------|---------|-----|
| Attendance Summary | `hr_attendance` | Setiap jam | `get_worker_attendance` |
| KPI Live Score | `hr_performance` | Setiap jam | `get_worker_status` |
| Early Warning | `hr_ai_tasks` | Setiap jam | `get_early_warning` |
| Anomaly Detection | `hr_ai_tasks` | Setiap jam | `get_anomaly_sentinel` |
| Online Users | `session_tokens` | Setiap jam | Direct query |

### 🟢 DAILY (Setiap hari)
| Data | Table | Refresh | RPC |
|------|-------|---------|-----|
| Payroll Calc | `hr_payroll` | Akhir bulan | `get_worker_payroll` |
| KPI Calc Log | `hr_kpi_calc_log` | Akhir bulan | `get_kpi_calc_log` |
| Engagement Score | `hr_engagement` | Mingguan | `get_worker_engagement` |
| Flight Risk | Direct query | Harian | `get_flight_risk_list` |
| Turnover Prediction | Direct query | Harian | `get_turnover_prediction` |
| Budget Spend | `team_budgets` | Harian | `admin_get_budget` |

### 🔵 WEEKLY (Setiap minggu)
| Data | Table | Refresh | RPC |
|------|-------|---------|-----|
| Performance Trend | `hr_performance` | Mingguan | `get_continuous_perf_team` |
| Learning Progress | `hr_learning` | Mingguan | `get_worker_learning` |
| Certification Status | `certifications` | Bulanan | Direct query |
| Asset Assignment | `asset_assignments` | On change | `checkout_asset` |

### ⚪ STATIC (Jarang berubah)
| Data | Table | Refresh | RPC |
|------|-------|---------|-----|
| Business Units | `business_units` | Sekali | `login_worker` |
| KPI Config | `hr_kpi_config` | Per quarter | `get_kpi_config_all` |
| Approval Config | `approval_config` | Per quarter | `get_approval_config` |
| Benefit Catalog | `hr_benefit_catalog` | Per tahun | `get_benefit_data` |
| Training Catalog | `hr_training_catalog` | Per quarter | Direct query |

---

## 📈 QUERY OPTIMIZATION RULES

### 1. Use Materialized Views (Pre-computed)
```sql
-- Dashboard summary (refresh every hour)
mv_dashboard_summary

-- KPI by division (refresh daily)
mv_kpi_by_division

-- Attendance summary (refresh hourly)
mv_attendance_summary

-- Payroll summary (refresh monthly)
mv_payroll_summary

-- Turnover stats (refresh weekly)
mv_turnover_stats
```

### 2. Index Strategy
```sql
-- Covering indexes for common queries
CREATE INDEX idx_hr_performance_nrp_period ON hr_performance(nrp, period);
CREATE INDEX idx_hr_attendance_nrp_date ON hr_attendance(nrp, date);
CREATE INDEX idx_hr_requests_status ON hr_requests(status, type);
CREATE INDEX idx_hr_tasks_status ON hr_tasks(status, assignee_nrp);
CREATE INDEX idx_employees_master_nrp ON employees_master(nrp);
CREATE INDEX idx_employees_master_bu ON employees_master(business_unit);
```

### 3. RPC Caching Rules
| RPC Type | Cache TTL | Strategy |
|----------|-----------|----------|
| Dashboard stats | 5 min | Client-side cache |
| Employee list | 10 min | Client-side cache |
| KPI scores | 15 min | Client-side cache |
| Payroll data | 1 hour | Client-side cache |
| Static config | 24 hours | Client-side cache |
| Session/Auth | None | Always fresh |

---

## 🚨 FREE TIER WARNING THRESHOLDS

| Metric | Warning | Critical | Action |
|--------|---------|----------|--------|
| DB Size | 400 MB (80%) | 450 MB (90%) | Archive old data |
| Edge Func | 400K (80%) | 450K (90%) | Optimize calls |
| API Calls | - | - | Unlimited ✅ |
| MAU | 40K (80%) | 45K (90%) | Cleanup sessions |

---

## 🗑️ DATA ARCHIVE STRATEGY

### Auto-archive (> 6 bulan):
```sql
-- Archive old attendance
INSERT INTO hr_attendance_archive 
SELECT * FROM hr_attendance 
WHERE date < CURRENT_DATE - INTERVAL '6 months';

DELETE FROM hr_attendance 
WHERE date < CURRENT_DATE - INTERVAL '6 months';
```

### Auto-delete (> 1 tahun):
```sql
-- Delete old audit logs
DELETE FROM audit_log 
WHERE created_at < CURRENT_DATE - INTERVAL '1 year';

-- Delete old webhook logs
DELETE FROM webhook_logs 
WHERE created_at < CURRENT_DATE - INTERVAL '1 year';
```

---

## 📊 SEED DATA SIZES (Optimized)

| Table | Rows | Size | Notes |
|-------|------|------|-------|
| employees_master | 2,000 | 2 MB | Core data |
| hr_attendance | 2,100 | 0.5 MB | 7 days (not 30) |
| hr_payroll | 4,000 | 1.5 MB | 2 months (not 6) |
| hr_performance | 4,000 | 1 MB | 2 months (not 6) |
| hr_skills | 3,000 | 1 MB | 3 skills per employee |
| hr_tasks | 400 | 0.2 MB | Active tasks |
| hr_benefits | 1,200 | 0.5 MB | Active benefits |
| Other tables | ~3,000 | ~2 MB | Mixed |
| **TOTAL** | **~20,000** | **~9 MB** | **1.8% of 500MB** |

---

## ✅ VERDICT

| Category | Status |
|----------|--------|
| Storage | ✅ 9 MB / 500 MB (1.8%) |
| API | ✅ Unlimited |
| Performance | ✅ Indexed + MV |
| Data Freshness | ✅ Classified by urgency |
| Archive Strategy | ✅ Auto-cleanup ready |
| Free Tier Safe | ✅ **97.2% headroom** |
