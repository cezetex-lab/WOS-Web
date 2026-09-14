-- ================================================================
-- rollback/183_rollback.sql — Rollback migration 183
-- Recreate employees_master as TABLE (was VIEW), drop core+extended.
-- WARNING: Destructive — ensure backup exists before running.
-- ================================================================

-- 1. Drop triggers on employees_master VIEW
DROP TRIGGER IF EXISTS employees_master_insert_trigger ON employees_master;
DROP TRIGGER IF EXISTS employees_master_update_trigger ON employees_master;
DROP TRIGGER IF EXISTS employees_master_delete_trigger ON employees_master;
DROP FUNCTION IF EXISTS employees_master_insert_trigger() CASCADE;
DROP FUNCTION IF EXISTS employees_master_update_trigger() CASCADE;
DROP FUNCTION IF EXISTS employees_master_delete_trigger() CASCADE;

-- 2. Drop the VIEW
DROP VIEW IF EXISTS employees_master CASCADE;

-- 3. Recreate employees_master as TABLE with all columns from core+extended
CREATE TABLE employees_master (
  -- Core columns
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
  updated_at      TIMESTAMPTZ DEFAULT now(),
  -- Extended columns
  tanggal_lahir   DATE,
  jenis_kelamin   TEXT,
  alamat          TEXT,
  no_hp           TEXT,
  nik_encrypted   BYTEA,
  npwp_encrypted  BYTEA,
  no_rekening     TEXT,
  nama_bank       TEXT,
  nama_rekening   TEXT,
  bpjs_kesehatan  TEXT,
  bpjs_ketenagakerjaan TEXT,
  status_perkawinan TEXT,
  jumlah_anak     INTEGER,
  nama_ayah       TEXT,
  nama_ibu        TEXT,
  pendidikan      TEXT,
  jurusan         TEXT,
  institusi       TEXT,
  tahun_lulus     INTEGER,
  sertifikasi     TEXT,
  pengalaman_kerja TEXT,
  keahlian        TEXT,
  bahasa          TEXT,
  foto_profil     TEXT,
  no_darurat      TEXT,
  nama_darurat    TEXT,
  hubungan_darurat TEXT,
  kompetensi      TEXT,
  pelatihan       TEXT,
  penilaian       TEXT,
  absensi         TEXT,
  gaji            NUMERIC,
  tunjangan       TEXT,
  potongan        TEXT,
  jaminan         TEXT,
  kontrak_kerja   TEXT,
  dokumen_lain    TEXT,
  catatan         TEXT,
  status_internal TEXT,
  last_updated_by TEXT
);

-- 4. Copy data from core + extended
INSERT INTO employees_master
SELECT
  c.nrp, c.employee_id, c.nik, c.nama, c.email, c.divisi, c.posisi,
  c.status_kerja, c.business_unit, c.business_unit_id, c.site_id,
  c.role_level, c.auth_id, c.is_active, c.jabatan, c.divisi_code,
  c.position_code, c.level_jabatan, c.tanggal_masuk, c.contract_end_date,
  c.resign_date, c.created_at, c.updated_at,
  e.tanggal_lahir, e.jenis_kelamin, e.alamat, e.no_hp,
  e.nik_encrypted, e.npwp_encrypted,
  e.no_rekening, e.nama_bank, e.nama_rekening,
  e.bpjs_kesehatan, e.bpjs_ketenagakerjaan,
  e.status_perkawinan, e.jumlah_anak,
  e.nama_ayah, e.nama_ibu,
  e.pendidikan, e.jurusan, e.institusi, e.tahun_lulus,
  e.sertifikasi, e.pengalaman_kerja, e.keahlian, e.bahasa,
  e.foto_profil, e.no_darurat, e.nama_darurat, e.hubungan_darurat,
  e.kompetensi, e.pelatihan, e.penilaian, e.absensi,
  e.gaji, e.tunjangan, e.potongan, e.jaminan,
  e.kontrak_kerja, e.dokumen_lain, e.catatan,
  e.status_internal, e.last_updated_by
FROM employees_core c
LEFT JOIN employees_extended e ON c.nrp = e.nrp;

-- 5. Drop extended and core tables
DROP TABLE IF EXISTS employees_extended CASCADE;
DROP TABLE IF EXISTS employees_core CASCADE;

-- 6. Verify
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname='employees_master' AND relkind='r') THEN
    RAISE WARNING 'employees_master is not a TABLE after rollback';
  END IF;
  RAISE NOTICE '183_rollback: employees_master restored as TABLE';
END $$;
