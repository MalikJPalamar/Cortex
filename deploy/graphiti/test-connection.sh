#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════
# Centaurion — Graphiti / Neo4j Connection Test (Phase 10)
# ═══════════════════════════════════════════════════════════
#
# READ-ONLY reachability check for the Neo4j that backs the
# Graphiti temporal knowledge graph. It NEVER writes to the
# graph, never installs anything, and never mutates state.
#
# It reports:
#   1. Whether the `neo4j` Docker container is running
#   2. Whether the HTTP endpoint (:7474) answers + version/edition
#   3. Whether the Bolt port (:7687) is open
#   4. Whether the activation secrets are present in the env
#      (NEO4J_PASSWORD, GRAPHITI_LLM_API_KEY) — names only, never values
#
# Degrades gracefully: missing tools / container / creds produce
# a warning and a hint, never a hard crash. Exit 0 = ready or
# Neo4j-reachable; exit 1 = Neo4j unreachable / action needed.
#
# Usage:
#   bash deploy/graphiti/test-connection.sh
#   # optional: load host secrets first to also check the keys
#   set -a; . /root/Centaurion/.env; set +a
#   bash deploy/graphiti/test-connection.sh
# ═══════════════════════════════════════════════════════════

set -uo pipefail

HTTP_URL="${NEO4J_HTTP_URL:-http://localhost:7474}"
BOLT_HOST="${NEO4J_BOLT_HOST:-localhost}"
BOLT_PORT="${NEO4J_BOLT_PORT:-7687}"
CONTAINER="${NEO4J_CONTAINER:-neo4j}"
RC=0

echo "═══ Graphiti / Neo4j Connection Test — $(hostname) ═══"

# ── 1. Docker container ─────────────────────────────────────
if command -v docker >/dev/null 2>&1; then
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$CONTAINER"; then
    LINE=$(docker ps --filter "name=^${CONTAINER}$" --format '{{.Image}} | {{.Status}} | {{.Ports}}' 2>/dev/null | head -1)
    echo "✓ Container '${CONTAINER}' running: ${LINE}"
  else
    echo "✗ Container '${CONTAINER}' not in 'docker ps'."
    echo "  → It should already be up on this host. Check: docker ps -a | grep ${CONTAINER}"
    RC=1
  fi
else
  echo "⚠ docker not available on PATH — skipping container check."
fi

# ── 2. HTTP endpoint (:7474) ────────────────────────────────
if command -v curl >/dev/null 2>&1; then
  CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$HTTP_URL" 2>/dev/null || echo "000")
  if [ "$CODE" = "200" ]; then
    echo "✓ HTTP ${HTTP_URL} → 200"
    BODY=$(curl -s --max-time 5 "$HTTP_URL" 2>/dev/null || true)
    if [ -n "$BODY" ] && command -v python3 >/dev/null 2>&1; then
      echo "$BODY" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
v = d.get("neo4j_version", "?"); e = d.get("neo4j_edition", "?")
print(f"  • Neo4j {v} ({e})")
print(f"  • bolt_direct: {d.get(\"bolt_direct\",\"?\")}")
' 2>/dev/null || true
    fi
  else
    echo "✗ HTTP ${HTTP_URL} → ${CODE} (expected 200)."
    echo "  → Neo4j HTTP not reachable. Check the container and port mapping."
    RC=1
  fi
else
  echo "⚠ curl not available — skipping HTTP check."
fi

# ── 3. Bolt port (:7687) ────────────────────────────────────
BOLT_OK=0
if command -v bash >/dev/null 2>&1 && (exec 3<>"/dev/tcp/${BOLT_HOST}/${BOLT_PORT}") 2>/dev/null; then
  exec 3>&- 2>/dev/null || true
  BOLT_OK=1
fi
if [ "$BOLT_OK" -eq 1 ]; then
  echo "✓ Bolt port ${BOLT_HOST}:${BOLT_PORT} open"
else
  # fall back to nc if /dev/tcp is unavailable
  if command -v nc >/dev/null 2>&1 && nc -z -w3 "$BOLT_HOST" "$BOLT_PORT" 2>/dev/null; then
    echo "✓ Bolt port ${BOLT_HOST}:${BOLT_PORT} open"
  else
    echo "⚠ Bolt port ${BOLT_HOST}:${BOLT_PORT} not confirmed open (driver/socket check skipped)."
  fi
fi

# ── 4. Activation secrets (names only, never values) ────────
echo ""
echo "── Activation secrets (env) ──"
if [ -n "${NEO4J_PASSWORD:-}" ]; then
  echo "✓ NEO4J_PASSWORD is set"
else
  echo "✗ NEO4J_PASSWORD not in env"
  echo "  → set -a; . /root/Centaurion/.env; set +a   (after adding it; see README)"
  RC=1
fi
if [ -n "${GRAPHITI_LLM_API_KEY:-}" ] || [ -n "${OPENAI_API_KEY:-}" ] || [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  echo "✓ LLM key present (GRAPHITI_LLM_API_KEY / OPENAI_API_KEY / ANTHROPIC_API_KEY)"
else
  echo "✗ No LLM key in env — Graphiti cannot extract entities without one."
  echo "  → Add GRAPHITI_LLM_API_KEY (maps to OPENAI_API_KEY or ANTHROPIC_API_KEY). See README."
  RC=1
fi

echo ""
if [ "$RC" -eq 0 ]; then
  echo "═══ READY — Neo4j reachable + secrets present ═══"
else
  echo "═══ Neo4j reachable but action needed (see ✗ above + README) ═══"
  echo "    (Neo4j itself being live is enough to scaffold; the keys gate activation.)"
fi
exit "$RC"
