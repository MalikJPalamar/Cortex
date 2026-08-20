#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════
# Centaurion Health Check — L3 Sensing (Tripwires)
# ═══════════════════════════════════════════════════════════
#
# Checks VPS services, disk, memory, docker containers,
# and outputs a machine-readable JSON status.
#
# Run manually:
#   bash deploy/vps1/health-check.sh
#
# No separate cron entry needed: centaurion-dev-loop.sh calls this script at the
# end of every run (3x daily) and commits memory/state/health-status.json along
# with dev-loop-status.json. Failures here never fail the dev loop.
#
# ═══════════════════════════════════════════════════════════

set -uo pipefail

REPO_DIR="${CENTAURION_REPO:-$HOME/Centaurion}"
STATUS_FILE="$REPO_DIR/memory/state/health-status.json"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

mkdir -p "$(dirname "$STATUS_FILE")"

# ── Checks ────────────────────────────────────────────────

# Disk usage
DISK_PCT=$(df / 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')
DISK_STATUS="ok"
if [ "${DISK_PCT:-0}" -ge 90 ]; then DISK_STATUS="critical";
elif [ "${DISK_PCT:-0}" -ge 80 ]; then DISK_STATUS="warning"; fi

# Memory usage
MEM_PCT=$(free 2>/dev/null | awk '/^Mem:/ {printf "%.0f", $3/$2*100}')
MEM_STATUS="ok"
if [ "${MEM_PCT:-0}" -ge 90 ]; then MEM_STATUS="critical";
elif [ "${MEM_PCT:-0}" -ge 80 ]; then MEM_STATUS="warning"; fi

# Docker status
# NB: no "|| echo 0" after wc — wc always prints a count, and with pipefail the
# fallback would append a second "0" and corrupt the JSON when docker is absent.
DOCKER_RUNNING=$(docker ps --format '{{.Names}}' 2>/dev/null | wc -l | tr -d ' ')
DOCKER_RUNNING=${DOCKER_RUNNING:-0}
DOCKER_STATUS="ok"
if ! command -v docker &>/dev/null; then DOCKER_STATUS="not_installed";
elif [ "$DOCKER_RUNNING" -eq 0 ]; then DOCKER_STATUS="no_containers"; fi

# NanoClaw container
NANOCLAW_UP="false"
if docker ps --format '{{.Names}}' 2>/dev/null | grep -qi "nanoclaw\|claw"; then
  NANOCLAW_UP="true"
fi

# Claude Code auth
CLAUDE_AUTH="unknown"
if command -v claude &>/dev/null; then
  CLAUDE_AUTH=$(claude auth status 2>/dev/null | grep -o '"authMethod": *"[^"]*"' | sed 's/.*"authMethod": *"//;s/"//' || echo "unknown")
fi

# Git status
GIT_CLEAN="false"
if [ -z "$(git -C "$REPO_DIR" status --porcelain 2>/dev/null)" ]; then
  GIT_CLEAN="true"
fi
COMMITS_AHEAD=$(git -C "$REPO_DIR" log origin/main..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
COMMITS_AHEAD=${COMMITS_AHEAD:-0}

# Dev loop last run
LAST_LOG=$(find "$REPO_DIR/logs" -name "dev-loop-*.log" -type f 2>/dev/null | sort | tail -1)
LAST_RUN="never"
LAST_RUN_OK="false"
if [ -n "$LAST_LOG" ]; then
  LAST_RUN=$(basename "$LAST_LOG" | sed 's/dev-loop-//;s/.log//')
  if grep -q "Dev Loop Complete" "$LAST_LOG" 2>/dev/null; then
    LAST_RUN_OK="true"
  fi
fi

# Uptime
UPTIME=$(uptime -p 2>/dev/null || uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')

# ── Output JSON ──────────────────────────────────────────

cat > "$STATUS_FILE" <<HEALTH_JSON
{
  "timestamp": "$TIMESTAMP",
  "overall": "$([ "$DISK_STATUS" = "ok" ] && [ "$MEM_STATUS" = "ok" ] && echo "healthy" || echo "degraded")",
  "system": {
    "disk_percent": ${DISK_PCT:-0},
    "disk_status": "$DISK_STATUS",
    "memory_percent": ${MEM_PCT:-0},
    "memory_status": "$MEM_STATUS",
    "uptime": "$UPTIME"
  },
  "services": {
    "docker_running": $DOCKER_RUNNING,
    "docker_status": "$DOCKER_STATUS",
    "nanoclaw_up": $NANOCLAW_UP,
    "claude_auth": "$CLAUDE_AUTH"
  },
  "repo": {
    "git_clean": $GIT_CLEAN,
    "commits_ahead": $COMMITS_AHEAD,
    "last_dev_loop": "$LAST_RUN",
    "last_dev_loop_ok": $LAST_RUN_OK
  }
}
HEALTH_JSON

# ── Human-readable output ────────────────────────────────

echo "═══ Centaurion Health Check — $TIMESTAMP ═══"
echo ""
echo "System:"
echo "  Disk:   ${DISK_PCT:-?}% ($DISK_STATUS)"
echo "  Memory: ${MEM_PCT:-?}% ($MEM_STATUS)"
echo "  Uptime: $UPTIME"
echo ""
echo "Services:"
echo "  Docker:    $DOCKER_RUNNING containers ($DOCKER_STATUS)"
echo "  NanoClaw:  $([ "$NANOCLAW_UP" = "true" ] && echo "running" || echo "DOWN")"
echo "  Claude:    $CLAUDE_AUTH"
echo ""
echo "Repo:"
echo "  Clean:     $GIT_CLEAN"
echo "  Unpushed:  $COMMITS_AHEAD commits"
echo "  Last loop: $LAST_RUN (success: $LAST_RUN_OK)"
echo ""
echo "Status: $(cat "$STATUS_FILE" | grep -o '"overall": *"[^"]*"' | sed 's/.*"overall": *"//;s/"//')"
echo "Written to: $STATUS_FILE"
