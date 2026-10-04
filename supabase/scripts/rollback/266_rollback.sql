-- ============================================================================
-- 266_rollback.sql — batalkan migrasi 266 (Fix #14 §9 batch 3/5,
-- rewiring get_user_context_by_auth_id + hapus UPDATE auth_id)
--
-- Dijalankan MANUAL via psql (file ini punya BEGIN/COMMIT sendiri — berbeda dari
-- file migrasi yang P4-nya forbid BEGIN/COMMIT).
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/scripts/rollback/266_rollback.sql
--
-- ISI ROLLBACK
--   1. Body fungsi dikembalikan ke PRE-IMAGE byte-exact (pg_get_functiondef LIVE
--      sebelum 266; salinan: .agents/logs/fix14-266-preimage-functiondef.sql)
--        md5(pg_get_functiondef) = 13afaf040b523095c789877aa1d190bc
--        md5(prosrc)             = 6a512421764f0c58ff5c5947fa7c5ecf
--        length(pg_get_functiondef) = 1666
--        length(prosrc)             = 1470
--      Termasuk blok UPDATE auth_id (auto-repair) yang 266 hapus.
--   2. ACL dikembalikan eksplisit ke pre-266 (defensif; CREATE OR REPLACE sudah
--      mempertahankan ACL, tapi ini mengunci kontrak):
--        REVOKE EXECUTE ... FROM PUBLIC            (no-op di pre-266)
--        GRANT  EXECUTE ... TO authenticated, service_role  (idempoten)
--
-- CATATAN: 266 tidak mengubah signature, tidak mengubah attrs. schema_migrations
-- tidak disentuh oleh file ini. Idempoten: jalan kedua kali tidak mengubah apa pun.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public.get_user_context_by_auth_id(p_auth_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE v_emp RECORD; v_role RECORD; v_bu RECORD; v_email TEXT;
BEGIN
  SELECT email INTO v_email FROM auth.users WHERE id = p_auth_id;
  
  SELECT employee_id, nrp, nama, email, business_unit_id, role_level, divisi, posisi
  INTO v_emp FROM employees_master WHERE auth_id = p_auth_id LIMIT 1;
  
  IF NOT FOUND AND v_email IS NOT NULL THEN
    SELECT employee_id, nrp, nama, email, business_unit_id, role_level, divisi, posisi
    INTO v_emp FROM employees_master
    WHERE LOWER(TRIM(email)) = LOWER(TRIM(v_email)) LIMIT 1;
    IF FOUND THEN
      UPDATE employees_master SET auth_id = p_auth_id WHERE nrp = v_emp.nrp;
    END IF;
  END IF;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akun tidak ditemukan. Email: ' || COALESCE(v_email, 'null'));
  END IF;

  SELECT role, role_level INTO v_role FROM user_roles WHERE nrp = v_emp.nrp LIMIT 1;
  SELECT tier, unit_name, unit_code INTO v_bu FROM business_units WHERE id = v_emp.business_unit_id;

  RETURN jsonb_build_object(
    'ok', true, 'nrp', v_emp.nrp, 'nama', v_emp.nama, 'email', v_emp.email,
    'role', COALESCE(v_role.role, 'worker'),
    'role_level', GREATEST(COALESCE(v_role.role_level, 1), COALESCE(v_emp.role_level, 1)),
    'business_unit_id', v_emp.business_unit_id,
    'business_unit_name', COALESCE(v_bu.unit_name, ''),
    'unit_code', COALESCE(v_bu.unit_code, 'HQ'),
    'tier', COALESCE(v_bu.tier, 0),
    'divisi', v_emp.divisi, 'jabatan', v_emp.posisi
  );
END;
$function$
;

-- (2) ACL pre-266 (defensif, idempoten).
REVOKE EXECUTE ON FUNCTION public.get_user_context_by_auth_id(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_user_context_by_auth_id(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_context_by_auth_id(uuid) TO service_role;

COMMIT;
