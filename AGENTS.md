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
   **Prioritas + Bukti + Definition of Done**; item hanya boleh ✅ bila DoD-nya **dibuktikan
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
7. **G7 — Catat dampak di log.** Entri `agentsLogs_YYYY-MM.md` wajib memuat baris
   `Dampak lintas-page: worker → admin → dashboard → owner` berisi hasil pengecekan tiap page
   (termasuk "tidak terdampak" + alasannya).

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

## 0.12 WORK QUEUE LIFECYCLE

Setiap item Work Queue melewati state berikut:
NEW → INVESTIGATE → DECIDED → IN-PROGRESS → VERIFIED → DONE → REMOVED

| State | Arti | Siapa yang mengubah |
|---|---|---|
| NEW | Temuan baru, belum diverifikasi | Agen (saat audit) |
| INVESTIGATE | Sedang dicek ke DB/kode live | Agen |
| DECIDED | Keputusan user sudah ada | User |
| IN-PROGRESS | Sedang dikerjakan | Agen |
| VERIFIED | DoD terbukti dengan bukti mentah | Agen + User |
| DONE | Sudah masuk `agentsLogs_YYYY-MM.md` | Agen |
| REMOVED | Baris dihapus dari §5.8 | Agen setelah DONE |

**Aturan keras:**
- Item DILARANG masuk state VERIFIED tanpa bukti mentah (query result / output terminal).
- Item DILARANG dihapus dari §5.8 sebelum tercatat di `agentsLogs_YYYY-MM.md`.
- Item dengan state NEW > 7 hari → tandai "stale" dan tanyakan user.

## 0.13 PRIORITY DEFINITIONS

| Prio | Arti | SLA | Contoh |
|---|---|---|---|
| P0 | Blocker — menghentikan semua kerja | Selesaikan sebelum task berikutnya | Data corruption, security breach, deploy blocker |
| P1 | Penting — dampak user signifikan | Selesaikan dalam sesi ini | Bug fungsional, RLS salah, drift data |
| P2 | Menengah — dampak terbatas | Selesaikan dalam 1-2 sesi | Bundle size, drift registry, duplikat data |
| P3 | Nice-to-have — kosmetik/optimasi | Kapan saja | Komentar stale, header file |

**Aturan:**
- Prioritas di-set oleh User, bukan Agen.
- Agen boleh usul naik/turun prioritas, tetapi harus minta konfirmasi.
- P0 wajib direview user sebelum eksekusi.

## 0.14 SESSION PROTOCOL

### Sebelum mulai kerja (CHECKLIST):
1. `git status --short` — pastikan working tree tahu statusnya.
2. `git log --oneline -5` — pahami state terakhir.
3. Baca `AGENTS.md` §5.8 (Work Queue) + baca file derivatif sesuai Reading Map.
4. Baca entry terakhir `agentsLogs_YYYY-MM.md` untuk konteks.
5. Konfirmasi plan ke user SEBELUM eksekusi.

### Setelah selesai kerja (CHECKLIST):
1. Semua perubahan ter-commit ATAU ada di work queue sebagai OPEN.
2. Gate dijalankan (`check:types`, `lint`, `test`, `build`).
3. Hasil ditulis ke `agentsLogs_YYYY-MM.md`.
4. Work Queue di-update (item DONE → REMOVED; item baru → NEW).
5. Lapor ringkas ke user dengan hash commit.

## 0.15 STOP CONDITIONS

Agen WAJIB berhenti dan tanya user jika:
1. Tool timeout (mis. `npm test` butuh 20s tapi tool limit 30s) — jangan retry buta.
2. File di luar scope berubah (`git status` menunjukkan file yang tidak diminta).
3. Ada ambiguitas instruksi.
4. Ada duplikat data (mis. 2 baris `module_definitions` dengan `route_path` sama).
5. Fix yang diminta berpotensi breaking change (RPC, route, kontrak session).
6. Sebuah task butuh > 3 percobaan → lapor, jangan loop.
7. Database query mengembalikan hasil di luar ekspektasi.

**Format laporan STOP:**
STOP — <alasan 1 baris>
Konteks: <apa yang sedang dilakukan>
Bukti: <output mentah>
Opsi: <A/B/C, dengan risiko masing-masing>
Butuh keputusan user.

## 0.16 ANTI-HALLUCINATION RULE

**Semua klaim DONE wajib disertai output MENTAH.**

Yang dianggap bukti sah:
- Output terminal yang di-copy-paste (bukan ringkasan).
- Query result dari DB (bukan parafrase).
- Commit hash yang bisa diverifikasi via `git log`.
- Screenshot/trace file (untuk E2E).

Yang DILARANG:
- "Sudah saya jalankan" tanpa output.
- "Gate hijau 4/4" tanpa copy terminal.
- "Sudah diverifikasi" tanpa bukti query.
- Angka statistik (bundle size, test count) tanpa output mentah.

**Konsekuensi:** Klaim DONE tanpa bukti → status tetap OPEN sampai dibuktikan.

**Pelajaran nyata:**
- 2026-09-19: helper klaim "SQL-04/05/07 COMPLETED" tapi log tidak mencatat. Ternyata belum di-apply ke live.
- 2026-09-20: helper klaim "gzip max 2 kB" padahal output build menunjukkan 200 kB.
- 2026-09-20: helper klaim "SELESAI" untuk SQL-09 padahal file migrasi hanya berisi komentar.

## 0.17 DESTRUCTIVE OPERATION PROTOCOL

Operasi berikut WAJIB dry-run dulu, STOP, tunggu approval user:

| Operasi | Contoh | Gate |
|---|---|---|
| DROP | DROP TABLE, DROP FUNCTION, DROP POLICY | `--dry` dulu, STOP |
| DELETE massal | DELETE tanpa WHERE, TRUNCATE | `--dry` dulu, STOP |
| ALTER destruktif | DROP COLUMN, RENAME, ALTER TYPE | Preview diff, STOP |
| Migration --apply | npm run db:migrate -- --apply | Dry + checksum, STOP |
| Deploy production | npx vercel --prod, supabase functions deploy | Gate hijau dulu, STOP |
| Git force | push --force, reset --hard, revert | Konfirmasi eksplisit, STOP |
| Update auth.users | updateUserById, createUser massal | Dry count dulu, STOP |

**DILARANG** menjalankan dry-run dan apply dalam satu instruksi. Kalau prompt bilang "dry dulu, apply", helper WAJIB:
1. Jalankan dry.
2. Tampilkan output mentah.
3. STOP — tunggu user ketik "APPROVE".
4. Baru apply.

**Pelanggaran = revert + catat di log sebagai insiden.**

## 5.8 STATE OPEN — WORK QUEUE: Temuan Audit SQL (WAJIB DISELESAIKAN)

> **Sumber:** audit menyeluruh 2026-09-17 — 150+ migrasi diparsing lalu **setiap temuan
> diverifikasi ke DB live** (read-only; satu probe tulis di dalam transaksi yang di-`ROLLBACK`).
> Laporan + data mentah: `agentsLogs_2026-09.md` entri `[2026-09-17] Audit kesiapan instalasi`.
>
> **ATURAN WORK QUEUE (jangan dilanggar):**
> 1. Setiap temuan audit **WAJIB** jadi item bernomor di tabel ini dengan **Bukti** dan
>    **Definition of Done**. **Dilarang** menutup temuan sebagai komentar/prosa saja.
> 2. Item hanya boleh ditandai ✅ bila **DoD-nya terbukti** (perintah/query + hasil), bukan
>    karena "sudah dikerjakan".
> 3. Item ✅ hanya boleh **dihapus dari file ini setelah** hasilnya tertulis di `agentsLogs_YYYY-MM.md` (§0.4).
> 4. Dilarang menambah item "catatan" tanpa aksi; kalau tidak ada aksi, bukan item.
> 5. Item P0 wajib dikerjakan sebelum migrasi/fitur besar berikutnya.
>
> **Status di bawah diverifikasi ulang 2026-09-17** (bukan salinan catatan lama).

