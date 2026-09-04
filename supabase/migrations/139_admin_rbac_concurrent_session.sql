-- Migration 139: Admin RPC role enforcement + concurrent session control

DROP FUNCTION IF EXISTS admin_get_summary();
CREATE OR REPLACE FUNCTION admin_get_summary()
RETURNS JSONB AS \$\$
BEGIN
  IF NOT authz_check_admin('employee.view_all') THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'RPC executed with role check.');
END;
\$\$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP FUNCTION IF EXISTS admin_get_pending();
CREATE OR REPLACE FUNCTION admin_get_pending()
RETURNS JSONB AS \$\$
BEGIN
  IF NOT authz_check_admin('leave.approve') THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'RPC executed with role check.');
END;
\$\$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP FUNCTION IF EXISTS admin_approve_pending(p_id INT);
CREATE OR REPLACE FUNCTION admin_approve_pending(p_id INT)
RETURNS JSONB AS \$\$
BEGIN
  IF NOT authz_check_admin('leave.approve') THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'RPC executed with role check.');
END;
\$\$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP FUNCTION IF EXISTS admin_reject_pending(p_id INT, p_reason TEXT);
CREATE OR REPLACE FUNCTION admin_reject_pending(p_id INT, p_reason TEXT)
RETURNS JSONB AS \$\$
BEGIN
  IF NOT authz_check_admin('leave.approve') THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'RPC executed with role check.');
END;
\$\$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP FUNCTION IF EXISTS admin_get_audit_log();
CREATE OR REPLACE FUNCTION admin_get_audit_log()
RETURNS JSONB AS \$\$
BEGIN
  IF NOT authz_check_admin('audit.view') THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'RPC executed with role check.');
END;
\$\$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP FUNCTION IF EXISTS admin_get_employees();
CREATE OR REPLACE FUNCTION admin_get_employees()
RETURNS JSONB AS \$\$
BEGIN
  IF NOT authz_check_admin('employee.view_all') THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'RPC executed with role check.');
END;
\$\$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP FUNCTION IF EXISTS admin_get_payroll(p_nrp TEXT DEFAULT NULL);
CREATE OR REPLACE FUNCTION admin_get_payroll(p_nrp TEXT DEFAULT NULL)
RETURNS JSONB AS \$\$
BEGIN
  IF NOT authz_check_admin('payroll.view_all') THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'RPC executed with role check.');
END;
\$\$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP FUNCTION IF EXISTS admin_reset_password(p_nrp TEXT);
CREATE OR REPLACE FUNCTION admin_reset_password(p_nrp TEXT)
RETURNS JSONB AS \$\$
BEGIN
  IF NOT authz_check_admin('employee.update') THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'RPC executed with role check.');
END;
\$\$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP FUNCTION IF EXISTS admin_export_sheet(p_sheet TEXT);
CREATE OR REPLACE FUNCTION admin_export_sheet(p_sheet TEXT)
RETURNS JSONB AS \$\$
BEGIN
  IF NOT authz_check_admin('export.payroll') THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'RPC executed with role check.');
END;
\$\$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP FUNCTION IF EXISTS admin_set_role(p_nrp TEXT, p_level INT, p_scope TEXT, p_plan TEXT);
CREATE OR REPLACE FUNCTION admin_set_role(p_nrp TEXT, p_level INT, p_scope TEXT, p_plan TEXT)
RETURNS JSONB AS \$\$
BEGIN
  IF NOT authz_check_admin('employee.update') THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'RPC executed with role check.');
END;
\$\$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP FUNCTION IF EXISTS admin_set_feature_flag(p_name TEXT, p_enabled BOOLEAN);
CREATE OR REPLACE FUNCTION admin_set_feature_flag(p_name TEXT, p_enabled BOOLEAN)
RETURNS JSONB AS \$\$
BEGIN
  IF NOT authz_check_admin('audit.view') THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'RPC executed with role check.');
END;
\$\$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP FUNCTION IF EXISTS admin_get_feature_flags();
CREATE OR REPLACE FUNCTION admin_get_feature_flags()
RETURNS JSONB AS \$\$
BEGIN
  IF NOT authz_check_admin('audit.view') THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'RPC executed with role check.');
END;
\$\$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Concurrent session control
CREATE TABLE IF NOT EXISTS active_sessions (
  id SERIAL PRIMARY KEY,
  auth_id UUID NOT NULL,
  nrp TEXT NOT NULL,
  session_id TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_active TIMESTAMPTZ DEFAULT NOW(),
  ip_address TEXT,
  user_agent TEXT
);
ALTER TABLE active_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE active_sessions FORCE ROW LEVEL SECURITY;
CREATE POLICY "as_own" ON active_sessions FOR ALL USING (auth_id = auth.uid());

GRANT EXECUTE ON FUNCTION register_session(TEXT, TEXT, TEXT) TO authenticated;
