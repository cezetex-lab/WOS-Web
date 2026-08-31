-- ============================================================
-- 055_mining_estate_rpcs.sql — RPC functions for Mining & Estate
-- ============================================================

-- ==================== MINING RPCs ====================

-- 1. SIMPER (Surat Izin Masuk Pertambangan)
CREATE OR REPLACE FUNCTION get_simper_list(
  p_nrp TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
BEGIN
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'id', sm.id,
      'nrp', sm.nrp,
      'worker_name', COALESCE(em.full_name, sm.nrp),
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
$$ LANGUAGE plpgsql;

-- 2. Heavy Equipment Monitor
CREATE OR REPLACE FUNCTION get_heavy_equipment(
  p_nrp TEXT DEFAULT NULL
)
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
$$ LANGUAGE plpgsql;

-- 3. Fatigue Monitor
CREATE OR REPLACE FUNCTION get_fatigue_data(
  p_nrp TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
BEGIN
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'id', fd.id,
      'nrp', fd.nrp,
      'worker_name', COALESCE(em.full_name, fd.nrp),
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
$$ LANGUAGE plpgsql;

-- 4. Production Daily
CREATE OR REPLACE FUNCTION get_production_daily(
  p_nrp TEXT DEFAULT NULL
)
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
$$ LANGUAGE plpgsql;

-- 5. Safety K3 Incidents
CREATE OR REPLACE FUNCTION get_safety_incidents(
  p_nrp TEXT DEFAULT NULL
)
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
      'reporter_name', COALESCE(em.full_name, si.reported_by),
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
$$ LANGUAGE plpgsql;

-- 6. JSA (Job Safety Analysis)
CREATE OR REPLACE FUNCTION get_jsa_list(
  p_nrp TEXT DEFAULT NULL
)
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
        (ARRAY['Use PPE + spotters','Speed limit + mirrors','Respirator required','Ear plugs mandatory','Hydration break every 
