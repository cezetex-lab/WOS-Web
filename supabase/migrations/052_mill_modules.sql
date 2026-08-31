-- ============================================================
-- MIGRATION 052: MILL/PKS MODULES + BUSINESS UNIT STRUCTURE
-- Pabrik Kelapa Sawit — 7 modul operasional
-- ============================================================

-- ============================================================
-- 1. BUSINESS UNIT DIVISION STRUCTURE
-- ============================================================
CREATE TABLE IF NOT EXISTS bu_divisions (
  id SERIAL PRIMARY KEY,
  business_unit TEXT NOT NULL,
  division_code TEXT NOT NULL,
  division_name TEXT NOT NULL,
  description TEXT,
  head_nrp TEXT,
  UNIQUE(business_unit, division_code)
);

-- MINING Divisions
INSERT INTO bu_divisions (business_unit, division_code, division_name, description) VALUES
('MINING', 'OPR', 'Operasi Tambang', 'Drilling, blasting, excavating, hauling'),
('MINING', 'MTN', 'Maintenance', 'Perawatan alat berat & workshop'),
('MINING', 'SFL', 'Safety & Environment', 'K3, lingkungan, emergency response'),
('MINING', 'PLN', 'Planning', 'Mine planning, blasting schedule'),
('MINING', 'QTY', 'Quality & Control', 'Grade control, sampling, assay'),
('MINING', 'LGS', 'Logistics', 'Hauling, crushing, stockpile'),
('MINING', 'ADM', 'Administrasi', 'HR, finance, admin support')
ON CONFLICT (business_unit, division_code) DO NOTHING;

-- ESTATE Divisions
INSERT INTO bu_divisions (business_unit, division_code, division_name, description) VALUES
('ESTATE', 'HAR', 'Harvesting', 'Pemanenan TBS, transport kebun'),
('ESTATE', 'PLN', 'Planting', 'Penanaman, nursery, replanting'),
('ESTATE', 'FRT', 'Fertilizer', 'Pemupukan, soil analysis'),
('ESTATE', 'PST', 'Pest Control', 'Pengendalian hama & penyakit'),
('ESTATE', 'IRR', 'Irrigation', 'Pengairan, water management'),
('ESTATE', 'MNT', 'Maintenance', 'Perawatan mesin & fasilitas kebun'),
('ESTATE', 'TRN', 'Transport', 'Transport TBS ke pabrik'),
('ESTATE', 'ADM', 'Administrasi', 'HR, finance, admin support')
ON CONFLICT (business_unit, division_code) DO NOTHING;

-- MILL Divisions
INSERT INTO bu_divisions (business_unit, division_code, division_name, description) VALUES
('MILL', 'BRG', 'Boiler & Steam', 'Ketel uap, steam turbine, energi'),
('MILL', 'PRS', 'Pressing', 'Mesin press CPO, screw press'),
('MILL', 'QCL', 'QC Laboratory', 'Quality control, grading CPO'),
('MILL', 'PKG', 'Packing & Loading', 'Packing kernel, loading CPO'),
('MILL', 'MNT', 'Maintenance', 'Preventive & breakdown maintenance'),
('MILL', 'OPR', 'Operator', 'Operator produksi 3 shift'),
('MILL', 'ENV', 'Environment', 'Limbah, emisi, water treatment'),
('MILL', 'ADM', 'Administrasi', 'HR, finance, admin support')
ON CONFLICT (business_unit, division_code) DO NOTHING;

-- HQ Divisions
INSERT INTO bu_divisions (business_unit, division_code, division_name, description) VALUES
('HQ', 'HRD', 'Human Resource', 'Rekrutmen, training, compensation'),
('HQ', 'FIN', 'Finance & Accounting', 'Akuntansi, payroll, tax'),
('HQ', 'IT', 'Information Technology', 'Dev, infra, security'),
('HQ', 'LGL', 'Legal & Compliance', 'Kontrak, UU, regulatory'),
('HQ', 'OPS', 'Operations', 'Planning, procurement, logistics'),
('HQ', 'MKT', 'Marketing & Sales', 'Sales, marketing, CSR'),
('HQ', 'EXT', 'Executive', 'Director, VP, C-level')
ON CONFLICT (business_unit, division_code) DO NOTHING;

-- ============================================================
-- 2. MILL MODULE TABLES
-- ============================================================

