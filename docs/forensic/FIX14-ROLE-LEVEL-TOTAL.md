# FIX14 — ROLE / LEVEL / LOGIN — PETA TOTAL

Status: 🟡 INVESTIGASI PROGRESIF (B1 dari 3)
Tanggal: 2026-09-30
Baseline commit: 978584d
File tracked — single source of truth untuk Fix #14.
Raw probes: `.agents/scripts/fix14-b1-dbmap.mjs` (B1 baru) + `.agents/scripts/fix14-dbmap.mjs` (B–I, sesi sebelumnya) — gitignored.

## §1 Ringkasan eksekutif

Fix #14 = aktivasi sistem level 1-5 yang infrastrukturnya sudah ada di DB (kolom `role_level`, `module_definitions.minimum_tier_required`, `useModuleAccess` hook, RoleMatrixPage UI) tapi belum diaktifkan sebagai gate. Saat ini semua user `role_level=1` di `user_roles` (flat), semua BU `tier=4` (tier gate tidak pernah memblokir), `employees_core.role_level=0` untuk semua NRP, dan RoleGuard TIDAK membaca `role_level` — gate riil = entry + allowedRoles[]. Fix #14 = (a) aktifkan level sebagai gate, (b) dukung multi-view (1 user bisa masuk /dashboard sesuai jabatan DAN /worker sebagai data diri), (c) login pakai email + password.

## §2 Konteks & kaitan batch

§2.1 Fix #14 = batch baru. Muncul dari kebutuhan aktivasi level.

§2.2 Kaitan:
- Fix #4 (audit trail): Fix #14 butuh audit untuk perubahan level/role. **Catatan B1:** `admin_set_employee_role` sudah menulis `audit_log (actor, action='SET_ROLE', …)` — infrastruktur audit Fix #4 bisa dipakai; tapi `owner_update_role` menulis ke `audit_log_owner` dengan **kolom yang tidak ada** (lihat §4.19) → RPC itu broken.
- Fix #5 (auth + identitas): Fix #14 mengaktifkan login email + multi-view. Fix #5 tetap HOLD (deploy staging edge `password-reset` menunggu approve terpisah, §0.17).
- Fix #9 (baseline): Fix #14 menambah migrasi baru, ikut regenerasi baseline.
- Fix #10 (dokumentasi): Fix #14 bagian dari dokumentasi role.
- SECURITY.md §3.1 + §7.6 akan di-update saat Fix #14 CLOSED (Work Queue P2-F14-A/B, P3-F14-C).

## §3 Keputusan produk (dari user, 2026-09-30)

- Level 1 = worker murni
- Level 2 = supervisor
- Level 3 = manager
- Level 4 = admin
- Level 5 = CEO
- Owner = terpisah (GOD/superuser, bukan level)
- Multi-view: 1 user bisa masuk /dashboard (sesuai jabatan) DAN /worker (data diri individu sebagai pekerja)
- Login pakai email + password (bukan NRP/NIK)

## §4 Fakta DB LIVE

> Sumber: probe `fix14-b1-dbmap.mjs` B1–B7 (2026-09-30, BEGIN READ ONLY + ROLLBACK) + probe `fix14-dbmap.mjs` B–I (sesi sebelumnya, sama-sama read-only). Semua angka mentah.

§4.1 `user_roles` — 17 baris; `role_level` **flat = 1 untuk semua** (distinct_level=1); plan semua FREE; scope_divisi semua NULL. Role: admin_pusat ×2 (NRP001, NRP100), admin_hrd NRP101, admin_finance NRP102, admin_operasional NRP103, admin_mining NRP104, admin_mill NRP105, admin_estate NRP106, worker ×9 (NRP002–010).

§4.2 `user_role_assignments` — 17 baris (id 18–34), seed migrasi 246 (OPS-14, assigned_at 2026-09-24T10:31:16, assigned_by NULL): ENTERPRISE+BU04 untuk NRP001/100/101/102/103; BU untuk NRP104 (BU01 mining), NRP105 (BU03 mill), NRP106 (BU02 estate); SELF untuk worker (NRP002–010); semua is_primary=true.

