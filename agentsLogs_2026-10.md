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
