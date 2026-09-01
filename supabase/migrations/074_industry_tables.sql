-- INSIGHTWOS V6 - INDUSTRY TABLES + SEED DATA
-- 21 tables: Mining 7 + Estate 7 + Mill 7

-- MINING TABLES
CREATE TABLE IF NOT EXISTS mining_simper (id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT, business_unit_id TEXT, nrp TEXT, nama TEXT, simper_type TEXT, status TEXT DEFAULT 'ACTIVE', issued_date DATE, expiry_date DATE, site TEXT, created_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE IF NOT EXISTS mining_equipment (id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT, business_unit_id TEXT, equipment_code TEXT, equipment_name TEXT, type TEXT, status TEXT DEFAULT 'OPERATIONAL', operator_nrp TEXT, operator_nama TEXT, last_maintenance DATE, created_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE IF NOT EXISTS mining_production (id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT, business_unit_id TEXT, date DATE DEFAULT CURRENT_DATE, pit_name TEXT, tonnage NUMERIC DEFAULT 0, truck_count INT DEFAULT 0, fuel_used NUMERIC DEFAULT 0, status TEXT DEFAULT 'COMPLETED', created_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE IF NOT EXISTS mining_fuel (id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT, business_unit_id TEXT, date DATE DEFAULT CURRENT_DATE, equipment_code TEXT, fuel_type TEXT, liters NUMERIC DEFAULT 0, driver_nrp TEXT, driver_nama TEXT, created_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE IF NOT EXISTS mining_fatigue (id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT, business_unit_id TEXT, nrp TEXT, nama TEXT, shift TEXT, fatigue_level INT DEFAULT 0, hours_worked NUMERIC DEFAULT 0, rest_hours NUMERIC DEFAULT 0, status TEXT DEFAULT 'NORMAL', created_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE IF NOT EXISTS mining_safety (id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT, business_unit_id TEXT, date DATE DEFAULT CURRENT_DATE, incident_type TEXT, severity TEXT, location TEXT, description TEXT, reported_by TEXT, status TEXT DEFAULT 'OPEN', created_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE IF NOT EXISTS mining_jsa (id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT, business_unit_id TEXT, job_name TEXT, hazard TEXT, risk_level TEXT, control_measure TEXT, prepared_by TEXT, approved_by TEXT, status TEXT DEFAULT 'DRAFT', created_at TIMESTAMPTZ DEFAULT NOW());

-- ESTATE TABLES
CREATE TABLE IF NOT EXISTS estate_harvest (id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT, business_unit_id TEXT, date DATE DEFAULT CURRENT_DATE, block_name TEXT, tonnage NUMERIC DEFAULT 0, harvester_nrp TEXT, harvester_nama TEXT, quality TEXT, status TEXT DEFAULT 'RECORDED', created_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE IF NOT EXISTS estate_blocks (id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT, business_unit_id TEXT, block_code TEXT, block_name TEXT, area_ha NUMERIC DEFAULT 0, plant_age INT DEFAULT 0, yield_potential NUMERIC DEFAULT 0, status TEXT DEFAULT 'ACTIVE', created_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE IF NOT EXISTS estate_irrigation (id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT, business_unit_id TEXT, date DATE DEFAULT CURRENT_DATE, block_name TEXT, water_level NUMERIC DEFAULT 0, ph_level NUMERIC DEFAULT 7, status TEXT DEFAULT 'NORMAL', operator_nama TEXT, created_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE IF NOT EXISTS estate_nursery (id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT, business_unit_id TEXT, nursery_name TEXT, seedling_type TEXT, quantity INT DEFAULT 0, age_weeks INT DEFAULT 0, health_status TEXT DEFAULT 'GOOD', target_date DATE, created_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE IF NOT EXISTS estate_transport (id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT, business_unit_id TEXT, date DATE DEFAULT CURRENT_DATE, vehicle_code TEXT, driver_nama TEXT, tonnage NUMERIC DEFAULT 0, origin TEXT, destination TEXT, status TEXT DEFAULT 'IN_TRANSIT', created_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE IF NOT EXISTS estate_field (id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT, business_unit_id TEXT, date DATE DEFAULT CURRENT_DATE, activity_type TEXT, block_name TEXT, worker_count INT DEFAULT 0, description TEXT, supervisor_nama TEXT, created_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE IF NOT EXISTS estate_yield (id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT, business_unit_id TEXT, month TEXT, block_name TEXT, actual_tonnage NUMERIC DEFAULT 0, target_tonnage NUMERIC DEFAULT 0, achievement_pct NUMERIC DEFAULT 0, status TEXT DEFAULT 'ON_TRACK', created_at TIMESTAMPTZ DEFAULT NOW());

-- MILL TABLES
CREATE TABLE IF NOT EXISTS mill_boiler (id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT, business_unit_id TEXT, date DATE DEFAULT CURRENT_DATE, boiler_id TEXT, temperature NUMERIC DEFAULT 0, pressure NUMERIC DEFAULT 0, fuel_consumption NUMERIC DEFAULT 0, efficiency_pct NUMERIC DEFAULT 0, status TEXT DEFAULT 'RUNNING', created_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE IF NOT EXISTS mill_press (id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT, business_unit_id TEXT, date DATE DEFAULT CURRENT_DATE, press_id TEXT, rpm NUMERIC DEFAULT 0, load_tons NUMERIC DEFAULT 0, oil_quality TEXT, status TEXT DEFAULT 'RUNNING', created_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE IF NOT EXISTS mill_qc (id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT, business_unit_id TEXT, date DATE DEFAULT CURRENT_DATE, batch_id TEXT, ffa_pct NUMERIC DEFAULT 0, moisture_pct NUMERIC DEFAULT 0, dobii NUMERIC DEFAULT 0, grade TEXT, status TEXT DEFAULT 'PASSED', created_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE IF NOT EXISTS mill_packing (id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT, business_unit_id TEXT, date DATE DEFAULT CURRENT_DATE, product_type TEXT, quantity_kg NUMERIC DEFAULT 0, pallet_count INT DEFAULT 0, warehouse TEXT, status TEXT DEFAULT 'PACKED', created_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE IF NOT EXISTS mill_maintenance (id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT, business_unit_id TEXT, equipment_id TEXT, equipment_name TEXT, maintenance_type TEXT, scheduled_date DATE, completed_date DATE, technician_nama TEXT, status TEXT DEFAULT 'SCHEDULED', created_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE IF NOT EXISTS mill_breakdown (id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT, business_unit_id TEXT, equipment_id TEXT, equipment_name TEXT, breakdown_type TEXT, severity TEXT, start_time TIMESTAMPTZ, end_time TIMESTAMPTZ, status TEXT DEFAULT 'OPEN', created_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE IF NOT EXISTS mill_shift (id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT, business_unit_id TEXT, date DATE DEFAULT CURRENT_DATE, shift_name TEXT, start_time TIME, end_time TIME, headcount INT DEFAULT 0, supervisor_nama TEXT, status TEXT DEFAULT 'ACTIVE', created_at TIMESTAMPTZ DEFAULT NOW());

-- SEED DATA: Mining SIMPER (10 records)
INSERT INTO mining_simper (business_unit_id, nrp, nama, simper_type, issued_date, expiry_date, site) VALUES
('BU01','MN0001','Budi Santoso','HEALTH_CERT',CURRENT_DATE-30,CURRENT_DATE+335,'Pit A'),
('BU01','MN0002','Ahmad Fauzi','SAFETY_CERT',CURRENT_DATE-25,CURRENT_DATE+340,'Pit A'),
('BU01','MN0003','Rudi Hermawan','DRIVING_LICENSE',CURRENT_DATE-20,CURRENT_DATE+345,'Pit A'),
('BU01','MN0004','Dedi Kurniawan','BLAST_CERT',CURRENT_DATE-15,CURRENT_DATE+350,'Pit A'),
('BU01','MN0005','Eko Prasetyo','HAULING_CERT',CURRENT_DATE-10,CURRENT_DATE+355,'Pit A'),
('BU01','MN0006','Fajar Nugroho','RIGGING_CERT',CURRENT_DATE-5,CURRENT_DATE+360,'Pit B'),
('BU01','MN0007','Hendra Wijaya','WELDING_CERT',CURRENT_DATE-3,CURRENT_DATE+362,'Pit B'),
('BU01','MN0008','Indra Gunawan','ELECTRICAL_CERT',CURRENT_DATE-2,CURRENT_DATE+363,'Pit B'),
('BU01','MN0009','Joko Susilo','FORKLIFT_CERT',CURRENT_DATE-1,CURRENT_DATE+364,'Pit B'),
('BU01','MN0010','Kurniawan','CRANE_CERT',CURRENT_DATE,CURRENT_DATE+365,'Pit B');

-- SEED DATA: Mining Equipment (8 records)
INSERT INTO mining_equipment (business_unit_id, equipment_code, equipment_name, type, operator_nrp, operator_nama) VALUES
('BU01','EQ-M-001','CAT 777F','Dump Truck','MN0001','Budi Santoso'),
('BU01','EQ-M-002','CAT D6T','Dozer','MN0002','Ahmad Fauzi'),
('BU01','EQ-M-003','Komatsu PC300','Excavator','MN0003','Rudi Hermawan'),
('BU01','EQ-M-004','
CAT 992K','Wheel Loader','MN0004','Dedi Kurniawan'),
('BU01','EQ-M-005','Volvo A60H','Artic Truck','MN0005','Eko Prasetyo'),
('BU01','EQ-M-006','CAT 16M','Motor Grader','MN0006','Fajar Nugroho'),
('BU01','EQ-M-007','Hitachi EX5500','Mining Excavator','MN0007','Hendra Wijaya'),
('BU01','EQ-M-008','Caterpillar 785C','Haul Truck','MN0008','Indra Gunawan');

-- Mining Production 30 days
INSERT INTO mining_production (business_unit_id, date, pit_name, tonnage, truck_count, fuel_used) VALUES
('BU01',CURRENT_DATE-29,'Pit A',1500,8,150),('BU01',CURRENT_DATE-28,'Pit B',1550,9,155),
('BU01',CURRENT_DATE-27,'Pit A',1600,8,160),('BU01',CURRENT_DATE-26,'Pit B',1650,10,165),
('BU01',CURRENT_DATE-25,'Pit A',1700,9,170),('BU01',CURRENT_DATE-24,'Pit B',1750,8,175),
('BU01',CURRENT_DATE-23,'Pit A',1800,10,180),('BU01',CURRENT_DATE-22,'Pit B',1850,9,185),
('BU01',CURRENT_DATE-21,'Pit A',1900,8,190),('BU01',CURRENT_DATE-20,'Pit B',1950,10,195),
('BU01',CURRENT_DATE-19,'Pit A',2000,9,200),('BU01',CURRENT_DATE-18,'Pit B',2050,8,205),
('BU01',CURRENT_DATE-17,'Pit A',2100,10,210),('BU01',CURRENT_DATE-16,'Pit B',2150,9,215),
('BU01',CURRENT_DATE-15,'Pit A',2200,8,220),('BU01',CURRENT_DATE-14,'Pit B',2250,10,225),
('BU01',CURRENT_DATE-13,'Pit A',2300,9,230),('BU01',CURRENT_DATE-12,'Pit B',2350,8,235),
('BU01',CURRENT_DATE-11,'Pit A',2400,10,240),('BU01',CURRENT_DATE-10,'Pit B',2450,9,245),
('BU01',CURRENT_DATE-9,'Pit A',2500,8,250),('BU01',CURRENT_DATE-8,'Pit B',2550,10,255),
('BU01',CURRENT_DATE-7,'Pit A',2600,9,260),('BU01',CURRENT_DATE-6,'Pit B',2650,8,265),
('BU01',CURRENT_DATE-5,'Pit A',2700,10,270),('BU01',CURRENT_DATE-4,'Pit B',2750,9,275),
('BU01',CURRENT_DATE-3,'Pit A',2800,8,280),('BU01',CURRENT_DATE-2,'Pit B',2850,10,285),
('BU01',CURRENT_DATE-1,'Pit A',2900,9,290),('BU01',CURRENT_DATE,'Pit B',2950,8,295);

-- Mining Fatigue
INSERT INTO mining_fatigue (business_unit_id, nrp, nama, shift, fatigue_level, hours_worked, rest_hours) VALUES
('BU01','MN0001','Budi Santoso','Pagi',1,8,16),('BU01','MN0002','Ahmad Fauzi','Sore',2,9,15),
('BU01','MN0003','Rudi Hermawan','Malam',3,10,14),('BU01','MN0004','Dedi Kurniawan','Pagi',2,8,16),
('BU01','MN0005','Eko Prasetyo','Sore',3,9,15),('BU01','MN0006','Fajar Nugroho','Malam',4,10,14),
('BU01','MN0007','Hendra Wijaya','Pagi',3,8,16),('BU01','MN0008','Indra Gunawan','Sore',4,9,15),
('BU01','MN0009','Joko Susilo','Malam',5,10,14);

-- Mill seed data moved to 077_fix_seed_data.sql (existing tables have different schemas)

-- Estate Harvest 7 records
INSERT INTO estate_harvest (business_unit_id, block_name, tonnage, harvester_nrp, harvester_nama, quality) VALUES
('BU02','Blok A1',20.5,'EST0001','Panen 1','A'),('BU02','Blok A2',25.5,'EST0002','Panen 2','B'),
('BU02','Blok B1',30.5,'EST0003','Panen 3','A'),('BU02','Blok B2',35.5,'EST0004','Panen 4','B'),
('BU02','Blok C1',15.5,'EST0005','Panen 5','A'),('BU02','C2',20.5,'EST0006','Panen 6','B'),
('BU02','D1',25.5,'EST0007','Panen 7','A');

-- Estate Blocks 7 records
INSERT INTO estate_blocks (business_unit_id, block_code, block_name, area_ha, plant_age, yield_potential) VALUES
('BU02','BLK-A1','Blok A1',18.0,3,25.0),('BU02','BLK-A2','Blok A2',21.0,4,30.0),
('BU02','BLK-B1','Blok B1',24.0,5,35.0),('BU02','BLK-B2','Blok B2',27.0,6,40.0),
('BU02','BLK-C1','Blok C1',30.0,7,45.0),('BU02','BLK-C2','C2',33.0,8,50.0),
('BU02','BLK-D1','D1',36.0,9,55.0);

-- RLS POLICIES
ALTER TABLE mining_simper ENABLE ROW LEVEL SECURITY;
ALTER TABLE mining_equipment ENABLE ROW LEVEL SECURITY;
ALTER TABLE mining_production ENABLE ROW LEVEL SECURITY;
ALTER TABLE mining_fuel ENABLE ROW LEVEL SECURITY;
ALTER TABLE mining_fatigue ENABLE ROW LEVEL SECURITY;
ALTER TABLE mining_safety ENABLE ROW LEVEL SECURITY;
ALTER TABLE mining_jsa ENABLE ROW LEVEL SECURITY;
ALTER TABLE estate_harvest ENABLE ROW LEVEL SECURITY;
ALTER TABLE estate_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE estate_irrigation ENABLE ROW LEVEL SECURITY;
ALTER TABLE estate_nursery ENABLE ROW LEVEL SECURITY;
ALTER TABLE estate_transport ENABLE ROW LEVEL SECURITY;
ALTER TABLE estate_field ENABLE ROW LEVEL SECURITY;
ALTER TABLE estate_yield ENABLE ROW LEVEL SECURITY;
ALTER TABLE mill_boiler ENABLE ROW LEVEL SECURITY;
ALTER TABLE mill_press ENABLE ROW LEVEL SECURITY;
ALTER TABLE mill_qc ENABLE ROW LEVEL SECURITY;
ALTER TABLE mill_packing ENABLE ROW LEVEL SECURITY;
ALTER TABLE mill_maintenance ENABLE ROW LEVEL SECURITY;
ALTER TABLE mill_breakdown ENABLE ROW LEVEL SECURITY;
ALTER TABLE mill_shift ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ms_all" ON mining_simper FOR ALL USING (TRUE);
CREATE POLICY "meq_all" ON mining_equipment FOR ALL USING (TRUE);
CREATE POLICY "mpr_all" ON mining_production FOR ALL USING (TRUE);
CREATE POLICY "mfl_all" ON mining_fuel FOR ALL USING (TRUE);
CREATE POLICY "mft_all" ON mining_fatigue FOR ALL USING (TRUE);
CREATE POLICY "msa_all" ON mining_safety FOR ALL USING (TRUE);
CREATE POLICY "mjsa_all" ON mining_jsa FOR ALL USING (TRUE);
CREATE POLICY "eh_all" ON estate_harvest FOR ALL USING (TRUE);
CREATE POLICY "eb_all" ON estate_blocks FOR ALL USING (TRUE);
CREATE POLICY "ei_all" ON estate_irrigation FOR ALL USING (TRUE);
CREATE POLICY "en_all" ON estate_nursery FOR ALL USING (TRUE);
CREATE POLICY "etr_all" ON estate_transport FOR ALL USING (TRUE);
CREATE POLICY "ef_all" ON estate_field FOR ALL USING (TRUE);
CREATE POLICY "ey_all" ON estate_yield FOR ALL USING (TRUE);
CREATE POLICY "mbo_all" ON mill_boiler FOR ALL USING (TRUE);
CREATE POLICY "mprs_all" ON mill_press FOR ALL USING (TRUE);
CREATE POLICY "mqc_all" ON mill_qc FOR ALL USING (TRUE);
CREATE POLICY "mpk_all" ON mill_packing FOR ALL USING (TRUE);
CREATE POLICY "mmn_all" ON mill_maintenance FOR ALL USING (TRUE);
CREATE POLICY "mbrk_all" ON mill_breakdown FOR ALL USING (TRUE);
CREATE POLICY "msh_all" ON mill_shift FOR ALL USING (TRUE);
