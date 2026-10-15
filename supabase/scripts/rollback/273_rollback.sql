-- Rollback P1-F05-01 (migrasi 273): kembalikan stub admin_get_employees() BYTE-IDENTIK
-- dengan pre-image (oid 298117, def_len 399, md5_def a083780957e0da890d3490115c46c3ad).
--
-- URUTAN WAJIB:
--   1) DROP fungsi baru (signature p_search text) LEBIH DULU. CREATE OR REPLACE
--      dengan signature 0-arg tidak bisa menimpa fungsi ber-signature beda —
--      kalau urutan terbalik, stub 0-arg menjadi OVERLOAD yatim di samping
--      fungsi (p_search) yang tetap hidup → pemanggil 0-arg justru bisa
--      ambigu/resolve ke stub (defeat the fix).
--   2) CREATE pre-image VERBATIM (teks di bawah = pg_get_functiondef live
--      hasil capture .agents/logs/f0501-preimage-def.sql).
--   3) GRANT/REVOKE eksplisit: DROP menghapus ACL, dan default fungsi baru
--      adalah EXECUTE untuk PUBLIC → proacl {postgres,authenticated,service_role}
--      pre-image harus direstore eksplisit (pelajaran P12 — ACL bagian dari
--      "byte-identik").

BEGIN;

DROP FUNCTION IF EXISTS public.admin_get_employees(p_search text);

CREATE OR REPLACE FUNCTION public.admin_get_employees()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  IF NOT authz_check_admin('employee.view_all') THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'RPC executed with role check.');
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_get_employees() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_get_employees() TO authenticated, service_role;

COMMIT;
