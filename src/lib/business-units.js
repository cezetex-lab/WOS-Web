// ============================================================
// business-units.js — BU-Specific Menu & Module Configs
// Conditional rendering based on business_unit from login
// ============================================================

// ── MINING (Tambang) ──
export const MINING_MODULES = {
  label: 'Tambang',
  icon: '⛏️',
  color: 'red',
  quickTiles: [
    { icon: '📍', label: 'Kehadiran', color: 'teal', path: '/worker/attendance' },
    { icon: '⏰', label: 'Lembur', color: 'orange', path: '/worker/overtime' },
    { icon: '📊', label: 'KPI', color: 'purple', path: '/worker/kpi' },
    { icon: '⛏️', label: 'SIMPER', color: 'red', path: '/worker/simper' },
    { icon: '🏗️', label: 'Alat Berat', color: 'orange', path: '/worker/heavy-equip' },
    { icon: '⚠️', label: 'Fatigue', color: 'red', path: '/worker/fatigue' },
    { icon: '🛡️', label: 'Safety K3', color: 'green', path: '/worker/safety' },
    { icon: '📋', label: 'Tasks', color: 'slate', path: '/worker/tasks' },
  ],
  sidebarGroups: [
    {
      title: 'OPERASI TAMBANG',
      items: [
        { icon: '⛏️', label: 'SIMPER', path: '/worker/simper', desc: 'Surat Izin Masuk Pertambangan' },
        { icon: '🏗️', label: 'Alat Berat', path: '/worker/heavy-equip', desc: 'Monitor unit alat berat' },
        { icon: '⚠️', label: 'Fatigue Monitor', path: '/worker/fatigue', desc: 'Tracking kelelahan kerja' },
        { icon: '🪨', label: 'Produksi Harian', path: '/worker/production', desc: 'Tonase bijih/hari' },
      ],
    },
    {
      title: 'SAFETY & K3',
      items: [
        { icon: '🛡️', label: 'Safety K3', path: '/worker/safety', desc: 'Insiden & near-miss' },
        { icon: '🔥', label: 'Emergency', path: '/worker/emergency', desc: 'Prosedur darurat' },
        { icon: '📋', label: 'JSA', path: '/worker/jsa', desc: 'Job Safety Analysis' },
      ],
    },
    {
      title: 'AKTIVITAS',
      items: [
        { icon: '🌴', label: 'Cuti', path: '/worker/leave' },
        { icon: '💼', label: 'Lembur', path: '/worker/overtime' },
        { icon: '📋', label: 'Riwayat', path: '/worker/activities' },
      ],
    },
  ],
};

// ── ESTATE (Perkebunan Sawit) ──
export const ESTATE_MODULES = {
  label: 'Perkebunan',
  icon: '🌴',
  color: 'green',
  quickTiles: [
    { icon: '📍', label: 'Kehadiran', color: 'teal', path: '/worker/attendance' },
    { icon: '🌾', label: 'Panen', color: 'green', path: '/worker/harvest' },
    { icon: '🗺️', label: 'Blok Kebun', color: 'blue', path: '/worker/blocks' },
    { icon: '📊', label: 'KPI', color: 'purple', path: '/worker/kpi' },
    { icon: '🚛', label: 'Transport TBS', color: 'orange', path: '/worker/transport' },
    { icon: '💧', label: 'Irigrasi', color: 'blue', path: '/worker/irrigation' },
    { icon: '📋', label: 'Tasks', color: 'slate', path: '/worker/tasks' },
    { icon: '🏠', label: 'Fasilitas', color: 'orange', path: '/worker/facility' },
  ],
  sidebarGroups: [
    {
      title: 'OPERASI KEBUN',
      items: [
        { icon: '🌾', label: 'Record Panen', path: '/worker/harvest', desc: 'Tonase TBS per blok' },
        { icon: '🗺️', label: 'Blok Kebun', path: '/worker/blocks', desc: 'Peta & luas hektar' },
        { icon: '🚛', label: 'Transport TBS', path: '/worker/transport', desc: 'Jadwal & tonase' },
        { icon: '🌱', label: 'Nursery', path: '/worker/nursery', desc: 'Persemaian bibit' },
        { icon: '💧', label: 'Irigrasi', path: '/worker/irrigation', desc: 'Sistem pengairan' },
      ],
    },
    {
      title: 'FASILITAS',
      items: [
        { icon: '🏠', label: 'Mess/Kerja', path: '/worker/facility', desc: 'Perbaikan fasilitas' },
        { icon: '🚑', label: 'Medical', path: '/worker/medical', desc: 'Puskesmas kebun' },
      ],
    },
    {
      title: 'AKTIVITAS',
      items: [
        { icon: '🌴', label: 'Cuti', path: '/worker/leave' },
        { icon: '💼', label: 'Lembur', path: '/worker/overtime' },
        { icon: '📋', label: 'Riwayat', path: '/worker/activities' },
      ],
    },
  ],
};

