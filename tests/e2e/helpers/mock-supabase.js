/**
 * mock-supabase.js — Deterministic Supabase mock for E2E tests (Q5).
 *
 * Intercepts every network call the frontend makes to Supabase (REST RPC,
 * Auth REST, Edge Functions) and serves canned responses, so the 5 Q5 flows
 * run in CI without real credentials and without touching production.
 *
 * It also replaces /sw.js with a no-op service worker: the real one uses
 * network-first for *.supabase.co requests, which would bypass Playwright's
 * route interception on page reloads (where the SW is already active).
 *
 * Usage:
 *   import { mockSupabase } from './helpers/mock-supabase';
 *   test('...', async ({ page }) => {
 *     const mock = await mockSupabase(page);
 *     ...
 *   });
 */
import { expect } from '@playwright/test';

// .env.local is loaded by playwright.config.js — VITE_SUPABASE_URL must be
// the same URL the app embeds, otherwise interception patterns won't match.
export const SUPABASE_URL = process.env.VITE_SUPABASE_URL || 'https://placeholder.supabase.co';

const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

// ─────────────────────────────────────────────────────────────
// Mock users (worker + admin roles used across the 5 flows)
// ─────────────────────────────────────────────────────────────
export const MOCK_USERS = {
  worker: {
    id: '00000000-0000-0000-0000-000000000001',
    email: 'budi@insightwos.test',
    nrp: 'NRP001',
    nama: 'Budi Santoso',
    role: 'worker',
    role_level: 1,
    business_unit_id: 'BU-HQ',
    business_unit: 'HQ',
    unit_code: 'HQ',
    tier: 1,
  },
  admin_pusat: {
    id: '00000000-0000-0000-0000-000000000101',
    email: 'admin.pusat@insightwos.test',
    nrp: 'ADM001',
    nama: 'Siti Administrator',
    role: 'admin_pusat',
    role_level: 9,
    business_unit_id: 'BU-HQ',
    business_unit: 'HQ',
    unit_code: 'HQ',
    tier: 5,
  },
  admin_finance: {
    id: '00000000-0000-0000-0000-000000000102',
    email: 'finance@insightwos.test',
    nrp: 'ADM002',
    nama: 'Rina Finance',
    role: 'admin_finance',
    role_level: 7,
    business_unit_id: 'BU-HQ',
    business_unit: 'HQ',
    unit_code: 'HQ',
    tier: 4,
  },
  admin_hrd: {
    id: '00000000-0000-0000-0000-000000000103',
    email: 'hrd@insightwos.test',
    nrp: 'ADM003',
    nama: 'Dewi HRD',
    role: 'admin_hrd',
    role_level: 7,
    business_unit_id: 'BU-HQ',
    business_unit: 'HQ',
    unit_code: 'HQ',
    tier: 4,
  },
};

export const WORKER_LOGIN = { nrp: MOCK_USERS.worker.nrp, nik: '1234567890', password: 'Test123!' };
export const ADMIN_LOGIN = { email: MOCK_USERS.admin_pusat.email, password: 'Admin123!' };

// ─────────────────────────────────────────────────────────────
// Mock data
// ─────────────────────────────────────────────────────────────

// Module routes consumed by DynamicRoutes (get_enabled_modules).
// Only the modules the Q5 flows actually visit are needed here.
const MODULES = [
  { module_code: 'ATTENDANCE', route_path: '/worker/attendance', route_component: 'WorkerAttendance', route_group: 'worker' },
  { module_code: 'LEAVE', route_path: '/worker/leave', route_component: 'WorkerLeave', route_group: 'worker' },
  { module_code: 'PAYROLL_W', route_path: '/worker/payroll', route_component: 'WorkerPayroll', route_group: 'worker' },
  { module_code: 'PAYROLL', route_path: '/admin/payroll', route_component: 'Payroll', route_group: 'admin' },
  { module_code: 'OVERTIME', route_path: '/worker/overtime', route_component: 'WorkerOvertime', route_group: 'worker' },
  { module_code: 'KPI', route_path: '/worker/kpi', route_component: 'WorkerKpi', route_group: 'worker' },
  { module_code: 'PROFILE', route_path: '/worker/profile', route_component: 'WorkerProfile', route_group: 'worker' },
  { module_code: 'LEARNING', route_path: '/worker/learning', route_component: 'WorkerLearning', route_group: 'worker' },
  { module_code: 'CAREER', route_path: '/worker/career', route_component: 'WorkerCareer', route_group: 'worker' },
  { module_code: 'ACTIVITIES', route_path: '/worker/activities', route_component: 'WorkerActivities', route_group: 'worker' },
  { module_code: 'TASKS', route_path: '/worker/tasks', route_component: 'TaskBoard', route_group: 'worker' },
];

