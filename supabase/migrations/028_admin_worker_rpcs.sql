-- ============================================================
-- 028_admin_worker_rpcs.sql
-- New RPC functions for admin & worker pages that had no RPC
-- Run in Supabase SQL Editor after 027_seed_remaining_tables.sql
-- ============================================================

-- ============================================================
-- ADMIN RPCs — for pages that had broken/non-existent RPC names
-- ============================================================

-- pending requests (was admin_get_requests)
CREATE OR REPLACE FUNCTION admin_get_pending_requests() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',r.id,'nrp',r.nrp,'nama',e.nama,'type',r.type,'status',r.status,'note',r.note,'created_at',r.created_at)
    ORDER BY r.created_at DESC),'[]'::jsonb))
  FROM hr_requests r LEFT JOIN employees_master e ON e.nrp=r.nrp WHERE r.status='Pending' LIMIT 50); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- overtime data for admin view
CREATE OR REPLACE FUNCTION admin_get_overtime() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'nrp',nrp,'date',date,'hours',hours,'reason',reason,'status',status)
    ORDER BY date DESC),'[]'::jsonb))
  FROM hr_overtime LIMIT 50); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- timesheet data (uses hr_attendance as timesheet)
CREATE OR REPLACE FUNCTION admin_get_timesheet() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'nrp',nrp,'date',date,'status_hadir',status_hadir,'jam_masuk',jam_masuk,'jam_keluar',jam_keluar,'menit_terlambat',menit_terlambat,'shift',shift)
    ORDER BY date DESC),'[]'::jsonb))
  FROM hr_attendance ORDER BY date DESC LIMIT 50); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- certifications (uses hr_skills with certified flag)
CREATE OR REPLACE FUNCTION admin_get_certifications() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'nrp',nrp,'skill_name',skill_name,'level',level,'certified',certified,'valid_until',valid_until)
    ORDER BY created_at DESC),'[]'::jsonb))
  FROM hr_skills WHERE certified=true LIMIT 50); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- badges / gamifikasi (placeholder — uses hr_performance for top performers)
CREATE OR REPLACE FUNCTION admin_get_badges() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',p.nrp,'nama',e.nama,'kpi_score',p.kpi_score,'badge',
      CASE WHEN p.kpi_score>=85 THEN 'Gold' WHEN p.kpi_score>=75 THEN 'Silver' WHEN p.kpi_score>=60 THEN 'Bronze' ELSE 'No Badge' END,
      'periode',p.periode) ORDER BY p.kpi_score DESC),'[]'::jsonb))
  FROM hr_performance p LEFT JOIN employees_master e ON e.nrp=p.nrp WHERE p.periode=(SELECT MAX(periode) FROM hr_performance) LIMIT 30); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- OKR (placeholder — uses hr_kpi_config as OKR source)
CREATE OR REPLACE FUNCTION admin_get_okr() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'position_code',position_code,'indicator',indicator,'target_value',target_value,'uom',uom,'weight',weight,'formula_type',formula_type)
    ORDER BY id),'[]'::jsonb))
  FROM hr_kpi_config LIMIT 30); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- assets (placeholder — uses hr_equipment_util as asset proxy)
CREATE OR REPLACE FUNCTION admin_get_assets() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'machine_id',machine_id,'date',date,'fuel_liters',fuel_liters,'availability_pct',availability_pct)
    ORDER BY date DESC),'[]'::jsonb))
  FROM hr_equipment_util LIMIT 30); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- asset assignments (placeholder — uses hr_equipment_util)
CREATE OR REPLACE FUNCTION admin_get_asset_assignments() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('machine_id',machine_id,'date',date,'shift',shift,'fuel_liters',fuel_liters,'availability_pct',availability_pct)
    ORDER BY date DESC),'[]'::jsonb))
  FROM hr_equipment_util LIMIT 30); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- estate blocks (placeholder — uses hr_production_daily)
CREATE OR REPLACE FUNCTION admin_get_estate_blocks() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',nrp,'date',date,'shift',shift,'volume',volume,'uom',uom)
    ORDER BY date DESC),'[]'::jsonb))
  FROM hr_production_daily LIMIT 30); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- facility requests (placeholder — uses hr_requests with type)
CREATE OR REPLACE FUNCTION admin_get_facility_requests() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'nrp',nrp,'type',type,'status',status,'note',note,'created_at',created_at)
    ORDER BY created_at DESC),'[]'::jsonb))
  FROM hr_requests WHERE type ILIKE '%facility%' OR type ILIKE '%aset%' LIMIT 30); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- surveys / eNPS (uses hr_engagement)
CREATE OR REPLACE FUNCTION admin_get_surveys() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',nrp,'score',score,'period',period)
    ORDER BY created_at DESC),'[]'::jsonb))
  FROM hr_engagement ORDER BY created_at DESC LIMIT 30); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- whistleblower (placeholder — uses hr_safety for incident reports)
CREATE OR REPLACE FUNCTION admin_get_whistleblower() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'nrp',nrp,'incident_type',incident_type,'severity',severity,'description',description,'date',incident_date)
    ORDER BY incident_date DESC),'[]'::jsonb))
  FROM hr_safety LIMIT 30); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- exit interviews (uses hr_exit_clearance)
CREATE OR REPLACE FUNCTION admin_get_exit_interviews() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',nrp,'resign_date',resign_date,'last_work_date',last_work_date,'clearance_status',clearance_status)
    ORDER BY resign_date DESC),'[]'::jsonb))
  FROM hr_exit_clearance LIMIT 20); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- settlements (placeholder — uses hr_exit_clearance)
