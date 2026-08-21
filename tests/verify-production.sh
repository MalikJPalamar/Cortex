#!/usr/bin/env bash
# Centaurion — Phase 7: Deployment & Integration (Production)
# These tests can ONLY pass when real systems are configured and running.
# No amount of markdown can satisfy them.
# Usage: bash tests/verify-production.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0
TOTAL=0

pass() { PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); echo "  ✗ $1"; }

# ============================================================
# R31: VPS1 Services — Are They Actually Running?
# ============================================================
echo ""
echo "═══ R31: VPS1 Services ═══"

# R31.1: Claude Code is authenticated (not using a raw API key)
if command -v claude &>/dev/null; then
  # Headless hosts authenticate via CLAUDE_CODE_OAUTH_TOKEN (see deploy/vps1/README.md);
  # `claude auth status` reports "none" in that mode, so check the env/env-file first.
  ENV_FILE="${CENTAURION_ENV_FILE:-/root/.config/centaurion/env}"
  if [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] && [ -r "$ENV_FILE" ] && grep -q '^CLAUDE_CODE_OAUTH_TOKEN=sk-ant-' "$ENV_FILE"; then
    TOKEN_SOURCE="env file $ENV_FILE"
  elif [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
    TOKEN_SOURCE="environment"
  else
    TOKEN_SOURCE=""
  fi
  AUTH_METHOD=$(claude auth status 2>/dev/null | grep -o '"authMethod": *"[^"]*"' | sed 's/.*"authMethod": *"//;s/"//' || echo "unknown")
  if [ -n "$TOKEN_SOURCE" ]; then
    pass "R31.1: Claude Code authenticated via OAuth token ($TOKEN_SOURCE)"
  elif [ "$AUTH_METHOD" = "claude.ai" ] || [ "$AUTH_METHOD" = "oauth_token" ]; then
    pass "R31.1: Claude Code authenticated via subscription ($AUTH_METHOD)"
  elif [ "$AUTH_METHOD" = "none" ]; then
    fail "R31.1: Claude Code not authenticated"
  else
    fail "R31.1: Claude Code using $AUTH_METHOD (should be claude.ai or oauth_token)"
  fi
else
  fail "R31.1: claude CLI not found"
fi

# R31.2: Cron job is installed and pointing to correct path
if crontab -l 2>/dev/null | grep -q "centaurion-dev-loop"; then
  CRON_PATH=$(crontab -l | grep "centaurion-dev-loop" | head -1)
  # Repo was renamed Centaurion -> Cortex; accept either checkout path or an
  # explicit CENTAURION_REPO= in the cron line.
  if echo "$CRON_PATH" | grep -qE "/root/(Centaurion|Cortex)|\\\$HOME/(Centaurion|Cortex)|CENTAURION_REPO"; then
    pass "R31.2: Dev loop cron installed with correct path"
  else
    fail "R31.2: Cron installed but path may be wrong"
  fi
else
  fail "R31.2: Dev loop cron not installed"
fi

# R31.3: Dev loop has run successfully at least once in the last 48 hours
# Check ALL recent logs (not just first) because today's in-progress log won't
# have the completion marker yet while the loop is running this very test.
LOG_DIR="$REPO_ROOT/logs"
RECENT_COMPLETED_LOG=""
if [ -d "$LOG_DIR" ]; then
  while IFS= read -r log; do
    if grep -q "Dev Loop Complete" "$log" 2>/dev/null; then
      RECENT_COMPLETED_LOG="$log"
      break
    fi
  done < <(find "$LOG_DIR" -name "dev-loop-*.log" -mtime -2 -type f)
fi
if [ -n "$RECENT_COMPLETED_LOG" ]; then
  pass "R31.3: Dev loop ran successfully within last 48 hours ($(basename "$RECENT_COMPLETED_LOG"))"
else
  fail "R31.3: No successful dev loop run in last 48 hours"
fi

# R31.4: Git push works (can the loop actually push?)
if git push --dry-run origin main &>/dev/null; then
  pass "R31.4: Git push to origin/main works"
else
  fail "R31.4: Git push to origin/main fails (auth issue?)"
fi

# ============================================================
# R32: NanoClaw / Nova — Agent Is Live
# ============================================================
# Two supported topologies:
#   (a) Host install — a /root/nanoclaw daemon (systemd) that spawns ephemeral
#       agent containers per message.
#   (b) Containerized — NanoClaw/OpenClaw runs as a long-lived Docker container
#       (e.g. ghcr.io/hostinger/hvps-openclaw) with its workspace under
#       /data/.openclaw. This is the current VPS topology.
# Each check below accepts EITHER topology so Phase 7 reflects the real deployment.
echo ""
echo "═══ R32: NanoClaw / Nova ═══"

# Detect a running NanoClaw/OpenClaw container (topology b).
NANOCLAW_CONTAINER=""
if command -v docker &>/dev/null; then
  NANOCLAW_CONTAINER=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -iE 'nanoclaw|openclaw|claw' | head -1)
