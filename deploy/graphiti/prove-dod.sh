#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════
# Centaurion — Phase 10 DoD PROOF (Ontraport temporal query)
# ═══════════════════════════════════════════════════════════
#
# Proves the Phase 10 Definition of Done END-TO-END against a REAL Neo4j:
#   an agent answers "When did we decide to migrate from Ontraport?"
#   from a temporal knowledge graph.
#
# SAFETY — this NEVER touches the shared live `neo4j` container on this host
# (ports 7474/7687, possibly used by Hermes). It spins up its OWN disposable
# Neo4j on DIFFERENT ports (7475/7688), uses it, and tears it down. The trap
# guarantees teardown even on failure or Ctrl-C.
#
# It is LLM-FREE: Graphiti needs an LLM key to auto-EXTRACT decision records
# from raw conversation text. Here we hand-load already-structured records
# (the shape the MemPalace miner emits) to prove the temporal-graph mechanism
# WITHOUT a key. The only gap to "live" is adding an LLM key. See prove-dod.md.
#
# Usage:
#   bash deploy/graphiti/prove-dod.sh
#
# Requires: docker, python3. The neo4j Python driver is installed into a
# THROWAWAY venv (/tmp/neo4jv) — never added to repo requirements.
# ═══════════════════════════════════════════════════════════

set -euo pipefail

# ── Config (deliberately NON-default ports to avoid the shared neo4j) ──
CONTAINER="neo4j-dod-test"
HTTP_PORT="7475"   # shared neo4j uses 7474 — we use 7475
BOLT_PORT="7688"   # shared neo4j uses 7687 — we use 7688
NEO4J_USER="neo4j"
NEO4J_PASS="testpassword123"
VENV="/tmp/neo4jv"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Teardown trap — runs on ANY exit (success, failure, signal) ──
cleanup() {
  local rc=$?
  echo ""
  echo "── TEARDOWN ──────────────────────────────────────────────"
  docker rm -f "$CONTAINER" >/dev/null 2>&1 && echo "OK Removed container '$CONTAINER'." \
    || echo "  (container '$CONTAINER' already gone)"
  if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx "$CONTAINER"; then
    echo "FAIL container '$CONTAINER' still present!"
  else
    echo "OK Verified: no '$CONTAINER' in 'docker ps -a'."
  fi
  exit "$rc"
}
trap cleanup EXIT INT TERM

echo "═══ Phase 10 DoD proof — ephemeral Neo4j (NOT the shared one) ═══"

# ── Guard: refuse to collide with the shared neo4j ports ──
if [ "$HTTP_PORT" = "7474" ] || [ "$BOLT_PORT" = "7687" ]; then
  echo "FAIL refusing to use the shared neo4j ports (7474/7687). Aborting."
  exit 1
fi

# ── Guard: bail if a stale test container is lingering ──
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true

# ── 1. Start an EPHEMERAL Neo4j (--rm) on our own ports ──
echo ""
echo "── 1. START ephemeral Neo4j ($CONTAINER) on :$HTTP_PORT / :$BOLT_PORT ──"
docker run -d --rm \
  --name "$CONTAINER" \
  -p "${HTTP_PORT}:7474" \
  -p "${BOLT_PORT}:7687" \
  -e NEO4J_AUTH="${NEO4J_USER}/${NEO4J_PASS}" \
  neo4j:5 >/dev/null
echo "OK Container started. Waiting for HTTP :$HTTP_PORT to answer ..."

# ── Poll HTTP until ready (Neo4j 5 takes ~20-40s to boot) ──
READY=0
for i in $(seq 1 60); do
  CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "http://localhost:${HTTP_PORT}" 2>/dev/null || echo "000")
  if [ "$CODE" = "200" ]; then
    READY=1
    echo "OK Neo4j HTTP ready after ~$((i*2))s (HTTP $CODE)."
    break
  fi
  sleep 2
done
if [ "$READY" -ne 1 ]; then
  echo "FAIL Neo4j did not become ready in time. Container logs:"
  docker logs "$CONTAINER" 2>&1 | tail -20
  exit 1
fi
# Bolt needs a couple extra seconds after HTTP is up.
sleep 4

# ── 2. Throwaway venv with the neo4j driver (NOT in repo requirements) ──
echo ""
echo "── 2. THROWAWAY venv + neo4j driver ($VENV) ──"
if [ ! -x "$VENV/bin/python" ]; then
  python3 -m venv "$VENV"
fi
"$VENV/bin/pip" install --quiet --disable-pip-version-check neo4j
echo "OK neo4j driver installed in throwaway venv."

# ── 3. Load temporal records + run the DoD query ──
echo ""
echo "── 3. LOAD records + RUN DoD query ──"
"$VENV/bin/python" "$HERE/load_and_query.py" \
  --uri "bolt://localhost:${BOLT_PORT}" \
  --user "$NEO4J_USER" \
  --password "$NEO4J_PASS"

echo ""
echo "═══ DoD PROVEN. Tearing down (trap) ═══"
# Teardown happens in the EXIT trap.
