# ROADMAP — Centaurion

## Phase 1: Core Loop ✅ COMPLETE
> "Does the exo-cortex skeleton work?"
- [x] CLAUDE.md, AGENTS.md, identity (10 files), framework (7 files), agents (3), skills (5)
- [x] 134 automated checks passing

## Phase 2: Memory Integration ✅ COMPLETE
> "Can the exo-cortex remember?"
- [x] Supermemory config, wiki structure, state files, feedback workflow

## Phase 3: Multi-Runtime & Feedback ✅ COMPLETE
> "Can other agents run the same loop?"
- [x] Deploy configs (Pi, NanoClaw, Agent Zero), deploy README

## Phase 4: Knowledge Depth ✅ COMPLETE
> "Does the system have deep, cross-linked knowledge?"
- [x] centaurion-wiki (11 pages), aob-wiki (5 pages), builderbee-wiki (5 pages)

## Phase 5: Operational Workflows ✅ COMPLETE
> "Can the system execute real venture work?"
- [x] Venture skills (aob-ops, builderbee-delivery), workflows, framework index

## Phase 6: Cross-Venture Coherence ✅ COMPLETE
> "Does the system compound knowledge across ventures?"
- [x] Cross-venture map, architecture doc, getting-started, case study, CHANGELOG

## Phase 7: Production Deployment ✅ NEAR-COMPLETE (1 remaining)
> "Is the system actually running in production?"
- [x] VPS1: Claude auth, cron 3x daily, health check, NanoClaw running
- [x] GitHub Actions report-only workflow
- [ ] Supermemory API key (skipped for now)

## Phase 8: Operational Automation ✅ COMPLETE
> "Do the automated workflows actually run?"
- [x] Dev loop: lock file, log rotation, metrics, status JSON
- [x] Weekly review runner (Mondays 7am CET)
- [x] Health check runner (daily 5:55am CET)
- [x] One-command installer (install.sh)

## Phase 9: Real Integrations (current)
> "Is the system connected to external services?"

- [x] Autoresearch skill + runner script (overnight iteration pattern)
- [x] NanoClaw renamed from OpenClaw across deploy/
- [ ] Syncthing between VPS1 and VPS2 (P2P wiki sync)
- [ ] Nova actually scanning via Telegram (NanoClaw → Cortex routing)
- [x] gh-aw or equivalent scheduled issue creation for daily health (`.github/workflows/daily-health.yml`)
- [ ] InfraNodus MCP for gap analysis (or equivalent)
- [ ] Wiki repos as separate GitHub repos (not just docs/ subdirectories)

**Definition of Done:** Nova responds to a Telegram message using Centaurion identity. Syncthing running. At least one gh-aw workflow creating issues.

## Phase 10: Knowledge Graph (Month 2)
> "Does the system track how knowledge evolves?"

