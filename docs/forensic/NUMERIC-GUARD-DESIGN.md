# NUMERIC-GUARD-DESIGN — Fase-2 Level B: registry + meta-guard klaim angka

> **Status: Fase-3 CLOSED (commit d48169e, CI #59, 2026-10-09) — design + implementasi registry + meta-guard verify:numeric tuntas. L9 (approve user) sudah tercapai — Fase-2 L2–L8 selesai, L3 (update docs angka) + L4 (regen) + L5 (update SECURITY.md) + B1/B2 (rewrite guard + harness) semua HIJAU. P2-F14-X (P1-F14-AA) + P2-F14-Y + P3-F14-Z + P2-F14-W belum dikerjakan (Fase-4). Registry = 19 entry (bukan 17 — asumsi awal salah). Snapshot marker [snapshot:<hash>] resmi (§5.x).**
> Baseline: `cc15ee1` (Fase-1 CLOSED — NUMERIC-CLAIMS-INVENTORY.md ter-track).
> Mode: DESIGN-ONLY. Tidak menyentuh `src/`, `tests/`, `scripts/`, `supabase/`, `package.json`.
> Referensi eksternal (dokumen CLAUDE.md/CLAUDE.md-*), hanya inspirasian, tidak diimpor.

## 0. Ringkasan singkat (L1 — pola existing)

Dari ketiga guard yang ada, pola yang dijadikan dasar desain:

- **`scripts/verify-derived-artifacts.mjs` (`npm run verify:artifacts`)** —
  script Node standalone. Re-reads `ARCHITECTURE.md`, hitung live via pg client + git ls-files
  + fs walk, bandingkan per-item dengan `check(label, doc, live, {soft})`, cetak `OK/DRIFT/WARN`,
  exit 1 kalau ada DRIFT keras (guard check_login_lockout = keras walau bukan angka dokumen),
  exit 0 kalau sinkron. butuh `DATABASE_URL` (.env.local) OR exit 1 kalau tidak ada.
- **`scripts/verify-test-count.mjs` (`npm run verify:test-count`)** —
  Node standalone. parsing `ARCHITECTURE.md §7.5` → ambil total test + file count; baca JSON
  `vitest run --reporter=json --outputFile=.vitest/test-result.json` (kalau ada) untuk angka actual;
  fallback offline = hitung berkas .test.ts/.tsx saja via fs walk; exit 1 kalau drift/bukan parsing,
  exit 0 kalau sinkron. testing jumlah TOTAL, bukan passed (karena pending skip di CI).
- **`tests/unit/doc-claims-vs-live.test.ts`** —
  vitest describe yang running di dalam suite. meng-import DB_CLAIMS + CAPABILITIES sebagai array
  claim {label/ doc/ pattern/ group/ mode/ sql}. baca angka klaim dari dokumen via regex; query live;
  gabungkan drift; `expect(drift, msg).toEqual([])`. mode `gte` untuk counter yang hanya bertambah.
  perlu DB_URL (.env.local) → di-skip tanpa itu (`describe.skipIf(!DB_URL)`). tapi runtime env lain
  tetap jalan.

Pola yang DIADOPSI oleh meta-guard baru:
- "ambil angka dari dokumen" (tidak duplikasi angka di kode).
- "cross-check vs live value per entry".
- "mode per klaim: eq / gte / skip / warning-only".
- "whitelist arsip + blacklist jelas (exclude by path)".
- "exit code: 0 = hijau, 1 = ada drift, 2 = error tak terduga".

# pola yang TIDAK diadopsi (karena desain berbeda):
- duplikasi angka di kode (dihindari).
- menjalankan suite sendiri di dalam guard (biaya CI tinggi) — meta-guard hanya membaca
  artifact yang sudah ada atau menjalankan extractor yang murah.

## 1. Latar masalah (kenapa Level B)

Real problem yang sudah terbukti (Fase-1 + riwayat):
- Angka yang ditulis manual di .md meluruh sewaktu-waktu (ARCHITECTURE.md sempat 667 vs 672 fungsi,
  129 vs 132 grant, 169 vs 172 baris audit) — tidak ada yang menangkap sebelum guard sekarang.
- Kelas bug "guard diam": verify:artifacts sempat buta terhadap perubahan LANGUAGE/provolatile
  fungsi (hanya hitung jumlah fungsi → ekstraksi per-klaim jadi pola yang dikehendaki).
- Duplikasi klaim di beberapa dokumen dengan status berbeda (ARCHITECTURE vs FORENSIC-INDEX vs
  CONSTANTS-INVENTORY) — beresiko salah klasifikasi kalau hanya satu sumber yang di-guard.
- 6 klaim (b) tanpa guard; 3 kasus (e) ambigu belum didisambigu-kan.

Tujuan Level B: SATU registry terstruktur yang menjadi single source of truth untuk "klaim angka
apa yang harus dijaga, bagaimana ambil live value, di file mana, kapan dijalankan". Meta-guard
baru memindai ALL .md tracked, bukan hanya handle dokumen tertentu.

## 2. Desain skema Registry (L2)

### 2.1 Format registry
**Rekomendasi: satu berkas JSON (`scripts/numeric-claims-registry.json`)**.
Alasan:
- Struktur terdefinisi, tanpa logika runtime di dalamnya.
- Mudah di-load oleh meta-guard + paralel-script.
- Mudah di-extend: menambah claim baru = 1 entry di JSON, bukan mengubah guard.
- Tooling existing (verify:artifacts, verify:test-count, doc-claims-vs-live) tetap berjalan
  tanpa harus direfactor — registry jadi layer di atas/def di samping mereka, bukan pengganti.
- JSON mudah di-lint (JSON schema / memvalidasi minimal shape), tapi desain ini tidak wajib
  JSON Schema; kita cukup validasi shape minimal di dalam guard (L7).

Jangan gunakan JS/ESM modul sebagai registry: lebih beresiko ad-hoc logic + coupling ke loader;
tinggal gunakan untuk hanya data statik.

### 2.2 Struktur entry per jenis angka

Minimal shape per entry (wajib):
```json
{
  "id": "db-functions",
  "label": "Functions (public schema count, termasuk overload)",
  "modes": ["eq"],
  "claimPatterns": [
    { "regex": "^\\\\| Functions \\\\| (\\\\d+) \\\\|", "group": 1, "doc": "ARCHITECTURE.md" },
    { "regex": "other-file-pattern" }
  ],
  "source": { "type": "db-live", "query": "SELECT count(*)::int n FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'" },
  "scope": { "scanAllTracked": true, /* atau whitelist */ },
  "category": "live-guarded",
  "existingGuard": ["verify:artifacts", "doc-claims-vs-live"],
  "verifyAfter": "git-add",
  "runIf": { "needDb": true, "needGit": false, "needFilesystem": false },
  "notes": "..."
}
```

Field penjelasan singkat:
- `id`: slug unik seluruh registry — jadi titik referensi di work queue, log, test.
- `label`: nama manusia.
- `modes`: array string `eq` | `gte` | `regex` | `skip`. `eq` = persis sama; `gte` = >= (counter
  hanya bertambah); `regex` = klaim bentuk string / range; `skip` = tidak dicek (mis. arsip).
- `claimPatterns`: array regex+pola yang dicari di dokumen untuk menemukan klaim. Bisa ada
  multi-pattern per entry kalau klaim muncul di beberapa file/varian (noun-first, tabel, prose).
- `source`: abstraksi cara ambil live value. Type kandidat: `db-live`(SQL atau QUERY object),
  `git-ls-files`, `fs-walk`, `npm-run-output`, `external-snapshot`, `static`/`n/a`(tidak perlu live,
  mis. KPI target).
- `scope`: apakah scan semua .md tracked atau whitelist file.
- `category`: sudah finalisasi kategori (a/b/c/d/e) → jangan ambigu di registry.
- `existingGuard`: array nama guard yang sudah menangani entry ini (agar Fase-3 tahu kohesi).
- `verifyAfter`: kapan meta-guard wajib menjalankan cek untuk entry ini — `git-add`|`pre-commit`|`post-test`.
- `runIf`: kondisi lazy — mis. entry db-live tidak dijalankan kalau tidak ada DATABASE_URL
  (tapi tetap dilaporkan status skip, bukan drift).
- `notes`: konteks, edge case, atau referensi ke work queue item.

Catatan: JSON tidak perlu berisi live value; registry hanya "deklarasi" klaim + cara ambil live.

### 2.3 Registry entry untuk 20 jenis (Fase-1) — semua dikategorikan (a/b/c/d/e)

Rumusan ID kandidat (status Fase-2 — bisa ditambah/ubah di Fase-3):
- (a) db-functions, db-tables, db-migrations-tracked, db-max-version, db-rls-policies,
      db-notForce-rls, db-anon-grants, db-cron-jobs, db-searchpath-violations, db-audit-chain,
      db-overloads, ts-total, unit-test-total, unit-test-files, security-unit-nn, rollback-scripts,
      migration-folder-count, e2e-smoke, lint-errors.
- (b) — masuk registry dengan `category: live-unguarded`.
- (c) — masuk dengan `category: archive`, `mode: skip`, `scope: excludePaths`.
- (d) — masuk dengan `category: external-snapshot`, `mode: regex|skip`, catatan perlakuan khusus.
- (e) — masuk dengan `status: pending-decision`, `category: ambiguous`, `notes: (opsi A/B/C)`.

Catatan: entry untuk "angka bukti Work Queue" tidak dimasukkan ke meta-guard sekarang
(kecuali user ingin, bisa ditambahkan di Fase-2 revision) — karena bukan angka turunan live
yang terstruktur tapi klaim per-item ber-tanggal (berbeda karakter).

## 3. Desain 2 sub-registry (L3 — sesuai §6b Fase-1)

Keputusan desain: **SATU file registry JSON berisi array entries, tiap entry punya field `source.type`
dan `category`** — jadi sub-A dan sub-B tinggal pembagian logic di dalam loader, bukan file terpisah.

Alasan:
- Satu sumber kebenaran = lebih mudah audit "semua klaim apa yang terjaga".
- Hindari drift dua-file (satu update tapi yang lain tidak).
- Filter by `source.type` dan `runIf.needDb` memisahkan pipeline eksekusi.
- Jika suatu saat memang perlu file terpisah (mis. CI perenvironment yang berbeda izin),
  bisa dialihkan via manifest tambahan tanpa ubah skema.

Namun: di Fase-3 implementation boleh membuat dua helper extractor (mis.
`extractDbLiveClaims(registry)` vs `extractRepoFileClaims(registry)`) yang dipanggil oleh
meta-guard — tapi registry tetap satu.

Meta-guard agregasi exit code:
- Jalankan semua entry yang `runIf` terpenuhi (mis. db-live hanya kalau DATABASE_URL ada,
  repo-file selalu jalan, external hanya kalau artifact ada).
- Tiap entry hasil cross-check → kumpulkan drift entries.
- Setelah semua, kalau ada entry `category: ambiguous` dengan `mode: skip` yang kemudian user
  sudah putuskan → nanti di-Fase-2-revise ubah kategori.
- Exit code meta-guard: 0 = tidak ada drift dari semua entry yang jalan; 1 = ada drift; 2 = error
  tak terduga (mis. registry corrupt / parser error).

## 4. Alur meta-guard `verify-numeric-claims` (L4)

Flow (implementasi belum, hanya desain):
1. Load registry (validate shape minimal).
2. Tentukan environment: apakah ada DATABASE_URL, apakah ada vitest JSON, apakah CI run, dll.
3. Buat scan Corpus semua .md tracked via `git ls-files '*.md'` (mengikuti pola existing di
   doc-claims-vs-live.test.ts).
4. Untuk tiap entry registry:
   - Ekstrak klaim dari corpus dengan `claimPatterns` (regex) — kumpulkan semua ditempati
     file:line.
   - Untuk tiap ditempati: cek scope (whitelist / exclude).
   - Jika `category === archive` dan file masuk exclude → skip.
   - Jika `category === live-guarded` atau `live-unguarded`: ambil live value via `source`;
     bandingkan; hasilkan diff.
   - Jika `category === external-snapshot`: cek apakah artifact tersedia; kalau tidak → warn;
     kalau ada → cross-check sesuai mode.
   - Jika `category === ambiguous`: hasilkan warn-only (bukan drift), sampai user memutuskan.
5. Output: daftar diff per file:line dengan dokumen vs live, dikelompokkan per entry.
   Format mengikuti pola existing: WARN/DRIFT/OK, lalu ringkasan.
6. Exit 1 kalau ada DRIFT; exit 2 kalau error; 0 kalau ok.

Desain output (terinspirasi existing):
```
=== verify-numeric-claims (registry-based drift scan) ===

  -- db-functions --
  OK    ARCHITECTURE.md:132  657
  WARN  CONSTANTS-INVENTORY.md:19  208 (stale vs live 209) [live-unguarded → drift]
  ...
=== RINGKASAN: N drift, M warnings, skipped: ...
```

## 5. Hubungan dengan guard existing (L5 — coexist)

Prinsip: guard existing JALAN TERUS; meta-guard baru ADDITIVE.
Rencana:
- Fase-3: meta-guard baru dibuat sebagai script terpisah (`scripts/verify-numeric-claims.mjs`),
  dipanggil sendiri/diperluas dari npm scripts (mis. `npm run verify:numeric` baru), tidak
  mengganti verify:artifacts/verify:test-count.
- Untuk menghindari duplikasi drift: di Fase-4, registry mulai menjadi "sumber kebenaran" untuk
  beberapa klaim yang dulunya di dua tempat — tapi bukan dengan menghapus guard lama sebelumnnya.
  Pendekatan aman: registry mendefinisikan klaim; guard lama tetap jalan tapi mulai membacanya
  dari registry untuk konsistensi (refactor bertahap).
- Fase-4: migrasi bertahap — mis. dari verify:artifacts → baca beberapa klaim dari registry,
  tapi guard lama tetap ada sampai tested.
- Fase-5 (cleanup): hapus guard lama HANYA jika registry + meta-guard sudah menangani semua
  klaim yang sama dan atleast satu siklus CI/verifikasi tanpa regression. Minimal syarat: semua
  entry yang sama sudah dipindahkan ke registry, meta-guard telah berjalan hijau beberapa kali di
  lingkungan berbeda, dan tidak ada guard lama yang menangani klaim unik di luar registry.

Catatan: doc-claims-vs-live.test.ts adalah guard di dalam suite uji yang benar-benar live query
DB — itu kepercayaan tinggi; meta-guard baru TIDAK menggantikan validasi itu, tapi melengkapi
dengan coverage 20 jenis dan cross-file.

### 5.x Snapshot marker (mekanisme resmi, Fase-3)

Baris kutipan historis (angka yang benar pada baseline-nya tapi basi terhadap live
saat ini) dilindungi dengan marker kanonik `[snapshot:<baseline-hash>]` — mis.
`[snapshot:7ada2d0]`. Scanner `verify:numeric` me-skip setiap baris ber-marker
(reported sebagai SKIPPED, bukan silent) karena meng-update angkanya akan memalsukan
catatan forensik. Marker menyertakan hash baseline agar bisa di-grep dan dicek ke
`git log` (auditability). Baris ber-marker tetap di-drift-check file-nya (file TIDAK
di-archive — koreksi #2), hanya baris itu yang skip. Lihat §6.1/§6.2 untuk 3 baris
pertama yang memakai mekanisme ini.

## 6. 3 edge case Fase-1 (L6)

### 6.1 5 klaim manual yang lolos scanner kanonik
Pola noun-first yang tidak tertangkap regex awal:
- `| Tables | 209 |`
- `supabase/migrations/` `(157 berkas)` [snapshot:7ada2d0]
- `FORENSIC-INDEX` klaim duplikat
- dll (lihat NUMERIC-CLAIMS-INVENTORY.md baris yang tidak tangkap)
Desain: claimPatterns di registry wajib menangkap JSON-nya (multi-regex atau "noun-first" parser
sederhana). Ini jadi uji wajib Fase-3: registry harus menemukannya.

### 6.2 CONSTANTS-INVENTORY.md:19/28/29 yang basi (b-P1)
Desain entry: `db-tables`, `ts-total`, `unit-test-files` punya claimPatterns yang mencakup baris
di CONSTANTS-INVENTORY.md juga (karena merupakan klaim turunan yang sudah usang). Tujuannya:
meta-guard new akan menghasilkan DRIFT untuk baris tersebut → jadi test pertama registry.
Catatan: ini sengaja tidak langsung diperbaiki manual, untuk membuktikan guard berfungsi.

### 6.3 Kategori (d) — E2E 4/4, lint 0, bundle size
Desain: entry dengan `category: external-snapshot`, mode `regex` atau `skip`; tapi termasuk
registry supaya tercatat dan bisa ditelusur. Untuk angka yang bergantung CI artifact (mis. E2E
passed, lint) → meta-guard bisa hanya membaca file artifact yang dihasilkan CI (sesuai
verify:test-count) dengan mode fuzzy atau skip kalau artifact tidak ada. Untuk bundle size,
diperlukan build output / artifact; bisa jadi category external-snapshot dengan `verifyAfter: post-test`.

## 7. Rencana test Fase-3 (L7)

Desain test (nanti implementasi):
- Unit test loader registry: validasi shape minimal entry, tolak entry corrupt.
- Unit test scanner claim extraction (mock corpus .md): memastikan regex menempatkan klaim benar.
- Unit test cross-check logic per mode (eq/gte/regex/skip) dengan mock live value.
- Unit test exclude-by-path (arsip tidak dilaporkan drift).
- Unit test exit code behavior.
- Integration test: jalankan meta-guard di tree ini → diharapkan menemukan drift di
  CONSTANTS-INVENTORY.md:19/28/29 (karena memang stale) DAN tidak ada drift palsu untuk klaim
  yang benar.
- Negative test: masukkan klaim baru dengan drift di mock → guard harus merah.
  (Penting: seperti pelajaran P14-ext — guard sebaiknya terbukti "merah saat drift" di controlled.)

## 8. Keputusan arsitektur yang tersisa? (L8 — status)

Saat desain ini ditulis, tidak ada keputusan arsitektur mayor yang tersisa untuk Fase-3,
kecuali:
- Detail filter regex per entry sebenarnya (akan teroptimasi di Fase-3 via testing).
- Apakah external-snapshot masuk guard default atau opsional — diserahkan ke user via Fase-2
  approve (lihat bagian berikut).

Opsi yang diserahkan ke user (di L9):
- Apakah 3 kasus (e) di Fase-1 tetap PENDING, atau mau didisambigu-kan sekarang.
- Apakah snapshot external (E2E, lint, bundle) dimasukkan ke meta-guard default (mode warn/skip),
  atau tidak di-guard sama sekali (hanya tercatat).
- Apakah meta-guard baru dimulai sebagai npm script baru (`verify:numeric`) atau hanya
  development helper di awal.

## 9. Append cross-link ke NUMERIC-CLAIMS-INVENTORY.md (L8)

(diimplementasi di langkah terpisah di bawah, append-only di file itu)

## 10. GATE Fase-2 (L9 — sudah dijalankan di langkah ini, hasil di bawah)

- [ ] NUMERIC-GUARD-DESIGN.md dibuat
- [ ] NUMERIC-CLAIMS-INVENTORY.md hanya di-append cross-link
- [ ] verify:artifacts tetap 0 drift
- [ ] verify:test-count tetap 0 drift
- [ ] zona larang 0 diff
- [ ] tidak ada kode implementasi
- [ ] menunggu approve user sebelum commit

## 11. Rujukan pelajaran proses yang mempengaruhi desain

- P14-ext-2: 2 guard + angka di ≥3 dokumen → wajar jadi registry.
- P6/P7/P13: byte-identik, rollback, dll — bukan inti desain ini tapi relevan saat
  implementasi meta-guard nanti (verify:artifacts perlu tetap robust).
- P14 (sync dokumen tidak sah divalidasi dari exit-code skrip) → meta-guard wajib benar-benar
  cross-check, bukan hanya membaca artifact guard lain tanpa verifikasi.

## 12. STOP conditions untuk Fase-2

- Jika >2 ambiguitas arsitektur tetap ada setelah desain ini → lapor dulu (sekarang tidak ada).
- Jika design doc melebihi 400 baris → lapor (sekarang masih di bawah).
- Jika ada entry yang extractor needing akses luar (mis. artifact CI yang tidak ada di repo)
  tanpa alternative → lapor, tapi sebagian bisa mode skip/warn.
