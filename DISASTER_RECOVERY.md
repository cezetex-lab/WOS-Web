# DISASTER_RECOVERY.md — BACKUP, RPO/RTO, MONITORING

> **Pecahan dari `AGENTS.md` (2026-09-19).** Isi di bawah ini dipindahkan apa adanya —
> nomor bagian lama (`§5.7`, `§6.4`, `§7.4`, …) sengaja DIPERTAHANKAN agar rujukan lama tetap
> bisa ditelusuri. Peta bacanya ada di `AGENTS.md` (Reading Map). Jangan menaruh riwayat
> pekerjaan selesai di berkas ini — itu milik `agentsLogs.md`.


## 9. DISASTER RECOVERY

- Backup: Supabase automated daily (30d retention Pro), pg_dump weekly core tables (90d), git = permanent.
- **RPO 24h / RTO 4h.** Scenario: data corruption → PITR; mass delete → PITR; full restore → new project + migrations + backup; security breach → force logout all + rotate api_keys.
- Monitoring: backup status daily, RLS policies weekly, audit_log growth weekly, failed login spikes daily, session count anomaly daily.
- Testing: smoke test after each migration, backup restore monthly, DR drill quarterly, security audit bi-annually.
- Escalation: P1 1hr / P2 4hr / P3 24hr / P4 1wk.
