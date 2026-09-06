#!/usr/bin/env bash
# ================================================================
# run-gates.sh — insightWOS Strict Test Gate Runner (L1-L9)
#
# Usage:
#   bash tests/run-gates.sh "postgresql://..."
#
# Exit:
#   0 = all mandatory gates passed
#   1 = one or more mandatory gates failed
# ================================================================

set -Eeuo pipefail

CONN="${1:-}"

if [[ -z "$CONN" ]]; then
  echo "Usage: bash tests/run-gates.sh <DATABASE_URL>"
  exit 1
fi

cd "$(dirname "$0")/.."

GATES_PASS=0
GATES_FAIL=0
GATES_SKIP=0

echo "╔══════════════════════════════════════════════════════╗"
echo "║       insightWOS — STRICT TEST GATE (L1-L9)         ║"
echo "╚══════════════════════════════════════════════════════╝"
echo

run_gate() {
  local level="$1"
  local name="$2"
  shift 2

  echo "── $level: $name ──"

  if "$@"; then
    echo "  ✅ $level PASS"
    GATES_PASS=$((GATES_PASS + 1))
  else
    echo "  ❌ $level FAIL"
    GATES_FAIL=$((GATES_FAIL + 1))
  fi

  echo
}

# ────────────────────────────────────────────────────────────────
# L1 — Code Review / Git Integrity
# ────────────────────────────────────────────────────────────────

run_gate "L1" "Code Review / Git" \
  bash -c '
    git rev-parse --is-inside-work-tree >/dev/null &&
    git log -1 --oneline >/dev/null
  '

# ────────────────────────────────────────────────────────────────
# L2 — Static Analysis
# ────────────────────────────────────────────────────────────────

run_gate "L2" "ESLint" \
  npx eslint src/ --max-warnings=0

# ────────────────────────────────────────────────────────────────
# L3 — Unit Tests
# ────────────────────────────────────────────────────────────────

run_gate "L3" "Unit Tests (Vitest)" \
  npx vitest run

# ────────────────────────────────────────────────────────────────
# L4 — Component Tests
# ────────────────────────────────────────────────────────────────

if [[ -d "tests/component" ]]; then
  run_gate "L4" "Component Tests (RTL)" \
    npx vitest run tests/component/
else
  echo "── L4: Component Tests (RTL) ──"
  echo "  ⏭️  L4 SKIP — tests/component not found"
  GATES_SKIP=$((GATES_SKIP + 1))
  echo
fi

# ────────────────────────────────────────────────────────────────
# L5 — Integration Tests
# ────────────────────────────────────────────────────────────────

run_gate "L5" "Integration Tests (DB)" \
  node supabase/migrations/run_171.mjs \
    "$CONN" \
    tests/integration/rpc-security.test.sql

# ────────────────────────────────────────────────────────────────
# L6 — Security Tests
# ────────────────────────────────────────────────────────────────

run_gate "L6" "Security Tests (DB)" \
  node supabase/migrations/run_171.mjs \
    "$CONN" \
    supabase/migrations/184_test_q1_q4_security.sql

# ────────────────────────────────────────────────────────────────
# L7 — E2E Tests
# ────────────────────────────────────────────────────────────────

echo "── L7: E2E Tests (Playwright) ──"

if command -v npx >/dev/null 2>&1 &&
   npx playwright --version >/dev/null 2>&1; then

  if npx playwright test --reporter=line; then
    echo "  ✅ L7 PASS"
    GATES_PASS=$((GATES_PASS + 1))
  else
    echo "  ❌ L7 FAIL"
    GATES_FAIL=$((GATES_FAIL + 1))
  fi

else
  echo "  ❌ L7 FAIL — Playwright is not installed"
  GATES_FAIL=$((GATES_FAIL + 1))
fi

echo

# ────────────────────────────────────────────────────────────────
# L8 — Performance
# ────────────────────────────────────────────────────────────────

run_gate "L8" "Performance" \
  node tests/performance/api-bench.js "$CONN"

# ────────────────────────────────────────────────────────────────
# L9 — Production Smoke
# ────────────────────────────────────────────────────────────────

run_gate "L9" "Production Smoke" \
  bash tests/production/smoke.sh "$CONN"

# ────────────────────────────────────────────────────────────────
# Summary
# ────────────────────────────────────────────────────────────────

echo "╔══════════════════════════════════════════════════════╗"
echo "║                    GATE SUMMARY                     ║"
echo "╠══════════════════════════════════════════════════════╣"
printf "║  PASS: %-3s | FAIL: %-3s | SKIP: %-3s               ║\n" \
  "$GATES_PASS" "$GATES_FAIL" "$GATES_SKIP"
echo "╚══════════════════════════════════════════════════════╝"
echo

if (( GATES_FAIL > 0 )); then
  echo "❌ DEPLOY BLOCKED — mandatory gate failure detected"
  exit 1
fi

if (( GATES_SKIP > 0 )); then
  echo "⚠️  DEPLOY BLOCKED — mandatory gate was skipped"
  exit 1
fi

echo "✅ ALL MANDATORY GATES PASSED — deployment allowed"
exit 0
