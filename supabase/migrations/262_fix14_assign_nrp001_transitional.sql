-- ============================================================================
-- 262 — Fix #14 §J3: assignment transisi NRP001
--
-- MASALAH
--   Rantai authz yang SUDAH LIVE hari ini tidak membaca user_roles:
--       authz_check_admin(perm)
--         -> authz_has_permission(perm)
--            -> JOIN user_role_assignments ura ON ura.nrp = authz_current_nrp()
--              JOIN role_permission_sets rps ON rps.role_code = ura.role_code
--              JOIN permission_set_items  psi ON psi.permission_set = rps.permission_set
--   NRP001 (CEO, role 'admin_pusat', level 5) TIDAK PUNYA baris di
--   user_role_assignments — sehingga secara teknis kehilangan 50 permission
--   termasuk employee.update, employee.view_all, leave.approve, payroll.process,
--   audit.view, dan 44 lainnya. Rantai ini juga menyentuh 15 policy RLS.
--
-- BUKTI (probe read-only + simulasi transaksi ROLLBACK 2026-10-02,
--        log .agents/logs/fix14-b235b-simulate-j3.log):
--   pre-J3 : authz_check_admin('employee.update') = false
--            authz_has_role('admin_pusat')         = false
--            authz_in_scope('NRP002')              = false
--   post-J3: ketiganya = true
--   INSERT 1 baris tidak crash: tidak ada CHECK, tidak ada FK, tidak ada
--   tabrakan UNIQUE (NRP001 belum punya baris). Trigger audit 257 menyala
--   dengan actor='NRP001'.
--
-- KEPUTUSAN USER (2026-10-02)
--   - J3 (assignment transisi) SEKARANG sebagai mitigasi §9.
--   - is_primary = FALSE karena ini assignment transisi, bukan definitif.
--   - J1 (rename penuh NRP001 -> role 'ceo') DITUNDA ke §10; saat itu baris
--     ini ikut dibersihkan.
--   - 'admin_pusat' tetap dipakai (§10 J1 belum berjalan) sesuai keputusan K1.
--
-- P4: TIDAK ada BEGIN/COMMIT di file ini.
-- ============================================================================

-- Idempoten: kalau file ini dijalankan ulang, baris yang sama tidak digandakan.
-- UNIQUE (nrp, role_code, scope_type, scope_bu_id) sudah ada sejak migrasi awal
-- (probe D1b), tapi ON CONFLICT dipakai eksplisit supaya idetifikasi batasnya
-- terlihat di file — bukan bergantung pada driver.
INSERT INTO user_role_assignments
  (nrp, role_code, scope_type, scope_bu_id, is_primary, assigned_by)
VALUES
  ('NRP001', 'admin_pusat', 'ENTERPRISE', 'BU04', FALSE, 'migration:262')
ON CONFLICT (nrp, role_code, scope_type, scope_bu_id) DO NOTHING;