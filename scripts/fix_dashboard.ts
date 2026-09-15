import * as fs from 'fs';

let content = fs.readFileSync('src/pages/OwnerDashboard.tsx', 'utf-8');

const interfaces = `
interface Stats {
  total_employees?: number;
  active_employees?: number;
  enabled_modules?: number;
  total_modules?: number;
  total_business_units?: number;
  pending_requests?: number;
  recent_logins_24h?: number;
  total_departments?: number;
  db_size?: string;
  [key: string]: unknown;
}

interface EmployeesByBU {
  unit_name: string;
  total_employees: number;
  active_employees: number;
}

interface Module {
  module_code: string;
  module_name?: string;
  module_group: string;
  is_enabled: boolean;
  business_unit_id: string;
}

interface BusinessUnit {
  id?: string;
  bu_id?: string;
  unit_code: string;
  unit_name: string;
  description?: string;
  tier?: number;
  is_active?: boolean;
}

interface RoleData {
  id?: string;
  nrp: string;
  name?: string;
  nama?: string;
  role: string;
  role_level: number;
  business_unit?: string;
}

interface AuditLog {
  created_at: string;
  action: string;
  target_type: string;
  target_id: string;
  new_value?: unknown;
}

interface AuditAction {
  action: string;
  count: number;
}

interface SessionData {
  nrp: string;
  nama?: string;
  divisi?: string;
  type: string;
  created_at: string;
}

interface LoginStats {
  success_24h?: number;
  failed_24h?: number;
  locked_accounts?: number;
  unique_users_24h?: number;
  [key: string]: unknown;
}

interface SecuritySetting {
  label: string;
  description: string;
  config_value: any;
}

interface EmployeeData {
  nrp: string;
  nama: string;
  email?: string;
  divisi?: string;
  posisi?: string;
  business_unit?: string;
  status_kerja?: string;
  is_active?: boolean;
}

interface AnnouncementData {
  id: string | number;
  title: string;
  priority: string;
  target_audience: string;
  message?: string;
  created_at: string;
  expiry_date?: string;
}

interface NotifConfig {
  id: string | number;
  event_type: string;
  label: string;
  email_enabled: boolean;
  push_enabled: boolean;
  updated_at: string;
}

interface SysAnnouncement {
  id: string | number;
  title: string;
  type: string;
  dismissible: boolean;
  message?: string;
  created_at: string;
  end_at?: string;
}

interface AdminRole {
  id: string;
  role_code: string;
  role_name: string;
  scope_type: string;
  scope_id?: string;
  is_active: boolean;
}

interface AdminAccount {
  nrp: string;
  nama?: string;
  role_code: string;
  role_name?: string;
  assigned_at: string;
}
`;

content = content.replace("export default function OwnerDashboard() {", interfaces + "export default function OwnerDashboard() {");
content = content.replace("import { useState, useEffect, useCallback } from 'react';", "import React, { useState, useEffect, useCallback, ReactNode } from 'react';");

