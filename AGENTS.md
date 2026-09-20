# AGENTS.md — ATURAN KERJA AGENT (WAJIB) — ONE SINGLE TRUTH

> **Restrukturisasi 2026-09-19 (P0): berkas ini DIPECAH.** Sejak sekarang ia hanya memuat
> (a) alur kerja wajib §0 + sandbox rule §0.11, (b) Golden Rules §0.5, dan (c) Work Queue §5.8
> — plus peta bacaan di bawah. Semua isi lain pindah ke berkas terpisah supaya agent tidak memuat 57 KB hanya
> untuk membaca satu aturan, dan supaya aturan tidak lagi bercampur dengan status proyek.
>
> **Reading Map — BACA berkas yang relevan SEBELUM mulai kerja:**
>
> | Kalau tugasnya menyentuh… | Baca dulu |
> |---|---|
> | arsitektur, halaman/route, auth 3-layer, kontrak sesi client, status DB/frontend, konteks proyek, peta file penting | `ARCHITECTURE.md` |
> | aturan teknis keras §3 (authz dari JWT, bcrypt, `SECURITY DEFINER`, TypeScript-only, angka dokumen tidak boleh dikarang) + security posture §7.6 | `SECURITY.md` |
> | menjalankan migrasi, registry/checksum drift, instalasi perusahaan baru (baseline), identitas perusahaan | `MIGRATION_GUIDE.md` |
> | gate (tsc/lint/build/test), E2E, daftar kerja pascaaudit §5.7, jebakan vitest | `TESTING_GUIDE.md` |
> | Windows/PowerShell/SQL Editor, `npx`, timeout proses, jebakan DB | `ENVIRONMENT_TRAPS.md` |
> | state OPEN non-SQL: Upstash/region SG, audit `Readme/upppp.txt` (F1–F4), installer baseline | `OPEN_WORK.md` |
> | roadmap fitur (Workday/SAP/ADP) | `ROADMAP.md` |
> | backup, RPO/RTO, DR drill, eskalasi insiden | `DISASTER_RECOVERY.md` |
> | riwayat pekerjaan yang SUDAH selesai | `agentsLogs_YYYY-MM.md` (indeks bulan: `agentsLogs.md`) — JANGAN taruh history di sini |
>
> Nomor bagian lama tidak diubah di berkas barunya (`§3.11`, `§5.7`, `§6.4`, `§7.4`, `§9`, …),
> jadi rujukan lama tetap bisa ditelusuri lewat tabel di atas.

## 0. ALUR KERJA WAJIB (PROSES)

1. **PAHAMI dulu, baru bertindak.** Verifikasi setiap temuan langsung ke DB live
   (`DATABASE_URL` di `.env.local`) atau kode live sebelum dikerjakan. Laporan audit lama
   terbukti banyak false positive.
2. **Ikuti analisa/arahan user** — jangan bikin rencana sendiri yang mengubah urutan tahap,
   jangan kerjakan item di luar daftar tanpa persetujuan.
3. **Setiap perubahan wajib: COMMIT → PUSH → DEPLOY** (deploy = `npx vercel --prod` untuk
   perubahan frontend, apply migration ke DB live untuk perubahan DB, redeploy edge function
   untuk perubahan edge).
4. **Setelah sukses: tulis hasilnya ke berkas log BULAN BERJALAN (`agentsLogs_YYYY-MM.md`)** —
   `agentsLogs.md` kini hanya **indeks** (`scripts/split-agents-logs.ts`); format entri ada di
   header berkas bulan itu. Lalu **KELUARKAN dari AGENTS.md** — item selesai TIDAK tinggal di file ini.
5. Yang tinggal di AGENTS.md hanya: aturan kerja, aturan teknis keras, dan state OPEN
   (rencana/bug yang belum selesai).
6. **DILARANG commit artefak/rahasia**: audit scripts, test-results, CSV/plaintext password,
   `.env*`, arsip `Readme/` + `files/`. Cek `git status` sebelum `git add` — pakai `git add`
   spesifik, hindari `git add -A` buta. Secret scan pre-commit wajib
   (`postgresql://|SERVICE_ROLE|<password-lama>`).
