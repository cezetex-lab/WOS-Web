-- ============================================================
-- 013_p7_p9_p10_final.sql
-- P7: Financial (cost analysis, ROI)
-- P9: Intelligence (HREngine output, narratives, anomaly)
-- P10: Platform (export, snapshot trends)
-- ============================================================

-- ============================================================
-- SEED: Financial data (hr_finance_kpi)
-- ============================================================
INSERT INTO hr_finance_kpi (periode,divisi,total_employee_avg,revenue,profit,opex,total_labor_cost) VALUES
('2026-07','HRD',8,250000000,50000000,180000000,120000000),
('2026-07','FINANCE',6,180000000,35000000,130000000,90000000),
('2026-07','OPERATIONAL',12,450000000,120000000,280000000,200000000),
('2026-07','IT',4,120000000,25000000,85000000,60000000),
('2026-06','HRD',8,240000000,48000000,175000000,118000000),
('2026-06','FINANCE',6,175000000,33000000,128000000,88000000),
('2026-06','OPERATIONAL',12,430000000,115000000,270000000,195000000),
('2026-06','IT',4,115000000,23000000,82000000,58000000)
ON CONFLICT DO NOTHING;

-- ============================================================
-- SEED: Monthly snapshots
-- ============================================================
INSERT INTO hr_monthly_snapshot (periode,divisi,total_headcount,avg_kpi,total_turnover,total_hire,avg_engagement,total_training_hours,total_incidents,total_overtime_hours,total_payroll,total_revenue,total_profit,productivity_index,compliance_rate,retention_rate) VALUES
('2026-07','HRD',8,82,1,0,78,40,0,80,120000000,250000000,50000000,85,95,98),
('2026-07','FINANCE',6,85,0,0,80,20,0,60,90000000,180000000,35000000,88,100,100),
('2026-07','OPERATIONAL',12,72,2,1,65,60,2,200,200000000,450000000,120000000,75,88,96),
('2026-07','IT',4,88,0,0,82,30,0,40,60000000,120000000,25000000,90,100,100),
('2026-06','HRD',8,80,0,0,76,35,0,75,118000000,240000000,48000000,83,95,100),
('2026-06','FINANCE',6,83,0,0,78,18,0,55,88000000,175000000,33000000,86,100,100),
('2026-06','OPERATIONAL',12,70,1,0,63,55,3,195,195000000,430000000,115000000,73,85,98),
('2026-06','IT',4,86,0,0,80,28,0,38,58000000,115000000,23000000,88,100,100)
ON CONFLICT DO NOTHING;

-- ============================================================
-- SEED: AI tasks (anomaly, flight risk)
-- ============================================================
INSERT INTO hr_ai_tasks (id,agent_name,task_type,title,status,priority,details_json) VALUES
('AI001','HREngine','ANOMALY','Produksi turun 25% di OPERATIONAL','ACTIVE','HIGH','{"division":"OPERATIONAL","drop_pct":25,"ma30":4500,"ma3":3375}'),
('AI002','HREngine','FLIGHT_RISK','NRP020 high flight risk score','ACTIVE','HIGH','{"nrp":"NRP020","score":82,"factors":"KPI 55, Telat 8x"}'),
('AI003','HREngine','FLIGHT_RISK','NRP021 high flight risk score','ACTIVE','HIGH','{"nrp":"NRP021","score":78,"factors":"KPI 58, Telat 6x"}'),
('AI004','HREngine','CERT_EXPIRY','Sertifikat K3 NRP005 expire 30 hari','PENDING','MEDIUM','{"nrp":"NRP005","skill":"K3","days_left":28}'),
('AI005','HREngine','AUTO_COACHING','Auto-coaching untuk NRP020 (KPI < 60)','ACTIVE','HIGH','{"nrp":"NRP020","topic":"PIP - Performance Improvement","reason":"KPI turun 2 bulan"}')
ON CONFLICT DO NOTHING;

-- ============================================================
-- SEED: hr_skills (capability data)
-- ============================================================
INSERT INTO hr_skills (id,nrp,skill_name,level,target_level,certified,skill_code,valid_until) VALUES
('SK001','NRP001','Leadership',4,5,true,'LEAD','2027-01-01'),
('SK002','NRP001','Strategic Planning',4,5,true,'STRAT','2027-06-01'),
('SK003','NRP002','People Management',3,4,true,'PEOP','2026-12-01'),
('SK004','NRP005','Safety K3',2,3,true,'K3','2026-09-15'),
('SK005','NRP008','Data Analysis',2,3,false,'DATA','2027-03-01'),
('SK006','NRP010','Communication',2,3,false,'COMM','2027-01-01'),
('SK007','NRP020','Operational',1,3,false,'OPR','2026-12-01'),
('SK008','NRP025','IT Security',3,4,true,'SEC','2027-06-01')
ON CONFLICT DO NOTHING;

