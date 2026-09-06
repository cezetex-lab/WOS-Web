-- ================================================================
-- 168_fix_p0_p1.sql — FIX P0 + P1 (hasil audit forensik 6 Sep 2026)
-- Daftar perbaikan:
--  S1. P0: bug deteksi bcrypt di login_worker(3-arg) & change_password
--       (pola LIKE '\b\$%' / '\u0007\$%' tidak pernah match hash bcrypt $2b$...
--       => semua worker yang auto-upgrade ke bcrypt terkunci selamanya)
--  S2. P0: REVOKE decrypt_pii dari authenticated + PUBLIC
--       (fungsi decrypt PII hanya untuk internal SECURITY DEFINER)
--  S3. P1: register_session (dipanggil SessionGuard.jsx, belum pernah ada)
--  S4. P1: overload create_worker_request(p_nrp,p_type,p_detail,p_note)
--       (kontrak frontend TrainingForm/WorkerOvertime/ContinuousPerf)
--  S5. P1: 6 fungsi mining 055 hilang di DB (full_name -> nama)
--  S6. P1: kolom jabatan + rewrite get_hr_payroll (kolom aktual DB)
--  S7. P1: tabel hr_production/hr_safety_incidents/notifications +
--       fix kolom drift fungsi 160 (status_hadir, periode, overtime_approved)
--  S8. P1: 8 RPC cron yang dipanggil edge function tapi tidak ada di DB
-- ================================================================
-- SEMUA definisi IDEMPOTENT (CREATE OR REPLACE / IF NOT EXISTS).
-- ================================================================

-- ════════════════════════════════════════════════════════════════
-- S1. P0 — FIX BCRYPT DETECTION
-- Root cause: password_hash bcrypt diawali '$2a$'/'$2b$', tapi pola
-- LIKE '\b\$%' / '\u0007\$%' (string literal standar) TIDAK PERNAH
-- match -> kode jatuh ke cabang sha256 dengan salt=NULL -> selalu
-- "Password salah". Diganti pola literal '$2%' yang benar-benar match.
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION login_worker(p_nrp TEXT, p_nik TEXT, p_password TEXT)
RETURNS JSONB AS $$
DECLARE
  v_emp RECORD; v_pwd RECORD; v_role RECORD; v_site RECORD;
  v_salt TEXT; v_hash TEXT; v_token TEXT; v_reset_required BOOLEAN := FALSE;
