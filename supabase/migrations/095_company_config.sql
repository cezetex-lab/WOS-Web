-- 095: Company Configuration Table
-- Semua konstanta bisnis bisa di-adjust per perusahaan dari Owner Dashboard

-- 1. Config categories
CREATE TABLE IF NOT EXISTS config_categories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  icon TEXT,
  sort_order INT DEFAULT 0
);

INSERT INTO config_categories (id, name, description, icon, sort_order) VALUES
  ('kpi', 'KPI & Performance', 'Threshold, bobot, band nilai', '📊', 1),
  ('salary', 'Gaji & Compensation', 'Salary bands, tunjangan, formula', '💰', 2),
  ('attendance', 'Absensi & Shift', 'Jam kerja, grace period, shift', '⏰', 3),
  ('leave', 'Cuti & Benefit', 'Kuota cuti, jenis cuti, benefit', '📅', 4),
  ('security', 'Keamanan', 'Lockout, OTP, password policy', '🔒', 5),
  ('approval', 'Approval Workflow', 'Chain approval, level', '✅', 6),
  ('industry', 'Industri', 'Status, threshold spesifik industri', '🏭', 7),
  ('scoring', 'Scoring & Formula', 'Bobot penilaian, rumus', '🧮', 8),
  ('display', 'Tampilan & Label', 'Label, warna, threshold UI', '🎨', 9),
  ('currency', 'Mata Uang & Rate', 'Exchange rate, format', '💱', 10)
ON CONFLICT (id) DO NOTHING;

-- 2. Main config table
CREATE TABLE IF NOT EXISTS company_config (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
  category_id TEXT NOT NULL REFERENCES config_categories(id) ON DELETE CASCADE,
  config_key TEXT NOT NULL,
  config_value JSONB NOT NULL,
  data_type TEXT NOT NULL CHECK (data_type IN ('number','string','boolean','json','array')),
  label TEXT NOT NULL,
  description TEXT,
  min_value NUMERIC,
  max_value NUMERIC,
  options JSONB,
  is_system BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(category_id, config_key)
);

-- 4. Seed: KPI & Performance
INSERT INTO company_config (category_id, config_key, config_value, data_type, label, description, min_value, max_value) VALUES
  ('kpi', 'kpi_high_threshold', '{"value": 80}', 'number', 'KPI High Threshold', 'KPI score minimum untuk kategori High Performer', 50, 100),
  ('kpi', 'kpi_medium_threshold', '{"value": 60}', 'number', 'KPI Medium Threshold', 'KPI score minimum untuk kategori Medium', 30, 100),
  ('kpi', 'kpi_low_threshold', '{"value": 40}', 'number', 'KPI Low Threshold', 'KPI score minimum untuk kategori Low', 0, 100),
  ('kpi', 'flight_risk_kpi_threshold', '{"value": 70}', 'number', 'Flight Risk KPI', 'KPI di bawah ini = flight risk', 30, 100),
  ('kpi', 'flight_risk_late_threshold', '{"value": 5}', 'number', 'Flight Risk Late Count', 'Jumlah telat sebelum flight risk', 1, 30),
  ('kpi', 'badge_gold', '{"value": 85}', 'number', 'Badge Gold', 'KPI minimum untuk badge Gold', 50, 100),
  ('kpi', 'badge_silver', '{"value": 75}', 'number', 'Badge Silver', 'KPI minimum untuk badge Silver', 50, 100),
  ('kpi', 'badge_bronze', '{"value": 60}', 'number', 'Badge Bronze', 'KPI minimum untuk badge Bronze', 0, 100),
  ('kpi', 'nps_promoter', '{"value": 9}', 'number', 'NPS Promoter', 'NPS score minimum untuk Promoter', 0, 10),
  ('kpi', 'nps_detractor', '{"value": 6}', 'number', 'NPS Detractor', 'NPS score maksimum untuk Detractor', 0, 10)
ON CONFLICT (category_id, config_key) DO NOTHING;