-- ============================================================
-- SEED: hr_capability
-- ============================================================
INSERT INTO hr_capability (nrp,kompetensi,level_sekarang,level_target,gap,is_mandatory) VALUES
('NRP001','Leadership',4,5,1,false),
('NRP001','Strategic Planning',4,5,1,false),
('NRP002','People Management',3,4,1,false),
('NRP005','Safety K3',2,3,1,true),
('NRP008','Data Analysis',2,3,1,false),
('NRP010','Communication',2,3,1,false),
('NRP020','Operational',1,3,2,true),
('NRP025','IT Security',3,4,1,false)
ON CONFLICT DO NOTHING;

-- ============================================================
-- SEED: hr_relations (SP/disciplinary)
-- ============================================================
INSERT INTO hr_relations (nrp,type,related_nrp,notes) VALUES
('NRP020','SP','NRP002','SP1 - Keterlambatan berulang'),
('NRP021','SP','NRP002','SP1 - Absensi tanpa keterangan')
ON CONFLICT DO NOTHING;

-- ============================================================
-- SEED: hr_succession
-- ============================================================
INSERT INTO hr_succession (id,position,candidate_nrp,readiness,notes) VALUES
('SUC001','Manager HRD','NRP005','Ready Soon','Promotion candidate dalam 6 bulan'),
('SUC002','Supervisor Operasional','NRP020','Not Ready','Perlu improvement KPI dulu'),
('SUC003','Kepala IT','NRP026','Ready Now','Senior, sudah siap')
ON CONFLICT DO NOTHING;

-- ============================================================
-- SEED: hr_critical positions
-- ============================================================
INSERT INTO hr_critical (nrp,position,backup_nrp,risk_level) VALUES
('NRP001','CEO','NRP002','HIGH'),
('NRP002','Manager HRD','NRP005','MEDIUM'),
('NRP003','Manager Finance','NRP006','MEDIUM'),
('NRP004','Manager Operasional','NRP007','HIGH')
ON CONFLICT DO NOTHING;


-- ============================================================
-- P7: FINANCIAL FUNCTIONS
-- ============================================================

-- Get financial stats by division
CREATE OR REPLACE FUNCTION get_financial_stats() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('periode',periode,'divisi',divisi,'revenue',revenue,'profit',profit,'opex',opex,'labor_cost',total_labor_cost,
    'profit_margin',CASE WHEN revenue>0 THEN ROUND(profit/revenue*100,1) ELSE 0 END,
    'labor_pct',CASE WHEN revenue>0 THEN ROUND(total_labor_cost/revenue*100,1) ELSE 0 END)
    ORDER BY periode DESC, revenue DESC),'[]'::jsonb))
  FROM hr_finance_kpi); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Cost per production unit
CREATE OR REPLACE FUNCTION get_cost_per_unit() RETURNS JSONB AS $$
DECLARE v_labor NUMERIC; v_prod NUMERIC; BEGIN
  SELECT SUM(total_labor_cost) INTO v_labor FROM hr_finance_kpi WHERE periode=(SELECT MAX(periode) FROM hr_finance_kpi);
  SELECT SUM(volume) INTO v_prod FROM hr_production_daily WHERE date>=date_trunc('month',NOW());
  RETURN jsonb_build_object('ok',true,'labor_cost',COALESCE(v_labor,0),'total_production',COALESCE(v_prod,0),
    'cost_per_ton',CASE WHEN v_prod>0 THEN ROUND(v_labor/v_prod,2) ELSE 0 END); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Financial trend (3 months)
CREATE OR REPLACE FUNCTION get_financial_trend() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('periode',periode,'total_revenue',SUM(revenue),'total_profit',SUM(profit),'total_labor',SUM(total_labor_cost),
    'profit_margin',CASE WHEN SUM(revenue)>0 THEN ROUND(SUM(profit)/SUM(revenue)*100,1) ELSE 0 END) ORDER BY periode DESC),'[]'::jsonb))
  FROM hr_finance_kpi GROUP BY periode LIMIT 6); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- P9: INTELLIGENCE FUNCTIONS
-- ============================================================

