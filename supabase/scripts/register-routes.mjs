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
const ADMIN = [
  '/admin', '/admin/employees', '/admin/org-chart', '/admin/divisions',
  '/admin/master-data', '/admin/role-matrix', '/admin/requests',
  '/admin/leave', '/admin/overtime', '/admin/payroll', '/admin/timesheet',
  '/admin/shift-schedule', '/admin/approval-center', '/admin/kpi',
  '/admin/incentive', '/admin/okrs', '/admin/learning',
  '/admin/certifications', '/admin/badges', '/admin/talent-market',
  '/admin/career-path', '/admin/succession', '/admin/career-dev',
  '/admin/attendance', '/admin/performance-trend', '/admin/settings',
  '/admin/feature-flags', '/admin/export', '/admin/integrations',
  '/admin/budget', '/admin/headcount', '/admin/audit-log',
  '/admin/audit-chain', '/admin/pipeline', '/admin/recruitment',
  '/admin/screening', '/admin/onboarding', '/admin/offboarding',
  '/admin/compensation-intel', '/admin/turnover', '/admin/simulation',
  '/admin/analytics',
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
for (const p of ADMIN) {
  const exists = await client.query('SELECT 1 FROM module_definitions WHERE route_path = $1', [p]);
  if (exists.rowCount > 0) { skipped++; console.log(`SKIP (exists): ${p}`); continue; }

  const code = p.replace('/admin/', '') || 'dashboard';
  const name = code.replace(/-/g, ' ');
  try {
    await client.query(
      `INSERT INTO module_definitions (id, route_path, route_component, route_group, module_code, module_name, module_group, is_active)
       VALUES ($1, $2, $3, 'admin', $4, $5, 'PLATFORM', true)`,
      [randomUUID(), p, code, code, name]
    );
    inserted++; console.log(`INSERTED: ${p}`);
  } catch (e) {
    errors++; console.log(`ERROR ${p}: ${e.message}`);
  }
}

console.log(`\nDone: ${inserted} inserted, ${skipped} skipped, ${errors} errors`);
const total = await client.query("SELECT count(*) FROM module_definitions WHERE route_group='admin'");
console.log(`Total admin routes in DB: ${total.rows[0].count}`);
await client.end();