-- 2a. Boiler Status (real-time monitoring)
CREATE TABLE IF NOT EXISTS mill_boiler (
  id SERIAL PRIMARY KEY,
  boiler_code TEXT NOT NULL UNIQUE,
  boiler_name TEXT NOT NULL,
  capacity_kg_hr NUMERIC DEFAULT 0,
  status TEXT DEFAULT 'OFFLINE' CHECK (status IN ('RUNNING','STANDBY','MAINTENANCE','OFFLINE')),
  temperature_c NUMERIC DEFAULT 0,
  pressure_bar NUMERIC DEFAULT 0,
  steam_flow_kg_hr NUMERIC DEFAULT 0,
  fuel_type TEXT DEFAULT 'BIOMASS',
  fuel_consumption_kg_hr NUMERIC DEFAULT 0,
  efficiency_pct NUMERIC DEFAULT 0,
  last_maintenance DATE,
  next_maintenance DATE,
  site_code TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2b. Mesin Press (screw press status)
CREATE TABLE IF NOT EXISTS mill_press (
  id SERIAL PRIMARY KEY,
  press_code TEXT NOT NULL UNIQUE,
  press_name TEXT NOT NULL,
  capacity_tph NUMERIC DEFAULT 0,
  status TEXT DEFAULT 'OFFLINE' CHECK (status IN ('RUNNING','STANDBY','MAINTENANCE','OFFLINE')),
  rpm NUMERIC DEFAULT 0,
  torque_nm NUMERIC DEFAULT 0,
  temperature_c NUMERIC DEFAULT 0,
  vibration_mm_s NUMERIC DEFAULT 0,
  oil_quality TEXT DEFAULT 'GOOD',
  last_maintenance DATE,
  next_maintenance DATE,
  site_code TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2c. QC Lab Results
CREATE TABLE IF NOT EXISTS mill_qc_results (
  id SERIAL PRIMARY KEY,
  batch_id TEXT NOT NULL,
  sample_date DATE NOT NULL DEFAULT CURRENT_DATE,
  sample_time TIME DEFAULT NOW(),
  ffa_pct NUMERIC DEFAULT 0,
  moisture_pct NUMERIC DEFAULT 0,
  dobi NUMERIC DEFAULT 0,
  color NUMERIC DEFAULT 0,
  dirt_pct NUMERIC DEFAULT 0,
  result TEXT DEFAULT 'PASS' CHECK (result IN ('PASS','REVIEW','REJECT')),
  tested_by TEXT,
  notes TEXT,
  site_code TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2d. Packing Log
CREATE TABLE IF NOT EXISTS mill_packing (
  id SERIAL PRIMARY KEY,
  pack_date DATE NOT NULL DEFAULT CURRENT_DATE,
  pack_time TIME DEFAULT NOW(),
  product_type TEXT DEFAULT 'CPO' CHECK (product_type IN ('CPO','PK','PKS','OIL')),
  quantity_kg NUMERIC DEFAULT 0,
  batch_id TEXT,
  destination TEXT,
  truck_plate TEXT,
  driver_name TEXT,
  status TEXT DEFAULT 'PACKED' CHECK (status IN ('PACKED','LOADED','DISPATCHED')),
  qc_status TEXT DEFAULT 'PASS',
  operator_nrp TEXT,
  site_code TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2e. Preventive Maintenance Schedule
CREATE TABLE IF NOT EXISTS mill_maintenance (
  id SERIAL PRIMARY KEY,
  equipment_code TEXT NOT NULL,
  equipment_name TEXT NOT NULL,
  maintenance_type TEXT DEFAULT 'PREVENTIVE' CHECK (maintenance_type IN ('PREVENTIVE','PREDICTIVE','CORRECTIVE')),
  description TEXT,
  scheduled_date DATE NOT NULL,
  completed_date DATE,
  status TEXT DEFAULT 'SCHEDULED' CHECK (status IN ('SCHEDULED','IN_PROGRESS','COMPLETED','OVERDUE')),
  assigned_to TEXT,
  priority TEXT DEFAULT 'MEDIUM' CHECK (priority IN ('LOW','MEDIUM','HIGH','CRITICAL')),
  cost NUMERIC DEFAULT 0,
  parts_used TEXT,
  downtime_hours NUMERIC DEFAULT 0,
  site_code TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2f. Breakdown Log
CREATE TABLE IF NOT EXISTS mill_breakdowns (
  id SERIAL PRIMARY KEY,
  equipment_code TEXT NOT NULL,
  equipment_name TEXT NOT NULL,
  breakdown_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  resolved_time TIMESTAMPTZ,
  severity TEXT DEFAULT 'MEDIUM' CHECK (severity IN ('LOW','MEDIUM','HIGH','CRITICAL')),
  category TEXT DEFAULT 'MECHANICAL' CHECK (category IN ('MECHANICAL','ELECTRICAL','INSTRUMENT','PROCESS','SAFETY')),
  description TEXT NOT NULL,
  root_cause TEXT,
  action_taken TEXT,
  reported_by TEXT,
  assigned_to TEXT,
  status TEXT DEFAULT 'OPEN' CHECK (status IN ('OPEN','IN_PROGRESS','RESOLVED','CLOSED')),
  downtime_hours NUMERIC DEFAULT 0,
  cost NUMERIC DEFAULT 0,
  site_code TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2g. Shift Schedule (3-shift for MINING + MILL)
CREATE TABLE IF NOT EXISTS shift_assignments (
  id SERIAL PRIMARY KEY,
  nrp TEXT NOT NULL,
  shift_date DATE NOT NULL,
  shift_type TEXT NOT NULL CHECK (shift_type IN ('PAGI','SORE','MALAM')),
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  section TEXT,
  equipment TEXT,
  status TEXT DEFAULT 'ASSIGNED' CHECK (status IN ('ASSIGNED','CHECKED_IN','CHECKED_OUT','ABSENT')),
  check_in_time TIMESTAMPTZ,
  check_out_time TIMESTAMPTZ,
  site_code TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(nrp, shift_date)
);

-- ============================================================
-- 3. RPC FUNCTIONS FOR MILL MODULES
-- ============================================================

-- Get boiler status
CREATE OR REPLACE FUNCTION get_boiler_status(p_site_code TEXT DEFAULT NULL)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', b.id, 'code', b.boiler_code, 'name', b.boiler_name,
        'status', b.status, 'temperature', b.temperature_c,
        'pressure', b.pressure_bar, 'steam_flow', b.steam_flow_kg_hr,
        'efficiency', b.efficiency_pct, 'fuel_type', b.fuel_type,
        'last_maintenance', b.last_maintenance, 'next_maintenance', b.next_maintenance
      ) ORDER BY b.boiler_code
    ), '[]'::jsonb))
    FROM mill_boiler b
    WHERE p_site_code IS NULL OR b.site_code = p_site_code
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get press status
CREATE OR REPLACE FUNCTION get_press_status(p_site_code TEXT DEFAULT NULL)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', p.id, 'code', p.press_code, 'name', p.press_name,
        'status', p.status, 'rpm', p.rpm, 'torque', p.torque_nm,
        'temperature', p.temperature_c, 'vibration', p.vibration_mm_s,
        'oil_quality', p.oil_quality, 'capacity', p.capacity_tph,
        'last_maintenance', p.last_maintenance, 'next_maintenance', p.next_maintenance
      ) ORDER BY p.press_code
    ), '[]'::jsonb))
    FROM mill_press p
    WHERE p_site_code IS NULL OR p.site_code = p_site_code
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get QC results
CREATE OR REPLACE FUNCTION get_qc_results(p_limit INTEGER DEFAULT 50)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', q.id, 'batch_id', q.batch_id, 'date', q.sample_date,
        'time', q.sample_time, 'ffa', q.ffa_pct, 'moisture', q.moisture_pct,
        'dobi', q.dobi, 'color', q.color, 'dirt', q.dirt_pct,
        'result', q.result, 'tested_by', q.tested_by, 'notes', q.notes
      ) ORDER BY q.sample_date DESC, q.sample_time DESC
    ), '[]'::jsonb))
    FROM mill_qc_results q
    ORDER BY q.sample_date DESC, q.sample_time DESC
    LIMIT p_limit
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get packing log
CREATE OR REPLACE FUNCTION get_packing_log(p_limit INTEGER DEFAULT 50)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', pk.id, 'date', pk.pack_date, 'time', pk.pack_time,
        'product', pk.product_type, 'quantity', pk.quantity_kg,
        'batch_id', pk.batch_id, 'destination', pk.destination,
        'truck_plate', pk.truck_plate, 'driver', pk.driver_name,
        'status', pk.status, 'qc_status', pk.qc_status
      ) ORDER BY pk.pack_date DESC, pk.pack_time DESC
    ), '[]'::jsonb))
    FROM mill_packing pk
    ORDER BY pk.pack_date DESC, pk.pack_time DESC
    LIMIT p_limit
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get maintenance schedule
CREATE OR REPLACE FUNCTION get_maintenance_schedule(p_status TEXT DEFAULT NULL)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', m.id, 'equipment', m.equipment_code, 'equipment_name', m.equipment_name,
        'type', m.maintenance_type, 'description', m.description,
        'scheduled', m.scheduled_date, 'completed', m.completed_date,
        'status', m.status, 'priority', m.priority,
        'assigned_to', m.assigned_to, 'cost', m.cost,
        'downtime', m.downtime_hours
      ) ORDER BY m.scheduled_date
    ), '[]'::jsonb))
    FROM mill_maintenance m
    WHERE (p_status IS NULL OR m.status = p_status)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get breakdown log