-- 5. Seed: Performance weights
INSERT INTO company_config (category_id, config_key, config_value, data_type, label, description, min_value, max_value) VALUES
  ('scoring', 'performance_weights', '{"kpi": 0.4, "attendance": 0.3, "productivity": 0.2, "attitude": 0.05, "initiative": 0.05}', 'json', 'Performance Weights', 'Bobot komponen penilaian kinerja (total = 1.0)', NULL, NULL),
  ('scoring', 'health_score_defaults', '{"kpi": 70, "attendance": 90, "engagement": 75}', 'json', 'Health Score Defaults', 'Default values saat tidak ada data', NULL, NULL),
  ('scoring', 'flight_risk_weights', '{"kpi": 0.3, "lateness": 0.4, "sp": 0.3}', 'json', 'Flight Risk Weights', 'Bobot komponen flight risk score', NULL, NULL),
  ('scoring', 'engagement_highly_engaged', '{"value": 80}', 'number', 'Highly Engaged Threshold', 'Score minimum untuk Highly Engaged', 50, 100),
  ('scoring', 'engagement_engaged', '{"value": 60}', 'number', 'Engaged Threshold', 'Score minimum untuk Engaged', 0, 100),
  ('scoring', 'review360_green', '{"value": 70}', 'number', 'Review 360 Green', 'Score minimum untuk warna hijau', 0, 100),
  ('scoring', 'review360_yellow', '{"value": 50}', 'number', 'Review 360 Yellow', 'Score minimum untuk warna kuning', 0, 100),
  ('scoring', 'turnover_risk_red', '{"value": 70}', 'number', 'Turnover Risk Red', 'Score di atas ini = risiko tinggi', 0, 100),
  ('scoring', 'turnover_risk_yellow', '{"value": 40}', 'number', 'Turnover Risk Yellow', 'Score di atas ini = risiko sedang', 0, 100),
  ('scoring', 'penalty_matrix', '{"LOW": 1, "MEDIUM": 3, "HIGH": 5, "CRITICAL": 10}', 'json', 'Penalty Matrix', 'Poin penalti per tingkat keparahan', NULL, NULL)
ON CONFLICT (category_id, config_key) DO NOTHING;

-- 6. Seed: Salary & Compensation
INSERT INTO company_config (category_id, config_key, config_value, data_type, label, description, min_value, max_value) VALUES
  ('salary', 'salary_bands', '{"L5": 25000000, "L4": 18000000, "L3": 12000000, "L2": 8000000, "L1": 7000000}', 'json', 'Salary Bands per Level', 'Gaji pokok per level (IDR)', NULL, NULL),
  ('salary', 'currency_default', '{"value": "IDR"}', 'string', 'Default Currency', 'Mata uang default', NULL, NULL),
  ('salary', 'exchange_rates', '{"USD": 15800, "SGD": 11800, "MYR": 3600, "AUD": 10200}', 'json', 'Exchange Rates', 'Kurs terhadap IDR', NULL, NULL),
  ('salary', 'overtime_rate_multiplier', '{"value": 1.5}', 'number', 'Overtime Rate Multiplier', 'Pengali upah lembur', 1, 3),
  ('salary', 'holiday_rate_multiplier', '{"value": 2.0}', 'number', 'Holiday Rate Multiplier', 'Pengali upah hari libur', 1, 4)
ON CONFLICT (category_id, config_key) DO NOTHING;

-- 7. Seed: Attendance & Shift
INSERT INTO company_config (category_id, config_key, config_value, data_type, label, description, min_value, max_value) VALUES
  ('attendance', 'work_hours_per_day', '{"value": 480}', 'number', 'Work Hours Per Day', 'Jam kerja standar (menit)', 240, 720),
  ('attendance', 'grace_period_minutes', '{"value": 10}', 'number', 'Grace Period', 'Toleransi keterlambatan (menit)', 0, 60),
  ('attendance', 'work_days_per_week', '{"value": 5}', 'number', 'Work Days Per Week', 'Hari kerja per minggu', 1, 7),
  ('attendance', 'shift_types', '{"value": ["PAGI","SORE","MALAM"]}', 'array', 'Shift Types', 'Jenis shift yang tersedia', NULL, NULL),
  ('attendance', 'attendance_statuses', '{"value": ["Hadir","Telat","Izin","Sakit","Alpha","Cuti","WFH","Dinas Luar"]}', 'array', 'Attendance Statuses', 'Status kehadiran yang diizinkan', NULL, NULL)
