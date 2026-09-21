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
| OPS-04 | ✅ | **Provisioning sesi Supabase gagal di login worker** → semua RPC berjalan sebagai anon (konteks NULL) → shell worker stuck "Memuat modul…" (0 route). Ditemukan saat smoke SQL-12 (2026-09-21) | Trace Playwright (`test-results/…retry1/trace.zip`): edge `worker-auth-sync` **timeout 5012ms** (limit 5000) + fallback `signInWithPassword` **HTTP 400**; 2× `get_enabled_modules` 200 OK tapi body `[]` (2 byte) dengan `Authorization: Bearer sb_publishable…` (anon). DB sehat: impersonasi NRP005/007/009 → `get_enabled_modules('worker')` = 31 item | ✅ **SELESAI (2026-09-21, FASE 3A/3B):** B1a′ edge self-repair (`supabase/functions/worker-auth-sync/index.ts` — cabang 3a: `mintSession(authEmail, password_user)` dulu; divergen → `updateUserById({password_user})`; fallback rotasi internal bila GoTrue menolak; cabang 3b `createUser({password})`) + B2c′ klien (`Home.tsx` `timeoutMs` 5000→20000 + loading state "Menyiapkan sesi akun…") + B1d′ harness (`supabase/scripts/repair-worker-auth.mjs` — apply: NRP002/NRP005 DIVERGEN→SINKRON). DoD terbukti: smoke OPS-01 **PASS 2/2 (84,9s)**, `/worker/profile` ter-render penuh + JWT sesi; harness `probe-auth-divergence.ts` → **SINKRON 9/9 (NRP002–NRP010), DIVERGEN 0**; edge ter-deploy (`verwobaejumvpagwynae`); gate `check:types`/`lint`/`test`/`build` = 0/0/0/0 (141/141); commit `e8155ef` + `fix(ops04): complete edge self-repair…` (push+deploy FASE 3B). Buktikan di `agentsLogs_2026-09.md` entri OPS-04 FASE 3A/3B | ✅ SELESAI |
| OPS-04 | ✅ | **Provisioning sesi Supabase gagal di login worker** → semua RPC berjalan sebagai anon (konteks NULL) → shell worker stuck "Memuat modul…" (0 route). Ditemukan saat smoke SQL-12 (2026-09-21) | Trace Playwright (`test-results/…retry1/trace.zip`): edge `worker-auth-sync` **timeout 5012ms** (limit 5000) + fallback `signInWithPassword` **HTTP 400**; 2× `get_enabled_modules` 200 OK tapi body `[]` (2 byte) dengan `Authorization: Bearer sb_publishable…` (anon). DB sehat: impersonasi NRP005/007/009 → `get_enabled_modules('worker')` = 31 item | ✅ **SELESAI (2026-09-21, FASE 3A/3B):** B1a′ edge self-repair (`supabase/functions/worker-auth-sync/index.ts` — cabang 3a: `mintSession(authEmail, password_user)` dulu; divergen → `updateUserById({password})` dengan password user; fallback rotasi internal bila GoTrue menolak; cabang 3b `createUser({password})`) + B2c′ klien (`Home.tsx` `timeoutMs` 5000→20000 + loading state "Menyiapkan sesi akun…") + B1d′ harness (`supabase/scripts/repair-worker-auth.mjs` — apply: NRP002/NRP005 DIVERGEN→SINKRON). DoD terbukti: smoke OPS-01 **PASS 2/2 (84,9s)**, `/worker/profile` ter-render penuh + JWT sesi; harness `probe-auth-divergence.ts` → **SINKRON 9/9 (NRP002–NRP010), DIVERGEN 0**; edge ter-deploy (`verwobaejumvpagwynae`); gate `check:types`/`lint`/`test`/`build` = 0/0/0/0 (141/141); commit `e8155ef` + `fix(ops04): complete edge self-repair…` (push+deploy FASE 3B). Buktikan di `agentsLogs_2026-09.md` entri OPS-04 FASE 3A/3B | ✅ SELESAI |
| OPS-05 | **P1** | **`check_login_lockout` 401 untuk `anon`** → cek lockout pra-login tidak pernah berjalan (fail-open; kontrol S10 hanya dekorasi). Ditemukan saat investigasi OPS-04 | Trace OPS-04 2026-09-21 (2 run): `401 {"code":"42501","message":"permission denied for function check_login_lockout"}` (grep: `has_function_privilege('anon','check_login_lockout(text,text)','EXECUTE') = false`, sedangkan `hit_rate_limit`/`login_worker*`/`get_enabled_modules` = true). Dipanggil `Home.tsx:189` & `:270` SEBELUM sesi ada | Grant anon via migrasi baru ATAU pindahkan cek lockout ke dalam `login_worker_by_email`/`login_worker`; bukti: percobaan login ke-N benar-benar ditolak (`attempts`/`blocked_until` naik) + login normal tetap 200 | OPEN |
| OPS-06 | **P2** | **`change_password` & `admin_reset_worker_password` tidak menyinkronkan `auth.users.password`** → setiap worker yang mengganti/reset password kembali DIVERGEN (fast path `signInWithPassword` mati lagi). Ditemukan saat FASE 1 OPS-04. **Keputusan user 2026-09-21: JANGAN fix sekarang** | `pg_get_functiondef`: kedua RPC hanya menulis `worker_passwords` (`SET password_hash = crypt(p_new_password, gen_salt('bf'))`); hanya edge `password-reset` yang juga `updateUserById` (`index.ts:229-243`); `Home.tsx:245-251` (alur `reset_required`) memakai `change_password` lalu `provisionWorkerAuth` dengan password baru | Setelah B1a′ terpasang: buktikan self-heal (ubah password → login berikutnya → fast path hijau) ATAU sinkronkan kedua RPC ke `auth.users`; bukti: probe signIn mengembalikan SINKRON untuk akun yang baru ganti/reset password | OPEN |
| OPS-07 | **P3** | **`check_login_lockout` anon bisa INSERT ke `login_attempts`** → fungsional (lockout benar-benar berjalan setelah OPS-05 grant) tapi bisa inflasi tabel via spam langsung tanpa login. Ditemukan saat disclosure OPS-05 (2026-09-21) | Helper OPS-05 disclosure 2026-09-21; badan fungsi: `L35: INSERT INTO login_attempts (identifier, attempt_type, success, ip_address)` (probe `pg_get_functiondef`); grant `anon` = true (migrasi 245) | Tambah rate-limit pada `check_login_lockout` ATAU cleanup otomatis `login_attempts` (retensi > X hari) ATAU pindahkan cek lockout ke dalam `login_worker_by_email`. Bukti: tabel `login_attempts` tidak tumbuh > ambang wajar selama seminggu | OPEN |
| OPS-07 | **P3** | **`check_login_lockout` anon bisa INSERT ke `login_attempts`** → fungsional (lockout benar-benar berjalan setelah OPS-05 grant) tapi bisa inflasi tabel via spam langsung tanpa login. Ditemukan saat disclosure OPS-05 (2026-09-21) | Helper OPS-05 disclosure 2026-09-21; badan fungsi: `L35: INSERT INTO login_attempts (identifier, attempt_type, success, ip_address)` (probe `pg_get_functiondef`); grant `anon` = true (migrasi 245) | Tambah rate-limit pada `check_login_lockout` ATAU cleanup otomatis `login_attempts` (retensi > X hari) ATAU pindahkan cek ke `login_worker_by_email`. Bukti: tabel `login_attempts` tidak tumbuh > ambang wajar selama seminggu | OPEN |