const replacements = [
  ['const [stats, setStats] = useState<Record<string, unknown>>({});', 'const [stats, setStats] = useState<Stats>({});'],
  ['const [employeesByBU, setEmployeesByBU] = useState<Record<string, unknown>[]>([]);', 'const [employeesByBU, setEmployeesByBU] = useState<EmployeesByBU[]>([]);'],
  ['const [modules, setModules] = useState<Record<string, unknown>[]>([]);', 'const [modules, setModules] = useState<Module[]>([]);'],
  ['const [businessUnits, setBusinessUnits] = useState<Record<string, unknown>[]>([]);', 'const [businessUnits, setBusinessUnits] = useState<BusinessUnit[]>([]);'],
  ['const [roles, setRoles] = useState<Record<string, unknown>[]>([]);', 'const [roles, setRoles] = useState<RoleData[]>([]);'],
  ['const [auditLog, setAuditLog] = useState<Record<string, unknown>>({ data: [], total: 0 });', 'const [auditLog, setAuditLog] = useState<{data: AuditLog[], total: number}>({ data: [], total: 0 });'],
  ['const [sessions, setSessions] = useState<Record<string, unknown>[]>([]);', 'const [sessions, setSessions] = useState<SessionData[]>([]);'],
  ['const [loginStats, setLoginStats] = useState<Record<string, unknown>>({});', 'const [loginStats, setLoginStats] = useState<LoginStats>({});'],
  ['const [securitySettings, setSecuritySettings] = useState<Record<string, unknown>[]>([]);', 'const [securitySettings, setSecuritySettings] = useState<SecuritySetting[]>([]);'],
  ['const [employees, setEmployees] = useState<Record<string, unknown>>({ data: [], total: 0 });', 'const [employees, setEmployees] = useState<{data: EmployeeData[], total: number}>({ data: [], total: 0 });'],
  ['const [editEmp, setEditEmp] = useState<Record<string, unknown> | null>(null);', 'const [editEmp, setEditEmp] = useState<EmployeeData | null>(null);'],
  ['const [announcements, setAnnouncements] = useState<Record<string, unknown>[]>([]);', 'const [announcements, setAnnouncements] = useState<AnnouncementData[]>([]);'],
  ['const [notifConfig, setNotifConfig] = useState<Record<string, unknown>[]>([]);', 'const [notifConfig, setNotifConfig] = useState<NotifConfig[]>([]);'],
  ['const [sysAnnouncements, setSysAnnouncements] = useState<Record<string, unknown>[]>([]);', 'const [sysAnnouncements, setSysAnnouncements] = useState<SysAnnouncement[]>([]);'],
  ['const [activityStats, setActivityStats] = useState<Record<string, unknown>>({});', 'const [activityStats, setActivityStats] = useState<Record<string, unknown>>({});'],
  ['const [integrations, setIntegrations] = useState<Record<string, unknown>[]>([]);', 'const [integrations, setIntegrations] = useState<Record<string, unknown>[]>([]);'],
  ['const [retentionRules, setRetentionRules] = useState<Record<string, unknown>[]>([]);', 'const [retentionRules, setRetentionRules] = useState<Record<string, unknown>[]>([]);'],
  ['const [changelog, setChangelog] = useState<Record<string, unknown>[]>([]);', 'const [changelog, setChangelog] = useState<Record<string, unknown>[]>([]);'],
  ['const [tickets, setTickets] = useState<Record<string, unknown>[]>([]);', 'const [tickets, setTickets] = useState<Record<string, unknown>[]>([]);'],
  ['const [usageAnalytics, setUsageAnalytics] = useState<Record<string, unknown>>({});', 'const [usageAnalytics, setUsageAnalytics] = useState<Record<string, unknown>>({});'],
  ['const [editRole, setEditRole] = useState<Record<string, unknown> | null>(null);', 'const [editRole, setEditRole] = useState<RoleData | null>(null);'],
  ['const [editBU, setEditBU] = useState<Record<string, unknown> | null>(null);', 'const [editBU, setEditBU] = useState<BusinessUnit | null>(null);'],
  ['const [adminRoles, setAdminRoles] = useState<Record<string, unknown>[]>([]);', 'const [adminRoles, setAdminRoles] = useState<AdminRole[]>([]);'],
  ['const [adminAccounts, setAdminAccounts] = useState<Record<string, unknown>[]>([]);', 'const [adminAccounts, setAdminAccounts] = useState<AdminAccount[]>([]);'],
  ['const [editRoleAdmin, setEditRoleAdmin] = useState<Record<string, unknown> | null>(null);', 'const [editRoleAdmin, setEditRoleAdmin] = useState<AdminRole | null>(null);'],
];

replacements.forEach(([oldStr, newStr]) => {
  content = content.replace(oldStr, newStr);
});

