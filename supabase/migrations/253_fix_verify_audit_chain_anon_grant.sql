-- =============================================================================
-- 253 — Opsi A: cabut grant anon/PUBLIC dari verify_audit_chain (P1-58-01)
-- =============================================================================
-- KONTEKS:
--   Migrasi 252 menambah parameter p_mode sehingga `verify_audit_chain` menjadi
--   fungsi dengan signature 3-argumen, OID 330584. Fungsi BARU di Supabase
--   otomatis mendapat EXECUTE dari PUBLIC lewat default privileges
--   (`proacl = NULL`), jadi anon bisa memanggilnya.
--
--   Ini kelas masalah yang P1-58-01 sudah tutup untuk RPC PENULIS: default
--   privilege Supabase memberi EXECUTE ke anon untuk setiap fungsi baru, dan
--   tanpa REVOKE eksplisit privilege itu ikut terbuka. Kita tidak mau membuka
--   celah yang sama dua kali untuk hal yang sama.
--
--   RISIKO TERUKUR (2026-09-27, diverifikasi ke live):
--   * `grep verify_audit_chain` di `src/` → **0 hit**. Tidak ada aplikasi,
--     RPC, edge function, atau runner baseline yang memanggilnya, jadi
--     pencabutan TIDAK merusak behavior apa pun.
--   * Fungsi ini read-only: mengembalikan (issue_type, row_id, detail) —
--     hanya memberi tahu baris mana yang gagal verifikasi hash, bukan isi data.
--   * Jadi severity-nya rendah; tetap dipakai REVOKE supaya privilege tidak
--     tumbuh diam-diam setiap kali ada fungsi baru.
--
-- CATATAN ANOMALI (follow-up, bukan blocker):
--   Overload lama `verify_audit_chain(integer, integer)` (OID 298611) tidak
--   lagi ada setelah 252, padahal tidak ada DROP FUNCTION di migrasi mana pun
--   dan tidak ada caller-nya. Penyebabnya belum teridentifikasi; dampaknya nol
--   karena 0 caller. Dicatat sebagai P3 di Work Queue.
-- =============================================================================

REVOKE EXECUTE ON FUNCTION public.verify_audit_chain(integer, integer, text)
  FROM anon, PUBLIC;

-- Yang boleh memanggil: sudah login, atau mesin (service_role).
-- authenticated & service_role tetap punya akses penuh ke audit.
GRANT EXECUTE ON FUNCTION public.verify_audit_chain(integer, integer, text)
  TO authenticated, service_role;
