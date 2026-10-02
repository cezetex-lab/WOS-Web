-- Fix #14 §9 P1-F14-K: user_role_assignments tanpa trigger audit.
-- Pola Fix #4 (migrasi 251): _generic_audit_trigger_fixed sudah
-- SECURITY DEFINER + search_path=public,extensions + actor via
-- COALESCE(authz_current_nrp(),'SYSTEM') + obsolete-safe.
--
-- Bukti (probe B2.22, 2026-10-01): Q1b = 0 trigger di tabel ini, sementara
-- 20 trigger audit lain (17x hr_*, user_roles, worker_passwords, reviews_360)
-- semuanya memakai fungsi generik yang sama. Yang hilang hanya 1 baris CREATE
-- TRIGGER — bukan logikanya. Tabel ini punya kolom `nrp`, jadi v_nrp di fungsi
-- generic terisi tanpa adaptasi.
--
-- PENTING: pasang ini SEBELUM penulisan massal §9, kalau tidak rewiring
-- menulis data otorisasi admin tanpa jejak audit.
--
-- P4: TANPA BEGIN/COMMIT (wrapper apply-migration.mjs membungkus sendiri).

DROP TRIGGER IF EXISTS trg_audit_user_role_assignments
  ON user_role_assignments;

CREATE TRIGGER trg_audit_user_role_assignments
  AFTER INSERT OR UPDATE OR DELETE ON user_role_assignments
  FOR EACH ROW EXECUTE FUNCTION _generic_audit_trigger_fixed();