§4.3 `admin_roles` — 7 baris + permissions jsonb lengkap (query 22, verbatim):
```
id | role_code         | scope_type | scope_id    | permissions_json                                                        | can_manage_users | can_manage_modules | is_active
7  | admin_estate      | industry   | estate      | ["estate.*"]                                                             | false | false | true
3  | admin_finance     | function   | finance     | ["payroll.*","budget.*","timesheet.*","overtime.*","export.*","kpi.*"]   | false | false | true
2  | admin_hrd         | function   | hrd         | ["employees.*","recruitment.*","kpi.*","learning.*","talent.*","exit.*"] | false | false | true
6  | admin_mill        | industry   | mill        | ["mill.*"]                                                               | false | false | true
5  | admin_mining      | industry   | mining      | ["mining.*"]                                                             | false | false | true
4  | admin_operasional | function   | operasional | ["requests.*","leave.*","overtime.*","timesheet.*","assets.*","shift.*"] | false | false | true
1  | admin_pusat       | global     | NULL        | ["*"]                                                                    | true  | false | true
```

§4.4 `role_permission_sets` — 28 baris, **ada role yatim terbukti** (Q27b, `dipakai_oleh` = jumlah baris `user_role_assignments` dengan role_code itu): `supervisor` (id 2,3 — dipakai 0), `manager` (id 4,5,6 — dipakai 0), `admin_produksi` (id 14,15,16 — dipakai 0). Total 8 baris mapping yatim. `admin_operasional` (id 27,28) dibuat 2026-09-24 = seed OPS-14 (migrasi 246). Struktur kolom (Q27 — **tidak ada kolom `role_level`/`description`**; query awal gagal 42703, lapor mentah): `id, role_code, permission_set, created_at`.

§4.5 `permission_set_items` — 93 baris, 9 set: worker_basic 14, supervisor_ext 7, manager_ext 6, hrd_ops 13, finance_ops 8, mining_ops 7, estate_ops 7, mill_ops 7, admin_pusat_all 24.

§4.6 `role_page_access` — 48 baris: admin_pusat `/admin/*` true; role admin lain halaman spesifik + `/admin/*` false; admin industri diberi halaman `/worker/*` (boiler/simper/harvest dll).

§4.7 `employees_core` — 26 kolom; **`role_level = 0 untuk 17 NRP`** (Q25/Q26); `level_jabatan`, `jabatan`, `position_code` **semua NULL**; divisi: NRP001 KORPORAT · NRP002/010 HRD · NRP003/004/005 MINING · NRP006/007 ESTATE · NRP008/009 MILL · admin NRP100–106 NULL. Semua status PKWTT, is_active.

§4.8 `employees_master` — 75 kolom view (core+extended; kolom encrypted bytea, data keluarga/bank/bpjs).

§4.9 `module_definitions` — 155 baris; `minimum_tier_required`: 0→121, 2→13, 3→21 modul.

§4.10 `business_units` — **4 baris, SEMUA tier=4** (Q12/Q14): BU01 MINING Tambang, BU02 ESTATE Perkebunan, BU03 MILL Pabrik, BU04 HQ Korporat; semua is_active, effective_from 2026-09-02/09-01. Kolom (Q13): `id, unit_code, unit_name, description, is_active, effective_from, effective_to, tier(integer)`. → Konsekuensi: gate tier (`check_module_access` vs `minimum_tier_required` ≤ 3) **tidak pernah memblokir modul apa pun** saat ini.

§4.11 `business_unit_modules` — hanya BU04 terisi (is_enabled=true; toggled_by OWNER001 hanya attendance).

§4.12 `auth.users` — 18 user (owner `owner@insightwos.com` `a8a77284-…` + 17 karyawan); semua provider=email; last_sign_in aktif 2026-09-21…26.

§4.13 `auth.identities` — 18 baris (email, match 1:1).

§4.14 `auth.sessions` — total **298** (Q17); top: semua milik admin/owner (pusat 42, operasional 35, ceo 34, …); worker < 13.

§4.15 `session_tokens` — total **354, aktif 0, expired 354** (Q15); per NRP top-5 (Q16): NRP101=84, NRP008=59, NRP100=44, NRP009=20, NRP004=19 (16 NRP terdaftar).

§4.16 `worker_passwords` — total 17; `reset_required=0`; `blocked_now=0` (Q18).

§4.17 `otp_store` — **0 baris** (min/max expiry NULL) (Q19).

§4.18 `login_attempts` — 7 hari (Q20): hanya `worker | success=true | 158`. Tidak ada attempt gagal 7 hari terakhir.

§4.19 `audit_log_owner` — **ADA, tapi TIDAK PERNAH TERISI (count=0)** dan **skema tidak cocok dengan pemakainya** (Q21a, 9 kolom): `id, owner_nrp, action, target_type, target_id, old_value, new_value, ip_address, created_at`. `owner_update_role` (§4.21.8) melakukan `INSERT (owner_auth_id, action, details)` — **kolom `owner_auth_id` dan `details` TIDAK ADA** → INSERT pasti gagal 42703 → `owner_update_role` **broken end-to-end** (konsisten dengan count=0). Temuan B1 baru.

