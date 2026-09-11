-- 195: Fix worker_passwords reset_required for non-bcrypt passwords
-- 
-- Audit finding F-5: Some workers (NRP002,003,004,006,007,008,010) have non-bcrypt 
-- passwords (sha256+salt) with reset_required = false, but they should have 
-- reset_required = true to force password upgrade on next login.
--
-- This migration sets reset_required = true for all workers with non-bcrypt passwords
-- (those where password_hash does NOT start with '').

DO 
DECLARE
    v_count INTEGER;
BEGIN
    -- Update reset_required to true for workers with non-bcrypt passwords
    UPDATE worker_passwords
    SET reset_required = TRUE
    WHERE password_hash NOT LIKE '%'
      AND is_active = TRUE;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Fixed reset_required for % workers with non-bcrypt passwords', v_count;
END ;
