```
=== uji end-to-end installer baseline: db=wos_replay_install_e2e ===
database scratch dibuat (kosong, seperti project Supabase baru)
prereq platform disiapkan (schema auth/extensions, auth.*(), stub cron, default privilege)

--- 1) dry run (project kosong) → exit 0
    tabel di public: 0

--- 2) --apply → exit 0
--- PREFLIGHT ---
  role   : postgres
  postgres: 17.6
  tabel di public: 0
--- APPLY 000_baseline_schema.sql ... ok (4464ms)
--- APPLY 010_baseline_config_data.sql ... ok (789ms)
--- IDENTITAS PERUSAHAAN ---
  branding.company_name → "PT Uji Instalasi Otomatis" (1 baris)
  company_config.owner_email → owner@uji-instalasi.test (baris baru dibuat, 1)
--- VERIFIKASI ---
  tabel non-partisi         : 209
  fungsi project            : 553
  policy RLS                : 224
  trigger                   : 27
  partisi absensi           : 285
  menu (module_definitions) : 155
  cap schema_migrations     : 160
  branding (nama perusahaan): PT Uji Instalasi Otomatis
  owner_email               : owner@uji-instalasi.test
  check_migrations()        : bersih (0 issue)
--- SELESAI ---
  1. Buat akun OWNER pertama  → supabase/baseline/README.md §5
     (owner_email sudah diisi, tetapi system_owner_identity BELUM dibuat)
  2. Set nama/logo perusahaan → OwnerDashboard → tab 🎨 Branding
  3. Isi business_units + pemetaan modul sesuai perusahaan
  4. Arahkan frontend (env VITE_SUPABASE_*) ke project ini, lalu deploy

--- 3) metrik: live vs hasil instalasi lewat installer ---
  SAMA  tabel_non_partisi  live=  209  install=  209
  SAMA  partisi            live=  285  install=  285
  SAMA  view               live=    1  install=    1
  SAMA  fungsi_project     live=  553  install=  553
  SAMA  policy             live=  224  install=  224
  SAMA  trigger            live=   27  install=   27
  SAMA  sequence           live=   96  install=   96
  SAMA  cron_job           live=    4  install=    4
  SAMA  migration_cap      live=  160  install=  160

--- 4) identitas perusahaan hasil instalasi ---
  branding.company_name   : "PT Uji Instalasi Otomatis"  (dari --company-name)
  company_config.owner_email : "owner@uji-instalasi.test"  (dari --owner-email)
  get_owner_email()        : "owner@uji-instalasi.test"  (harus sama dengan owner_email)
  ceo_email (tidak diwariskan) : 0 baris
  module_definitions       : 155
  merek DB sumber (tidak boleh muncul) : "insightWIP"

--- 5) jalankan ulang dengan --force (uji idempoten) → exit 0
    --- APPLY 000_baseline_schema.sql ... ok (2997ms)
    --- APPLY 010_baseline_config_data.sql ... ok (406ms)
  tabel non-partisi : sebelum=209 sesudah=209 (harus sama)
  cap migrasi       : sebelum=160 sesudah=160 (harus sama)

database scratch wos_replay_install_e2e di-drop (pakai --keep untuk menyimpannya)

=== HASIL: PASS — installer siap dipakai ===
```
