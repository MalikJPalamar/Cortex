# Syncthing — P2P Wiki Sync (PT-7a)

Part of **Phase 9 / PT-7**. Keeps the Centaurion wikis under `docs/` in sync
between the two hosts over a direct, encrypted peer-to-peer channel — no central
server, no git round-trip, no cloud dependency.

> **Status: SCAFFOLD, not yet active.** These files are a deployable runbook.
> Activation is a two-host pairing handshake that *must* be run on **both**
> machines (each generates its own device ID, then each adds the other). Nothing
> here was executed on a live host — see [Manual steps](#manual-steps-operator).

## Topology

```
┌─────────────────────────────┐         ┌─────────────────────────────┐
│ VPS1                        │ <─────> │ VPS2 / container host       │
│ 187.124.45.132              │  P2P    │ srv1514399                  │
│                             │ (TLS,   │                             │
│ ~/Centaurion/docs/          │ direct) │ ~/Centaurion/docs/          │
│   centaurion-wiki/          │         │   centaurion-wiki/          │
│   aob-wiki/                 │         │   aob-wiki/                 │
│   builderbee-wiki/          │         │   builderbee-wiki/          │
└─────────────────────────────┘         └─────────────────────────────┘
         folder id: centaurion-wiki  (send-receive on both)
```

- **Synced folder:** the wiki content under `docs/` (see
  [folder-config.md](folder-config.md) for the exact folder ID, path, and type).
- **Transport:** Syncthing's own block-exchange protocol — mutual-TLS, device-ID
  pinned. Goes direct when the hosts can reach each other; falls back to the
  public relay pool otherwise. No inbound port is strictly required to *start*,
  but opening **TCP/UDP 22000** on both ends makes sync direct and fast.
- **Why P2P (not git):** wikis change from either host (dev-loop on VPS2, manual
  edits on VPS1). Syncthing gives near-real-time bidirectional convergence with
  automatic conflict files, without either host needing push access to the other.

## Current state on this host (srv1514399)

At scaffold time, `which syncthing` returned **not installed**. Run
[`install.sh`](install.sh) to install it, then follow the runbook below.

## What's in this directory

| File               | Purpose                                                          |
|--------------------|------------------------------------------------------------------|
| `README.md`        | This file — topology + runbook.                                  |
| `install.sh`       | Idempotent Syncthing install (apt repo + systemd) + prints ID.   |
| `folder-config.md` | The shared-folder definition both hosts must configure identically. |
| `verify.sh`        | Read-only status check (installed? running? prints device ID).   |

---

## RUNBOOK

Do **all** of these on **both** hosts unless a step says otherwise. The pairing
is symmetric: each host adds the *other* as a remote device, then one side shares
the folder and the other accepts it.

### Step 0 — Prerequisites (both hosts)

```bash
# Run as the user that owns ~/Centaurion (NOT root, unless that's the repo owner).
whoami
ls -d ~/Centaurion/docs   # confirm the wiki tree exists at the expected path
```

### Step 1 — Install Syncthing (both hosts)

```bash
cd ~/Centaurion
bash deploy/syncthing/install.sh
```

The script installs from the official Syncthing apt repo, enables the per-user
systemd service (`syncthing@<user>`), starts it, and prints this host's
**device ID** at the end. Copy that ID — you need it on the *other* host.

> The Web GUI binds to `127.0.0.1:8384` by default (local only). To reach it
> from your laptop over SSH: `ssh -L 8384:127.0.0.1:8384 user@<host>` then open
> <http://127.0.0.1:8384>. All steps below can also be done from the GUI; the
> CLI/`curl` commands are given so the whole thing is scriptable from a phone.

### Step 2 — Get each device ID

On each host:

```bash
syncthing --device-id
# or, if it's already running:
bash deploy/syncthing/verify.sh
```

Record them:

- `DEVICE_ID_VPS1` = (from 187.124.45.132)
- `DEVICE_ID_VPS2` = (from srv1514399)

### Step 3 — Add the remote device (on BOTH hosts)

Easiest path is the Web GUI: **Add Remote Device** → paste the *other* host's ID
→ name it (`vps1` or `vps2`) → for the address use `tcp://<other-host-ip>:22000`
or leave `dynamic` to let the relay/discovery find it.

- On **VPS1**, add `DEVICE_ID_VPS2`, address `tcp://srv1514399:22000` (or
  `dynamic`).
- On **VPS2 (srv1514399)**, add `DEVICE_ID_VPS1`, address
  `tcp://187.124.45.132:22000` (or `dynamic`).

CLI/API equivalent (uses the local API key from `config.xml`; run on each host,
substituting the *other* host's ID and IP):

```bash
API_KEY=$(syncthing cli config gui apikey get 2>/dev/null || \
          sed -n 's:.*<apikey>\(.*\)</apikey>.*:\1:p' ~/.local/state/syncthing/config.xml 2>/dev/null || \
          sed -n 's:.*<apikey>\(.*\)</apikey>.*:\1:p' ~/.config/syncthing/config.xml)

syncthing cli --gui-apikey "$API_KEY" config devices add \
  --device-id "<OTHER_DEVICE_ID>" || true
# then set a friendly name + address via the GUI, or:
syncthing cli --gui-apikey "$API_KEY" config devices "<OTHER_DEVICE_ID>" \
  addresses set "tcp://<OTHER_HOST_IP>:22000"
```

Each side will show the other as "Disconnected (unused)" until the folder is
shared — that's expected.

### Step 4 — Define the shared folder (on the FIRST host, e.g. VPS1)

Use the exact values from [folder-config.md](folder-config.md):

- **Folder ID:** `centaurion-wiki`  *(must be identical on both hosts)*
- **Folder Path:** `~/Centaurion/docs`  *(absolute path on each host)*
- **Folder Type:** `Send & Receive`
- **Share with:** the remote device you added in Step 3.

GUI: **Add Folder** → set ID + path → **Sharing** tab → tick the remote device →
**Advanced** → File Versioning = *Simple* (keep 5) so a bad sync is recoverable.

CLI/API equivalent:

```bash
syncthing cli --gui-apikey "$API_KEY" config folders add \
  --id centaurion-wiki --label "Centaurion Wiki" --path "$HOME/Centaurion/docs"
syncthing cli --gui-apikey "$API_KEY" config folders centaurion-wiki \
  devices add --device-id "<OTHER_DEVICE_ID>"
```

### Step 5 — Accept the folder (on the SECOND host, e.g. VPS2)

When the first host shares the folder, the second host gets a notification:
**"<host> wants to share folder centaurion-wiki"** → **Add** → set the path to
`~/Centaurion/docs` (the same place on this host) → Folder Type
**Send & Receive** → Save.

If you don't see the prompt (relay lag), add the folder manually with the **same
folder ID** `centaurion-wiki` and share it back with the first device — Syncthing
matches folders by ID across devices.

### Step 6 — Set send/receive mode (both hosts)

Confirm the folder type is **Send & Receive** on *both* hosts so edits flow both
ways. (Use *Receive Only* on a host only if you want it to be a read replica —
not the default for this setup.)

### Step 7 — Verify sync

```bash
bash deploy/syncthing/verify.sh        # run on each host
```

Then confirm convergence end-to-end:

```bash
# On VPS1:
echo "sync probe $(date -u +%FT%TZ)" >> ~/Centaurion/docs/.synctest
# Within a few seconds, on VPS2:
cat ~/Centaurion/docs/.synctest        # should show the same line
# Clean up afterwards (on either host — deletion also syncs):
rm ~/Centaurion/docs/.synctest
```

In the GUI both devices should read **"Up to Date"** and the remote device should
show **Connected**. PT-7a is "done" only once this round-trip succeeds on both
hosts.

---

## Operational notes

- **`.stignore`:** Syncthing reads a `.stignore` file at the folder root to skip
  paths. If you do **not** want `docs/`'s own scratch files or VCS metadata
  synced, add a `.stignore` inside `~/Centaurion/docs/` on both hosts. See
  `folder-config.md`.
- **Conflicts:** simultaneous edits to the same file on both hosts produce a
  `*.sync-conflict-*.md` file rather than silent data loss. Resolve by hand and
  delete the loser.
- **Firewall:** if sync stays stuck on relays and feels slow, open `22000/tcp`
  and `22000/udp` (and `21027/udp` for LAN discovery, irrelevant across the WAN)
  on both hosts and re-add the device address as `tcp://<ip>:22000`.
- **Service control:** `systemctl --user status syncthing@$USER`,
  `journalctl --user -u syncthing@$USER -f`.

## Manual steps (operator)

These **cannot** be done from this container and must be run on the hosts:

1. Run `install.sh` on **VPS1 (187.124.45.132)** — it is not installed there yet
   (only this container, srv1514399, was inspected).
2. Run `install.sh` on **VPS2 (srv1514399)** — `which syncthing` was empty at
   scaffold time.
3. Exchange the two device IDs (Step 2) and add each as a remote device on the
   other host (Step 3) — a mutual handshake; one host alone can't complete it.
4. Share + accept the `centaurion-wiki` folder (Steps 4–6) on both hosts.
5. Run the Step 7 round-trip probe and confirm "Up to Date" on both. Only then
   check the **PT-7** box in `.planning/ROADMAP.md`.