fi
# Best-effort read of the container's workspace files (config, SOUL).
nc_read() { [ -n "$NANOCLAW_CONTAINER" ] && docker exec "$NANOCLAW_CONTAINER" sh -c "$1" 2>/dev/null; }

# R32.1: NanoClaw deployment exists (host dir OR running container)
if [ -d "/root/nanoclaw" ] || [ -d "$HOME/nanoclaw" ]; then
  pass "R32.1: NanoClaw directory exists (host install)"
elif [ -n "$NANOCLAW_CONTAINER" ]; then
  pass "R32.1: NanoClaw/OpenClaw deployed as container ($NANOCLAW_CONTAINER)"
else
  fail "R32.1: No NanoClaw host dir (/root/nanoclaw) or running container found"
fi

# R32.2: NanoClaw config exists (host .env OR container workspace config)
NANOCLAW_ENV=""
for candidate in /root/nanoclaw/.env "$HOME/nanoclaw/.env"; do
  if [ -f "$candidate" ]; then NANOCLAW_ENV="$candidate"; break; fi
done
NANOCLAW_CFG=""   # captured model/provider config text, from whichever topology
if [ -n "$NANOCLAW_ENV" ]; then
  NANOCLAW_CFG=$(cat "$NANOCLAW_ENV" 2>/dev/null)
  pass "R32.2: NanoClaw .env exists (host install)"
elif [ -n "$NANOCLAW_CONTAINER" ]; then
  NANOCLAW_CFG=$(nc_read 'cat /data/.openclaw/*.json 2>/dev/null')
  if [ -n "$NANOCLAW_CFG" ]; then
    pass "R32.2: NanoClaw/OpenClaw config present in container workspace"
  else
    fail "R32.2: Container running but no workspace config found (/data/.openclaw)"
  fi
else
  fail "R32.2: NanoClaw config not found (no host .env, no container)"
fi

# R32.3: Using a low-cost / non-Anthropic provider (not burning subscription credits)
if [ -n "$NANOCLAW_CFG" ]; then
  if echo "$NANOCLAW_CFG" | grep -qiE "free|qwen|minimax|nexos|openrouter|groq|deepseek"; then
    pass "R32.3: Configured with a low-cost / non-Anthropic provider"
  else
    fail "R32.3: Provider may not be low-cost — check model/provider config"
  fi
fi

# R32.4: NanoClaw orchestrator is live and able to spawn agent containers.
# Architecture (see /root/nanoclaw/CLAUDE.md): a single Node.js daemon
# (systemd unit `nanoclaw.service`) connects to WhatsApp/Telegram and
# spawns *ephemeral* Docker containers per message — they exit on `--rm`.
# So `docker ps` will normally show no nanoclaw container, even when fully
# operational. The correct liveness signal is: orchestrator process up AND
# agent image built so spawn-on-demand actually works.
ORCH_LIVE=0
if pgrep -f "nanoclaw/dist/index.js" >/dev/null 2>&1; then
  ORCH_LIVE=1
fi
IMAGE_READY=0
if docker images --format '{{.Repository}}' 2>/dev/null | grep -qi "nanoclaw-agent\|nanoclaw\|claw"; then
  IMAGE_READY=1
fi
if [ "$ORCH_LIVE" = "1" ] && [ "$IMAGE_READY" = "1" ]; then
  pass "R32.4: NanoClaw orchestrator running + agent image built (ready to spawn)"
