-- ================================================================
-- 176_fix_rownum_and_pgcrypto_path.sql
-- Fixes 2 root causes found by 175_smoke_tests.sql (12 failures):
--
--  T1. P0: login_worker / change_password / create_worker_request
--      declare `SET search_path = public` (set at creation in 168),
--      so migration 174's "fix functions with NO search_path" sweep
--      skipped them (they DID have a search_path — just an
--      incomplete one). None of them include the `extensions`
--      schema, where pgcrypto lives, so every call to
--      crypt()/digest()/gen_salt()/gen_random_bytes() inside them
--      fails at runtime with "function ... does not exist".
--      175 only caught this on create_worker_request (C6) because
--      it's the only one of the three actually invoked in the
--      smoke suite — login_worker/change_password were only
--      existence-checked (A2/A3/A5), so they carry the same bug
--      untested. Fix: extend search_path on all three.
--
--  T2. P1: get_simper_list, get_heavy_equipment, get_fatigue_data,
--      get_production_daily, get_safety_incidents, get_jsa_list
--      (all from 168 S5) call `ROW_NUMBER()` a second time (without
--      an OVER clause) to derive pseudo-random columns from the row
--      index — only the first, aliased-as-id call has OVER(). This
--      is invalid: every window-function call needs its own OVER(),
--      you cannot reference an earlier one's value implicitly.
--      Fix: compute ROW_NUMBER() OVER () once in an inner subquery
--      and reuse that value (rn) in the outer SELECT list.
--      Verified against a local Postgres 16 + pgcrypto reproduction.
--
-- Idempotent: safe to re-run (CREATE OR REPLACE / ALTER).
-- ================================================================

-- ════════════════════════════════════════════════════════════════
-- T1. Extend search_path to include `extensions` (pgcrypto)
-- ════════════════════════════════════════════════════════════════

ALTER FUNCTION login_worker(text, text, text) SET search_path = public, extensions;
ALTER FUNCTION change_password(text, text, text) SET search_path = public, extensions;
ALTER FUNCTION create_worker_request(text, text, text, text) SET search_path = public, extensions;

