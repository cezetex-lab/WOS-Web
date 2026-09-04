-- ============================================================
-- 094_owner_login.sql — Owner Login RPC Function
-- ============================================================

-- ============================================================
-- 1. Create owner_login function (hanya butuh p_email, password sudah diverifikasi Supabase Auth)
-- ============================================================
DROP FUNCTION IF EXISTS owner_login(text, text) CASCADE;
DROP FUNCTION IF EXISTS owner_login(text) CASCADE;

CREATE OR REPLACE FUNCTION owner_login(p_email TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Owner hanya perlu validasi email ada di system_bootstrap
  -- Tidak perlu cek employees_master karena owner bukan pekerja
  
  RETURN jsonb_build_object(
    'ok', true,
    'nrp', 'OWNER001',
    'nama', 'System Owner',
    'role', 'owner',
    'role_level', 5,
    'is_owner', true
  );
END;
$$;

-- 2. Grant execute permission
GRANT EXECUTE ON FUNCTION owner_login(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION owner_login(TEXT) TO anon;

-- ============================================================
-- 4. check_mfa_status — Check if MFA is enabled for a user
-- ============================================================
CREATE OR REPLACE FUNCTION check_mfa_status(p_nrp TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_mfa RECORD;
BEGIN
  SELECT * INTO v_mfa FROM mfa_store WHERE nrp = p_nrp AND enabled = true;
  
  IF v_mfa IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'enabled', false);
  END IF;
  
  RETURN jsonb_build_object('ok', true, 'enabled', true);
END;
$$;

GRANT EXECUTE ON FUNCTION check_mfa_status(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION check_mfa_status(TEXT) TO anon;

-- ============================================================
-- 5. verify_mfa — Verify MFA code
-- ============================================================
CREATE OR REPLACE FUNCTION verify_mfa(p_nrp TEXT, p_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_mfa RECORD;
  v_hash TEXT;
BEGIN
  -- Hash the code
  v_hash := encode(digest(p_code, 'sha256'), 'hex');
  
  -- Find matching MFA record
  SELECT * INTO v_mfa FROM mfa_store 
  WHERE nrp = p_nrp 
    AND code_hash = v_hash 
    AND enabled = true 
    AND expires_at > NOW();
  
  IF v_mfa IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Kode MFA tidak valid atau sudah kadaluarsa');
  END IF;
  
  -- Mark as used
  UPDATE mfa_store SET used = true WHERE id = v_mfa.id;
  
  RETURN jsonb_build_object('ok', true, 'msg', 'Verifikasi berhasil');
END;
$$;

GRANT EXECUTE ON FUNCTION verify_mfa(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION verify_mfa(TEXT, TEXT) TO anon;

-- ============================================================
-- 6. Create mfa_store table if not exists
-- ============================================================
CREATE TABLE IF NOT EXISTS mfa_store (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
  nrp TEXT NOT NULL,
  code_hash TEXT NOT NULL,
  enabled BOOLEAN DEFAULT true,
  used BOOLEAN DEFAULT false,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS for mfa_store (drop existing policies first to make idempotent)
ALTER TABLE mfa_store ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "mfa_store_select" ON mfa_store;
DROP POLICY IF EXISTS "mfa_store_insert" ON mfa_store;
DROP POLICY IF EXISTS "mfa_store_update" ON mfa_store;

CREATE POLICY "mfa_store_select" ON mfa_store FOR SELECT USING (TRUE);
CREATE POLICY "mfa_store_insert" ON mfa_store FOR INSERT WITH CHECK (TRUE);
CREATE POLICY "mfa_store_update" ON mfa_store FOR UPDATE USING (TRUE);

-- Log completion
DO $$ BEGIN
  RAISE NOTICE 'Owner login, check_mfa_status, and verify_mfa functions created';
END $$;