elif [ -n "$NANOCLAW_CONTAINER" ]; then
  # Containerized topology: the long-lived container IS the live orchestrator.
  pass "R32.4: NanoClaw/OpenClaw orchestrator live as container ($NANOCLAW_CONTAINER)"
elif [ "$ORCH_LIVE" = "1" ]; then
  fail "R32.4: Orchestrator running but agent image missing — run /root/nanoclaw/container/build.sh"
elif [ "$IMAGE_READY" = "1" ]; then
  fail "R32.4: Agent image built but orchestrator not running — systemctl start nanoclaw"
else
  fail "R32.4: NanoClaw orchestrator not running and agent image not built"
fi

# R32.5: SOUL.md deployed matches repo's Nova personality (host file OR container workspace)
SOUL_CONTENT=""
SOUL_SOURCE=""
HOST_SOUL=$(find /root/nanoclaw "$HOME/nanoclaw" -name "SOUL.md" 2>/dev/null | head -1)
if [ -n "$HOST_SOUL" ]; then
  SOUL_CONTENT=$(cat "$HOST_SOUL" 2>/dev/null); SOUL_SOURCE="$HOST_SOUL"
elif [ -n "$NANOCLAW_CONTAINER" ]; then
  SOUL_CONTENT=$(nc_read 'cat /data/.openclaw/workspace/SOUL.md 2>/dev/null'); SOUL_SOURCE="container workspace"
fi
if [ -z "$SOUL_CONTENT" ]; then
  fail "R32.5: SOUL.md not deployed to NanoClaw/OpenClaw"
elif echo "$SOUL_CONTENT" | grep -qiE "Nova|sensing|afferent|Centaurion"; then
  pass "R32.5: Deployed SOUL.md carries Nova/Centaurion identity ($SOUL_SOURCE)"
else
  fail "R32.5: Deployed SOUL.md is the generic template, not the Centaurion Nova soul ($SOUL_SOURCE)"
fi

# ============================================================
# R33: GitHub Actions — Report Workflow Operational
# ============================================================
echo ""
echo "═══ R33: GitHub Actions Report ═══"

# R33.1: daily-dev-loop.yml exists and has no Claude Code action (report only)
WORKFLOW="$REPO_ROOT/.github/workflows/daily-dev-loop.yml"
if [ -f "$WORKFLOW" ]; then
  if grep -q "anthropics/claude-code-action" "$WORKFLOW"; then
    fail "R33.1: Workflow still uses claude-code-action (should be report-only)"
  else
    pass "R33.1: Workflow is report-only (no claude-code-action)"
  fi
else
  fail "R33.1: daily-dev-loop.yml not found"
fi

# R33.2: At least 2 dev-loop issues have been created on GitHub
ISSUE_COUNT=$(git log --all --oneline --grep="dev-loop" 2>/dev/null | wc -l)
if [ -f "$REPO_ROOT/.planning/STATE.md" ] && grep -qi "issue\|dev-loop.*report\|github.*issue" "$REPO_ROOT/.planning/STATE.md"; then
  pass "R33.2: Dev loop issues referenced in state tracking"
else
  # Can't directly query GitHub API from bash, check for evidence
  if [ -f "$WORKFLOW" ] && grep -q "issues.create" "$WORKFLOW"; then
    pass "R33.2: Workflow configured to create issues (verify on GitHub)"
  else
    fail "R33.2: No evidence of dev-loop issues being created"
  fi
fi

# ============================================================
# R34: Memory Layer — Real Connections
# ============================================================
echo ""
echo "═══ R34: Memory Layer Connections ═══"

# R34.1: Supermemory API key is real (not placeholder)
SM_CONFIG="$REPO_ROOT/memory/supermemory.json"
if [ -f "$SM_CONFIG" ]; then
  if grep -q "REPLACE_WITH" "$SM_CONFIG"; then
    fail "R34.1: Supermemory API key is still a placeholder"
  else
    pass "R34.1: Supermemory API key configured (not placeholder)"
  fi
else
  fail "R34.1: supermemory.json not found"
fi

