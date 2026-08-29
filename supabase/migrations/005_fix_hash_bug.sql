-- ============================================================
-- 005_fix_hash_bug.sql
-- CRITICAL FIX: hash upgrade generates 2 different salts!
-- Generate salt ONCE, use for both hash and storage
-- Run in Supabase SQL Editor
-- ============================================================

-- Reset ALL passwords to plain text first (fix corrupted hashes)
UPDATE worker_passwords SET password_hash = 'Password123', salt = '', attempts = 0, blocked_until = NULL;

-- Drop and recreate login_worker with fixed hash logic
DROP FUNCTION IF EXISTS login_worker(TEXT, TEXT);

CREATE OR REPLACE FUNCTION login_worker(p_nrp TEXT, p_password TEXT)
RETURNS JSONB AS $$
DECLARE
  v_worker RECORD;
  v_role RECORD;
  v_new_salt TEXT;
  v_computed TEXT;
BEGIN
  SELECT * INTO v_worker FROM worker_passwords WHERE nrp = p_nrp AND is_active = true;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'NRP tidak ditemukan atau tidak aktif.');
  END IF;

  IF v_worker.blocked_until IS NOT NULL AND v_worker.blocked_until > NOW() THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akun terkunci. Coba lagi nanti.');
  END IF;

  IF v_worker.salt IS NULL OR v_worker.salt = '' OR v_worker.password_hash IS NULL OR v_worker.password_hash = '' THEN
    -- Legacy plain text comparison
    IF p_password = v_worker.password_hash THEN
      -- Generate ONE salt, use for both hash and storage
      v_new_salt := encode(gen_random_bytes(16), 'hex');
      v_computed := encode(digest(p_password || v_new_salt, 'sha256'), 'hex');
      UPDATE worker_passwords
      SET password_hash = v_computed,
          salt = v_new_salt,
          attempts = 0,
          blocked_until = NULL
      WHERE nrp = p_nrp;
    ELSE
      UPDATE worker_passwords SET attempts = attempts + 1 WHERE nrp = p_nrp;
      IF v_worker.attempts + 1 >= 5 THEN
        UPDATE worker_passwords SET blocked_until = NOW() + INTERVAL '15 minutes' WHERE nrp = p_nrp;
        RETURN jsonb_build_object('ok', false, 'msg', 'Terlalu banyak percobaan. Akun dikunci 15 menit.');
      END IF;
      RETURN jsonb_build_object('ok', false, 'msg', 'Password salah.');
    END IF;
  ELSE
    -- Hashed comparison: hash(password + stored_salt) == stored_hash
    v_computed := encode(digest(p_password || v_worker.salt, 'sha256'), 'hex');
    IF v_computed != v_worker.password_hash THEN
      UPDATE worker_passwords SET attempts = attempts + 1 WHERE nrp = p_nrp;
      IF v_worker.attempts + 1 >= 5 THEN
        UPDATE worker_passwords SET blocked_until = NOW() + INTERVAL '15 minutes' WHERE nrp = p_nrp;
        RETURN jsonb_build_object('ok', false, 'msg', 'Terlalu banyak percobaan. Akun dikunci 15 menit.');
      END IF;
      RETURN jsonb_build_object('ok', false, 'msg', 'Password salah.');
    END IF;
    UPDATE worker_passwords SET attempts = 0, blocked_until = NULL WHERE nrp = p_nrp;
  END IF;

  SELECT * INTO v_role FROM user_roles WHERE nrp = p_nrp;

  RETURN jsonb_build_object(
    'ok', true,
    'nrp', p_nrp,
    'nama', (SELECT nama FROM employees_master WHERE nrp = p_nrp LIMIT 1),
    'level', COALESCE(v_role.role_level, 1),
    'tier', COALESCE(v_role.plan, 'FREE'),
    'position', (SELECT posisi FROM employees_master WHERE nrp = p_nrp LIMIT 1),
    'divisi', (SELECT divisi FROM employees_master WHERE nrp = p_nrp LIMIT 1)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
