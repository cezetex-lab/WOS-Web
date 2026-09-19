# ENVIRONMENT_TRAPS.md — JEBAKAN LINGKUNGAN (Windows / PowerShell / Supabase)

> **Pecahan dari `AGENTS.md` (2026-09-19).** Isi di bawah ini dipindahkan apa adanya —
> nomor bagian lama (`§5.7`, `§6.4`, `§7.4`, …) sengaja DIPERTAHANKAN agar rujukan lama tetap
> bisa ditelusuri. Peta bacanya ada di `AGENTS.md` (Reading Map). Jangan menaruh riwayat
> pekerjaan selesai di berkas ini — itu milik `agentsLogs.md`.

> **Satu sumber untuk seluruh §6.** Berkas lain merujuk ke sini alih-alih menyalin
> (mencegah teks kembar yang menyimpang): `MIGRATION_GUIDE.md` → §6.4,
> `TESTING_GUIDE.md` → §6.7.

## 6. JEBAKAN LINGKUNGAN (Windows / PowerShell / Supabase)

1. SQL Editor: hanya statement terakhir tampil → pecah blok multi-statement; agregat
   `pg_get_functiondef` error di `avg` → filter `prokind='f'`.
2. PowerShell: `$env:` untuk env; tanpa `< >` placeholder; hati-hati `[0]` pada single string
   (pakai `Select-Object -First 1`).
3. `npx` via PowerShell sering gagal stderr-as-error → jalankan via `cmd /c`, atau
   `Start-Process` untuk proses lama (vitest ~30–100s; jangan sync dalam timeout tool 30s).
4. **Apply migrasi ke DB live WAJIB lewat wrapper**, bukan SQL Editor / pg8000 manual:
   `npm run db:migrate -- <berkas>.sql --apply` (`supabase/scripts/apply-migration.mjs`). Wrapper itu
   menjalankan SQL DAN mendaftarkannya ke `schema_migrations` dalam **SATU transaksi** — kalau
   pendaftaran gagal, SQL-nya ikut ROLLBACK, jadi mustahil berakhir "sudah jalan tapi tidak tercatat"
   (penyebab drift 221/222/223, §5.7 no.11). Ia juga menolak jalan kalau nomor versi sudah dipakai
   berkas lain, dan mendeteksi berkas yang diubah setelah diterapkan (checksum beda). Default = dry run.
5. `.env.local` pernah pecah dotenv (blok SQL mentah) — cek parse sebelum deploy edge.
6. **Post-verify read-only setelah apply**: pakai script python pg8000 yang membaca `DATABASE_URL` dari
   `.env.local` (jangan lewat argv agar tidak ter-log) untuk memastikan efek migrasi benar di DB live.
7. **"Timeout waiting for worker to respond" bukan masalah konfigurasi tes.** Vitest memakai timeout keras **60s** untuk pool runner-nya (`START_TIMEOUT` di `node_modules/vitest/dist`) yang TIDAK bisa dikonfigurasi, sementara default worker = satu per core. Di mesin 12 core pool runner kalah rebutan CPU → sebagian berkas "passed" tapi ada puluhan error dan jumlah test jauh di bawah 119. `vitest.config.ts` membatasi `maxWorkers` (2 per project; suite dipecah jadi project `node` + `jsdom`). Gejala ini pernah dicatat sebagai "flaky Windows" — akarnya konkret, jangan di-workaround dengan `--no-file-parallelism`.
   **Anomali teramati sekali (2026-09-17):** tepat setelah split jadi 2 project, satu run melaporkan `Test Files 15 passed (15) / Tests 100 passed (100)` — persis kehilangan `session.test.ts` (11) + `supabase-browser.test.ts` (8) — **tanpa satu pun baris error**, saat mesin sedang berat (run 94s, setup 24.6s). Tidak terulang dalam 9 run berikutnya (semuanya 17/119). Kalau suatu saat jumlah test < 119 tapi tidak ada error, curigai ini dulu: jalankan ulang, dan cek `npm run check:types` masih 0 error.
