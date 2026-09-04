-- 084: Account Lockout — Failed Login Protection
-- Prevents brute force attacks on login

-- 1. Login attempts tracking table
CREATE TABLE IF NOT EXISTS login_attempts (
  id SERIAL PRIMARY KEY,
  identifier TEXT NOT NULL, -- NRP or email
  attempt_type TEXT NOT NULL CHECK (attempt_type IN ('admin', 'worker')),
  success BOOLEAN NOT NULL DEFAULT FALSE,
  ip_address TEXT,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast lookup
CREATE INDEX IF NOT EXISTS idx_login_attempts_lookup 
  ON login_attempts (identifier, attempt_type, created_at DESC);

-- RLS: only service_role can access (server-side only)
ALTER TABLE login_attempts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS la_service_only ON login_attempts;
CREATE POLICY la_service_only ON login_attempts
  USING (TRUE); -- Edge Functions use service_role, bypasses RLS

-- 2. Check if account is locked (returns true if locked)
CREATE OR REPLACE FUNCTION check_login_lockout(
  p_identifier TEXT,
  p_attempt_type TEXT DEFAULT 'worker'
)
RETURNS JSONB AS $$
DECLARE
  v_failed_count INT;
  v_last_attempt TIMESTAMPTZ;
  v_is_locked BOOLEAN := FALSE;
  v_lockout_reason TEXT := '';
  v_remaining_seconds INT := 0;
BEGIN
  -- Count failed attempts in last 15 minutes
  SELECT COUNT(*), MAX(created_at)
  INTO v_failed_count, v_last_attempt
  FROM login_attempts
  WHERE identifier = p_identifier
    AND attempt_type = p_attempt_type
    AND success = FALSE
    AND created_at > NOW() - INTERVAL '15 minutes';

  -- Check lockout: 5 failed attempts in 15 minutes = locked for 15 minutes
  IF v_failed_count >= 5 THEN
    v_remaining_seconds := EXTRACT(EPOCH FROM (
      (v_last_attempt + INTERVAL '15 minutes') - NOW()
    ))::INT;
    
    IF v_remaining_seconds > 0 THEN
      v_is_locked := TRUE;
      v_lockout_reason := 'Terlalu banyak percobaan gagal. Coba lagi dalam ' || 
                          (v_remaining_seconds / 60)::INT || ' menit.';
      
      -- Log the lockout
      INSERT INTO login_attempts (identifier, attempt_type, success, ip_address)
      VALUES (p_identifier, p_attempt_type, FALSE, 'LOCKOUT_TRIGGERED');
    END IF;
  END IF;

  -- Also check: 10 failed attempts in 24 hours = locked for 1 hour
  SELECT COUNT(*), MAX(created_at)
  INTO v_failed_count, v_last_attempt
  FROM login_attempts
  WHERE identifier = p_identifier
    AND attempt_type = p_attempt_type
    AND success = FALSE
    AND created_at > NOW() - INTERVAL '24 hours';

  IF v_failed_count >= 10 THEN
    v_remaining_seconds := EXTRACT(EPOCH FROM (
      (v_last_attempt + INTERVAL '1 hour') - NOW()
    ))::INT;
    
    IF v_remaining_seconds > 0 THEN
      v_is_locked := TRUE;
      v_lockout_reason := 'Akun dikunci karena terlalu banyak percobaan gagal. Coba lagi dalam ' ||
                          (v_remaining_seconds / 60)::INT || ' menit.';
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'locked', v_is_locked,
    'reason', v_lockout_reason,
    'remaining_seconds', GREATEST(v_remaining_seconds, 0),
    'failed_attempts', v_failed_count
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Record login attempt
CREATE OR REPLACE FUNCTION record_login_attempt(
  p_identifier TEXT,
  p_attempt_type TEXT,
  p_success BOOLEAN,
  p_ip_address TEXT DEFAULT NULL,
  p_user_agent TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
  INSERT INTO login_attempts (identifier, attempt_type, success, ip_address, user_agent)
  VALUES (p_identifier, p_attempt_type, p_success, p_ip_address, p_user_agent);

  -- If successful, clear old failed attempts (clean slate)
  IF p_success THEN
    DELETE FROM login_attempts
    WHERE identifier = p_identifier
      AND attempt_type = p_attempt_type
      AND success = FALSE
      AND created_at < NOW() - INTERVAL '24 hours';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Cleanup old attempts (run via cron or pg_cron)
CREATE OR REPLACE FUNCTION cleanup_login_attempts()
RETURNS VOID AS $$
BEGIN
  DELETE FROM login_attempts
  WHERE created_at < NOW() - INTERVAL '7 days';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Audit log for security events
CREATE TABLE IF NOT EXISTS security_audit_log (
  id SERIAL PRIMARY KEY,
  event_type TEXT NOT NULL,
  identifier TEXT,
  details JSONB DEFAULT '{}'::jsonb,
  ip_address TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE security_audit_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS sal_service_only ON security_audit_log;
CREATE POLICY sal_service_only ON security_audit_log
  USING (TRUE);

-- Index
CREATE INDEX IF NOT EXISTS idx_security_audit_created 
  ON security_audit_log (created_at DESC);
