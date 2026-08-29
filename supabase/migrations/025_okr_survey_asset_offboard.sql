-- ============================================================
-- 025: Wave 3 — OKR, Survey, Tasks, Shift Swaps
-- ============================================================

-- TASKS board (kanban)
DO $$ BEGIN
  CREATE TABLE IF NOT EXISTS hr_task_board (
    id SERIAL PRIMARY KEY,
    nrp TEXT NOT NULL,
    assigner_nrp TEXT,
    title TEXT NOT NULL,
    description TEXT,
    status TEXT DEFAULT 'todo' CHECK (status IN ('todo','doing','done')),
    priority TEXT DEFAULT 'medium' CHECK (priority IN ('high','medium','low')),
    due_date DATE,
    created_at TIMESTAMPTZ DEFAULT NOW()
  );
EXCEPTION WHEN OTHERS THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "task_board_all" ON hr_task_board FOR ALL USING (true);
EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- OKRs
DO $$ BEGIN
  CREATE TABLE IF NOT EXISTS hr_okrs (
    id SERIAL PRIMARY KEY,
    nrp TEXT NOT NULL,
    periode TEXT NOT NULL,
    objective TEXT NOT NULL,
    status TEXT DEFAULT 'on_track' CHECK (status IN ('on_track','at_risk','behind','completed')),
    created_at TIMESTAMPTZ DEFAULT NOW()
  );
EXCEPTION WHEN OTHERS THEN NULL; END $$;

DO $$ BEGIN
  CREATE TABLE IF NOT EXISTS hr_okr_results (
    id SERIAL PRIMARY KEY,
    okr_id INT REFERENCES hr_okrs(id),
    key_result TEXT NOT NULL,
    target_val NUMERIC DEFAULT 100,
    actual_val NUMERIC DEFAULT 0,
    unit TEXT DEFAULT '%',
    created_at TIMESTAMPTZ DEFAULT NOW()
  );
EXCEPTION WHEN OTHERS THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "okrs_all" ON hr_okrs FOR ALL USING (true);
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "okr_results_all" ON hr_okr_results FOR ALL USING (true);
EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- eNPS SURVEY
DO $$ BEGIN
  CREATE TABLE IF NOT EXISTS hr_surveys (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    questions JSONB DEFAULT '[]'::jsonb,
    status TEXT DEFAULT 'active' CHECK (status IN ('active','closed')),
    created_at TIMESTAMPTZ DEFAULT NOW()
  );
EXCEPTION WHEN OTHERS THEN NULL; END $$;

DO $$ BEGIN
  CREATE TABLE IF NOT EXISTS hr_survey_responses (
    id SERIAL PRIMARY KEY,
    survey_id INT REFERENCES hr_surveys(id),
    nrp TEXT NOT NULL,
    answers JSONB DEFAULT '{}'::jsonb,
    score INT,
    created_at TIMESTAMPTZ DEFAULT NOW()
  );
EXCEPTION WHEN OTHERS THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "surveys_all" ON hr_surveys FOR ALL USING (true);
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "survey_responses_all" ON hr_survey_responses FOR ALL USING (true);
EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- SHIFT SWAPS
DO $$ BEGIN
  CREATE TABLE IF NOT EXISTS hr_shift_swaps (
    id SERIAL PRIMARY KEY,
    requester_nrp TEXT NOT NULL,
    target_nrp TEXT,
    request_date DATE NOT NULL,
    target_date DATE,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
    approver_nrp TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
  );
EXCEPTION WHEN OTHERS THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "shift_swaps_all" ON hr_shift_swaps FOR ALL USING (true);
EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- AUDIT CHAIN (tamper-evident)
DO $$ BEGIN
  CREATE TABLE IF NOT EXISTS hr_audit_chain (
    id SERIAL PRIMARY KEY,
    action TEXT NOT NULL,
    actor_nrp TEXT,
    details JSONB,
    prev_hash TEXT,
    chain_hash TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
  );