const PAYROLL_ROWS = [
  { nrp: 'NRP001', nama: 'Budi Santoso', divisi: 'Korporat', gross_salary: 8500000, total_potongan: 1200000, nett_salary: 7300000, status: 'Processed', jenis: 'PKWTT' },
  { nrp: 'NRP002', nama: 'Andi Wijaya', divisi: 'Tambang', gross_salary: 9000000, total_potongan: 1400000, nett_salary: 7600000, status: 'Pending', jenis: 'PKWT' },
  { nrp: 'NRP003', nama: 'Cici Lestari', divisi: 'Pabrik', gross_salary: 7500000, total_potongan: 1000000, nett_salary: 6500000, status: 'Paid', jenis: 'PKWTT' },
  { nrp: 'NRP004', nama: 'Deni Pratama', divisi: 'Perkebunan', gross_salary: 6800000, total_potongan: 900000, nett_salary: 5900000, status: 'Draft', jenis: 'PKWT' },
];

// Attendance records for the current month (so the calendar + stats render).
function makeAttendanceRecords() {
  const now = new Date();
  const y = now.getFullYear();
  const m = now.getMonth();
  const records = [];
  for (let d = 1; d <= 5; d++) {
    records.push({
      date: `${y}-${String(m + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}`,
      status_hadir: d === 2 ? 'Terlambat' : 'Hadir',
      jam_masuk: d === 2 ? '08:15:00' : '07:45:00',
      jam_keluar: '16:30:00',
      shift: 'Pagi',
      menit_terlambat: d === 2 ? 15 : 0,
    });
  }
  return records;
}

// ─────────────────────────────────────────────────────────────
// Per-RPC responses
// ─────────────────────────────────────────────────────────────
function handleRpc(fn, params, state) {
  const u = state.user;
  switch (fn) {
    case 'get_branding':
      return { company_name: 'insightWOS', logo_url: '' };

    case 'check_login_lockout':
      return { locked: false };

    case 'login_worker': {
      if (state.registeredSessions.size >= state.maxSessions) {
        return { ok: false, msg: 'Sesi aktif melebihi batas maksimum. Silakan logout dari perangkat lain.' };
      }
      const w = MOCK_USERS.worker;
      return {
        ok: true,
        token: 'mock-worker-token',
        role: w.role,
        nama: w.nama,
        nrp: w.nrp,
        role_level: w.role_level,
        business_unit_id: w.business_unit_id,
        business_unit: w.business_unit,
        tier: w.tier,
        email: w.email,
      };
    }

    case 'get_user_context_by_auth_id': {
      if (!u) return { ok: false, msg: 'Akun tidak ditemukan di sistem' };
      return {
        ok: true,
        nrp: u.nrp,
        role: u.role,
        nama: u.nama,
        role_level: u.role_level,
        business_unit_id: u.business_unit_id,
        unit_code: u.unit_code || 'HQ',
        tier: u.tier,
      };
    }

    case 'get_current_user_context': {
      if (!u) return { nrp: null };
      return {
        nrp: u.nrp,
        nama: u.nama,
        role: u.role,
        role_level: u.role_level,
        business_unit_id: u.business_unit_id,
        divisi: 'Korporat',
        posisi: 'Staff',
        is_owner: u.role === 'owner',
        email: u.email,
      };
    }

    case 'register_session': {
      if (params.p_session_id) state.registeredSessions.add(params.p_session_id);
      return { ok: true };
    }

    case 'get_enabled_modules':
      return MODULES;

    case 'get_worker_status':
      return { attendance_hadir: 18, attendance_total: 20, pending_requests: 2, unread_notifications: 3 };

    case 'get_worker_narrative':
      return {
        sapaan: 'Halo, Budi!',
        analisis: 'Performa Anda stabil bulan ini.',
        action_plan: 'Pertahankan tren positif Anda.',
        penutup: 'Tim HRD siap mendukung.',
        kpi_score: 85,
        kpi_target: 100,
      };

    // Worker.jsx reads `annData?.data` where annData is the RPC body.
    case 'get_announcements':
      return {
        data: [
          { id: 1, title: 'Hari Libur Nasional', message: 'Libur tanggal merah minggu ini.', priority: 'HIGH' },
        ],
      };

    case 'get_worker_attendance':
      return makeAttendanceRecords();

    case 'get_worker_leave':
      return { ok: true, kuota_cuti: 12, cuti_terpakai: 3 };

    case 'get_worker_requests':
      return {
        ok: true,
        data: [
          { id: 1, type: 'CUTI', sub_type: 'Cuti Tahunan', status: 'Pending', note: 'Liburan keluarga', created_at: '2026-09-01T00:00:00Z' },
        ],
      };

    case 'admin_get_payroll':
      return PAYROLL_ROWS;

    case 'admin_get_payroll_summary':
      return { total_net: 27300000, total_employees: 4, avg_salary: 6825000, total_deduction_items: 4 };

    case 'get_dashboard_stats':
      return { total_workers: 120, total_divisions: 8, pending_requests: 3, pkwt_count: 40, pkwtt_count: 80, retiring_soon: 5 };

    case 'admin_get_pending_requests':
      return [];

    case 'get_auto_healing_actions':
      return [];

    case 'get_anomaly_sentinel':
      return [];

    case 'check_owner_identity':
      return u && u.role === 'owner';

    default:
      return { ok: false, msg: `[mock] no handler for ${fn}` };
  }
}

