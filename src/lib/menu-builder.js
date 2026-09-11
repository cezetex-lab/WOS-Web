/**
 * menu-builder.js — Dynamic menu berdasarkan modul yang diaktifkan + role-based
 *
 * Panggil: const menu = await buildMenu();        // auto-detect area dari URL
 *         const menu = await buildMenu('admin');  // eksplisit (untuk test)
 * Return: array of menu items yang bisa diakses user, SUDAH difilter per area shell.
 *
 * CATATAN: filter ini KOSMETIK (menyembunyikan entri menu yang salah tempat).
 * Otoritas akses sesungguhnya = DynamicRoutes guard + RLS di database.
 */
import { supabase } from '@/lib/supabase-browser';
import { getSession } from './supabase-browser';

// 'worker' | 'admin' | 'dashboard' | 'owner' — dari pathname saat ini
export function areaFromPath(p) {
  if (p === '/owner' || p.startsWith('/owner/')) return 'owner';
  if (p === '/admin' || p.startsWith('/admin/')) return 'admin';
  if (p === '/dashboard' || p.startsWith('/dashboard/')) return 'dashboard';
  return 'worker';
}

// Diekspor agar AppDrawer memakai SATU implementasi filter area yang sama
// (mencegah kedua filter divergen lagi).
export function pathInArea(path, area) {
  if (!path || path === '#') return false; // modul tanpa rasa -> buang
  if (area === 'owner') return path === '/owner' || path.startsWith('/owner/');
  if (area === 'admin') return path === '/admin' || path.startsWith('/admin/');
  if (area === 'dashboard') return path === '/dashboard' || path.startsWith('/dashboard/');
  return path === '/worker' || path.startsWith('/worker/');
}

// Varian untuk drawer (AppDrawer): sama dengan pathInArea, plus aturan khusus
// area worker — tautan dashboard tetap tampil (manajer sedang membuka halaman
// worker; menu dinamis sudah memfilter area ini di buildMenu).
export function drawerPathInArea(path, area) {
  if (area === 'worker' && (path === '/dashboard' || path.startsWith('/dashboard/'))) return true;
  return pathInArea(path, area);
}

export async function buildMenu(area) {
  // Area: eksplisit > auto-detect dari URL (sinkron, aman utk one-shot effect)
  const a = area || areaFromPath(window.location.pathname);
  const session = getSession();
  const role = session?.role || 'worker';
  const isOwner = session?.is_owner || role === 'owner';
  const tier = session?.tier || 0;
  const bu = session?.business_unit || 'HQ';

  // Owner gets all modules regardless of tier
  const effectiveTier = isOwner ? 999 : tier;

  const { data: modules, error } = await supabase.rpc('get_enabled_modules');
  if (error || !modules) return [];

  const seen = new Set();
  return modules
    .sort((a, b) => a.menu_order - b.menu_order)
    .filter(m => {
      // Tier check: skip if user tier below minimum required
      if (m.minimum_tier_required && effectiveTier < m.minimum_tier_required) return false;
      // Role-specific filtering
      if (m.role_access && !m.role_access.includes(role)) return false;
      // Business unit filtering for industry modules
      if (m.is_industry_module && m.required_business_unit && m.required_business_unit !== bu) return false;
      return true;
    })
    .map(m => ({
      code: m.module_code,
      name: m.module_name,
      group: m.module_group,
      icon: m.menu_icon,
      isIndustry: m.is_industry_module,
      path: getModulePath(m.module_code),
    }))
    .filter(item => {
      if (!pathInArea(item.path, a)) return false; // menu campur aduk fix
      if (seen.has(item.path)) return false;       // dedup by path
      seen.add(item.path);
      return true;
    });
}

function getModulePath(code) {
  const pathMap = {
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