// ── MILL (Pabrik PKS) ──
export const MILL_MODULES = {
  label: 'Pabrik',
  icon: '🏭',
  color: 'orange',
  quickTiles: [
    { icon: '📍', label: 'Kehadiran', color: 'teal', path: '/worker/attendance' },
    { icon: '🔄', label: 'Shift', color: 'orange', path: '/worker/shift' },
    { icon: '🔥', label: 'Boiler', color: 'red', path: '/worker/boiler' },
    { icon: '⚙️', label: 'Mesin', color: 'blue', path: '/worker/machines' },
    { icon: '📊', label: 'KPI', color: 'purple', path: '/worker/kpi' },
    { icon: '🧪', label: 'QC Lab', color: 'green', path: '/worker/qc' },
    { icon: '📋', label: 'Tasks', color: 'slate', path: '/worker/tasks' },
    { icon: '📦', label: 'Packing', color: 'orange', path: '/worker/packing' },
  ],
  sidebarGroups: [
    {
      title: 'OPERASI PABRIK',
      items: [
        { icon: '🔄', label: 'Jadwal Shift', path: '/worker/shift', desc: '3 shift: Pagi/Sore/Malam' },
        { icon: '🔥', label: 'Boiler Monitor', path: '/worker/boiler', desc: 'Status ketel uap' },
        { icon: '⚙️', label: 'Mesin Press', path: '/worker/machines', desc: 'Status mesin pabrik' },
        { icon: '🧪', label: 'QC Lab', path: '/worker/qc', desc: 'Quality control' },
        { icon: '📦', label: 'Packing', path: '/worker/packing', desc: 'Packing & loading' },
      ],
    },
    {
      title: 'MAINTENANCE',
      items: [
        { icon: '🔧', label: 'Preventive', path: '/worker/maintenance', desc: 'Jadwal perawatan' },
        { icon: '⚠️', label: 'Breakdown', path: '/worker/breakdown', desc: 'Laporan kerusakan' },
      ],
    },
    {
      title: 'AKTIVITAS',
      items: [
        { icon: '🌴', label: 'Cuti', path: '/worker/leave' },
        { icon: '💼', label: 'Lembur', path: '/worker/overtime' },
        { icon: '📋', label: 'Riwayat', path: '/worker/activities' },
      ],
    },
  ],
};

// ── HQ (Korporat) ──
export const HQ_MODULES = {
  label: 'Korporat',
  icon: '🏢',
  color: 'blue',
  quickTiles: [
    { icon: '📍', label: 'Kehadiran', color: 'teal', path: '/worker/attendance' },
    { icon: '🌴', label: 'Cuti', color: 'blue', path: '/worker/leave' },
    { icon: '💼', label: 'Lembur', color: 'orange', path: '/worker/overtime' },
    { icon: '📊', label: 'KPI', color: 'purple', path: '/worker/kpi' },
    { icon: '💰', label: 'Slip Gaji', color: 'teal', path: '/worker/payroll' },
    { icon: '📚', label: 'Learning', color: 'blue', path: '/worker/learning' },
    { icon: '🚀', label: 'Karir', color: 'purple', path: '/worker/career' },
    { icon: '✅', label: 'Tasks', color: 'slate', path: '/worker/tasks' },
  ],
  sidebarGroups: [
    {
      title: 'AKTIVITAS',
      items: [
        { icon: '🌴', label: 'Cuti', path: '/worker/leave' },
        { icon: '💼', label: 'Lembur', path: '/worker/overtime' },
        { icon: '📋', label: 'Riwayat', path: '/worker/activities' },
        { icon: '✅', label: 'Tasks', path: '/worker/tasks' },
      ],
    },
    {
      title: 'PENGEMBANGAN',
      items: [
        { icon: '📚', label: 'Learning', path: '/worker/learning' },
        { icon: '🚀', label: 'Karir', path: '/worker/career' },
        { icon: '📊', label: 'KPI Saya', path: '/worker/kpi' },
      ],
    },
    {
      title: 'KOMPENSASI',
      items: [
        { icon: '💰', label: 'Slip Gaji', path: '/worker/payroll' },
        { icon: '👤', label: 'Profil', path: '/worker/profile' },
      ],
    },
  ],
};

// ── LOOKUP MAP ──
export const BU_MODULES = {
  MINING: MINING_MODULES,
  ESTATE: ESTATE_MODULES,
  MILL: MILL_MODULES,
  HQ: HQ_MODULES,
};

// ── HELPER: Get modules for current user ──
export function getUserModules() {
  if (typeof window === 'undefined') return HQ_MODULES;
  try {
    const session = JSON.parse(sessionStorage.getItem('wos_user') || '{}');
    const bu = session.business_unit || 'HQ';
    return BU_MODULES[bu] || HQ_MODULES;
  } catch {
    return HQ_MODULES;
  }
}

// ── HELPER: Get business unit code ──
export function getBusinessUnit() {
  if (typeof window === 'undefined') return 'HQ';
  try {
    const session = JSON.parse(sessionStorage.getItem('wos_user') || '{}');
    return session.business_unit || 'HQ';
  } catch {
    return 'HQ';
  }
}

// ── HELPER: Get role level ──
export function getRoleLevel() {
  if (typeof window === 'undefined') return 1;
  try {
    const session = JSON.parse(sessionStorage.getItem('wos_user') || '{}');
    return session.role_level || 1;
  } catch {
    return 1;
  }
}
