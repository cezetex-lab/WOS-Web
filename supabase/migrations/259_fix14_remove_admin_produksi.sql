-- Fix #14 §9 P2-F14-I (keputusan user: I2 — tahap murah) — admin_produksi
-- setengah jadi: ada di CHECK + whitelist is_admin_or_owner, tapi TIDAK ada di
-- admin_roles / role_page_access / user_roles / user_role_assignments.
--
-- Bukti (probe B2.22 + B2.23, 2026-10-01):
--   B6 user_roles role='admin_produksi'              = 0
--   B7 user_role_assignments role_code='admin_produksi'= 0
--   B8 admin_roles role_code='admin_produksi'         = 0
--   B9 role_page_access role_code='admin_produksi'    = 0
--   → nol user bisa memicunya; jalur check_admin_access akan menolak dengan
--     reason='role_not_found' bila suatu saat dipakai.
--
-- TAHAP MURAH — yang TIDAK dikerjakan di sini:
--   3 baris role_permission_sets (id 14/15/16) milik admin_produksi masih ada
--   dan TIDAK dihapus. Itu migrasi 260 (P3, opsional) terpisah, karena
--   role_permission_sets dibaca authz_has_permission() yang dipakai 105 RLS
--   policy — menghapus di sini berisiko memotong hak akses secara diam-diam.
--
-- PERUBAHAN: (1) CHECK user_roles_role_check kehilangan 'admin_produksi',
--           (2) is_admin_or_owner() kehilangan 'admin_produksi' dari whitelist.
-- Body is_admin_or_owner selebihnya byte-identik hasil pg_get_functiondef (B2).
-- WAJIB preserve: LANGUAGE sql, STABLE SECURITY DEFINER,
-- SET search_path TO 'public','extensions', signature () → RETURNS boolean.
--
-- P4: TANPA BEGIN/COMMIT (wrapper apply-migration.mjs membungkus sendiri).

ALTER TABLE user_roles DROP CONSTRAINT IF EXISTS user_roles_role_check;

ALTER TABLE user_roles ADD CONSTRAINT user_roles_role_check
  CHECK (role = ANY (ARRAY[
    'owner',
    'admin',
    'worker',
    'admin_pusat',
    'admin_hrd',
    'admin_finance',
    'admin_operasional',
    'admin_mining',
    'admin_mill',
    'admin_estate',
    'manager',
    'supervisor',
    'director'
  ]));

CREATE OR REPLACE FUNCTION public.is_admin_or_owner()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM user_roles ur
    JOIN employees_master em ON em.nrp = ur.nrp
    WHERE em.auth_id = auth.uid()
    AND ur.role IN ('owner', 'admin_pusat', 'admin_hrd', 'admin_finance')
  ) OR EXISTS (
    SELECT 1 FROM user_roles WHERE nrp = (
      SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1
    ) AND role = 'owner'
  );
$function$
