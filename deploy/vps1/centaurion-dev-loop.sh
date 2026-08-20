#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════
# Centaurion Daily Development Loop — VPS1 Cron Script
# ═══════════════════════════════════════════════════════════
#
# Runs Claude Code against failing tests using Max subscription.
# Scheduled via cron (3x daily) on VPS1.
#
# Install:
#   CENTAURION_REPO=~/Centaurion bash deploy/vps1/centaurion-dev-loop.sh --install
#
# Manual run:
#   CENTAURION_REPO=~/Centaurion bash deploy/vps1/centaurion-dev-loop.sh
#
# Logs: ~/Centaurion/logs/dev-loop-YYYY-MM-DD.log
# Status: memory/state/dev-loop-status.json  (status "error" + claude_exit /
#         claude_elapsed_seconds / claude_stderr_tail / consecutive_zero_fix_runs
#         when claude exits non-zero, finishes in < 60s, prints an auth/error
#         signature, or is missing from PATH)
# Health: deploy/vps1/health-check.sh runs at the end of every loop and its
#         memory/state/health-status.json is committed alongside the status.
# Picker: tests/identify-next-priority.sh is called with
#         CENTAURION_SKIP_HOST_TESTS=1 so host-config checks (R31.x) are never
#         handed to Claude — they can only be fixed on the VPS itself.
#
# ═══════════════════════════════════════════════════════════

set -uo pipefail

REPO_DIR="${CENTAURION_REPO:-$HOME/Centaurion}"

# Headless auth: cron has no browser, so an interactive `claude login` OAuth
# session eventually expires and cannot refresh. A long-lived token from
# `claude setup-token` placed in this file (chmod 600) as
#   CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat01-...
# is picked up by `claude -p` automatically. See deploy/vps1/README.md.
ENV_FILE="${CENTAURION_ENV_FILE:-/root/.config/centaurion/env}"
if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
fi
LOG_DIR="$REPO_DIR/logs"
LOCK_FILE="$REPO_DIR/logs/.dev-loop.lock"
STATUS_FILE="$REPO_DIR/memory/state/dev-loop-status.json"
DATE=$(date +%Y-%m-%d)
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
LOG_FILE="$LOG_DIR/dev-loop-$DATE.log"
MAX_TURNS=30
MAX_FIXES=10
START_TIME=$(date +%s)

# ── Install mode ──────────────────────────────────────────
if [ "${1:-}" = "--install" ]; then
  mkdir -p "$LOG_DIR"
  CRON_BASE="cd $REPO_DIR && CENTAURION_REPO=$REPO_DIR bash deploy/vps1/centaurion-dev-loop.sh >> $LOG_DIR/cron.log 2>&1"

  if crontab -l 2>/dev/null | grep -q "centaurion-dev-loop"; then
    echo "Cron jobs already installed:"
    crontab -l | grep "centaurion-dev-loop"
  else
    (crontab -l 2>/dev/null
     echo "0 4 * * * $CRON_BASE"
     echo "0 12 * * * $CRON_BASE"
     echo "0 20 * * * $CRON_BASE"
    ) | crontab -
    echo "Cron jobs installed (3x daily: 6am, 2pm, 10pm CET):"
    crontab -l | grep "centaurion-dev-loop"
  fi
  exit 0
fi

# ── Uninstall mode ────────────────────────────────────────
if [ "${1:-}" = "--uninstall" ]; then
  crontab -l 2>/dev/null | grep -v "centaurion-dev-loop" | crontab -
  rm -f "$LOCK_FILE"
  echo "Cron jobs removed."
  exit 0
fi

# ── Concurrency lock ──────────────────────────────────────
mkdir -p "$LOG_DIR"

if [ -f "$LOCK_FILE" ]; then
  LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null)
  if kill -0 "$LOCK_PID" 2>/dev/null; then
    echo "[$(date '+%H:%M:%S')] Dev loop already running (PID $LOCK_PID). Skipping." | tee -a "$LOG_FILE"
    exit 0
  else
    rm -f "$LOCK_FILE"
  fi
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

