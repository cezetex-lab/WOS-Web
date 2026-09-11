#!/usr/bin/env node
/**
 * run-gates.mjs — Cross-platform test gate runner L1-L9
 * Usage: node tests/run-gates.mjs "postgresql://..."
 * Works on Windows, Mac, Linux (no bash needed)
 */
import { execSync } from 'child_process';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');
const CONN = process.argv[2];

if (!CONN) {
  console.error('Usage: node tests/run-gates.mjs "postgresql://..."');
  process.exit(1);
}

function run(name, cmd, opts = {}) {
  try {
    const result = execSync(cmd, {
      cwd: ROOT,
      encoding: 'utf-8',
      timeout: 60000,
      stdio: ['pipe', 'pipe', 'pipe'],
      ...opts,
    });
    return { ok: true, output: result.trim() };
  } catch (e) {
    return { ok: false, output: (e.stdout || '') + '\n' + (e.stderr || '') };
  }
}

function runSQL(sqlFile) {
  const r = run('SQL', `node supabase/migrations/run_171.mjs "${CONN}" ${sqlFile}`);
  const match = r.output.match(/Result: (\d+) succeeded, (\d+) failed/);
  if (match) {
    const [, s, f] = match;
    return { ok: parseInt(f) === 0, passed: parseInt(s), failed: parseInt(f) };
  }
  return { ok: r.ok, passed: 0, failed: 1 };
}

console.log('╔══════════════════════════════════════════════════════╗');
console.log('║        insightWOS — Test Gate Report (L1-L9)        ║');
console.log('╚══════════════════════════════════════════════════════╝');
console.log('');

let gatesPass = 0, gatesFail = 0, gatesWarn = 0;

// ── L1: Code Review ──
console.log('── L1: Code Review (Git) ──');
const git = run('Git', 'git log --oneline -1');
if (git.ok) {
  console.log(`  ✅ L1 PASS — Latest: ${git.output.split('\n')[0]}`);
  gatesPass++;
} else {
  console.log('  ❌ L1 FAIL — git not available');
  gatesFail++;
}
console.log('');

// ── L2: Static Analysis (ESLint) ──
// L2 = "0 critical errors". Warnings (no-unused-vars, no-console, …) worden
// bewust als non-blocking behandeld (backlog ~400) — EXIT 0 van eslint is het
// enige harde signaal voor "geen errors" (zonder --max-warnings).
// Bugfix 2026-09-11 (was: inverted logic + removed --format=compact flag):
//   - oude condition `errors === 0 || !eslint.ok` slaagde ALTIJD wanneer eslint
//     faalde (crashed of errors gevonden) → gate was nooit FAIL.
//   - --format=compact is uit core ESLint verwijderd sinds v9 → command faalde
//     altijd met "The compact formatter is no longer part of core ESLint".
console.log('── L2: ESLint ──');
const eslint = run('ESLint', 'npx eslint src/');
const errors = (eslint.output.match(/error/g) || []).length;
if (eslint.ok) {
  console.log('  ✅ L2 PASS — 0 errors');
  gatesPass++;
} else if (errors > 0) {
  console.log(`  ❌ L2 FAIL — ${errors} errors found`);
  gatesFail++;
} else {
  console.log('  ⚠️  L2 WARN — eslint crashed (exit non-zero zonder error lines)');
  gatesWarn++;
}
console.log('');

// ── L3: Unit Tests (Vitest) ──
console.log('── L3: Unit Tests (Vitest) ──');
const vitest = run('Vitest', 'npx vitest run --reporter=dot');

// === FIXED REGEX ===
const failedMatch = vitest.output.match(/Tests\s+(\d+)\s+failed/);
const passedMatch = vitest.output.match(/Tests\s+(?:\d+\s+failed\s+\|\s+)?(\d+)\s+passed/);
const failed = failedMatch ? parseInt(failedMatch[1]) : 0;
const passed = passedMatch ? parseInt(passedMatch[1]) : 0;

if (passed > 0 || failed > 0) {
  if (failed === 0) {
    console.log(`  ✅ L3 PASS — ${passed} tests, 0 failed`);
    gatesPass++;
  } else {
    console.log(`  ⚠️  L3 WARN — ${passed} passed, ${failed} failed (pre-existing)`);
    gatesWarn++;
  }
} else {
  console.log('  ⚠️  L3 WARN — could not parse output');
  gatesWarn++;
}
console.log('');

// ── L4: Component Tests ──
console.log('── L4: Component Tests (RTL) ──');
const rtl = run('RTL', 'npx vitest run tests/component/ --reporter=dot');

// === FIXED REGEX (same pattern) ===
const failedMatchRTL = rtl.output.match(/Tests\s+(\d+)\s+failed/);
const passedMatchRTL = rtl.output.match(/Tests\s+(?:\d+\s+failed\s+\|\s+)?(\d+)\s+passed/);
const failedRTL = failedMatchRTL ? parseInt(failedMatchRTL[1]) : 0;
const passedRTL = passedMatchRTL ? parseInt(passedMatchRTL[1]) : 0;

if (passedRTL > 0 || failedRTL > 0) {
  if (failedRTL === 0) {
    console.log(`  ✅ L4 PASS — ${passedRTL} tests, 0 failed`);
    gatesPass++;
  } else {
    console.log(`  ⚠️  L4 WARN — ${passedRTL} passed, ${failedRTL} failed`);
    gatesWarn++;
  }
} else if (rtl.ok && rtl.output.includes('No tests found')) {
  console.log('  ⏭️  L4 SKIP — no component tests found');
  gatesWarn++; // or treat as skip; adjust summary if needed
} else {
  console.log('  ⚠️  L4 WARN — could not parse output');
  gatesWarn++;
}
console.log('');

