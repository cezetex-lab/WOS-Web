-- ============================================================================
-- 265 — Fix #14 §9 batch 2/5: rewiring get_current_user_context()
--       (Work Queue P2-F14-S — didaftarkan saat apply)
--
-- KENAPA 265 INI ADA
--   Sejak 261/262, sumber kebenaran role admin adalah user_role_assignments
--   (FK fk_ura_role_code -> role_codes + fk_ur_role). Tapi get_current_user_context()
--   masih membaca role dari user_roles.role — sumber LAMA. Dua fungsi ini harus
--   memakai sumber yang sama supaya kontrak §9 konsisten.
--
-- PERUBAHAN (3 hunk, tidak ada yang lain — dibuktikan inverse proof di FASE D)
--   1. DECLARE: tambah `v_assign_role TEXT;`
--   2. Setelah SELECT user_roles: SELECT a.role_code INTO v_assign_role
--      FROM user_role_assignments a WHERE a.nrp = v_emp.nrp
--      ORDER BY a.is_primary DESC NULLS LAST, a.role_code ASC LIMIT 1;
--   3. RETURN: role -> COALESCE(v_assign_role, v_role.role, worker)
--
-- YANG SENGAJA TIDAK BERUBAH
--   - role_level TETAP dari user_roles (user_role_assignments tidak punya kolom level).
--   - Owner bypass check_owner_identity() DIPERTAHANKAN apa adanya.
--   - Signature `() -> jsonb`, return shape, dan URUTAN key tidak berubah.
--   - Attrs: plpgsql, VOLATILE, SECURITY DEFINER, search_path — tidak disentuh.
--   - Anomali B-1/B-2/B-3 di get_user_context_by_auth_id TIDAK disentuh (batch 266).
--
-- KENAPA NETRAL (dibuktikan FASE E)
--   - 17/17 baris user_role_assignments.role_code identik dengan user_roles.role.
--   - 0 user dengan lebih dari satu assignment -> ORDER BY deterministik.
--   - 0 user_roles tanpa assignment dan 0 assignment tanpa user_roles.
--   Karena itu COALESCE(v_assign_role, v_role.role, worker) menghasilkan nilai
--   yang sama untuk SEMUA 17 user; 8 kasus baseline byte-identik pre vs post.
--
-- GRANT (defensif, P10)
--   Setiap helper SECURITY DEFINER yang dipanggil policy RLS WAJIB punya EXECUTE
--   untuk role yang di-shadow. ACL live sudah memuat authenticated; GRANT ini
--   idempoten dan hanya mengunci kontrak supaya tidak bisa lepas diam-diam.
--   Tidak ada grant ke anon — fail-closed untuk JWT kosong.
--
-- P4: file ini TIDAK BOLEH punya BEGIN/COMMIT — wrapper apply-migration.mjs
-- yang memegang transaksi.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_current_user_context()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  v_emp RECORD;
  v_role RECORD;
  v_is_owner BOOLEAN;
  v_assign_role TEXT;
BEGIN
  IF v_uid IS NULL THEN RETURN NULL; END IF;

  -- Check Owner identity (NOT role-based)
  SELECT check_owner_identity() INTO v_is_owner;

  IF v_is_owner THEN
    RETURN jsonb_build_object(
      'nrp', 'OWNER001',
      'nama', 'System Owner',
      'role', 'owner',
      'role_level', 5,
      'is_owner', TRUE,
      'business_unit_id', NULL,
      'email', (SELECT email FROM auth.users WHERE id = v_uid LIMIT 1)
    );
  END IF;

  -- Regular employee lookup
  SELECT * INTO v_emp FROM employees_master WHERE auth_id = v_uid LIMIT 1;
  IF v_emp IS NULL THEN RETURN NULL; END IF;

  SELECT * INTO v_role FROM user_roles WHERE nrp = v_emp.nrp LIMIT 1;

  -- Fix #14 §9 batch 265: role diambil dari user_role_assignments
  -- (sumber kebenaran baru), fallback ke user_roles.role.
  -- role_level TETAP dari user_roles — assignment tidak punya kolom level.
  SELECT a.role_code INTO v_assign_role
    FROM user_role_assignments a
   WHERE a.nrp = v_emp.nrp
   ORDER BY a.is_primary DESC NULLS LAST, a.role_code ASC
   LIMIT 1;

  RETURN jsonb_build_object(
    'nrp', v_emp.nrp,
    'nama', v_emp.nama,
    'role', COALESCE(v_assign_role, v_role.role, 'worker'),
    'role_level', COALESCE(v_role.role_level, 1),
    'is_owner', FALSE,
    'business_unit_id', v_emp.business_unit_id,
    'email', v_emp.email
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_current_user_context() TO authenticated;
