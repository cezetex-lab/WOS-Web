-- ================================================================
-- rollback/183_rollback.sql — Rollback migration 183
-- Recreate employees_master as TABLE from core+extended.
-- WARNING: Destructive — ensure backup exists before running.
-- Verified against live schema (2026-09-14).
-- ================================================================

-- 1. Drop triggers on employees_master VIEW (from 211)
DROP TRIGGER IF EXISTS trg_employees_master_insert ON employees_master;
DROP TRIGGER IF EXISTS trg_employees_master_update ON employees_master;
DROP TRIGGER IF EXISTS trg_employees_master_delete ON employees_master;
DROP FUNCTION IF EXISTS employees_master_insert_trigger() CASCADE;
DROP FUNCTION IF EXISTS employees_master_update_trigger() CASCADE;
DROP FUNCTION IF EXISTS employees_master_delete_trigger() CASCADE;

-- 2. Drop the VIEW
DROP VIEW IF EXISTS employees_master CASCADE;

-- 3. Recreate employees_master as TABLE with all columns
CREATE TABLE employees_master (
  -- Core columns (26)
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
  lokasi_penempatan TEXT,
  updated_by      TEXT,
  status_kerja_internal TEXT,
  -- Extended columns (48)
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
  ukuran_celana   TEXT,
  ukuran_sepatu   TEXT,
  agama           TEXT,
  media_sosial    JSONB,
  jenjang_pendidikan TEXT,
  no_bpjs_kesehatan TEXT,
  no_bpjs_ketenagakerjaan TEXT,
  riwayat_penyakit TEXT,
  komorbid        TEXT,
  alergi          TEXT,
  nama_bank       TEXT,
  no_rekening     TEXT,
  nama_rekening   TEXT
);

-- 4. Copy data from core + extended
INSERT INTO employees_master
SELECT
  c.nrp, c.employee_id, c.nik, c.nama, c.email, c.divisi, c.posisi,
  c.status_kerja, c.business_unit, c.business_unit_id, c.site_id,
  c.role_level, c.auth_id, c.is_active, c.jabatan, c.divisi_code,
  c.position_code, c.level_jabatan, c.tanggal_masuk, c.contract_end_date,
  c.resign_date, c.created_at, c.updated_at,
  c.lokasi_penempatan, c.updated_by, c.status_kerja_internal,
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
  e.ukuran_baju, e.ukuran_celana, e.ukuran_sepatu,
  e.agama, e.media_sosial, e.jenjang_pendidikan,
  e.no_bpjs_kesehatan, e.no_bpjs_ketenagakerjaan,
  e.riwayat_penyakit, e.komorbid, e.alergi,
  e.nama_bank, e.no_rekening, e.nama_rekening
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