§4.20 `sites` — 4 baris (Q23): SITE-ESTATE-01 Kebun Sawit Riau (Riau, ESTATE, radius 400), SITE-HQ-01 Kantor Pusat Jakarta (HQ, 250), SITE-MILL-01 Pabrik CPO Riau (MILL, 300), SITE-MINING-01 Site Tambang Sangatta (MINING, 500); semua status ACTIVE. Kolom (Q24): `id, site_name, location, business_unit, latitude, longitude, radius_meters, created_at, status, effective_from, effective_to`.

§4.21 RPC pusat — prosrc lengkap (query 2–11, verbatim):

§4.21.1 `get_current_user_context()`:
```sql
DECLARE
  v_uid UUID := auth.uid();
  v_emp RECORD;
  v_role RECORD;
  v_is_owner BOOLEAN;
BEGIN
  IF v_uid IS NULL THEN RETURN NULL; END IF;

  -- Check Owner identity (NOT role-based)
  SELECT check_owner_identity() INTO v_is_owner;

  IF v_is_owner THEN
    RETURN jsonb_build_object(
      'nrp', 'OWNER001',
      'nama', 'System Owner',
      'role', 'owner',
      'role_level', 5,
      'is_owner', TRUE,
      'business_unit_id', NULL,
      'email', (SELECT email FROM auth.users WHERE id = v_uid LIMIT 1)
    );
  END IF;

  -- Regular employee lookup
  SELECT * INTO v_emp FROM employees_master WHERE auth_id = v_uid LIMIT 1;
  IF v_emp IS NULL THEN RETURN NULL; END IF;

  SELECT * INTO v_role FROM user_roles WHERE nrp = v_emp.nrp LIMIT 1;

  RETURN jsonb_build_object(
    'nrp', v_emp.nrp,
    'nama', v_emp.nama,
    'role', COALESCE(v_role.role, 'worker'),
    'role_level', COALESCE(v_role.role_level, 1),
    'is_owner', FALSE,
    'business_unit_id', v_emp.business_unit_id,
    'email', v_emp.email
  );
END;
```
Catatan: owner dikembalikan dengan `role_level=5` **hanya di context ini** (Owner = GOD, sesuai keputusan §3 owner bukan level 5 persisten); non-owner tanpa baris `employees_master.auth_id` → NULL (owner buta `authz_current_nrp`, residual OPS-14 terkonfirmasi).

§4.21.2 `owner_login(p_email)`:
```sql
DECLARE
  v_uid UUID := auth.uid();
  v_is_owner BOOLEAN;
  v_owner_email TEXT;
BEGIN
  -- Baca owner_email dari config (bisa diubah owner/admin lewat OwnerDashboard)
  SELECT get_owner_email() INTO v_owner_email;

  -- Validate against system_owner_identity
  SELECT EXISTS (
    SELECT 1 FROM system_owner_identity
    WHERE auth_id = v_uid AND is_active = TRUE
  ) INTO v_is_owner;

  IF NOT v_is_owner THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Akun owner tidak ditemukan atau tidak aktif');
  END IF;

  -- Instalasi baru belum mengisi owner_email. Beri pesan yang bisa ditindaklanjuti;
  -- JANGAN menerima email apa pun (lihat catatan keamanan di header).
  IF v_owner_email IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'msg', 'owner_email belum dikonfigurasi. Isi dulu: company_config config_key=owner_email, '
             || 'atau jalankan installer dengan --owner-email="email-owner@perusahaan.com".'
    );
  END IF;

  IF lower(btrim(p_email)) IS DISTINCT FROM lower(v_owner_email) THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Email tidak sesuai dengan konfigurasi owner');
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'nrp', 'OWNER001',
    'nama', 'System Owner',
    'role', 'owner',
    'role_level', 5,
    'is_owner', true
  );
END;
```

§4.21.3 `authz_check_admin(p_permission)` — owner bypass **hanya auth_id** (tanpa fallback email), lalu delegasi ke `authz_has_permission`:
```sql
BEGIN
  IF EXISTS (SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = true) THEN
    RETURN TRUE;
  END IF;
  RETURN authz_has_permission(p_permission);
END;
```
`authz_has_permission(p_permission_code)` — owner bypass (auth_id saja), lalu chain `user_role_assignments → role_permission_sets → permission_set_items`:
```sql
BEGIN
  -- Owner bypasses everything
  IF EXISTS (SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = TRUE) THEN
    RETURN TRUE;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM user_role_assignments ura
    JOIN role_permission_sets rps ON rps.role_code = ura.role_code
    JOIN permission_set_items psi ON psi.permission_set = rps.permission_set
    WHERE ura.nrp = authz_current_nrp()
      AND psi.permission_code = p_permission_code
  );
END;
```

