-- ================================================================
-- FASE 9: INFRASTRUCTURE — CIRCUIT BREAKER, DATA CACHE, OFFLINE SYNC
-- Migration 166
-- ================================================================
-- Sumber spec: supabase/c/migrasiGASbelum.sql bagian 9
-- Catatan penting:
--  * cache_get / cache_set pada migrasi 130 masih STUB — di sini
--    diimplementasikan sungguhan di atas tabel data_cache (tanpa
--    menyentuh dashboard_cache milik migrasi 145).
--  * check_rate_limit(TEXT,TEXT,INT) adalah overload baru; fungsi
--    check_rate_limit 4-arg milik migrasi 035 (tabel rate_limits)
--    TIDAK diubah.
-- ================================================================

-- ------------------------------------------------------------------
-- 9.1 CIRCUIT BREAKER & RATE LIMITER (Global)
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS circuit_breaker (
  identifier     TEXT NOT NULL,
  endpoint       TEXT NOT NULL,
  state          TEXT NOT NULL DEFAULT 'CLOSED' CHECK (state IN ('CLOSED','OPEN')),
  request_count  INTEGER NOT NULL DEFAULT 0,
  window_start   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  failure_count  INTEGER NOT NULL DEFAULT 0,
  opened_at      TIMESTAMPTZ,
  last_failure_at TIMESTAMPTZ,
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (identifier, endpoint)
);

ALTER TABLE circuit_breaker ENABLE ROW LEVEL SECURITY;
ALTER TABLE circuit_breaker FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "cb_select" ON circuit_breaker;
CREATE POLICY "cb_select" ON circuit_breaker FOR SELECT
USING (identifier = COALESCE(authz_current_nrp(), ''));

-- Periksa batas request per window (default: 60 request / 60 detik).
-- Jika circuit sedang OPEN (dalam cooldown) -> langsung tolak.
DROP FUNCTION IF EXISTS check_rate_limit(TEXT, TEXT, INT) CASCADE;
CREATE OR REPLACE FUNCTION check_rate_limit(
  p_identifier TEXT,
  p_endpoint TEXT,
  p_max_requests INT DEFAULT 60
) RETURNS JSONB AS $$
DECLARE
  v_row circuit_breaker%ROWTYPE;
  v_retry INT := 0;
BEGIN
  IF p_identifier IS NULL OR p_endpoint IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'allowed', false, 'msg', 'Parameter tidak valid');
  END IF;

  INSERT INTO circuit_breaker (identifier, endpoint)
  VALUES (p_identifier, p_endpoint)
  ON CONFLICT (identifier, endpoint) DO NOTHING;

  SELECT * INTO v_row FROM circuit_breaker
  WHERE identifier = p_identifier AND endpoint = p_endpoint;

  -- Circuit OPEN: tolak selama cooldown 300 detik sejak dibuka
  IF v_row.state = 'OPEN' AND v_row.opened_at IS NOT NULL THEN
    v_retry := GREATEST(0, 300 - EXTRACT(EPOCH FROM (NOW() - v_row.opened_at))::INT);
    IF v_retry > 0 THEN
      RETURN jsonb_build_object('ok', true, 'allowed', false, 'state', 'OPEN', 'retry_after_seconds', v_retry);
    END IF;
    -- Cooldown habis: tutup kembali
    UPDATE circuit_breaker SET state = 'CLOSED', opened_at = NULL, failure_count = 0
    WHERE identifier = p_identifier AND endpoint = p_endpoint;
    SELECT * INTO v_row FROM circuit_breaker
    WHERE identifier = p_identifier AND endpoint = p_endpoint;
  END IF;

  -- Window baru jika sudah lewat 60 detik
  IF v_row.window_start < NOW() - INTERVAL '60 seconds' THEN
    UPDATE circuit_breaker
    SET window_start = NOW(), request_count = 0, updated_at = NOW()
    WHERE identifier = p_identifier AND endpoint = p_endpoint;
    SELECT * INTO v_row FROM circuit_breaker
    WHERE identifier = p_identifier AND endpoint = p_endpoint;
  END IF;

  IF v_row.request_count >= p_max_requests THEN
    RETURN jsonb_build_object('ok', true, 'allowed', false, 'state', v_row.state,
                              'request_count', v_row.request_count, 'max', p_max_requests);
  END IF;

  UPDATE circuit_breaker
  SET request_count = request_count + 1, updated_at = NOW()
  WHERE identifier = p_identifier AND endpoint = p_endpoint;

  RETURN jsonb_build_object('ok', true, 'allowed', true, 'state', 'CLOSED',
                            'request_count', v_row.request_count + 1, 'max', p_max_requests);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Catat kegagalan; jika melampaui threshold, buka circuit (OPEN).
