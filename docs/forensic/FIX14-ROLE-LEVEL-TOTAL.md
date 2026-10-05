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

## §3b Keputusan teknis (2026-09-30, setelah B1)
- **Q1 = A**: Fix #14 perbaiki `owner_update_role` (INSERT `audit_log_owner` kolom sesuai skema riil: `owner_nrp, action, target_type, target_id, old_value, new_value`). Tidak bikin RPC baru.
- **Q2 = A**: Fix #14 patch `get_my_role(p_nrp)` — NULL → `authz_current_nrp()`.
- **Q3 = A**: Fix #14 sentuh HANYA `role_level`. Tier BU tetap (scope creep dihindari — `business_units.tier` tidak diubah).
- 4 Work Queue baru dari B2: **P1-F14-D** (get_my_role percaya param), **P2-F14-E** (admin_set_role stub), **P2-F14-F** (admin_set_employee_role mapping hardcoded), **P2-F14-G** (tier gate tak pernah memblokir).

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

> Sumber: baca langsung file + `git grep` @ a85d88c (rg rusak → git grep). Read-only; src/ tidak diubah.

§5.1 **Home.tsx** (`src/pages/Home.tsx`, 1085 baris) — login bukan 4 jalur melainkan **3 tab** (worker | admin | dashboard) + OwnerLogin terpisah (`src/pages/OwnerLogin.tsx`):
- Tab worker: `loginMode` state — **default `'email'`** (baris ~106: `const [loginMode, setLoginMode] = useState('email')`) → `login_worker_by_email` (email+password), fallback toggle NRP → `login_worker` (NRP+NIK+password). Keputusan §3 "login email" **sudah jadi default UI** sejak sekarang.
- Tab admin: `syncSupabaseAuth(adminEmail, adminPass)` (Supabase Auth signIn) → RPC `get_user_context_by_auth_id` → OTP wajib via edge `password-reset` action `login_otp` (Home.tsx:338-351, `requestAdminOtpForEntry`).
- Tab dashboard: login worker dulu lalu OTP wajib (`submitWorkerCredentials` → `requestAdminOtpForEntry` bila `tab==='dashboard'`).
- Owner: file terpisah OwnerLogin.tsx (bukan tab di Home).
- `finalizeWorkerSession` (Home.tsx:165): session build memasukkan `role_level: d.role_level` + `entry: (entry || tab)` — **entry = tab asal login**, bukan role.
- `redirectAfterLogin(entry)` (Home.tsx:181): redirect per TAB (`dashboard`→/dashboard, `admin`→/admin, else /worker) — komentarnya eksplisit: "Admin juga bisa jadi worker: login lewat tab Pekerja → area pekerja".

§5.2 **supabase-browser.ts** (`entryFromRole` + session build, baris ~130-170):
```ts
function entryFromRole(role?: string, isOwner?: boolean): UserSession['entry'] {
  if (isOwner || role === 'owner') return 'owner';
  if (role?.startsWith('admin_')) return 'admin';
  if (role === 'manager') return 'dashboard';
  return 'worker';
}
```
`setSession()` = satu choke point: `entry: user.entry ?? entryFromRole(...)` + `expires_at` wajib (fail-closed `isSessionValid`: butuh `nrp` + `expires_at` masa depan). Key sessionStorage `wos_user_v2` (legacy `wos_user` dibuang). `SESSION_TTL_MS` 8 jam. `initSession()` → `get_current_user_context` (baris ~235 memasukkan `role_level: data.role_level`).

§5.3 **RoleGuard.tsx** — gate riil = `session.entry` + `allowedRoles[]`, TIDAK membaca `role_level`:
- Fail-closed tanpa nrp; isolasi entry: `if (entry && s.entry !== entry && s.role !== 'owner') → redirect` (multi-view saat ini TERKUNCI ke satu entry);
- Role check: owner bypass semua; `allowedRoles.length === 0` → tolak semua (fail-closed); else `allowedRoles.includes(userRole)`.

§5.4 **route-config.ts + App.tsx** — route statis yang di-guard hanya 3 (App.tsx:64-66, literal):
```
/admin     allowedRoles=[admin_pusat, admin_hrd, admin_finance, admin_operasional, admin_mining, admin_mill, admin_estate, owner] entry=admin
/worker    allowedRoles=[worker, owner]                                          entry=worker
/dashboard allowedRoles=[manager, admin_pusat, admin_hrd, admin_finance, admin_operasional, owner] entry=dashboard
```
route-config.ts = pemetaan `route_component` → lazy component (getComponent dipakai DynamicRoutes untuk 155 modul); /owner/* di-guard OwnerGuard (bukan RoleGuard).

§5.5 **menu-builder.ts** — menu dari RPC `get_enabled_modules`, filter: `minimum_tier_required` vs `session.tier` (owner = 999), `role_access[]`, `required_business_unit`; area dari path (`areaFromPath`); TIDAK membaca role_level.

§5.6 **useModuleAccess.ts** — `useModuleAccess(moduleCode, requiredRoleLevel = 1)` → RPC `check_module_access` (level dikirim, default 1 — karena user_roles flat=1, tidak pernah menolak); `useCurrentUserContext()` → `get_user_context_by_auth_id` (tanpa fallback session — "auth.uid() is the only source of truth").

§5.7 **src/types/index.ts** — `UserSession` (baris 8-23): `nrp, nama, role, role_level, business_unit_id, business_unit?, divisi?, posisi?, is_owner?, email?, entry?: 'admin'|'worker'|'dashboard'|'owner' (SINGLE value), tier?, expires_at?` — TANPA `token` (by design). `UserContext` + `CurrentUserContext` punya `role_level?`.

§5.8 **RoleMatrixPage.tsx** (`src/features/platform/authorization/`) — read-only: `admin_get_role_matrix` → group by `role_level`; **label LEVEL beda dengan keputusan §3**: `{1:Worker, 2:Supervisor, 3:Manager, 4:'Sr. Manager', 5:Admin}` vs keputusan user (4=admin, 5=CEO) → perlu diselaraskan saat Fix #14. Guard halaman: `useAdminAuth(["admin_pusat"])`.

§5.9 **Dashboard routing per role** — dipilih via App.tsx route (entry=dashboard) + RoleGuard; Dashboard.tsx membaca session (clearSession/signOutAuth); OwnerDashboard terpisah di /owner (OwnerGuard → RPC `check_owner_identity` server-side). OwnerDashboard.tsx:349 memanggil `owner_update_role` (RPC broken per §4.19) → **UI kelola role owner saat ini mati end-to-end**; :205/:224 form role_level; :597-603 render label `L{role_level}`.

§5.10 Grep results (mentah, `git grep -c`):
- §5.10.1 `allowedRoles` — 18 hit / 3 file: App.tsx 3 (deklarasi route), RoleGuard.tsx 10, useAdminAuth.ts 5.
- §5.10.2 `.entry` — 8 hit / 6 file: RoleGuard 2, supabase-browser 1, Admin.tsx 1, Dashboard.tsx 1, Home.tsx 1, Worker.tsx 2 (kategori: route guard ×4, page re-check ×3, redirect-after-login ×1).
- §5.10.3 `role_level` — 25+ hit: Home.tsx ×7 (tulis session), supabase-browser ×1 (initSession), **business-units.ts:247 `session.role_level || 1` (konsumen gate tersembunyi)**, RoleMatrixPage ×4 (UI), OrgSubtree ×2 (display), ModuleManagement ×2 (display), OwnerDashboard ×6 (edit + panggil owner_update_role), useModuleAccess ×1 (kirim requiredRoleLevel).
- §5.10.4 `useModuleAccess|useCurrentUserContext` — 4 file pemakai: CoreDataWrapper, ModuleRouteGuard, ModuleManagement, hook itu sendiri.
- §5.10.5 `check_module_access` — 1 pemakai saja (useModuleAccess.ts:17).

## §5b Sistem bisnis — peta lengkap (2026-09-30, B2.5)

> Pemicu: AI Core salah paham peta role (mengira "level 4=admin" cukup menggambarkan sistem). User mengoreksi: "ADMIN ya hanya ADMIN saja dia masuk, khusus page admin". §5b merekam FAKTA dari DB live + code, tanpa keputusan. Probe: `.agents/scripts/fix14-b25-biz.mjs` (SELECT only, SAVEPOINT per query).

§5b.1 **Struktur perusahaan** (DB live):
- **4 Business Unit**: BU01 MINING "Tambang" · BU02 ESTATE "Perkebunan (Sawit)" · BU03 MILL "Pabrik (CPO)" · BU04 HQ "Korporat" — semua `tier=4`, aktif.
- **4 Site** (lokasi fisik + geofence): SITE-MINING-01 Site Tambang Sangatta (Kaltim, radius 500 m) · SITE-ESTATE-01 Kebun Sawit Riau (400 m) · SITE-MILL-01 Pabrik CPO Riau (300 m) · SITE-HQ-01 Kantor Pusat Jakarta (250 m).
- **17 karyawan** (semua PKWTT): NRP001 CEO (BU HQ, site Jakarta, divisi KORPORAT); worker NRP002+010 (HQ/HRD, Jakarta), NRP003-005 (MINING, Sangatta), NRP006-007 (ESTATE, Riau), NRP008-009 (MILL, Riau); **admin NRP100-106: `business_unit` NULL, `site_id` NULL** (pusat — tidak ditempatkan di BU mana pun); `posisi/jabatan/level_jabatan/position_code` NULL untuk SEMUA.

§5b.2 **Peta halaman** — dua lapis:
- **Route statis (App.tsx:64-66 + OwnerGuard)**: `/admin` (entry=admin; allowedRoles 7 admin_* + owner) · `/worker` (entry=worker; allowedRoles `['worker','owner']` SAJA) · `/dashboard` (entry=dashboard; allowedRoles `['manager','admin_pusat','admin_hrd','admin_finance','admin_operasional','owner']` — TANPA admin industri) · `/owner/*` (OwnerGuard → RPC `check_owner_identity`, bukan RoleGuard).
- **155 modul dinamis** (`module_definitions.route_group`): **hanya 2 nilai — admin 103, worker 52** (TIDAK ada route_group dashboard/owner). Area prefix: /admin 100, /worker 51, 4 path landing tanpa sub-path (`/admin` admin_landing, `/worker`, `/dashboard` ×2 = ceo_dashboard + dashboard_landing yang dinonaktifkan SQL-13). Sample 30 tercetak di probe; gate dinamis = ModuleRouteGuard/useModuleAccess (`check_module_access`), bukan allowedRoles.

§5b.3 **Peta role → halaman EKSPLISIT** (`role_page_access`, 48 baris lengkap):
```
admin_pusat      : /admin/*                          can_access=T can_action=T   (SATU-SATUNYA akses admin penuh)
admin_hrd        : /admin/{employees,recruitment,kpi,learning,talent,exit,requests,review-360} + /admin/*=F
admin_finance    : /admin/{payroll,budget,timesheet,overtime,kpi,export} + /admin/*=F
admin_operasional: /admin/{requests,leave,overtime,timesheet,shift-swap,assets} + /admin/*=F
admin_mining     : /worker/{simper,heavy-equip,fatigue,production,safety,emergency,jsa} + /admin/*=F  ← HALAMAN /worker/*
admin_mill       : /worker/{boiler,machines,qc,packing,maintenance,breakdown,shift}     + /admin/*=F  ← HALAMAN /worker/*
admin_estate     : /worker/{harvest,blocks,nursery,transport,irrigation,facility,medical} + /admin/*=F ← HALAMAN /worker/*
worker/manager/supervisor/owner : TIDAK ADA baris (sumber kebenaran mereka = module_definitions + App.tsx literal)
```

§5b.4 **Admin roles — apa bedanya** (role_page_access × admin_roles.permissions):
- **admin_pusat** = super-admin aplikasi: `/admin/*` penuh, permissions `["*"]`, can_manage_users=true; tiles Admin.tsx: Pengajuan, Karyawan, Organisasi, Payroll, KPI, Analytics, Audit, Reset PW, Pengaturan.
- **admin_hrd** = fungsi HRD: employees/recruitment/learning/talent/kpi/exit; permissions `employees.*, recruitment.*, kpi.*, learning.*, talent.*, exit.*`.
- **admin_finance** = fungsi keuangan: payroll/budget/timesheet/overtime/kpi/export; permissions `payroll.*, budget.*, timesheet.*, overtime.*, export.*, kpi.*`.
- **admin_operasional** = fungsi operasional: requests/leave/overtime/timesheet/shift-swap/assets; permissions `requests.*, leave.*, overtime.*, timesheet.*, assets.*, shift.*`.
- **admin_mining / admin_mill / admin_estate** = **industri**: scope industry, permissions `mining.* / mill.* / estate.*`; halamannya BUKAN /admin melainkan **7 halaman operasional di bawah /worker/*** (simper/boiler/harvest dll) — artinya "admin industri" mengelola data operasional lapangan yang rutenya di area worker.

§5b.5 **Dashboard vs Admin vs Worker vs Owner** — siapa masuk, lihat apa:
- **/worker** (`Worker.tsx`, 153 baris): RPC `get_worker_status`, `get_worker_narrative`, `get_announcements`; menu dari `getUserModules()` (business-units.ts); **cek ganda**: entry ≠ worker → redirect; `role ≠ worker & ≠ owner` → "Akses Worker Ditolak".
- **/dashboard** (`Dashboard.tsx`, 212 baris): permintaan tim (`approve_team_request`), KPI divisi, snapshot, keuangan, flight risk, turnover, exec summary (`get_executive_summary`/`get_executive_brief`), early warning, planning. Modul CEO `ceo_dashboard` (route_path `/dashboard`) — RPC data: `get_ceo_command_data` (2 overload), `get_dashboard_data`, `get_dashboard_stats` (**`ceo_dashboard` adalah MODULE_CODE, bukan RPC** — klarifikasi temuan awal B1).
- **/admin** (`Admin.tsx`, 325 baris): ROLE_BADGES + ADMIN_TILES per admin_* (dashboard ringkasan approval + pintasan ke halaman fungsi masing-masing).
- **/owner** (`OwnerDashboard.tsx`): **18 tab** — Overview, Module Lock, Tier & Pricing, Roles, Audit Log, Security, Business Units, Employees, Announcements, Notifications, System Banner, Activity, Integrations, Data Retention, System Log, Support, Analytics, Access Control (+ Branding + halaman Config). Memanggil `owner_update_role` di tab Roles (:349 — RPC broken per §4.19).

