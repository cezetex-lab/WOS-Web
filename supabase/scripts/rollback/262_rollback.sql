-- ============================================================================
-- 262_rollback.sql — batalkan migrasi 262 (Fix #14 §J3 assignment NRP001)
--
-- Dijalankan MANUAL via psql (file ini punya BEGIN/COMMIT sendiri —
-- berbeda dari file migrasi yang P4-nya forbiden BEGIN/COMMIT).
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/scripts/rollback/262_rollback.sql
--
-- CATATAN PENTING
--   Predicate TIDAK memfilter is_primary, padahal baris yang dibuat 262
--   bernilai is_primary = FALSE. Kalau nanti (§10 J1 atau operasi lain)
--   ada baris NRP001/admin_pusat dengan is_primary = TRUE, DELETE ini akan
--   ikut menghapusnya. Itu perilaku yang dikehendaki: 262 hanya_Status
--   "hapus seluruh assignment transisi NRP001", bukan "hapus baris
--   non-primary saja". Kalau di masa depan assignment NRP001 menjadi
--   permanen dan tidak boleh ikut terhapus, ubah predicate ini SEBELUM
--   menjalankan rollback.
--
-- Idempoten: jalan kedua kali menghapus 0 baris, tidak error.
-- ============================================================================

BEGIN;

DELETE FROM user_role_assignments
 WHERE nrp = 'NRP001'
   AND role_code = 'admin_pusat'
   AND scope_type = 'ENTERPRISE'
   AND scope_bu_id = 'BU04';

COMMIT;