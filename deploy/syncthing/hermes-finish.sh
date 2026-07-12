#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════
# Syncthing-behind-Traefik — VPS2 / hermes SIDE FINISH
# ═══════════════════════════════════════════════════════════════════════
# Run ON hermes (this box, 187.124.45.132), as root. Single-paste safe.
# Traefik + router for sync2.centaurion.me are ALREADY done — this only does
# the two remaining hermes-side items:
#   1. set the Syncthing GUI password (currently open on 0.0.0.0:8384) 🔴
#   2. add VPS1 as a peer + create/share the 3 wiki folders (mirror of VPS1)
#
# Sharing is directional per host, so this must run in addition to vps1-setup.sh.
# Idempotent + re-runnable.
# ═══════════════════════════════════════════════════════════════════════
set -uo pipefail

# ─── EDIT THESE ─────────────────────────────────────────────────────────
ST_GUI_USER="malik"                 # <<< Syncthing GUI username for hermes
ST_GUI_PASS="CHANGE_ME_STRONG_PW"   # <<< strong GUI password (stored bcrypt-hashed)

# VPS1's device ID — printed at the end of vps1-setup.sh. Add a 3rd device
# (laptop/phone) to this space-separated list if you have one.
PEER_DEVICE_IDS="PASTE_VPS1_DEVICE_ID_HERE"

WIKI_BASE="$HOME/Centaurion/docs"
WIKIS=(aob-wiki builderbee-wiki centaurion-wiki)
# ────────────────────────────────────────────────────────────────────────

say(){ echo "▸ $*"; }; ok(){ echo "  ✓ $*"; }; warn(){ echo "  ⚠ $*"; }
die(){ echo "✗ $*" >&2; exit 1; }
[ "$(id -u)" -eq 0 ] || die "run as root (owns the Syncthing config)"

CFG="/root/.local/state/syncthing/config.xml"
[ -f "$CFG" ] || CFG="/root/.config/syncthing/config.xml"
[ -f "$CFG" ] || die "Syncthing config not found"
API=$(sed -n 's:.*<apikey>\(.*\)</apikey>.*:\1:p' "$CFG" | head -1)
[ -n "$API" ] || die "could not read apikey from $CFG"
ok "hermes device ID: $(syncthing --device-id 2>/dev/null)"

# ─── 1. GUI password ────────────────────────────────────────────────────
say "Setting Syncthing GUI auth"
if [ "$ST_GUI_PASS" = "CHANGE_ME_STRONG_PW" ]; then
  warn "ST_GUI_PASS still default — SKIPPING. Edit the script and re-run."
else
  syncthing cli --gui-address 127.0.0.1:8384 --gui-apikey "$API" config gui user set "$ST_GUI_USER"
  syncthing cli --gui-address 127.0.0.1:8384 --gui-apikey "$API" config gui password set "$ST_GUI_PASS" \
    && ok "GUI auth set for '$ST_GUI_USER'"
fi

# ─── 2. Peer + wiki folders ─────────────────────────────────────────────
if [ "$PEER_DEVICE_IDS" = "PASTE_VPS1_DEVICE_ID_HERE" ]; then
  warn "PEER_DEVICE_IDS not set — SKIPPING peer/folder step."
  warn "Run vps1-setup.sh on VPS1 first, copy its printed device ID in here, re-run."
else
  say "Pairing peers + wiki folders"
  for DID in $PEER_DEVICE_IDS; do
    syncthing cli --gui-address 127.0.0.1:8384 --gui-apikey "$API" config devices add --device-id "$DID" 2>/dev/null \
      && ok "peer added: ${DID:0:7}…" || ok "peer ${DID:0:7}… already present"
  done
  for f in "${WIKIS[@]}"; do
    mkdir -p "$WIKI_BASE/$f"
    syncthing cli --gui-address 127.0.0.1:8384 --gui-apikey "$API" config folders add \
      --id "$f" --label "$f" --path "$WIKI_BASE/$f" 2>/dev/null \
      && ok "folder $f created" || ok "folder $f already present"
    for DID in $PEER_DEVICE_IDS; do
      syncthing cli --gui-address 127.0.0.1:8384 --gui-apikey "$API" config folders "$f" devices add --device-id "$DID" 2>/dev/null || true
    done
    ok "folder $f shared to peer(s)"
  done
fi

echo ""
echo "═══ hermes side complete ═══"
echo "Verify once DNS + VPS1 are up:"
echo "  curl -sI https://sync2.centaurion.me | head -1     # expect TLS (200/401)"
echo "  echo probe >> $WIKI_BASE/centaurion-wiki/.synctest # then check it on VPS1"