§5b.6 **Owner GOD — konfirmasi teknis**: OwnerLogin.tsx = `signInWithPassword` (email pre-filled owner@insightwos.com) → RPC `owner_login(p_email)` (validasi `system_owner_identity` + `get_owner_email()` fail-closed) → `setSession({nrp:'OWNER001', role:'owner', role_level:5, is_owner:true})` → `/owner/dashboard`. Bypass owner ada di: RoleGuard (role owner lolos entry isolation + semua allowedRoles), Worker.tsx (owner boleh), authz_check_admin/authz_has_permission (owner bypass), get_current_user_context (OWNER001/level 5), menu-builder (`effectiveTier = 999`). `is_owner` dipakai 9 file. Owner tidak punya baris employees_core/user_roles — identitas murni `system_owner_identity`.

§5b.7 **Yang BELUM jelas — perlu klarifikasi user** (bukan nebak):
1. **Jalur masuk admin industri**: role_page_access memberi admin_mining/mill/estate 7 halaman `/worker/*` masing-masing, TAPI route statis `/worker` allowedRoles=`['worker','owner']` dan Worker.tsx menolak `role ≠ worker` → bagaimana admin industri SEHARUSNYA masuk (login tab worker lalu langsung ke halaman industri via dynamic route?) — perlu klarifikasi + kemungkinan desain di B3.
2. **CEO lvl 5 belum ada wujud DB**: NRP001 = `admin_pusat` level 1 di user_roles; tidak ada role/level khusus CEO; beda UI CEO vs admin lvl 4 **belum ada** di code (cegah nebak: keputusan peta level §3 belum dieksekusi).
3. **Tiga label level saling kontradiksi**: RoleMatrixPage `{4:'Sr. Manager',5:'Admin'}` vs ModuleManagement `{1:Staff,2:Supervisor,3:Manager,4:Director,5:CEO}` vs keputusan user `{4:admin,5:CEO}` — butuh satu peta final di B3.
4. **worker/manager/supervisor/owner tidak ada di role_page_access** → peta halaman mereka tersebar di 2 sumber (module_definitions + App.tsx literal) — tidak ada satu matriks tunggal.

§5b.8 **Koreksi AI Core** (fakta yang memperbaiki salah paham):
- AI Core mengira "level 4 = admin" adalah satu wajah. FAKTA: **"admin" = 7 sub-kategori role** (pusat/hrd/finance/operasional + 3 industri) dengan matriks halaman BERBEDA per role; admin_pusat satu-satunya yang melihat seluruh /admin.
- Perkataan user "ADMIN ya hanya ADMIN saja dia masuk, khusus page admin" terkonfirmasi di code: allowedRoles `/admin` HANYA 7 admin_* (+owner) — manager/worker TIDAK masuk; sebaliknya /worker HANYA worker (+owner); /dashboard = manager + admin fungsi (bukan admin industri).
- **Level (angka) dan halaman (matriks role×pattern) adalah dua dimensi berbeda**: level belum dipakai gate sama sekali (B1/B2), sementara halaman diatur role string + role_page_access. Fix #14 harus memetakan keduanya eksplisit, bukan menyamakan.

## §5c Peta final level (keputusan user + Opsi A GPT, 2026-09-30)

### §5c.1 Definisi level
- Level 1 = Worker
- Level 2 = Supervisor
- Level 3 = Manager
- Level 4 = Director / VP
- Level 5 = CEO
- Owner = terpisah (GOD/superuser, tidak masuk hierarki)

> CATATAN REKONSILIASI: keputusan awal §3 menulis "Level 4 = admin". Opsi A (keputusan 2026-09-30, jawaban GPT Senior Enterprise HRIS Architect) MENGGANTIKAN peta itu: level 4 = Director/VP, level 5 = CEO. "Admin" BUKAN level — admin adalah fungsi (admin_role). §3 tetap sebagai riwayat; peta berlaku = §5c.

### §5c.2 Peta final NRP → level + admin_role + scope

| NRP | Jabatan | Job Level | Admin Role | Scope |
|---|---|---|---|---|
| NRP001 | CEO | 5 | (bukan admin) | ALL |
| NRP100 | Manager / Admin Pusat | 3 | admin_pusat | ALL COMPANY |
| NRP101 | Manager HRD | 3 | admin_hrd | HRD |
| NRP102 | Manager Finance | 3 | admin_finance | Finance |
| NRP103 | Manager Operasional | 3 | admin_operasional | Operations |
| NRP104 | Manager Mining | 3 | admin_mining | BU01 |
| NRP105 | Manager Mill | 3 | admin_mill | BU03 |
| NRP106 | Manager Estate | 3 | admin_estate | BU02 |
| NRP002–010 | Worker | 1 | (bukan admin) | BU/SELF |

Level 2 (Supervisor) dan 4 (Director/VP) BELUM ada pemiliknya saat ini — hanya definisi.

### §5c.3 Alasan
Admin = fungsi, bukan level. NRP100 punya akses administrasi paling luas TAPI tidak dinaikkan jadi Director/CEO. Scope luas direpresentasikan oleh Admin Role + Permission + Scope, bukan job_level.

### §5c.4 Sumber
- Jawaban GPT (Senior Enterprise HRIS Architect) 2026-09-30 — Opsi A, di-approve user.
- Preseden migrasi 051 (legacy: admin_pusat=5, admin fungsi=4) di-REPLACE — bukan diikuti.
- Arsitektur lama = USANG.
- Bukti B2.6/B2.6b: tidak ada level existing di DB — peta ini KEPUTUSAN BARU, bukan penggalian data.

## §5d Prinsip RBAC 4-layer (WAJIB)

### §5d.1 Pemisahan konsep
```
JOB LEVEL    → posisi hierarki (approval, reporting)
ADMIN ROLE   → fungsi administrasi aplikasi
PERMISSION   → tindakan yang boleh
DATA SCOPE   → data/unit yang boleh diakses

JOB LEVEL ≠ ADMIN ROLE ≠ PERMISSION ≠ DATA SCOPE
```

### §5d.2 Gate audit rules (dari spec §G)

| Kebutuhan | Gunakan |
|---|---|
| Apakah Manager? | `job_level >= 3` |
| Apakah Director/VP? | `job_level >= 4` |
| Apakah CEO? | `job_level === 5` |
| Apakah admin pusat? | `admin_role === 'admin_pusat'` |
| Apakah admin HRD? | `admin_role === 'admin_hrd'` |
| Apakah admin Mining? | `admin_role === 'admin_mining'` |
| Apakah boleh edit? | permission |
| Apakah boleh lihat BU01? | scope |
| Apakah full admin? | permission/scope, BUKAN job_level |

### §5d.3 Pola salah yang harus dicari di code
```
SALAH:
  if (user.role_level >= 4) { allowFullAdmin(); }
  — NRP100 lvl 3 tetap punya full admin.
BENAR:
  if (user.admin_role === 'admin_pusat') { allowFullAdmin(); }

SALAH:
  if (user.role_level >= 3) { allowMiningAdmin(); }
  — semua Manager dapat akses Mining.
BENAR:
  if (user.admin_role === 'admin_mining' && user.admin_scope.includes('BU01'))
```

### §5d.4 Konsekuensi ke Fix #14
- RoleGuard harus baca `admin_role` + `scope` untuk gate admin.
- `job_level` dipakai HANYA untuk hierarki (approval, reporting).
- Multi-view: `job_level >= 3` boleh masuk `/dashboard` + `/worker` (data diri). `/admin` tetap butuh `admin_role`.

## §5e Gap DB — source of truth baru (perlu keputusan user)

### §5e.1 Kondisi existing (B1/B2.6)
- `user_roles` (5 kolom): `nrp | role_level | scope_divisi | plan | role` — TIDAK ada admin_role, admin_scope, permissions.
- `admin_roles` (7 baris): `role_code | scope_type | permissions jsonb`.
- `user_role_assignments` (17 baris): `nrp | role_code | scope_type | scope_bu_id | scope_org_unit | scope_domain`.
- `role_page_access` (48 baris); `role_permission_sets` (28 baris); `permission_set_items` (93 baris).

