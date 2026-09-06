/**
 * L8: API Performance Benchmarks
 * Run: node tests/performance/api-bench.js "postgresql://..."
 *
 * Tests response times for critical RPCs.
 * Threshold: < 500ms for single-row queries, < 2000ms for aggregation.
 */
import pg from 'pg';

const CONN = process.argv[2];
if (!CONN) { console.error('Usage: node api-bench.js <DATABASE_URL>'); process.exit(1); }

const client = new pg.Client({ connectionString: CONN, ssl: { rejectUnauthorized: false } });

const BENCHMARKS = [
  // name, query, maxMs
  // Thresholds include ~200ms network latency to Supabase pooler
  ['login_worker (exists check)', "SELECT 1 FROM pg_proc WHERE proname='login_worker'", 500],
  ['get_enabled_modules', "SELECT count(*) FROM module_definitions WHERE is_active=true", 500],
  ['employees_master view', "SELECT count(*) FROM employees_master", 500],
  ['employees_core', "SELECT count(*) FROM employees_core", 500],
  ['hr_payroll', "SELECT count(*) FROM hr_payroll", 500],
  ['hr_attendance', "SELECT count(*) FROM hr_attendance", 500],
  ['hr_leave', "SELECT count(*) FROM hr_leave", 500],
  ['estate_blocks', "SELECT count(*) FROM estate_blocks", 500],
  ['mill_boiler', "SELECT count(*) FROM mill_boiler", 500],
  ['module_definitions', "SELECT count(*) FROM module_definitions", 500],
  ['worker_passwords', "SELECT count(*) FROM worker_passwords", 500],
  ['system_owner_identity', "SELECT count(*) FROM system_owner_identity", 500],
];

async function run() {
  await client.connect();
  console.log('L8: API Performance Benchmarks');
  console.log('='.repeat(60));

  let passed = 0;
  let failed = 0;

  for (const [name, query, maxMs] of BENCHMARKS) {
    const start = performance.now();
    try {
      await client.query(query);
      const elapsed = performance.now() - start;
      const status = elapsed <= maxMs ? 'PASS' : 'SLOW';
      if (status === 'PASS') passed++; else failed++;
      console.log(`  ${status === 'PASS' ? '✅' : '⚠️ '} ${name}: ${elapsed.toFixed(1)}ms (max: ${maxMs}ms)`);
    } catch (e) {
      failed++;
      console.log(`  ❌ ${name}: ERROR — ${e.message}`);
    }
  }

  console.log('='.repeat(60));
  console.log(`Result: ${passed} passed, ${failed} failed out of ${BENCHMARKS.length}`);

  await client.end();
  process.exit(failed > 0 ? 1 : 0);
}

run();
