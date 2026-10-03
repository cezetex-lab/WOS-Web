-- ============================================================================
-- 263_rollback.sql — batalkan migrasi 263 (Fix #14 §9 batch 1/5,
-- rewiring is_admin_or_owner + GRANT authenticated)
--
-- Dijalankan MANUAL via psql (file ini punya BEGIN/COMMIT sendiri —
-- berbeda dari file migrasi yang P4-nya forbid BEGIN/COMMIT).
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/scripts/rollback/263_rollback.sql
--
-- ISI ROLLBACK (2 hal, keduanya wajib)
--   1. Body fungsi dikembalikan ke PRE-IMAGE byte-exact. Pre-image diambil
--      dari pg_get_functiondef(oid) LIVE sebelum 263 diterapkan dan disimpan
--      ke .agents/logs/fix14-263-preimage-functiondef.sql
--        md5(pg_get_functiondef) = 6c0fb3d3ca5a10e2f789f295790d33c7
--        length                  = 547
--        CRLF                     = 0 (LF saja)
--      Verifikasi byte-identik ada di laporan turn draft (bagian D).
--   2. GRANT EXECUTE ke authenticated dicabut, mengembalikan ACL ke
--      pre-263 = {postgres=X/postgres, service_role=X/postgres}.
--
-- CATATAN: mencabut grant mengembalikan 6 policy RLS ke kondisi PRE-263,
-- yaitu error 42501 untuk semua role authenticated (lihat blok MASALAH 2
-- di header 263). Itu memang restore yang jujur — kalau sistem ini memang
-- butuh policy itu hidup, JANGAN rollback 263; perbaiki forward.
--
-- Idempoten: jalan kedua kali tidak mengubah apa pun (CREATE OR REPLACE
-- dengan body yang sama + REVOKE yang sama), tidak error.
-- ============================================================================

BEGIN;

-- (1) Body pre-263, byte-exact dari pre-image.
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
$function$;

-- (2) Cabut grant yang ditambahkan 263.
REVOKE EXECUTE ON FUNCTION public.is_admin_or_owner() FROM authenticated;

COMMIT;