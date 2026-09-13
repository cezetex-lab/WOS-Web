-- ================================================================
-- 208_industry_tables_and_rpcs.sql — Tahap 5.4 (A10 data palsu/fallback)
--
-- Fix: CREATE 6 backing tables + CREATE OR REPLACE 6 RPCs.
-- All tables match existing conventions (id text PK, business_unit_id,
-- created_at, CHECK constraints per forensic §3).
-- RPCs return {ok: true, data: [...]} — empty array when no rows.
-- Rollback: supabase/migrations/rollback/208_rollback.sql
-- ================================================================

-- ══════════════════════════════════════════════════════════════
-- 1. CREATE TABLES
-- ══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS safety_incidents (
  id            TEXT PRIMARY KEY,
  incident_date DATE NOT NULL DEFAULT CURRENT_DATE,
  zone          TEXT NOT NULL,
  incident_type TEXT NOT NULL DEFAULT 'INCIDENT',
  severity      TEXT NOT NULL DEFAULT 'MEDIUM',
  description   TEXT NOT NULL,
  reporter_nrp  TEXT NOT NULL,
  status        TEXT NOT NULL DEFAULT 'OPEN',
  action_taken  TEXT,
  business_unit_id TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS jsa_data (
  id            TEXT PRIMARY KEY,
  job           TEXT NOT NULL,
  area          TEXT NOT NULL,
  risk_level    TEXT NOT NULL DEFAULT 'MEDIUM',
  hazards       TEXT[] NOT NULL DEFAULT '{}',
  controls      TEXT[] NOT NULL DEFAULT '{}',
  status        TEXT NOT NULL DEFAULT 'ACTIVE',
  prepared_by   TEXT NOT NULL,
  valid_until   DATE,
  business_unit_id TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS production_daily (
  id              SERIAL PRIMARY KEY,
  record_date     DATE NOT NULL DEFAULT CURRENT_DATE,
  zone            TEXT NOT NULL,
  product         TEXT NOT NULL,
  target_qty      NUMERIC NOT NULL DEFAULT 0,
  actual_qty      NUMERIC NOT NULL DEFAULT 0,
  unit            TEXT NOT NULL DEFAULT 'ton',
  operator_count  INTEGER NOT NULL DEFAULT 0,
  shift           TEXT NOT NULL DEFAULT 'Pagi',
  business_unit_id TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS heavy_equipment (
  id              TEXT PRIMARY KEY,
  equipment_type  TEXT NOT NULL,
  brand           TEXT NOT NULL,
  status          TEXT NOT NULL DEFAULT 'OPERATIONAL',
  operator_nrp    TEXT,
  zone            TEXT NOT NULL,
  hours_run       NUMERIC NOT NULL DEFAULT 0,
  fuel_level      NUMERIC NOT NULL DEFAULT 100,
  next_service    TEXT,
  business_unit_id TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS fatigue_data (
  id              SERIAL PRIMARY KEY,
  nrp             TEXT NOT NULL,
  nama            TEXT NOT NULL,
  shift           TEXT NOT NULL DEFAULT 'Pagi',
  hours_worked    NUMERIC NOT NULL DEFAULT 0,
  hours_rest      NUMERIC NOT NULL DEFAULT 8,
  fatigue_level   TEXT NOT NULL DEFAULT 'LOW',
  status          TEXT NOT NULL DEFAULT 'FIT',
  last_check      TEXT,
  business_unit_id TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS simper_data (
  id            TEXT PRIMARY KEY,
  nrp           TEXT NOT NULL,
  zone          TEXT NOT NULL,
  purpose       TEXT NOT NULL,
  status        TEXT NOT NULL DEFAULT 'ACTIVE',
  valid_until   DATE NOT NULL,
  issued_by     TEXT NOT NULL DEFAULT 'Safety Manager',
  business_unit_id TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ══════════════════════════════════════════════════════════════
-- 2. CHECK CONSTRAINTS
-- ══════════════════════════════════════════════════════════════

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='safety_incidents_type_chk') THEN
    ALTER TABLE safety_incidents ADD CONSTRAINT safety_incidents_type_chk
      CHECK (incident_type = ANY(ARRAY['NEAR_MISS','INCIDENT','OBSERVATION']));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='safety_incidents_severity_chk') THEN
    ALTER TABLE safety_incidents ADD CONSTRAINT safety_incidents_severity_chk
      CHECK (severity = ANY(ARRAY['LOW','MEDIUM','HIGH','CRITICAL']));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='safety_incidents_status_chk') THEN
    ALTER TABLE safety_incidents ADD CONSTRAINT safety_incidents_status_chk
      CHECK (status = ANY(ARRAY['OPEN','INVESTIGATING','CLOSED']));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='jsa_data_risk_chk') THEN
    ALTER TABLE jsa_data ADD CONSTRAINT jsa_data_risk_chk
      CHECK (risk_level = ANY(ARRAY['LOW','MEDIUM','HIGH','CRITICAL']));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='jsa_data_status_chk') THEN
    ALTER TABLE jsa_data ADD CONSTRAINT jsa_data_status_chk
      CHECK (status = ANY(ARRAY['ACTIVE','EXPIRED','DRAFT']));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='heavy_equipment_status_chk') THEN
    ALTER TABLE heavy_equipment ADD CONSTRAINT heavy_equipment_status_chk
      CHECK (status = ANY(ARRAY['OPERATIONAL','MAINTENANCE','IDLE','BREAKDOWN']));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fatigue_data_level_chk') THEN
    ALTER TABLE fatigue_data ADD CONSTRAINT fatigue_data_level_chk
      CHECK (fatigue_level = ANY(ARRAY['LOW','MEDIUM','HIGH','CRITICAL']));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fatigue_data_status_chk') THEN
    ALTER TABLE fatigue_data ADD CONSTRAINT fatigue_data_status_chk
      CHECK (status = ANY(ARRAY['FIT','CAUTION','REST REQUIRED']));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='simper_data_status_chk') THEN
    ALTER TABLE simper_data ADD CONSTRAINT simper_data_status_chk
      CHECK (status = ANY(ARRAY['ACTIVE','EXPIRED','REVOKED']));
  END IF;