EXCEPTION WHEN OTHERS THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "audit_chain_all" ON hr_audit_chain FOR ALL USING (true);
EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- ============================================================
-- RPC: TASK BOARD
-- ============================================================
DROP FUNCTION IF EXISTS get_my_tasks(p_nrp TEXT);
CREATE OR REPLACE FUNCTION get_my_tasks(p_nrp TEXT) RETURNS JSONB AS $BODY$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'title',title,'description',description,'status',status,'priority',priority,'due_date',due_date,'assigner_nrp',assigner_nrp)
  ORDER BY CASE priority WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END, due_date ASC),'[]'::jsonb))
FROM hr_task_board WHERE nrp=p_nrp); END;
$BODY$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS update_task_status(p_id INT, p_status TEXT);
CREATE OR REPLACE FUNCTION update_task_status(p_id INT, p_status TEXT) RETURNS JSONB AS $BODY$
BEGIN UPDATE hr_task_board SET status=p_status WHERE id=p_id;
RETURN jsonb_build_object('ok',true,'msg','Task updated'); END;
$BODY$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS create_task(p_nrp TEXT, p_assigner TEXT, p_title TEXT, p_desc TEXT, p_priority TEXT, p_due DATE);
CREATE OR REPLACE FUNCTION create_task(p_nrp TEXT, p_assigner TEXT, p_title TEXT, p_desc TEXT, p_priority TEXT, p_due DATE) RETURNS JSONB AS $BODY$
BEGIN INSERT INTO hr_task_board(nrp,assigner_nrp,title,description,priority,due_date) VALUES(p_nrp,p_assigner,p_title,p_desc,p_priority,p_due);
RETURN jsonb_build_object('ok',true,'msg','Task created'); END;
$BODY$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- RPC: OKRs
-- ============================================================
DROP FUNCTION IF EXISTS get_my_okrs(p_nrp TEXT);
CREATE OR REPLACE FUNCTION get_my_okrs(p_nrp TEXT) RETURNS JSONB AS $BODY$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',o.id,'objective',o.objective,'status',o.status,'periode',o.periode,
    'key_results',(SELECT COALESCE(jsonb_agg(jsonb_build_object('id',r.id,'kr',r.key_result,'target',r.target_val,'actual',r.actual_val,'unit',r.unit,'pct',CASE WHEN r.target_val>0 THEN ROUND(r.actual_val/r.target_val*100,0) ELSE 0 END)),'[]'::jsonb) FROM hr_okr_results r WHERE r.okr_id=o.id)
  ) ORDER BY o.created_at DESC),'[]'::jsonb))
