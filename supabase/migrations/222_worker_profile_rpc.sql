-- ================================================================
-- 222_worker_profile_rpc.sql — Worker self-service profile RPC
--
-- - get_worker_profile(p_nrp)
-- - worker_update_profile(...)
--
-- Rules:
-- - SECURITY DEFINER + SET search_path = public, extensions
-- - authz_current_nrp() used for identity; no client-trusted params
-- - worker may update only their own row
-- - allowed editable fields are explicit; others are ignored
-- ================================================================

-- ================================================================
-- 1. READ: get_worker_profile
-- ================================================================

CREATE OR REPLACE FUNCTION public.get_worker_profile(p_nrp text)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_caller text := authz_current_nrp();
  v_owner boolean := EXISTS (
    SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = TRUE
  );
BEGIN
  IF v_caller IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Sesi tidak valid');
  END IF;

  IF v_caller <> p_nrp AND NOT v_owner THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak');
  END IF;

  RETURN COALESCE((
    SELECT jsonb_build_object(
      'ok', true,
      'data', jsonb_build_object(
        'nrp', c.nrp,
        'nik', c.nik,
        'nama', c.nama,
        'email', c.email,
        'no_hp', e.no_hp,
        'alamat', e.alamat,
        'divisi', c.divisi,
        'posisi', c.posisi,
        'status_kerja', c.status_kerja,
        'tanggal_masuk', c.tanggal_masuk,
        'tanggal_lahir', e.tanggal_lahir,
        'jenis_kelamin', e.jenis_kelamin,
        'atasan_nrp', NULL,
        'agama', e.agama,
        'media_sosial', e.media_sosial,
        'jenjang_pendidikan', e.jenjang_pendidikan,
        'no_bpjs_kesehatan', e.no_bpjs_kesehatan,
        'no_bpjs_ketenagakerjaan', e.no_bpjs_ketenagakerjaan,
        'riwayat_penyakit', e.riwayat_penyakit,
        'komorbid', e.komorbid,
        'alergi', e.alergi,
        'nama_bank', e.nama_bank,
        'no_rekening', e.no_rekening,
        'nama_rekening', e.nama_rekening,
        'lokasi_penempatan', c.lokasi_penempatan,
        'updated_by', c.updated_by,
        'status_kerja_internal', c.status_kerja_internal
      )
    )
    FROM employees_core c
    LEFT JOIN employees_extended e ON e.nrp = c.nrp
    WHERE c.nrp = p_nrp
  ), jsonb_build_object('ok', false, 'msg', 'Data tidak ditemukan'));
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_worker_profile(text) TO authenticated;


-- ================================================================
-- 2. WRITE: worker_update_profile
-- ================================================================

CREATE OR REPLACE FUNCTION public.worker_update_profile(
  p_nrp text,
  p_no_hp text DEFAULT NULL,
  p_alamat text DEFAULT NULL,
  p_agama text DEFAULT NULL,
  p_media_sosial jsonb DEFAULT NULL,
  p_jenjang_pendidikan text DEFAULT NULL,
  p_no_bpjs_kesehatan text DEFAULT NULL,
  p_no_bpjs_ketenagakerjaan text DEFAULT NULL,
  p_riwayat_penyakit text DEFAULT NULL,
  p_komorbid text DEFAULT NULL,
  p_alergi text DEFAULT NULL,
  p_nama_bank text DEFAULT NULL,
  p_no_rekening text DEFAULT NULL,
  p_nama_rekening text DEFAULT NULL,
  p_lokasi_penempatan text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_caller text := authz_current_nrp();
  v_owner boolean := EXISTS (
    SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = TRUE
  );
BEGIN
  IF v_caller IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Sesi tidak valid');
  END IF;

  IF v_caller <> p_nrp AND NOT v_owner THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akses ditolak');
  END IF;

  UPDATE employees_core
  SET
    lokasi_penempatan = COALESCE(p_lokasi_penempatan, lokasi_penempatan),
    updated_by = v_caller,
    updated_at = NOW()
  WHERE nrp = p_nrp;

  UPDATE employees_extended
  SET
    no_hp = COALESCE(p_no_hp, no_hp),
    alamat = COALESCE(p_alamat, alamat),
    agama = COALESCE(p_agama, agama),
    media_sosial = COALESCE(p_media_sosial, media_sosial),
    jenjang_pendidikan = COALESCE(p_jenjang_pendidikan, jenjang_pendidikan),
    no_bpjs_kesehatan = COALESCE(p_no_bpjs_kesehatan, no_bpjs_kesehatan),
    no_bpjs_ketenagakerjaan = COALESCE(p_no_bpjs_ketenagakerjaan, no_bpjs_ketenagakerjaan),
    riwayat_penyakit = COALESCE(p_riwayat_penyakit, riwayat_penyakit),
    komorbid = COALESCE(p_komorbid, komorbid),
    alergi = COALESCE(p_alergi, alergi),
    nama_bank = COALESCE(p_nama_bank, nama_bank),
    no_rekening = COALESCE(p_no_rekening, no_rekening),
    nama_rekening = COALESCE(p_nama_rekening, nama_rekening)
  WHERE nrp = p_nrp;

  RETURN jsonb_build_object('ok', true, 'msg', 'Profil berhasil diperbarui');
END;
$function$;

GRANT EXECUTE ON FUNCTION public.worker_update_profile(
  text, text, text, text, jsonb, text, text, text, text, text, text, text, text, text, text
) TO authenticated;