7. **Rahasia**: kredensial akun ada di `supabase/akun/akun.txt` (gitignored, plaintext —
   bagikan per-orang lalu hapus). Tidak pernah commit kredensial apa pun.
8. **Klaim "DONE" wajib terverifikasi dulu.** Status DONE baru sah bila: perubahan sudah
   **ter-commit** (+push/deploy untuk frontend), dan gate (`tsc`/lint/build/test) **dijalankan
   ulang pada tree saat itu** dan hijau. Perubahan yang masih ada di working tree = **PARTIAL/OPEN**,
   bukan DONE. Pelajaran 2026-09-16: kerja paralel beberapa helper meninggalkan ±22 file
   uncommitted + **7 error `tsc`** (`requireNrp` dipanggil tanpa import; `React` UMD di `main.tsx`)
   padahal dokumen sudah menandainya "DONE, 0 error".
9. **Temuan audit WAJIB jadi tugas, bukan catatan.** Setiap temuan dari audit/inspeksi apa pun
   harus masuk **WORK QUEUE** (§5.8 untuk temuan SQL) sebagai item bernomor dengan
   **Prioriitas + Bukti + Definition of Done**; item hanya boleh ✅ bila DoD-nya **dibuktikan
   dengan perintah/query + hasil**. Dilarang menutup temuan sebagai prosa, ringkasan, atau
   "sudah dicatat". Kalau sebuah temuan ternyata **bukan masalah**, pindahkan ke tabel
   *"Sudah diverifikasi BUKAN masalah"* beserta alasannya — supaya tidak diinvestigasi ulang,
   dan jangan tinggalkan sebagai item OPEN palsu.
10. **Butuh keputusan user? Tulis sebagai item + tanyakan, jangan diam.** Item yang menunggu
   keputusan (mis. risiko `FORCE ROW LEVEL SECURITY` terhadap SQL Editor) tetap tinggal di
   WORK QUEUE dengan penanda **"butuh keputusan user"** beserta opsi + risikonya, agar tidak
   hilang dari pandangan.

## 0.11 SANDBOX RULE — DILARANG membuat berkas di root

> **Aturan keras.** Semua AI agent **DILARANG** membuat berkas baru di direktori root
> (`WOS-Web/`). Root hanya untuk berkas proyek yang memang bagian aplikasi: `package.json`,
> `index.html`, `*.config.ts`, `vercel.json`, dan dokumen `*.md` yang dirujuk Reading Map di atas.

Ke mana berkas baru HARUS pergi:

| Jenis berkas | Tempat |
|---|---|
| skrip sementara, probe DB, debug, audit sekali-pakai | `.agents/scripts/` |
| log gate/build/test, keluaran perintah, screenshot diagnosa | `.agents/logs/` |
| laporan audit/forensik | `.agents/reports/` |
| arsip dokumen / salinan cadangan | `.agents/docs/` |
| tooling proyek yang memang ikut di-commit | `supabase/scripts/` atau `scripts/` |

**Berkas lama tidak dihapus — DIARSIPKAN** ke `.agents/archive/<kategori>/` supaya masih bisa
ditelusuri. Menghapus berkas tanpa keputusan user dilarang (§0.2). Untuk isi setiap kategori
arsip: `.agents/archive/scripts/`, `.agents/archive/logs/`, `.agents/archive/reports/`,
`.agents/archive/docs/`.

**Dilarang menulis berkas lewat shell** (`echo >`, `cat <<EOF`, `printf >`, `Add-Content`).
Pakai `node scripts/safe-file-writer.ts --file <path> --content-file <sumber> --mode <append|overwrite>`.
Alasannya nyata: append lewat redirection pernah merusak `agentsLogs.md` (864 NULL byte, UTF-16
menempel di berkas UTF-8) — pemulihnya `scripts/repair-text-encoding.ts`.

