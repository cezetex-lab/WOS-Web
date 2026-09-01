-- ============================================================
-- Migration 065: Wire 5 estate/mining pages to real RPCs
-- ============================================================

-- 1. Irrigation data table + RPC
CREATE TABLE IF NOT EXISTS irrigation_blocks (
  id SERIAL PRIMARY KEY,
  block TEXT NOT NULL,
  status TEXT DEFAULT "ACTIVE",
  last_irrigation DATE,
  next_scheduled DATE,
  water_level NUMERIC(5,1),
  soil_moisture NUMERIC(5,1),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO irrigation_blocks (block, status, last_irrigation, next_scheduled, water_level, soil_moisture, notes) VALUES
('BLOK-A1', 'OPTIMAL', CURRENT_DATE - INTERVAL '1 days', CURRENT_DATE + INTERVAL '2 days', 75.0, 68.5, 'Irrigation normal'),
('BLOK-A2', 'NEEDS_WATER', CURRENT_DATE - INTERVAL '3 days', CURRENT_DATE, 45.0, 42.0, 'Soil kering, perlu irigasi segera'),
('BLOK-B1', 'OPTIMAL', CURRENT_DATE - INTERVAL '1 days', CURRENT_DATE + INTERVAL '1 days', 80.0, 72.0, 'Kelembaban baik'),
('BLOK-B2', 'OVER_WATERED', CURRENT_DATE, CURRENT_DATE + INTERVAL '3 days', 95.0, 88.0, 'Terlalu basah, skip irigasi'),
('BLOK-C1', 'MAINTENANCE', CURRENT_DATE - INTERVAL '5 days', CURRENT_DATE + INTERVAL '7 days', 0.0, 35.0, 'Pipa bocor, sedang diperbaiki'),
('BLOK-C2', 'OPTIMAL', CURRENT_DATE - INTERVAL '2 days', CURRENT_DATE + INTERVAL '1 days', 70.0, 65.0, 'Normal')
ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION get_irrigation_data()
RETURNS JSONB AS $$
BEGIN RETURN (
  SELECT jsonb_build_object("ok", true, "data", COALESCE(jsonb_agg(row_to_json(ib)), "[]"::jsonb))
  FROM irrigation_blocks ib
); END;
$$ LANGUAGE plpgsql STABLE;

-- 2. Nursery data table + RPC
CREATE TABLE IF NOT EXISTS nursery_blocks (
  id SERIAL PRIMARY KEY,
  block TEXT NOT NULL,
  seedling_count INTEGER DEFAULT 0,
  age_months INTEGER DEFAULT 0,
  species TEXT DEFAULT "Tenera",
  health TEXT DEFAULT "GOOD",
  next_transfer DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO nursery_blocks (block, seedling_count, age_months, species, health, next_transfer) VALUES
('NRS-001', 5000, 12, 'Tenera', 'EXCELLENT', CURRENT_DATE + INTERVAL '2 months'),
('NRS-002', 3500, 8, 'Dura', 'GOOD', CURRENT_DATE + INTERVAL '6 months'),
('NRS-003', 4200, 10, 'Tenera', 'GOOD', CURRENT_DATE + INTERVAL '4 months'),
('NRS-004', 2800, 6, 'Hybrid', 'FAIR', CURRENT_DATE + INTERVAL '8 months'),
('NRS-005', 6000, 14, 'Tenera', 'EXCELLENT', CURRENT_DATE + INTERVAL '1 month'),
('NRS-006', 1500, 3, 'Dura', 'POOR', CURRENT_DATE + INTERVAL '11 months')
ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION get_nursery_data()
RETURNS JSONB AS $$
BEGIN RETURN (
  SELECT jsonb_build_object("ok", true, "data", COALESCE(jsonb_agg(row_to_json(nb)), "[]"::jsonb))
  FROM nursery_blocks nb
); END;
$$ LANGUAGE plpgsql STABLE;

-- 3. Emergency procedures table + RPC
CREATE TABLE IF NOT EXISTS emergency_procedures (
  id SERIAL PRIMARY KEY,
  code TEXT NOT NULL,
  title TEXT NOT NULL,
  category TEXT DEFAULT "SAFETY",
  severity TEXT DEFAULT "HIGH",
  steps TEXT,
  contact TEXT,
  last_drill DATE,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO emergency_procedures (code, title, category, severity, steps, contact, last_drill) VALUES
('EP-001', 'Kebakaran Hutan', 'FIRE', 'CRITICAL', '1. Evakuasi area
2. Hubungi pemadam
3. Gunakan APAR jika aman', '0812-xxxx-xxxx', CURRENT_DATE - INTERVAL '30 days'),
('EP-002', 'Kecelakaan Alat Berat', 'ACCIDENT', 'CRITICAL', '1. Stop operasi
2. Hubungi medis
3. Amankan lokasi', '0812-xxxx-xxxx', CURRENT_DATE - INTERVAL '15 days'),
('EP-003', 'Tumpahan Bahan Kimia', 'HAZMAT', 'HIGH', '1. Evakuasi radius 100m
2. Hubungi HSE
3. Jangan sentuh tanpa APD', '0812-xxxx-xxxx', CURRENT_DATE - INTERVAL '45 days'),
('EP-004', 'Gempa Bumi', 'NATURAL', 'HIGH', '1. Drop-cover-hold
2. Evakuasi setelah gempa
3. Kumpul di assembly point', '0812-xxxx-xxxx', CURRENT_DATE - INTERVAL '60 days'),
('EP-005', 'Banjir', 'NATURAL', 'MEDIUM', '1. Pindahkan ke tempat tinggi
2. Matikan listrik
3. Hubungi tim evakuasi', '0812-xxxx-xxxx', CURRENT_DATE - INTERVAL '90 days'),
('EP-006', 'Kecelakaan Kerja Ringan', 'ACCIDENT', 'MEDIUM', '1. Berikan pertolongan pertama
2. Catat insiden
3. Laporkan ke HSE', '0812-xxxx-xxxx', CURRENT_DATE - INTERVAL '7 days')
ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION get_emergency_procedures()
RETURNS JSONB AS $$
BEGIN RETURN (
  SELECT jsonb_build_object("ok", true, "data", COALESCE(jsonb_agg(row_to_json(ep)), "[]"::jsonb))
  FROM emergency_procedures ep WHERE ep.is_active = true
); END;
$$ LANGUAGE plpgsql STABLE;

-- 4. RLS
ALTER TABLE irrigation_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE nursery_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE emergency_procedures ENABLE ROW LEVEL SECURITY;
CREATE POLICY "irrigation_read" ON irrigation_blocks FOR SELECT USING (true);
CREATE POLICY "nursery_read" ON nursery_blocks FOR SELECT USING (true);
CREATE POLICY "emergency_read" ON emergency_procedures FOR SELECT USING (true);