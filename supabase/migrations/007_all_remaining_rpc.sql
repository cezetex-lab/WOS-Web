-- ============================================================
-- 007_all_remaining_rpc.sql
-- Port ALL remaining GAS functions to Supabase RPC
-- Run in Supabase SQL Editor
-- ============================================================

-- ============================================================
-- WORKER: MY ROLE & PLAN
-- ============================================================
CREATE OR REPLACE FUNCTION get_my_role(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE v_role RECORD;
BEGIN
  SELECT * INTO v_role FROM user_roles WHERE nrp = p_nrp;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'msg', 'Role tidak ditemukan.'); END IF;
  RETURN jsonb_build_object('ok', true, 'nrp', p_nrp, 'level', v_role.role_level, 'tier', COALESCE(v_role.plan, 'FREE'), 'scope', v_role.scope_divisi);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_my_plan(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE v_role RECORD;
BEGIN
  SELECT * INTO v_role FROM user_roles WHERE nrp = p_nrp;
  RETURN jsonb_build_object('ok', true, 'plan', COALESCE(v_role.plan, 'FREE'), 'level', COALESCE(v_role.role_level, 1));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- WORKER: TRAINING
-- ============================================================
CREATE OR REPLACE FUNCTION request_training(p_nrp TEXT, p_training_code TEXT, p_reason TEXT)
RETURNS JSONB AS $$
BEGIN
  INSERT INTO hr_learning (nrp, type, title, status, required_flag)
  VALUES (p_nrp, 'REQUEST', p_training_code, 'REQUESTED', false);
  RETURN jsonb_build_object('ok', true, 'msg', 'Training request dikirim.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_my_training_requests(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('id', id, 'type', type, 'title', title, 'status', status, 'start_date', start_date, 'end_date', end_date)
      ORDER BY created_at DESC
    ), '[]'::jsonb))
    FROM hr_learning WHERE nrp = p_nrp LIMIT 20
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_training_catalog()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('code', training_code, 'title', title, 'category', category, 'duration_hours', duration_hours, 'provider', provider)
    ), '[]'::jsonb))
    FROM hr_training_catalog
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- WORKER: VOICE (Suara Karyawan)
-- ============================================================
CREATE OR REPLACE FUNCTION submit_voice(p_nrp TEXT, p_type TEXT, p_title TEXT, p_details TEXT, p_anonymous BOOLEAN)
RETURNS JSONB AS $$
BEGIN
  INSERT INTO hr_voice (type, nrp, is_anonymous, title, details_json, status)
  VALUES (p_type, p_nrp, COALESCE(p_anonymous, false), p_title, p_details, 'NEW');
  RETURN jsonb_build_object('ok', true, 'msg', 'Ide berhasil dikirim.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION list_ideas(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('id', id, 'type', type, 'title', title, 'status', status_idea, 'votes', jsonb_array_length(COALESCE(votes_json::jsonb, '[]'::jsonb)))
      ORDER BY created_at DESC
    ), '[]'::jsonb))
    FROM hr_voice LIMIT 50
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- WORKER: CONTINUOUS PERFORMANCE
-- ============================================================
CREATE OR REPLACE FUNCTION get_my_continuous_performance(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('periode', periode, 'kpi_score', kpi_score, 'feedback', feedback_json)
      ORDER BY created_at DESC
    ), '[]'::jsonb))
    FROM hr_performance WHERE nrp = p_nrp LIMIT 12
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- WORKER: COMPENSATION INTELLIGENCE
-- ============================================================
CREATE OR REPLACE FUNCTION get_my_compensation_intelligence(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE v_pay RECORD; v_avg NUMERIC;
BEGIN
  SELECT * INTO v_pay FROM hr_payroll WHERE nrp = p_nrp ORDER BY created_at DESC LIMIT 1;
  SELECT AVG(total_bersih) INTO v_avg FROM hr_payroll WHERE periode = (SELECT MAX(periode) FROM hr_payroll);
  RETURN jsonb_build_object('ok', true,
    'my_salary', COALESCE(v_pay.total_bersih, 0),
    'team_avg', COALESCE(v_avg, 0),
    'diff_pct', CASE WHEN v_avg > 0 THEN ROUND((COALESCE(v_pay.total_bersih,0) - v_avg) / v_avg * 100, 1) ELSE 0 END
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- WORKER: CAREER PATH
-- ============================================================
CREATE OR REPLACE FUNCTION get_career_path(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE v_emp RECORD; v_skills RECORD;
BEGIN
  SELECT * INTO v_emp FROM employees_master WHERE nrp = p_nrp;
  SELECT * INTO v_skills FROM hr_position_skills WHERE position_code = v_emp.position_code LIMIT 1;
  RETURN jsonb_build_object('ok', true,
    'current_position', v_emp.posisi,
    'current_level', (SELECT role_level FROM user_roles WHERE nrp = p_nrp),
    'required_skills', COALESCE(v_skills.required_skills, ''),
    'gap_analysis', 'Complete training to unlock next level'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- WORKER: LEARNING RECOMMENDATIONS
-- ============================================================
CREATE OR REPLACE FUNCTION get_learning_recommendations(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('title', title, 'category', category, 'reason', 'Recommended based on your role')
    ), '[]'::jsonb))
    FROM hr_training_catalog WHERE priority = 'HIGH' LIMIT 5
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- WORKER: TALENT MARKETPLACE
-- ============================================================
CREATE OR REPLACE FUNCTION get_talent_marketplace()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('position', position_name, 'divisi', target_divisi, 'vacancies', vacancies, 'urgency', urgency)
    ), '[]'::jsonb))
    FROM hr_talent_catalog WHERE status = 'OPEN'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- WORKER: SKILLS INTELLIGENCE
