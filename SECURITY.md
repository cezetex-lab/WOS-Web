# SECURITY.md — ATURAN TEKNIS KERAS + SECURITY POSTURE

> **Pecahan dari `AGENTS.md` (2026-09-19).** Isi di bawah ini dipindahkan apa adanya —
> nomor bagian lama (`§5.7`, `§6.4`, `§7.4`, …) sengaja DIPERTAHANKAN agar rujukan lama tetap
> bisa ditelusuri. Peta bacanya ada di `AGENTS.md` (Reading Map). Jangan menaruh riwayat
> pekerjaan selesai di berkas ini — itu milik `agentsLogs.md`.

> §3 adalah aturan yang **tidak boleh dilanggar**, dirujuk dari banyak tempat sebagai
> `§3.11` (TypeScript only), `§3.13` (angka dokumen tidak boleh dikarang), `§3.15`/`§3.16`
> (instalasi baseline) — nomornya sengaja tidak diubah.

## 3. ATURAN TEKNIS KERAS (JANGAN dilanggar)

1. Identitas & authz **selalu dari JWT** (`authz_current_nrp()`, `authz_check_admin()`,
   `authz_in_scope()`) — **jangan pernah** percaya param client (`p_admin_nrp`, `p_nrp` bebas).
2. Password **tidak pernah plaintext** — bcrypt (`gen_salt('bf')` + `crypt()`), tanpa echo
   password di response.
3. `SECURITY DEFINER` wajib `SET search_path` (state: 0 pelanggaran — jangan tambah baru).
4. Jangan bikin overload fungsi dengan nama sama; bereskan legacy dengan RENAME `_legacy_*`,
   bukan DROP liar.
5. Fungsi sensitif: default fail-closed; REVOKE PUBLIC/anon untuk fungsi admin.
6. Klaim "sudah aman" dari sesi sebelumnya = belum terverifikasi sampai dicek ke DB live.
7. `SECURITY DEFINER` + edge service-role: `auth.uid()` = NULL — RPC yang butuh
   `auth.uid()` tidak boleh dipanggil dari edge (pelajaran: bug 500 login OTP).
8. Supabase JS v2: `.catch()` tidak tersedia di query builder — pakai
   `const { error } = await ...; if (error) {...}`.
9. Branding (nama/logo) = konfigurasi OWNER (`branding` table + `update_branding` owner-only).
   **Jangan hardcode di JS.** UI: tab 🎨 Branding OwnerDashboard.
10. Verifikasi gate sebelum commit: `npm run check:types` (0 error), `npm run lint` (0 error),
    `npm test` (unit 119/119), `npm run build` (EXIT 0), secret scan. Untuk perubahan
    fungsional, tambah smoke lintas-page (§0.5 G6).
11. **TypeScript wajib untuk SEMUA kode** (aturan keras): `src/`, `tests/`, dan file konfigurasi
    (`vite/vitest/playwright/tailwind/postcss/eslint.config.ts`) harus `.ts`/`.tsx`/`.config.ts`.
    **DILARANG membuat file `.js`/`.jsx` baru** — termasuk test/E2E spec. `tsconfig.json` memakai
    `allowJs: false`, jadi file `.js` di `src/`/`tests/`/config menggagalkan gate tipe.
    Satu-satunya pengecualian: `public/sw.js` (Service Worker — di-serve apa adanya oleh browser).
    Skrip tooling DB di `supabase/**/*.mjs` (mis. `run_171.mjs`) di luar cakupan — dijalankan
    langsung oleh Node dan dikelola terpisah.
12. **Keterkaitan 4 page adalah hukum, bukan preferensi** — setiap perubahan pada satu page
    (worker/admin/dashboard/owner) WAJIB dievaluasi & diverifikasi lintas-page (§0.5 G1–G7).
13. **Angka metrik di dokumen tidak boleh dikarang.** Klaim kuantitatif di `ARCHITECTURE.md` (§7.1, §7.3, §7.4, §7.5) dan `FuturePlans.md` (§1.3) diverifikasi otomatis oleh `tests/unit/doc-claims-vs-live.test.ts` terhadap DB live + isi repo. Kalau schema/berkas berubah secara sah: **perbarui dokumennya** — JANGAN melemahkan/menghapus tesnya. Angka yang hanya bertambah (mis. baris `audit_log`) diperiksa sebagai `>=`. Tes itu di-skip bila `DATABASE_URL` tidak ada, jadi `npm test` tanpa kredensial tetap jalan. Aturan yang sama berlaku untuk klaim kapabilitas roadmap di `FuturePlans.md` (tabel/RPC/berkas yang diklaim sudah ada atau belum ada).
14. **Migrasi tidak boleh masuk DB live tanpa tercatat.** Migrasi 221/222/223 pernah diterapkan lewat SQL Editor sehingga `schema_migrations` tertinggal (`TESTING_GUIDE.md` §5.7 no.11). Sejak 2026-09-17 jalurnya satu: `npm run db:migrate -- <berkas>.sql --apply` (`ENVIRONMENT_TRAPS.md` §6.4). Klaim "DONE" untuk migrasi baru wajib menyertakan bukti `verify_migration_checksum` PASS dan `check_migrations()` bersih.
15. **Instalasi perusahaan baru = baseline, bukan rantai migrasi.** `supabase/migrations/` (157 berkas) adalah HISTORI + gerbang regresi, bukan jalur instalasi: ia membawa data seed/demo dan tidak memuat objek yang hanya hidup di DB live. Jalur resmi: `npm run install:baseline -- --target ... --apply` (runbook: `supabase/baseline/README.md`). Setelah setiap migrasi yang mengubah schema, **wajib regenerasi** `npm run db:baseline` lalu buktikan dengan `npm run db:verify-install` — baseline yang tertinggal dari live akan memasang perilaku lama ke perusahaan baru (kejadian nyata 2026-09-18: perbaikan `get_owner_email()` di migrasi 230 belum ter-dump sehingga instalasi baru masih mewarisi email owner kita).
16. **Identitas perusahaan tidak boleh diwariskan lewat baseline.** Nama/logo (`branding`), email owner (`company_config.owner_email`/`ceo_email`), dan `system_owner_identity` adalah milik tiap perusahaan: dilarang berada di dump data, dan dilarang menjadi nilai default di fungsi DB bersama (mis. `COALESCE(..., 'owner@insightwos.com')`) — fungsi seperti itu wajib **fail-closed**. Generator baseline sudah memblokirnya (`EXCLUDED_ROWS` + pemindai domain) dan `verify-install-e2e.mjs` menegakkannya setiap kali dijalankan.


### 7.6 Security Posture

| Check | Status | Migration |
|---|---|---|
| JWT-based authz | ✅ | 131-140 |
| bcrypt passwords | ✅ | 141 |
| SECDEF search_path | ✅ | 207 |
| RLS all tables | ✅ | 131-140 |
| REVOKE anon/PUBLIC | ✅ | 210 |
| Audit log | ✅ | 141, 220 (hash-chain) |
| Rate limiting | ✅ | 141, 215 |
| MFA TOTP | ✅ | 150 |
| NIK NULL guard | ✅ | 206 |
| Migration versioning | ✅ | 219 |
| Rollback scripts | ✅ | 18 scripts (183-214) |
