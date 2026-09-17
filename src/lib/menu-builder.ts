/**
 * menu-builder.ts — Dynamic menu based on enabled modules + role-based filtering (TypeScript)
 *
 * Typed module — drop-in replacement for the pre-TypeScript version.
 */

import { supabase } from '@/lib/supabase-browser';
import { getSession } from './supabase-browser';

// ─── Types ────────────────────────────────────────────────────

export type Area = 'worker' | 'admin' | 'dashboard' | 'owner';

export interface MenuItem {
  code: string;
  name: string;
  group: string;
  icon: string;
  isIndustry: boolean;
  path: string;
}

interface DbModule {
  module_code: string;
  module_name: string;
  module_group: string;
  menu_icon: string;
  menu_order: number;
  is_industry_module: boolean;
  route_path: string;
  route_component: string;
  minimum_tier_required?: number;
  role_access?: string[];
  required_business_unit?: string;
}

// ─── Area Detection ───────────────────────────────────────────

export function areaFromPath(p: string): Area {
  if (p === '/owner' || p.startsWith('/owner/')) return 'owner';
  if (p === '/admin' || p.startsWith('/admin/')) return 'admin';
  if (p === '/dashboard' || p.startsWith('/dashboard/')) return 'dashboard';
  return 'worker';
}

export function pathInArea(path: string, area: Area): boolean {
  if (!path || path === '#') return false;
  if (area === 'owner') return path === '/owner' || path.startsWith('/owner/');
  if (area === 'admin') return path === '/admin' || path.startsWith('/admin/');
  if (area === 'dashboard') return path === '/dashboard' || path.startsWith('/dashboard/');
  return path === '/worker' || path.startsWith('/worker/');
}

export function drawerPathInArea(path: string, area: Area): boolean {
  if (area === 'worker' && (path === '/dashboard' || path.startsWith('/dashboard/'))) return true;
  return pathInArea(path, area);
}

// ─── Menu Building ────────────────────────────────────────────

export async function buildMenu(area?: Area): Promise<MenuItem[]> {
  const a = area || areaFromPath(window.location.pathname);
  const session = getSession();
  const role = session?.role || 'worker';
  const isOwner = session?.is_owner || role === 'owner';
  const tier = session?.tier || 0;
  const bu = session?.business_unit || 'HQ';

  const effectiveTier = isOwner ? 999 : tier;

  const { data: modules, error } = await supabase.rpc('get_enabled_modules');
  if (error || !modules) return [];

  const seen = new Set<string>();
  return (modules as DbModule[])
    .sort((a, b) => a.menu_order - b.menu_order)
    .filter((m) => {
      if (m.minimum_tier_required && effectiveTier < m.minimum_tier_required) return false;
      if (m.role_access && !m.role_access.includes(role)) return false;
      if (m.is_industry_module && m.required_business_unit && m.required_business_unit !== bu) return false;
      return true;
    })
    .map((m) => ({
      code: m.module_code,
      name: m.module_name,
      group: m.module_group,
      icon: m.menu_icon,
      isIndustry: m.is_industry_module,
      path: getModulePath(m.module_code),
    }))
    .filter((item) => {
      if (!pathInArea(item.path, a)) return false;
      if (seen.has(item.path)) return false;
      seen.add(item.path);
      return true;
    });
}

// ─── Module Path Mapping ──────────────────────────────────────

function getModulePath(code: string): string {
  const pathMap: Record<string, string> = {
    // CORE
    profile: '/worker/profile',
    attendance: '/worker/attendance',
    leave: '/worker/leave',
    overtime: '/worker/overtime',
    payroll: '/worker/payroll',
    self_service: '/worker/self-service',
    kpi: '/admin/kpi',
    performance: '/admin/performance',
    learning: '/worker/learning',
    '360_review': '/worker/review-360',
    talent: '/admin/talent',
    career_path: '/worker/career',
    succession: '/admin/succession',
    recruitment: '/admin/recruitment',
    onboarding: '/admin/onboarding',
    offboarding: '/admin/offboarding',
    engagement: '/admin/engagement',
    voice_ideas: '/worker/voice',
    badges: '/worker/badges',
    referral: '/worker/referral',
    ceo_dashboard: '/dashboard',
    analytics: '/admin/analytics',
    workforce_planning: '/admin/workforce',
    simulation: '/admin/simulation',
    turnover: '/admin/turnover',
    flight_risk: '/admin/flight-risk',
    narrative: '/admin/narrative',
    // PLATFORM
    org_structure: '/admin/org',
    divisions: '/admin/divisions',
    approvals: '/admin/approvals',
    audit_log: '/admin/audit',
    settings: '/admin/settings',
    export_data: '/admin/export',
    announcements: '/admin/announcements',
    whistleblowing: '/worker/whistleblowing',
    mfa: '/admin/mfa',
    module_management: '/admin/modules',
    // GOVERNANCE
    safety: '/admin/safety',
    qhse: '/admin/qhse',
    certifications: '/worker/certifications',
    // INDUSTRY - MINING
    mining_simper: '/worker/simper',
    mining_equipment: '/worker/heavy-equip',
    mining_production: '/worker/production',
    mining_fuel: '/worker/fuel',
    mining_fatigue: '/worker/fatigue',
    mining_safety: '/worker/safety',
    mining_jsa: '/worker/jsa',
    // INDUSTRY - ESTATE
    estate_harvest: '/worker/harvest',
    estate_blocks: '/worker/blocks',
    estate_irrigation: '/worker/irrigation',
    estate_nursery: '/worker/nursery',
    estate_transport: '/worker/transport',
    estate_field: '/worker/field',
    estate_yield: '/worker/yield',
    // INDUSTRY - MILL
    mill_boiler: '/worker/boiler',
    mill_press: '/worker/machines',
    mill_qc: '/worker/qc',
    mill_packing: '/worker/packing',
    mill_maintenance: '/worker/maintenance',
    mill_breakdown: '/worker/breakdown',
    mill_shift: '/worker/shift',
  };
  return pathMap[code] || '#';
}
