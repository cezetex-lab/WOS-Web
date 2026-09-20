```
=== latihan instalasi perusahaan baru: db=wos_replay_newco ===
=== latihan instalasi perusahaan baru: db=wos_replay_newco ===
database scratch dibuat (kosong, seperti project Supabase baru)
prereq platform disiapkan (auth/extensions, stub cron, default privilege)

--- 1) install-baseline --apply → exit 0
--- PREFLIGHT ---
  role   : postgres
  postgres: 17.6
  tabel di public: 0
--- APPLY 000_baseline_schema.sql ... ok (4032ms)
--- APPLY 010_baseline_config_data.sql ... ok (780ms)
--- IDENTITAS PERUSAHAAN ---
  branding.company_name → "PT Uji Perusahaan Baru" (1 baris)
  company_config.owner_email → owner@perusahaan-baru.test (baris baru dibuat, 1)
--- VERIFIKASI ---
  tabel non-partisi         : 209
  fungsi project            : 553
  policy RLS                : 224
  trigger                   : 27
  partisi absensi           : 285
  menu (module_definitions) : 155
  cap schema_migrations     : 164
  branding (nama perusahaan): PT Uji Perusahaan Baru
  owner_email               : owner@perusahaan-baru.test
  check_migrations()        : bersih (0 issue)
--- SELESAI ---
  1. Buat akun OWNER pertama  → supabase/baseline/README.md §5
     (owner_email sudah diisi, tetapi system_owner_identity BELUM dibuat)
  2. Set nama/logo perusahaan → OwnerDashboard → tab 🎨 Branding
  3. Isi business_units + pemetaan modul sesuai perusahaan
  4. Arahkan frontend (env VITE_SUPABASE_*) ke project ini, lalu deploy
  OK   baseline terpasang — exit 0
  OK   skema + menu hidup — 209 tabel, 155 menu

--- 2) owner pertama (langkah DB dari first-owner.example.sql)
  OK   company_config.owner_email terisi — owner@perusahaan-baru.test
  OK   get_owner_email() = email owner

--- 3) sesi owner (SET LOCAL role + klaim JWT yang dibaca stub auth.*)
  OK   auth.uid() = auth_id owner
  OK   check_owner_identity() = true (OwnerGuard lolos)
  OK   owner_login() = ok — {"ok":true,"nrp":"OWNER001","nama":"System Owner","role":"owner","is_owner":true,"role_level":5}

  RPC dashboard (perusahaan baru: datanya boleh kosong, yang penting tidak error)
    OK    get_owner_overview_stats → 9 field
    OK    get_modules_for_owner → 61 baris
    OK    get_business_units_for_owner → 4 baris
    OK    get_dashboard_stats → 7 field

--- 4) isolasi anon pada instalasi baru
  OK   anon ditolak saat memanggil RPC owner — ditolak: permission denied for function check_owner_identity

=== HASIL: PASS — perusahaan baru siap dipakai ===

Catatan penting:
  * owner_auth_id di atas dibuat di tabel stub auth.users database scratch.
    Di project Supabase nyata, user Auth dibuat lewat --create-owner
    (butuh SUPABASE_URL + service key) atau Dashboard → Authentication. <dibuat di Auth project nyata lewat --create-owner>
  * Latihan ini TIDAK menyentuh database live, dan DB scratch di-drop di akhir
    kecuali dijalankan dengan --keep.
```
