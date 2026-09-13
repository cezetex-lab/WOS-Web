-- ================================================================
-- 211_employees_master_write_trigger.sql — Tahap 5.9 (A5)
--
-- employees_master = VIEW (employees_core LEFT JOIN employees_extended)
-- created in migration 183. Before 183, it was a TABLE — some legacy
-- code still writes to it. INSTEAD OF triggers delegate writes to
-- the base tables (employees_core for core cols, extended for PII).
--
-- Rollback: supabase/migrations/rollback/211_rollback.sql
-- ================================================================

-- 1. INSTEAD OF INSERT on employees_master
CREATE OR REPLACE FUNCTION employees_master_insert_trigger()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  -- Insert core columns into employees_core
  INSERT INTO employees_core (
    nrp, employee_id, nik, nama, email, divisi, posisi, status_kerja,
    business_unit, business_unit_id, site_id, role_level, auth_id,
    is_active, jabatan, divisi_code, position_code, level_jabatan,
    tanggal_masuk, contract_end_date, resign_date
  ) VALUES (
    NEW.nrp, NEW.employee_id, NEW.nik, NEW.nama, NEW.email,
    NEW.divisi, NEW.posisi, NEW.status_kerja, NEW.business_unit,
    NEW.business_unit_id, NEW.site_id, NEW.role_level, NEW.auth_id,
    NEW.is_active, NEW.jabatan, NEW.divisi_code, NEW.position_code,
    NEW.level_jabatan, NEW.tanggal_masuk, NEW.contract_end_date,
    NEW.resign_date
  )
  ON CONFLICT (nrp) DO UPDATE SET
    employee_id = EXCLUDED.employee_id, nik = EXCLUDED.nik,
    nama = EXCLUDED.nama, email = EXCLUDED.email,
    divisi = EXCLUDED.divisi, posisi = EXCLUDED.posisi,
    status_kerja = EXCLUDED.status_kerja,
    business_unit = EXCLUDED.business_unit,
    business_unit_id = EXCLUDED.business_unit_id,
    site_id = EXCLUDED.site_id, role_level = EXCLUDED.role_level,
    auth_id = EXCLUDED.auth_id, is_active = EXCLUDED.is_active,
    jabatan = EXCLUDED.jabatan, divisi_code = EXCLUDED.divisi_code,
    position_code = EXCLUDED.position_code,
    level_jabatan = EXCLUDED.level_jabatan,
    tanggal_masuk = EXCLUDED.tanggal_masuk,
    contract_end_date = EXCLUDED.contract_end_date,
    resign_date = EXCLUDED.resign_date;

  -- Insert extended columns into employees_extended (if any provided)
  IF NEW.tanggal_lahir IS NOT NULL OR NEW.jenis_kelamin IS NOT NULL
     OR NEW.alamat IS NOT NULL OR NEW.no_hp IS NOT NULL THEN
    INSERT INTO employees_extended (
      nrp, tanggal_lahir, jenis_kelamin, alamat, no_hp,
      kk, npwp, tempat_lahir, golongan_darah, alamat_domisili,
      darurat_nama, darurat_hubungan, darurat_no_hp,
      status_pernikahan, jumlah_tanggungan, status_ptkp,
      nama_pasangan, nik_pasangan,
      jurusan, institusi, tahun_lulus,
      sertifikasi_pekerja, masa_berlaku_sertifikasi,
      ukuran_baju, ukuran_celana, ukuran_sepatu
    ) VALUES (
      NEW.nrp, NEW.tanggal_lahir, NEW.jenis_kelamin,
      NEW.alamat, NEW.no_hp, NEW.kk, NEW.npwp,
      NEW.tempat_lahir, NEW.golongan_darah, NEW.alamat_domisili,
      NEW.darurat_nama, NEW.darurat_hubungan, NEW.darurat_no_hp,
      NEW.status_pernikahan, NEW.jumlah_tanggungan, NEW.status_ptkp,
      NEW.nama_pasangan, NEW.nik_pasangan,
      NEW.jurusan, NEW.institusi, NEW.tahun_lulus,
      NEW.sertifikasi_pekerja, NEW.masa_berlaku_sertifikasi,
      NEW.ukuran_baju, NEW.ukuran_celana, NEW.ukuran_sepatu
    )
    ON CONFLICT (nrp) DO UPDATE SET
      tanggal_lahir = EXCLUDED.tanggal_lahir,
      jenis_kelamin = EXCLUDED.jenis_kelamin,
      alamat = EXCLUDED.alamat, no_hp = EXCLUDED.no_hp,
      kk = EXCLUDED.kk, npwp = EXCLUDED.npwp,
      tempat_lahir = EXCLUDED.tempat_lahir,
      golongan_darah = EXCLUDED.golongan_darah,
      alamat_domisili = EXCLUDED.alamat_domisili,
      darurat_nama = EXCLUDED.darurat_nama,
      darurat_hubungan = EXCLUDED.darurat_hubungan,
      darurat_no_hp = EXCLUDED.darurat_no_hp,
      status_pernikahan = EXCLUDED.status_pernikahan,
      jumlah_tanggungan = EXCLUDED.jumlah_tanggungan,
      status_ptkp = EXCLUDED.status_ptkp,
      nama_pasangan = EXCLUDED.nama_pasangan,
      nik_pasangan = EXCLUDED.nik_pasangan,
      jurusan = EXCLUDED.jurusan, institusi = EXCLUDED.institusi,
      tahun_lulus = EXCLUDED.tahun_lulus,
      sertifikasi_pekerja = EXCLUDED.sertifikasi_pekerja,
      masa_berlaku_sertifikasi = EXCLUDED.masa_berlaku_sertifikasi,
      ukuran_baju = EXCLUDED.ukuran_baju,
      ukuran_celana = EXCLUDED.ukuran_celana,
      ukuran_sepatu = EXCLUDED.ukuran_sepatu;
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_employees_master_insert ON employees_master;
CREATE TRIGGER trg_employees_master_insert
  INSTEAD OF INSERT ON employees_master
  FOR EACH ROW
  EXECUTE FUNCTION employees_master_insert_trigger();

