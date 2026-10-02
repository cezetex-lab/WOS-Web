-- Rollback 257 — lepaskan trigger audit user_role_assignments.
-- Dijalankan MANUAL via psql (file rollback WAJIB punya BEGIN/COMMIT sendiri).
-- Pre-image 257: 0 trigger di user_role_assignments (probe B4 = 0 baris).

BEGIN;

DROP TRIGGER IF EXISTS trg_audit_user_role_assignments
  ON user_role_assignments;

COMMIT;