CREATE OR REPLACE FUNCTION get_breakdown_log(p_limit INTEGER DEFAULT 50)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', bd.id, 'equipment', bd.equipment_code, 'equipment_name', bd.equipment_name,
        'time', bd.breakdown_time, 'resolved', bd.resolved_time,
        'severity', bd.severity, 'category', bd.category,
        'description', bd.description, 'root_cause', bd.root_cause,
        'action', bd.action_taken, 'status', bd.status,
        'downtime', bd.downtime_hours, 'cost', bd.cost,
        'reported_by', bd.reported_by, 'assigned_to', bd.assigned_to
      ) ORDER BY bd.breakdown_time DESC
    ), '[]'::jsonb))
    FROM mill_breakdowns bd
    ORDER BY bd.breakdown_time DESC
    LIMIT p_limit
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get shift schedule
CREATE OR REPLACE FUNCTION get_shift_assignments(p_date DATE DEFAULT CURRENT_DATE, p_shift TEXT DEFAULT NULL)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', sa.id, 'nrp', sa.nrp, 'date', sa.shift_date,
        'shift', sa.shift_type, 'start', sa.start_time, 'end', sa.end_time,
        'section', sa.section, 'equipment', sa.equipment,
        'status', sa.status, 'check_in', sa.check_in_time, 'check_out', sa.check_out_time
      ) ORDER BY sa.shift_type, sa.nrp
    ), '[]'::jsonb))
    FROM shift_assignments sa
    WHERE sa.shift_date = p_date
      AND (p_shift IS NULL OR sa.shift_type = p_shift)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get MILL dashboard summary
