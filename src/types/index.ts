/**
 * Shared types for insightWOS (WOS-Web)
 * Generated as part of the TypeScript Migration (Phase 1)
 */

// ─── Auth & Session ───────────────────────────────────────────

export interface UserSession {
  nrp: string;
  nama: string;
  role: string;
  role_level: number;
  business_unit_id: string;
  business_unit?: string;
  divisi?: string;
  posisi?: string;
  is_owner?: boolean;
  email?: string;
  token?: string;
  entry?: 'admin' | 'worker' | 'dashboard' | 'owner';
  tier?: number;
  expires_at?: string;
}

export interface AuthUser {
  id: string;
  email: string;
  aud: string;
  role: string;
}

// ─── RPC Responses ────────────────────────────────────────────

export interface RpcOk<T = Record<string, unknown>> {
  ok: true;
  data?: T;
  msg?: string;
}

export interface RpcError {
  ok: false;
  msg: string;
}

export type RpcResult<T = Record<string, unknown>> = RpcOk<T> | RpcError;

export interface LoginWorkerResponse {
  ok: boolean;
  msg?: string;
  token?: string;
  role?: string;
  nama?: string;
  nrp?: string;
  nik?: string;
  role_level?: number;
  business_unit_id?: string;
  business_unit?: string;
  tier?: number;
  email?: string;
}

export interface LoginWorkerByEmailResponse extends LoginWorkerResponse {
  nik?: string;
}

export interface UserContext {
  ok: boolean;
  nrp?: string;
  role?: string;
  nama?: string;
  role_level?: number;
  business_unit_id?: string;
  unit_code?: string;
  tier?: number;
  is_owner?: boolean;
  msg?: string;
}

export interface CurrentUserContext {
  nrp: string | null;
  nama?: string;
  role?: string;
  role_level?: number;
  business_unit_id?: string;
  divisi?: string;
  posisi?: string;
  is_owner?: boolean;
  email?: string;
}

// ─── Employee ─────────────────────────────────────────────────

export interface Employee {
  nrp: string;
  employee_id?: string;
  nik: string;
  nama: string;
  email: string;
  divisi: string;
  posisi: string;
  status_kerja: string;
  business_unit: string;
  business_unit_id?: string;
  site_id?: string;
  role_level: number;
  auth_id?: string;
  is_active: boolean;
  jabatan?: string;
  divisi_code?: string;
  position_code?: string;
  level_jabatan?: string;
  tanggal_masuk?: string;
  contract_end_date?: string;
  resign_date?: string;
  created_at?: string;
  updated_at?: string;
  lokasi_penempatan?: string;
  updated_by?: string;
  status_kerja_internal?: string;
}

// ─── Payroll ──────────────────────────────────────────────────

export interface PayrollRow {
  nrp: string;
  nama: string;
  divisi: string;
  gross_salary: number;
  total_potongan: number;
  nett_salary: number;
  status: string;
  jenis: string;
  nama_bank?: string;
  no_rekening?: string;
}

export interface PayrollSummary {
  total_net: number;
  total_employees: number;
  avg_salary: number;
  total_deduction_items: number;
}

// ─── Attendance ───────────────────────────────────────────────

export interface AttendanceRecord {
  date: string;
  status_hadir: string;
  jam_masuk: string;
  jam_keluar: string;
  shift: string;
  menit_terlambat: number;
}

// ─── Leave ────────────────────────────────────────────────────

export interface LeaveQuota {
  kuota_cuti: number;
  cuti_terpakai: number;
}

export interface LeaveRequest {
  id: number;
  type: string;
  sub_type: string;
  status: string;
  note: string;
  created_at: string;
}

// ─── Announcements ────────────────────────────────────────────

export interface Announcement {
  id: number;
  title: string;
  message: string;
  priority: string;
}

// ─── Dashboard Stats ──────────────────────────────────────────

export interface DashboardStats {
  total_workers: number;
  total_divisions: number;
  pending_requests: number;
  pkwt_count: number;
  pkwtt_count: number;
  retiring_soon: number;
}

// ─── Worker Status ────────────────────────────────────────────

export interface WorkerStatus {
  attendance_hadir: number;
  attendance_total: number;
  pending_requests: number;
  unread_notifications: number;
}

export interface WorkerNarrative {
  sapaan: string;
  analisis: string;
  action_plan: string;
  penutup: string;
  kpi_score: number;
  kpi_target: number;
}

// ─── Modules ──────────────────────────────────────────────────

export interface ModuleRoute {
  module_code: string;
  route_path: string;
  route_component: string;
  route_group: string;
}

// ─── Branding ─────────────────────────────────────────────────

export interface Branding {
  company_name: string;
  logo_url: string;
  favicon_url?: string;
  primary_color?: string;
  secondary_color?: string;
}

// ─── Industry (Mining/Estate/Mill) ────────────────────────────

export interface SafetyIncident {
  id: number;
  incident_date: string;
  incident_type: string;
  severity: string;
  zone: string;
  status: string;
  description: string;
  reported_by: string;
}

export interface JsaEntry {
  id: number;
  job_title: string;
  hazards: string[];
  controls: string[];
  risk_level: string;
  valid_until: string;
}

export interface ProductionDaily {
  id: number;
  production_date: string;
  zone: string;
  product: string;
  target_qty: number;
  actual_qty: number;
  shift: string;
}

export interface HeavyEquipment {
  id: number;
  equipment_type: string;
  brand: string;
  status: string;
  operator_nrp?: string;
  hours_used: number;
  fuel_level: number;
}

export interface FatigueData {
  id: number;
  nrp: string;
  shift: string;
  hours_worked: number;
  hours_rest: number;
  fatigue_level: string;
  status: string;
}

export interface SimperData {
  id: number;
  nrp: string;
  zone: string;
  purpose: string;
  valid_until: string;
  issued_by: string;
}

// ─── Rate Limiting ────────────────────────────────────────────

export interface RateLimitInfo {
  allowed: boolean;
  retryAfter?: number;
  remaining?: number;
  limit?: number;
}

// ─── AI Copilot ───────────────────────────────────────────────

export interface AiCopilotResponse {
  message: string;
  sources?: string[];
  db_data?: DbDataItem[];
}

export interface DbDataItem {
  category: string;
  data: Record<string, unknown>;
}

// ─── Chart Config ─────────────────────────────────────────────

export interface ChartDataset {
  label: string;
  data: number[];
  backgroundColor?: string | string[];
  borderColor?: string;
  borderWidth?: number;
}
