-- ════════════════════════════════════════════════════════════════════════════
-- 246_ops14_seed_user_role_assignments.sql — OPS-14 (P1, keputusan user 2026-09-24)
-- PREVIEW — BELUM DI-APPLY (menunggu §0.17 approval)
--
-- Masalah: `user_role_assignments` = 0 baris di live, padahal migration 135
-- (PART 3) sudah berisi INSERT...SELECT FROM user_roles untuk mengisi tabel ini.
-- 134 & 135 tercatat applied via "baseline install (schema dari DB live)"
-- 2026-09-22T01:01:46Z — baseline hanya mengambil SCHEMA, bukan DATA, sehingga efek
-- seed 135 tidak pernah hadir di live.
--
-- Akibat (semua authz engine v2 mati, bukan hanya 1 fitur):
--   authz_has_permission()  → FALSE utk semua (impact: admin_reset_worker_password
--                              DENIED "Akses ditolak" untuk semua role admin)
--   authz_in_scope()        → FALSE utk semua (impact: 105 RLS policy authz-v2 mati)
--   authz_has_role()         → FALSE utk semua
--
-- Fix: jalankan KEMBALI seed yang sama dengan 135 PART 3 (idempotent via ON CONFLICT).
-- TIDAK mengubah definisi fungsi, signature, RLS, atau data lain.
--
-- Dry-run 2026-09-24 (transaksi ROLLBACK, `.agents/scripts/ops14-dryrun.mjs`):
--   17 baris · admin_pusat & admin_hrd employee.update false→true · worker tetap false
--   · owner tetap true (bypass system_owner_identity) · ROLLBACK → live tetap 0 baris.
--
-- DI LUAR SCOPE (sengaja tidak dikerjakan, lapor ke user):
--   auth_id owner TIDAK punya baris employees_master (employees_master = VIEW di atas
--   employees_core) → authz_current_nrp() NULL → admin_reset_worker_password menolak
--   di `v_caller IS NULL` sebelum owner-bypass sempat dicek. Perbaikannya butuh
--   perubahan fungsi SECURITY DEFINER (bukan 1-liner) → keputusan desain user.
--
-- SISI TERBUKA (harus disadari): mengisi tabel ini MENYALAKAN gate yang selama ini
-- mati — 105 RLS policy + authz_has_permission. Ini memang desainnya, tapi dampaknya
-- harus diverifikasi (probe 3b) sebelum/selesai apply.
--
-- BAGIAN 1 (side-finding 1, disetujui user): permission set untuk
-- `admin_operasional` — satu-satunya role di `user_roles` yang TIDAK punya baris di
-- `role_permission_sets` (probe live: 10 role, 9 punya set). Dipetakan ke set yang
-- SUDAH ada, mengikuti `role_page_access` (migrasi 110): /admin/requests, /admin/leave,
-- /admin/overtime, /admin/shift-swap, /admin/assets.
-- SENGAJA TIDAK diberi employee.update/hrd_ops/admin_pusat_all: guard UI
-- ResetPassword.tsx hanya izinkan ["admin_pusat","admin_hrd"] → memberi hak reset
-- password ke admin_operasional = privilege escalation di luar kontrak aplikasi.
-- Catatan: timesheet.approve TIDAK dipetakan (butuh keputusan terpisah).
-- ════════════════════════════════════════════════════════════════════════════

-- CATATAN sequence: baseline install (2026-09-22) mengisi `role_permission_sets`
-- dengan id EXPLICIT tanpa Advance sequence → `role_permission_sets_id_seq` masih
-- last_value=1 padahal max(id)=26 (probe live 2026-09-24). Tanpa setval di bawah,
-- INSERT pertama bentrok "duplicate key value violates unique constraint
-- role_permission_sets_pkey" (terbukti pada percobaan apply pertama). Setval
-- idempoten (GREATEST max(id)) dan TIDAK menyentuh data.
SELECT setval('public.role_permission_sets_id_seq',
              GREATEST((SELECT COALESCE(MAX(id), 1) FROM public.role_permission_sets), 1));

INSERT INTO role_permission_sets (role_code, permission_set)
VALUES
  ('admin_operasional', 'worker_basic'),
  ('admin_operasional', 'supervisor_ext')
ON CONFLICT (role_code, permission_set) DO NOTHING;

-- BAGIAN 2: seed `user_role_assignments` (efek 135 PART 3 yang hilang).
-- admin_operasional tidak ada di CASE 135 → ELSE='SELF', padahal role_page_access-nya
-- lintas karyawan → dipaksa ENTERPRISE (sama seperti admin_hrd/admin_finance).
-- ════════════════════════════════════════════════════════════════════════════

INSERT INTO user_role_assignments (nrp, role_code, scope_type, scope_bu_id, is_primary)
SELECT
  ur.nrp,
  ur.role,
  CASE
    WHEN ur.role = 'worker' THEN 'SELF'
    WHEN ur.role IN ('admin_mining') THEN 'BU'
    WHEN ur.role IN ('admin_estate') THEN 'BU'
    WHEN ur.role IN ('admin_mill') THEN 'BU'
    WHEN ur.role IN ('admin_hrd', 'admin_finance', 'admin_produksi') THEN 'ENTERPRISE'
    WHEN ur.role = 'admin_pusat' THEN 'ENTERPRISE'
    WHEN ur.role = 'admin_operasional' THEN 'ENTERPRISE'
    ELSE 'SELF'
  END,
  COALESCE(em.business_unit_id, 'HQ'),
  TRUE
FROM user_roles ur
LEFT JOIN employees_master em ON em.nrp = ur.nrp
ON CONFLICT (nrp, role_code, scope_type, scope_bu_id) DO NOTHING;