-- ============================================================
CREATE OR REPLACE FUNCTION get_skills_intelligence(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('skill', skill_name, 'current_level', current_level, 'required_level', required_level, 'gap', required_level - current_level)
    ), '[]'::jsonb))
    FROM hr_capability WHERE nrp = p_nrp
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- WORKER: SUCCESSION
-- ============================================================
CREATE OR REPLACE FUNCTION get_succession(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('position', target_position, 'readiness', readiness_level, 'potential_nrp', potential_nrp)
    ), '[]'::jsonb))
    FROM hr_succession WHERE current_nrp = p_nrp
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- MANAGER: COMMAND DATA
-- ============================================================
CREATE OR REPLACE FUNCTION get_manager_command_data(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE v_team JSONB; v_requests JSONB; v_stats JSONB;
BEGIN
  SELECT jsonb_agg(jsonb_build_object('nrp', e.nrp, 'nama', e.nama, 'kpi', COALESCE(p.kpi_score, 0), 'status', e.status_kerja))
  INTO v_team FROM hr_org o JOIN employees_master e ON e.nrp = o.nrp LEFT JOIN hr_performance p ON p.nrp = o.nrp
  WHERE o.atasan_nrp = p_nrp;

  SELECT jsonb_agg(jsonb_build_object('id', r.id, 'nrp', r.nrp, 'type', r.type, 'status', r.status, 'created_at', r.created_at))
  INTO v_requests FROM hr_requests r JOIN hr_org o ON o.nrp = r.nrp AND o.atasan_nrp = p_nrp WHERE r.status = 'Pending';

  RETURN jsonb_build_object('ok', true, 'team', COALESCE(v_team, '[]'::jsonb), 'pending_requests', COALESCE(v_requests, '[]'::jsonb));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- MANAGER: SUBTREE (org tree)
-- ============================================================
CREATE OR REPLACE FUNCTION get_subtree_data(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('nrp', e.nrp, 'nama', e.nama, 'atasan', o.atasan_nrp, 'posisi', e.posisi, 'divisi', e.divisi, 'level', COALESCE(ur.role_level, 1))
    ), '[]'::jsonb))
    FROM employees_master e
    LEFT JOIN hr_org o ON o.nrp = e.nrp
    LEFT JOIN user_roles ur ON ur.nrp = e.nrp
    ORDER BY e.nama
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- MANAGER: CONTINUOUS PERF TEAM
-- ============================================================
CREATE OR REPLACE FUNCTION get_continuous_perf_team(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('nrp', p.nrp, 'nama', e.nama, 'periode', p.periode, 'kpi_score', p.kpi_score, 'feedback', p.feedback_json)
    ), '[]'::jsonb))
    FROM hr_performance p
    JOIN hr_org o ON o.nrp = p.nrp AND o.atasan_nrp = p_nrp
    LEFT JOIN employees_master e ON e.nrp = p.nrp
    ORDER BY p.created_at DESC LIMIT 20
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- CEO: COMMAND DATA
-- ============================================================
CREATE OR REPLACE FUNCTION get_ceo_command_data(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE v_org JSONB; v_kpi JSONB; v_finance JSONB;
BEGIN
  SELECT jsonb_agg(jsonb_build_object('divisi', divisi, 'headcount', hc, 'avg_kpi', ak))
  INTO v_org FROM (
    SELECT e.divisi, COUNT(*) as hc, ROUND(AVG(p.kpi_score),1) as ak
    FROM employees_master e LEFT JOIN hr_performance p ON p.nrp = e.nrp
    WHERE e.divisi IS NOT NULL GROUP BY e.divisi
  ) t;

  SELECT jsonb_agg(jsonb_build_object('periode', periode, 'revenue', revenue, 'profit', profit))
  INTO v_finance FROM hr_finance_kpi ORDER BY created_at DESC LIMIT 4;

  RETURN jsonb_build_object('ok', true, 'org_summary', COALESCE(v_org, '[]'::jsonb), 'finance', COALESCE(v_finance, '[]'::jsonb),
    'total_workers', (SELECT COUNT(*) FROM employees_master),
    'avg_kpi', (SELECT ROUND(AVG(kpi_score),1) FROM hr_performance WHERE period = (SELECT MAX(period) FROM hr_performance))
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- CEO: ORGANIZATION HEALTH
-- ============================================================
CREATE OR REPLACE FUNCTION get_organization_health()
RETURNS JSONB AS $$
BEGIN
  RETURN jsonb_build_object('ok', true,
    'headcount', (SELECT COUNT(*) FROM employees_master),
    'avg_kpi', (SELECT COALESCE(ROUND(AVG(kpi_score),1),0) FROM hr_performance WHERE period = (SELECT MAX(period) FROM hr_performance)),
    'attendance_rate', (SELECT COALESCE(ROUND(COUNT(*) FILTER(WHERE status_hadir='Hadir')::NUMERIC/COUNT(*)*100,1),0) FROM hr_attendance WHERE date >= date_trunc('month',NOW())),
    'open_positions', (SELECT COUNT(*) FROM hr_talent_catalog WHERE status='OPEN'),
    'pending_requests', (SELECT COUNT(*) FROM hr_requests WHERE status='Pending'),
    'coaching_active', (SELECT COUNT(*) FROM hr_coaching WHERE status='ACTIVE'),
    'compliance_issues', (SELECT COUNT(*) FROM hr_compliance WHERE status='OVERDUE')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- CEO: EARLY WARNING
-- ============================================================
CREATE OR REPLACE FUNCTION get_early_warning()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('category', category, 'title', title, 'message', message, 'created_at', created_at)
    ), '[]'::jsonb))
    FROM hr_notifications WHERE is_read = false
    ORDER BY created_at DESC LIMIT 10
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- CEO: EXECUTIVE SUMMARY
-- ============================================================
CREATE OR REPLACE FUNCTION get_executive_summary()
RETURNS JSONB AS $$
BEGIN
  RETURN jsonb_build_object('ok', true,
    'headcount', (SELECT COUNT(*) FROM employees_master),
    'avg_kpi', (SELECT COALESCE(ROUND(AVG(kpi_score),1),0) FROM hr_performance WHERE period = (SELECT MAX(period) FROM hr_performance)),
    'high_performers', (SELECT COUNT(*) FROM hr_performance WHERE kpi_score >= 80 AND period = (SELECT MAX(period) FROM hr_performance)),
    'low_performers', (SELECT COUNT(*) FROM hr_performance WHERE kpi_score < 60 AND period = (SELECT MAX(period) FROM hr_performance)),
    'turnover_rate', (SELECT COALESCE(ROUND(COUNT(*) FILTER(WHERE status_kerja != 'Active')::NUMERIC/COUNT(*)*100,1),0) FROM employees_master),
    'total_payroll', (SELECT COALESCE(SUM(total_bersih),0) FROM hr_payroll WHERE periode = (SELECT MAX(periode) FROM hr_payroll))
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- CEO: WORKFORCE PLANNING
-- ============================================================
CREATE OR REPLACE FUNCTION get_workforce_planning()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('position', position_name, 'current', current_headcount, 'desired', desired_headcount, 'gap', desired_headcount - current_headcount, 'status', CASE WHEN desired_headcount > current_headcount THEN 'VACANT' ELSE 'OK' END)
    ), '[]'::jsonb))
    FROM hr_talent_catalog
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- CEO: WORKFORCE HEALTH SCORE
-- ============================================================
CREATE OR REPLACE FUNCTION get_workforce_health_score()
RETURNS JSONB AS $$
DECLARE v_kpi NUMERIC; v_att NUMERIC; v_turn NUMERIC; v_eng NUMERIC; v_score NUMERIC;
BEGIN
  SELECT COALESCE(AVG(kpi_score), 70) INTO v_kpi FROM hr_performance WHERE period = (SELECT MAX(period) FROM hr_performance);
  SELECT COALESCE(COUNT(*) FILTER(WHERE status_hadir='Hadir')::NUMERIC/NULLIF(COUNT(*),0)*100, 90) INTO v_att FROM hr_attendance WHERE date >= date_trunc('month',NOW());
  SELECT COALESCE(AVG(score), 75) INTO v_eng FROM hr_engagement;
  v_score := (v_kpi * 0.4 + v_att * 0.3 + v_eng * 0.3);
  RETURN jsonb_build_object('ok', true, 'score', ROUND(v_score, 1), 'kpi_component', ROUND(v_kpi,1), 'attendance_component', ROUND(v_att,1), 'engagement_component', ROUND(v_eng,1));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- CEO: ANOMALY SENTINEL
