# DISASTER_RECOVERY.md — BACKUP, RPO/RTO, MONITORING

> **Pecahan dari `AGENTS.md` (2026-09-19).** Isi di bawah ini dipindahkan apa adanya —
> nomor bagian lama (`§5.7`, `§6.4`, `§7.4`, …) sengaja DIPERTAHANKAN agar rujukan lama tetap
> bisa ditelusuri. Peta bacanya ada di `AGENTS.md` (Reading Map). Jangan menaruh riwayat
> pekerjaan selesai di berkas ini — itu milik `agentsLogs.md`.


## 9. DISASTER RECOVERY

> **REVISI 2026-09-27 (P1-45-01 ditutup).** Seluruh versi sebelumnya dokumen ini
> berisi klaim yang **terbukti salah** dan sengaja dihapus, bukan diperbarui.
> Lihat §9.6 "Yang Dihapus dan Kenapa" — jangan dipulihkan tanpa bukti.

### 9.1 Kondisi sebenarnya (2026-09-27)

| Aspek | Nilai nyata | Bukti |
|---|---|---|
| **Hot standby** | ❌ **TIDAK ADA** | step `Sync to Neon` dihapus, commit `727b835` |
| Backup harian | ✅ GitHub Actions artifact, cron 02:00 UTC | `.github/workflows/supabase-backup.yml` |
| Retensi | 30 hari | `retention-days: 30` |
| Verifikasi artifact | ✅ tiap push/PR | `.github/workflows/ci.yml` job `backup-artifact`, commit `347ba01` |
| Restore test | ✅ mingguan (Kamis 03:00 UTC) | `.github/workflows/restore-test.yml` |
| **RPO** | **24 jam** | backup harian |
| **RTO** | **1–2 jam**, seluruhnya **manual** | lihat §9.4 |

### 9.2 Kenapa tidak ada hot standby

Dulu ada langkah "sync ke Neon" setiap hari. Itu **dihapus pada 2026-09-27**
setelah 5 run berturut-turut gagal (run #28–#32). Akarnya bukan bug per
langkah, melainkan **premis yang salah**:

| Aspek | Supabase | Neon free | Akibat |
|---|---|---|---|
| schema `public` | milik aplikasi | milik platform, permanen | `DROP`/`CREATE` bertabrakan terus |
| `pg_cron` | ada | **tidak ada** | 7 job mati, termasuk 3 refresh MV → **KPI diam-diam basi** |
| `pg_stat_statements` | ada | **tidak ada** | monitoring hilang |
| extension | pre-installed | harus provision manual | mismatch tiap restore |
| default privileges | berbeda | berbeda | error lanjutan |

Neon free **tidak akan pernah setara Supabase**. Memaksakan Neon jadi DR site
hanya menghasilkan DR site **cacat** — dan yang paling berbahaya, KPI-nya
tampak benar padahal angkanya lama. Dokumentasi resminya juga menegaskan:
Neon free tier tidak menyediakan `pg_cron` maupun `pg_stat_statements`.

### 9.3 Yang benar-benar melindungi (dan sudah otomatis)

1. **Backup artifact** — dump `--schema=public` harian → artifact GitHub, 30 hari.
2. **Verifikasi artifact tiap backup harian** — di workflow `supabase-backup.yml` (step
   `Verify artifact`, setelah upload). Cek file ada, ukuran masuk ambang, gzip utuh, isi
   bermakna. Menangkap backup rusak **di run yang sama**, bukan 24 jam kemudian.
   Dulu dijalankan sebagai job terpisah di `ci.yml` — dihapus 2026-09-27 karena artifact
   antar-workflow-run tidak bisa dibaca tanpa API token, jadi job itu membuat dump sendiri
   (duplikasi) dan memakai `pg_dump` 16 sehingga gagal *server version mismatch*.
   Jalankan manual: `node scripts/verify-backup-artifact.mjs backups/<file>.sql.gz`
3. **Restore test mingguan** — `npm run db:replay` membuat DB sekali pakai di
   cluster yang sama, mereplay baseline, lalu **membandingkan metrik + ACL
   dengan DB live**. Ini yang menutup P1-14-02: backup tanpa bukti restore
   hanyalah asumsi.

Yang **tidak** dilindungi: zero-downtime, multi-region, atau hot standby.
Kalau proyek butuh itu, itu keputusan berbayar dan di luar cakupan repo ini.

### 9.4 Jalur pemulihan (semuanya manual)

**PITR (data corruption / mass delete)** — Supabase Pro, point-in-time:

**Restore penuh** (project rusak total, ~1–2 jam, manual):

1. Buat project Supabase **baru** di region yang sama.
2. Ambil connection string, lalu pasang baseline:
   `npm run install:baseline -- --target "<conn>" --apply`
3. Restore data dari artifact terbaru:
   `gunzip backup_<timestamp>.sql.gz && psql "<conn>" -v ON_ERROR_STOP=1 -f backup_<timestamp>.sql`
4. Verifikasi jumlah baris `employees_core`, `user_roles`, `module_definitions`
   terhadap catatan sebelum insiden.
5. Uji login worker + admin pada DB baru (RPC auth, bukan hanya tabel).
6. Cutover: arahkan env aplikasi, redeploy Vercel.

Langkah 2 memakai **baseline** (bukan `supabase/migrations/`) karena baseline
adalah potret DB live: 209 tabel, 657 fungsi, 225 policy, 27 trigger, 5 cron job. Diverifikasi 2026-10-10.
Rantai migrasi adalah histori + gerbang regresi,
bukan jalur instalasi � lihat supabase/baseline/README.md.

### 9.5 Pemantauan

Belum ada pemantauan otomatis khusus backup. Yang ada hanyalah **red/green
di GitHub Actions** (backup harian + verifikasi artifact + restore test
mingguan). Pemantauan proaktif (alert saat backup gagal) **belum ada** —
status `OPEN`, lihat `OPEN_WORK.md`.

### 9.6 Yang DIHAPUS dari versi lama (dan kenapa)

| Klaim lama | Kenapa dihapus |
|---|---|
| "Supabase automated daily (30d retention Pro)" | Backup yang berjalan adalah **artifact GitHub Actions**, bukan PITR Supabase. Keduanya berbeda; hanya yang pertama yang terverifikasi. |
| "pg_dump weekly core tables (90d)" | **Tidak pernah ada** job mingguan seperti itu. 90 hari retensi juga tidak dikonfigurasi di mana pun. |
| "Monitoring: backup status daily, RLS weekly, failed login spikes daily" | Tidak ada satu pun monitoring otomatis yang berjalan. Hanya red/green CI. |
| "backup restore monthly" | **Tidak pernah terjadi.** Yang ada: 5 run gagal berturut (#28–#32) pada 2026-09-27. |
| "DR drill quarterly" | `git log --all --grep="drill\|disaster"` → **0 entri**. Tidak pernah ada drill. |
| "RTO 4h" | Angka tanpa dasar. Jalur manual realistis 1–2 jam; disorot agar tidak terlalu optimis. |
| "security audit bi-annually" | Tidak ada bukti klaim ini. Dicatat sebagai `OPEN`, bukan diakui benar. |

**Prinsip**: dokumen DR yang salah lebih berbahaya daripada tidak ada, karena
saat insiden nyata tim akan mengikutinya (§0.16 anti-hallucination). Setiap
angka di atas harus bisa ditelusuri ke workflow atau log — kalau tidak, angka
itu dihapus, bukan ditebak.

Eskalasi: P1 1 jam / P2 4 jam / P3 24 jam / P4 1 minggu.
