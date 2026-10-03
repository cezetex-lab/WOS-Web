-- ============================================================================
-- 264_rollback.sql — pulihkan check_admin_access (2 overload) yang di-DROP 264
--
-- Dijalankan MANUAL via psql (file ini punya BEGIN/COMMIT sendiri —
-- berbeda dari file migrasi yang P4-nya forbid BEGIN/COMMIT).
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/scripts/rollback/264_rollback.sql
--
-- ISI ROLLBACK
--   1. CREATE OR REPLACE kedua overload, body byte-exact dari pre-image.
--   2. Restore ACL. INI WAJIB, bukan opsional — lihat catatan di bawah.
--
-- PRE-IMAGE (pg_get_functiondef live, diambil 2026-10-03 sebelum 264,
--            disimpan .agents/logs/fix14-264-preimage-{noargs,p_path_text}.sql):
--
--   oid 298204  check_admin_access()
--     ret boolean · plpgsql · VOLATILE · SECURITY DEFINER
--     search_path=public, extensions · owner postgres
--     md5(pg_get_functiondef) = 0106fcb4584a0e06d9c3200c4dd2a1b2
--     md5(prosrc)            = 970bd74bb4b0c18a2357f559eef87f31
--     prosrc_len = 210
--
--   oid 298205  check_admin_access(p_path text)
--     ret jsonb · plpgsql · VOLATILE · SECURITY DEFINER
--     search_path=public, extensions · owner postgres
--     md5(pg_get_functiondef) = 5aeaa26ccbf17f928fe95c4a41aa457e
--     md5(prosrc)            = 0f0ce77ce4cc68a8b1ac9f66c400988c
--     prosrc_len = 2093
--
--   ACL pre-264 (keduanya identik) = {postgres=X/postgres, service_role=X/postgres}
--   → authenticated = TIDAK, anon = TIDAK
--
-- MENGAPA ACL HARUS DI-RESTORE EKSPLISIT
--   Default privilege untuk fungsi baru di PostgreSQL adalah EXECUTE untuk
--   owner **dan PUBLIC**. ACL pre-264 tidak mengandung PUBLIC, karena migrasi
--   172_me-revoke_ seluruhnya lalu grant hanya service_role. Kalau rollback
--   hanya CREATE OR REPLACE tanpa REVOKE, hasilnya proacl = {postgres=X/postgres,
--   =X/postgres} — artinya setiap role bisa memanggil fungsi SECURITY DEFINER ini
--   (role_page_access dan admin_roles ikut terekspos). Itu mengembalikan
--   security hole, bukan pre-image. Karena itu blok REVOKE + GRANT di bawah
--   adalah bagian dari definisi "byte-identik" untuk item ini, bukan hiasan.
--
-- Idempoten: CREATE OR REPLACE dengan body sama tidak mengubah apa pun;
-- REVOKE/GRANT juga idempoten. Jalankan kedua kali aman.
-- ============================================================================

BEGIN;

-- (1a) overload 0-arg — byte-exact dari pre-image
CREATE OR REPLACE FUNCTION public.check_admin_access()
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_role TEXT;
BEGIN
  v_role := COALESCE(
    current_setting('request.jwt.claims', true)::json->>'role',
    ''
  );
  RETURN v_role IN ('admin_pusat', 'admin_hrd', 'admin_finance', 'manager');
END;
$function$;

-- (1b) overload text-arg — byte-exact dari pre-image
CREATE OR REPLACE FUNCTION public.check_admin_access(p_path text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_role TEXT;
  v_is_owner BOOLEAN;
  v_result JSONB;
  v_scope_type TEXT;
  v_scope_id TEXT;
  v_permissions JSONB;
BEGIN
  -- 1. Owner bypass (identity-based)
  SELECT check_owner_identity() INTO v_is_owner;
  IF v_is_owner THEN
    RETURN jsonb_build_object('ok', TRUE, 'can_access', TRUE, 'can_action', TRUE, 'reason', 'owner_bypass');
  END IF;

  -- 2. Get user role from user_roles
  SELECT ur.role INTO v_role
  FROM user_roles ur
  WHERE ur.nrp = (SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1)
  ORDER BY ur.role_level DESC LIMIT 1;

  IF v_role IS NULL OR v_role = 'worker' THEN
    RETURN jsonb_build_object('ok', TRUE, 'can_access', FALSE, 'can_action', FALSE, 'reason', 'not_admin');
  END IF;

  -- 3. Look up dynamic admin role
  SELECT ar.scope_type, ar.scope_id, ar.permissions
  INTO v_scope_type, v_scope_id, v_permissions
  FROM admin_roles ar
  WHERE ar.role_code = v_role AND ar.is_active = TRUE;

  IF v_scope_type IS NULL THEN
    RETURN jsonb_build_object('ok', TRUE, 'can_access', FALSE, 'can_action', FALSE, 'reason', 'role_not_found');
  END IF;

  -- 4. Global scope
  IF v_scope_type = 'global' THEN
    IF p_path IN ('/admin/modules', '/admin/system-config', '/admin/access-control') THEN
      RETURN jsonb_build_object('ok', TRUE, 'can_access', FALSE, 'can_action', FALSE, 'reason', 'owner_only_feature');
    END IF;
    RETURN jsonb_build_object('ok', TRUE, 'can_access', TRUE, 'can_action', TRUE, 'reason', 'global_admin');
  END IF;

  -- 5. Function/Industry scope - check role_page_access table
  SELECT jsonb_build_object('ok', TRUE, 'can_access', rpa.can_access, 'can_action', rpa.can_action)
  INTO v_result
  FROM role_page_access rpa
  WHERE rpa.role_code = v_role AND (
    rpa.page_pattern = p_path
    OR (rpa.page_pattern LIKE '%/*' AND p_path LIKE REPLACE(rpa.page_pattern, '/*', '') || '%')
  )
  LIMIT 1;

  IF v_result IS NOT NULL THEN
    RETURN v_result;
  END IF;

  -- 6. Default: deny
  RETURN jsonb_build_object('ok', TRUE, 'can_access', FALSE, 'can_action', FALSE, 'reason', 'no_matching_rule');
END;
$function$;

-- (2) Restore ACL ke pre-264 = {postgres, service_role} (tanpa PUBLIC/anon/authenticated)
REVOKE EXECUTE ON FUNCTION public.check_admin_access() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.check_admin_access() FROM anon;
REVOKE EXECUTE ON FUNCTION public.check_admin_access() FROM authenticated;
GRANT  EXECUTE ON FUNCTION public.check_admin_access() TO service_role;

REVOKE EXECUTE ON FUNCTION public.check_admin_access(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.check_admin_access(text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.check_admin_access(text) FROM authenticated;
GRANT  EXECUTE ON FUNCTION public.check_admin_access(text) TO service_role;

COMMIT;