-- HREngine: Flight risk details
CREATE OR REPLACE FUNCTION get_flight_risk_details() RETURNS JSONB AS $$ BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',e.nrp,'nama',e.nama,'divisi',e.divisi,'posisi',e.posisi,
    'kpi_score',COALESCE(p.kpi_score,0),'telat_count',COALESCE(t.telat_count,0),
    'sp_count',COALESCE(s.sp_count,0),'risk_score',ROUND(COALESCE(p.kpi_score,100)*0.3 + COALESCE(t.telat_count,0)*10*0.4 + COALESCE(s.sp_count,0)*15*0.3,0))
    ORDER BY COALESCE(p.kpi_score,100) ASC),'[]'::jsonb))
  FROM employees_master e
  LEFT JOIN hr_performance p ON p.nrp=e.nrp AND p.period=(SELECT MAX(period) FROM hr_performance)
  LEFT JOIN (SELECT nrp,COUNT(*) as telat_count FROM hr_attendance WHERE status_hadir='Telat' AND date>=date_trunc('month',NOW()) GROUP BY nrp) t ON t.nrp=e.nrp
  LEFT JOIN (SELECT nrp,COUNT(*) as sp_count FROM hr_relations WHERE type='SP' GROUP BY nrp) s ON s.nrp=e.nrp
  WHERE COALESCE(p.kpi_score,100)<70 OR COALESCE(t.telat_count,0)>5); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- HREngine: Anomaly detection
CREATE OR REPLACE FUNCTION get_anomaly_details() RETURNS JSONB AS $$
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'agent',agent_name,'type',task_type,'title',title,'status',status,'priority',priority,'details',details_json,'created_at',created_at)
    ORDER BY created_at DESC),'[]'::jsonb))
  FROM hr_ai_tasks ORDER BY created_at DESC LIMIT 20); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- HREngine: Auto-healing actions
CREATE OR REPLACE FUNCTION get_auto_healing_actions() RETURNS JSONB AS $$
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'agent',agent_name,'type',task_type,'title',title,'status',status,'details',details_json)
    ORDER BY created_at DESC),'[]'::jsonb))
  FROM hr_ai_tasks WHERE task_type IN ('AUTO_COACHING','AUTO_ENROLL','AUTO_REJECT') LIMIT 20); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Narrative: generate human-readable narrative for a worker
CREATE OR REPLACE FUNCTION get_worker_narrative(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v_emp RECORD; v_kpi RECORD; v_att RECORD; v_leave RECORD; v_narrative TEXT;
DECLARE v_sapaan TEXT; v_analisis TEXT; v_action TEXT; v_outcome TEXT; v_penutup TEXT;
DECLARE v_kpi_score INT; v_kpi_target INT; v_gap INT;
BEGIN
  SELECT * INTO v_emp FROM employees_master WHERE nrp=p_nrp;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'msg','Pekerja tidak ditemukan'); END IF;
  SELECT * INTO v_kpi FROM hr_performance WHERE nrp=p_nrp ORDER BY periode DESC LIMIT 1;
  SELECT COUNT(*) FILTER(WHERE status_hadir='Hadir') as hadir,COUNT(*) as total,
    COUNT(*) FILTER(WHERE status_hadir='Telat') as telat INTO v_att
  FROM hr_attendance WHERE nrp=p_nrp AND date>=date_trunc('month',NOW()) AND date<date_trunc('month',NOW())+INTERVAL '1 month';
  SELECT * INTO v_leave FROM hr_leave WHERE nrp=p_nrp ORDER BY tahun DESC LIMIT 1;

  v_kpi_score := COALESCE(v_kpi.kpi_score, 70)::INT;
  v_kpi_target := 85;
  v_gap := v_kpi_target - v_kpi_score;

  -- Sapaan
  v_sapaan := 'Halo ' || v_emp.nama || ', performa Anda pada periode ' || COALESCE(v_kpi.periode,'-') || ' telah kami evaluasi dengan semangat membangun.';

  -- Analisis
  IF v_gap > 0 THEN
    v_analisis := 'Skor KPI Anda saat ini ' || v_kpi_score || ' dari target ' || v_kpi_target || '. ';
    IF COALESCE(v_att.telat, 0) > 3 THEN
      v_analisis := v_analisis || 'Penurunan terutama disebabkan oleh keterlambatan sebanyak ' || v_att.telat || ' kali dalam sebulan terakhir. ';
    END IF;
    IF COALESCE(v_att.hadir, 0) < COALESCE(v_att.total, 0) * 0.9 THEN
      v_analisis := v_analisis || 'Tingkat kehadiran ' || ROUND(COALESCE(v_att.hadir,0)::NUMERIC/NULLIF(COALESCE(v_att.total,1),0)*100) || '% perlu ditingkatkan. ';
    END IF;
  ELSE
    v_analisis := 'Skor KPI Anda ' || v_kpi_score || ' sudah sesuai target. Pertahankan performa positif ini! ';
  END IF;

  -- Action plan
  IF v_gap > 0 THEN
    v_action := '1. Datang 15 menit lebih awal untuk menghindari keterlambatan. ';
    v_action := v_action || '2. Gunakan fitur Digital Leave Request di WOS jika berhalangan hadir. ';
    v_action := v_action || '3. Evaluasi mandiri setiap Jumat sore dengan mengecek dashboard kehadiran.';
  ELSE
    v_action := '1. Pertahankan konsistensi kehadiran tepat waktu. ';
    v_action := v_action || '2. Ikuti training lanjutan untuk meningkatkan skill. ';
    v_action := v_action || '3. Bantu rekan tim yang membutuhkan bimbingan.';
  END IF;

  -- Outcome
  IF v_gap > 0 THEN
    v_outcome := 'Jika konsisten selama 1 bulan, skor KPI dipastikan naik ke ' || v_kpi_target || '+. Peluang bonus dan promosi akan terbuka.';
  ELSE
    v_outcome := 'Dengan performa ini, Anda berpeluang menjadi High Performer dan mendapatkan reward tahunan.';
  END IF;

  -- Penutup
  v_penutup := 'Tim HRD siap mendukung. Silakan jadwalkan sesi coaching jika perlu.';

  RETURN jsonb_build_object('ok',true,
    'nrp',p_nrp,'nama',v_emp.nama,'period',COALESCE(v_kpi.periode,'-'),
    'kpi_score',v_kpi_score,'kpi_target',v_kpi_target,'gap',v_gap,
    'sapaan',v_sapaan,'analisis',v_analisis,'action_plan',v_action,'outcome',v_outcome,'penutup',v_penutup,
    'data_source_mode',CASE WHEN v_kpi_score > 0 THEN 'live' ELSE 'dummy' END); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Dashboard narrative: team summary
