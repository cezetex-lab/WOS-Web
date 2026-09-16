/**
 * supabase-rpc.ts — typed wrappers untuk RPC yang sudah dikenal.
 *
 * Implementasi `rpc()` TIDAK diduplikasi di sini (audit L1). File ini me-reexport
 * implementasi kanonik dari `supabase-browser` supaya hanya ada SATU kontrak:
 * sukses mengembalikan payload apa adanya, gagal mengembalikan `RpcError`
 * (`{ ok: false, msg, kind }`). Sebelumnya file ini punya salinan sendiri yang
 * mengembalikan `{ ok: false, msg } as T` — jadi perbaikan di satu tempat tidak
 * berlaku di tempat lain, dan pemanggil bisa menerima bentuk yang salah tanpa
 * error tipe.
 *
 * Usage:
 *   import { rpcGetBranding, isRpcError } from '@/lib/supabase-rpc';
 *   const d = await rpcGetBranding();
 *   if (isRpcError(d)) return;   // kegagalan transport / rate-limit
 */

import { rpc, isRpcError } from './supabase-browser';
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
  RpcError,
} from '@/types';

export { rpc, isRpcError };

// ─── Typed RPC Functions ──────────────────────────────────────
// Setiap wrapper mengembalikan `T | RpcError` supaya pemanggil WAJIB menangani
// kegagalan transport — bukan menganggapnya sebagai data.

/** Login worker by NRP+NIK+Password */
export function rpcLoginWorker(params: {
  p_nrp: string;
  p_nik: string;
  p_password: string;
}): Promise<LoginWorkerResponse | RpcError> {
  return rpc<LoginWorkerResponse>('login_worker', params);
}

/** Login worker by Email+Password (new) */
export function rpcLoginWorkerByEmail(params: {
  p_email: string;
  p_password: string;
}): Promise<LoginWorkerByEmailResponse | RpcError> {
  return rpc<LoginWorkerByEmailResponse>('login_worker_by_email', params);
}

/** Get user context by auth ID */
export function rpcGetUserContextByAuthId(params: {
  p_auth_id: string;
}): Promise<UserContext | RpcError> {
  return rpc<UserContext>('get_user_context_by_auth_id', params);
}

/** Get current user context (from JWT) */
export function rpcGetCurrentUserContext(): Promise<CurrentUserContext | RpcError> {
  return rpc<CurrentUserContext>('get_current_user_context');
}

/** Get enabled modules for an area */
export function rpcGetEnabledModules(params: {
  p_area: string;
}): Promise<ModuleRoute[] | RpcError> {
  return rpc<ModuleRoute[]>('get_enabled_modules', params);
}

/** Get branding */
export function rpcGetBranding(): Promise<Branding | RpcError> {
  return rpc<Branding>('get_branding');
}

/** Get worker status */
export function rpcGetWorkerStatus(): Promise<WorkerStatus | RpcError> {
  return rpc<WorkerStatus>('get_worker_status');
}

/** Get worker narrative */
export function rpcGetWorkerNarrative(): Promise<WorkerNarrative | RpcError> {
  return rpc<WorkerNarrative>('get_worker_narrative');
}

/** Get announcements */
export function rpcGetAnnouncements(): Promise<{ data: Announcement[] } | RpcError> {
  return rpc<{ data: Announcement[] }>('get_announcements');
}

/** Get payroll data (admin) */
export function rpcAdminGetPayroll(): Promise<PayrollRow[] | RpcError> {
  return rpc<PayrollRow[]>('admin_get_payroll');
}

/** Get payroll summary (admin) */
export function rpcAdminGetPayrollSummary(): Promise<PayrollSummary | RpcError> {
  return rpc<PayrollSummary>('admin_get_payroll_summary');
}

/** Get dashboard stats */
export function rpcGetDashboardStats(): Promise<DashboardStats | RpcError> {
  return rpc<DashboardStats>('get_dashboard_stats');
}

/** Get worker leave quota */
export function rpcGetWorkerLeave(): Promise<LeaveQuota | RpcError> {
  return rpc<LeaveQuota>('get_worker_leave');
}

/** Get worker requests */
export function rpcGetWorkerRequests(): Promise<{
  ok: boolean;
  data: LeaveRequest[];
} | RpcError> {
  return rpc<{ ok: boolean; data: LeaveRequest[] }>('get_worker_requests');
}

/** Get worker attendance */
export function rpcGetWorkerAttendance(): Promise<AttendanceRecord[] | RpcError> {
  return rpc<AttendanceRecord[]>('get_worker_attendance');
}

/** Check login lockout */
export function rpcCheckLoginLockout(params: {
  p_identifier: string;
  p_attempt_type: string;
}): Promise<{ locked: boolean; reason?: string } | RpcError> {
  return rpc<{ locked: boolean; reason?: string }>('check_login_lockout', params);
}

/** Register session */
export function rpcRegisterSession(params: {
  p_session_id: string;
}): Promise<{ ok: boolean } | RpcError> {
  return rpc<{ ok: boolean }>('register_session', params);
}

/** Get worker profile for self-service edit */
export function rpcGetWorkerProfile(params: {
  p_nrp: string;
}): Promise<
  | {
      ok: boolean;
      data: {
        nrp?: string;
        nik?: string;
        nama?: string;
        email?: string;
        no_hp?: string;
        alamat?: string;
        divisi?: string;
        posisi?: string;
        status_kerja?: string;
        tanggal_masuk?: string;
        tanggal_lahir?: string;
        jenis_kelamin?: string;
        atasan_nrp?: string;
        agama?: string;
        media_sosial?: string | Record<string, any>;
        jenjang_pendidikan?: string;
        no_bpjs_kesehatan?: string;
        no_bpjs_ketenagakerjaan?: string;
        riwayat_penyakit?: string;
        komorbid?: string;
        alergi?: string;
        nama_bank?: string;
        no_rekening?: string;
        nama_rekening?: string;
        lokasi_penempatan?: string;
        updated_by?: string;
        status_kerja_internal?: string;
      };
    }
  | RpcError
> {
  return rpc('get_worker_profile', params);
}

/** Update worker self-service profile fields */
export function rpcWorkerUpdateProfile(params: {
  p_nrp: string;
  p_no_hp?: string | null;
  p_alamat?: string | null;
  p_agama?: string | null;
  p_media_sosial?: string | Record<string, any> | null;
  p_jenjang_pendidikan?: string | null;
  p_no_bpjs_kesehatan?: string | null;
  p_no_bpjs_ketenagakerjaan?: string | null;
  p_riwayat_penyakit?: string | null;
  p_komorbid?: string | null;
  p_alergi?: string | null;
  p_nama_bank?: string | null;
  p_no_rekening?: string | null;
  p_nama_rekening?: string | null;
  p_lokasi_penempatan?: string | null;
}): Promise<{ ok: boolean; msg?: string } | RpcError> {
  return rpc('worker_update_profile', params);
}
