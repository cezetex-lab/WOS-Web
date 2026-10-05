# agentsLogs.md — LOG RIWAYAT PEKERJAAN (insightWOS / WOS-Web)

> **ONE SINGLE TRUTH — LOG.** Semua riwayat/history pekerjaan yang sudah SELESAI dicatat di sini.
> Aturan (lihat `AGENTS.md` §0.3-4): setiap perubahan harus **commit → push → deploy**; setelah sukses,
> hasilnya ditulis ke file ini dan **dikeluarkan dari `AGENTS.md`**.

## [2026-10-01] Fix #14 §8 CLOSED — apply 255/256 (bukti pengganti)

- **Status: CLOSED.** Migrasi `255` + `256` DITERAPKAN ke DB live, diverifikasi, di-commit (`6ffc890`), di-push ke `origin/migrasi-vite`. Entri ini menutup kewajiban §0.4 (hasilnya belum pernah masuk log bulan berjalan).
- **Commit migrasi:** `6ffc8900bfffaa5d7b810d598ad96bfe0703b9a9` — `fix14: backfill role_level + align owner_assign_admin_user (255/256)` (4 files, 249 insertions).
- **Berkas migrasi:**
  - `supabase/migrations/255_fix14_backfill_level_nrp001_role.sql` (78 baris) — backfill `role_level` + hapus assignment `admin_pusat` milik NRP001.
  - `supabase/migrations/256_fix14_owner_assign_level_map.sql` (69 baris) — selaraskan pemetaan level di `owner_assign_admin_user` (§5d: admin = fungsi, bukan tingkat → semua `admin_*` = 3).
  - `supabase/scripts/rollback/{255,256}_rollback.sql` — jalur pemulihan.
- **Berkas dokumentasi yang berubah di entri ini (4):**
  - [`docs/forensic/FIX14-ROLE-LEVEL-TOTAL.md`](docs/forensic/FIX14-ROLE-LEVEL-TOTAL.md) §8 → **CLOSED** + sub-blok *State transisi (K1α)*, *Bukti*, *Catatan bukti*.
  - [`docs/forensic/FORENSIC-INDEX.md`](docs/forensic/FORENSIC-INDEX.md) → Work Queue §9/§10 baru (P1-F14-K, P2-F14-H, P2-F14-I, P1-F14-J).
  - [`ARCHITECTURE.md`](ARCHITECTURE.md) §7.4 → `Migrations tracked` 179 → **181** + Fact 2026-10-01. Drift ini **efek apply 255/256 sesi sebelumnya**, tertinggal karena gate `verify:artifacts` tidak dijalankan setelah apply.
  - `agentsLogs_2026-10.md` (baru) — berkas ini.

### Bukti (READ ONLY — `BEGIN READ ONLY` … `ROLLBACK`)

**E1 — registry apply sukses** (`schema_migrations`, 2 baris):
```
{"version":"255","filename":"255_fix14_backfill_level_nrp001_role.sql","checksum":"04ba81a1197bb91161954c6f9b993e750a09b8905cb251a2a61905b7c925cbb7","applied_at":"2026-10-02T06:41:07.566Z"}
{"version":"256","filename":"256_fix14_owner_assign_level_map.sql","checksum":"8126bf1b15c49ad65c33a86cd5b802f3ceca504f9946721b00bc132e1f4240ed","applied_at":"2026-10-02T06:41:31.393Z"}
{"version":"255","filename":"255_fix14_backfill_level_nrp001_role.sql","ok":true}
{"migration_rows":181,"max_version":"256","min_version":"000"}
```
Cross-check wrapper (mode dry-run default, tidak eksekusi SQL): `status: SUDAH terdaftar (checksum cocok)` untuk kedua berkas, EXIT 0.

> **Catatan satuan angka:** `max(version)=256` itu **nomor versi**, bukan jumlah baris. Angka yang
> ditampilkan di §7.4 `ARCHITECTURE.md` adalah **count** = 181, dan itu cocok tiga sumber:
> `COUNT(*) schema_migrations` = 181 · `supabase/migrations/*.sql` = 181 file · doc = 181.
> Nomor versi melompat karena 176/186/208/215 dipakai >1 file (sah — komentar migrasi 219).

**E2 — DoD-255.** `user_roles` 17/17 baris: NRP001=**5**; NRP002–010=**1** (no-op); NRP100–106=**3**. `employees_master`: NRP001=5, NRP100–106=3, worker 0. `user_role_assignments` = `{"total":16,"nrp001":0}` (17→16); NRP100 `admin_pusat/ENTERPRISE/BU04`, NRP104 `admin_mining/BU/BU01`, NRP106 `admin_estate/BU/BU02` utuh. `audit_log`: 8 baris `actor=SYSTEM`, `action="UPDATE user_roles"`, `detail` berisi old+new, rantai `prev_hash`/`row_hash` menyambung → `{"actor":"SYSTEM","n":8}`.

**E3 — prosrc 256.**
```
{"punya_LIKE_admin_pct_THEN_3":true,"masih_punya_5_4_3":false,"masih_punya_THEN_4":false}
{"prosecdef":true,"proconfig":["search_path=public, extensions"],"provolatile":"v","proisstrict":false,"returns":"jsonb"}
```

**Smoke gate `role_level`** (impersonasi JWT, `ROLLBACK`): NRP100 `role_level=3` → `check_module_access` mining_simper/equipment/production @ butuh 1 & 3 = **true semua**; NRP001 `role_level=5` = **true semua**; NRP003 `role_level=1` = **false semua** (kondisi data lama `business_unit_modules`, pre-existing). **Akses hanya naik, tidak turun.**

**Push:** `git log origin/migrasi-vite -1` = `6ffc8900…` (HEAD = remote ref, sinkron).

