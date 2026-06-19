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

- [ ] Neo4j deployed on VPS1 (Docker)
- [ ] Graphiti installed and connected via MCP
- [ ] Temporal entity tracking live
- [ ] MemPalace installed — Claude conversation exports mined

**Definition of Done:** Agent answers "When did we decide to migrate from Ontraport?" from Graphiti.
**Status note (2026-06-19):** Neo4j IS deployed (container `neo4j:5` live on srv1514399, ports 7474/7687). Graphiti MCP + temporal tracking still pending.

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
- [ ] **PT-3 Surface live endpoints in the UI** 🤖. Frontend consumes only
  `/api/dashboard/stats`; add a "System" panel wiring `/api/status/live` +
  `/api/cicd/health` (phase, dev-loop, component health). **Done when:** dashboard shows a live system-status panel.
- [ ] **PT-4 Live data, not a build-time snapshot** 🤖. Stats currently freeze at deploy.
  Read fresh state (dev-loop-written volume, or pull from VPS/API) so it updates without
  a redeploy. **Done when:** a new routing decision appears without rebuilding the image.

### P2 — Retire mock surfaces & harden
- [ ] **PT-5 Real ai-operations / cicd-pipelines / settings** 🤖. Map ai-operations ←
  routing-log+dev-loop runs; cicd/pipelines ← GitHub Actions API; settings ← real config;
  drop/wire market. **Done when:** no endpoint returns mock fixtures.
- [x] **PT-6 Kill Render cold-starts** 🤖/👤. Keep-warm cron on `/api/health` (~10 min) or
  paid tier. **Done when:** first-load < 2s consistently. (keep-warm.yml, every 13 min)

### P3 — Phase 9 infra remainder
- [ ] **PT-7** Syncthing (VPS1↔VPS2 wiki sync), InfraNodus MCP (gap analysis),
  wikis-as-separate-repos. **Done when:** Phase 9 DoD infra items met.

**Sequencing:** PT-1 (clean footing) → PT-2/3/4 (system is real & live) → PT-5/6 (polish & reliability) → PT-7 (infra).

---

## Meta: Daily Development Loop
> "Does the system develop itself on a schedule?"

- [x] VPS1 cron: 3x daily (6am, 2pm, 10pm CET)
- [x] GitHub Actions: daily report at 6:15am CET
- [x] Weekly review: Mondays 7am CET
- [x] Health check: daily 5:55am CET
- [x] Autoresearch: on-demand overnight iteration
