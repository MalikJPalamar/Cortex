# Temporal Tracking — Phase 10 Definition of Done

## The DoD question

> **The agent can answer: "When did we decide to migrate from Ontraport?"**

This is the canonical Phase 10 acceptance test. It is deliberately a question that
the rest of the memory stack **cannot** answer well:

| Layer | What it gives | Why it falls short on this question |
|-------|---------------|-------------------------------------|
| Supermemory (L1) | Real-time recall of recent context | No durable time axis on *relationships*; recall ≠ "when did X become true". |
| InfraNodus (L2b) | Topology / structural holes over wiki text | Spatial, not temporal — shows *what connects*, not *when it changed*. |
| MemPalace (L3) | Verbatim transcript archive | Has the raw words, but you must already know which conversation, and it doesn't model facts as edges. |
| **Graphiti (L2a)** | **Bi-temporal entity graph** | **Stamps every fact with when it became true and when it was learned — built for exactly this.** |

## Why a bi-temporal graph answers it

Graphiti models the world as **entities** (nodes) joined by **facts** (edges), and
every edge carries two independent time axes:

- **Valid time** — when the fact was true *in the world*: `valid_at` → `invalid_at`.
- **Transaction time** — when Graphiti *learned/recorded* it: `created_at` → `expired_at`.

So the decision "AOB migrates off Ontraport → GoHighLevel" is stored as a fact edge
between the `Ontraport` / `GoHighLevel` / `AOB` entities, with `valid_at` set to the
decision date. Answering the DoD question is then a `search_facts` query that reads
`valid_at` off that edge — not a fuzzy text recall.

## Walkthrough (after activation)

1. **Ingest the decision as an episode** (via `add_memory` / `add_episode`):

   > "On 2025-09-12, after the GHL evaluation, Malik and Anthony decided to migrate
   > AOB off Ontraport to GoHighLevel."

   The LLM extracts entities (`Malik`, `Anthony`, `AOB`, `Ontraport`, `GoHighLevel`,
   `GHL evaluation`) and a `decided_to_migrate` fact edge, stamped
   `valid_at = 2025-09-12`.

2. **Ask the DoD question** (`search_facts`: *"when did we decide to migrate from
   Ontraport?"*). Graphiti returns the fact edge and its `valid_at` — **2025-09-12** —
   with the source episode as provenance.

3. **Evolution, for free.** If a later episode says the migration *completed* on a
   different date, that's a **new** edge with its own `valid_at`; the decision edge is
   untouched. Asking "how did the Ontraport migration unfold?" returns the ordered
   timeline. If a fact is later contradicted (e.g. "we paused the migration"), the old
   edge is **invalidated** (`invalid_at` set), not deleted — so "what did we believe
   on date X?" still reconstructs correctly.

## DoD checklist

- [x] Neo4j live and reachable (verified read-only — see README §1; Neo4j 5.26.23).
- [x] Integration descriptor (`memory/graphiti.json`) with env-ref secrets, no hardcoded password.
- [x] MCP wiring documented (`deploy/graphiti/mcp.json`, README §4).
- [x] Read-only connection test script.
- [ ] **Operator:** set `NEO4J_PASSWORD` + an LLM key in host `.env`.
- [ ] **Operator:** install Graphiti, register the MCP server, ingest first episodes.
- [ ] **Operator:** confirm the agent answers the DoD question from a `search_facts` call.

The first three are this scaffold. The last three are the operator's activation
steps — Graphiti needs an LLM key to build the graph, and none is fabricated here.
