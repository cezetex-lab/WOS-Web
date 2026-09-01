-- FIX: Replace broken INSERT statements with correct column names
-- Existing tables from 052 have different schemas than 074 assumed

-- Mill Boiler (existing: boiler_code, temperature_c, pressure_bar, fuel_consumption_kg_hr)
INSERT INTO mill_boiler (boiler_code, boiler_name, capacity_kg_hr, status, temperature_c, pressure_bar, fuel_consumption_kg_hr, efficiency_pct, fuel_type, site_code) VALUES
('BLR-01','Boiler Utama',5000,'RUNNING',187,12.5,530,75,'BIOMASS','S03'),
('BLR-02','Boiler Backup',4000,'RUNNING',194,13.5,560,80,'BIOMASS','S03'),
('BLR-03','Boiler Ekspor',6000,'STANDBY',201,14.5,590,85,'BIOMASS','S03'),
('BLR-04','Boiler Lama',3500,'MAINTENANCE',180,15.5,620,78,'FURNACE_OIL','S03'),
('BLR-05','Boiler Baru',5500,'RUNNING',187,12.5,500,82,'BIOMASS','S03'),
('BLR-06','Boiler CPO',4500,'RUNNING',194,13.5,530,88,'BIOMASS','S03'),
('BLR-07','Boiler PKS',5000,'RUNNING',201,14.5,560,90,'BIOMASS','S03')
ON CONFLICT (boiler_code) DO NOTHING;

-- Mill Press (existing: press_code, rpm, oil_quality)
INSERT INTO mill_press (press_code, press_name, capacity_tph, status, rpm, oil_quality, site_code) VALUES
('PRS-01','Screw Press 1',15,'RUNNING',280,'GOOD','S03'),
('PRS-02','Screw Press 2',15,'RUNNING',275,'GOOD','S03'),
('PRS-03','Screw Press 3',12,'STANDBY',0,'FAIR','S03'),
('PRS-04','Screw Press 4',15,'RUNNING',285,'EXCELLENT','S03'),
('PRS-05','Screw Press 5',10,'MAINTENANCE',0,'POOR','S03'),
('PRS-06','Screw Press 6',15,'RUNNING',270,'GOOD','S03'),
('PRS-07','Screw Press 7',12,'RUNNING',280,'GOOD','S03')
ON CONFLICT (press_code) DO NOTHING;

-- Mill QC Results (existing: batch_id, ffa_pct, moisture_pct, dobi, result)
INSERT INTO mill_qc_results (batch_id, sample_date, ffa_pct, moisture_pct, dobi, result, tested_by, site_code) VALUES
('QC-001',CURRENT_DATE-6,1.80,9.3,3.0,'PASS','Lab Tech 1','S03'),
('QC-002',CURRENT_DATE-5,2.10,10.1,3.5,'PASS','Lab Tech 2','S03'),
('QC-003',CURRENT_DATE-4,2.40,10.9,4.0,'PASS','Lab Tech 1','S03'),
('QC-004',CURRENT_DATE-3,2.70,11.7,4.5,'REVIEW','Lab Tech 3','S03'),
('QC-005',CURRENT_DATE-2,3.00,12.5,5.0,'PASS','Lab Tech 1','S03'),
('QC-006',CURRENT_DATE-1,3.30,13.3,5.5,'REJECT','Lab Tech 2','S03'),
('QC-007',CURRENT_DATE,3.60,14.1,6.0,'PASS','Lab Tech 1','S03');

-- Mill Packing (existing: pack_date, product_type, quantity_kg, status)
INSERT INTO mill_packing (pack_date, product_type, quantity_kg, batch_id, destination, status, operator_nrp, site_code) VALUES
(CURRENT_DATE-6,'CPO',15000,'QC-001','PT Sawit Jaya','DISPATCHED','MN0001','S03'),
(CURRENT_DATE-5,'PK',8000,'QC-002','PT Perkasa','LOADED','MN0002','S03'),
(CURRENT_DATE-4,'CPO',18000,'QC-003','PT Makmur','DISPATCHED','MN0003','S03'),
(CURRENT_DATE-3,'PKS',12000,'QC-004','PT Abadi','PACKED','MN0004','S03'),
(CURRENT_DATE-2,'CPO',16000,'QC-005','PT Sejahtera','DISPATCHED','MN0005','S03'),
(CURRENT_DATE-1,'OIL',9000,'QC-006','PT Gemilang','LOADED','MN0006','S03'),
(CURRENT_DATE,'CPO',14000,'QC-007','PT Lestari','PACKED','MN0007','S03');

-- Mill Maintenance (existing: equipment_code, maintenance_type, scheduled_date, status)
INSERT INTO mill_maintenance (equipment_code, equipment_name, maintenance_type, scheduled_date, status, assigned_to, priority, site_code) VALUES
('PRS-05','Screw Press 5','CORRECTIVE',CURRENT_DATE-2,'IN_PROGRESS','Teknisi 1','HIGH','S03'),
('BLR-04','Boiler Lama','PREVENTIVE',CURRENT_DATE+3,'SCHEDULED','Teknisi 2','MEDIUM','S03'),
('PRS-03','Screw Press 3','PREVENTIVE',CURRENT_DATE+5,'SCHEDULED','Teknisi 3','LOW','S03');

-- Mill Breakdowns (existing: equipment_code, breakdown_time, severity, status)
INSERT INTO mill_breakdowns (equipment_code, equipment_name, breakdown_time, severity, category, description, reported_by, status, site_code) VALUES
('PRS-05','Screw Press 5',CURRENT_DATE-2 + INTERVAL '14 hours','HIGH','MECHANICAL','Bearing rusak, perlu penggantian','Operator 1','IN_PROGRESS','S03'),
('BLR-04','Boiler Lama',CURRENT_DATE-5 + INTERVAL '9 hours','MEDIUM','INSTRUMENT','Pressure sensor error','Operator 2','RESOLVED','S03');