# ── Helpers ───────────────────────────────────────────────
log() {
  echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# JSON-escape a multi-line string for embedding in a double-quoted JSON value.
json_escape() {
  tr '\t' ' ' | tr -d '\000-\010\013-\037' | sed 's/\\/\\\\/g; s/"/\\"/g' | awk '{printf "%s\\n", $0}'
}

# Diagnostics carried into the status file (populated by the Claude step).
CLAUDE_EXIT=-1
CLAUDE_ELAPSED=0
CLAUDE_STDERR_TAIL=""
ERROR_REASON=""
CONSECUTIVE_ZERO_FIX_RUNS=$(grep -o '"consecutive_zero_fix_runs": *[0-9]*' "$STATUS_FILE" 2>/dev/null | head -1 | sed 's/.*: *//')
CONSECUTIVE_ZERO_FIX_RUNS=${CONSECUTIVE_ZERO_FIX_RUNS:-0}

write_status() {
  local status="$1" phase="${2:-0}" fixed="${3:-0}" remaining="${4:-0}" elapsed="${5:-0}"
  local tail_json
  tail_json=$(printf '%s' "$CLAUDE_STDERR_TAIL" | json_escape)
  mkdir -p "$(dirname "$STATUS_FILE")"
  cat > "$STATUS_FILE" <<STATUS_JSON
{
  "timestamp": "$TIMESTAMP",
  "date": "$DATE",
  "status": "$status",
  "phase": $phase,
  "tests_fixed": $fixed,
  "tests_remaining": $remaining,
  "elapsed_seconds": $elapsed,
  "max_turns": $MAX_TURNS,
  "max_fixes": $MAX_FIXES,
  "claude_exit": $CLAUDE_EXIT,
  "claude_elapsed_seconds": $CLAUDE_ELAPSED,
  "claude_stderr_tail": "$tail_json",
  "error_reason": "$ERROR_REASON",
  "auth_source": "$([ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] && echo oauth_token_env || echo interactive_login)",
  "consecutive_zero_fix_runs": $CONSECUTIVE_ZERO_FIX_RUNS
}
STATUS_JSON
}

# Commit + push the status/health snapshots so a broken run is visible on GitHub
# even when Claude produced nothing. Never fatal.
publish_state() {
  git add memory/state/dev-loop-status.json memory/state/health-status.json 2>/dev/null || true
  if ! git diff --cached --quiet 2>/dev/null; then
    local st; st=$(grep -o '"status": *"[^"]*"' "$STATUS_FILE" | head -1 | sed 's/.*: *"//;s/"//')
    if [ "$st" = "error" ]; then
      git commit -m "status: dev loop error (${ERROR_REASON:-unknown}) $DATE" >> "$LOG_FILE" 2>&1 || true
    else
      git commit -m "status: dev loop $st $DATE" >> "$LOG_FILE" 2>&1 || true
    fi
  fi
  if [ "$(git log origin/main..HEAD --oneline 2>/dev/null | wc -l)" -gt 0 ]; then
    git push origin main >> "$LOG_FILE" 2>&1 || log "ERROR: git push failed. Will retry on next run."
  fi
}

# Run the VPS health check at the end of every loop so health-status.json can't
# go stale. Failure is tolerated.
run_health_check() {
  if [ -f "$REPO_DIR/deploy/vps1/health-check.sh" ]; then
    log "Running health check..."
    CENTAURION_REPO="$REPO_DIR" bash "$REPO_DIR/deploy/vps1/health-check.sh" >> "$LOG_FILE" 2>&1 \
      || log "WARNING: health-check.sh exited non-zero (tolerated)"
  fi
}

# ── Log rotation (keep last 14 days) ──────────────────────
find "$LOG_DIR" -name "dev-loop-*.log" -mtime +14 -delete 2>/dev/null || true

# ── Main execution ────────────────────────────────────────
log "═══ Centaurion Dev Loop Starting ═══"
log "Date: $DATE | Max turns: $MAX_TURNS | Max fixes: $MAX_FIXES"
log "Repo: $REPO_DIR"

# Step 1: Pull latest
log "Pulling latest from main..."
cd "$REPO_DIR"
git pull origin main >> "$LOG_FILE" 2>&1 || {
  log "ERROR: git pull failed"
  ERROR_REASON="git_pull_failed"
  CLAUDE_STDERR_TAIL="git pull origin main failed (see $LOG_FILE)"
  write_status "error" 0 0 0 $(($(date +%s) - START_TIME))
  exit 1
}

# Step 2: Run tests and identify priority
log "Running test suite..."
PRIORITY_JSON=$(CENTAURION_SKIP_HOST_TESTS=1 bash tests/identify-next-priority.sh 2>/dev/null)
STATUS=$(echo "$PRIORITY_JSON" | grep -o '"status": *"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')
PHASE=$(echo "$PRIORITY_JSON" | grep -o '"phase": *[0-9]*' | head -1 | sed 's/.*: *//')
FIRST_FAIL=$(echo "$PRIORITY_JSON" | grep -o '"first_failure": *"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')
TOTAL_FAIL=$(echo "$PRIORITY_JSON" | grep -o '"fail": *[0-9]*' | tail -1 | sed 's/.*: *//')
TOTAL_FAIL=${TOTAL_FAIL:-0}

log "Status: $STATUS | Phase: $PHASE | Failures: $TOTAL_FAIL"

if [ "$STATUS" = "all_passing" ]; then
  log "All tests passing. Nothing to develop."
  CONSECUTIVE_ZERO_FIX_RUNS=0
  write_status "all_passing" "$PHASE" 0 0 $(($(date +%s) - START_TIME))
  run_health_check
  publish_state
  log "═══ Dev Loop Complete (no work needed) ═══"
  exit 0
fi

log "First failure: $FIRST_FAIL"

# Step 3: Run Claude Code to fix failing tests
log "Running Claude Code (Max subscription)..."

PROMPT="You are Cortex, the Centaurion daily development loop. Read CLAUDE.md for your identity and the Active Inference loop.

## Current State
$(echo "$PRIORITY_JSON")

## Your Task
Fix the failing tests by building REAL implementation — runnable scripts, accurate content, operational configs. NOT placeholder content that just matches grep patterns.

### Rules
1. Read the failing test to understand EXACTLY what it checks
2. Read related source files to understand context and patterns
3. Build the REAL implementation:
   - Scripts must be runnable (bash -n passes, real commands)
   - Wiki content must be factually accurate (AOB = Art of Breath, not Brilliance)
   - Config files must have real structure (valid JSON/YAML)
   - Cross-references must resolve to actual files
4. Run the phase test to verify your fix
5. Run \`bash tests/run-all.sh\` to check for regressions
6. Stage and commit passing changes
7. Fix up to $MAX_FIXES tests per run
8. If a test requires VPS-specific access (SSH, Docker, external APIs) that you cannot provide, SKIP it and move to the next

### Quality Standards
- Prefer operational code over documentation
- Every script must be executable and do real work
- Wiki pages must contain specific, accurate information — not generic templates
- Cross-venture connections must reference real shared patterns
- Commit message format: \"fix(phase-$PHASE): description\"
- Do NOT push — the script handles pushing"

CLAUDE_OUT="$LOG_DIR/.claude-output-$$.log"
CLAUDE_START=$(date +%s)
if ! command -v claude >/dev/null 2>&1; then
  log "ERROR: claude binary not found on PATH"
  CLAUDE_EXIT=127
  CLAUDE_STDERR_TAIL="claude: command not found (PATH=$PATH)"
else
  claude -p "$PROMPT" \
    --max-turns "$MAX_TURNS" \
    --allowedTools "Bash(bash tests/*)" "Bash(git add*)" "Bash(git commit*)" "Bash(git status)" "Bash(git diff*)" "Bash(mkdir*)" "Edit" "Read" "Write" "Glob" "Grep" \
    --disallowedTools "Bash(git push*)" "Bash(git reset*)" "Bash(rm -rf*)" \
    > "$CLAUDE_OUT" 2>&1
  CLAUDE_EXIT=$?
  cat "$CLAUDE_OUT" >> "$LOG_FILE"
  CLAUDE_STDERR_TAIL=$(tail -n 30 "$CLAUDE_OUT" 2>/dev/null)
  rm -f "$CLAUDE_OUT"
fi
CLAUDE_ELAPSED=$(($(date +%s) - CLAUDE_START))
ELAPSED=$(($(date +%s) - START_TIME))
log "Claude Code exited with: $CLAUDE_EXIT (claude elapsed: ${CLAUDE_ELAPSED}s, total: ${ELAPSED}s)"

# Detect a run that "succeeded" without doing anything: instant exit, non-zero
# exit, or an auth/login/error signature in the output.
CLAUDE_FAILED=""
MIN_CLAUDE_SECONDS=60
if printf '%s' "$CLAUDE_STDERR_TAIL" | grep -qiE 'oauth session expired|oauth token (has )?expired|token expired|failed to authenticate|not logged in|please (run )?/login|login required|invalid api key|authentication[_ ]error|unauthorized'; then
  CLAUDE_FAILED="auth_expired"
  ERROR_REASON="auth_expired"
elif [ "$CLAUDE_EXIT" -eq 127 ]; then
  CLAUDE_FAILED="claude binary missing"
  ERROR_REASON="claude_missing"
elif [ "$CLAUDE_EXIT" -ne 0 ]; then
  CLAUDE_FAILED="exit code $CLAUDE_EXIT"
  ERROR_REASON="claude_exit_$CLAUDE_EXIT"
elif [ "$CLAUDE_ELAPSED" -lt "$MIN_CLAUDE_SECONDS" ]; then
  CLAUDE_FAILED="finished in ${CLAUDE_ELAPSED}s (< ${MIN_CLAUDE_SECONDS}s)"
  ERROR_REASON="instant_exit"
elif printf '%s' "$CLAUDE_STDERR_TAIL" | grep -qiE 'credit balance|rate limit|usage limit|"is_error": *true|^error:'; then
  CLAUDE_FAILED="error signature in output"
  ERROR_REASON="error_signature"
fi
if [ -n "$CLAUDE_FAILED" ]; then
  log "ERROR: Claude run looks broken: $CLAUDE_FAILED"
fi

# Step 4: Commit any uncommitted changes Claude left behind — only when the
# Claude run actually succeeded. A failed run leaves nothing worth a
# "fix(...)" commit; its status is committed separately by publish_state.
if [ -z "$CLAUDE_FAILED" ] && [ -n "$(git status --porcelain -- . ':!logs' ':!memory/state')" ]; then
  log "Claude left uncommitted changes. Committing..."
  git add -A -- . ':!logs'
  git commit -m "fix(phase-$PHASE): dev loop auto-commit $DATE" >> "$LOG_FILE" 2>&1 || true
elif [ -n "$CLAUDE_FAILED" ]; then
  log "Skipping fix(...) auto-commit: Claude run failed ($CLAUDE_FAILED)"
fi

# Step 5: Push if there are new commits
COMMITS_AHEAD=$(git log origin/main..HEAD --oneline 2>/dev/null | wc -l)
if [ "$COMMITS_AHEAD" -gt 0 ]; then
  log "Pushing $COMMITS_AHEAD new commit(s)..."
  if git push origin main >> "$LOG_FILE" 2>&1; then
    log "Pushed successfully."
  else
    log "ERROR: git push failed. Will retry on next run."
  fi
else
  log "No new commits to push."
fi

# Step 6: Post-development verification
log "Running post-development verification..."
POST_JSON=$(CENTAURION_SKIP_HOST_TESTS=1 bash tests/identify-next-priority.sh 2>/dev/null)
POST_FAIL=$(echo "$POST_JSON" | grep -o '"fail": *[0-9]*' | tail -1 | sed 's/.*: *//')
POST_STATUS=$(echo "$POST_JSON" | grep -o '"status": *"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')
POST_FAIL=${POST_FAIL:-0}

FIXED=$((TOTAL_FAIL - POST_FAIL))
if [ "$FIXED" -lt 0 ]; then FIXED=0; fi

if [ "$FIXED" -eq 0 ]; then
  CONSECUTIVE_ZERO_FIX_RUNS=$((CONSECUTIVE_ZERO_FIX_RUNS + 1))
else
  CONSECUTIVE_ZERO_FIX_RUNS=0
fi

FINAL_STATUS="$POST_STATUS"
if [ -n "$CLAUDE_FAILED" ]; then
  FINAL_STATUS="error"
fi

ELAPSED=$(($(date +%s) - START_TIME))
log "Post-dev status: $FINAL_STATUS | Fixed: $FIXED | Remaining: $POST_FAIL | Zero-fix streak: $CONSECUTIVE_ZERO_FIX_RUNS | Duration: ${ELAPSED}s"
write_status "$FINAL_STATUS" "$PHASE" "$FIXED" "$POST_FAIL" "$ELAPSED"

# Step 7: Health check + publish snapshots (status file is pushed even on error)
run_health_check
publish_state

if [ "$FINAL_STATUS" = "error" ]; then
  log "═══ Dev Loop Complete (WITH ERRORS — see claude_stderr_tail in status) ═══"
  exit 1
fi
log "═══ Dev Loop Complete ═══"
