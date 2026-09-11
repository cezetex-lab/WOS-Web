# Disaster Recovery Plan — insightWOS V6

## 1. Backup Strategy

### Supabase Automated Backups
- **Daily backups**: Automatic (Supabase Pro/Team plan)
- **Point-in-time recovery**: Available on Pro plan (WAL archival)
- **Backup retention**: 7 days (Free) / 30 days (Pro) / configurable (Team)

### Manual Backup (if needed)
```bash
# Full database backup
pg_dump $DATABASE_URL > backup_$(date +%Y%m%d_%H%M%S).sql

# Schema only
pg_dump --schema-only $DATABASE_URL > schema_$(date +%Y%m%d).sql

# Specific tables only
pg_dump $DATABASE_URL -t employees_master -t hr_payroll -t user_roles > core_$(date +%Y%m%d).sql
```

### Backup Schedule
| Data | Frequency | Retention | Method |
|------|-----------|-----------|--------|
| Full database | Daily | 30 days | Supabase automated |
| Core tables | Weekly | 90 days | pg_dump + S3 |
| Migration files | On change | Permanent | Git |

## 2. Recovery Procedures

### Scenario A: Data Corruption (Single Table)
```sql
-- 1. Identify affected table and time range
SELECT * FROM audit_log WHERE action LIKE '%hr_payroll%' ORDER BY created_at DESC LIMIT 10;

-- 2. Restore from backup (Supabase Dashboard → Database → Backups)
-- 3. Re-run affected migrations if needed
-- 4. Verify data integrity
```

### Scenario B: Accidental Mass Delete
```sql
-- 1. Check audit_log for the delete action
SELECT * FROM audit_log WHERE action = 'DELETE hr_payroll' ORDER BY created_at DESC;

-- 2. If within retention, restore from Supabase point-in-time recovery
-- 3. If not, reconstruct from audit_log diffs (if available)
```

### Scenario C: Full Database Restore
```bash
# 1. Create new Supabase project
# 2. Run all migrations in order:
for f in supabase/migrations/*.sql; do
  psql $NEW_DATABASE_URL -f "$f"
done
# 3. Restore data from latest backup
psql $NEW_DATABASE_URL < latest_backup.sql
# 4. Update frontend environment variables
# 5. Verify all RPCs work
```

### Scenario D: Security Breach
```sql
-- 1. Force logout all sessions
UPDATE session_tokens SET is_used = true;

-- 2. Reset all passwords (if needed)
-- 3. Review audit_log for unauthorized access
SELECT * FROM audit_log WHERE action LIKE '%UNAUTHORIZED%' OR result = 'DENIED';

-- 4. Check for data exfiltration
SELECT * FROM audit_log WHERE action LIKE '%export%' OR action LIKE '%DELETE%';

-- 5. Rotate API keys
UPDATE api_keys SET is_active = false;
```

## 3. RTO/RPO Targets

| Metric | Target | Notes |
|--------|:------:|-------|
| RPO (Recovery Point Objective) | 24 hours | Supabase daily backup |
| RTO (Recovery Time Objective) | 4 hours | Full restore from backup |
| Data Loss Window | < 24 hours | WAL archival on Pro plan |

## 4. Monitoring & Alerts

| Check | Frequency | Action if Failed |
|-------|-----------|-----------------|
| Backup status | Daily | Check Supabase dashboard |
| RLS policies active | Weekly | Run smoke test #3 |
| Audit log growing | Weekly | Run cleanup_expired_data() |
| Failed login spikes | Daily | Check login_attempts table |
| Session count anomaly | Daily | Check session_tokens count |

## 5. Testing Schedule

| Test | Frequency | Procedure |
|------|-----------|-----------|
| Smoke test (28 tests) | After each migration | Run smoke_test_backend.sql |
| Backup restore test | Monthly | Restore to staging, verify data |
| DR drill | Quarterly | Simulate full restore |
| Security audit | Bi-annually | External audit review |

## 6. Contact & Escalation

| Level | Response | Action |
|:-----:|----------|--------|
| P1 (Critical) | 1 hour | Full system down, data breach |
| P2 (High) | 4 hours | Major feature broken, data loss |
| P3 (Medium) | 24 hours | Minor bug, performance issue |
| P4 (Low) | 1 week | Enhancement, documentation |

---

*Last updated: September 5, 2026*
