/**
 * menu-builder.js — Dynamic menu berdasarkan modul yang diaktifkan
 * 
 * Panggil: const menu = await buildMenu();
 * Return: array of menu items yang bisa diakses user
 */
import { supabase } from '@/lib/supabase-browser';

export async function buildMenu() {
  const { data: modules, error } = await supabase.rpc('get_enabled_modules');
  if (error || !modules) return [];

  return modules
    .sort((a, b) => a.menu_order - b.menu_order)
    .map(m => ({
      code: m.module_code,
      name: m.module_name,
      group: m.module_group,
      icon: m.menu_icon,
      isIndustry: m.is_industry_module,
      path: getModulePath(m.module_code),
    }));
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
    mining_simper: '/worker/mining/simper',
    mining_equipment: '/worker/mining/equipment',
    mining_production: '/worker/mining/production',
    mining_fuel: '/worker/mining/fuel',
    mining_fatigue: '/worker/mining/fatigue',
    mining_safety: '/worker/mining/safety',
    mining_jsa: '/worker/mining/jsa',
    // INDUSTRY - ESTATE
    estate_harvest: '/worker/estate/harvest',
    estate_blocks: '/worker/estate/blocks',
    estate_irrigation: '/worker/estate/irrigation',
    estate_nursery: '/worker/estate/nursery',
    estate_transport: '/worker/estate/transport',
    estate_field: '/worker/estate/field',
    estate_yield: '/worker/estate/yield',
    // INDUSTRY - MILL
    mill_boiler: '/worker/mill/boiler',
    mill_press: '/worker/mill/press',
    mill_qc: '/worker/mill/qc',
    mill_packing: '/worker/mill/packing',
    mill_maintenance: '/worker/mill/maintenance',
    mill_breakdown: '/worker/mill/breakdown',
    mill_shift: '/worker/mill/shift',
  };
  return pathMap[code] || '#';
}
