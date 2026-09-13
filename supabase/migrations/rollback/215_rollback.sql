-- ================================================================
-- rollback/215_rollback.sql — Rollback migration 215
-- Drop 14 kolom baru, restore employees_master VIEW + INSTEAD OF
-- triggers ke state pre-215 (migration 183 + 211), restore
-- admin_get_payroll ke state pre-215 (migration 190), hapus seed
-- hr_document_types yang ditambahkan 215.
-- ================================================================

-- ════════════════════════════════════════════════════════════════════
-- 1. Drop kolom baru
-- ════════════════════════════════════════════════════════════════════
ALTER TABLE employees_core DROP COLUMN IF EXISTS lokasi_penempatan;
ALTER TABLE employees_core DROP COLUMN IF EXISTS updated_by;
ALTER TABLE employees_core DROP COLUMN IF EXISTS status_kerja_internal;

ALTER TABLE employees_extended DROP COLUMN IF EXISTS agama;
ALTER TABLE employees_extended DROP COLUMN IF EXISTS media_sosial;
ALTER TABLE employees_extended DROP COLUMN IF EXISTS jenjang_pendidikan;
ALTER TABLE employees_extended DROP COLUMN IF EXISTS no_bpjs_kesehatan;
ALTER TABLE employees_extended DROP COLUMN IF EXISTS no_bpjs_ketenagakerjaan;
ALTER TABLE employees_extended DROP COLUMN IF EXISTS riwayat_penyakit;
ALTER TABLE employees_extended DROP COLUMN IF EXISTS komorbid;
ALTER TABLE employees_extended DROP COLUMN IF EXISTS alergi;
ALTER TABLE employees_extended DROP COLUMN IF EXISTS nama_bank;
ALTER TABLE employees_extended DROP COLUMN IF EXISTS no_rekening;
ALTER TABLE employees_extended DROP COLUMN IF EXISTS nama_rekening;

-- ════════════════════════════════════════════════════════════════════
-- 2. Restore employees_master VIEW (pre-215 / migration 183)
-- ════════════════════════════════════════════════════════════════════
-- Sama seperti 215: CREATE OR REPLACE VIEW menolak perubahan nama/urutan
-- kolom, sehingga restore memakai DROP + CREATE.
DROP VIEW IF EXISTS employees_master CASCADE;
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


-- ════════════════════════════════════════════════════════════════════
-- 3. Restore INSTEAD OF INSERT trigger (pre-215 / migration 211)
-- ════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION employees_master_insert_trigger()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
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
    nama = EXCLUDED.nik,
    email = EXCLUDED.email, divisi = EXCLUDED.divisi,
    posisi = EXCLUDED.posisi, status_kerja = EXCLUDED.status_kerja,
    business_unit = EXCLUDED.business_unit,
    business_unit_id = EXCLUDED.business_unit_id, site_id = EXCLUDED.site_id,
    role_level = EXCLUDED.role_level, auth_id = EXCLUDED.auth_id,
    is_active = EXCLUDED.is_active, jabatan = EXCLUDED.jabatan,
    divisi_code = EXCLUDED.divisi_code, position_code = EXCLUDED.position_code,
    level_jabatan = EXCLUDED.level_jabatan,
    tanggal_masuk = EXCLUDED.tanggal_masuk,
    contract_end_date = EXCLUDED.contract_end_date,
    resign_date = EXCLUDED.resign_date;

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


-- ════════════════════════════════════════════════════════════════════
-- 4. Restore INSTEAD OF UPDATE trigger (pre-215 / migration 211)
-- ════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION employees_master_update_trigger()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
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

  UPDATE employees_extended SET
    tanggal_lahir = NEW.tanggal_lahir, jenis_kelamin = NEW.jenis_kelamin,
    alamat = NEW.alamat, no_hp = NEW.no_hp, kk = NEW.kk, npwp = NEW.npwp,
    tempat_lahir = NEW.tempat_lahir, golongan_darah = NEW.golongan_darah,
    alamat_domisili = NEW.alamat_domisili,
    darurat_nama = NEW.darurat_nama, darurat_hubungan = NEW.darurat_hubungan,
    darurat_no_hp = NEW.darurat_no_hp,
    status_pernikahan = NEW.status_pernikahan,
    jumlah_tanggungan = NEW.jumlah_tanggungan, status_ptkp = NEW.status_ptkp,
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


-- ════════════════════════════════════════════════════════════════════
-- 5. Restore admin_get_payroll (pre-215 / migration 190)
-- ════════════════════════════════════════════════════════════════════
DROP FUNCTION IF EXISTS public.admin_get_payroll(text);

CREATE OR REPLACE FUNCTION public.admin_get_payroll(p_period text DEFAULT NULL::text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_role TEXT;
BEGIN
  IF EXISTS (SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = TRUE) THEN
    v_role := 'admin_pusat';
  ELSE
    SELECT ura.role_code INTO v_role
    FROM user_role_assignments ura
    WHERE ura.nrp = authz_current_nrp()
      AND ura.role_code IN ('admin_pusat', 'admin_hrd', 'admin_finance')
    LIMIT 1;
  END IF;
  IF v_role IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak');
  END IF;
  RETURN COALESCE(
    (SELECT jsonb_build_object('ok', true, 'data', jsonb_agg(
      jsonb_build_object(
        'nrp', t.nrp, 'periode', t.periode, 'base_salary', t.base_salary,
        'allowance', t.allowance, 'deduction', t.deduction,
        'overtime_pay', t.overtime_pay, 'net_salary', t.net_salary,
        'gross_salary', t.gross_salary, 'pph21_ter', t.pph21_ter,
        'thr_amount', t.thr_amount, 'created_at', t.created_at
      ) ORDER BY t.periode DESC, t.nrp))
    FROM hr_payroll t
    WHERE p_period IS NULL OR t.periode = p_period),
    jsonb_build_object('ok', true, 'data', '[]'::jsonb)
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.admin_get_payroll(text) TO anon, authenticated;

-- ════════════════════════════════════════════════════════════════════
-- 6. Hapus seed hr_document_types yang ditambahkan 215
-- ════════════════════════════════════════════════════════════════════
DELETE FROM hr_document_types
WHERE type IN (
  'FOTO', 'KK', 'KTP', 'BPJS_KESEHATAN', 'BPJS_KETENAGAKERJAAN',
  'IJAZAH', 'SERTIFIKASI', 'TABUNGAN', 'NPWP', 'SIM',
  'KET_ANAK_KULIAH', 'LAINNYA'
);

NOTIFY pgrst, 'reload schema';


-- ════════════════════════════════════════════════════════════════════
-- 4b. Restore INSTEAD OF DELETE trigger (pre-215 / migration 211)
-- ════════════════════════════════════════════════════════════════════
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