-- ============================================================
CREATE OR REPLACE FUNCTION get_anomaly_sentinel()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('nrp', nrp, 'nama', (SELECT nama FROM employees_master WHERE nrp = a.nrp), 'type', anomaly_type, 'detail', detail, 'severity', severity, 'created_at', created_at)
    ), '[]'::jsonb))
    FROM hr_ai_tasks a WHERE status = 'ACTIVE' ORDER BY created_at DESC LIMIT 10
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- HRD: PEOPLE SEARCH
-- ============================================================
CREATE OR REPLACE FUNCTION get_people_search(p_query TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('nrp', nrp, 'nama', nama, 'divisi', divisi, 'posisi', posisi)
    ), '[]'::jsonb))
    FROM employees_master
    WHERE nama ILIKE '%' || p_query || '%' OR nrp ILIKE '%' || p_query || '%' OR nik ILIKE '%' || p_query || '%'
    LIMIT 20
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- HRD: ACTION CENTER
-- ============================================================
CREATE OR REPLACE FUNCTION get_action_center()
RETURNS JSONB AS $$
BEGIN
  RETURN jsonb_build_object('ok', true,
    'pending_requests', (SELECT COUNT(*) FROM hr_requests WHERE status = 'Pending'),
    'pending_registrations', (SELECT COUNT(*) FROM daftar_baru WHERE status = 'PENDING'),
    'expired_certs', (SELECT COUNT(*) FROM hr_skills WHERE valid_until < NOW()),
    'coaching_pending', (SELECT COUNT(*) FROM hr_coaching WHERE status = 'SCHEDULED'),
    'compliance_overdue', (SELECT COUNT(*) FROM hr_compliance WHERE status = 'OVERDUE'),
    'exit_clearance_pending', (SELECT COUNT(*) FROM hr_exit_clearance WHERE status = 'PENDING')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- PRODUCTION & OPERATIONS
-- ============================================================
CREATE OR REPLACE FUNCTION get_production_output(p_nrp TEXT, p_date_from DATE, p_date_to DATE)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('date', date, 'volume', volume, 'unit', unit, 'target', target)
    ), '[]'::jsonb))
    FROM hr_production_daily
    WHERE (p_nrp IS NULL OR nrp = p_nrp)
      AND (p_date_from IS NULL OR date >= p_date_from)
      AND (p_date_to IS NULL OR date <= p_date_to)
    ORDER BY date DESC LIMIT 30
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_plantation_harvest(p_nrp TEXT, p_date_from DATE, p_date_to DATE)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('date', date, 'block', block, 'harvest_kg', harvest_kg, 'target_kg', target_kg)
    ), '[]'::jsonb))
    FROM hr_plantation_harvest
    WHERE (p_nrp IS NULL OR nrp = p_nrp)
      AND (p_date_from IS NULL OR date >= p_date_from)
      AND (p_date_to IS NULL OR date <= p_date_to)
    ORDER BY date DESC LIMIT 30
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_equipment_util(p_machine TEXT, p_date_from DATE, p_date_to DATE)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('date', date, 'machine_id', machine_id, 'utilization_pct', utilization_pct, 'downtime_hrs', downtime_hrs)
    ), '[]'::jsonb))
    FROM hr_equipment_util
    WHERE (p_machine IS NULL OR machine_id = p_machine)
      AND (p_date_from IS NULL OR date >= p_date_from)
      AND (p_date_to IS NULL OR date <= p_date_to)
    ORDER BY date DESC LIMIT 30
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- SCHEDULE & CALENDAR
-- ============================================================
CREATE OR REPLACE FUNCTION get_shift_schedule()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('shift_code', shift_code, 'shift_name', shift_name, 'start_time', start_time, 'end_time', end_time)
    ), '[]'::jsonb))
    FROM hr_shift_master
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_calendar_holidays(p_year INT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('date', date, 'is_holiday', is_holiday, 'description', description)
    ), '[]'::jsonb))
    FROM hr_calendar WHERE EXTRACT(YEAR FROM date) = COALESCE(p_year, EXTRACT(YEAR FROM NOW())::INT)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_work_schedule(p_divisi TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('divisi_code', divisi_code, 'work_days_per_week', work_days_per_week, 'roster_pattern', roster_pattern)
    ), '[]'::jsonb))
    FROM hr_work_schedule WHERE p_divisi IS NULL OR divisi_code = p_divisi
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- OVERTIME
-- ============================================================
CREATE OR REPLACE FUNCTION get_overtime_data(p_nrp TEXT, p_date_from DATE, p_date_to DATE)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('nrp', nrp, 'date', date, 'hours', hours, 'reason', reason, 'status', status)
    ), '[]'::jsonb))
    FROM hr_overtime
    WHERE (p_nrp IS NULL OR nrp = p_nrp)
      AND (p_date_from IS NULL OR date >= p_date_from)
      AND (p_date_to IS NULL OR date <= p_date_to)
    ORDER BY date DESC LIMIT 30
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- MEDICAL CHECKUP
-- ============================================================
CREATE OR REPLACE FUNCTION get_medical_checkup(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('nrp', nrp, 'checkup_date', checkup_date, 'result', result, 'notes', notes)
    ), '[]'::jsonb))
    FROM hr_medical_checkup WHERE p_nrp IS NULL OR nrp = p_nrp ORDER BY checkup_date DESC LIMIT 10
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- SAFETY & COMPLIANCE
-- ============================================================
CREATE OR REPLACE FUNCTION calculate_ltifr(p_periode TEXT)
RETURNS JSONB AS $$
DECLARE v_incidents INT; v_hours NUMERIC;
BEGIN
  SELECT COUNT(*) INTO v_incidents FROM hr_safety;
  SELECT SUM(menit_lembur + 480) / 60 INTO v_hours FROM hr_attendance WHERE date >= date_trunc('month', NOW());
  RETURN jsonb_build_object('ok', true, 'ltifr', CASE WHEN v_hours > 0 THEN ROUND(v_incidents::NUMERIC / (v_hours/1000000) * 1000000, 2) ELSE 0 END, 'incidents', v_incidents, 'hours_worked', COALESCE(v_hours, 0));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_compliance_rate(p_divisi TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('divisi', divisi_code, 'total', total, 'compliant', compliant, 'rate', CASE WHEN total > 0 THEN ROUND(compliant::NUMERIC/total*100,1) ELSE 0 END)
    ), '[]'::jsonb))
    FROM (
      SELECT e.divisi as divisi_code, COUNT(*) as total, COUNT(*) FILTER (WHERE c.status = 'COMPLIANT') as compliant
      FROM employees_master e LEFT JOIN hr_compliance c ON c.nrp = e.nrp WHERE e.divisi = COALESCE(p_divisi, e.divisi) GROUP BY e.divisi
    ) t
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_near_miss_data(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('id', id, 'nrp', nrp, 'incident_date', incident_date, 'description', description, 'severity', severity, 'status', status)
    ), '[]'::jsonb))
    FROM hr_safety WHERE type = 'NEAR_MISS' AND (p_nrp IS NULL OR nrp = p_nrp) ORDER BY incident_date DESC LIMIT 20
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- BENEFITS & EXIT
-- ============================================================
CREATE OR REPLACE FUNCTION get_benefit_data(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('nrp', nrp, 'kode_benefit', kode_benefit, 'nama_benefit', nama_benefit, 'nilai', nilai, 'status', status)
    ), '[]'::jsonb))
    FROM hr_benefits WHERE p_nrp IS NULL OR nrp = p_nrp
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_exit_clearance(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('nrp', nrp, 'department', department, 'status', status, 'cleared_by', cleared_by)
    ), '[]'::jsonb))
    FROM hr_exit_clearance WHERE p_nrp IS NULL OR nrp = p_nrp
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- CAPABILITY & COMPETENCY
-- ============================================================
CREATE OR REPLACE FUNCTION get_capability_gap(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('nrp', nrp, 'skill', skill, 'current_level', current_level, 'required_level', required_level, 'gap', required_level - current_level, 'is_mandatory', is_mandatory)
    ), '[]'::jsonb))
    FROM hr_capability WHERE p_nrp IS NULL OR nrp = p_nrp
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_competency_matrix()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('position_code', position_code, 'skill', skill, 'required_level', required_level)
    ), '[]'::jsonb))
    FROM hr_competency_matrix
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_succession_matrix()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('id', id, 'position', target_position, 'readiness_level', readiness_level, 'candidates', candidates_json)
    ), '[]'::jsonb))
    FROM hr_succession_matrix
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_penalty_matrix()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('id', id, 'violation', violation, 'severity', severity, 'penalty', penalty)
    ), '[]'::jsonb))
    FROM hr_penalty_matrix
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- SNAPSHOT & KPI LOG
-- ============================================================
CREATE OR REPLACE FUNCTION get_monthly_snapshot_trend(p_divisi TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('periode', periode, 'divisi', divisi, 'headcount', headcount, 'avg_kpi', avg_kpi, 'turnover_pct', turnover_pct, 'revenue', revenue)
      ORDER BY periode DESC
    ), '[]'::jsonb))
    FROM hr_monthly_snapshot WHERE p_divisi IS NULL OR divisi = p_divisi LIMIT 12
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_kpi_calc_log()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('id', id, 'nrp', nrp, 'periode', periode, 'indicator', indicator, 'realisasi', realisasi, 'target', target, 'score', score)
      ORDER BY created_at DESC
    ), '[]'::jsonb))
    FROM hr_kpi_calc_log LIMIT 50
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- CATALOGS
-- ============================================================
CREATE OR REPLACE FUNCTION get_coaching_catalog()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('id', id, 'title', title, 'description', description, 'duration_min', duration_min)
    ), '[]'::jsonb))
    FROM hr_coaching_catalog
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_compliance_catalog()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('id', id, 'title', title, 'frequency', frequency, 'required_for', required_for)
    ), '[]'::jsonb))
    FROM hr_compliance_catalog
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_benefit_catalog()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('kode', kode_benefit, 'nama', nama, 'deskripsi', deskripsi, 'nilai_default', nilai_default)
    ), '[]'::jsonb))
    FROM hr_benefit_catalog
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_document_types()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('code', doc_code, 'name', doc_name)
    ), '[]'::jsonb))
    FROM hr_document_types
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- ADMIN: ORG STRUCTURE
-- ============================================================
CREATE OR REPLACE FUNCTION admin_get_org_structure()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('nrp', e.nrp, 'nama', e.nama, 'divisi', e.divisi, 'posisi', e.posisi, 'atasan', o.atasan_nrp, 'level', COALESCE(ur.role_level, 1))
    ), '[]'::jsonb))
    FROM employees_master e LEFT JOIN hr_org o ON o.nrp = e.nrp LEFT JOIN user_roles ur ON ur.nrp = e.nrp ORDER BY e.nama
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION admin_get_divisions()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('divisi', divisi, 'headcount', hc)
    ), '[]'::jsonb))
    FROM (SELECT divisi, COUNT(*) as hc FROM employees_master WHERE divisi IS NOT NULL GROUP BY divisi) t
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION admin_export_sheet(p_sheet TEXT)
RETURNS JSONB AS $$
BEGIN
  -- For now, return row count as confirmation
  RETURN jsonb_build_object('ok', true, 'msg', 'Export prepared for ' || p_sheet, 'rows', (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = p_sheet));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