ON CONFLICT (category_id, config_key) DO NOTHING;

-- 8. Seed: Leave & Benefit
INSERT INTO company_config (category_id, config_key, config_value, data_type, label, description, min_value, max_value) VALUES
  ('leave', 'annual_leave_quota', '{"value": 12}', 'number', 'Annual Leave Quota', 'Kuota cuti tahunan (hari)', 0, 30),
  ('leave', 'sick_leave_quota', '{"value": 12}', 'number', 'Sick Leave Quota', 'Kuota cuti sakit (hari)', 0, 30),
  ('leave', 'maternity_leave_quota', '{"value": 90}', 'number', 'Maternity Leave Quota', 'Kuota cuti melahirkan (hari)', 0, 180),
  ('leave', 'leave_types', '{"value": ["Cuti Tahunan","Cuti Sakit","Cuti Melahirkan","Izin Dinas","Cuti Besar","Cuti Penting"]}', 'array', 'Leave Types', 'Jenis cuti yang tersedia', NULL, NULL),
  ('leave', 'benefit_types', '{"value": ["BPJS-KES","BPJS-TK","THP","JHT","JP","Tunjangan Makan","Tunjangan Transport"]}', 'array', 'Benefit Types', 'Jenis benefit karyawan', NULL, NULL)
ON CONFLICT (category_id, config_key) DO NOTHING;

-- 9. Seed: Security
INSERT INTO company_config (category_id, config_key, config_value, data_type, label, description, min_value, max_value) VALUES
  ('security', 'login_lockout_attempts', '{"value": 4}', 'number', 'Login Lockout Attempts', 'Jumlah gagal login sebelum lockout', 3, 10),
  ('security', 'login_lockout_duration_minutes', '{"value": 15}', 'number', 'Login Lockout Duration', 'Durasi lockout (menit)', 5, 1440),
  ('security', 'otp_lockout_attempts', '{"value": 5}', 'number', 'OTP Lockout Attempts', 'Jumlah gagal OTP sebelum lockout', 3, 10),
  ('security', 'severe_lockout_attempts', '{"value": 10}', 'number', 'Severe Lockout Attempts', 'Jumlah gagal berat sebelum lockout lama', 5, 20),
  ('security', 'severe_lockout_duration_minutes', '{"value": 60}', 'number', 'Severe Lockout Duration', 'Durasi lockout berat (menit)', 15, 1440),
  ('security', 'token_expiry_hours', '{"value": 24}', 'number', 'Token Expiry', 'Masa aktif token (jam)', 1, 168),
  ('security', 'cleanup_old_attempts_days', '{"value": 7}', 'number', 'Cleanup Attempts', 'Hapus data login gagal setelah (hari)', 1, 90)
ON CONFLICT (category_id, config_key) DO NOTHING;

