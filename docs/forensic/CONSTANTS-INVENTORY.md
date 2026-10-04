# CONSTANTS INVENTORY — insightWOS

Status: 🟡 INVENTARIS AWAL
Tanggal: 2026-09-30
Baseline commit: f81af1e
Tujuan: daftar semua konstanta hitungan di repo tracked + guard yang menjaganya.
Setiap fix WAJIB rujuk file ini sebelum menambah migrasi/test/dokumen berangka.

Prinsip: konstanta tanpa guard = drift diam-diam; guard yang tidak tahu konstanta yang harus dijaga = guard palsu.

Metode: `git grep -E` (rg rusak di lingkungan kerja ini) + pembacaan kode guard. Sweep dokumen mengecualikan `agentsLogs_*.md` (log historis — angkanya snapshot masa lalu, bukan klaim hidup). Read-only terhadap `src/`, `supabase/` (kecuali baca), `tests/` (kecuali baca).

## §1 Konstanta di dokumen tracked

### 1.1 ARCHITECTURE.md — DIJAGA guard

| File:line | Konstanta | Nilai saat f81af1e | Guard penjaga | Catatan |
|---|---|---|---|---|
| ARCHITECTURE.md:131 (§7.4) | Tables | 208 | `verify:artifacts` + `doc-claims-vs-live` | vs `pg_class` relkind r/p non-partisi; 209 jika view dihitung |
| ARCHITECTURE.md:132 (§7.4) | Functions | 656 (+19 overloads) | `verify:artifacts` + `doc-claims-vs-live` | overloads = query `HAVING count(*)>1`, dijaga terpisah | Turun 658 → 656 pada migrasi **264** (2026-10-03, DROP 2 overload dead `check_admin_access`); overload 20 → 19. Naik lagi hanya lewat migrasi yang menambah fungsi |
| ARCHITECTURE.md:133 (§7.4) | Migrations tracked | 191 (max 266) | `verify:artifacts` + `doc-claims-vs-live` | vs `schema_migrations`; max(version) dijaga verify:artifacts. Nilai ini rose 179→181 (Fix #5 migrasi 254) → 184 (Fix #14 §8 255/256 + §9 257/258/259) → 185 (migrasi 260) → 187 (261 `role_codes` + 262 assignment NRP001) → 188 (263 rewire `is_admin_or_owner` + restore grant `authenticated`) → 189 (264 DROP 2 overload dead `check_admin_access`) → **190 (265 rewire `get_current_user_context` hybrid — netralitas 8/8, oid 298319 preserved)** → **191 (266 rewire `get_user_context_by_auth_id` — `role` hybrid + hapus auto-repair `UPDATE auth_id`; netralitas 8/8, oid 298467 preserved)**; kolom ini pernah tertinggal 2× karena `verify:artifacts` tidak dijalankan langsung setelah apply, dan **tertilang lagi tepat setelah 263** — akar masalahnya sama: verify harus dijalankan segera setelah apply, bukan nanti |
| **`role_codes` jumlah baris** (BARU 2026-10-03) | `role_codes` | **13** (10 `is_active=true` + 3 `false`) | `verify:artifacts` (tidak ada) + probe manual | Master role_code setelah migrasi 261. 10 = union 5 sumber data; 3 = `owner`/`director`/`admin` dari CHECK lama tanpa data. `is_active` = **metadata UI/docs, BUKAN gate runtime** — gate tetap rantai `authz_has_permission → role_permission_sets`. Belum ada guard otomatis; naik/turun harus selalu lewat migrasi |
| ARCHITECTURE.md:134 (§7.4) | RLS policies | 225 (10 belum FORCE) | `verify:artifacts` + `doc-claims-vs-live` | No-FORCE=10 dijaga keduanya |
| ARCHITECTURE.md:135 (§7.4) | SECDEF search_path violations | 0 | `doc-claims-vs-live` | |
| ARCHITECTURE.md:136 (§7.4) | anon/PUBLIC grants | 130 | `verify:artifacts` + `doc-claims-vs-live` | TANPA filter `prokind` — metodologi kedua guard wajib identik (catatan di dalam guard) |
| ARCHITECTURE.md:137 (§7.4) | pg_cron jobs | 5 | `verify:artifacts` + `doc-claims-vs-live` | |
| ARCHITECTURE.md:138 (§7.4) | Audit chain rows | 526 | `doc-claims-vs-live` (mode `>=`) saja | snapshot 2026-09-26; verify:artifacts SENGAJA tidak hard-compare (baris bertambah tiap hari) |
| ARCHITECTURE.md:122 (§7.3) | file TS total | 214 (157 src + 49 tests + 8 config) | `verify:artifacts` + `doc-claims-vs-live` | basis `git ls-files` (berkas ter-track), bukan disk |
| ARCHITECTURE.md:145 (§7.5) | Unit tests | 173 total — 169 auto + 4 `it.todo`; 26 berkas | `verify:test-count` (+ `doc-claims-vs-live` untuk baris .ts/.tsx) | yang dijaga TOTAL, bukan `passed` (beda antar environment) |

### 1.2 FuturePlans.md — DIJAGA guard

| File:line | Konstanta | Nilai | Guard penjaga | Catatan |
|---|---|---|---|---|
| FuturePlans.md:40 (§1.3) | Total Tables | ~209 | `doc-claims-vs-live` | tabel non-partisi + 1 view |
| FuturePlans.md:41 (§1.3) | Total Functions | ~658 | `doc-claims-vs-live` | |
| FuturePlans.md:44 (§1.3) | Legacy Overloads | 20 | `doc-claims-vs-live` | |
| FuturePlans.md §1.3 | Audit Chain rows | gte | `doc-claims-vs-live` | hanya-bertambah |

Plus 9 klaim kapabilitas (`CAPABILITIES`): exists/absent + `mustNotSay` (payroll engine, shift swap, payslip, mobile, geofencing, auto-approval, PWA, predictive, whistleblowing).

### 1.3 Konstanta TANPA guard (drift diam-diam bila berubah)

| File:line | Konstanta | Nilai | Kenapa tanpa guard / risiko |
|---|---|---|---|
| docs/forensic/FORENSIC-INDEX.md §5.8 (BARU 2026-10-03) | Tabel RLS tanpa policy SELECT | **61 dari 208** | **TIDAK ADA guard** + probe manual `.agents/logs/fix14-c9c-why-select2.log`. Work Queue `P1-TABLE-AUDIT`. RLS default-deny, jadi 0 baris untuk semua user termasuk admin_pusat & owner. Angka bergerak sendiri tiap migrasi menambah/menghapus policy SELECT dan tidak ada gate yang berteriak — kelas bug yang sama seperti P2-F14-M |
| Work Queue `P1-POST-HARDENING-AUDIT` tahap 1 (BARU 2026-10-03) | Fungsi `public` tanpa `EXECUTE` untuk `authenticated` | **46** | **TIDAK ADA guard** (rencana guard baru `scripts/verify-*`). `verify:artifacts` hanya menghitung policy, tidak pernah membandingkan `proacl` fungsi vs policy yang memanggilnya — itulah akar kelas bug "mati senyap" |
| SECURITY.md:61 | Rollback scripts | 18 scripts (183–214) | tidak ada guard yang baca SECURITY.md |
| SECURITY.md:30 (§3.10) | unit count gate | ~~119/119~~ → **174/174 · 4 todo** (fixed 2026-09-30 B0.5) | semula tanpa guard; kini dijaga test baru di `doc-claims-vs-live` (total via `.vitest/test-result.json`; pola "unit N/N" jadi canary — lihat §2 catatan) |
| SECURITY.md:52/56/57 | nomor migrasi referensi | 141; 141, 220; 141, 215 | idem — berubah saat migrasi baru tanpa peringatan |
| ARCHITECTURE.md:118–119 | rentang fase | 141–153; 154–168 | histori fase; relatif stabil |
| docs/forensic/FORENSIC-INDEX.md:68–69 | duplikat klaim migrasi Fix #4/#5 | 251/252/253; 254; 179 baris; max(version)=254 | TIDAK dijaga di file ini — hanya ARCHITECTURE.md yang dijaga; FORENSIC-INDEX bisa menyimpang diam-diam |
| docs/forensic/FORENSIC-INDEX.md:4,21,138,152,157 | total batch audit | 88 audit · 122 temuan · 2 P0 · 38 P1 · 44 P2 · 38 P3 | histori batch 1–9; berubah hanya bila audit baru, tapi tak ada yang menangkap salah ketik |
| supabase/baseline/README.md:106–107, rehearse-new-company.md:18/23/35, verify-install-e2e.md:25–60, replay-chain.md:178 | snapshot hasil menjalankan alat | 209 tabel · 155 menu · cap 173 · replay=212 | snapshot output alat pada saat itu; basi permanen sampai Fix #9 regenerasi — jangan dijaga, hapus/ganti saat regenerasi |
| AGENTS.md §5.8 blok "Dipangkas" | angka riwayat | 141/141, 154 halaman, migrasi 240–254, 144,5 kB | snapshot riwayat item DONE; by design tidak dijaga |
| tests/unit/*.test.ts | magic number assert | 30 (rate limit), 5/15 mnt, 17 (flags), 23505, 200/401, dll. | dijaga logika test itu sendiri; tidak butuh inventaris otomatis — cukup dirujuk file ini saat menambah test |

## §2 Guard + coverage

| Guard | File/objek dijaga | Konstanta yang di-assert | Fail condition |
|---|---|---|---|
| `scripts/verify-derived-artifacts.mjs` (`npm run verify:artifacts`) | ARCHITECTURE.md §7.4 + §7.3; registry `schema_migrations`; DB live | Tables 208, Functions 658, Migrations 179, RLS 225, No-FORCE 10, anon 130, cron 5, TS 214/157/49/8, rows=max file repo, max(version)=254 | dok ≠ live/git → exit 1; `check_login_lockout` tidak granted ke anon → exit 1 (guard keamanan); shell gagal → mati keras (bukan angka 0) |
| `scripts/verify-test-count.mjs` (`npm run verify:test-count`) | ARCHITECTURE.md §7.5; JSON suite vitest | Unit tests total 173, berkas 26, accounting passed+pending+failed+todo = total | dok ≠ suite → exit 1; failed>0 → exit 1; skipped → WARN |
| `scripts/verify-backup-artifact.mjs` (CI `supabase-backup.yml`) | artifact backup .gz | ambang ukuran 50 kB..10 MB; header dump dikenali; >0 CREATE | file tidak ada/rusak/di luar ambang/dump kosong → exit 1 (header → WARN saja) |
| `tests/unit/doc-claims-vs-live.test.ts` | ARCHITECTURE.md §7.1/§7.3/§7.4/§7.5 + FuturePlans.md §1.3 | 14 klaim DB + 4 klaim TS + 9 klaim kapabilitas | angka dok ≠ query live; pola regex basi (angka hilang); anchor roadmap yatim |
| `tests/unit/work-queue-consistency.test.ts` | AGENTS.md §5.8 ↔ `agentsLogs_*.md`; `supabase/migrations/` | R1 item SELESAI ↔ entry log; R2 OPEN tidak boleh diklaim DONE; R3 no-op migration wajib terdaftar di exempt | inkonsistensi status ↔ log; queue "kosong" tanpa blok Dipangkas |
| `tests/unit/no-stale-file-references.test.ts` | komentar di `src/` + `tests/` | referensi nama berkas (R1 ekstensi lama → TS; R2 nama tidak ada) | komentar menyebut berkas yang hilang |
| `tests/unit/baseline-install-guard.test.ts` | `supabase/baseline/000+010`, installer, generator data | tanpa identitas perusahaan sumber (owner/ceo email, merek, domain); registry pakai padding bukan `parseInt` | pola terlarang muncul di dump/generator |
| `tests/unit/migration-checksum-eol.test.ts` | `supabase/scripts/migration-checksum.mjs`; cap checksum di `010_baseline_config_data.sql` | checksum identik LF vs CRLF; nilai = cap baseline | algoritma bergantung EOL / tidak cocok cap |
| **Presisi `timestamptz` di probe** (BARU 2026-10-02) | `role_permission_sets.created_at` | `datetime_precision = 6` | **belum ada** — lihat P2-F14-M | Driver `pg` truncate tampilan ke 3 digit desimal, jadi `created_at` yang terbaca lewat driver bisa **kehilangan 2 digit mikrodetik terakhir**. Untuk pre-image rollback wajib ambil via `created_at::text` / `to_char(..., 'USOF')` di sisi server. Terbukti di rollback 260: `.036` vs `.036520` → hash tabel tidak byte-identik |
| `tests/unit/db-security-and-partition-guard.test.ts` | DB live | `PRE_AUTH_WHITELIST` eksplisit (8 RPC pra-login); RPC penulis tak terjangkau anon/PUBLIC; jendela partisi absensi ≥12 bulan; fail-fast `to_regclass` | RPC penulis bocor ke anon; partisi habis |
| `tests/unit/db-audit-trail.test.ts` | DB live | chain 0 issue, fungsi audit ada, actor terisi, retensi | chain/retensi/actor rusak |
| `tests/unit/db-password-reset-channel.test.ts` | DB live + sumber edge `password-reset` | setting `password_reset_channel`; UNIQUE `employees_core_email_unique`; FORCE RLS settings; guard `EMAIL_PROVIDER_READY` di `getResetMessage()` | kontrak Fix #5 melenceng |
| `tests/unit/db-security-anon-access.test.ts` | PostgREST HTTP (anon key) | status 401/403 pada tabel sensitif | anon bisa baca/tulis |
| `tests/unit/db-constraint-guard.test.ts` | DB live | CHECK/UNIQUE constraint ada (P1-58-01) | constraint hilang |

npm scripts terkait (package.json): `verify:artifacts`, `verify:test-count`, `test` (vitest), `test:a11y`, `test:a11y:full`, `db:verify-install`, `db:replay` — dua guard verify: dijalankan CI setelah step Unit test; `verify-backup-artifact` dijalankan workflow backup harian.

## §3 Matriks konstanta × guard

| Konstanta | verify:artifacts | doc-claims-vs-live | verify:test-count | Guard lain | TANPA guard |
|---|---|---|---|---|---|
| §7.4 Tables/Functions/Migrations/RLS/No-FORCE/anon/cron (7) | ✔ | ✔ | | | |
| §7.4 Audit chain 526 | (sengaja tidak) | ✔ `>=` | | | prose snapshot |
| §7.3 TS total/src/tests/config (4) | ✔ | ✔ | | | |
| §7.5 Unit tests total/berkas (2) | | (baris .ts/.tsx) | ✔ | | |
| §7.5 max(version)=266 | ✔ | | | | |
| FuturePlans Tables/Functions/Overloads/Audit (4) | | ✔ | | | |
| SECURITY.md rollback 18 / migrasi 141/215/220 | | | | | ✔ TANPA guard |
| FORENSIC-INDEX migrasi 251–264/189 (duplikat klaim) | | | | | ✔ TANPA guard |
| FORENSIC-INDEX batch 88/122 + tabel severity | | | | | ✔ TANPA guard (histori) |
| Baseline docs snapshot (209/155/cap 173/replay 212) | | | | | ✔ TANPA guard (snapshot alat) |
| Magic number test (30, 17, 23505, …) | | | | logika test masing-masing | inventaris manual |

| FORENSIC-INDEX tabel RLS tanpa policy SELECT 61/208 | | | | | ✔ TANPA guard (P1-TABLE-AUDIT) |
| Fungsi tanpa EXECUTE authenticated 46 | | | | guard baru (P1-POST-HARDENING-AUDIT tahap 1) | ✔ TANPA guard sekarang |

## §4 Rekomendasi (masukan, bukan keputusan)

1. **Duplikat klaim migrasi di FORENSIC-INDEX.md** (baris 68–69: 179 baris, max 254) TANPA guard padahal konstanta yang sama DIJAGA di ARCHITECTURE.md. Risiko: dua dokumen menyimpang. Opsi: (a) FORENSIC-INDEX merujuk §7.4 alih-alih menulis ulang angka, atau (b) perluas `doc-claims-vs-live` ke FORENSIC-INDEX.
2. **SECURITY.md** kolom migrasi (141/215/220) + "18 scripts (183–214)" TANPA guard — murah ditambahkan sebagai klaim baru di `doc-claims-vs-live` (pola "N scripts (A–B)" bisa diverifikasi ke daftar file `supabase/migrations`). *Update B0.5: klaim "unit N/N" §3.10 KINI dijaga (test baru) — item 1.3 baris SECURITY.md:30; item Work Queue P2-F14-A/B + P3-F14-C menutup sisa klaim kontrak SECURITY.md saat Fix #14.*
3. **Snapshot di supabase/baseline/*.md** (cap 173, 209 tabel, replay=212) sengaja TIDAK dijaga — basi permanen; hapus/perbarui saat Fix #9 regenerasi baseline, jangan dibikin guard.
4. **Magic number test** tidak perlu guard tambahan; disiplin yang diminta: setiap fix yang menambah test berangka / migrasi / tabel severity FORENSIC-INDEX wajib memperbarui file ini di §1.3/§3.
5. Guard yang terbukti hidup saat inventaris ini ditulis (bukti f81af1e): `verify:artifacts` = 0 drift, 1 warning (baseline commit → Fix #9, pre-existing).

## §5 Referensi

- Guard scripts: `scripts/verify-derived-artifacts.mjs`, `scripts/verify-test-count.mjs`, `scripts/verify-backup-artifact.mjs`
- Doc guards (test): `tests/unit/doc-claims-vs-live.test.ts`, `tests/unit/work-queue-consistency.test.ts`, `tests/unit/no-stale-file-references.test.ts`, `tests/unit/baseline-install-guard.test.ts`, `tests/unit/migration-checksum-eol.test.ts`
- DB guards (test): `tests/unit/db-security-and-partition-guard.test.ts`, `tests/unit/db-audit-trail.test.ts`, `tests/unit/db-password-reset-channel.test.ts`, `tests/unit/db-security-anon-access.test.ts`, `tests/unit/db-constraint-guard.test.ts`
- npm scripts: lihat `package.json` (`verify:*`, `test:*`, `db:*`)
- Konteks prinsip: AGENTS.md §0.16 (anti-hallucination), docs/forensic/FORENSIC-INDEX.md §"Pola akar 3×" (P1-71-01)
