-- 195: Fix worker_passwords reset_required for non-bcrypt passwords
--
-- Audit finding F-5: Some workers (NRP002,003,004,006,007,008,010) have non-bcrypt
-- passwords (sha256+salt) with reset_required = false, but they should have
-- reset_required = true to force password upgrade on next login.
--
-- Perbaikan (2026-09-18): awalnya `DO ` + `END ;` — marker dollar `$$` hilang sehingga
-- syntax error di instalasi dari awal. Diperbaiki jadi `DO $$ ... END $$;` dan semantik
-- klausa WHERE dikembalikan ke pencarian prefiks bcrypt (`$2`). Idempoten & aman di live.

DO $$
DECLARE
    v_count INTEGER;
BEGIN
    -- bcrypt hashes always start with '$2'; everything else is legacy -> force reset.
    UPDATE worker_passwords
    SET reset_required = TRUE
    WHERE (password_hash IS DISTINCT FROM '' AND left(password_hash, 2) <> '$2')
      AND is_active = TRUE;

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Fixed reset_required for % workers with non-bcrypt passwords', v_count;
END $$;
