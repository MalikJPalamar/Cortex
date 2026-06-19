# STATE — Session Memory

## Current Phase
Phase 7: Production Deployment (requires real system access)

## Current Status
Phases 1-6, 8, 10 COMPLETE. CI now runs the framework suite (~309 checks) + the
deployed app build (PR #62, #69). Phase 9 started (daily-health workflow live).

Phase 7 reconciled to the real topology (2026-06-19): NanoClaw/Nova runs as the
**containerized OpenClaw** deployment (`openclaw-…-openclaw-1`, image
`ghcr.io/hostinger/hvps-openclaw`) on the container host `srv1514399` — NOT the
`/root/nanoclaw` host install the tests originally assumed. `verify-production.sh`
R32.x now detects either topology. On the container host Phase 7 = **15/17**:
- R32.1–R32.5 ✓ (container live; Nova SOUL deployed to /data/.openclaw/workspace
  on 2026-06-19, runtime line corrected to srv1514399; backup kept alongside it)
- R34.1/R34.3/R35.3 ✓ (real Supermemory key, a real rating, clean recent history)
- Remaining real gaps: R31.2/R31.3 (dev-loop cron+logs live on VPS1
  `187.124.45.132`, a different machine than this container host).

Dev loop runs 3x daily on VPS1 via Max subscription (proven by daily auto-commits).

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
| **R31.2 / R31.3: dev-loop on VPS1** | The dev-loop cron + logs live on VPS1 (`187.124.45.132`), not this container host (`srv1514399`). Verify-production flags them as "not on this host"; not a real outage (daily auto-commits prove the loop runs). Run the suite on VPS1, or split host-specific checks. | Low |
| **R35.3: Git history (deep)** | The last-20-commit scan is clean, but earlier history may still carry exposed keys — needs `git-filter-repo`/BFG + force-push + key rotation. Deferred pending explicit go-ahead. | Medium |
| ~~R32.5: Nova SOUL~~ | RESOLVED 2026-06-19 — Nova soul deployed to the live OpenClaw container workspace (runtime line corrected to srv1514399; generic template backed up). | ✓ |
| ~~R32.4: NanoClaw agent image~~ | RESOLVED — deployment is the long-lived OpenClaw container, not a spawn-on-demand image. R32.x reconciled. | ✓ |
| ~~R34.1 / R34.3~~ | RESOLVED on host — real Supermemory key + a real task rating present. | ✓ |

## Open Questions
- NanoClaw vs OpenClaw: the live deployment on `srv1514399` is the **OpenClaw**
  container (`ghcr.io/hostinger/hvps-openclaw`), workspace at `/data/.openclaw`.
  The repo carries both `deploy/openclaw/SOUL.md` and `deploy/nanoclaw/SOUL.md`.
  - Open: which SOUL is canonical for Nova, and do we standardize naming on OpenClaw?
- Coherence Equation: Noted for future — extend Precision Ratio to measure human-AI alignment.

## Branch Map
| Branch | Purpose | Status |
|--------|---------|--------|
| `main` | Production (all phases merged) | Active |
| `claude/centaurion-pai-fork-g9XC7` | Phase 0 implementation | Merged to main |
| `prototype/centaurion-core-loop` | GSD validation | Merged to main |
