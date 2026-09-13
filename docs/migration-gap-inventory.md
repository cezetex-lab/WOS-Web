# Migration Gap Inventory — GAS → Supabase

> **Status:** Verified read-only against live DB (610 RPC, 253 tables) + 62 GAS files (Readme/GAS sebelum refaktor/).
> **Purpose:** Inventory of what EXISTS in GAS but is MISSING from the Supabase migration.
> **Not a security audit** — these are feature/field gaps, not bugs or vulnerabilities.

---

## A. Data/Domain Verification — Summary

58 GAS sheets checked vs live tables: all present except `login_tokens` (replaced by `active_sessions` + Supabase JWT — correct design decision).

Frontend RPC: 206 used, 0 without DB equivalent (F-9 already resolved).

---

## B. Employee Master — Fields in GAS Not Yet in DB

GAS `MASTER_HEADERS` = 69 columns. Live: `employees_core` (23) + `employees_extended` (39). 39 already migrated. Remaining:

| # | Field (GAS) | Status in DB | Notes |
|---|-------------|--------------|-------|
| 1 | Agama Pekerja | ❌ Missing | No column exists |
| 2 | Akun Media Sosial | ❌ Missing | No column exists |
| 3 | Pendidikan Terakhir (jenjang) | ❌ Partial | Only jurusan, institusi, tahun_lulus exist |
| 4 | Lokasi Penempatan (teks) | ❌ Partial | Only site_id/business_unit_id exist |
| 5 | Nama Bank | ❌ Missing | hr_payroll has no bank column |
| 6 | Nomor Rekening | ❌ Missing | hr_payroll has no account number column |
| 7 | Nama Rekening | ❌ Missing | hr_payroll has no account name column |
| 8 | No BPJS Kesehatan | ❌ Missing | hr_payroll has BPJS nominal, not card number |
| 9 | No BPJS Ketenagakerjaan | ❌ Missing | hr_payroll has BPJS nominal, not card number |
| 10 | Riwayat Penyakit Khusus | ❌ Missing | No column exists |
| 11 | Komorbid | ❌ Missing | No column exists |
| 12 | Alergi | ❌ Missing | No column exists |
| 13 | 10 Upload Columns (Pas Foto, KK+KTP, BPJS, Ijazah, Sertifikasi, Buku Tabungan, NPWP, SIM, Ket Anak Kuliah, Update Lainnya) | ⚠️ Replaced | Replaced by generic `employee_documents` table — currently empty (0 rows). `hr_document_types` also not populated. |
| 14 | lastUpdatedBy | ❌ Missing | No column exists |
| 15 | statusKerjaInternal | ❌ Missing | No column exists |
| 16 | fileLinksJSON | ❌ Missing | No column exists |
| 17 | Pernyataan kebenaran data | ✅ Present | Exists as `consents` table |