**Jebakan penting:** `.agents/` ada di `.gitignore`, jadi apa pun yang ditaruh di sana **tidak
ikut ter-commit**. Dilarang memindahkan berkas yang **ber-git-track** (`FuturePlans.md`,
`AGENTS.md`, `agentsLogs.md`, berkas di `src/`, `tests/`, `supabase/`) ke `.agents/` — itu sama
dengan menghapusnya dari version control. Berkas ber-track tetap di root atau di `docs/`.

## 0.5 GOLDEN RULES (WAJIB) — KETERKAITAN 4 PAGE: worker ⇄ admin ⇄ dashboard ⇄ owner

> **PRINSIP DASAR:** insightWOS = **SATU sistem terintegrasi**, bukan 4 aplikasi terpisah.
> Halaman **Worker**, **Admin**, **Dashboard**, dan **OwnerDashboard** memakai **DB, RPC, authz,
> session, menu/route, design system, dan types yang SAMA**. Karena itu **satu perubahan di
> halaman Worker HAMPIR SELALU berdampak ke Admin, Dashboard, dan Owner** (dan sebaliknya).
> Bekerjalah SELALU dengan asumsi keterkaitan erat ini.

**Rantai dampak data (hafalkan):**
```
Worker (input: absensi, izin, lembur, produksi, dokumen)
  → Admin (approval queue, koreksi, payroll run, master karyawan)
     → Dashboard (KPI agregat, monitoring, laporan)
        → Owner (analitik lintas-BU, branding, konfigurasi global, audit)
```

1. **G1 — Default asumsi: TERDAMPAK.** Setiap koding di salah satu page, anggap 4 page lain
   terdampak sampai dibuktikan sebaliknya. Dilarang menyimpulkan "ini hanya perubahan page
   worker" tanpa mengecek Admin/Dashboard/Owner.
2. **G2 — Perbaiki di lapisan bersama, bukan hack per-page.** Solusi harus di layer bersama
   (RPC/DB, `src/lib/*`, `src/types/index.ts`, `route-config.ts`, `menu-builder.ts`,
   `design-system/*`, authz). Jangan patch lokal per-page (mis. rename/override RPC hanya di
   Worker). Perbedaan kebutuhan antar-page = parameter/role, bukan duplikasi logika.
3. **G3 — Kontrak bersama = breaking change.** Perubahan pada nama/param/return RPC,
   `module_code`/`route_path`/`route_component`, bentuk `session`/`entry`, kolom tabel
   (`employees_core` dkk), prop design-system, atau interface di `src/types` → WAJIB grep semua
   pemakai di `src/` lalu verifikasi ke-4 page.
4. **G4 — Data worker = input rantai hilir.** Mengubah bentuk/validasi data tulisan worker
   (absensi, izin, lembur, item payroll) mengubah konsumennya (approval Admin → KPI Dashboard →
   analitik Owner). Cek pembaca hilir (VIEW/MV/report/RPC) SEBELUM mengubah penulis.
5. **G5 — Isolasi role JANGAN dilemahkan.** Perbaikan lintas-page tidak boleh melonggarkan
   `RoleGuard` + cek `session.entry` + authz DB (3 layer, `ARCHITECTURE.md` §7.2). Membuka akses hanya jika
   user memutuskan.
6. **G6 — Gate verifikasi lintas-page.** Bukti minimal sebelum commit untuk perubahan
   fungsional: (a) `npm run check:types` 0 error, (b) unit test hijau, (c) `npm run build`
   EXIT 0, (d) smoke putar 4 page (worker → admin → dashboard → owner), (e) E2E
   `full-sweep`/`tab-click-test`/`role-change` bila menyentuh route/menu/role.
7. **G7 — Catat dampak di log.** Entri `agentsLogs.md` wajib memuat baris
   `Dampak lintas-page: worker → admin → dashboard → owner` berisi hasil pengecekan tiap page
   (termasuk "tidak terdampak" + alasannya).