FROM hr_okrs o WHERE o.nrp=p_nrp); END;
$BODY$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS create_okr(p_nrp TEXT, p_periode TEXT, p_objective TEXT);
CREATE OR REPLACE FUNCTION create_okr(p_nrp TEXT, p_periode TEXT, p_objective TEXT) RETURNS JSONB AS $BODY$
DECLARE v_id INT;
BEGIN INSERT INTO hr_okrs(nrp,periode,objective) VALUES(p_nrp,p_periode,p_objective) RETURNING id INTO v_id;
RETURN jsonb_build_object('ok',true,'id',v_id); END;
$BODY$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS add_okr_result(p_okr_id INT, p_kr TEXT, p_target NUMERIC, p_unit TEXT);
CREATE OR REPLACE FUNCTION add_okr_result(p_okr_id INT, p_kr TEXT, p_target NUMERIC, p_unit TEXT) RETURNS JSONB AS $BODY$
BEGIN INSERT INTO hr_okr_results(okr_id,key_result,target_val,unit) VALUES(p_okr_id,p_kr,p_target,p_unit);
RETURN jsonb_build_object('ok',true,'msg','KR added'); END;
$BODY$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- RPC: SURVEYS (eNPS)
-- ============================================================
DROP FUNCTION IF EXISTS get_active_surveys();
CREATE OR REPLACE FUNCTION get_active_surveys() RETURNS JSONB AS $BODY$
BEGIN RETURN jsonb_build_object('ok',true,'data',COALESCE((SELECT jsonb_agg(jsonb_build_object('id',id,'title',title,'questions',questions)) FROM hr_surveys WHERE status='active'),'[]'::jsonb)); END;
$BODY$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS submit_survey(p_survey_id INT, p_nrp TEXT, p_answers JSONB, p_score INT);
CREATE OR REPLACE FUNCTION submit_survey(p_survey_id INT, p_nrp TEXT, p_answers JSONB, p_score INT) RETURNS JSONB AS $BODY$
BEGIN INSERT INTO hr_survey_responses(survey_id,nrp,answers,score) VALUES(p_survey_id,p_nrp,p_answers,p_score);
RETURN jsonb_build_object('ok',true,'msg','Survey submitted'); END;
$BODY$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS get_survey_results(p_survey_id INT);
CREATE OR REPLACE FUNCTION get_survey_results(p_survey_id INT) RETURNS JSONB AS $BODY$
DECLARE v_total INT; v_promoter INT; v_detractor INT; v_enps NUMERIC;
BEGIN
  SELECT COUNT(*),COUNT(*) FILTER(WHERE score>=9),COUNT(*) FILTER(WHERE score<=6) INTO v_total,v_promoter,v_detractor FROM hr_survey_responses WHERE survey_id=p_survey_id;
  v_enps := CASE WHEN v_total>0 THEN ROUND((v_promoter::NUMERIC/v_total - v_detractor::NUMERIC/v_total)*100,0) ELSE 0 END;
  RETURN jsonb_build_object('ok',true,'total',v_total,'promoter',v_promoter,'detractor',v_detractor,'enps',v_enps); END;
$BODY$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- RPC: SHIFT SWAPS
-- ============================================================
DROP FUNCTION IF EXISTS request_shift_swap(p_requester TEXT, p_target TEXT, p_req_date DATE, p_target_date DATE);
CREATE OR REPLACE FUNCTION request_shift_swap(p_requester TEXT, p_target TEXT, p_req_date DATE, p_target_date DATE) RETURNS JSONB AS $BODY$
BEGIN INSERT INTO hr_shift_swaps(requester_nrp,target_nrp,request_date,target_date) VALUES(p_requester,p_target,p_req_date,p_target_date);
RETURN jsonb_build_object('ok',true,'msg','Swap requested'); END;
$BODY$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS get_shift_swaps(p_nrp TEXT);
CREATE OR REPLACE FUNCTION get_shift_swaps(p_nrp TEXT) RETURNS JSONB AS $BODY$
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('id',id,'requester',requester_nrp,'target',target_nrp,'req_date',request_date,'target_date',target_date,'status',status)
  ORDER BY created_at DESC),'[]'::jsonb))
FROM hr_shift_swaps WHERE requester_nrp=p_nrp OR target_nrp=p_nrp); END;
$BODY$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- RPC: ORG HEALTH
-- ============================================================
DROP FUNCTION IF EXISTS get_org_health();
CREATE OR REPLACE FUNCTION get_org_health() RETURNS JSONB AS $BODY$
BEGIN RETURN jsonb_build_object('ok',true,
  'headcount',(SELECT COUNT(*) FROM employees_master),
  'avg_kpi',(SELECT COALESCE(ROUND(AVG(kpi_score),1),0) FROM hr_performance WHERE periode=(SELECT MAX(periode) FROM hr_performance)),
  'turnover_rate',(SELECT COALESCE(ROUND(COUNT(*) FILTER(WHERE status_kerja!='PKWTT')::NUMERIC/NULLIF(COUNT(*),0)*100,1),0) FROM employees_master),
  'engagement_score',(SELECT COALESCE(ROUND(AVG(score),0),0) FROM hr_engagement),
  'compliance_rate',(SELECT COALESCE(ROUND(COUNT(*) FILTER(WHERE status='Compliant')::NUMERIC/NULLIF(COUNT(*),0)*100,1),0) FROM hr_compliance),
  'safety_incidents',(SELECT COUNT(*) FROM hr_safety)); END;
