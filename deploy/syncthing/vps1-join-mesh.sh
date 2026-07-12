#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════
# VPS1 (srv940848) → join the Syncthing mesh, over Tailscale, no relay.
# ═══════════════════════════════════════════════════════════════════════
# Run this ON VPS1, as root:
#     bash vps1-join-mesh.sh
#
# It installs Syncthing (if missing), starts it, adds hermes as a peer using
# hermes' Tailscale IP (so the link is direct, no public relay), creates
# /root/Sync and pre-shares it to hermes, then prints VPS1's Device ID.
# Copy that Device ID back to Cortex — that's the only manual handoff left.
# Safe to re-run.
# ═══════════════════════════════════════════════════════════════════════
set -uo pipefail
HERMES_ID="CDVP4FC-AFOKCVZ-JYL5DDS-F4ZMXQB-BDGDG62-6NGTU77-G4NJ3DO-4X6RPAX"
HERMES_TS="100.80.130.68"          # hermes (VPS2) Tailscale IP
SYNC_DIR="/root/Sync"
GUI="http://127.0.0.1:8384"
say(){ echo "▸ $*"; }

[ "$(id -u)" -eq 0 ] || { echo "✗ run as root"; exit 1; }

# ─── 1. Install Syncthing if missing ────────────────────────────────────
if ! command -v syncthing >/dev/null 2>&1; then
  say "Installing Syncthing (official apt repo)…"
  install -d /etc/apt/keyrings
  curl -fsSL https://syncthing.net/release-key.gpg -o /etc/apt/keyrings/syncthing.gpg
  echo "deb [signed-by=/etc/apt/keyrings/syncthing.gpg] https://apt.syncthing.net/ syncthing stable" \
    > /etc/apt/sources.list.d/syncthing.list
  apt-get update -qq && apt-get install -y syncthing || {
    say "apt repo failed, trying distro package…"; apt-get install -y syncthing; }
fi
say "syncthing: $(syncthing --version 2>/dev/null | head -1)"

# ─── 2. Start as a service (fallback: background) ───────────────────────
if command -v systemctl >/dev/null 2>&1; then
  systemctl enable --now syncthing@root >/dev/null 2>&1 || true
fi
sleep 3
if ! curl -fsS "$GUI/rest/noauth/health" >/dev/null 2>&1; then
  say "Service not up — starting in background…"
  nohup syncthing serve --no-browser >/var/log/syncthing.log 2>&1 &
fi

# ─── 3. Wait for config + API ───────────────────────────────────────────
CFG=""
for _ in $(seq 1 30); do
  CFG=$(ls /root/.local/state/syncthing/config.xml /root/.config/syncthing/config.xml 2>/dev/null | head -1)
  [ -n "$CFG" ] && break; sleep 2
done
[ -n "$CFG" ] || { echo "✗ Syncthing config never appeared — see /var/log/syncthing.log"; exit 1; }
API=$(sed -n 's:.*<apikey>\(.*\)</apikey>.*:\1:p' "$CFG" | head -1)
for _ in $(seq 1 30); do
  curl -fsS -H "X-API-Key: $API" "$GUI/rest/system/status" >/dev/null 2>&1 && break; sleep 2
done

# ─── 4. Add hermes peer (Tailscale addr) + create/share folder ──────────
mkdir -p "$SYNC_DIR"
python3 - "$API" "$GUI" "$HERMES_ID" "$HERMES_TS" "$SYNC_DIR" <<'PY'
import sys, json, urllib.request
api, gui, hid, hts, path = sys.argv[1:6]
def call(method, p, data=None):
    r = urllib.request.Request(gui+p, method=method,
        headers={"X-API-Key": api, "Content-Type": "application/json"},
        data=json.dumps(data).encode() if data is not None else None)
    b = urllib.request.urlopen(r).read()
    return json.loads(b) if b.strip() else None

myid = call("GET", "/rest/system/status")["myID"]

try:
    call("PUT", "/rest/config/devices/%s" % hid,
         {"deviceID": hid, "name": "hermes",
          "addresses": ["tcp://%s:22000" % hts], "compression": "metadata"})
    print("  ✓ hermes added as peer (tcp://%s:22000 — direct, no relay)" % hts)
except Exception as e:
    print("  ! add hermes:", e)

try:
    ids = [f["id"] for f in call("GET", "/rest/config/folders")]
    if "default" not in ids:
        call("POST", "/rest/config/folders",
             {"id": "default", "label": "Default Folder", "path": path, "type": "sendreceive",
              "devices": [{"deviceID": myid}, {"deviceID": hid}]})
        print("  ✓ folder 'default' created at %s + shared to hermes" % path)
    else:
        f = call("GET", "/rest/config/folders/default")
        if hid not in [d["deviceID"] for d in f["devices"]]:
            f["devices"].append({"deviceID": hid}); call("PUT", "/rest/config/folders/default", f)
        print("  ✓ folder 'default' shared to hermes")
except Exception as e:
    print("  ! folder config:", e)

print("\nVPS1_DEVICE_ID=" + myid)
PY

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  VPS1 is running Syncthing and pre-shared /root/Sync to hermes."
echo "  → COPY the VPS1_DEVICE_ID line above and paste it to Cortex."
echo "  Cortex adds VPS1 on hermes and sync starts over Tailscale."
echo "════════════════════════════════════════════════════════════"
