# Instalasi Perusahaan Baru (Baseline)

> **Jawaban singkat:** untuk perusahaan baru, **jangan** replay `supabase/migrations/`.
> Pakai **2 berkas di folder ini** lewat satu perintah. Rantai migrasi tetap dipertahankan,
> tetapi perannya adalah *histori + gerbang regresi*, bukan jalur instalasi.
>
> Diverifikasi 2026-09-18 terhadap DB live: `supabase/baseline/replay-baseline.md` dan
> `supabase/baseline/verify-install-e2e.md`.

## 1. Dua jalur, dan kapan memakai yang mana

| | **Baseline** (folder ini) | **Rantai migrasi** (`supabase/migrations/`) |
|---|---|---|
| Berkas | **2** (`000_baseline_schema.sql`, `010_baseline_config_data.sql`) | **157** berkas, ±1,6 MB |
| Untuk | perusahaan **baru**, project Supabase **kosong** | upgrade DB yang sudah jalan; gerbang regresi |
| Hasil | sama persis dengan DB live (12/12 metrik + ACL) | instalasi lebih tipis (mis. objek yang hanya ada di live tidak terbentuk) |
| Data | hanya konfigurasi/referensi (menu, role, permission) | termasuk data seed/demo |
| Waktu | ±4 detik | ±1,5 menit |
| Perintah | `npm run install:baseline -- --target ... --apply` | `node supabase/scripts/replay-fresh-install.mjs --mode=chain` (uji, bukan produksi) |

Rantai migrasi **sudah** diperbaiki sampai replay bersih 157/157, jadi ia bukan lagi rusak.
Tapi ia tetap bukan jalur terbaik untuk instalasi: ia membawa data demo, 77 nomor versi kosong,
dan tidak memuat objek yang selama ini hanya hidup di DB live. Baseline adalah potret apa adanya
dari DB live, termasuk 208 tabel, 549 fungsi, 223 policy, 27 trigger, 285 partisi, 4 cron job.

## 2. Prasyarat

- Project Supabase **baru** (kosong) di region pilihan Anda. Baseline membuat schema
  `extensions` sendiri, jadi tidak perlu disiapkan manual.
- Connection string project baru (Dashboard → Settings → Database → Connection string).
  Pooler (`...pooler.supabase.com:6543`) sudah cukup.
- Node.js + dependensi repo (`npm install`).
- Untuk langkah akun owner: akses Dashboard project baru.

## 3. Instalasi satu perintah

```bash
# 1. Lihat rencananya dulu (dry run — tidak menulis apa pun)
npm run install:baseline -- --target "<connection string dari Supabase -> Connect -> Connection pooling>"

# 2. Jalankan
npm run install:baseline -- \
  --target "<connection string dari Supabase -> Connect -> Connection pooling>" \
  --company-name "PT Contoh Tambang" \
  --owner-email "owner@contohtambang.com" \
  --apply
```

Flag:

| Flag | Fungsi |
|---|---|
| `--target` | **wajib** — connection string project tujuan |
| `--apply` | benar-benar menulis (tanpa ini hanya dry run) |
| `--company-name "PT ..."` | mengisi `branding.company_name` |
| `--owner-email "..."` | mengisi `company_config.owner_email` (**tanpa ini owner tidak bisa login**) |
| `--force` | mengizinkan jalan pada project yang sudah berisi tabel (baseline idempoten) |

**Pengaman yang sengaja dipasang:** skrip ini **tidak pernah** memakai `DATABASE_URL` repo;
`--target` wajib, dan nilainya ditolak bila sama dengan DB live. Tanpa `--force` ia menolak
project yang sudah berisi tabel. Jadi tidak ada jalan tidak sengaja menimpa DB produksi.

### Alternatif tanpa Node (SQL Editor)

Buka SQL Editor project baru, jalankan **berurutan** dan tunggu tiap berkas selesai:

1. `supabase/baseline/000_baseline_schema.sql` (±1,1 MB — tempel apa adanya, sekali jalan)
2. `supabase/baseline/010_baseline_config_data.sql` (±255 KB)

