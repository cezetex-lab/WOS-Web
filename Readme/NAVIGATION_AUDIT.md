# 🔍 Navigation Audit — insightWOS
**Date: 30 August 2026 | After fixes**

---

## ✅ WORKER Flow

| Step | Action | Expected | Code | Status |
|------|--------|----------|------|--------|
| 1 | Tab "Pekerja" → NRP001 + NIK + Password123 | → OTP page | `submitWorkerCredentials()` | ✅ |
| 2 | Enter OTP | → `/worker` with session `role='worker'` | `setSession({ ...d, role: 'worker' })` | ✅ |
| 3 | Reload Home | → Redirect to `/worker` | `user.role !== 'admin'` → `/worker` | ✅ |
| 4 | BottomNav "Beranda" | → `/worker` | `ROLE_CONFIG.worker.items[0].to` | ✅ |
| 5 | BottomNav "Aktivitas" | → `/worker/activities` | `ROLE_CONFIG.worker.items[1]` | ✅ |
| 6 | BottomNav "Gaji" | → `/worker/payroll` | `ROLE_CONFIG.worker.items[2]` | ✅ |
| 7 | BottomNav "Saya" | → `/worker/profile` | `ROLE_CONFIG.worker.items[3]` | ✅ |
| 8 | BottomNav "Menu" (📌) | → Opens AppDrawer (worker groups) | `getSession().role='worker'` → `WORKER_GROUPS` | ✅ |
| 9 | AppDrawer links | All `/worker/*` paths exist in Routes | `workerPage()` routes | ✅ |
| 10 | Logout button | → Clears session → `/` | `clearSession(); location.href='/'` | ✅ |
| 11 | Worker.jsx NRP | Read from `getSession().nrp` | Not `localStorage('wos_nrp')` anymore | ✅ **FIXED** |

---

## ✅ ADMIN Flow

| Step | Action | Expected | Code | Status |
|------|--------|----------|------|--------|
| 1 | Tab "Admin" → Admin123 | → OTP request page | `submitAdminCredentials()` | ✅ |
| 2 | Request OTP → Enter OTP | → `/admin` with session `role='admin'` | `setSession({ token, role: 'admin' })` | ✅ |
| 3 | Reload Home | → Redirect to `/admin` | `user.role === 'admin'` → `/admin` | ✅ |
| 4 | BottomNav "Beranda" | → `/admin` | `ROLE_CONFIG.admin.items[0].to` | ✅ |
| 5 | BottomNav "Karyawan" | → `/admin/employees` | `ROLE_CONFIG.admin.items[1]` | ✅ |
| 6 | BottomNav "Pengajuan" | → `/admin/requests` | `ROLE_CONFIG.admin.items[2]` | ✅ |
| 7 | BottomNav "Payroll" | → `/admin/payroll` | `ROLE_CONFIG.admin.items[3]` | ✅ |
| 8 | BottomNav "Menu" (📌) | → Opens AppDrawer (admin groups) | `getSession().role='admin'` → `ADMIN_GROUPS` | ✅ |
| 9 | AppDrawer links | All `/admin/*` paths exist in Routes | 8 groups, 40+ links | ✅ |
| 10 | QuickTile "Pengaturan" | → `/admin/settings` | `navigate('/admin/settings')` | ✅ |
| 11 | Settings → PKWT Alerts | → Shows expired/critical/warning | `get_pkwt_expiry_alert()` RPC | ✅ |
| 12 | Settings → Change Password | → `admin_change_password()` | Form with old/new/confirm | ✅ |
| 13 | Logout button | → Clears session → `/` | `clearSession(); location.href='/'` | ✅ |

---

## ✅ MANAGER/DASHBOARD Flow

| Step | Action | Expected | Code | Status |
|------|--------|----------|------|--------|
| 1 | Tab "Dashboard" → NRP + NIK + Password | → OTP page | `submitWorkerCredentials()` | ✅ |
| 2 | Enter OTP | → `/dashboard` with session `role='manager'` | `setSession({ ...d, role: 'manager' })` | ✅ **FIXED** |
| 3 | Reload Home | → Redirect to `/dashboard` | `user.role === 'manager'` → `/dashboard` | ✅ **FIXED** |
| 4 | Dashboard internal tabs | Beranda / Menu / Notifikasi | `setActiveTab()` internal state | ✅ |
| 5 | No BottomNav overlap | Dashboard uses own tab bar | `withNav()` removed from Dashboard route | ✅ **FIXED** |
| 6 | Quick Access tiles | Tim, KPI, Flight Risk, etc. | `setMenuDetail()` internal state | ✅ |
| 7 | Approve/Reject buttons | → `approve_team_request()` RPC | Working buttons in beranda | ✅ |
| 8 | Logout button | → Clears session → `/` | `clearSession(); location.href='/'` | ✅ |

---

## 🐛 Bugs Found & Fixed This Session

| # | Bug | File | Fix |
|---|-----|------|-----|
| 1 | BottomNav hardcoded to `/worker` for all roles | `BottomNav.jsx` | Role-aware with `ROLE_CONFIG` |
| 2 | AppDrawer shows admin menu to all roles | `AppDrawer.jsx` | Role-aware with `ROLE_MAP` |
| 3 | Worker NRP from `localStorage('wos_nrp')` wrong key | `Worker.jsx` | Use `getSession().nrp` |
| 4 | Dashboard double BottomNav (own + withNav) | `App.jsx` | Remove `withNav()` from Dashboard route |
| 5 | Manager login sets `role='worker'` | `Home.jsx` | Set `role='manager'` for dashboard tab |
| 6 | Manager reload redirects to `/worker` | `Home.jsx` | Check `role === 'manager'` → `/dashboard` |

---

## 📊 Summary

| Role | Nav Items | Drawer Groups | Routes | Status |
|------|-----------|---------------|--------|--------|
| Worker | 4 + Menu | 3 groups (10 links) | 11 routes | ✅ |
| Admin | 4 + Menu | 8 groups (40+ links) | 37 routes | ✅ |
| Manager | Internal tabs | Internal menu | 1 route (tab system) | ✅ |

**All navigation flows verified. Zero remaining nav bugs.**
