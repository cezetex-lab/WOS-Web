-- ============================================================================
-- 266 — Fix #14 §9 batch 3/5: rewiring get_user_context_by_auth_id()
--       (Work Queue P2-F14-S di sini; P2-F14-T = keputusan by-design,
--        didokumentasikan tanpa perubahan SQL)
--
-- KENAPA 266 INI ADA
--   Dua anomali pada get_user_context_by_auth_id(p_auth_id uuid):
--   (1) ia fungsi "get" tapi MENULIS: blok
--         IF FOUND THEN UPDATE employees_master SET auth_id = p_auth_id ... END IF;
--       → permukaan privilege escalation (SECURITY DEFINER, dipanggil lewat JWT
--       apa pun). Keputusan user B-1/S1: HAPUS.
--   (2) role dibaca dari user_roles.role — sumber LAMA. Sejak 261/262 sumber
--       kebenaran adalah user_role_assignments. Disamakan dengan 265 (hybrid).
--
-- PERUBAHAN (4 hunk, dibuktikan inverse proof di FASE E)
--   1. DECLARE: tambah `v_assign_role TEXT;`
--   2. Hapus blok `IF FOUND THEN UPDATE employees_master SET auth_id ...`
--   3. Tambah SELECT a.role_code INTO v_assign_role FROM user_role_assignments ...
--      setelah SELECT user_roles.
--   4. RETURN: role -> COALESCE(v_assign_role, v_role.role, 'worker')
--
-- YANG SENGAJA TIDAK BERUBAH
--   - role_level (GREATEST dari user_roles + employees_master) TETAP.
--   - divisi/jabatan TETAP di RETURN (field legitimate, hanya tidak dipakai UI).
--   - TIDAK ada owner bypass (keputusan user B-2/T2: owner lewat OwnerLogin;
--     by_auth_id tetap {"ok":false} untuk owner — by-design, bukan bug).
--   - Header/attrs: plpgsql, VOLATILE, SECURITY DEFINER, search_path — tidak disentuh.
--   - Signature `(p_auth_id uuid) -> jsonb` dan URUTAN key tidak berubah.
--
-- DAMPAK S1 (kenapa aman, dibuktikan FASE C)
--   - 1 auth.users tanpa employee link = owner (shadow, tanpa employee record);
--     jalur owner memang tidak lewat by_auth_id (T2).
--   - 0 baris employees_master yang email-nya match auth.users tapi auth_id beda
--     → jalur UPDATE itu TIDAK TERJANGKAU pada data sekarang.
--   - Fallback email pada baca tetap ada; yang hilang hanya efek tulis.
--
-- GRANT (defensif, P10)
--   ACL live sudah memuat authenticated; GRANT idempoten — mengunci kontrak
--   supaya tidak bisa lepas diam-diam. Tidak ada grant ke anon (fail-closed).
--
-- P4: file ini TIDAK BOLEH punya BEGIN/COMMIT — wrapper apply-migration.mjs
-- yang memegang transaksi.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_user_context_by_auth_id(p_auth_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE v_emp RECORD; v_role RECORD; v_bu RECORD; v_email TEXT; v_assign_role TEXT;
BEGIN
  SELECT email INTO v_email FROM auth.users WHERE id = p_auth_id;
  
  SELECT employee_id, nrp, nama, email, business_unit_id, role_level, divisi, posisi
  INTO v_emp FROM employees_master WHERE auth_id = p_auth_id LIMIT 1;
  
  IF NOT FOUND AND v_email IS NOT NULL THEN
    SELECT employee_id, nrp, nama, email, business_unit_id, role_level, divisi, posisi
    INTO v_emp FROM employees_master
    WHERE LOWER(TRIM(email)) = LOWER(TRIM(v_email)) LIMIT 1;
  END IF;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akun tidak ditemukan. Email: ' || COALESCE(v_email, 'null'));
  END IF;

  SELECT role, role_level INTO v_role FROM user_roles WHERE nrp = v_emp.nrp LIMIT 1;

  -- Fix #14 §9 batch 266: role dari user_role_assignments (sumber kebenaran
  -- sejak 261/262), fallback ke user_roles.role. role_level TETAP user_roles.
  SELECT a.role_code INTO v_assign_role
    FROM user_role_assignments a
   WHERE a.nrp = v_emp.nrp
   ORDER BY a.is_primary DESC NULLS LAST, a.role_code ASC
   LIMIT 1;

  SELECT tier, unit_name, unit_code INTO v_bu FROM business_units WHERE id = v_emp.business_unit_id;

  RETURN jsonb_build_object(
    'ok', true, 'nrp', v_emp.nrp, 'nama', v_emp.nama, 'email', v_emp.email,
    'role', COALESCE(v_assign_role, v_role.role, 'worker'),
    'role_level', GREATEST(COALESCE(v_role.role_level, 1), COALESCE(v_emp.role_level, 1)),
    'business_unit_id', v_emp.business_unit_id,
    'business_unit_name', COALESCE(v_bu.unit_name, ''),
    'unit_code', COALESCE(v_bu.unit_code, 'HQ'),
    'tier', COALESCE(v_bu.tier, 0),
    'divisi', v_emp.divisi, 'jabatan', v_emp.posisi
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_user_context_by_auth_id(uuid) TO authenticated;
