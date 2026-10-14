-- Cabut employee.view_all dari hrd_ops
-- Alasan: hierarki berjenjang akan dibangun; sementara hanya LV5
-- (admin_pusat) + owner yang boleh view_all.
-- HRD nanti dapat permission lebih sempit (item terpisah).
-- Idempotent: DELETE WHERE cocok → no-op kalau sudah tidak ada.

BEGIN;

DELETE FROM public.permission_set_items
WHERE permission_set = 'hrd_ops'
  AND permission_code = 'employee.view_all';

-- Verifikasi kondisi akhir: hrd_ops TIDAK punya employee.view_all
DO $$
DECLARE v_count INT;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM public.permission_set_items
  WHERE permission_set = 'hrd_ops'
    AND permission_code = 'employee.view_all';
  IF v_count != 0 THEN
    RAISE EXCEPTION 'Cabut gagal: % baris masih ada', v_count;
  END IF;
END $$;

COMMIT;
