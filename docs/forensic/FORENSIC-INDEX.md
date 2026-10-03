# FORENSIC INDEX — insightWOS

Tanggal: 2026-09-25
Total audit: 88 (batch 1-9)
Status: **AUDIT-ONLY** — belum ada fix dieksekusi (menunggu approve user)

> Protokol: read-only mutlak selama 88 audit. Tidak ada fix / commit (kecuali file
> index ini) / test yang menulis state. Temuan P0 TIDAK menghentikan audit.

## Batch Raw (.agents/reports/forensic/)
- [x] Batch 01 — Audit 01-10 → FORENSIC-RAW-batch-01.md ✅ **selesai**
- [x] Batch 02 — Audit 11-20 → FORENSIC-RAW-batch-02.md ✅ **selesai**
- [x] Batch 03 — Audit 21-30 → FORENSIC-RAW-batch-03.md ✅ **selesai** (baseline `9715fe8`)
- [x] Batch 04 — Audit 31-40 → FORENSIC-RAW-batch-04.md ✅ **selesai** (baseline `4609c80`)
- [x] Batch 05 — Audit 41-50 → FORENSIC-RAW-batch-05.md ✅ **selesai** (baseline `3229a02`)
- [x] Batch 06 — Audit 51-60 → FORENSIC-RAW-batch-06.md ✅ **selesai** (baseline `0528bb0`)
- [x] Batch 07 — Audit 61-70 → FORENSIC-RAW-batch-07.md ✅ **selesai** (baseline `86d47da`)
- [x] Batch 08 — Audit 71-80 → FORENSIC-RAW-batch-08.md ✅ **selesai** (baseline `fe8b153`)
- [x] Batch 09 — Audit 81-88 → FORENSIC-RAW-batch-09.md ✅ **selesai** (baseline `c98875d`)

## ✅ SELESAI — 9 BATCH AUDIT SELESAI (88 audit, 2026-09-25/26)

Semua 88 audit telah dijalankan dalam mode **read-only**. Siap untuk `FORENSIC-GLOBAL` +
`FORENSIC-FIXPLAN` (menunggu instruksi terpisah — **belum** dibuat).
Sisa: tidak ada.

