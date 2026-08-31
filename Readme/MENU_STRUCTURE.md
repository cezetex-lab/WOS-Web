# 📋 Menu Structure — insightWOS v3.0

> Reference document for navigation restructuring
> Source: User-provided menu hierarchy

## Structure Summary

| Role | Modules | Features | Depth |
|------|---------|----------|-------|
| Worker | 11 | 85 | Max 3 levels |
| Manager | 9 | 35 | Max 3 levels |
| Admin | 13 | 110 | Max 3 levels |
| Global | 3 services | 15 | 1 level |

## Worker Modules (11)

1. **Beranda** — Status Hari Ini, Performa Saya, Pengumuman, Notifikasi
2. **Aktivitas** — Pengajuan (Cuti/Izin/Sakit/Lembur/Training/Dinas), Riwayat, Reimbursement, Task
3. **Pengembangan Diri** — Learning, Skill & Kompetensi, Karier
4. **Engagement** — Ide & Inovasi, Survei eNPS, Forum, Whistleblowing
5. **Akun Saya** — Profil, Kompensasi, Dokumen & Kesehatan, Status Kerja, Keamanan

## Manager Modules (9)

1. **Dashboard Tim** — Ringkasan, Approval Center, Team Analytics, AI Insights, Command
2. **Kinerja Tim** — Performance Trend, Catatan Kinerja, Continuous Performance
3. **Eksekutif** — CEO Command, Org Health, Executive Brief, Financial Stats, Health Score, Early Warning
4. **Risk Management** — Flight Risk, Turnover, Anomaly Detection, Safety, Compliance

## Admin Modules (13)

1. **Ringkasan** — Summary, Pending Registration, Approval Center, Action Center, Alert
2. **People Management** — Karyawan, Organization, Recruitment, Talent
3. **Operasional** — Attendance, Leave & Overtime, Performance, Learning, Engagement, Safety & Compliance, Asset, Offboarding
4. **Analytics & Planning** — Workforce Planning, Financial Analytics, Simulation, AI Tasks
5. **Integrasi** — Payroll, Attendance Sync, Webhooks, SSO, Calendar, Slack/Teams
6. **Security & Compliance** — Audit, RLS, GDPR, Documents, Session, Rate Limiting
7. **Sistem & Konfigurasi** — User & Access, Approval Config, Data Management, Configuration, Admin Security

## Current Implementation Status

### Worker Routes (11 routes → needs restructure to 5 modules)
- [x] /worker — Beranda (✅ Full page)
- [ ] /worker/aktivitas — New module (Pengajuan + Riwayat + Task)
- [ ] /worker/pengembangan — New module (Learning + Skill + Karier)
- [ ] /worker/engagement — New module (Ide + Survei + Forum)
- [ ] /worker/akun — New module (Profil + Kompensasi + Dokumen + Keamanan)

### Manager Routes (1 route → needs restructure to 4 modules)
- [x] /dashboard — Current (has Beranda + Menu + Notifikasi tabs)
- [ ] /dashboard/tim — New module (Ringkasan + Approval + Analytics)
- [ ] /dashboard/kinerja — New module (Trend + Catatan + Continuous)
- [ ] /dashboard/eksekutif — New module (CEO + Health + Brief + Financial)
- [ ] /dashboard/risk — New module (Flight + Turnover + Anomaly)

### Admin Routes (37 routes → needs restructure to 7 modules)
- [x] /admin — Current (has MetricCards + QuickTiles)
- [ ] /admin/ringkasan — New module (Summary + Pending + Approval)
- [ ] /admin/people — New module (Karyawan + Org + Recruitment + Talent)
- [ ] /admin/operasional — New module (Attendance + Leave + Performance + Learning + ...)
- [ ] /admin/analytics — New module (Planning + Financial + Simulation + AI)
- [ ] /admin/integrasi — New module (Payroll + Sync + Webhooks + SSO)
- [ ] /admin/security — New module (Audit + RLS + GDPR + Session)
- [ ] /admin/system — New module (User + Approval + Data + Config)

## Key Design Principles

1. **Zero Duplikasi** — Setiap fitur muncul di exactly 1 menu
2. **Max 3 Level** — Tidak ada menu yang lebih dalam dari 3 level
3. **Action-Oriented** — Menu dinamai berdasarkan aksi, bukan entitas
4. **Role-Based** — Worker/Manager/Admin memiliki menu terpisah
5. **Global Utilities** — Search, Warning Engine, AI Copilot tersedia di semua halaman
