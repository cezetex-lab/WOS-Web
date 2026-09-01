-- ============================================================
-- Migration 063: Performance — Missing DB Indexes
-- ============================================================

-- employees_master
CREATE INDEX IF NOT EXISTS idx_emp_divisi ON employees_master(divisi);
CREATE INDEX IF NOT EXISTS idx_emp_business_unit ON employees_master(business_unit);
CREATE INDEX IF NOT EXISTS idx_emp_nama ON employees_master(nama);
CREATE INDEX IF NOT EXISTS idx_emp_status ON employees_master(status_kerja);

-- user_roles
CREATE INDEX IF NOT EXISTS idx_user_roles_role ON user_roles(role_level);
CREATE INDEX IF NOT EXISTS idx_user_roles_scope ON user_roles(scope_divisi);

-- hr_payroll
CREATE INDEX IF NOT EXISTS idx_payroll_nrp ON hr_payroll(nrp);
CREATE INDEX IF NOT EXISTS idx_payroll_periode ON hr_payroll(periode);
CREATE INDEX IF NOT EXISTS idx_payroll_nrp_periode ON hr_payroll(nrp, periode);

-- hr_requests (leave/overtime/training requests)
CREATE INDEX IF NOT EXISTS idx_requests_nrp ON hr_requests(nrp);
CREATE INDEX IF NOT EXISTS idx_requests_status ON hr_requests(status);
CREATE INDEX IF NOT EXISTS idx_requests_type ON hr_requests(type);
CREATE INDEX IF NOT EXISTS idx_requests_nrp_status ON hr_requests(nrp, status);

-- hr_overtime
CREATE INDEX IF NOT EXISTS idx_overtime_nrp ON hr_overtime(nrp);
CREATE INDEX IF NOT EXISTS idx_overtime_status ON hr_overtime(status);

-- hr_tasks
CREATE INDEX IF NOT EXISTS idx_tasks_assignee ON hr_tasks(assignee_nrp);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON hr_tasks(status);
-- hr_tasks has no priority column, skip

-- hr_kpi_config
CREATE INDEX IF NOT EXISTS idx_kpi_config_position ON hr_kpi_config(position_code);
CREATE INDEX IF NOT EXISTS idx_kpi_config_periode ON hr_kpi_config(periode);

-- hr_attendance
CREATE INDEX IF NOT EXISTS idx_attendance_nrp ON hr_attendance(nrp);
CREATE INDEX IF NOT EXISTS idx_attendance_date ON hr_attendance(date);
CREATE INDEX IF NOT EXISTS idx_attendance_nrp_date ON hr_attendance(nrp, date);

-- performance_notes
CREATE INDEX IF NOT EXISTS idx_notes_nrp ON performance_notes(nrp);
CREATE INDEX IF NOT EXISTS idx_notes_author ON performance_notes(author_nrp);

-- hr_voice (ideas)
CREATE INDEX IF NOT EXISTS idx_voice_nrp ON hr_voice(nrp);
CREATE INDEX IF NOT EXISTS idx_voice_status ON hr_voice(type);

-- reviews_360
CREATE INDEX IF NOT EXISTS idx_reviews_reviewee ON reviews_360(reviewee_nrp);
CREATE INDEX IF NOT EXISTS idx_reviews_period ON reviews_360(period);
CREATE INDEX IF NOT EXISTS idx_reviews_status ON reviews_360(status);

-- onboarding_tasks
CREATE INDEX IF NOT EXISTS idx_onboarding_nrp ON onboarding_tasks(nrp);
CREATE INDEX IF NOT EXISTS idx_onboarding_status ON onboarding_tasks(status);

-- hr_leave (quota)
CREATE INDEX IF NOT EXISTS idx_leave_nrp ON hr_leave(nrp);
CREATE INDEX IF NOT EXISTS idx_leave_tahun ON hr_leave(tahun);