Lalu isi identitas secara manual (§4). Berkas data juga mencap `schema_migrations`, jadi
migrasi baru tetap bisa menyusul lewat `npm run db:migrate`.

## 4. Setelah instalasi — WAJIB, kalau tidak aplikasi tidak bisa dipakai

1. **`owner_email`** — jalankan installer dengan `--owner-email`, atau:
   ```sql
   update public.company_config
      set config_value = jsonb_set(config_value, '{value}', to_jsonb('owner@perusahaan.com'::text))
    where config_key = 'owner_email';
   ```
   Sejak migrasi 230 fungsi `get_owner_email()` **fail-closed**: tanpa baris ini tidak ada email
   yang diterima, dan `owner_login` menjawab *"owner_email belum dikonfigurasi"*. Sebelum 230,
   fungsi ini justru default ke domain insightWOS — artinya owner perusahaan baru diminta
   memakai email kita.
2. **Akun owner pertama** — lihat `first-owner.example.sql` di folder ini,
   atau manual: Dashboard → Authentication → Users → *Add user* dengan **email yang sama
   dengan `owner_email`**, salin UUID-nya, lalu:
   ```sql
   insert into public.system_owner_identity (auth_id, owner_email)
   values ('<uuid-dari-dashboard>', 'owner@perusahaan.com');
   ```
   Inilah yang membuat `check_owner_identity()` (dipakai `OwnerGuard` di `/owner/dashboard`)
   dan `authz_check_admin()` mengenali akun tersebut sebagai owner.
3. **Branding** — ganti nama/logo di OwnerDashboard → tab 🎨 Branding. Baseline sengaja
   hanya menaruh nama netral (`Perusahaan Anda`) dan mengosongkan logo/warna.
4. **Business unit & modul** — isi `business_units` dan pemetaan modul sesuai struktur
   perusahaan; menu (`module_definitions`, 155 baris) sudah terisi, jadi route langsung hidup.
5. **Akun karyawan** — pakai `supabase/scripts/provision-worker-auth.mjs`
   (`--dry` dulu) setelah data karyawan ada di `employees_core`.
6. **Frontend** — arahkan env `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY` ke project baru,
   lalu deploy (`npx vercel --prod`).

## 5. Verifikasi

```sql
select count(*) from information_schema.tables where table_schema='public';   -- 209 (208 + 1 view)
select count(*) from public.module_definitions;                               -- 155
select public.get_owner_email();                                              -- email owner Anda
select * from public.check_migrations();                                      -- 0 baris
select count(*) from public.ensure_attendance_partitions(null, 24);           -- partisi sampai +24 bulan
```

Atau jalankan uji end-to-end otomatis (membuat database scratch sekali pakai, lalu menghapusnya):

```bash
npm run db:verify-install
```

## 6. Yang **tidak** ada di baseline (dan memang tidak boleh ada)

Data karyawan & PII (`employees_core`, `employees_extended`, `user_roles`, `worker_passwords`),
transaksi (absensi, payroll, lembur, `audit_log`, `hr_okrs`), dan identitas perusahaan
(`system_owner_identity`, `company_config.owner_email` / `ceo_email`, `branding`).

Konsekuensinya: perusahaan baru **mulai dari data kosong** dan wajib melewati §4.
Ini disengaja — far better daripada perusahaan baru sudah berisi karyawan dan transaksi
milik perusahaan lain.

## 7. Perawatan baseline

```bash
npm run db:baseline        # regenerate dari DB live (schema + data konfigurasi)
npm run db:verify-install  # buktikan hasilnya bisa dipasang ke project kosong
npm run db:replay -- --mode=baseline --twice   # replay + uji idempoten
```

Setiap kali ada migrasi baru **yang mengubah schema**, jalankan `npm run db:baseline` lalu
`npm run db:verify-install`. Tanpa regenerasi, baseline akan tertinggal dari live — persis
kejadian 2026-09-18 ketika `get_owner_email()` hasil perbaikan migrasi 230 belum ikut
ter-dump, dan instalasi baru masih membawa perilaku lama.

Migrasi **baru** setelah versi tertinggi tetap diterapkan normal:
`npm run db:migrate -- <berkas>.sql --apply`.
