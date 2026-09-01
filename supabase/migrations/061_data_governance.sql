-- ============================================================
-- Migration 061: Data Governance
-- Phase 4: effective_date, status columns, missing RPCs
-- ============================================================

-- 1. Master Table Enhancements

ALTER TABLE sites ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'ACTIVE';
ALTER TABLE sites ADD COLUMN IF NOT EXISTS effective_from DATE DEFAULT CURRENT_DATE;
ALTER TABLE sites ADD COLUMN IF NOT EXISTS effective_to DATE;
ALTER TABLE bu_divisions ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'ACTIVE';
ALTER TABLE bu_divisions ADD COLUMN IF NOT EXISTS effective_from DATE DEFAULT CURRENT_DATE;
ALTER TABLE bu_divisions ADD COLUMN IF NOT EXISTS effective_to DATE;
ALTER TABLE bu_divisions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE business_units ADD COLUMN IF NOT EXISTS effective_from DATE DEFAULT CURRENT_DATE;
ALTER TABLE business_units ADD COLUMN IF NOT EXISTS effective_to DATE;
ALTER TABLE hr_org ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'ACTIVE';
ALTER TABLE hr_org ADD COLUMN IF NOT EXISTS effective_from DATE DEFAULT CURRENT_DATE;
ALTER TABLE hr_org ADD COLUMN IF NOT EXISTS effective_to DATE;
ALTER TABLE hr_org ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE hr_org ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 2. Tables (if not exists)

CREATE SEQUENCE IF NOT EXISTS harvest_seq START 1;
CREATE SEQUENCE IF NOT EXISTS dispatch_seq START 1;

