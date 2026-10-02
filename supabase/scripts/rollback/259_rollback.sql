-- Rollback 259 — kembalikan CHECK constraint + is_admin_or_owner ke pre-image
-- byte-exact. Dijalankan MANUAL via psql (file rollback WAJIB punya BEGIN/COMMIT).
-- Pre-image:
--   CHECK      = pg_get_constraintdef probe B2.23 (b3c1e8f4062a836dd0329134c0bb9f4dbb991e376cfbabc29f5838da9bf458f0)
--   fungsi     = pg_get_functiondef probe B2.23 (d7c7d1f623f0bc0884e25d3719f8544f2f555d004847e271f7930126b20fe771)
-- Mengembalikan 'admin_produksi' ke whitelist CHECK + is_admin_or_owner.

BEGIN;

ALTER TABLE user_roles DROP CONSTRAINT IF EXISTS user_roles_role_check;

ALTER TABLE user_roles ADD CONSTRAINT user_roles_role_check
  CHECK ((role = ANY (ARRAY[
    'owner'::text,
    'admin'::text,
    'worker'::text,
    'admin_pusat'::text,
    'admin_hrd'::text,
    'admin_finance'::text,
    'admin_produksi'::text,
    'admin_operasional'::text,
    'admin_mining'::text,
    'admin_mill'::text,
    'admin_estate'::text,
    'manager'::text,
    'supervisor'::text,
    'director'::text
  ])));

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
    AND ur.role IN ('owner', 'admin_pusat', 'admin_hrd', 'admin_finance', 'admin_produksi')
  ) OR EXISTS (
    SELECT 1 FROM user_roles WHERE nrp = (
      SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1
    ) AND role = 'owner'
  );
$function$;

COMMIT;
