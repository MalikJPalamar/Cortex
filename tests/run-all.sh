#!/usr/bin/env bash
# Centaurion — Run All Verification Tests
# Executes all phase verification scripts in order.
# Usage: bash tests/run-all.sh
# Exit 0 = all phases pass, Exit 1 = any phase has failures

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OVERALL_PASS=0
OVERALL_FAIL=0
PHASE_RESULTS=""

run_phase() {
  local phase_num="$1" phase_name="$2" script="$3"

  if [ ! -f "$REPO_ROOT/$script" ]; then
    echo "⚠ Phase $phase_num ($phase_name): script not found ($script)"
    return
  fi

  echo ""
  echo "╔══════════════════════════════════════╗"
  echo "║  Phase $phase_num: $phase_name"
  echo "╚══════════════════════════════════════╝"

  OUTPUT=""
  EXIT_CODE=0
  OUTPUT=$(bash "$REPO_ROOT/$script" 2>&1) || EXIT_CODE=$?

  echo "$OUTPUT"

  # Count only genuine pass()/fail() result lines, not each script's footer
  # summary line ("  ✓ ALL …" / "  ✗ <N> … PENDING|FAILED"). Footer summaries
  # start with "ALL" or a digit; real assertions start with an Rxx.x id.
  P_PASS=$(echo "$OUTPUT" | grep "  ✓" | grep -vc "  ✓ ALL " || true)
  P_FAIL=$(echo "$OUTPUT" | grep "  ✗" | grep -vc "  ✗ [0-9]" || true)
  OVERALL_PASS=$((OVERALL_PASS + P_PASS))
  OVERALL_FAIL=$((OVERALL_FAIL + P_FAIL))

  if [ "$EXIT_CODE" -eq 0 ]; then
    PHASE_RESULTS="${PHASE_RESULTS}  ✓ Phase $phase_num ($phase_name): $P_PASS/$((P_PASS + P_FAIL)) passed\n"
  else
    PHASE_RESULTS="${PHASE_RESULTS}  ✗ Phase $phase_num ($phase_name): $P_PASS/$((P_PASS + P_FAIL)) passed, $P_FAIL failed\n"
  fi
}

# --- Run phases in order ---
run_phase 1 "Core Loop" "tests/verify-core-loop.sh"
run_phase 2 "Memory Integration" "tests/verify-memory-integration.sh"
run_phase 3 "Multi-Runtime & Feedback" "tests/verify-multi-runtime.sh"
run_phase 4 "Knowledge Depth" "tests/verify-knowledge-depth.sh"
run_phase 5 "Operational Workflows" "tests/verify-operational.sh"
run_phase 6 "Cross-Venture Coherence" "tests/verify-coherence.sh"
# Phase 7 validates the live VPS1 host (cron, NanoClaw, deployment) and cannot pass
# on an ephemeral CI runner. GitHub Actions sets CI=true; skip it there. It still runs
# locally and on VPS1 (where the dev loop and health check cover production).
if [ "${CI:-}" = "true" ]; then
  echo ""
  echo "⏭  Phase 7 (Production Deployment): skipped in CI (validates live VPS1 host)"
else
  run_phase 7 "Production Deployment" "tests/verify-production.sh"
fi
run_phase 8 "Operational Automation" "tests/verify-automation.sh"
run_phase 10 "Hermes Integration" "tests/verify-hermes-integration.sh"

# Dev loop infrastructure (not a development phase, but a meta-test)
echo ""
echo "╔══════════════════════════════════════╗"
echo "║  Infrastructure: Dev Loop            "
echo "╚══════════════════════════════════════╝"

INFRA_OUTPUT=""
INFRA_EXIT=0
INFRA_OUTPUT=$(bash "$REPO_ROOT/tests/verify-dev-loop.sh" 2>&1) || INFRA_EXIT=$?
echo "$INFRA_OUTPUT"

I_PASS=$(echo "$INFRA_OUTPUT" | grep -c "  ✓" || true)
I_FAIL=$(echo "$INFRA_OUTPUT" | grep -c "  ✗" || true)
OVERALL_PASS=$((OVERALL_PASS + I_PASS))
OVERALL_FAIL=$((OVERALL_FAIL + I_FAIL))

if [ "$INFRA_EXIT" -eq 0 ]; then
  PHASE_RESULTS="${PHASE_RESULTS}  ✓ Infrastructure (Dev Loop): $I_PASS/$((I_PASS + I_FAIL)) passed\n"
else
  PHASE_RESULTS="${PHASE_RESULTS}  ✗ Infrastructure (Dev Loop): $I_PASS/$((I_PASS + I_FAIL)) passed, $I_FAIL failed\n"
fi

# --- Overall Summary ---
OVERALL_TOTAL=$((OVERALL_PASS + OVERALL_FAIL))

echo ""
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║           CENTAURION TEST SUITE SUMMARY          ║"
echo "╠══════════════════════════════════════════════════╣"
printf "$PHASE_RESULTS"
echo "╠══════════════════════════════════════════════════╣"
echo "  TOTAL: $OVERALL_PASS passed, $OVERALL_FAIL failed ($OVERALL_TOTAL checks)"
echo "╚══════════════════════════════════════════════════╝"

if [ "$OVERALL_FAIL" -eq 0 ]; then
  echo ""
  echo "  ✓ ALL TESTS PASS"
  exit 0
else
  echo ""
  echo "  Phase 2 failures are EXPECTED (TDD — tests written before implementation)"
  exit 1
fi