## 5.8 STATE OPEN — WORK QUEUE: Temuan Audit SQL (WAJIB DISELESAIKAN)

> **Sumber:** audit menyeluruh 2026-09-17 — 150+ migrasi diparsing lalu **setiap temuan
> diverifikasi ke DB live** (read-only; satu probe tulis di dalam transaksi yang di-`ROLLBACK`).
> Laporan + data mentah: `agentsLogs.md` entri `[2026-09-17] Audit kesiapan instalasi`.
>
> **ATURAN WORK QUEUE (jangan dilanggar):**
> 1. Setiap temuan audit **WAJIB** jadi item bernomor di tabel ini dengan **Bukti** dan
>    **Definition of Done**. **Dilarang** menutup temuan sebagai komentar/prosa saja.
> 2. Item hanya boleh ditandai ✅ bila **DoD-nya terbukti** (perintah/query + hasil), bukan
>    karena "sudah dikerjakan".
> 3. Item ✅ hanya boleh **dihapus dari file ini setelah** hasilnya tertulis di `agentsLogs.md` (§0.4).
> 4. Dilarang menambah item "catatan" tanpa aksi; kalau tidak ada aksi, bukan item.
> 5. Item P0 wajib dikerjakan sebelum migrasi/fitur besar berikutnya.
>
> **Status di bawah diverifikasi ulang 2026-09-17** (bukan salinan catatan lama).