BEGIN
  IF p_nrp IS NULL OR LENGTH(p_nrp) < 3 OR LENGTH(p_nrp) > 20 THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Format NRP tidak valid');
  END IF;
  IF p_nik IS NULL OR LENGTH(p_nik) < 5 OR LENGTH(p_nik) > 20 THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Format NIK tidak valid');
  END IF;
  IF p_password IS NULL OR LENGTH(p_password) < 6 THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Password minimal 6 karakter');
  END IF;

  SELECT * INTO v_emp FROM employees_master WHERE nrp = p_nrp AND nik = p_nik;
  IF v_emp IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'NRP/NIK tidak ditemukan');
  END IF;

  SELECT * INTO v_pwd FROM worker_passwords WHERE nrp = p_nrp AND is_active = true;
  IF v_pwd IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akun tidak aktif');
  END IF;

  IF v_pwd.blocked_until IS NOT NULL AND v_pwd.blocked_until > NOW() THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akun diblokir sementara');
  END IF;

  -- K6: bcrypt ($2a$/$2b$) vs sha256 (hex) — deteksi via prefix '$2'
  IF v_pwd.password_hash LIKE '$2%' THEN
    IF crypt(p_password, v_pwd.password_hash) != v_pwd.password_hash THEN
      UPDATE worker_passwords SET attempts = attempts + 1,
        blocked_until = CASE WHEN attempts >= 4 THEN NOW() + INTERVAL '15 minutes' ELSE blocked_until END
      WHERE nrp = p_nrp;
      RETURN jsonb_build_object('ok', false, 'msg', 'Password salah');
    END IF;
  ELSE
    v_salt := v_pwd.salt;
    v_hash := encode(digest(p_password || v_salt, 'sha256'), 'hex');
    IF v_hash != v_pwd.password_hash THEN
      UPDATE worker_passwords SET attempts = attempts + 1,
        blocked_until = CASE WHEN attempts >= 4 THEN NOW() + INTERVAL '15 minutes' ELSE blocked_until END
      WHERE nrp = p_nrp;
      RETURN jsonb_build_object('ok', false, 'msg', 'Password salah');
    END IF;
    -- K6: Auto-upgrade ke bcrypt saat login sukses (hanya untuk akun sha256)
    UPDATE worker_passwords
    SET password_hash = crypt(p_password, gen_salt('bf')), salt = NULL, reset_required = FALSE
    WHERE nrp = p_nrp;
  END IF;

  UPDATE worker_passwords SET attempts = 0, blocked_until = NULL WHERE nrp = p_nrp;
  SELECT reset_required INTO v_reset_required FROM worker_passwords WHERE nrp = p_nrp;
  UPDATE session_tokens SET is_used = true, used_at = NOW() WHERE nrp = p_nrp AND is_used = false;
  SELECT * INTO v_role FROM user_roles WHERE nrp = p_nrp;
  SELECT s.* INTO v_site FROM sites s WHERE s.id = v_emp.site_id;

  v_token := encode(gen_random_bytes(32), 'hex');
  INSERT INTO session_tokens (nrp, token_hash, ip_address, user_agent, is_used)
  VALUES (p_nrp, encode(digest(v_token, 'sha256'), 'hex'), NULL, NULL, false) ON CONFLICT DO NOTHING;
  INSERT INTO login_attempts (nrp, success, ip_address, user_agent, attempted_at)
  VALUES (p_nrp, true, NULL, NULL, NOW());

  RETURN jsonb_build_object(
    'ok', true, 'nrp', v_emp.nrp, 'nama', v_emp.nama, 'nik', v_emp.nik,
    'divisi', v_emp.divisi, 'posisi', v_emp.posisi,
    'role_level', COALESCE(v_role.role_level, 1),
    'role', COALESCE(v_role.role, 'worker'),
    'business_unit', COALESCE(v_emp.business_unit, 'HQ'),
    'token', v_token, 'reset_required', COALESCE(v_reset_required, false),
    'expires_at', (NOW() + INTERVAL '24 hours')::text
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION login_worker(text, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION change_password(
  p_nrp TEXT, p_old_password TEXT, p_new_password TEXT
) RETURNS JSONB AS $$
DECLARE
  v_pwd RECORD; v_valid BOOLEAN := FALSE;
BEGIN
  IF p_new_password IS NULL OR LENGTH(p_new_password) < 8 THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Password baru minimal 8 karakter');
  END IF;
  SELECT * INTO v_pwd FROM worker_passwords WHERE nrp = p_nrp AND is_active = true;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akun tidak ditemukan');
  END IF;
  -- K6: deteksi bcrypt via prefix '$2'
  IF v_pwd.password_hash LIKE '$2%' THEN
    v_valid := (crypt(p_old_password, v_pwd.password_hash) = v_pwd.password_hash);
  ELSE
    v_valid := (encode(digest(p_old_password || v_pwd.salt, 'sha256'), 'hex') = v_pwd.password_hash);
  END IF;
  IF NOT v_valid THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Password lama salah');
  END IF;
  UPDATE worker_passwords
  SET password_hash = crypt(p_new_password, gen_salt('bf')),
      salt = NULL, reset_required = FALSE, attempts = 0, blocked_until = NULL
  WHERE nrp = p_nrp;
  UPDATE session_tokens SET is_used = true, used_at = NOW() WHERE nrp = p_nrp AND is_used = false;
  INSERT INTO audit_log (action, detail, timestamp)
  VALUES ('PASSWORD_CHANGED', jsonb_build_object('nrp', p_nrp)::text, NOW());
  RETURN jsonb_build_object('ok', true, 'msg', 'Password berhasil diubah');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION change_password(text, text, text) TO authenticated;

-- ════════════════════════════════════════════════════════════════
-- S2. P0 — REVOKE decrypt_pii DARI authenticated + PUBLIC
-- decrypt_pii = SECURITY DEFINER, key dari company_config. Panggilan
-- internal (mfa_verify_login, get_employee_pii) TETAP jalan karena
-- berjalan sebagai postgres. Frontend tidak memanggilnya langsung.
-- ════════════════════════════════════════════════════════════════

REVOKE EXECUTE ON FUNCTION decrypt_pii(BYTEA) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION decrypt_pii(BYTEA) FROM authenticated;

-- ════════════════════════════════════════════════════════════════
-- S3. P1 — register_session (SessionGuard.jsx -> active_sessions)
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION register_session(p_session_id TEXT, p_ip TEXT DEFAULT '', p_ua TEXT DEFAULT '')
RETURNS JSONB AS $$
DECLARE v_nrp TEXT;
BEGIN
  IF p_session_id IS NULL OR p_session_id = '' THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'session_id wajib');
  END IF;
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Unauthenticated');
  END IF;
  v_nrp := COALESCE(authz_current_nrp(), 'SYSTEM');
  INSERT INTO active_sessions (auth_id, nrp, session_id, ip_address, user_agent)
  VALUES (auth.uid(), v_nrp, p_session_id, p_ip, p_ua)
  ON CONFLICT (session_id) DO UPDATE SET last_active = NOW(), ip_address = EXCLUDED.ip_address, user_agent = EXCLUDED.user_agent;
  RETURN jsonb_build_object('ok', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION register_session(text, text, text) TO authenticated;

-- ════════════════════════════════════════════════════════════════
-- S4. P1 — create_worker_request overload kontrak frontend
-- Frontend (TrainingForm/WorkerOvertime/ContinuousPerf) kirim:
--   {p_nrp, p_type, p_detail, p_note}
-- Versi 5-arg lama (p_reason,p_start_date,p_end_date) TIDAK diubah.
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION create_worker_request(p_nrp TEXT, p_type TEXT, p_detail TEXT, p_note TEXT)
RETURNS JSONB AS $$
BEGIN
  INSERT INTO hr_requests (id, nrp, type, status, details_json, note)
  VALUES (encode(gen_random_bytes(8), 'hex'), p_nrp, p_type, 'PENDING', p_detail, p_note);
  RETURN jsonb_build_object('ok', true, 'msg', 'Request berhasil dikirim.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION create_worker_request(text, text, text, text) TO authenticated;

-- ════════════════════════════════════════════════════════════════
-- S5. P1 — 6 fungsi mining 055 (hilang di DB)
-- Salinan definisi 055 dengan perbaikan: em.full_name -> em.nama
-- (kolom employees_master aktual = nama, bukan full_name).
-- Ditambah SECURITY DEFINER SET search_path (RULE 4).
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION get_simper_list(p_nrp TEXT DEFAULT NULL)
RETURNS JSONB AS $$
BEGIN
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'id', sm.id,
      'nrp', sm.nrp,
      'worker_name', COALESCE(em.nama, sm.nrp),
      'zone', sm.zone,
      'entry_time', sm.entry_time,
      'exit_time', sm.exit_time,
      'status', sm.status,
      'valid_until', sm.valid_until
    ))
    FROM (
      SELECT ROW_NUMBER() OVER () as id, nrp,
        CASE (ROW_NUMBER() % 5) WHEN 0 THEN 'Pit A' WHEN 1 THEN 'Pit B' WHEN 2 THEN 'Haul Road 1' WHEN 3 THEN 'Crusher Zone' ELSE 'Stockpile' END as zone,
        NOW() - (random() * interval '8 hours') as entry_time,
        CASE WHEN random() > 0.3 THEN NOW() - (random() * interval '2 hours') ELSE NULL END as exit_time,
        CASE WHEN random() > 0.3 THEN 'COMPLETED' ELSE 'ACTIVE' END as status,
        NOW() + interval '12 hours' as valid_until
      FROM employees_master
      WHERE business_unit = 'MINING'
        AND (p_nrp IS NULL OR nrp = p_nrp)
      ORDER BY random()
      LIMIT 20
    ) sm
    LEFT JOIN employees_master em ON em.nrp = sm.nrp
  ), '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION get_simper_list(text) TO authenticated;

