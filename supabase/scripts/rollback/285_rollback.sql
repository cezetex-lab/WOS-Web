-- ============================================================================
-- ROLLBACK migrasi 285 (P2-F14-CA) — kembalikan owner_get_admin_roles()
-- ke pre-image byte-exact: md5(prosrc) = 694785d0c4e6744725a09e5e29e588fd
-- (676 byte), diambil dari live sebelum 285 (.agents/logs/m285-preimage.sql).
--
-- Isi = definisi lama apa adanya (bug 42803 ada lagi setelah rollback — itu
-- memang tujuannya). Signature, SECURITY DEFINER, VOLATILE, SET search_path,
-- dan ACL tidak berubah karena CREATE OR REPLACE mempertahankan oid + ACL.
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
    )), '[]'::JSONB)
    FROM admin_roles ar
    ORDER BY ar.role_code
  );
END;
$function$;