| ID | Prio | Masalah | Bukti (terverifikasi) | Definition of Done | Status |
|---|---|---|---|---|---|
| SQL-02 | **P2** (turun dari P1) | **25 tabel + 14 fungsi live tanpa sumber migrasi** — sekarang **tercakup**: ke-25 tabel ada di baseline (di-generate dari katalog live, bukan dari rantai), jadi instalasi perusahaan baru tidak kehilangan apa pun | Tabel: `ai_rate_limits`, `api_keys`, `api_rate_limits`, `dashboard_cache`, `user_consents`, `hr_shift_swaps`, `hr_audit_chain`, `hr_okr_results`, `hr_survey_responses`, `hr_task_board`, `safety_incidents`, `webhook_logs`, 5×`mining_*`, 5×`estate_*`, 3×`mill_*` — dipulihkan `008_restore_missing_objects.sql`. Fungsi: 13×`_legacy_*` + `worker_update_profile_legacy` — tidak dibuat rerantai, dan itu aman sekarang karena `172`/`210`/`221`/`226` memakai guard (`to_regprocedure`) sehingga ketidakhadirannya tidak menggagalkan apa pun. Terbukti: replay 156/156 dengan 14 fungsi itu tetap absen | **TERBUKTI 2026-09-18:** baseline memuat seluruh objek live — `verify-install-e2e.mjs` memasang ke project kosong dan mencocokkan **9/9 metrik** dengan live (208 tabel, 549 fungsi, 223 policy, 27 trigger, 285 partisi, 95 sequence, 4 cron job, cap 157). Sisa satu keputusan kecil: 14 `_legacy_*` di DB live dibuat ulang atau dihapus | OPEN (dampak instalasi sudah nol) |
| SQL-06 | **P1** | **9 tabel RLS enabled tapi TIDAK forced** | `employees_core`, `employees_extended`, `fatigue_data`, `heavy_equipment`, `jsa_data`, `production_daily`, `safety_incidents`, `schema_migrations`, `simper_data` | Keputusan user (FORCE membuat **pemilik** tunduk policy → berisiko ke SQL Editor/dashboard); bila disetujui → `FORCE ROW LEVEL SECURITY` + verifikasi 0 tersisa | OPEN — **butuh keputusan user** |
| SQL-08 | **P2** | **`hr_attendance_partitioned` = struktur mati** (0 baris) dan `RENAME` masih dikomentari | Kedua tabel absensi **0 baris**; `141:1403` masih `-- ALTER TABLE hr_attendance_partitioned RENAME TO hr_attendance`; hanya fungsi 225/227 yang menyentuh namanya | Keputusan adopsi (jalankan RENAME + pindahkan penulis data) **atau** dibuang (drop partisi + index + cron 225); tidak ada dua tabel absensi paralel | OPEN — **butuh keputusan user** |
| SQL-09 | ✅ | **Duplikat `CREATE` dalam satu berkas** — ternyata **dead code**, bukan konflik | Terverifikasi 2026-09-20: blok di 141 (baris 545-556 & 558-567) **byte-identik** (`diff` kosong) dengan pengulangan di 1911-1922 & 1924-1933; berkas 183 hanya punya **1** `CREATE VIEW employees_master` (baris 181) — klaim audit "view 2x" **SALAH**, kemunculan lain adalah `DROP` di dalam DO-block yang memang wajib. Live: **1** `hr_okrs` (TABLE, 10 kolom, 9 baris data), **1** `hr_surveys`, **1** `employees_master` (VIEW) — **0 objek kembar**. DROP ke DB live ditolak karena tidak ada yang kembar dan justru menghapus data | Duplikat dihapus **di sumber** (141) + `239` v2 jadi **assertion non-destruktif** (gagal-cepat bila kelak muncul objek kembar) | ✅ SELESAI (2026-09-20: 24 baris duplikat dibuang diganti catatan; replay rantai **164/164, 0 GAGAL**; installer E2E **PASS 9/9 SAMA**; assertion 239 **PASS** di live; checksum 141 & 239 di-restamp; cap baseline disegarkan 160→**164**) |
| SQL-10 | **P3** | **Checksum migrasi bergantung EOL checkout** — `.gitattributes` memakai `* text=auto eol=crlf` (blob repo LF, working tree CRLF), sedangkan generator baseline & `apply-migration.mjs` meng-hash **byte berkas kerja** | Bukti 2026-09-20: `git cat-file HEAD:141` = LF (2629 baris), berkas kerja = LF, dan `sha256` keduanya = `1b97c988...` = nilai cap baseline lama. Di checkout baru berkas jadi CRLF sehingga hash berbeda → cap/registry tidak cocok lintas mesin. `check_migrations()` **tidak** membandingkan checksum berkas (hanya UNAPPLIED/DUPLICATE/VERSION_MISMATCH), jadi instalasi tidak terblokir; efeknya `apply-migration.mjs` meminta `--restamp` di mesin dengan EOL berbeda | Pilih satu: normalisasi CRLF→LF sebelum hashing (generator + `apply-migration.mjs`) **atau** kunci `*.sql text eol=lf`; buktikan sha256 identik pada checkout LF dan CRLF | ✅ SELESAI (2026-09-20: modul bersama `supabase/scripts/migration-checksum.mjs` menormalisasi EOL CRLF→LF sebelum hashing; **66** cap baseline + **50** entri registry disegarkan lewat `npm run db:refresh-checksums -- --apply --db`; bukti pada 141 (berkas terbesar): LF & CRLF sama-sama `17989aa0…` sedangkan algoritma lama `17989aa0…` vs `7a7f0b9a…`; guard `tests/unit/migration-checksum-eol.test.ts` **5/5**; `001_init.sql` (CRLF) kembali “checksum cocok”; `--restamp` kini tidak lagi menimpa `applied_at`). **Bukti lintas-checkout NYATA 2026-09-20** (main tree 98 LF + 66 CRLF-campuran vs `git worktree` segar 164 CRLF): algoritma lama **101/164** berkas beda sha256, algoritma baru **0/164**; registry live cocok **129/164** (sisa 35 = SQL-11). Turunan: drift **KONTEN** 35 berkas → SQL-11 |
| SQL-11 | **P2** | **35 migrasi drift checksum KONTEN** — registry ≠ hash berkas sekarang, dan ini BUKAN soal EOL | Bukti 2026-09-20 (`db:refresh-checksums --db`): dari 85 entri tidak cocok, **50 hanya beda EOL** (sudah disegarkan) dan **35 beda konten**: 011, 018, 027, 051, 052, 053, 054, 058, 062, 073, 083, 086, 091, 140, 171, 172, 175, 176, 178, 180, 181, 183, 186, 195, 196, 199, 201, 206, 208, 210, 212, 213, 219, 221, 226 — sebagian besar berkas yang diperbaiki sesi fresh-install, jadi live kemungkinan sudah benar tetapi registry tidak lagi membuktikannya. `check_migrations()` tidak memeriksa checksum berkas, jadi tidak memblokir instalasi | Audit per berkas: tentukan (a) cukup `--restamp` (live sudah memuat perubahan, dibuktikan objek per berkas) atau (b) perlu `--apply` ulang (live tertinggal); tidak boleh diselesaikan dengan restamp massal tanpa bukti | OPEN |
| SQL-12 | **P3** | **`worker_update_profile` tidak bisa mengosongkan field** — pola `COALESCE(p_param, kolom)` membuat NULL = "jangan ubah", jadi sekali field terisi (mis. agama) worker tak bisa mengosongkannya lewat UI | Terverifikasi 2026-09-20: definisi live `agama = COALESCE(p_agama, agama)`; smoke OPS-01 attempt-1: simpan '' sukses di UI tapi DB tetap berisi nilai lama (residu dibersihkan manual ke NULL). UI sudah benar (kirim `form.agama ∥ null`), masalahnya di RPC | Putuskan: (a) terima batasan + dokumentasikan, atau (b) ubah RPC agar pengosongan eksplisit mungkin (kontrak RPC berubah — G3: grep semua pemakai + cek konsumen hilir sebelum mengubah) | OPEN — **butuh keputusan user** |