CREATE OR REPLACE FUNCTION get_heavy_equipment(p_nrp TEXT DEFAULT NULL)
RETURNS JSONB AS $$
BEGIN
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'id', eq.id,
      'equipment_id', eq.equipment_id,
      'type', eq.equipment_type,
      'status', eq.status,
      'location', eq.location,
      'operator', eq.operator,
      'hours_run', eq.hours_run,
      'fuel_level', eq.fuel_level,
      'next_maintenance', eq.next_maintenance
    ))
    FROM (
      SELECT ROW_NUMBER() OVER () as id,
        'EQ-' || LPAD(ROW_NUMBER()::TEXT, 3, '0') as equipment_id,
        (ARRAY['Excavator CAT 320','Dump Truck 789D','Bulldozer D6T','Wheel Loader 966M','Drill Rig PV-271','Motor Grader 16M'])[1 + ROW_NUMBER() % 6] as equipment_type,
        (ARRAY['OPERATIONAL','MAINTENANCE','IDLE','STANDBY'])[1 + ROW_NUMBER() % 4] as status,
        (ARRAY['Pit A - Level 3','Haul Road Main','Crusher Station','Stockpile Zone 2','Workshop Area'])[1 + ROW_NUMBER() % 5] as location,
        'MNG' || LPAD(((ROW_NUMBER() * 7) % 500 + 1)::TEXT, 4, '0') as operator,
        (2000 + ROW_NUMBER() * 150)::INT as hours_run,
        (40 + ROW_NUMBER() * 5) % 100 as fuel_level,
        NOW() + (random() * interval '30 days') as next_maintenance
      FROM generate_series(1, 12) s
    ) eq
    WHERE p_nrp IS NULL OR eq.operator = p_nrp
  ), '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION get_heavy_equipment(text) TO authenticated;