END $$;

-- ══════════════════════════════════════════════════════════════
-- 3. RLS + GRANTS
-- ══════════════════════════════════════════════════════════════

DO $$ DECLARE t TEXT; BEGIN
  FOREACH t IN ARRAY ARRAY[
    'safety_incidents','jsa_data','production_daily',
    'heavy_equipment','fatigue_data','simper_data'
  ] LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename=t AND policyname='select_auth') THEN
      EXECUTE format('CREATE POLICY select_auth ON %I FOR SELECT TO authenticated USING (true)', t);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename=t AND policyname='all_service') THEN
      EXECUTE format('CREATE POLICY all_service ON %I FOR ALL TO service_role USING (true) WITH CHECK (true)', t);
    END IF;
    EXECUTE format('GRANT SELECT ON %I TO authenticated', t);
    EXECUTE format('GRANT ALL ON %I TO service_role', t);
  END LOOP;
END $$;

-- ══════════════════════════════════════════════════════════════
-- 4. REWRITE RPCs (CREATE OR REPLACE — subquery pattern)
-- ══════════════════════════════════════════════════════════════

-- 4a. get_safety_incidents
CREATE OR REPLACE FUNCTION public.get_safety_incidents(p_nrp text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN jsonb_build_object('ok', true, 'data', COALESCE((
    SELECT jsonb_agg(sub)
    FROM (
      SELECT jsonb_build_object(
        'id', si.id, 'date', si.incident_date, 'zone', si.zone,
        'type', si.incident_type, 'severity', si.severity,
        'description', si.description, 'reporter', si.reporter_nrp,
        'status', si.status, 'action_taken', si.action_taken
      ) as sub
      FROM safety_incidents si
      WHERE (p_nrp IS NULL OR si.reporter_nrp = p_nrp)
      ORDER BY si.incident_date DESC
    ) t
  ), '[]'::jsonb));
END;
$function$;

-- 4b. get_jsa_list
CREATE OR REPLACE FUNCTION public.get_jsa_list(p_nrp text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN jsonb_build_object('ok', true, 'data', COALESCE((
    SELECT jsonb_agg(sub)
    FROM (
      SELECT jsonb_build_object(
        'id', j.id, 'job', j.job, 'area', j.area,
        'risk_level', j.risk_level, 'hazards', j.hazards,
        'controls', j.controls, 'status', j.status,
        'prepared_by', j.prepared_by, 'valid_date', j.valid_until
      ) as sub
      FROM jsa_data j
      WHERE (p_nrp IS NULL OR j.prepared_by = p_nrp)
      ORDER BY j.created_at DESC
    ) t
  ), '[]'::jsonb));
END;
$function$;

-- 4c. get_production_daily
CREATE OR REPLACE FUNCTION public.get_production_daily(p_nrp text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN jsonb_build_object('ok', true, 'data', COALESCE((
    SELECT jsonb_agg(sub)
    FROM (
      SELECT jsonb_build_object(
        'zone', pd.zone, 'product', pd.product,
        'target', pd.target_qty, 'actual', pd.actual_qty,
        'unit', pd.unit, 'operator_count', pd.operator_count
      ) as sub
      FROM production_daily pd
      WHERE pd.record_date = CURRENT_DATE
      ORDER BY pd.zone
    ) t
  ), '[]'::jsonb));
END;
$function$;

-- 4d. get_heavy_equipment
CREATE OR REPLACE FUNCTION public.get_heavy_equipment(p_nrp text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN jsonb_build_object('ok', true, 'data', COALESCE((
    SELECT jsonb_agg(sub)
    FROM (
      SELECT jsonb_build_object(
        'id', he.id, 'type', he.equipment_type, 'brand', he.brand,
        'status', he.status, 'operator', he.operator_nrp,
        'zone', he.zone, 'hours', he.hours_run,
        'fuel_level', he.fuel_level, 'next_service', he.next_service
      ) as sub
      FROM heavy_equipment he
      WHERE (p_nrp IS NULL OR he.operator_nrp = p_nrp)
      ORDER BY he.zone
    ) t
  ), '[]'::jsonb));
END;
$function$;

-- 4e. get_fatigue_data
CREATE OR REPLACE FUNCTION public.get_fatigue_data(p_nrp text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN jsonb_build_object('ok', true, 'data', COALESCE((
    SELECT jsonb_agg(sub)
    FROM (
      SELECT jsonb_build_object(
        'nrp', fd.nrp, 'name', fd.nama, 'shift', fd.shift,
        'hours_worked', fd.hours_worked, 'hours_rest', fd.hours_rest,
        'fatigue_level', fd.fatigue_level, 'status', fd.status,
        'last_check', fd.last_check
      ) as sub
      FROM fatigue_data fd
      WHERE (p_nrp IS NULL OR fd.nrp = p_nrp)
      ORDER BY fd.fatigue_level DESC, fd.nama
    ) t
  ), '[]'::jsonb));
END;
$function$;

-- 4f. get_simper_list
CREATE OR REPLACE FUNCTION public.get_simper_list(p_nrp text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN jsonb_build_object('ok', true, 'data', COALESCE((
    SELECT jsonb_agg(sub)
    FROM (
      SELECT jsonb_build_object(
        'id', sd.id, 'nrp', sd.nrp, 'zone', sd.zone,
        'purpose', sd.purpose, 'status', sd.status,
        'valid_until', sd.valid_until, 'issued_by', sd.issued_by
      ) as sub
      FROM simper_data sd
      WHERE (p_nrp IS NULL OR sd.nrp = p_nrp)
      ORDER BY sd.valid_until DESC
    ) t
  ), '[]'::jsonb));
END;
$function$;

-- ══════════════════════════════════════════════════════════════
-- 5. VERIFY
-- ══════════════════════════════════════════════════════════════

SELECT '208.1 tables created' AS test,
  CASE WHEN (SELECT count(*) FROM information_schema.tables
    WHERE table_schema='public' AND table_name IN (
      'safety_incidents','jsa_data','production_daily',
      'heavy_equipment','fatigue_data','simper_data'
    )) = 6 THEN 'PASS' ELSE 'FAIL' END AS result;

-- All 6 RPCs return {ok: true, data: []} for empty tables
SELECT '208.2 get_safety_incidents' AS test, (get_safety_incidents()) AS result;
SELECT '208.3 get_jsa_list' AS test, (get_jsa_list()) AS result;
SELECT '208.4 get_production_daily' AS test, (get_production_daily()) AS result;
SELECT '208.5 get_heavy_equipment' AS test, (get_heavy_equipment()) AS result;
SELECT '208.6 get_fatigue_data' AS test, (get_fatigue_data()) AS result;
SELECT '208.7 get_simper_list' AS test, (get_simper_list()) AS result;