**Gate:** `npm run verify:artifacts` → **EXIT 0**, `0 drift, 1 warning` (warning baseline installer = infosional, sudah menjadi target Fix #9).

### Catatan bukti (jujur)

**stdout asli `apply-migration.mjs --apply` untuk 255/256 TIDAK TERSIMPAN** — tidak ada di `.agents/logs/`, tidak ada di konteks saat entri ini ditulis, dan **tidak direkonstruksi** (§0.16 melarang klaim tanpa output mentah). CLOSED §8 karena dibangun di bukti pengganti yang lebih kuat dari log apply: checksum file ter-commit cocok byte-per-byte dengan yang tercatat `schema_migrations` hasil eksekusi + `verify_migration_checksum ok:true` + DoD per-versi di live + `prosrc`/`proconfig`/`prosecdef` sesuai + smoke tidak regresi + sudah ada di remote. Grade bukti *rollback byte-identik* = ringkasan probe simulasi B2.16–B2.18 sesi sebelumnya (raw stdout-nya tidak di-archive).

### State transisi (K1α)

NRP001 `role_level=5` tetapi `role` **tetap `'admin_pusat'`** — rename ke `'ceo'` ditunda ke §10 (CHECK `user_roles_role_check` tidak memuat `'ceo'`, dan 61 file `src/` / 127 kemunculan menyebut literal `admin_pusat`). **Zero lock-out** selama transisi. Reversibel via `rollback/255_rollback.sql`.

### Work Queue baru (untuk §9/§10) — didaftarkan di `FORENSIC-INDEX.md`

- **P1-F14-K** — `user_role_assignments` **0 trigger audit** (bukti: 20 trigger `trg_audit_*` ada, tidak satu pun di tabel ini; `audit_log` = 0 baris terkait). Blocker §9: pasang trigger **sebelum** penulisan massal.
- **P2-F14-H** — `authz_in_scope()` cabang `TEAM` memakai `ho1.manager_nrp`, tapi `hr_org` hanya punya `atasan_nrp` (7 kolom, tanpa `manager_nrp`) → error runtime.
- **P2-F14-I** — `admin_produksi` ada di CHECK + whitelist `is_admin_or_owner` tapi **tidak ada di `admin_roles`** (7 role, n=0) → lolos satu gerbang, ditolak gerbang lain dengan `reason='role_not_found'`.
- **P1-F14-J** — rename NRP001 → `'ceo'` (butuh ALTER CHECK + review 61 file `src/`), dijadwalkan §10.

**Dampak lintas-page: TIDAK terdampak (docs only)** — worker → admin → dashboard → owner **tidak terdampak**. Keempat berkas yang berubah di entri ini semuanya dokumen. Tidak ada `src/`, `supabase/`, `tests/`, atau `.github/` yang disentuh. (Migrasi 255/256 sendiri sudah diterapkan sebelum entri ini, dan gate terkait ada di `FIX14-ROLE-LEVEL-TOTAL.md` §8.)

> Catatan: §9–§13 Fix #14 **belum dieksekusi**. Target berikutnya = §9 (rewiring 10 RPC), dengan P1-F14-K dipasang lebih dulu.
>
> Pelajaran: jalankan `verify:artifacts` **langsung setelah apply**, jangan menunggu sampai batch docs — drift angka §7.4 (179 vs 181) tertinggal satu sesi penuh hanya karena itu.
## [2026-10-02] Fix #14 §9 blocker K/H/I CLOSED — apply 257/258/259

- **Status: 3 blocker §9 CLOSED.** Migrasi `257` + `258` + `259` DITERAPKAN ke DB live satu per satu dengan verifikasi di antaranya. Rewiring 10 RPC (§9) **belum** dieksekusi.
- **Berkas migrasi + rollback (6 file):**
  - `supabase/migrations/257_fix14_audit_trigger_user_role_assignments.sql` (22 baris) — P1-F14-K.
  - `supabase/migrations/258_fix14_authz_in_scope_team_atasan.sql` (71 baris) — P2-F14-H, keputusan **H2**.
  - `supabase/migrations/259_fix14_remove_admin_produksi.sql` (62 baris) — P2-F14-I, keputusan **I2 tahap murah**.
  - `supabase/scripts/rollback/{257,258,259}_rollback.sql` — 3 jalur pemulihan, byte-identik teruji.

### Bukti apply (stdout mentah wrapper, 3x)

```
berkas    : 257_fix14_audit_trigger_user_role_assignments.sql
versi     : 257
checksum  : eb67db0389573a2b82f90e823a7a8694b39f3f79bc58f1f2c785e913ac6948a5
status    : DITERAPKAN + terdaftar + checksum terverifikasi (1025ms)

berkas    : 258_fix14_authz_in_scope_team_atasan.sql
versi     : 258
checksum  : c3cb8e7bf4bb61ce54e32f0c49f4467da0a38add0235f036d0625bd41fbc9ccd
status    : DITERAPKAN + terdaftar + checksum terverifikasi (747ms)

berkas    : 259_fix14_remove_admin_produksi.sql
versi     : 259
checksum  : b69e53c18068923a1a95dc29d45b9dbe81ed5a0b982a3b39659dda9063c1ee38
status    : DITERAPKAN + terdaftar + checksum terverifikasi (940ms)
```

Registry: `schema_migrations` **181 -> 184** baris, `max(version)` 256 -> **259**.
```
{"version":"257","filename":"257_fix14_audit_trigger_user_role_assignments.sql","applied_at":"2026-10-02T15:46:56.051Z"}
{"version":"258","filename":"258_fix14_authz_in_scope_team_atasan.sql","applied_at":"2026-10-02T15:47:20.734Z"}
{"version":"259","filename":"259_fix14_remove_admin_produksi.sql","applied_at":"2026-10-02T15:47:54.812Z"}
```

### P1-F14-K — trigger audit (migrasi 257)

Pola Fix #4 (migrasi 251) tanpa logika baru: fungsi `_generic_audit_trigger_fixed` sudah ada,
`SECURITY DEFINER` + `search_path=public, extensions`, `actor` via `COALESCE(authz_current_nrp(),'SYSTEM')`.
Yang hilang hanya 1 `CREATE TRIGGER`.

```
{"tgname":"trg_audit_user_role_assignments","tgenabled":"O","fungsi":"_generic_audit_trigger_fixed"}
{"n":582}   <- audit_log sebelum INSERT
{"nrp":"NRP999-TEST","role_code":"worker","scope_type":"SELF"}
{"n":583}   <- audit_log sesudah
{"audit_naik_1":true}
{"id":641,"actor":"SYSTEM","action":"INSERT user_role_assignments","detail":"{\"nrp\": \"NRP999-TEST\", ...}"}
{"actor_bukan_null":true,"actor_nilai":"SYSTEM"}
```
`actor='SYSTEM'` **diterima** (probe dijalankan tanpa JWT context, jadi fail-safe, bukan error).
Yang dilarang yaitu `actor` NULL atau baris audit tidak muncul, tidak terjadi. Uji dalam transaksi, di-ROLLBACK.

### P2-F14-H — fix cabang TEAM (migrasi 258, H2)

```
{"pakai_atasan_nrp":true,"masih_manager_nrp":false,"ret":"boolean","args":"p_target_nrp text","prosecdef":true,"proconfig":["search_path=public, extensions"],"provolatile":"s"}
        JOIN hr_org ho2 ON ho1.atasan_nrp = ho2.atasan_nrp
```
Smoke: `SELECT authz_in_scope('NRP002')` = `{"r":false}` — **bukan** error `42703 undefined_column`.
Sebelum 258, cabang ini error saat runtime kalau ada assignment `TEAM`. `TEAM` sendiri = 0 baris di
live, jadi tidak ada user yang pernah menyentuh jalur itu — bom waktu, bukan bug yang sudah terjadi.

### P2-F14-I — cabut admin_produksi (migrasi 259, I2 tahap murah)

Pre-check WAJIB sebelum `DROP CONSTRAINT`:
```
{"n":0}   <- user_roles role='admin_produksi'
{"role_di_luar_whitelist":0}
{"n":0}   <- role IS NULL
```
Post-apply:
```
{"jumlah_elemen":13,"punya_admin_produksi":false}
{"punya_admin_produksi":false,"ret":"boolean","args":"","prosecdef":true,"proconfig":["search_path=public, extensions"],"provolatile":"s","bahasa":"sql"}
=== D8-uji-negatif ===
{"error_code":"23514","message":"new row for relation \"user_roles\" violates check constraint \"user_roles_role_check\"","check_terpasang":true}
=== D8b-sanity-role-tetap-valid ===
{"nrp":"NRP002","role":"admin_hrd"}
```
Uji negatif **wajib** dan **berhasil**, jadi CHECK benar-benar aktif, bukan sekadar constraint yang
ada. Sanity: role yang masih valid tetap bisa ditulis.

### Koreksi terhadap draft (terbukti lewat DB, bukan asumsi)

Rencana awal menyebut `is_admin_or_owner` = `LANGUAGE plpgsql`. Fact live: **`LANGUAGE sql` + `STABLE`**
(`{"bahasa":"sql","provolatile":"s"}`). Migrasi memakai definisi byte-exact hasil `pg_get_functiondef`,
jadi bahasa + volatilitas tidak berubah. Kalau rencana dipakai apa adanya, `CREATE OR REPLACE` akan
mengubah semantik fungsi tersebut. Kenaikan `Functions` tetap **658** (tiga migrasi ini tidak menambah fungsi).

### Gate

```
npm run verify:artifacts  -> EXIT 0   (0 drift, 1 warning baseline = infosional Fix #9)
npm run check:types       -> EXIT 0
npm test                  -> EXIT 0   (26 files, 170 passed | 4 todo (174))
```
`verify:artifacts` sempat keluar `DRIFT dok=181 live=184` sesudah apply. Itu **efek yang diharapkan**
(angka dok tertinggal 3), bukan tanda apply gagal. Disinkronkan ke 184 di `ARCHITECTURE.md` §7.4 +
`CONSTANTS-INVENTORY.md`, lalu hijau. Lesson P1 handoff ("jalankan `verify:artifacts` langsung setelah
apply") justru mencegah masalah yang lebih besar: drift ketahuan di gate yang sama, bukan tertinggal
satu sesi penuh seperti kasus 179 vs 181 sebelumnya.

### Rollback (byte-identik, teruji pra-apply)

Simulasi 257+258+259 lalu rollback ketiganya dalam satu transaksi (B2.24):
`{"trigger_count_sama_pre":true,"authz_in_scope_byte_identik":true,"is_admin_or_owner_byte_identik":true,"check_byte_identik":true,"schema_migrations_257_259_tercatat":0,"pulih_sepenuhnya":true}`

**Catatan jujur soal rollback 258:** file `258_rollback.sql` mengembalikan kondisi yang **error**
(`manager_nrp`). Itu satu-satunya cara mengembalikan byte-identik, tapi berarti rollback bukan
"kembalikan fungsi benar" melainkan "kembalikan fungsi seperti sebelumnya". Sudah dibahas sebelum apply.

### Residual (§9, BELUM dikerjakan)

- **Migrasi 260 (P3, opsional):** 3 baris `role_permission_sets` (`id` 14/15/16) milik
  `admin_produksi` masih ada. Tidak dihapus di 259 karena `role_permission_sets` dibaca
  `authz_has_permission()` yang dipakai 105 RLS policy — menghapus di sini berisiko memotong
  hak akses diam-diam. Dijadwalkan terpisah.
- **§9 rewiring 10 RPC + §10 rewiring 3 edge function + §12 test** — belum dieksekusi.
- **P1-F14-J** (rename NRP001 ke `'ceo'`) — tetap §10.

**Dampak lintas-page: tidak terdampak** — worker / admin / dashboard / owner. Tiga migrasi ini
menyentuh trigger audit + 2 fungsi authz + 1 CHECK constraint; **tidak ada satu pun perubahan
perilaku untuk user yang ada** (NRP001/002/003/100-106 tidak punya role `admin_produksi`, dan
scope `TEAM` = 0 baris). `src/`, `supabase/functions/`, `tests/` tidak disentuh. Yang berubah
hanya kemampuan audit (K) dan penghapusan 1 nilai role yang memang mustahil dipakai.
## [2026-10-02] Fix #14 §9 I2 tahap 2 CLOSED — migrasi 260 (hapus 3 perm set `admin_produksi`)

- **Status: 260 CLOSED.** `admin_produksi` kini **0 di kelima tempat**. Melanjutkan 259 (I2 tahap murah) yang hanya menghapus CHECK + whitelist.
- **Alasan 260 ada.** Setelah 259, `admin_produksi` mustahil ada di `user_roles`, tapi 3 baris `role_permission_sets`-nya masih ada dan dibaca `authz_has_permission()`. Itu sisa setengah jadi yang persis kelas bug yang baru diperbaiki — jadi dibersihkan **sebelum** §9 rewiring, saat masih murah.
- **Berkas:** `supabase/migrations/260_fix14_remove_admin_produksi_perm_sets.sql` (38 baris) + `supabase/scripts/rollback/260_rollback.sql` (34 baris).

### Bukti apply

```
berkas    : 260_fix14_remove_admin_produksi_perm_sets.sql
versi     : 260
checksum  : 1cee1e4d11e94f63442a7f880817fe0a02d084919b13b281d2ff24abae30e931
status    : DITERAPKAN + terdaftar + checksum terverifikasi (848ms)
{"version":"260","filename":"260_fix14_remove_admin_produksi_perm_sets.sql","applied_at":"2026-10-02T16:02:04.553Z"}
{"migration_rows":185,"max_version":"260"}
```

Verifikasi:
```
{"n":0}    <- role_permission_sets role_code='admin_produksi'
{"n":93}   <- permission_set_items (TIDAK tersentuh)
{"ada_set_kosong":false,"total_set":9}
{"last_value":"28","is_called":true}   <- sequence tidak bergeser
{"n":0}    <- id 14/15/16 kosong

=== X1-sisa-admin_produksi-semua tempat ===
{"tempat":"user_roles","n":0}                {"tempat":"user_role_assignments","n":0}
{"tempat":"admin_roles","n":0}                {"tempat":"role_page_access","n":0}
{"tempat":"role_permission_sets","n":0}
```
Distribusi setelah 260: `worker_basic` 10 · `supervisor_ext` 6 · `manager_ext` 3 · plus 6 set khusus
(`admin_pusat_all`, `estate_ops`, `finance_ops`, `hrd_ops`, `mill_ops`, `mining_ops`) = 25 baris
dari 28. **Tidak ada set jadi 0**, jadi tidak ada metadata yatim.

Pra-apply (probe B2.29, read-only): 0 foreign key ke `role_permission_sets` (dua metodologi),
0 RLS policy yang hardcode `admin_produksi`, 1 fungsi yang menyebutnya (`admin_set_employee_role`,
§11 P2-F14-F), 27 `permission_set_items` terkait, 0 assignment `admin_produksi`, dan ketiga
permission_set dipakai 11/7/4 role lain.

### Pelajaran P7 — pre-image timestamp WAJIB dari sisi server

Kolom `role_permission_sets.created_at` punya `datetime_precision = 6`, tapi driver `pg` **truncate**
tampilan ke **3 digit** desimal. Probe pertama melaporkan `10:00:41.036`, padahal nilai aslinya
`10:00:41.**036520**`. Rollback versi pertama menulis `.036`, jadi hasil simulasi `byte_identik: false`
meskipun 3 baris `pulih_persis: true` dan `jumlah_diff: 0` — hash seluruh tabel tetap beda 2 digit
mikrodetik. Diperbaiki dengan pre-image yang diambil langsung dari server:
```
{"created_at_server":"2026-09-04 10:00:41.03652+00","created_at_us":"2026-09-04 10:00:41.036520+00","epoch":"1788516041.036520"}
{"column_name":"created_at","datetime_precision":6}
```
**Aturan:** pre-image untuk rollback diambil via `created_at::text` / `to_char(..., 'USOF')` di sisi
server, **bukan** dari output driver. Simulasi apply+rollback (satu transaksi, `ROLLBACK`) yang
menangkapnya — tanpa simulasi, byte yang salah akan tersimpan permanen di DB.

### Pelajaran P8 — `verify:artifacts` buta terhadap perubahan bahasa/volatilitas fungsi

Rencana 259 menyebut `is_admin_or_owner` = `LANGUAGE plpgsql`; fact live = **`LANGUAGE sql` + `STABLE`**
(`{"bahasa":"sql","provolatile":"s"}`). Kalau draft dipakai apa adanya, `CREATE OR REPLACE` mengubah
semantik fungsi **tanpa** gate yang berteriak: `verify:artifacts` hanya menghitung **jumlah** fungsi
(658 -> 658). Tertangkap karena definisi byte-exact `pg_get_functiondef` dipakai — bukan karena ada guard.
Item **P2-F14-M** didaftarkan (test yang baca `prolang`/`provolatile`/`prosecdef`/`proconfig`).

### Work Queue baru

- **P2-F14-L** — `user_role_assignments.role_code` tanpa CHECK/FK ke `admin_roles` sehingga INSERT
  langsung dengan `role_code` sembarang masih mungkin. Bukan blocker §9, tapi tabel ini jadi sumber
  kebenaran tunggal setelah rewiring, jadi harus dipasang sebelum atau bersamaan dengan rewiring.
- **P2-F14-M** — guard deteksi perubahan `LANGUAGE`/`provolatile` fungsi authz kunci.

### Gate

```
npm run check:types        -> EXIT 0
npm test                   -> 1 gagal (doc-claims-vs-live: ARCHITECTURE.md 184 vs live 185)
                             ^ diperbaiki di entri ini: ARCHITECTURE.md 184 -> 185, max 259 -> 260
npm run verify:artifacts   -> EXIT 0 setelah sync (0 drift)
```

**Dampak lintas-page: tidak terdampak** — worker / admin / dashboard / owner. 260 hanya menghapus
3 baris metadata permission untuk role yang **mustahil dipakai** (0 user, 0 assignment, 0 di
`admin_roles`/`role_page_access`). Tidak ada jalur authz yang berubah untuk user nyata:
`permission_set_items` tetap 93, keenam set khusus tidak tersentuh, dan ketiga set yang terpengaruh
masih dipakai 10/6/3 role lain. `src/`, `tests/`, `supabase/functions/` tidak disentuh.

> Sisa `admin_produksi` setelah 260: **nol** di `user_roles` / `user_role_assignments` / `admin_roles` /
> `role_page_access` / `role_permission_sets`. Satu-satunya sisa = whitelist di `admin_set_employee_role`
> (§11 P2-F14-F, item OPEN terpisah — daftarnya masih memuat `admin_produksi` yang kini tak akan pernah
> bisa melewati CHECK `user_roles_role_check`).
## [2026-10-03] Fix #14 §9 blocker L2 + J3 CLOSED — migrasi 261 + 262

**Commit:** (diisi setelah commit) · **Branch:** `migrasi-vite` · **HEAD sebelum:** `57cffe2`

### Yang dikerjakan

Dua blocker §9 yang tersisa ditutup: **L2** (master table role_code) dan **J3** (assignment transisi NRP001).

### FASE A — Investigasi read-only (sebelum desain)

Semua probe `BEGIN READ ONLY … ROLLBACK`; tidak ada write. Log: `.agents/logs/fix14-b23[5-9]*.log`

**State role saat ini:** `user_roles` 17 baris (NRP001 `admin_pusat` level 5; NRP100–106 `admin_*` level 3; NRP002–010 `worker` level 1) · `user_role_assignments` **16** baris, **NRP001 = 0** · `admin_roles` 7 · `role_permission_sets` 25 baris / 10 role_code · `role_page_access` 48 baris / 7 role_code.

**Daftar role_code (dipakai untuk seed 261):**

| sumber | role_code distinct |
|---|---|
| 5 sumber data (union) | **10** — 7 `admin_*` + `manager`, `supervisor`, `worker` |
| CHECK lama `user_roles_role_check` | **13** elemen |
| diff (CHECK − 5 sumber) | **3** — `admin`, `director`, `owner` |
| diff (5 sumber − CHECK) | **0** — tidak ada role hilang |
| union final | **13** — persis sama dengan CHECK lama |

Pre-image CHECK: `len=283`, `md5(pg_get_constraintdef)=bd4d0ad49d6c587a6b0f21a92434da12` (diambil dari server, pelajaran **P7**).

**Constraint/FK existing di `user_role_assignments`:** PK + UNIQUE `(nrp, role_code, scope_type, scope_bu_id)`; **0 CHECK**, **0 FK**, **0 FK menunjuk ke tabel ini**. Tabel `role_codes` belum ada (`false`) → nama bebas.

**Temuan utama — urgensi J3 bukan untuk masa depan.** Rantai berikut **sudah live** hari ini dan membaca `user_role_assignments`, bukan `user_roles`:

```
authz_check_admin(perm) → authz_has_permission(perm)
  → JOIN user_role_assignments ura ON ura.nrp = authz_current_nrp()
    JOIN role_permission_sets rps ON rps.role_code = ura.role_code
```

NRP001 (CEO) tidak punya baris assignment, sehingga secara teknis kehilangan **50 permission** termasuk `employee.update`, `employee.view_all`, `leave.approve`, `payroll.process`, `audit.view`. Rantai ini juga menyentuh **15 policy RLS**. Bukti (impersonasi claims, `auth_id` **terverifikasi dari DB** = `1e4c944e-60ba-4423-b5e8-997edd0beac8`):

| gate | pre-J3 | post-J3 |
|---|---|---|
| `is_admin_or_owner()` | true | true |
| `authz_check_admin('employee.update')` | **false** | **true** |
| `authz_has_role('admin_pusat')` | **false** | **true** |
| `authz_in_scope('NRP002')` | **false** | **true** |

**Pemetaan RPC §9 (E1–E4):** **32** RPC masih baca `user_roles`; hanya **3** yang sudah baca `user_role_assignments` (`authz_has_permission`, `authz_has_role`, `admin_get_payroll`). Ketiganya (`is_admin_or_owner`, 2 overload `check_admin_access`) terbukti **belum** menyentuh assignments. 6 policy RLS memanggil `is_admin_or_owner`.

**`admin_pusat` di `src/` (untuk §10 J1):** **61 file, 127 kemunculan** — teratas `AdminRouteGuard.tsx` 53 (peta akses per-path), `App.tsx` 2 (`allowedRoles` di route guard).

**Nomor migrasi:** `schema_migrations` 185 baris, `max(version)=260` → **261/262 bebas**.

### FASE B — Apply 261 (L2)

```
node supabase/scripts/apply-migration.mjs 261_fix14_role_codes_master_table.sql --apply
status : DITERAPKAN + terdaftar + checksum terverifikasi (848ms)   EXIT_261=0
```

Isi: `CREATE TABLE role_codes(code PK, is_active, catatan, created_at)` + seed 13 (`ON CONFLICT DO NOTHING`) + FK `fk_ura_role_code` + FK `fk_ur_role` (dua-duanya `DO $$ … IF NOT EXISTS`) + `DROP CONSTRAINT user_roles_role_check`.

**Deviasi dari rancangan awal (disengaja, fail-safe):** FK ditambahkan **lebih dahulu**, CHECK lama di-`DROP` **setelahnya**. Kalau urutannya dibalik dan `ADD FK` gagal, `user_roles` tertinggal **tanpa validasi sama sekali** di tengah migrasi. Keduanya satu transaksi → hasil akhir identik.

**Desain `role_codes` = tabel mandiri, bukan FK ke `admin_roles`:** `manager` dan `supervisor` hanya hidup di `role_permission_sets` (terverifikasi) — kalau FK diarahkan ke `admin_roles` keduanya akan ditolak.

Verifikasi post-apply:

```
registry            : {"version":"261","filename":"261_fix14_role_codes_master_table.sql"}
role_codes          : 13 baris → {"is_active":true,"n":10} · {"is_active":false,"n":3}
FK                  : fk_ur_role       FOREIGN KEY (role)      REFERENCES role_codes(code)
                      fk_ura_role_code FOREIGN KEY (role_code) REFERENCES role_codes(code)
CHECK lama          : 0 baris (hilang ✅)
data utuh           : user_roles 17 · user_role_assignments 16
registry            : n=186, max=261
uji negatif 23503   : user_roles 'role_palsu'          → violates foreign key constraint "fk_ur_role"
                      user_role_assignments 'role_palsu_2' → violates foreign key constraint "fk_ura_role_code"
```

### FASE C — Apply 262 (J3)

```
node supabase/scripts/apply-migration.mjs 262_fix14_assign_nrp001_transitional.sql --apply
status : DITERAPKAN + terdaftar + checksum terverifikasi (817ms)   EXIT_262=0
```

```
assignment  : {"id":45,"nrp":"NRP001","role_code":"admin_pusat","scope_type":"ENTERPRISE",
               "scope_bu_id":"BU04","is_primary":false,"assigned_by":"migration:262"}
total       : 17 (16 + 1)
audit_log   : {"id":662,"actor":"SYSTEM","action":"INSERT user_role_assignments"}
registry    : n=187, max=262
C7 UTAMA    : {"ceo_gate":true,"emp_update":true,"has_role":true,"audit_view":true,
               "payroll_process":true,"current_nrp":"NRP001",
               "acc_admin":"{\"ok\": true, \"reason\": \"global_admin\", ...}"}
             → is_admin_or_owner(NRP001) = true → J3 BERHASIL
kontrol     : NRP105 (admin_mill, sudah punya assignment) = {"gate":false,"emp_update":false}
```

`actor='SYSTEM'` karena apply berjalan tanpa JWT context — fail-safe yang diterima.

### FASE D — Gate

`npm run verify:artifacts` → **2 drift yang diharapkan** (Tables dok=208 live=209 · Migrations tracked dok=185 live=187), `migration rows 187 OK`, `max(version) 262 OK`, 1 warning baseline Fix #9 · `npm run check:types` **EXIT 0** · `npm test` → setelah 4 klaim dokumen di-sync: **5 passed** di `doc-claims-vs-live`, suite penuh hijau (26 files).

### Pelajaran proses P7 (reused) & P9 (baru)

**P7** — pre-image CHECK diambil via `pg_get_constraintdef` **di sisi server**, bukan dari output driver. `261_rollback.sql` memakai definisi byte-exact tersebut; simulasi membuktikan `byte-identik: TRUE`.

**P9 (baru)** — pengukuran **di dalam transaksi yang belum di-`ROLLBACK`** selalu terlihat "menyimpang" untuk tabel berttrigger audit. Simulasi 262 menunjukkan `audit_n` 582→583→584 lalu "tidak kembali". Probe terpisah membuktikannya artefak, bukan drift:

```
T0 sebelum transaksi          : audit_log=582
T1 di dalam trx, setelah 262   : audit_log=583   (+1, trigger 257)
T2 di dalam trx, setelah RB    : audit_log=584   (DELETE juga tercatat)
T3 SETELAH ROLLBACK transaksi  : audit_log=582   ← pulih
trigger: trg_audit_hash_chain (audit_log), trg_audit_user_role_assignments
```

`audit_log` punya `trg_audit_hash_chain` sendiri (bukan trigger generik) → tidak rekursif. **Aturan: ukur ulang setelah `ROLLBACK`, di koneksi baru.**

### Simulasi pra-apply (semua ROLLBACK, tidak tersimpan)

- `261 byte-identik: TRUE` · `261 rollback kedua idempoten: TRUE`
- `262 pulih persis: TRUE` (data role) · `262 idempoten jalan 2×: TRUE` · `262 rollback kedua idempoten: TRUE`
- Gabungan `261→262→RB262→RB261`: byte-identik untuk seluruh state role

### 4 file baru

`supabase/migrations/261_fix14_role_codes_master_table.sql` (117 baris, tanpa BEGIN/COMMIT — P4)
`supabase/migrations/262_fix14_assign_nrp001_transitional.sql` (44 baris, tanpa BEGIN/COMMIT — P4)
`supabase/scripts/rollback/261_rollback.sql` (47 baris, ada BEGIN/COMMIT)
`supabase/scripts/rollback/262_rollback.sql` (30 baris, ada BEGIN/COMMIT)

### ⚠️ Peringatan yang wajib dibawa ke §10

**`262_rollback.sql` sengaja TIDAK memfilter `is_primary`.** Kalau di §10 assignment NRP001 di-upgrade jadi permanen dengan `is_primary=TRUE`, predicate rollback **harus diubah lebih dulu** atau assignment permanen ikut terhapus. Peringatan ini tertanam di file rollback itu sendiri.

### Work Queue

**P2-F14-L → PARTIAL** — FK terpasang (261, uji 23503 ✅). Sisa: guard test otomatis (§12). FK bisa dilepas tanpa `verify:artifacts` berteriak — kelas bug yang sama seperti **P2-F14-M**.

### Dampak lintas-page: worker → admin → dashboard → owner

**Tidak keempatnya.** Rinciannya: (1) **Worker** — 261/262 tidak menambah/mengubah kolom yang dibaca worker; `get_worker_status` tetap baca `user_roles`, tidak disentuh. (2) **Admin** — FK baru hanya menolak `role_code` yang tidak ada di master (tidak ada data existing yang ditolak, dibuktikan `user_roles` 17 + assignments 16 utuh); assignment NRP001 **menambah** akses, tidak mengurangi. (3) **Dashboard** — `is_admin_or_owner` kini `true` untuk NRP001 (sebelumnya sudah `true` juga, lewat `user_roles`), jadi tidak ada perubahan perilaku. (4) **Owner** — `role_codes` adalah tabel referensi baru, tidak ada UI/call yang membaca `is_active`; gate owner tetap `system_owner_identity` + bypass yang tidak disentuh. §8 sudah memberi NRP001 `role_level=5`, jadi tidak ada perubahan role level.
## [2026-10-03] Fix #14 §9 **batch 263 CLOSED** — rewire `is_admin_or_owner` + restore grant `authenticated` (P2-F14-N)

- **Status: CLOSED.** Migrasi `263` DITERAPKAN ke DB live lewat wrapper `apply-migration.mjs --apply`, diverifikasi, di-commit, di-push ke `origin/migrasi-vite`. Entrinya menutup kewajiban §0.4 untuk batch 1 dari 5 (rencana `263`–`267`).
- **Keputusan user: Opsi 1** — rewire body + `GRANT EXECUTE` dalam **satu** migrasi, bukan dipecah dua nomor. Alasan yang diuji: tanpa grant, 6 policy RLS tetap `42501` dan hasil fix tidak bisa diobservasi sama sekali; memecah hanya menambah satu titik gagal di tengah.
- **Berkas (2):**
  - `supabase/migrations/263_fix14_is_admin_or_owner_rewire.sql` (119 baris, sha256 `a9707149b0706c574ad6262a4aef5956eee6ad83e521a0b3b6f11c629f20dacb`) — **tanpa** BEGIN/COMMIT (P4).
  - `supabase/scripts/rollback/263_rollback.sql` (53 baris, sha256 `ffce8d18620b9494a1aea3dab805719fdb10241cf56079c70d3e569a89c2ba89`) — dengan BEGIN/COMMIT (psql manual).
- **Dokumentasi tersinkron (5):** `ARCHITECTURE.md` §7.4 (187→188, Fact 2026-10-03), `FIX14-ROLE-LEVEL-TOTAL.md` §9 (blok `### 263` + P10/P11 + §13), `FORENSIC-INDEX.md` (4 Work Queue + blok bukti), `CONSTANTS-INVENTORY.md` (188/max 263), `AGENTS.md` §5.8 (N CLOSED + O/P/Q/P1-ACL-AUDIT + P10/P11).

### Dua masalah yang ditutup dalam satu migrasi

**MASALAH 1 — P2-F14-N, whitelist gerbang tidak lengkap.** `is_admin_or_owner()` membaca role lewat `user_roles` dengan whitelist literal 4 dari 7 admin role: `IN ('owner','admin_pusat','admin_hrd','admin_finance')`. Yang hilang: `admin_operasional`, `admin_mining`, `admin_mill`, `admin_estate` — keempatnya `is_active=TRUE` di `role_codes`, punya `role_page_access` sendiri, dan punya permission set khusus (`supervisor_ext` / `mining_ops` / `mill_ops` / `estate_ops`).

**MASALAH 2 — temuan BARU saat investigasi, blocking: grant `authenticated` hilang sejak migrasi 172.** ACL live hanya `{postgres, service_role}`. Policy RLS dievaluasi dengan hak akses role **pemanggil**, jadi keenam policy yang memanggil fungsi ini tidak pernah bisa dievaluasi:

```
business_units.bu_update        [UPDATE]  is_admin_or_owner()
hr_kpi_config.hk_update         [UPDATE]  is_admin_or_owner()
hr_okrs.ok_select               [SELECT]  (nrp = <self>) OR is_admin_or_owner()
hr_succession_matrix.sc_select  [SELECT]  is_admin_or_owner()
offboarding_checklist.of_select [SELECT]  is_admin_or_owner()
settings.st_update              [UPDATE]  is_admin_or_owner()
```

Akar: `172_hardening_grants.sql` `REVOKE EXECUTE ON ALL FUNCTIONS` dari PUBLIC/anon/authenticated lalu grant balik **hanya daftar putih manual**; `is_admin_or_owner` tidak ada di daftar itu (`git grep is_admin_or_owner -- supabase/migrations/172_hardening_grants.sql` = **0 hit**). Bandingkan `authz_check_admin` / `authz_has_permission` / `authz_current_nrp` / `authz_in_scope` yang semuanya punya `authenticated=X`.

### Bukti pre-263 — 42501 untuk SEMUA user, bukan hanya 4 admin

```
[PRE] NRP001..NRP106 + NRP002  SELECT hr_okrs              = 42501
[PRE] NRP001..NRP106 + NRP002  SELECT offboarding_checklist = 42501
[PRE] NRP001..NRP106 + NRP002  SELECT hr_succession_matrix = 42501
[PRE] NRP105 SELECT ai_rate_limits = OK:0   ← pembanding: authz_check_admin punya grant
[PRE] NRP105 SELECT api_keys        = OK:0
[PRE] NRP105 SELECT api_rate_limits = OK:0
```

Status **latent**: UI tidak membaca ketiga tabel itu langsung (`git grep hr_okrs -- src` = 0 hit; `Offboarding.tsx:95` memakai RPC `get_offboarding_checklist`), jadi tidak pernah ada user yang komplain.

### Perubahan body

```
- AND ur.role IN ('owner', 'admin_pusat', 'admin_hrd', 'admin_finance')
+     AND ura.role_code LIKE 'admin\_%'
```

blok pertama pindah dari `user_roles` ke `EXISTS` atas `user_role_assignments` JOIN `employees_master`; cabang `authz_is_owner()` ditambahkan di akhir; blok kedua yang lama (`user_roles.role='owner'`) dipertahankan apa adanya. Alasannya dua:

1. Pola ditulis `admin\_%` (underscore di-escape), bukan `admin_%` polos — tanpa escape `adminx` ikut cocok. Pada 13 baris `role_codes` live hasil keduanya identik (`beda = 0`), jadi ini tidak mengubah perilaku sekarang, hanya menutup celah kalau nanti ada kode liar. Bukti semantik live: `'admin_pusat' LIKE 'admin\_%'` = true, `'adminx'` = false, `'admin'` = false.
2. Cabang `authz_is_owner()` wajib ada karena owner (`a8a77284-…`, **diverifikasi ke `system_owner_identity`**, bukan placeholder) punya `employees_core` = **0 baris** — tidak bisa dicocokkan lewat `employees_master` sama sekali, dan `user_roles.role='owner'` = **0 baris** juga (mati secara struktural). Tanpa cabang ini owner berubah jadi FALSE, yaitu regresi dari perilaku migrasi 247.

### Bukti apply (mentah, `BEGIN READ ONLY` … `ROLLBACK`)

**B1 stdout wrapper:**
```
berkas    : 263_fix14_is_admin_or_owner_rewire.sql
versi     : 263
checksum  : a9707149b0706c574ad6262a4aef5956eee6ad83e521a0b3b6f11c629f20dacb
status    : DITERAPKAN + terdaftar + checksum terverifikasi (648ms)
```

**B3–B7 query pasca-apply:**
```
{"version":"263","filename":"263_fix14_is_admin_or_owner_rewire.sql"}
{"total":188,"max_version":"263"}
ada_pola_admin_escaped=true  ada_ura_alias=true  ada_authz_is_owner=true
masih_whitelist_lama=false   masih_ur_role_in=false
acl = {postgres=X/postgres, service_role=X/postgres, authenticated=X/postgres}
attrs = {bahasa:"sql", volatilitas:"s", secdef:true, config:{search_path=public, extensions}, ret:"boolean"}
md5(pg_get_functiondef) = 18a97b91ebd8152f788fc7b72fb8f454  (pre: 6c0fb3d3ca5a10e2f789f295790d33c7)
audit_log 583 → 583   user_role_assignments 17 → 17   (tidak tersentuh)
```

**C1 positif 9/9:** NRP001, NRP100, NRP101, NRP102, NRP103, NRP104, NRP105, NRP106, owner `a8a77284` → `is_admin_or_owner() = true`.

**C2 negatif 4/4:** NRP002 worker `false` · anon `{}` **42501** · anon ber-sub worker **42501** · authenticated sub asing `false`. Tidak ada grant ke `anon` — fail-closed terbukti.

**C3 policy RLS:** 6 policy × 4 NRP (105/106/103/100) → semua **OK, 0 × 42501**.

**C4 fail-closed (bukti definitif, bukan "kebetulan 0 baris"):** admin `NRP100`/`NRP105` meng-update baris `business_units` id `BU01` yang **benar-benar ada** (sanity: 1 baris) → policy dievaluasi; worker `NRP002` meng-update **baris yang sama** → **0 baris ter-update** karena RLS menyaring. Enam tabel dari sudut worker: `SELECT` 0 baris, `UPDATE` 0 baris.

**Rollback byte-identik (D4, simulasi pra-apply):**
```
pre      md5(pg_get_functiondef) = 6c0fb3d3ca5a10e2f789f295790d33c7  len 547  acl {postgres,service_role}
apply    md5                     = 18a97b91ebd8152f788fc7b72fb8f454  len 544  acl {postgres,service_role,authenticated=X}
rollback md5                     = 6c0fb3d3ca5a10e2f789f295790d33c7  len 547  acl {postgres,service_role}   ← identik
```
`md5(prosrc)` `d3ccc554…` kembali persis; panjang identik; ACL persis sama. `schema_migrations` tidak tersentuh (187/262 → 187/262 di dalam simulasi).

### Gate

| Gate | Hasil |
|---|---|
| `verify:artifacts` | 1 drift **dokumen** (dok=187 live=188) → sinkron di entri ini, lalu EXIT 0 |
| `check:types` | **EXIT 0** |
| `npm test` | run-1 gagal `vitest-pool` timeout (2 file tak sempat start; **lolos 19/19 saat diisolasi** → bukan regresi). run-2: 26 file, **169 passed \| 4 todo**, 1 gagal = `doc-claims-vs-live` yang tepat menunjuk drift 187→188. Setelah sync → hijau |
| `npm run test:a11y` | **4/6 PASS**. 2 test owner gagal: `storageState` owner dibuat 24 Sep, token sudah kedaluwarsa → halaman mendarat di `/owner/login` yang punya violation `label` **critical** pada `input[type=email]`. **Bukan regresi 263** — `is_admin_or_owner` tidak menyentuh render. Bug `OwnerLogin.tsx:62` (`<label>` tanpa `htmlFor`) dicatat terpisah |

### Dampak lintas-page

- **worker** → **tidak berubah**: `is_admin_or_owner()` tetap `false`, 6 policy RLS tetap fail-closed (0 baris, UPDATE ditolak). Tidak ada akses baru.
- **admin_pusat / admin_hrd / admin_finance / CEO** → **tidak berubah** di hasil fungsi, tapi **6 policy RLS berhenti error 42501**. Sebelumnya halaman yang membaca `hr_okrs` / `offboarding_checklist` / `hr_succession_matrix` akan gagal total untuk semua orang, termasuk mereka.
- **admin_operasional / admin_mining / admin_mill / admin_estate** → **perubahan nyata**: `is_admin_or_owner()` **false → true**, sehingga 3 policy SELECT + 3 policy UPDATE aktif untuk mereka. Ini inti fix P2-F14-N.
- **dashboard** → tidak ada panggilan langsung ke fungsi ini;tergantung secara transitif dari policy RLS yang kini hidup.
- **owner** → **tidak berubah** (`authz_is_owner()` sudah TRUE lewat 247); cabang itu hanya dipagari agar tidak jadi FALSE.

### Work Queue yang diperbarui

| ID | Status | Isi |
|---|---|---|
| **P2-F14-N** | ✔ **CLOSED** (263) | whitelist 4 role → `user_role_assignments` `admin\_%` |
| **P2-F14-O** | ⚠ **NEW** | wrapper `rpcGetWorkerStatus` (`src/lib/supabase-rpc.ts:87`) tanpa `p_nrp` |
| **P1-ACL-AUDIT** | ⚠ **NEW** | **46** fungsi `public` tanpa `EXECUTE` untuk `authenticated`; sprint audit menyeluruh, 263 menutup 1 dari 46 |
| **P2-F14-P** | ⚠ **NEW** | `employee.view_all` hanya dimiliki `admin_hrd` + `admin_pusat` → 4 admin industri `authz_check_admin(...) = false`; **butuh keputusan user** |
| **P2-F14-Q** | ⚠ **NEW** | **61 dari 208** tabel RLS tanpa policy SELECT (termasuk `business_units`, `settings` — `bu_select`/`st_select` dari `083` hilang). **Tidak terkait 263** |

### Pelajaran proses baru

**P10 — whitelist grant yang melewatkan fungsi kritis.** `172_hardening_grants.sql` bermaksud "end-state deterministik: revoke semua, grant minimal", tapi daftar putih dipilih manual dan fungsi yang tidak masuk daftar **mati senyap** selama berbulan-bulan. Policy RLS tetap tertulis di `pg_policies`, jadi `verify:artifacts` menghitungnya sebagai policy yang **ADA** — yang mati adalah *permission untuk mengevaluasinya*, dan tidak ada guard mana pun yang menangkapnya. Aturan turunan: **setiap policy RLS yang memanggil helper `SECURITY DEFINER` WAJIB punya `EXECUTE` untuk role yang di-shadow**; menambah policy tanpa grant = policy mati. Item turunan: **P1-ACL-AUDIT**.

**P11 — grep substring menyesatkan untuk memetakan caller.** `prosrc ILIKE '%is_admin_or_owner%'` mengembalikan 5 pemanggil dan **salah 3**: `_is_admin_or_owner` / `_is_admin_or_owner_caller` hanya mengandung string itu sebagai **substring nama**, lalu `get_worker_leave` / `get_worker_overtime` / `submit_voice` memanggil *helper* itu, bukan `is_admin_or_owner`. Rantai sebenarnya: `_is_admin_or_owner_caller()` → `authz_check_admin('employee.view_all')`. Verifikasi caller harus baca `pg_get_functiondef` per fungsi, bukan mengandalkan substring.

### Catatan untuk batch berikutnya

- §9b dikoreksi: hanya **1 dari 10** RPC yang selesai. `263` = `is_admin_or_owner`. Sisa: `check_admin_access` (264, termasuk DROP overload 0-arg), `get_current_user_context` + `get_user_context_by_auth_id` (265), `verify_admin_otp_core` + `generate_admin_otp` (266), `admin_get_role_matrix` + `admin_set_employee_role` (267).
- `check_admin_access()` (kedua overload) juga **tidak** punya `EXECUTE` untuk `authenticated` (`{postgres, service_role}`) dan **0 policy** memanggilnya — kalau memang tidak dipakai, **DROP** lebih murah daripada rewrite.
- `263_rollback.sql` mengembalikan policy RLS ke kondisi **42501 untuk semua user**. Itu restore yang jujur, tapi kalau sistem ini butuh policy itu hidup, jangan rollback 263 — perbaiki forward.
## [2026-10-03] Fix #14 §9 **batch 264 CLOSED** — DROP dead `check_admin_access` (2 overload)

- **Status: CLOSED.** Migrasi `264` DITERAPKAN ke DB live lewat wrapper `apply-migration.mjs --apply`, diverifikasi, di-commit, di-push ke `origin/migrasi-vite`.
- **Keputusan user: DROP kedua overload, bukan rewrite.** Alasannya konfirmasi caller: fungsi ini dead code total. Rewrite 72 baris logika yang tidak pernah dieksekusi hanya menambah permukaan authz yang harus diaudit tanpa memberi manfaat.
- **Berkas (2):**
  - `supabase/migrations/264_fix14_drop_dead_check_admin_access.sql` (78 baris, sha256 `43eed6f50624d92a0f7d1cee4f65bc7588cd8935caea9912b4b8e6c952a817e5`) — **tanpa** BEGIN/COMMIT (P4).
  - `supabase/scripts/rollback/264_rollback.sql` (145 baris, sha256 `7c636fda4678e706e55a8224f473598099f16a98eafda991c47d55ff360c1f73`) — dengan BEGIN/COMMIT + restore ACL eksplisit.
- **Dokumentasi tersinkron (6):** `ARCHITECTURE.md` §7.4 (Functions 658→656, overload 20→19, Migrations 188→189, diagram §7.1, Fact 264), `FuturePlans.md` §1.3 (Total Functions + Legacy Overloads — ikut dijaga `doc-claims-vs-live`), `FIX14-ROLE-LEVEL-TOTAL.md` §9 (blok `### 264` + P12/P13 + §9b), `FORENSIC-INDEX.md` (merge Work Queue + blok bukti), `CONSTANTS-INVENTORY.md` (189/max 264, 656/+19), `AGENTS.md` §5.8.

### Konfirmasi 0 caller — 7 sumber, bukan 5

```
B1 src/                git grep -n "check_admin_access" -- src/   = 0 hit
B2 pg_proc.prosrc      prosrc ILIKE '%check_admin_access%'
                         AND proname <> 'check_admin_access'       = 0 baris
B3 pg_policies         qual / with_check ILIKE                   = 0 baris
B4 pg_trigger          JOIN pg_proc ON tgfoid                    = 0 baris
B5 pg_views + pg_matviews  definition ILIKE                      = 0 baris
B6 pg_attrdef          DEFAULT kolom ILIKE                       = 0 baris
B6 pg_constraint       pg_get_constraintdef ILIKE                = 0 baris
B6 seluruh schema (bukan cuma public)                            = 2 baris
                          → keduanya definisi overload itu sendiri
```

`pg_depend` tiap overload: `normal=2` (milik schema + kolom `pg_proc`), `internal=0` → **DROP tanpa CASCADE** tidak akan merusak objek lain. ACL pre-264 `{postgres=X/postgres, service_role=X/postgres}` — `authenticated` dan `anon` **tidak** punya EXECUTE, jadi mustahil dipanggil lewat PostgREST dan nol risiko kompatibilitas API.

### Dua overload, dua alasan berbeda bahwa DROP lebih baik daripada rewrite

**1. `check_admin_access()` → boolean, prosrc 210 byte — struktural selalu FALSE.**
Membaca `current_setting('request.jwt.claims', true)::json->>'role'`. Supabase **tidak pernah** mengisi claim `role`; claim itu berisi `sub`/`email`/`app_metadata`, bukan nilai role aplikasi (role ada di `user_roles`/`user_role_assignments`). Sisa policy konfirmasi era-083 yang tidak pernah lagi relevan.

**2. `check_admin_access(p_path text)` → jsonb, prosrc 2093 byte — logikanya salah untuk §9.**
Logikanya masih masuk akal (owner bypass → `user_roles` → `admin_roles` → `role_page_access`, default deny) **tapi** chain-nya:
`SELECT ur.role INTO v_role FROM user_roles ur … ORDER BY ur.role_level DESC LIMIT 1`
mengambil role dari `user_roles`, sementara sumber kebenaran admin setelah §9 adalah `user_role_assignments` + permission set. Kalau dihidupkan, dia butuh **rewrite total**, bukan pemulihan sebagian — dan tidak ada satu pun pemanggil yang membutuhkan dia hidup.

### Bukti apply (mentah, query live pasca-264)

**B1 stdout wrapper:**
```
berkas    : 264_fix14_drop_dead_check_admin_access.sql
versi     : 264
checksum  : 43eed6f50624d92a0f7d1cee4f65bc7588cd8935caea9912b4b8e6c952a817e5
status    : DITERAPKAN + terdaftar + checksum terverifikasi (635ms)
```

**B3–B8:**
```
{"version":"264","filename":"264_fix14_drop_dead_check_admin_access.sql","checksum":"43eed6f5…"}
check_admin_access overload tersisa      = 0
public_functions                          = 656   (dari 658, turun 2)
schema_migrations                         = 189 / max 264
SELECT public.check_admin_access();       → 42883 function public.check_admin_access() does not exist
SELECT public.check_admin_access('/admin') → 42883 function public.check_admin_access(unknown) does not exist
policy_total   = 225   base_tables = 209   (tidak berubah)
check_owner_identity() masih ada (ret boolean) — bukan target 264
is_admin_or_owner md5 = 18a97b91ebd8152f788fc7b72fb8f454  acl {postgres,service_role,authenticated} — utuh
authz_check_admin / authz_current_nrp / authz_has_permission / authz_in_scope / authz_is_owner — md5 tidak berubah
```

### Rollback byte-identik termasuk ACL (simulasi pra-apply, 19 PASS / 0 FAIL)

```
pre      (noargs)      md5def=0106fcb4584a0e06d9c3200c4dd2a1b2  md5src=970bd74bb4b0c18a2357f559eef87f31  len=210
rollback (noargs)      md5def=0106fcb4584a0e06d9c3200c4dd2a1b2  md5src=970bd74bb4b0c18a2357f559eef87f31  len=210   ← identik
pre      (p_path text) md5def=5aeaa26ccbf17f928fe95c4a41aa457e  md5src=0f0ce77ce4cc68a8b1ac9f66c400988c  len=2093
rollback (p_path text) md5def=5aeaa26ccbf17f928fe95c4a41aa457e  md5src=0f0ce77ce4cc68a8b1ac9f66c400988c  len=2093  ← identik
ACL keduanya rollback  {postgres=X/postgres,service_role=X/postgres}   = pre-264
privilege post-rollback  anon=false  auth=false  svc=true              = pre-264
schema_migrations 188/263 → 188/263 (tidak tersentuh)
```

### Gate

| Gate | Hasil |
|---|---|
| `verify:artifacts` | pre-sync 2 drift (Migrations 188→189, Functions 658→656) → sinkron → **0 drift, EXIT 0** |
| `check:types` | **EXIT 0** |
| `npm test` | pre-sync 1 gagal = `doc-claims-vs-live` yang tepat menunjuk 5 drift dokumen → sinkron → **26 file, 170 passed \| 4 todo, EXIT 0** |
| `npm run test:a11y` | **6/6 PASS, 0 violation** (storageState owner sudah di-regen di sesi draft; ini konfirmasi, bukan pekerjaan ulang) |

### Dampak lintas-page

- **worker** → tidak berubah (fungsi tidak pernah bisa dipanggil role aplikasi).
- **admin** → tidak berubah. Tidak ada halaman yang memanggil fungsi ini (`src/` = 0 hit).
- **dashboard** → tidak berubah.
- **owner** → tidak berubah; `check_owner_identity()` yang dipanggil overload text **tidak** ikut di-DROP (punya caller sendiri, bukan target 264).
- Yang benar-benar berubah: `Functions` 658 → 656 (angka yang dijaga `verify:artifacts` + `doc-claims-vs-live` di 3 dokumen) dan Work Queue.

### Work Queue

| ID | Status | Isi |
|---|---|---|
| **P1-POST-HARDENING-AUDIT** | ⚠ **NEW (merge)** | `P1-ACL-AUDIT` + `P2-F14-Q` digabung — satu akar (migrasi 172), dua sisi: **(a)** 46 fungsi tanpa `EXECUTE` untuk `authenticated`; **(b)** 61 dari 208 tabel RLS tanpa policy SELECT. Sprint audit gabungan + guard CI `proacl` vs daftar policy pemanggil |
| **P2-F14-R** | ⚠ **NEW** | Bug a11y latent: `<label>` tanpa `htmlFor` di `src/pages/OwnerLogin.tsx:62` → axe `label` critical. Terbukti saat a11y 4/6; setelah storageState di-regen menjadi 6/6, jadi bug ini **tidak pernah dieksekusi** pada alur normal |

### Pelajaran proses baru

**P12 — rollback `DROP FUNCTION` WAJIB sertakan restore ACL.** Default privilege fungsi baru di PostgreSQL adalah EXECUTE untuk owner **dan PUBLIC**. ACL pre-264 sengaja tidak mengandung PUBLIC (migrasi 172 revoke-all lalu grant hanya service_role). Kalau rollback hanya `CREATE OR REPLACE`, hasilnya `proacl = {postgres=X/postgres, =X/postgres}` — setiap role bisa memanggil fungsi `SECURITY DEFINER` ini, dan `role_page_access`/`admin_roles` ikut terekspos. Itu mengembalikan **security hole**, bukan pre-image. Aturan: untuk rollback berbasis `CREATE OR REPLACE`, **ACL adalah bagian dari definisi "byte-identik"**, bukan hiasan. `pg_get_functiondef` **tidak** memuat ACL sama sekali, jadi gate wajib menambah `proacl` + `has_function_privilege` per role — membandingkan functiondef saja tidak cukup.

**P13 — OID berubah setelah DROP + CREATE; itu normal.** Simulasi 264 menunjukkan oid `298204` → `336335` dan `298205` → `336336`, meski transaksi seluruhnya di-`ROLLBACK`. Bukan drift: **OID counter PostgreSQL tidak pernah di-rollback**. Konsekuensi praktis untuk semua gate byte-identik: kunci perbandingan ke **signature** (`pg_get_function_identity_arguments`), **jangan** ke `oid` — kalau tidak, simulasi kedua akan melahukan gate yang sebenarnya hijau. Kelas bug yang sama seperti **P3-F04-01**.

### Catatan untuk batch berikutnya

- §9b: **2 dari 10** selesai. Sisa: `265` `get_current_user_context` + `get_user_context_by_auth_id`, `266` `verify_admin_otp_core` + `generate_admin_otp`, `267` `admin_get_role_matrix` + `admin_set_employee_role`.
- 265 punya 75 caller RPC untuk `get_current_user_context`, dan `user_role_assignments` **tidak** punya `role_level`/`scope_divisi`/`plan` → rewrite-nya wajib **hybrid** (assignment untuk role_code + `user_roles.role_level` untuk level), bukan pengganti total.
- `264_rollback.sql` mengembalikan ACL dengan `REVOKE` eksplisit — **jangan** dihapus barisnya saat menyederhanakan file.
### [2026-10-03] Work Queue sync — A3 (guard CI) + B1 (pecah jadi P1-TABLE-AUDIT) — docs-only

Dokumentasi saja, **tanpa migrasi, tanpa SQL, tanpa `src/`**. Tujuannya hanya §0.9: dua follow-up dari batch 264 tidak boleh hilang dari pandangan.

**2 keputusan user yang didaftarkan:**

- **A3 → masuk `P1-POST-HARDENING-AUDIT` (scope ditambah).** Item itu kini hanya memegang sisi (a) grant yatim **46** fungsi, plus **guard CI otomatis** dengan urutan wajib: **tahap 1 guard (2-3 jam, dahulukan) → tahap 2 checklist audit 46 fungsi → tahap 3 perbaikan per fungsi**. Guard wajib **MERAH** pada 46 fungsi yatim sekarang — guard yang diam adalah guard palsu (kelas bug yang sama seperti `P2-F14-M`).
- **B1 → item baru `P1-TABLE-AUDIT` (P1).** **61 dari 208** tabel RLS tanpa policy SELECT → default-deny, `SELECT` 0 baris untuk semua orang termasuk `admin_pusat` dan owner. DoD-nya **tabel keputusan 61 baris**, **BUKAN** sprint perbaikan teknis, dan helper berikutnya **dilarang** membuka policy SELECT tanpa baris keputusan.

**Kenapa 2 follow-up ini dipisah** (bukan satu item): sifatnya berbeda. Grant yatim ditutup dengan alat yang objektif — ada grant atau tidak, bisa dibuktikan `proacl`, murah, dan selesai dengan guard + checklist. Policy SELECT hilang tidak bisa ditutup dengan asumsi: tabel yang hari ini perlu dibuka mungkin memang harus tertutup, dan itu **keputusan produk per tabel**. Menggabungnya akan memaksa helper mengarang akses untuk 61 tabel sekaligus. Keduanya tetap satu akar historis (whitelist `172`), dan itu dicatat di masing-masing baris.

**Rujukan ID dibersihkan** (tidak ada lagi item yang menunjuk ID yang sudah tidak ada di tabel Work Queue): `P1-ACL-AUDIT` dan `P2-F14-Q` di [AGENTS.md](AGENTS.md) §5.8 + [FORENSIC-INDEX.md](docs/forensic/FORENSIC-INDEX.md) §5.8 + blok P10 + blok CLOSED 263/264 → diarahkan ke `P1-POST-HARDENING-AUDIT` / `P1-TABLE-AUDIT` (nama lama disimpan di satu tempat sebagai catatan, supaya riwayatnya tidak hilang).

**Konstanta baru** di [CONSTANTS-INVENTORY.md](docs/forensic/CONSTANTS-INVENTORY.md) §1.3 + §3 matriks: `61/208` tabel tanpa policy SELECT dan `46` fungsi tanpa `EXECUTE authenticated`, keduanya **TIDAK ADA guard** — itu justru isi item A3 tahap 1.

**Diketahui, sengaja tidak dikerjakan turn ini** (di luar gate 4 file): [FIX14-ROLE-LEVEL-TOTAL.md](docs/forensic/FIX14-ROLE-LEVEL-TOTAL.md) baris 921, 1014, 1106, 1108 masih menyebut `P2-F14-Q` dan `P1-ACL-AUDIT`. Rujukan historis di blok 263/264 itu tidak salah secara fakta, tapi menunjuk ID yang sudah tidak ada di tabel Work Queue. Perlu sapuan singkat di turn dokumentasi berikutnya.

Dampak lintas-page: worker → admin → dashboard → owner **tidak terdampak** — tidak ada perubahan kode, kontrak RPC, RLS, menu, route, maupun design system. Four-page smoke dan E2E `full-sweep` tidak perlu diulang karena tidak ada byte `src/` yang berubah; yang diverifikasi hanya dokumen (`verify:artifacts` + `doc-claims-vs-live`).
## [2026-10-03] Fix #14 §9 batch 265 CLOSED — apply `265_fix14_get_current_user_context_hybrid.sql` (rewire hybrid)

- **Status: CLOSED.** Migrasi `265` DITERAPKAN ke DB live, diverifikasi, di-commit, di-push ke `origin/migrasi-vite`.
- **Berkas migrasi:** `supabase/migrations/265_fix14_get_current_user_context_hybrid.sql` (98 baris, sha256 `da1bb156859f2eca89bed144178ccaf56c5ec69a6778cfe5b69a2c654856482a`) + jalur pemulihan `supabase/scripts/rollback/265_rollback.sql` (81 baris, sha256 `c31fa16726a0c36b16396bb022c04929c9a3acfd70fbd3c3555c62c80f87378a`).
- **Keputusan user:** Opsi B — 265 hanya `get_current_user_context()`. Batch 266 (`get_user_context_by_auth_id` + keputusan B-1/B-2/B-3) terpisah.

### Perubahan (3 hunk, tidak ada yang lain)

Dibuktikan *inverse proof*: body baru dengan 3 hunk dibalik ke bentuk lama **===** pre-image persis (`TRUE`).

1. `DECLARE`: tambah `v_assign_role TEXT;`
2. Setelah `SELECT * INTO v_role FROM user_roles WHERE nrp = v_emp.nrp LIMIT 1;` → `SELECT a.role_code INTO v_assign_role FROM user_role_assignments a WHERE a.nrp = v_emp.nrp ORDER BY a.is_primary DESC NULLS LAST, a.role_code ASC LIMIT 1;`
3. `RETURN`: `'role'` → `COALESCE(v_assign_role, v_role.role, 'worker')`

**Sengaja tidak berubah:** `role_level` tetap `user_roles` (assignment tidak punya kolom level) · owner bypass `check_owner_identity()` dipertahankan · signature `() -> jsonb` + return shape + urutan key · attrs (plpgsql/VOLATILE/SECDEF/`search_path`) · anomali `by_auth_id` (B-1/B-2/B-3) untuk batch 266.

### Bukti apply (mentah)

```
$ node supabase/scripts/apply-migration.mjs 265_fix14_get_current_user_context_hybrid.sql --apply
berkas    : 265_fix14_get_current_user_context_hybrid.sql
versi     : 265
checksum  : da1bb156859f2eca89bed144178ccaf56c5ec69a6778cfe5b69a2c654856482a
status    : DITERAPKAN + terdaftar + checksum terverifikasi (1022ms)
EXIT=0
```

| Uji | Hasil |
|---|---|
| registry | `{"version":"265","filename":"265_fix14_get_current_user_context_hybrid.sql","checksum":"da1bb156..."}` · 190 baris / `max(version)=265` |
| oid | **298319 preserved** (CREATE OR REPLACE — bukan DROP+CREATE, tidak ada window tanpa fungsi untuk 75 caller) |
| attrs | plpgsql · `provolatile='v'` · `prosecdef=true` · `proconfig={"search_path=public, extensions"}` · `ret=jsonb` — preserved |
| ACL | `{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}` preserved · `anon_exec=false` (fail-closed) |
| def/prosrc | 1211 → 1621 · 1032 → 1442 (`md5(def)` `65c9b578...` → `29f0f732...` · `md5(prosrc)` `0227517266...` → `666bf8ef...`) |
| `Functions` | tetap **656** (265 tidak menambah/mengurangi fungsi) |
| prosrc hunks | `v_assign_role`=true · `user_role_assignments`=true · `COALESCE(v_assign_role, v_role.role`=true · blok lama `COALESCE(v_role.role, 'worker')`=**false** · `check_owner_identity()`=true |

### C1 — netralitas 8/8 byte-identik (post-apply vs baseline pre-265)

```
PASS  C1 NRP001     byte-identik
PASS  C1 NRP002     byte-identik
PASS  C1 NRP100     byte-identik
PASS  C1 NRP101     byte-identik
PASS  C1 NRP102     byte-identik
PASS  C1 NRP105     byte-identik
PASS  C1 OWNER      byte-identik
PASS  C1 ZERO_UUID  byte-identik

PASS  C2 owner is_owner=true role=owner level=5 nrp=OWNER001 bu=null  {"nrp":"OWNER001","nama":"System Owner","role":"owner","email":"owner@insightwos.com","is_owner":true,"role_level":5,"business_unit_id":null}
PASS  C3 NRP001 role='admin_pusat' role_level=5  {"nrp":"NRP001","nama":"CEO InsightWOS","role":"admin_pusat","email":"ceo@insightwos.com","is_owner":false,"role_level":5,"business_unit_id":"BU04"}
PASS  C4 NRP002 role='worker' role_level=1  {"nrp":"NRP002","nama":"Worker NRP002","role":"worker","email":"nrp002@insightwos.internal","is_owner":false,"role_level":1,"business_unit_id":"BU04"}

===== RINGKASAN: SEMUA PASS =====
```

Kenapa netral: 17/17 `user_role_assignments.role_code` identik dengan `user_roles.role`; 0 user dengan >1 assignment (ORDER BY deterministik); 0 `user_roles` tanpa assignment dan 0 assignment tanpa `user_roles`.

### Simulasi pra-apply (30/30 PASS)

| Uji | Hasil |
|---|---|
| D1a pre-image live === file pre-image | PASS |
| D2a/D2a2 def+prosrc post-apply === expected | PASS |
| D2b oid preserved | PASS (298319 → 298319) |
| D2c/D2d attrs + ACL preserved | PASS |
| D2e/D2f anon=false / authenticated=true | PASS |
| D2g def_len 1211 → 1621 (+410) | PASS |
| D4a-D4g rollback byte-identik + ACL + oid + def/prosrc vs file | PASS (`29f0f732...` → `65c9b578...`) |
| D5 `schema_migrations` tidak tersentuh | PASS |
| D7 state live kembali pre-265 setelah ROLLBACK | PASS |
| E5 read-path proof | PASS — assignment NRP002 → `admin_estate` ⇒ `role` ikut berubah; `role_level` tetap 1; restore ⇒ byte-identik |

### Gate

- `npm run verify:artifacts` — pra-sync: 1 drift (`Migrations tracked dok=189 live=190`), pasca-sync: **0 drift, EXIT 0**.
- `npm run check:types` — **EXIT 0**.
- `npm test` — pra-sync: 25/26 files (1 gagal = `doc-claims-vs-live` menuntut sync dokumen, ekspektasi); pasca-sync: **26/26 files, 170 passed | 4 todo**.
- Dry-run wrapper: EXIT 0, `status: belum terdaftar`, checksum cocok.

### Work Queue

3 item baru terdaftar (P2-F14-S, P2-F14-T, P3-F14-U) — semua untuk batch 266:

- **P2-F14-S** — `get_user_context_by_auth_id()` fungsi "get" tapi **menulis**: `UPDATE employees_master SET auth_id = p_auth_id` (SECURITY DEFINER, privilege escalation surface).
- **P2-F14-T** — `by_auth_id` tanpa owner bypass → owner dapat `{"ok":false,...}`; `Home.tsx:328` memakainya.
- **P3-F14-U** — field mati `divisi`/`posisi` di `initSession` (`get_current_user_context` tidak mengembalikannya).

### Pelajaran proses (2 baru dari turn ini)

1. **Komparator byte-identik wajib pakai teks in-tag, bukan line-slice** (perluasan P7/P13). `pg_get_functiondef()` mengembalikan trailing `\n`; `prosrc` adalah teks **di antara** tag dollar-quote termasuk newline pembuka+penutup. Ekstraksi line-slice kehilangan tepat 2 byte → `md5(prosrc)` beda walau isi identik → 3 FAIL palsu di simulasi. Gate yang benar: `def` vs file+`\n`, dan `prosrc` vs regex `/\\$function\\$([\\s\\S]*)\\$function\\$/`. Setelah dibetulkan: 30/30 PASS.
2. **`String.replace(old, newString)` berbahaya untuk konten markdown — wajib function replacer.** Replacement string JS memperlakukan `$&`, `` $` ``, `$'`, `$1` sebagai pola substitusi. Teks yang memuat `` `$function$` `` berakhiran `` $` `` = "seluruh prefix match" → seluruh isi file tersuntik ke tengah → **file terduplikasi** (`FIX14-ROLE-LEVEL-TOTAL.md` 1125 → 2239 baris, `FORENSIC-INDEX.md` 429 → 549). Tidak terlihat di diff singkat. Kerusakan ditemukan sebelum commit dan dipulihkan dengan `git checkout --`; tidak ada byte korup yang masuk commit. Aturan: `s.replace(old, () => newS)`.

### Dampak lintas-page: worker → admin → dashboard → owner TIDAK berubah

Rewiring ini **nilai-netral** dan dibuktikan begitu: 8 kasus baseline (worker NRP002 · admin NRP100/101/102/105 · CEO NRP001 · owner · uuid nol) byte-identik pre vs post. Tidak ada perubahan `src/`, kontrak RPC, RLS, menu, route, design system. `role` yang dibaca frontend tetap nilai yang sama; choke point `entryFromRole` (`supabase-browser.ts:138-143`) menerima input identik. Owner bypass — satu-satunya perlindungan owner (tidak punya baris `user_roles`/`user_role_assignments`) — terverifikasi hidup. Four-page smoke dan E2E tidak diulang karena tidak ada byte `src/` yang berubah; yang diverifikasi adalah DB + dokumen.
### Addendum (pasca-commit `0e2f6b3`)

Gate pertama pasca-sync ternyata masih merah satu kali: skrip sync dokumen v2 menempel Fact 265 ke sel tabel §7.4 **tetapi tidak mengubah angka** `| Migrations tracked | 189 |` di depan sel — `verify:artifacts` membaca angka itu, jadi dok=189 vs live=190. Fix: edit langsung angka `189 → 190` (CRLF-preserving, diff tepat 1 baris). Hasil mentah setelah fix:

- `verify:artifacts` pra-push: **0 drift, 1 warning** (WARN baseline = Fix #9, infosional).
- `verify:artifacts` pasca-push: **0 drift**; `migration rows 190`, `max(version) 265`, `Tables 209`, `Functions 656`, `RLS policies 225`, `anon grants 130`.
- `npm test` pasca-sync: **26/26 files, 170 passed | 4 todo (174)**.
- Commit `0e2f6b3` (8 file, 375+/6−) + push `e854658..0e2f6b3`; `git status` bersih.

**Pelajaran P14** — sync berbasis replacement **tidak boleh** divalidasi dengan "skrip exit 0". Skrip v2 sukses, 0 duplikasi, 0 lone CR, dan tetap meninggalkan dokumen **tidak sinkron** karena target replacement-nya memilih pola yang tidak memuat angka tabel §7.4. Pintu yang benar: rerun gate (**`verify:artifacts`** harus hijau) barulah sync dianggap selesai — kelas bug yang sama dengan P8 (jumlah fungsi hijau ≠ atribut fungsi benar). Untuk sync berikutnya: assert `dok == live` per metrik, bukan hanya keberhasilan skrip.

Dampak lintas-page: worker → admin → dashboard → owner **tidak terdampak** — addendum hanya mencatat temuan proses + bukti gate; tidak ada byte `src/`, DB, RPC, RLS, menu, route, atau design system yang berubah.
## [2026-10-04] Fix #14 §9 batch 266 CLOSED — apply `266_fix14_by_auth_id_rewire_and_cleanup.sql` (rewire `by_auth_id` + hapus auto-repair UPDATE) + U1a

- **Status: CLOSED.** Migrasi `266` DITERAPKAN ke DB live, diverifikasi, di-commit, di-push ke `origin/migrasi-vite`.
- **Berkas migrasi:** `supabase/migrations/266_fix14_by_auth_id_rewire_and_cleanup.sql` (92 baris, sha256 `22c370546ad6bc9a7fecaf3cfab9b8d18852cf005cc138289b3268655d44d3a9`) + jalur pemulihan `supabase/scripts/rollback/266_rollback.sql` (76 baris, sha256 `8d5985751b894f6a886bb5a2ac1d5531d59c0409730139f48b35d01bc5c57af0`).
- **Keputusan user:** **S1** (hapus blok `UPDATE`), **T2** (owner tetap by-design — tanpa bypass di `by_auth_id`), **U1a** (hapus 4 field interface `divisi?`/`posisi?`). Ini batch terakhir §9 rewiring; 267 (OTP), 268 (matrix+set_role) menyusul.

### Perubahan (4 hunk, tidak ada yang lain)

Dibuktikan *inverse proof*: body baru dengan 4 hunk dibalik ke bentuk lama **===** pre-image persis (`TRUE`).

1. `DECLARE`: tambah `v_assign_role TEXT;`
2. **Hapus** blok `IF FOUND THEN UPDATE employees_master SET auth_id = p_auth_id WHERE nrp = v_emp.nrp; END IF;` — satu-satunya jalur tulis di fungsi "get" (S1/P2-F14-S); fallback baca via email TETAP (SELECT tanpa efek tulis).
3. Tambah `SELECT a.role_code INTO v_assign_role FROM user_role_assignments a WHERE a.nrp = v_emp.nrp ORDER BY a.is_primary DESC NULLS LAST, a.role_code ASC LIMIT 1;`
4. `RETURN`: `'role'` → `COALESCE(v_assign_role, v_role.role, 'worker')`

**Sengaja tidak berubah:** `role_level` / `bu` / `unit_code` / `tier` / `divisi` / `jabatan` · signature `(p_auth_id uuid) -> jsonb` + urutan key · attrs (plpgsql/VOLATILE/SECDEF/`search_path`) + ACL · **tanpa** owner bypass (T2 — owner lewat `OwnerLogin`; `by_auth_id` tetap `{"ok":false}` untuk owner, `Home.tsx` tidak diubah).

### Bukti apply (mentah)

```
$ node supabase/scripts/apply-migration.mjs --apply --file supabase/migrations/266_fix14_by_auth_id_rewire_and_cleanup.sql
berkas    : 266_fix14_by_auth_id_rewire_and_cleanup.sql
versi     : 266
checksum  : 22c370546ad6bc9a7fecaf3cfab9b8d18852cf005cc138289b3268655d44d3a9
status    : DITERAPKAN + terdaftar + checksum terverifikasi (1230ms)
EXIT=0
```

| Uji | Hasil |
|---|---|
| B3 registry | `{"version":"266","filename":"266_fix14_by_auth_id_rewire_and_cleanup.sql","checksum":"22c37054..."}` |
| B4 oid | **298467 preserved** (CREATE OR REPLACE — bukan DROP+CREATE) |
| B5 attrs | plpgsql · `provolatile='v'` · `prosecdef=true` · `proconfig=["search_path=public, extensions"]` · `ret=jsonb` — preserved |
| B5 ACL | `{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}` · `auth=true anon=false svc=true` |
| B6 prosrc | `v_assign_role`=true · `user_role_assignments`=true · `UPDATE employees_master`=**false** · `md5(def)` `9cf05457...` · `md5(prosrc)` `c19ec787...` · def 1666→1922 · prosrc 1470→1726 |
| B7 registry | count=**191** · `max(version)=266` |
| `Functions` | tetap **656** (266 tidak menambah fungsi) |

### C1 — netralitas 8/8 byte-identik (post-apply vs baseline pre-266)

```
PASS  NRP001    ctx={"ok": true, "nrp": "NRP001", ... "role": "admin_pusat", "role_level": 5, ...}
PASS  NRP002    ctx={"ok": true, "nrp": "NRP002", ... "role": "worker", "role_level": 1, ...}
PASS  NRP100    ctx={"ok": true, "nrp": "NRP100", ... "role": "admin_pusat", "role_level": 3, ...}
PASS  NRP101    ctx={"ok": true, "nrp": "NRP101", ... "role": "admin_hrd", "role_level": 3, ...}
PASS  NRP102    ctx={"ok": true, "nrp": "NRP102", ... "role": "admin_finance", "role_level": 3, ...}
PASS  NRP105    ctx={"ok": true, "nrp": "NRP105", ... "role": "admin_mill", "role_level": 3, "unit_code": "MILL", ...}
PASS  OWNER     ctx={"ok": false, "msg": "Akun tidak ditemukan. Email: owner@insightwos.com"}
PASS  ZERO_UUID ctx={"ok": false, "msg": "Akun tidak ditemukan. Email: null"}
PASS  C1 netralitas — 8/8 byte-identik
```

### C2 — uji S1: auto-repair mati + C1c dampak

NRP002 `auth_id=NULL` di dalam tx, lalu panggil `by_auth_id` dengan `auth_id` aslinya:

```
{
  "call_ctx_text": "{\"ok\": true, \"nrp\": \"NRP002\", ... \"role\": \"worker\", \"role_level\": 1, ...}",
  "auth_id_sebelum_rollback_master": null,
  "auth_id_sebelum_rollback_core": null,
  "repaired": false,
  "ctx_identik_dengan_baseline_NRP002": true
}
PASS  C2 auto-repair MATI — repaired=false (auth_id tetap NULL di dalam tx)
PASS  C2 baca tetap utuh — ctx identik baseline NRP002
PASS  C2 rollback utuh — auth_id pasca-rollback=55f100d8-c215-435c-942a-d2502e5119d7
```

Catatan jujur: ekspektasi awal prompt (`{"ok":false}`) terlalu kuat — fallback **baca** via email memang tetap ada; delta S1 yang benar adalah hilangnya **efek tulis** (inilah yang diuji `repaired=false`), dan itu persis hasil G2 dry-run. C1c: **0 baris** `employees_master` email-match `auth.users` dengan `auth_id` beda → jalur UPDATE tidak terjangkau pada data sekarang; 1 `auth.users` tanpa employee link = owner (T2, memang tidak lewat `by_auth_id`).

### U1a — hapus field mati (kode)

- `src/lib/supabase-browser.ts`: 2 baris `divisi: data.divisi,` / `posisi: data.posisi,` dihapus (diff 2 deletions).
- `src/types/index.ts`: 4 field `divisi?`/`posisi?` dihapus dari `UserSession` + `CurrentUserContext` (diff 4 deletions).
- `git grep session.divisi|session.posisi|data.divisi|data.posisi` = **0 hit**; satu-satunya `s.divisi` (`OwnerDashboard.tsx:709`) = baris data list, bukan `UserSession`.
- `npm run check:types` — **EXIT 0**.

### Simulasi pra-apply + dry-run

- Simulasi rollback: `md5(def)` `13afaf04…` → `9cf05457…` → `13afaf04…` byte-identik; oid + ACL preserved + auth/anon/svc = true/false/true; registry 190/265 tidak tersentuh; audit 587→587→587.
- Dry-run wrapper: EXIT 0, "belum terdaftar", checksum cocok — dijalankan sebelum apply.

### Gate

- `npm run verify:artifacts` — pra-sync: 1 drift (`Migrations tracked dok=190 live=191`, ekspektasi); pasca-sync: **0 drift, 1 warning (baseline commit = Fix #9, infosional), EXIT 0** (Migrations tracked 191 · max(version) 266 · Functions 656).
- `npm run check:types` — **EXIT 0**.
- `npm test` — pra-sync: 25/26 files (1 gagal = `doc-claims-vs-live` menuntut sync dokumen, ekspektasi); pasca-sync: **26/26 files, 170 passed | 4 todo**, EXIT 0.

### Work Queue

- **P2-F14-S** → ✔ CLOSED (migrasi 266) — blok `UPDATE` dihapus; C2 sintetis membuktikan auto-repair mati.
- **P2-F14-T** → ✔ CLOSED (keputusan T2) — by-design: owner lewat `OwnerLogin`; `by_auth_id` tetap `{"ok":false}` untuk owner.
- **P3-F14-U** → ✔ CLOSED (266 + U1a) — 2 baris `initSession` + 4 field interface dihapus; 0 konsumen.
- **P2-F14-V** (baru, P2) — `employees_master`/`employees_core` **tidak punya trigger audit**: probe 2026-10-04 → `employees_master` hanya `trg_employees_master_{insert,update,delete}` (sync, `prosrc` tanpa `audit_log`), `employees_core` 0 trigger, **0** `trg_audit_*` (21 tabel lain punya). DoD: pasang `trg_audit` via `_generic_audit_trigger_fixed` (pola Fix #4) + uji INSERT/UPDATE.

### Pelajaran proses

1. **D2 — hapus field "mati" hanya sah setelah membaca interface-nya.** Asumsi awal (dari laporan 265): `UserSession` tidak punya `divisi?`/`posisi?` sehingga cukup bersihkan `initSession`. Fact live: kedua field MEMANG ada di `UserSession` + `CurrentUserContext` — perbaikan yang benar = hapus 2 baris `initSession` **dan** 4 field interface (keputusan user U1a). Verifikasi grep konsumen sebelum menghapus: 0 hit.
2. **P14 diformalkan ke AGENTS.md §5.8** (berasal dari sync 265): sync dokumen tidak sah divalidasi oleh exit-code skrip pengganti; `verify:artifacts` (+ `doc-claims-vs-live`) wajib dijalankan ulang **setelah sync dan sebelum commit**. Batch ini memperkuatnya: test doc-claims memang merah sampai ARCHITECTURE.md disinkronkan, dan hijau hanya setelah gate dijalankan.

### Dampak lintas-page: worker → admin → dashboard → owner TIDAK berubah

Rewiring ini **nilai-netral** dan dibuktikan begitu: 8 kasus baseline (worker NRP002 · admin NRP100/101/102/105 · CEO NRP001 · owner · uuid nol) byte-identik pre vs post. Worker: `role=worker` identik. Admin: keempat NRP admin identik (`Home.tsx:328` menerima JSON yang sama). Dashboard/CEO: NRP001 identik (`admin_pusat`, level 5). Owner: alur `OwnerLogin` tidak berubah; `by_auth_id` tetap `{"ok":false}` untuk owner (T2 by-design, perilaku sama seperti sebelum 266). U1a hanya menghapus field yang **terbukti selalu `undefined`** (0 konsumen, `check:types` EXIT 0); kontrak `entryFromRole`/session tidak berubah. Tidak ada perubahan RLS, menu, route, design system. Four-page smoke/E2E tidak diulang karena tidak ada perubahan perilaku `src/` yang dapat diamati (yang berubah hanya dua baris objek sesi yang nilainya selalu undefined + tipe field yang tidak dipakai).
## [2026-10-05] Fix #14 §9 batch 267 CLOSED — apply `267_fix14_otp_rewire_wildcard.sql` (rewire OTP `verify_admin_otp_core` + `generate_admin_otp`; wildcard `admin\_%` escaped + override assignment E2)

- **Status: CLOSED.** Migrasi `267` DITERAPKAN ke DB live, diverifikasi (B3–B7 + C1–C3), docs disinkronkan, di-commit, di-push ke `origin/migrasi-vite`. **Batch 5/5 §9 rewiring → §9 rewiring tuntas (5/5 batch).** Sisa §9 = batch 268 (`admin_get_role_matrix` + `admin_set_employee_role`).
- **Commit:** (diisi setelah commit) · **Branch:** `migrasi-vite` · **HEAD sebelum:** `399061c`
- **Berkas migrasi:** `supabase/migrations/267_fix14_otp_rewire_wildcard.sql` (206 baris, LF, sha256 `553ed3adb898ffcdb846c70d811629e0052fd5b48e19e7083ce16a181273316b`, tanpa `BEGIN`/`COMMIT` — P4) + jalur pemulihan `supabase/scripts/rollback/267_rollback.sql` (161 baris, LF, sha256 `9fb026fa8580cd8af202761794b9b9c3f940a2897fe209968f1fe6e94599500f`, pre-image byte-exact + ACL restore).
- **Konteks:** dua fungsi OTP `verify_admin_otp_core(p_code text)` + `generate_admin_otp()` = RPC #7–#8 rencana §9b. Selain rewiring sumber role (hybrid assignment + fallback `user_roles`), 267 menutup **celah wildcard**: gerbang lama memakai `LIKE 'admin_%'` polos — di `LIKE`, `_` = wildcard 1 karakter, sehingga role generik `'admin'` LOLOS gate (terbukti T5 pra-267). Pola baru **escaped** `admin\_%` (kanon migrasi `263:81`). **E2**: gate `generate_admin_otp` memakai `SELECT CASE` — assignment menang, fallback `user_roles` menahan instalasi baru tanpa assignment (simetris `COALESCE` di verify).

### Perubahan (5 hunk, tidak ada yang lain)

Dibuktikan *inverse proof*: body baru dengan 5 hunk dibalik ke bentuk lama **===** pre-image persis (`TRUE`).

1. `verify_admin_otp_core` `DECLARE`: tambah `v_assign_role TEXT;`
2. Tambah `SELECT a.role_code INTO v_assign_role FROM user_role_assignments a WHERE a.nrp = v_nrp ORDER BY a.is_primary DESC NULLS LAST, a.role_code ASC LIMIT 1;`
3. Gate `verify_admin_otp_core`: `v_role.role` → `COALESCE(v_assign_role, v_role.role)`; whitelist `... <> 'owner' AND ... NOT LIKE 'admin\_%'`
4. `RETURN` `verify_admin_otp_core`: `'role'` → `COALESCE(v_assign_role, v_role.role, 'admin_pusat')` (fallback dipertahankan)
5. Gate `generate_admin_otp`: `SELECT CASE WHEN EXISTS(assignment utk v_nrp) THEN EXISTS(assignment role_code LIKE 'admin\_%') ELSE EXISTS(user_roles owner|admin\_%) END INTO v_is_admin;`

**Sengaja tidak berubah:** signature `(p_code text)` / `()` + rettype `jsonb` + urutan key · attrs (plpgsql/VOLATILE/SECDEF/`search_path=public, extensions`) + ACL · wrapper publik `verify_admin_otp` + **grant anon pra-sesi** (dari migrasi 231, sengaja — `Home.tsx:361`/`:468` memanggil SEBELUM sesi ada; 267 hanya menyasar `_core`/`generate`) · fallback `'admin_pusat'` di RETURN verify · `role_codes`/assignments/`user_roles` tidak disentuh.

### Bukti apply (mentah)

```text
$ node supabase/scripts/apply-migration.mjs --apply --file supabase/migrations/267_fix14_otp_rewire_wildcard.sql
berkas    : 267_fix14_otp_rewire_wildcard.sql
versi     : 267
checksum  : 553ed3adb898ffcdb846c70d811629e0052fd5b48e19e7083ce16a181273316b
status    : DITERAPKAN + terdaftar + checksum terverifikasi (1022ms)
PIPESTATUS=0
```

Post-apply B3–B7 (`.agents/logs/fix14-267b-verify-apply.log` / `.json`, verdict **ALL PASS 14/14**):

| Uji | Hasil |
|---|---|
| B3 registry | `{"version":"267","filename":"267_fix14_otp_rewire_wildcard.sql"}` |
| B4 oid | **298610** (verify, `p_code text`) + **298267** (generate, `''`) **preserved** (CREATE OR REPLACE — bukan DROP+CREATE) |
| B5 attrs | plpgsql · `provolatile='v'` · `prosecdef=true` · `proconfig=["search_path=public, extensions"]` · `ret=jsonb` — preserved |
| B5 ACL | `{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}` · `auth=true anon=false svc=true` (keduanya) |
| B6 prosrc verify | `v_assign_role`=true · escaped `admin\_%`=true · `LIKE 'admin%'` polos=**false** · `md5(def)` `5ec65ec8…` → `bcdfbaee5933a7a15ec3587b95f45211` (== ekspektasi simulasi) · def 2438→2893 · prosrc 2251→2706 |
| B6 prosrc generate | `SELECT CASE`=true · escaped×3 · `LIKE 'admin%'` polos=**false** · `md5(def)` `0605759c…` → `cf00922d1c642b83129e433d354c49a9` (== ekspektasi simulasi) · def 2320→2817 · prosrc 2147→2644 |
| B7 registry | count=**192** · `max(version)=267` |
| `Functions` | tetap **656** (267 tidak menambah fungsi) |

### C1–C3 — netralitas 5/5 + wildcard fix + zero residue (post-apply via call-based, tx ROLLBACK)

```
C1 netralitas 5/5 byte-identik vs baseline pre-267 (.agents/logs/fix14-267-baseline-call.json):
   NRP001 PASS (admin_pusat) · NRP100 PASS (admin_pusat) · NRP105 PASS (admin_mill)
   NRP002 REJECT ("Akses ditolak." / "Kode OTP admin tidak valid") · OWNER PASS (OWNER001)
C2 T5 wildcard: role generik 'admin' TANPA assignment → pra-267 generate=true verify=true (LOLOS)
   → pasca-267 generate=false verify=false (REJECT)   ← inti DoD 267
C2 T6 override: assignment admin_pusat + user_roles 'worker' → pra DITOLAK → pasca PASS (assignment dibaca)
C2 T7 basi:    assignment worker + user_roles 'admin_pusat' → pra LOLOS → pasca REJECT
C3 regression: NRP100 identik simulasi · P9 nol residu (koneksi baru setelah ROLLBACK):
   audit_log 587 · otp_store 0 · otp_attempts 0 · session_tokens 357
VERDICT ALL PASS (.agents/logs/fix14-267c-postapply-call.log / .json)
```

### Simulasi pra-apply + dry-run (sebelum apply)

- Simulasi satu tx (F/G): rollback byte-identik (`F4 TRUE`), oid + ACL + attrs preserved di 3 stage, registry 191/266 tidak tersentuh, G1 netralitas 5/5, T5 fix terbukti, P9 zero residue (`.agents/logs/fix14-267f-simulasi.log` / `.json`).
- Dry-run `apply-migration.mjs` (mode default): checksum `553ed3ad…` · status "belum terdaftar" · EXIT 0.

### Gate

- `npm run verify:artifacts` — pra-sync: 1 drift (`Migrations tracked dok=191 live=192`, ekspektasi); **pasca-sync: 0 drift, 1 warning (baseline commit = Fix #9, infosional), EXIT 0** (Migrations tracked 192 · max(version) 267 · Functions 656).
- `npm run check:types` — **EXIT 0**.
- `npm test` — pra-sync: 26 file total (25 passed, 1 gagal = `doc-claims-vs-live` menuntut sync 191→192, ekspektasi); **pasca-sync: 26/26 files, 170 passed | 4 todo, EXIT 0**.

### Work Queue

- Tidak ada item Work Queue baru dari batch ini (267 adalah item rencana §9b #7/#8, bukan temuan audit baru).
- Tidak ada item OPEN yang tertutup karena 267: **P3-F05-06** (`login_otp` edge function — jalur lain), **P1-POST-HARDENING-AUDIT** (46 fungsi tanpa grant — kedua fungsi 267 terbukti `auth=true`), **P2-F14-V** (audit trigger `employees_master`/`employees_core` — belum dikerjakan). Status item queue di AGENTS.md §5.8 tidak diubah selain blok CLOSED 267.

### Pelajaran proses

1. **P15 — wildcard `_` di `LIKE` yang lolos review.** `LIKE 'admin_%'` "terlihat sama" dengan `LIKE 'admin\_%'` tapi artinya beda satu karakter: `_` = wildcard 1 karakter vs literal underscore — role generik `'admin'` karena itu LOLOS gate OTP sejak lama. **Aturan turunan:** setiap whitelist pola role di `LIKE` wajib escaped + punya uji negatif sintetis (role generik tanpa assignment → REJECT).
2. **P7 tepat lagi:** pre-image/functiondef diambil dari sisi server; komparator byte-identik pakai ekstraksi in-tag `/\$function\$([\s\S]*)\$function\$/`; gate kunci ke **signature**, bukan `oid` (P13). Kelas bug P12 (rollback DROP wajib restore ACL) tidak terulang: 267 CREATE OR REPLACE + rollback menyertakan ACL restore dan disimulasikan.

### Dampak lintas-page: worker → admin → dashboard → owner TIDAK berubah

Rewiring nilai-netral **dan** dibuktikan byte-exact: 5 kasus baseline pre vs post identik pada dua fungsi yang hidup di jalur login. **Worker** — `NRP002` tetap REJECT (worker tidak lewat gate OTP admin; login worker harian via `login_worker` tidak disentuh). **Admin** — NRP100/105 identik (tab admin via OTP tetap sama). **Dashboard/CEO** — NRP001 identik (`admin_pusat`). **Owner** — OWNER identik; `OwnerLogin` tidak memakai kedua fungsi ini, cabang `'owner'` di verify tidak berubah. **Wildcard fix hanya menutup celah hipotetis**: role generik `'admin'` **0 baris** di `user_roles` maupun `user_role_assignments`, jadi tidak ada user nyata yang kehilangan akses; `role_codes` menganggap `'admin'` reserved non-aktif. Tidak ada perubahan RLS, menu, route, design system, kontrak session/entry. E2E 4-page tidak diulang karena 0 perubahan perilaku `src/` yang dapat diamati.

**Signature: Batch 267 CLOSED. §9 rewiring tuntas (5/5 batch). Batch 268 (matrix + set_role) = penutup §9.**
