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
- [ ] FORENSIC-GLOBAL.md — analisis relasi (setelah 88)
- [ ] FORENSIC-FIXPLAN.md — fix plan batched (setelah global)

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