## Global Analysis (docs/forensic/)
- [x] **FORENSIC-GLOBAL.md** — analisis relasi, root cause map, cakupan audit, prioritas risiko
- [x] **FORENSIC-FIXPLAN.md** — 13 batch fix berurutan dari akar (**#1** `5cd9ab3` · **#13 SELESAI** `727b835`+`347ba01`+`6594cb0`; sisanya RENCANA)
- Laporan mentah per batch: `.agents/reports/forensic/FORENSIC-RAW-batch-01..09.md`

## 🔢 Konstanta & Guard — Inventaris (🟡 B0, 2026-09-30)

- File: [`docs/forensic/CONSTANTS-INVENTORY.md`](CONSTANTS-INVENTORY.md) — peta semua konstanta hitungan
  di repo tracked (dokumen, guard scripts, test, baseline) + guard yang menjaganya.
- Prinsip: konstanta tanpa guard = drift diam-diam; guard yang tidak tahu konstanta yang dijaga = guard palsu.
- Bukti guard hidup @ `f81af1e`: `verify:artifacts` 0 drift, 1 warning (baseline commit → Fix #9).
- Konstanta TANPA guard yang teridentifikasi: SECURITY.md (kolom migrasi 141/215/220, "18 scripts (183–214)"),
  duplikat klaim migrasi Fix #4/#5 di file ini (179/254), total batch audit 88/122, snapshot supabase/baseline/*.md.
- Aturan: fix apa pun yang menambah migrasi/test/angka dokumen WAJIB cek + perbarui file itu.

## Fix #14 — Peta Role/Level/Login (🟡 INVESTIGASI 2/3 — B1 DB live + B2 code src/, 2026-09-30)

- File: [`docs/forensic/FIX14-ROLE-LEVEL-TOTAL.md`](FIX14-ROLE-LEVEL-TOTAL.md) — single source of truth Fix #14 (B1 §1–§4 diisi; §5–§6 menunggu B2 code read; §7–§11 menunggu B3 rencana).
- Fakta kunci DB live: `user_roles.role_level` flat=1 (17 baris) · `employees_core.role_level`=0 semua · `business_units` SEMUA tier=4 (gate tier tidak pernah memblokir) · `master_job_levels` kosong · `audit_log_owner` count=0 dan skema tidak cocok (`owner_auth_id`/`details` tidak ada) → `owner_update_role` broken · `admin_set_role` stub · `admin_set_employee_role` mapping level hardcoded 4/3/1 · set yatim `supervisor`/`manager`/`admin_produksi` (dipakai 0) · 0 FK pada tabel role · `get_my_role` percaya param `p_nrp`.
- Keputusan produk (user, 2026-09-30): level 1=worker, 2=supervisor, 3=manager, 4=admin, 5=CEO; owner = GOD terpisah; multi-view (/dashboard sesuai jabatan + /worker data diri); login email+password.
- Raw probes (gitignored): `.agents/scripts/fix14-b1-dbmap.mjs` (B1) + `.agents/scripts/fix14-dbmap.mjs` (peta awal B–I).
- **[2026-10-01] §8 CLOSED** — migrasi `255` (backfill `role_level` + hapus assignment NRP001) + `256` (selaraskan pemetaan level `owner_assign_admin_user`) DITERAPKAN ke live, commit `6ffc890`, sudah push. NRP001=5, NRP100–106=3, NRP002–010=1; assignments 17→16; `prosrc` 256 = semua `admin_*`→3. Detail + bukti di [`FIX14-ROLE-LEVEL-TOTAL.md` §8](FIX14-ROLE-LEVEL-TOTAL.md). **§9–§13 belum dieksekusi.**

## ✅ Work Queue Fix #14 — blocker §9/§10 (2026-10-01, bukti fresh; K/H/I **CLOSED** 2026-10-02)

> Item **wajib ditutup seperti item lain** — lihat `AGENTS.md` §5.8. Bukti di bawah dari probe
> READ ONLY `.agents/scripts/fix14-b221-wq-evidence.mjs` (2026-10-01) + `git grep src/`.
> Nomor P1/P2-F14-A…G sudah ada di `AGENTS.md` §5.8; yang baru di sini = K, H, I, J.

| ID | Prio | Masalah | Bukti (terverifikasi) | Definition of Done | Target |
|---|---|---|---|---|---|
| **P1-F14-K** | P1 | `user_role_assignments` — tabel yang **menjadi sumber kebenaran admin** setelah §9 — **tidak punya trigger audit sama sekali**. Perubahan role/scope admin tidak masuk `audit_log`. Gate audit rules §12 tidak akan menangkapnya. | PRE: `K1-trig-user_role_assignments = 0 trigger`; 20 trigger `trg_audit_*` semuanya di tabel lain. POST (migrasi `257`): trigger `trg_audit_user_role_assignments` live `tgenabled='O'` via `_generic_audit_trigger_fixed`; uji INSERT `NRP999-TEST` → `audit_log` **582→583** (`audit_naik_1: true`), `actor='SYSTEM'` (probe tanpa JWT = fail-safe yang diterima, bukan NULL) | ✔ **CLOSED** (migrasi 257) |
| **P2-F14-H** | P2 | `authz_in_scope()` cabang `TEAM` memakai `ho1.manager_nrp = ho2.manager_nrp`, tapi kolom itu **tidak ada** di `hr_org` (hanya `atasan_nrp`) → cabang TEAM **error saat runtime**, bukan sekadar false | PRE: `hr_org` 7 kolom tanpa `manager_nrp`; `Q4` scope_type distinct = `BU` 3, `ENTERPRISE` 4, `SELF` 9 (**`TEAM` = 0**). POST (migrasi `258`, keputusan **H2**): `pakai_atasan_nrp: true`, `masih_manager_nrp: false`; `prosecdef=true`/`provolatile='s'`/`proconfig` preservasi; smoke `authz_in_scope('NRP002')` = `false` (**bukan** error `42703`) | ✔ **CLOSED** (migrasi 258) |
| **P2-F14-I** | P2 | `admin_produksi` ada di CHECK `user_roles_role_check` dan di whitelist `is_admin_or_owner`, tapi **tidak ada di tabel `admin_roles`** (7 role_code, `admin_produksi` n=0). Akibat: user dengan role itu **lolos `is_admin_or_owner`** lalu ditolak `check_admin_access` dengan `reason='role_not_found'` — dua gerbang admin tidak konsisten. | PRE: `B6`–`B9` = 0 di empat tempat; `I5` `is_admin_or_owner` vs `check_admin_access` tidak konsisten. POST (migrasi `259`, **I2 tahap murah**): CHECK 14→**13 elemen**, `punya_admin_produksi: false`; `is_admin_or_owner` `LANGUAGE sql`+`STABLE`+`SECURITY DEFINER` preservasi; **uji negatif `23514` check_violation** + sanity role valid tetap bisa ditulis. POST (migrasi `260`, **I2 tahap 2**): 3 baris `role_permission_sets` (id 14/15/16) dihapus, `permission_set_items` tetap **93** (ketiga set dipakai 10/6/3 role lain, tidak ada set yatim), 0 FK ke tabel, `sequence last_value=28` tak bergeser | ✔ **CLOSED** (migrasi 259 + 260) — `admin_produksi` = **0 di kelima tempat**; sisa satu-satunya whitelist `admin_set_employee_role` (§11 P2-F14-F) |
| **P2-F14-L** | P2 | `user_role_assignments.role_code` **tidak punya CHECK constraint maupun FK ke `admin_roles`** → INSERT langsung dengan `role_code` sembarang tetap mungkin. Tabel ini yang jadi sumber kebenaran admin setelah §9, jadi gap di sini berarti sumber kebenaran bisa berisi role yang tidak dikenal sistem. | `user_role_assignments` constraint: PK + UNIQUE `(nrp, role_code, scope_type, scope_bu_id)` (probe B2.22), **tanpa CHECK role_code / FK**; `pg_constraint confrelid='user_role_assignments'` = 0 FK | CHECK `role_code IN (role_code aktif di admin_roles)` atau FK ke `admin_roles(role_code)` + guard test yang membuktikan INSERT role asing ditolak | 🟡 **PARTIAL** (2026-10-03) — FK ✅ via migrasi **261**: master table `role_codes(code)` 13 baris (10 aktif + 3 reservasi `owner`/`director`/`admin`) + `fk_ura_role_code` + `fk_ur_role` menggantikan CHECK `user_roles_role_check`. Uji negatif **23503** pada kedua FK. Sisa: guard test otomatis (§12) — FK bisa dilepas tanpa `verify:artifacts` berteriak (kelas bug yang sama seperti P2-F14-M). Deviasi dari rancangan: FK ditambahkan sebelum CHECK di-drop (fail-safe), bukan sebaliknya |
| **P2-F14-M** | P2 | Tidak ada guard yang mendeteksi perubahan **bahasa** / **volatilitas** fungsi. `verify:artifacts` hanya membandingkan **jumlah** fungsi, jadi `LANGUAGE sql` → `plpgsql` pada `is_admin_or_owner` (atau `STABLE`→`VOLATILE`) **tetap hijau**. | Hot spot nyata: migrasi 259 menyebut `is_admin_or_owner` `LANGUAGE plpgsql`, padahal fact live `LANGUAGE sql` + `STABLE` (`{"bahasa":"sql","provolatile":"s"}`). Kalau draft dipakai apa adanya, semantik fungsi berubah **tanpa** gate yang berteriak. `Functions` tetap 658 sebelum-sesudah | Test baru (mis. `tests/unit/db-function-attributes-guard.test.ts`) yang baca `pg_proc.prolang` / `provolatile` / `prosecdef` / `proconfig` untuk fungsi authz kunci dan bandingkan dengan ekspektasi | P2 (usulan) |
| **P1-F14-J** | P1 | NRP001 sudah `role_level=5` (CEO) tetapi `role` masih literal `'admin_pusat'`. Rename ke `'ceo'` **belum dilakukan** dan belum bisa dilakukan murah | `J1 = 0 baris role='ceo'`; CHECK `user_roles_role_check` tidak memuat `'ceo'`; `git grep -l admin_pusat -- src/` = **61 file** / **127 kemunculan** | `ALTER TABLE ... DROP/ADD CONSTRAINT` memuat `'ceo'` + `user_roles` NRP001=`'ceo'` + **`admin_roles` + `role_page_access` punya `ceo`** + 61 file `src/` di-review — atau keputusan user mendokumentasikan keputusan menolak rename | §10 (K1β) |

**Catatan prioritas (bukan keputusan — §0.13)**

> P1-F14-J saya usulkan **P1**, bukan P2: selama NRP001 masih `admin_pusat`, gate mana pun yang
> memeriksa `role = 'admin_pusat'` (bukan `role_level`) akan memperlakukan CEO sebagai admin
> biasa — persis kelas bug yang §9 akan perbaiki. Tapi prioritas di-set **user**, jadi item
> ini menunggu konfirmasi.
>
> P1-F14-K saya usulkan **P1** karena tanpa trigger, §9 menulis ulang data otorisasi admin
> **tanpa jejak audit** — dan `audit_log` sudah jadi bahan investigasi §4/P1-13-01.

**Pelajaran proses baru (2026-10-02)**

> **P7 — pre-image timestamp untuk rollback WAJIB diambil dari sisi server.** `role_permission_sets.created_at`
> punya `datetime_precision = 6`, tapi driver `pg` truncate tampilan ke **3 digit** desimal, jadi probe
> membaca `10:00:41.036` padahal aslinya `10:00:41.**036520**`. Rollback versi pertama menulis `.036`
> → hash tabel tidak byte-identik. Simulasi pra-apply yang menangkapnya; kalau tidak disimulasikan,
> byte yang salah ini akan tersimpan permanen di DB sampai migrasi berikutnya. **Aturan:** pakai
> `created_at::text` atau `to_char(created_at, 'YYYY-MM-DD HH24:MI:SS.USOF')`.
>
> **P8 — `verify:artifacts` buta terhadap perubahan `LANGUAGE` / `provolatile`.** Gate hanya menghitung
> **jumlah** fungsi (658). Mengubah `LANGUAGE sql` → `plpgsql` atau `STABLE` → `VOLATILE` tidak
> mengubah hitungan, jadi gate tetap hijau padahal semantik authz bisa berubah. Migrasi 259 hampir
> kena (rencana tulis `plpgsql`; fact live `sql`+`STABLE`) — tertangkap karena definisi byte-exact
> `pg_get_functiondef` dipakai, bukan karena ada guard. Item: **P2-F14-M**.

**Dampak lintas-page**: worker → admin → dashboard → owner **tidak terdampak** untuk 257/258/259/260
(0 user dengan role `admin_produksi`, 0 assignment, scope `TEAM` = 0 baris — tidak ada perubahan
perilaku untuk siapa pun). Yang berubah hanya kemampuan audit (`user_role_assignments`) dan
penghapusan metadata role yang mustahil dipakai. Tidak ada yang menyentuh `src/` atau `tests/`.

## Status Temuan Backup & DR (P1-14 / P1-45) — ✅ SEMUA CLOSED (2026-09-27)

| Temuan | Status | Bukti |
|---|---|---|
| **P1-14-01** (`pg_restore` untuk plain SQL) | ✅ **CLOSED** | step "Sync to Neon" dihapus — commit `727b835`. Ditutup lewat **perubahan desain**, bukan patch: target restore (Neon free) tidak pernah setara Supabase. |
| **P1-14-02** (tidak ada restore test / DR drill) | ✅ **CLOSED** | (a) `scripts/verify-backup-artifact.mjs`, dijalankan sebagai step `Verify artifact` di `supabase-backup.yml` — commit `347ba01`, dipindah `08f74cb`; (b) workflow `.github/workflows/restore-test.yml` mingguan (`npm run db:replay` → replay baseline + bandingkan metrik & ACL vs DB live) — commit `6594cb0`. **Bukti eksekusi:** run hijau 2026-09-27 → <https://github.com/cezetex-lab/WOS-Web/actions/runs/36302850533> |
| **P1-45-01** (`DISASTER_RECOVERY.md` klaim palsu) | ✅ **CLOSED** | `DISASTER_RECOVERY.md` ditulis ulang 2026-09-27: hot standby dinyatakan **TIDAK ADA**, RPO 24 jam, RTO 1–2 jam manual, §9.6 mencantumkan tiap klaim lama yang dihapus + alasannya — commit `6594cb0`. |

**Riwayat commit Batch #13** (branch `migrasi-vite`):

> **Catatan akurasi bukti.** Angka `2/2 berkas sukses · 0 GAGAL · 12 metrik SAMA` berasal dari
> `supabase/baseline/replay-baseline.md` yang **bertimestamp 2026-09-18** — itu implementasi
> **manual**, satu hari sebelum workflow `restore-test.yml` dibuat. **Bukti eksekusi workflow**
> adalah link run di atas. Run CI berikutnya (Kamis 03:00 UTC) akan menimpa file itu dengan
> timestamp baru, dan angka saat itu **benar-benar** berasal dari workflow.

| Commit | Isi |
|---|---|
| `727b835` | hapus step "Sync to Neon" (−15 baris) — P1-14-01 tertutup |
| `347ba01` | `verify-backup-artifact.mjs` (5/5 exit code teruji lokal) + `npm run verify:backup` — **dipindah ke `supabase-backup.yml` di `08f74cb`** |
| `6594cb0` | `restore-test.yml` (mingguan) + rewrite `DISASTER_RECOVERY.md` — P1-14-02 & P1-45-01 tertutup |

**Kronologi kegagalan run #28–#32**: 5 run berturut gagal karena **premis** (dump Supabase →
restore ke Neon free), bukan karena bug per langkah. #26 dan #28 adalah bug NYATA (versi client,
tool restore); #29–#32 adalah gejala premis salah. Detail + pelajaran di `FORENSIC-FIXPLAN.md`
§13.7.

