-- ============================================================
-- 004_seed_passwords.sql
-- Seed default passwords untuk semua 30 pekerja
-- Default password: Password123
-- Run in Supabase SQL Editor
-- ============================================================

INSERT INTO worker_passwords (nrp, password_hash, salt, is_active)
VALUES
  ('NRP001', 'Password123', '', true),
  ('NRP002', 'Password123', '', true),
  ('NRP003', 'Password123', '', true),
  ('NRP004', 'Password123', '', true),
  ('NRP005', 'Password123', '', true),
  ('NRP006', 'Password123', '', true),
  ('NRP007', 'Password123', '', true),
  ('NRP008', 'Password123', '', true),
  ('NRP009', 'Password123', '', true),
  ('NRP010', 'Password123', '', true),
  ('NRP011', 'Password123', '', true),
  ('NRP012', 'Password123', '', true),
  ('NRP013', 'Password123', '', true),
  ('NRP014', 'Password123', '', true),
  ('NRP015', 'Password123', '', true),
  ('NRP016', 'Password123', '', true),
  ('NRP017', 'Password123', '', true),
  ('NRP018', 'Password123', '', true),
  ('NRP019', 'Password123', '', true),
  ('NRP020', 'Password123', '', true),
  ('NRP021', 'Password123', '', true),
  ('NRP022', 'Password123', '', true),
  ('NRP023', 'Password123', '', true),
  ('NRP024', 'Password123', '', true),
  ('NRP025', 'Password123', '', true),
  ('NRP026', 'Password123', '', true),
  ('NRP027', 'Password123', '', true),
  ('NRP028', 'Password123', '', true),
  ('NRP029', 'Password123', '', true),
  ('NRP030', 'Password123', '', true)
ON CONFLICT (nrp) DO UPDATE SET
  password_hash = 'Password123',
  salt = '',
  is_active = true,
  attempts = 0,
  blocked_until = NULL;
