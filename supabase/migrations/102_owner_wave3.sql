-- ============================================================
-- 102_owner_wave3.sql
-- Owner Dashboard Wave 3 — Activity, Integrations, Branding, Retention, Changelog, Support
-- ============================================================

-- 0. NEW TABLES
CREATE TABLE IF NOT EXISTS integrations (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
  name TEXT NOT NULL,
  type TEXT DEFAULT 'webhook' CHECK (type IN ('webhook','api_key','email','sms')),
  config JSONB DEFAULT '{}'::jsonb,
  status TEXT DEFAULT 'disconnected' CHECK (status IN ('connected','disconnected','error')),
  api_key TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS data_retention_rules (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
  table_name TEXT NOT NULL UNIQUE,
  retention_days INT DEFAULT 90,
  archive_enabled BOOLEAN DEFAULT FALSE,
  last_cleanup TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS system_changelog (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
  version TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  changes JSONB DEFAULT '[]'::JSONB,
  created_by TEXT DEFAULT 'OWNER001',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS support_tickets (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
  creator_nrp TEXT NOT NULL,
  subject TEXT NOT NULL,
  description TEXT,
  priority TEXT DEFAULT 'NORMAL' CHECK (priority IN ('LOW','NORMAL','HIGH','CRITICAL')),
  status TEXT DEFAULT 'OPEN' CHECK (status IN ('OPEN','IN_PROGRESS','RESOLVED','CLOSED')),
  assigned_to TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ticket_comments (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
  ticket_id TEXT NOT NULL REFERENCES support_tickets(id) ON DELETE CASCADE,
  commenter_nrp TEXT NOT NULL,
  comment TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed default retention rules
INSERT INTO data_retention_rules (table_name, retention_days, archive_enabled) VALUES
  ('audit_log_owner', 180, FALSE),
  ('login_attempts', 30, FALSE),
  ('session_tokens', 7, FALSE),
  ('security_audit_log', 90, FALSE)
ON CONFLICT (table_name) DO NOTHING;

-- Seed default changelog
INSERT INTO system_changelog (id, version, title, description) VALUES
  ('CL001', '6.0.0', 'V6 Initial Release', 'Platform launch with Core, Industry, Governance modules')
ON CONFLICT (id) DO NOTHING;

-- RLS
ALTER TABLE integrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE data_retention_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_changelog ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE ticket_comments ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  DROP POLICY IF EXISTS int_owner ON integrations;
  CREATE POLICY int_owner ON integrations FOR ALL USING (TRUE);
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS dr_owner ON data_retention_rules;
  CREATE POLICY dr_owner ON data_retention_rules FOR ALL USING (TRUE);
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS sc_public ON system_changelog;
  CREATE POLICY sc_public ON system_changelog FOR ALL USING (TRUE);
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS st_owner ON support_tickets;
  CREATE POLICY st_owner ON support_tickets FOR ALL USING (TRUE);
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS tc_owner ON ticket_comments;
  CREATE POLICY tc_owner ON ticket_comments FOR ALL USING (TRUE);
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- ============================================================
-- 1. ACTIVITY: owner_get_activity_stats
-- ============================================================
CREATE OR REPLACE FUNCTION owner_get_activity_stats()
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_actions_today INT;
  v_actions_week INT;
  v_top_actions JSONB;
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN '{}'::JSONB;
  END IF;
  SELECT COUNT(*) INTO v_actions_today FROM audit_log_owner WHERE created_at > NOW() - INTERVAL '24 hours';
  SELECT COUNT(*) INTO v_actions_week FROM audit_log_owner WHERE created_at > NOW() - INTERVAL '7 days';
  SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::JSONB) INTO v_top_actions FROM (
    SELECT action, COUNT(*) as count FROM audit_log_owner WHERE created_at > NOW() - INTERVAL '7 days' GROUP BY action ORDER BY count DESC LIMIT 10
  ) t;
  RETURN jsonb_build_object('actions_today', v_actions_today, 'actions_week', v_actions_week, 'top_actions', v_top_actions);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION owner_get_activity_stats() TO authenticated;

-- ============================================================
-- 2. INTEGRATIONS: owner_get_integrations
-- ============================================================
CREATE OR REPLACE FUNCTION owner_get_integrations()
RETURNS JSONB AS $$
DECLARE v_ctx JSONB := get_current_user_context();
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN RETURN '[]'::JSONB; END IF;
  RETURN (SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::JSONB) FROM (SELECT id, name, type, status, created_at, updated_at FROM integrations ORDER BY name) t);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION owner_get_integrations() TO authenticated;

-- 3. INTEGRATIONS: owner_create_integration
CREATE OR REPLACE FUNCTION owner_create_integration(p_name TEXT, p_type TEXT DEFAULT 'webhook', p_config JSONB DEFAULT '{}')
RETURNS JSONB AS $$
DECLARE v_ctx JSONB := get_current_user_context(); v_id TEXT;
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN RETURN jsonb_build_object('ok', FALSE, 'msg', 'Owner only.'); END IF;
  v_id := 'INT' || LPAD((SELECT COALESCE(MAX(SUBSTRING(id FROM 4)::INT), 0) + 1 FROM integrations WHERE id ~ '^INT[0-9]+$')::TEXT, 4, '0');
  INSERT INTO integrations (id, name, type, config) VALUES (v_id, TRIM(p_name), p_type, p_config);
  INSERT INTO audit_log_owner (owner_nrp, action, target_type, target_id, new_value) VALUES ('OWNER001', 'CREATE_INTEGRATION', 'integration', v_id, jsonb_build_object('name', TRIM(p_name), 'type', p_type));
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'Integration created: ' || v_id, 'id', v_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION owner_create_integration(TEXT, TEXT, JSONB) TO authenticated;

-- 4. INTEGRATIONS: owner_delete_integration
CREATE OR REPLACE FUNCTION owner_delete_integration(p_id TEXT)
RETURNS JSONB AS $$
DECLARE v_ctx JSONB := get_current_user_context(); v_old JSONB;
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN RETURN jsonb_build_object('ok', FALSE, 'msg', 'Owner only.'); END IF;
  SELECT row_to_json(i) INTO v_old FROM integrations i WHERE id = p_id;
  IF v_old IS NULL THEN RETURN jsonb_build_object('ok', FALSE, 'msg', 'Not found.'); END IF;
  DELETE FROM integrations WHERE id = p_id;
  INSERT INTO audit_log_owner (owner_nrp, action, target_type, target_id, old_value) VALUES ('OWNER001', 'DELETE_INTEGRATION', 'integration', p_id, v_old);
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'Deleted: ' || p_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION owner_delete_integration(TEXT) TO authenticated;

-- ============================================================
-- 5. DATA RETENTION: owner_get_retention_rules
-- ============================================================
CREATE OR REPLACE FUNCTION owner_get_retention_rules()
RETURNS JSONB AS $$
DECLARE v_ctx JSONB := get_current_user_context();
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN RETURN '[]'::JSONB; END IF;
  RETURN (SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::JSONB) FROM (SELECT id, table_name, retention_days, archive_enabled, last_cleanup FROM data_retention_rules ORDER BY table_name) t);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION owner_get_retention_rules() TO authenticated;

-- 6. DATA RETENTION: owner_update_retention_rule
CREATE OR REPLACE FUNCTION owner_update_retention_rule(p_id TEXT, p_retention_days INT DEFAULT NULL, p_archive_enabled BOOLEAN DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE v_ctx JSONB := get_current_user_context(); v_old JSONB;
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN RETURN jsonb_build_object('ok', FALSE, 'msg', 'Owner only.'); END IF;
  SELECT row_to_json(r) INTO v_old FROM data_retention_rules r WHERE id = p_id;
  IF v_old IS NULL THEN RETURN jsonb_build_object('ok', FALSE, 'msg', 'Not found.'); END IF;
  UPDATE data_retention_rules SET retention_days = COALESCE(p_retention_days, retention_days), archive_enabled = COALESCE(p_archive_enabled, archive_enabled), updated_at = NOW() WHERE id = p_id;
  INSERT INTO audit_log_owner (owner_nrp, action, target_type, target_id, old_value, new_value) VALUES ('OWNER001', 'UPDATE_RETENTION', 'data_retention', p_id, v_old, jsonb_build_object('retention_days', p_retention_days, 'archive_enabled', p_archive_enabled));
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'Updated.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION owner_update_retention_rule(TEXT, INT, BOOLEAN) TO authenticated;

-- ============================================================
-- 7. SYSTEM LOG: owner_get_changelog
-- ============================================================
CREATE OR REPLACE FUNCTION owner_get_changelog()
RETURNS JSONB AS $$
DECLARE v_ctx JSONB := get_current_user_context();
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN RETURN '[]'::JSONB; END IF;
  RETURN (SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::JSONB) FROM (SELECT id, version, title, description, changes, created_by, created_at FROM system_changelog ORDER BY created_at DESC) t);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION owner_get_changelog() TO authenticated;

-- 8. SYSTEM LOG: owner_create_changelog
CREATE OR REPLACE FUNCTION owner_create_changelog(p_version TEXT, p_title TEXT, p_description TEXT DEFAULT NULL, p_changes JSONB DEFAULT '[]')
RETURNS JSONB AS $$
DECLARE v_ctx JSONB := get_current_user_context(); v_id TEXT;
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN RETURN jsonb_build_object('ok', FALSE, 'msg', 'Owner only.'); END IF;
  v_id := 'CL' || LPAD((SELECT COALESCE(MAX(SUBSTRING(id FROM 3)::INT), 0) + 1 FROM system_changelog WHERE id ~ '^CL[0-9]+$')::TEXT, 4, '0');
  INSERT INTO system_changelog (id, version, title, description, changes) VALUES (v_id, p_version, TRIM(p_title), p_description, p_changes);
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'Changelog created: ' || v_id, 'id', v_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION owner_create_changelog(TEXT, TEXT, TEXT, JSONB) TO authenticated;

-- ============================================================
-- 9. SUPPORT: owner_get_tickets
-- ============================================================
CREATE OR REPLACE FUNCTION owner_get_tickets()
RETURNS JSONB AS $$
DECLARE v_ctx JSONB := get_current_user_context();
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN RETURN '[]'::JSONB; END IF;
  RETURN (SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::JSONB) FROM (SELECT st.*, em.nama as creator_nama FROM support_tickets st LEFT JOIN employees_master em ON em.nrp = st.creator_nrp ORDER BY st.created_at DESC) t);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION owner_get_tickets() TO authenticated;

-- 10. SUPPORT: owner_update_ticket_status
CREATE OR REPLACE FUNCTION owner_update_ticket_status(p_ticket_id TEXT, p_status TEXT, p_assigned_to TEXT DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE v_ctx JSONB := get_current_user_context();
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN RETURN jsonb_build_object('ok', FALSE, 'msg', 'Owner only.'); END IF;
  UPDATE support_tickets SET status = p_status, assigned_to = COALESCE(p_assigned_to, assigned_to), updated_at = NOW() WHERE id = p_ticket_id;
  INSERT INTO audit_log_owner (owner_nrp, action, target_type, target_id, new_value) VALUES ('OWNER001', 'UPDATE_TICKET', 'ticket', p_ticket_id, jsonb_build_object('status', p_status, 'assigned_to', p_assigned_to));
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'Ticket updated.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION owner_update_ticket_status(TEXT, TEXT, TEXT) TO authenticated;

-- ============================================================
-- 11. ANALYTICS: owner_get_usage_analytics
-- ============================================================
CREATE OR REPLACE FUNCTION owner_get_usage_analytics()
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_daily_actions JSONB;
  v_action_distribution JSONB;
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN RETURN '{}'::JSONB; END IF;
  SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::JSONB) INTO v_daily_actions FROM (
    SELECT DATE(created_at) as date, COUNT(*) as count FROM audit_log_owner WHERE created_at > NOW() - INTERVAL '30 days' GROUP BY DATE(created_at) ORDER BY date
  ) t;
  SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::JSONB) INTO v_action_distribution FROM (
    SELECT action, COUNT(*) as count FROM audit_log_owner WHERE created_at > NOW() - INTERVAL '30 days' GROUP BY action ORDER BY count DESC
  ) t;
  RETURN jsonb_build_object('daily_actions', v_daily_actions, 'action_distribution', v_action_distribution);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION owner_get_usage_analytics() TO authenticated;

CREATE INDEX IF NOT EXISTS idx_integrations_status ON integrations(status);
CREATE INDEX IF NOT EXISTS idx_support_tickets_status ON support_tickets(status);
CREATE INDEX IF NOT EXISTS idx_ticket_comments_ticket ON ticket_comments(ticket_id);
CREATE INDEX IF NOT EXISTS idx_system_changelog_version ON system_changelog(version);
