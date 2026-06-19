# Changelog

All changes to the Centaurion exo-cortex, with real dates and deliverables.

## CI/CD Hardening + Phase 9 start (2026-06-19)
- **CI/CD pipeline** now validates the deployed app (root Dockerfile = React/Vite + FastAPI), enforces a real security gate (bandit blocking on our code, safety advisory), and added a first pytest suite. Build job repointed off the non-deployed legacy server; live at centaurion.onrender.com. (PR #62)
- **`.github/workflows/ci.yml`**: new `framework-verify` job runs the phase verification suite (`tests/run-all.sh`) on every push/PR — GitHub CI now checks ~309 framework invariants, not just smoke tests. Blocks `build`.
- **`tests/run-all.sh`**: auto-skips Phase 7 (live VPS1 host) when `CI=true`.
- **`tests/verify-core-loop.sh`**: R10.1/R10.2 now skip intentionally gitignored per-operator files (onboarding-state.json, BASELINE-*.md) — fixes CI false-positives while still validating real broken references.
- **Phase 9:** `.github/workflows/daily-health.yml` created — scheduled daily GitHub Issue with framework-suite status, last VPS health snapshot, dev-loop status, wiki freshness, and routing recency (satisfies the "gh-aw workflow creating issues" Definition-of-Done item).

## Phase 8 — Operational Automation (2026-04-16)
- **deploy/vps1/centaurion-dev-loop.sh** rewritten: lock file prevents concurrent runs, log rotation (14 days), execution metrics, dev-loop-status.json output
- **deploy/vps1/weekly-review.sh** created: L2 sensing runner, uses `claude -p`, generates structured weekly comparison, cron-installable (Mondays 7am CET)
- **deploy/vps1/health-check.sh** created: checks disk/memory/docker/nanoclaw/claude-auth/git-status, outputs health-status.json
- **install.sh** created: one-command VPS setup (clone, auth check, cron install, Nova deploy, health check, test suite)
- First weekly review output generated (2026W16)
- Tests: 18 checks (R36-R40)

## Phase 7 — Production Deployment (2026-04-15)
- VPS1: Claude Code authenticated via Max subscription (claude.ai)
- VPS1: Dev loop cron running 3x daily (6am, 2pm, 10pm CET)
- VPS1: NanoClaw running with free model, Nova SOUL.md deployed
- GitHub Actions: report-only workflow (no API cost)
- Exposed API keys scrubbed from repo files
- Tests: 16 checks (R31-R35), 1 remaining (Supermemory API key)

## Phase 6 — Cross-Venture Coherence (2026-04-15, autonomous)
- `docs/centaurion-wiki/cross-venture-map.md`: AOB ↔ BuilderBee ↔ Centaurion connections
- `docs/architecture.md`: agent topology + memory layer diagram
- `docs/getting-started.md`: setup instructions for new sessions
- `docs/case-studies/centaurion-as-client.md`: the system building itself
- `CHANGELOG.md` created
- Tests: 25 checks (R27-R30)

## Phase 5 — Operational Workflows (2026-04-15, autonomous)
- `skills/aob-ops/SKILL.md`: AOB operations skill
- `skills/builderbee-delivery/SKILL.md`: BuilderBee client delivery skill
- `workflows/client-onboarding.md`: 5-day GHL onboarding workflow
- `workflows/aob-weekly-ops.md`: Monday ops checklist
- `framework/README.md`: index linking all framework files
- All 5 core skills expanded with examples (≥1000 bytes each)
- Tests: 26 checks (R23-R26)

## Phase 4 — Knowledge Depth (2026-04-14 – 04-15, autonomous)
- centaurion-wiki expanded to 11 pages (five-sensing-layers, markov-blanket, 11-levels, named-agents, memory-architecture, ventures, glossary, free-energy-principle, feedback-loop, multi-runtime-deployment)
- `docs/aob-wiki/` created: 5 pages (README, crm-migration, team, facilitator-certification, tech-stack)
- `docs/builderbee-wiki/` created: 5 pages (README, ghl-playbook, client-onboarding, service-offerings, ai-automation-patterns)
- Tests: 32 checks (R19-R22)

## Phase 3 — Multi-Runtime & Feedback (2026-04-12 – 04-13)
- `deploy/pi/settings.json`: Pi coding-agent scaffold
- `deploy/openclaw/SOUL.md`: Nova personality for OpenClaw/NanoClaw
- `deploy/agent-zero/system-prompt.md`: Three Laws for Agent Zero
- `deploy/README.md`: deployment instructions
- `memory/state/ratings.jsonl` and `routing-log.jsonl`: sample entries
- `workflows/feedback-capture.md`: rating + routing capture workflow
- Tests: 12 checks (R17-R18)

## Phase 2 — Memory Integration (2026-04-12)
- Supermemory config: status set to `connected`, venture containers defined
- centaurion-wiki: 4 initial pages (fitness-equation→precision-ratio, three-laws, active-inference-loop, routing-gate)
- `memory/state/` directory: ratings.jsonl + routing-log.jsonl initialized
- CLAUDE.md REMEMBER step references Supermemory explicitly
- centaurion-core SKILL.md: Supermemory in SENSE + REMEMBER sections
- Tests: 14 checks (R15-R16)

## Phase 1 — Core Loop (2026-04-12)
- CLAUDE.md: Active Inference execution schema (7-step loop)
- AGENTS.md: multi-runtime schema for pi/OpenClaw/Codex/Agent Zero
- `identity/`: 10 TELOS files (PURPOSE, MISSION, GOALS, CHALLENGES, CONTACTS, BELIEFS, MODELS, PREFERENCES, HISTORY, OPINIONS)
- `framework/`: 7 theoretical core files (precision-ratio, three-laws, active-inference-loop, five-sensing-layers, markov-blanket, routing-gate, 11-levels)
- `agents/`: Cortex.md, Nova.md, Daemon.md personalities
- `skills/`: 5 SKILL.md files (centaurion-core, routing-gate, weekly-review, sa-scan, gap-analysis)
- `memory/`: 4 config files (supermemory, wiki-repos, graphiti, mempalace)
- GSD planning: .planning/ with PROJECT, REQUIREMENTS, ROADMAP, STATE
- Test suite: verify-core-loop.sh (134 checks)
- Tests: 134 checks (R1-R10)

## Phase 0 — Architecture Decision (2026-04-12)
- Decided: unified repo (exo-cortex alongside existing web dashboard)
- Decided: native build, not PAI fork (markdown + JSON, no TypeScript hooks)
- Decided: GSD spec-driven TDD approach (tests before implementation)
- Renamed: Fitness Equation → Precision Ratio (avoid Darwinian connotations)
