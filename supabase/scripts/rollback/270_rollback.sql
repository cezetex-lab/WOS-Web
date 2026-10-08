-- ============================================================================
-- 270_rollback.sql — batalkan migrasi 270 (B2-FULL batch 270B: RPC baru
-- get_my_permissions)
--
-- Dijalankan MANUAL via psql (file ini punya BEGIN/COMMIT sendiri — berbeda dari
-- file migrasi yang P4-nya forbid BEGIN/COMMIT).
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/scripts/rollback/270_rollback.sql
--
-- ISI ROLLBACK
--   DROP fungsi baru get_my_permissions(). Additive murni — 270 tidak
--   mengubah fungsi existing apa pun, jadi tidak ada pre-image yang harus
--   dikembalikan (blok ACL ikut terhapus bersama objeknya).
--   schema_migrations TIDAK disentuh oleh file ini (registry dikembalikan
--   lewat DELETE baris 270 bila migrasi sudah terdaftar — lihat catatan
--   bawah).
--
-- CATATAN: bila 270 sudah terdaftar di schema_migrations, hapus juga barisnya
--   supaya checksum registry konsisten:
--   DELETE FROM schema_migrations WHERE version = '270';
-- ============================================================================

BEGIN;

DROP FUNCTION IF EXISTS public.get_my_permissions();

COMMIT;
