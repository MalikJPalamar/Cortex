# VPS2 Build Report — Syncthing + Traefik (handoff for the Claude finishing VPS1)

**Date captured:** 2026-07-02 (verified live off the hermes box, not reconstructed)
**Author:** Cortex (Claude, hermes session)
**Reader:** the Claude instance that will finish VPS1 (srv940848)
**Goal of the overall build:** expose each VPS's Syncthing Web GUI over HTTPS at
`https://sync{1,2}.centaurion.me` (behind Traefik), then peer the two hosts and
bidirectionally sync the three wiki folders. Block-exchange sync itself is
Syncthing-native on TCP/UDP 22000 — Traefik only fronts the **GUI**.

---

## TL;DR for the VPS1 operator

VPS2/hermes is **DONE and verified**. To finish VPS1, run
`deploy/syncthing/vps1-setup.sh` on VPS1 (edit the 2 password lines first). It
auto-discovers VPS1's Traefik (which is at a *different* path than hermes),
applies the identical pattern, and pairs back to hermes. Then add DNS records and
mirror the folder-share on hermes. Details below.

---

## Authoritative host map (the old `README.md` has the IPs BACKWARDS)

| Role | Hostname | Public IP | Subdomain | Traefik compose dir | Status |
|------|----------|-----------|-----------|---------------------|--------|
| VPS1 | `srv940848` | `148.230.117.105` | `sync1.centaurion.me` | **unknown — auto-discover** | TODO |
| VPS2 | `hermes` (`srv1514399`) | `187.124.45.132` | `sync2.centaurion.me` | `/docker/traefik` | ✅ DONE |

> Do **not** trust `deploy/syncthing/README.md` (the PT-7a P2P scaffold): it
> labels `187.124.45.132` as "VPS1". Wrong. `187.124.45.132` is hermes/VPS2.

---

## What was built on VPS2 / hermes (verified facts)

### Traefik
- Image `traefik:latest` (running `v3.6.11`), container `traefik-traefik-1`,
  `restart: unless-stopped`.
- **`network_mode: host`** — this is the key detail. It means the file-provider
  router can point at `http://127.0.0.1:8384` and reach the host's Syncthing GUI
  directly, with **no `extra_hosts` / `host-gateway` needed.**
- Compose: `/docker/traefik/docker-compose.yml`. The three lines that were added
  to enable the file provider:
  ```yaml
  command:
    - --providers.file.directory=/dynamic
    - --providers.file.watch=true
  volumes:
    - /docker/traefik/dynamic:/dynamic:ro
  ```
  (Docker provider, ACME/letsencrypt HTTP-01, web→websecure redirect were
  already present.)
- `.env`: `ACME_EMAIL=admin@srv1514399.hstgr.cloud`.
- `--providers.file.watch=true` means new/edited `dynamic/*.yml` load with **no
  Traefik restart** — but adding the *volume mount + command flags themselves*
  did require a `docker compose up -d` recreate (done).

### The router file — `/docker/traefik/dynamic/syncthing.yml` (live, exact)
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

### Syncthing (apt package, runs as root)
- Version `v1.27.2-ds4` ("Gold Grasshopper"), systemd `syncthing@root`.
- Config: `/root/.local/state/syncthing/config.xml`.
- GUI bound `0.0.0.0:8384`, `tls=false`, **no user/password set yet** 🔴.
- API key: `evWXWDtXrD2DZveEHkSun6HWtjxmf9Ji`.
- Listener up on `:22000` (block-exchange), address discovery `dynamic`.
- **Device ID (hermes/VPS2):**
  `CDVP4FC-AFOKCVZ-JYL5DDS-F4ZMXQB-BDGDG62-6NGTU77-G4NJ3DO-4X6RPAX`
- Folders: `default` (`/root/Sync`) plus the **3 wiki folders now STAGED**
  (2026-07-02): `aob-wiki`, `builderbee-wiki`, `centaurion-wiki`, each at
  `~/Centaurion/docs/<id>`, type Send & Receive, **not yet shared to any peer**
  (waiting on VPS1's device ID). The dirs already existed on disk (wiki repos);
  only the Syncthing folder config was added.

---

## What is NOT done yet (the whole remaining critical path)

1. **VPS1 Traefik** — rediscover its compose dir (it is *not* `/docker/traefik`;
   use `docker inspect … project.working_dir`), apply the same 3 edits + router
   for `sync1.centaurion.me`. → automated by `vps1-setup.sh`.
2. **DNS A records** on the `centaurion.me` registrar:
   `sync1 → 148.230.117.105`, `sync2 → 187.124.45.132`. Until these resolve,
   Traefik can't complete the ACME HTTP-01 challenge, so no cert / no HTTPS.
3. 🔴 **GUI passwords on BOTH hosts** — currently open on `0.0.0.0:8384`. Set
   these **before** the DNS records go live, or the GUIs are briefly exposed
   unauthenticated on the public internet. (Syncthing's own auth is enough;
   Traefik basicAuth is optional defence-in-depth.)
4. **Peer + share the 3 wiki folders full-mesh** — `aob-wiki`,
   `builderbee-wiki`, `centaurion-wiki` under `~/Centaurion/docs/`, identical
   folder IDs on every host, type Send & Receive. The context mentions **3
   devices** — if a laptop/phone is the third, add its device ID everywhere too.
5. **Round-trip verification** — write a `.synctest` on one host, confirm it
   appears on the other, then delete. Only then is PT-7b done.

---

## Gotchas / lessons from the VPS2 build

- **VPS1's Traefik network mode may differ.** If VPS1's Traefik is *not*
  `network_mode: host`, `127.0.0.1:8384` will hit the container, not the host —
  use `http://172.17.0.1:8384` (docker0 gateway) instead. The `vps1-setup.sh`
  script detects `NetworkMode` and picks the right URL automatically.
- **Match entrypoint + certresolver names to VPS1's existing compose.** hermes
  uses `websecure` + `letsencrypt`; if VPS1 named them differently, the router
  won't attach. The script exposes `ENTRYPOINT`/`CERT_RESOLVER` vars for this.
- **File-watch ≠ full reload.** Editing `dynamic/*.yml` is hot; adding the
  provider flags/volume needs a compose recreate.
- **Config path is state-dir, not `~/.config`.** hermes has it at
  `~/.local/state/syncthing/config.xml`. Script checks both.
- **`syncthing cli` needs BOTH `--gui-address` AND `--gui-apikey`.** With only
  the apikey it errors "Both --gui-address and --gui-apikey should be specified".
  And `--gui-address` takes bare `host:port` (`127.0.0.1:8384`) — NOT a URL with
  `http://` (that double-escapes to a parse error). All scripts here use the
  correct form; hand-typed commands must too.

---

## Pointers
- Full step-by-step runbook: `deploy/syncthing/traefik-runbook.md` (PT-7b).
- Automated VPS1 script: `deploy/syncthing/vps1-setup.sh`.
- Legacy P2P scaffold (still valid for the 22000 sync mechanics, WRONG on IPs):
  `deploy/syncthing/README.md`, `install.sh`, `verify.sh`, `folder-config.md`.
- Rationale for Syncthing vs git-private-repo split: `docs/private-data-sync.md`.
