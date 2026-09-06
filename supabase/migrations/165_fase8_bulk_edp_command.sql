-- ================================================================
-- FASE 8: BULK ACTIONS, DASHBOARD AGGREGATOR, EDP,
--         HR/CEO COMMAND CENTER RPCs
-- Migration 165
-- ================================================================
-- Sumber spec: supabase/c/migrasiGASbelum.sql bagian 8
-- Konvensi: identitas dari authz_current_nrp() (bukan param token),
-- p_ prefix, JSONB {ok:...}, SECURITY DEFINER + SET search_path = public,
-- audit ke audit_log (action, detail, timestamp), GRANT ke authenticated.
-- ================================================================

-- ------------------------------------------------------------------
-- 8.0 Kolom defensif yang dipakai aggregator (IDEMPOTENT, aman jika sudah ada)
-- ------------------------------------------------------------------
DO $$ BEGIN
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
EXCEPTION WHEN duplicate_column THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS resign_date DATE;
EXCEPTION WHEN duplicate_column THEN NULL; END $$;

-- ------------------------------------------------------------------
-- 8.1 BULK ACTIONS
-- Semantik meniru admin_approve_pending / admin_reject_pending (migrasi 003)
-- ------------------------------------------------------------------

-- 8.1.1 Approve banyak pendaftaran (daftar_baru) sekaligus
DROP FUNCTION IF EXISTS admin_bulk_approve_pending(INTEGER[]) CASCADE;
CREATE OR REPLACE FUNCTION admin_bulk_approve_pending(p_ids INTEGER[])
RETURNS JSONB AS $$
DECLARE
  v_caller TEXT;
  v_id INT;
  v_entry RECORD;
  v_ok INT := 0;
  v_fail INT := 0;
