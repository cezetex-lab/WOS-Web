-- ================================================================
-- 215_gap_employee_fields.sql — §7 Migration Gap Inventory (karyawan)
--
-- Keputusan 2026-09-13: 16 field GAS yang belum ada di DB
--   → employees_core       : lokasi_penempatan, updated_by (lastUpdatedBy),
--                            status_kerja_internal (statusKerjaInternal)
--   → employees_extended   : agama, media_sosial (JSONB), jenjang_pendidikan,
--                            no_bpjs_kesehatan, no_bpjs_ketenagakerjaan,
--                            riwayat_penyakit, komorbid, alergi,
--                            nama_bank, no_rekening, nama_rekening
--   → hr_document_types    : seed 12 kategori upload (menggantikan 10 kolom
--                            upload GAS; fileLinksJSON diwakili employee_documents)
--   → employees_master VIEW + INSTEAD OF trigger disinkronkan
--   → admin_get_payroll LEFT JOIN data karyawan (nama/divisi/jenis/bank)
--
-- Rollback: supabase/migrations/rollback/215_rollback.sql
-- ================================================================

-- ════════════════════════════════════════════════════════════════════
-- 1. employees_core — data org/status/audit
-- ════════════════════════════════════════════════════════════════════
ALTER TABLE employees_core ADD COLUMN IF NOT EXISTS lokasi_penempatan TEXT;
ALTER TABLE employees_core ADD COLUMN IF NOT EXISTS updated_by TEXT;
ALTER TABLE employees_core ADD COLUMN IF NOT EXISTS status_kerja_internal TEXT;

-- ════════════════════════════════════════════════════════════════════
-- 2. employees_extended — data pribadi statis (PII)
-- ════════════════════════════════════════════════════════════════════
ALTER TABLE employees_extended ADD COLUMN IF NOT EXISTS agama TEXT;
ALTER TABLE employees_extended ADD COLUMN IF NOT EXISTS media_sosial JSONB;
ALTER TABLE employees_extended ADD COLUMN IF NOT EXISTS jenjang_pendidikan TEXT;
ALTER TABLE employees_extended ADD COLUMN IF NOT EXISTS no_bpjs_kesehatan TEXT;
ALTER TABLE employees_extended ADD COLUMN IF NOT EXISTS no_bpjs_ketenagakerjaan TEXT;
ALTER TABLE employees_extended ADD COLUMN IF NOT EXISTS riwayat_penyakit TEXT;
ALTER TABLE employees_extended ADD COLUMN IF NOT EXISTS komorbid TEXT;
ALTER TABLE employees_extended ADD COLUMN IF NOT EXISTS alergi TEXT;
ALTER TABLE employees_extended ADD COLUMN IF NOT EXISTS nama_bank TEXT;
ALTER TABLE employees_extended ADD COLUMN IF NOT EXISTS no_rekening TEXT;
ALTER TABLE employees_extended ADD COLUMN IF NOT EXISTS nama_rekening TEXT;

-- ════════════════════════════════════════════════════════════════════
-- 3. hr_document_types — seed 12 kategori upload GAS
--    (idempoten; fileLinksJSON diwakili employee_documents)
-- ════════════════════════════════════════════════════════════════════
INSERT INTO hr_document_types (type, sub_type)
SELECT v.type, v.sub_type
FROM (VALUES
  ('FOTO', 'Identity'),
  ('KK', 'Family'),
  ('KTP', 'Identity'),
  ('BPJS_KESEHATAN', 'Insurance'),
  ('BPJS_KETENAGAKERJAAN', 'Insurance'),
  ('IJAZAH', 'Diploma'),
  ('SERTIFIKASI', 'Certificate'),
  ('TABUNGAN', 'Finance'),
  ('NPWP', 'Tax'),
  ('SIM', 'License'),
  ('KET_ANAK_KULIAH', 'Family'),
  ('LAINNYA', 'Other')
) AS v(type, sub_type)
WHERE NOT EXISTS (
  SELECT 1 FROM hr_document_types t WHERE t.type = v.type
);


