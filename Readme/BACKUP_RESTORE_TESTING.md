# 🔄 BACKUP & RESTORE TESTING PROCEDURES
## INSIGHTWOS — Disaster Recovery Validation
**Created:** September 3, 2026

---

## 1. Backup Schedule

| Backup Type | Frequency | Retention | Storage | Method |
|-------------|-----------|-----------|---------|--------|
| Supabase → GitHub | Daily 02:00 UTC | 30 days | GitHub Actions | pg_dump via supabase-db-url |
| Supabase → Neon | Manual | 7 days | Neon PostgreSQL | pg_dump + psql restore |
| Frontend → Cloudflare | On push | Rolling | Cloudflare Pages | Auto-deploy |
| Local → Git | On commit | Forever | GitHub | git push |

---

## 2. Restore Testing Procedure

### Step 1: Verify Latest Backup

```bash
# Check GitHub Actions latest run
gh run list --workflow=supabase-backup.yml --limit=5

# Verify backup file exists
ls -la backups/
```

### Step 2: Test Restore to Neon (Staging)

```bash
# Restore to Neon cold standby
NEON_URL="postgresql://user:pass@ep-xxx.neon.tech/neondb"
pg_restore -d "$NEON_URL" backups/latest.dump

# Verify table count
psql "$NEON_URL" -c "SELECT count(*) FROM information_schema.tables WHERE table_schema='public';"
```

### Step 3: Validate Data Integrity

```sql
-- Row counts per table
SELECT tablename, n_live_tup FROM pg_stat_user_tables ORDER BY n_live_tup DESC;

-- Check for corruption
SELECT count(*) FROM employees_master;
SELECT count(*) FROM user_roles;
SELECT count(*) FROM module_definitions;
SELECT count(*) FROM business_unit_modules;

-- Verify RPC functions exist
SELECT count(*) FROM information_schema.routines WHERE routine_schema='public';
```

### Step 4: Test Rollback Scenario

```sql
-- Simulate: restore to specific migration state
-- 1. Create backup of current state
pg_dump > pre_rollback_$(date +%Y%m%d).dump

-- 2. Apply reverse migration if needed
-- (manual, depends on what went wrong)

-- 3. Verify data consistency
SELECT count(*) FROM employees_master;
```

---

## 3. Monitoring Checklist

| Item | Check | Frequency |
|------|-------|-----------|
| GitHub Actions runs | `gh run list` | Daily |
| Backup file size | Compare with yesterday | Daily |
| Neon sync status | Connect + query | Weekly |
| Full restore test | Complete restore to staging | Monthly |
| RPO verification | Max data loss window < 24h | Monthly |
| RTO verification | Recovery time < 1 hour | Monthly |

---

## 4. Emergency Contacts & Procedures

### Supabase Down
1. Check status: https://status.supabase.com
2. Switch to Neon standby (if DB issue)
3. Cloudflare Pages still serves frontend

### Vercel Down
1. Check status: https://www.vercel.status.com
2. Switch to Cloudflare Pages: `insightwos.pages.dev`
3. Update DNS if needed

### GitHub Down
1. Local development continues
2. Manual backup via pg_dump
3. Restore when GitHub returns