**Dampak lintas-page**: worker → admin → dashboard → owner **tidak terdampak** — perubahan hanya
di `.github/workflows/`, `scripts/`, dan dokumen. Tidak menyentuh `src/` maupun `supabase/`.

### Progres eksekusi FIXPLAN
| Batch | Status | Commit / Bukti |
|---|---|---|
| #1 CI DULU | ✅ **SELESAI** (2026-09-26) | `5cd9ab3` — run #1 `success`, 11/11 step hijau |
| #2 Sinkronisasi artefak | ⏳ RENCANA | menutup P1-31-01/56-01/68-01 + `continue-on-error` residual #1 |
| #13 Backup & DR | ✅ **SELESAI** (2026-09-27) | `727b835`+`347ba01`+`6594cb0` — P1-14-01/02 + P1-45-01 CLOSED; [run restore-test hijau](https://github.com/cezetex-lab/WOS-Web/actions/runs/36302850533) (2/2 replay, 12 metrik SAMA) |
| #4 Audit Trail | ✔ **SELESAI** (2026-09-27) | migrasi `251`/`252`/`253` — P1-13-01 (actor terisi: NRP asli / SYSTEM, dibuktikan uji JWT claim) · P2-13-01 (cron retensi 365 hari) · verify_audit_chain chain-aware · konsolidasi trigger (1 perubahan = 1 baris audit) · anon grants 131→130 (Opsi A) |
| #5 Auth + Identitas | ✔ **SELESAI** (2026-09-28) — *kecuali deploy edge* | migrasi `254` DITERAPKAN (live 179 baris, `max(version)=254`) — **P1-46-01** (kanal reset password jujur via `settings.password_reset_channel`, default `admin`) · **P1-74-01** (`employees_core_email_unique`; 17/17 terisi, 0 duplikat raw & case-insensitive, 0 NULL) · edge `password-reset` action=request membaca flag lewat `service_role` (settings FORCE RLS tanpa policy SELECT) · `tests/unit/db-password-reset-channel.test.ts` (7 test, 5 DB-live + 2 sumber) · guard `EMAIL_PROVIDER_READY` (2026-09-29): kanal `email` butuh env saat deploy, bukan cukup `UPDATE settings` |


