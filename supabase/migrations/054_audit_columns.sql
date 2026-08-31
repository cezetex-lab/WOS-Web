-- ============================================================
-- 054_audit_columns.sql — Add audit columns to all HR tables
-- ============================================================
-- Safe: ADD COLUMN IF NOT EXISTS — no data loss
-- ============================================================

-- Core HR tables
DO $$ BEGIN
  ALTER TABLE hr_payroll ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
  ALTER TABLE hr_payroll ADD COLUMN IF NOT EXISTS created_by TEXT;
  ALTER TABLE hr_payroll ADD COLUMN IF NOT EXISTS updated_by TEXT;
EXCEPTION WHEN duplicate_column THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE hr_performance ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
  ALTER TABLE hr_performance ADD COLUMN IF NOT EXISTS created_by TEXT;
  ALTER TABLE hr_performance ADD COLUMN IF NOT EXISTS updated_by TEXT;
EXCEPTION WHEN duplicate_column THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE hr_tasks ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
  ALTER TABLE hr_tasks ADD COLUMN IF NOT EXISTS created_by TEXT;
  ALTER TABLE hr_tasks ADD COLUMN IF NOT EXISTS updated_by TEXT;
EXCEPTION WHEN duplicate_column THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE hr_leave ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
  ALTER TABLE hr_leave ADD COLUMN IF NOT EXISTS created_by TEXT;
  ALTER TABLE hr_leave ADD COLUMN IF NOT EXISTS updated_by TEXT;
EXCEPTION WHEN duplicate_column THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE hr_overtime ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
  ALTER TABLE hr_overtime ADD COLUMN IF NOT EXISTS created_by TEXT;
  ALTER TABLE hr_overtime ADD COLUMN IF NOT EXISTS updated_by TEXT;
EXCEPTION WHEN duplicate_column THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE hr_requests ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
  ALTER TABLE hr_requests ADD COLUMN IF NOT EXISTS created_by TEXT;
  ALTER TABLE hr_requests ADD COLUMN IF NOT EXISTS updated_by TEXT;
EXCEPTION WHEN duplicate_column THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE hr_safety ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
  ALTER TABLE hr_safety ADD COLUMN IF NOT EXISTS created_by TEXT;
  ALTER TABLE hr_safety ADD COLUMN IF NOT EXISTS updated_by TEXT;
EXCEPTION WHEN duplicate_column THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE hr_okrs ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
  ALTER TABLE hr_okrs ADD COLUMN IF NOT EXISTS created_by TEXT;
  ALTER TABLE hr_okrs ADD COLUMN IF NOT EXISTS updated_by TEXT;
EXCEPTION WHEN duplicate_column THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE hr_surveys ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
  ALTER TABLE hr_surveys ADD COLUMN IF NOT EXISTS created_by TEXT;
  ALTER TABLE hr_surveys ADD COLUMN IF NOT EXISTS updated_by TEXT;
EXCEPTION WHEN duplicate_column THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE reviews_360 ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
  ALTER TABLE reviews_360 ADD COLUMN IF NOT EXISTS created_by TEXT;
  ALTER TABLE reviews_360 ADD COLUMN IF NOT EXISTS updated_by TEXT;
EXCEPTION WHEN duplicate_column THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE hr_whistleblower ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
  ALTER TABLE hr_whistleblower ADD COLUMN IF NOT EXISTS created_by TEXT;
  ALTER TABLE hr_whistleblower ADD COLUMN IF NOT EXISTS updated_by TEXT;
EXCEPTION WHEN duplicate_column THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE hr_forum ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
  ALTER TABLE hr_forum ADD COLUMN IF NOT EXISTS created_by TEXT;
  ALTER TABLE hr_forum ADD COLUMN IF NOT EXISTS updated_by TEXT;
EXCEPTION WHEN duplicate_column THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE hr_assets ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
  ALTER TABLE hr_assets ADD COLUMN IF NOT EXISTS created_by TEXT;
  ALTER TABLE hr_assets ADD COLUMN IF NOT EXISTS updated_by TEXT;
EXCEPTION WHEN duplicate_column THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS updated_by TEXT;
EXCEPTION WHEN duplicate_column THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE user_roles ADD COLUMN IF NOT EXISTS created_by TEXT;
  ALTER TABLE user_roles ADD COLUMN IF NOT EXISTS updated_by TEXT;