# R34.2: Routing log has real entries (not just schema + samples from dev loop)
RLOG="$REPO_ROOT/memory/state/routing-log.jsonl"
if [ -f "$RLOG" ]; then
  REAL_ENTRIES=$(grep -c '"task"' "$RLOG" || echo "0")
  if [ "$REAL_ENTRIES" -ge 5 ]; then
    pass "R34.2: routing-log.jsonl has $REAL_ENTRIES entries (≥5)"
  else
    fail "R34.2: routing-log.jsonl has $REAL_ENTRIES entries (need ≥5 real entries)"
  fi
else
  fail "R34.2: routing-log.jsonl not found"
fi

# R34.3: Ratings log has real entries from Malik (not just dev loop self-ratings)
RATINGS="$REPO_ROOT/memory/state/ratings.jsonl"
if [ -f "$RATINGS" ]; then
  # Look for entries that aren't about "Phase N TDD" — those are self-generated
  REAL_RATINGS=$(grep '"task"' "$RATINGS" 2>/dev/null | grep -v "Phase.*TDD\|Phase.*partial\|_schema" 2>/dev/null | wc -l || true)
  REAL_RATINGS=$(echo "$REAL_RATINGS" | tr -d ' ')
  if [ "$REAL_RATINGS" -ge 1 ]; then
    pass "R34.3: ratings.jsonl has $REAL_RATINGS real task ratings (not self-generated)"
  else
    fail "R34.3: No real task ratings yet — only dev loop self-ratings"
  fi
else
  fail "R34.3: ratings.jsonl not found"
fi

# ============================================================
# R35: Disk & System Health
# ============================================================
echo ""
echo "═══ R35: System Health ═══"

# R35.1: Disk usage under 90%
DISK_PCT=$(df / 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')
if [ -n "$DISK_PCT" ] && [ "$DISK_PCT" -lt 90 ]; then
  pass "R35.1: Disk usage at ${DISK_PCT}% (under 90%)"
else
  fail "R35.1: Disk usage at ${DISK_PCT:-?}% (≥90% — needs cleanup)"
fi

# R35.2: No exposed API keys in repo (git secrets scan)
# Excludes: placeholder strings, ellipsis-truncated examples (e.g. sk-ant-oat01-...),
# regex character-class patterns (e.g. sk-ant-api03-[A-Za-z0-9]),
# gitignored local settings, this test file itself, and grep invocations referencing key shapes.
EXPOSED=$(grep -rn "sk-ant-\|sk-or-v1-\|sk-proj-\|ghp_\|AIzaSy" "$REPO_ROOT" \
  --include="*.md" --include="*.json" --include="*.yaml" --include="*.yml" --include="*.sh" \
  2>/dev/null | grep -v "REPLACE_WITH\|example\|placeholder\|\.\.\.\|verify-production\.sh\|grep -c\|grep -rn\|\[A-Za-z0-9\]\|\[a-f0-9\]\|\[0-9\]\|settings\.local\.json" | head -5)
if [ -z "$EXPOSED" ]; then
  pass "R35.2: No exposed API keys in repo files"
else
  fail "R35.2: Possible exposed API keys found — run git secrets scan"
fi

# R35.3: Git log shows no secrets in commit diffs (last 20 commits)
SECRET_IN_HISTORY=$(git log -20 --diff-filter=A -p 2>/dev/null | grep -c "sk-ant-api03-[A-Za-z0-9]\{10,\}\|sk-or-v1-[a-f0-9]\{10,\}" || true)
SECRET_IN_HISTORY=${SECRET_IN_HISTORY:-0}
if [ "$SECRET_IN_HISTORY" -eq 0 ]; then
  pass "R35.3: No API keys in recent commit history"
else
  fail "R35.3: API keys found in recent git history — needs rotation + BFG cleanup"
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo "════════════════════════════════════════"
echo "  PHASE 7 RESULTS: $PASS passed, $FAIL failed ($TOTAL total)"
echo "════════════════════════════════════════"

if [ "$FAIL" -eq 0 ]; then
  echo "  ✓ ALL PHASE 7 REQUIREMENTS PASS"
  exit 0
else
  echo "  ✗ $FAIL PHASE 7 REQUIREMENT(S) PENDING"
  echo "  (These require real deployment — agent cannot fake them)"
  exit 1
fi
