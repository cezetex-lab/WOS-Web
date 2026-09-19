# ROADMAP.md — FUTURE ROADMAP

> **Pecahan dari `AGENTS.md` (2026-09-19).** Isi di bawah ini dipindahkan apa adanya —
> nomor bagian lama (`§5.7`, `§6.4`, `§7.4`, …) sengaja DIPERTAHANKAN agar rujukan lama tetap
> bisa ditelusuri. Peta bacanya ada di `AGENTS.md` (Reading Map). Jangan menaruh riwayat
> pekerjaan selesai di berkas ini — itu milik `agentsLogs.md`.

> Detail lengkap per fase: `FuturePlans.md`. Klaim kapabilitas di `FuturePlans.md`
> (tabel/RPC/berkas yang diklaim sudah ada atau belum ada) diverifikasi otomatis oleh
> `tests/unit/doc-claims-vs-live.test.ts` terhadap DB live.

## 8. FUTURE ROADMAP (dari FuturePlans.md)

> Phase 1-3 roadmap untuk kompetisi dengan Workday/SAP/ADP di segmen mining/industri.
> Detail lengkap: `FuturePlans.md`

### Phase 1: Critical Foundation (3-6 bulan)
- [ ] **Native Mobile App** (React Native/Flutter) — GPS geofencing, offline mode, biometric
- [ ] **GPS Geofencing Attendance** — define zones, verify location, radius validation
- [ ] **Auto-Approval Rules** — threshold-based, net-staffing condition, multi-level
- [ ] **Bulk Operations** — salary update, department move, leave approval
- [ ] **Payroll Engine** — gross/net calculation, tax, BPJS, payslip PDF
- [ ] **Payslip Generation** — PDF, storage, email, MOM compliance
- [ ] **Shift Swap Workflow** — request, bidding, auto-approve
- [ ] **Anonymous Reporting** — grievance, evidence upload, two-way messaging

### Phase 2: High Value Features (6-12 bulan)
- [ ] **Push Notifications** — OneSignal/FCM, notification center
- [ ] **Team Dashboard** — attendance, performance, leave, overtime
- [ ] **Performance Grid** — 360 review, coaching, KPI
- [ ] **Onboarding/Offboarding Workflow** — checklist, document, settlement
- [ ] **SSO Integration** — Okta, Azure AD, Google Workspace

### Phase 3: Competitive Edge (12-18 bulan)
- [ ] **Predictive Analytics** — flight risk, attrition, skill gap
- [ ] **Team Chat** — Supabase Realtime, file sharing
- [ ] **Recognition System** — peer recognition, badges, gamification
- [ ] **LMS Integration** — course catalog, enrollment, certificates