### §5e.2 Yang dibutuhkan spec
`user_roles`: `admin_role | admin_scope | permissions` (sesuai spec §G/§5d).

### §5e.3 Opsi desain (perlu keputusan user)
- **Opsi A** — pakai `user_role_assignments` existing (tambah ref admin_role).
- **Opsi B** — tambah 3 kolom ke `user_roles` (duplikasi).
- **Opsi C** — konsolidasi: `user_roles` = job_level only; `user_role_assignments` = admin_role + scope (**rekomendasi AI Core**).
- **Opsi D** — struktur lain.

### §5e.4 Rekomendasi AI Core
Opsi C — separation of concerns sesuai spec §5d. **Status: menunggu keputusan user** (gates B3).

## §6 Gap analysis

§6.1 **Level 1-5 sebagai gate** — Target: level jadi gate /dashboard sesuai jabatan. Realita: RoleGuard pakai entry+allowedRoles (string role), bukan level; DB-nya pun flat=1. Gap: (a) data — seed role_level per keputusan §3, (b) kode — RoleGuard/App.tsx allowedRoles harus membaca/menghormati `session.role_level`; konsumen lain yang membaca role_level hanya business-units.ts:247 + UI display.

§6.2 **Owner terpisah (GOD)** — Realita: `authz_is_owner` + `owner_login` + OwnerGuard (`check_owner_identity`) hidup; TAPI `owner_update_role` broken (audit kolom salah, §4.19) → UI OwnerDashboard.tsx:349 mati. Gap: Q1=A perbaiki INSERT audit; tidak ada perubahan konsep owner.

§6.3 **Multi-view (1 user 2 entry)** — Realita: `UserSession.entry` single value; RoleGuard menolak `s.entry !== entry` (kecuali owner); redirectAfterLogin = tab asal. Gap: kontrak session + RoleGuard harus berubah — breaking untuk 8 titik baca `.entry` di 6 file (§5.10.2) + kontrak v2 `wos_user_v2` (perlu strategi migrasi sesi agar user login ulang sekali).

§6.4 **Login email** — Realita: RPC `login_worker_by_email` sudah ada + anon grant + **Home.tsx default loginMode='email' sudah berlaku**; NRP tetap tersedia sebagai fallback toggle. Gap: praktis nihil di UI — sisanya verifikasi E2E + keputusan apakah fallback NRP dipertahankan.

§6.5 **Tulisan level (owner/admin set role)** — Realita: 3 RPC bermasalah: `owner_update_role` broken (Q1=A), `admin_set_role` STUB (P2-F14-E), `admin_set_employee_role` mapping hardcoded 4/3/1 + whitelist role tidak lengkap (P2-F14-F). Gap: per Q1=A yang diperbaiki di Fix #14 = owner_update_role; dua lainnya berstatus Work Queue.

§6.6 **Bacaan level** — `get_my_role(p_nrp)` percaya param (P1-F14-D, Q2=A patch NULL→authz_current_nrp).

§6.7 **Tier gate** — business_units tier=4 semua vs minimum_tier_required max 3 → tidak pernah memblokir (P2-F14-G). Q3=A: Fix #14 TIDAK menyentuh tier.