DROP FUNCTION IF EXISTS record_failure(TEXT, TEXT, INT, INT) CASCADE;
CREATE OR REPLACE FUNCTION record_failure(
  p_identifier TEXT,
  p_endpoint TEXT,
  p_threshold INT DEFAULT 5,
  p_cooldown_seconds INT DEFAULT 300
) RETURNS JSONB AS $$
DECLARE
  v_fail INT;
BEGIN
  IF p_identifier IS NULL OR p_endpoint IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Parameter tidak valid');
  END IF;

  INSERT INTO circuit_breaker (identifier, endpoint)
  VALUES (p_identifier, p_endpoint)
  ON CONFLICT (identifier, endpoint) DO NOTHING;

  UPDATE circuit_breaker
  SET failure_count = failure_count + 1,
      last_failure_at = NOW(),
      updated_at = NOW()
  WHERE identifier = p_identifier AND endpoint = p_endpoint;

  SELECT failure_count INTO v_fail FROM circuit_breaker
  WHERE identifier = p_identifier AND endpoint = p_endpoint;

  IF v_fail >= p_threshold THEN
    UPDATE circuit_breaker
    SET state = 'OPEN', opened_at = NOW(), updated_at = NOW()
    WHERE identifier = p_identifier AND endpoint = p_endpoint
      AND state = 'CLOSED';
    RETURN jsonb_build_object('ok', true, 'state', 'OPEN', 'failure_count', v_fail,
                              'cooldown_seconds', p_cooldown_seconds);
  END IF;

  RETURN jsonb_build_object('ok', true, 'state', 'CLOSED', 'failure_count', v_fail);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Tutup circuit secara manual (internal / service role / owner).
DROP FUNCTION IF EXISTS reset_circuit_breaker(TEXT, TEXT) CASCADE;
CREATE OR REPLACE FUNCTION reset_circuit_breaker(p_identifier TEXT, p_endpoint TEXT)
RETURNS JSONB AS $$
BEGIN
  UPDATE circuit_breaker
  SET state = 'CLOSED', opened_at = NULL, failure_count = 0,
      request_count = 0, window_start = NOW(), updated_at = NOW()
  WHERE identifier = p_identifier AND endpoint = p_endpoint;
  RETURN jsonb_build_object('ok', true, 'msg', 'Circuit reset');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Pembersih circuit yang sudah lama tidak dipakai.
DROP FUNCTION IF EXISTS cleanup_circuit_breakers(INT) CASCADE;
CREATE OR REPLACE FUNCTION cleanup_circuit_breakers(p_older_than_hours INT DEFAULT 24)
RETURNS JSONB AS $$
DECLARE
  v_count INT;
BEGIN
  DELETE FROM circuit_breaker WHERE updated_at < NOW() - (p_older_than_hours || ' hours')::interval;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'deleted', v_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ------------------------------------------------------------------