-- 10. Seed: Industry-specific (Mill)
INSERT INTO company_config (category_id, config_key, config_value, data_type, label, description, min_value, max_value) VALUES
  ('industry', 'boiler_statuses', '{"value": ["RUNNING","STANDBY","MAINTENANCE","OFFLINE"]}', 'array', 'Boiler Statuses', 'Status boiler yang diizinkan', NULL, NULL),
  ('industry', 'press_statuses', '{"value": ["RUNNING","STANDBY","MAINTENANCE","OFFLINE"]}', 'array', 'Press Statuses', 'Status press yang diizinkan', NULL, NULL),
  ('industry', 'qc_result_statuses', '{"value": ["PASS","REVIEW","REJECT"]}', 'array', 'QC Result Statuses', 'Status hasil QC', NULL, NULL),
  ('industry', 'product_types', '{"value": ["CPO","PK","PKS","OIL"]}', 'array', 'Product Types', 'Jenis produk sawit', NULL, NULL),
  ('industry', 'packing_statuses', '{"value": ["PACKED","LOADED","DISPATCHED"]}', 'array', 'Packing Statuses', 'Status packing', NULL, NULL),
  ('industry', 'maintenance_types', '{"value": ["PREVENTIVE","PREDICTIVE","CORRECTIVE"]}', 'array', 'Maintenance Types', 'Jenis maintenance', NULL, NULL),
  ('industry', 'maintenance_statuses', '{"value": ["SCHEDULED","IN_PROGRESS","COMPLETED","OVERDUE"]}', 'array', 'Maintenance Statuses', 'Status maintenance', NULL, NULL),
  ('industry', 'breakdown_severities', '{"value": ["LOW","MEDIUM","HIGH","CRITICAL"]}', 'array', 'Breakdown Severities', 'Tingkat keparahan breakdown', NULL, NULL),
  ('industry', 'breakdown_categories', '{"value": ["MECHANICAL","ELECTRICAL","INSTRUMENT","PROCESS","SAFETY"]}', 'array', 'Breakdown Categories', 'Kategori breakdown', NULL, NULL),
  ('industry', 'harvest_quality_grades', '{"value": ["A","B","C"]}', 'array', 'Harvest Quality Grades', 'Grade kualitas panen', NULL, NULL)
ON CONFLICT (category_id, config_key) DO NOTHING;

-- 11. Seed: Display & UI
INSERT INTO company_config (category_id, config_key, config_value, data_type, label, description, min_value, max_value) VALUES
  ('display', 'kpi_color_bands', '{"green": 80, "teal": 60, "orange": 40}', 'json', 'KPI Color Bands', 'Threshold warna KPI di UI', NULL, NULL),
  ('display', 'kpi_labels_id', '{"excellent": "Sangat Baik", "good": "Baik", "needs_improvement": "Cukup", "at_risk": "Perlu Perbaikan"}', 'json', 'KPI Labels (ID)', 'Label KPI Bahasa Indonesia', NULL, NULL),
  ('display', 'kpi_labels_en', '{"excellent": "Excellent", "good": "Good", "needs_improvement": "Needs Improvement", "at_risk": "At Risk"}', 'json', 'KPI Labels (EN)', 'KPI Labels English', NULL, NULL)
ON CONFLICT (category_id, config_key) DO NOTHING;

-- 12. Seed: Approval
INSERT INTO company_config (category_id, config_key, config_value, data_type, label, description, min_value, max_value) VALUES
  ('approval', 'leave_approval_chain', '{"chain": ["atasan_langsung","hr_manager"], "max_level": 2}', 'json', 'Leave Approval Chain', 'Approval chain untuk cuti', NULL, NULL),
  ('approval', 'overtime_approval_chain', '{"chain": ["atasan_langsung"], "max_level": 1}', 'json', 'Overtime Approval Chain', 'Approval chain untuk lembur', NULL, NULL),
  ('approval', 'training_approval_chain', '{"chain": ["atasan_langsung","hr_manager","director"], "max_level": 3}', 'json', 'Training Approval Chain', 'Approval chain untuk training', NULL, NULL)
ON CONFLICT (category_id, config_key) DO NOTHING;