-- ════════════════════════════════════════════════════════════════════
-- 4. employees_master VIEW — sinkronkan dengan kolom baru
-- ════════════════════════════════════════════════════════════════════
-- PostgreSQL: CREATE OR REPLACE VIEW menolak perubahan nama/urutan kolom
-- (42P16), dan kolom baru disisipkan di tengah daftar select.
-- DROP + CREATE aman: tidak ada view turunan dan tidak ada policy pada view;
-- ketiga INSTEAD OF trigger di-drop CASCADE lalu dibuat ulang di bawah.
DROP VIEW IF EXISTS employees_master CASCADE;
CREATE VIEW employees_master AS
SELECT
  c.nrp, c.employee_id, c.nik, c.nama, c.email, c.divisi, c.posisi,
  c.status_kerja, c.status_kerja_internal, c.business_unit, c.business_unit_id,
  c.site_id, c.role_level, c.auth_id, c.is_active, c.jabatan, c.divisi_code,
  c.position_code, c.level_jabatan, c.tanggal_masuk, c.contract_end_date,
  c.resign_date, c.lokasi_penempatan, c.updated_by, c.created_at, c.updated_at,
  e.tanggal_lahir, e.jenis_kelamin, e.alamat, e.no_hp,
  e.nik_encrypted, e.npwp_encrypted, e.alamat_encrypted, e.no_hp_encrypted,
  e.kk, e.npwp, e.tempat_lahir, e.golongan_darah, e.alamat_domisili,
  e.darurat_nama, e.darurat_hubungan, e.darurat_no_hp,
  e.status_pernikahan, e.jumlah_tanggungan, e.status_ptkp,
  e.nama_pasangan, e.nik_pasangan,
  e.nama_anak1, e.tgl_lahir_anak1, e.nik_anak1,
  e.nama_anak2, e.tgl_lahir_anak2, e.nik_anak2,
  e.nama_anak3, e.tgl_lahir_anak3, e.nik_anak3,
  e.jurusan, e.institusi, e.tahun_lulus, e.jenjang_pendidikan,
  e.sertifikasi_pekerja, e.masa_berlaku_sertifikasi,
  e.ukuran_baju, e.ukuran_celana, e.ukuran_sepatu,
  e.agama, e.media_sosial, e.no_bpjs_kesehatan, e.no_bpjs_ketenagakerjaan,
  e.riwayat_penyakit, e.komorbid, e.alergi,
  e.nama_bank, e.no_rekening, e.nama_rekening
FROM employees_core c
LEFT JOIN employees_extended e ON c.nrp = e.nrp;


