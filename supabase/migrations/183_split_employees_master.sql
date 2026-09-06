-- ================================================================
-- 183_split_employees_master.sql
-- I5: Split employees_master (61 columns) into:
--   employees_core (20 cols) — auth, identity, role
--   employees_extended (41 cols) — PII, family, education, certs
-- Then create VIEW employees_master as JOIN for backward compat.
-- ================================================================

-- ════════════════════════════════════════════════════════════════
-- Step 1: Create employees_core (20 essential columns)
-- ════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS employees_core (
  nrp             TEXT PRIMARY KEY,
  employee_id     TEXT,
  nik             TEXT,
  nama            TEXT NOT NULL,
  email           TEXT,
  divisi          TEXT,
  posisi          TEXT,
  status_kerja    TEXT,
  business_unit   TEXT,
  business_unit_id TEXT,
  site_id         TEXT,
  role_level      INTEGER DEFAULT 0,
  auth_id         UUID,
  is_active       BOOLEAN DEFAULT true,
  jabatan         TEXT,
  divisi_code     TEXT,
  position_code   TEXT,
  level_jabatan   TEXT,
  tanggal_masuk   DATE,
  contract_end_date DATE,
  resign_date     DATE,
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

-- ════════════════════════════════════════════════════════════════
-- Step 2: Create employees_extended (41 PII/family/education cols)
-- ════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS employees_extended (
  nrp             TEXT PRIMARY KEY REFERENCES employees_core(nrp),
  tanggal_lahir   DATE,
  jenis_kelamin   TEXT,
  alamat          TEXT,
  no_hp           TEXT,
  nik_encrypted   BYTEA,
  npwp_encrypted  BYTEA,
  alamat_encrypted BYTEA,
  no_hp_encrypted BYTEA,
  kk              TEXT,
  npwp            TEXT,
  tempat_lahir    TEXT,
  golongan_darah  TEXT,
  alamat_domisili TEXT,
  darurat_nama    TEXT,
  darurat_hubungan TEXT,
  darurat_no_hp   TEXT,
  status_pernikahan TEXT,
  jumlah_tanggungan INTEGER,
  status_ptkp     TEXT,
  nama_pasangan   TEXT,
  nik_pasangan    TEXT,
  nama_anak1      TEXT,
  tgl_lahir_anak1 DATE,
  nik_anak1       TEXT,
  nama_anak2      TEXT,
  tgl_lahir_anak2 DATE,
  nik_anak2       TEXT,
  nama_anak3      TEXT,
  tgl_lahir_anak3 DATE,
  nik_anak3       TEXT,
  jurusan         TEXT,
  institusi       TEXT,
  tahun_lulus     INTEGER,
  sertifikasi_pekerja TEXT,
  masa_berlaku_sertifikasi DATE,
  ukuran_baju     TEXT,
  ukuran_celana   INTEGER,
  ukuran_sepatu   INTEGER
);

-- ════════════════════════════════════════════════════════════════
-- Step 3: Migrate data from employees_master → core + extended
-- ════════════════════════════════════════════════════════════════

INSERT INTO employees_core (
  nrp, employee_id, nik, nama, email, divisi, posisi, status_kerja,
  business_unit, business_unit_id, site_id, role_level, auth_id,
  is_active, jabatan, divisi_code, position_code, level_jabatan,
  tanggal_masuk, contract_end_date, resign_date, created_at, updated_at
)
SELECT
  nrp, employee_id, nik, nama, email, divisi, posisi, status_kerja,
  business_unit, business_unit_id, site_id, role_level, auth_id,
  is_active, jabatan, divisi_code, position_code, level_jabatan,
  tanggal_masuk, contract_end_date, resign_date, created_at, updated_at
FROM employees_master
ON CONFLICT (nrp) DO UPDATE SET
  employee_id = EXCLUDED.employee_id,
  nik = EXCLUDED.nik,
  nama = EXCLUDED.nama,
  email = EXCLUDED.email,
  divisi = EXCLUDED.divisi,
  posisi = EXCLUDED.posisi,
  status_kerja = EXCLUDED.status_kerja,
  business_unit = EXCLUDED.business_unit,
  business_unit_id = EXCLUDED.business_unit_id,
  site_id = EXCLUDED.site_id,
  role_level = EXCLUDED.role_level,
  auth_id = EXCLUDED.auth_id,
  is_active = EXCLUDED.is_active,
  jabatan = EXCLUDED.jabatan,
  updated_at = EXCLUDED.updated_at;

INSERT INTO employees_extended (
  nrp, tanggal_lahir, jenis_kelamin, alamat, no_hp,
  nik_encrypted, npwp_encrypted, alamat_encrypted, no_hp_encrypted,
  kk, npwp, tempat_lahir, golongan_darah, alamat_domisili,
  darurat_nama, darurat_hubungan, darurat_no_hp,
  status_pernikahan, jumlah_tanggungan, status_ptkp,
  nama_pasangan, nik_pasangan,
  nama_anak1, tgl_lahir_anak1, nik_anak1,
  nama_anak2, tgl_lahir_anak2, nik_anak2,
  nama_anak3, tgl_lahir_anak3, nik_anak3,
  jurusan, institusi, tahun_lulus,
  sertifikasi_pekerja, masa_berlaku_sertifikasi,
  ukuran_baju, ukuran_celana, ukuran_sepatu
)
SELECT
  nrp, tanggal_lahir, jenis_kelamin, alamat, no_hp,
  nik_encrypted, npwp_encrypted, alamat_encrypted, no_hp_encrypted,
  kk, npwp, tempat_lahir, golongan_darah, alamat_domisili,
  darurat_nama, darurat_hubungan, darurat_no_hp,
  status_pernikahan, jumlah_tanggungan, status_ptkp,
  nama_pasangan, nik_pasangan,
  nama_anak1, tgl_lahir_anak1, nik_anak1,
  nama_anak2, tgl_lahir_anak2, nik_anak2,
  nama_anak3, tgl_lahir_anak3, nik_anak3,
  jurusan, institusi, tahun_lulus,
  sertifikasi_pekerja, masa_berlaku_sertifikasi,
  ukuran_baju, ukuran_celana, ukuran_sepatu
FROM employees_master
ON CONFLICT (nrp) DO UPDATE SET
  tanggal_lahir = EXCLUDED.tanggal_lahir,
  jenis_kelamin = EXCLUDED.jenis_kelamin,
  alamat = EXCLUDED.alamat,
  no_hp = EXCLUDED.no_hp;

-- ════════════════════════════════════════════════════════════════
-- Step 4: Drop old table, create VIEW for backward compat
-- ════════════════════════════════════════════════════════════════

DROP VIEW IF EXISTS employees_master CASCADE;
DROP TABLE IF EXISTS employees_master CASCADE;

CREATE VIEW employees_master AS
SELECT
  c.nrp, c.employee_id, c.nik, c.nama, c.email, c.divisi, c.posisi,
  c.status_kerja, c.business_unit, c.business_unit_id, c.site_id,
  c.role_level, c.auth_id, c.is_active, c.jabatan, c.divisi_code,
  c.position_code, c.level_jabatan, c.tanggal_masuk, c.contract_end_date,
  c.resign_date, c.created_at, c.updated_at,
  e.tanggal_lahir, e.jenis_kelamin, e.alamat, e.no_hp,
  e.nik_encrypted, e.npwp_encrypted, e.alamat_encrypted, e.no_hp_encrypted,
  e.kk, e.npwp, e.tempat_lahir, e.golongan_darah, e.alamat_domisili,
  e.darurat_nama, e.darurat_hubungan, e.darurat_no_hp,
  e.status_pernikahan, e.jumlah_tanggungan, e.status_ptkp,
  e.nama_pasangan, e.nik_pasangan,
  e.nama_anak1, e.tgl_lahir_anak1, e.nik_anak1,
  e.nama_anak2, e.tgl_lahir_anak2, e.nik_anak2,
  e.nama_anak3, e.tgl_lahir_anak3, e.nik_anak3,
  e.jurusan, e.institusi, e.tahun_lulus,
  e.sertifikasi_pekerja, e.masa_berlaku_sertifikasi,
  e.ukuran_baju, e.ukuran_celana, e.ukuran_sepatu
FROM employees_core c
LEFT JOIN employees_extended e ON c.nrp = e.nrp;

-- ════════════════════════════════════════════════════════════════
-- Step 5: RLS — core is accessible, extended is PII-protected
-- ════════════════════════════════════════════════════════════════

ALTER TABLE employees_core ENABLE ROW LEVEL SECURITY;
ALTER TABLE employees_extended ENABLE ROW LEVEL SECURITY;

-- Core: authenticated can read (needed for most functions)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='core_select_auth' AND tablename='employees_core') THEN
    CREATE POLICY "core_select_auth" ON employees_core
      FOR SELECT TO authenticated USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='core_all_service' AND tablename='employees_core') THEN
    CREATE POLICY "core_all_service" ON employees_core
      FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='extended_all_service' AND tablename='employees_extended') THEN
    CREATE POLICY "extended_all_service" ON employees_extended
      FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
END $$;

-- ════════════════════════════════════════════════════════════════
-- Step 6: GRANT
-- ════════════════════════════════════════════════════════════════

GRANT SELECT ON employees_core TO authenticated;
GRANT ALL ON employees_core TO service_role;
GRANT ALL ON employees_extended TO service_role;

-- ════════════════════════════════════════════════════════════════
-- Verify
-- ════════════════════════════════════════════════════════════════

SELECT 'employees_core rows' AS test, count(*)::text AS result FROM employees_core;
SELECT 'employees_extended rows' AS test, count(*)::text AS result FROM employees_extended;
SELECT 'employees_master view rows' AS test, count(*)::text AS result FROM employees_master;
SELECT 'core columns' AS test, count(*)::text AS result FROM information_schema.columns WHERE table_name = 'employees_core';
SELECT 'extended columns' AS test, count(*)::text AS result FROM information_schema.columns WHERE table_name = 'employees_extended';
SELECT 'view columns' AS test, count(*)::text AS result FROM information_schema.columns WHERE table_name = 'employees_master';