function buildAuthSession(user) {
  const now = Math.floor(Date.now() / 1000);
  return {
    access_token: `mock-access-token-${user.id}`,
    token_type: 'bearer',
    expires_in: 36000,
    expires_at: now + 36000,
    refresh_token: `mock-refresh-token-${user.id}`,
    user: {
      id: user.id,
      aud: 'authenticated',
      role: 'authenticated',
      email: user.email,
      app_metadata: { role: 'authenticated' },
      user_metadata: {},
      created_at: '2026-01-01T00:00:00Z',
    },
  };
}

/**
 * Server-side mock state (per test, can be shared across tabs/pages so the
 * concurrent-session simulation behaves like a real backend).
 */
export function createMockState({ maxSessions = Infinity, user = null } = {}) {
  return { user, maxSessions, registeredSessions: new Set() };
}

/**
 * Set up all Supabase mocks on a page. Call once per test (before navigation).
 *
 * @param {import('@playwright/test').Page} page
 * @param {object} [opts]
 * @param {number} [opts.maxSessions] — simulate concurrent-session limit for login_worker
 * @param {object} [opts.user] — pre-authenticated user (context)
 * @param {object} [opts.state] — shared mock state (from createMockState / a previous call)
 */
export async function mockSupabase(page, { maxSessions = Infinity, user = null, state } = {}) {
  if (!state) state = createMockState({ maxSessions, user });
  else {
    // Reuse shared state; apply overrides if provided.
    if (maxSessions !== Infinity) state.maxSessions = maxSessions;
    if (user) state.user = user;
  }

  const json = (route, body, status = 200) =>
    route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) });

  // 1) Neutralize the service worker entirely. The real sw.js (network-first
  //    for navigations and *.supabase.co GETs) would serve cached responses and
  //    bypass Playwright route interception — but page.route() does NOT
  //    intercept the sw.js registration fetch, so we must kill registration.
  await page.addInitScript(() => {
    try {
      // Unregister any existing SW + clear caches (fresh contexts have none,
      // but this makes the mock robust if a profile is ever reused).
      if ('serviceWorker' in navigator) {
        navigator.serviceWorker.getRegistrations().then((regs) =>
          regs.forEach((r) => r.unregister())
        );
        navigator.serviceWorker.register = () => Promise.resolve({});
      }
      if (window.caches) {
        caches.keys().then((keys) => keys.forEach((k) => caches.delete(k)));
      }
    } catch { /* ignore */ }

    // 2) Pre-accept the privacy consent modal so it never blocks the UI.
    try { localStorage.setItem('wos_privacy_consent', 'true'); } catch { /* ignore */ }
  });

  // 3) Edge functions (MFA check + AI copilot + worker auth-sync).
  await page.route(`${SUPABASE_URL}/functions/v1/mfa-service`, (route) =>
    json(route, { mfa_enabled: false, enabled: false })
  );
  await page.route(`${SUPABASE_URL}/functions/v1/ai-copilot`, (route) =>
    json(route, { message: 'Mock AI response.', sources: [] })
  );
  // worker-auth-sync: default = provisioning sukses (dapat di-unroute
  // per-test untuk skenario MFA/gagal — lihat worker-auth-mfa-flow.spec.js).
  await page.route(`${SUPABASE_URL}/functions/v1/worker-auth-sync`, (route) =>
    json(route, {
      ok: true,
      email: 'budi@insightwos.test',
      temp_password: 'mock-temp-pass-1234567890',
      auth_id: MOCK_USERS.worker.id,
    })
  );

  // 4) Supabase Auth REST.
  await page.route(new RegExp(`^${esc(SUPABASE_URL)}/auth/v1/(token|user|logout)`), async (route) => {
    const req = route.request();
    const url = new URL(req.url());
    const grantType = url.searchParams.get('grant_type');
    const method = req.method();

    // Password / refresh sign-in → establishes the session (and current user).
    if (url.pathname.endsWith('/token') && method === 'POST') {
      const body = req.postDataJSON?.() || {};
      const email = (body.email || '').toLowerCase();
      const match = Object.values(MOCK_USERS).find((u) => u.email.toLowerCase() === email);
      if (!match) {
        return json(route, { error: 'invalid_grant', error_description: 'Invalid login credentials' }, 400);
      }
      state.user = match;
      return json(route, buildAuthSession(match));
    }

    // GET /user → current user (or 401 when not authenticated).
    if (url.pathname.endsWith('/user')) {
      if (!state.user) return json(route, { msg: 'Invalid JWT' }, 401);
      const { id, email } = state.user;
      return json(route, { id, aud: 'authenticated', role: 'authenticated', email, app_metadata: {}, user_metadata: {}, created_at: '2026-01-01T00:00:00Z' });
    }

    // POST /logout → 204 (supabase-js clears its own storage).
    if (url.pathname.endsWith('/logout')) {
      return route.fulfill({ status: 204, body: '' });
    }

    // Unknown auth call → pass through with a generic empty response.
    return json(route, {}, 404);
  });

  // 5) Supabase REST RPC.
  await page.route(new RegExp(`^${esc(SUPABASE_URL)}/rest/v1/rpc/([^/?]+)`), async (route) => {
    const match = route.request().url().match(new RegExp(`${esc(SUPABASE_URL)}/rest/v1/rpc/([^/?]+)`));
    const fn = decodeURIComponent(match[1]);
    const params = route.request().postDataJSON?.() || {};
    return json(route, handleRpc(fn, params, state));
  });

  return {
    state,
    /** Swap the "current user" (e.g. to simulate an immediate role change). */
    setUser: (u) => { state.user = u; },
  };
}