-- ════════════════════════════════════════════════════════════════════
-- 5. INSTEAD OF INSERT — persist kolom baru ke base tables
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
    status_kerja_internal, business_unit, business_unit_id, site_id,
    role_level, auth_id, is_active, jabatan, divisi_code, position_code,
    level_jabatan, tanggal_masuk, contract_end_date, resign_date,
    lokasi_penempatan, updated_by
  ) VALUES (
    NEW.nrp, NEW.employee_id, NEW.nik, NEW.nama, NEW.email, NEW.divisi,
    NEW.posisi, NEW.status_kerja, NEW.status_kerja_internal,
    NEW.business_unit, NEW.business_unit_id, NEW.site_id, NEW.role_level,
    NEW.auth_id, NEW.is_active, NEW.jabatan, NEW.divisi_code,
    NEW.position_code, NEW.level_jabatan, NEW.tanggal_masuk,
    NEW.contract_end_date, NEW.resign_date, NEW.lokasi_penempatan,
    NEW.updated_by
  )
  ON CONFLICT (nrp) DO UPDATE SET
    employee_id = EXCLUDED.employee_id, nik = EXCLUDED.nik,
    nama = EXCLUDED.nama,
    email = EXCLUDED.email, divisi = EXCLUDED.divisi,
    posisi = EXCLUDED.posisi, status_kerja = EXCLUDED.status_kerja,
    status_kerja_internal = EXCLUDED.status_kerja_internal,
    business_unit = EXCLUDED.business_unit,
    business_unit_id = EXCLUDED.business_unit_id, site_id = EXCLUDED.site_id,
    role_level = EXCLUDED.role_level, auth_id = EXCLUDED.auth_id,
    is_active = EXCLUDED.is_active, jabatan = EXCLUDED.jabatan,
    divisi_code = EXCLUDED.divisi_code, position_code = EXCLUDED.position_code,
    level_jabatan = EXCLUDED.level_jabatan,
    tanggal_masuk = EXCLUDED.tanggal_masuk,
    contract_end_date = EXCLUDED.contract_end_date,
    resign_date = EXCLUDED.resign_date,
    lokasi_penempatan = EXCLUDED.lokasi_penempatan,
    updated_by = EXCLUDED.updated_by,
    updated_at = NOW();

  IF NEW.tanggal_lahir IS NOT NULL OR NEW.jenis_kelamin IS NOT NULL
     OR NEW.alamat IS NOT NULL OR NEW.no_hp IS NOT NULL
     OR NEW.agama IS NOT NULL OR NEW.media_sosial IS NOT NULL
     OR NEW.jenjang_pendidikan IS NOT NULL
     OR NEW.no_bpjs_kesehatan IS NOT NULL
     OR NEW.no_bpjs_ketenagakerjaan IS NOT NULL
     OR NEW.riwayat_penyakit IS NOT NULL OR NEW.komorbid IS NOT NULL
     OR NEW.alergi IS NOT NULL OR NEW.nama_bank IS NOT NULL
     OR NEW.no_rekening IS NOT NULL OR NEW.nama_rekening IS NOT NULL THEN
    INSERT INTO employees_extended (
      nrp, tanggal_lahir, jenis_kelamin, alamat, no_hp,
      kk, npwp, tempat_lahir, golongan_darah, alamat_domisili,
      darurat_nama, darurat_hubungan, darurat_no_hp,
      status_pernikahan, jumlah_tanggungan, status_ptkp,
      nama_pasangan, nik_pasangan,
      jurusan, institusi, tahun_lulus, jenjang_pendidikan,
      sertifikasi_pekerja, masa_berlaku_sertifikasi,
      ukuran_baju, ukuran_celana, ukuran_sepatu,
      agama, media_sosial, no_bpjs_kesehatan, no_bpjs_ketenagakerjaan,
      riwayat_penyakit, komorbid, alergi,
      nama_bank, no_rekening, nama_rekening
    ) VALUES (
      NEW.nrp, NEW.tanggal_lahir, NEW.jenis_kelamin, NEW.alamat, NEW.no_hp,
      NEW.kk, NEW.npwp, NEW.tempat_lahir, NEW.golongan_darah,
      NEW.alamat_domisili, NEW.darurat_nama, NEW.darurat_hubungan,
      NEW.darurat_no_hp, NEW.status_pernikahan, NEW.jumlah_tanggungan,
      NEW.status_ptkp, NEW.nama_pasangan, NEW.nik_pasangan,
      NEW.jurusan, NEW.institusi, NEW.tahun_lulus, NEW.jenjang_pendidikan,
      NEW.sertifikasi_pekerja, NEW.masa_berlaku_sertifikasi,
      NEW.ukuran_baju, NEW.ukuran_celana, NEW.ukuran_sepatu,
      NEW.agama, NEW.media_sosial, NEW.no_bpjs_kesehatan,
      NEW.no_bpjs_ketenagakerjaan, NEW.riwayat_penyakit, NEW.komorbid,
      NEW.alergi, NEW.nama_bank, NEW.no_rekening, NEW.nama_rekening
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
      jenjang_pendidikan = EXCLUDED.jenjang_pendidikan,
      sertifikasi_pekerja = EXCLUDED.sertifikasi_pekerja,
      masa_berlaku_sertifikasi = EXCLUDED.masa_berlaku_sertifikasi,
      ukuran_baju = EXCLUDED.ukuran_baju,
      ukuran_celana = EXCLUDED.ukuran_celana,
      ukuran_sepatu = EXCLUDED.ukuran_sepatu,
      agama = EXCLUDED.agama, media_sosial = EXCLUDED.media_sosial,
      no_bpjs_kesehatan = EXCLUDED.no_bpjs_kesehatan,
      no_bpjs_ketenagakerjaan = EXCLUDED.no_bpjs_ketenagakerjaan,
      riwayat_penyakit = EXCLUDED.riwayat_penyakit,
      komorbid = EXCLUDED.komorbid, alergi = EXCLUDED.alergi,
      nama_bank = EXCLUDED.nama_bank, no_rekening = EXCLUDED.no_rekening,
      nama_rekening = EXCLUDED.nama_rekening;
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
-- 6. INSTEAD OF UPDATE — persist kolom baru ke base tables
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
    status_kerja = NEW.status_kerja,
    status_kerja_internal = NEW.status_kerja_internal,
    business_unit = NEW.business_unit, business_unit_id = NEW.business_unit_id,
    site_id = NEW.site_id, role_level = NEW.role_level, auth_id = NEW.auth_id,
    is_active = NEW.is_active, jabatan = NEW.jabatan,
    divisi_code = NEW.divisi_code, position_code = NEW.position_code,
    level_jabatan = NEW.level_jabatan, tanggal_masuk = NEW.tanggal_masuk,
    contract_end_date = NEW.contract_end_date, resign_date = NEW.resign_date,
    lokasi_penempatan = NEW.lokasi_penempatan, updated_by = NEW.updated_by,
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
    tahun_lulus = NEW.tahun_lulus, jenjang_pendidikan = NEW.jenjang_pendidikan,
    sertifikasi_pekerja = NEW.sertifikasi_pekerja,
    masa_berlaku_sertifikasi = NEW.masa_berlaku_sertifikasi,
    ukuran_baju = NEW.ukuran_baju, ukuran_celana = NEW.ukuran_celana,
    ukuran_sepatu = NEW.ukuran_sepatu, agama = NEW.agama,
    media_sosial = NEW.media_sosial,
    no_bpjs_kesehatan = NEW.no_bpjs_kesehatan,
    no_bpjs_ketenagakerjaan = NEW.no_bpjs_ketenagakerjaan,
    riwayat_penyakit = NEW.riwayat_penyakit, komorbid = NEW.komorbid,
    alergi = NEW.alergi, nama_bank = NEW.nama_bank,
    no_rekening = NEW.no_rekening, nama_rekening = NEW.nama_rekening
  WHERE nrp = NEW.nrp;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_employees_master_update ON employees_master;
CREATE TRIGGER trg_employees_master_update
  INSTEAD OF UPDATE ON employees_master
  FOR EACH ROW
  EXECUTE FUNCTION employees_master_update_trigger();

-- INSTEAD OF DELETE hilang ter-drop CASCADE bersama VIEW (211 tidak diubah
-- strukturnya, tapi definisinya perlu dibuat ulang agar legacy delete via
-- view tetap berfungsi).
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


-- ════════════════════════════════════════════════════════════════════
-- 7. admin_get_payroll — join data karyawan (nama/divisi/jenis/bank)
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
         'nrp', t.nrp, 'periode', t.periode,
         'nama', c.nama, 'divisi', c.divisi,
         'status_kerja', c.status_kerja, 'jenis', c.status_kerja,
         'base_salary', t.base_salary, 'allowance', t.allowance,
         'deduction', t.deduction, 'overtime_pay', t.overtime_pay,
         'net_salary', t.net_salary, 'gross_salary', t.gross_salary,
         'pph21_ter', t.pph21_ter, 'thr_amount', t.thr_amount,
         'nama_bank', e.nama_bank, 'no_rekening', e.no_rekening,
         'nama_rekening', e.nama_rekening,
         'lokasi_penempatan', c.lokasi_penempatan,
         'created_at', t.created_at
       ) ORDER BY t.periode DESC, t.nrp))
    FROM hr_payroll t
    LEFT JOIN employees_core c ON c.nrp = t.nrp
    LEFT JOIN employees_extended e ON e.nrp = t.nrp
    WHERE p_period IS NULL OR t.periode = p_period),
    jsonb_build_object('ok', true, 'data', '[]'::jsonb)
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.admin_get_payroll(text) TO anon, authenticated;