CREATE OR REPLACE FUNCTION get_fatigue_data(p_nrp TEXT DEFAULT NULL)
RETURNS JSONB AS $$
BEGIN
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'id', fd.id,
      'nrp', fd.nrp,
      'worker_name', COALESCE(em.nama, fd.nrp),
      'shift', fd.shift,
      'hours_worked', fd.hours_worked,
      'fatigue_level', fd.fatigue_level,
      'rest_hours', fd.rest_hours,
      'status', fd.status,
      'last_check', fd.last_check
    ))
    FROM (
      SELECT ROW_NUMBER() OVER () as id,
        'MNG' || LPAD(((ROW_NUMBER() * 3) % 500 + 1)::TEXT, 4, '0') as nrp,
        (ARRAY['Shift Pagi','Shift Sore','Shift Malam'])[1 + ROW_NUMBER() % 3] as shift,
        (6 + ROW_NUMBER() % 8) as hours_worked,
        (ARRAY['LOW','MEDIUM','HIGH','CRITICAL'])[1 + ROW_NUMBER() % 4] as fatigue_level,
        (16 - 6 - ROW_NUMBER() % 8) as rest_hours,
        CASE WHEN ROW_NUMBER() % 4 = 0 THEN 'NEEDS_REST' ELSE 'OK' END as status,
        NOW() - (random() * interval '2 hours') as last_check
      FROM generate_series(1, 15) s
    ) fd
    LEFT JOIN employees_master em ON em.nrp = fd.nrp
    WHERE p_nrp IS NULL OR fd.nrp = p_nrp
  ), '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION get_fatigue_data(text) TO authenticated;

CREATE OR REPLACE FUNCTION get_production_daily(p_nrp TEXT DEFAULT NULL)
RETURNS JSONB AS $$
BEGIN
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'id', pd.id,
      'zone', pd.zone,
      'target_tonase', pd.target_tonase,
      'actual_tonase', pd.actual_tonase,
      'progress_pct', pd.progress_pct,
      'operator_count', pd.operator_count,
      'equipment_count', pd.equipment_count,
      'status', pd.status,
      'shift', pd.shift
    ))
    FROM (
      SELECT ROW_NUMBER() OVER () as id,
        (ARRAY['Pit A - Lvl 1','Pit A - Lvl 2','Pit B - Lvl 1','Pit B - Lvl 2','Haul Road','Crusher','Stockpile'])[1 + ROW_NUMBER() % 7] as zone,
        (200 + ROW_NUMBER() * 50)::INT as target_tonase,
        (150 + ROW_NUMBER() * 40 + ROW_NUMBER() * 10)::INT as actual_tonase,
        ROUND((150 + ROW_NUMBER() * 40 + ROW_NUMBER() * 10)::NUMERIC / (200 + ROW_NUMBER() * 50) * 100, 1) as progress_pct,
        (8 + ROW_NUMBER() % 12) as operator_count,
        (3 + ROW_NUMBER() % 5) as equipment_count,
        CASE WHEN ROW_NUMBER() % 3 = 0 THEN 'COMPLETED' WHEN ROW_NUMBER() % 3 = 1 THEN 'IN_PROGRESS' ELSE 'PENDING' END as status,
        (ARRAY['Pagi','Sore','Malam'])[1 + ROW_NUMBER() % 3] as shift
      FROM generate_series(1, 7) s
    ) pd
  ), '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION get_production_daily(text) TO authenticated;

