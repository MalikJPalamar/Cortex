#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════
# Centaurion — Syncthing Install (PT-7a)
# ═══════════════════════════════════════════════════════════
#
# Idempotent install of Syncthing on a Debian/Ubuntu host.
# Installs from the official Syncthing apt repo, enables the
# per-user systemd service, starts it, and prints this host's
# device ID + the next step.
#
# Run on EACH host (VPS1 187.124.45.132 and VPS2 srv1514399).
# Run as the user that owns ~/Centaurion (a real login user with
# a home dir, not a system account) — the per-user service syncs
# that user's files.
#
# Usage:
#   cd ~/Centaurion && bash deploy/syncthing/install.sh
#
# Safe to re-run: every step is guarded.
# ═══════════════════════════════════════════════════════════

set -uo pipefail

KEYRING="/usr/share/keyrings/syncthing-archive-keyring.gpg"
LIST="/etc/apt/sources.list.d/syncthing.list"
SVC_USER="${SUDO_USER:-$USER}"

say()  { echo "▸ $*"; }
ok()   { echo "  ✓ $*"; }
warn() { echo "  ⚠ $*"; }

# sudo wrapper — works whether or not we're already root
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "✗ Need root (or sudo) to install packages. Re-run as root or install sudo." >&2
    exit 1
  fi
fi

echo "═══ Syncthing Install — $(hostname) ═══"
echo "Service user: $SVC_USER"
echo ""

# ── Step 1: apt repo + key (idempotent) ─────────────────────
say "Step 1: Syncthing apt repository"
if command -v syncthing >/dev/null 2>&1; then
  ok "syncthing already installed ($(syncthing --version 2>/dev/null | head -1)) — skipping repo + install"
else
  if [ ! -f "$KEYRING" ]; then
    $SUDO mkdir -p "$(dirname "$KEYRING")"
    if curl -fsSL https://syncthing.net/release-key.gpg | $SUDO tee "$KEYRING" >/dev/null; then
      ok "Release key installed → $KEYRING"
    else
      echo "  ✗ Failed to fetch Syncthing release key (no network?)." >&2
      exit 1
    fi
  else
    ok "Release key already present"
  fi

  if [ ! -f "$LIST" ]; then
    echo "deb [signed-by=$KEYRING] https://apt.syncthing.net/ syncthing stable" \
      | $SUDO tee "$LIST" >/dev/null
    ok "apt source added → $LIST"
  else
    ok "apt source already present"
  fi

  # ── Step 2: install package ──────────────────────────────
  say "Step 2: apt-get install syncthing"
  $SUDO apt-get update -qq
  if $SUDO apt-get install -y -qq syncthing; then
    ok "Installed $(syncthing --version 2>/dev/null | head -1)"
  else
    echo "  ✗ apt-get install syncthing failed." >&2
    exit 1
  fi
fi

# ── Step 3: generate config (so a device ID exists) ─────────
say "Step 3: Initialise config / device identity"
# `syncthing generate` creates the config + TLS keys for $SVC_USER if absent.
# It is a no-op if the config already exists.
if [ "$SVC_USER" != "$USER" ] && command -v runuser >/dev/null 2>&1; then
  $SUDO runuser -u "$SVC_USER" -- syncthing generate >/dev/null 2>&1 || true
else
  syncthing generate >/dev/null 2>&1 || true
fi
ok "Config initialised (existing config left untouched)"

# ── Step 4: enable + start per-user systemd service ─────────
say "Step 4: Enable systemd user service (syncthing@$SVC_USER)"
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
  # Allow the user service to run without an active login session.
  $SUDO loginctl enable-linger "$SVC_USER" 2>/dev/null \
    && ok "Lingering enabled for $SVC_USER" \
    || warn "Could not enable lingering (service may stop on logout)"

  if $SUDO systemctl enable --now "syncthing@${SVC_USER}.service" 2>/dev/null; then
    ok "Service enabled + started"
  else
    warn "systemctl enable --now failed — start manually with:"
    echo "      systemctl enable --now syncthing@${SVC_USER}.service"
  fi

  # Give the daemon a moment to come up before we query it.
  for _ in 1 2 3 4 5; do
    systemctl is-active --quiet "syncthing@${SVC_USER}.service" && break
    sleep 1
  done
else
  warn "systemd not available (container without systemd?)."
  echo "      Run Syncthing manually:  syncthing serve --no-browser &"
fi

# ── Step 5: print device ID + next step ─────────────────────
echo ""
say "Step 5: This host's device ID"
DEVICE_ID=""
if [ "$SVC_USER" != "$USER" ] && command -v runuser >/dev/null 2>&1; then
  DEVICE_ID=$($SUDO runuser -u "$SVC_USER" -- syncthing --device-id 2>/dev/null)
else
  DEVICE_ID=$(syncthing --device-id 2>/dev/null)
fi

if [ -n "$DEVICE_ID" ]; then
  echo ""
  echo "    ┌──────────────────────────────────────────────────────────┐"
  echo "    │ DEVICE ID ($(hostname)):"
  echo "    │   $DEVICE_ID"
  echo "    └──────────────────────────────────────────────────────────┘"
else
  warn "Could not read device ID yet. Once the service is up, run:"
  echo "      syncthing --device-id"
fi

echo ""
echo "═══ Done ═══"
echo ""
echo "NEXT STEPS (see deploy/syncthing/README.md → RUNBOOK):"
echo "  1. Run this same script on the OTHER host."
echo "  2. Copy each host's device ID above."
echo "  3. On BOTH hosts: add the other device (README Step 3)."
echo "  4. Share the 'centaurion-wiki' folder = ~/Centaurion/docs"
echo "     as Send & Receive (README Steps 4-6; see folder-config.md)."
echo "  5. Verify:  bash deploy/syncthing/verify.sh"
echo ""
echo "Web GUI (local only):  http://127.0.0.1:8384"
echo "  Tunnel from laptop:  ssh -L 8384:127.0.0.1:8384 ${SVC_USER}@$(hostname)"