$BODY$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- SEED: Sample OKRs + Tasks + Survey
-- ============================================================
INSERT INTO hr_okrs(nrp,periode,objective,status) VALUES
  ('NRP001','2026-Q3','Tingkatkan Revenue 15% YoY','on_track'),
  ('NRP001','2026-Q3','Implementasi ERP Phase 2','at_risk'),
  ('NRP002','2026-Q3','Optimasi Biaya Operasional 10%','on_track'),
  ('NRP003','2026-Q3','Reducing Turnover Rate di Bawah 5%','behind')
ON CONFLICT DO NOTHING;

INSERT INTO hr_okr_results(okr_id,key_result,target_val,actual_val,unit) VALUES
  (1,'Revenue Q3 vs Q2',115,108,'%'),
  (1,'New Client Acquisition',20,14,'clients'),
  (1,'Customer Retention Rate',95,92,'%'),
  (2,'ERP Module Go-Live',4,2,'modules'),
  (2,'Staff Training Completion',100,65,'%'),
  (3,'OPEX Reduction',10,7,'%'),
  (3,'Energy Cost per Unit',90,85,'%'),
  (4,'Exit Interview Completion',100,40,'%'),
  (4,'Internal Transfer Rate',30,15,'%'),
  (4,'Exit Reason: Better Opportunity',0,35,'%')
ON CONFLICT DO NOTHING;

INSERT INTO hr_task_board(nrp,assigner_nrp,title,description,status,priority,due_date) VALUES
  ('NRP001','NRP001','Review Q3 Financial Report','Analisis laporan keuangan Q3 dan buat rekomendasi','todo','high','2026-09-05'),
  ('NRP001','NRP001','Approve Budget 2027','Review dan approve anggaran tahun depan','todo','high','2026-09-15'),
  ('NRP002','NRP001','Submit OPEX Report','Kirim laporan biaya operasional bulanan','doing','medium','2026-09-01'),
  ('NRP003','NRP001','Training Coordinator','Susun jadwal training Q4','todo','medium','2026-09-10'),
  ('NRP004','NRP001','Monthly KPI Review','Review KPI semua divisi','doing','high','2026-09-03'),
  ('NRP005','NRP001','IT Security Audit','Audit keamanan sistem','todo','low','2026-09-20')
ON CONFLICT DO NOTHING;

INSERT INTO hr_surveys(title,questions,status) VALUES
  ('eNPS Q3 2026','["Bagaimana kemungkinan Anda merekomendasikan perusahaan ini sebagai tempat kerja? (0-10)","Apa alasan utama Anda memberikan skor tersebut?","Apa yang perlu diperbaiki di perusahaan?"]','active')
ON CONFLICT DO NOTHING;

INSERT INTO hr_survey_responses(survey_id,nrp,answers,score) VALUES
  (1,'NRP001','{"q1":"9","q2":"Lingkungan kerja mendukung","q3":"Perlu fleksibilitas remote"}',9),
  (1,'NRP002','{"q1":"7","q2":"Cukup baik tapi ada ruang improvement","q3":"Training lebih sering"}',7),
  (1,'NRP003','{"q1":"8","q2":"Tim solid","q3":"Fasilitas kantor"}',8),
  (1,'NRP004','{"q1":"6","q2":"Workload tinggi","q3":"Work-life balance"}',6),
  (1,'NRP005','{"q1":"9","q2":"Canggih dan modern","q3":"Lebih banyak inovasi"}',9),
  (1,'NRP006','{"q1":"5","q2":"Gaji kurang kompetitif","q3":"Tunjangan lebih baik"}',5),
  (1,'NRP007','{"q1":"8","q2":"Kesempatan berkembang","q3":"Mentoring program"}',8),
  (1,'NRP008','{"q1":"7","q2":"Stabil","q3":"Komunikasi antar divisi"}',7)
ON CONFLICT DO NOTHING;

SELECT '025 OKR+Survey+Tasks+Swaps DONE' as status;
