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
- [ ] Batch 07 — Audit 61-70 → FORENSIC-RAW-batch-07.md
- [ ] Batch 08 — Audit 71-80 → FORENSIC-RAW-batch-08.md
- [ ] Batch 09 — Audit 81-88 → FORENSIC-RAW-batch-09.md

## Global Analysis (docs/forensic/)
- [ ] FORENSIC-GLOBAL.md — analisis relasi (setelah 88)
- [ ] FORENSIC-FIXPLAN.md — fix plan batched (setelah global)

## Temuan Summary (setelah Batch 06)
| Severity | Jumlah | Catatan |
|---|---|---|
| **P0** | **2** | ✅ keduanya mitigated (migrasi 249 + 250) |
| P1 | **29** | 24 (b1-5) + 5 (batch 06) |
| P2 | **40** | 30 (b1-5) + 10 (batch 06) |
| P3 | **34** | 31 (b1-5) + 3 (batch 06) |
| **Total (6 batch dari 9)** | **105** | 3 batch lagi berjalan |

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

## Kemajuan
- ✅ Batch 01 (Audit 01-10) — P0: 1 (mitigated), P1: 5, P2: 2, P3: 2
- ✅ Batch 02 (Audit 11-20) — P0: 0, P1: 5, P2: 6, P3: 7
- ✅ Batch 03 (Audit 21-30) — P0: 1 (mitigated 4609c80), P1: 3, P2: 3, P3: 8
- ✅ Batch 04 (Audit 31-40) — P0: 0, P1: 6, P2: 11, P3: 7
- ✅ Batch 05 (Audit 41-50) — P0: 0, P1: 5, P2: 8, P3: 7
- ✅ Batch 06 (Audit 51-60) — P0: 0, P1: 5, P2: 10, P3: 3
- ⏳ Batch 07-09 (Audit 61-88) — menunggu

## Catatan lintas-batch
- **P1-31-02 + P1-32-01 saling mengunci** (UU PDP): NRP dikirim ke PostHog, tapi
  `user_consents` 0 baris → tidak ada bukti persetujuan.
- **P2-37-01 + P1-53-01 + P1-13-01 saling mengunci**: test menulis ke DB produksi, tanpa hook
  cleanup, dan 98,7% entri `audit_log` tanpa `actor` → audit **tidak bisa membedakan** tulisan
  E2E vs manusia vs exploit.
- **P1-18-01 (tanpa CI) menjelaskan P1-56-01**: guard `doc-claims-vs-live` menangkap drift, tapi
  tidak ada yang menjalankannya → unit suite diam-diam merah.

## Kemajuan
- ✅ Batch 01 (Audit 01-10) — P0: 1 (mitigated), P1: 5, P2: 2, P3: 2
- ✅ Batch 02 (Audit 11-20) — P0: 0, P1: 5, P2: 6, P3: 7
- ✅ Batch 03 (Audit 21-30) — P0: 1 (mitigated 4609c80), P1: 3, P2: 3, P3: 8
- ✅ Batch 04 (Audit 31-40) — P0: 0, P1: 6, P2: 11, P3: 7
- ✅ Batch 05 (Audit 41-50) — P0: 0, P1: 5, P2: 8, P3: 7
- ⏳ Batch 06-09 (Audit 51-88) — menunggu

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
