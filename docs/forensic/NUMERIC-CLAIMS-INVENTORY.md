# NUMERIC-CLAIMS-INVENTORY — Fase-1 Level B

> **Status: Fase-1 DI-APPROVE user (2026-10-09) — di-commit; 3 kasus (e) PENDING Fase-2.**
> Baseline: `7ada2d0` (270C CLOSED, CI #56 hijau). Ditulis: 2026-10-09. Mode: READ-ONLY.
> Data mentah: `.agents/reports/numeric-claims-raw.txt` (gitignored, dihasilkan
> `.agents/scripts/scan-numeric-claims.mjs` — dedup per `file:line`, satu jenis per baris,
> pola "nomor bagian (7.3, 1.1, §3.10)" dan versi postgres BUKAN klaim dan tidak dihitung).

## 0. Ringkasan

- **24 file .md tracked** (0 untracked): **17 file status** (di-scan) + **7 file arsip**
  (`agentsLogs*.md` x4, `FIX14-ROLE-LEVEL-TOTAL.md`, `FORENSIC-INDEX.md`,
  `.agents/skills/agent-browser/SKILL.md` — dua terakhir ada di `git ls-files` walau
  `.agents/` di-gitignore, karena memang pernah ter-track).
- **141 klaim** terdeteksi scanner kanonik + **5 klaim tambahan** teridentifikasi manual
  (pola noun-first seperti `| Tables | 209 |`, `supabase/migrations/` `(157 berkas)`, [snapshot:7ada2d0]
  `FORENSIC-INDEX` duplikat) = **146 klaim** di file status. < 200 (lolos ambang).
- **20 jenis** pola mentah scanner — **tepat di ambang STOP (>20)**; jenis yang benar-benar
  butuh registry (turunan live, kategori a+b+d) = **~16**. Rekomendasi: terima sebagai satu
  Fase-1, lihat §6.
- **False positive yang dikecualikan dari hitungan**: nomor bagian `### 7.3`, `§3.10`,
  versi `postgres 17.6`, angka contoh di aturan (`0 error` sebagai spesifikasi gate),
  nomor baris tabel (`baris 2/3/4/10`).

### Distribusi kategori

| Kategori | Jumlah klaim | Keterangan |
|---|---|---|
| **(a) KLIM LIVE + ADA GUARD** | **14** | ARCHITECTURE §7.1/§7.3/§7.4/§7.5, FuturePlans §1.3 (3), SECURITY §3.10 |
| **(b) KLIM LIVE + TANPA GUARD** | **6** | TARGET UTAMA Level B — lihat §2 |
| **(c) ARSIP / HISTORIS / TARGET** | **~118** | whitelist eksplisit — lihat §3, JANGAN di-guard |
| **(d) SNAPSHOT EXTERNAL** | **4** | hasil run/CI — lihat §4 |
| **(e) AMBIGU** | **3 kasus** | butuh keputusan user — lihat §5 |

## 1. Tabel per jenis angka

| # | Jenis | Lokasi (file:baris) | Klaim mentah | Cara ambil live | Guard existing | Kategori |
|---|---|---|---|---|---|---|
| 1 | TS total/src/tests/config | ARCHITECTURE.md:122 | 215 (157 src + 50 tests + 8 config) | `git ls-files` + filter ekstensi | `verify:artifacts` + `doc-claims-vs-live` | (a) |
| 2 | Unit test total + berkas | ARCHITECTURE.md:145 | 189 test total (185+4 todo), 27 berkas | regenerasi JSON vitest resmi | `verify:test-count` | (a) |
| 3 | unit N/N (gate) | SECURITY.md:30 | unit 189/189 | sama dengan #2 | `doc-claims-vs-live` §3.10 | (a) |
| 4 | Tables | ARCHITECTURE.md:131, 73; FuturePlans.md:40 | 209 (210 + view) | `pg_class` relkind r/p non-partisi | `verify:artifacts` + `doc-claims` | (a); duplikat CONSTANTS-INVENTORY:19 **208 STALE** -> (b) |
| 5 | Functions | ARCHITECTURE.md:132, 73; FuturePlans.md:41 | 657 | `pg_proc` | keduanya | (a) |
| 6 | Overloads | ARCHITECTURE.md:132; FuturePlans.md:44 | 19 | `pg_proc HAVING count>1` | `doc-claims` | (a) |
| 7 | Migrations tracked | ARCHITECTURE.md:133 | 195 | `schema_migrations` count | `verify:artifacts` + `doc-claims` | (a) |
| 8 | max(version) | ARCHITECTURE §7.5 (via `verify:artifacts`) | 270 | `schema_migrations MAX(version)` | `verify:artifacts` | (a); duplikat FORENSIC-INDEX:68-69 (max 254) [snapshot:7ada2d0] -> (e) |
| 9 | RLS policies | ARCHITECTURE.md:134 | 225 | `pg_policies` | keduanya | (a) |
| 10 | Tabel belum FORCE | ARCHITECTURE.md:134 | 10 | `pg_class.reloverowsec` | keduanya | (a) |
| 11 | anon/PUBLIC grants | ARCHITECTURE.md:136 | 130 | `pg_proc.proacl` | keduanya | (a) |
| 12 | pg_cron jobs | ARCHITECTURE.md:137 | 5 | `cron.job` | keduanya | (a) |
| 13 | SECDEF search_path violations | ARCHITECTURE.md:135 | 0 | `pg_proc.proconfig` | `doc-claims` | (a); duplikat FuturePlans.md:42 TANPA guard -> (b) |
| 14 | Audit chain rows | ARCHITECTURE.md:138 | 526 (counter bertumbuh) | `count(*) audit_log` | `doc-claims` mode `>=` | (a); FuturePlans.md:45 "44 rows" -> (e) |
| 15 | Rollback scripts | SECURITY.md:61 | 18 scripts (183-214) | `git ls-files supabase/scripts/rollback` | **TIDAK ADA** | (b) |
| 16 | Jumlah file migrasi di folder | SECURITY.md:3.15 (baris "157 berkas") | 157 | `git ls-files supabase/migrations/*.sql` | **TIDAK ADA** | (b) |
| 17 | Hasil E2E | ARCHITECTURE.md:146 | 4/4 passed | run `tests/e2e/four-page-smoke` | tidak ada (external) | (d) |
| 18 | Lint errors | ARCHITECTURE.md:147 | 0 errors | `npm run lint` | CI (bukan guard docs) | (d) |
| 19 | Ukuran (bundle/backup/baseline) | AGENTS.md:5,224; baseline/README:14,67-68 | 57 KB, 144,5 kB, +/-1,6 MB | build output / ukuran file | `verify:backup-artifact` (backup saja) | (c)/(d) |
| 20 | Persen KPI/coverage | FuturePlans.md:24,898-899,986-1010,1128-1130 | 80-100% | n/a (TARGET, bukan kondisi live) | tidak perlu | (c) |
| 21 | Bukti Work Queue (query per item) | AGENTS.md:268-301,376-384 | 61 dari 208, 46 fungsi, 519/526, 272 grant, 102/105 | query per item saat audit (sudah dijalankan, ber-tanggal) | `work-queue-consistency` (struktur item saja, bukan angka) | (c) |
| 22 | Snapshot baseline/install | supabase/baseline/*.md:24,35,97,106-107 | 208 tabel, 155 menu, 61 baris | n/a (output log sekali jalan) | keputusan existing: TIDAK dijaga (CONSTANTS-INVENTORY:102) | (c) |
| 23 | Duplikat katalog klaim | CONSTANTS-INVENTORY.md:19,28,29 | 208 / 214 (157+49+8) / 173+26 berkas | salinan dari #1 dan #2 | **TIDAK ADA** — dan **ketiganya sudah STALE saat Fase-1 ini ditulis** | (b) |
| 24 | Angka riwayat prose | AGENTS CLOSED/Dipangkas; OPEN_WORK; MIGRATION_GUIDE:34; TESTING_GUIDE:15,47; ENVIRONMENT_TRAPS:30 | registry 185..195, max 260..270, 51/64, 146 migrasi, dst. | n/a (pernah diverifikasi pada tanggalnya) | tidak perlu | (c) |

## 2. (b) KLIM LIVE + TANPA GUARD — TARGET UTAMA Level B

| P | Klaim | Bukti | Definition of Done (indikasi) |
|---|---|---|---|
| P1 | `CONSTANTS-INVENTORY.md:19/28/29` menyalin nilai guarded tapi **sudah basi** (208 vs live 209; 214/49 vs 215/50; 173/26 vs 189/27) | dibaca 2026-10-09 vs ARCHITECTURE:131/122/145 yang hijau | baris katalog diambil dari registry (generated) atau di-guard; 0 drift |
| P2 | `SECURITY.md` "157 berkas" migrasi | SECURITY.md §3.15; live `git ls-files supabase/migrations/*.sql` | dijaga `doc-claims`/registry; drift merah saat migrasi baru |
| P3 | `SECURITY.md:61` "18 scripts (183-214)" rollback | CONSTANTS-INVENTORY:101 sudah menandai TANPA guard | idem |
| P4 | `FuturePlans.md:42` "Search Path Violations: 0" | tidak ada label `doc-claims` untuk baris ini (grep `it(`/`label:` 2026-10-09) | dijaga guard yang sama dengan ARCHITECTURE:135 |

Perkiraan prioritas: P1 (sudah rusak sekarang) > P2 = P3 (murah, pola sama) > P4 (nilai konstan).

## 3. (c) ARSIP / HISTORIS / TARGET — whitelist eksplisit (JANGAN di-guard)

- `agentsLogs.md`, `agentsLogs_2026-09.md`, `agentsLogs_2026-09-25.md`, `agentsLogs_2026-10.md`
- `docs/forensic/FIX14-ROLE-LEVEL-TOTAL.md` (riwayat batch), `docs/forensic/FORENSIC-INDEX.md`
  (blok bukti apply — KECUALI kasus duplikat di §5)
- `.agents/skills/**` (skill eksternal)
- `AGENTS.md`: blok CLOSED + "Dipangkas" + kolom **Bukti** Work Queue (angka ber-tanggal
  hasil query) + pelajaran §0.16 + angka contoh di aturan (pola `0 error` = spesifikasi gate)
- `FuturePlans.md`: KPI target (`80%`, `100%` dst), teks OBSOLETE/coret (`8 functions`,
  `20 overloads`), "95% complete"
- `OPEN_WORK.md`: status historical (`7 error`, `146 migrations` plan SG), `MIGRATION_GUIDE.md:34`
  (`21 migrasi historis`), `ENVIRONMENT_TRAPS.md:30` (anomali ber-tanggal),
  `TESTING_GUIDE.md:15,47` (hasil run lama `51/64`, bukti §5.7 no.11)
- `supabase/baseline/*.md` + `supabase/scripts/migrasi-region-sg-plan.md` (snapshot/plan;
  keputusan existing CONSTANTS-INVENTORY:102)
- `SECURITY.md` tabel `| Migration versioning | 219 |` (rujukan versi historis)
- `DISASTER_RECOVERY.md` RPO/RTO (`24 jam`, `1-2 jam`) — kebijakan, bukan turunan live

## 4. (d) SNAPSHOT EXTERNAL — perlakuan khusus (sumber di luar repo)

`ARCHITECTURE.md:146` (E2E 4/4), `ARCHITECTURE.md:147` (lint 0 errors),
`TESTING_GUIDE.md:15` (51/64 tests passed — run berbeda environment), angka bundle
(`144,5 kB`, `57 KB`). Perlakuan: boleh di-guard longgar (`>=`/regex) atau ditandai
tanggal run — jangan drift-check ketat.

## 5. (e) AMBIGU — butuh keputusan user

> **PENDING Fase-2 — tidak diklasifikasi final (keputusan user 2026-10-09).** Ketiga kasus
> di bawah tetap berkategori (e) sampai Fase-2 memutuskan; JANGAN ditutup lebih awal.

1. `DISASTER_RECOVERY.md:81-82` — "potret DB live: 208 tabel, 549 fungsi, 223 policy,
   27 trigger, 285 partisi, 4 cron job". Berada di §9.1 ber-tanggal (2026-09-27), tapi
   tulisan "potret DB live" terbaca sebagai kondisi sekarang dan angkanya sudah beda jauh
   dari live (657 fungsi dst.). Opsi: (i) tandai snapshot + tanggal eksplisit di baris itu
   (masuk whitelist (c)), atau (ii) sinkronkan ke live + guard. Risiko (ii): angka DR
   berubah tiap migrasi, DR doc harus ikut tiap kali.
2. `FORENSIC-INDEX.md:68-69` — duplikat klaim migrasi (179 baris, max 254) TANPA guard,
   padahal nilai yang sama dijaga di ARCHITECTURE. Opsi: whitelist sebagai arsip-indeks,
   atau guard/pindahkan angka ke registry.
3. `FuturePlans.md:45` — "Audit Chain: 44 rows" (live 526). Guard `doc-claims` memakai
   mode `>=` jadi **hijau meski basi**. Opsi: perbarui angka + biarkan `>=`, atau hapus
   angka persis dari prose dan biarkan guard `>=` saja.

## 6. Perkiraan skala registry Level B

- **Jenis unik yang dimuat registry (turunan live, kategori a+b+d): ~16**
  (ts-total, test-total, unit-xy, tables, functions, overloads, migrations-tracked,
  max-version, rls-policies, no-force, grants, cron, search-path, audit-rows,
  rollback-scripts, migration-folder-count — plus 2 snapshot external opsional).
- **Instansi (b) yang harus ter-cover segera: 6 baris di 3 file** (SECURITY, FuturePlans,
  CONSTANTS-INVENTORY).
- **Whitelist (c): ~118 klaim** di 10+ file — meta-guard harus memakai whitelist ini
  supaya tidak berisiko false-positive ke arsip (pelajaran P14-ext-2: scan semua .md).
- **Guard existing yang jadi input migrasi Fase-3**: `scripts/verify-derived-artifacts.mjs`,
  `scripts/verify-test-count.mjs`, `tests/unit/doc-claims-vs-live.test.ts`,
  `tests/unit/work-queue-consistency.test.ts` (struktur), `scripts/verify-backup-artifact.mjs`.
- **Ambang**: 20 jenis persis (STOP hanya jika > 20) dan 146 klaim (< 200). Rekomendasi:
  jalur normal satu Fase-1; kalau user ingin aman, registry bisa di-split jadi
  "DB-live claims" (10 jenis) + "repo-file claims" (6 jenis) di Fase-2.

## 6a. Referensi desain Fase-2

- **Design doc**: `docs/forensic/NUMERIC-GUARD-DESIGN.md` (Fase-2 — registry + meta-guard
  numeric claims; design-only, belum implementasi).

## 6b. Rencana Fase-2 (keputusan user 2026-10-09 — BELUM diimplementasi)

- **Split 2 sub-registry**: (1) **DB-live claims** (~10 jenis: tables, functions, overloads,
  migrations-tracked, max-version, rls-policies, no-force, grants, cron, search-path,
  audit-rows) vs (2) **repo-file claims** (~6 jenis: ts-total, test-total, unit-xy,
  rollback-scripts, migration-folder-count, + snapshot external opsional).
- Tutup 4 instansi (b) via registry + meta-guard scan semua .md tracked dengan whitelist
  §3; **3 kasus (e)** di §5 diadili pada Fase-2.
- `CONSTANTS-INVENTORY.md:19/28/29` (b-P1) sengaja TIDAK ditambal manual — jadi uji
  pertama registry (Fase-3).

## 7. GATE Fase-1

- [x] File `docs/forensic/NUMERIC-CLAIMS-INVENTORY.md` dibuat (DRAFT ini)
- [x] Data mentah di `.agents/reports/numeric-claims-raw.txt` (gitignored)
- [x] Semua klaim punya kategori a/b/c/d/e
- [x] Tidak ada file kode disentuh (`src/`, `tests/`, `scripts/`, `supabase/`, `package.json` = 0)
- [x] **COMMIT — di-approve user 2026-10-09 (gate dijalankan setelah `git add`, P14-ext)**