BEGIN
  v_caller := authz_current_nrp();
  IF v_caller IS NULL
     OR (NOT authz_check_admin('employee.create') AND NOT authz_check_admin('recruitment.approve')) THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak');
  END IF;
  IF p_ids IS NULL OR array_length(p_ids, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Tidak ada ID yang dipilih');
  END IF;

  FOREACH v_id IN ARRAY p_ids LOOP
    BEGIN
      SELECT * INTO v_entry FROM daftar_baru WHERE id = v_id AND status = 'PENDING';
      IF FOUND THEN
        INSERT INTO employees_master (employee_id, nrp, nik, nama, email, status_kerja)
        VALUES ('EMP' || v_id, v_entry.nrp, v_entry.nik, v_entry.nama, v_entry.email, 'Active')
        ON CONFLICT (nrp) DO NOTHING;
        INSERT INTO worker_passwords (nrp, password_hash, salt, is_active)
        VALUES (v_entry.nrp, COALESCE(v_entry.password_hash, 'pending'), COALESCE(v_entry.salt, ''), true)
        ON CONFLICT (nrp) DO NOTHING;
        INSERT INTO user_roles (nrp, role_level, plan)
        VALUES (v_entry.nrp, 1, 'FREE')
        ON CONFLICT (nrp) DO NOTHING;
        UPDATE daftar_baru SET status = 'APPROVED' WHERE id = v_id;
        v_ok := v_ok + 1;
      ELSE
        v_fail := v_fail + 1;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      v_fail := v_fail + 1;
    END;
  END LOOP;

  INSERT INTO audit_log (action, detail, timestamp)
  VALUES ('BULK_APPROVE', jsonb_build_object('caller', v_caller, 'approved', v_ok, 'failed', v_fail)::text, NOW());
  RETURN jsonb_build_object('ok', true, 'approved', v_ok, 'failed', v_fail);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 8.1.2 Reject banyak pendaftaran (daftar_baru) sekaligus
DROP FUNCTION IF EXISTS admin_bulk_reject_pending(INTEGER[], TEXT) CASCADE;
CREATE OR REPLACE FUNCTION admin_bulk_reject_pending(p_ids INTEGER[], p_note TEXT DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
  v_caller TEXT;
  v_id INT;
  v_ok INT := 0;
  v_fail INT := 0;
BEGIN
  v_caller := authz_current_nrp();
  IF v_caller IS NULL
     OR (NOT authz_check_admin('employee.create') AND NOT authz_check_admin('recruitment.approve')) THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak');
  END IF;
  IF p_ids IS NULL OR array_length(p_ids, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Tidak ada ID yang dipilih');
  END IF;

  FOREACH v_id IN ARRAY p_ids LOOP
    BEGIN
      UPDATE daftar_baru SET status = 'REJECTED' WHERE id = v_id AND status = 'PENDING';
      IF FOUND THEN
        v_ok := v_ok + 1;
      ELSE
        v_fail := v_fail + 1;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      v_fail := v_fail + 1;
    END;
  END LOOP;

  INSERT INTO audit_log (action, detail, timestamp)
  VALUES ('BULK_REJECT',
          jsonb_build_object('caller', v_caller, 'rejected', v_ok, 'failed', v_fail, 'note', p_note)::text,
          NOW());
  RETURN jsonb_build_object('ok', true, 'rejected', v_ok, 'failed', v_fail);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 8.1.3 Broadcast announcement ke notifikasi karyawan
-- Semantik: target_audience 'ALL' -> semua karyawan aktif;
-- selain itu dicocokkan dengan kolom divisi (case-insensitive).
DROP FUNCTION IF EXISTS admin_broadcast_announcement(TEXT) CASCADE;
CREATE OR REPLACE FUNCTION admin_broadcast_announcement(p_ann_id TEXT)
RETURNS JSONB AS $$
DECLARE
  v_caller TEXT;
  v_ann RECORD;
  v_count INT := 0;
BEGIN
  v_caller := authz_current_nrp();
  IF v_caller IS NULL OR NOT authz_check_admin('employee.view_all') THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak');
  END IF;

  SELECT * INTO v_ann FROM announcements WHERE id = p_ann_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Announcement tidak ditemukan');
  END IF;

  IF v_ann.target_audience IS NULL OR UPPER(v_ann.target_audience) = 'ALL' THEN
    INSERT INTO hr_notifications (nrp, category, title, message)
    SELECT nrp, 'announcement', v_ann.title, v_ann.message
    FROM employees_master WHERE is_active = true;
  ELSE
    INSERT INTO hr_notifications (nrp, category, title, message)
    SELECT nrp, 'announcement', v_ann.title, v_ann.message
    FROM employees_master
    WHERE is_active = true AND UPPER(COALESCE(divisi, '')) = UPPER(v_ann.target_audience);
  END IF;
  GET DIAGNOSTICS v_count = ROW_COUNT;

  INSERT INTO audit_log (action, detail, timestamp)
  VALUES ('BROADCAST_ANNOUNCEMENT',
          jsonb_build_object('caller', v_caller, 'ann_id', p_ann_id, 'sent', v_count)::text,
          NOW());
  RETURN jsonb_build_object('ok', true, 'sent', v_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ------------------------------------------------------------------
-- 8.2 DASHBOARD AGGREGATOR — get_dashboard_data()
-- Gabungan demografi, employment, compliance, alerts dalam 1 panggilan.
-- ------------------------------------------------------------------
DROP FUNCTION IF EXISTS get_dashboard_data() CASCADE;
CREATE OR REPLACE FUNCTION get_dashboard_data()
RETURNS JSONB AS $$
DECLARE
  v_caller TEXT;
BEGIN
  v_caller := authz_current_nrp();
  IF v_caller IS NULL OR NOT authz_check_admin('employee.view_all') THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak');
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'demographics', jsonb_build_object(
      'total_active',   (SELECT COUNT(*) FROM employees_master WHERE is_active = true),
      'total_all',      (SELECT COUNT(*) FROM employees_master),
      'male',           (SELECT COUNT(*) FROM employees_master WHERE is_active = true AND UPPER(jenis_kelamin) IN ('L','LAKI-LAKI','MALE','PRIA')),
      'female',         (SELECT COUNT(*) FROM employees_master WHERE is_active = true AND UPPER(jenis_kelamin) IN ('P','PEREMPUAN','FEMALE','WANITA')),
      'avg_age',        (SELECT ROUND(AVG((CURRENT_DATE - tanggal_lahir) / 365.25)::NUMERIC, 1) FROM employees_master WHERE is_active = true AND tanggal_lahir IS NOT NULL),
      'by_divisi',      COALESCE((SELECT jsonb_agg(jsonb_build_object('divisi', divisi, 'total', total) ORDER BY total DESC)
                                  FROM (SELECT divisi, COUNT(*) AS total FROM employees_master
                                        WHERE is_active = true GROUP BY divisi ORDER BY total DESC LIMIT 10) d), '[]'::jsonb)
    ),
    'employment', jsonb_build_object(
      'by_status_kerja', COALESCE((SELECT jsonb_agg(jsonb_build_object('status', status_kerja, 'total', total))
                                   FROM (SELECT COALESCE(status_kerja, 'UNKNOWN') AS status_kerja, COUNT(*) AS total
                                         FROM employees_master WHERE is_active = true
                                         GROUP BY status_kerja) s), '[]'::jsonb),
      'new_hires_30d',  (SELECT COUNT(*) FROM employees_master WHERE is_active = true AND tanggal_masuk >= (CURRENT_DATE - 30)),
      'resigned_30d',   (SELECT COUNT(*) FROM employees_master WHERE resign_date IS NOT NULL AND resign_date >= (CURRENT_DATE - 30)),
      'pkwt_count',     (SELECT COUNT(*) FROM employees_master WHERE is_active = true AND status_kerja = 'PKWT')
    ),
    'compliance', jsonb_build_object(
      'cert_expiring_90d', (SELECT COUNT(*) FROM certifications WHERE status = 'ACTIVE' AND expiry_date IS NOT NULL AND expiry_date <= (CURRENT_DATE + 90)),
      'cert_expired',      (SELECT COUNT(*) FROM certifications WHERE status = 'ACTIVE' AND expiry_date IS NOT NULL AND expiry_date < CURRENT_DATE),
      'compliance_pending',(SELECT COUNT(*) FROM hr_compliance WHERE status = 'PENDING'),
      'compliance_overdue',(SELECT COUNT(*) FROM hr_compliance WHERE status = 'PENDING' AND due_date IS NOT NULL AND due_date < CURRENT_DATE)
    ),
    'alerts', jsonb_build_object(
      'pending_requests',       (SELECT COUNT(*) FROM hr_requests WHERE status = 'PENDING'),
      'pending_registrations',  (SELECT COUNT(*) FROM daftar_baru WHERE status = 'PENDING'),
      'active_announcements',   (SELECT COUNT(*) FROM announcements WHERE expiry_date IS NULL OR expiry_date >= CURRENT_DATE),
      'unread_notifications',   (SELECT COUNT(*) FROM hr_notifications WHERE is_read = false)
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ------------------------------------------------------------------
-- 8.3 EDP — get_edp_data(p_nrp)
-- 360 derajat: profil, skills, KPI, flight risk, training, voice, notes.
-- Akses: diri sendiri / atasan dalam scope / admin employee.view_all.
-- ------------------------------------------------------------------
DROP FUNCTION IF EXISTS get_edp_data(TEXT) CASCADE;
CREATE OR REPLACE FUNCTION get_edp_data(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE
  v_caller TEXT;
  v_emp RECORD;
  v_att_total INT; v_att_hadir INT; v_att_late INT; v_att_alpha INT;
  v_kpi_last NUMERIC;
BEGIN
  v_caller := authz_current_nrp();
  IF v_caller IS NULL OR p_nrp IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Parameter tidak valid');
  END IF;
  IF p_nrp <> v_caller AND NOT authz_in_scope(p_nrp) AND NOT authz_check_admin('employee.view_all') THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak');
  END IF;

  SELECT * INTO v_emp FROM employees_master WHERE nrp = p_nrp;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Karyawan tidak ditemukan');
  END IF;

  SELECT COUNT(*),
         COUNT(*) FILTER (WHERE status_hadir = 'Hadir'),
         COUNT(*) FILTER (WHERE menit_terlambat > 0),
         COUNT(*) FILTER (WHERE UPPER(COALESCE(status_hadir, '')) = 'ALPHA')
  INTO v_att_total, v_att_hadir, v_att_late, v_att_alpha
  FROM hr_attendance WHERE nrp = p_nrp AND date >= (CURRENT_DATE - 90);

  SELECT kpi_score INTO v_kpi_last FROM hr_performance
  WHERE nrp = p_nrp AND kpi_score IS NOT NULL ORDER BY periode DESC LIMIT 1;

  RETURN jsonb_build_object(
    'ok', true,
    'profile', jsonb_build_object(
      'nrp', v_emp.nrp, 'nama', v_emp.nama, 'email', v_emp.email,
      'divisi', v_emp.divisi, 'posisi', v_emp.posisi, 'status_kerja', v_emp.status_kerja,
      'business_unit', COALESCE(v_emp.business_unit, 'HQ'),
      'tanggal_masuk', v_emp.tanggal_masuk, 'tanggal_lahir', v_emp.tanggal_lahir,
      'jenis_kelamin', v_emp.jenis_kelamin, 'level_jabatan', v_emp.level_jabatan
    ),
    'skills', jsonb_build_object(
      'skills', COALESCE((SELECT jsonb_agg(jsonb_build_object('skill', skill_name, 'level', level, 'target_level', target_level, 'certified', certified))
                          FROM (SELECT skill_name, level, target_level, certified FROM hr_skills
                                WHERE nrp = p_nrp ORDER BY created_at DESC LIMIT 30) t), '[]'::jsonb),
      'certifications', COALESCE((SELECT jsonb_agg(jsonb_build_object('cert_name', cert_name, 'issuer', issuer, 'expiry_date', expiry_date, 'status', status))
                                  FROM (SELECT cert_name, issuer, expiry_date, status FROM certifications
                                        WHERE nrp = p_nrp ORDER BY created_at DESC LIMIT 20) t), '[]'::jsonb)
    ),
    'kpi', jsonb_build_object(
      'last_score', v_kpi_last,
      'trend', COALESCE((SELECT jsonb_agg(jsonb_build_object('periode', periode, 'score', kpi_score))
                         FROM (SELECT periode, kpi_score FROM hr_performance
                               WHERE nrp = p_nrp AND kpi_score IS NOT NULL
                               ORDER BY periode DESC LIMIT 6) t), '[]'::jsonb)
    ),
    'attendance_90d', jsonb_build_object(
      'total_days', v_att_total, 'hadir', v_att_hadir, 'late_days', v_att_late, 'alpha_days', v_att_alpha,
      'attendance_rate', CASE WHEN v_att_total > 0 THEN ROUND((v_att_hadir::NUMERIC / v_att_total) * 100, 2) ELSE NULL END
    ),
    'training', COALESCE((SELECT jsonb_agg(jsonb_build_object('title', title, 'status', status, 'score', score, 'end_date', end_date))
                          FROM (SELECT title, status, score, end_date FROM hr_learning
                                WHERE nrp = p_nrp ORDER BY created_at DESC LIMIT 10) t), '[]'::jsonb),
    'voice', jsonb_build_object(
      'submitted', (SELECT COUNT(*) FROM hr_voice WHERE nrp = p_nrp),
      'total_votes', (SELECT COALESCE(SUM(votes), 0) FROM hr_voice WHERE nrp = p_nrp)
    ),
    'notes', COALESCE((SELECT jsonb_agg(jsonb_build_object('note_type', note_type, 'content', content, 'author_nrp', author_nrp, 'created_at', created_at))
                       FROM (SELECT note_type, content, author_nrp, created_at FROM performance_notes
                             WHERE nrp = p_nrp ORDER BY created_at DESC LIMIT 10) t), '[]'::jsonb)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ------------------------------------------------------------------
-- 8.4 HR COMMAND CENTER — get_hr_command_data()
-- Workforce, contract risk, retirement risk, talent matrix, pending actions.
-- ------------------------------------------------------------------
DROP FUNCTION IF EXISTS get_hr_command_data() CASCADE;
CREATE OR REPLACE FUNCTION get_hr_command_data()
RETURNS JSONB AS $$
DECLARE
  v_caller TEXT;
BEGIN
  v_caller := authz_current_nrp();
  IF v_caller IS NULL OR NOT (authz_check_admin('employee.view_all') OR authz_check_admin('department.reports')) THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak');
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'workforce', jsonb_build_object(
      'total_active', (SELECT COUNT(*) FROM employees_master WHERE is_active = true),
      'total_inactive', (SELECT COUNT(*) FROM employees_master WHERE is_active = false),
      'by_divisi', COALESCE((SELECT jsonb_agg(jsonb_build_object('divisi', divisi, 'total', total))
                             FROM (SELECT COALESCE(divisi, 'UNKNOWN') AS divisi, COUNT(*) AS total
                                   FROM employees_master WHERE is_active = true
                                   GROUP BY divisi ORDER BY total DESC LIMIT 10) t), '[]'::jsonb),
      'new_hires_30d', (SELECT COUNT(*) FROM employees_master WHERE is_active = true AND tanggal_masuk >= (CURRENT_DATE - 30)),
      'resigned_30d',  (SELECT COUNT(*) FROM employees_master WHERE resign_date IS NOT NULL AND resign_date >= (CURRENT_DATE - 30))
    ),
    'contract_risk', jsonb_build_object(
      'pkwt_count',        (SELECT COUNT(*) FROM employees_master WHERE is_active = true AND status_kerja = 'PKWT'),
      'cert_expiring_90d', (SELECT COUNT(*) FROM certifications WHERE status = 'ACTIVE' AND expiry_date IS NOT NULL AND expiry_date <= (CURRENT_DATE + 90)),
      'cert_expired',      (SELECT COUNT(*) FROM certifications WHERE status = 'ACTIVE' AND expiry_date IS NOT NULL AND expiry_date < CURRENT_DATE)
    ),
    'retirement_risk', jsonb_build_object(
      'within_5_years', (SELECT COUNT(*) FROM employees_master
                         WHERE is_active = true AND tanggal_lahir IS NOT NULL
                           AND tanggal_lahir <= (CURRENT_DATE - INTERVAL '51 years')),
      'proyeksi_usia_pensiun', 56
    ),
    'talent_matrix', jsonb_build_object(
      'avg_kpi_last',     (SELECT ROUND(AVG(kpi_score)::NUMERIC, 2) FROM hr_performance
                           WHERE periode = (SELECT MAX(periode) FROM hr_performance)),
      'kpi_below_target', (SELECT COUNT(*) FROM hr_performance
                           WHERE periode = (SELECT MAX(periode) FROM hr_performance) AND kpi_score < 60),
      'certified_skills', (SELECT COUNT(*) FROM hr_skills WHERE certified = true),
      'training_completed', (SELECT COUNT(*) FROM hr_learning WHERE status = 'COMPLETED')
    ),
    'attendance_today', jsonb_build_object(
      'hadir_today',    (SELECT COUNT(*) FROM hr_attendance WHERE date = CURRENT_DATE AND status_hadir = 'Hadir'),
      'late_today',     (SELECT COUNT(*) FROM hr_attendance WHERE date = CURRENT_DATE AND menit_terlambat > 0),
      'alpa_today',     (SELECT COUNT(*) FROM hr_attendance WHERE date = CURRENT_DATE AND UPPER(COALESCE(status_hadir, '')) = 'ALPHA')
    ),
    'pending_actions', jsonb_build_object(
      'hr_requests',         (SELECT COUNT(*) FROM hr_requests WHERE status = 'PENDING'),
      'registrations',       (SELECT COUNT(*) FROM daftar_baru WHERE status = 'PENDING'),
      'latest_pending_types', COALESCE((SELECT jsonb_agg(jsonb_build_object('type', type, 'total', total))
                                        FROM (SELECT type, COUNT(*) AS total FROM hr_requests
                                              WHERE status = 'PENDING' GROUP BY type ORDER BY total DESC LIMIT 5) t), '[]'::jsonb)
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ------------------------------------------------------------------
-- 8.5 CEO COMMAND CENTER (ENHANCED) — get_ceo_command_data()
-- Overload tanpa argumen; get_ceo_command_data(TEXT) lama dari 011 tidak diubah.
-- Workforce, flight risk ringkas, talent pipeline, finance, health score, alert center.
-- ------------------------------------------------------------------
DROP FUNCTION IF EXISTS get_ceo_command_data() CASCADE;
CREATE OR REPLACE FUNCTION get_ceo_command_data()
RETURNS JSONB AS $$
DECLARE
  v_caller TEXT;
  v_health NUMERIC := 0;
  v_att_rate NUMERIC := 0;
  v_pending_rate NUMERIC := 0;
  v_cert_rate NUMERIC := 0;
BEGIN
  v_caller := authz_current_nrp();
  IF v_caller IS NULL OR NOT (authz_check_admin('employee.view_all') OR authz_check_admin('department.reports')) THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak');
  END IF;

  SELECT ROUND((COUNT(*) FILTER (WHERE status_hadir = 'Hadir')::NUMERIC / NULLIF(COUNT(*), 0)) * 100, 2)
  INTO v_att_rate FROM hr_attendance WHERE date >= (CURRENT_DATE - 30);
  SELECT ROUND((1 - (COUNT(*) FILTER (WHERE status = 'PENDING')::NUMERIC / NULLIF(COUNT(*), 0))) * 100, 2)
  INTO v_pending_rate FROM hr_requests;
  SELECT ROUND((1 - (COUNT(*) FILTER (WHERE expiry_date IS NOT NULL AND expiry_date <= CURRENT_DATE + 90)::NUMERIC / NULLIF(COUNT(*), 0))) * 100, 2)
  INTO v_cert_rate FROM certifications WHERE status = 'ACTIVE';

  v_health := ROUND((COALESCE(v_att_rate, 0) * 0.5 + COALESCE(v_pending_rate, 100) * 0.3 + COALESCE(v_cert_rate, 100) * 0.2), 1);

  RETURN jsonb_build_object(
    'ok', true,
    'workforce', jsonb_build_object(
      'total_active', (SELECT COUNT(*) FROM employees_master WHERE is_active = true),
      'by_divisi', COALESCE((SELECT jsonb_agg(jsonb_build_object('divisi', divisi, 'total', total))
                             FROM (SELECT COALESCE(divisi, 'UNKNOWN') AS divisi, COUNT(*) AS total
                                   FROM employees_master WHERE is_active = true
                                   GROUP BY divisi ORDER BY total DESC LIMIT 10) t), '[]'::jsonb),
      'new_hires_30d', (SELECT COUNT(*) FROM employees_master WHERE is_active = true AND tanggal_masuk >= (CURRENT_DATE - 30)),
      'resigned_30d',  (SELECT COUNT(*) FROM employees_master WHERE resign_date IS NOT NULL AND resign_date >= (CURRENT_DATE - 30))
    ),
    'flight_risk_top', COALESCE((SELECT jsonb_agg(jsonb_build_object('nrp', nrp, 'nama', nama, 'late_30d', late_30d))
                                 FROM (SELECT a.nrp, e.nama, COUNT(*) AS late_30d
                                       FROM hr_attendance a JOIN employees_master e ON e.nrp = a.nrp
                                       WHERE a.date >= (CURRENT_DATE - 30) AND a.menit_terlambat > 0
                                       GROUP BY a.nrp, e.nama ORDER BY late_30d DESC LIMIT 5) t), '[]'::jsonb),
    'talent_pipeline', jsonb_build_object(
      'avg_kpi_last',       (SELECT ROUND(AVG(kpi_score)::NUMERIC, 2) FROM hr_performance
                             WHERE periode = (SELECT MAX(periode) FROM hr_performance)),
      'certified_skills',   (SELECT COUNT(*) FROM hr_skills WHERE certified = true),
      'training_completed', (SELECT COUNT(*) FROM hr_learning WHERE status = 'COMPLETED'),
      'cert_expiring_90d',  (SELECT COUNT(*) FROM certifications WHERE status = 'ACTIVE' AND expiry_date IS NOT NULL AND expiry_date <= (CURRENT_DATE + 90))
    ),
    'finance', jsonb_build_object(
      'latest_period',  (SELECT MAX(periode) FROM hr_payroll),
      'net_pay_period', (SELECT COALESCE(SUM(net_salary), 0) FROM hr_payroll WHERE periode = (SELECT MAX(periode) FROM hr_payroll)),
      'overtime_pay_period', (SELECT COALESCE(SUM(overtime_pay), 0) FROM hr_payroll WHERE periode = (SELECT MAX(periode) FROM hr_payroll))
    ),
    'health_score', v_health,
    'alert_center', jsonb_build_object(
      'pending_requests',      (SELECT COUNT(*) FROM hr_requests WHERE status = 'PENDING'),
      'pending_registrations', (SELECT COUNT(*) FROM daftar_baru WHERE status = 'PENDING'),
      'cert_expired',          (SELECT COUNT(*) FROM certifications WHERE status = 'ACTIVE' AND expiry_date IS NOT NULL AND expiry_date < CURRENT_DATE),
      'active_announcements',  (SELECT COUNT(*) FROM announcements WHERE expiry_date IS NULL OR expiry_date >= CURRENT_DATE)
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ------------------------------------------------------------------
-- 8.6 CHECK REGISTRATION STATUS (Public, tanpa PII)
-- Hanya mengembalikan status; tidak membocorkan data pendaftar.
-- ------------------------------------------------------------------
DROP FUNCTION IF EXISTS check_registration_status(TEXT) CASCADE;
CREATE OR REPLACE FUNCTION check_registration_status(p_query TEXT)
RETURNS JSONB AS $$
DECLARE
  v_status TEXT;
BEGIN
  IF p_query IS NULL OR LENGTH(TRIM(p_query)) < 4 THEN
    RETURN jsonb_build_object('ok', true, 'found', false, 'status', 'NOT_FOUND');
  END IF;
  SELECT status INTO v_status FROM daftar_baru
  WHERE nik = TRIM(p_query) OR LOWER(email) = LOWER(TRIM(p_query))
  ORDER BY id DESC LIMIT 1;
  IF v_status IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'found', false, 'status', 'NOT_FOUND');
  END IF;
  RETURN jsonb_build_object('ok', true, 'found', true, 'status', v_status);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ------------------------------------------------------------------
-- 8.7 VOTE & UPDATE IDEA (hr_voice)
-- ------------------------------------------------------------------

-- Tabel pelacak vote agar 1 karyawan hanya 1 vote per ide.
CREATE TABLE IF NOT EXISTS hr_voice_votes (
  voice_id TEXT NOT NULL REFERENCES hr_voice(id) ON DELETE CASCADE,
  nrp TEXT NOT NULL REFERENCES employees_master(nrp) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (voice_id, nrp)
);

ALTER TABLE hr_voice_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr_voice_votes FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "hvv_select" ON hr_voice_votes;
CREATE POLICY "hvv_select" ON hr_voice_votes FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "hvv_insert" ON hr_voice_votes;
CREATE POLICY "hvv_insert" ON hr_voice_votes FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Vote up sebuah ide (1x per karyawan)
DROP FUNCTION IF EXISTS vote_idea(TEXT) CASCADE;
CREATE OR REPLACE FUNCTION vote_idea(p_idea_id TEXT)
RETURNS JSONB AS $$
DECLARE
  v_caller TEXT;
  v_author TEXT;
BEGIN
  v_caller := authz_current_nrp();
  IF v_caller IS NULL OR p_idea_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Parameter tidak valid');
  END IF;

  SELECT nrp INTO v_author FROM hr_voice WHERE id = p_idea_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Ide tidak ditemukan');
  END IF;
  IF v_author = v_caller THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Tidak bisa mem-vote ide sendiri');
  END IF;

  INSERT INTO hr_voice_votes (voice_id, nrp) VALUES (p_idea_id, v_caller)
  ON CONFLICT (voice_id, nrp) DO NOTHING;

  IF FOUND THEN
    UPDATE hr_voice SET votes = COALESCE(votes, 0) + 1 WHERE id = p_idea_id;
    INSERT INTO audit_log (action, detail, timestamp)
    VALUES ('VOTE_IDEA', jsonb_build_object('id', p_idea_id, 'nrp', v_caller)::text, NOW());
    RETURN jsonb_build_object('ok', true, 'already_voted', false);
  END IF;

  RETURN jsonb_build_object('ok', true, 'already_voted', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Update status ide (workflow GAS: SUBMITTED -> REVIEW -> APPROVED -> IMPLEMENTED -> REWARDED)
-- Nama & param mengikuti kontrak frontend: admin_update_idea_status({p_idea_id, p_status})
DROP FUNCTION IF EXISTS admin_update_idea_status(TEXT, TEXT) CASCADE;
CREATE OR REPLACE FUNCTION admin_update_idea_status(p_idea_id TEXT, p_status TEXT)
RETURNS JSONB AS $$
DECLARE
  v_caller TEXT;
BEGIN
  v_caller := authz_current_nrp();
  IF v_caller IS NULL OR NOT authz_check_admin('employee.view_all') THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak');
  END IF;
  IF p_status IS NULL OR UPPER(p_status) NOT IN ('SUBMITTED','REVIEW','APPROVED','IMPLEMENTED','REWARDED','REJECTED') THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Status tidak valid');
  END IF;

  UPDATE hr_voice SET status = UPPER(p_status) WHERE id = p_idea_id;
  IF FOUND THEN
    INSERT INTO audit_log (action, detail, timestamp)
    VALUES ('UPDATE_IDEA_STATUS', jsonb_build_object('id', p_idea_id, 'status', p_status, 'by', v_caller)::text, NOW());
    RETURN jsonb_build_object('ok', true, 'msg', 'Status ide diperbarui');
  END IF;
  RETURN jsonb_build_object('ok', false, 'msg', 'Ide tidak ditemukan');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ------------------------------------------------------------------
-- 8.8 CONTINUOUS PERFORMANCE NOTE
-- ------------------------------------------------------------------

-- Tambah catatan performance (ACHIEVEMENT / FEEDBACK / DEVELOPMENT)
DROP FUNCTION IF EXISTS add_perf_note(TEXT, TEXT, TEXT) CASCADE;
CREATE OR REPLACE FUNCTION add_perf_note(p_nrp TEXT, p_type TEXT, p_text TEXT)
RETURNS JSONB AS $$
DECLARE
  v_caller TEXT;
  v_type TEXT;
BEGIN
  v_caller := authz_current_nrp();
  IF v_caller IS NULL OR p_nrp IS NULL OR p_text IS NULL OR LENGTH(TRIM(p_text)) < 3 THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Parameter tidak valid');
  END IF;
  IF p_nrp <> v_caller AND NOT authz_in_scope(p_nrp) AND NOT authz_check_admin('performance.review') AND NOT authz_check_admin('employee.view_all') THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak');
  END IF;

  v_type := UPPER(COALESCE(p_type, 'FEEDBACK'));
  IF v_type NOT IN ('ACHIEVEMENT','FEEDBACK','DEVELOPMENT') THEN
    v_type := 'FEEDBACK';
  END IF;

  INSERT INTO performance_notes (nrp, author_nrp, note_type, content)
  VALUES (p_nrp, v_caller, v_type, p_text);

  INSERT INTO audit_log (action, detail, timestamp)
  VALUES ('ADD_PERF_NOTE', jsonb_build_object('nrp', p_nrp, 'type', v_type)::text, NOW());
  RETURN jsonb_build_object('ok', true, 'msg', 'Catatan performance ditambahkan');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Ambil riwayat performance + feedback
DROP FUNCTION IF EXISTS get_continuous_performance(TEXT) CASCADE;
CREATE OR REPLACE FUNCTION get_continuous_performance(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE
  v_caller TEXT;
BEGIN
  v_caller := authz_current_nrp();
  IF v_caller IS NULL OR p_nrp IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Parameter tidak valid');
  END IF;
  IF p_nrp <> v_caller AND NOT authz_in_scope(p_nrp) AND NOT authz_check_admin('employee.view_all') THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak');
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'data', COALESCE((SELECT jsonb_agg(jsonb_build_object('note_type', note_type, 'content', content, 'author_nrp', author_nrp, 'created_at', created_at))
                      FROM (SELECT note_type, content, author_nrp, created_at FROM performance_notes
                            WHERE nrp = p_nrp ORDER BY created_at DESC LIMIT 50) t), '[]'::jsonb)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ------------------------------------------------------------------
-- GRANTs
-- ------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION admin_bulk_approve_pending(INTEGER[]) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_bulk_reject_pending(INTEGER[], TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_broadcast_announcement(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_dashboard_data() TO authenticated;
GRANT EXECUTE ON FUNCTION get_edp_data(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_hr_command_data() TO authenticated;
GRANT EXECUTE ON FUNCTION get_ceo_command_data() TO authenticated;
GRANT EXECUTE ON FUNCTION check_registration_status(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION vote_idea(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_update_idea_status(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION add_perf_note(TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_continuous_performance(TEXT) TO authenticated;

DO $$ BEGIN
  RAISE NOTICE '=== Fase 8: Bulk/EDP/Command Center -- 12 functions, 1 table ===';
END $$;
