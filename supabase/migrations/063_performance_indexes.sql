-- ============================================================
-- Migration 063: Performance — Missing DB Indexes
-- ============================================================

-- Hot query indexes based on RPC analysis

-- employees_master (most queried table)
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

-- leave_requests
CREATE INDEX IF NOT EXISTS idx_leave_nrp ON leave_requests(nrp);
CREATE INDEX IF NOT EXISTS idx_leave_status ON leave_requests(status);
CREATE INDEX IF NOT EXISTS idx_leave_nrp_status ON leave_requests(nrp, status);

-- overtime_requests
CREATE INDEX IF NOT EXISTS idx_overtime_nrp ON overtime_requests(nrp);
CREATE INDEX IF NOT EXISTS idx_overtime_status ON overtime_requests(status);

-- hr_tasks
CREATE INDEX IF NOT EXISTS idx_tasks_assigned ON hr_tasks(assigned_to);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON hr_tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_priority ON hr_tasks(priority);

-- hr_kpi
CREATE INDEX IF NOT EXISTS idx_kpi_nrp ON hr_kpi(nrp);
CREATE INDEX IF NOT EXISTS idx_kpi_periode ON hr_kpi(periode);

-- hr_attendance
CREATE INDEX IF NOT EXISTS idx_attendance_nrp ON hr_attendance(nrp);
CREATE INDEX IF NOT EXISTS idx_attendance_date ON hr_attendance(attendance_date);
CREATE INDEX IF NOT EXISTS idx_attendance_nrp_date ON hr_attendance(nrp, attendance_date);

-- performance_notes
CREATE INDEX IF NOT EXISTS idx_notes_nrp ON performance_notes(nrp);

-- voice_ideas
CREATE INDEX IF NOT EXISTS idx_ideas_status ON voice_ideas(status);
CREATE INDEX IF NOT EXISTS idx_ideas_created ON voice_ideas(created_at DESC);

-- reviews_360
CREATE INDEX IF NOT EXISTS idx_reviews_reviewee ON reviews_360(reviewee_nrp);
CREATE INDEX IF NOT EXISTS idx_reviews_period ON reviews_360(review_period);

-- onboarding_tasks
CREATE INDEX IF NOT EXISTS idx_onboarding_nrp ON onboarding_tasks(employee_nrp);
CREATE INDEX IF NOT EXISTS idx_onboarding_status ON onboarding_tasks(status);