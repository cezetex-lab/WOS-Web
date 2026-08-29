-- ============================================================
-- 023: Fix payroll dedup + benefit names + admin summary
-- ============================================================

-- Drop conflicting functions first (different param names from earlier migrations)
DO $$ DECLARE fn TEXT; BEGIN
  FOREACH fn IN ARRAY ARRAY[
    'admin_reject_request','admin_approve_request','admin_get_pending_requests',
    'admin_get_summary','get_worker_payroll','get_worker_benefits','get_worker_leave',
    'export_employees','export_payroll','export_org','export_sheet'
  ] LOOP
    BEGIN EXECUTE 'DROP FUNCTION IF EXISTS '||fn||'(TEXT) CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE 'DROP FUNCTION IF EXISTS '||fn||'(TEXT,TEXT) CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE 'DROP FUNCTION IF EXISTS '||fn||'(INT) CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE 'DROP FUNCTION IF EXISTS '||fn||'(INT,TEXT) CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE 'DROP FUNCTION IF EXISTS '||fn||'(TEXT,TEXT,TEXT) CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE 'DROP FUNCTION IF EXISTS '||fn||'() CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
  END LOOP;
END $$;

-- 1. Fix get_worker_payroll — DISTINCT ON to prevent duplicates
CREATE OR REPLACE FUNCTION get_worker_payroll(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('periode',periode,'base_salary',base_salary,'allowance',allowance,
    'deduction',deduction,'overtime_pay',overtime_pay,'net_salary',net_salary) 
  ORDER BY periode DESC),'[]'::jsonb))
FROM (
  SELECT DISTINCT ON (periode) 
    nrp, periode, base_salary, allowance, deduction, overtime_pay, net_salary, created_at
  FROM hr_payroll 
  WHERE nrp=p_nrp 
  ORDER BY periode DESC, created_at DESC
  LIMIT 12
) sub); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Fix get_worker_benefits — JOIN with catalog for proper names
CREATE OR REPLACE FUNCTION get_worker_benefits(p_nrp TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object(
    'jenis_benefit', b.jenis_benefit,
    'nilai', b.nilai,
    'nama_benefit', COALESCE(c.jenis_benefit, b.jenis_benefit, 'Benefit'),
    'kode_benefit', COALESCE(c.kode_benefit, b.jenis_benefit, '-'),
    'kategori', COALESCE(c.kategori, 'Tunjangan'),
    'deskripsi', COALESCE(c.jenis_benefit, b.jenis_benefit) || ' - Fasilitas karyawan'
  ) ORDER BY b.jenis_benefit),'[]'::jsonb))
FROM hr_benefits b 
LEFT JOIN hr_benefit_catalog c ON c.kode_benefit = b.jenis_benefit
WHERE b.nrp=p_nrp); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Fix admin_get_summary — add pensiun, PKWT, total requests
CREATE OR REPLACE FUNCTION admin_get_summary() RETURNS JSONB AS $$
BEGIN RETURN jsonb_build_object('ok',true,
  'total_workers',(SELECT COUNT(*) FROM employees_master),
  'total_divisions',(SELECT COUNT(DISTINCT divisi) FROM employees_master WHERE divisi IS NOT NULL),
  'pending_requests',(SELECT COUNT(*) FROM hr_requests WHERE status='Pending'),
  'pending_registrations',(SELECT COUNT(*) FROM daftar_baru WHERE status='PENDING'),
  'retiring_soon',(SELECT COUNT(*) FROM employees_master WHERE status_kerja='PKWT' 
    AND tanggal_akhir IS NOT NULL AND tanggal_akhir < CURRENT_DATE + INTERVAL '90 days'),
  'contract_expiring',(SELECT COUNT(*) FROM employees_master WHERE status_kerja='PKWT'
    AND tanggal_akhir IS NOT NULL AND tanggal_akhir >= CURRENT_DATE AND tanggal_akhir < CURRENT_DATE + INTERVAL '90 days'),
  'pkwtt_count',(SELECT COUNT(*) FROM employees_master WHERE status_kerja='PKWTT'),
  'pkwt_count',(SELECT COUNT(*) FROM employees_master WHERE status_kerja='PKWT'));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Fix admin_get_pending_requests — get all pending hr_requests with worker info
CREATE OR REPLACE FUNCTION admin_get_pending_requests() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object(
    'id',r.id,'nrp',r.nrp,'nama',e.nama,'divisi',e.divisi,
    'type',r.type,'status',r.status,'note',r.note,'created_at',r.created_at
  ) ORDER BY r.created_at ASC),'[]'::jsonb))
