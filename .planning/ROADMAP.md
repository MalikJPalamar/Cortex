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

---

## Meta: Daily Development Loop
> "Does the system develop itself on a schedule?"

- [x] VPS1 cron: 3x daily (6am, 2pm, 10pm CET)
- [x] GitHub Actions: daily report at 6:15am CET
- [x] Weekly review: Mondays 7am CET
- [x] Health check: daily 5:55am CET
- [x] Autoresearch: on-demand overnight iteration