CREATE OR REPLACE FUNCTION get_safety_incidents(p_nrp TEXT DEFAULT NULL)
RETURNS JSONB AS $$
BEGIN
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'id', si.id,
      'incident_type', si.incident_type,
      'severity', si.severity,
      'location', si.location,
      'description', si.description,
      'reported_by', si.reported_by,
      'reporter_name', COALESCE(em.nama, si.reported_by),
      'status', si.status,
      'reported_at', si.reported_at,
      'zone', si.zone
    ))
    FROM (
      SELECT ROW_NUMBER() OVER () as id,
        (ARRAY['Near Miss','First Aid','Medical Treatment','Lost Time','Property Damage'])[1 + ROW_NUMBER() % 5] as incident_type,
        (ARRAY['LOW','MEDIUM','HIGH','CRITICAL'])[1 + ROW_NUMBER() % 4] as severity,
        (ARRAY['Pit A','Pit B','Haul Road','Crusher','Stockpile','Workshop'])[1 + ROW_NUMBER() % 6] as location,
        (ARRAY['Slip on wet surface','Equipment near miss','Falling debris','Fatigue-related','Chemical exposure'])[1 + ROW_NUMBER() % 5] as description,
        'MNG' || LPAD(((ROW_NUMBER() * 5) % 500 + 1)::TEXT, 4, '0') as reported_by,
        CASE WHEN ROW_NUMBER() % 3 = 0 THEN 'RESOLVED' WHEN ROW_NUMBER() % 3 = 1 THEN 'INVESTIGATING' ELSE 'OPEN' END as status,
        NOW() - (random() * interval '30 days') as reported_at,
        (ARRAY['Zone A','Zone B','Zone C','Zone D'])[1 + ROW_NUMBER() % 4] as zone
      FROM generate_series(1, 10) s
    ) si
    LEFT JOIN employees_master em ON em.nrp = si.reported_by
  ), '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION get_safety_incidents(text) TO authenticated;

CREATE OR REPLACE FUNCTION get_jsa_list(p_nrp TEXT DEFAULT NULL)
RETURNS JSONB AS $$
BEGIN
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'id', jsa.id,
      'job_name', jsa.job_name,
      'hazard', jsa.hazard,
      'risk_level', jsa.risk_level,
      'control_measure', jsa.control_measure,
      'reviewed_by', jsa.reviewed_by,
      'valid_until', jsa.valid_until,
      'status', jsa.status
    ))
    FROM (
      SELECT ROW_NUMBER() OVER () as id,
        (ARRAY['Blasting Operation','Hauling Coal','Excavation Level 3','Crusher Maintenance','Night Shift Patrol','Fuel Delivery'])[1 + ROW_NUMBER() % 6] as job_name,
        (ARRAY['Falling rocks','Equipment collision','Dust exposure','Noise exposure','Heat stress','Ground instability'])[1 + ROW_NUMBER() % 6] as hazard,
        (ARRAY['LOW','MEDIUM','HIGH','CRITICAL'])[1 + ROW_NUMBER() % 4] as risk_level,
        (ARRAY['Use PPE + spotters','Speed limit + mirrors','Respirator required','Ear plugs mandatory','Hydration break every 30min'])[1 + ROW_NUMBER() % 5] as control_measure,
        'MNG' || LPAD(((ROW_NUMBER() * 5) % 500 + 1)::TEXT, 4, '0') as reviewed_by,
        NOW() + interval '6 months' as valid_until,
        'ACTIVE' as status
      FROM generate_series(1, 6) s
    ) jsa
  ), '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION get_jsa_list(text) TO authenticated;