EXCEPTION WHEN duplicate_column THEN NULL; END $$;

-- Industry tables
DO $$ BEGIN
  ALTER TABLE hr_finance_kpi ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
  ALTER TABLE hr_finance_kpi ADD COLUMN IF NOT EXISTS created_by TEXT;
  ALTER TABLE hr_finance_kpi ADD COLUMN IF NOT EXISTS updated_by TEXT;
EXCEPTION WHEN duplicate_column THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE hr_finance_kpi ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
EXCEPTION WHEN duplicate_column THEN NULL; END $$;

-- Governance tables
DO $$ BEGIN
  ALTER TABLE hr_exit_clearance ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
  ALTER TABLE hr_exit_clearance ADD COLUMN IF NOT EXISTS created_by TEXT;
  ALTER TABLE hr_exit_clearance ADD COLUMN IF NOT EXISTS updated_by TEXT;
EXCEPTION WHEN duplicate_column THEN NULL; END $$;

-- Add indexes for audit queries
CREATE INDEX IF NOT EXISTS idx_hr_payroll_updated ON hr_payroll(updated_at);
CREATE INDEX IF NOT EXISTS idx_hr_performance_updated ON hr_performance(updated_at);
CREATE INDEX IF NOT EXISTS idx_hr_tasks_updated ON hr_tasks(updated_at);
CREATE INDEX IF NOT EXISTS idx_hr_leave_updated ON hr_leave(updated_at);
CREATE INDEX IF NOT EXISTS idx_hr_requests_updated ON hr_requests(updated_at);
CREATE INDEX IF NOT EXISTS idx_hr_safety_updated ON hr_safety(updated_at);

-- Auto-update trigger for updated_at
CREATE OR REPLACE FUNCTION update_audit_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to core tables
DO $$ BEGIN
  CREATE TRIGGER trg_hr_payroll_updated BEFORE UPDATE ON hr_payroll FOR EACH ROW EXECUTE FUNCTION update_audit_timestamp();
  CREATE TRIGGER trg_hr_performance_updated BEFORE UPDATE ON hr_performance FOR EACH ROW EXECUTE FUNCTION update_audit_timestamp();
  CREATE TRIGGER trg_hr_tasks_updated BEFORE UPDATE ON hr_tasks FOR EACH ROW EXECUTE FUNCTION update_audit_timestamp();
  CREATE TRIGGER trg_hr_leave_updated BEFORE UPDATE ON hr_leave FOR EACH ROW EXECUTE FUNCTION update_audit_timestamp();
  CREATE TRIGGER trg_hr_overtime_updated BEFORE UPDATE ON hr_overtime FOR EACH ROW EXECUTE FUNCTION update_audit_timestamp();
  CREATE TRIGGER trg_hr_requests_updated BEFORE UPDATE ON hr_requests FOR EACH ROW EXECUTE FUNCTION update_audit_timestamp();
  CREATE TRIGGER trg_hr_safety_updated BEFORE UPDATE ON hr_safety FOR EACH ROW EXECUTE FUNCTION update_audit_timestamp();
  CREATE TRIGGER trg_hr_okrs_updated BEFORE UPDATE ON hr_okrs FOR EACH ROW EXECUTE FUNCTION update_audit_timestamp();
  CREATE TRIGGER trg_hr_surveys_updated BEFORE UPDATE ON hr_surveys FOR EACH ROW EXECUTE FUNCTION update_audit_timestamp();
  CREATE TRIGGER trg_reviews_360_updated BEFORE UPDATE ON reviews_360 FOR EACH ROW EXECUTE FUNCTION update_audit_timestamp();
  CREATE TRIGGER trg_hr_whistleblower_updated BEFORE UPDATE ON hr_whistleblower FOR EACH ROW EXECUTE FUNCTION update_audit_timestamp();
  CREATE TRIGGER trg_hr_forum_updated BEFORE UPDATE ON hr_forum FOR EACH ROW EXECUTE FUNCTION update_audit_timestamp();
  CREATE TRIGGER trg_hr_assets_updated BEFORE UPDATE ON hr_assets FOR EACH ROW EXECUTE FUNCTION update_audit_timestamp();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Log completion
DO $$ BEGIN
  RAISE NOTICE '✅ 054: Audit columns added to 15 tables + auto-update triggers created';
END $$;
