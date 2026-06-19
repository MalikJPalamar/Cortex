# Syncthing Shared-Folder Config — `centaurion-wiki`

Both hosts must configure the synced folder **identically by ID**. Syncthing
matches folders across devices by their folder ID, so the ID below must be exactly
the same on VPS1 and VPS2. The on-disk path may differ per host but is the same
here because both clone the repo to `~/Centaurion`.

## Canonical definition

| Setting          | Value                                  | Notes                                            |
|------------------|----------------------------------------|--------------------------------------------------|
| **Folder ID**    | `centaurion-wiki`                      | Identical on both hosts. Do not change.          |
| **Folder Label** | `Centaurion Wiki`                      | Cosmetic; can differ per host.                   |
| **Folder Path**  | `~/Centaurion/docs`                    | Absolute path on each host. Same relative spot.  |
| **Folder Type**  | `Send & Receive`                       | Bidirectional on both hosts.                     |
| **Shared with**  | the other host's device               | VPS1 ↔ VPS2.                                      |
| **Rescan**       | `3600` s (default) or use watcher      | `fsWatcherEnabled=true` for near-real-time.      |
| **Versioning**   | `Simple`, keep `5`                     | Lets you recover from a bad sync / accidental rm.|
| **Ignore Perms** | off (default)                          | Both are Linux; keep perms in sync.              |

> **Why `docs/` and not just `docs/centaurion-wiki/`?** PT-7 calls for the wiki
> content under `docs/`, which holds `centaurion-wiki/`, `aob-wiki/`, and
> `builderbee-wiki/` plus top-level wiki docs. One folder rooted at `docs/` syncs
> all three wikis in a single share. If you want to sync *only* one wiki, set the
> path to that subdirectory and pick a distinct folder ID (e.g. `aob-wiki`).

## Equivalent `config.xml` fragment

This is what the folder stanza looks like inside Syncthing's `config.xml`
(`~/.local/state/syncthing/config.xml` on recent builds, or
`~/.config/syncthing/config.xml` on older ones). Replace the device IDs with the
real ones from `install.sh`; do **not** hand-edit `config.xml` while the daemon is
running — prefer the GUI or `syncthing cli config`.

```xml
<folder id="centaurion-wiki" label="Centaurion Wiki"
        path="/home/USER/Centaurion/docs"
        type="sendreceive" rescanIntervalS="3600"
        fsWatcherEnabled="true" fsWatcherDelayS="10"
        ignorePerms="false">
  <!-- This host -->
  <device id="THIS_HOST_DEVICE_ID"></device>
  <!-- The remote host (VPS1 or VPS2) -->
  <device id="OTHER_HOST_DEVICE_ID"></device>
  <versioning type="simple">
    <param key="keep" val="5"></param>
  </versioning>
</folder>
```

And the matching remote-device stanza (one per host, pointing at the *other*):

```xml
<device id="OTHER_HOST_DEVICE_ID" name="vps1-or-vps2" compression="metadata">
  <!-- Optional explicit address; 'dynamic' lets discovery/relays find it -->
  <address>tcp://OTHER_HOST_IP:22000</address>
  <address>dynamic</address>
</device>
```

## Scriptable (CLI) equivalent

Run on each host after both device IDs are known (see README Step 3-4):

```bash
API_KEY=$(syncthing cli config gui apikey get)

# Define the folder
syncthing cli --gui-apikey "$API_KEY" config folders add \
  --id centaurion-wiki --label "Centaurion Wiki" --path "$HOME/Centaurion/docs"
syncthing cli --gui-apikey "$API_KEY" config folders centaurion-wiki \
  type set sendreceive

# Share it with the remote device
syncthing cli --gui-apikey "$API_KEY" config folders centaurion-wiki \
  devices add --device-id "<OTHER_DEVICE_ID>"
```

## Optional `.stignore`

To keep VCS metadata and scratch files out of the sync, drop this file at the
folder root (`~/Centaurion/docs/.stignore`) on **both** hosts (identical content):

```gitignore
// Syncthing ignore patterns for the centaurion-wiki folder
.git
.DS_Store
*.tmp
*.swp
.synctest
// Keep conflict files visible so you notice them:
!*.sync-conflict-*
```

`.stignore` itself is **not** synced and must be created on each host.