-- ════════════════════════════════════════════════════════════════
-- T2. Fix ROW_NUMBER() reuse in the 6 mining stub functions
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
      SELECT rn AS id, nrp,
        CASE (rn % 5) WHEN 0 THEN 'Pit A' WHEN 1 THEN 'Pit B' WHEN 2 THEN 'Haul Road 1' WHEN 3 THEN 'Crusher Zone' ELSE 'Stockpile' END as zone,
        NOW() - (random() * interval '8 hours') as entry_time,
        CASE WHEN random() > 0.3 THEN NOW() - (random() * interval '2 hours') ELSE NULL END as exit_time,
        CASE WHEN random() > 0.3 THEN 'COMPLETED' ELSE 'ACTIVE' END as status,
        NOW() + interval '12 hours' as valid_until
      FROM (
        SELECT ROW_NUMBER() OVER () as rn, nrp
        FROM employees_master
        WHERE business_unit = 'MINING'
          AND (p_nrp IS NULL OR nrp = p_nrp)
        ORDER BY random()
        LIMIT 20
      ) base
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
      SELECT rn as id,
        'EQ-' || LPAD(rn::TEXT, 3, '0') as equipment_id,
        (ARRAY['Excavator CAT 320','Dump Truck 789D','Bulldozer D6T','Wheel Loader 966M','Drill Rig PV-271','Motor Grader 16M'])[1 + rn % 6] as equipment_type,
        (ARRAY['OPERATIONAL','MAINTENANCE','IDLE','STANDBY'])[1 + rn % 4] as status,
        (ARRAY['Pit A - Level 3','Haul Road Main','Crusher Station','Stockpile Zone 2','Workshop Area'])[1 + rn % 5] as location,
        'MNG' || LPAD(((rn * 7) % 500 + 1)::TEXT, 4, '0') as operator,
        (2000 + rn * 150)::INT as hours_run,
        (40 + rn * 5) % 100 as fuel_level,
        NOW() + (random() * interval '30 days') as next_maintenance
      FROM (
        SELECT ROW_NUMBER() OVER () as rn FROM generate_series(1, 12) s
      ) base
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
      SELECT rn as id,
        'MNG' || LPAD(((rn * 3) % 500 + 1)::TEXT, 4, '0') as nrp,
        (ARRAY['Shift Pagi','Shift Sore','Shift Malam'])[1 + rn % 3] as shift,
        (6 + rn % 8) as hours_worked,
        (ARRAY['LOW','MEDIUM','HIGH','CRITICAL'])[1 + rn % 4] as fatigue_level,
        (16 - 6 - rn % 8) as rest_hours,
        CASE WHEN rn % 4 = 0 THEN 'NEEDS_REST' ELSE 'OK' END as status,
        NOW() - (random() * interval '2 hours') as last_check
      FROM (
        SELECT ROW_NUMBER() OVER () as rn FROM generate_series(1, 15) s
      ) base
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
      SELECT rn as id,
        (ARRAY['Pit A - Lvl 1','Pit A - Lvl 2','Pit B - Lvl 1','Pit B - Lvl 2','Haul Road','Crusher','Stockpile'])[1 + rn % 7] as zone,
        (200 + rn * 50)::INT as target_tonase,
        (150 + rn * 40 + rn * 10)::INT as actual_tonase,
        ROUND((150 + rn * 40 + rn * 10)::NUMERIC / (200 + rn * 50) * 100, 1) as progress_pct,
        (8 + rn % 12) as operator_count,
        (3 + rn % 5) as equipment_count,
        CASE WHEN rn % 3 = 0 THEN 'COMPLETED' WHEN rn % 3 = 1 THEN 'IN_PROGRESS' ELSE 'PENDING' END as status,
        (ARRAY['Pagi','Sore','Malam'])[1 + rn % 3] as shift
      FROM (
        SELECT ROW_NUMBER() OVER () as rn FROM generate_series(1, 7) s
      ) base
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
      SELECT rn as id,
        (ARRAY['Near Miss','First Aid','Medical Treatment','Lost Time','Property Damage'])[1 + rn % 5] as incident_type,
        (ARRAY['LOW','MEDIUM','HIGH','CRITICAL'])[1 + rn % 4] as severity,
        (ARRAY['Pit A','Pit B','Haul Road','Crusher','Stockpile','Workshop'])[1 + rn % 6] as location,
        (ARRAY['Slip on wet surface','Equipment near miss','Falling debris','Fatigue-related','Chemical exposure'])[1 + rn % 5] as description,
        'MNG' || LPAD(((rn * 5) % 500 + 1)::TEXT, 4, '0') as reported_by,
        CASE WHEN rn % 3 = 0 THEN 'RESOLVED' WHEN rn % 3 = 1 THEN 'INVESTIGATING' ELSE 'OPEN' END as status,
        NOW() - (random() * interval '30 days') as reported_at,
        (ARRAY['Zone A','Zone B','Zone C','Zone D'])[1 + rn % 4] as zone
      FROM (
        SELECT ROW_NUMBER() OVER () as rn FROM generate_series(1, 10) s
      ) base
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
      SELECT rn as id,
        (ARRAY['Blasting Operation','Hauling Coal','Excavation Level 3','Crusher Maintenance','Night Shift Patrol','Fuel Delivery'])[1 + rn % 6] as job_name,
        (ARRAY['Falling rocks','Equipment collision','Dust exposure','Noise exposure','Heat stress','Ground instability'])[1 + rn % 6] as hazard,
        (ARRAY['LOW','MEDIUM','HIGH','CRITICAL'])[1 + rn % 4] as risk_level,
        (ARRAY['Use PPE + spotters','Speed limit + mirrors','Respirator required','Ear plugs mandatory','Hydration break every 30min'])[1 + rn % 5] as control_measure,
        'MNG' || LPAD(((rn * 5) % 500 + 1)::TEXT, 4, '0') as reviewed_by,
        NOW() + interval '6 months' as valid_until,
        'ACTIVE' as status
      FROM (
        SELECT ROW_NUMBER() OVER () as rn FROM generate_series(1, 6) s
      ) base
    ) jsa
  ), '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION get_jsa_list(text) TO authenticated;

-- ════════════════════════════════════════════════════════════════
-- Verify
-- ════════════════════════════════════════════════════════════════

SELECT 'VERIFY: create_worker_request callable (pgcrypto reachable)' AS test,
  CASE WHEN create_worker_request('TEST','LEAVE','test','test') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'VERIFY: get_simper_list callable' AS test,
  CASE WHEN get_simper_list('TEST') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'VERIFY: get_heavy_equipment callable' AS test,
  CASE WHEN get_heavy_equipment('TEST') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'VERIFY: get_fatigue_data callable' AS test,
  CASE WHEN get_fatigue_data('TEST') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'VERIFY: get_production_daily callable' AS test,
  CASE WHEN get_production_daily('TEST') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'VERIFY: get_safety_incidents callable' AS test,
  CASE WHEN get_safety_incidents('TEST') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'VERIFY: get_jsa_list callable' AS test,
  CASE WHEN get_jsa_list('TEST') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result;
