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
--- APPLY 000_baseline_schema.sql ... ok (3640ms)
--- APPLY 010_baseline_config_data.sql ... ok (642ms)
--- IDENTITAS PERUSAHAAN ---
  branding.company_name → "PT Uji Instalasi Otomatis" (1 baris)
  company_config.owner_email → owner@uji-instalasi.test (baris baru dibuat, 1)
--- VERIFIKASI ---
  tabel non-partisi         : 208
  fungsi project            : 552
  policy RLS                : 225
  trigger                   : 29
  partisi absensi           : 0
  menu (module_definitions) : 155
  cap schema_migrations     : 166
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
  SAMA  tabel_non_partisi  live=  208  install=  208
  SAMA  partisi            live=    0  install=    0
  SAMA  view               live=    1  install=    1
  SAMA  fungsi_project     live=  552  install=  552
  SAMA  policy             live=  225  install=  225
  SAMA  trigger            live=   29  install=   29
  SAMA  sequence           live=   95  install=   95
  SAMA  cron_job           live=    3  install=    3
  SAMA  migration_cap      live=  166  install=  166

--- 4) identitas perusahaan hasil instalasi ---
  branding.company_name   : "PT Uji Instalasi Otomatis"  (dari --company-name)
  company_config.owner_email : "owner@uji-instalasi.test"  (dari --owner-email)
  get_owner_email()        : "owner@uji-instalasi.test"  (harus sama dengan owner_email)
  ceo_email (tidak diwariskan) : 0 baris
  module_definitions       : 155
  merek DB sumber (tidak boleh muncul) : "insightWIP"

--- 5) jalankan ulang dengan --force (uji idempoten) → exit 0
    --- APPLY 000_baseline_schema.sql ... ok (2541ms)
    --- APPLY 010_baseline_config_data.sql ... ok (411ms)
  tabel non-partisi : sebelum=208 sesudah=208 (harus sama)
  cap migrasi       : sebelum=166 sesudah=166 (harus sama)

database scratch wos_replay_install_e2e di-drop (pakai --keep untuk menyimpannya)

=== HASIL: PASS — installer siap dipakai ===
```
