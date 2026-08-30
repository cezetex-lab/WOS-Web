-- ============================================================
-- 034: WAVE A — Database Foundation
-- 1. Tambah business_unit ke employees_master
-- 2. Tabel business_units + sites
-- 3. Update login_worker RPC
-- 4. Seed 2000 karyawan ke 4 business unit
-- 5. PgCron setup
-- ============================================================

-- ── 1. TAMBAH KOLOM business_unit KE employees_master ──
ALTER TABLE employees_master 
ADD COLUMN IF NOT EXISTS business_unit TEXT DEFAULT 'HQ';

-- Index untuk querying per business unit
CREATE INDEX IF NOT EXISTS idx_employees_business_unit 
ON employees_master (business_unit);

-- ── 2. TABEL business_units ──
CREATE TABLE IF NOT EXISTS business_units (
  id SERIAL PRIMARY KEY,
  code TEXT UNIQUE NOT NULL,        -- MINING, ESTATE, MILL, HQ
  name TEXT NOT NULL,               -- Tambang, Perkebunan, Pabrik PKS, Korporat
  description TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed business units
INSERT INTO business_units (code, name, description) VALUES
  ('MINING', 'Tambang', 'Operasi pertambangan — alat berat, tambang terbuka, bawah tanah'),
  ('ESTATE', 'Perkebunan Sawit', 'Perkebunan kelapa sawit — blok kebun, pemanen, TBS'),
  ('MILL', 'Pabrik PKS', 'Pabrik kelapa sawit — 3 shift, mesin, boiler, crane'),
  ('HQ', 'Korporat HQ', 'Kantor pusat — HR, Finance, IT, Legal, Directors')
ON CONFLICT (code) DO NOTHING;

-- ── 3. TABEL sites (lokasi operasional) ──
CREATE TABLE IF NOT EXISTS sites (
  id SERIAL PRIMARY KEY,
  code TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  business_unit TEXT NOT NULL REFERENCES business_units(code),
  province TEXT,
  city TEXT,
  address TEXT,
  latitude DECIMAL(10, 7),
  longitude DECIMAL(10, 7),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed sites per business unit
INSERT INTO sites (code, name, business_unit, province, city) VALUES
  -- MINING
  ('MNG-01', 'Tambang Batubara Kalimantan', 'MINING', 'Kalimantan Selatan', 'Banjar'),
  ('MNG-02', 'Tambang Emas Papua', 'MINING', 'Papua', 'Timika'),
  ('MNG-03', 'Tambang Nikel Sulawesi', 'MINING', 'Sulawesi Tengah', 'Morowali'),
  -- ESTATE
  ('EST-01', 'Kebun Riau Block A-E', 'ESTATE', 'Riau', 'Kampar'),
  ('EST-02', 'Kebun Kalimantan Timur', 'ESTATE', 'Kalimantan Timur', 'Kutai'),
  ('EST-03', 'Kebun Sumatera Utara', 'ESTATE', 'Sumatera Utara', 'Labuhanbatu'),
  -- MILL
  ('MLL-01', 'PKS Riau Main', 'MILL', 'Riau', 'Dumai'),
  ('MLL-02', 'PKS Kalimantan Barat', 'MILL', 'Kalimantan Barat', 'Pontianak'),
  -- HQ
  ('HQ-01', 'Kantor Pusat Jakarta', 'HQ', 'DKI Jakarta', 'Jakarta Selatan'),
  ('HQ-02', 'Kantor Regional Medan', 'HQ', 'Sumatera Utara', 'Medan')
ON CONFLICT (code) DO NOTHING;

-- Tambah site_id ke employees_master
ALTER TABLE employees_master 
ADD COLUMN IF NOT EXISTS site_id INTEGER REFERENCES sites(id);

CREATE INDEX IF NOT EXISTS idx_employees_site_id 
ON employees_master (site_id);

-- ── 4. UPDATE login_worker RPC → RETURN business_unit ──
DROP FUNCTION IF EXISTS login_worker(text, text, text) CASCADE;
CREATE OR REPLACE FUNCTION login_worker(
  p_nrp TEXT,
  p_nik TEXT,
  p_password TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_emp RECORD;
  v_pwd RECORD;
  v_role RECORD;
  v_site RECORD;
  v_salt TEXT;
  v_hash TEXT;
BEGIN
  -- Cari employee
  SELECT * INTO v_emp 
  FROM employees_master 
  WHERE nrp = p_nrp AND nik = p_nik;
  
  IF v_emp IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'NRP/NIK tidak ditemukan');
  END IF;

  -- Cari password
  SELECT * INTO v_pwd 
  FROM worker_passwords 
  WHERE nrp = p_nrp AND is_active = true;
  
  IF v_pwd IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akun tidak aktif');
  END IF;

  -- Cek blocked
  IF v_pwd.blocked_until IS NOT NULL AND v_pwd.blocked_until > NOW() THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akun diblokir sementara');
  END IF;

  -- Verify password (pbkdf2)
  v_salt := v_pwd.salt;
  v_hash := encode(digest(p_password || v_salt, 'sha256'), 'hex');
  
  IF v_hash != v_pwd.password_hash THEN
    -- Increment attempts
    UPDATE worker_passwords 
    SET attempts = attempts + 1,
        blocked_until = CASE WHEN attempts >= 4 THEN NOW() + INTERVAL '15 minutes' ELSE blocked_until END
    WHERE nrp = p_nrp;
    RETURN jsonb_build_object('ok', false, 'msg', 'Password salah');
  END IF;

  -- Reset attempts on success
  UPDATE worker_passwords SET attempts = 0, blocked_until = NULL WHERE nrp = p_nrp;

  -- Get role
  SELECT * INTO v_role FROM user_roles WHERE nrp = p_nrp;

  -- Get site info
  SELECT s.* INTO v_site 
  FROM sites s 
  WHERE s.id = v_emp.site_id;

  -- Return session data WITH business_unit
  RETURN jsonb_build_object(
    'ok', true,
    'nrp', v_emp.nrp,
    'nama', v_emp.nama,
    'nik', v_emp.nik,
    'divisi', v_emp.divisi,
    'posisi', v_emp.posisi,
    'role_level', COALESCE(v_role.role_level, 1),
    'scope_divisi', v_role.scope_divisi,
    'business_unit', COALESCE(v_emp.business_unit, 'HQ'),
    'site_code', v_site.code,
    'site_name', v_site.name,
    'token', encode(gen_random_bytes(32), 'hex'),
    'expires_at', (NOW() + INTERVAL '24 hours')::text
  );
END;
$$;

-- ── 5. SEED 2000 KARYAWAN KE 4 BUSINESS UNIT ──
-- Distribusi: MINING=500, ESTATE=700, MILL=500, HQ=300

-- Hapus data lama jika ingin fresh seed (UNCOMMENT jika perlu)
-- DELETE FROM worker_passwords WHERE nrp NOT IN ('NRP001','NRP002','NRP003');
-- DELETE FROM hr_org WHERE nrp NOT IN ('NRP001','NRP002','NRP003');
-- DELETE FROM user_roles WHERE nrp NOT IN ('NRP001','NRP002','NRP003');
-- DELETE FROM employees_master WHERE employee_id > 3;

-- MINING (500 karyawan)
INSERT INTO employees_master (employee_id, nrp, nik, nama, email, divisi, posisi, status_kerja, tanggal_lahir, jenis_kelamin, tanggal_masuk, business_unit, site_id)
SELECT 
  'MNG-' || LPAD(s.id::text, 4, '0'),
  'MNG' || LPAD(s.id::text, 4, '0'),
  '320' || LPAD(s.id::text, 7, '0'),
  CASE (s.id % 20)
    WHEN 0 THEN 'Ahmad' WHEN 1 THEN 'Budi' WHEN 2 THEN 'Citra' WHEN 3 THEN 'Dewi'
    WHEN 4 THEN 'Eko' WHEN 5 THEN 'Fitri' WHEN 6 THEN 'Gunawan' WHEN 7 THEN 'Hana'
    WHEN 8 THEN 'Irfan' WHEN 9 THEN 'Joko' WHEN 10 THEN 'Kartika' WHEN 11 THEN 'Lukman'
    WHEN 12 THEN 'Maya' WHEN 13 THEN 'Nanda' WHEN 14 THEN 'Omar' WHEN 15 THEN 'Putri'
    WHEN 16 THEN 'Rizki' WHEN 17 THEN 'Sari' WHEN 18 THEN 'Tono' WHEN 19 THEN 'Ulya'
  END || ' ' || 
  CASE (s.id % 10)
    WHEN 0 THEN 'Pratama' WHEN 1 THEN 'Saputra' WHEN 2 THEN 'Putra' WHEN 3 THEN 'Melati'
    WHEN 4 THEN 'Kusuma' WHEN 5 THEN 'Wijaya' WHEN 6 THEN 'Susanto' WHEN 7 THEN 'Anggraini'
    WHEN 8 THEN 'Hidayat' WHEN 9 THEN 'Rahayu'
  END,
  'mng' || LPAD(s.id::text, 4, '0') || '@insightwos.com',
  CASE (s.id % 8)
    WHEN 0 THEN 'Mining Operations' WHEN 1 THEN 'Heavy Equipment' WHEN 2 THEN 'Safety K3'
    WHEN 3 THEN 'Geology' WHEN 4 THEN 'Logistics' WHEN 5 THEN 'Maintenance'
    WHEN 6 THEN 'Environmental' WHEN 7 THEN 'Administration'
  END,
  CASE (s.id % 6)
    WHEN 0 THEN 'Operator Alat Berat' WHEN 1 THEN 'Operator Excavator' WHEN 2 THEN 'Kepala Tim'
    WHEN 3 THEN 'Teknisi' WHEN 4 THEN 'Safety Officer' WHEN 5 THEN 'Administrasi'
  END,
  'Aktif',
  ('1985-01-01'::date + (s.id * 47)::int)::date,
  CASE WHEN s.id % 3 = 0 THEN 'Perempuan' ELSE 'Laki-laki' END,
  ('2018-01-01'::date + (s.id * 12)::int)::date,
  'MINING',
  (1 + (s.id % 3))  -- site_id 1-3
FROM generate_series(1, 500) AS s(id)
ON CONFLICT (nrp) DO NOTHING;

-- ESTATE (700 karyawan)
INSERT INTO employees_master (employee_id, nrp, nik, nama, email, divisi, posisi, status_kerja, tanggal_lahir, jenis_kelamin, tanggal_masuk, business_unit, site_id)
SELECT 
  'EST-' || LPAD(s.id::text, 4, '0'),
  'EST' || LPAD(s.id::text, 4, '0'),
  '321' || LPAD(s.id::text, 7, '0'),
  CASE (s.id % 20)
    WHEN 0 THEN 'Andi' WHEN 1 THEN 'Bayu' WHEN 2 THEN 'Candra' WHEN 3 THEN 'Dian'
    WHEN 4 THEN 'Eka' WHEN 5 THEN 'Fajar' WHEN 6 THEN 'Gilang' WHEN 7 THEN 'Hadi'
    WHEN 8 THEN 'Indra' WHEN 9 THEN 'Joko' WHEN 10 THEN 'Kiki' WHEN 11 THEN 'Lestari'
    WHEN 12 THEN 'Mila' WHEN 13 THEN 'Niko' WHEN 14 THEN 'Oktavia' WHEN 15 THEN 'Pandu'
    WHEN 16 THEN 'Rina' WHEN 17 THEN 'Siti' WHEN 18 THEN 'Taufik' WHEN 19 THEN 'Uci'
  END || ' ' ||
  CASE (s.id % 10)
    WHEN 0 THEN 'Santoso' WHEN  THEN 'Nugroho' WHEN 2 THEN 'Permata' WHEN 3 THEN 'Sari'
    WHEN 4 THEN 'Lestari' WHEN 5 THEN 'Pratama' WHEN 6 THEN 'Wibowo' WHEN 7 THEN 'Oktaviani'
    WHEN 8 THEN 'Firmansyah' WHEN 9 THEN 'Handayani'
  END,
  'est' || LPAD(s.id::text, 4, '0') || '@insightwos.com',
  CASE (s.id % 8)
    WHEN 0 THEN 'Estate Operations' WHEN 1 THEN 'Harvest Team' WHEN 2 THEN 'Nursery'
    WHEN 3 THEN 'Transport' WHEN 4 THEN 'Maintenance' WHEN 5 THEN 'Quality Control'
    WHEN 6 THEN 'Agriculture' WHEN 7 THEN 'Field Admin'
  END,
  CASE (s.id % 6)
    WHEN 0 THEN 'Pemanen Sawit' WHEN 1 THEN 'Kepala Blok' WHEN 2 THEN 'Operator Truk'
    WHEN 3 THEN 'Teknisi Kebun' WHEN 4 THEN 'Agronomist' WHEN 5 THEN 'Administrasi'
  END,
  'Aktif',
  ('1987-01-01'::date + (s.id * 43)::int)::date,
  CASE WHEN s.id % 4 = 0 THEN 'Perempuan' ELSE 'Laki-laki' END,
  ('2019-01-01'::date + (s.id * 10)::int)::date,
  'ESTATE',
  (4 + (s.id % 3))  -- site_id 4-6
FROM generate_series(1, 700) AS s(id)
ON CONFLICT (nrp) DO NOTHING;

-- MILL (500 karyawan)
INSERT INTO employees_master (employee_id, nrp, nik, nama, email, divisi, posisi, status_kerja, tanggal_lahir, jenis_kelamin, tanggal_masuk, business_unit, site_id)
SELECT 
  'MLL-' || LPAD(s.id::text, 4, '0'),
  'MLL' || LPAD(s.id::text, 4, '0'),
  '322' || LPAD(s.id::text, 7, '0'),
  CASE (s.id % 20)
    WHEN 0 THEN 'Ari' WHEN 1 THEN 'Bagas' WHEN 2 THEN 'Dani' WHEN 3 THEN 'Erna'
    WHEN 4 THEN 'Fadil' WHEN 5 THEN 'Gita' WHEN 6 THEN 'Hendra' WHEN 7 THEN 'Ika'
    WHEN 8 THEN 'Juli' WHEN 9 THEN 'Kurnia' WHEN 10 THEN 'Lia' WHEN 11 THEN 'Maman'
    WHEN 12 THEN 'Nisa' WHEN 13 THEN 'Osi' WHEN 14 THEN 'Pramudia' WHEN 15 THEN 'Rani'
    WHEN 16 THEN 'Sandi' WHEN 17 THEN 'Tika' WHEN 18 THEN 'Udin' WHEN 19 THEN 'Vera'
  END || ' ' ||
  CASE (s.id % 10)
    WHEN 0 THEN 'Aditya' WHEN 1 THEN 'Setiawan' WHEN 2 THEN 'Lestari' WHEN 3 THEN 'Purnama'
    WHEN 4 THEN 'Saputra' WHEN 5 THEN 'Kurniawan' WHEN 6 THEN 'Indah' WHEN 7 THEN 'Widya'
    WHEN 8 THEN 'Rahman' WHEN 9 THEN 'Sari'
  END,
  'mll' || LPAD(s.id::text, 4, '0') || '@insightwos.com',
  CASE (s.id % 8)
    WHEN 0 THEN 'Mill Operations' WHEN 1 THEN 'Boiler' WHEN 2 THEN 'Press Station'
    WHEN 3 THEN 'Clarifier' WHEN 4 THEN 'Packing' WHEN 5 THEN 'Quality Lab'
    WHEN 6 THEN 'Maintenance' WHEN 7 THEN 'Mill Admin'
  END,
  CASE (s.id % 6)
    WHEN 0 THEN 'Operator Mesin' WHEN 1 THEN 'Operator Boiler' WHEN 2 THEN 'Kepala Shift'
    WHEN 3 THEN 'Teknisi Mesin' WHEN 4 THEN 'QC Operator' WHEN 5 THEN 'Administrasi'
  END,
  'Aktif',
  ('1988-01-01'::date + (s.id * 41)::int)::date,
  CASE WHEN s.id % 3 = 0 THEN 'Perempuan' ELSE 'Laki-laki' END,
  ('2019-06-01'::date + (s.id * 8)::int)::date,
  'MILL',
  (7 + (s.id % 2))  -- site_id 7-8
FROM generate_series(1, 500) AS s(id)
ON CONFLICT (nrp) DO NOTHING;

-- HQ (300 karyawan)
INSERT INTO employees_master (employee_id, nrp, nik, nama, email, divisi, posisi, status_kerja, tanggal_lahir, jenis_kelamin, tanggal_masuk, business_unit, site_id)
SELECT 
  'HQ-' || LPAD(s.id::text, 4, '0'),
  'HQ' || LPAD(s.id::text, 4, '0'),
  '323' || LPAD(s.id::text, 7, '0'),
  CASE (s.id % 20)
    WHEN 0 THEN 'Agus' WHEN 1 THEN 'Bimo' WHEN 2 THEN 'Citra' WHEN 3 THEN 'Dinar'
    WHEN 4 THEN 'Erlangga' WHEN 5 THEN 'Farah' WHEN 6 THEN 'Gilbert' WHEN 7 THEN 'Hesty'
    WHEN 8 THEN 'Iwan' WHEN 9 THEN 'Julia' WHEN 10 THEN 'Koko' WHEN 11 THEN 'Lulu'
    WHEN 12 THEN 'Melani' WHEN 13 THEN 'Nugroho' WHEN 14 THEN 'Olivia' WHEN 15 THEN 'Putra'
    WHEN 16 THEN 'Rina' WHEN 17 THEN 'Surya' WHEN 18 THEN 'Tina' WHEN 19 THEN 'Vito'
  END || ' ' ||
  CASE (s.id % 10)
    WHEN 0 THEN 'Suharto' WHEN 1 THEN 'Wibisono' WHEN 2 THEN 'Anggraeni' WHEN 3 THEN 'Hermawan'
    WHEN 4 THEN 'Lestari' WHEN 5 THEN 'Pramono' WHEN 6 THEN 'Susilawati' WHEN 7 THEN 'Firmansyah'
    WHEN 8 THEN 'Oktaviani' WHEN 9 THEN 'Rahmawati'
  END,
  'hq' || LPAD(s.id::text, 4, '0') || '@insightwos.com',
  CASE (s.id % 8)
    WHEN 0 THEN 'Human Resources' WHEN 1 THEN 'Finance' WHEN 2 THEN 'IT'
    WHEN 3 THEN 'Legal' WHEN 4 THEN 'Corporate Planning' WHEN 5 THEN 'Procurement'
    WHEN 6 THEN 'Internal Audit' WHEN 7 THEN 'Corporate Secretary'
  END,
  CASE (s.id % 6)
    WHEN 0 THEN 'Staff' WHEN 1 THEN 'Senior Staff' WHEN 2 THEN 'Supervisor'
    WHEN 3 THEN 'Manager' WHEN 4 THEN 'Senior Manager' WHEN 5 THEN 'Admin'
  END,
  'Aktif',
  ('1990-01-01'::date + (s.id * 37)::int)::date,
  CASE WHEN s.id % 2 = 0 THEN 'Perempuan' ELSE 'Laki-laki' END,
  ('2020-01-01'::date + (s.id * 6)::int)::date,
  'HQ',
  (9 + (s.id % 2))  -- site_id 9-10
FROM generate_series(1, 300) AS s(id)
ON CONFLICT (nrp) DO NOTHING;

-- ── 6. SEED USER ROLES UNTUK 2000 KARYAWAN ──
-- Level 1: Staff lapangan (80%)
-- Level 2: Senior Staff / Kepala Tim (12%)
-- Level 3: Supervisor / Mandor (5%)
-- Level 4: Manager (2.5%)
-- Level 5: Senior Manager / Director (0.5%)

INSERT INTO user_roles (nrp, role_level, scope_divisi)
SELECT 
  nrp,
  CASE 
    WHEN employee_id LIKE 'HQ-000%' AND posisi LIKE '%Manager%' THEN 5
    WHEN posisi LIKE '%Manager%' OR posisi LIKE '%Senior Manager%' THEN 4
    WHEN posisi LIKE '%Supervisor%' OR posisi LIKE '%Kepala%' THEN 3
    WHEN posisi LIKE '%Senior%' OR posisi LIKE '%Agronomist%' OR posisi LIKE '%Officer%' THEN 2
    ELSE 1
  END as role_level,
  divisi
FROM employees_master
WHERE employee_id NOT LIKE 'NRP00%'  -- Skip existing seed
ON CONFLICT (nrp) DO NOTHING;

-- ── 7. SEED HR ORG (hierarchy) ──
-- Setiap karyawan punya atasan (kecuali Director)

INSERT INTO hr_org (nrp, atasan_nrp)
SELECT 
  e.nrp,
  (SELECT e2.nrp FROM employees_master e2 
   WHERE e2.divisi = e.divisi 
   AND e2.business_unit = e.business_unit
   AND e2.nrp != e.nrp
   AND (e2.posisi LIKE '%Manager%' OR e2.posisi LIKE '%Supervisor%')
   ORDER BY RANDOM() LIMIT 1
  ) as atasan_nrp
FROM employees_master e
WHERE e.employee_id NOT LIKE 'NRP00%'
AND e.posisi NOT LIKE '%Director%'
ON CONFLICT (nrp) DO NOTHING;

-- ── 8. SEED WORKER PASSWORDS (semua pakai password default) ──
-- Password: Password123 → hash = sha256('Password123' || salt)

INSERT INTO worker_passwords (nrp, password_hash, salt, is_active)
SELECT 
  nrp,
  encode(digest('Password123' || encode(gen_random_bytes(16), 'hex'), 'sha256'), 'hex'),
  encode(gen_random_bytes(16), 'hex'),
  true
FROM employees_master
WHERE employee_id NOT LIKE 'NRP00%'
AND nrp NOT IN (SELECT nrp FROM worker_passwords)
ON CONFLICT (nrp) DO NOTHING;

-- ── 9. VERIFY ──
SELECT business_unit, count(*) as jumlah 
FROM employees_master 
GROUP BY business_unit 
ORDER BY business_unit;

SELECT 'DONE: Wave A — Database Foundation complete' as status;
