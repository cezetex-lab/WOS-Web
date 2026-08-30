-- ============================================================
-- 040: Wave 4 — Self-Service & Approval
-- 1. Dynamic Approval Workflow (#29)
-- 2. Multi-step Request (#28)
-- 3. Task Board (#71)
-- 4. Shift Management (#74)
-- ============================================================

-- ──────────────────────────────────────────────────────────
-- 1. GET APPROVAL CONFIG — who approves what
-- ──────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS get_approval_config(p_type TEXT) CASCADE;
CREATE OR REPLACE FUNCTION get_approval_config(p_type TEXT DEFAULT NULL)
RETURNS JSONB AS $$
  SELECT COALESCE(jsonb_agg(sub.*), '[]'::jsonb)
  FROM (
    SELECT request_type, min_days, required_approvers, required_level
    FROM approval_config
    WHERE (p_type IS NULL OR request_type = p_type)
    ORDER BY request_type
  ) sub;
$$ LANGUAGE sql SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────
-- 2. SUBMIT REQUEST — with auto-approval routing
-- ──────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS submit_request(p_nrp TEXT, p_type TEXT, p_details TEXT) CASCADE;
CREATE OR REPLACE FUNCTION submit_request(p_nrp TEXT, p_type TEXT, p_details TEXT)
RETURNS JSONB AS $$
DECLARE
  v_config RECORD;
  v_approver TEXT;
  v_request_id TEXT;
BEGIN
  -- Get approval config
  SELECT * INTO v_config FROM approval_config WHERE request_type = p_type LIMIT 1;
  
  -- Find approver (atasan from hr_org)
  SELECT atasan_nrp INTO v_approver FROM hr_org WHERE nrp = p_nrp;
  
  -- Generate request ID
  v_request_id := 'REQ-' || LPAD(nextval('hr_requests_id_seq')::text, 6, '0');
  
  -- Insert request
  INSERT INTO hr_requests (id, nrp, type, status, details_json, approver_nrp)
  VALUES (v_request_id, p_nrp, p_type, 'Pending', p_details, v_approver);
  
  RETURN jsonb_build_object(
    'ok', true,
    'request_id', v_request_id,
    'approver', v_approver,
    'msg', 'Request ' || p_type || ' berhasil diajukan. Menunggu approval dari ' || COALESCE(v_approver, 'System')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────
-- 3. APPROVE / REJECT REQUEST
-- ──────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS process_request(p_request_id TEXT, p_action TEXT, p_approver TEXT, p_note TEXT) CASCADE;
CREATE OR REPLACE FUNCTION process_request(p_request_id TEXT, p_action TEXT, p_approver TEXT, p_note TEXT DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
  v_request RECORD;
  v_new_status TEXT;
BEGIN
  SELECT * INTO v_request FROM hr_requests WHERE id = p_request_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Request tidak ditemukan');
  END IF;
  
  IF p_action = 'approve' THEN
    v_new_status := 'Approved';
  ELSIF p_action = 'reject' THEN
    v_new_status := 'Rejected';
  ELSE
    RETURN jsonb_build_object('ok', false, 'msg', 'Action harus approve atau reject');
  END IF;
  
  UPDATE hr_requests SET status = v_new_status, note = p_note WHERE id = p_request_id;
  
  INSERT INTO audit_log (actor, action, detail)
  VALUES (p_approver, 'REQUEST_' || UPPER(v_new_status), p_request_id || ' - ' || v_new_status);
  
  RETURN jsonb_build_object('ok', true, 'msg', 'Request ' || v_new_status);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────
-- 4. GET MY REQUESTS — worker's own requests
-- ──────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS get_my_requests(p_nrp TEXT) CASCADE;
CREATE OR REPLACE FUNCTION get_my_requests(p_nrp TEXT)
RETURNS JSONB AS $$
  SELECT COALESCE(jsonb_agg(sub.* ORDER BY sub.created_at DESC), '[]'::jsonb)
  FROM (
    SELECT id, nrp, type, status, details_json, approver_nrp, note, created_at
    FROM hr_requests
    WHERE nrp = p_nrp
    ORDER BY created_at DESC
    LIMIT 50
  ) sub;
$$ LANGUAGE sql SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────
-- 5. GET PENDING APPROVALS — manager's pending approvals
-- ──────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS get_pending_approvals(p_approver_nrp TEXT) CASCADE;
CREATE OR REPLACE FUNCTION get_pending_approvals(p_approver_nrp TEXT)
RETURNS JSONB AS $$
  SELECT COALESCE(jsonb_agg(sub.* ORDER BY sub.created_at DESC), '[]'::jsonb)
  FROM (
    SELECT r.id, r.nrp, e.nama, r.type, r.status, r.details_json, r.created_at,
           r.approver_nrp
    FROM hr_requests r
    JOIN employees_master e ON e.nrp = r.nrp
    WHERE r.approver_nrp = p_approver_nrp AND r.status = 'Pending'
    ORDER BY r.created_at DESC
  ) sub;
$$ LANGUAGE sql SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────
-- 6. TASK BOARD — get tasks grouped by status
-- ──────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS get_task_board(p_nrp TEXT) CASCADE;
CREATE OR REPLACE FUNCTION get_task_board(p_nrp TEXT DEFAULT NULL)
RETURNS JSONB AS $$
  SELECT jsonb_build_object(
    'todo', COALESCE((SELECT jsonb_agg(jsonb_build_object('id', id, 'title', title, 'assignee', assignee_nrp, 'due', due_date))
      FROM hr_tasks WHERE (p_nrp IS NULL OR assignee_nrp = p_nrp) AND status = 'TODO' ORDER BY due_date), '[]'::jsonb),
    'doing', COALESCE((SELECT jsonb_agg(jsonb_build_object('id', id, 'title', title, 'assignee', assignee_nrp, 'due', due_date))
      FROM hr_tasks WHERE (p_nrp IS NULL OR assignee_nrp = p_nrp) AND status = 'DOING' ORDER BY due_date), '[]'::jsonb),
    'done', COALESCE((SELECT jsonb_agg(jsonb_build_object('id', id, 'title', title, 'assignee', assignee_nrp, 'due', due_date))
      FROM hr_tasks WHERE (p_nrp IS NULL OR assignee_nrp = p_nrp) AND status = 'DONE' ORDER BY due_date), '[]'::jsonb)
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────
-- 7. CREATE TASK
-- ──────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS create_task(p_assignee TEXT, p_title TEXT, p_due DATE) CASCADE;
CREATE OR REPLACE FUNCTION create_task(p_assignee TEXT, p_title TEXT, p_due DATE DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE v_id TEXT;
BEGIN
  v_id := encode(gen_random_bytes(8), 'hex');
  INSERT INTO hr_tasks (id, assignee_nrp, title, status, due_date)
  VALUES (v_id, p_assignee, p_title, 'TODO', p_due);
  RETURN jsonb_build_object('ok', true, 'task_id', v_id, 'msg', 'Task created');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────
-- 8. UPDATE TASK STATUS
-- ──────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS update_task_status(p_task_id TEXT, p_status TEXT) CASCADE;
CREATE OR REPLACE FUNCTION update_task_status(p_task_id TEXT, p_status TEXT)
RETURNS JSONB AS $$
BEGIN
  UPDATE hr_tasks SET status = p_status WHERE id = p_task_id;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'msg', 'Task updated to ' || p_status);
  ELSE
    RETURN jsonb_build_object('ok', false, 'msg', 'Task not found');
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────
-- 9. SHIFT SCHEDULE — get all shifts
-- ──────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS get_shift_schedule() CASCADE;
CREATE OR REPLACE FUNCTION get_shift_schedule()
RETURNS JSONB AS $$
  SELECT COALESCE(jsonb_agg(sub.*), '[]'::jsonb)
  FROM (
    SELECT shift_code, shift_name, start_time, end_time, grace_minutes
    FROM hr_shift_master
    ORDER BY start_time
  ) sub;
$$ LANGUAGE sql SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────
-- 10. GET WORKER REQUESTS — all requests with worker info
-- ──────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS get_worker_requests() CASCADE;
CREATE OR REPLACE FUNCTION get_worker_requests()
RETURNS JSONB AS $$
  SELECT COALESCE(jsonb_agg(sub.* ORDER BY sub.created_at DESC), '[]'::jsonb)
  FROM (
    SELECT r.id, r.nrp, e.nama, e.divisi, r.type, r.status, r.details_json, r.created_at
    FROM hr_requests r
    JOIN employees_master e ON e.nrp = r.nrp
    ORDER BY r.created_at DESC
    LIMIT 100
  ) sub;
$$ LANGUAGE sql SECURITY DEFINER;

-- ============================================================
SELECT '040_wave4_self_service.sql applied' as status;