-- 9.2 DATA CACHE (In-Memory / TTL) — data_cache
-- Implementasi cache_get/cache_set (menggantikan stub migrasi 130).
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS data_cache (
  key        TEXT PRIMARY KEY,
  value      JSONB NOT NULL,
  expires_at TIMESTAMPTZ,
  hit_count  INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE data_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE data_cache FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "dc_select" ON data_cache;
CREATE POLICY "dc_select" ON data_cache FOR SELECT
USING (auth.uid() IS NOT NULL);

-- Ambil cache (expired otomatis dihapus). Sama signature dengan stub 130.
CREATE OR REPLACE FUNCTION cache_get(p_key TEXT)
RETURNS JSONB AS $$
DECLARE
  v_row data_cache%ROWTYPE;
BEGIN
  IF p_key IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'hit', false);
  END IF;

  DELETE FROM data_cache WHERE key = p_key AND expires_at IS NOT NULL AND expires_at < NOW();

  SELECT * INTO v_row FROM data_cache WHERE key = p_key;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'hit', false);
  END IF;

  UPDATE data_cache SET hit_count = hit_count + 1 WHERE key = p_key;
  RETURN jsonb_build_object('ok', true, 'hit', true, 'value', v_row.value);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Set cache dengan TTL. Frontend (src/lib/cache.js) mengirim {p_key, p_value (JSON string), p_ttl}.
DROP FUNCTION IF EXISTS cache_set(TEXT, JSONB, INT) CASCADE;
DROP FUNCTION IF EXISTS cache_set(TEXT, TEXT, INT) CASCADE;
CREATE OR REPLACE FUNCTION cache_set(p_key TEXT, p_value TEXT, p_ttl INT DEFAULT 300)
RETURNS JSONB AS $$
DECLARE
  v_json JSONB;
BEGIN
  IF p_key IS NULL OR p_value IS NULL OR p_ttl < 0 THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Parameter tidak valid');
  END IF;

  BEGIN
    v_json := p_value::jsonb;
  EXCEPTION WHEN others THEN
    v_json := to_jsonb(p_value);
  END;

  INSERT INTO data_cache (key, value, expires_at, updated_at)
  VALUES (p_key, v_json, NOW() + (p_ttl || ' seconds')::interval, NOW())
  ON CONFLICT (key) DO UPDATE
    SET value = EXCLUDED.value,
        expires_at = EXCLUDED.expires_at,
        updated_at = NOW();

  RETURN jsonb_build_object('ok', true, 'key', p_key);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Invalidasi cache berdasarkan pola LIKE (contoh: 'dashboard:%').
-- SENG AJA TIDAK di-grant ke authenticated agar tidak bisa menghapus
-- cache global sesuka hati (dipanggil internal / owner / service role).
DROP FUNCTION IF EXISTS cache_invalidate(TEXT) CASCADE;
CREATE OR REPLACE FUNCTION cache_invalidate(p_pattern TEXT)
RETURNS JSONB AS $$
DECLARE
  v_count INT;
BEGIN
  DELETE FROM data_cache WHERE key LIKE p_pattern;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'deleted', v_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Pembersih cache kedaluwarsa.
DROP FUNCTION IF EXISTS cleanup_expired_cache() CASCADE;
CREATE OR REPLACE FUNCTION cleanup_expired_cache()
RETURNS JSONB AS $$
DECLARE
  v_count INT;
