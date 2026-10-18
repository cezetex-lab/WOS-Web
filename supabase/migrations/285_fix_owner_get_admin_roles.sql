-- ============================================================================
-- 285 — Fix P2-F14-CA: owner_get_admin_roles() error 42803 pada cabang owner.
--
-- Bug (ditemukan saat audit P1-TABLE-AUDIT 2026-10-18, BUKAN akibat RLS):
--   RETURN (SELECT COALESCE(jsonb_agg(jsonb_build_object(...)), '[]')
--           FROM admin_roles ar
--           ORDER BY ar.role_code);          -- ← ORDER BY di luar agregat
--   Di dalam `RETURN (SELECT …)` plpgsql, ORDER BY tsb membuat seluruh kolom
--   `ar.*` wajib ada di GROUP BY → 42803 untuk SEMUA baris:
--     ERROR: column "ar.role_code" must appear in the GROUP BY clause
--            or be used in an aggregate function
--
-- Bukti RED (.agents/logs/m285-red.log, tx ROLLBACK):
--   * authenticated + owner JWT → 42803 (cabang owner dieksekusi)
--   * postgres tanpa JWT        → LOLOS (ambil cabang non-owner, bukan bug RLS)
--   Konsumen `src/pages/OwnerDashboard.tsx:330` menelan error via try/catch →
--   tab Access menampilkan "Tidak ada admin role" secara senyap.
--
-- Fix: ORDER BY dipindah KE DALAM jsonb_agg(... ORDER BY ar.role_code) —
--   perubahan sintaks murni. Gate authz (`get_current_user_context()` +
--   `check_owner_identity()`), return shape JSONB array, signature, SECURITY
--   DEFINER, VOLATILE, dan SET search_path TIDAK berubah.
--
-- Pre-image (byte-exact, md5 prosrc 694785d0c4e6744725a09e5e29e588fd, 676 B):
--   supabase/scripts/rollback/285_rollback.sql (.agents/logs/m285-preimage.sql).
-- P4: tanpa BEGIN/COMMIT — wrapper apply-migration.mjs memegang transaksi.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.owner_get_admin_roles()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE v_ctx JSONB := get_current_user_context();
BEGIN
  IF v_ctx IS NULL OR NOT check_owner_identity() THEN
    RETURN '[]'::JSONB;
  END IF;
  RETURN (
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'id', ar.id,
      'role_code', ar.role_code,
      'role_name', ar.role_name,
      'scope_type', ar.scope_type,
      'scope_id', ar.scope_id,
      'permissions', ar.permissions,
      'can_manage_users', ar.can_manage_users,
      'can_manage_modules', ar.can_manage_modules,
      'is_active', ar.is_active,
      'created_at', ar.created_at,
      'created_by', ar.created_by
    ) ORDER BY ar.role_code), '[]'::JSONB)
    FROM admin_roles ar
  );
END;
$function$;
