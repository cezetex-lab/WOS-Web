// ============================================================
// import-data.js — Import 30 workers + seed data ke Supabase
// Jalankan: node scripts/import-data.js
// ============================================================

const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://verwobaejumvpagwynae.supabase.co',
  'sb_secret_iyPr20e_-0uTKO2_rwpAxQ_bE5qGFw5'
);

// ── Data 30 Pekerja (identik dengan DummyData.gs) ──
const NAMES = [
  'Ahmad Fauzi','Budi Santoso','Citra Dewi','Dian Permata','Eko Prasetyo',
  'Fitriani Putri','Gilang Ramadhan','Hana Permesti','Irfan Hakim','Joko Widodo',
  'Kartika Sari','Lukman Hakim','Maya Angelina','Nanda Pratama','Omar Daniel',
  'Putri Sulastri','Rizky Amelia','Siti Nurhaliza','Taufik Rahman','Ulya Maghfiroh',
  'Vina Oktaviani','Wahyu Nugroho','Xenia Carissa','Yusuf Maulana','Zahra Amalia',
  'Aditya Pratama','Bella Saphira','Dimas Aditya','Elsa Puspita','Fajar Nugroho'
];

const POSITIONS = [
  'Direktur Utama / CEO','Kepala Divisi (Kadiv) / General Manager',
  'Kepala Bagian (Kebag) / Manager','Kepala Seksi (Kasie) / Supervisor',
  'Staf / Officer','Senior Staf / Senior Officer','Assistant Manager'
];

const DIVISIONS = ['HRD','FINANCE','OPERATIONAL','INFORMATION TECHNOLOGY / IT'];

const PHONES = [
  '081234567890','082345678901','083456789012','084567890123','085678901234',
  '086789012345','087890123456','088901234567','089012345678','080123456789',
  '081112223333','082223334444','083334445555','084445556666','085556667777',
  '086667778888','087778889999','088889990000','089990001111','080001112222',
  '081357924680','082468013579','083579124680','084680235791','085791346802',
  '086802457913','087913568024','088024679135','089135780246','080246891357'
];

const BANKS = ['BCA','Mandiri','BRI','BNI','CIMB Niaga','Danamon','Permata','BSI'];
const DIV_CODES = ['DIV-HRD','DIV-FIN','DIV-OPS','DIV-IT'];
const POS_CODES = [
  'POS-CEO','POS-GM','POS-MGR','POS-SUP',
  'POS-STF','POS-SR','POS-AM',
  'POS-STF','POS-STF','POS-STF',
  'POS-STF','POS-STF','POS-STF',
  'POS-STF','POS-STF','POS-STF',
  'POS-STF','POS-STF','POS-STF',
  'POS-STF','POS-STF','POS-STF',
  'POS-STF','POS-STF','POS-STF',
  'POS-GM','POS-STF','POS-STF',
  'POS-STF','POS-STF'
];