// Event handlers
content = content.replace(/onChange=\{e =>/g, "onChange={(e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) =>");
// `e` in onClick could be different
content = content.replace(/onClick=\{e => e\.stopPropagation\(\)\}/g, "onClick={(e: React.MouseEvent) => e.stopPropagation()}");

// Catch blocks
content = content.replace(/catch \(e\) \{ logError\('loadOverview', e\); \}/g, "catch (e: unknown) { logError('loadOverview', e instanceof Error ? e.message : String(e)); }");
content = content.replace(/catch \(e\) \{ logError\('loadModules', e\); \}/g, "catch (e: unknown) { logError('loadModules', e instanceof Error ? e.message : String(e)); }");
content = content.replace(/catch \(e\) \{ logError\('loadAuditLog', e\); \}/g, "catch (e: unknown) { logError('loadAuditLog', e instanceof Error ? e.message : String(e)); }");
content = content.replace(/catch \(e\) \{ logError\('loadSecurity', e\); \}/g, "catch (e: unknown) { logError('loadSecurity', e instanceof Error ? e.message : String(e)); }");
content = content.replace(/catch \(e\) \{ logError\('loadEmployees', e\); \}/g, "catch (e: unknown) { logError('loadEmployees', e instanceof Error ? e.message : String(e)); }");
content = content.replace(/catch \(e\) \{ logError\('loadAnnouncements', e\); \}/g, "catch (e: unknown) { logError('loadAnnouncements', e instanceof Error ? e.message : String(e)); }");
content = content.replace(/catch \(e\) \{ logError\('loadNotifConfig', e\); \}/g, "catch (e: unknown) { logError('loadNotifConfig', e instanceof Error ? e.message : String(e)); }");
content = content.replace(/catch \(e\) \{ logError\('loadSysAnnouncements', e\); \}/g, "catch (e: unknown) { logError('loadSysAnnouncements', e instanceof Error ? e.message : String(e)); }");
content = content.replace(/catch \(e\) \{ logError\('loadActivity', e\); \}/g, "catch (e: unknown) { logError('loadActivity', e instanceof Error ? e.message : String(e)); }");
content = content.replace(/catch \(e\) \{ logError\('loadIntegrations', e\); \}/g, "catch (e: unknown) { logError('loadIntegrations', e instanceof Error ? e.message : String(e)); }");
content = content.replace(/catch \(e\) \{ logError\('loadRetention', e\); \}/g, "catch (e: unknown) { logError('loadRetention', e instanceof Error ? e.message : String(e)); }");
content = content.replace(/catch \(e\) \{ logError\('loadChangelog', e\); \}/g, "catch (e: unknown) { logError('loadChangelog', e instanceof Error ? e.message : String(e)); }");
content = content.replace(/catch \(e\) \{ logError\('loadTickets', e\); \}/g, "catch (e: unknown) { logError('loadTickets', e instanceof Error ? e.message : String(e)); }");
content = content.replace(/catch \(e\) \{ logError\('loadAnalytics', e\); \}/g, "catch (e: unknown) { logError('loadAnalytics', e instanceof Error ? e.message : String(e)); }");
content = content.replace(/catch \(e\) \{ logError\('loadAccessControl', e\); \}/g, "catch (e: unknown) { logError('loadAccessControl', e instanceof Error ? e.message : String(e)); }");

// groups and byBU dict fixes
content = content.replace(/const groups = \{\};/g, "const groups: Record<string, Module[]> = {};");
content = content.replace(/const byBU = \{\};/g, "const byBU: Record<string, RoleData[]> = {};");
content = content.replace(/deleteAdminRole\(id\)/g, "deleteAdminRole(id: string)");

// map index/params fixes
// .map((s, i) -> .map((s, i) wait, s and i will be inferred if the array is typed!
// Yes, since we changed the types of the state arrays, the elements of the arrays (e.g., in `.map((s, i) =>`) will now be correctly inferred. 

// Let's also make sure JSON.stringify works on config_value by fixing its type to `unknown` in the SecuritySetting interface.

fs.writeFileSync('src/pages/OwnerDashboard.tsx', content, 'utf-8');
console.log("Fixes applied.");