| OPS-01 | **P2** | **Smoke runtime WorkerProfile belum dijalankan** (pindahan `§5` STATE DONE) | `§5` hanya menyisakan satu item OPEN: login worker → WorkerProfile → edit 1 kolom → simpan → reload. Grant `EXECUTE TO authenticated` sudah termigrasi di `222` (baris 79 + 150-152) — tidak ada langkah SQL tersisa. Lingkungan agent tidak bisa menjangkau app live | User menjalankan smoke di browser lalu hasilnya ditulis ke `agentsLogs.md` | ✅ SELESAI (smoke `npm run smoke:ops01` LULUS untuk worker NRP007; bukti di entri log 2026-09-20) |
| OPS-02 | **P2** | **Guard dokumen menghitung berkas *working tree*, termasuk yang UNTRACKED** — `doc-claims-vs-live.test.ts` §7.3 membandingkan klaim `ARCHITECTURE.md` dengan hasil penelusuran di disk, sehingga checkout bersih tidak bisa hijau selama ada berkas test yang belum di-commit | Bukti 2026-09-20: `find tests` = **38** berkas `*.ts` dan `*.tsx`, sedangkan `git ls-files tests` = **36**. Dua berkas untracked (`tests/e2e/worker-profile-smoke.spec.ts`, `tests/unit/work-queue-consistency.test.ts`) memaksa §7.3 ditulis `38` (disk) padahal HEAD hanya punya 36 — angka itu akan salah lagi begitu salah satu berkas di-commit atau dihapus | Pilih satu: **(a)** commit berkas test WIP lalu jaga angka §7.3, atau **(b)** ubah guard agar menghitung hanya berkas ter-track (`git ls-files`); buktikan §7.3 hijau pada tree kotor **dan** checkout bersih | ✅ SELESAI (2026-09-20: `countFiles` diganti `trackedFiles()` berbasis `git ls-files` + `countTracked(prefix, exts)`; §7.3 kini **202** = 157 `src` + 39 `tests` + 6 config (angka tracked, bukan disk yang saat itu 38 `tests`); guard hijau di tree kotor, dan angka tracked identik di checkout bersih karena bersumber dari index git). **Demo merah/hijau 2026-09-20** di worktree scratch dengan 2 berkas test untracked: logika lama (verbatim `4d11988^`) **MERAH** (disk tests 41 vs dokumen 39), logika `git ls-files` **HIJAU** (39=39); guard asli tetap hijau di tree yang sama dan di checkout bersih) |