- [x] Neo4j deployed (Docker) — `neo4j:5` (5.26.23 community) live on srv1514399, :7474/:7687
- [~] Graphiti installed and connected via MCP — **scaffolded** (#87): `memory/graphiti.json`
  + `deploy/graphiti/` (runbook, mcp.json, connection test, temporal-tracking doc). Needs
  operator: `NEO4J_PASSWORD` + LLM key in host `.env`, then `pip install graphiti-core`.
- [~] Temporal entity tracking — documented via Graphiti bi-temporal edges (`deploy/graphiti/temporal-tracking.md`); live once Graphiti is activated.
- [~] MemPalace — Claude conversation exports mined — **runnable miner** (#88):
  `deploy/mempalace/mine_conversations.py` (stdlib, extracts timestamped decisions/facts
  → `mempalace-extract.jsonl`, ready to feed Graphiti+Supermemory).

**Definition of Done:** Agent answers "When did we decide to migrate from Ontraport?" from Graphiti.
**Status note (2026-06-20):** Neo4j live; Graphiti + MemPalace scaffolded and runnable.
Two operator steps gate full activation: NEO4J_PASSWORD + an LLM key in the host `.env`.
The MemPalace miner already extracts the exact Ontraport-decision record from a sample
export — once Graphiti is keyed, ingesting it satisfies the DoD.

---

## Next Production Targets (lined up 2026-06-19, post real-dashboard ship)

> Context: the deployed dashboard now serves **real** state (`/api/dashboard/stats`,
> `/api/status/live`, `/api/cicd/health`) — PRs #70/#73/#74. These are the next
> production targets in priority order. Owner = who must act (🤖 Cortex can do
> autonomously · 👤 needs Malik).

### P0 — Security footing (👤+🤖)
- [ ] **PT-1 Rotate exposed keys.** Audit (3 agents, 2026-06-19) found the git history
  clean — no rewrite/BFG needed — but real keys must be rotated: Anthropic (leaked into
  Hermes session logs, now scrubbed), GitHub PAT, Render (was committed), OpenRouter,
  Supermemory; 2nd pass: NEXOS, Oxylabs, Browser-Use, Firecrawl, Honcho, 3× Telegram,
  OpenClaw gateway, Neo4j pw. 👤 revokes+reissues at dashboards → 🤖 updates host
  `.env`/container + restarts. **Done when:** old keys 401, services green on new keys.

### P1 — Make the system "real" to a user
- [ ] **PT-2 Verify Nova end-to-end via Telegram** (closes Phase 9 DoD). SOUL is deployed;
  send a real Telegram message and confirm Nova replies in Centaurion sensing identity.
  👤 sends / 🤖 inspects logs. **Done when:** a Telegram exchange shows Nova-as-Nova.
- [x] **PT-3 Surface live endpoints in the UI** 🤖. Dashboard now has a live "System
  Status" panel wiring `/api/status/live` + `/api/cicd/health` (phase, dev-loop,
  component health) — replaced the hardcoded Pipeline card (#83).
- [x] **PT-4 Live data, not a build-time snapshot** 🤖. `live_data.py` now fetches state
  from GitHub raw (`main`) at runtime with a TTL cache, falling back to the baked-in
  file on any failure. The dev loop pushes 3×/day → dashboard updates without a redeploy.
  Toggle via `CENTAURION_LIVE_FETCH`/`CENTAURION_FETCH_TTL`.

### P2 — Retire mock surfaces & harden
- [x] **PT-5 Real ai-operations / cicd-pipelines / settings / market** 🤖. All four wired
  to real state (#78, #85): ai-operations ← routing-log+dev-loop; pipelines ← workflows;
  settings ← real config; market ← honest "unconfigured" (no fabricated sentiment).
  **No GET endpoint returns mock fixtures.** (Only `market/intelligence` lacks a live feed,
  and now says so truthfully instead of faking it.)
- [x] **PT-6 Kill Render cold-starts** 🤖/👤. Keep-warm cron on `/api/health` (~10 min) or
  paid tier. **Done when:** first-load < 2s consistently. (keep-warm.yml, every 13 min)
- [x] **PT-8 Backend hardening (CORS + security headers)** 🤖 (#86). CORS locked to an
  env-driven allowlist (no `*`+credentials); security headers (CSP, X-Frame-Options DENY,
  nosniff, Referrer-Policy) on every response. Multi-user auth deliberately OUT of scope.

### P3 — Phase 9 infra remainder
- [ ] **PT-7** Syncthing (VPS1↔VPS2 wiki sync), InfraNodus MCP (gap analysis),
  wikis-as-separate-repos. **Done when:** Phase 9 DoD infra items met.
  - Syncthing scaffold added (`deploy/syncthing/`) — activation needs a run on
    each host (install + device-ID exchange + folder share on VPS1 *and* VPS2).
    Checkbox stays unchecked until both hosts are paired and "Up to Date".
  - InfraNodus scaffold added (`memory/infranodus.json` + `deploy/infranodus/`) —
    needs `INFRANODUS_API_KEY` to activate. MCP config + HTTP-API runbook + gap-analysis
    skill wiring all in place; flip to live by setting the key on the host.
  - Wiki-as-repos migration kit added (`deploy/wiki-migration/`, dry-run safe) —
    operator runs `migrate-wikis.sh --execute` to create the separate repos.

**Sequencing:** PT-1 (clean footing) → PT-2/3/4 (system is real & live) → PT-5/6 (polish & reliability) → PT-7 (infra).

---

## Meta: Daily Development Loop
> "Does the system develop itself on a schedule?"

- [x] VPS1 cron: 3x daily (6am, 2pm, 10pm CET)
- [x] GitHub Actions: daily report at 6:15am CET
- [x] Weekly review: Mondays 7am CET
- [x] Health check: daily 5:55am CET
- [x] Autoresearch: on-demand overnight iteration
