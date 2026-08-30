-- ============================================================
-- 044_push_subscriptions.sql
-- Push notification subscriptions table
-- ============================================================

CREATE TABLE IF NOT EXISTS push_subscriptions (
  id BIGSERIAL PRIMARY KEY,
  nrp TEXT NOT NULL,
  endpoint TEXT NOT NULL UNIQUE,
  keys JSONB NOT NULL DEFAULT '{}',
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast lookup by NRP
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_nrp ON push_subscriptions(nrp);

-- RLS
ALTER TABLE push_subscriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "push_subs_insert" ON push_subscriptions;
CREATE POLICY "push_subs_insert" ON push_subscriptions FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "push_subs_read" ON push_subscriptions;
CREATE POLICY "push_subs_read" ON push_subscriptions FOR SELECT USING (true);

DROP POLICY IF EXISTS "push_subs_update" ON push_subscriptions;
CREATE POLICY "push_subs_update" ON push_subscriptions FOR UPDATE USING (true);

DROP POLICY IF EXISTS "push_subs_delete" ON push_subscriptions;
CREATE POLICY "push_subs_delete" ON push_subscriptions FOR DELETE USING (true);

-- Grant
GRANT ALL ON push_subscriptions TO anon, authenticated;
GRANT USAGE ON SEQUENCE push_subscriptions_id_seq TO anon, authenticated;