§6.8 **Estimasi kompleksitas Fix #14** (fakta-driven, bukan rencana — rencana final di B3):
- Skala keseluruhan: **M (medium)**.
- DB: ±1 migrasi — seed/update `user_roles.role_level` (17 baris, peta §3), fix `owner_update_role` (kolom audit), patch `get_my_role`; regenerasi baseline (Fix #9) + sinkron artefak (CONSTANTS-INVENTORY: §7.4 Functions/Migrations ikut berubah).
- src/ (±6 file inti): RoleGuard.tsx (baca role_level / longgarkan isolasi entry), App.tsx (3 route literal), supabase-browser.ts (entryFromRole + kontrak multi-view), types/index.ts (UserSession.entry), business-units.ts (:247), RoleMatrixPage.tsx (label level 4/5); Home.tsx kemungkinan tidak sentuh (email sudah default).
- Dokumen wajib ikut: SECURITY.md §3.1+§7.6 (P2-F14-A/B), ARCHITECTURE.md §7.2 (Layer 1-2 + multi-view), CONSTANTS-INVENTORY §1.3.
- Risiko terbesar: kontrak session (breaking 8 titik `.entry` / 6 file) + uji E2E 4-page smoke (G6).

## §7 — Data model final (Opsi C')

Prinsip: JOB LEVEL ≠ ADMIN ROLE ≠ PERMISSION ≠ DATA SCOPE.

| Konsep | Sumber |
|---|---|
| Job level | user_roles.role_level (1–5) |
| Baseline worker role | user_roles.role (dipertahankan — sumber sesi login_worker) |
| Admin role | user_role_assignments.role_code (admin_pusat, admin_hrd, ...) |
| Permission | role_permission_sets + permission_set_items |
| Scope | user_role_assignments.scope_type + scope_bu_id + is_primary |

Deprecate (jangan drop):
- user_roles.scope_divisi — semantik sudah mati (NULL semua → COALESCE selalu 'FREE'), 3 pembaca kosmetik.

Tidak berubah:
- user_roles.role tetap di-maintain (login_worker, login_worker_by_email, gate OTP/admin, edge).
- RLS user_roles tetap lewat authz_* (baca user_role_assignments).

## §8 — Backfill data user_role_assignments — ✅ CLOSED (2026-10-01, commit `6ffc890`)

Status: **CLOSED**. Diterapkan ke DB live lewat migrasi `255` + `256`, diverifikasi ulang
2026-10-01, sudah di-commit (`6ffc890`) dan di-push (`origin/migrasi-vite` = `6ffc890`).

Rencana §8 di bawah ditulis 2026-09-30 (B3). Eksekusinya **menyimpang sengaja** dari tabel
rencana — sesuai keputusan K1–K5 user 2026-10-02; lihat "State transisi (K1α)". Bagian
§9–§13 tetap utuh dan belum dieksekusi.

Idempotent (INSERT ... ON CONFLICT DO NOTHING atau cek EXISTS dulu).

| NRP | role_code | scope_type | scope_bu_id | is_primary |
|---|---|---|---|---|
| NRP100 | admin_pusat | ENTERPRISE | NULL | TRUE |
| NRP101 | admin_hrd | DEPARTMENT | NULL | TRUE |
| NRP102 | admin_finance | DEPARTMENT | NULL | TRUE |
| NRP103 | admin_operasional | DEPARTMENT | NULL | TRUE |
| NRP104 | admin_mining | BU | BU01 | TRUE |
| NRP105 | admin_mill | BU | BU03 | TRUE |
| NRP106 | admin_estate | BU | BU02 | TRUE |

NRP001 (CEO), NRP002–010 (Worker): TIDAK dapat assignment admin.

### State transisi (K1α)

Setelah migrasi 255 + 256, state role di live:

| NRP | role | role_level (sebelum → sesudah) | assignment |
|---|---|---|---|
| NRP001 (CEO) | `admin_pusat` (**dipertahankan**) | 1 → **5** | **dihapus** (sebelumnya 1 baris `admin_pusat`) |
| NRP100 | `admin_pusat` | 1 → **3** | `admin_pusat` / ENTERPRISE / `BU04` (tak berubah) |
| NRP101 | `admin_hrd` | 1 → **3** | `admin_hrd` / ENTERPRISE / `BU04` (tak berubah) |
| NRP102 | `admin_finance` | 1 → **3** | `admin_finance` / ENTERPRISE / `BU04` (tak berubah) |
| NRP103 | `admin_operasional` | 1 → **3** | `admin_operasional` / ENTERPRISE / `BU04` (tak berubah) |
| NRP104 | `admin_mining` | 1 → **3** | `admin_mining` / BU / `BU01` (tak berubah) |
| NRP105 | `admin_mill` | 1 → **3** | `admin_mill` / BU / `BU03` (tak berubah) |
| NRP106 | `admin_estate` | 1 → **3** | `admin_estate` / BU / `BU02` (tak berubah) |
| NRP002–010 | `worker` | 1 → **1** (no-op) | `worker` / SELF (tak berubah) |

**NRP001 masih memakai `role='admin_pusat'`** — sengaja. Rename ke `'ceo'` **DITUNDA** ke §9/§10
karena (a) CHECK `user_roles_role_check` tidak memuat `'ceo'`, dan (b) 61 file di `src/`
menyebut literal `admin_pusat`. `role_level=5` sudah memberi CEO seluruh hak akses modul
(lihat Bukti/smoke), jadi **zero lock-out** NRP001 selama transisi.

**`employees_master.role_level` ikut dicerminkan** (NRP001=5, NRP100–106=3) walau kolom itu
vestigial (sebelumnya semua 0 dan tidak meng-gate apa pun) — dicerminkan supaya tidak
menjadi drift baru.

**Divergence dari rencana §8:** tabel rencana menyebut NRP101–103 = `DEPARTMENT` dengan
`scope_bu_id` NULL, dan NRP100 `scope_bu_id` NULL. Live sekarang semua NRP100–103 =
`ENTERPRISE` dengan `scope_bu_id='BU04'`. Ini **keputusan K2/K3 user** (divisi NULL untuk
NRP100–106 → `DEPARTMENT` selalu FALSE; `scope_bu_id` BU04 sengaja dipertahankan agar
`ON CONFLICT` tetap idempoten). Rencana tabel di atas **tidak** diubah; yang berlaku adalah
tabel state transisi ini.

Reversibel: `supabase/scripts/rollback/255_rollback.sql` (52 baris) dan
`supabase/scripts/rollback/256_rollback.sql` (50 baris). Rollback = keputusan terpisah
(§0.17), tidak dijalankan otomatis.

### Bukti

Semua READ ONLY (`BEGIN READ ONLY` … `ROLLBACK`), probe `.agents/scripts/fix14-b219-verify-255.mjs`
dan `.agents/scripts/fix14-b220-verify-256-smoke.mjs`, dijalankan ulang **2026-10-01**.

**E1 — registry apply sukses** (`schema_migrations`, 2 baris):
```
{"version":"255","filename":"255_fix14_backfill_level_nrp001_role.sql","checksum":"04ba81a1197bb91161954c6f9b993e750a09b8905cb251a2a61905b7c925cbb7","applied_at":"2026-10-02T06:41:07.566Z"}
{"version":"256","filename":"256_fix14_owner_assign_level_map.sql","checksum":"8126bf1b15c49ad65c33a86cd5b802f3ceca504f9946721b00bc132e1f4240ed","applied_at":"2026-10-02T06:41:31.393Z"}
{"version":"255","filename":"255_fix14_backfill_level_nrp001_role.sql","ok":true}          ← verify_migration_checksum
```
Cross-check checksum file lokal via wrapper (mode dry-run default, **tidak** eksekusi SQL) —
`status: SUDAH terdaftar (checksum cocok)` untuk kedua berkas, EXIT 0 → file yang di-commit
adalah file yang benar-benar dieksekusi.

**E2 — DoD-255** (`user_roles`, 17/17 baris): NRP001=**5**; NRP002–010=**1** (tidak berubah);
NRP100–106=**3**. `employees_master`: NRP001=5, NRP100–106=3, worker 0.
`user_role_assignments` = `{"total":16,"nrp001":0}` (17→16). Assignment NRP100/104/106 utuh
persis: `admin_pusat/ENTERPRISE/BU04`, `admin_mining/BU/BU01`, `admin_estate/BU/BU02`.
Audit trail: 8 baris `actor=SYSTEM`, `action="UPDATE user_roles"`, `detail` berisi old+new,
rantai `prev_hash`/`row_hash` menyambung → `{"actor":"SYSTEM","n":8}`.

**E3 — prosrc 256** (`pg_proc`, `proname='owner_assign_admin_user'`):
```
{"punya_LIKE_admin_pct_THEN_3":true,"masih_punya_5_4_3":false,"masih_punya_THEN_4":false}
{"prosecdef":true,"proconfig":["search_path=public, extensions"],"provolatile":"v","proisstrict":false,"returns":"jsonb"}
```
Mapping lama 5/4/3 hilang; `SECURITY DEFINER` + `search_path` eksplisit **terus preserve**.

**Smoke gate `role_level`** (impersonasi JWT di dalam transaksi, lalu `ROLLBACK`):
`get_current_user_context` → NRP100 `role_level=3`, NRP001 `role_level=5`, NRP003 `role_level=1`.
`check_module_access(mining_simper|mining_equipment|mining_production)` pada butuh_level 1 & 3:
NRP100 semua **true**, NRP001 semua **true**, NRP003 semua **false** (kondisi data lama
`business_unit_modules`, pre-existing — bukan regresi 255/256). **Akses hanya naik, tidak turun.**

**Rollback teruji byte-identik** (sesi sebelumnya 2026-10-02, probe B2.16–B2.18): simulasi
255 + 256 + kedua file rollback dalam 1 transaksi → `pulih_sepenuhnya = true` untuk
`user_roles`, `employees_master`, `user_role_assignments`, `fn_src` (1121 char) dan `fn_attrs`;
`schema_migrations` tidak tersentuh. ⚠ Grade bukti: **ringkasan hasil probe sesi sebelumnya**,
raw stdout tidak di-archive di `.agents/logs/`.

### Catatan bukti

**stdout asli `apply-migration.mjs --apply` untuk 255 dan 256 TIDAK TERSIMPAN** — tidak ada di
`.agents/logs/` dan tidak ada di konteks saat CLOSED ditulis. Tidak direkonstruksi, karena
§0.16 melarang klaim tanpa output mentah.

CLOSED §8 karena itu dibangun di **bukti pengganti yang lebih kuat dari log apply**:
(1) checksum file di-commit cocok byte-per-byte dengan checksum yang tercatat di
`schema_migrations` hasil eksekusi, (2) `verify_migration_checksum` = `ok:true`,
(3) state data live memenuhi DoD per-versi, (4) `prosrc`/`proconfig`/`prosecdef` live
sesuai, (5) smoke gate tidak regresi, (6) commit `6ffc890` sudah di `origin/migrasi-vite`.

## §9 — Rewiring RPC gate admin (10 RPC) — 🟡 BLOCKER K/H/I/L2/J3 **fully CLOSED** (2026-10-02 257/258/259/260 · 2026-10-03 261/262/263/264/265 · 2026-10-04 266 · 2026-10-05 267), **batch 263–267 CLOSED** — 4 RPC sisanya belum

Item §9 blocker ditutup lewat migrasi `257`/`258`/`259`/`260`/`261`/`262`/`263` (DITERAPKAN +
terdaftar + checksum terverifikasi), lalu batch rewiring `264`–`267`. Registry live per
2026-10-05: `schema_migrations` = **192** baris, `max(version)=267`.
**Batch 263–267 semuanya CLOSED** — lihat blok `### 263` … `### 267` di bawah (267 = rewire OTP:
`verify_admin_otp_core` + `generate_admin_otp`, wildcard `admin\_%` **escaped**).
Sisa **4 RPC** dari rencana §9b belum dieksekusi: batch 268 (`admin_get_role_matrix` +
`admin_set_employee_role`) + 2 belum terjadwal (`get_my_admin_modules`, `get_worker_status`).
Plan batch:
`263` is_admin_or_owner ✅ · `264` check_admin_access ✅ · `265` get_current_user_context ✅ ·
`266` get_user_context_by_auth_id ✅ · `267` verify_admin_otp_core + generate_admin_otp ✅ ·
`268` admin_get_role_matrix + admin_set_employee_role.

| Item | Migrasi | Yang diubah | Bukti apply |
|---|---|---|---|
| **P1-F14-K** | `257` | trigger `trg_audit_user_role_assignments` (AFTER INSERT/UPDATE/DELETE, `_generic_audit_trigger_fixed`) | trigger live `tgenabled='O'`; uji INSERT `NRP999-TEST` → `audit_log` 582→583 (`audit_naik_1: true`), `actor='SYSTEM'` (probe tanpa JWT; fail-safe yang diterima) |
| **P2-F14-H** | `258` | cabang `TEAM` `authz_in_scope`: `ho1.manager_nrp = ho2.manager_nrp` → `ho1.atasan_nrp = ho2.atasan_nrp` | `pakai_atasan_nrp: true`, `masih_manager_nrp: false`; `prosecdef=true`, `provolatile='s'`, `proconfig=["search_path=public, extensions"]` preservasi; smoke `authz_in_scope('NRP002')` = `false` (**bukan** error 42703) |
| **P2-F14-I** | `259` | `admin_produksi` dicabut dari CHECK `user_roles_role_check` (14→13 elemen) + whitelist `is_admin_or_owner` | `jumlah_elemen: 13`, `punya_admin_produksi: false`; `is_admin_or_owner` `LANGUAGE sql` + `STABLE` + `SECURITY DEFINER` preservasi; **uji negatif `23514` check_violation** (CHECK benar-benar aktif) + sanity role valid tetap bisa ditulis |
| **P2-F14-S/T + P3-F14-U** | `265` | `get_current_user_context()`: `role` dari `user_role_assignments.role_code` (fallback `user_roles.role`); `role_level` tetap `user_roles`; owner bypass dipertahankan. Anomali `by_auth_id` (S/T/U) TIDAK disentuh — batch 266 | netralitas **8/8 byte-identik** vs baseline pre-265; owner bypass `is_owner:true`; NRP001 `admin_pusat`; NRP002 `worker`; oid 298319 preserved; attrs + ACL preserved; rollback byte-identik |
| **P2-F14-S/T + P3-F14-U (lanjutan)** | `266` | `get_user_context_by_auth_id()`: **hapus** blok `UPDATE employees_master SET auth_id` (S1) + `role` hybrid dari `user_role_assignments` (fallback `user_roles.role`); **tanpa** owner bypass (**T2 by-design** — owner via `OwnerLogin`). U1a (kode): hapus field mati `divisi`/`posisi` di `initSession` + 4 field interface | netralitas **8/8 byte-identik** vs baseline pre-266; **oid 298467 preserved**; C2 sintetis: auto-repair mati (`repaired=false`) dengan baca tetap utuh; owner tetap `{"ok":false}`; `check:types` EXIT 0; rollback byte-identik |
| **§9 RPC OTP (7+8)** | `267` | `verify_admin_otp_core(p_code text)` + `generate_admin_otp()`: `role` hybrid dari `user_role_assignments.role_code` (fallback `user_roles.role`); whitelist pola **escaped** `admin\_%` (kanon 263:81); E2 CASE override — assignment menang, fallback `user_roles` untuk instalasi tanpa assignment | netralitas OTP **5/5 byte-identik** (NRP001/100/105 + owner PASS, NRP002 REJECT); oid **298610/298267 preserved**; T5 wildcard fix (generik `'admin'` pra-267 LOLOS → pasca REJECT); T6 override terbaca; T7 basi REJECT; ACL tetap tanpa anon; rollback byte-identik |

**Pre-check 259 (wajib, sebelum `DROP CONSTRAINT`)** — `role_di_luar_whitelist: 0`,
`user_roles` `admin_produksi: 0`, `role IS NULL: 0`. Tidak ada data yang bisa membuat
`ADD CONSTRAINT` gagal dan meninggalkan `user_roles` tanpa CHECK.

**Koreksi terhadap draft:** `is_admin_or_owner` adalah `LANGUAGE sql` + `STABLE` (bukan plpgsql).
Migrasi memakai definisi byte-exact hasil `pg_get_functiondef`, jadi volatilitas & bahasa tidak
berubah. Kenaikan `Functions` tetap 658 (tiga migrasi ini tidak menambah fungsi). Kelas bug ini
tidak tertangkap `verify:artifacts` — dicatat sebagai **P2-F14-M**.

### 260 — I2 tahap 2 (penutup): hapus 3 permission set

Setelah 259, `admin_produksi` mustahil ada di `user_roles`, tapi masih punya 3 baris
`role_permission_sets` yang dibaca `authz_has_permission()` — sisa setengah-jadi yang persis
kelas bug yang baru diperbaiki.

| Bukti pra-apply (probe B2.29) | Nilai |
|---|---|
| baris target | 3 (`id` 14/15/16) |
| foreign key ke `role_permission_sets` | **0** (dua metodologi: `information_schema` + `pg_constraint`) |
| RLS policy yang hardcode `admin_produksi` | **0** |
| fungsi yang masih menyebut `admin_produksi` | 1 (`admin_set_employee_role` — §11 P2-F14-F) |
| `permission_set_items` terkait | 27 (14 + 7 + 6) — **tidak dihapus**, dipakai role lain |
| `user_role_assignments` `admin_produksi` | **0** |
| pemakaian 3 set oleh role lain | `worker_basic` 11 · `supervisor_ext` 7 · `manager_ext` 4 → tidak ada set yatim |

Post-apply: `{"n":0}` di `role_permission_sets` · `permission_set_items` tetap **93** ·
distribusi set `worker_basic` 10, `supervisor_ext` 6, `manager_ext` 3, `ada_set_kosong: false`
· registry 185 / `max=260` · sequence `last_value=28` tidak bergeser (INSERT eksplisit id, bukan serial).

**`admin_produksi` = 0 di kelima tempat** (`user_roles`, `user_role_assignments`, `admin_roles`,
`role_page_access`, `role_permission_sets`). Sisa satu-satunya = whitelist `admin_set_employee_role`
(§11 P2-F14-F, sudah terdaftar sebagai item terpisah).

**Pelajaran P7 — pre-image timestamp wajib dari server.** `created_at` kolom ini
`datetime_precision = 6`, tapi driver `pg` truncate tampilan ke **3 digit** desimal, jadi probe
pertama membaca `10:00:41.036` padahal aslinya `10:00:41.**036520**`. Rollback versi pertama
hanya menulis `.036` → hash tabel tidak byte-identik (selisih 2 digit mikrodetik). Simulasi
menangkapnya sebelum apply. Pre-image untuk rollback **wajib** diambil via
`created_at::text` / `to_char(created_at, 'YYYY-MM-DD HH24:MI:SS.USOF')` di sisi server, bukan
dari output driver.

**Pelajaran P8 — `verify:artifacts` buta terhadap perubahan bahasa/volatilitas fungsi.**
Changing `LANGUAGE sql` → `plpgsql` pada `is_admin_or_owner` **tidak** mengubah `Functions`
(658 → 658), jadi gate tetap hijau. Itu sebabnya definisi byte-exact dipakai. Dicatat sebagai
item **P2-F14-M** (butuh guard test), bukan catatan biasa.

**Sisa pekerjaan §9 (belum):** rewiring 10 RPC + rewiring 3 edge function (§10) + test §12.

### 261 — L2: master table `role_codes` (P2-F14-L)

Sebelum 261, `role_code` tersebar di 5 tabel **tanpa constraint silang**. After §9, tabel
`user_role_assignments` menjadi sumber kebenaran tunggal admin — jadi `role_code` palsu di sana
berarti sumber kebenaran berisi role yang tidak dikenal sistem.

`role_codes` harus **tabel mandiri**, bukan FK ke `admin_roles`: `manager` dan `supervisor`
hanya hidup di `role_permission_sets`, tidak punya baris di `admin_roles` — kalau FK diarahkan
ke sana keduanya akan ditolak (terverifikasi, bukan asumsi).

| Bukti pra-apply (probe B2.36, read-only) | Nilai |
|---|---|
| role_code distinct dari 5 sumber | **10** |
| diff CHECK lama minus 5 sumber | **3** — `admin`, `director`, `owner` |
| diff 5 sumber minus CHECK lama | **0** (tidak ada role hilang) |
| union final | **13** — persis sama dengan CHECK lama |
| pre-image CHECK | `len=283`, `md5=bd4d0ad49d6c587a6b0f21a92434da12` |
| tabel `role_codes` bentrok? | `false` |
| sumber lain (`session_store`, `admin_division_access`) | **0 baris** — bukan sumber role |

**Urutan fail-safe (deviasi dari rancangan awal, disengaja):** FK ditambahkan **lebih dahulu**,
CHECK lama di-`DROP` **setelahnya**. Kalau urutannya dibalik dan `ADD FK` gagal, `user_roles`
tertinggal **tanpa validasi sama sekali** di tengah migrasi. Keduanya dalam satu transaksi, jadi
hasil akhirnya identik.

Post-apply: registry 186 / `max=261` · `role_codes` **13 baris** (10 `is_active=true` + 3 `false`)
· FK `fk_ura_role_code` + `fk_ur_role` terpasang, keduanya `REFERENCES role_codes(code)` ·
CHECK `user_roles_role_check` **0 baris** · data utuh (`user_roles` 17, assignments 16) ·
**uji negatif 23503** pada kedua FK (`role_palsu` di `user_roles` DAN `role_palsu_2` di
`user_role_assignments`) — FK benar-benar enforce, bukan sekadar dekoratif.

Simulasi pra-apply: `261 byte-identik: TRUE` · `rollback kedua idempoten: TRUE` · gabungan
261→262→RB262→RB261 byte-identik untuk seluruh state role.

### 262 — J3: assignment transisi NRP001

Temuan investigasi yang mengubah urgensi J3: rantai `authz_check_admin → authz_has_permission`
**sudah live hari ini** dan membaca `user_role_assignments` — **bukan** `user_roles`. NRP001
(CEO, `role='admin_pusat'`, level 5) tidak punya baris assignment, sehingga secara teknis
kehilangan **50 permission** termasuk `employee.update`, `employee.view_all`, `leave.approve`,
`payroll.process`, `audit.view`. Rantai ini menyentuh **15 policy RLS**.

Jadi J3 bukan mitigasi untuk masa depan — itu **perbaikan kondisi yang sedang rusak**.

| Gate (impersonasi claims, auth_id terverifikasi dari DB) | pre-262 | post-262 |
|---|---|---|
| `is_admin_or_owner()` | true | **true** |
| `authz_check_admin('employee.update')` | **false** | **true** |
| `authz_has_role('admin_pusat')` | **false** | **true** |
| `authz_has_permission('audit.view')` | **false** | **true** |
| `authz_has_permission('payroll.process')` | **false** | **true** |

Baris: `id=45`, `admin_pusat`, `ENTERPRISE`, `BU04`, `is_primary=false`, `assigned_by='migration:262'`.
`audit_log` id 662 tercatat (`actor='SYSTEM'` — apply berjalan tanpa JWT context, fail-safe yang
diterima). Registry 187 / `max=262`.

> ⚠️ **`262_rollback.sql` sengaja TIDAK memfilter `is_primary`.** Kalau di §10 assignment NRP001
> di-upgrade jadi permanen dengan `is_primary=TRUE`, predicate rollback **harus diubah lebih dulu**
> atau assignment permanen ikut terhapus. Peringatan ini tertanam di file rollback itu sendiri.

### 263 — Batch 1/5: rewire `is_admin_or_owner()` (P2-F14-N) + restore grant

Applied 2026-10-03 (commit + registry 188 / `max(version)=263`, checksum
`a9707149b0706c574ad6262a4aef5956eee6ad83e521a0b3b6f11c629f20dacb`).

**MASALAH 1 — whitelist gerbang tidak lengkap (P2-F14-N).** Fungsi membaca role lewat
`user_roles` dengan whitelist literal 4 dari 7 admin role:
`IN ('owner','admin_pusat','admin_hrd','admin_finance')`. Hilang:
`admin_operasional`, `admin_mining`, `admin_mill`, `admin_estate` — semuanya role_code
aktif di `role_codes`, punya `role_page_access` sendiri, dan punya permission set khusus.

**MASALAH 2 (temuan baru, blocking) — grant `authenticated` hilang sejak migrasi 172.**
ACL live hanya `{postgres, service_role}`. Policy RLS dievaluasi dengan hak akses role
PEMANGGIL, jadi keenam policy yang memanggil fungsi ini **tidak pernah bisa dievaluasi**:

| policy | tabel | cmd |
|---|---|---|
| `ok_select` | hr_okrs | SELECT |
| `of_select` | offboarding_checklist | SELECT |
| `sc_select` | hr_succession_matrix | SELECT |
| `bu_update` | business_units | UPDATE |
| `hk_update` | hr_kpi_config | UPDATE |
| `st_update` | settings | UPDATE |

Akar: `172_hardening_grants.sql` `REVOKE EXECUTE ON ALL FUNCTIONS` dari
PUBLIC/anon/authenticated lalu grant balik hanya daftar putih; `is_admin_or_owner` tidak ada
di daftar itu (`git grep` = 0 hit). Bandingkan `authz_check_admin` / `authz_has_permission` /
`authz_current_nrp` / `authz_in_scope` yang semuanya punya `authenticated=X`.

**Bukti pre-263 (probe read-only, role=authenticated).** Tiga tabel policy SELECT gagal
**42501 untuk SEMUA user** — bukan hanya 4 admin role, juga `admin_pusat` dan CEO:

```
NRP001..NRP106 + NRP002  SELECT hr_okrs              = 42501
NRP001..NRP106 + NRP002  SELECT offboarding_checklist = 42501
NRP001..NRP106 + NRP002  SELECT hr_succession_matrix = 42501
NRP105 SELECT ai_rate_limits = OK:0   ← pembanding: authz_check_admin punya grant
```

Dampaknya **latent** — UI tidak membaca ketiga tabel itu langsung (`git grep hr_okrs -- src`
= 0 hit; `Offboarding.tsx:95` memakai RPC `get_offboarding_checklist`), jadi tidak pernah
ada user yang komplain. Tetap harus diperbaiki.

**Body baru.** Blok pertama diganti ke `user_role_assignments` + pola `admin\_%` (underscore
di-escape; tanpa escape `adminx` ikut cocok — dibuktikan live). Cabang `authz_is_owner()`
ditambahkan karena owner (`a8a77284-…`) **tidak punya baris di `employees_core`** sehingga
tidak bisa dicocokkan lewat `employees_master`, dan `user_roles.role='owner'` = 0 baris —
tanpa cabang ini owner berubah jadi FALSE (regresi dari 247). Blok kedua yang lama
(`user_roles.role='owner'`) dipertahankan apa adanya. `GRANT EXECUTE` ke `authenticated`
ikut dalam berkas yang sama; **tidak** ada grant ke `anon`.

**Bukti apply (query live pasca-263).**

| Uji | Hasil |
|---|---|
| registry | `schema_migrations` 188 baris, `max(version)=263`, 1 baris version=263 |
| prosrc | `ada_authz_is_owner=true`, `ada_ura=true`, `ada_pola_admin_escaped=true`, `masih_whitelist_lama=false`, `masih_ur_role_in=false` |
| ACL | `{postgres=X/postgres, service_role=X/postgres, authenticated=X/postgres}` — tanpa `anon` |
| attrs preservasi | `sql` · `s` · `secdef=true` · `{search_path=public, extensions}` · `boolean` |
| C1 positif 9/9 | NRP001, NRP100, NRP101, NRP102, NRP103, NRP104, NRP105, NRP106, owner `a8a77284` → **true** |
| C2 negatif 4/4 | NRP002 worker **false** · anon `{}` **42501** · anon ber-sub worker **42501** · sub asing **false** |
| C3 policy RLS | 6 policy × 4 NRP (105/106/103/100) → semua **OK**, 0 × 42501 |
| C4 fail-closed | worker 0 baris di 6 tabel; UPDATE baris nyata ditolak RLS |
| rollback D4 | `md5(pg_get_functiondef)` `6c0fb3d3…` → `18a97b91…` → `6c0fb3d3…` **byte-identik**, ACL kembali persis |

Perubahan inti: `admin_operasional`/`admin_mining`/`admin_mill`/`admin_estate`
**false → true**; owner **tidak berubah** (tetap TRUE lewat `authz_is_owner()`); worker
**tidak berubah** (tetap fail-closed).

> ⚠️ **KLASIFIKASI TIDAK SEPADAT — 3 RPC di §9b TIDAK terpengaruh 263.** Investigasi
> menunjukkan `get_worker_leave` / `get_worker_overtime` / `submit_voice` **tidak** memanggil
> `is_admin_or_owner()` sama sekali; rantainya
> `_is_admin_or_owner_caller()` → `authz_check_admin('employee.view_all')`. Grep substring
> `%is_admin_or_owner%` menyesatkan karena nama helper itu mengandung `is_admin_or_owner`.
> NRP105 tetap `"Akses ditolak."` pada `get_worker_leave` — dan itu perilaku yang benar
> menurut permission, bukan bug grant. Item: **P2-F14-P**.

> ⚠️ **61 dari 208 tabel RLS tidak punya policy SELECT sama sekali** (default-deny).
> Termasuk `business_units` dan `settings`: policy `bu_select`/`st_select` yang dibuat
> migrasi `083` (`USING (TRUE)`) **tidak ada lagi di live**, jadi kedua tabel itu `SELECT 0
> baris` untuk siapa pun — termasuk `admin_pusat` meski `is_admin_or_owner()=true`.
>Ini **tidak** terkait 263 (policy 263 sudah dievaluasi normal). Item: **P2-F14-Q**.

### 264 — Batch 2/5: DROP `check_admin_access` (2 overload, dead code)

Applied 2026-10-03 (registry 189 / `max(version)=264`, checksum
`43eed6f50624d92a0f7d1cee4f65bc7588cd8935caea9912b4b8e6c952a817e5`).

**Konfirmasi 0 caller di 7 sumber** (probe read-only post-263,
log `.agents/logs/fix14-h0-264-probe.log`):

| Sumber | Hasil |
|---|---|
| `src/` (`git grep`) | 0 hit |
| `pg_proc.prosrc` ≠ definisi | 0 baris |
| `pg_policies` qual/with_check | 0 baris |
| `pg_trigger` → `tgfoid` | 0 baris |
| `pg_views` + `pg_matviews` | 0 baris |
| `pg_attrdef` (DEFAULT kolom) | 0 baris |
| `pg_constraint` | 0 baris |
| seluruh schema (bukan cuma `public`) | 2 baris = kedua overload itu sendiri |

`pg_depend` tiap overload: normal=2 (milik schema + kolom `pg_proc`), internal=0 → **DROP
tanpa CASCADE**. ACL pre-264 `{postgres=X/postgres, service_role=X/postgres}` — `authenticated`
dan `anon` TIDAK punya EXECUTE, jadi mustahil dipanggil lewat PostgREST dan nol risiko
kompatibilitas API.

**Dua overload, dua masalah berbeda — dan keduanya alasan DROP lebih baik daripada rewrite:**

1. `check_admin_access()` → boolean, prosrc 210 byte.
   Membaca `current_setting('request.jwt.claims', true)::json->>'role'`. Supabase **tidak pernah**
   mengisi claim `role` — claim itu berisi sub/email/app_metadata, bukan nilai role aplikasi
   (role ada di `user_roles`/`user_role_assignments`). Jadi fungsi ini secara struktural
   **selalu FALSE** untuk sesi Supabase mana pun. Sisa policy konfirmasi era-083 yang tidak
   pernah lagi relevan.

2. `check_admin_access(p_path text)` → jsonb, prosrc 2093 byte.
   Logikanya masih masuk akal (owner bypass → `user_roles` → `admin_roles` →
   `role_page_access`, default deny) **tapi** chain-nya salah untuk §9:
   `SELECT ur.role INTO v_role FROM user_roles ur … ORDER BY ur.role_level DESC LIMIT 1`
   membaca role dari `user_roles`, sementara sumber kebenaran admin setelah §9 adalah
   `user_role_assignments` + permission set. Kalau dihidupkan, dia butuh rewrite total —
   bukan pemulihan sebagian. Dan tidak ada satu pun pemanggil yang membutuhkan dia hidup.

**Bukti apply (query live pasca-264):**

| Uji | Hasil |
|---|---|
| registry | `schema_migrations` 189 baris, `max(version)=264`, 1 baris version=264 |
| overload tersisa | **0** |
| `Functions` | 658 → **656** (overload 20 → 19) |
| pemanggilan | `check_admin_access()` → **42883** · `check_admin_access('/admin')` → **42883** |
| sanity | policy tetap 225 · tabel tetap 209 · `check_owner_identity()` tetap ada · `audit_log` 583 → 587 (login a11y) · `ura` 17 |
| authz utuh | `is_admin_or_owner` md5 `18a97b91…` + acl `{postgres,service_role,authenticated}`; 5 helper `authz_*` md5 tidak berubah |

**Rollback byte-identik** (simulasi pra-apply, `.agents/logs/fix14-h1-simulasi-264.log`,
19 PASS / 0 FAIL): `md5(pg_get_functiondef)` `0106fcb4…` → rollback `0106fcb4…`
dan `5aeaa26c…` → `5aeaa26c…`; `md5(prosrc)` `970bd74b…` / `0f0ce77c…` identik; panjang
prosrc 210 / 2093 identik; **ACL identik**; privilege post-rollback
anon=false auth=false svc=true = pre-264.

### 265 — Batch 3/5: rewire `get_current_user_context()` hybrid (P2-F14-S/T, P3-F14-U)

Applied 2026-10-03 (registry **190** / `max(version)=265`, checksum
`da1bb156859f2eca89bed144178ccaf56c5ec69a6778cfe5b69a2c654856482a`, 1022ms).

**Perubahan = 3 hunk, tidak ada yang lain** (dibuktikan *inverse proof*: body baru dengan 3
hunk dibalik ke bentuk lama **===** pre-image persis):

1. `DECLARE`: tambah `v_assign_role TEXT;`
2. Setelah `SELECT * INTO v_role FROM user_roles ...`: `SELECT a.role_code INTO v_assign_role`
   `FROM user_role_assignments a WHERE a.nrp = v_emp.nrp`
   `ORDER BY a.is_primary DESC NULLS LAST, a.role_code ASC LIMIT 1;`
3. `RETURN`: `'role'` → `COALESCE(v_assign_role, v_role.role, 'worker')`

**Yang sengaja tidak berubah:** `role_level` tetap dari `user_roles` (assignment tidak punya
kolom level) · owner bypass `check_owner_identity()` dipertahankan · signature `() -> jsonb` +
return shape + urutan key identik · attrs (plpgsql/VOLATILE/SECDEF/`search_path`) tidak disentuh ·
anomali `by_auth_id` (B-1/B-2/B-3) tidak disentuh — batch 266.

**Kenapa netral (bukti C1):** 17/17 `user_role_assignments.role_code` identik dengan
`user_roles.role`; 0 user dengan >1 assignment (ORDER BY deterministik); 0 `user_roles` tanpa
assignment dan 0 assignment tanpa `user_roles`. Jadi `COALESCE(...)` menghasilkan nilai yang
sama untuk SEMUA 17 user.

| Uji | Hasil |
|---|---|
| registry | 190 baris, `max(version)=265`, checksum cocok |
| oid | **298319 preserved** (CREATE OR REPLACE, bukan DROP+CREATE) |
| attrs | plpgsql · `v` · `prosecdef=true` · `search_path=public, extensions` — preserved |
| ACL | `{postgres,authenticated,service_role}` preserved · **anon tetap tanpa EXECUTE** |
| `Functions` | tetap **656** (265 tidak menambah fungsi) |
| def/prosrc | 1211 → 1621 · 1032 → 1442 (`md5` `29f0f732...` / `666bf8ef...`) |
| C1 netralitas | **8/8 byte-identik** vs baseline pre-265 (NRP001/002/100/101/102/105 + owner + uuid nol) |
| C2 owner bypass | `is_owner:true` · `role:owner` · `role_level:5` · `nrp:OWNER001` · `bu:null` |
| C3 NRP001 | `role:admin_pusat` (assignment 262, `is_primary=false`) · `role_level:5` (user_roles) |
| C4 NRP002 | `role:worker` · `role_level:1` |
| D4 rollback | byte-identik + ACL restore: `md5(def)` `29f0f732...` → `65c9b578...` · oid preserved · D4a-D4g PASS |
| E5 read-path | assignment NRP002 → `admin_estate` ⇒ `role` ikut berubah; `role_level` tetap 1; restore ⇒ byte-identik |

Simulasi pra-apply: **30/30 PASS** (2 FAIL awal palsu — artefak komparator, lihat pelajaran di bawah).

**Pelajaran perluasan P7/P13 — komparator byte-identik wajib pakai teks in-tag.**
`pg_get_functiondef()` mengembalikan trailing `\n`; `prosrc` adalah teks **di antara** tag
dollar-quote termasuk newline pembuka+penutup. Ekstraksi line-slice kehilangan tepat 2 byte →
`md5(prosrc)` beda walau isi identik. Gate yang benar: `def` vs file+`\n`, dan `prosrc` vs
regex tag dollar-quote.

**Pelajaran baru — `String.replace` dengan string replacement berbahaya untuk markdown.**
Replacement string JS memperlakukan `$&`, `` $` ``, `$'`, `$1` sebagai pola substitusi.
Teks yang memuat `` `$function$` `` berakhiran `` $` `` = "seluruh prefix match" → seluruh isi
file tersuntik ke tengah → **file terduplikasi** (1125 → 2239 baris) dan tidak terlihat di diff
singkat. Wajib function replacer: `s.replace(old, () => newS)`. Kerusakan ditemukan dan
dipulihkan dengan `git checkout --` sebelum commit; tidak ada byte korup yang masuk commit.
### Pelajaran proses P12 — rollback `DROP FUNCTION` WAJIB sertakan restore ACL

Default privilege fungsi baru di PostgreSQL adalah EXECUTE untuk owner **dan PUBLIC**.
ACL pre-264 sengaja **tidak** mengandung PUBLIC (migrasi 172 me-`REVOKE EXECUTE ON ALL
FUNCTIONS` lalu grant hanya service_role). Kalau `264_rollback.sql` hanya
`CREATE OR REPLACE` tanpa `REVOKE` eksplisit, hasilnya
`proacl = {postgres=X/postgres, =X/postgres}` — setiap role bisa memanggil fungsi
`SECURITY DEFINER` ini, dan `role_page_access`/`admin_roles` ikut terekspos. Itu
mengembalikan **security hole**, bukan pre-image.

Aturan: untuk rollback yang memakai `CREATE OR REPLACE`, **ACL adalah bagian dari definisi
"byte-identik"**, bukan hiasan. Bandingkan `proacl` pre-drop vs post-restore secara
eksplisit — jangan hanya bandingkan `pg_get_functiondef`, karena functiondef **tidak**
memuat ACL sama sekali. Gate yang dipakai di simulasi 264:
`md5 functiondef` + `md5 prosrc` + panjang + `proacl` + `has_function_privilege` per role.

### Pelajaran proses P13 — OID berubah setelah DROP + CREATE, itu normal

Simulasi 264 menunjukkan oid `298204` → `336335` dan `298205` → `336336`, meski transaksi
seluruhnya di-`ROLLBACK`. Bukan drift: **OID counter PostgreSQL tidak pernah di-rollback**.
Konsekuensi praktis untuk semua gate byte-identik: **kunci perbandingan ke signature**
(`pg_get_function_identity_arguments`), **jangan** ke `oid`, karena setiap simulasi kedua akan
melahukan gate yang sebenarnya hijau. Kelas bug yang sama seperti **P3-F04-01**.

### Pelajaran proses P10 — whitelist grant yang melewatkan fungsi kritis

Kelas bug berulang yang harus di-hole. `172_hardening_grants.sql` Intentional "end-state
deterministik: revoke semua, grant minimal" — tapi daftar putih itu **dipilih manual** dan
fungsi yang tidak masuk daftar **mati senyap**, bukan error yang terlihat. Gejalanya:
policy RLS tetap tertulis di `pg_policies`, jadi `verify:artifacts` menghitungnya sebagai
policy yang ada; yang mati adalah **permission untuk mengevaluasinya**. Tidak ada guard
mana pun yang membandingkan `proacl` fungsi terhadap daftar policy yang memanggilnya.
Migrasi 263 menutup satu kasus; **46 fungsi lain** di `public` juga tidak punya
`EXECUTE` untuk `authenticated` (Work Queue **P1-ACL-AUDIT**).

Aturan turunan: setiap policy RLS yang memanggil `SECURITY DEFINER` helper WAJIB punya
`EXECUTE` untuk role yang di-shadow. Menambah policy tanpa grant = policy mati.

### Pelajaran proses P11 — grep substring menyesatkan untuk memetakan caller

`prosrc ILIKE '%is_admin_or_owner%'` mengembalikan 5 pemanggil, dan itu **salah 3**:
`_is_admin_or_owner` dan `_is_admin_or_owner_caller` mengandung string itu sebagai
**substring nama**, lalu `get_worker_leave`/`get_worker_overtime`/`submit_voice` memanggil
*helper* itu, bukan `is_admin_or_owner`. Rantai sebenarnya lewat `authz_check_admin`.
Verifikasi caller harus baca `pg_get_functiondef` per fungsi, bukan Uncategorized



Simulasi rollback 262 menunjukkan `audit_n` 582→583→584 lalu "tidak kembali". Itu **bukan
drift**. Probe terpisah (B2.38) membuktikan:

```
T0 sebelum transaksi          : audit_log=582
T1 di dalam trx, setelah 262   : audit_log=583   (+1, trigger 257)
T2 di dalam trx, setelah RB    : audit_log=584   (DELETE juga tercatat)
T3 SETELAH ROLLBACK transaksi  : audit_log=582   ← pulih
```

Pengukuran di dalam transaksi **sebelum** `ROLLBACK` selalu terlihat "menyimpang" untuk tabel
yang punya trigger audit. Ukur ulang **setelah** `ROLLBACK`, di koneksi baru. `audit_log` punya
`trg_audit_hash_chain` sendiri (bukan trigger audit generik), jadi tidak rekursif.

### 266 — Batch 4/5: rewire `get_user_context_by_auth_id()` + hapus auto-repair UPDATE (P2-F14-S/T + P3-F14-U)

Applied 2026-10-04 (registry **191** / `max(version)=266`, checksum
`22c370546ad6bc9a7fecaf3cfab9b8d18852cf005cc138289b3268655d44d3a9`, 1230ms).

**Perubahan = 4 hunk, tidak ada yang lain** (dibuktikan *inverse proof*: body baru dengan 4
hunk dibalik ke bentuk lama **===** pre-image persis; `def_len` 1666 → 1922, `prosrc` 1470 → 1726):

1. `DECLARE`: tambah `v_assign_role TEXT;`
2. **Hapus** blok `IF FOUND THEN UPDATE employees_master SET auth_id = p_auth_id`
   `WHERE nrp = v_emp.nrp; END IF;` — satu-satunya jalur tulis di fungsi "get" (keputusan user
   **S1**, P2-F14-S) → fungsi jadi **read-only murni**.
3. Tambah `SELECT a.role_code INTO v_assign_role FROM user_role_assignments a`
   `WHERE a.nrp = v_emp.nrp ORDER BY a.is_primary DESC NULLS LAST, a.role_code ASC LIMIT 1;`
   (disamakan dengan 265).
4. `RETURN`: `'role'` → `COALESCE(v_assign_role, v_role.role, 'worker')`.

**Yang sengaja tidak berubah:** fallback baca via email (`SELECT` saja, tanpa efek tulis) TETAP ·
`role_level` / `bu` / `unit_code` / `tier` / `divisi` / `jabatan` identik · signature + attrs +
ACL tidak disentuh · **TIDAK** ada owner bypass (keputusan **T2**: owner lewat `OwnerLogin`,
`by_auth_id` tetap `{"ok":false}` untuk owner — **by-design**, bukan bug; `Home.tsx` tidak diubah).

| Uji | Hasil |
|---|---|
| registry | 191 baris, `max(version)=266`, checksum cocok |
| oid | **298467 preserved** (CREATE OR REPLACE, bukan DROP+CREATE) |
| attrs | plpgsql · `v` · `prosecdef=true` · `search_path=public, extensions` — preserved |
| ACL | `{postgres,authenticated,service_role}` preserved · **anon tetap tanpa EXECUTE** |
| `Functions` | tetap **656** (266 tidak menambah fungsi) |
| C1 netralitas | **8/8 byte-identik** vs baseline pre-266 (NRP001/002/100/101/102/105 + owner + uuid nol) |
| C2 uji S1 | NRP002 `auth_id=NULL` dalam tx → panggilan `by_auth_id` **tidak me-repair** (`repaired=false`, `auth_id` tetap NULL); output baca tetap **byte-identik** baseline NRP002 |
| C1c dampak | **0 baris** `employees_master` email-match `auth.users` dengan `auth_id` beda → jalur UPDATE **tidak terjangkau** pada data sekarang; 1 `auth.users` tanpa employee link = owner (T2, memang tidak lewat `by_auth_id`) |
| U1a kode | `divisi`/`posisi` dihapus dari `initSession` + 4 field interface (`UserSession` + `CurrentUserContext`) — **0 konsumen**, `check:types` EXIT 0 |

Simulasi pra-apply: rollback byte-identik (`md5(def)` `13afaf04…` → `9cf05457…` → `13afaf04…`,
oid preserved, ACL preserved, registry 190/265 tidak tersentuh) + dry-run `apply-migration.mjs`
EXIT 0 sebelum apply.

**Pelajaran baru — D2: hapus field "mati" hanya sah setelah membaca interface.** Asumsi awal:
`UserSession` tidak punya `divisi?`/`posisi?` sehingga cukup bersihkan `initSession`. Fact live:
kedua field MEMANG ada di `UserSession` + `CurrentUserContext` (`src/types/index.ts`), jadi
perbaikan yang benar = hapus 2 baris `initSession` **dan** 4 field interface (keputusan user **U1a**).

### 267 — Batch 5/5: rewire OTP `verify_admin_otp_core` + `generate_admin_otp` (P15 wildcard escaped)

Applied 2026-10-05 (registry **192** / `max(version)=267`, checksum
`553ed3adb898ffcdb846c70d811629e0052fd5b48e19e7083ce16a181273316b`, 1022ms).

**Perubahan = 5 hunk, tidak ada yang lain** (dibuktikan *inverse proof*: body baru dengan 5
hunk dibalik === pre-image persis; `def_len` verify 2438 → 2893 / generate 2320 → 2817;
`prosrc` verify 2251 → 2706 / generate 2147 → 2644):

1. `verify_admin_otp_core` `DECLARE`: tambah `v_assign_role TEXT;`.
2. `verify_admin_otp_core`: tambah `SELECT a.role_code INTO v_assign_role FROM user_role_assignments a
   WHERE a.nrp = v_nrp ORDER BY a.is_primary DESC NULLS LAST, a.role_code ASC LIMIT 1;`
3. Gate `verify_admin_otp_core`: `v_role.role` → `COALESCE(v_assign_role, v_role.role)`; whitelist
   `... <> 'owner' AND ... NOT LIKE 'admin\_%'` — **escaped**, `_` literal (kanon migrasi 263:81).
4. `RETURN` `verify_admin_otp_core`: `'role'` → `COALESCE(v_assign_role, v_role.role, 'admin_pusat')`
   (fallback dipertahankan agar pemanggil lama tetap aman).
5. Gate `generate_admin_otp`: → `SELECT CASE WHEN EXISTS(assignment untuk v_nrp) THEN
   EXISTS(assignment role_code LIKE 'admin\_%') ELSE EXISTS(user_roles owner|admin\_%) END
   INTO v_is_admin;` (**E2**: assignment menang; fallback `user_roles` untuk instalasi baru
   tanpa assignment).

**Wildcard fix — inti 267.** Pra-267 gate memakai `LIKE 'admin_%'` **polos**; di `LIKE`, `_`
adalah wildcard 1 karakter sehingga role generik `'admin'` LOLOS gate (celah, terbukti T5
pra-267). Pasca-267 pola **escaped** `'admin\_%'` = literal `admin_` + apa pun: `'admin'` polos
**REJECT**. Kanon pola diambil dari 263:81 (`bukan 'admin_%' polos`).

| Uji | Hasil |
|---|---|
| registry | 192 baris, `max(version)=267`, checksum cocok |
| oid | **298610** (verify) + **298267** (generate) **preserved** (CREATE OR REPLACE, bukan DROP+CREATE) |
| attrs | plpgsql · `v` · `prosecdef=true` · `search_path=public, extensions` — preserved |
| ACL | `{postgres,authenticated,service_role}` preserved · **anon tetap tanpa EXECUTE** (wrapper publik `verify_admin_otp` + grant anon pra-sesi dari 231 TIDAK disentuh) |
| `Functions` | tetap **656** (267 tidak menambah fungsi) |
| C1 netralitas | **5/5 byte-identik** vs baseline pre-267: NRP001/100/105 + owner PASS, NRP002 REJECT |
| C2 T5 wildcard | `'admin'` generik tanpa assignment: pra-267 **generate=true + verify=true (LOLOS)** → pasca-267 **generate=false + verify=false (REJECT)** |
| C2 T6 override | assignment `admin_pusat` + `user_roles.role='worker'` → **PASS** (assignment dibaca; pra-267 DITOLAK) |
| C2 T7 basi | assignment `worker` + `user_roles.role='admin_pusat'` → **REJECT** (user_roles basi tidak menyelamatkan; pra-267 LOLOS) |
| C3 regression | NRP100 (admin_pusat) → gate PASS + verify sukses, identik simulasi |
| P9 residu | `audit_log` 587, `otp_store` 0, `otp_attempts` 0, `session_tokens` 357 — nol residu (diukur di koneksi baru setelah ROLLBACK) |

Simulasi pra-apply: rollback byte-identik (F4 TRUE), oid + ACL + attrs preserved di 3 stage,
registry 191/266 tidak tersentuh, dry-run `apply-migration.mjs` EXIT 0 sebelum apply.

**Pelajaran baru — P15: wildcard `_` yang lolos review.** `LIKE 'admin_%'` "terlihat sama" dengan
`LIKE 'admin\_%'` di mata reviewer, tapi artinya beda: `_` = wildcard 1 karakter vs literal
underscore. Dua fungsi OTP memakai pola polos itu sejak lama tanpa gate; satu tes sintetis
(role `'admin'` generik tanpa assignment) cukup untuk membuktikan celahnya. **Aturan turunan:**
setiap whitelist pola role di `LIKE` wajib escaped + punya uji negatif sintetis.

### §9b — Rencana rewiring 10 RPC (**6/10 selesai** via 263/264/265/266/267; sisanya 4)

Ubah dari baca user_roles.role → baca admin_role via user_role_assignments.role_code (JOIN role_permission_sets sesuai authz_has_permission existing):

1. is_admin_or_owner ✅ **CLOSED via 263**
2. check_admin_access ✅ **CLOSED via 264 — DROP, bukan rewrite**
3. get_my_admin_modules
4. get_current_user_context ✅ **CLOSED via 265** (hybrid: role dari assignments, role_level tetap user_roles)
5. get_user_context_by_auth_id ✅ **CLOSED via 266** (`role` hybrid dari assignments + hapus auto-repair `UPDATE auth_id` — S1; T2 by-design)
6. get_worker_status
7. verify_admin_otp_core ✅ **CLOSED via 267** (rewire + wildcard escaped `admin\_%` + override assignment E2)
8. generate_admin_otp ✅ **CLOSED via 267** (CASE override assignment + fallback `user_roles`)
9. admin_get_role_matrix (sesuaikan sumber level+scope)
10. admin_set_employee_role (lihat §11)

TETAP baca user_roles.role + role_level:
- login_worker, login_worker_by_email (entry sesi worker) — TIDAK diubah.

## §10 — Rewiring edge function (3 hit)

- supabase/functions/password-reset/index.ts:138 — .select("role") → ganti via authz_current_nrp() + assignments.role_code
- supabase/functions/password-reset/index.ts:285 — sama
- supabase/functions/ai-copilot/index.ts:86-87 — sama

Gate: isAdmin = role_code.startsWith("admin") (dari assignments, bukan user_roles.role).

## §11 — Perbaikan RPC rusak (Fix #14)

1. owner_update_role — INSERT audit_log_owner pakai skema riil 9 kolom:
   (id, owner_nrp, action, target_type, target_id, old_value, new_value, ip_address, created_at).
2. get_my_role(p_nrp) — ganti p_nrp → authz_current_nrp(). Jangan percaya param.
3. admin_set_role — implementasi 3 param yang selama ini diabaikan.
4. admin_set_employee_role — mapping lengkap: worker/supervisor/manager/director/ceo + admin_* (termasuk admin_operasional, admin_industri bila ada). Bukan hardcoded 4/3/1.
5. get_my_role / get_my_plan — berhenti pakai scope_divisi sebagai 'tier'/'plan'. Pakai sumber benar (role_level / assignments).

## §12 — Test + verifikasi

Unit test (gate audit rules):
- job_level >= 3 → manager; >= 4 → director; === 5 → CEO
- admin_role === 'admin_pusat' → gate admin, terlepas dari role_level
- Pola salah `role_level >= 4 allowFullAdmin()` harus GAGAL di test.

Integration test:
- NRP100 (lvl 3, admin_pusat, ENTERPRISE) → akses ALL company
- NRP104 (lvl 3, admin_mining, BU01) → akses BU01 saja, BUKAN BU02/BU03
- Worker NRP002 (lvl 1) → /worker saja

Regression:
- login_worker + login_worker_by_email tetap hijau (role dari user_roles)
- generate_admin_otp + verify_admin_otp_core tetap hijau (via assignments)
- RLS user_roles masih valid (authz_* tetap lewat assignments)

CI: hijau (types/lint/test/build) di HEAD setelah eksekusi.

### 2026-10-03 — Batch 263 CLOSED (P2-F14-N) + grant restoration

Keputusan: **Opsi 1** (rewire + `GRANT EXECUTE` dalam satu migrasi `263`), bukan dipisah
menjadi dua nomor. Alasan: tanpa grant, 6 policy RLS tetap 42501 dan hasil fix tidak bisa
diobservasi sama sekali — memisahkannya hanya menambah satu titik gagal di tengah.

Hasil: `263` DITERAPKAN + terdaftar + checksum terverifikasi; registry 188 / `max=263`;
C1 9/9 positif, C2 4/4 negatif, C3 6 policy tanpa 42501, C4 worker tetap fail-closed,
rollback byte-identik. 4 item Work Queue didaftarkan: **P2-F14-O** (wrapper
`rpcGetWorkerStatus` tanpa `p_nrp`), **P1-ACL-AUDIT** (46 fungsi tanpa grant
`authenticated`), **P2-F14-P** (`employee.view_all` hanya dimiliki `admin_hrd` +
`admin_pusat`), **P2-F14-Q** (61 tabel RLS tanpa policy SELECT). Pelajaran baru **P10**
(whitelist grant yang melewatkan fungsi kritis) dan **P11** (grep substring menyesatkan
untuk memetakan caller).

## §13 Riwayat keputusan
- 2026-10-05: **batch 267 CLOSED** — migrasi `267` (rewire OTP: `verify_admin_otp_core` + `generate_admin_otp` — `role` hybrid dari `user_role_assignments.role_code` fallback `user_roles.role`; whitelist `admin\_%` **escaped**; E2 CASE override + fallback) DITERAPKAN + terdaftar; registry **192** baris / `max=267`, checksum `553ed3ad…`. Netralitas OTP **5/5 byte-identik**; oid **298610/298267 preserved**; wildcard fix T5 terbukti (generik `'admin'` pra-267 LOLOS → pasca REJECT kedua fungsi); T6 override assignment terbaca, T7 `user_roles` basi REJECT; nol residu P9. Pelajaran **P15**: wildcard `_` di `LIKE` (`admin_%` polos) lolos review — wajib escaped + uji negatif sintetis.
- 2026-10-04: **batch 266 CLOSED** — migrasi `266` (rewire `get_user_context_by_auth_id()`: `role` hybrid dari `user_role_assignments` + **hapus auto-repair `UPDATE employees_master SET auth_id`** — S1/P2-F14-S; T2 by-design: owner tetap `{"ok":false}` lewat `by_auth_id`) DITERAPKAN + terdaftar; registry **191** baris / `max=266`. Netralitas **8/8 byte-identik**; **oid 298467 preserved**; C2 sintetis membuktikan auto-repair mati (`repaired=false`) dengan baca tetap utuh; C1c: 0 baris jalur repair terjangkau. **U1a**: hapus 4 field `divisi?`/`posisi?` (`UserSession` + `CurrentUserContext`) + 2 baris `initSession` — 0 konsumen, `check:types` EXIT 0. Item baru **P2-F14-V** (audit coverage `employees_master`/`employees_core` tanpa `trg_audit_*`). Pelajaran **P14** (sync dokumen tidak sah divalidasi dari exit-code skrip; `verify:artifacts` wajib dijalankan ulang setelah sync, sebelum commit).
- 2026-10-03: **batch 265 CLOSED** — migrasi `265` (rewire `get_current_user_context()` hybrid: `role` dari `user_role_assignments.role_code` + fallback `user_roles.role`, `role_level` tetap dari `user_roles`, owner bypass dipertahankan) DITERAPKAN + terdaftar; registry **190** baris / `max=265`. Netralitas **8/8 byte-identik** karena 17/17 `role_code` assignment identik dengan `user_roles.role` + 0 user multi-assignment; oid **298319 preserved**, attrs + ACL preserved; rollback byte-identik + ACL restore (D4a-D4g PASS); read-path proof E5 membuktikan `role` benar-benar dibaca dari assignment. 3 item Work Queue baru: **P2-F14-S** (UPDATE `auth_id` di fungsi "get"), **P2-F14-T** (by_auth_id tanpa owner bypass), **P3-F14-U** (field mati `divisi`/`posisi`) — semuanya untuk batch 266. Pelajaran: komparator byte-identik wajib pakai teks in-tag dollar-quote (perluasan P7/P13) + `String.replace` string replacement bisa menduplikasi file (wajib function replacer).
- 2026-09-30: user menetapkan peta level 1-5 + owner terpisah + multi-view.
- 2026-09-30: user menetapkan prinsip "investigasi wajib tracked, bukan chat".
- 2026-09-30: B0 selesai (inventaris konstanta + guard coverage).
- 2026-09-30: B0.5 selesai (SECURITY.md §3.10 fix + guard).
- 2026-09-30: B1 selesai — §1-§4 diisi.
- 2026-09-30: **Q1=A, Q2=A, Q3=A ditetapkan** (lihat §3b); 4 Work Queue baru P1-F14-D, P2-F14-E/F/G.
- 2026-09-30: **B2 selesai — §5-§6 diisi** (code read src/ read-only; src/ tidak diubah).
- 2026-09-30: **GPT menjawab Opsi A — semua admin NRP100–106 = level 3** (peta final §5c: NRP001=5 CEO, NRP100–106=3 Manager + admin_role + scope, NRP002–010=1 Worker). Prinsip RBAC 4-layer + gate audit rules ditulis §5d. Gap DB (user_roles belum punya admin_role/admin_scope/permissions; 4 opsi desain A/B/C/D) ditulis §5e — **menunggu keputusan user sebelum B3**.
- 2026-09-30: **B2.5 — user mengoreksi AI Core soal sistem bisnis** ("ADMIN ya hanya ADMIN saja dia masuk, khusus page admin"). Investigasi ulang BU/sites/karyawan + peta halaman + role_page_access 48 baris + admin_roles + owner flow → **§5b ditambahkan** (termasuk 4 hal "perlu klarifikasi user").
- 2026-09-30: **B2.8 — peta dependensi user_roles/user_role_assignments** (read-only): 32 RPC sebut user_roles, 5 RPC authz sebut user_role_assignments; RLS user_roles memanggil authz_* yang baca assignments; 0 FK/0 view; code hanya 3 file (password-reset ×2, ai-copilot ×1) + DetailPageFactory fallback.
- 2026-10-02: **§9 blocker K/H/I CLOSED** — migrasi `257` (P1-F14-K: trigger audit `user_role_assignments`) + `258` (P2-F14-H, H2: `authz_in_scope` TEAM `manager_nrp` → `atasan_nrp`) + `259` (P2-F14-I, I2 tahap murah: cabut `admin_produksi` dari CHECK + `is_admin_or_owner`) + **`260`** (I2 tahap 2: hapus 3 `role_permission_sets` `admin_produksi`) DITERAPKAN. Registry 185 baris / `max=260`. `admin_produksi` = **0 di kelima tempat**. Uji negatif `23514` membuktikan CHECK `user_roles_role_check` benar-benar aktif. Dua item Work Queue baru: **P2-F14-L** (`role_code` tanpa CHECK/FK) + **P2-F14-M** (guard bahasa/volatilitas fungsi). Pelajaran **P7** (pre-image timestamp dari server, bukan driver — driver `pg` truncate ke 3 digit padahal kolom precision 6) dan **P8** (`verify:artifacts` buta terhadap perubahan `LANGUAGE`/`provolatile` karena jumlah fungsi tidak berubah).
- 2026-10-03: **§9 blocker L2 + J3 CLOSED** — investigasi read-only memetakan state role sebelum desain, lalu migrasi `261` (master table `role_codes`, P2-F14-L) + `262` (assignment transisi NRP001, J3) DITERAPKAN; registry **187** baris / `max=262`. Keputusan desain user: seed **semua** role sah — 10 aktif dari 5 sumber + 3 reservasi (`owner`/`director`/`admin`) dengan `is_active=false`; `is_active` = metadata UI/docs, **bukan** gate runtime. Temuan utama investigasi: rantai `authz_check_admin → authz_has_permission` **sudah live** dan membaca `user_role_assignments` (bukan `user_roles`), sehingga NRP001 sejak awal kehilangan 50 permission — J3 memperbaiki kondisi yang sedang rusak. Uji negatif **23503** pada kedua FK. `P2-F14-L` → **PARTIAL** (sisa: guard test §12). Pelajaran **P9**: pengukuran di dalam transaksi sebelum `ROLLBACK` terlihat menyimpang untuk tabel berttrigger audit — ukur ulang setelah `ROLLBACK`.
- 2026-09-30: **B3 — rencana eksekusi Fix #14 §7–§12 (Opsi C') ditulis** (data model, backfill, rewiring 10 RPC + 3 edge, perbaikan RPC rusak, test plan; docs only; HEAD 6e3920b) — menunggu APPROVE user sebelum commit. Riwayat pindah ke §13 (nomor §12 dipakai draft Test + verifikasi).
