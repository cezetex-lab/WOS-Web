-- Fase 2: Master Data (6 tabel + seed 48 divisi)

-- MASTER DATA TABLES

-- 2.1 Divisions
CREATE TABLE IF NOT EXISTS master_divisions (
  id SERIAL PRIMARY KEY,
  division_code TEXT NOT NULL UNIQUE,
  division_name TEXT NOT NULL,
  parent_division TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE master_divisions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS md_pub ON master_divisions;
CREATE POLICY md_pub ON master_divisions FOR SELECT USING (true);

-- 2.2 Positions
CREATE TABLE IF NOT EXISTS master_positions (
  id SERIAL PRIMARY KEY,
  position_code TEXT NOT NULL UNIQUE,
  position_name TEXT NOT NULL,
  level_jabatan TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE master_positions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS mp_pub ON master_positions;
CREATE POLICY mp_pub ON master_positions FOR SELECT USING (true);

-- 2.3 Job Levels
CREATE TABLE IF NOT EXISTS master_job_levels (
  id SERIAL PRIMARY KEY,
  level_code TEXT NOT NULL UNIQUE,
  level_name TEXT NOT NULL,
  level_order INT NOT NULL,
  is_active BOOLEAN DEFAULT true
);
ALTER TABLE master_job_levels ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS mjl_pub ON master_job_levels;
CREATE POLICY mjl_pub ON master_job_levels FOR SELECT USING (true);

-- 2.4 Employment Status
CREATE TABLE IF NOT EXISTS master_employment_status (
  id SERIAL PRIMARY KEY,
  status_code TEXT NOT NULL UNIQUE,
  status_name TEXT NOT NULL,
  is_active BOOLEAN DEFAULT true
);
ALTER TABLE master_employment_status ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS mes_pub ON master_employment_status;
CREATE POLICY mes_pub ON master_employment_status FOR SELECT USING (true);

-- 2.5 Locations
CREATE TABLE IF NOT EXISTS master_locations (
  id SERIAL PRIMARY KEY,
  location_code TEXT NOT NULL UNIQUE,
  location_name TEXT NOT NULL,
  is_active BOOLEAN DEFAULT true
);
ALTER TABLE master_locations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ml_pub ON master_locations;
CREATE POLICY ml_pub ON master_locations FOR SELECT USING (true);

-- 2.6 Validation Rules
CREATE TABLE IF NOT EXISTS validation_rules (
  id SERIAL PRIMARY KEY,
  field_name TEXT NOT NULL,
  rule_type TEXT NOT NULL,
  rule_value TEXT NOT NULL,
  error_message TEXT,
  is_active BOOLEAN DEFAULT true
);
ALTER TABLE validation_rules ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS vr_pub ON validation_rules;
CREATE POLICY vr_pub ON validation_rules FOR SELECT USING (true);

-- SEED DATA

-- 48 Divisi (from GAS)
INSERT INTO master_divisions (division_code, division_name, parent_division) VALUES
('CORP','Korporat/HQ',NULL),
('HRD','Human Resources Development','CORP'),
('GA','General Affairs','CORP'),
('FIN','Finance','CORP'),
('ACC','Accounting','FIN'),
('TRE','Treasury','FIN'),
('MKT','Marketing','CORP'),
('SALES','Sales','CORP'),
('OPS','Operational','CORP'),
('PRD','Production','OPS'),
('QC','Quality Control','OPS'),
('ENG','Engineering','OPS'),
('MAINT','Maintenance','OPS'),
('WHS','Warehouse','OPS'),
('LOG','Logistics','OPS'),
('IT','Information Technology','CORP'),
('SYS','System Administration','IT'),
('DEV','Development','IT'),
('SEC','Security','CORP'),
('HSE','Health Safety Environment','OPS'),
('LEG','Legal','CORP'),
('COR','Corporate Secretary','CORP'),
('ADM','Administration','CORP'),
('PUR','Procurement','CORP'),
('QHSE','Quality HSE','OPS'),
('RND','Research & Development','CORP'),
('CRM','Customer Relations','MKT'),
('PRM','Public Relations','CORP'),
('EDU','Education & Training','HRD'),
('TRL','Training & Learning','HRD'),
('CUL','Culture','HRD'),
('BEN','Benefits','HRD'),
('REC','Recruitment','HRD'),
('CMP','Compensation','HRD'),
('REL','Industrial Relations','HRD'),
('MIN','Mining','OPS'),
('EST','Estate/Plantation','OPS'),
('MIL','Mill/Pabrik','OPS'),
('PKL','Perkebunan','OPS'),
('TRN','Transport','OPS'),
('FLD','Field Operations','OPS'),
('SPL','Supply Chain','OPS'),
('CTO','CITO Office','CORP'),
('BUS','Business Development','CORP'),
('STR','Strategy','CORP'),
('INT','Internal Audit','CORP'),
('CSR','CSR','CORP'),
('DIG','Digital','IT')
ON CONFLICT (division_code) DO NOTHING;

-- 12 Posisi
INSERT INTO master_positions (position_code, position_name, level_jabatan) VALUES
('MAG','Magang','Entry'),
('STF','Staff','Entry'),
('SST','Senior Staff','Entry'),
('SPV','Supervisor','Mid'),
('SPT','Senior Supervisor','Mid'),
('MGR','Manager','Middle'),
('SMGR','Senior Manager','Middle'),
('DIR','Director','Top'),
('SVP','Senior Vice President','Top'),
('VP','Vice President','Top'),
('CXX','C-Level (CEO/CFO/CTO)','Top'),
('CEO','Chief Executive Officer','Top')
ON CONFLICT (position_code) DO NOTHING;

-- 4 Job Levels
INSERT INTO master_job_levels (level_code, level_name, level_order) VALUES
('ENTRY','Entry Level',1),
('MID','Mid Level',2),
('MIDDLE','Middle Management',3),
('TOP','Top Management',4)
ON CONFLICT (level_code) DO NOTHING;

-- 5 Employment Status
INSERT INTO master_employment_status (status_code, status_name) VALUES
('PKWTT','Pegawai dengan Perjanjian Kerja Waktu Tidak Tertentu'),
('PKWT','Pegawai dengan Perjanjian Kerja Waktu Tertentu'),
('PROBATION','Masa Percobaan'),
('BHL','Bukan Hubungan Kerja (Outsourcing)'),
('INTERN','Internship/Magang')
ON CONFLICT (status_code) DO NOTHING;

-- 7 Locations
INSERT INTO master_locations (location_code, location_name) VALUES
('PUSAT','Kantor Pusat'),
('CABANG','Kantor Cabang'),
('SITE','Site/Field'),
('MILL','Pabrik/Mill'),
('ESTATE','Perkebunan/Estate'),
('REMOTE','Remote/WFH'),
('OTHER','Lainnya')
ON CONFLICT (location_code) DO NOTHING;

-- 23 Validation Rules
INSERT INTO validation_rules (field_name, rule_type, rule_value, error_message) VALUES
('nik','regex','^[0-9]{16}$','NIK harus 16 digit angka'),
('npwp','regex','^[0-9]{15,16}$','NPWP harus 15-16 digit angka'),
('nrp','min_length','3','NRP minimal 3 karakter'),
('nrp','max_length','20','NRP maksimal 20 karakter'),
('email','regex','^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$','Format email tidak valid'),
('no_hp','regex','^[0-9]{10,13}$','No HP harus 10-13 digit'),
('tanggal_lahir','min_date','1940-01-01','Tanggal lahir terlalu tua'),
('tanggal_lahir','max_date','-18 years','Karyawan harus minimal 18 tahun'),
('tanggal_masuk','min_date','2000-01-01','Tanggal masuk tidak valid'),
('base_salary','min_value','0','Gaji pokok tidak boleh negatif'),
('base_salary','max_value','500000000','Gaji pokok melebihi batas'),
('kk','regex','^[0-9]{16}$','Nomor KK harus 16 digit'),
('nama','min_length','2','Nama minimal 2 karakter'),
('nama','max_length','100','Nama maksimal 100 karakter'),
('divisi','required','true','Divisi wajib diisi'),
('posisi','required','true','Posisi wajib diisi'),
('status_kerja','required','true','Status kerja wajib diisi'),
('tanggal_masuk','required','true','Tanggal masuk wajib diisi'),
('golongan_darah','enum','A,B,AB,O','Golongan darah harus A/B/AB/O'),
('status_pernikahan','enum','Menikah,Belum,Cerai','Status pernikahan tidak valid'),
('level_jabatan','enum','Entry,Mid,Middle,Top','Level jabatan tidak valid'),
('ukuran_celana','min_value','28','Ukuran celana minimal 28'),
('ukuran_celana','max_value','44','Ukuran celana maksimal 44')
ON CONFLICT DO NOTHING;

-- RPC: get_master_data (semua master dalam 1 panggilan)
CREATE OR REPLACE FUNCTION get_master_data() RETURNS JSONB AS $$
BEGIN
  RETURN jsonb_build_object('ok', true,
    'divisions', (SELECT COALESCE(jsonb_agg(row_to_json(t)),'[]'::jsonb) FROM (SELECT * FROM master_divisions WHERE is_active ORDER BY division_name) t),
    'positions', (SELECT COALESCE(jsonb_agg(row_to_json(t)),'[]'::jsonb) FROM (SELECT * FROM master_positions WHERE is_active ORDER BY position_name) t),
    'job_levels', (SELECT COALESCE(jsonb_agg(row_to_json(t)),'[]'::jsonb) FROM (SELECT * FROM master_job_levels WHERE is_active ORDER BY level_order) t),
    'employment_status', (SELECT COALESCE(jsonb_agg(row_to_json(t)),'[]'::jsonb) FROM (SELECT * FROM master_employment_status WHERE is_active) t),
    'locations', (SELECT COALESCE(jsonb_agg(row_to_json(t)),'[]'::jsonb) FROM (SELECT * FROM master_locations WHERE is_active) t),
    'validation_rules', (SELECT COALESCE(jsonb_agg(row_to_json(t)),'[]'::jsonb) FROM (SELECT * FROM validation_rules WHERE is_active) t)
  );
END; $$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION get_master_data() TO authenticated;
