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
