#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════
# Syncthing-behind-Traefik — VPS1 (srv940848 / 148.230.117.105) setup
# ═══════════════════════════════════════════════════════════════════════
# Run this ON VPS1, as root (the Syncthing config owner). Single-paste safe.
# It mirrors what was already done on VPS2/hermes (see VPS2-BUILD-REPORT.md).
#
#   1. auto-discovers VPS1's Traefik compose dir + network mode
#   2. writes the Traefik file-provider router for sync1.centaurion.me
#   3. idempotently patches Traefik's docker-compose.yml (file provider + mount)
#   4. recreates Traefik and sets a GUI password on VPS1's Syncthing
#   5. pairs hermes as a peer + creates/shares the 3 wiki folders
#
# Safe to re-run: every step is guarded; the compose file is backed up first.
# ═══════════════════════════════════════════════════════════════════════
set -uo pipefail

# ─── EDIT THESE (only the ones marked <<<) ──────────────────────────────
ST_GUI_USER="malik"                 # <<< Syncthing GUI username for VPS1
ST_GUI_PASS="CHANGE_ME_STRONG_PW"   # <<< strong GUI password (stored bcrypt-hashed)

# hermes/VPS2 device ID is pre-filled. If you have a 3rd device (laptop/phone),
# add its ID to this space-separated list.
PEER_DEVICE_IDS="CDVP4FC-AFOKCVZ-JYL5DDS-F4ZMXQB-BDGDG62-6NGTU77-G4NJ3DO-4X6RPAX"

# Leave blank to auto-discover. Override only if discovery fails.
TRAEFIK_WORKDIR=""                  # e.g. /docker/traefik  (auto if blank)
SYNC_URL=""                         # e.g. http://127.0.0.1:8384 (auto if blank)

SUBDOMAIN="sync1.centaurion.me"
WIKI_BASE="$HOME/Centaurion/docs"
WIKIS=(aob-wiki builderbee-wiki centaurion-wiki)
CERT_RESOLVER="letsencrypt"         # match VPS1's existing certresolver name
ENTRYPOINT="websecure"              # match VPS1's existing TLS entrypoint name
# ────────────────────────────────────────────────────────────────────────

say(){ echo "▸ $*"; }; ok(){ echo "  ✓ $*"; }; warn(){ echo "  ⚠ $*"; }
die(){ echo "✗ $*" >&2; exit 1; }
[ "$(id -u)" -eq 0 ] || die "run as root (owns /root/.local/state/syncthing/config.xml)"

# ─── 1. Discover Traefik compose dir + network mode ─────────────────────
say "Discovering VPS1 Traefik"
CID=$(docker ps -q --filter name=traefik | head -1)
[ -n "$CID" ] || die "no running container named *traefik* found on this host"
[ -n "$TRAEFIK_WORKDIR" ] || TRAEFIK_WORKDIR=$(docker inspect "$CID" \
  --format '{{index .Config.Labels "com.docker.compose.project.working_dir"}}')
NETMODE=$(docker inspect "$CID" --format '{{.HostConfig.NetworkMode}}')
COMPOSE="$TRAEFIK_WORKDIR/docker-compose.yml"
[ -f "$COMPOSE" ] || die "compose not found at $COMPOSE — set TRAEFIK_WORKDIR manually"
if [ -z "$SYNC_URL" ]; then
  if [ "$NETMODE" = "host" ]; then SYNC_URL="http://127.0.0.1:8384"
  else SYNC_URL="http://172.17.0.1:8384"; fi   # docker0 bridge gateway
fi
ok "workdir=$TRAEFIK_WORKDIR  netmode=$NETMODE  backend=$SYNC_URL"

# ─── 2. Write the Traefik file-provider router (sync1) ──────────────────
say "Writing $TRAEFIK_WORKDIR/dynamic/syncthing.yml"
mkdir -p "$TRAEFIK_WORKDIR/dynamic"
cat > "$TRAEFIK_WORKDIR/dynamic/syncthing.yml" <<YML
http:
  routers:
    syncthing:
      rule: "Host(\`$SUBDOMAIN\`)"
      service: syncthing
      entryPoints: [$ENTRYPOINT]
      tls:
        certResolver: $CERT_RESOLVER
  services:
    syncthing:
      loadBalancer:
        servers:
          - url: "$SYNC_URL"