BEGIN
  DELETE FROM data_cache WHERE expires_at IS NOT NULL AND expires_at < NOW();
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'deleted', v_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ------------------------------------------------------------------
-- 9.3 OFFLINE MODE PREPARATION — offline_sync
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS offline_sync (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nrp              TEXT NOT NULL,
  table_name       TEXT NOT NULL,
  operation        TEXT NOT NULL CHECK (operation IN ('INSERT','UPDATE','DELETE')),
  payload          JSONB NOT NULL,
  client_request_id TEXT,
  status           TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','SYNCED','ERROR')),
  error            TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  synced_at        TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_offline_sync_nrp_status ON offline_sync (nrp, status);

ALTER TABLE offline_sync ENABLE ROW LEVEL SECURITY;
ALTER TABLE offline_sync FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "os_select" ON offline_sync;
CREATE POLICY "os_select" ON offline_sync FOR SELECT
USING (nrp = authz_current_nrp() OR authz_check_admin('employee.view_all'));

-- Terima perubahan dari frontend saat online (payload tunggal atau array).
-- NRP SELALU diambil dari authz_current_nrp(), tidak pernah dari payload.
DROP FUNCTION IF EXISTS offline_sync_push(JSONB) CASCADE;
CREATE OR REPLACE FUNCTION offline_sync_push(p_payload JSONB)
RETURNS JSONB AS $$
DECLARE
  v_caller TEXT;
  v_item JSONB;
  v_count INT := 0;
  v_op TEXT;
  v_table TEXT;
BEGIN
  v_caller := authz_current_nrp();
  IF v_caller IS NULL OR p_payload IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak / payload kosong');
  END IF;

  IF jsonb_typeof(p_payload) = 'array' THEN
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_payload) LOOP
      v_op := UPPER(v_item->>'operation');
      v_table := v_item->>'table_name';
      IF v_table IS NOT NULL AND v_op IN ('INSERT','UPDATE','DELETE') THEN
        INSERT INTO offline_sync (nrp, table_name, operation, payload, client_request_id)
        VALUES (v_caller, v_table, v_op, COALESCE(v_item->'data', '{}'::jsonb), v_item->>'client_request_id');
        v_count := v_count + 1;
      END IF;
    END LOOP;
  ELSE
    v_op := UPPER(p_payload->>'operation');
    v_table := p_payload->>'table_name';
    IF v_table IS NOT NULL AND v_op IN ('INSERT','UPDATE','DELETE') THEN
      INSERT INTO offline_sync (nrp, table_name, operation, payload, client_request_id)
      VALUES (v_caller, v_table, v_op, COALESCE(p_payload->'data', '{}'::jsonb), p_payload->>'client_request_id');
      v_count := 1;
    END IF;
  END IF;

  RETURN jsonb_build_object('ok', true, 'queued', v_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Ambil antrian perubahan yang belum tersinkron (milik sendiri).
DROP FUNCTION IF EXISTS get_my_pending_syncs() CASCADE;
CREATE OR REPLACE FUNCTION get_my_pending_syncs()
RETURNS JSONB AS $$
DECLARE
  v_caller TEXT;
BEGIN
  v_caller := authz_current_nrp();
  IF v_caller IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak');
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'data', COALESCE((SELECT jsonb_agg(jsonb_build_object(
                       'id', id, 'table_name', table_name, 'operation', operation,
                       'payload', payload, 'created_at', created_at))
                      FROM (SELECT id, table_name, operation, payload, created_at
                            FROM offline_sync WHERE nrp = v_caller AND status = 'PENDING'
                            ORDER BY created_at ASC LIMIT 100) t), '[]'::jsonb)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ------------------------------------------------------------------
-- 9.4 SIMULATION LOGS — log_simulation_event
-- ------------------------------------------------------------------
DROP FUNCTION IF EXISTS log_simulation_event(TEXT, JSONB) CASCADE;
CREATE OR REPLACE FUNCTION log_simulation_event(p_event_type TEXT, p_payload JSONB)
RETURNS JSONB AS $$
BEGIN
  IF p_event_type IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Parameter tidak valid');
  END IF;

  INSERT INTO simulation_logs (action, details)
  VALUES (p_event_type, COALESCE(p_payload, '{}'::jsonb)::text);

  RETURN jsonb_build_object('ok', true, 'logged', p_event_type);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ------------------------------------------------------------------
-- GRANTs
-- (check_rate_limit / record_failure / reset_circuit_breaker /
--  cache_invalidate SENG AJA tidak di-grant ke authenticated:
--  utility internal untuk service role / owner / SECURITY DEFINER lain.)
-- ------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION cache_get(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION cache_set(TEXT, TEXT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION offline_sync_push(JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION get_my_pending_syncs() TO authenticated;
GRANT EXECUTE ON FUNCTION log_simulation_event(TEXT, JSONB) TO authenticated;

DO $$ BEGIN
  RAISE NOTICE '=== Fase 9: Infrastructure -- 3 tables, 11 functions ===';
END $$;
