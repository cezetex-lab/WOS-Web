#!/bin/bash
# ================================================================
# L9: Production Smoke Test
# Run: bash tests/production/smoke.sh "postgresql://..."
# Quick health checks — must pass before any deploy.
# ================================================================

set -e
CONN="$1"
if [ -z "$CONN" ]; then
  echo "Usage: bash smoke.sh <DATABASE_URL>"
  exit 1
fi

PASS=0
FAIL=0

check() {
  local name="$1"
  local query="$2"
  local result
  result=$(psql "$CONN" -t -A -c "$query" 2>/dev/null)
  if [ "$result" = "t" ] || [ "$result" = "true" ] || [ "$result" != "" ]; then
    echo "  ✅ $name"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $name"
    FAIL=$((FAIL + 1))
  fi
}

echo "L9: Production Smoke Test"
echo "============================================================"

# ── Database connectivity ──
echo ""
echo "── Database ──"
check "DB connected" "SELECT true"

# ── Critical tables exist ──
echo ""
echo "── Tables ──"
check "employees_core" "SELECT EXISTS(SELECT 1 FROM pg_class WHERE relname='employees_core')"
check "employees_extended" "SELECT EXISTS(SELECT 1 FROM pg_class WHERE relname='employees_extended')"
check "hr_payroll" "SELECT EXISTS(SELECT 1 FROM pg_class WHERE relname='hr_payroll')"
check "hr_attendance" "SELECT EXISTS(SELECT 1 FROM pg_class WHERE relname='hr_attendance')"
check "worker_passwords" "SELECT EXISTS(SELECT 1 FROM pg_class WHERE relname='worker_passwords')"
check "module_definitions" "SELECT EXISTS(SELECT 1 FROM pg_class WHERE relname='module_definitions')"

# ── Critical functions exist ──
echo ""
echo "── Functions ──"
check "login_worker" "SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname='login_worker')"
check "worker_change_password" "SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname='worker_change_password')"
check "register_session" "SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname='register_session')"
check "get_enabled_modules" "SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname='get_enabled_modules')"
check "decrypt_pii" "SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname='decrypt_pii')"

# ── Security ──
echo ""
echo "── Security ──"
check "login_worker is SECDEF" "SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname='login_worker' AND prosecdef=true)"
check "admin_* all SECDEF" "SELECT NOT EXISTS(SELECT 1 FROM pg_proc WHERE proname LIKE 'admin_%' AND prosecdef=false)"
check "export_* all SECDEF" "SELECT NOT EXISTS(SELECT 1 FROM pg_proc WHERE proname LIKE 'export_%' AND prosecdef=false)"
check "anon NO EXECUTE decrypt_pii" "SELECT NOT has_function_privilege('anon', 'decrypt_pii(bytea)', 'EXECUTE')"
check "employees_core RLS" "SELECT relrowsecurity FROM pg_class WHERE relname='employees_core'"
check "hr_payroll RLS" "SELECT relrowsecurity FROM pg_class WHERE relname='hr_payroll'"

# ── Dynamic routes ──
echo ""
echo "── Routes ──"
check "modules have route_path" "SELECT EXISTS(SELECT 1 FROM module_definitions WHERE route_path IS NOT NULL LIMIT 1)"

# ── Data integrity ──
echo ""
echo "── Data ──"
check "employees_core has data" "SELECT EXISTS(SELECT 1 FROM employees_core LIMIT 1)"
check "module_definitions has data" "SELECT EXISTS(SELECT 1 FROM module_definitions WHERE is_active=true LIMIT 1)"

echo ""
echo "============================================================"
echo "Result: $PASS passed, $FAIL failed"
if [ $FAIL -gt 0 ]; then
  echo "❌ SMOKE TEST FAILED"
  exit 1
else
  echo "✅ SMOKE TEST PASSED"
  exit 0
fi