-- ════════════════════════════════════════════════════════════════════
-- 8. Verify
-- ════════════════════════════════════════════════════════════════════
SELECT '215.1 employees_core columns' AS test,
  CASE WHEN (
    SELECT count(*) FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'employees_core'
      AND column_name IN ('lokasi_penempatan', 'updated_by', 'status_kerja_internal')
  ) = 3 THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT '215.2 employees_extended columns' AS test,
  CASE WHEN (
    SELECT count(*) FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'employees_extended'
      AND column_name IN (
        'agama', 'media_sosial', 'jenjang_pendidikan',
        'no_bpjs_kesehatan', 'no_bpjs_ketenagakerjaan',
        'riwayat_penyakit', 'komorbid', 'alergi',
        'nama_bank', 'no_rekening', 'nama_rekening'
      )
  ) = 11 THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT '215.3 hr_document_types seeded' AS test,
  CASE WHEN (SELECT count(*) FROM hr_document_types) >= 12 THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT '215.4 employees_master view columns' AS test,
  CASE WHEN (
    SELECT count(*) FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'employees_master'
      AND column_name IN ('agama', 'nama_bank', 'lokasi_penempatan', 'status_kerja_internal')
  ) = 4 THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT '215.5 admin_get_payroll joins karyawan' AS test,
  CASE WHEN pg_get_functiondef('public.admin_get_payroll(text)'::regprocedure) ILIKE '%LEFT JOIN employees_core%'
    THEN 'PASS' ELSE 'FAIL' END AS result;

NOTIFY pgrst, 'reload schema';