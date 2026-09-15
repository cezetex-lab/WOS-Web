// i18n Translation Skeleton (ID + EN)
export interface Translations {
  nav: {
    dashboard: string;
    employees: string;
    attendance: string;
    leave: string;
    overtime: string;
    payroll: string;
    performance: string;
    talent: string;
    learning: string;
    engagement: string;
    recruitment: string;
    organization: string;
    analytics: string;
    settings: string;
    mining: string;
    estate: string;
    mill: string;
    safety: string;
  };
  common: {
    save: string;
    cancel: string;
    delete: string;
    edit: string;
    add: string;
    search: string;
    filter: string;
    export: string;
    loading: string;
    noData: string;
    confirm: string;
    back: string;
    next: string;
    submit: string;
    approve: string;
    reject: string;
    status: string;
    date: string;
    total: string;
  };
  employee: {
    name: string;
    nrp: string;
    nik: string;
    position: string;
    division: string;
    joinDate: string;
    employmentType: string;
    permanent: string;
    contract: string;
    outsourcing: string;
    intern: string;
  };
  payroll: {
    baseSalary: string;
    allowance: string;
    deduction: string;
    overtimePay: string;
    netSalary: string;
    period: string;
    currency: string;
  };
  form: {
    required: string;
    invalid: string;
    emailInvalid: string;
    phoneInvalid: string;
    passwordWeak: string;
    minLength: string;
    maxLength: string;
  };
  settings: {
    general: string;
    branding: string;
    security: string;
    modules: string;
    systemConfig: string;
    saveSuccess: string;
    saveFailed: string;
  };
  dashboard: {
    welcome: string;
    overview: string;
    recentActivity: string;
    quickActions: string;
    notifications: string;
    noNotifications: string;
  };
  leave: {
    type: string;
    startDate: string;
    endDate: string;
    reason: string;
    days: string;
    annual: string;
    sick: string;
    permission: string;
  };
  mining: {
    equipment: string;
    production: string;
    safety: string;
    fatigue: string;
    simper: string;
    jsa: string;
    blast: string;
  };
  estate: {
    block: string;
    harvest: string;
    transport: string;
    yield: string;
    ripe: string;
  };
  mill: {
    boiler: string;
    press: string;
    qc: string;
    packing: string;
    maintenance: string;
    breakdown: string;
  };
}

