-- ============================================================================
-- 261_rollback.sql — batalkan migrasi 261 (Fix #14 §L2 role_codes)
--
-- Dijalankan MANUAL via psql (file ini punya BEGIN/COMMIT sendiri —
-- berbeda dari file migrasi yang P4-nya forbiden BEGIN/COMMIT).
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/scripts/rollback/261_rollback.sql
--
-- URUTAN (balik dari 261):
--   1. Drop FK user_roles            (harus sebelum CHECK, tidak ada dependensi)
--   2. Drop FK user_role_assignments
--   3. Pulihkan CHECK user_roles_role_check — BYTE-EXACT dari pre-image
--   4. Drop TABLE role_codes         (harus SETELAH FK di-drop, karena FK_
--                                      mengindeks role_codes)
--
-- PRE-IMAGE CHECK (probe 2026-10-02, log .agents/logs/fix14-b236-konfirmasi-role.log):
--   pg_get_constraintdef = CHECK ((role = ANY (ARRAY['owner'::text, 'admin'::text,
--   'worker'::text, 'admin_pusat'::text, 'admin_hrd'::text, 'admin_finance'::text,
--   'admin_operasional'::text, 'admin_mining'::text, 'admin_mill'::text,
--   'admin_estate'::text, 'manager'::text, 'supervisor'::text, 'director'::text])))
--   length = 283
--   md5    = bd4d0ad49d6c587a6b0f21a92434da12
--
-- BUKAN byte-exact akan menyebabkan drift yang tidak terdeteksi — lihat
-- pelajaran P7 (presisi) dan P8 (verify:artifacts buta terhadap atribut fungsi).
-- Verifikasi setelah rollback:
--   SELECT md5(pg_get_constraintdef(oid)) FROM pg_constraint
--   WHERE conrelid='user_roles'::regclass AND conname='user_roles_role_check';
--   -- harus: bd4d0ad49d6c587a6b0f21a92434da12
-- ============================================================================

BEGIN;

ALTER TABLE user_roles          DROP CONSTRAINT IF EXISTS fk_ur_role;
ALTER TABLE user_role_assignments DROP CONSTRAINT IF EXISTS fk_ura_role_code;
ALTER TABLE user_roles          DROP CONSTRAINT IF EXISTS user_roles_role_check;

-- Restore CHECK byte-exact (urutan elemen PENTING — pg_get_constraintdef
-- menyimpan urutan deklarasi, dan md5 di atas Depends on urutan ini).
ALTER TABLE user_roles
  ADD CONSTRAINT user_roles_role_check
  CHECK ((role = ANY (ARRAY['owner'::text, 'admin'::text, 'worker'::text, 'admin_pusat'::text, 'admin_hrd'::text, 'admin_finance'::text, 'admin_operasional'::text, 'admin_mining'::text, 'admin_mill'::text, 'admin_estate'::text, 'manager'::text, 'supervisor'::text, 'director'::text])));

DROP TABLE IF EXISTS role_codes;

COMMIT;
