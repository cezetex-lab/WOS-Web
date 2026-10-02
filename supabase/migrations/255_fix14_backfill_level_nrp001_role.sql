-- =============================================================================
-- 255_fix14_backfill_level_nrp001_role.sql
-- Fix #14 §8 — backfill role_level + hapus assignment admin NRP001 (CEO)
-- =============================================================================
-- Keputusan user (K1–K5, 2026-10-02), berbasis fakta probe read-only
-- B2.9–B2.13 (lihat docs/forensic/FIX14-ROLE-LEVEL-TOTAL.md):
--   K1(a-inti) : NRP001 = CEO → role_level 5, TANPA admin_role; baris assignment
--                admin_pusat dihapus. Kolom user_roles.role SENGAJA tetap
--                'admin_pusat' untuk kompatibilitas sesi (is_admin_or_owner(),
--                check_admin_access(), login_worker() masih membacanya).
--                Rename ke 'ceo' DITUNDA ke §9/§10: CHECK user_roles_role_check
--                tidak memuat 'ceo' (hanya owner/admin/worker/admin_*/manager/
--                supervisor/director) dan 61 file src/ menyebut 'admin_pusat'.
--   K2(a)      : NRP101–103 tetap ENTERPRISE. employees_master.divisi NULL untuk
--                NRP100–106, jadi scope DEPARTMENT akan selalu FALSE.
--   K3(b)      : NRP100 scope_bu_id tetap 'BU04'. authz_get_scope() hanya
--                mengembalikan scope_type, authz_in_scope() pada ENTERPRISE
--                mengabaikan v_bu, dan check_module_access() memakai BU dari
--                employees_master — jadi 'BU04' inert. Non-NULL menjaga
--                ON CONFLICT pada UNIQUE (nrp, role_code, scope_type, scope_bu_id).
--   K4         : NRP001→5, NRP100–106→3, NRP002–010 sudah 1 (no-op).
--
-- Sumber kebenaran level = user_roles.role_level:
--   get_current_user_context()      : 'role_level', COALESCE(v_role.role_level, 1)
--   login_worker() / _by_email()    : 'role_level', COALESCE(v_role.role_level, 1)
--   check_module_access()           : DENY bila (v_ctx->>'role_level') < p_required_role_level
-- employees_master.role_level = vestigial (17/17 bernilai 0, tidak meng-gate apa
-- pun); di-cerminkan agar sinkron dengan owner_update_role() yang menulis kedua tabel.
--
-- CATATAN TRANSAKSI — JANGAN menulis BEGIN/COMMIT di berkas ini.
--   Wrapper supabase/scripts/apply-migration.mjs membungkus seluruh isi berkas
--   dalam BEGIN/COMMIT lalu mendaftarkan ke schema_migrations. Bila berkas ini
--   membawa COMMIT sendiri, transaksi wrapper tertutup lebih awal sehingga
--   pendaftaran migrasi berjalan di luar transaksi — persis celah 221/222/223
--   yang justru dicegah oleh wrapper tersebut.
--
-- IDEMPOTEN: setiap statement memakai guard `IS DISTINCT FROM`; apply ulang = no-op.
--
-- Definition of Done (bukti wajib sesudah apply):
--   1) user_roles       : 8 baris berubah (NRP001→5, NRP100–106→3)
--   2) employees_master : 8 baris berubah (cerminan)
--   3) user_role_assignments : count 17 → 16 (hanya nrp='NRP001' hilang)
--   4) audit_log        : actor = 'SYSTEM' (trg_audit_user_roles; migrasi berjalan
--                         tanpa JWT claims) — ekspektasi, bukan anomali
--   5) NRP002–010 dan assignment NRP100–106 TIDAK tersentuh
--
-- Rollback: supabase/scripts/rollback/255_rollback.sql
-- =============================================================================

-- 1) Backfill role_level di user_roles (sumber kebenaran sesi & gate modul)
UPDATE user_roles
   SET role_level = 5
 WHERE nrp = 'NRP001'
   AND role_level IS DISTINCT FROM 5;

UPDATE user_roles
   SET role_level = 3
 WHERE nrp IN ('NRP100', 'NRP101', 'NRP102', 'NRP103', 'NRP104', 'NRP105', 'NRP106')
   AND role_level IS DISTINCT FROM 3;

-- 2) Cerminkan ke employees_master.role_level (kosmetik-konsistensi)
UPDATE employees_master
   SET role_level = 5
 WHERE nrp = 'NRP001'
   AND role_level IS DISTINCT FROM 5;

UPDATE employees_master
   SET role_level = 3
 WHERE nrp IN ('NRP100', 'NRP101', 'NRP102', 'NRP103', 'NRP104', 'NRP105', 'NRP106')
   AND role_level IS DISTINCT FROM 3;

-- 3) NRP001 tidak punya admin_role: CEO diwakili oleh level 5, bukan peran admin
--    Predikat nrp (bukan id) supaya idempoten di instalasi baru — baseline
--    tetap men-seed baris yang sama, jadi migrasi ini harus menyatu di semua env.
DELETE FROM user_role_assignments
 WHERE nrp = 'NRP001';

-- NRP100–106 (assignment) dan NRP002–010: 0 tulis — sudah sesuai keputusan K2a/K3b.