> **Dipangkas 2026-09-20** — item ✅ yang hasilnya sudah tertulis di `agentsLogs_2026-09.md` dikeluarkan dari tabel
> ini sesuai aturan #3 di atas: **SQL-01, SQL-03, SQL-04, SQL-05, SQL-07**. Jangan diinvestigasi ulang.

> Baris ber-ID `OPS-*` adalah temuan operasional non-SQL yang tetap wajib ditutup seperti item lain.

### Sudah diverifikasi **BUKAN masalah** — jangan diinvestigasi ulang

> Semua di bawah ini awalnya terlihat seperti drift/kerusakan, lalu **terbukti salah** setelah
> dicek ke kode/DB. Dicatat supaya tidak memakan waktu agent berikutnya.

| Yang tampak rusak | Kenapa ternyata bukan masalah |
|---|---|
| 18 "ACL mismatch" migrasi vs live | `172_hardening_grants.sql:13-15` melakukan `REVOKE EXECUTE ON ALL FUNCTIONS ... FROM PUBLIC, anon, authenticated` lalu re-grant daftar putih; `141:2599-2611` melakukan hal sama secara dinamis. Live = hasil yang dimaksud |
| 19 trigger `trg_audit_*` "tanpa sumber" | Dibuat dinamis oleh loop `141:2332` (`trig_name := 'trg_audit_' || tbl`) |
| 102 dari 105 policy "tanpa sumber" | Dibuat dinamis: `141:607` (`rls_authz_`), `141:2218/2333` (`rls_%I_read/_write/_select`), `208` (`select_auth`, `all_service`) |
| 87 dari 95 sequence "tanpa CREATE" | Sequence implisit dari kolom `SERIAL` — tidak pernah ditulis eksplisit |
| 4 versi migrasi `DUPLICATE` (176/186/208/215) | Sah per komentar migrasi 219 (beberapa berkas boleh berbagi nomor versi) |
| `get_enabled_modules_legacy_noarg` "tanpa sumber" | Di-rename oleh migrasi **205** (`ALTER FUNCTION ... RENAME TO`) |
| `review_360` di-drop `058:137` lalu dirujuk `083:240` | Rujukan itu dibungkus `IF EXISTS (information_schema.tables)` → aman |
| 272 grant tabel ke `anon` | Terverifikasi **0 tabel** dengan grant anon tapi RLS mati, dan **0 tabel** RLS tanpa policy → tertutup RLS |
| 240 "partisi" | Angka itu termasuk **index** partisi (`relispartition` juga benar untuk index); partisi nyata = 57 |
| **Niat migrasi 226C mencabut `anon` dari `verify_admin_otp(text)`** | **BUKAN masalah — justru niat itu yang keliru.** `src/pages/Home.tsx:361` dan `:468` memanggil `rpc('verify_admin_otp', { p_code })` SEBELUM sesi Supabase ada (verifikasi OTP di halaman login), jadi `anon` memang WAJIB bisa memanggilnya. Grant eksplisit di migrasi 231-lah yang benar; migrasi 233 sengaja TIDAK mencabutnya. Diverifikasi ke kode live 2026-09-19 |
| **"Grant anon melonjak ke 130" setelah migrasi 231** | **Diperiksa tuntas, bukan kebocoran.** 119 di antaranya fungsi internal pgvector (operator/distance/typmod — memang begitu sejak extension dipasang), 7 entry pra-login, dan 3 RPC baca yang memang publik (`get_branding`, `get_branding_public`, `get_enabled_modules`). Sisa 1 memang bocor (`auth_testing_override_bypass`, mewarisi default privilege saat 231 membuatnya) → dicabut migrasi 233, sehingga live sekarang **129**. Rinciannya dari probe `anon` non-whitelist, 2026-09-19 |