FROM hr_requests r 
LEFT JOIN employees_master e ON e.nrp=r.nrp 
WHERE r.status='Pending'); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Fix admin_approve_request — approve a worker request
CREATE OR REPLACE FUNCTION admin_approve_request(p_id TEXT, p_note TEXT) RETURNS JSONB AS $$
BEGIN 
  UPDATE hr_requests SET status='Approved', note=COALESCE(p_note,'Disetujui admin') WHERE id=p_id AND status='Pending';
  IF FOUND THEN RETURN jsonb_build_object('ok',true,'msg','Request disetujui.'); END IF;
  RETURN jsonb_build_object('ok',false,'msg','Tidak ditemukan atau sudah diproses.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Fix admin_reject_request — reject a worker request
CREATE OR REPLACE FUNCTION admin_reject_request(p_id TEXT, p_note TEXT) RETURNS JSONB AS $$
BEGIN 
  UPDATE hr_requests SET status='Rejected', note=COALESCE(p_note,'Ditolak admin') WHERE id=p_id AND status='Pending';
  IF FOUND THEN RETURN jsonb_build_object('ok',true,'msg','Request ditolak.'); END IF;
  RETURN jsonb_build_object('ok',false,'msg','Tidak ditemukan atau sudah diproses.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Fix get_worker_leave — add roster info
CREATE OR REPLACE FUNCTION get_worker_leave(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v RECORD; v_div TEXT; v_roster TEXT;
BEGIN 
  SELECT * INTO v FROM hr_leave WHERE nrp=p_nrp ORDER BY tahun DESC LIMIT 1;
  SELECT divisi INTO v_div FROM employees_master WHERE nrp=p_nrp;
  SELECT roster_pattern INTO v_roster FROM hr_work_schedule WHERE divisi_code=v_div;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',true,'kuota',0,'terpakai',0,'sisa',0,'roster_leave','Tidak ada'); END IF;
  RETURN jsonb_build_object('ok',true,
    'kuota',COALESCE(v.kuota_cuti,12),'terpakai',COALESCE(v.cuti_terpakai,0),
    'sisa',COALESCE(v.kuota_cuti,12)-COALESCE(v.cuti_terpakai,0),
    'tahun',v.tahun,
    'roster_leave',CASE WHEN v_roster IS NOT NULL AND v_roster != '-' 
      THEN 'Pola: '||v_roster||' (7 hari kerja / 10 hari off)' 
      ELSE 'Jadwal reguler (5 hari kerja)' END);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. Export functions for admin CSV
CREATE OR REPLACE FUNCTION export_employees() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,
  'headers','NRP;Nama;NIK;Email;Divisi;Posisi;Status Kerja;No HP;Status Aktif',
  'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',nrp,'nama',nama,'nik',nik,'email',email,'divisi',divisi,
      'posisi',posisi,'status_kerja',status_kerja,'no_hp',no_hp,'status_kerja',status_kerja) 
    ORDER BY nama),'[]'::jsonb))
FROM employees_master); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION export_payroll(p_periode TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,
  'headers','NRP;Nama;Periode;Gaji Pokok;Tunjangan;Potongan;Lembur;Bersih',
  'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',e.nrp,'nama',e.nama,'periode',p.periode,
      'base_salary',p.base_salary,'allowance',p.allowance,'deduction',p.deduction,
      'overtime_pay',p.overtime_pay,'net_salary',p.net_salary) 
    ORDER BY e.nrp),'[]'::jsonb))
FROM hr_payroll p LEFT JOIN employees_master e ON e.nrp=p.nrp 
WHERE p.periode=COALESCE(p_periode,(SELECT MAX(periode) FROM hr_payroll))); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION export_attendance(p_periode TEXT) RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,
  'headers','NRP;Nama;Tanggal;Status;Shift;Telat(mnt)',
  'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',a.nrp,'nama',e.nama,'date',a.date,
      'status_hadir',a.status_hadir,'shift',a.shift,'menit_terlambat',a.menit_terlambat) 
    ORDER BY a.nrp,a.date),'[]'::jsonb))
FROM hr_attendance a LEFT JOIN employees_master e ON e.nrp=a.nrp 
WHERE (p_periode IS NULL OR TO_CHAR(a.date,'YYYY-MM')=p_periode) LIMIT 1000); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION export_leave() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,
  'headers','NRP;Nama;Tahun;Kuota;Terpakai;Sisa',
  'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',l.nrp,'nama',e.nama,'tahun',l.tahun,
      'kuota',l.kuota_cuti,'terpakai',l.cuti_terpakai,'sisa',l.kuota_cuti-l.cuti_terpakai) 
    ORDER BY l.nrp),'[]'::jsonb))
FROM hr_leave l LEFT JOIN employees_master e ON e.nrp=l.nrp); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION export_org() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,
  'headers','NRP;Nama;Divisi;Posisi;Atasan;Level',
  'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',e.nrp,'nama',e.nama,'divisi',e.divisi,
      'posisi',e.posisi,'atasan',o.atasan_nrp,'level',COALESCE(ur.role_level,1)) 
    ORDER BY e.nama),'[]'::jsonb))
FROM employees_master e 
LEFT JOIN hr_org o ON o.nrp=e.nrp 
LEFT JOIN user_roles ur ON ur.nrp=e.nrp); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. export_sheet — routes to the right export function
CREATE OR REPLACE FUNCTION export_sheet(p_sheet TEXT) RETURNS JSONB AS $$
BEGIN
  IF p_sheet = 'employees_master' OR p_sheet = 'employees' THEN RETURN export_employees();
  ELSIF p_sheet = 'hr_payroll' OR p_sheet = 'payroll' THEN RETURN export_payroll(NULL);
  ELSIF p_sheet = 'hr_attendance' OR p_sheet = 'attendance' THEN RETURN export_attendance(NULL);
  ELSIF p_sheet = 'hr_leave' OR p_sheet = 'leave' THEN RETURN export_leave();
  ELSIF p_sheet = 'hr_org' OR p_sheet = 'org' THEN RETURN export_org();
  ELSE RETURN jsonb_build_object('ok',false,'msg','Sheet tidak dikenali: '||p_sheet);
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