// ── Org hierarchy (30 people) ──
const org = [
  { nrp: 'NRP001', div: 'HRD', pos: 0, level: 5, atasan: '' },
  { nrp: 'NRP002', div: 'HRD', pos: 2, level: 4, atasan: 'NRP001' },
  { nrp: 'NRP003', div: 'FINANCE', pos: 2, level: 4, atasan: 'NRP001' },
  { nrp: 'NRP004', div: 'OPERATIONAL', pos: 2, level: 4, atasan: 'NRP001' },
  { nrp: 'NRP005', div: 'HRD', pos: 3, level: 3, atasan: 'NRP002' },
  { nrp: 'NRP006', div: 'FINANCE', pos: 3, level: 3, atasan: 'NRP003' },
  { nrp: 'NRP007', div: 'OPERATIONAL', pos: 3, level: 3, atasan: 'NRP004' },
  { nrp: 'NRP008', div: 'HRD', pos: 4, level: 1, atasan: 'NRP005' },
  { nrp: 'NRP009', div: 'HRD', pos: 5, level: 1, atasan: 'NRP005' },
  { nrp: 'NRP010', div: 'HRD', pos: 4, level: 1, atasan: 'NRP005' },
  { nrp: 'NRP011', div: 'HRD', pos: 4, level: 1, atasan: 'NRP005' },
  { nrp: 'NRP012', div: 'HRD', pos: 4, level: 1, atasan: 'NRP005' },
  { nrp: 'NRP013', div: 'HRD', pos: 4, level: 1, atasan: 'NRP002' },
  { nrp: 'NRP014', div: 'FINANCE', pos: 4, level: 1, atasan: 'NRP006' },
  { nrp: 'NRP015', div: 'FINANCE', pos: 5, level: 1, atasan: 'NRP006' },
  { nrp: 'NRP016', div: 'FINANCE', pos: 4, level: 1, atasan: 'NRP006' },
  { nrp: 'NRP017', div: 'FINANCE', pos: 4, level: 1, atasan: 'NRP006' },
  { nrp: 'NRP018', div: 'FINANCE', pos: 4, level: 1, atasan: 'NRP006' },
  { nrp: 'NRP019', div: 'FINANCE', pos: 4, level: 1, atasan: 'NRP003' },
  { nrp: 'NRP020', div: 'OPERATIONAL', pos: 4, level: 1, atasan: 'NRP007' },
  { nrp: 'NRP021', div: 'OPERATIONAL', pos: 5, level: 1, atasan: 'NRP007' },
  { nrp: 'NRP022', div: 'OPERATIONAL', pos: 4, level: 1, atasan: 'NRP007' },
  { nrp: 'NRP023', div: 'OPERATIONAL', pos: 4, level: 1, atasan: 'NRP007' },
  { nrp: 'NRP024', div: 'OPERATIONAL', pos: 4, level: 1, atasan: 'NRP007' },
  { nrp: 'NRP025', div: 'OPERATIONAL', pos: 4, level: 1, atasan: 'NRP004' },
  { nrp: 'NRP026', div: 'INFORMATION TECHNOLOGY / IT', pos: 2, level: 4, atasan: 'NRP001' },
  { nrp: 'NRP027', div: 'INFORMATION TECHNOLOGY / IT', pos: 4, level: 1, atasan: 'NRP026' },
  { nrp: 'NRP028', div: 'INFORMATION TECHNOLOGY / IT', pos: 4, level: 1, atasan: 'NRP026' },
  { nrp: 'NRP029', div: 'INFORMATION TECHNOLOGY / IT', pos: 4, level: 1, atasan: 'NRP026' },
  { nrp: 'NRP030', div: 'INFORMATION TECHNOLOGY / IT', pos: 4, level: 1, atasan: 'NRP026' }
];

function genNik(i) { return String(3200000000000000 + i * 1111111); }
function genDob(i) { return `19${70 + (i % 25)}-${String(1 + (i % 12)).padStart(2,'0')}-${String(1 + (i % 28)).padStart(2,'0')}`; }

