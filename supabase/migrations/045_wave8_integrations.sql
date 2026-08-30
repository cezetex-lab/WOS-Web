-- ============================================================
-- 045_wave8_integrations.sql
-- Wave 8: Webhooks, SSO stub, Slack/Teams notifications
-- ============================================================

-- 1. WEBHOOKS — outgoing event notifications
CREATE TABLE IF NOT EXISTS webhook_configs (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  url TEXT NOT NULL,
  events TEXT[] NOT NULL DEFAULT '{}',  -- ['leave_approved', 'kpi_alert', 'turnover_warning']
  secret TEXT,
  active BOOLEAN DEFAULT true,
  last_triggered_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS webhook_logs (
  id BIGSERIAL PRIMARY KEY,
  webhook_id BIGINT REFERENCES webhook_configs(id) ON DELETE CASCADE,
  event TEXT NOT NULL,
  payload JSONB,
  response_status INT,
  response_body TEXT,
  success BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. SSO PROVIDERS — OAuth2 configuration
CREATE TABLE IF NOT EXISTS sso_providers (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,           -- 'Google Workspace', 'Microsoft Azure AD'
  provider_type TEXT NOT NULL,  -- 'oauth2', 'oidc', 'saml'
  client_id TEXT,
  client_secret_encrypted TEXT,
  auth_url TEXT,
  token_url TEXT,
  userinfo_url TEXT,
  scopes TEXT[] DEFAULT '{openid,email,profile}',
  enabled BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. EXTERNAL NOTIFICATIONS — Slack/Teams/WhatsApp
CREATE TABLE IF NOT EXISTS external_notifications (
  id BIGSERIAL PRIMARY KEY,
  channel TEXT NOT NULL,        -- 'slack', 'teams', 'whatsapp', 'email'
  webhook_url TEXT NOT NULL,    -- Incoming webhook URL
  event_types TEXT[] NOT NULL DEFAULT '{}',
  active BOOLEAN DEFAULT true,
  last_sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS external_notification_logs (
  id BIGSERIAL PRIMARY KEY,
  channel TEXT NOT NULL,
  event TEXT NOT NULL,
  payload JSONB,
  success BOOLEAN DEFAULT false,
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS
ALTER TABLE webhook_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE webhook_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE sso_providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE external_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE external_notification_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "webhook_configs_admin" ON webhook_configs FOR ALL USING (true);
CREATE POLICY "webhook_logs_admin" ON webhook_logs FOR SELECT USING (true);
CREATE POLICY "sso_providers_admin" ON sso_providers FOR ALL USING (true);
CREATE POLICY "external_notifications_admin" ON external_notifications FOR ALL USING (true);
CREATE POLICY "external_notification_logs_admin" ON external_notification_logs FOR SELECT USING (true);

GRANT ALL ON webhook_configs TO anon, authenticated;
GRANT ALL ON webhook_logs TO anon, authenticated;
GRANT ALL ON sso_providers TO anon, authenticated;
GRANT ALL ON external_notifications TO anon, authenticated;
GRANT ALL ON external_notification_logs TO anon, authenticated;
GRANT USAGE ON SEQUENCE webhook_configs_id_seq TO anon, authenticated;
GRANT USAGE ON SEQUENCE webhook_logs_id_seq TO anon, authenticated;
GRANT USAGE ON SEQUENCE sso_providers_id_seq TO anon, authenticated;
GRANT USAGE ON SEQUENCE external_notifications_id_seq TO anon, authenticated;
GRANT USAGE ON SEQUENCE external_notification_logs_id_seq TO anon, authenticated;

-- ============================================================
-- RPCs
-- ============================================================

-- GET all webhook configs
CREATE OR REPLACE FUNCTION admin_get_webhooks()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('id', w.id, 'name', w.name, 'url', w.url, 'events', w.events, 'active', w.active, 'last_triggered_at', w.last_triggered_at)
    ), '[]'::jsonb))
    FROM webhook_configs w ORDER BY w.id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- CREATE webhook
CREATE OR REPLACE FUNCTION admin_create_webhook(p_name TEXT, p_url TEXT, p_events TEXT[])
RETURNS JSONB AS $$
DECLARE v_id BIGINT;
BEGIN
  INSERT INTO webhook_configs(name, url, events) VALUES(p_name, p_url, p_events) RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- TOGGLE webhook
CREATE OR REPLACE FUNCTION admin_toggle_webhook(p_id BIGINT, p_active BOOLEAN)
RETURNS JSONB AS $$
BEGIN
  UPDATE webhook_configs SET active = p_active WHERE id = p_id;
  RETURN jsonb_build_object('ok', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- DELETE webhook
CREATE OR REPLACE FUNCTION admin_delete_webhook(p_id BIGINT)
RETURNS JSONB AS $$
BEGIN
  DELETE FROM webhook_configs WHERE id = p_id;
  RETURN jsonb_build_object('ok', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- GET webhook logs
CREATE OR REPLACE FUNCTION admin_get_webhook_logs()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('id', l.id, 'webhook_id', l.webhook_id, 'event', l.event, 'success', l.success, 'response_status', l.response_status, 'created_at', l.created_at)
      ORDER BY l.created_at DESC
    ), '[]'::jsonb))
    FROM webhook_logs l LIMIT 50
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- GET SSO providers
CREATE OR REPLACE FUNCTION admin_get_sso_providers()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('id', s.id, 'name', s.name, 'provider_type', s.provider_type, 'enabled', s.enabled)
    ), '[]'::jsonb))
    FROM sso_providers s ORDER BY s.id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- GET external notification configs
CREATE OR REPLACE FUNCTION admin_get_external_notifications()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object('id', e.id, 'channel', e.channel, 'event_types', e.event_types, 'active', e.active, 'last_sent_at', e.last_sent_at)
    ), '[]'::jsonb))
    FROM external_notifications e ORDER BY e.id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Seed: default SSO providers (disabled)
INSERT INTO sso_providers (name, provider_type, enabled) VALUES
  ('Google Workspace', 'oidc', false),
  ('Microsoft Azure AD', 'oauth2', false)
ON CONFLICT DO NOTHING;

-- Seed: default external notification channels (disabled)
INSERT INTO external_notifications (channel, webhook_url, event_types, active) VALUES
  ('slack', '', ARRAY['leave_approved', 'kpi_alert'], false),
  ('teams', '', ARRAY['leave_approved', 'kpi_alert'], false)
ON CONFLICT DO NOTHING;