-- 13. Seed: Competency & Succession
INSERT INTO company_config (category_id, config_key, config_value, data_type, label, description, min_value, max_value) VALUES
  ('industry', 'competency_levels', '{"value": ["Staff","Senior","Supervisor","Manager","Director"]}', 'array', 'Competency Levels', 'Level kompetensi', NULL, NULL),
  ('industry', 'succession_readiness', '{"value": [{"label":"Ready Now","months":3},{"label":"Ready Soon","months":6},{"label":"Future Ready","months":12},{"label":"Not Ready","months":99}]}', 'array', 'Succession Readiness', 'Tingkat kesiapan suksesi', NULL, NULL),
  ('industry', 'fatigue_levels', '{"value": [1,2,3,4,5]}', 'array', 'Fatigue Levels', 'Level kelelahan', NULL, NULL),
  ('industry', 'training_types', '{"value": ["SAFETY","TECHNICAL","SOFT_SKILL","LEADERSHIP","COMPLIANCE"]}', 'array', 'Training Types', 'Jenis pelatihan', NULL, NULL),
  ('industry', 'training_priorities', '{"value": ["HIGH","NORMAL","LOW"]}', 'array', 'Training Priorities', 'Prioritas pelatihan', NULL, NULL)
ON CONFLICT (category_id, config_key) DO NOTHING;

-- 13. Index
CREATE INDEX IF NOT EXISTS idx_company_config_category ON company_config(category_id);
CREATE INDEX IF NOT EXISTS idx_company_config_key ON company_config(config_key);

-- 14. RPC: Get all config (grouped by category)
CREATE OR REPLACE FUNCTION get_company_config()
RETURNS JSONB AS $$
DECLARE v_ctx JSONB := get_current_user_context();
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN '[]'::JSONB;
  END IF;
  RETURN (
    SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::JSONB)
    FROM (
      SELECT
        cc.id,
        cc.category_id,
        cc.config_key,
        cc.config_value,
        cc.data_type,
        cc.label,
        cc.description,
        cc.min_value,
        cc.max_value,
        cc.options,
        cc.is_system,
        cc.updated_at,
        cat.name as category_name,
        cat.icon as category_icon
      FROM company_config cc
      JOIN config_categories cat ON cat.id = cc.category_id
      ORDER BY cat.sort_order, cc.config_key
    ) t
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_company_config() TO authenticated;

-- 15. RPC: Update config value
CREATE OR REPLACE FUNCTION update_company_config(p_config_id TEXT, p_value JSONB)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_old JSONB;
  v_key TEXT;
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Hanya Owner.');
  END IF;

  SELECT config_value, config_key INTO v_old, v_key FROM company_config WHERE id = p_config_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Config tidak ditemukan.');
  END IF;

  UPDATE company_config SET config_value = p_value, updated_at = NOW() WHERE id = p_config_id;

  INSERT INTO audit_log_owner (owner_nrp, action, target_type, target_id, old_value, new_value)
  VALUES ('OWNER001', 'UPDATE_CONFIG', 'config', v_key, v_old, p_value);

  RETURN jsonb_build_object('ok', TRUE, 'msg', 'Config updated: ' || v_key);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION update_company_config(TEXT, JSONB) TO authenticated;

-- 16. RPC: Get config by key (for runtime use by other functions)
CREATE OR REPLACE FUNCTION get_config_value(p_category TEXT, p_key TEXT)
RETURNS JSONB AS $$
DECLARE v_result JSONB;
BEGIN
  SELECT config_value INTO v_result FROM company_config
  WHERE category_id = p_category AND config_key = p_key;
  RETURN COALESCE(v_result, 'null'::JSONB);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_config_value(TEXT, TEXT) TO authenticated;

-- 17. RPC: Bulk update (for owner dashboard)
CREATE OR REPLACE FUNCTION update_company_config_bulk(p_updates JSONB)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_item JSONB;
  v_id TEXT;
  v_value JSONB;
  v_count INT := 0;
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Hanya Owner.');
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_updates)
  LOOP
    v_id := v_item->>'id';
    v_value := v_item->>'value';
    UPDATE company_config SET config_value = v_value, updated_at = NOW() WHERE id = v_id;
    IF FOUND THEN v_count := v_count + 1; END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', TRUE, 'msg', v_count || ' configs updated.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION update_company_config_bulk(JSONB) TO authenticated;
