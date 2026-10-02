-- =============================================================================
-- 255_rollback.sql — kebalikan efek migrasi 255 (Fix #14 §8)
-- =============================================================================
-- Cara pakai (JALANKAN MANUAL, bukan lewat apply-migration.mjs):
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/scripts/rollback/255_rollback.sql
--   atau tempelkan SQL di bawah ke SQL Editor (bungkus manual dalam transaksi).
--
-- Pre-image terverifikasi (probe read-only B2.9 & B2.10, 2026-10-02):
--   user_roles.role_level       : 17/17 = 1
--   employees_master.role_level : 17/17 = 0
--   user_role_assignments       : 17 baris; baris nrp='NRP001' =
--     role_code='admin_pusat', scope_type='ENTERPRISE', scope_bu_id='BU04',
--     scope_org_unit=NULL, scope_domain=NULL, is_primary=true,
--     assigned_at='2026-09-24T10:31:16.422Z', assigned_by=NULL
--
-- CATATAN: id baris yang dipulihkan TIDAK dijamin kembali menjadi 18 karena
-- sequence user_role_assignments_id_seq sudah maju. Konsistensi dijamin oleh
-- UNIQUE (nrp, role_code, scope_type, scope_bu_id).
--
-- Dibuat bersama migrasi 255, belum pernah dijalankan.
-- =============================================================================

BEGIN;

-- 1) Pulihkan assignment admin NRP001 (idempoten lewat NOT EXISTS)
INSERT INTO user_role_assignments
       (nrp, role_code, scope_type, scope_bu_id, scope_org_unit, scope_domain,
        is_primary, assigned_at, assigned_by)
SELECT 'NRP001', 'admin_pusat', 'ENTERPRISE', 'BU04', NULL, NULL,
       TRUE, '2026-09-24T10:31:16.422Z'::timestamptz, NULL
 WHERE NOT EXISTS (
       SELECT 1 FROM user_role_assignments WHERE nrp = 'NRP001');

-- 2) Kembalikan user_roles.role_level ke 1
UPDATE user_roles SET role_level = 1
 WHERE nrp = 'NRP001' AND role_level IS DISTINCT FROM 1;

UPDATE user_roles SET role_level = 1
 WHERE nrp IN ('NRP100', 'NRP101', 'NRP102', 'NRP103', 'NRP104', 'NRP105', 'NRP106')
   AND role_level IS DISTINCT FROM 1;

-- 3) Kembalikan employees_master.role_level ke 0
UPDATE employees_master SET role_level = 0
 WHERE nrp = 'NRP001' AND role_level IS DISTINCT FROM 0;

UPDATE employees_master SET role_level = 0
 WHERE nrp IN ('NRP100', 'NRP101', 'NRP102', 'NRP103', 'NRP104', 'NRP105', 'NRP106')
   AND role_level IS DISTINCT FROM 0;

-- NRP002–010 tidak pernah diubah oleh 255, jadi tidak ada yang dikembalikan.

COMMIT;