CREATE OR REPLACE FUNCTION get_team_narrative(p_nrp TEXT) RETURNS JSONB AS $$
DECLARE v_avg NUMERIC; v_count INT; v_low INT; v_high INT; v_narrative TEXT;
BEGIN
  SELECT ROUND(AVG(p.kpi_score),1),COUNT(*),COUNT(*) FILTER(WHERE p.kpi_score<60),COUNT(*) FILTER(WHERE p.kpi_score>=80)
  INTO v_avg,v_count,v_low,v_high
  FROM hr_performance p JOIN hr_org o ON o.nrp=p.nrp WHERE o.atasan_nrp=p_nrp AND p.period=(SELECT MAX(period) FROM hr_performance);

  v_narrative := 'Tim Anda memiliki ' || v_count || ' anggota dengan rata-rata KPI ' || COALESCE(v_avg,0) || '. ';
  IF v_low > 0 THEN v_narrative := v_narrative || v_low || ' anggota perlu perhatian (KPI < 60). '; END IF;
  IF v_high > 0 THEN v_narrative := v_narrative || v_high << ' anggota High Performers. '; END IF;

  RETURN jsonb_build_object('ok',true,'avg_kpi',COALESCE(v_avg,0),'team_size',COALESCE(v_count,0),
    'low_performers',COALESCE(v_low,0),'high_performers',COALESCE(v_high,0),'narrative',v_narrative); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- P10: PLATFORM FUNCTIONS
-- ============================================================

-- Export data (returns CSV-ready JSON)
CREATE OR REPLACE FUNCTION export_employees() RETURNS JSONB AS $$
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',nrp,'nama',nama,'nik',nik,'email',email,'divisi',divisi,'posisi',posisi,'status_kerja',status_kerja,'no_hp',no_hp)
    ORDER BY nama),'[]'::jsonb))
  FROM employees_master); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Export payroll
CREATE OR REPLACE FUNCTION export_payroll(p_periode TEXT) RETURNS JSONB AS $$
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',nrp,'periode',periode,'base_salary',base_salary,'allowance',allowance,'deduction',deduction,'overtime_pay',overtime_pay,'net_salary',net_salary)
    ORDER BY nrp),'[]'::jsonb))
  FROM hr_payroll WHERE periode=COALESCE(p_periode,(SELECT MAX(periode) FROM hr_payroll))); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Real-time: get latest notifications
CREATE OR REPLACE FUNCTION get_realtime_notifications(p_nrp TEXT, p_since TIMESTAMPTZ) RETURNS JSONB AS $$
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('id',id,'category',category,'title',title,'message',message,'created_at',created_at) ORDER BY created_at DESC),'[]'::jsonb))
  FROM hr_notifications WHERE nrp=p_nrp AND created_at > COALESCE(p_since, NOW() - INTERVAL '1 hour') LIMIT 10); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- KPI config
CREATE OR REPLACE FUNCTION get_kpi_config_all() RETURNS JSONB AS $$
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('position_code',position_code,'indicator',indicator,'target_value',target_value,'uom',uom,'weight',weight,'formula_type',formula_type)),'[]'::jsonb))
  FROM hr_kpi_config); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- KPI calc log
CREATE OR REPLACE FUNCTION get_kpi_calc_log_all() RETURNS JSONB AS $$
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',nrp,'periode',periode,'indicator',indicator,'realisasi',realisasi,'target',target,'final_score',final_score) ORDER BY created_at DESC),'[]'::jsonb))
  FROM hr_kpi_calc_log LIMIT 50); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
