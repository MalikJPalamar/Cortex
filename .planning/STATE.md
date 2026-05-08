# STATE — Session Memory

## Current Phase
Phase 7: Production Deployment (requires real system access)

## Current Status
Phases 1-6, 8, 10 COMPLETE. Suite at 325/327 (≥99%) as of 2026-05-08.
Phase 7 has 1 real failing check (R32.4 — NanoClaw agent image not built).
The other Phase 7 "fail" line is the suite's summary line being grep-counted as a ✗.
R32.4 cannot be auto-fixed by the dev loop: `docker build` is not in the auto-approve
allowlist, and adding it without operator review would expand the agent's privilege.
Dev loop runs 3x daily (6am, 2pm, 10pm CET) on VPS1 via Max subscription.

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-04-12 | Unified repo (exo-cortex + existing dashboard) | User preference. Don't split into separate repos. |
| 2026-04-12 | Native build, not PAI fork | PAI's TypeScript/Bun assumptions don't fit phone-first, multi-runtime. |
| 2026-04-12 | All markdown + JSON, no TypeScript hooks | Portability across runtimes. Intelligence in prompts, not compiled code. |
| 2026-04-12 | GSD spec-driven TDD approach | Tests before implementation. Verification before expansion. |
| 2026-04-12 | Renamed Fitness Equation → Precision Ratio | Avoid Darwinian/deterministic connotations. Active Inference native term. |
| 2026-04-13 | Dev loop moved from GitHub Actions to VPS1 cron | Max subscription (zero API cost) vs API key billing. |
| 2026-04-14 | 3x daily cadence (6am, 2pm, 10pm CET) | 30 turns, 10 fixes per run. Cleared Phases 4-6 in 12 hours. |
| 2026-04-15 | Phase 7: production tests | Tests that require real deployment — agent routes to Malik what it can't fix. |

## Blockers — Items Requiring Malik's Input

| Item | What's Needed | Priority |
|------|--------------|----------|
| **R32.4: NanoClaw agent image** | Run `/root/nanoclaw/container/build.sh` on VPS1. Orchestrator is up, `.env` + SOUL.md are already deployed; only the Docker image is missing. The dev loop cannot self-approve `docker build`, so this is the one remaining manual step. | High |
| **R34.1: Supermemory** | Sign up for Supermemory, get API key, replace placeholder in memory/supermemory.json | Medium |
| **R34.3: Real ratings** | Rate one real task output (not dev loop self-rating) | Low |
| **R35.3: Git history** | API keys exposed in history from earlier session — needs BFG repo cleaner | Medium |

## Open Questions
- NanoClaw vs OpenClaw: User confirmed it's NanoClaw, not OpenClaw. Update deploy/ references?
  - Decision: Rename when NanoClaw config is confirmed working.
- Coherence Equation: Noted for future — extend Precision Ratio to measure human-AI alignment.

## Branch Map
| Branch | Purpose | Status |
|--------|---------|--------|
| `main` | Production (all phases merged) | Active |
| `claude/centaurion-pai-fork-g9XC7` | Phase 0 implementation | Merged to main |
| `prototype/centaurion-core-loop` | GSD validation | Merged to main |
