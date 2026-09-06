-- Pilar 2: Self-Service Total (4 tables + 14 RPCs)

-- NEW TABLES

CREATE TABLE IF NOT EXISTS letter_requests (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
  nrp TEXT NOT NULL, letter_type TEXT NOT NULL,
  purpose TEXT, notes TEXT, status TEXT DEFAULT 'PENDING',
  file_url TEXT, created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE letter_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS lr_own ON letter_requests;
CREATE POLICY lr_own ON letter_requests FOR ALL USING (nrp = authz_current_nrp() OR authz_check_admin('employee.view_all'));

CREATE TABLE IF NOT EXISTS resignation_requests (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
  nrp TEXT NOT NULL, resign_date DATE NOT NULL, last_work_date DATE NOT NULL,
  reason TEXT NOT NULL, notes TEXT, status TEXT DEFAULT 'PENDING',
  approved_by TEXT, created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE resignation_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rr_own ON resignation_requests;
CREATE POLICY rr_own ON resignation_requests FOR ALL USING (nrp = authz_current_nrp() OR authz_check_admin('employee.view_all'));

CREATE TABLE IF NOT EXISTS employee_documents (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
  nrp TEXT NOT NULL, doc_type TEXT NOT NULL, doc_name TEXT NOT NULL,
  file_url TEXT NOT NULL, file_size INT, mime_type TEXT,
  status TEXT DEFAULT 'ACTIVE', created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE employee_documents ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ed_own ON employee_documents;
CREATE POLICY ed_own ON employee_documents FOR ALL USING (nrp = authz_current_nrp() OR authz_check_admin('employee.view_all'));

CREATE TABLE IF NOT EXISTS peer_recognitions (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
  from_nrp TEXT NOT NULL, to_nrp TEXT NOT NULL, message TEXT NOT NULL,
  badge_code TEXT, created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE peer_recognitions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pr_own ON peer_recognitions;
CREATE POLICY pr_own ON peer_recognitions FOR SELECT USING (to_nrp = authz_current_nrp() OR from_nrp = authz_current_nrp() OR authz_check_admin('employee.view_all'));

-- RPCs: Reimbursement
CREATE OR REPLACE FUNCTION submit_reimbursement(p_nrp TEXT, p_category TEXT, p_amount NUMERIC, p_description TEXT DEFAULT NULL, p_receipt_url TEXT DEFAULT NULL) RETURNS JSONB AS $$ DECLARE v_caller TEXT; v_id TEXT; BEGIN v_caller := authz_current_nrp(); IF v_caller IS NULL OR (p_nrp != v_caller AND NOT authz_check_admin('employee.view_all')) THEN RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak'); END IF; v_id := 'REIM-' || encode(gen_random_bytes(4), 'hex'); INSERT INTO reimbursements (id, nrp, category, amount, description, receipt_url, status) VALUES (v_id, p_nrp, p_category, p_amount, p_description, p_receipt_url, 'PENDING'); INSERT INTO audit_log (action, detail, timestamp) VALUES ('SUBMIT_REIMBURSEMENT', jsonb_build_object('id',v_id,'nrp',p_nrp,'amount',p_amount)::text, NOW()); RETURN jsonb_build_object('ok', true, 'id', v_id); END; $$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION get_my_reimbursements(p_nrp TEXT) RETURNS JSONB AS $$ DECLARE v_caller TEXT; BEGIN v_caller := authz_current_nrp(); IF v_caller IS NULL OR (p_nrp != v_caller AND NOT authz_check_admin('employee.view_all')) THEN RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak'); END IF; RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(row_to_json(t)),'[]'::jsonb)) FROM (SELECT * FROM reimbursements WHERE nrp=p_nrp ORDER BY created_at DESC LIMIT 50) t); END; $$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- RPCs: Travel
CREATE OR REPLACE FUNCTION submit_travel_request(p_nrp TEXT, p_destination TEXT, p_purpose TEXT, p_start_date DATE, p_end_date DATE, p_estimated_cost NUMERIC DEFAULT 0) RETURNS JSONB AS $$ DECLARE v_caller TEXT; v_id TEXT; BEGIN v_caller := authz_current_nrp(); IF v_caller IS NULL OR (p_nrp != v_caller AND NOT authz_check_admin('employee.view_all')) THEN RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak'); END IF; v_id := 'TRV-' || encode(gen_random_bytes(4), 'hex'); INSERT INTO travel_requests (id, nrp, destination, purpose, start_date, end_date, estimated_cost, status) VALUES (v_id, p_nrp, p_destination, p_purpose, p_start_date, p_end_date, p_estimated_cost, 'PENDING'); INSERT INTO audit_log (action, detail, timestamp) VALUES ('SUBMIT_TRAVEL', jsonb_build_object('id',v_id,'nrp',p_nrp)::text, NOW()); RETURN jsonb_build_object('ok', true, 'id', v_id); END; $$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION get_my_travels(p_nrp TEXT) RETURNS JSONB AS $$ DECLARE v_caller TEXT; BEGIN v_caller := authz_current_nrp(); IF v_caller IS NULL OR (p_nrp != v_caller AND NOT authz_check_admin('employee.view_all')) THEN RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak'); END IF; RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(row_to_json(t)),'[]'::jsonb)) FROM (SELECT * FROM travel_requests WHERE nrp=p_nrp ORDER BY created_at DESC LIMIT 50) t); END; $$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- RPCs: Letters
CREATE OR REPLACE FUNCTION request_letter(p_nrp TEXT, p_type TEXT, p_purpose TEXT, p_notes TEXT DEFAULT NULL) RETURNS JSONB AS $$ DECLARE v_caller TEXT; v_id TEXT; BEGIN v_caller := authz_current_nrp(); IF v_caller IS NULL OR (p_nrp != v_caller AND NOT authz_check_admin('employee.view_all')) THEN RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak'); END IF; v_id := gen_random_uuid()::TEXT; INSERT INTO letter_requests (id, nrp, letter_type, purpose, notes) VALUES (v_id, p_nrp, p_type, p_purpose, p_notes); INSERT INTO audit_log (action, detail, timestamp) VALUES ('REQUEST_LETTER', jsonb_build_object('id',v_id,'nrp',p_nrp,'type',p_type)::text, NOW()); RETURN jsonb_build_object('ok', true, 'id', v_id); END; $$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION get_my_letters(p_nrp TEXT) RETURNS JSONB AS $$ DECLARE v_caller TEXT; BEGIN v_caller := authz_current_nrp(); IF v_caller IS NULL OR (p_nrp != v_caller AND NOT authz_check_admin('employee.view_all')) THEN RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak'); END IF; RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(row_to_json(t)),'[]'::jsonb)) FROM (SELECT * FROM letter_requests WHERE nrp=p_nrp ORDER BY created_at DESC) t); END; $$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- RPCs: Resignation + Exit Interview
CREATE OR REPLACE FUNCTION submit_resignation(p_nrp TEXT, p_resign_date DATE, p_last_work_date DATE, p_reason TEXT, p_notes TEXT DEFAULT NULL) RETURNS JSONB AS $$ DECLARE v_caller TEXT; v_id TEXT; BEGIN v_caller := authz_current_nrp(); IF v_caller IS NULL OR (p_nrp != v_caller AND NOT authz_check_admin('employee.view_all')) THEN RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak'); END IF; v_id := gen_random_uuid()::TEXT; INSERT INTO resignation_requests (id, nrp, resign_date, last_work_date, reason, notes) VALUES (v_id, p_nrp, p_resign_date, p_last_work_date, p_reason, p_notes); INSERT INTO audit_log (action, detail, timestamp) VALUES ('SUBMIT_RESIGNATION', jsonb_build_object('id',v_id,'nrp',p_nrp)::text, NOW()); RETURN jsonb_build_object('ok', true, 'id', v_id); END; $$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION submit_exit_interview(p_nrp TEXT, p_score INT, p_reason TEXT, p_feedback TEXT) RETURNS JSONB AS $$ DECLARE v_caller TEXT; v_id TEXT; BEGIN v_caller := authz_current_nrp(); IF v_caller IS NULL OR (p_nrp != v_caller AND NOT authz_check_admin('employee.view_all')) THEN RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak'); END IF; v_id := gen_random_uuid()::TEXT; INSERT INTO exit_interviews (id, nrp, satisfaction_score, reason, feedback) VALUES (v_id, p_nrp, p_score, p_reason, p_feedback); INSERT INTO audit_log (action, detail, timestamp) VALUES ('EXIT_INTERVIEW', jsonb_build_object('nrp',p_nrp,'score',p_score)::text, NOW()); RETURN jsonb_build_object('ok', true, 'msg', 'Exit interview submitted'); END; $$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- RPCs: Documents
CREATE OR REPLACE FUNCTION upload_document(p_nrp TEXT, p_doc_type TEXT, p_doc_name TEXT, p_file_url TEXT) RETURNS JSONB AS $$ DECLARE v_caller TEXT; v_id TEXT; BEGIN v_caller := authz_current_nrp(); IF v_caller IS NULL OR (p_nrp != v_caller AND NOT authz_check_admin('employee.view_all')) THEN RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak'); END IF; v_id := gen_random_uuid()::TEXT; INSERT INTO employee_documents (id, nrp, doc_type, doc_name, file_url) VALUES (v_id, p_nrp, p_doc_type, p_doc_name, p_file_url); INSERT INTO audit_log (action, detail, timestamp) VALUES ('UPLOAD_DOCUMENT', jsonb_build_object('id',v_id,'nrp',p_nrp,'type',p_doc_type)::text, NOW()); RETURN jsonb_build_object('ok', true, 'id', v_id); END; $$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION get_my_documents(p_nrp TEXT) RETURNS JSONB AS $$ DECLARE v_caller TEXT; BEGIN v_caller := authz_current_nrp(); IF v_caller IS NULL OR (p_nrp != v_caller AND NOT authz_check_admin('employee.view_all')) THEN RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak'); END IF; RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(row_to_json(t)),'[]'::jsonb)) FROM (SELECT * FROM employee_documents WHERE nrp=p_nrp ORDER BY created_at DESC) t); END; $$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- RPCs: Onboarding + Recognition
CREATE OR REPLACE FUNCTION complete_onboarding_task(p_task_id INT) RETURNS JSONB AS $$ DECLARE v_caller TEXT; BEGIN v_caller := authz_current_nrp(); IF v_caller IS NULL THEN RETURN jsonb_build_object('ok', false, 'msg', 'Unauthorized'); END IF; UPDATE onboarding_tasks SET status='COMPLETED', completed_at=NOW() WHERE id=p_task_id AND nrp=v_caller; RETURN jsonb_build_object('ok', true, 'msg', 'Task completed'); END; $$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION send_recognition(p_to_nrp TEXT, p_message TEXT, p_badge TEXT DEFAULT NULL) RETURNS JSONB AS $$ DECLARE v_caller TEXT; v_id TEXT; BEGIN v_caller := authz_current_nrp(); IF v_caller IS NULL THEN RETURN jsonb_build_object('ok', false, 'msg', 'Unauthorized'); END IF; v_id := gen_random_uuid()::TEXT; INSERT INTO peer_recognitions (id, from_nrp, to_nrp, message, badge_code) VALUES (v_id, v_caller, p_to_nrp, p_message, p_badge); INSERT INTO audit_log (action, detail, timestamp) VALUES ('SEND_RECOGNITION', jsonb_build_object('from',v_caller,'to',p_to_nrp)::text, NOW()); RETURN jsonb_build_object('ok', true, 'msg', 'Recognition sent'); END; $$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- RPCs: Payslip + Tax Form
CREATE OR REPLACE FUNCTION download_payslip(p_nrp TEXT, p_periode TEXT) RETURNS JSONB AS $$ DECLARE v_caller TEXT; v_pay RECORD; BEGIN v_caller := authz_current_nrp(); IF v_caller IS NULL OR (p_nrp != v_caller AND NOT authz_check_admin('employee.view_all')) THEN RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak'); END IF; SELECT * INTO v_pay FROM hr_payroll WHERE nrp=p_nrp AND periode=p_periode; IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'msg', 'Payroll tidak ditemukan'); END IF; RETURN jsonb_build_object('ok', true, 'nrp', v_pay.nrp, 'periode', v_pay.periode, 'base_salary', v_pay.base_salary, 'allowance', v_pay.allowance, 'overtime_pay', v_pay.overtime_pay, 'deduction', v_pay.deduction, 'net_salary', v_pay.net_salary); END; $$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION download_tax_form(p_nrp TEXT, p_year INT) RETURNS JSONB AS $$ DECLARE v_caller TEXT; v_total NUMERIC; BEGIN v_caller := authz_current_nrp(); IF v_caller IS NULL OR (p_nrp != v_caller AND NOT authz_check_admin('employee.view_all')) THEN RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak'); END IF; SELECT COALESCE(SUM(net_salary),0) INTO v_total FROM hr_payroll WHERE nrp=p_nrp AND periode LIKE p_year || '-%'; RETURN jsonb_build_object('ok', true, 'nrp', p_nrp, 'year', p_year, 'total_income', v_total, 'form_type', '1721-A1'); END; $$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- GRANTs
GRANT EXECUTE ON FUNCTION submit_reimbursement(TEXT,TEXT,NUMERIC,TEXT,TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_my_reimbursements(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION submit_travel_request(TEXT,TEXT,TEXT,DATE,DATE,NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION get_my_travels(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION request_letter(TEXT,TEXT,TEXT,TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_my_letters(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION submit_resignation(TEXT,DATE,DATE,TEXT,TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION submit_exit_interview(TEXT,INT,TEXT,TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION upload_document(TEXT,TEXT,TEXT,TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_my_documents(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION complete_onboarding_task(INT) TO authenticated;
GRANT EXECUTE ON FUNCTION send_recognition(TEXT,TEXT,TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION download_payslip(TEXT,TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION download_tax_form(TEXT,INT) TO authenticated;