CREATE OR REPLACE FUNCTION get_mill_summary()
RETURNS JSONB AS $$
DECLARE v_result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'ok', true,
    'boilers_running', (SELECT count(*) FROM mill_boiler WHERE status = 'RUNNING'),
    'boilers_total', (SELECT count(*) FROM mill_boiler),
    'presses_running', (SELECT count(*) FROM mill_press WHERE status = 'RUNNING'),
    'presses_total', (SELECT count(*) FROM mill_press),
    'qc_today', (SELECT count(*) FROM mill_qc_results WHERE sample_date = CURRENT_DATE),
    'qc_pass', (SELECT count(*) FROM mill_qc_results WHERE sample_date = CURRENT_DATE AND result = 'PASS'),
    'qc_reject', (SELECT count(*) FROM mill_qc_results WHERE sample_date = CURRENT_DATE AND result = 'REJECT'),
    'packing_today', (SELECT COALESCE(sum(quantity_kg), 0) FROM mill_packing WHERE pack_date = CURRENT_DATE),
    'breakdowns_open', (SELECT count(*) FROM mill_breakdowns WHERE status IN ('OPEN','IN_PROGRESS')),
    'maintenance_overdue', (SELECT count(*) FROM mill_maintenance WHERE status = 'OVERDUE'),
    'shift_pagi', (SELECT count(*) FROM shift_assignments WHERE shift_date = CURRENT_DATE AND shift_type = 'PAGI'),
    'shift_sore', (SELECT count(*) FROM shift_assignments WHERE shift_date = CURRENT_DATE AND shift_type = 'SORE'),
    'shift_malam', (SELECT count(*) FROM shift_assignments WHERE shift_date = CURRENT_DATE AND shift_type = 'MALAM')
  ) INTO v_result;
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 4. SEED MILL DATA — Realistic PKS operations
-- ============================================================

-- 4a. Boilers (3 unit — typical PKS)
INSERT INTO mill_boiler (boiler_code, boiler_name, capacity_kg_hr, status, temperature_c, pressure_bar, steam_flow_kg_hr, fuel_type, fuel_consumption_kg_hr, efficiency_pct, last_maintenance, next_maintenance, site_code) VALUES
('BLR-001', 'Boiler Utama #1', 25000, 'RUNNING', 185, 22, 22000, 'BIOMASS', 3200, 82.5, CURRENT_DATE - 30, CURRENT_DATE + 60, 'MILL-01'),
('BLR-002', 'Boiler Utama #2', 25000, 'RUNNING', 182, 21.5, 21500, 'BIOMASS', 3100, 81.8, CURRENT_DATE - 45, CURRENT_DATE + 45, 'MILL-01'),
('BLR-003', 'Boiler Cadangan', 15000, 'STANDBY', 25, 0, 0, 'BIOMASS', 0, 0, CURRENT_DATE - 15, CURRENT_DATE + 75, 'MILL-01')
ON CONFLICT (boiler_code) DO NOTHING;

-- 4b. Presses (5 units — typical PKS)
INSERT INTO mill_press (press_code, press_name, capacity_tph, status, rpm, torque_nm, temperature_c, vibration_mm_s, oil_quality, last_maintenance, next_maintenance, site_code) VALUES
('PRS-001', 'Screw Press #1', 5.5, 'RUNNING', 28, 450, 65, 2.1, 'GOOD', CURRENT_DATE - 20, CURRENT_DATE + 40, 'MILL-01'),
('PRS-002', 'Screw Press #2', 5.5, 'RUNNING', 27, 440, 63, 2.3, 'GOOD', CURRENT_DATE - 25, CURRENT_DATE + 35, 'MILL-01'),
('PRS-003', 'Screw Press #3', 5.5, 'RUNNING', 28, 460, 67, 1.9, 'GOOD', CURRENT_DATE - 10, CURRENT_DATE + 50, 'MILL-01'),
('PRS-004', 'Screw Press #4', 5.5, 'MAINTENANCE', 0, 0, 25, 0, 'CHANGE', CURRENT_DATE - 2, CURRENT_DATE + 5, 'MILL-01'),
('PRS-005', 'Screw Press #5', 5.5, 'STANDBY', 0, 0, 25, 0, 'GOOD', CURRENT_DATE - 30, CURRENT_DATE + 30, 'MILL-01')
ON CONFLICT (press_code) DO NOTHING;