§4.21.4 `admin_get_role_matrix()` — read dari `user_roles`+`employees_master` (nrp, nama, level=ur.role_level, scope=ur.scope_divisi, plan):
```sql
BEGIN RETURN (SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
  jsonb_build_object('nrp',ur.nrp,'nama',e.nama,'level',ur.role_level,'scope',ur.scope_divisi,'plan',COALESCE(ur.plan,'FREE')) ORDER BY ur.role_level DESC),'[]'::jsonb))
FROM user_roles ur LEFT JOIN employees_master e ON e.nrp=ur.nrp); END; 
```
`admin_set_employee_role(p_target_nrp, p_role, p_scope_divisi)` — **mapping level hardcoded 4/3/1**; daftar role yang dibolehkan TIDAK memuat supervisor, admin_operasional, admin_mining/mill/estate; audit ke `audit_log (actor=v_caller, 'SET_ROLE')`:
```sql
DECLARE
  v_caller TEXT;
BEGIN
  v_caller := authz_current_nrp();
  IF v_caller IS NULL THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;

  -- Hanya admin_pusat / owner yang boleh set role
  IF NOT authz_check_admin('employee.update') THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Hanya Admin Pusat yang bisa mengatur role');
  END IF;

  -- Anti self-escalation & anti target kosong
  IF p_target_nrp IS NULL OR p_target_nrp = '' THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'NRP target tidak valid');
  END IF;

  IF p_role NOT IN ('admin_pusat','admin_hrd','admin_finance','admin_produksi','manager','worker') THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Role tidak valid');
  END IF;

  UPDATE user_roles SET role = p_role, scope_divisi = COALESCE(p_scope_divisi, scope_divisi) WHERE nrp = p_target_nrp;
  IF NOT FOUND THEN
    INSERT INTO user_roles (nrp, role_level, role, scope_divisi)
    VALUES (p_target_nrp, CASE WHEN p_role LIKE 'admin_%' THEN 4 WHEN p_role = 'manager' THEN 3 ELSE 1 END, p_role, p_scope_divisi);
  END IF;

  INSERT INTO audit_log (actor, action, detail, timestamp)
  VALUES (v_caller, 'SET_ROLE', 'Set ' || p_target_nrp || ' -> ' || p_role, NOW());
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'Role berhasil diupdate');
END;
```
`admin_set_role(p_nrp, p_level, p_scope, p_plan)` — **STUB**: p_level/p_scope/p_plan TIDAK dipakai sama sekali:
```sql
BEGIN
  IF NOT authz_check_admin('employee.update') THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Akses ditolak.');
  END IF;
  RETURN jsonb_build_object('ok', TRUE, 'msg', 'RPC executed with role check.');
END;
```

§4.21.5 `get_bu_tier(p_business_unit_id)`:
```sql
DECLARE
  v_bu TEXT;
  v_tier INT;
BEGIN
  v_bu := COALESCE(p_business_unit_id, authz_get_bu());
  IF v_bu IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'business_unit_id', NULL, 'tier', NULL);
  END IF;
  SELECT tier INTO v_tier FROM business_units WHERE id = v_bu;
  RETURN jsonb_build_object('ok', true, 'business_unit_id', v_bu, 'tier', v_tier);
END;
```
`tier_msg_(p_feature, p_min_tier)` — pembentuk pesan saja:
```sql
BEGIN RETURN 'Fitur "' || p_feature || '" memerlukan paket ' || p_min_tier || ' atau level lebih tinggi.'; END;
```

§4.21.6 `get_role_overview()` — owner-only via ctx; COALESCE(ur.role_level, em.role_level, 1):
```sql
DECLARE v_ctx JSONB := get_current_user_context();
BEGIN
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN '[]'::JSONB;
  END IF;
  RETURN (
    SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::JSONB)
    FROM (
      SELECT
        em.nrp,
        em.nama,
        COALESCE(ur.role, 'worker') as role,
        COALESCE(ur.role_level, em.role_level, 1) as role_level,
        COALESCE(em.business_unit_id, 'HQ') as business_unit
      FROM employees_master em
      LEFT JOIN user_roles ur ON ur.nrp = em.nrp
      ORDER BY COALESCE(em.business_unit_id, 'HQ'), COALESCE(ur.role_level, em.role_level, 1) DESC
    ) t
  );
END;
```
`get_my_role(p_nrp)` — **percaya param p_nrp** (tanpa cek JWT caller); `tier` diisi `scope_divisi` (free-tier legacy):
```sql
DECLARE v RECORD; BEGIN SELECT * INTO v FROM user_roles WHERE nrp=p_nrp;
IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'msg','Role not found'); END IF;
RETURN jsonb_build_object('ok',true,'nrp',p_nrp,'level',v.role_level,'tier',COALESCE(v.scope_divisi,'FREE')); END;
```

