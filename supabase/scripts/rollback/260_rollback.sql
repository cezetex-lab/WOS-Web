-- Rollback 260 — kembalikan 3 baris role_permission_sets admin_produksi.
-- Dijalankan MANUAL via psql (file rollback WAJIB punya BEGIN/COMMIT sendiri).
--
-- Pre-image (probe B2.33, diambil LANGSUNG dari server lewat created_at::text):
--   id 14 | admin_produksi | worker_basic    | 2026-09-04 10:00:41.03652+00
--   id 15 | admin_produksi | supervisor_ext  | 2026-09-04 10:00:41.03652+00
--   id 16 | admin_produksi | manager_ext     | 2026-09-04 10:00:41.03652+00
--
-- PENTING — presisi 6 digit (datetime_precision = 6). Nilai aslinya adalah
-- 10:00:41.036**520**, BUKAN 10:00:41.036. Driver pg memotong tampilan ke
-- 3 digit desimal, jadi probe pertama salah baca dan rollback versi pertama
-- hanya menulis .036. Akibatnya hash tabel tidak byte-identik (selisih 2 digit
-- mikrodetik). Simulations menangkapnya, jadi nilainya di bawah ditulis 6 digit.
--
-- created_at ditulis eksplisit (bukan DEFAULT now()) supaya rollback
-- mengembalikan byte-identik, bukan "waktu rollback".
--
-- ON CONFLICT DO NOTHING menutup PK (id) dan UNIQUE (role_code, permission_set),
-- jadi rollback yang dijalankan dua kali tidak menggandakan data.
--
-- CATATAN: id 14/15/16 tidak dipakai baris lain (28 baris, id 1-28 unik) dan
-- sequence role_permission_sets_id_seq sudah last_value=28, jadi INSERT eksplisit
-- id 14-16 tidak membuat sequence bentrok.

BEGIN;

INSERT INTO role_permission_sets (id, role_code, permission_set, created_at)
VALUES
  (14, 'admin_produksi', 'worker_basic',   '2026-09-04 10:00:41.036520+00'::timestamptz),
  (15, 'admin_produksi', 'supervisor_ext', '2026-09-04 10:00:41.036520+00'::timestamptz),
  (16, 'admin_produksi', 'manager_ext',    '2026-09-04 10:00:41.036520+00'::timestamptz)
ON CONFLICT DO NOTHING;

COMMIT;
