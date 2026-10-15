-- P1-F05-01: ganti stub admin_get_employees() dengan data karyawan nyata.
--
-- ALASAN (gate wajib user):
--   Gate authz: authz_check_admin('employee.view_all') — pemegang: admin_pusat
--   (set admin_pusat_all) + owner (bypass di dalam authz_check_admin).
--   Pemegang sah → data; tanpa permission → DITOLAK FAIL-CLOSED. HRD TIDAK
--   diakses di sini (view_all dicabut via 272; evaluasi HRD lewat P2-F14-AR).
--
-- SHAPE KEPUTUSAN (terverifikasi ke konsumen):
--   Sukses → JSON ARRAY LANGSUNG (bukan {ok:true,data:[...]}): Employees.tsx:67
--   (useRpcQuery tanpa select/ok-check) melakukan .filter pada hasil — objek
--   non-array akan CRASH. ResetPassword.tsx:35 menerima array langsung juga.
--   Tolak → RAISE EXCEPTION SQLSTATE 42501, BUKAN {ok:false,msg} (bentuk itu
--   tidak memicu isRpcError → Employees terima objek → .filter crash). Exception
--   → rpc() laporkan error transport → useRpcQuery setData(defaultValue []) →
--   halaman tampil kosong tanpa crash (fail-closed yang anggun).
--
-- SIGNATURE: tambah param optional p_search DEFAULT NULL (mirror
--   owner_get_employees; dipakai uji kasus kosong). Pemanggil 0-arg lama
--   (Employees.tsx, ResetPassword.tsx, smoke baseline 175) tetap resolve.
--   Preseden DROP+CREATE fungsi ini ada di migrasi 038/139. OID BERUBAH
--   (298117 → baru): normal untuk DROP+CREATE (§ P13) — gate kunci signature.
--
-- IDEMPOTEN: DROP IF EXISTS + CREATE + verifikasi akhir (pola 272).

BEGIN;

DROP FUNCTION IF EXISTS public.admin_get_employees();

CREATE FUNCTION public.admin_get_employees(p_search text DEFAULT NULL)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_data JSONB;
BEGIN
  -- Gate fail-closed: pemegang employee.view_all = admin_pusat (+ owner bypass).
  -- Tolak = exception 42501 → konsumen dapat error transport → [] (lihat header).
  IF NOT authz_check_admin('employee.view_all') THEN
    RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501';
  END IF;

  SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::JSONB) INTO v_data
  FROM (
    SELECT
      em.nrp,
      em.nik,
      em.nama,
      em.email,
      em.no_hp,
      em.divisi,
      em.jabatan,
      em.status_kerja_internal AS jenis,
      CASE WHEN em.is_active THEN 'Aktif' ELSE 'Non-Aktif' END AS status,
      em.is_active,
      em.tanggal_masuk,
      em.contract_end_date AS tanggal_habis
    FROM employees_master em
    WHERE (p_search IS NULL
           OR em.nama ILIKE '%' || p_search || '%'
           OR em.nrp ILIKE '%' || p_search || '%'
           OR em.email ILIKE '%' || p_search || '%')
    ORDER BY em.nrp
  ) t;

  RETURN v_data;
END;
$function$;

-- ACL identik pre-image: postgres (owner, implisit) + authenticated + service_role.
-- PUBLIC & anon TIDAK boleh EXECUTE (fail-closed; konsisten prosrc 172 + 270).
REVOKE ALL ON FUNCTION public.admin_get_employees(p_search text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_get_employees(p_search text) TO authenticated, service_role;

-- Verifikasi kondisi akhir (pola 272): tepat satu fungsi ber-signature (p_search text),
-- nol fungsi 0-arg (stub lama benar-benar hilang, tidak jadi overload yatim).
DO $$
DECLARE
  v_new INT;
  v_old INT;
BEGIN
  SELECT count(*) INTO v_new
  FROM pg_proc
  WHERE proname = 'admin_get_employees'
    AND pg_get_function_identity_arguments(oid) = 'p_search text';
  IF v_new != 1 THEN
    RAISE EXCEPTION 'admin_get_employees(p_search text) harus tepat 1, ditemukan %', v_new;
  END IF;
  SELECT count(*) INTO v_old
  FROM pg_proc
  WHERE proname = 'admin_get_employees'
    AND pg_get_function_identity_arguments(oid) = '';
  IF v_old != 0 THEN
    RAISE EXCEPTION 'stub admin_get_employees() 0-arg masih ada (% baris)', v_old;
  END IF;
END $$;

COMMIT;