CREATE OR REPLACE FUNCTION admin_get_settlements() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',nrp,'resign_date',resign_date,'clearance_status',clearance_status)
    ORDER BY resign_date DESC),'[]'::jsonb))
  FROM hr_exit_clearance LIMIT 20); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- audit chain (uses audit_log)
CREATE OR REPLACE FUNCTION admin_get_audit_chain() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'timestamp',timestamp,'actor',actor,'action',action,'detail',detail)
    ORDER BY timestamp DESC),'[]'::jsonb))
  FROM audit_log LIMIT 50); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- feature flags (placeholder — uses settings table)
CREATE OR REPLACE FUNCTION admin_get_feature_flags() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('key',key,'value',value)
    ORDER BY key),'[]'::jsonb))
  FROM settings LIMIT 20); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- headcount plan (uses hr_talent_catalog)
CREATE OR REPLACE FUNCTION admin_get_headcount_plan() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('type',type,'judul',judul,'status',status,'priority',priority)
    ORDER BY created_at DESC),'[]'::jsonb))
  FROM hr_talent_catalog LIMIT 20); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- budget allocation (placeholder — uses hr_finance_kpi)
CREATE OR REPLACE FUNCTION admin_get_budget() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('periode',periode,'divisi',divisi,'revenue',revenue,'opex',opex,'profit',profit,'total_labor_cost',total_labor_cost)
    ORDER BY created_at DESC),'[]'::jsonb))
  FROM hr_finance_kpi ORDER BY created_at DESC LIMIT 20); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- referrals (placeholder — uses daftar_baru)
CREATE OR REPLACE FUNCTION admin_get_referrals() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'nrp',nrp,'nama',nama,'email',email,'divisi',divisi,'posisi',posisi,'status',status,'created_at',created_at)
    ORDER BY created_at DESC),'[]'::jsonb))
  FROM daftar_baru LIMIT 20); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- WORKER RPCs — for worker sub-pages that had no RPC
-- ============================================================

-- worker attendance (all attendance for the worker)
CREATE OR REPLACE FUNCTION get_worker_attendance(p_nrp TEXT) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'date',date,'status_hadir',status_hadir,'jam_masuk',jam_masuk,'menit_terlambat',menit_terlambat,'jam_keluar',jam_keluar,'shift',shift)
    ORDER BY date DESC),'[]'::jsonb))
  FROM hr_attendance WHERE nrp=p_nrp LIMIT 30); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- worker leave
CREATE OR REPLACE FUNCTION get_worker_leave(p_nrp TEXT) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',nrp,'tahun',tahun,'kuota_cuti',kuota_cuti,'cuti_terpakai',cuti_terpakai)
    ORDER BY created_at DESC),'[]'::jsonb))
  FROM hr_leave WHERE nrp=p_nrp LIMIT 5); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- worker overtime
CREATE OR REPLACE FUNCTION get_worker_overtime(p_nrp TEXT) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'date',date,'hours',hours,'reason',reason,'status',status)
    ORDER BY date DESC),'[]'::jsonb))
  FROM hr_overtime WHERE nrp=p_nrp LIMIT 30); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- worker KPI (continuous performance)
CREATE OR REPLACE FUNCTION get_worker_kpi(p_nrp TEXT) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('periode',periode,'kpi_score',kpi_score,'feedback',feedback_json)
    ORDER BY created_at DESC),'[]'::jsonb))
  FROM hr_performance WHERE nrp=p_nrp LIMIT 12); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- worker career (uses hr_skills + user_roles)
CREATE OR REPLACE FUNCTION get_worker_career(p_nrp TEXT) RETURNS JSONB AS $$ DECLARE v_emp RECORD; v_role RECORD; BEGIN
  SELECT * INTO v_emp FROM employees_master WHERE nrp=p_nrp;
  SELECT * INTO v_role FROM user_roles WHERE nrp=p_nrp;
  RETURN jsonb_build_object('ok',true,
    'current_position',COALESCE(v_emp.posisi,'-'),
    'current_level',COALESCE(v_role.role_level,1),
    'division',COALESCE(v_emp.divisi,'-'),
    'data',COALESCE((SELECT jsonb_agg(jsonb_build_object('skill',skill_name,'level',level,'target_level',target_level)) FROM hr_skills WHERE nrp=p_nrp),'[]'::jsonb)); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- worker tasks
CREATE OR REPLACE FUNCTION get_worker_tasks(p_nrp TEXT) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'title',title,'status',status,'due_date',due_date)
    ORDER BY due_date),'[]'::jsonb))
  FROM hr_tasks WHERE assignee_nrp=p_nrp LIMIT 20); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- worker profile (basic employee data)
CREATE OR REPLACE FUNCTION get_worker_profile(p_nrp TEXT) RETURNS JSONB AS $$ DECLARE v RECORD; BEGIN
  SELECT * INTO v FROM employees_master WHERE nrp=p_nrp;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'msg','Employee not found'); END IF;
  RETURN jsonb_build_object('ok',true,
    'nrp',v.nrp,'nik',v.nik,'nama',v.nama,'email',v.email,
    'divisi',v.divisi,'posisi',v.posisi,'status_kerja',v.status_kerja,
    'tanggal_lahir',v.tanggal_lahir,'jenis_kelamin',v.jenis_kelamin,
    'alamat',v.alamat,'no_hp',v.no_hp,'tanggal_masuk',v.tanggal_masuk); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- worker activities (audit log for this worker)
CREATE OR REPLACE FUNCTION get_worker_activities(p_nrp TEXT) RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('timestamp',timestamp,'action',action,'detail',detail)
    ORDER BY timestamp DESC),'[]'::jsonb))
  FROM audit_log WHERE actor=p_nrp LIMIT 20); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- DONE — All missing RPCs created
-- ============================================================
