# AGENTS.md — ATURAN KERJA AGENT (WAJIB) — ONE SINGLE TRUTH

> **Restrukturisasi 2026-09-19 (P0): berkas ini DIPECAH.** Sejak sekarang ia hanya memuat
> (a) alur kerja wajib §0, (b) Golden Rules §0.5, dan (c) Work Queue §5.8 — plus peta bacaan
> di bawah. Semua isi lain pindah ke berkas terpisah supaya agent tidak memuat 57 KB hanya
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
> | riwayat pekerjaan yang SUDAH selesai | `agentsLogs.md` (JANGAN taruh history di sini) |
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
4. **Setelah sukses: tulis hasilnya ke `agentsLogs.md`** (format entri ada di header file itu)
   dan **KELUARKAN dari AGENTS.md** — item selesai TIDAK tinggal di file ini.
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
| SQL-01 | ✅ | **Instalasi dari awal SUDAH JALAN** (dulu berhenti di `047:220`; replay pertama hari ini `136/156 sukses, 20 GAGAL`) | 20 berkas gagal saat replay pertama (000→229, 156 berkas). Akarnya: `047` bentrok bentuk `webhook_logs` vs `045`; `083` policy untuk tabel buatan `141`; `091` FK `user_roles_nrp_fkey` bertentangan dengan desain Owner; `062`/`206` constraint dipasang sebelum data dinormalkan; `172` GRANT ke fungsi yang belum ada; `175/176/178` skrip smoke memanggil RPC dengan data demo; `180/181` OVERLOAD fungsi industri + kolom `harvest_date` vs `date`; `183` `DROP VIEW` pada objek TABLE + `npwp_encrypted` tak ada; `199` `ura.role_id` tak ada; `201` ubah return type `jsonb`→`boolean`; `208_fix_groupby` jalan sebelum tabelnya dibuat; `221` REVOKE fungsi buatan `215` | **TERBUKTI 2026-09-18:** `node supabase/scripts/replay-fresh-install.mjs --mode=chain` → **156/156 berkas sukses, 0 GAGAL** (log: `supabase/baseline/replay-chain.md`). `140` kini pakai `'COAL'` (6 kutip ganda dibuang); `210`/`221`/`226` pakai guard `to_regprocedure`; `229` tanpa FK integer→text; `073` → `_legacy_get_estate_blocks_paged` | ✅ SELESAI — boleh dipangkas setelah entri `agentsLogs.md` ditulis |
| SQL-02 | **P2** (turun dari P1) | **25 tabel + 14 fungsi live tanpa sumber migrasi** — sekarang **tercakup**: ke-25 tabel ada di baseline (di-generate dari katalog live, bukan dari rantai), jadi instalasi perusahaan baru tidak kehilangan apa pun | Tabel: `ai_rate_limits`, `api_keys`, `api_rate_limits`, `dashboard_cache`, `user_consents`, `hr_shift_swaps`, `hr_audit_chain`, `hr_okr_results`, `hr_survey_responses`, `hr_task_board`, `safety_incidents`, `webhook_logs`, 5×`mining_*`, 5×`estate_*`, 3×`mill_*` — dipulihkan `008_restore_missing_objects.sql`. Fungsi: 13×`_legacy_*` + `worker_update_profile_legacy` — tidak dibuat rerantai, dan itu aman sekarang karena `172`/`210`/`221`/`226` memakai guard (`to_regprocedure`) sehingga ketidakhadirannya tidak menggagalkan apa pun. Terbukti: replay 156/156 dengan 14 fungsi itu tetap absen | **TERBUKTI 2026-09-18:** baseline memuat seluruh objek live — `verify-install-e2e.mjs` memasang ke project kosong dan mencocokkan **9/9 metrik** dengan live (208 tabel, 549 fungsi, 223 policy, 27 trigger, 285 partisi, 95 sequence, 4 cron job, cap 157). Sisa satu keputusan kecil: 14 `_legacy_*` di DB live dibuat ulang atau dihapus | OPEN (dampak instalasi sudah nol) |
| SQL-03 | ✅ | **5 materialized view hilang + 3 cron gagal setiap jam** | `pg_matviews` public = 0; 3 job refresh gagal 94/94/189× | **TERBUKTI 2026-09-18:** migration `228_retire_dead_mv_cache_layer.sql` men-drop 3 job + fungsi refresh `mv_*` (5 MV terbukti tidak dibaca siapa pun — 0 referensi di `src/`, `dashboard_cache` yang dipakai). Live: **4 cron job aktif, 0 kegagalan**; ke-4 job sudah diuji jalan bersih di transaksi yang di-ROLLBACK | ✅ SELESAI — boleh dipangkas setelah entri `agentsLogs.md` ditulis |
| SQL-04 | **P1** | **`hr_okrs` beda skema: live 6 kolom vs migrasi 141 (10 kolom)** | live: `id,nrp,periode,objective,status,created_at`; `141:545` mendefinisikan +`key_result,target_value,current_value,updated_at,created_by,updated_by`. `IF NOT EXISTS` → no-op di live | Satu definisi disepakati sebagai benar; `information_schema.columns` = definisi migrasi (atau migrasi diperbaiki bila live yang benar) | OPEN |
| SQL-05 | **P1** | **3 RLS policy tanpa sumber migrasi** | `candidate_pipeline.admin_read_candidate_pipeline`, `dashboard_cache.dc_admin`, `vacancies.admin_read_vacancies` (ada di live, 0 `CREATE POLICY` di migrasi, tidak ada generator loop) | Ketiganya dibuat di migrasi baru (atau dibuang bila tidak dipakai) | OPEN |
| SQL-06 | **P1** | **9 tabel RLS enabled tapi TIDAK forced** | `employees_core`, `employees_extended`, `fatigue_data`, `heavy_equipment`, `jsa_data`, `production_daily`, `safety_incidents`, `schema_migrations`, `simper_data` | Keputusan user (FORCE membuat **pemilik** tunduk policy → berisiko ke SQL Editor/dashboard); bila disetujui → `FORCE ROW LEVEL SECURITY` + verifikasi 0 tersisa | OPEN — **butuh keputusan user** |
| SQL-07 | **P1** | **Default privilege Supabase bocor ke `anon`** (fungsi baru dapat EXECUTE, tabel baru dapat ALL) | `pg_default_acl`: objtype `f` → anon/authenticated/service_role; objtype `r` → anon/authenticated/service_role. Akibat nyata: 4 RPC penulis terbuka (sudah ditutup migrasi 226); `anon` EXECUTE live = **128** fungsi | `ALTER DEFAULT PRIVILEGES` mencabut `anon` dari fungsi/tabel baru + daftar putih login eksplisit; tes penjaga tetap hijau | OPEN |
| SQL-08 | **P2** | **`hr_attendance_partitioned` = struktur mati** (0 baris) dan `RENAME` masih dikomentari | Kedua tabel absensi **0 baris**; `141:1403` masih `-- ALTER TABLE hr_attendance_partitioned RENAME TO hr_attendance`; hanya fungsi 225/227 yang menyentuh namanya | Keputusan adopsi (jalankan RENAME + pindahkan penulis data) **atau** dibuang (drop partisi + index + cron 225); tidak ada dua tabel absensi paralel | OPEN — **butuh keputusan user** |
| SQL-09 | **P2** | **Duplikat `CREATE` dalam satu berkas** (dead code, bukan konflik) | `141:545` & `141:1911` `hr_okrs`; `141:558` & `141:1924` `hr_surveys` (definisi **identik**, diverifikasi); `183` view `employees_master` 2× | Duplikat dihapus tanpa mengubah hasil replay | OPEN |
| SQL-10 | **P2** | **79 nomor versi tanpa berkas** — repo bukan histori lengkap | Nomor kosong per audit 2026-09-17: 2,4,8–26,29–32,36,37,41,46,49,56,64,66–70,**74**,85,94,96–99,103–109,112–119,121–129,142–153,170 (2026-09-18: nomor **008** kini terisi `008_restore_missing_objects.sql`, nomor **229** terisi `229_fresh_install_fk_repair.sql` — keduanya berkas perbaikan fresh-install, bukan nomor versi yang hilang. Sisa 77 nomor tetap kosong — histori tetap tidak utuh). `140:2` menyebut *"…were in 074 (deleted)"* | Ada pernyataan resmi di dokumen bahwa `000–230` bukan histori utuh + jalur instalasi resmi menggantikannya. | **TERBUKTI 2026-09-18:** (a) rantai `000→230` replay bersih **157/157**; (b) baseline replay bersih **2/2 + idempoten 2/2** dan lolos `verify-install-e2e` (metrik & ACL = live); (c) pernyataan resmi **sudah ditulis** di `supabase/baseline/README.md` §1 (dua jalur + kapan pakai yang mana). Tidak ada lagi yang bisa dituntut dari item ini | ✅ SELESAI — boleh dipangkas setelah entri `agentsLogs.md` ditulis |
| SQL-11 | ✅ SELESAI (P0) — `schema_migrations` registry verified fixed; `231_apply_missing_effects.sql` applied + registered + checksum verified; `generate_worker_otp` NIK guard confirmed present (line 182/185 source + audit entry PENDING_APPROVE_REJECTED_NIK line 261); semua 13 efek terpenuhi (`verify_install-e2e.mjs` PASS, `check_migrations()` 0 issue, replay 157/157). Boleh dipangkas setelah entri `agentsLogs.md` [2026-09-19] ditulis. | — | — | — |
| SQL-12 | **P2** | **Kolom tabel industri & beberapa tabel lain masih beda antara rantai dan live** | Diukur `diff_chain_vs_live_columns.mjs` (2026-09-18, database scratch hasil replay vs live): `estate_harvest` `harvest_date` vs `date` (**sudah diperbaiki di 180**); sisa `mining_equipment` (rantai: `category/fuel_level/hours_run/location/next_maintenance` vs live: `operator_nama/operator_nrp/type`) dan `mining_simper` (rantai: `applicant_name/area_hectare/commodity/company/issue_date/notes/simper_no` vs live: `issued_date/nama/nrp/simper_type/site`); `assets` & `forum_posts` punya kolom berlebih di rantai (`created_by`, `updated_at`, `updated_by`) | Kolom disamakan (rename/add) ATAU perbedaan dinyatakan resmi beserta alasannya; jalankan `node .freebuff/audit/diff_chain_vs_live_columns.mjs` sebagai bukti ulang | OPEN |
| SQL-14 | ✅ | **Baseline instalasi mewarisi identitas perusahaan sumber + 3 bug generator** (ditemukan 2026-09-18 saat menyiapkan instalasi satu-perintah) | (1) `branding.company_name` ikut ter-dump → perusahaan baru memakai merek kita; (2) `company_config.owner_email`/`ceo_email` ikut ter-dump, dan `get_owner_email()` punya fallback hardcoded `'owner@insightwos.com'` → owner perusahaan baru **tidak bisa login** selain dengan email kita; (3) `schema_migrations.version` ditulis `parseInt` → `check_migrations()` melaporkan **59 VERSION_MISMATCH** di instalasi baru; (4) ACL: `tables` memakai `not relispartition` sehingga 48 partisi mewarisi hak `anon` (instalasi baru lebih terbuka dari live); (5) trigger hanya diiterasi untuk tabel → 3 trigger `INSTEAD OF` di view `employees_master` hilang, membuat view itu read-only tanpa error | **TERBUKTI 2026-09-18:** migrasi `230` fail-closed (`get_owner_email()` → NULL, `owner_login` beri pesan tindak-lanjut); uji dalam transaksi yang di-ROLLBACK: owner sah `ok:true`, email lain ditolak, config kosong → tidak ada email diterima. Generator: `EXCLUDED_ROWS` + branding netral + pemindai kebocoran domain; harness hanya menjalankan berkas `NNN_*.sql`. Bukti akhir: `verify-install-e2e` → **PASS**, 9/9 metrik = live, `check_migrations()` 0 issue, trigger 27/27, ACL 0 selisih, idempoten | ✅ SELESAI — boleh dipangkas setelah entri `agentsLogs.md` ditulis |
| SQL-13 | **P1** | **21 migrasi historis diperbaiki untuk jalur instalasi dari awal → checksum registry tidak lagi cocok dengan berkasnya** | Berkas yang diubah 2026-09-18: `062, 073, 083, 091, 140, 172, 175, 176, 178, 180, 181, 183, 199, 201, 206, 208_fix_groupby, 221, 226` (+ `008/229` dari sesi sebelumnya). Perbaikannya menyentuh JALUR INSTALASI (guard/urutan/idempotensi), **bukan** objek live — live tidak diubah sama sekali hari ini. `check_migrations()` tetap **0 issue** karena ia tidak membandingkan checksum berkas; `verify_migration_checksum` akan melaporkan BEDA | Putuskan: (a) re-stamp checksum berkas-berkas itu di `schema_migrations` (dengan catatan tanggal+alasan), atau (b) tambahkan mode `--restamp` pada `apply-migration.mjs` + daftar "diperbaiki maju" yang ditinjau manual. Bukti: `select filename from schema_migrations where filename in (...)` + `verify_migration_checksum` per berkas | OPEN — **butuh keputusan user** |
| OPS-01 | **P2** | **Smoke runtime WorkerProfile belum dijalankan** (pindahan `§5` STATE DONE) | `§5` hanya menyisakan satu item OPEN: login worker → WorkerProfile → edit 1 kolom → simpan → reload. Grant `EXECUTE TO authenticated` sudah termigrasi di `222` (baris 79 + 150-152) — tidak ada langkah SQL tersisa. Lingkungan agent tidak bisa menjangkau app live | User menjalankan smoke di browser lalu hasilnya ditulis ke `agentsLogs.md` | OPEN |

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
