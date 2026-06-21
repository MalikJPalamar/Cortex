#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════
# Centaurion — Graphiti LIVE activation (one command, phone-runnable)
# ═══════════════════════════════════════════════════════════
#
# This is the "flip the memory layer ON" switch. It does, in order:
#   1. (optional) writes the keys you pass into the host .env (chmod 600).
#   2. confirms the live Neo4j password (from .env, or read from the running
#      neo4j container's NEO4J_AUTH if you didn't set one).
#   3. installs graphiti-core into a DEDICATED venv (never repo requirements).
#   4. feeds the live Neo4j a raw episode, lets the LLM auto-extract the
#      Ontraport decision, and runs the Phase 10 DoD query to prove it answers.
#
# ── PHONE-NATIVE USAGE — paste ONE of these ──
#
#   # If you already put the keys in /root/Centaurion/.env, just run:
#   bash deploy/graphiti/activate-graphiti.sh
#
#   # Or pass the keys inline (they get written to .env, 600 perms, then used):
#   bash deploy/graphiti/activate-graphiti.sh \
#       --openai-key 'sk-...' \
#       --neo4j-password 'the-neo4j-password'
#
#   # Anthropic instead of OpenAI for extraction (still needs --openai-key for
#   # embeddings — Anthropic has no embeddings API):
#   bash deploy/graphiti/activate-graphiti.sh \
#       --anthropic-key 'sk-ant-...' --openai-key 'sk-...' --provider anthropic
#
# SAFETY: writes only to the activation-probe namespace in the graph; deletes
# nothing. Secrets go to .env (gitignored, 600) — never to git, never echoed.
# ═══════════════════════════════════════════════════════════

set -euo pipefail

ENV_FILE="${CENTAURION_ENV_FILE:-/root/Centaurion/.env}"
VENV="${GRAPHITI_VENV:-/root/.venvs/graphiti}"
NEO4J_CONTAINER="${NEO4J_CONTAINER:-neo4j}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROVIDER="openai"
OPENAI_KEY=""
ANTHROPIC_KEY=""
NEO4J_PW_ARG=""

# ── Parse args ──
while [ $# -gt 0 ]; do
  case "$1" in
    --openai-key)      OPENAI_KEY="$2"; shift 2 ;;
    --anthropic-key)   ANTHROPIC_KEY="$2"; shift 2 ;;
    --neo4j-password)  NEO4J_PW_ARG="$2"; shift 2 ;;
    --provider)        PROVIDER="$2"; shift 2 ;;
    -h|--help)         sed -n '2,40p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

# ── Helper: upsert KEY=VALUE into the .env without duplicating ──
set_env() {
  local key="$1" val="$2"
  [ -z "$val" ] && return 0
  touch "$ENV_FILE"; chmod 600 "$ENV_FILE"
  if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
    # Replace in place (use a tmp file; value may contain slashes).
    grep -v "^${key}=" "$ENV_FILE" > "${ENV_FILE}.tmp" || true
    printf '%s=%s\n' "$key" "$val" >> "${ENV_FILE}.tmp"
    mv "${ENV_FILE}.tmp" "$ENV_FILE"; chmod 600 "$ENV_FILE"
  else
    printf '%s=%s\n' "$key" "$val" >> "$ENV_FILE"
  fi
  echo "OK  wrote ${key} to ${ENV_FILE} (perms 600, gitignored)"
}

echo "═══ Graphiti LIVE activation ═══"

# ── 1. Persist any keys passed inline ──
set_env "OPENAI_API_KEY"    "$OPENAI_KEY"
set_env "ANTHROPIC_API_KEY" "$ANTHROPIC_KEY"
set_env "NEO4J_PASSWORD"    "$NEO4J_PW_ARG"

# ── 2. Load host .env so its keys reach the verifier ──
if [ -f "$ENV_FILE" ]; then
  set -a; . "$ENV_FILE"; set +a
  echo "OK  loaded $ENV_FILE"
else
  echo "WARN  $ENV_FILE not found — relying on inherited environment."
fi

# ── 3. Resolve the live Neo4j password (fall back to the container's auth) ──
if [ -z "${NEO4J_PASSWORD:-}" ]; then
  echo "──  NEO4J_PASSWORD not in .env; trying the running '${NEO4J_CONTAINER}' container ..."
  AUTH="$(docker inspect "$NEO4J_CONTAINER" \
            --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null \
            | grep '^NEO4J_AUTH=' | head -1 | cut -d= -f2- || true)"
  if [ -n "$AUTH" ] && [ "$AUTH" != "none" ]; then
    NEO4J_PASSWORD="${AUTH#*/}"   # strip "neo4j/" prefix
    export NEO4J_PASSWORD
    echo "OK  recovered Neo4j password from the live container's NEO4J_AUTH."
  else
    echo "FAIL  No NEO4J_PASSWORD in .env and could not read it from the container."
    echo "      Re-run with: --neo4j-password 'your-neo4j-password'"
    exit 1
  fi
fi

# ── 4. Guard: an LLM key must be present ──
if [ "$PROVIDER" = "openai" ] && [ -z "${OPENAI_API_KEY:-}" ]; then
  echo "FAIL  provider=openai but OPENAI_API_KEY is unset."
  echo "      Re-run with: --openai-key 'sk-...'"
  exit 1
fi
if [ "$PROVIDER" = "anthropic" ] && { [ -z "${ANTHROPIC_API_KEY:-}" ] || [ -z "${OPENAI_API_KEY:-}" ]; }; then
  echo "FAIL  provider=anthropic needs BOTH --anthropic-key (extraction) and"
  echo "      --openai-key (embeddings — Anthropic has no embeddings API)."
  exit 1
fi

# ── 5. Dedicated venv with graphiti-core (NOT in repo requirements) ──
echo "──  Installing graphiti-core into $VENV (first run takes a minute) ..."
if [ ! -x "$VENV/bin/python" ]; then
  python3 -m venv "$VENV"
fi
"$VENV/bin/pip" install --quiet --disable-pip-version-check --upgrade pip
"$VENV/bin/pip" install --quiet --disable-pip-version-check graphiti-core
echo "OK  graphiti-core installed."

# ── 6. Activate + verify against the live graph ──
echo "──  Running activation + DoD verification ..."
GRAPHITI_LLM_PROVIDER="$PROVIDER" \
"$VENV/bin/python" "$HERE/activate_and_verify.py" \
  --uri "${NEO4J_URI:-bolt://localhost:7687}" \
  --user "${NEO4J_USER:-neo4j}" \
  --password "$NEO4J_PASSWORD" \
  --llm-provider "$PROVIDER"
RC=$?

echo ""
if [ "$RC" -eq 0 ]; then
  echo "═══ DONE. Graphiti is live — the memory layer auto-extracts now. ═══"
  echo "    Next: point the MCP server / dev loop at it (deploy/graphiti/mcp.json)."
  echo "    Flip memory/graphiti.json status scaffolded → connected on the next commit."
else
  echo "═══ Activation hit an error (rc=$RC). Keys are saved; fix + re-run. ═══"
fi
exit "$RC"
