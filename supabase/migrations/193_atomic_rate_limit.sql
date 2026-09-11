-- ================================================================
-- 193_atomic_rate_limit.sql
-- Atomic rate limiting for edge functions (mfa-service, password-reset)
-- ================================================================
-- Masalah: implementasi hitRateLimit() di edge functions pakai
-- SELECT lalu UPDATE/INSERT terpisah — di bawah concurrency dua request
-- bisa sama-sama membaca count lama dan sama-sama mengizinkan (race),
-- dan upsert versi lama bisa menimpa counter window lain.
-- Solusi: satu RPC SECURITY DEFINER dengan INSERT ... ON CONFLICT
-- DO UPDATE ... WHERE (atomic upsert + conditional increment) + unique
-- index (identifier, action, window_start) + indexes lookup.
-- Edge function cukup: SELECT hit_rate_limit('ident','action',max,window).
-- ================================================================

-- Tabel rate_limits sudah ada (audit: identifier, action, count,
-- window_start, created_at). Pastikan kolomnya lengkap.
ALTER TABLE rate_limits ADD COLUMN IF NOT EXISTS identifier TEXT NOT NULL DEFAULT '';
ALTER TABLE rate_limits ADD COLUMN IF NOT EXISTS action TEXT NOT NULL DEFAULT '';
ALTER TABLE rate_limits ADD COLUMN IF NOT EXISTS count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE rate_limits ADD COLUMN IF NOT EXISTS window_start TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE rate_limits ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- Unique index per (identifier, action, window) — kunci atomic upsert.
-- CONCURRENTLY tidak bisa di dalam transaction; pakai plain CREATE
-- UNIQUE INDEX IF NOT EXISTS (idempotent, tabel kecil).
CREATE UNIQUE INDEX IF NOT EXISTS uq_rate_limits_ident_action_window
  ON rate_limits (identifier, action, window_start);

-- Lookup index untuk pembersihan window lama & query edge function.
CREATE INDEX IF NOT EXISTS idx_rate_limits_window_start ON rate_limits (window_start);

-- ────────────────────────────────────────────────────────────────
-- hit_rate_limit(p_identifier, p_action, p_max, p_window_seconds)
-- RETURNS BOOLEAN — TRUE = diizinkan, FALSE = melebihi limit.
-- Atomic: satu statement INSERT ... ON CONFLICT ... WHERE.
-- ────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION hit_rate_limit(
  p_identifier TEXT,
  p_action TEXT,
  p_max INT DEFAULT 5,
  p_window_seconds INT DEFAULT 900
)
RETURNS BOOLEAN AS $$
DECLARE
  v_window_start TIMESTAMPTZ;
  v_now TIMESTAMPTZ := NOW();
  v_window_len INTERVAL := make_interval(secs => p_window_seconds::int);
BEGIN
  IF p_identifier IS NULL OR p_identifier = '' OR p_action IS NULL OR p_action = '' THEN
    RETURN FALSE; -- input invalid = tolak (fail-closed)
  END IF;
  IF p_max IS NULL OR p_max < 1 THEN p_max := 5; END IF;
  IF p_window_seconds IS NULL OR p_window_seconds < 1 THEN p_window_seconds := 900; END IF;

  -- Window tetap (fixed window, bukan sliding) supaya unik per window
  v_window_start := to_timestamp(
    (EXTRACT(EPOCH FROM v_now)::BIGINT / p_window_seconds) * p_window_seconds
  );

  -- Atomic increment-with-limit:
  --   - row baru -> count = 1 (allowed)
  --   - row lama window ini -> count = count+1 HANYA jika count < p_max
  --   - row window lain -> diabaikan oleh unique index (window baru = row baru)
  INSERT INTO rate_limits (identifier, action, count, window_start)
  VALUES (p_identifier, p_action, 1, v_window_start)
  ON CONFLICT (identifier, action, window_start)
  DO UPDATE SET count = rate_limits.count + 1
  WHERE rate_limits.count < p_max;

  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Cleanup: window kadaluarsa dihapus oleh pg_cron / manual (opsional).
-- Biarkan data lama — query selalu filter window_start >= window aktif.

-- ────────────────────────────────────────────────────────────────
-- Cleanup helper: hapus window kadaluarsa > 1 hari (dipanggil pg_cron)
-- ────────────────────────────────────────────────────────────────
-- Live cleanup_rate_limits() punya return type berbeda — drop dulu.
DROP FUNCTION IF EXISTS cleanup_rate_limits();
CREATE FUNCTION cleanup_rate_limits()
RETURNS VOID AS $$
BEGIN
  DELETE FROM rate_limits WHERE window_start < NOW() - INTERVAL '1 day';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Grants: edge functions pakai service role (bypass RLS), tapi beri
-- authenticated juga supaya bisa dipakai dari SQL langsung.
GRANT EXECUTE ON FUNCTION hit_rate_limit(TEXT, TEXT, INT, INT) TO service_role, authenticated;
GRANT EXECUTE ON FUNCTION cleanup_rate_limits() TO service_role;

DO $$ BEGIN
  RAISE NOTICE '=== 193: atomic rate limiting (hit_rate_limit + unique window index) ===';
END $$;
