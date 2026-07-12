# Syncthing behind Traefik — 2-VPS Runbook (PT-7b)

> Supersedes the P2P-only scaffold in this directory (`README.md`, PT-7a) for the
> **GUI-over-HTTPS** access path. The block-exchange sync (port 22000) is
> unchanged; this adds a Traefik reverse proxy so each host's Syncthing Web GUI
> is reachable at `https://sync{1,2}.centaurion.me` instead of only via SSH tunnel.
>
> **Captured 2026-07-02 from the live hermes box** — this reflects what was
> actually built today, not a hypothetical. Everything under "VPS2 / hermes" is
> DONE and verified; "VPS1 / srv940848" is the remaining work.

## ⚠️ IP / host mapping (authoritative — the old `README.md` has it BACKWARDS)

| Role | Hostname | Public IP | Subdomain | Traefik path |
|------|----------|-----------|-----------|--------------|
| **VPS1** | `srv940848` | `148.230.117.105` | `sync1.centaurion.me` | **rediscover** (see Step V1-1) |
| **VPS2** | `hermes` (`srv1514399`) | `187.124.45.132` | `sync2.centaurion.me` | `/docker/traefik` ✅ |

> The legacy `README.md` labels `187.124.45.132` as "VPS1" — that is wrong for
> this deployment. `187.124.45.132` is **hermes / VPS2**. Trust this table.

## Device IDs

| Host | Syncthing device ID |
|------|---------------------|
| **VPS2 / hermes** | `CDVP4FC-AFOKCVZ-JYL5DDS-F4ZMXQB-BDGDG62-6NGTU77-G4NJ3DO-4X6RPAX` |
| **VPS1 / srv940848** | _(get via `syncthing --device-id` on VPS1)_ |

Both hosts run **apt Syncthing v1.27.2**, GUI bound `0.0.0.0:8384`, config at
`/root/.local/state/syncthing/config.xml` (running as **root**).

---

## STATE AS OF 2026-07-02

### ✅ VPS2 / hermes — DONE

- Traefik `v3.6.11`, `network_mode: host`, compose at `/docker/traefik/docker-compose.yml`.
- File provider active — these 3 lines are in the compose `command:` + `volumes:`
  (this is the exact edit VPS1 needs too):
  ```yaml
  - --providers.file.directory=/dynamic
  - --providers.file.watch=true
  # volumes:
  - /docker/traefik/dynamic:/dynamic:ro
  ```
  Because Traefik is `network_mode: host`, `http://127.0.0.1:8384` inside the
  router config reaches the host's Syncthing GUI directly — **no `host-gateway`
  / `extra_hosts` needed.** VPS1 only needs this workaround if its Traefik is
  NOT on host networking (check in Step V1-1).
- `/docker/traefik/dynamic/syncthing.yml` (live):
  ```yaml
  http:
    routers:
      syncthing:
        rule: "Host(`sync2.centaurion.me`)"
        service: syncthing
        entryPoints: [websecure]
        tls:
          certResolver: letsencrypt
    services:
      syncthing:
        loadBalancer:
          servers:
            - url: "http://127.0.0.1:8384"
  ```
- Traefik restarted clean; file watch picks up `dynamic/*.yml` with no restart.

### ⛔ VPS1 / srv940848 — TODO (Traefik path unknown, must rediscover)

---

## REMAINING WORK

### Step V1-1 — Rediscover VPS1's Traefik (run ON VPS1, 148.230.117.105)

VPS1's Traefik is NOT at `/docker/traefik` like hermes. Find it:

```bash
# Container name + its compose working_dir (this is the folder to edit):
docker ps --filter name=traefik --format '{{.Names}}'
docker inspect $(docker ps -q --filter name=traefik) \
  --format 'workdir={{index .Config.Labels "com.docker.compose.project.working_dir"}} netmode={{.HostConfig.NetworkMode}}'
```

Note `workdir` (edit `docker-compose.yml` there) and `netmode`:
- `netmode=host` → use `http://127.0.0.1:8384` in the router (like hermes).
- anything else → use `http://172.17.0.1:8384` (docker0 bridge) **and** ensure
  Syncthing GUI is bound `0.0.0.0:8384` (it is), or add
  `extra_hosts: ["host.docker.gateway:host-gateway"]` and target that.

### Step V1-2 — Apply the same 3 Traefik edits on VPS1

In VPS1's Traefik `docker-compose.yml` (the `workdir` from V1-1), add to
`command:` (skip any that already exist) and `volumes:`:

```yaml
    command:
      - --providers.file.directory=/dynamic
      - --providers.file.watch=true
    volumes:
      - <WORKDIR>/dynamic:/dynamic:ro   # substitute the real workdir path
```

Then create the router (heredoc — phone-paste-safe), **note `sync1`, and match
the entryPoint / certresolver names to VPS1's existing compose**:

