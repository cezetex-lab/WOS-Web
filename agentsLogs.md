# agentsLogs.md — INDEKS LOG (LOG DIPISAH PER BULAN)

> **Log dipisah per bulan.** Berkas ini hanya **penunjuk**. Entri pekerjaan yang sudah
> selesai ada di `agentsLogs_YYYY-MM.md` untuk bulan berjalan.
>
> Header asli dipindahkan apa adanya ke tiap berkas bulan — tidak ada baris yang hilang.

| Bulan | Berkas | Entri |
|---|---|---|
| 2026-09 | `agentsLogs_2026-09.md` | 69 |
| 2026-09-25 | `agentsLogs_2026-09-25.md` | 1 entri (E2E DONE ALL) |

## Cara mencatat pekerjaan baru

1. Tulis ke berkas bulan berjalan (`agentsLogs_<YYYY-MM>.md`). Kalau belum ada, buat dengan
   menyalin header dari bulan sebelumnya, lalu tambahkan barisnya ke tabel indeks di atas.
2. **Jangan tulis lewat shell** (`echo >`, `cat <<EOF`, `Add-Content`) — itu pernah merusak
   berkas ini (864 NULL byte). Pakai:
   `node scripts/safe-file-writer.ts --file agentsLogs_<YYYY-MM>.md --content-file <sumber> --mode append`
3. Entri selesai **dikeluarkan** dari `AGENTS.md` (§0.4) — log adalah satu-satunya tempat riwayat.

> Riwayat lama tidak dihapus dan tidak masuk `.agents/` (folder itu gitignored). Kalau ada
> bulan-bulan lama, berkasnya tetap ber-track di root supaya ikut ter-commit.