const translations: Record<string, Translations> = {
  id: {
    nav: { dashboard: 'Dashboard', employees: 'Karyawan', attendance: 'Absensi', leave: 'Cuti', overtime: 'Lembur', payroll: 'Payroll', performance: 'Kinerja', talent: 'Talenta', learning: 'Pelatihan', engagement: 'Engagement', recruitment: 'Rekrutmen', organization: 'Organisasi', analytics: 'Analytics', settings: 'Pengaturan', mining: 'Tambang', estate: 'Perkebunan', mill: 'Pabrik', safety: 'Keselamatan' },
    common: { save: 'Simpan', cancel: 'Batal', delete: 'Hapus', edit: 'Edit', add: 'Tambah', search: 'Cari...', filter: 'Filter', export: 'Ekspor', loading: 'Memuat...', noData: 'Tidak ada data', confirm: 'Konfirmasi', back: 'Kembali', next: 'Selanjutnya', submit: 'Kirim', approve: 'Setuju', reject: 'Tolak', status: 'Status', date: 'Tanggal', total: 'Total' },
    employee: { name: 'Nama', nrp: 'NRP', nik: 'NIK', position: 'Posisi', division: 'Divisi', joinDate: 'Tanggal Masuk', employmentType: 'Jenis Kontrak', permanent: 'PKWTT', contract: 'PKWT', outsourcing: 'Outsourcing', intern: 'Magang' },
    payroll: { baseSalary: 'Gaji Pokok', allowance: 'Tunjangan', deduction: 'Potongan', overtimePay: 'Lembur', netSalary: 'Gaji Bersih', period: 'Periode', currency: 'Mata Uang' },
    form: { required: 'Wajib diisi', invalid: 'Format tidak valid', emailInvalid: 'Email tidak valid', phoneInvalid: 'Telepon tidak valid', passwordWeak: 'Password terlalu lemah', minLength: 'Minimal {n} karakter', maxLength: 'Maksimal {n} karakter' },
    settings: { general: 'Umum', branding: 'Branding', security: 'Keamanan', modules: 'Modul', systemConfig: 'Konfigurasi Sistem', saveSuccess: 'Pengaturan tersimpan', saveFailed: 'Gagal menyimpan' },
    dashboard: { welcome: 'Selamat Datang', overview: 'Ringkasan', recentActivity: 'Aktivitas Terbaru', quickActions: 'Aksi Cepat', notifications: 'Notifikasi', noNotifications: 'Tidak ada notifikasi' },
    leave: { type: 'Jenis Cuti', startDate: 'Mulai', endDate: 'Selesai', reason: 'Alasan', days: 'Hari', annual: 'Cuti Tahunan', sick: 'Sakit', permission: 'Izin' },
    mining: { equipment: 'Alat Berat', production: 'Produksi', safety: 'Keselamatan', fatigue: 'Fatigue', simper: 'SIMPER', jsa: 'JSA', blast: 'Peledakan' },
    estate: { block: 'Blok', harvest: 'Panen', transport: 'Transportasi', yield: 'Hasil', ripe: 'Matang' },
    mill: { boiler: 'Boiler', press: 'Mesin Press', qc: 'Quality Control', packing: 'Packing', maintenance: 'Maintenance', breakdown: 'Breakdown' },
  },
  en: {
    nav: { dashboard: 'Dashboard', employees: 'Employees', attendance: 'Attendance', leave: 'Leave', overtime: 'Overtime', payroll: 'Payroll', performance: 'Performance', talent: 'Talent', learning: 'Learning', engagement: 'Engagement', recruitment: 'Recruitment', organization: 'Organization', analytics: 'Analytics', settings: 'Settings', mining: 'Mining', estate: 'Estate', mill: 'Mill', safety: 'Safety' },
    common: { save: 'Save', cancel: 'Cancel', delete: 'Delete', edit: 'Edit', add: 'Add', search: 'Search...', filter: 'Filter', export: 'Export', loading: 'Loading...', noData: 'No data', confirm: 'Confirm', back: 'Back', next: 'Next', submit: 'Submit', approve: 'Approve', reject: 'Reject', status: 'Status', date: 'Date', total: 'Total' },
    employee: { name: 'Name', nrp: 'NRP', nik: 'NIK', position: 'Position', division: 'Division', joinDate: 'Join Date', employmentType: 'Employment Type', permanent: 'Permanent', contract: 'Fixed-Term', outsourcing: 'Outsourcing', intern: 'Intern' },
    payroll: { baseSalary: 'Base Salary', allowance: 'Allowance', deduction: 'Deduction', overtimePay: 'Overtime Pay', netSalary: 'Net Salary', period: 'Period', currency: 'Currency' },
    form: { required: 'Required', invalid: 'Invalid format', emailInvalid: 'Invalid email', phoneInvalid: 'Invalid phone', passwordWeak: 'Password too weak', minLength: 'Min {n} characters', maxLength: 'Max {n} characters' },
    settings: { general: 'General', branding: 'Branding', security: 'Security', modules: 'Modules', systemConfig: 'System Config', saveSuccess: 'Settings saved', saveFailed: 'Failed to save' },
    dashboard: { welcome: 'Welcome', overview: 'Overview', recentActivity: 'Recent Activity', quickActions: 'Quick Actions', notifications: 'Notifications', noNotifications: 'No notifications' },
    leave: { type: 'Leave Type', startDate: 'Start Date', endDate: 'End Date', reason: 'Reason', days: 'Days', annual: 'Annual Leave', sick: 'Sick Leave', permission: 'Permission' },
    mining: { equipment: 'Heavy Equipment', production: 'Production', safety: 'Safety', fatigue: 'Fatigue', simper: 'SIMPER', jsa: 'JSA', blast: 'Blasting' },
    estate: { block: 'Block', harvest: 'Harvest', transport: 'Transport', yield: 'Yield', ripe: 'Ripe' },
    mill: { boiler: 'Boiler', press: 'Press Machine', qc: 'Quality Control', packing: 'Packing', maintenance: 'Maintenance', breakdown: 'Breakdown' },
  },
};

let currentLang: string = localStorage.getItem("lang") || "id";

export function t(key: string): string {
  const keys = key.split(".");
  let val: any = translations[currentLang];
  for (const k of keys) val = val?.[k];
  return val || key;
}

export function setLang(lang: string): void {
  currentLang = lang;
  localStorage.setItem("lang", lang);
}

export function getLang(): string {
  return currentLang;
}

export default translations;
