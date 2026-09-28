-- =============================================================================
-- 254 — Fix #5: channel reset password (admin|email) + UNIQUE email
-- =============================================================================
-- P1-46-01 — alur lupa-password tidak pernah kirim email. Pesan "link reset
-- sudah dikirim" bohong. Fix #5: pesan jujur via setting
-- 'password_reset_channel' (default 'admin'), siap switch ke 'email' nanti.
--
-- P1-74-01 — employees_core.email tanpa UNIQUE constraint. Data live:
-- 17/17 terisi, 0 NULL, 0 duplikat (raw & case-insensitive), semua lower+trim.
-- Aman langsung tambah UNIQUE.
--
-- Flag dibaca edge password-reset via adminClient (service_role, bypass RLS)
-- dari tabel public.settings (key text PK, value text). Tanpa policy SELECT —
-- sengaja, hanya service_role yang boleh baca.
-- =============================================================================

-- 1. Seed setting default: 'admin' (pesan jujur, jalur admin)
INSERT INTO public.settings (key, value)
VALUES ('password_reset_channel', 'admin')
ON CONFLICT (key) DO NOTHING;

-- 2. UNIQUE email (P1-74-01). 17/17 terisi, 0 duplikat — aman.
ALTER TABLE public.employees_core
  ADD CONSTRAINT employees_core_email_unique UNIQUE (email);
