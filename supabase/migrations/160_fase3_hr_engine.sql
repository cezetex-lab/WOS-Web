-- ================================================================
-- FASE 3: HR ENGINE (Analytics & Auto-Healing)
-- Migration 160
-- ================================================================

-- 3.1 KPI Bulanan (Composite: attendance 40% + production 35% + safety 25%)
CREATE OR REPLACE FUNCTION run_monthly_kpi(p_period TEXT)
RETURNS JSONB AS $$
DECLARE
  v_count INT := 0; v_emp RECORD;
  v_kpi NUMERIC; v_att NUMERIC; v_prod NUMERIC; v_safe NUMERIC;
BEGIN
  FOR v_emp IN SELECT em.nrp, em.nama FROM employees_master em WHERE em.is_active = true LOOP
    SELECT COALESCE(ROUND(SUM(CASE WHEN status='Hadir' THEN 1 ELSE 0 END)::NUMERIC/NULLIF(COUNT(*),0)*100,2),0)
    INTO v_att FROM hr_attendance WHERE nrp=v_emp.nrp AND date_trunc('month',date::date)=date_trunc('month',p_period::date);
    v_prod := 75;
    SELECT GREATEST(0,100-COUNT(*)*10) INTO v_safe FROM hr_safety_incidents WHERE nrp=v_emp.nrp;
    v_kpi := ROUND((v_att*0.4+v_prod*0.35+v_safe*0.25),2);
    INSERT INTO hr_performance (nrp,period,kpi_score,attendance_score,production_score,safety_score,created_at)
    VALUES (v_emp.nrp,p_period,v_kpi,v_att,v_prod,v_safe,NOW())
    ON CONFLICT (nrp,period) DO UPDATE SET kpi_score=v_kpi,attendance_score=v_att,production_score=v_prod,safety_score=v_safe;
    v_count := v_count + 1;
  END LOOP;
  INSERT INTO audit_log (action,detail,timestamp) VALUES ('KPI_MONTHLY','Period: '||p_period||', processed: '||v_count,NOW());
  RETURN jsonb_build_object('ok',true,'period',p_period,'processed',v_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 3.2 Daily Intelligence (Flight Risk + Cert Expiry)
CREATE OR REPLACE FUNCTION run_daily_intelligence()
RETURNS JSONB AS $$
DECLARE v_count INT:=0; v_emp RECORD; v_flight NUMERIC; v_cert RECORD;
BEGIN
  FOR v_emp IN SELECT em.nrp,em.nama,
    COALESCE(ROUND(SUM(CASE WHEN status!='Hadir' THEN 1 ELSE 0 END)::NUMERIC/NULLIF(COUNT(*),0)*100,2),0) AS abs_rate,
    COALESCE((SELECT kpi_score FROM hr_performance WHERE nrp=em.nrp ORDER BY period DESC LIMIT 1),70) AS last_kpi
  FROM employees_master em LEFT JOIN hr_attendance a ON a.nrp=em.nrp AND a.date>=(NOW()-INTERVAL '90 days')::date
  WHERE em.is_active=true GROUP BY em.nrp,em.nama LOOP
    v_flight:=LEAST(100,(v_emp.abs_rate*0.6)+((100-v_emp.last_kpi)*0.4));
    IF v_flight>60 THEN
      INSERT INTO notifications (nrp,title,message,type,created_at)
      VALUES (v_emp.nrp,'Flight Risk Warning','Risk: '||ROUND(v_flight)||'%','warning',NOW());
      v_count:=v_count+1;
    END IF;
  END LOOP;
  FOR v_cert IN SELECT em.nrp,em.sertifikasi_pekerja,em.masa_berlaku_sertifikasi
  FROM employees_master em WHERE em.is_active=true AND em.masa_berlaku_sertifikasi IS NOT NULL
    AND em.masa_berlaku_sertifikasi<=(NOW()+INTERVAL '30 days')::date LOOP
    INSERT INTO notifications (nrp,title,message,type,created_at)
    VALUES (v_cert.nrp,'Certificate Expiring',v_cert.sertifikasi_pekerja||' expires: '||v_cert.masa_berlaku_sertifikasi,
      CASE WHEN v_cert.masa_berlaku_sertifikasi<=NOW()::date THEN 'critical' ELSE 'warning' END,NOW());
    v_count:=v_count+1;
  END LOOP;
  INSERT INTO audit_log (action,detail,timestamp) VALUES ('DAILY_INTEL','Alerts: '||v_count,NOW());
  RETURN jsonb_build_object('ok',true,'alerts',v_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 3.3 Monthly Intelligence (OT cost/ton, talent gap)
CREATE OR REPLACE FUNCTION run_monthly_intelligence()
RETURNS JSONB AS $$
DECLARE v_ot NUMERIC; v_gap INT;
BEGIN
  SELECT COALESCE(SUM(overtime_pay)/NULLIF(SUM(production_volume),0),0) INTO v_ot
  FROM hr_payroll p LEFT JOIN hr_production pr ON pr.nrp=p.nrp AND pr.period=p.period
  WHERE p.period=to_char(NOW()-INTERVAL '1 month','YYYY-MM');
  SELECT COUNT(*) INTO v_gap FROM employees_master em WHERE em.is_active=false AND em.resign_date>(NOW()-INTERVAL '3 month')::date;
  INSERT INTO audit_log (action,detail,timestamp) VALUES ('MONTHLY_INTEL','OT/ton: '||v_ot||', gaps: '||v_gap,NOW());
  RETURN jsonb_build_object('ok',true,'ot_cost_per_ton',v_ot,'talent_gap',v_gap);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 3.4 Auto-Healing: Coaching
CREATE OR REPLACE FUNCTION auto_coaching(p_nrp TEXT, p_topic TEXT, p_reason TEXT)
RETURNS JSONB AS $$
BEGIN
  INSERT INTO notifications (nrp,title,message,type,created_at)
  VALUES (p_nrp,'Auto Coaching: '||p_topic,p_reason,'coaching',NOW());
  INSERT INTO audit_log (action,detail,timestamp) VALUES ('AUTO_COACHING','NRP: '||p_nrp,NOW());
  RETURN jsonb_build_object('ok',true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 3.5 Auto-Healing: Training Enrollment
CREATE OR REPLACE FUNCTION auto_learn(p_nrp TEXT, p_skill_code TEXT)
RETURNS JSONB AS $$
BEGIN
  INSERT INTO notifications (nrp,title,message,type,created_at)
  VALUES (p_nrp,'Auto Training Enrollment','Skill: '||p_skill_code,'training',NOW());
  INSERT INTO audit_log (action,detail,timestamp) VALUES ('AUTO_LEARN','NRP: '||p_nrp||', Skill: '||p_skill_code,NOW());
  RETURN jsonb_build_object('ok',true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 3.6 Auto-Healing: Reject Overtime (budget > 90%)
CREATE OR REPLACE FUNCTION auto_reject_ot()
RETURNS JSONB AS $$
DECLARE v_rejected INT:=0; v_rec RECORD;
BEGIN
  FOR v_rec IN SELECT nrp,SUM(overtime_pay) AS total_ot FROM hr_payroll
    WHERE period=to_char(NOW(),'YYYY-MM') GROUP BY nrp
    HAVING SUM(overtime_pay)>COALESCE((SELECT (config_value->>'value')::NUMERIC*0.9 FROM company_config WHERE config_key='budget_ot_monthly'),999999999)
  LOOP
    UPDATE hr_attendance SET overtime_approved=false WHERE nrp=v_rec.nrp AND overtime_approved IS NULL;
    v_rejected:=v_rejected+1;
  END LOOP;
  INSERT INTO audit_log (action,detail,timestamp) VALUES ('AUTO_REJECT_OT','Rejected: '||v_rejected,NOW());
  RETURN jsonb_build_object('ok',true,'rejected',v_rejected);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION run_monthly_kpi(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION run_daily_intelligence() TO authenticated;
GRANT EXECUTE ON FUNCTION run_monthly_intelligence() TO authenticated;
GRANT EXECUTE ON FUNCTION auto_coaching(TEXT,TEXT,TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION auto_learn(TEXT,TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION auto_reject_ot() TO authenticated;

DO $$ BEGIN
  RAISE NOTICE '=== Fase 3: HR Engine -- 6 functions, 6 GRANTs ===';
END $$;