| ID | Prio | Masalah | Bukti (terverifikasi) | Definition of Done | Status |
|---|---|---|---|---|---|
| **P1-13-01** | P1 | 519 dari 526 baris `audit_log` punya `actor` NULL (98,7%) → jejak siapa tidak dapat ditentukan | `SELECT count(*) FILTER (WHERE actor IS NULL) FROM audit_log` = 519 dari 526; `prosrc` `_generic_audit_trigger_fixed()` tidak menulis kolom `actor` sama sekali | Actor terisi untuk setiap perubahan baru: dibuktikan uji transaksi dengan JWT claim → `actor = NRP100`, tanpa JWT → `SYSTEM`. Guard `tests/unit/db-audit-trail.test.ts` | ✔ **CLOSED** (migrasi 251, 2026-09-27) |
| **P2-13-01** | P2 | Tidak ada cron retensi `audit_log` → tabel tumbuh tanpa batas | `SELECT * FROM cron.job WHERE command ILIKE '%audit_log%'` = 0 baris; `cleanup_audit_log()` mereferensikan kolom `created_at` yang TIDAK ADA (kolomnya `timestamp`) → fungsi pasti error kalau dipanggil | Cron `cleanup-audit-log` @ `30 4 * * *` terdaftar; dry-run `{"ok":true,"deleted":0,"retention_days":365}` | ✔ **CLOSED** (migrasi 252, 2026-09-27) |
| **P2-22-01** | P2 | Tidak ada pola soft delete di tabel aplikasi → `DELETE` fisik tanpa pemulihan | `information_schema.columns WHERE column_name='deleted_at'` = 4 (semua tabel platform Supabase), 0 tabel aplikasi; `DELETE worker_passwords` 8x tercatat di `audit_log` | → → | ⚠ **DECIDED** accepted risk 2026-09-27: tidak dikerjakan di Fix #4 (menyentuh seluruh query aplikasi). Dicatat juga di `DISASTER_RECOVERY.md` §9.6 |
| **P3-F04-01** | P3 | Anomali OID tak terduga: overload `verify_audit_chain(integer, integer)` (OID 298611) hilang setelah migrasi 252 tanpa ada `DROP FUNCTION` di file mana pun; signature 3-argumen mendapat OID 330584 | `pg_proc` sebelum 252: 2 overload; sesudah: 1. Grep semua skrip `.agents/scripts/`: nol `DROP FUNCTION` yang menyasar fungsi ini. `grep verify_audit_chain src/` = **0 hit** | Aktor DDL teridentifikasi, **atau** dicatat permanen sebagai known-unexplained | ⚠ **NEW** (2026-09-27) |
| **P1-F05-01** | P1 | `admin_get_employees()` **stub** — hanya cek authz lalu `RETURN jsonb_build_object('ok',TRUE,'msg',...)`; **0 baris data**. `Employees.tsx` memakainya sebagai sumber daftar karyawan → admin tidak bisa melihat daftar | `prosrc` live panjang 225 byte tanpa `SELECT`; `src/features/core/people/Employees.tsx:68` `useRpcQuery({ fn: 'admin_get_employees' })`; pembanding `owner_get_employees()` benar (`:247` kolom Email) | RPC mengembalikan data karyawan nyata saat admin login | ⚠ **NEW** (2026-09-28) |
| **P1-F05-02** | P1 | Dua skema hash password hidup berdampingan — `reset_password()` menulis `worker_passwords` dengan `digest(sha256)+salt`, sedangkan `change_password()`/`admin_reset_worker_password()` memakai `crypt(..., gen_salt('bf'))` | `prosrc` live keduanya | satu skema saja, atau buktikan kompatibel + audit | ⚠ **NEW** (2026-09-28) |
| **P2-F05-03** | P2 | 9 dari 17 email memakai `@insightwos.internal` (TLD privat — tidak bisa menerima surat). Bila `password_reset_channel` di-switch ke `email`, 9 user terkunci | `SELECT split_part(email,'@',2), count(*) FROM employees_core GROUP BY 1` → `insightwos.internal` 9 · `insightwos.com` 8; guard `EMAIL_PROVIDER_READY` di edge (env = izin, bukan bukti — kanal `email` tidak bisa dinyalakan hanya lewat `UPDATE settings`) | semua email bisa menerima surat, atau documented accepted risk | ⚠ **NEW** (2026-09-28) |
| **P3-F05-04** | P3 | `src/pages/PasswordReset.tsx` orphan — 0 route, 0 referensi; helper-nya `callEdgeFunctionApiKey` (hanya header `apikey`, tanpa `Authorization`) yang tidak cocok dengan gate edge | `git grep 'PasswordReset'` → hanya definisi dirinya; `route-config.ts` hanya memuat `features/platform/auth/ResetPassword` | hapus ATAU daftarkan route | ⚠ **NEW** (2026-09-28) |
| **P3-F05-05** | P3 | RPC `request_password_reset` **dead code** + pesan palsu "link reset akan dikirim ke email" di migrasi `141:680/702` dan `baseline:14067/14089` | 0 pemanggil di `src/` maupun `supabase/functions/`; `proacl` hanya `postgres`+`service_role` | dihapus/dikoreksi saat regenerasi baseline (Fix #9) | ⚠ **NEW** (2026-09-28) |
| **P3-F05-06** | P3 | `login_otp`: `emailed = !linkErr` dari `auth.admin.generateLink()` — `generateLink` **membuat** link, tidak **mengirim** email, sehingga balasan "OTP sudah dikirim ke email" bisa menyesatkan | `supabase/functions/password-reset/index.ts:160-166` | pesan jujur atau provider email nyata | ⚠ **NEW** (2026-09-28) |
| **P2-F14-A** | P2 | SECURITY.md §3.1 (authz dari JWT) harus di-update saat Fix #14 — kontrak authz diperluas (level 1-5 + multi-view + posisi owner) | SECURITY.md §3.1 + ARCHITECTURE.md §7.2 Layer 3 duplikasi nama fungsi (verbatim sama, dibaca 2026-09-30); Fix #14 wajib sentuh keduanya | Update §3.1 saat Fix #14 CLOSED | ⚠ **NEW** (2026-09-30) |
| **P2-F14-B** | P2 | SECURITY.md §7.6 baris "JWT-based authz — 131-140" perlu baris baru "Role levels 1-5 — migrasi <N>" setelah Fix #14 | Tabel §7.6 baris 1 hanya mencakup 3 fungsi authz lama; level baru belum ada | Update §7.6 saat Fix #14 CLOSED | ⚠ **NEW** (2026-09-30) |
| **P3-F14-C** | P3 | Duplikasi nama fungsi authz antara SECURITY.md §3.1 dan ARCHITECTURE.md §7.2 Layer 3 — perubahan kontrak wajib di 2 tempat, risiko drift ganda | SECURITY.md §3.1 ↔ ARCHITECTURE.md §7.2 (nama fungsi verbatim sama) | Salah satu rujuk yang lain, atau guard konsistensi | ⚠ **NEW** (2026-09-30) |
| **P1-F14-D** | P1 | RPC `get_my_role(p_nrp)` percaya param tanpa cek JWT — siapa pun ber-JWT bisa query role NRP apa pun | prosrc live: `SELECT * FROM user_roles WHERE nrp=p_nrp` langsung, tanpa `authz_current_nrp()` (dibaca 2026-09-30 B2) | p_nrp NULL → `authz_current_nrp()`, atau tolak p_nrp ≠ caller | ⚠ **NEW** (2026-09-30) |
| **P2-F14-E** | P2 | RPC `admin_set_role(p_nrp, p_level, p_scope, p_plan)` STUB — 3 dari 4 param tidak dipakai | prosrc live: hanya `authz_check_admin('employee.update')` lalu return ok; tidak ada UPDATE (dibaca 2026-09-30 B2) | Perbaiki atau hapus; konsolidasi ke 1 RPC set-role | ⚠ **NEW** (2026-09-30) |
| **P2-F14-F** | P2 | `admin_set_employee_role` mapping level hardcoded 4/3/1 + whitelist role tidak memuat supervisor/admin_operasional/admin_mining\|mill\|estate | prosrc live: `CASE WHEN p_role LIKE 'admin_%' THEN 4 WHEN p_role='manager' THEN 3 ELSE 1 END`; whitelist `('admin_pusat','admin_hrd','admin_finance','admin_produksi','manager','worker')` | Mapping konsisten peta level 1-5 (§3 FIX14 file) | ⚠ **NEW** (2026-09-30) |
| **P2-F14-G** | P2 | `business_units.tier=4` untuk SEMUA 4 baris, sementara `module_definitions.minimum_tier_required` max=3 → tier gate `check_module_access` tidak pernah memblokir | Q12/Q14 @ B1: 4/4 baris tier=4; E19: tier 0→121, 2→13, 3→21 modul | Tier data realistis, ATAU dokumentasikan tier=4 sebagai "unlimited" | ⚠ **NEW** (2026-09-30) |
| **P2-F14-L** | P2 | `user_role_assignments.role_code` **tidak punya CHECK constraint maupun FK ke `admin_roles`** → INSERT langsung dengan `role_code` sembarang masih mungkin. Tabel ini jadi sumber kebenaran admin setelah §9, jadi gap di sini berarti sumber kebenaran bisa berisi role yang tidak dikenal sistem | `user_role_assignments`: PK + UNIQUE `(nrp, role_code, scope_type, scope_bu_id)` (probe B2.22), **tanpa CHECK role_code / FK**; `pg_constraint` `confrelid='user_role_assignments'` = 0 FK | CHECK `role_code IN (role_code aktif di admin_roles)` atau FK ke `admin_roles(role_code)` + guard test yang membuktikan INSERT role asing ditolak | 🟡 **PARTIAL** (2026-10-03) — FK ✅ via migrasi **261**: master table `role_codes(code)` **13 baris** (10 aktif + 3 reservasi `owner`/`director`/`admin`) + `fk_ura_role_code` + `fk_ur_role` menggantikan CHECK `user_roles_role_check`; uji negatif **23503** kedua FK; `schema_migrations` 187 / max 262. Sisa: **guard test otomatis** (§12) — FK bisa dilepas tanpa `verify:artifacts` berteriak (kelas bug sama seperti P2-F14-M) |
| **P2-F14-M** | P2 | Tidak ada guard yang mendeteksi perubahan **bahasa** / **volatilitas** fungsi. `verify:artifacts` hanya membandingkan **jumlah** fungsi, jadi `LANGUAGE sql` → `plpgsql` atau `STABLE` → `VOLATILE` **tetap hijau** | Hot spot nyata: migrasi 259 menyebut `is_admin_or_owner` `LANGUAGE plpgsql`, fact live `LANGUAGE sql` + `STABLE` (`{"bahasa":"sql","provolatile":"s"}`); `Functions` tetap 658 sebelum-sesudah, jadi tidak ada gate yang berteriak | Test baru (mis. `tests/unit/db-function-attributes-guard.test.ts`) yang baca `pg_proc.prolang` / `provolatile` / `prosecdef` / `proconfig` untuk fungsi authz kunci, bandingkan dengan ekspektasi | ⚠ **NEW** (2026-10-02) |
| **P2-F14-N** | P2 | `is_admin_or_owner()` membaca role lewat `user_roles` dengan whitelist literal 4 dari 7 admin role → `admin_operasional` / `admin_mining` / `admin_mill` / `admin_estate` ditolak, padahal keempatnya punya `role_page_access` sendiri, permission set khusus, dan `admin_roles.is_active=TRUE` | Pre-263 (probe live, simulasi 17 `employees_core`): NRP103/104/105/106 **false**; `user_roles` memuat 7 admin role tapi hanya 4 masuk whitelist. Dampak: **6 policy RLS + 3 RPC** menolak mereka. 0 test menyentuh fungsi ini | Rewire ke `user_role_assignments` pola `admin\_%` + uji positif 8 admin + owner | ✔ **CLOSED** (migrasi **263**, 2026-10-03) — `admin_operasional`/`admin_mining`/`admin_mill`/`admin_estate` **false → true**; owner TRUE lewat `authz_is_owner()`; worker tetap false; anon tetap **DENIED 42501** |
| **P2-F14-O** | P2 | Wrapper `rpcGetWorkerStatus` ([supabase-rpc.ts:87](src/lib/supabase-rpc.ts#L87)) memanggil RPC **tanpa argumen `p_nrp`**, padahal signature live `get_worker_status(p_nrp text)`. Pemanggil lain ([Worker.tsx:35](src/pages/Worker.tsx#L35)) benar | `supabase-rpc.ts:87` memanggil `get_worker_status` tanpa argumen; `pg_get_function_identity_arguments` = `p_nrp text`; 0 caller `src/` lain memakai wrapper ini | Wrapper menerima `p_nrp` lalu meneruskannya; atau hapus bila memang tidak dipakai | ⚠ **NEW** (2026-10-03) |
| **P1-POST-HARDENING-AUDIT** | P1 | **Sisi (a) grant yatim** — **46** fungsi di `public` tanpa `EXECUTE` untuk `authenticated`; policy RLS tetap tertulis di `pg_policies` jadi `verify:artifacts` menghitungnya sebagai policy yang ADA, tapi tidak bisa dievaluasi (kasus terbukti `is_admin_or_owner` → 6 policy **42501 untuk SEMUA user**, termasuk `admin_pusat` & CEO; 263 menutup **1 dari 46**). Sisi (b) **dipisah** ke `P1-TABLE-AUDIT`. **Scope tambahan (keputusan user A3, 2026-10-03)**: **guard CI otomatis** — kelas bug "mati senyap" berulang berbulan-bulan tanpa gate, jadi butuh alat yang berteriak | `has_function_privilege('authenticated', oid, 'EXECUTE')` = false untuk 46 fungsi (log `.agents/logs/fix14-c3d-gate-grants.log`) | **Tahap 1** guard CI (2-3 jam, dahulukan): bandingkan `proacl` tiap fungsi vs daftar policy RLS pemanggilnya; harus **MERAH** pada 46 fungsi yatim sekarang (guard yang diam = guard palsu). **Tahap 2** checklist audit 46 fungsi. **Tahap 3** perbaikan per fungsi sampai hijau. Guard masuk `scripts/verify-*` lalu jadi bagian `npm run verify:artifacts` atau gate setara | ⚠ **NEW** (2026-10-03; scope ditambah A3 guard CI) |
| **P1-TABLE-AUDIT** | P1 | **61 dari 208** tabel RLS **tanpa policy SELECT** → default-deny, jadi `SELECT` mengembalikan **0 baris untuk siapa pun**, termasuk `admin_pusat` dan owner. Termasuk `business_units` + `settings`, yang policy `bu_select`/`st_select` dari `083` (`USING (TRUE)`) **tidak ada lagi di live**. **Dipisah dari `P1-POST-HARDENING-AUDIT` (keputusan user B1, 2026-10-03)** — bukan karena bukti berbeda, tapi karena **tidak bisa diselesaikan dengan asumsi teknis**: perlu keputusan produk per tabel. **Bukan efek samping 264** — `264_fix14_drop_dead_check_admin_access.sql` hanya menyentuh fungsi, tidak ada `DROP POLICY` di file itu | `pg_policies` `business_units` = 1 policy (`bu_update` UPDATE saja), `settings` = 1 (`st_update` UPDATE saja); sumber policy SELECT hilang di `083_rls_hardening.sql:52` + `:123`; total **61/208** (log `.agents/logs/fix14-c9c-why-select2.log`) | **Tabel keputusan 61 baris** (`nama tabel` · `siapa butuh akses` · `pernah dipakai UI di mana`) lalu keputusan per tabel: **buka** (pulihkan policy SELECT) atau **tutup** (buktikan dengan policy SELECT `USING (false)` **eksplisit**, bukan policy hilang). **BUKAN sprint perbaikan teknis** — helper berikutnya **dilarang** membuka policy SELECT tanpa baris keputusan di tabel ini. Bukan blocker §9; boleh paralel dengan batch 265-267 | ⚠ **NEW** (2026-10-03; butuh keputusan produk bertahap) |
| **P2-F14-R** | P2 | Bug a11y **latent**: `<label>Email</label>` di [OwnerLogin.tsx:62](src/pages/OwnerLogin.tsx#L62) tanpa `htmlFor`, `input[type=email]` di baris 63 tanpa `id` → axe violation `label` **critical**. Tidak terlihat berbulan-bulan karena route `/owner/*` butuh sesi valid, jadi test a11y hanya mendarat di halaman ini saat `storageState` owner **kedaluwarsa** | Terbukti saat a11y 4/6 pada 2026-10-03: `[critical] label (1 node): input[type="email"]`, html tanpa `htmlFor`/`id` (log `.agents/logs/fix14-d4-a11y.log`). Setelah storageState di-regen → suite **6/6 PASS, 0 violation**, jadi bug ini **tidak pernah dieksekusi** pada alur normal | Tambahkan `htmlFor` + `id` yang cocok (atau `aria-label`) pada input email, verifikasi suite a11y tetap 6/6. Cek juga `<label>` Password baris 66 — pola sama kemungkinan berulang | ⚠ **NEW** (2026-10-03) |
| **P2-F14-P** | P2 | `employee.view_all` hanya dimiliki 2 role (`admin_hrd` lewat `hrd_ops`, `admin_pusat` lewat `admin_pusat_all`) → `authz_check_admin('employee.view_all')` = **false** untuk `admin_operasional` (21 perm), `admin_mining` (21), `admin_mill` (21), `admin_estate` (21), dan `admin_finance` (28) | `permission_set_items` join `role_permission_sets`: hanya `hrd_ops`→`admin_hrd` + `admin_pusat_all`→`admin_pusat` punya `employee.view_all`. Probe live: NRP001/100/101 **true**, NRP102/103/104/105/106 **false** | Keputusan produk: apakah 4 admin industri memang tidak boleh melihat semua karyawan? Kalau tidak, tambahkan permission ke `role_permission_sets` masing-masing | ⚠ **NEW** (2026-10-03) — **butuh keputusan user** |
| **P2-F14-S** | P2 | `get_user_context_by_auth_id()` — fungsi "get" tapi **menulis**: ada `UPDATE employees_master SET auth_id = p_auth_id` di dalam body (SECURITY DEFINER, dipanggil lewat JWT apa pun) → privilege escalation surface | `prosrc` live `get_user_context_by_auth_id` baris `UPDATE employees_master SET auth_id = p_auth_id WHERE nrp = v_emp.nrp;` (fallback email→auth_id), dibaca 2026-10-03 | Pindahkan UPDATE ke fungsi terpisah dengan gate eksplisit, atau hapus dengan keputusan user. Batch 266 tidak boleh apply sebelum ini diputuskan | ✔ **CLOSED** (migrasi 266, 2026-10-04) — keputusan user **S1**: blok `UPDATE` DIHAPUS; C2 sintetis membuktikan auto-repair mati (`repaired=false`) dengan output baca tetap utuh |
| **P2-F14-T** | P2 | `get_user_context_by_auth_id()` **tanpa owner bypass** — owner (shadow, 0 baris `employees_core`) dapat `{"ok":false,"msg":"Akun tidak ditemukan..."}`. `Home.tsx:328` memakai fungsi ini → owner tidak bisa login lewat tab admin | Probe impersonasi owner `a8a77284-...`: `by_auth_id` → `{"ok":false,"msg":"Akun tidak ditemukan. Email: owner@insightwos.com"}`; `get_current_user_context()` → `is_owner:true` | Keputusan produk: tambahkan `check_owner_identity()` (konsisten dengan `get_current_user_context`) ATAU dokumentasikan sebagai by-design. Batch 266 | ✔ **CLOSED** (keputusan **T2**, 2026-10-04) — **by-design**: owner lewat `OwnerLogin`; `by_auth_id` tetap `{"ok":false}` untuk owner, diverifikasi netralitas 8/8 pasca-266 (Home.tsx tidak diubah) |
| **P3-F14-U** | P3 | Field mati `divisi`/`posisi` di [src/lib/supabase-browser.ts:229](src/lib/supabase-browser.ts#L229) — `initSession` membaca `data.divisi`/`data.posisi`, tapi `get_current_user_context()` **tidak pernah** mengembalikan kedua field itu (`by_auth_id` yang mengembalikan) | `get_current_user_context()` return keys: `nrp,nama,role,role_level,is_owner,business_unit_id,email` — tanpa `divisi`/`posisi`; `by_auth_id` memuat `divisi`, `jabatan` (bukan `posisi`) | Hapus referensi `divisi`/`posisi` di `initSession` + 4 field interface (`UserSession`/`CurrentUserContext`) — keputusan **U1a** | ✔ **CLOSED** (migrasi 266 + U1a, 2026-10-04) — 2 baris `initSession` + 4 field interface dihapus; 0 konsumen; `check:types` EXIT 0 |
| **P2-F14-V** | P2 | `employees_master`/`employees_core` **tidak punya trigger audit** — perubahan `auth_id` (pre-266 masih mungkin lewat auto-repair `by_auth_id`) dan semua kolom lain tidak meninggalkan jejak di `audit_log` | Probe trigger live 2026-10-04: `employees_master` hanya punya `trg_employees_master_{insert,update,delete}` (sync → core/extended, `prosrc` tanpa `audit_log`), `employees_core` 0 trigger, **0** `trg_audit_*` di keduanya (21 tabel lain punya) | Pasang `trg_audit` via `_generic_audit_trigger_fixed` (pola Fix #4) + uji INSERT/UPDATE → baris `audit_log` bertambah dengan `actor` terisi | ⚠ **NEW** (2026-10-04) |


> **CLOSED 2026-10-02 — P1-F14-K, P2-F14-H, P2-F14-I** (Fix #14 §9 blocker, migrasi 257/258/259/260 DITERAPKAN; registry 185 baris, `max(version)=260`; bukti di `agentsLogs_2026-10.md` entri 2026-10-02 + `docs/forensic/FORENSIC-INDEX.md`). Ringkasan: **K** trigger audit `user_role_assignments` terpasang via `_generic_audit_trigger_fixed`, uji INSERT → `audit_log` 582→583 dengan `actor` terisi; **H** `authz_in_scope` cabang `TEAM` `manager_nrp` → `atasan_nrp`, smoke tidak crash; **I** `admin_produksi` dicabut dari CHECK `user_roles_role_check` (uji negatif `23514`) + whitelist `is_admin_or_owner` + 3 `role_permission_sets` (items tetap 93) → **0 di kelima tempat**. Sisa satu-satunya: whitelist `admin_set_employee_role` = item **P2-F14-F** (masih OPEN). **P2-F14-J** (rename NRP001 → `'ceo'`) masih OPEN, target §10.
>
> **Pelajaran proses P7 (2026-10-02)** — pre-image `timestamptz` untuk file rollback **wajib** diambil dari sisi server (`created_at::text` / `to_char(..., 'USOF')`), **bukan** dari output driver `pg` yang truncate ke 3 digit desimal padahal kolomnya `datetime_precision = 6`. Terbukti di rollback 260: tulis `.036` vs aslinya `.036520` → hash tabel tidak byte-identik. Selalu simulasikan apply+rollback sebelum apply sungguhan.
> **Pelajaran proses P8 (2026-10-02)** — `verify:artifacts` **buta** terhadap perubahan `LANGUAGE`/`provolatile` fungsi karena hanya menghitung **jumlah** fungsi (658). Item: **P2-F14-M**.
>
> **CLOSED 2026-10-03 — L2 (master table `role_codes`) + J3 (assignment transisi NRP001)**, migrasi `261`/`262` DITERAPKAN; registry **187** baris, `max(version)=262`. **L2**: `role_codes(code)` 13 baris = 10 aktif (union 5 sumber) + 3 reservasi (`owner`/`director`/`admin` dari CHECK lama tanpa data); FK `fk_ura_role_code` + `fk_ur_role` **menggantikan** `user_roles_role_check`; uji negatif **23503** kedua FK; `role_codes` harus tabel mandiri (bukan FK ke `admin_roles`) karena `manager`/`supervisor` hanya hidup di `role_permission_sets`. **J3**: NRP001 (CEO) dapat assignment `admin_pusat`/`ENTERPRISE`/`BU04`/`is_primary=false`; `authz_check_admin('employee.update')` **false→true**, `authz_has_permission('audit.view')` **false→true** — rantai authz itu **sudah live** dan membaca assignments, jadi J3 memperbaiki kondisi yang sedang rusak, bukan hanya mitigasi masa depan.
> ⚠ **`262_rollback.sql` TIDAK memfilter `is_primary`** (sengaja). Kalau di §10 assignment NRP001 jadi permanen dengan `is_primary=TRUE`, **predicate rollback harus diubah lebih dulu** atau assignment permanen ikut terhapus. Peringatan tertanam di file rollback.
>
> **Pelajaran proses P9 (2026-10-03)** — pengukuran **di dalam** transaksi yang belum di-`ROLLBACK` selalu terlihat "menyimpang" untuk tabel yang punya trigger audit (`audit_log` 582→583→584). Itu artefak, bukan drift: ukur ulang **setelah** `ROLLBACK`, di koneksi baru (probe T0/T1/T2/T3 → kembali 582). `audit_log` punya `trg_audit_hash_chain` sendiri, jadi tidak rekursif.

> **CLOSED 2026-10-03 — batch 263 (P2-F14-N)**, migrasi `263_fix14_is_admin_or_owner_rewire.sql` DITERAPKAN + terdaftar + checksum terverifikasi; registry **188** baris, `max(version)=263`. Dua hal diperbaiki dalam satu migrasi (keputusan user **Opsi 1**): (1) **P2-F14-N** — whitelist literal 4 role di `user_roles` diganti `EXISTS` atas `user_role_assignments` pola `admin\_%`, plus cabang `authz_is_owner()` untuk owner bypass; (2) **temuan baru blocking** — `GRANT EXECUTE` ke `authenticated` dipulihkan, tanpa itu 6 policy RLS tetap 42501. `admin_operasional`/`admin_mining`/`admin_mill`/`admin_estate` **false → true**; owner **tidak berubah** (TRUE); worker **tidak berubah** (fail-closed). Uji: C1 **9/9** positif, C2 **4/4** negatif (termasuk anon **DENIED 42501**), C3 **6 policy** × 4 NRP tanpa 42501, C4 worker 0 baris + UPDATE baris nyata ditolak RLS, rollback **byte-identik** (`md5(pg_get_functiondef)` `6c0fb3d3…` → `18a97b91…` → `6c0fb3d3…`). Item terkait: **P1-POST-HARDENING-AUDIT** (46 fungsi lain tanpa grant), **P2-F14-P** (`employee.view_all`), **P1-TABLE-AUDIT** (61 tabel RLS tanpa policy SELECT; dulu ber-ID `P2-F14-Q`), **P2-F14-O** (wrapper `rpcGetWorkerStatus`).
>
> ⚠️ **Klasifikasi §9b dikoreksi.** `get_worker_leave` / `get_worker_overtime` / `submit_voice` **TIDAK** memakai `is_admin_or_owner()` — rantainya `_is_admin_or_owner_caller()` → `authz_check_admin('employee.view_all')`. Jadi 263 **tidak** membuka 3 RPC itu; NRP105 tetap `"Akses ditolak."` dan itu benar menurut permission (item **P2-F14-P**).
>
> **CLOSED 2026-10-03 — batch 265**, migrasi `265_fix14_get_current_user_context_hybrid.sql` DITERAPKAN + terdaftar + checksum terverifikasi; registry **190** baris, `max(version)=265`, `Functions` **tetap 656** (CREATE OR REPLACE, bukan fungsi baru). Perubahan **3 hunk** (dibuktikan inverse proof: body baru dengan 3 hunk dibalik === pre-image persis): (1) `v_assign_role TEXT` di DECLARE; (2) `SELECT a.role_code INTO v_assign_role FROM user_role_assignments a WHERE a.nrp = v_emp.nrp ORDER BY a.is_primary DESC NULLS LAST, a.role_code ASC LIMIT 1;`; (3) `'role'` → `COALESCE(v_assign_role, v_role.role, 'worker')`. `role_level` TETAP dari `user_roles` (assignment tidak punya kolom level); owner bypass `check_owner_identity()` dipertahankan. Bukti: netralitas **8/8 byte-identik** (NRP001/002/100/101/102/105 + owner + uuid nol vs baseline pre-265) karena 17/17 `role_code` assignment identik dengan `user_roles.role` + 0 user multi-assignment; owner bypass **PASS** (`is_owner:true, role:owner, level:5`); NRP001 `role:admin_pusat` (assignment 262 `is_primary=false`), NRP002 `role:worker`; **oid 298319 preserved**; attrs (plpgsql/VOLATILE/SECDEF/search_path) + ACL (`{postgres,authenticated,service_role}`, anon **tidak**) preserved; rollback byte-identik + ACL restore teruji (D4a-D4g PASS); read-path proof E5: ubah assignment NRP002 → `role` ikut berubah sementara `role_level` tetap 1. 3 item Work Queue baru: **P2-F14-S** (UPDATE `auth_id` di fungsi "get"), **P2-F14-T** (by_auth_id tanpa owner bypass), **P3-F14-U** (field mati `divisi`/`posisi`). Batch 266 (`by_auth_id`) menunggu keputusan B-1/B-2/B-3 — **selesai 2026-10-04 (S1/T2/U1), lihat blok CLOSED batch 266 di bawah**.

> **Pelajaran proses P10 (2026-10-03)** — **whitelist grant yang melewatkan fungsi kritis.** `172_hardening_grants.sql` bermaksud "end-state deterministik: revoke semua, grant minimal", tapi daftar putih dipilih manual dan fungsi yang tidak masuk daftar **mati senyap** selama berbulan-bulan. Policy RLS tetap tertulis di `pg_policies`, jadi `verify:artifacts` menghitungnya sebagai policy yang ADA — yang mati adalah *permission untuk mengevaluasinya*, dan tidak ada guard yang menangkapnya. Aturan turunan: **setiap policy RLS yang memanggil helper `SECURITY DEFINER` WAJIB punya `EXECUTE` untuk role yang di-shadow**; menambah policy tanpa grant = policy mati. Item turunan: **P1-POST-HARDENING-AUDIT** (sisi a = grant yatim + guard CI tahap 1; sisi b dipisah jadi **P1-TABLE-AUDIT**).
>
> **Pelajaran proses P11 (2026-10-03)** — **grep substring menyesatkan untuk memetakan caller.** `prosrc ILIKE '%is_admin_or_owner%'` mengembalikan 5 pemanggil dan **salah 3**: `_is_admin_or_owner`/`_is_admin_or_owner_caller` hanya mengandung string itu sebagai *substring nama*, lalu `get_worker_leave`/`get_worker_overtime`/`submit_voice` memanggil *helper* itu, bukan `is_admin_or_owner`. Verifikasi caller harus baca `pg_get_functiondef` per fungsi, bukan mengandalkan substring.
> **CLOSED 2026-10-03 — batch 264**, migrasi `264_fix14_drop_dead_check_admin_access.sql` DITERAPKAN + terdaftar + checksum terverifikasi; registry **189** baris, `max(version)=264`, `Functions` **658 → 656** (overload 20 → 19). Keputusan user: **DROP kedua overload, bukan rewrite** — konfirmasi 0 caller di **7 sumber** (`src/` 0 hit · `pg_proc.prosrc` 0 · `pg_policies` 0 · `pg_trigger`→`tgfoid` 0 · `pg_views`+`pg_matviews` 0 · `pg_attrdef` 0 · `pg_constraint` 0), `pg_depend` internal=0 jadi tanpa CASCADE. Root cause kenapa rewrite tidak sepadan: overload 0-arg membaca claim JWT `role` yang **tidak pernah diisi Supabase** (jadi struktural selalu FALSE), sedangkan overload text-arg mengambil role dari `user_roles … ORDER BY role_level` — sumber yang **salah** untuk §9, sehingga butuh rewrite total, bukan pemulihan sebagian. Bukti apply: overload tersisa **0**, `check_admin_access()` dan `check_admin_access('/admin')` → **42883** `function does not exist`, policy tetap 225, tabel 209, `check_owner_identity()` tetap ada (bukan target 264), 5 helper `authz_*` md5 tidak berubah. Rollback **byte-identik termasuk ACL** (simulasi 19 PASS / 0 FAIL): `md5 functiondef` `0106fcb4…`→`0106fcb4…` dan `5aeaa26c…`→`5aeaa26c…`, prosrc 210/2093, privilege post-rollback `anon=false auth=false svc=true`. Work Queue: `P1-ACL-AUDIT` + `P2-F14-Q` **di-merge** jadi **P1-POST-HARDENING-AUDIT** (satu akar, dua sisi) — lalu **dipecah lagi** 2026-10-03 (keputusan user A3 + B1): sisi grant yatim + guard CI tetap di `P1-POST-HARDENING-AUDIT`, sisi policy SELECT jadi item baru **P1-TABLE-AUDIT** karena butuh keputusan produk per tabel, bukan asumsi teknis. Dan **P2-F14-R** baru (bug label `OwnerLogin.tsx:62`, latent).
>
> **Pelajaran proses P12 (2026-10-03)** — **rollback `DROP FUNCTION` WAJIB sertakan restore ACL.** Default privilege fungsi baru di PostgreSQL adalah EXECUTE untuk owner **dan PUBLIC**. ACL pre-264 sengaja **tidak** mengandung PUBLIC (migrasi 172 revoke-all lalu grant hanya service_role). Kalau rollback hanya `CREATE OR REPLACE`, hasilnya `proacl = {postgres=X/postgres, =X/postgres}` — setiap role bisa memanggil fungsi `SECURITY DEFINER` itu dan `role_page_access`/`admin_roles` ikut terekspos. Itu mengembalikan **security hole**, bukan pre-image. Aturan: untuk rollback berbasis `CREATE OR REPLACE`, **ACL adalah bagian dari definisi "byte-identik"**. `pg_get_functiondef` **tidak** memuat ACL sama sekali, jadi gate wajib menambah `proacl` + `has_function_privilege` per role — membandingkan functiondef saja tidak cukup.
>
> **Pelajaran proses P13 (2026-10-03)** — **OID berubah setelah DROP + CREATE; itu normal.** Simulasi 264: oid `298204`→`336335` dan `298205`→`336336`, meski transaksi di-`ROLLBACK`. **OID counter PostgreSQL tidak pernah di-rollback.** Konsekuensi untuk semua gate byte-identik: kunci perbandingan ke **signature** (`pg_get_function_identity_arguments`), **jangan** ke `oid` — kalau tidak, simulasi kedua akan melahukan gate yang sebenarnya hijau. Kelas bug yang sama seperti **P3-F04-01**.

> **CLOSED 2026-10-04 — batch 266**, migrasi `266_fix14_by_auth_id_rewire_and_cleanup.sql` DITERAPKAN + terdaftar + checksum terverifikasi; registry **191** baris, `max(version)=266`, `Functions` **tetap 656** (CREATE OR REPLACE, bukan fungsi baru). Perubahan **4 hunk** (inverse proof: body baru dengan 4 hunk dibalik === pre-image persis; def 1666 → 1922, prosrc 1470 → 1726): (1) `v_assign_role TEXT` di DECLARE; (2) **hapus** blok `IF FOUND THEN UPDATE employees_master SET auth_id = p_auth_id ... END IF;` — S1/P2-F14-S, satu-satunya jalur tulis di fungsi "get" → **read-only murni**; (3) `SELECT a.role_code INTO v_assign_role FROM user_role_assignments a WHERE a.nrp = v_emp.nrp ORDER BY a.is_primary DESC NULLS LAST, a.role_code ASC LIMIT 1;`; (4) `'role'` → `COALESCE(v_assign_role, v_role.role, 'worker')`. Fallback baca via email TETAP (SELECT tanpa efek tulis). **T2 by-design**: owner tetap `{"ok":false}` di `by_auth_id` (owner lewat `OwnerLogin`; `Home.tsx` tidak diubah). Bukti: netralitas **8/8 byte-identik** (NRP001/002/100/101/102/105 + owner + uuid nol vs baseline pre-266); **oid 298467 preserved**; attrs (plpgsql/VOLATILE/SECDEF/search_path) + ACL (`{postgres,authenticated,service_role}`, anon **tidak**) preserved; C2 sintetis: NRP002 `auth_id=NULL` dalam tx → `repaired=false` (tidak me-repair) dengan output baca tetap byte-identik baseline; C1c: **0 baris** email-match `auth.users` dengan `auth_id` beda → jalur UPDATE tidak terjangkau pada data sekarang; rollback byte-identik + ACL. U1a (kode): `divisi`/`posisi` dihapus dari `initSession` + 4 field interface (`UserSession` + `CurrentUserContext`) — 0 konsumen, `check:types` EXIT 0. Item Work Queue baru: **P2-F14-V** (audit coverage `employees_master`/`employees_core` — tanpa `trg_audit_*`).

> **Pelajaran proses P14 (2026-10-04)** — **mengganti angka dokumen tidak sah divalidasi oleh exit-code skrip pengganti.** Skrip sync yang berhenti `exit 0` tidak membuktikan dokumen sinkron dengan live; gate `npm run verify:artifacts` (+ `doc-claims-vs-live`) wajib dijalankan ulang **setelah sync dan sebelum commit**, bukan sesudahnya dan bukan diasumsikan dari exit code. Hijau hanya sah kalau gate-nya yang menghijaukan.
>
> **CLOSED 2026-10-05 — batch 267**, migrasi `267_fix14_otp_rewire_wildcard.sql` DITERAPKAN + terdaftar + checksum terverifikasi; registry **192** baris, `max(version)=267`, `Functions` **tetap 656** (CREATE OR REPLACE, bukan fungsi baru). Perubahan **5 hunk** (inverse proof: body baru dengan 5 hunk dibalik === pre-image persis; def verify 2438 → 2893 / generate 2320 → 2817, prosrc verify 2251 → 2706 / generate 2147 → 2644): (1) `v_assign_role TEXT` di DECLARE `verify_admin_otp_core`; (2) `SELECT a.role_code INTO v_assign_role FROM user_role_assignments a WHERE a.nrp = v_nrp ORDER BY a.is_primary DESC NULLS LAST, a.role_code ASC LIMIT 1;`; (3) gate `verify_admin_otp_core`: `v_role.role` → `COALESCE(v_assign_role, v_role.role)` + whitelist `admin\_%` **escaped** (kanon 263:81); (4) RETURN: `'role'` → `COALESCE(v_assign_role, v_role.role, 'admin_pusat')` (fallback dipertahankan); (5) gate `generate_admin_otp`: `SELECT CASE WHEN EXISTS(assignment utk v_nrp) THEN EXISTS(assignment role_code LIKE 'admin\_%') ELSE EXISTS(user_roles owner|admin\_%) END` — **E2**: assignment menang, fallback `user_roles` menahan instalasi baru tanpa assignment. Bukti: netralitas OTP **5/5 byte-identik** vs baseline pre-267 (NRP001/100/105 + owner PASS, NRP002 REJECT); **oid 298610/298267 preserved**; attrs (plpgsql/VOLATILE/SECDEF/search_path) + ACL (`{postgres,authenticated,service_role}`, anon **tidak**) preserved; **wildcard fix T5**: role generik `'admin'` tanpa assignment pra-267 **LOLOS** kedua fungsi → pasca-267 **REJECT** keduanya; T6 assignment `admin_pusat` terbaca (pra DITOLAK), T7 `user_roles` basi tidak menyelamatkan (pra LOLOS); P9 nol residu (`audit_log` 587, `otp_store` 0, `otp_attempts` 0, `session_tokens` 357); rollback byte-identik. Wrapper publik `verify_admin_otp` + grant anon pra-sesi (dari 231) TIDAK disentuh.
>
> **Pelajaran proses P15 (2026-10-05)** — **wildcard `_` di `LIKE` yang lolos review.** `LIKE 'admin_%'` "terlihat sama" dengan `LIKE 'admin\_%'` tapi artinya beda satu karakter: `_` = wildcard 1 karakter vs literal underscore — role generik `'admin'` karena itu LOLOS gate OTP sejak lama. Aturan turunan: setiap whitelist pola role di `LIKE` wajib escaped + punya uji negatif sintetis (role generik tanpa assignment → REJECT).

> **Dipangkas 2026-09-20** — item ✅ yang hasilnya sudah tertulis di `agentsLogs_2026-09.md` dikeluarkan dari tabel
> ini sesuai aturan #3 di atas: **SQL-01, SQL-03, SQL-04, SQL-05, SQL-07** + **SQL-06** (keputusan 2026-09-20: TIDAK FORCE RLS — SQL Editor masih dipakai debugging/maintenance) + **SQL-08** (dieksekusi migrasi 240: drop tabel mati + cron + fungsi terkait) + **SQL-09, SQL-10, OPS-01, OPS-02** (dipangkas 2026-09-20). Jangan diinvestigasi ulang.
> **Dipangkas 2026-09-21** — **SQL-11**: DONE (verifikasi 3 ronde + migrasi 241 + restamp 35 berkas + pulihkan file 240 + baseline/verify-install PASS 9/9; bukti di `agentsLogs_2026-09.md` entri 2026-09-21). Jangan diinvestigasi ulang.
> **Dipangkas 2026-09-21** — **SQL-12**: DONE (keputusan user Opsi D: migrasi 244 — semantik NULL=jangan ubah, ''=kosongkan; signature TIDAK berubah; 13 konversi `‖ null` dihapus dari `WorkerProfile.tsx`; verifikasi impersonasi 4 langkah via `get_worker_profile`; restamp `b421600b…`; **catatan: smoke browser gagal karena temuan baru OPS-04 — provisioning sesi, bukan bagian DoD SQL-12**; bukti di `agentsLogs_2026-09.md` entri 2026-09-21). Jangan diinvestigasi ulang.
> **Dipangkas 2026-09-21** — **OPS-05**: DONE (grant anon `check_login_lockout` via migrasi 245; RPC 200, lockout aktif; OPS-07 tetap OPEN sebagai follow-up rate-limit `login_attempts`; bukti di `agentsLogs_2026-09.md` entri 2026-09-21). Jangan diinvestigasi ulang.
> **Dipangkas 2026-09-21** — **SQL-02**: DONE (keputusan user Opsi A: DROP 13 fungsi legacy tanpa sumber via migrasi 243; bukti 0 pemakai `src/`, 0 caller internal, 0 view, grant sudah dicabut 210/073; sisa 2 fungsi legacy bersumber 073/205 dipertahankan; baseline regen fungsi 552→539; verify-install PASS 9/9 cap 168; bukti di `agentsLogs_2026-09.md` entri 2026-09-21). Jangan diinvestigasi ulang.
> **Dipangkas 2026-09-21** — **SQL-13**: DONE (keputusan user Opsi B: `dashboard_landing` dinonaktifkan via migrasi 242; 0 ref kode, tidak di pathMap menu-builder; `ceo_dashboard` tetap aktif melayani /dashboard; verify-install PASS 9/9; bukti di `agentsLogs_2026-09.md` entri 2026-09-21). Jangan diinvestigasi ulang.
> **Dipangkas 2026-09-21** — **OPS-03**: DONE (OPS-03c: lazy() shell App.tsx + boundary Suspense; OPS-03b: manualChunks vendor-supabase/posthog/dompurify + posthog deferred idle-init. Main `index-*.js` = 27,6 kB gzip; initial load 4 file = **144,5 kB gzip < 150 kB** — DoD terpenuhi; gate tsc/lint/build/test 141/141 hijau; bukti di `agentsLogs_2026-09.md` entri 2026-09-21). Jangan diinvestigasi ulang.
> **Dipangkas 2026-09-21** — **OPS-04**: DONE (B1a′ edge self-repair + B2c′ timeout 20s + loading state + B1d′ repair-worker-auth.mjs; smoke OPS-01 PASS 2/2; SINKRON 9/9 DIVERGEN 0; edge ter-deploy; gate 0/0/0/0 141/141; commit e8155ef + fa363ea; bukti di `agentsLogs_2026-09.md` entri 2026-09-21). Jangan diinvestigasi ulang.
> **Dipangkas 2026-09-23** — **OPS-09**: a11y sweep 154 halaman SELESAI — 0 violation (color-contrast/select-name/label/scrollable semua tuntas). Fix 2 gelombang: color-contrast commit e3ca82d (24 lokasi/19 file) + select-name 8/label 2/scrollable 1/color-contrast 1 commit 3b1e7e6 (8 file). Sweep FINAL 2026-09-23: 153/154 PASS, 0 violation a11y (0 critical, 0 serious); sisa 1 = timeout `/admin/mill` (non-a11y) → OPS-10. Bukti: `.agents/logs/a11y-sweep-final.json` + `sweep-final-parsed.json` (agentsLogs entri 2026-09-23). Jangan diinvestigasi ulang.
> **Dipangkas 2026-09-23** — **OPS-08**: rotate NRP admin test SELESAI via storageState reuse (0 OTP/run) — suite 6-halaman `tests/a11y/accessibility.spec.ts` kini memakai `auth-{worker,admin,owner}.json` per describe (pola sweep 154); commit 4804f5d. Bukti: 3 run berturut `npm run test:a11y` = 6/6 PASS tanpa OTP block. Rate limiter tidak disentuh, tidak ada provisioning password. Jangan diinvestigasi ulang.
> **Dipangkas 2026-09-23** — **OPS-10**: /admin/mill timeout SELESAI via storageState admin_mill (NRP105, `auth-admin-mill.json`) + settle timeout 15s. Root cause 3-layer: role mismatch (admin_hrd di-redirect oleh useAdminAuth) + flash-redirect + churn get_branding/token-refresh. Bukti: sweep mill-only 8/8 PASS (`admin /admin/mill` 9.6s, 0 violation, tanpa timeout); RPC get_industry_admin_stats 128–183ms (bukan query lambat). Sisa akar di-register sebagai OPS-11/OPS-12. Jangan diinvestigasi ulang.
> **Dipangkas 2026-09-24** — **OPS-11**: dedupe `get_branding` SELESAI di layer RPC (Opsi B, keputusan user — caller tidak di-refactor, jadi PR terpisah): cache 5 menit + dedupe in-flight di `supabase-browser.ts` + `invalidateBrandingCache()` dipanggil `LogoUploader` setelah `update_branding` sukses; error TIDAK di-cache. Bukti probe CDP fetch-instrumented (`.agents/logs/ops11-branding-probe.json`): call logis per mount **2 → 1** di /worker, /admin, /dashboard; `/` **4 → 1**; /owner/dashboard 0 (LogoUploader hanya di tab branding). Regresi: tsc/lint 0, unit 141/141, a11y 6/6 (setelah regen storageState owner yang kedaluwarsa — bukan regresi fix, terbukti A/B sama di HEAD), sweep mill 8/8; commit 624ddf7. Bukti di `agentsLogs_2026-09.md` entri 2026-09-24. Jangan diinvestigasi ulang.
> **Dipangkas 2026-09-24** — **OPS-12**: fix `useAdminAuth` flash-redirect SELESAI via `roleSettled` + fail-safe **8s** (bukan 3 — token refresh bisa 5,6 dtk saat jaringan lambat): redirect dicekar sampai role termuat ATAU 8 dtk; kontrak return `{ role, isAllowed }` tidak berubah → 50 caller aman. Bukti: gate tsc/lint 0 error + unit 141/141 + a11y 6/6 + sweep mill 8/8 + 4-page smoke 4/4; probe deterministik admin_finance NRP102 deep-link `/admin/payroll` (delay penulisan sesi 3 dtk, 0 OTP): kode lama **BOUNCE** (URL akhir `/`, h1 Payroll TIDAK muncul) → kode baru **TIDAK BOUNCE** (URL tetap `/admin/payroll`, h1 Payroll MUNCUL); commit 5db8a85. Bukti di `agentsLogs_2026-09.md` entri 2026-09-24. Jangan diinvestigasi ulang.
> **Dipangkas 2026-09-24** — **OPS-06**: auth.users sync via edge `change_password_sync` — action baru di edge `password-reset` (RPC `change_password` tetap source of truth → `updateUserById` service role menyinkronkan `auth.users`; rate limit 5/15 mnt per NRP; balas `auth_synced`). Sekaligus fix bug `reset_required`: RPC `change_password` TIDAK di-grant anon → alur sebelumnya gagal diam-diam → `Home.tsx` kini submit lewat edge + banner "Copy" password baru (dicatat ke `akun.txt` via `supabase/scripts/record-password.mjs --from-env`, verifikasi masked). Bukti: round-trip manual NRP002 PASS (signIn password baru `OK 200`, lama `GAGAL`, cleanup kembali `OK 200`, kedua sisi sinkron). Gate: tsc/lint/build EXIT 0, unit 141/141, a11y 6/6; **sweep mill TIDAK hijau** (flake timeout 20 s, scan 0 violation) → **OPS-13**. Bukti di `agentsLogs_2026-09.md` entri 2026-09-24. Jangan diinvestigasi ulang.
> **Dipangkas 2026-09-24** — **OPS-06b**: jalur admin reset password kini sinkron penuh ke `auth.users`. Edge `password-reset` action `admin_reset_sync` (JWT admin wajib, fail-closed 403 tanpa JWT, role `admin*`/`owner` dari `user_roles`, rate limit 10/15 mnt, audit `ADMIN_RESET_AUTH_SYNC`); `ResetPassword.tsx` memanggilnya setelah RPC `admin_reset_worker_password` sukses (kegagalan sinkron hanya warning, tidak memblokir). Bukti: probe `admin_reset_sync LIVE: true` + 403 anon; test end-to-end NRP003 (setelah OPS-14) RPC `ok:true` → edge HTTP 200 `auth_synced:true` → `signInWithPassword` **OK 200** → cleanup kedua sisi `OK 200`; gate tsc/lint 0, unit 141/141, a11y 6/6, build EXIT 0. (`callEdgeFunctionAuth` sudah ada di `edge-functions.ts` — tidak diubah.) Bukti di `agentsLogs_2026-09.md` entri 2026-09-24. Jangan diinvestigasi ulang.
> **Dipangkas 2026-09-24** — **OPS-14b**: owner GOD bypass via `system_owner_identity`. Migrasi `247_ops14b_owner_god_bypass.sql`: helper baru `authz_is_owner()` (SECURITY DEFINER + `SET search_path`, cocok `auth_id = auth.uid()` **ATAU** email JWT vs `owner_email`, `is_active = TRUE`; `REVOKE` PUBLIC+anon, `GRANT` authenticated) + patch `admin_reset_worker_password` 2 baris (cek owner **sebelum** gate `v_caller IS NULL`, jalur non-owner identik gate lama) + `audit_log.actor` fallback `'owner:'||email`. Konsep: owner = shadow/GOD — tidak perlu `employees_core`/`user_roles`, tidak muncul di headcount, tidak "menyamar" jadi NRP (`authz_current_nrp` **tidak** disentuh). Bukti: impersonasi claims (ROLLBACK) owner `authz_is_owner()=true` + reset `ok:true` (sebelumnya `Akses ditolak`), worker `authz_is_owner()=false` + reset **DENIED** (fail-closed), `admin_pusat` tetap lewat `authz_check_admin` (`authz_is_owner()=false`, reset `ok:true`); E2E browser owner login → `/owner/dashboard` render (h1 "Owner Dashboard", bodyLen 310), `/admin` & `/admin/reset-password` render — **by design** (`RoleGuard.tsx:52-59` "owner bypass semua", guard tidak diubah). Gate: tsc/lint EXIT 0, unit 141/141, a11y 6/6, build EXIT 0. **9 `admin_*` lain TIDAK dipatch** (belum ada use case owner; tidak didaftarkan ke Work Queue). Bukti di `agentsLogs_2026-09.md` entri 2026-09-24. Jangan diinvestigasi ulang.
> **Dipangkas 2026-09-24** — **OPS-07**: rate-limit `login_lockout_record` (**300 global / 30 per-identifier per 15 menit**, dipasang HANYA di cabang INSERT `check_login_lockout` agar user sah tetap selalu bisa cek status lockout) + cron `cleanup-login-attempts` (03:30 UTC, retensi 7 hari — `cleanup_login_attempts()` sudah ada tapi belum pernah dijadwalkan) + **restore grant anon `check_login_lockout`** (regresi OPS-05 pasca reset DB 2026-09-22: baseline lama tidak memuat grant, `proacl` tanpa `anon`, panggilan anon 42501 → `Home.tsx:206/313` fail-open). Baseline di-regenerate (§3.15) sehingga grant ikut terbawa untuk instalasi berikutnya. Bukti: `proacl` memuat `anon=X`, anon call **200** `{"locked":false,…,"audit_logged":true}`, spam 50× pada identifier terkunci → tepat **30 baris** ter-write + 20× `audit_logged=false` (limiter aktif), `rate_limits` global=50 / ident=30, identifier normal tak terpengaruh, login worker **OK 200** + admin **OK 200**; baseline `000` baris 18479 berisi `GRANT EXECUTE … check_login_lockout … TO anon`; gate tsc/lint EXIT 0, unit 141/141, a11y 6/6, build EXIT 0. Bukti di `agentsLogs_2026-09.md` entri 2026-09-24. Jangan diinvestigasi ulang.
> **Dipangkan 2026-09-24** — **OPS-13**: sweep mill timeout beratas. Akar: budget per-test 20 s terlalu tipis — `settle()` memakai `networkidle` 15 s (di-`catch` diam-diam) + jeda 1,5 s + `axe` 1–2 s, sehingga 16,5 s hampir habis untuk settle saat jaringan lambat; scan-nya sendiri selalu OK 0 violation. Bukti pre-fix: 3 run (`gate-ops13-run1/2/3.log`) → **2/3 hijau**, run2 `admin /admin/mill` 24,2 s timeout; netprobe 4 iterasi (`gate-ops13-netprobe2.log`) → networkidle selalu tercapai 2,3–8,4 s, **0 websocket**, tanpa RPC >3 s. Fix (khusus test, `src/` tidak disentuh): `settle()` → networkidle 8 s + jeda 500 ms + **wait heading 4 s** (anti render-gagal), budget per-test 20 s → 45 s. Bukti post-fix: sweep mill **3/3 run PASS (8/8)** (2,0 / 2,2 / 2,0 m) + regresi suite 6-halaman **6/6 PASS, 0 violation** + gate tsc/lint 0, unit 141/141, build EXIT 0. Bukti di `agentsLogs_2026-09.md` entri 2026-09-24. Jangan diinvestigasi ulang.
> **Dipangkas 2026-09-24** — **OPS-14**: `user_role_assignments` **0 baris** di live ( efek seed migrasi 135 PART 3 hilang — 134/135 tercatat applied lewat "baseline install" yang hanya mengambil SCHEMA, bukan DATA) → `authz_has_permission()` FALSE untuk semua → `admin_reset_worker_password` **DENIED "Akses ditolak"** untuk semua role admin → fitur **Reset Password Admin mati total di production**; 105 RLS policy authz-v2 ikut mati. Fix: migrasi **246_ops14_seed_user_role_assignments.sql** (idempotent): (1) seed 17 baris assignment dari `user_roles` (scope ENTERPRISE untuk admin_pusat/hrd/finance/operasional, BU untuk mill/mining/estate, SELF untuk worker), (2) permission set untuk `admin_operasional` (`worker_basic`+`supervisor_ext`) yang sebelumnya tidak punya set sama sekali, (3) `setval` `role_permission_sets_id_seq` (drift baseline: last_value=1 vs max(id)=26 → apply pertama bentrok PK). Bukti: impersonasi claims (transaksi ROLLBACK) `authz_check_admin('employee.update')` NRP100 **false→true**, NRP101 **false→true**, NRP103 leave.approve **false→true**, worker & role non-admin tetap **false**; uji nyata JWT `hrd@` → RPC `{"ok":true,"msg":"Password NRP003 berhasil direset..."}` (sebelumnya `Akses ditolak`); round-trip end-to-end NRP003 PASS (RPC ok → edge `admin_reset_sync` HTTP 200 `auth_synced:true` → `signInWithPassword` **OK 200** → cleanup kedua sisi kembali `OK 200`). Gate: tsc/lint EXIT 0, unit 141/141, a11y 6/6, build EXIT 0. **Sisa di luar scope (lapor, tanpa item):** `auth_id` owner tidak punya baris `employees_master` (view di atas `employees_core`) → `authz_current_nrp()` NULL → owner tetap DENIED di RPC yang mengecek `v_caller IS NULL` sebelum owner-bypass; perbaikannya mengubah fungsi SECURITY DEFINER (bukan 1-liner) → menunggu keputusan user. Bukti di `agentsLogs_2026-09.md` entri 2026-09-24. Jangan diinvestigasi ulang.
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