> **Dipangkas 2026-09-20** — item ✅ yang hasilnya sudah tertulis di `agentsLogs_2026-09.md` dikeluarkan dari tabel
> ini sesuai aturan #3 di atas: **SQL-01, SQL-03, SQL-04, SQL-05, SQL-07** + **SQL-06** (keputusan 2026-09-20: TIDAK FORCE RLS — SQL Editor masih dipakai debugging/maintenance) + **SQL-08** (dieksekusi migrasi 240: drop tabel mati + cron + fungsi terkait) + **SQL-09, SQL-10, OPS-01, OPS-02** (dipangkas 2026-09-20). Jangan diinvestigasi ulang.
> **Dipangkas 2026-09-21** — **SQL-11**: DONE (verifikasi 3 ronde + migrasi 241 + restamp 35 berkas + pulihkan file 240 + baseline/verify-install PASS 9/9; bukti di `agentsLogs_2026-09.md` entri 2026-09-21). Jangan diinvestigasi ulang.
> **Dipangkas 2026-09-21** — **SQL-12**: DONE (keputusan user Opsi D: migrasi 244 — semantik NULL=jangan ubah, ''=kosongkan; signature TIDAK berubah; 13 konversi `‖ null` dihapus dari `WorkerProfile.tsx`; verifikasi impersonasi 4 langkah via `get_worker_profile`; restamp `b421600b…`; **catatan: smoke browser gagal karena temuan baru OPS-04 — provisioning sesi, bukan bagian DoD SQL-12**; bukti di `agentsLogs_2026-09.md` entri 2026-09-21). Jangan diinvestigasi ulang.
> **Dipangkas 2026-09-21** — **SQL-02**: DONE (keputusan user Opsi A: DROP 13 fungsi legacy tanpa sumber via migrasi 243; bukti 0 pemakai `src/`, 0 caller internal, 0 view, grant sudah dicabut 210/073; sisa 2 fungsi legacy bersumber 073/205 dipertahankan; baseline regen fungsi 552→539; verify-install PASS 9/9 cap 168; bukti di `agentsLogs_2026-09.md` entri 2026-09-21). Jangan diinvestigasi ulang.
> **Dipangkas 2026-09-21** — **SQL-13**: DONE (keputusan user Opsi B: `dashboard_landing` dinonaktifkan via migrasi 242; 0 ref kode, tidak di pathMap menu-builder; `ceo_dashboard` tetap aktif melayani /dashboard; verify-install PASS 9/9; bukti di `agentsLogs_2026-09.md` entri 2026-09-21). Jangan diinvestigasi ulang.
> **Dipangkas 2026-09-21** — **OPS-03**: DONE (OPS-03c: lazy() shell App.tsx + boundary Suspense; OPS-03b: manualChunks vendor-supabase/posthog/dompurify + posthog deferred idle-init. Main `index-*.js` = 27,6 kB gzip; initial load 4 file = **144,5 kB gzip < 150 kB** — DoD terpenuhi; gate tsc/lint/build/test 141/141 hijau; bukti di `agentsLogs_2026-09.md` entri 2026-09-21). Jangan diinvestigasi ulang.
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