async function importAll() {
  console.log('🚀 Starting import to Supabase...\n');

  // ── 1. employees_master ──
  const masterRows = org.map((p, i) => ({
    employee_id: `EMP${String(i+1).padStart(3,'0')}`,
    nrp: p.nrp,
    nik: genNik(i),
    nama: NAMES[i],
    email: NAMES[i].toLowerCase().replace(/ /g, '.') + '@amm.co.id',
    divisi: p.div,
    posisi: POSITIONS[p.pos],
    status_kerja: (i % 3 === 0) ? 'PKWT' : 'PKWTT',
    tanggal_lahir: genDob(i),
    jenis_kelamin: (i % 2 === 0) ? 'Laki-laki' : 'Perempuan',
    no_hp: PHONES[i],
    tanggal_masuk: `20${15 + (i % 8)}-01-01`
  }));
  const { error: e1 } = await supabase.from('employees_master').upsert(masterRows, { onConflict: 'nrp' });
  console.log(e1 ? `❌ employees_master: ${e1.message}` : `✅ employees_master: ${masterRows.length} rows`);

  // ── 2. user_roles ──
  const roleRows = org.map(p => ({
    nrp: p.nrp,
    role_level: p.level,
    scope_divisi: p.level === 5 ? 'ALL' : p.div
  }));
  const { error: e2 } = await supabase.from('user_roles').upsert(roleRows, { onConflict: 'nrp' });
  console.log(e2 ? `❌ user_roles: ${e2.message}` : `✅ user_roles: ${roleRows.length} rows`);

  // ── 3. hr_org ──
  const orgRows = org.filter(p => p.atasan).map(p => ({
    nrp: p.nrp,
    atasan_nrp: p.atasan
  }));
  const { error: e3 } = await supabase.from('hr_org').upsert(orgRows, { onConflict: 'nrp' });
  console.log(e3 ? `❌ hr_org: ${e3.message}` : `✅ hr_org: ${orgRows.length} rows`);

  // ── 4. settings ──
  const settingsRows = [
    { key: 'PLAN_LEVEL', value: 'FREE' },
    { key: 'LICENSE_KEY', value: '' },
    { key: 'ENV', value: 'SIMULATION' },
    { key: 'PENSION_AGE', value: '56' },
    { key: 'COMPANY_NAME', value: 'PT. AMM' },
    { key: 'APP_VERSION', value: '1.0.0' },
    { key: 'ADMIN_PASSWORD_HASH', value: '' }
  ];
  const { error: e4 } = await supabase.from('settings').upsert(settingsRows, { onConflict: 'key' });
  console.log(e4 ? `❌ settings: ${e4.message}` : `✅ settings: ${settingsRows.length} rows`);

  // ── 5. hr_preview_data (summary untuk tier rendah) ──
  const previewRows = [
    { section: 'KPI', key: 'avg_3_periode', value: JSON.stringify({P1: 85, P2: 82, P3: 80}) },
    { section: 'FINANCE', key: 'total_ytd', value: JSON.stringify({Y: 500000000, Y1: 125000000, Y2: 150000000}) },
    { section: 'ATTENDANCE', key: 'rata_rata_hadir', value: '92' },
    { section: 'SAFETY', key: 'incident_count', value: '3' },
    { section: 'WORKFORCE', key: 'total_headcount', value: '30' },
    { section: 'WORKFORCE', key: 'turnover_rate', value: '8.5' },
    { section: 'WORKFORCE', key: 'retention_rate', value: '91.5' },
    { section: 'KPI', key: 'target', value: '85' },
    { section: 'KPI', key: 'avg_score', value: '82' },
    { section: 'FINANCE', key: 'revenue_mtd', value: '42000000' },
    { section: 'FINANCE', key: 'profit_mtd', value: '8500000' },
    { section: 'ATTENDANCE', key: 'late_avg_menit', value: '12' },
    { section: 'SAFETY', key: 'ltifr', value: '2.1' },
    { section: 'TRAINING', key: 'completed_this_month', value: '8' },
    { section: 'COACHING', key: 'active_sessions', value: '5' },
    { section: 'OVERTIME', key: 'avg_hours_per_week', value: '4.5' }
  ];
  const { error: e5 } = await supabase.from('hr_preview_data').upsert(previewRows, { onConflict: 'section,key' });
  console.log(e5 ? `❌ hr_preview_data: ${e5.message}` : `✅ hr_preview_data: ${previewRows.length} rows`);

  // ── 6. announcements ──
  const annRows = [
    { id: 'ANN001', title: 'Selamat Datang di insightWOS', message: 'Platform Workforce Intelligence untuk manajemen SDM yang lebih cerdas.', priority: 'HIGH', target_audience: 'ALL' },
    { id: 'ANN002', title: 'Evaluasi KPI Q3 2026', message: 'Evaluasi kuartal ketiga akan dimulai tanggal 1 Oktober. Pastikan data kehadiran dan produksi tercatat dengan benar.', priority: 'NORMAL', target_audience: 'ALL' },
    { id: 'ANN003', title: 'Training K3 Mandatory', message: 'Seluruh pekerja wajib mengikuti training K3 bulanan. Hubungi HRD untuk jadwal.', priority: 'HIGH', target_audience: 'ALL' }
  ];
  const { error: e6 } = await supabase.from('announcements').upsert(annRows, { onConflict: 'id' });
  console.log(e6 ? `❌ announcements: ${e6.message}` : `✅ announcements: ${annRows.length} rows`);

  // ── 7. hr_kpi_config ──
  const kpiRows = [
    { position_code: 'POS-OPR-01', indicator: 'PRODUKSI', target_value: 5000, uom: 'Ton', weight: 40, formula_type: 'HIGHER' },
    { position_code: 'POS-OPR-01', indicator: 'DISIPLIN', target_value: 10, uom: 'Menit', weight: 20, formula_type: 'LOWER' },
    { position_code: 'POS-OPR-01', indicator: 'K3', target_value: 0, uom: 'Insiden', weight: 30, formula_type: 'LOWER' },
    { position_code: 'POS-OPR-01', indicator: 'KEHADIRAN', target_value: 95, uom: '%', weight: 10, formula_type: 'HIGHER' }
  ];
  const { error: e7 } = await supabase.from('hr_kpi_config').insert(kpiRows);
  console.log(e7 ? `❌ hr_kpi_config: ${e7.message}` : `✅ hr_kpi_config: ${kpiRows.length} rows`);

  console.log('\n🏁 Import selesai!');
}

importAll().catch(err => {
  console.error('💥 Fatal error:', err.message);
  process.exit(1);
});
