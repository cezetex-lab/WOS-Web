-- Migration 138: Admin RBAC helper + RLS on missing tables + audit protection

-- Helper: check admin permission with owner bypass
DROP FUNCTION IF EXISTS authz_check_admin(TEXT);
CREATE OR REPLACE FUNCTION authz_check_admin(p_permission TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = TRUE) THEN
    RETURN TRUE;
  END IF;
  RETURN authz_has_permission(p_permission);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;
GRANT EXECUTE ON FUNCTION authz_check_admin(TEXT) TO authenticated;

-- Enable RLS on 5 tables without it
DO $$ BEGIN IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'hr_audit_chain' AND table_schema = 'public') THEN
  ALTER TABLE hr_audit_chain ENABLE ROW LEVEL SECURITY;
  ALTER TABLE hr_audit_chain FORCE ROW LEVEL SECURITY;
  DROP POLICY IF EXISTS "hr_audit_c_auth" ON hr_audit_chain;
  CREATE POLICY "hr_audit_c_auth" ON hr_audit_chain FOR ALL USING (auth.uid() IS NOT NULL);
END IF; END $$;

DO $$ BEGIN IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'hr_okr_results' AND table_schema = 'public') THEN
  ALTER TABLE hr_okr_results ENABLE ROW LEVEL SECURITY;
  ALTER TABLE hr_okr_results FORCE ROW LEVEL SECURITY;
  DROP POLICY IF EXISTS "hr_okr_res_auth" ON hr_okr_results;
  CREATE POLICY "hr_okr_res_auth" ON hr_okr_results FOR ALL USING (auth.uid() IS NOT NULL);
END IF; END $$;

DO $$ BEGIN IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'hr_shift_swaps' AND table_schema = 'public') THEN
  ALTER TABLE hr_shift_swaps ENABLE ROW LEVEL SECURITY;
  ALTER TABLE hr_shift_swaps FORCE ROW LEVEL SECURITY;
  DROP POLICY IF EXISTS "hr_shift_s_auth" ON hr_shift_swaps;
  CREATE POLICY "hr_shift_s_auth" ON hr_shift_swaps FOR ALL USING (auth.uid() IS NOT NULL);
END IF; END $$;

DO $$ BEGIN IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'hr_survey_responses' AND table_schema = 'public') THEN
  ALTER TABLE hr_survey_responses ENABLE ROW LEVEL SECURITY;
  ALTER TABLE hr_survey_responses FORCE ROW LEVEL SECURITY;
  DROP POLICY IF EXISTS "hr_survey__auth" ON hr_survey_responses;
  CREATE POLICY "hr_survey__auth" ON hr_survey_responses FOR ALL USING (auth.uid() IS NOT NULL);
END IF; END $$;

DO $$ BEGIN IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'hr_task_board' AND table_schema = 'public') THEN
  ALTER TABLE hr_task_board ENABLE ROW LEVEL SECURITY;
  ALTER TABLE hr_task_board FORCE ROW LEVEL SECURITY;
  DROP POLICY IF EXISTS "hr_task_bo_auth" ON hr_task_board;
  CREATE POLICY "hr_task_bo_auth" ON hr_task_board FOR ALL USING (auth.uid() IS NOT NULL);
END IF; END $$;

-- Protect audit tables from UPDATE/DELETE
DO $$ BEGIN
  DROP POLICY IF EXISTS "audit_log_immutable" ON audit_log;
  CREATE POLICY "audit_log_immutable" ON audit_log FOR UPDATE USING (FALSE);
  DROP POLICY IF EXISTS "audit_log_nodelete" ON audit_log;
  CREATE POLICY "audit_log_nodelete" ON audit_log FOR DELETE USING (FALSE);
  DROP POLICY IF EXISTS "alo_immutable" ON audit_log_owner;
  CREATE POLICY "alo_immutable" ON audit_log_owner FOR UPDATE USING (FALSE);
  DROP POLICY IF EXISTS "alo_nodelete" ON audit_log_owner;
  CREATE POLICY "alo_nodelete" ON audit_log_owner FOR DELETE USING (FALSE);
END $$;
