-- Fase 1: 33 Kolom Baru di employees_master + Indexes

-- 33 Kolom Baru (IDEMPOTENT: ADD COLUMN IF NOT EXISTS)
DO $$ BEGIN
  -- Keluarga & Kontak Darurat
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS kk TEXT;
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS tempat_lahir TEXT;
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS golongan_darah TEXT;
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS alamat_domisili TEXT;
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS darurat_nama TEXT;
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS darurat_hubungan TEXT;
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS darurat_no_hp TEXT;
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS status_pernikahan TEXT;
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS jumlah_tanggungan INT;
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS status_ptkp TEXT;
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS nama_pasangan TEXT;
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS nik_pasangan TEXT;
  -- Anak 1-3
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS nama_anak1 TEXT;
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS tgl_lahir_anak1 DATE;
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS nik_anak1 TEXT;
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS nama_anak2 TEXT;
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS tgl_lahir_anak2 DATE;
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS nik_anak2 TEXT;
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS nama_anak3 TEXT;
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS tgl_lahir_anak3 DATE;
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS nik_anak3 TEXT;
  -- Pendidikan & Sertifikasi
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS jurusan TEXT;
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS institusi TEXT;
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS tahun_lulus INT;
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS sertifikasi_pekerja TEXT;
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS masa_berlaku_sertifikasi DATE;
  -- Ukuran
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS ukuran_baju TEXT;
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS ukuran_celana INT;
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS ukuran_sepatu INT;
  -- Kode & Level
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS divisi_code TEXT;
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS position_code TEXT;
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS level_jabatan TEXT;
  -- NPWP (plaintext untuk enkripsi)
  ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS npwp TEXT;
EXCEPTION WHEN duplicate_column THEN NULL; END $$;

DO $$ BEGIN RAISE NOTICE 'Fase 1: 33 kolom ditambahkan ke employees_master'; END $$;

-- Indexes untuk performa
CREATE INDEX IF NOT EXISTS idx_emp_kk ON employees_master(kk) WHERE kk IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_emp_tempat_lahir ON employees_master(tempat_lahir) WHERE tempat_lahir IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_emp_status_ptkp ON employees_master(status_ptkp) WHERE status_ptkp IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_emp_level_jabatan ON employees_master(level_jabatan) WHERE level_jabatan IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_emp_npwp ON employees_master(npwp) WHERE npwp IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_emp_divisi_code ON employees_master(divisi_code) WHERE divisi_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_emp_status_pernikahan ON employees_master(status_pernikahan) WHERE status_pernikahan IS NOT NULL;

DO $$ BEGIN RAISE NOTICE 'Fase 1: 7 indexes dibuat'; END $$;