-- 4c. QC Results (today's samples — realistic CPO grading)
INSERT INTO mill_qc_results (batch_id, sample_date, sample_time, ffa_pct, moisture_pct, dobi, color, dirt_pct, result, tested_by, notes, site_code) VALUES
('BTH-20260831-001', CURRENT_DATE, '08:30', 3.2, 0.15, 3.8, 20, 0.02, 'PASS', 'NRP-QLC-01', 'CPO grade premium', 'MILL-01'),
('BTH-20260831-002', CURRENT_DATE, '09:15', 4.1, 0.22, 3.2, 24, 0.05, 'PASS', 'NRP-QLC-01', 'CPO grade standard', 'MILL-01'),
('BTH-20260831-003', CURRENT_DATE, '10:00', 5.8, 0.35, 2.5, 28, 0.12, 'REVIEW', 'NRP-QLC-01', 'FFA tinggi, perlu review', 'MILL-01'),
('BTH-20260831-004', CURRENT_DATE, '10:45', 2.9, 0.12, 4.1, 18, 0.01, 'PASS', 'NRP-QLC-02', 'Excellent quality', 'MILL-01'),
('BTH-20260831-005', CURRENT_DATE, '11:30', 3.5, 0.18, 3.5, 22, 0.03, 'PASS', 'NRP-QLC-02', 'CPO good quality', 'MILL-01'),
('BTH-20260831-006', CURRENT_DATE, '13:00', 7.2, 0.42, 1.8, 35, 0.18, 'REJECT', 'NRP-QLC-01', 'FFA & moisture超标, reject batch', 'MILL-01'),
('BTH-20260831-007', CURRENT_DATE, '13:45', 3.1, 0.14, 3.9, 19, 0.02, 'PASS', 'NRP-QLC-02', 'CPO premium grade', 'MILL-01'),
('BTH-20260831-008', CURRENT_DATE, '14:30', 3.8, 0.20, 3.3, 23, 0.04, 'PASS', 'NRP-QLC-01', 'Standard CPO', 'MILL-01')
ON CONFLICT DO NOTHING;

-- 4d. Packing Log (today's output)
INSERT INTO mill_packing (pack_date, pack_time, product_type, quantity_kg, batch_id, destination, truck_plate, driver_name, status, qc_status, operator_nrp, site_code) VALUES
(CURRENT_DATE, '09:00', 'CPO', 18500, 'BTH-20260831-001', 'PT Sinar Palm — Surabaya', 'L 1234 AB', 'Budi Santoso', 'DISPATCHED', 'PASS', 'NRP-OPR-01', 'MILL-01'),
(CURRENT_DATE, '10:30', 'CPO', 19200, 'BTH-20260831-002', 'PT Masagena — Gresik', 'L 5678 CD', 'Andi Wijaya', 'LOADED', 'PASS', 'NRP-OPR-01', 'MILL-01'),
(CURRENT_DATE, '12:00', 'PK', 8500, NULL, 'PT Kernel Jaya — Sidoarjo', 'L 9012 EF', 'Rudi Hartono', 'PACKED', 'PASS', 'NRP-OPR-02', 'MILL-01'),
(CURRENT_DATE, '14:00', 'CPO', 20100, 'BTH-20260831-004', 'PT Sinar Palm — Surabaya', 'L 3456 GH', 'Dedi Kurniawan', 'PACKED', 'PASS', 'NRP-OPR-02', 'MILL-01'),
(CURRENT_DATE, '15:30', 'OIL', 5200, NULL, 'Internal Storage', NULL, NULL, 'PACKED', 'PASS', 'NRP-OPR-03', 'MILL-01')
ON CONFLICT DO NOTHING;

-- 4e. Preventive Maintenance Schedule (30 days)
INSERT INTO mill_maintenance (equipment_code, equipment_name, maintenance_type, description, scheduled_date, status, assigned_to, priority, downtime_hours, site_code) VALUES
('BLR-001', 'Boiler Utama #1', 'PREVENTIVE', 'Inspeksi tabung & clean burning chamber', CURRENT_DATE + 5, 'SCHEDULED', 'NRP-MNT-01', 'HIGH', 8, 'MILL-01'),
('BLR-002', 'Boiler Utama #2', 'PREVENTIVE', 'Kalibrasi pressure gauge & safety valve', CURRENT_DATE + 12, 'SCHEDULED', 'NRP-MNT-01', 'MEDIUM', 4, 'MILL-01'),
('PRS-001', 'Screw Press #1', 'PREDICTIVE', 'Vibration analysis & bearing check', CURRENT_DATE + 3, 'SCHEDULED', 'NRP-MNT-02', 'MEDIUM', 6, 'MILL-01'),
('PRS-004', 'Screw Press #4', 'CORRECTIVE', 'Ganti seal & screw tip', CURRENT_DATE - 1, 'IN_PROGRESS', 'NRP-MNT-02', 'CRITICAL', 24, 'MILL-01'),
('PRS-002', 'Screw Press #2', 'PREVENTIVE', 'Oil change & filter replacement', CURRENT_DATE + 7, 'SCHEDULED', 'NRP-MNT-02', 'LOW', 3, 'MILL-01'),
('QCL-LAB', 'QC Laboratory Equipment', 'PREVENTIVE', 'Kalibrasi semua instrumen QC', CURRENT_DATE + 10, 'SCHEDULED', 'NRP-QLC-01', 'HIGH', 2, 'MILL-01'),
('CONV-001', 'Conveyor Belt #1', 'PREVENTIVE', 'Roller & belt inspection', CURRENT_DATE + 15, 'SCHEDULED', 'NRP-MNT-03', 'MEDIUM', 4, 'MILL-01'),
('PUMP-001', 'CPO Pump Main', 'PREVENTIVE', 'Seal & impeller check', CURRENT_DATE + 8, 'SCHEDULED', 'NRP-MNT-03', 'LOW', 2, 'MILL-01')
ON CONFLICT DO NOTHING;

-- 4f. Breakdown Log (recent incidents)
INSERT INTO mill_breakdowns (equipment_code, equipment_name, breakdown_time, resolved_time, severity, category, description, root_cause, action_taken, status, downtime_hours, cost, reported_by, assigned_to, site_code) VALUES
('PRS-004', 'Screw Press #4', NOW() - INTERVAL '2 days', NULL, 'HIGH', 'MECHANICAL', 'Screw tip pecah, press berhenti total', 'Wear & tear setelah 6 bulan operasi', 'Ganti screw tip & seal', 'IN_PROGRESS', 48, 15000000, 'NRP-OPR-02', 'NRP-MNT-02', 'MILL-01'),
('BLR-001', 'Boiler Utama #1', NOW() - INTERVAL '5 days', NOW() - INTERVAL '5 days' + INTERVAL '4 hours', 'MEDIUM', 'INSTRUMENT', 'Pressure sensor error, display tidak akurat', 'Sensor kotor, perlu cleaning', 'Clean & kalibrasi sensor', 'RESOLVED', 4, 500000, 'NRP-BRG-01', 'NRP-MNT-01', 'MILL-01'),
('CONV-002', 'Conveyor Belt #2', NOW() - INTERVAL '8 days', NOW() - INTERVAL '8 days' + INTERVAL '6 hours', 'LOW', 'MECHANICAL', 'Belt slip, material tumpah', 'Belt longgar, tensioner aus', 'Retension belt & ganti tensioner', 'CLOSED', 6, 200000, 'NRP-OPR-03', 'NRP-MNT-03', 'MILL-01'),
('PUMP-002', 'Water Pump Cooling', NOW() - INTERVAL '12 days', NOW() - INTERVAL '12 days' + INTERVAL '3 hours', 'HIGH', 'ELECTRICAL', 'Motor pump terbakar', 'Overheating karena bearing aus', 'Ganti motor pump baru', 'CLOSED', 3, 8000000, 'NRP-BRG-02', 'NRP-MNT-1', 'MILL-01')
ON CONFLICT DO NOTHING;

-- 4g. Shift Assignments (today + tomorrow, 3 shifts, 30 workers per shift)
-- PAGI (06:00-14:00), SORE (14:00-22:00), MALAM (22:00-06:00)
INSERT INTO shift_assignments (nrp, shift_date, shift_type, start_time, end_time, section, equipment, status, site_code)
SELECT
  'MLL' || LPAD(n::text, 4, '0'),
  CURRENT_DATE,
  CASE (n % 3)
    WHEN 0 THEN 'PAGI'
    WHEN 1 THEN 'SORE'
    WHEN 2 THEN 'MALAM'
  END,
  CASE (n % 3)
    WHEN 0 THEN '06:00'::time
    WHEN 1 THEN '14:00'::time
    WHEN 2 THEN '22:00'::time
  END,
  CASE (n % 3)
    WHEN 0 THEN '14:00'::time
    WHEN 1 THEN '22:00'::time
    WHEN 2 THEN '06:00'::time
  END,
  CASE (n % 5)
    WHEN 0 THEN 'Boiler'
    WHEN 1 THEN 'Press'
    WHEN 2 THEN 'Packing'
    WHEN 3 THEN 'QC'
    WHEN 4 THEN 'Maintenance'
  END,
  CASE (n % 5)
    WHEN 0 THEN 'BLR-001'
    WHEN 1 THEN 'PRS-00' || ((n % 5) + 1)::text
    WHEN 2 THEN 'PKG-001'
    WHEN 3 THEN 'QCL-001'
    WHEN 4 THEN 'MNT-SHOP'
  END,
  'ASSIGNED',
  'MILL-01'
FROM generate_series(1, 30) n
ON CONFLICT (nrp, shift_date) DO NOTHING;

-- Tomorrow's shifts
INSERT INTO shift_assignments (nrp, shift_date, shift_type, start_time, end_time, section, equipment, status, site_code)
SELECT
  'MLL' || LPAD(n::text, 4, '0'),
  CURRENT_DATE + 1,
  CASE (n % 3)
    WHEN 0 THEN 'PAGI'
    WHEN 1 THEN 'SORE'
    WHEN 2 THEN 'MALAM'
  END,
  CASE (n % 3)
    WHEN 0 THEN '06:00'::time
    WHEN 1 THEN '14:00'::time
    WHEN 2 THEN '22:00'::time
  END,
  CASE (n % 3)
    WHEN 0 THEN '14:00'::time
    WHEN 1 THEN '22:00'::time
    WHEN 2 THEN '06:00'::time
  END,
  CASE (n % 5)
    WHEN 0 THEN 'Boiler'
    WHEN 1 THEN 'Press'
    WHEN 2 THEN 'Packing'
    WHEN 3 THEN 'QC'
    WHEN 4 THEN 'Maintenance'
  END,
  'MILL-01',
  'ASSIGNED',
  'MILL-01'
FROM generate_series(1, 30) n
ON CONFLICT (nrp, shift_date) DO NOTHING;

-- ============================================================
-- 5. ENABLE RLS
-- ============================================================
ALTER TABLE bu_divisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE mill_boiler ENABLE ROW LEVEL SECURITY;
ALTER TABLE mill_press ENABLE ROW LEVEL SECURITY;
ALTER TABLE mill_qc_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE mill_packing ENABLE ROW LEVEL SECURITY;
ALTER TABLE mill_maintenance ENABLE ROW LEVEL SECURITY;
ALTER TABLE mill_breakdowns ENABLE ROW LEVEL SECURITY;
ALTER TABLE shift_assignments ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY mill_select ON bu_divisions FOR SELECT USING (true);
  CREATE POLICY mill_select ON mill_boiler FOR SELECT USING (true);
  CREATE POLICY mill_select ON mill_press FOR SELECT USING (true);
  CREATE POLICY mill_select ON mill_qc_results FOR SELECT USING (true);
  CREATE POLICY mill_select ON mill_packing FOR SELECT USING (true);
  CREATE POLICY mill_select ON mill_maintenance FOR SELECT USING (true);
  CREATE POLICY mill_select ON mill_breakdowns FOR SELECT USING (true);
  CREATE POLICY mill_select ON shift_assignments FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- 6. ALSO SEED: OKRs + eNPS + Forum + Continuous Feedback data
-- ============================================================

-- 6a. OKRs (if table exists)
DO $$ BEGIN
  INSERT INTO okrs (nrp, objective, key_results, period, status, progress_pct)
  SELECT e.nrp,
    CASE (random()*3)::int
      WHEN 0 THEN 'Meningkatkan produktivitas tambang 15%'
      WHEN 1 THEN 'Zero accident untuk Q3 2026'
      WHEN 2 THEN 'Menurunkan biaya operasional 10%'
      ELSE 'Mencapai sertifikasi ISO 45001'
    END,
    CASE (random()*3)::int
      WHEN 0 THEN '[{"kr":"Target tonase 500 ton/hari","target":500,"current":420},{"kr":"Safety incident < 2/bulan","target":2,"current":1}]'::jsonb
      WHEN 1 THEN '[{"kr":"No lost time injury","target":0,"current":0},{"kr":"100% safety training completion","target":100,"current":85}]'::jsonb
      WHEN 2 THEN '[{"kr":"Reduce fuel consumption 10%","target":10,"current":6},{"kr":"Optimize route hauling","target":3,"current":2}]'::jsonb
      ELSE '[{"kr":"Complete ISO 45001 documentation","target":100,"current":45},{"kr":"Internal audit passed","target":1,"current":0}]'::jsonb
    END,
    '2026-Q' || ((extract(month from NOW())::int - 1) / 3 + 1)::text,
    CASE WHEN random() > 0.3 THEN 'IN_PROGRESS' ELSE 'COMPLETED' END,
    (random() * 100)::int
  FROM employees_master e
  WHERE e.nrp IN (SELECT DISTINCT nrp FROM user_roles WHERE role_level >= 3 LIMIT 20)
  ON CONFLICT DO NOTHING;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- 6b. Forum Posts (if table exists)
DO $$ BEGIN
  INSERT INTO forum_posts (author_nrp, title, content, category, upvotes, downvotes, is_pinned)
  VALUES
  ('NRP0001', 'Tips Safety Tambang Q3 2026', 'Berikut 5 tips keselamatan kerja di area tambang untuk Q3: 1) Selalu gunakan APD lengkap, 2) Check equipment sebelum operasi, 3) Laporkan near-miss, 4) Ikuti JSA briefing, 5) Jangan fatigue driving.', 'K3', 15, 0, true),
  ('NRP0010', 'Optimasi Jadwal Shift PKS', 'Saya punya proposal untuk optimasi jadwal shift di pabrik PKS. Dengan rotasi yang lebih baik, kita bisa kurangi overtime 20%. Siapa yang mau bahas?', 'Saran', 8, 2, false),
  ('NRP0025', 'Training K3 untuk New Hire', 'Mohon diadakan training K3 khusus karyawan baru. Banyak yang belum paham prosedur emergency di tambang.', 'Training', 12, 0, false),
  ('NRP0033', 'Ide: Sistem Rekan Sebaya', 'Bagaimana kalau kita buat sistem peer recognition? Karyawan bisa kasih apresiasi ke rekan kerja yang membantu.', 'Ide', 20, 1, false),
  ('NRP0042', 'Hasil Panen Bulan Ini', 'Panen bulan ini naik 8% dibanding bulan lalu. Ini berkat perbaikan irigasi di blok C. Terima kasih tim Estate!', 'Informasi', 18, 0, false),
  ('NRP0055', 'Workshop K3 untuk Tim Estate', 'Workshop K3 dijadwalkan 15 Sept. Attendance wajib untuk semua mandor dan pemanen. Tempat: Aula Kantor Pusat.', 'K3', 10, 0, true),
  ('NRP0008', 'Maintenance Breakdown Equipment', 'Beberapa equipment di press room sering breakdown. Mohon preventive maintenance lebih sering. Minimal mingguan.', 'Keluhan', 14, 3, false),
  ('NRP0015', 'Tips Produktivitas Kerja dari Tim Mining', 'Berikut 5 tips yang kami terapkan di divisi Mining untuk meningkatkan produktivitas harian. Semoga bermanfaat untuk tim lain.', 'Saran', 22, 0, false),
  ('NRP0028', 'Absensi Online untuk Field Worker', 'Saya usulkan ada absensi online untuk pekerja lapangan yang tidak punya fingerprint. Bisa pakai GPS check-in.', 'Ide', 16, 2, false),
  ('NRP0045', 'Pengumuman: Libur Nasional', 'Daftar libur nasional Q4 2026 sudah keluar. Silakan cek di halaman profil untuk lihat jadwal cuti bersama.', 'Informasi', 5, 0, false)
  ON CONFLICT DO NOTHING;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- 6c. Survey/eNPS (if table exists)
DO $$ BEGIN
  INSERT INTO surveys (title, description, type, status, questions)
  VALUES
  ('eNPS Q3 2026', 'Employee Net Promoter Score — seberapa besar kemungkinan Anda merekomendasikan perusahaan ini?', 'eNPS', 'ACTIVE',
   '[{"q":"Seberapa besar kemungkinan Anda merekomendasikan perusahaan ini? (0-10)","type":"nps"},{"q":"Apa alasan utama Anda memberikan skor tersebut?","type":"text"},{"q":"Apa yang perlu diperbaiki di perusahaan?","type":"text"}]'::jsonb),
  ('Pulse Survey Agustus 2026', 'Survei singkat tentang kepuasan kerja bulan ini', 'PULSE', 'ACTIVE',
   '[{"q":"Bagaimana kondisi K3 di area kerja Anda? (1-5)","type":"rating"},{"q":"Apakah workload Anda seimbang? (1-5)","type":"rating"},{"q":"Saran perbaikan?","type":"text"}]'::jsonb),
  ('Training Needs Assessment', 'Identifikasi kebutuhan training karyawan', 'ASSESSMENT', 'ACTIVE',
   '[{"q":"Training apa yang paling Anda butuhkan?","type":"multi","options":["Safety K3","Leadership","Technical","Digital","Language"]},{"q":"Berapa jam per minggu untuk training?","type":"number"}]'::jsonb)
  ON CONFLICT DO NOTHING;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- 6d. Continuous Performance Notes (if table exists)
DO $$ BEGIN
  INSERT INTO performance_notes (nrp, manager_nrp, note_type, content, rating, created_at)
  SELECT
    e.nrp,
    (SELECT atasan_nrp FROM hr_org WHERE nrp = e.nrp LIMIT 1),
    CASE (random()*3)::int
      WHEN 0 THEN 'POSITIVE'
      WHEN 1 THEN 'COACHING'
      WHEN 2 THEN 'RECOGNITION'
      ELSE 'IMPROVEMENT'
    END,
    CASE (random()*4)::int
      WHEN 0 THEN 'Performa kerja sangat baik bulan ini. Target tercapai 110%.'
      WHEN 1 THEN 'Perlu improve di bagian komunikasi tim. Sudah diberikan coaching.'
      WHEN 2 THEN 'Apresiasi untuk bantu tim lain selesaikan proyek deadline.'
      WHEN 3 THEN 'Ada penurunan kinerja di safety compliance. Perlu perhatian.'
      ELSE 'Keep up the good work! Consistent performance.'
    END,
    (3 + (random() * 2)::int),
    NOW() - (random() * 90 || ' days')::interval
  FROM employees_master e
  WHERE e.nrp IN (SELECT DISTINCT nrp FROM user_roles WHERE role_level >= 2 LIMIT 30)
  ON CONFLICT DO NOTHING;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- ============================================================
-- DONE — Migration 052: MILL Modules + Seed Data
-- ============================================================
