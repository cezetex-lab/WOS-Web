/**
 * L-3: Register all admin routes into `module_definitions` (live DB).
 * Uses pg + DATABASE_URL (proven path; supabase-js key rejected "Unregistered API key").
 * Idempotent: skips routes that already exist.
 *
 * Run: node supabase/scripts/register-routes.mjs
 * Env: DATABASE_URL from .env.local (loaded via dotenv-style parse below).
 */
import fs from 'fs';
import { Client } from 'pg';
import { randomUUID } from 'crypto';

// Parse .env.local (dotenv-style, tolerant of CRLF)
const env = Object.fromEntries(
  fs.readFileSync('.env.local', 'utf8')
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l && !l.startsWith('#') && l.includes('='))
    .map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1)])
);
const DB = env.DATABASE_URL;
if (!DB) { console.error('DATABASE_URL missing'); process.exit(1); }

// All admin routes (from full-sweep ROUTES.admin, minus typo /admin/feature-flants)
// MUST map to real component names from src/lib/route-config.js COMPONENT_MAP.
// Bug fix (migration 197): inserting the route slug as route_component made
// DynamicRoutes -> getComponent() return null -> Navigate to "/".
const ADMIN = [
  // [path, COMPONENT_MAP key]
  ['/admin/employees', 'Employees'],
  ['/admin/org-chart', 'OrgChart'],
  ['/admin/divisions', 'DivisionsManagement'],
  ['/admin/master-data', 'MasterDataPage'],
  ['/admin/role-matrix', 'RoleMatrixPage'],
  ['/admin/requests', 'RequestsList'],
  ['/admin/leave', 'LeaveManagement'],
  ['/admin/overtime', 'OvertimeManagement'],
  ['/admin/payroll', 'Payroll'],
  ['/admin/timesheet', 'TimesheetManagement'],
  ['/admin/shift-schedule', 'ShiftSchedule'],
  ['/admin/approval-center', 'ApprovalCenter'],
  ['/admin/kpi', 'Kpi'],
  ['/admin/incentive', 'IncentiveCalc'],
  ['/admin/okrs', 'Okrs'],
  ['/admin/learning', 'LearningManagement'],
  ['/admin/certifications', 'CertificationsPage'],
  ['/admin/badges', 'BadgesPage'],
  ['/admin/talent-market', 'TalentMarketPage'],
  ['/admin/career-path', 'CareerPathPage'],
  ['/admin/succession', 'SuccessionPlanning'],
  ['/admin/career-dev', 'CareerDevelopment'],
  ['/admin/attendance', 'AdminAttendance'],
  ['/admin/performance-trend', 'PerformanceTrend'],
  ['/admin/settings', 'Settings'],
  ['/admin/feature-flags', 'FeatureFlagsPage'],
  ['/admin/export', 'ExportPage'],
  ['/admin/integrations', 'Integrations'],
  ['/admin/budget', 'BudgetPage'],
  ['/admin/headcount', 'HeadcountPage'],
  ['/admin/audit-log', 'AuditLog'],
  ['/admin/audit-chain', 'AuditChainPage'],
  ['/admin/pipeline', 'PipelineKanban'],
  ['/admin/recruitment', 'RecruitmentDashboard'],
  ['/admin/screening', 'ScreeningPage'],
  ['/admin/onboarding', 'OnboardingWorkflow'],
  ['/admin/offboarding', 'Offboarding'],
  ['/admin/compensation-intel', 'CompensationIntel'],
  ['/admin/turnover', 'TurnoverPrediction'],
  ['/admin/simulation', 'WorkforceSimulation'],
  ['/admin/analytics', 'Analytics'],
];

const client = new Client({ connectionString: DB, ssl: { rejectUnauthorized: false } });
await client.connect();
console.log('Connected. Registering routes...');

// Inspect schema of module_definitions first
const cols = await client.query(
  "SELECT column_name, data_type, column_default FROM information_schema.columns WHERE table_name='module_definitions' ORDER BY ordinal_position"
);
const colNames = cols.rows.map((r) => r.column_name);
console.log('Columns:', colNames.join(', '));

let inserted = 0, skipped = 0, errors = 0;
for (const [p, component] of ADMIN) {
  const exists = await client.query('SELECT 1 FROM module_definitions WHERE route_path = $1', [p]);
  if (exists.rowCount > 0) { skipped++; console.log(`SKIP (exists): ${p}`); continue; }

  const code = p.replace('/admin/', '');
  const name = code.replace(/-/g, ' ');
  try {
    await client.query(
      `INSERT INTO module_definitions (id, route_path, route_component, route_group, module_code, module_name, module_group, is_active)
       VALUES ($1, $2, $3, 'admin', $4, $5, 'PLATFORM', true)`,
      [randomUUID(), p, component, code, name]
    );
    inserted++; console.log(`INSERTED: ${p} -> ${component}`);
  } catch (e) {
    errors++; console.log(`ERROR ${p}: ${e.message}`);
  }
}

console.log(`\nDone: ${inserted} inserted, ${skipped} skipped, ${errors} errors`);
const total = await client.query("SELECT count(*) FROM module_definitions WHERE route_group='admin'");
console.log(`Total admin routes in DB: ${total.rows[0].count}`);
await client.end();