```bash
WORKDIR=<from V1-1>
mkdir -p "$WORKDIR/dynamic"
cat > "$WORKDIR/dynamic/syncthing.yml" <<'YML'
http:
  routers:
    syncthing:
      rule: "Host(`sync1.centaurion.me`)"
      service: syncthing
      entryPoints: [websecure]
      tls:
        certResolver: letsencrypt
  services:
    syncthing:
      loadBalancer:
        servers:
          - url: "http://127.0.0.1:8384"   # or http://172.17.0.1:8384 if Traefik is NOT host-networked
YML
docker compose -f "$WORKDIR/docker-compose.yml" up -d   # recreate to load new command/volume flags
```

### Step V1-3 — DNS A records (registrar for centaurion.me)

| Record | Type | Value |
|--------|------|-------|
| `sync1` | A | `148.230.117.105` |
| `sync2` | A | `187.124.45.132` |

Wait for propagation, then Traefik's HTTP-01 challenge mints the LE certs
automatically. Verify: `curl -sI https://sync2.centaurion.me | head -1`.

### Step V1-4 — Set Syncthing GUI passwords (BOTH hosts) 🔴 do before DNS is public

Right now both GUIs are on `0.0.0.0:8384` with **no auth**. Once `sync{1,2}`
resolve publicly, the GUI is exposed. Set a user+password on each host:

```bash
# On EACH host (run as root, the config owner):
API=$(sed -n 's:.*<apikey>\(.*\)</apikey>.*:\1:p' /root/.local/state/syncthing/config.xml)
syncthing cli --gui-address 127.0.0.1:8384 --gui-apikey "$API" config gui user set <USERNAME>
syncthing cli --gui-address 127.0.0.1:8384 --gui-apikey "$API" config gui password set '<STRONG_PASSWORD>'
# password is stored bcrypt-hashed; takes effect immediately, no restart needed
```

hermes apikey (for reference, VPS2): `evWXWDtXrD2DZveEHkSun6HWtjxmf9Ji`
(VPS1 has its own — read it from its config.xml with the `sed` line above.)

> Optional hardening: also add Traefik basicAuth middleware in each
> `syncthing.yml` so there are two auth layers. Not required if Syncthing's own
> auth is set.

### Step V1-5 — Pair devices full-mesh + share the 3 wikis

Current folder state on hermes: only the throwaway `default` folder
(`/root/Sync`). The **3 wiki folders are not configured on either host yet.**

The context notes **3 devices full-mesh** — if there's a laptop/3rd node, add
its device ID everywhere too. For the two VPS at minimum:

1. On **each** host: **Add Remote Device** → paste the other's device ID →
   address `dynamic` (or `tcp://<other-ip>:22000` to force direct).
2. Add the three shared folders with **identical folder IDs on every host**:

   | Folder ID | Path (same on each host) | Type |
   |-----------|--------------------------|------|
   | `aob-wiki` | `~/Centaurion/docs/aob-wiki` | Send & Receive |
   | `builderbee-wiki` | `~/Centaurion/docs/builderbee-wiki` | Send & Receive |
   | `centaurion-wiki` | `~/Centaurion/docs/centaurion-wiki` | Send & Receive |

   CLI form (run per host, per folder, then share to each remote device):
   ```bash
   API=$(sed -n 's:.*<apikey>\(.*\)</apikey>.*:\1:p' /root/.local/state/syncthing/config.xml)
   for f in aob-wiki builderbee-wiki centaurion-wiki; do
     syncthing cli --gui-address 127.0.0.1:8384 --gui-apikey "$API" config folders add \
       --id "$f" --label "$f" --path "$HOME/Centaurion/docs/$f"
     syncthing cli --gui-address 127.0.0.1:8384 --gui-apikey "$API" config folders "$f" devices add --device-id "<OTHER_DEVICE_ID>"
   done
   ```
3. On the receiving host, accept each shared-folder prompt (or pre-create with
   the same ID). Confirm both sides read **"Up to Date"** and the peer shows
   **Connected**.

### Step V1-6 — Round-trip verification

```bash
# On hermes:
echo "probe $(date -u +%FT%TZ)" >> ~/Centaurion/docs/centaurion-wiki/.synctest
# within seconds, on VPS1:
cat ~/Centaurion/docs/centaurion-wiki/.synctest && rm ~/Centaurion/docs/centaurion-wiki/.synctest
```

PT-7b is done only when: `https://sync1` and `https://sync2` both load the GUI
(password-gated), all 3 wikis are "Up to Date" on both hosts, and the round-trip
probe converges.

---

## Quick reference

- Service: `systemctl status syncthing@root` · logs `journalctl -u syncthing@root -f`
- Reload Traefik file config: **no action** — `--providers.file.watch=true` is live.
- Firewall: if sync stays on relays, open `22000/tcp`+`22000/udp` both hosts.
- hermes Traefik: `/docker/traefik` · `docker compose -f /docker/traefik/docker-compose.yml up -d`