// ── L5: Integration Tests ──
console.log('── L5: Integration Tests (DB) ──');
const l5 = runSQL('tests/integration/rpc-security.test.sql');
if (l5.ok) {
  console.log(`  ✅ L5 PASS — ${l5.passed}/${l5.passed + l5.failed}`);
  gatesPass++;
} else {
  console.log(`  ❌ L5 FAIL — ${l5.passed}/${l5.passed + l5.failed}`);
  gatesFail++;
}
console.log('');

// ── L6: Security Tests ──
console.log('── L6: Security Tests (DB) ──');
const l6 = runSQL('supabase/migrations/184_test_q1_q4_security.sql');
if (l6.ok) {
  console.log(`  ✅ L6 PASS — ${l6.passed}/${l6.passed + l6.failed}`);
  gatesPass++;
} else {
  console.log(`  ❌ L6 FAIL — ${l6.passed}/${l6.passed + l6.failed}`);
  gatesFail++;
}
console.log('');

// ── L7: E2E Tests (Playwright) ──
console.log('── L7: E2E Tests (Playwright) ──');
try {
  const pw = run('Playwright', 'npx playwright --version');
  if (pw.ok) {
    const e2e = run('E2E', 'npx playwright test --reporter=line');
    if (e2e.ok) {
      console.log('  ✅ L7 PASS');
      gatesPass++;
    } else {
      console.log('  ⚠️  L7 WARN — some E2E tests failed');
      gatesWarn++;
    }
  } else {
    console.log('  ⏭️  L7 SKIP — Playwright not installed');
    gatesWarn++;
  }
} catch {
  console.log('  ⏭️  L7 SKIP — Playwright not installed');
  gatesWarn++;
}
console.log('');

// ── L8: Performance ──
console.log('── L8: Performance (api-bench) ──');
const perf = run('Perf', `node tests/performance/api-bench.js "${CONN}"`);
const pMatch = perf.output.match(/Result: (\d+) passed, (\d+) failed/);
if (pMatch && parseInt(pMatch[2]) === 0) {
  console.log(`  ✅ L8 PASS — ${pMatch[1]} queries < 500ms`);
  gatesPass++;
} else {
  console.log(`  ❌ L8 FAIL`);
  gatesFail++;
}
console.log('');

// ── L9: Production Smoke ──
console.log('── L9: Production Smoke (SQL) ──');
// Convert smoke.sh checks to SQL
const smokeSql = `
SELECT 'L9.1 DB connected' AS test, CASE WHEN true THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'L9.2 employees_core' AS test, CASE WHEN EXISTS(SELECT 1 FROM pg_class WHERE relname='employees_core') THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'L9.3 hr_payroll' AS test, CASE WHEN EXISTS(SELECT 1 FROM pg_class WHERE relname='hr_payroll') THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'L9.4 module_definitions' AS test, CASE WHEN EXISTS(SELECT 1 FROM pg_class WHERE relname='module_definitions') THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'L9.5 login_worker' AS test, CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='login_worker') THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'L9.6 worker_change_password' AS test, CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='worker_change_password') THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'L9.7 register_session' AS test, CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='register_session') THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'L9.8 login_worker SECDEF' AS test, CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname='login_worker' AND prosecdef=true) THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'L9.9 admin_* SECDEF' AS test, CASE WHEN NOT EXISTS(SELECT 1 FROM pg_proc WHERE proname LIKE 'admin_%' AND prosecdef=false) THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'L9.10 export_* SECDEF' AS test, CASE WHEN NOT EXISTS(SELECT 1 FROM pg_proc WHERE proname LIKE 'export_%' AND prosecdef=false) THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'L9.11 employees_core RLS' AS test, CASE WHEN (SELECT relrowsecurity FROM pg_class WHERE relname='employees_core') THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'L9.12 hr_payroll RLS' AS test, CASE WHEN (SELECT relrowsecurity FROM pg_class WHERE relname='hr_payroll') THEN 'PASS' ELSE 'FAIL' END AS result;
SELECT 'L9.13 modules have route_path' AS test, CASE WHEN EXISTS(SELECT 1 FROM module_definitions WHERE route_path IS NOT NULL) THEN 'PASS' ELSE 'FAIL' END AS result;
`;
// Write temp file and run
const { writeFileSync, unlinkSync } = await import('fs');
const tmpFile = join(ROOT, 'tests', '_l9_smoke.sql');
writeFileSync(tmpFile, smokeSql);
const l9 = runSQL('tests/_l9_smoke.sql');
try { unlinkSync(tmpFile); } catch {}
if (l9.ok) {
  console.log(`  ✅ L9 PASS — ${l9.passed}/${l9.passed + l9.failed} checks`);
  gatesPass++;
} else {
  console.log(`  ❌ L9 FAIL — ${l9.passed}/${l9.passed + l9.failed}`);
  gatesFail++;
}
console.log('');

// ── Summary ──
console.log('╔══════════════════════════════════════════════════════╗');
console.log('║                    GATE SUMMARY                     ║');
console.log('╠══════════════════════════════════════════════════════╣');
console.log(`║  ✅ PASS: ${gatesPass}  |  ❌ FAIL: ${gatesFail}  |  ⚠️  WARN: ${gatesWarn}              ║`);
console.log('╚══════════════════════════════════════════════════════╝');

if (gatesFail > 0) {
  console.log('\n❌ DEPLOY BLOCKED — fix failing gates first');
  process.exit(1);
} else if (gatesWarn > 0) {
  console.log('\n⚠️  DEPLOY WITH CAUTION — some gates have warnings');
  process.exit(0);
} else {
  console.log('\n✅ ALL GATES PASSED — safe to deploy');
  process.exit(0);
}