/**
 * Perform a full worker login through the real UI (with mocked backend).
 * Assumes mockSupabase(page) was already called.
 */
export async function loginAsWorker(page) {
  await page.goto('/');
  await expect(page.locator('input[placeholder*="NRP"]')).toBeVisible();
  await page.locator('input[placeholder*="NRP"]').fill(WORKER_LOGIN.nrp);
  await page.locator('input[placeholder*="NIK"]').fill(WORKER_LOGIN.nik);
  await page.locator('input[placeholder*="password"]').fill(WORKER_LOGIN.password);
  await page.locator('button[type="submit"]').click();
  await page.waitForURL('**/worker', { timeout: 15000 });
  await expect(page.getByRole('heading', { name: /Ringkasan Hari Ini/i })).toBeVisible();
}

/**
 * Perform a full admin login through the real UI (with mocked backend).
 * @param {string} role - one of MOCK_USERS keys (admin_pusat | admin_finance | admin_hrd)
 */
export async function loginAsAdmin(page, role = 'admin_pusat') {
  const u = MOCK_USERS[role];
  await page.goto('/');
  await page.locator('button', { hasText: 'Admin' }).click();
  await expect(page.locator('input[type="email"]')).toBeVisible();
  await page.locator('input[type="email"]').fill(u.email);
  await page.locator('input[type="password"]').fill(ADMIN_LOGIN.password);
  await page.locator('button[type="submit"]').click();
  await page.waitForURL('**/admin', { timeout: 15000 });
  await expect(page.getByRole('heading', { name: /Selamat Datang, Admin/i })).toBeVisible();
}