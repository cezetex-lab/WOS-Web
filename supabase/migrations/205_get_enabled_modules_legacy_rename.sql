-- ================================================================
-- 205_get_enabled_modules_legacy_rename.sql
-- ================================================================
-- F-4 RESIDUE (verifikasi live 2026-09-13):
--   Overload legacy 0-arg get_enabled_modules() masih ada di DB —
--   SECURITY DEFINER TANPA SET search_path → pelanggaran Rule §6.3.
--   Frontend (DynamicRoutes.jsx) SELALU memanggil versi 1-arg (p_area),
--   jadi overload 0-arg tidak terpakai.
-- Aksi (ikuti Rule §6.4 — RENAME legacy, bukan DROP):
--   1. RENAME get_enabled_modules() → get_enabled_modules_legacy_noarg()
--   2. SET search_path (perbaiki pelanggaran §6.3)
--   3. REVOKE anon/PUBLIC (keep authenticated — fungsi fail-closed via
--      get_current_user_context() → '[]' jika ctx NULL)
-- ================================================================

ALTER FUNCTION public.get_enabled_modules()
  RENAME TO get_enabled_modules_legacy_noarg;

ALTER FUNCTION public.get_enabled_modules_legacy_noarg()
  SET search_path TO 'public', extensions;

REVOKE EXECUTE ON FUNCTION public.get_enabled_modules_legacy_noarg()
  FROM anon, PUBLIC;
