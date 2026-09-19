# MIGRATION_GUIDE.md — JALUR MIGRASI & INSTALASI PERUSAHAAN BARU

> **Pecahan dari `AGENTS.md` (2026-09-19).** Isi di bawah ini dipindahkan apa adanya —
> nomor bagian lama (`§5.7`, `§6.4`, `§7.4`, …) sengaja DIPERTAHANKAN agar rujukan lama tetap
> bisa ditelusuri. Peta bacanya ada di `AGENTS.md` (Reading Map). Jangan menaruh riwayat
> pekerjaan selesai di berkas ini — itu milik `agentsLogs.md`.

> Aturan kerasnya tinggal di `SECURITY.md` §3.14–§3.16. Di sini yang operasional: perintah,
> urutan, dan bukti. Jebakan CLI/DB yang menyertainya: `ENVIRONMENT_TRAPS.md` §6.4.
> Daftar kerja pascaaudit (termasuk butir registry/checksum): `TESTING_GUIDE.md` §5.7.

## 0. Jalur resmi — satu perintah, satu transaksi

Migrasi ke DB live **tidak boleh** lewat SQL Editor / pg8000 manual:

    npm run db:migrate -- <berkas>.sql --apply      # supabase/scripts/apply-migration.mjs

Wrapper itu menjalankan SQL **DAN** mendaftarkannya ke `schema_migrations` dalam **satu
transaksi** — kalau pendaftaran gagal, SQL-nya ikut ROLLBACK, jadi mustahil berakhir
"sudah jalan tapi tidak tercatat". Tanpa `--apply` = dry run. Ia menolak berkas yang nomor
versinya sudah dipakai berkas lain, dan mendeteksi berkas yang diubah setelah diterapkan
(checksum beda). Detail jebakannya: `ENVIRONMENT_TRAPS.md` §6.4.

Invariant yang mengikat (rujuk, jangan gandakan): `SECURITY.md` §3.14 (semua migrasi
tercatat), §3.15 (baseline vs rantai), §3.16 (identitas perusahaan tidak diwariskan).

## 1. Registry & checksum drift

Yang **bukan** masalah: `DUPLICATE` untuk versi yang memang dipakai beberapa berkas
(176/186/208/215) — migration 219 mengizinkannya dan migration 224 menyempitkan aturannya.
Yang **selalu** masalah: `UNAPPLIED` dan `VERSION_MISMATCH`.

Kasus nyata (migrasi 221/222/223 diterapkan lewat SQL Editor sehingga registry tertinggal,
dan 21 migrasi historis yang diperbaiki untuk jalur instalasi sehingga checksum registry tidak
lagi cocok) ada di `TESTING_GUIDE.md` §5.7 butir 11 beserta catatannya — satu sumber, JANGAN
disalin ke sini.

Aturan praktis: setiap migrasi yang mengubah schema **wajib** langsung diregenerasi ke baseline
(`npm run db:baseline`) dan dibuktikan (`npm run db:verify-install`), karena baseline yang
tertinggal akan memasang perilaku lama ke perusahaan baru.

## 2. Instalasi perusahaan baru (baseline, BUKAN rantai migrasi)

`supabase/migrations/` adalah **histori + gerbang regresi**, bukan jalur instalasi: ia membawa
data seed/demo dan tidak memuat objek yang hanya hidup di DB live. Jalur resmi:

    npm run install:baseline -- --target "<connection string project Supabase baru>" --company-name "PT X" --owner-email "owner@x.com" --apply

Runbook lengkap: `supabase/baseline/README.md`. Pengamannya kaku: `--target` wajib (skrip
TIDAK pernah memakai `DATABASE_URL` repo), target yang sama dengan DB live ditolak, project
yang sudah berisi tabel ditolak tanpa `--force`, default dry run.

Kelas bug yang sudah pernah terjadi dan **tidak boleh kembali** (semuanya kini dijaga generator
+ `verify-install-e2e.mjs`): merek perusahaan sumber ikut ter-dump; email owner diwariskan
sementara `owner_login()` mewajibkan email itu (owner baru tidak bisa login); versi registry
ditulis `parseInt` sehingga muncul 59 `VERSION_MISMATCH`; partisi absensi mewarisi hak `anon`;
trigger `INSTEAD OF` di view `employees_master` hilang sehingga view tulis jadi read-only
tanpa error.

## 3. Bukti yang wajib disertakan sebelum klaim DONE

`verify_migration_checksum` PASS untuk migrasi yang baru diterapkan, `check_migrations()` tanpa
`UNAPPLIED`/`VERSION_MISMATCH`, dan `npm run db:verify-install` PASS setiap kali baseline
diregenerasi. Status OPEN yang belum ditutup tinggal di `AGENTS.md` §5.8.