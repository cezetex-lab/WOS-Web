-- Pilar 3: Platform Terbuka (3 tables + trigger_webhook + 3 RPCs)

-- TABLES
CREATE TABLE IF NOT EXISTS webhook_subscriptions (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
  business_id TEXT NOT NULL, event_type TEXT NOT NULL,
  target_url TEXT NOT NULL, secret_key TEXT,
  is_active BOOLEAN DEFAULT true, created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE webhook_subscriptions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ws_admin ON webhook_subscriptions;
CREATE POLICY ws_admin ON webhook_subscriptions FOR ALL USING (authz_check_admin('employee.view_all'));

CREATE TABLE IF NOT EXISTS webhook_deliveries (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
  subscription_id TEXT, event_type TEXT, payload JSONB,
  http_status INT, response_body TEXT, attempt INT DEFAULT 1,
  delivered_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE webhook_deliveries ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS wd_admin ON webhook_deliveries;
CREATE POLICY wd_admin ON webhook_deliveries FOR ALL USING (authz_check_admin('employee.view_all'));

CREATE TABLE IF NOT EXISTS integration_marketplace (
  id TEXT PRIMARY KEY, name TEXT NOT NULL, category TEXT,
  logo_url TEXT, description TEXT, config_schema JSONB,
  is_active BOOLEAN DEFAULT true
);
ALTER TABLE integration_marketplace ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS imp_admin ON integration_marketplace;
CREATE POLICY imp_admin ON integration_marketplace FOR ALL USING (authz_check_admin('employee.view_all'));

-- FUNCTIONS
CREATE OR REPLACE FUNCTION trigger_webhook(p_event TEXT, p_payload JSONB) RETURNS VOID AS $$ DECLARE v_sub RECORD; BEGIN FOR v_sub IN SELECT * FROM webhook_subscriptions WHERE event_type=p_event AND is_active=true LOOP INSERT INTO webhook_deliveries (subscription_id, event_type, payload, http_status, response_body) VALUES (v_sub.id, p_event, p_payload, 200, 'Queued'); END LOOP; END; $$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION create_webhook(p_event TEXT, p_url TEXT, p_secret TEXT DEFAULT NULL) RETURNS JSONB AS $$ DECLARE v_id TEXT; BEGIN IF NOT authz_check_admin('employee.view_all') THEN RETURN jsonb_build_object('ok', false, 'msg', 'Admin only'); END IF; v_id := gen_random_uuid()::TEXT; INSERT INTO webhook_subscriptions (id, business_id, event_type, target_url, secret_key) VALUES (v_id, 'default', p_event, p_url, p_secret); RETURN jsonb_build_object('ok', true, 'id', v_id); END; $$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION list_webhooks() RETURNS JSONB AS $$ BEGIN IF NOT authz_check_admin('employee.view_all') THEN RETURN jsonb_build_object('ok', false, 'msg', 'Admin only'); END IF; RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(row_to_json(t)),'[]'::jsonb)) FROM (SELECT id, event_type, target_url, is_active, created_at FROM webhook_subscriptions ORDER BY created_at DESC) t); END; $$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- GRANTs
GRANT EXECUTE ON FUNCTION trigger_webhook(TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION create_webhook(TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION list_webhooks() TO authenticated;
