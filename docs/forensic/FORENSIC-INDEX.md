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
- [ ] Batch 04 — Audit 31-40 → FORENSIC-RAW-batch-04.md
- [ ] Batch 05 — Audit 41-50 → FORENSIC-RAW-batch-05.md
- [ ] Batch 06 — Audit 51-60 → FORENSIC-RAW-batch-06.md
- [ ] Batch 07 — Audit 61-70 → FORENSIC-RAW-batch-07.md
- [ ] Batch 08 — Audit 71-80 → FORENSIC-RAW-batch-08.md
- [ ] Batch 09 — Audit 81-88 → FORENSIC-RAW-batch-09.md

## Global Analysis (docs/forensic/)
- [ ] FORENSIC-GLOBAL.md — analisis relasi (setelah 88)
- [ ] FORENSIC-FIXPLAN.md — fix plan batched (setelah global)

## Temuan Summary (setelah Batch 03)
| Severity | Jumlah | Catatan |
|---|---|---|
| **P0** | **2** | P0-01-01 (mitigated, migrasi 249) + **P0-03-01 (BARU, BELUM mitigasi)** |
| P1 | **13** | 10 (b1+b2) + 3 (batch 03) |
| P2 | **11** | 8 (b1+b2) + 3 (batch 03) |
| P3 | **17** | 9 + 8 |
| **Total (3 batch dari 9)** | **43** | 6 batch lagi berjalan |

> 🔴 **P0-03-01 belum mitigated** — view `employees_master` masih bisa ditulis oleh
> `authenticated` lewat 3 trigger `SECURITY DEFINER` tanpa gate authz.
> Perbaikan 1 statement: `REVOKE INSERT, UPDATE, DELETE ON public.employees_master FROM authenticated;`
> Menunggu keputusan user (mode audit-only masih aktif).

## Kemajuan
- ✅ Batch 01 (Audit 01-10) — P0: 1 (mitigated), P1: 5, P2: 2, P3: 2
- ✅ Batch 02 (Audit 11-20) — P0: 0, P1: 5, P2: 6, P3: 7
- ✅ Batch 03 (Audit 21-30) — P0: 1 (**baru`), P1: 3, P2: 3, P3: 8
- ⏳ Batch 04-09 (Audit 31-88) — menunggu


## Konteks Repo (penting untuk reading hasil audit)
- Branch audit: `migrasi-vite` @ `c70df84`
- WIP E2E fix #3 diparkir di branch `wip/e2e-fix3` (`2d28de7`) — **tidak** ikut di-audit
