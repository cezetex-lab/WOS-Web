-- ============================================================
-- 057_mfa_totp.sql — TOTP MFA Implementation
-- ============================================================

-- MFA Factors table — stores TOTP secrets per user
CREATE TABLE IF NOT EXISTS mfa_factors (
  id TEXT PRIMARY KEY DEFAULT encode(gen_random_bytes(8), 'hex'),
  nrp TEXT NOT NULL REFERENCES employees_master(nrp),
  secret TEXT NOT NULL,  -- TOTP shared secret (base32 encoded)
  issuer TEXT DEFAULT 'insightWOS',
  label TEXT,  -- user-friendly label e.g. "Google Authenticator"
  enabled BOOLEAN DEFAULT false,
  verified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast lookup
CREATE INDEX IF NOT EXISTS idx_mfa_factors_nrp ON mfa_factors(nrp);

-- RLS: users can only see their own MFA factors
ALTER TABLE mfa_factors ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "mfa_own_factors" ON mfa_factors;

CREATE POLICY "mfa_own_factors" ON mfa_factors
  FOR ALL USING (nrp = current_setting('request.jwt.claims', true)::json->>'nrp');

-- ============================================================
-- MFA RPCs
-- ============================================================

-- 1. Check if MFA is enabled for a user
CREATE OR REPLACE FUNCTION mfa_check_status(p_nrp TEXT)
RETURNS JSONB AS $$
DECLARE
  v_factor RECORD;
BEGIN
  SELECT id, enabled, verified_at, label
  INTO v_factor
  FROM mfa_factors
  WHERE nrp = p_nrp AND enabled = true
  LIMIT 1;
  
  IF FOUND THEN
    RETURN jsonb_build_object(
      'ok', true,
      'mfa_enabled', true,
      'factor_id', v_factor.id,
      'label', v_factor.label,
      'verified_at', v_factor.verified_at
    );
  ELSE
    RETURN jsonb_build_object('ok', true, 'mfa_enabled', false);
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Enroll MFA — generate TOTP secret
-- Uses PostgreSQL pgcrypto for random bytes, encodes as base32
CREATE OR REPLACE FUNCTION mfa_enroll(p_nrp TEXT, p_label TEXT DEFAULT 'insightWOS')
RETURNS JSONB AS $$
DECLARE
  v_secret TEXT;
  v_secret_b32 TEXT;
  v_factor_id TEXT;
  v_otpauth_url TEXT;
BEGIN
  -- Check if already enrolled
  IF EXISTS (SELECT 1 FROM mfa_factors WHERE nrp = p_nrp AND enabled = true) THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'MFA sudah aktif. Disable dulu sebelum enroll ulang.');
  END IF;
  
  -- Generate 20-byte random secret
  v_secret := encode(gen_random_bytes(20), 'hex');
  
  -- Convert hex to base32 for TOTP
  -- PostgreSQL doesn't have native base32, so we store hex and convert in frontend
  v_secret_b32 := upper(replace(
    encode(decode(v_secret, 'hex'), 'base64'),
    '=', ''
  ));
  
  -- Create factor record
  v_factor_id := encode(gen_random_bytes(8), 'hex');
  
  INSERT INTO mfa_factors (id, nrp, secret, issuer, label, enabled)
  VALUES (v_factor_id, p_nrp, v_secret, 'insightWOS', p_label, false);
  
  -- Build otpauth URL for QR code generation
  v_otpauth_url := 'otpauth://totp/insightWOS:' || p_nrp || '?secret=' || v_secret_b32 || '&issuer=insightWOS&algorithm=SHA1&digits=6&period=30';
  
  RETURN jsonb_build_object(
    'ok', true,
    'factor_id', v_factor_id,
    'secret', v_secret_b32,
    'otpauth_url', v_otpauth_url,
    'msg', 'Scan QR code dengan authenticator app, lalu verifikasi kode TOTP'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Verify and activate MFA — user enters TOTP code to confirm enrollment
CREATE OR REPLACE FUNCTION mfa_verify_and_activate(p_nrp TEXT, p_factor_id TEXT, p_code TEXT)
RETURNS JSONB AS $$
DECLARE
  v_factor RECORD;
  v_current_time BIGINT;
  v_counter BIGINT;
  v_computed TEXT;
  v_match BOOLEAN := false;
  i INT;
BEGIN
  -- Get factor
  SELECT * INTO v_factor
  FROM mfa_factors
  WHERE id = p_factor_id AND nrp = p_nrp AND enabled = false;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'MFA factor tidak ditemukan atau sudah aktif.');
  END IF;
  
  -- TOTP verification: check current time window and ±1 window
  v_current_time := EXTRACT(EPOCH FROM NOW())::BIGINT;
  
  FOR i IN -1..1 LOOP
    v_counter := (v_current_time / 30) + i;
    
    -- Compute HMAC-SHA1
    v_computed := LOWER(encode(
      hmac(
        E'\x' || LPAD(TO_HEX(v_counter), 16, '0'),
        decode(v_factor.secret, 'hex'),
        'sha1'
      ),
      'hex'
    ));
    
    -- Dynamic truncation (RFC 4226)
    DECLARE
      v_offset INT;
      v_binary INT;
      v_otp TEXT;
    BEGIN
      v_offset := ('x' || RIGHT(v_computed, 1))::bit(8)::int + 1;
      v_binary := (
        ('x' || SUBSTRING(v_computed FROM v_offset * 2 + 1 FOR 8))::bit(32)::bigint
        % 1000000
      )::int;
      v_otp := LPAD(v_binary::TEXT, 6, '0');
      
      IF v_otp = p_code THEN
        v_match := true;
        EXIT;
      END IF;
    END;
  END LOOP;
  
  IF NOT v_match THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Kode TOTP salah. Coba lagi.');
  END IF;
  
  -- Activate MFA
  UPDATE mfa_factors
  SET enabled = true, verified_at = NOW(), updated_at = NOW()
  WHERE id = p_factor_id;
  
  RETURN jsonb_build_object(
    'ok', true,
    'msg', 'MFA berhasil diaktifkan! Gunakan authenticator app untuk login.',
    'enabled', true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Verify TOTP during login (after OTP verification)
CREATE OR REPLACE FUNCTION mfa_verify_login(p_nrp TEXT, p_code TEXT)
RETURNS JSONB AS $$
DECLARE
  v_factor RECORD;
  v_current_time BIGINT;
  v_counter BIGINT;
  v_computed TEXT;
  v_match BOOLEAN := false;
  i INT;
BEGIN
  -- Get active MFA factor
  SELECT * INTO v_factor
  FROM mfa_factors
  WHERE nrp = p_nrp AND enabled = true
  LIMIT 1;
  
  IF NOT FOUND THEN
    -- No MFA enabled — allow login
    RETURN jsonb_build_object('ok', true, 'mfa_required', false);
  END IF;
  
  -- TOTP verification
  v_current_time := EXTRACT(EPOCH FROM NOW())::BIGINT;
  
  FOR i IN -1..1 LOOP
    v_counter := (v_current_time / 30) + i;
    
    v_computed := LOWER(encode(
      hmac(
        E'\x' || LPAD(TO_HEX(v_counter), 16, '0'),
        decode(v_factor.secret, 'hex'),
        'sha1'
      ),
      'hex'
    ));
    
    DECLARE
      v_offset INT;
      v_binary INT;
      v_otp TEXT;
    BEGIN
      v_offset := ('x' || RIGHT(v_computed, 1))::bit(8)::int + 1;
      v_binary := (
        ('x' || SUBSTRING(v_computed FROM v_offset * 2 + 1 FOR 8))::bit(32)::bigint
        % 1000000
      )::int;
      v_otp := LPAD(v_binary::TEXT, 6, '0');
      
      IF v_otp = p_code THEN
        v_match := true;
        EXIT;
      END IF;
    END;
  END LOOP;
  
  IF NOT v_match THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Kode TOTP salah.');
  END IF;
  
  RETURN jsonb_build_object(
    'ok', true,
    'mfa_required', true,
    'mfa_verified', true,
    'msg', 'MFA verified'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Disable MFA
CREATE OR REPLACE FUNCTION mfa_disable(p_nrp TEXT, p_code TEXT)
RETURNS JSONB AS $$
DECLARE
  v_verify JSONB;
BEGIN
  -- Must verify TOTP before disabling
  v_verify := mfa_verify_login(p_nrp, p_code);
  
  IF NOT (v_verify->>'ok')::boolean THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Kode TOTP salah. Tidak bisa disable MFA.');
  END IF;
  
  UPDATE mfa_factors SET enabled = false, updated_at = NOW() WHERE nrp = p_nrp AND enabled = true;
  
  RETURN jsonb_build_object('ok', true, 'msg', 'MFA berhasil dinonaktifkan.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Log completion
DO $$ BEGIN
  RAISE NOTICE 'MFA TOTP: mfa_factors table + 5 RPCs created (check, enroll, verify, login, disable)';
END $$;
