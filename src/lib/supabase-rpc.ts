/**
 * supabase-rpc.ts — Type-safe RPC wrapper for insightWOS
 *
 * Drop-in replacement for the untyped `rpc()` in supabase-browser.js.
 * Provides typed overloads for known RPCs + a generic fallback.
 *
 * Usage:
 *   import { rpc } from '@/lib/supabase-rpc';
 *   const result = await rpc('login_worker_by_email', { p_email: '...', p_password: '...' });
 *   if (result.ok) { /* typed as LoginWorkerByEmailResponse * / }
 */

import { supabase } from './supabase-browser';
import { checkRateLimit } from './rate-limiter';
import type {
  LoginWorkerResponse,
  LoginWorkerByEmailResponse,
  UserContext,
  CurrentUserContext,
  ModuleRoute,
  Branding,
  WorkerStatus,
  WorkerNarrative,
  Announcement,
  PayrollRow,
  PayrollSummary,
  DashboardStats,
  LeaveQuota,
  LeaveRequest,
  AttendanceRecord,
  Employee,
} from '@/types';

// ─── Generic RPC ──────────────────────────────────────────────

/**
 * Type-safe RPC call. Use the typed overloads for known functions,
 * or the generic fallback for unknown ones.
 */
export async function rpc<T = Record<string, unknown>>(
  fn: string,
  params: Record<string, unknown> = {},
): Promise<T> {
  const { allowed, retryAfter } = checkRateLimit(fn);
  if (!allowed) {
    console.error(`[RPC] Rate limited for ${fn}. Retry in ${retryAfter}s`);
    return { ok: false, msg: `Rate limited. Retry in ${retryAfter}s.` } as T;
  }

  const { data, error } = await supabase.rpc(fn, params);
  if (error) {
    console.error(`[RPC] Error calling ${fn}:`, error);
    return { ok: false, msg: error.message } as T;
  }
  return (data || { ok: false, msg: 'No response' }) as T;
}

// ─── Typed RPC Functions ──────────────────────────────────────

/** Login worker by NRP+NIK+Password (legacy) */
export function rpcLoginWorker(params: {
  p_nrp: string;
  p_nik: string;
  p_password: string;
}): Promise<LoginWorkerResponse> {
  return rpc<LoginWorkerResponse>('login_worker', params);
}

/** Login worker by Email+Password (new) */
export function rpcLoginWorkerByEmail(params: {
  p_email: string;
  p_password: string;
}): Promise<LoginWorkerByEmailResponse> {
  return rpc<LoginWorkerByEmailResponse>('login_worker_by_email', params);
}

/** Get user context by auth ID */
export function rpcGetUserContextByAuthId(params: {
  p_auth_id: string;
}): Promise<UserContext> {
  return rpc<UserContext>('get_user_context_by_auth_id', params);
}

/** Get current user context (from JWT) */
export function rpcGetCurrentUserContext(): Promise<CurrentUserContext> {
  return rpc<CurrentUserContext>('get_current_user_context');
}

/** Get enabled modules for an area */
export function rpcGetEnabledModules(params: {
  p_area: string;
}): Promise<ModuleRoute[]> {
  return rpc<ModuleRoute[]>('get_enabled_modules', params);
}

/** Get branding */
export function rpcGetBranding(): Promise<Branding> {
  return rpc<Branding>('get_branding');
}

/** Get worker status */
export function rpcGetWorkerStatus(): Promise<WorkerStatus> {
  return rpc<WorkerStatus>('get_worker_status');
}

/** Get worker narrative */
export function rpcGetWorkerNarrative(): Promise<WorkerNarrative> {
  return rpc<WorkerNarrative>('get_worker_narrative');
}

/** Get announcements */
export function rpcGetAnnouncements(): Promise<{ data: Announcement[] }> {
  return rpc<{ data: Announcement[] }>('get_announcements');
}

/** Get payroll data (admin) */
export function rpcAdminGetPayroll(): Promise<PayrollRow[]> {
  return rpc<PayrollRow[]>('admin_get_payroll');
}

/** Get payroll summary (admin) */
export function rpcAdminGetPayrollSummary(): Promise<PayrollSummary> {
  return rpc<PayrollSummary>('admin_get_payroll_summary');
}

/** Get dashboard stats */
export function rpcGetDashboardStats(): Promise<DashboardStats> {
  return rpc<DashboardStats>('get_dashboard_stats');
}

/** Get worker leave quota */
export function rpcGetWorkerLeave(): Promise<LeaveQuota> {
  return rpc<LeaveQuota>('get_worker_leave');
}

/** Get worker requests */
export function rpcGetWorkerRequests(): Promise<{
  ok: boolean;
  data: LeaveRequest[];
}> {
  return rpc<{ ok: boolean; data: LeaveRequest[] }>('get_worker_requests');
}

/** Get worker attendance */
export function rpcGetWorkerAttendance(): Promise<AttendanceRecord[]> {
  return rpc<AttendanceRecord[]>('get_worker_attendance');
}

/** Check login lockout */
export function rpcCheckLoginLockout(params: {
  p_identifier: string;
  p_attempt_type: string;
}): Promise<{ locked: boolean; reason?: string }> {
  return rpc<{ locked: boolean; reason?: string }>('check_login_lockout', params);
}

/** Register session */
export function rpcRegisterSession(params: {
  p_session_id: string;
}): Promise<{ ok: boolean }> {
  return rpc<{ ok: boolean }>('register_session', params);
}