-- ════════════════════════════════════════════════════════════════
-- S6. P1 — kolom yang dipakai fungsi 136 tapi TIDAK ADA di DB aktual
--  * employees_master.jabatan (get_worker_profile, get_worker_status)
--  * get_hr_payroll: tulis ulang memakai kolom aktual hr_payroll
--    (periode/base_salary/allowance/deduction) dengan key JSON tetap.
-- ════════════════════════════════════════════════════════════════

ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS jabatan TEXT;

CREATE OR REPLACE FUNCTION get_hr_payroll(p_nrp TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN (SELECT COALESCE(
    jsonb_build_object('ok', TRUE, 'data', jsonb_agg(p.*)),
    jsonb_build_object('ok', TRUE, 'data', '[]'::jsonb)
  ) FROM (
    SELECT periode AS payroll_period,
           base_salary AS basic_salary,
           allowance AS allowances,
           deduction AS deductions,
           overtime_pay, net_salary, created_at
    FROM hr_payroll
    WHERE nrp = p_nrp
    ORDER BY created_at DESC
    LIMIT 12
  ) p);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION get_hr_payroll(text) TO authenticated;

-- ════════════════════════════════════════════════════════════════
-- S7. P1 — tabel yang dirujuk migrasi 160 tapi TIDAK ADA di DB
-- (auto_coaching/auto_learn/run_* akan error runtime tanpa ini)
-- ════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS hr_safety_incidents (
  id SERIAL PRIMARY KEY,
  nrp TEXT REFERENCES employees_master(nrp),
  incident_type TEXT,
  severity TEXT,
  status TEXT DEFAULT 'OPEN',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS hr_production (
  id SERIAL PRIMARY KEY,
  nrp TEXT REFERENCES employees_master(nrp),
  period TEXT,
  production_volume NUMERIC DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- id punya DEFAULT agar INSERT (nrp,title,message,type,created_at)
-- dari fungsi 160/168 tidak wajib menyertakan id.
CREATE TABLE IF NOT EXISTS notifications (
  id TEXT PRIMARY KEY DEFAULT encode(gen_random_bytes(8), 'hex'),
  nrp TEXT REFERENCES employees_master(nrp),
  title TEXT,
  message TEXT,
  type TEXT DEFAULT 'info',
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Kolom drift hr_attendance: fungsi 160 memakai overtime_approved
ALTER TABLE hr_attendance ADD COLUMN IF NOT EXISTS overtime_approved BOOLEAN;

-- ── Fix fungsi 160 agar cocok kolom aktual DB ──
-- run_monthly_kpi: hr_attendance.status -> status_hadir;
--                  hr_performance.periode (bukan period) + tanpa
--                  kolom skor yg tak ada; anti-duplikat tanpa UNIQUE.
CREATE OR REPLACE FUNCTION run_monthly_kpi(p_period TEXT)
RETURNS JSONB AS $$
DECLARE
  v_count INT := 0; v_emp RECORD;
  v_kpi NUMERIC; v_att NUMERIC; v_prod NUMERIC; v_safe NUMERIC;
BEGIN
  FOR v_emp IN SELECT em.nrp, em.nama FROM employees_master em WHERE em.is_active = true LOOP
    SELECT COALESCE(ROUND(SUM(CASE WHEN status_hadir='Hadir' THEN 1 ELSE 0 END)::NUMERIC/NULLIF(COUNT(*),0)*100,2),0)
    INTO v_att FROM hr_attendance WHERE nrp=v_emp.nrp AND date_trunc('month',date::date)=date_trunc('month',p_period::date);
    v_prod := 75;
    SELECT GREATEST(0,100-COUNT(*)*10) INTO v_safe FROM hr_safety_incidents WHERE nrp=v_emp.nrp;
    v_kpi := ROUND((v_att*0.4+v_prod*0.35+v_safe*0.25),2);
    IF EXISTS (SELECT 1 FROM hr_performance WHERE nrp=v_emp.nrp AND periode=p_period) THEN
      UPDATE hr_performance SET kpi_score=v_kpi WHERE nrp=v_emp.nrp AND periode=p_period;
    ELSE
      INSERT INTO hr_performance (nrp,periode,kpi_score,created_at)
      VALUES (v_emp.nrp,p_period,v_kpi,NOW());
    END IF;
    v_count := v_count + 1;
  END LOOP;
  INSERT INTO audit_log (action,detail,timestamp) VALUES ('KPI_MONTHLY','Period: '||p_period||', processed: '||v_count,NOW());
  RETURN jsonb_build_object('ok',true,'period',p_period,'processed',v_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- run_daily_intelligence: a.status -> a.status_hadir
CREATE OR REPLACE FUNCTION run_daily_intelligence()
RETURNS JSONB AS $$
DECLARE v_count INT:=0; v_emp RECORD; v_flight NUMERIC; v_cert RECORD;
BEGIN
  FOR v_emp IN SELECT em.nrp,em.nama,
    COALESCE(ROUND(SUM(CASE WHEN status_hadir!='Hadir' THEN 1 ELSE 0 END)::NUMERIC/NULLIF(COUNT(*),0)*100,2),0) AS abs_rate,
    COALESCE((SELECT kpi_score FROM hr_performance WHERE nrp=em.nrp ORDER BY periode DESC LIMIT 1),70) AS last_kpi
  FROM employees_master em LEFT JOIN hr_attendance a ON a.nrp=em.nrp AND a.date>=(NOW()-INTERVAL '90 days')::date
  WHERE em.is_active=true GROUP BY em.nrp,em.nama LOOP
    v_flight:=LEAST(100,(v_emp.abs_rate*0.6)+((100-v_emp.last_kpi)*0.4));
    IF v_flight>60 THEN
      INSERT INTO notifications (nrp,title,message,type,created_at)
      VALUES (v_emp.nrp,'Flight Risk Warning','Risk: '||ROUND(v_flight)||'%','warning',NOW());
      v_count:=v_count+1;
    END IF;
  END LOOP;
  FOR v_cert IN SELECT em.nrp,em.sertifikasi_pekerja,em.masa_berlaku_sertifikasi
  FROM employees_master em WHERE em.is_active=true AND em.masa_berlaku_sertifikasi IS NOT NULL
    AND em.masa_berlaku_sertifikasi<=(NOW()+INTERVAL '30 days')::date LOOP
    INSERT INTO notifications (nrp,title,message,type,created_at)
    VALUES (v_cert.nrp,'Certificate Expiring',v_cert.sertifikasi_pekerja||' expires: '||v_cert.masa_berlaku_sertifikasi,
      CASE WHEN v_cert.masa_berlaku_sertifikasi<=NOW()::date THEN 'critical' ELSE 'warning' END,NOW());
    v_count:=v_count+1;
  END LOOP;
  INSERT INTO audit_log (action,detail,timestamp) VALUES ('DAILY_INTEL','Alerts: '||v_count,NOW());
  RETURN jsonb_build_object('ok',true,'alerts',v_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- run_monthly_intelligence: hr_payroll.period -> periode
CREATE OR REPLACE FUNCTION run_monthly_intelligence()
RETURNS JSONB AS $$
DECLARE v_ot NUMERIC; v_gap INT;
BEGIN
  SELECT COALESCE(SUM(overtime_pay)/NULLIF(SUM(production_volume),0),0) INTO v_ot
  FROM hr_payroll p LEFT JOIN hr_production pr ON pr.nrp=p.nrp AND pr.period=p.periode
  WHERE p.periode=to_char(NOW()-INTERVAL '1 month','YYYY-MM');
  SELECT COUNT(*) INTO v_gap FROM employees_master em WHERE em.is_active=false AND em.resign_date>(NOW()-INTERVAL '3 month')::date;
  INSERT INTO audit_log (action,detail,timestamp) VALUES ('MONTHLY_INTEL','OT/ton: '||v_ot||', gaps: '||v_gap,NOW());
  RETURN jsonb_build_object('ok',true,'ot_cost_per_ton',v_ot,'talent_gap',v_gap);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- auto_reject_ot: hr_payroll.period -> periode (overtime_approved kini ada)
CREATE OR REPLACE FUNCTION auto_reject_ot()
RETURNS JSONB AS $$
DECLARE v_rejected INT:=0; v_rec RECORD;
BEGIN
  FOR v_rec IN SELECT nrp,SUM(overtime_pay) AS total_ot FROM hr_payroll
    WHERE periode=to_char(NOW(),'YYYY-MM') GROUP BY nrp
    HAVING SUM(overtime_pay)>COALESCE((SELECT (config_value->>'value')::NUMERIC*0.9 FROM company_config WHERE config_key='budget_ot_monthly'),999999999)
  LOOP
    UPDATE hr_attendance SET overtime_approved=false WHERE nrp=v_rec.nrp AND overtime_approved IS NULL;
    v_rejected:=v_rejected+1;
  END LOOP;
  INSERT INTO audit_log (action,detail,timestamp) VALUES ('AUTO_REJECT_OT','Rejected: '||v_rejected,NOW());
  RETURN jsonb_build_object('ok',true,'rejected',v_rejected);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ════════════════════════════════════════════════════════════════
-- S8. P1 — 8 RPC cron (dipanggil cron-handler / gas-migration)
-- GRANT ke authenticated (konvensi) + service_role (caller cron)
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION calculate_monthly_kpi(p_period TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN run_monthly_kpi(p_period);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION run_early_detection()
RETURNS JSONB AS $$
BEGIN
  RETURN run_daily_intelligence();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION run_auto_healing()
RETURNS JSONB AS $$
BEGIN
  RETURN auto_reject_ot();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION check_pkwt_expiry(p_days_before INT DEFAULT 90)
RETURNS JSONB AS $$
DECLARE v_count INT := 0; v_emp RECORD;
BEGIN
  FOR v_emp IN SELECT nrp, nama, contract_end_date FROM employees_master
    WHERE is_active = true AND contract_end_date IS NOT NULL
      AND contract_end_date <= (NOW() + make_interval(days => p_days_before))::date
  LOOP
    INSERT INTO notifications (nrp,title,message,type,created_at)
    VALUES (v_emp.nrp, 'PKWT Expiring', 'Kontrak berakhir: ' || v_emp.contract_end_date, 'warning', NOW());
    v_count := v_count + 1;
  END LOOP;
  INSERT INTO audit_log (action,detail,timestamp) VALUES ('PKWT_CHECK','Expiring: '||v_count,NOW());
  RETURN jsonb_build_object('ok',true,'count',v_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION generate_attendance_summary(p_date TEXT)
RETURNS JSONB AS $$
DECLARE v_total INT := 0; v_hadir INT := 0;
BEGIN
  SELECT COUNT(*) INTO v_total FROM hr_attendance WHERE date = p_date::date;
  SELECT COUNT(*) INTO v_hadir FROM hr_attendance WHERE date = p_date::date AND status_hadir = 'Hadir';
  INSERT INTO audit_log (action,detail,timestamp) VALUES ('ATT_SUMMARY',p_date||': '||v_hadir||'/'||v_total,NOW());
  RETURN jsonb_build_object('ok',true,'date',p_date,'hadir',v_hadir,'total',v_total);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION calculate_workforce_health()
RETURNS JSONB AS $$
DECLARE v_att NUMERIC := 0; v_active INT := 0; v_total INT := 0; v_health NUMERIC := 0;
BEGIN
  SELECT COALESCE(ROUND(AVG(rate)*100,1),0) INTO v_att FROM (
    SELECT nrp, AVG(CASE WHEN status_hadir='Hadir' THEN 1 ELSE 0 END) AS rate
    FROM hr_attendance WHERE date >= (NOW()-INTERVAL '90 days')::date GROUP BY nrp
  ) t;
  SELECT COUNT(*) FILTER (WHERE is_active) INTO v_active FROM employees_master;
  SELECT COUNT(*) INTO v_total FROM employees_master;
  IF v_total > 0 THEN
    v_health := ROUND(v_att*0.7 + (v_active::NUMERIC/v_total*100)*0.3, 1);
  END IF;
  RETURN jsonb_build_object('ok',true,'attendance_rate',v_att,'active_ratio',v_total, 'health_score',v_health);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION process_payroll_batch(p_period TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN calculate_all_payroll(p_period);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION cleanup_expired_otps()
RETURNS JSONB AS $$
DECLARE v_deleted INT;
BEGIN
  DELETE FROM otp_store WHERE expiry < NOW();
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  INSERT INTO audit_log (action,detail,timestamp) VALUES ('OTP_CLEANUP','Deleted: '||v_deleted,NOW());
  RETURN jsonb_build_object('ok',true,'deleted',v_deleted);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION calculate_monthly_kpi(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION run_early_detection() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION run_auto_healing() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION check_pkwt_expiry(integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION generate_attendance_summary(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION calculate_workforce_health() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION process_payroll_batch(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION cleanup_expired_otps() TO authenticated, service_role;