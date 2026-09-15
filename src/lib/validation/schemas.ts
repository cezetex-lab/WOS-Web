/**
 * validation/schemas.ts — Zod schemas for input validation
 *
 * Used by:
 *   - Frontend forms (real-time validation)
 *   - Edge functions (server-side validation)
 *   - E2E tests (schema assertions)
 *
 * Convention: schemas are prefixed with the entity name,
 * e.g. `LoginWorkerSchema`, `EmployeeSchema`.
 */

import { z } from 'zod';

// ─── Auth ─────────────────────────────────────────────────────

export const LoginWorkerSchema = z.object({
  nrp: z.string().min(3, 'NRP minimal 3 karakter').max(20),
  nik: z.string().regex(/^\d{16}$/, 'NIK harus 16 digit'),
  password: z.string().min(6, 'Password minimal 6 karakter'),
});

export const LoginEmailSchema = z.object({
  email: z.string().email('Email tidak valid'),
  password: z.string().min(6, 'Password minimal 6 karakter'),
});

export const LoginAdminSchema = z.object({
  email: z.string().email('Email tidak valid'),
  password: z.string().min(6, 'Password minimal 6 karakter'),
});

export const OtpSchema = z.object({
  code: z.string().length(6, 'OTP harus 6 digit').regex(/^\d+$/, 'OTP hanya angka'),
});

// ─── Registration ─────────────────────────────────────────────

export const RegistrationSchema = z.object({
  nrp: z.string().min(3, 'NRP minimal 3 karakter').max(20),
  nik: z.string().regex(/^\d{16}$/, 'NIK harus 16 digit'),
  nama: z.string().min(2, 'Nama minimal 2 karakter').max(100),
  email: z.string().email('Email tidak valid'),
  divisi: z.string().min(1, 'Divisi wajib diisi'),
  posisi: z.string().min(1, 'Posisi wajib diisi'),
  password: z.string().min(8, 'Password minimal 8 karakter'),
});

// ─── Employee ─────────────────────────────────────────────────

export const EmployeeCoreSchema = z.object({
  nrp: z.string().min(3).max(20),
  nik: z.string().regex(/^\d{16}$/, 'NIK harus 16 digit'),
  nama: z.string().min(2).max(100),
  email: z.string().email(),
  divisi: z.string().min(1),
  posisi: z.string().min(1),
  status_kerja: z.enum(['Aktif', 'Non-Aktif', 'Resign', 'PHK']),
  business_unit: z.string().min(1),
  role_level: z.number().int().min(1).max(9),
  is_active: z.boolean(),
});

export const EmployeeExtendedSchema = z.object({
  agama: z.string().optional(),
  media_sosial: z.record(z.string(), z.string()).optional(),
  jenjang_pendidikan: z.string().optional(),
  no_bpjs_kesehatan: z.string().optional(),
  no_bpjs_ketenagakerjaan: z.string().optional(),
  riwayat_penyakit: z.string().optional(),
  komorbid: z.string().optional(),
  alergi: z.string().optional(),
  nama_bank: z.string().optional(),
  no_rekening: z.string().optional(),
  nama_rekening: z.string().optional(),
});

// ─── Leave Request ────────────────────────────────────────────

export const LeaveRequestSchema = z.object({
  leave_type: z.string().min(1, 'Jenis cuti wajib dipilih'),
  start_date: z.string().min(1, 'Tanggal mulai wajib diisi'),
  end_date: z.string().min(1, 'Tanggal selesai wajib diisi'),
  reason: z.string().min(3, 'Alasan minimal 3 karakter').max(500),
}).refine(
  (data) => new Date(data.end_date) >= new Date(data.start_date),
  { message: 'Tanggal selesai harus setelah tanggal mulai', path: ['end_date'] }
);

// ─── Safety Incident ──────────────────────────────────────────

export const SafetyIncidentSchema = z.object({
  incident_type: z.enum(['NEAR_MISS', 'INCIDENT', 'OBSERVATION']),
  severity: z.enum(['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']),
  zone: z.string().min(1, 'Zona wajib diisi'),
  description: z.string().min(5, 'Deskripsi minimal 5 karakter').max(2000),
});

// ─── Facility Request ─────────────────────────────────────────

export const FacilityRequestSchema = z.object({
  facility_type: z.string().min(1, 'Jenis fasilitas wajib dipilih'),
  description: z.string().min(5, 'Deskripsi minimal 5 karakter').max(2000),
  priority: z.enum(['LOW', 'MEDIUM', 'HIGH']),
});

// ─── Harvest Record ───────────────────────────────────────────

export const HarvestRecordSchema = z.object({
  crop_type: z.string().min(1, 'Jenis tanaman wajib diisi'),
  quantity: z.number().positive('Jumlah harus positif'),
  unit: z.string().min(1, 'Satuan wajib diisi'),
  block: z.string().min(1, 'Block wajib diisi'),
  notes: z.string().max(500).optional(),
});

// ─── Task ─────────────────────────────────────────────────────

export const TaskSchema = z.object({
  title: z.string().min(1, 'Judul wajib diisi').max(200),
  description: z.string().max(2000).optional(),
  priority: z.enum(['LOW', 'MEDIUM', 'HIGH', 'URGENT']),
  assignee_nrp: z.string().min(1).optional(),
  due_date: z.string().optional(),
});

// ─── Profile Update ───────────────────────────────────────────

export const ProfileUpdateSchema = z.object({
  nama: z.string().min(2).max(100).optional(),
  email: z.string().email().optional(),
  no_hp: z.string().regex(/^[\d\-\+\s]+$/, 'Format nomor HP tidak valid').optional(),
  alamat: z.string().max(500).optional(),
});

// ─── Type exports (inferred from schemas) ─────────────────────

export type LoginWorkerInput = z.infer<typeof LoginWorkerSchema>;
export type LoginEmailInput = z.infer<typeof LoginEmailSchema>;
export type LoginAdminInput = z.infer<typeof LoginAdminSchema>;
export type OtpInput = z.infer<typeof OtpSchema>;
export type RegistrationInput = z.infer<typeof RegistrationSchema>;
export type EmployeeCoreInput = z.infer<typeof EmployeeCoreSchema>;
export type EmployeeExtendedInput = z.infer<typeof EmployeeExtendedSchema>;
export type LeaveRequestInput = z.infer<typeof LeaveRequestSchema>;
export type SafetyIncidentInput = z.infer<typeof SafetyIncidentSchema>;
export type FacilityRequestInput = z.infer<typeof FacilityRequestSchema>;
export type HarvestRecordInput = z.infer<typeof HarvestRecordSchema>;
export type TaskInput = z.infer<typeof TaskSchema>;
export type ProfileUpdateInput = z.infer<typeof ProfileUpdateSchema>;
