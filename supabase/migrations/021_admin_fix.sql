-- ============================================================
-- 021_admin_fix.sql — Fix ALL admin functions + seed admin password
-- Run this ONE query in Supabase SQL Editor
-- ============================================================

-- 1. Fix admin password seed
INSERT INTO settings (key, value) VALUES ('admin_password', 'Admin123') ON CONFLICT (key) DO UPDATE SET value = 'Admin123';

-- 2. Fix admin_get_summary (no "Divisi Departemen" column)
CREATE OR REPLACE FUNCTION admin_get_summary() RETURNS JSONB AS $$
BEGIN RETURN jsonb_build_object('ok',true,
  'total_workers',(SELECT COUNT(*) FROM employees_master),
  'total_divisions',(SELECT COUNT(DISTINCT divisi) FROM employees_master),
  'pending_requests',(SELECT COUNT(*) FROM hr_requests WHERE status='Pending'),
  'pending_registrations',(SELECT COUNT(*) FROM daftar_baru WHERE status='PENDING')); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Fix admin_get_pending (no GROUP BY needed)
CREATE OR REPLACE FUNCTION admin_get_pending() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'nrp',nrp,'nik',nik,'nama',nama,'email',email,'status',status,'created_at',created_at) ORDER BY created_at ASC),'[]'::jsonb))
FROM daftar_baru WHERE status='PENDING'); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Fix admin_get_audit_log (correct column: timestamp not created_at)
CREATE OR REPLACE FUNCTION admin_get_audit_log() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('action',action,'result','OK','message',detail,'created_at',timestamp) ORDER BY timestamp DESC),'[]'::jsonb))
FROM audit_log LIMIT 50); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Fix admin_get_org_structure
CREATE OR REPLACE FUNCTION admin_get_org_structure() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',e.nrp,'nama',e.nama,'divisi',e.divisi,'posisi',e.posisi,'atasan',o.atasan_nrp,'level',COALESCE(ur.role_level,1)) ORDER BY e.nama),'[]'::jsonb))
FROM employees_master e LEFT JOIN hr_org o ON o.nrp=e.nrp LEFT JOIN user_roles ur ON ur.nrp=e.nrp); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Fix admin_get_divisions
CREATE OR REPLACE FUNCTION admin_get_divisions() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(jsonb_build_object('divisi',divisi,'headcount',hc)),'[]'::jsonb))
FROM (SELECT divisi,COUNT(*) as hc FROM employees_master WHERE divisi IS NOT NULL GROUP BY divisi) t); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Fix get_financial_trend (extra parenthesis removed)
CREATE OR REPLACE FUNCTION get_financial_trend() RETURNS JSONB AS $$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('periode',periode,'total_revenue',SUM(revenue),'total_profit',SUM(profit),'total_labor',SUM(total_labor_cost),
  'profit_margin',CASE WHEN SUM(revenue)>0 THEN ROUND(SUM(profit)/SUM(revenue)*100,1) ELSE 0 END) ORDER BY periode DESC),'[]'::jsonb))
FROM hr_finance_kpi GROUP BY periode LIMIT 6); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. Fix get_narrative (string concatenation)
CREATE OR REPLACE FUNCTION get_narrative(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v_kpi NUMERIC; v_att NUMERIC; v_nama TEXT; v_narasi TEXT;
BEGIN
  SELECT kpi_score INTO v_kpi FROM hr_performance WHERE nrp=p_nrp ORDER BY created_at DESC LIMIT 1;
  SELECT ROUND(COUNT(*) FILTER(WHERE status_hadir='Hadir')::NUMERIC/NULLIF(COUNT(*),0)*100,1) INTO v_att
    FROM hr_attendance WHERE nrp=p_nrp AND date>=date_trunc('month',NOW());
  SELECT nama INTO v_nama FROM employees_master WHERE nrp=p_nrp;
  v_narasi := 'Halo '||COALESCE(v_nama,'Karyawan')||'. ';
  IF COALESCE(v_kpi,0) >= 80 THEN
    v_narasi := v_narasi || 'KPI Anda Excellent ('||COALESCE(v_kpi,0)||'). Pertahankan! ';
  ELSIF COALESCE(v_kpi,0) >= 60 THEN
    v_narasi := v_narasi || 'KPI Anda cukup baik ('||COALESCE(v_kpi,0)||'). Ada ruang untuk improvement. ';
  ELSE
    v_narasi := v_narasi || 'KPI Anda perlu perhatian ('||COALESCE(v_kpi,0)||'). Rekomendasi: coaching 1:1 dengan atasan. ';
  END IF;
  IF COALESCE(v_att,100) < 90 THEN
    v_narasi := v_narasi || 'Kehadiran Anda ('||v_att||'%) perlu diperbaiki.';
  END IF;
  RETURN jsonb_build_object('ok',true,'narrative',v_narasi,'kpi',COALESCE(v_kpi,0),'attendance_pct',COALESCE(v_att,100));
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. Fix checkin_asset (UPDATE ORDER BY not valid in PostgreSQL)
CREATE OR REPLACE FUNCTION checkin_asset(p_asset_id TEXT, p_condition TEXT) RETURNS JSONB AS $$
BEGIN
  UPDATE assets SET status='AVAILABLE', assigned_to=NULL WHERE id=p_asset_id;
  UPDATE asset_assignments SET checkin_date=CURRENT_DATE, condition_in=p_condition
    WHERE ctid IN (SELECT ctid FROM asset_assignments WHERE asset_id=p_asset_id AND checkin_date IS NULL ORDER BY checkout_date DESC LIMIT 1);
  RETURN jsonb_build_object('ok',true,'msg','Aset di-checkin.');
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10. Verify all functions exist
DO $$ DECLARE fn TEXT; BEGIN
  FOREACH fn IN ARRAY ARRAY['admin_get_summary','admin_get_pending','admin_get_audit_log','admin_get_org_structure','admin_get_divisions','get_financial_trend','get_narrative','checkin_asset'] LOOP
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = fn) THEN
      RAISE NOTICE 'OK: % exists', fn;
    ELSE
      RAISE NOTICE 'MISSING: %', fn;
    END IF;
  END LOOP;
END $$;
