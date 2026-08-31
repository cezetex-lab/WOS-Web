-- ============================================================
-- 006_wire_all_rpc.sql
-- All missing RPC functions for full frontend wiring
-- Run in Supabase SQL Editor
-- ============================================================

-- ============================================================
-- WORKER: PAYROLL (Slip Gaji)
-- ============================================================
CREATE OR REPLACE FUNCTION get_worker_payroll(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object(
      'ok', true,
      'data', COALESCE(jsonb_agg(
        jsonb_build_object(
          'periode', periode,
          'gaji_pokok', gaji_pokok,
          'tunjangan', tunjangan,
          'potongan', potongan,
          'total_bersih', total_bersih,
          'created_at', created_at
        )
        ORDER BY created_at DESC
      ), '[]'::jsonb)
    )
    FROM hr_payroll
    WHERE nrp = p_nrp
    LIMIT 12
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- WORKER: LEAVE (Cuti)
-- ============================================================
CREATE OR REPLACE FUNCTION get_worker_leave(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE
  v_leave RECORD;
BEGIN
  SELECT * INTO v_leave FROM hr_leave WHERE nrp = p_nrp ORDER BY tahun DESC LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'kuota', 0, 'terpakai', 0, 'sisa', 0);
  END IF;
  RETURN jsonb_build_object(
    'ok', true,
    'kuota', COALESCE(v_leave.kuota_cuti, 12),
    'terpakai', COALESCE(v_leave.cuti_terpakai, 0),
    'sisa', COALESCE(v_leave.kuota_cuti, 12) - COALESCE(v_leave.cuti_terpakai, 0),
    'tahun', v_leave.tahun
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- WORKER: LEARNING (Training)
-- ============================================================
CREATE OR REPLACE FUNCTION get_worker_learning(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object(
      'ok', true,
      'data', COALESCE(jsonb_agg(
        jsonb_build_object(
          'id', id,
          'type', type,
          'title', title,
          'status', status,
          'start_date', start_date,
          'end_date', end_date,
          'expiry_date', expiry_date,
          'required', required_flag
        )
        ORDER BY created_at DESC
      ), '[]'::jsonb)
    )
    FROM hr_learning
    WHERE nrp = p_nrp
    LIMIT 20
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- WORKER: ENGAGEMENT (Skor Engagement)
-- ============================================================
CREATE OR REPLACE FUNCTION get_worker_engagement(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE
  v_eng RECORD;
BEGIN
  SELECT * INTO v_eng FROM hr_engagement WHERE nrp = p_nrp ORDER BY created_at DESC LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'score', 0, 'category', 'N/A');
  END IF;
  RETURN jsonb_build_object(
    'ok', true,
    'score', COALESCE(v_eng.score, 0),
    'category', COALESCE(v_eng.category, 'N/A'),
    'survey_date', v_eng.survey_date
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- WORKER: NOTIFICATIONS (Inbox)
-- ============================================================
CREATE OR REPLACE FUNCTION get_worker_notifications(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object(
      'ok', true,
      'unread', (SELECT COUNT(*) FROM hr_notifications WHERE nrp = p_nrp AND read_flag = false),
      'data', COALESCE(jsonb_agg(
        jsonb_build_object(
          'id', id,
          'category', category,
          'title', title,
          'message', message,
          'priority', priority,
          'read_flag', read_flag,
          'created_at', created_at
        )
        ORDER BY created_at DESC
      ), '[]'::jsonb)
    )
    FROM hr_notifications
    WHERE nrp = p_nrp
    LIMIT 20
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- MANAGER: TEAM DATA
-- ============================================================
CREATE OR REPLACE FUNCTION get_team_data(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object(
      'ok', true,
      'data', COALESCE(jsonb_agg(
        jsonb_build_object(
          'nrp', e.nrp,
          'nama', e.nama,
          'posisi', e.posisi,
          'divisi', e.divisi,
          'kpi_score', COALESCE(p.kpi_score, 0),
          'status_kerja', e.status_kerja
        )
      ), '[]'::jsonb)
    )
    FROM hr_org o
    JOIN employees_master e ON e.nrp = o.nrp
    LEFT JOIN hr_performance p ON p.nrp = o.nrp
    WHERE o.atasan_nrp = p_nrp
    ORDER BY e.nama
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- MANAGER: TEAM REQUESTS (for approval)
-- ============================================================
CREATE OR REPLACE FUNCTION get_team_requests(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object(
      'ok', true,
      'data', COALESCE(jsonb_agg(
        jsonb_build_object(
          'id', r.id,
          'nrp', r.nrp,
          'nama', e.nama,
          'type', r.type,
          'status', r.status,
          'note', r.note,
          'created_at', r.created_at
        )
      ), '[]'::jsonb)
    )
    FROM hr_requests r
    JOIN hr_org o ON o.nrp = r.nrp AND o.atasan_nrp = p_nrp
    LEFT JOIN employees_master e ON e.nrp = r.nrp
    WHERE r.status = 'Pending'
    ORDER BY r.created_at ASC
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- MANAGER: APPROVE/REJECT TEAM REQUEST
-- ============================================================
CREATE OR REPLACE FUNCTION approve_team_request(p_id TEXT, p_status TEXT, p_note TEXT)
RETURNS JSONB AS $$
BEGIN
  UPDATE hr_requests SET status = p_status, note = p_note WHERE id = p_id AND status = 'Pending';
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'msg', 'Request ' || p_status);
  ELSE
    RETURN jsonb_build_object('ok', false, 'msg', 'Request tidak ditemukan.');
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- DASHBOARD: STATS (for manager/CEO overview)
-- ============================================================
CREATE OR REPLACE FUNCTION get_dashboard_stats()
RETURNS JSONB AS $$
DECLARE
  v_total INT;
  v_avg_kpi NUMERIC;
  v_attendance_rate NUMERIC;
  v_pending INT;
  v_high_performers INT;
  v_low_performers INT;
BEGIN
  SELECT COUNT(*) INTO v_total FROM employees_master;
  
  SELECT ROUND(AVG(kpi_score), 1) INTO v_avg_kpi FROM hr_performance 
  WHERE period = (SELECT MAX(period) FROM hr_performance);
  
  SELECT ROUND(
    COUNT(*) FILTER (WHERE status_hadir = 'Hadir')::NUMERIC / 
    NULLIF(COUNT(*), 0) * 100, 1
  ) INTO v_attendance_rate
  FROM hr_attendance
  WHERE date >= date_trunc('month', NOW())
    AND date < date_trunc('month', NOW()) + INTERVAL '1 month';
  
  SELECT COUNT(*) INTO v_pending FROM hr_requests WHERE status = 'Pending';
  
  SELECT COUNT(*) INTO v_high_performers FROM hr_performance 
  WHERE kpi_score >= 80 AND period = (SELECT MAX(period) FROM hr_performance);
  
  SELECT COUNT(*) INTO v_low_performers FROM hr_performance 
  WHERE kpi_score < 60 AND period = (SELECT MAX(period) FROM hr_performance);
  
  RETURN jsonb_build_object(
    'ok', true,
    'total_workers', v_total,
    'avg_kpi', COALESCE(v_avg_kpi, 0),
    'attendance_rate', COALESCE(v_attendance_rate, 0),
    'pending_requests', v_pending,
    'high_performers', v_high_performers,
    'low_performers', v_low_performers
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- DASHBOARD: KPI BY DIVISION
-- ============================================================
CREATE OR REPLACE FUNCTION get_kpi_by_division()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object(
      'ok', true,
      'data', COALESCE(jsonb_agg(
        jsonb_build_object(
          'divisi', divisi,
          'avg_kpi', avg_kpi,
          'headcount', headcount
        )
        ORDER BY avg_kpi DESC
      ), '[]'::jsonb)
    )
    FROM (
      SELECT e.divisi, ROUND(AVG(p.kpi_score), 1) as avg_kpi, COUNT(*) as headcount
      FROM employees_master e
      LEFT JOIN hr_performance p ON p.nrp = e.nrp AND p.period = (SELECT MAX(period) FROM hr_performance)
      WHERE e.divisi IS NOT NULL
      GROUP BY e.divisi
    ) t
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- DASHBOARD: SAFETY SUMMARY
-- ============================================================
CREATE OR REPLACE FUNCTION get_safety_summary()
RETURNS JSONB AS $$
DECLARE
  v_incidents INT;
  v_ltifr NUMERIC;
BEGIN
  SELECT COUNT(*) INTO v_incidents FROM hr_safety;
  
  SELECT ROUND(
    COUNT(*)::NUMERIC / NULLIF(
      (SELECT SUM(hours_worked) FROM hr_attendance WHERE date >= date_trunc('month', NOW())) / 1000000.0,
    0) * 1000000, 2
  ) INTO v_ltifr FROM hr_safety;
  
  RETURN jsonb_build_object(
    'ok', true,
    'total_incidents', COALESCE(v_incidents, 0),
    'ltifr', COALESCE(v_ltifr, 0),
    'status', CASE WHEN COALESCE(v_incidents, 0) = 0 THEN 'AMAN' ELSE 'PERLU PERHATIAN' END
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- DASHBOARD: HRD FUNCTIONS (for HRD module)
-- ============================================================
CREATE OR REPLACE FUNCTION get_turnover_data()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object(
      'ok', true,
      'data', COALESCE(jsonb_agg(
        jsonb_build_object(
          'divisi', divisi,
          'active', active,
          'left', left_count,
          'rate', turnover_rate
        )
      ), '[]'::jsonb)
    )
    FROM (
      SELECT e.divisi,
        COUNT(*) FILTER (WHERE e.status_kerja = 'Active' OR e.status_kerja IS NULL) as active,
        COUNT(*) FILTER (WHERE e.status_kerja != 'Active' AND e.status_kerja IS NOT NULL) as left_count,
        ROUND(
          COUNT(*) FILTER (WHERE e.status_kerja != 'Active' AND e.status_kerja IS NOT NULL)::NUMERIC /
          NULLIF(COUNT(*), 0) * 100, 1
        ) as turnover_rate
      FROM employees_master e
      WHERE e.divisi IS NOT NULL
      GROUP BY e.divisi
    ) t
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- DASHBOARD: FLIGHT RISK (karyawan berisiko resign)
-- ============================================================
CREATE OR REPLACE FUNCTION get_flight_risk_list()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object(
      'ok', true,
      'data', COALESCE(jsonb_agg(
        jsonb_build_object(
          'nrp', e.nrp,
          'nama', e.nama,
          'divisi', e.divisi,
          'kpi_score', COALESCE(p.kpi_score, 0),
          'telat_count', COALESCE(t.telat_count, 0)
        )
        ORDER BY p.kpi_score ASC
      ), '[]'::jsonb)
    )
    FROM employees_master e
    LEFT JOIN hr_performance p ON p.nrp = e.nrp AND p.period = (SELECT MAX(period) FROM hr_performance)
    LEFT JOIN (
      SELECT nrp, COUNT(*) as telat_count
      FROM hr_attendance
      WHERE status_hadir = 'Telat' AND date >= date_trunc('month', NOW())
      GROUP BY nrp
    ) t ON t.nrp = e.nrp
    WHERE COALESCE(p.kpi_score, 100) < 70 OR COALESCE(t.telat_count, 0) > 5
    ORDER BY p.kpi_score ASC
    LIMIT 10
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
