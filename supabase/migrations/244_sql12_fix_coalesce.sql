-- 244_sql12_fix_coalesce.sql
-- SQL-12 — perbaiki `worker_update_profile` agar field BISA dikosongkan lewat UI.
--
-- Bug (terverifikasi 2026-09-20, smoke OPS-01): pola lama `COALESCE(p_param, kolom)`
-- menafsirkan NULL = "jangan ubah", padahal UI mengonversi string kosong '' → null
-- sebelum mengirim, sehingga sekali field terisi (mis. agama) worker tidak pernah
-- bisa mengosongkannya.
--
-- Semantik BARU (keputusan user: Opsi D):
--   NULL  = jangan ubah   (kompatibel mundur dengan pemanggil lama)
--   ''    = kosongkan     (set kolom ke NULL)
-- SIGNATURE TIDAK BERUBAH — identik 1:1 dengan live (15 arg, default sama),
-- sehingga tidak ada breaking change (G3: pemakai = wrapper `rpcWorkerUpdateProfile`
-- + `WorkerProfile.tsx` saja; UI disesuaikan agar kirim '' apa adanya).
--
-- Khusus `p_media_sosial` (jsonb): UI mengirim string; PostgREST membungkusnya
-- menjadi skalar jsonb, jadi string kosong sampai sebagai `""` (jsonb string
-- kosong — DUA tanda kutip; CATATAN: `''::jsonb` BUKAN JSON valid dan membuat
-- seluruh fungsi gagal "invalid input syntax for type json" — bug versi pertama
-- migrasi ini, diperbaiki ke `'""'::jsonb`).
-- Idempoten: CREATE OR REPLACE + semantik deterministik — re-run = hasil sama.

CREATE OR REPLACE FUNCTION public.worker_update_profile(
  p_nrp text,
  p_no_hp text DEFAULT NULL::text,
  p_alamat text DEFAULT NULL::text,
  p_agama text DEFAULT NULL::text,
  p_media_sosial jsonb DEFAULT NULL::jsonb,
  p_jenjang_pendidikan text DEFAULT NULL::text,
  p_no_bpjs_kesehatan text DEFAULT NULL::text,
  p_no_bpjs_ketenagakerjaan text DEFAULT NULL::text,
  p_riwayat_penyakit text DEFAULT NULL::text,
  p_komorbid text DEFAULT NULL::text,
  p_alergi text DEFAULT NULL::text,
  p_nama_bank text DEFAULT NULL::text,
  p_no_rekening text DEFAULT NULL::text,
  p_nama_rekening text DEFAULT NULL::text,
  p_lokasi_penempatan text DEFAULT NULL::text
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
    lokasi_penempatan = CASE
      WHEN p_lokasi_penempatan = '' THEN NULL          -- worker kirim '' = kosongkan
      ELSE COALESCE(p_lokasi_penempatan, lokasi_penempatan)  -- NULL = jangan ubah
    END,
    updated_by = v_caller,
    updated_at = NOW()
  WHERE nrp = p_nrp;

  UPDATE employees_extended
  SET
    no_hp = CASE WHEN p_no_hp = '' THEN NULL ELSE COALESCE(p_no_hp, no_hp) END,
    alamat = CASE WHEN p_alamat = '' THEN NULL ELSE COALESCE(p_alamat, alamat) END,
    agama = CASE WHEN p_agama = '' THEN NULL ELSE COALESCE(p_agama, agama) END,
    media_sosial = CASE
      WHEN p_media_sosial IS NULL THEN media_sosial    -- NULL = jangan ubah
      WHEN p_media_sosial = '""'::jsonb THEN NULL      -- skalar jsonb "" = kosongkan
      ELSE p_media_sosial
    END,
    jenjang_pendidikan = CASE WHEN p_jenjang_pendidikan = '' THEN NULL ELSE COALESCE(p_jenjang_pendidikan, jenjang_pendidikan) END,
    no_bpjs_kesehatan = CASE WHEN p_no_bpjs_kesehatan = '' THEN NULL ELSE COALESCE(p_no_bpjs_kesehatan, no_bpjs_kesehatan) END,
    no_bpjs_ketenagakerjaan = CASE WHEN p_no_bpjs_ketenagakerjaan = '' THEN NULL ELSE COALESCE(p_no_bpjs_ketenagakerjaan, no_bpjs_ketenagakerjaan) END,
    riwayat_penyakit = CASE WHEN p_riwayat_penyakit = '' THEN NULL ELSE COALESCE(p_riwayat_penyakit, riwayat_penyakit) END,
    komorbid = CASE WHEN p_komorbid = '' THEN NULL ELSE COALESCE(p_komorbid, komorbid) END,
    alergi = CASE WHEN p_alergi = '' THEN NULL ELSE COALESCE(p_alergi, alergi) END,
    nama_bank = CASE WHEN p_nama_bank = '' THEN NULL ELSE COALESCE(p_nama_bank, nama_bank) END,
    no_rekening = CASE WHEN p_no_rekening = '' THEN NULL ELSE COALESCE(p_no_rekening, no_rekening) END,
    nama_rekening = CASE WHEN p_nama_rekening = '' THEN NULL ELSE COALESCE(p_nama_rekening, nama_rekening) END
  WHERE nrp = p_nrp;

  RETURN jsonb_build_object('ok', true, 'msg', 'Profil berhasil diperbarui');
END;
$function$;