CREATE TABLE IF NOT EXISTS harvest_records (
  id TEXT PRIMARY KEY DEFAULT ('HVT-' || lpad(nextval('harvest_seq')::TEXT, 3, '0')),
  block TEXT NOT NULL,
  harvest_date DATE NOT NULL DEFAULT CURRENT_DATE,
  weight_kg NUMERIC(10,2) NOT NULL,
  ripe_pct NUMERIC(5,1),
  worker_nrp TEXT REFERENCES employees_master(nrp),
  quality TEXT DEFAULT 'A',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS transport_dispatch (
  id TEXT PRIMARY KEY DEFAULT ('DSP-' || lpad(nextval('dispatch_seq')::TEXT, 3, '0')),
  truck_id TEXT NOT NULL,
  driver_nrp TEXT REFERENCES employees_master(nrp),
  from_block TEXT NOT NULL,
  weight_ton NUMERIC(8,2),
  status TEXT DEFAULT 'SCHEDULED',
  depart_time TIME,
  arrive_time TIME,
  destination TEXT DEFAULT 'MILL-01',
  dispatch_date DATE DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS workforce_simulations (
  id SERIAL PRIMARY KEY,
  nrp TEXT REFERENCES employees_master(nrp),
  scenario TEXT NOT NULL,
  params JSONB NOT NULL,
  result JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Seed Data: Harvest Records
INSERT INTO harvest_records (block, harvest_date, weight_kg, ripe_pct, worker_nrp, quality) VALUES
('BLOK-A1', CURRENT_DATE, 25000, 85, 'EST0001', 'A'),
('BLOK-A2', CURRENT_DATE, 22000, 78, 'EST0002', 'A'),
('BLOK-B1', CURRENT_DATE, 18000, 72, 'EST0003', 'B'),
('BLOK-B2', CURRENT_DATE, 28000, 90, 'EST0004', 'A'),
('BLOK-C1', CURRENT_DATE, 15000, 65, 'EST0005', 'B'),
('BLOK-C2', CURRENT_DATE, 20000, 75, 'EST0006', 'B'),
('BLOK-A1', CURRENT_DATE - INTERVAL '1 days', 24000, 82, 'EST0001', 'A'),
('BLOK-B1', CURRENT_DATE - INTERVAL '1 days', 19500, 74, 'EST0003', 'B'),
('BLOK-A2', CURRENT_DATE - INTERVAL '1 days', 23000, 80, 'EST0002', 'A'),
('BLOK-C1', CURRENT_DATE - INTERVAL '1 days', 17000, 68, 'EST0005', 'B'),
('BLOK-B2', CURRENT_DATE - INTERVAL '1 days', 27000, 88, 'EST0004', 'A'),
('BLOK-A1', CURRENT_DATE - INTERVAL '2 days', 26000, 86, 'EST0001', 'A'),
('BLOK-C2', CURRENT_DATE - INTERVAL '2 days', 21000, 76, 'EST0006', 'B'),
('BLOK-B1', CURRENT_DATE - INTERVAL '2 days', 18500, 71, 'EST0003', 'B'),
('BLOK-A2', CURRENT_DATE - INTERVAL '2 days', 24500, 83, 'EST0002', 'A'),
('BLOK-B2', CURRENT_DATE - INTERVAL '3 days', 29000, 92, 'EST0004', 'A'),
('BLOK-C1', CURRENT_DATE - INTERVAL '3 days', 16000, 66, 'EST0005', 'B'),
('BLOK-A1', CURRENT_DATE - INTERVAL '3 days', 23500, 81, 'EST0001', 'A'),
('BLOK-C2', CURRENT_DATE - INTERVAL '3 days', 20500, 74, 'EST0006', 'B'),
('BLOK-B1', CURRENT_DATE - INTERVAL '4 days', 19000, 73, 'EST0003', 'B'),
('BLOK-A2', CURRENT_DATE - INTERVAL '4 days', 25500, 84, 'EST0002', 'A'),
('BLOK-B2', CURRENT_DATE - INTERVAL '4 days', 27500, 89, 'EST0004', 'A'),
('BLOK-C1', CURRENT_DATE - INTERVAL '4 days', 15500, 64, 'EST0005', 'B'),
('BLOK-A1', CURRENT_DATE - INTERVAL '5 days', 26500, 87, 'EST0001', 'A'),
('BLOK-C2', CURRENT_DATE - INTERVAL '5 days', 21500, 77, 'EST0006', 'B')
ON CONFLICT DO NOTHING;

-- 4. Seed Data: Transport Dispatch
INSERT INTO transport_dispatch (truck_id, driver_nrp, from_block, weight_ton, status, depart_time, arrive_time, destination, dispatch_date) VALUES
('T-001', 'EST0002', 'BLOK-A1', 25, 'DELIVERED', '06:00', '07:30', 'MILL-01', CURRENT_DATE),
('T-002', 'EST0003', 'BLOK-B2', 28, 'IN_TRANSIT', '07:00', NULL, 'MILL-01', CURRENT_DATE),
('T-003', 'EST0004', 'BLOK-A2', 22, 'LOADING', NULL, NULL, 'MILL-01', CURRENT_DATE),
('T-001', 'EST0002', 'BLOK-C1', 20, 'SCHEDULED', NULL, NULL, 'MILL-01', CURRENT_DATE),
('T-004', 'EST0006', 'BLOK-C2', 24, 'DELIVERED', '05:30', '07:00', 'MILL-01', CURRENT_DATE),
('T-002', 'EST0003', 'BLOK-A1', 26, 'DELIVERED', '06:15', '07:45', 'MILL-01', CURRENT_DATE - INTERVAL '1 days'),
('T-003', 'EST0004', 'BLOK-B1', 19, 'DELIVERED', '06:30', '08:00', 'MILL-01', CURRENT_DATE - INTERVAL '1 days'),
('T-001', 'EST0002', 'BLOK-A2', 23, 'DELIVERED', '05:45', '07:15', 'MILL-01', CURRENT_DATE - INTERVAL '1 days'),
('T-004', 'EST0006', 'BLOK-C2', 21, 'IN_TRANSIT', '07:30', NULL, 'MILL-01', CURRENT_DATE - INTERVAL '2 days'),
('T-002', 'EST0003', 'BLOK-B2', 27, 'DELIVERED', '06:00', '07:30', 'MILL-01', CURRENT_DATE - INTERVAL '2 days'),
('T-001', 'EST0002', 'BLOK-A1', 25, 'DELIVERED', '06:10', '07:40', 'MILL-01', CURRENT_DATE - INTERVAL '3 days'),
('T-003', 'EST0004', 'BLOK-B1', 18, 'DELIVERED', '06:20', '07:50', 'MILL-01', CURRENT_DATE - INTERVAL '3 days'),
('T-004', 'EST0006', 'BLOK-C1', 16, 'DELIVERED', '06:30', '08:00', 'MILL-01', CURRENT_DATE - INTERVAL '3 days'),
('T-002', 'EST0003', 'BLOK-A2', 24, 'DELIVERED', '05:50', '07:20', 'MILL-01', CURRENT_DATE - INTERVAL '4 days'),
('T-001', 'EST0002', 'BLOK-B2', 28, 'DELIVERED', '06:05', '07:35', 'MILL-01', CURRENT_DATE - INTERVAL '4 days')
ON CONFLICT DO NOTHING;

-- 5. Seed Data: Workforce Simulations
INSERT INTO workforce_simulations (nrp, scenario, params, result) VALUES
('HQ0001', 'turnover', '{"turnover": 10, "hiring": 0, "budget": 0, "kpi": 0}', '{"projected_hc": 485, "cost_impact": -125000, "risk": "MEDIUM"}'),
('HQ0001', 'hiring', '{"turnover": 0, "hiring": 20, "budget": 10, "kpi": 0}', '{"projected_hc": 600, "cost_impact": 250000, "risk": "LOW"}'),
('HQ0001', 'budget', '{"turnover": 5, "hiring": -5, "budget": -15, "kpi": -5}', '{"projected_hc": 450, "cost_impact": -375000, "risk": "HIGH"}'),
('HQ0001', 'kpi', '{"turnover": -3, "hiring": 10, "budget": 5, "kpi": 15}', '{"projected_hc": 540, "cost_impact": 125000, "risk": "LOW"}'),
('HQ0001', 'status_quo', '{"turnover": 0, "hiring": 0, "budget": 0, "kpi": 0}', '{"projected_hc": 510, "cost_impact": 0, "risk": "LOW"}')
ON CONFLICT DO NOTHING;

-- 6. RPC: get_harvest_records

CREATE OR REPLACE FUNCTION get_harvest_records()
RETURNS JSONB AS $$
DECLARE
  v_records JSONB;
  v_summary JSONB;
  v_total_weight NUMERIC;
  v_avg_ripe NUMERIC;
BEGIN
  SELECT COALESCE(jsonb_agg(row_to_json(hr)), '[]'::jsonb)
  INTO v_records
  FROM (
    SELECT id, block, harvest_date AS date,
           weight_kg, ripe_pct, worker_nrp AS worker, quality
    FROM harvest_records
    WHERE harvest_date = CURRENT_DATE
    ORDER BY created_at DESC
  ) hr;

  SELECT COALESCE(SUM(weight_kg)/1000, 0), COALESCE(AVG(ripe_pct), 0)
  INTO v_total_weight, v_avg_ripe
  FROM harvest_records
  WHERE harvest_date = CURRENT_DATE;

  v_summary := jsonb_build_object(
    'total_ton', ROUND(v_total_weight::numeric, 1),
    'avg_ripe', ROUND(v_avg_ripe, 1),
    'target_ton', 180,
    'achievement', CASE WHEN 180 > 0 THEN ROUND((v_total_weight / 180) * 100, 0) ELSE 0 END
  );

  RETURN jsonb_build_object('ok', true, 'data', v_records, 'summary', v_summary);
END;
$$ LANGUAGE plpgsql STABLE;

-- 7. RPC: get_transport_dispatch

CREATE OR REPLACE FUNCTION get_transport_dispatch()
RETURNS JSONB AS $$
DECLARE
  v_dispatches JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(row_to_json(td)), '[]'::jsonb)
  INTO v_dispatches
  FROM (
    SELECT id, truck_id AS truck, driver_nrp AS driver,
           from_block AS "from", weight_ton, status,
           depart_time::TEXT AS depart, arrive_time::TEXT AS arrive,
           destination
    FROM transport_dispatch
    WHERE dispatch_date = CURRENT_DATE
    ORDER BY depart_time NULLS LAST
  ) td;

  RETURN jsonb_build_object('ok', true, 'data', v_dispatches);
END;
$$ LANGUAGE plpgsql STABLE;

-- 8. RPC: get_simulations

CREATE OR REPLACE FUNCTION get_simulations()
RETURNS JSONB AS $$
DECLARE
  v_sims JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(row_to_json(ws)), '[]'::jsonb)
  INTO v_sims
  FROM (
    SELECT id, scenario, params, result, created_at
    FROM workforce_simulations
    ORDER BY created_at DESC
    LIMIT 20
  ) ws;

  RETURN v_sims;
END;
$$ LANGUAGE plpgsql STABLE;

-- 9. Indexes

CREATE INDEX IF NOT EXISTS idx_harvest_date ON harvest_records(harvest_date);
CREATE INDEX IF NOT EXISTS idx_harvest_worker ON harvest_records(worker_nrp);
CREATE INDEX IF NOT EXISTS idx_dispatch_date ON transport_dispatch(dispatch_date);
CREATE INDEX IF NOT EXISTS idx_dispatch_status ON transport_dispatch(status);
CREATE INDEX IF NOT EXISTS idx_sites_status ON sites(status);
CREATE INDEX IF NOT EXISTS idx_bu_div_status ON bu_divisions(status);
CREATE INDEX IF NOT EXISTS idx_hr_org_status ON hr_org(status);
CREATE INDEX IF NOT EXISTS idx_simulation_nrp ON workforce_simulations(nrp);

-- 10. RLS

ALTER TABLE harvest_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE transport_dispatch ENABLE ROW LEVEL SECURITY;
ALTER TABLE workforce_simulations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "harvest_read" ON harvest_records FOR SELECT USING (true);
CREATE POLICY "transport_read" ON transport_dispatch FOR SELECT USING (true);
CREATE POLICY "simulations_read" ON workforce_simulations FOR SELECT USING (true);
