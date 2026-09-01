-- INSIGHTWOS V6 - FOUNDATION (HARI 1)

-- 1. TAMBAH KOLOM KE TABEL EXISTING
DO '' BEGIN IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='business_units' AND column_name='tier') THEN ALTER TABLE business_units ADD COLUMN tier INT DEFAULT 0; END IF; END '';
DO '' BEGIN IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='employees_master' AND column_name='role_level') THEN ALTER TABLE employees_master ADD COLUMN role_level INT DEFAULT 1; END IF; END '';
DO '' BEGIN IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='employees_master' AND column_name='auth_id') THEN ALTER TABLE employees_master ADD COLUMN auth_id UUID REFERENCES auth.users(id) ON DELETE SET NULL; END IF; END '';
DO '' BEGIN IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='employees_master' AND column_name='business_unit_id') THEN ALTER TABLE employees_master ADD COLUMN business_unit_id TEXT REFERENCES business_units(id); END IF; END '';
DO '' BEGIN IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_roles' AND column_name='role') THEN ALTER TABLE user_roles ADD COLUMN role TEXT DEFAULT 'worker'; END IF; END '';

CREATE INDEX IF NOT EXISTS idx_employees_auth_id ON employees_master(auth_id);
CREATE INDEX IF NOT EXISTS idx_employees_bu ON employees_master(business_unit_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role ON user_roles(role);

-- 2. TABEL module_definitions
CREATE TABLE IF NOT EXISTS module_definitions (id TEXT PRIMARY KEY, module_code TEXT UNIQUE NOT NULL, module_name TEXT NOT NULL, module_group TEXT NOT NULL CHECK (module_group IN ('CORE','INDUSTRY','GOVERNANCE','PLATFORM','INTELLIGENCE')), description TEXT, minimum_tier_required INT DEFAULT 0 CHECK (minimum_tier_required BETWEEN 0 AND 4), is_industry_module BOOLEAN DEFAULT FALSE, menu_icon TEXT, menu_order INT DEFAULT 0, is_active BOOLEAN DEFAULT TRUE, created_at TIMESTAMPTZ DEFAULT NOW());

-- 3. TABEL business_unit_modules
CREATE TABLE IF NOT EXISTS business_unit_modules (id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT, business_unit_id TEXT NOT NULL REFERENCES business_units(id) ON DELETE CASCADE, module_code TEXT NOT NULL REFERENCES module_definitions(module_code) ON DELETE CASCADE, is_enabled BOOLEAN DEFAULT FALSE, toggled_by TEXT, toggled_at TIMESTAMPTZ, created_at TIMESTAMPTZ DEFAULT NOW(), UNIQUE(business_unit_id, module_code));

-- 4. TABEL audit_log_owner
CREATE TABLE IF NOT EXISTS audit_log_owner (id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT, owner_nrp TEXT NOT NULL, action TEXT NOT NULL, target_type TEXT NOT NULL, target_id TEXT, old_value JSONB, new_value JSONB, ip_address TEXT, created_at TIMESTAMPTZ DEFAULT NOW());

-- 5. TABEL system_bootstrap
CREATE TABLE IF NOT EXISTS system_bootstrap (id INT PRIMARY KEY DEFAULT 1, is_completed BOOLEAN DEFAULT FALSE, completed_at TIMESTAMPTZ, owner_nrp TEXT, created_at TIMESTAMPTZ DEFAULT NOW());
INSERT INTO system_bootstrap (id, is_completed) VALUES (1, FALSE) ON CONFLICT (id) DO NOTHING;


-- 6. SEED MODULE DEFINITIONS - CORE + PLATFORM + GOVERNANCE
INSERT INTO module_definitions (id, module_code, module_name, module_group, minimum_tier_required, is_industry_module, menu_icon, menu_order) VALUES
('mod_001','profile','Profil Karyawan','CORE',0,FALSE,'User',10),('mod_002','attendance','Absensi','CORE',0,FALSE,'Clock',20),('mod_003','leave','Cuti','CORE',1,FALSE,'Calendar',30),('mod_004','overtime','Lembur','CORE',1,FALSE,'Timer',40),('mod_005','payroll','Gaji','CORE',1,FALSE,'DollarSign',50),('mod_006','self_service','Self-Service','CORE',1,FALSE,'Layers',55),('mod_007','kpi','KPI','CORE',2,FALSE,'Target',60),('mod_008','performance','Kinerja','CORE',2,FALSE,'BarChart',70),('mod_009','learning','Learning','CORE',2,FALSE,'BookOpen',80),('mod_010','360_review','Review 360','CORE',2,FALSE,'Users',85),('mod_011','talent','Talent','CORE',3,FALSE,'Star',90),('mod_012','career_path','Career Path','CORE',3,FALSE,'Route',95),('mod_013','succession','Succession','CORE',3,FALSE,'GitBranch',100),('mod_014','recruitment','Rekrutmen','CORE',3,FALSE,'UserPlus',110),('mod_015','onboarding','Onboarding','CORE',3,FALSE,'Clipboard',115),('mod_016','offboarding','Offboarding','CORE',3,FALSE,'UserMinus',120),('mod_017','engagement','Engagement','CORE',3,FALSE,'Heart',130),('mod_018','voice_ideas','Voice & Ideas','CORE',3,FALSE,'MessageCircle',140),('mod_019','badges','Badges','CORE',3,FALSE,'Award',145),('mod_020','referral','Referral','CORE',3,FALSE,'Share2',150),('mod_021','ceo_dashboard','CEO Dashboard','CORE',4,FALSE,'Layout',200),('mod_022','analytics','Analytics','CORE',4,FALSE,'PieChart',210),('mod_023','workforce_planning','Workforce Planning','CORE',4,FALSE,'TrendingUp',220),('mod_024','simulation','Simulasi','CORE',4,FALSE,'Cpu',230),('mod_025','turnover','Turnover','CORE',4,FALSE,'Activity',240),('mod_026','flight_risk','Flight Risk','CORE',4,FALSE,'AlertTriangle',250),('mod_027','narrative','Narrative AI','CORE',4,FALSE,'Brain',260),('mod_050','org_structure','Struktur Organisasi','PLATFORM',0,FALSE,'Network',300),('mod_051','divisions','Divisi','PLATFORM',0,FALSE,'Grid',310),('mod_052','approvals','Approval','PLATFORM',0,FALSE,'CheckCircle',320),('mod_053','audit_log','Audit Log','PLATFORM',0,FALSE,'FileText',330),('mod_054','settings','Pengaturan','PLATFORM',0,FALSE,'Settings',340),('mod_055','export_data','Export Data','PLATFORM',0,FALSE,'Download',350),('mod_056','announcements','Pengumuman','PLATFORM',0,FALSE,'Bell',360),('mod_057','whistleblowing','Whistleblowing','PLATFORM',0,FALSE,'Shield',370),('mod_058','mfa','MFA Setup','PLATFORM',0,FALSE,'Lock',380),('mod_059','module_management','Module Management','PLATFORM',0,FALSE,'Package',390),('mod_060','safety','Safety K3','GOVERNANCE',0,FALSE,'ShieldAlert',400),('mod_061','qhse','QHSE','GOVERNANCE',0,FALSE,'ClipboardCheck',410),('mod_062','certifications','Sertifikasi','GOVERNANCE',0,FALSE,'Award',420)
ON CONFLICT (id) DO NOTHING;

-- 7. SEED MODULE DEFINITIONS - INDUSTRY (Add-on)
INSERT INTO module_definitions (id, module_code, module_name, module_group, minimum_tier_required, is_industry_module, menu_icon, menu_order) VALUES
('mod_101','mining_simper','SIMPER','INDUSTRY',0,TRUE,'HardHat',500),('mod_102','mining_equipment','Heavy Equipment','INDUSTRY',0,TRUE,'Truck',510),('mod_103','mining_production','Produksi Tambang','INDUSTRY',0,TRUE,'Factory',520),('mod_104','mining_fuel','BBM & Fuel','INDUSTRY',0,TRUE,'Droplet',530),('mod_105','mining_fatigue','Fatigue Monitor','INDUSTRY',0,TRUE,'Eye',540),('mod_106','mining_safety','K3 Tambang','INDUSTRY',0,TRUE,'ShieldAlert',550),('mod_107','mining_jsa','JSA','INDUSTRY',0,TRUE,'FileCheck',560),('mod_111','estate_harvest','Panen','INDUSTRY',0,TRUE,'Scissors',600),('mod_112','estate_blocks','Block & Afdeling','INDUSTRY',0,TRUE,'Grid',610),('mod_113','estate_irrigation','Irigasi','INDUSTRY',0,TRUE,'Droplets',620),('mod_114','estate_nursery','Pembibitan','INDUSTRY',0,TRUE,'Sprout',630),('mod_115','estate_transport','Transport TBS','INDUSTRY',0,TRUE,'Truck',640),('mod_116','estate_field','Aktivitas Lapangan','INDUSTRY',0,TRUE,'MapPin',650),('mod_117','estate_yield','Produktivitas','INDUSTRY',0,TRUE,'TrendingUp',660),('mod_121','mill_boiler','Boiler Monitor','INDUSTRY',0,TRUE,'Thermometer',700),('mod_122','mill_press','Mesin Press','INDUSTRY',0,TRUE,'Cpu',710),('mod_123','mill_qc','QC Lab','INDUSTRY',0,TRUE,'Flask',720),('mod_124','mill_packing','Packing','INDUSTRY',0,TRUE,'Package',730),('mod_125','mill_maintenance','Preventive Maintenance','INDUSTRY',0,TRUE,'Wrench',740),('mod_126','mill_breakdown','Breakdown Report','INDUSTRY',0,TRUE,'AlertTriangle',750),('mod_127','mill_shift','Jadwal Shift','INDUSTRY',0,TRUE,'Clock',760)
ON CONFLICT (id) DO NOTHING;

-- 8. SEED business_unit_modules (Industry default OFF)
INSERT INTO business_unit_modules (business_unit_id, module_code, is_enabled)
SELECT bu.id, md.module_code, FALSE
FROM business_units bu
CROSS JOIN module_definitions md
WHERE md.is_industry_module = TRUE
AND (
  (bu.unit_code = 'MINING' AND md.module_code LIKE 'mining_%')
  OR (bu.unit_code = 'ESTATE' AND md.module_code LIKE 'estate_%')
  OR (bu.unit_code = 'MILL' AND md.module_code LIKE 'mill_%')
)
ON CONFLICT (business_unit_id, module_code) DO NOTHING;

-- 9. RLS POLICIES
ALTER TABLE module_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE business_unit_modules ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log_owner ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_bootstrap ENABLE ROW LEVEL SECURITY;
CREATE POLICY "md_select" ON module_definitions FOR SELECT USING (TRUE);
CREATE POLICY "md_insert" ON module_definitions FOR INSERT WITH CHECK (TRUE);
CREATE POLICY "md_update" ON module_definitions FOR UPDATE USING (TRUE);
CREATE POLICY "bum_select" ON business_unit_modules FOR SELECT USING (TRUE);
CREATE POLICY "bum_update" ON business_unit_modules FOR UPDATE USING (TRUE);
CREATE POLICY "bum_insert" ON business_unit_modules FOR INSERT WITH CHECK (TRUE);
CREATE POLICY "alo_select" ON audit_log_owner FOR SELECT USING (TRUE);
CREATE POLICY "alo_insert" ON audit_log_owner FOR INSERT WITH CHECK (TRUE);
CREATE POLICY "sb_select" ON system_bootstrap FOR SELECT USING (TRUE);
CREATE POLICY "sb_update" ON system_bootstrap FOR UPDATE USING (TRUE);