-- 2. INSTEAD OF UPDATE on employees_master
CREATE OR REPLACE FUNCTION employees_master_update_trigger()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  -- Update core columns in employees_core
  UPDATE employees_core SET
    employee_id = NEW.employee_id, nik = NEW.nik, nama = NEW.nama,
    email = NEW.email, divisi = NEW.divisi, posisi = NEW.posisi,
    status_kerja = NEW.status_kerja, business_unit = NEW.business_unit,
    business_unit_id = NEW.business_unit_id, site_id = NEW.site_id,
    role_level = NEW.role_level, auth_id = NEW.auth_id,
    is_active = NEW.is_active, jabatan = NEW.jabatan,
    divisi_code = NEW.divisi_code, position_code = NEW.position_code,
    level_jabatan = NEW.level_jabatan, tanggal_masuk = NEW.tanggal_masuk,
    contract_end_date = NEW.contract_end_date, resign_date = NEW.resign_date,
    updated_at = NOW()
  WHERE nrp = NEW.nrp;

  -- Update extended columns in employees_extended
  UPDATE employees_extended SET
    tanggal_lahir = NEW.tanggal_lahir, jenis_kelamin = NEW.jenis_kelamin,
    alamat = NEW.alamat, no_hp = NEW.no_hp, kk = NEW.kk, npwp = NEW.npwp,
    tempat_lahir = NEW.tempat_lahir, golongan_darah = NEW.golongan_darah,
    alamat_domisili = NEW.alamat_domisili,
    darurat_nama = NEW.darurat_nama, darurat_hubungan = NEW.darurat_hubungan,
    darurat_no_hp = NEW.darurat_no_hp,
    status_pernikahan = NEW.status_pernikahan,
    jumlah_tanggungan = NEW.jumlah_tanggungan,
    status_ptkp = NEW.status_ptkp,
    nama_pasangan = NEW.nama_pasangan, nik_pasangan = NEW.nik_pasangan,
    jurusan = NEW.jurusan, institusi = NEW.institusi,
    tahun_lulus = NEW.tahun_lulus,
    sertifikasi_pekerja = NEW.sertifikasi_pekerja,
    masa_berlaku_sertifikasi = NEW.masa_berlaku_sertifikasi,
    ukuran_baju = NEW.ukuran_baju, ukuran_celana = NEW.ukuran_celana,
    ukuran_sepatu = NEW.ukuran_sepatu
  WHERE nrp = NEW.nrp;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_employees_master_update ON employees_master;
CREATE TRIGGER trg_employees_master_update
  INSTEAD OF UPDATE ON employees_master
  FOR EACH ROW
  EXECUTE FUNCTION employees_master_update_trigger();

-- 3. INSTEAD OF DELETE on employees_master
CREATE OR REPLACE FUNCTION employees_master_delete_trigger()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  DELETE FROM employees_extended WHERE nrp = OLD.nrp;
  DELETE FROM employees_core WHERE nrp = OLD.nrp;
  RETURN OLD;
END;
$function$;

DROP TRIGGER IF EXISTS trg_employees_master_delete ON employees_master;
CREATE TRIGGER trg_employees_master_delete
  INSTEAD OF DELETE ON employees_master
  FOR EACH ROW
  EXECUTE FUNCTION employees_master_delete_trigger();

-- 4. Verify
SELECT '211.1 INSERT trigger exists' AS test,
  CASE WHEN EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_employees_master_insert'
  ) THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT '211.2 UPDATE trigger exists' AS test,
  CASE WHEN EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_employees_master_update'
  ) THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT '211.3 DELETE trigger exists' AS test,
  CASE WHEN EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_employees_master_delete'
  ) THEN 'PASS' ELSE 'FAIL' END AS result;

-- Smoke test: INSERT via VIEW should now work (rolled back)
BEGIN;
INSERT INTO employees_master (nrp, nama, nik, email, status_kerja)
VALUES ('NRPTST', 'Test User', '3204000000000000', 'test@example.com', 'Active');
SELECT '211.4 INSERT via VIEW' AS test, count(*)::text AS result FROM employees_core WHERE nrp = 'NRPTST';
ROLLBACK;

SELECT '211.5 smoke rolled back' AS test,
  CASE WHEN NOT EXISTS (SELECT 1 FROM employees_core WHERE nrp = 'NRPTST')
  THEN 'PASS' ELSE 'FAIL' END AS result;