> **Anomali OID (P3-F04-01, ⚠ NEW, bukan blocker):** overload `verify_audit_chain(integer, integer)`
> (OID 298611) hilang setelah migrasi 252 tanpa ada `DROP FUNCTION` di file mana pun — grep
> seluruh skrip bersih dan `grep verify_audit_chain src/` = **0 hit**, jadi dampaknya nol. Penyebabnya
> belum teridentifikasi; dicatat terbuka di `AGENTS.md` §5.8. Aktor DDL yang tidak kita understand
> adalah risiko tersisa yang harus jujur, bukan diabaikan.
> **Dokumen diringkas**: 122 temuan → **4 akar masalah** (sinkronisasi artefak, test keamanan vakuit,
> audit trail kosong, keputusan lama tak dire-evaluasi). Fix plan diurutkan dari akar, bukan gejala.


### 🧾 Work Queue baru dari Fix #5 (2026-09-28) — wajib ditutup seperti item lain

> Detail lengkap (Bukti + Definition of Done) ada di `AGENTS.md` §5.8. Ringkas:

| ID | Prio | Masalah | DoD singkat |
|---|---|---|---|
| P1-F05-01 | P1 | `admin_get_employees()` stub — cek authz, **0 baris data**; dipakai `Employees.tsx` untuk daftar karyawan | RPC mengembalikan data nyata saat admin login |
| P1-F05-02 | P1 | Dua skema hash password (`digest(sha256)+salt` vs `crypt+gen_salt('bf')`) | satu skema, atau bukti kompatibel + audit |
| P2-F05-03 | P2 | 9/17 email `@insightwos.internal` (TLD privat) → tak bisa menerima surat | semua email bisa menerima surat, atau accepted risk tertulis |
| P3-F05-04 | P3 | `src/pages/PasswordReset.tsx` orphan (0 route, 0 referensi) | hapus atau daftarkan route |
| P3-F05-05 | P3 | RPC `request_password_reset` dead code + pesan palsu di `141:680/702` & `baseline:14067/14089` | dihapus/dikoreksi saat regenerasi baseline (Fix #9) |
| P3-F05-06 | P3 | `login_otp`: `emailed = !linkErr` dari `generateLink()` (tidak mengirim email) | pesan jujur atau provider email nyata |

> **Residual Fix #5:** `supabase/baseline/000_baseline_schema.sql` belum memuat `employees_core_email_unique`
> maupun baris `settings` baru → instalasi perusahaan baru berbeda dari live sampai Fix #9 regenerasi baseline
>
> **Residual Fix #5 lanjutan (2026-09-29):** `EMAIL_PROVIDER_READY` adalah **izin, BUKAN bukti**.
> Kalau di-set `true` tanpa kode SMTP/Resend nyata, guard itu justru meloloskan kebohongan yang
> sama seperti P1-46-01. Jangan diset sebelum provider benar-benar ada; implikasi pengiriman email
> = batch berikutnya. Variabel didaftarkan di `.env.example` (bukan di `settings`, supaya tidak
> bisa dinyalakan lewat satu `UPDATE`).
> (freeze P1-68-01 tetap dihormati). Sumber bukti: probe `.agents/scripts/fix5-*.mjs` + log `.agents/logs/fix5-*.log`.

## ❄️ FREEZE CONDITION — INSTALLER (P1-68-01)

**JANGAN jalankan `install-baseline.mjs` / `rehearse-new-company.mjs` untuk PT baru sampai baseline diperbaiki.**
Baseline `supabase/baseline/000_baseline_schema.sql` (regenerate 2026-09-24 19:14) meng-`GRANT`
`anon` + DML `authenticated` kembali ke `employees_master` di **L17327-17328** — **setelah** `REVOKE`
di L16458, jadi grant menang. PT baru berikutnya akan **mewarisi P0-01-01 + P0-03-01**.
Live DB **aman** (migrasi 249/250) — yang belum aman adalah **installer**.

## 🔁 POLA AKAR YANG MUNCUL 3× (P1-71-01)

Live DB berubah → artefak turunan **tidak** ikut tersinkron:

| Artefak | Temuan |
|---|---|
| `schema_migrations` | P1-31-01 (migrasi 250 apply di luar wrapper) |
| `ARCHITECTURE.md` §7.3/§7.4 | P1-56-01 (migrasi 249+250) |
| `supabase/baseline/000_*.sql` | P1-68-01 (migrasi 249+250) |

Satu root cause: **tidak ada langkah sinkronisasi artefak turunan** setelah perubahan DB.
→ Fix plan: guard otomatis (bukan manual) + checklist di §0.3.

## 🎭 LAPISAN TEST KEAMANAN FIKTIF (P1-58-02 + P1-63-01)

"Hijau ≠ aman". `rpc-security.test.sql` hanya cek **"tabel punya RLS aktif"**, bukan
**"anon/authenticated tak bisa baca/tulis"** — tepat celah yang membiarkan 2 P0 lolos.
Ditambah nol test untuk CHECK/UNIQUE constraint (P1-58-01) dan nol `to_regclass` fail-fast (P1-72-01).

## Temuan Summary (FINAL — 9 batch selesai)
| Severity | Jumlah | Catatan |
|---|---|---|
| **P0** | **2** | ✅ mitigated di live (migrasi 249 + 250) — **installer belum**, lihat ❄️ FREEZE |
| P1 | **38** | 36 (b1-8) + 2 (batch 09) |
| P2 | **44** | 43 (b1-8) + 1 (batch 09) |
| P3 | **38** | 36 (b1-8) + 2 (batch 09) |
| **TOTAL 88 AUDIT** | **122** | 9/9 batch selesai |

### Ringkasan batch
| Batch | Audit | P0 | P1 | P2 | P3 |
|---|---|---|---|---|---|
| 01 | 01-10 | 1* | 5 | 2 | 2 |
| 02 | 11-20 | 0 | 5 | 6 | 7 |
| 03 | 21-30 | 1* | 3 | 3 | 8 |
| 04 | 31-40 | 0 | 6 | 11 | 7 |
| 05 | 41-50 | 0 | 5 | 8 | 7 |
| 06 | 51-60 | 0 | 5 | 10 | 3 |
| 07 | 61-70 | 0 | 4 | 1 | 0 |
| 08 | 71-80 | 0 | 3 | 2 | 2 |
| 09 | 81-88 | 0 | 2 | 1 | 2 |
| **TOTAL** | **88** | **2*** | **38** | **44** | **38** |

`*` = keduanya sudah dimitigasi di live (migrasi 249 + 250).

### 🔴 Batas yang harus diakui (P1-88-01)
88 audit ini memverifikasi **struktur** (ACL, skema, kode, dokumen) — **tidak pernah memverifikasi
hasil**. Dengan `hr_attendance`/`hr_payroll`/`hr_leave` = **0 baris**, logika bisnis inti sistem HR
tempat kesalahan gaji berdampak uang asli **belum pernah diuji sama sekali**.

## 🚨 KNOWN-ISSUE PRIORITAS #1

**P1-46-01 — Alur lupa-password tidak pernah mengirim email.**
RPC `request_password_reset` + edge `password-reset` membuat token lalu mengembalikan
`"Jika email terdaftar, link reset sudah dikirim."` — **tetapi tidak ada satu pun kode yang
mengirim email** (tidak ada SMTP/Resend/SendGrid; semua hit di repo hanyalah komentar yang
mengonfirmasi ketidaktersediaan). Akibatnya user yang kehilangan password **mengunci dirinya
keluar tanpa jalan keluar** selain bantuan admin. Tidak terdeteksi karena belum ada pengguna
yang benar-benar kehilangan password, dan **tidak ada test** yang memanggil alur ini (P2-60-03).
→ Fix plan: kirim token lewat kanal yang benar, atau ubah pesannya jadi jujur
("Belum ada email; hubungi admin").

## 🔓 P0 — SUDAH DIMITIGASI
- **P0-01-01** — `employees_master` bocor PII ke `anon` (17 baris × 75 kolom) + bisa write/delete
  lewat 3 trigger `INSTEAD OF`. → **migrasi 249**, `REVOKE ALL … FROM anon/PUBLIC`.
  Verifikasi: GET/POST/PATCH/DELETE anon → HTTP 401 `42501`.
- **P0-03-01** — 3 trigger `employees_master_*` SECURITY DEFINER tanpa cek authz, executable
  `authenticated`. → **migrasi 250**, `REVOKE INSERT, UPDATE, DELETE … FROM authenticated`
  (checksum `90e1cbc7cf8d5ed82…`). Grants `authenticated` kini hanya
  `REFERENCES, SELECT, TRIGGER, TRUNCATE`. 3 trigger tetap `tgenabled='O'`, data 17/17 utuh,
  worker update profil + login ulang sukses.
- ⚠️ **Registry drift** yang menyertainya: SQL 250 sempat apply di luar wrapper sehingga tidak
  terdaftar (`max(version)` masih 249) — kelas bug 221/222/223 (§0.6). Ditutup lewat
  `apply_migration()` + `verify_migration_checksum()` **tanpa mengulang SQL**;
  dry-run wrapper sesudahnya `status: SUDAH terdaftar (checksum cocok)`.
  **Residu jujur**: `applied_at` = waktu registrasi, bukan waktu eksekusi SQL.

## 🚨 PRIORITAS FIX #1 — P1-68-01 (P0 latent di installer)

**Baseline resmi membatalkan kembali kedua mitigasi P0.**
`supabase/baseline/000_baseline_schema.sql` meng-`REVOKE` di **L16458**, lalu meng-`GRANT` semuanya
kembali di **L17327-17328** (`TO anon` + `TO authenticated`) — jadi **GRANT menang** dan hasilnya
persis kondisi bocor. PT baru berikutnya akan **mewarisi P0-01-01 + P0-03-01** secara penuh.
→ Fix: (1) regenerate baseline, (2) guard di `db:verify-install` yang menolak grant berbahaya.

## 🚨 PRIORITAS FIX #2 — P1-56-01 (utang kita sendiri)

`ARCHITECTURE.md` §7.3/§7.4 belum sinkron (migrasi 173→175, file TS 207→209, tests 42→44) →
`doc-claims-vs-live.test.ts` **MERAH** dan membuat tabel coverage tak tercetak.
→ Fix: perbarui ARCHITECTURE.md, lalu jalankan ulang `npx vitest run --coverage`.

## 🚨 PRIORITAS FIX #3 — P1-58-02 (kenapa 2 P0 lolos test)

Root cause kenapa P0-01-01 & P0-03-01 lolos: `rpc-security.test.sql` hanya cek
**"tabel punya RLS aktif"**, bukan **"anon/authenticated tak bisa baca/tulis"**.
→ Fix: tambah test nyata `GET /rest/v1/<tabel>?select=*` dgn anon key + JWT authenticated,
dan cek status 401/403. Lihat juga P1-58-01 (nol test CHECK/UNIQUE constraint).

## Kemajuan
- ✅ Batch 01 (Audit 01-10) — P0: 1 (mitigated), P1: 5, P2: 2, P3: 2
- ✅ Batch 02 (Audit 11-20) — P0: 0, P1: 5, P2: 6, P3: 7
- ✅ Batch 03 (Audit 21-30) — P0: 1 (mitigated 4609c80), P1: 3, P2: 3, P3: 8
- ✅ Batch 04 (Audit 31-40) — P0: 0, P1: 6, P2: 11, P3: 7
- ✅ Batch 05 (Audit 41-50) — P0: 0, P1: 5, P2: 8, P3: 7
- ✅ Batch 06 (Audit 51-60) — P0: 0, P1: 5, P2: 10, P3: 3
- ✅ Batch 08 (Audit 71-80) — P0: 0, P1: 3, P2: 2, P3: 2
- ⏳ Batch 09 (Audit 81-88) — menunggu

## Catatan lintas-batch
- **P1-31-02 + P1-32-01 saling mengunci** (UU PDP): NRP dikirim ke PostHog, tapi
  `user_consents` 0 baris → tidak ada bukti persetujuan.
- **P2-37-01 + P1-53-01 + P1-13-01 saling mengunci**: test menulis ke DB produksi, tanpa hook
  cleanup, dan 98,7% entri `audit_log` tanpa `actor` → audit **tidak bisa membedakan** tulisan
  E2E vs manusia vs exploit.
- **P1-18-01 (tanpa CI) menjelaskan P1-56-01**: guard `doc-claims-vs-live` menangkap drift, tapi
  tidak ada yang menjalankannya → unit suite diam-diam merah.

## Konteks Repo (penting untuk reading hasil audit)
- Branch audit: `migrasi-vite` @ HEAD saat audit
- WIP E2E fix #3 diparkir di branch `wip/e2e-fix3` (`2d28de7`)
- ⚠️ P1-56-01: `ARCHITECTURE.md` §7.3/§7.4 belum sinkron dengan live — `doc-claims-vs-live.test.ts` merah

---

## Utang di Luar 13 Batch (catatan, 2026-09-27)

> **Ini CATATAN, bukan fix plan.** Sesuai §0.9 setiap temuan harus punya Item + DoD; yang di
> bawah sengaja **tidak** diberi nomor batch, prioritas, atau DoD karena itu akan mengubah
> Batch Fix #1–#13 yang sudah ditutup. Tujuannya satu: supaya tidak hilang diam-diam.
> **Tidak ada pekerjaan di halaman ini yang sudah dikerjakan.**

### KATEGORI 1 — Bisa masuk batch kecil (terbatas, mandiri, low-risk)
| Utang | Rujukan |
|---|---|
| `esm.sh` pinning — 7 edge import `esm.sh@2` tanpa lock | P2-41-01 |
| Coverage threshold tidak di-enforce | P2-57-01 |
| gitleaks tidak jalan di CI | P3-15-01 |
| `npm audit signatures` belum dijalankan | — |

### KATEGORI 2 — Butuh batch baru (cakupan >> Fix #1–#13)
| Utang | Rujukan |
|---|---|
| Mutation testing nyata | audit 78 — dibatasi protokol read-only |
| Chaos / failure injection | audit 79 — tidak dijalankan penuh |
| Frontend analysis (`src/` substantive, bukan struktur) | 88 audit fokus DB, `src/` hanya dipindai struktur |
| Multi-tenancy verification | terblokir freeze P1-68-01 (installer) |
| Runtime edge behavior (`password-reset`, `mfa`) | 0 request nyata selama ini |
| Failover drill end-to-end | di luar Fix #13 — belum pernah dijalankan |

### KATEGORI 3 — Butuh akses non-kode (bukan batas kapasitas)
| Utang | Catatan |
|---|---|
| Branch protection | pernah `TOOL NOT AVAILABLE`; ruleset aktif per 2026-09-26 |
| Rotasi credential | butuh akses Dashboard |
| DPA cross-border | butuh keputusan legal, bukan kode |
| Config drift Vercel | butuh akses project Vercel |
| React render profile | butuh profiler/runtime nyata |
| Metrik edge (cold start, p95, error rate) | tidak ada telemetry terpasang |

### KATEGORI 4 — Manual test (di luar otomasi)
| Utang | Catatan |
|---|---|
| Stored XSS end-to-end | belum ada uji manualnya |
| Concurrent login & double-submit | belum ada uji manualnya |
| Fuzz form submit | belum ada uji manualnya |
| Tab order / focus trap / zoom 200% | belum ada uji manualnya |
| Mobile 375×667 | belum ada uji manualnya |
| Safari & Firefox | belum ada uji manualnya |

**Status**: semua item di atas **OPEN** dan belum dijadwalkan. Kalau salah satu dieksekusi,
tambahkan di `agentsLogs_2026-09.md` lalu pindahkan ke sini sebagai CLOSED — jangan biarkan
kategori "catatan" diisi item yang sebenarnya sudah dikerjakan.