YML
ok "router written"

# ─── 3. Patch docker-compose.yml (file provider flags + /dynamic mount) ──
say "Patching $COMPOSE (idempotent; backup kept)"
cp -n "$COMPOSE" "$COMPOSE.bak.pre-syncthing" 2>/dev/null || true
python3 - "$COMPOSE" "$TRAEFIK_WORKDIR" <<'PY'
import re, sys
path, workdir = sys.argv[1], sys.argv[2]
s = open(path).read(); lines = s.splitlines(keepends=True); out = lines[:]
def indent(l): return l[:len(l)-len(l.lstrip())]

# a) command flags — insert after the last "- --providers." line, reuse its indent
if "--providers.file.directory=/dynamic" not in s:
    idxs = [i for i,l in enumerate(out) if re.match(r'\s*- --providers\.', l)]
    if idxs:
        i = idxs[-1]; ind = indent(out[i])
        out[i:i+1] = [out[i],
            f"{ind}- --providers.file.directory=/dynamic\n",
            f"{ind}- --providers.file.watch=true\n"]
    else:
        print("  ! could not find a '- --providers.' line to anchor command flags — add them by hand")

# b) volume mount — insert after docker.sock mount (or after 'volumes:'), reuse indent
s2 = "".join(out)
mount = f"{workdir}/dynamic:/dynamic:ro"
if mount not in s2 and "/dynamic:ro" not in s2:
    sock = [i for i,l in enumerate(out) if re.search(r'-\s*/var/run/docker\.sock', l)]
    if sock:
        i = sock[0]; ind = indent(out[i])
        out[i:i+1] = [out[i], f"{ind}- {mount}\n"]
    else:
        vol = [i for i,l in enumerate(out) if re.match(r'\s*volumes:\s*$', l)]
        if vol:
            i = vol[0]; ind = indent(out[i]) + "  "
            out[i:i+1] = [out[i], f"{ind}- {mount}\n"]
        else:
            print("  ! no volumes: block found — add the /dynamic mount by hand")

open(path,"w").write("".join(out))
print("  ✓ compose patched (or already current)")
PY

# ─── 4. Recreate Traefik ────────────────────────────────────────────────
say "Recreating Traefik to load new command flags + mount"
docker compose -f "$COMPOSE" up -d && ok "traefik recreated" || warn "compose up failed — check $COMPOSE.bak.pre-syncthing"

# ─── 5. Set VPS1 Syncthing GUI password ─────────────────────────────────
say "Setting Syncthing GUI auth"
CFG="/root/.local/state/syncthing/config.xml"
[ -f "$CFG" ] || CFG="/root/.config/syncthing/config.xml"
API=$(sed -n 's:.*<apikey>\(.*\)</apikey>.*:\1:p' "$CFG" | head -1)
[ -n "$API" ] || die "could not read Syncthing apikey from $CFG"
if [ "$ST_GUI_PASS" = "CHANGE_ME_STRONG_PW" ]; then
  warn "ST_GUI_PASS still default — SKIPPING password set. Edit the script and re-run."
else
  syncthing cli --gui-address 127.0.0.1:8384 --gui-apikey "$API" config gui user set "$ST_GUI_USER"
  syncthing cli --gui-address 127.0.0.1:8384 --gui-apikey "$API" config gui password set "$ST_GUI_PASS" \
    && ok "GUI auth set for '$ST_GUI_USER'"
fi

# ─── 6. Pair peers + create/share the 3 wiki folders ────────────────────
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

echo ""
echo "═══ VPS1 setup complete ═══"
echo "This host's device ID (give it to hermes/VPS2 and any 3rd device):"
syncthing --device-id 2>/dev/null
echo ""
echo "NEXT (not automated):"
echo "  • DNS A record:  sync1 → 148.230.117.105   (+ sync2 → 187.124.45.132)"
echo "  • On hermes/VPS2: add THIS device ID as a peer + accept the 3 folders"
echo "    (or run the mirror of steps 6 there). Folders must share back both ways."
echo "  • Verify:  curl -sI https://$SUBDOMAIN | head -1   (expect 200/401 via TLS)"
echo "  • Round-trip: echo probe >> $WIKI_BASE/centaurion-wiki/.synctest ; check on hermes"
