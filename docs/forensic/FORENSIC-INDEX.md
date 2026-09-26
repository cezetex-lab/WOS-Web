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
- [ ] Batch 05 — Audit 41-50 → FORENSIC-RAW-batch-05.md
- [ ] Batch 06 — Audit 51-60 → FORENSIC-RAW-batch-06.md
- [ ] Batch 07 — Audit 61-70 → FORENSIC-RAW-batch-07.md
- [ ] Batch 08 — Audit 71-80 → FORENSIC-RAW-batch-08.md
- [ ] Batch 09 — Audit 81-88 → FORENSIC-RAW-batch-09.md

## Global Analysis (docs/forensic/)
- [ ] FORENSIC-GLOBAL.md — analisis relasi (setelah 88)
- [ ] FORENSIC-FIXPLAN.md — fix plan batched (setelah global)

## Temuan Summary (setelah Batch 04)
| Severity | Jumlah | Catatan |
|---|---|---|
| **P0** | **2** | ✅ keduanya mitigated (migrasi 249 + 250) |
| P1 | **19** | 13 (b1-3) + 6 (batch 04) |
| P2 | **22** | 11 (b1-3) + 11 (batch 04) |
| P3 | **24** | 17 (b1-3) + 7 (batch 04) |
| **Total (4 batch dari 9)** | **67** | 5 batch lagi berjalan |

## Kemajuan
- ✅ Batch 01 (Audit 01-10) — P0: 1 (mitigated), P1: 5, P2: 2, P3: 2
- ✅ Batch 02 (Audit 11-20) — P0: 0, P1: 5, P2: 6, P3: 7
- ✅ Batch 03 (Audit 21-30) — P0: 1 (**mitigated 4609c80**), P1: 3, P2: 3, P3: 8
- ✅ Batch 04 (Audit 31-40) — P0: 0, P1: 6, P2: 11, P3: 7
- ⏳ Batch 05-09 (Audit 41-88) — menunggu

> ✅ **P0-03-01 MITIGATED** (2026-09-26) — `REVOKE INSERT, UPDATE, DELETE ON public.employees_master FROM authenticated`
> via migrasi **250** (`90e1cbc7cf8d5ed82…`). Grants `authenticated` kini hanya
> `REFERENCES, SELECT, TRIGGER, TRUNCATE` (DML tidak ada). 3 trigger tetap
> `tgenabled='O'`, `employees_core`/`employees_master` = 17/17, worker update
> profil + login ulang sukses.
>
> ⚠️ **Registry drift yang ditemukan & ditutup**: saat mitigasi diterapkan, SQL
> **sudah jalan di live DB tetapi TIDAK terdaftar** di `schema_migrations`
> (`max(version)` masih 249). Drif ini persis kelas bug 221/222/223 yang
> diperingatkan AGENTS.md §0.6. Registrasi belatedan dilakukan lewat fungsi yang
> **sama persis** dengan konvensi `apply-migration.mjs` — `apply_migration()` lalu
> `verify_migration_checksum()`, checksum dari modul bersama `migration-checksum.mjs`
> — **tanpa menjalankan ulang SQL** (`REVOKE` sengaja tidak diulang).
> Bukti dry-run wrapper sesudah registrasi: `status: SUDAH terdaftar (checksum cocok)`.
> `max(version)` = 250, total 175 baris registry.
> **Catatan jujur**: kolom `applied_at` berisi waktu *registrasi belatedan*, bukan
> waktu SQL benar-benar dieksekusi — jejak auditnya tidak presisi, dan ini
> dicatat apa adanya di kolom `description`.

## Kemajuan
- ✅ Batch 01 (Audit 01-10) — P0: 1 (mitigated), P1: 5, P2: 2, P3: 2
- ✅ Batch 02 (Audit 11-20) — P0: 0, P1: 5, P2: 6, P3: 7
- ✅ Batch 03 (Audit 21-30) — P0: 1 (**baru`), P1: 3, P2: 3, P3: 8
- ⏳ Batch 04-09 (Audit 31-88) — menunggu


## Konteks Repo (penting untuk reading hasil audit)
- Branch audit: `migrasi-vite` @ `c70df84`
- WIP E2E fix #3 diparkir di branch `wip/e2e-fix3` (`2d28de7`) — **tidak** ikut di-audit
