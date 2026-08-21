#!/usr/bin/env bash
# Centaurion — Identify Next Development Priority
# Runs all phase verification scripts, finds the first failing phase,
# and outputs JSON with the next priority + TDD plan.
# Exit 0 always.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# --- Define phases ---
PHASE_NAMES=(
  "Core Loop"
  "Memory Integration"
  "Multi-Runtime and Feedback"
  "Knowledge Depth"
  "Operational Workflows"
  "Cross-Venture Coherence"
  "Production Deployment"
  "Operational Automation"
  "Hermes Integration"
)
PHASE_SCRIPTS=(
  "tests/verify-core-loop.sh"
  "tests/verify-memory-integration.sh"
  "tests/verify-multi-runtime.sh"
  "tests/verify-knowledge-depth.sh"
  "tests/verify-operational.sh"
  "tests/verify-coherence.sh"
  "tests/verify-production.sh"
  "tests/verify-automation.sh"
  "tests/verify-hermes-integration.sh"
)

# Check IDs that validate host configuration rather than repo content.
HOST_TEST_PATTERN="${CENTAURION_HOST_TEST_PATTERN:-R3[12]\.[0-9]+}"

# --- Run all phases and collect results ---
declare -a PASSES FAILS TOTALS OUTPUTS
OVERALL_PASS=0
OVERALL_FAIL=0

for i in "${!PHASE_SCRIPTS[@]}"; do
  SCRIPT="$REPO_ROOT/${PHASE_SCRIPTS[$i]}"
  if [ -f "$SCRIPT" ]; then
    OUTPUT=$(bash "$SCRIPT" 2>&1) || true
  else
    OUTPUT=""
  fi
  # Host-config checks (Phase 7 R31.x: crontab, claude auth, push rights, recent;
  # R32.x: docker images / systemd services on the host)
  # log) can only be fixed on the VPS host, never from inside the repo. When the
  # dev loop itself is the caller it sets CENTAURION_SKIP_HOST_TESTS=1 so those
  # failures are not handed to Claude as "the next priority".
  if [ "${CENTAURION_SKIP_HOST_TESTS:-0}" = "1" ]; then
    OUTPUT=$(echo "$OUTPUT" | grep -vE "^  ✗ ${HOST_TEST_PATTERN}")
  fi
  # Count genuine per-check result lines only. Each phase script prints a
  # summary footer that ALSO begins with the ✓/✗ glyph, e.g.
  #   "  ✓ ALL PHASE 7 REQUIREMENTS PASS" / "  ✓ DEV LOOP INFRASTRUCTURE VERIFIED"
  #   "  ✗ 1 PHASE 7 REQUIREMENT(S) PENDING"
  # Counting those footers inflated every phase's tally by one and made the loop
  # report phantom failures (e.g. R32.4 showed "2 fail" when only 1 check fails).
  # Exclude footers: pass footers start "✓ ALL "/"✓ DEV LOOP "; fail footers start
  # "✗ <digit>" (real checks start "✗ R.." or a text description, never a digit).
  P=$(echo "$OUTPUT" | grep "  ✓" | grep -cvE '^  ✓ (ALL |DEV LOOP )' || true)
  F=$(echo "$OUTPUT" | grep "  ✗" | grep -cvE '^  ✗ [0-9]' || true)
  PASSES[$i]=$P
  FAILS[$i]=$F
  TOTALS[$i]=$((P + F))
  OUTPUTS[$i]="$OUTPUT"
  OVERALL_PASS=$((OVERALL_PASS + P))
  OVERALL_FAIL=$((OVERALL_FAIL + F))
done

OVERALL_TOTAL=$((OVERALL_PASS + OVERALL_FAIL))

# --- Build phase stats JSON fragment ---
PHASE_STATS=""
for i in "${!PHASE_NAMES[@]}"; do
  NUM=$((i + 1))
  PHASE_STATS="$PHASE_STATS  \"phase${NUM}\": {\"pass\": ${PASSES[$i]}, \"fail\": ${FAILS[$i]}, \"total\": ${TOTALS[$i]}},"
done

# --- Find first failing phase ---
FOUND=false
for i in "${!PHASE_NAMES[@]}"; do
  NUM=$((i + 1))
  if [ "${FAILS[$i]}" -gt 0 ]; then
    FIRST_FAIL=$(echo "${OUTPUTS[$i]}" | grep "  ✗" | head -1 | sed 's/.*✗ //')
    REQ_GROUP=$(echo "$FIRST_FAIL" | grep -oE 'R[0-9]+' | head -1 || echo "R?")

    STATUS="progressing"
    if [ "$NUM" -eq 1 ]; then STATUS="failing"; fi

    cat <<PRIORITY_JSON
{
  "status": "$STATUS",
  "phase": $NUM,
  "phase_name": "${PHASE_NAMES[$i]}",
  "requirement": "$REQ_GROUP",
  "first_failure": "$FIRST_FAIL",
  "test_file": "${PHASE_SCRIPTS[$i]}",
$PHASE_STATS
  "overall": {"pass": $OVERALL_PASS, "fail": $OVERALL_FAIL, "total": $OVERALL_TOTAL},
  "host_tests_skipped": $([ "${CENTAURION_SKIP_HOST_TESTS:-0}" = "1" ] && echo true || echo false),
  "tdd_plan": {
    "red": "Phase $NUM test failing: $FIRST_FAIL",
    "green": "Implement the feature to make this test pass",
    "refactor": "Re-run full suite to check for regressions"
  }
}
PRIORITY_JSON
    FOUND=true
    break
  fi
done

if [ "$FOUND" = false ]; then
  NEXT=$((${#PHASE_NAMES[@]} + 1))
  cat <<PRIORITY_JSON
{
  "status": "all_passing",
  "phase": $NEXT,
  "phase_name": "All phases complete — write Phase $NEXT tests",
  "requirement": "none_failing",
  "first_failure": null,
  "test_file": null,
$PHASE_STATS
  "overall": {"pass": $OVERALL_PASS, "fail": $OVERALL_FAIL, "total": $OVERALL_TOTAL},
  "host_tests_skipped": $([ "${CENTAURION_SKIP_HOST_TESTS:-0}" = "1" ] && echo true || echo false),
  "tdd_plan": {
    "red": "Write Phase $NEXT verification tests",
    "green": "Implement Phase $NEXT requirements",
    "refactor": "Review and optimize existing implementations"
  }
}
PRIORITY_JSON
fi

exit 0
