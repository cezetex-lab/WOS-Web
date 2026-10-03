-- ============================================================================
-- 261 — Fix #14 §L2: master table role_codes
--
-- TUJUAN
--   Satu sumber kebenaran untuk nilai role_code. Sebelumnya role_code tersebar
--   di 5 tabel tanpa constraint silang, sehingga role_typo bisa masuk lewat
--   RPC apa pun (Work Queue P2-F14-L, dibaca 2026-10-02).
--
-- KONTEKS VERIFIKASI (probe read-only 2026-10-02, log:
-- .agents/logs/fix14-b236-konfirmasi-role.log)
--   - 10 role_code Distinct dari 5 sumber (user_roles, user_role_assignments,
--     admin_roles, role_permission_sets, role_page_access).
--   - CHECK lama `user_roles_role_check` punya 13 elemen; 3 di antaranya
--     TIDAK ada di 5 sumber: 'admin', 'director', 'owner'.
--   - Pre-image CHECK: length=283, md5(pg_get_constraintdef)=bd4d0ad49d6c587a6b0f21a92434da12
--
-- KEPUTUSAN USER (2026-10-02)
--   - Seed SEMUA role sah: 10 aktif + 3 reservasi.
--   - is_active=false = METADATA untuk UI/docs, BUKAN gate runtime.
--     Gate tetap rantai authz_has_permission -> role_permission_sets.
--   - CHECK user_roles_role_check DIHAPUS, diganti FK ke role_codes.
--   - §10 J1 (rename NRP001 -> 'ceo') hanya perlu INSERT 'ceo' ke tabel ini
--     + UPDATE user_roles; tidak perlu ALTER constraint lagi.
--
-- CATATAN PENTING SOAL URUTAN
--   FK ditambahkan LEBIH DAHULU, CHECK baru di-DROP setelahnya. Kalau urutannya
--   dibalik dan add FK gagal, tabel user_roles akan tertinggal tanpa validasi
--   sama sekali (fail-open di tengah migrasi).
--
-- P4: file ini TIDAK BOLEH punya BEGIN/COMMIT — wrapper apply-migration.mjs
--     yang membungkus dalam satu transaksi.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Tabel master
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS role_codes (
  code        text PRIMARY KEY,
  is_active   boolean NOT NULL DEFAULT true,
  catatan     text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE role_codes IS
  'Fix #14 §L2 — master daftar role_code. FK menggantikan CHECK user_roles_role_check. '
  'is_active = metadata (UI/docs), bukan gate runtime.';
COMMENT ON COLUMN role_codes.is_active IS
  'true = role dipakai di data live; false = reservasi (owner/director/admin/ceo).';

-- ---------------------------------------------------------------------------
-- 2. Seed — idempoten
--    10 role aktif (dari 5 sumber) + 3 reservasi (dari CHECK lama, tanpa data)
-- ---------------------------------------------------------------------------
INSERT INTO role_codes (code, is_active, catatan) VALUES
  -- 10 AKTIF — ada di data live
  ('admin_estate',      true,  'aktif dari 5 sumber data (semua admin_* punya baris)'),
  ('admin_finance',     true,  'aktif dari 5 sumber data'),
  ('admin_hrd',         true,  'aktif dari 5 sumber data'),
  ('admin_mill',        true,  'aktif dari 5 sumber data'),
  ('admin_mining',      true,  'aktif dari 5 sumber data'),
  ('admin_operasional', true,  'aktif dari 5 sumber data'),
  ('admin_pusat',       true,  'aktif dari 5 sumber data; satu-satunya role dengan /admin/* true'),
  ('manager',           true,  'aktif dari 5 sumber data (role_permission_sets saja)'),
  ('supervisor',        true,  'aktif dari 5 sumber data (role_permission_sets saja)'),
  ('worker',            true,  'aktif dari 5 sumber data'),

  -- 3 RESERVASI — ada di CHECK lama, tidak ada di data live
  ('owner',             false, 'reservasi: identitas owner lewat system_owner_identity, bukan tabel role. Tidak di 5 sumber.'),
  ('director',          false, 'reservasi: level 4 belum ada pemilik. Tidak di 5 sumber.'),
  ('admin',             false, 'reservasi: generic admin, tidak ada baris di 5 sumber.')
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. FK dari user_role_assignments (Work Queue P2-F14-L — inti item ini)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'user_role_assignments'::regclass
      AND conname = 'fk_ura_role_code'
  ) THEN
    ALTER TABLE user_role_assignments
      ADD CONSTRAINT fk_ura_role_code
      FOREIGN KEY (role_code) REFERENCES role_codes(code);
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 4. FK dari user_roles — ditambahkan SEBELUM CHECK lama di-drop (fail-safe)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'user_roles'::regclass
      AND conname = 'fk_ur_role'
  ) THEN
    ALTER TABLE user_roles
      ADD CONSTRAINT fk_ur_role
      FOREIGN KEY (role) REFERENCES role_codes(code);
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 5. Hapus CHECK lama — hanya setelah FK siap (bagian dari item yang sama)
-- ---------------------------------------------------------------------------
ALTER TABLE user_roles DROP CONSTRAINT IF EXISTS user_roles_role_check;

-- ---------------------------------------------------------------------------
-- 6. Komentar FK untuk jejak audit
-- ---------------------------------------------------------------------------
COMMENT ON CONSTRAINT fk_ura_role_code ON user_role_assignments IS
  'Fix #14 §L2 — role_code harus ada di master role_codes.';
COMMENT ON CONSTRAINT fk_ur_role ON user_roles IS
  'Fix #14 §L2 — menggantikan CHECK user_roles_role_check (md5 bd4d0ad49d6c587a6b0f21a92434da12).';
