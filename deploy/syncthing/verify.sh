#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════
# Centaurion — Syncthing Verify (PT-7a)
# ═══════════════════════════════════════════════════════════
#
# Read-only status check. Reports whether Syncthing is installed
# and running, prints this host's device ID, and (if reachable)
# the configured folders + connected devices.
#
# Degrades gracefully: never installs, never mutates, never fails
# the shell hard — exits 0 if healthy, 1 if absent/not running,
# so it's safe to call from cron / health checks.
#
# Usage:
#   bash deploy/syncthing/verify.sh
# ═══════════════════════════════════════════════════════════

set -uo pipefail

SVC_USER="${SUDO_USER:-$USER}"
RC=0

echo "═══ Syncthing Verify — $(hostname) ═══"

# ── Installed? ──────────────────────────────────────────────
if command -v syncthing >/dev/null 2>&1; then
  echo "✓ Installed: $(syncthing --version 2>/dev/null | head -1)"
else
  echo "✗ Not installed."
  echo "  → Run: bash deploy/syncthing/install.sh"
  exit 1
fi

# ── Device ID ───────────────────────────────────────────────
DEVICE_ID=$(syncthing --device-id 2>/dev/null || true)
if [ -n "$DEVICE_ID" ]; then
  echo "✓ Device ID: $DEVICE_ID"
else
  echo "⚠ Could not read device ID (config not yet generated?)."
  RC=1
fi

# ── Running? ────────────────────────────────────────────────
RUNNING=0
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
  if systemctl is-active --quiet "syncthing@${SVC_USER}.service" 2>/dev/null; then
    echo "✓ Service active: syncthing@${SVC_USER}.service"
    RUNNING=1
  else
    echo "✗ Service NOT active: syncthing@${SVC_USER}.service"
    echo "  → Start: systemctl enable --now syncthing@${SVC_USER}.service"
    RC=1
  fi
elif pgrep -x syncthing >/dev/null 2>&1; then
  echo "✓ syncthing process running (non-systemd)"
  RUNNING=1
else
  echo "✗ syncthing not running."
  echo "  → Start: syncthing serve --no-browser &"
  RC=1
fi

# ── Folders + connections (best-effort via API) ─────────────
if [ "$RUNNING" -eq 1 ]; then
  CFG=""
  for c in "$HOME/.local/state/syncthing/config.xml" "$HOME/.config/syncthing/config.xml"; do
    [ -f "$c" ] && CFG="$c" && break
  done

  if [ -n "$CFG" ]; then
    echo ""
    echo "── Configured folders ──"
    grep -oE '<folder id="[^"]+"[^>]*path="[^"]+"' "$CFG" 2>/dev/null \
      | sed -E 's/.*id="([^"]+)".*path="([^"]+)".*/  • \1  →  \2/' \
      || echo "  (none configured yet)"
    grep -q 'id="centaurion-wiki"' "$CFG" 2>/dev/null \
      && echo "  ✓ centaurion-wiki folder present" \
      || echo "  ⚠ centaurion-wiki folder NOT configured (see folder-config.md)"

    # Live status via REST API if curl + apikey available
    API_KEY=$(sed -n 's:.*<apikey>\(.*\)</apikey>.*:\1:p' "$CFG" 2>/dev/null | head -1)
    if [ -n "$API_KEY" ] && command -v curl >/dev/null 2>&1; then
      echo ""
      echo "── Connections (live) ──"
      CONN=$(curl -fsS -H "X-API-Key: $API_KEY" \
             http://127.0.0.1:8384/rest/system/connections 2>/dev/null || true)
      if [ -n "$CONN" ]; then
        if command -v python3 >/dev/null 2>&1; then
          echo "$CONN" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin).get("connections", {})
except Exception:
    sys.exit(0)
if not d:
    print("  (no remote devices configured)")
for dev, info in d.items():
    state = "connected" if info.get("connected") else "disconnected"
    print(f"  • {dev[:7]}…  {state}  {info.get(\"address\",\"\")}")
' 2>/dev/null || echo "  (could not parse connection JSON)"
        else
          echo "  (install python3 for a parsed view; raw API reachable)"
        fi
      else
        echo "  (API not reachable on 127.0.0.1:8384 yet)"
      fi
    fi
  else
    echo ""
    echo "⚠ No config.xml found — run install.sh / 'syncthing generate' first."
    RC=1
  fi
fi

echo ""
if [ "$RC" -eq 0 ]; then
  echo "═══ OK ═══"
else
  echo "═══ Action needed (see above + README RUNBOOK) ═══"
fi
exit "$RC"