§4.21.7 `login_worker` / `login_worker_by_email` — prosrc lengkap ada di evidence sesi sebelumnya (dikutip penuh di agentsLogs + chat 2026-09-27); poin penting: dual-schema hash (bcrypt `$2%` via `crypt`, else sha256+salt dengan auto-upgrade bcrypt saat sukses), lockout 5/15 mnt via `login_attempts`, token `session_tokens` 24 jam, return `role_level COALESCE(v_role.role_level,1)` + `role COALESCE(v_role.role,'worker')` + `business_unit COALESCE(v_emp.business_unit,'HQ')`; by-email resolve NRP/NIK dari `employees_core.email`.

§4.21.8 `owner_update_role(p_nrp, p_role, p_role_level)` — owner-only via ctx; UPDATE `user_roles` + `employees_master`; **INSERT ke `audit_log_owner (owner_auth_id, action, details)` memakai kolom yang tidak ada (§4.19) → RPC broken**:
```sql
DECLARE
  v_ctx JSONB := get_current_user_context();
BEGIN
  -- Owner bypass only
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Owner access required');
  END IF;

  IF p_nrp IS NULL OR p_role IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'nrp and role required');
  END IF;

  -- Update user_roles
  UPDATE user_roles SET role = p_role, role_level = p_role_level WHERE nrp = p_nrp;

  -- Update employees_master role_level
  UPDATE employees_master SET role_level = p_role_level WHERE nrp = p_nrp;

  -- Log to audit
  INSERT INTO audit_log_owner (owner_auth_id, action, details)
  VALUES (
    auth.uid(),
    'update_role',
    jsonb_build_object('nrp', p_nrp, 'new_role', p_role, 'new_level', p_role_level)
  );

  RETURN jsonb_build_object('ok', true, 'msg', 'Role updated for ' || p_nrp);
END;
```
`authz_current_nrp()` — `SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1;` (owner tanpa baris → NULL). `authz_is_owner()` — `system_owner_identity` WHERE is_active AND (auth_id=auth.uid() OR lower(owner_email)=lower(jwt email)) — SATU-SATUNYA helper authz dengan fallback email.

§4.21.9 (pelengkap) `check_module_access(p_module_code, p_required_role_level)` — ctx→owner bypass→cek `role_level < required`→industry module via `business_unit_modules`→else tier vs `minimum_tier_required`; `get_worker_profile(p_nrp)` — caller dari `authz_current_nrp`, owner check hanya auth_id, `atasan_nrp` hardcoded NULL.

§4.22 FK relationships — **0 FK** pada `user_roles`, `user_role_assignments`, `employees_core` (probe G31 + sanity pg_catalog: 16 FK di schema public, satu-satunya yang menyentuh gugus employees = `employees_extended.nrp → employees_core.nrp`). Integritas relasi role→karyawan tidak dijaga DB.

§4.23 `schema_migrations` — 179 baris / max(version)=254 (sinkron dengan jumlah file repo; bukti verify:artifacts @ 978584d).

## §5 Fakta code src/
⏳ Diisi di Prompt B2.

## §6 Gap analysis
⏳ Diisi di Prompt B2.

## §7 Rencana eksekusi
⏳ Diisi di Prompt B3.

## §8 Definition of Done
⏳ Diisi di Prompt B3.

## §9 Recovery plan / rollback
⏳ Diisi di Prompt B3.

## §10 Test plan
⏳ Diisi di Prompt B3.

## §11 Work Queue + referensi
⏳ Diisi di Prompt B3.

## §12 Riwayat keputusan
- 2026-09-30: user menetapkan peta level 1-5 + owner terpisah + multi-view.
- 2026-09-30: user menetapkan prinsip "investigasi wajib tracked, bukan chat".
- 2026-09-30: B0 selesai (inventaris konstanta + guard coverage).
- 2026-09-30: B0.5 selesai (SECURITY.md §3.10 fix + guard).
- 2026-09-30: B1 dibuat — §1-§4 diisi.
