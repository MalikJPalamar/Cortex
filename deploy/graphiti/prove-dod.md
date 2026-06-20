# Phase 10 DoD — Proven End-to-End (Ontraport temporal query)

## The Definition of Done

> **An agent answers "When did we decide to migrate from Ontraport?" from a
> temporal knowledge graph.**

This directory proves that mechanism works against a **real Neo4j**, not a mock.

## What this proves

`prove-dod.sh` + `load_and_query.py` demonstrate the full temporal-graph path:

1. A real Neo4j 5 instance accepts **bi-temporal** decision records.
2. Each decision is a `(:Decision)` node carrying two time axes:
   - `decided_at` — **valid time** (when the decision was actually made)
   - `recorded_at` — **transaction time** (when we ingested it into the graph)
3. A plain Cypher query (`WHERE d.text CONTAINS 'Ontraport'`) retrieves the
   migration decision and the agent answers in plain English:

   > **Decided to migrate from Ontraport on 2026-03-02.**

The records use the **exact shape** the MemPalace miner emits
(`deploy/mempalace/mine_conversations.py` →
`{"timestamp","type","text", ...}`), so this is a faithful proof of the
downstream graph, not a contrived schema. Content is **synthetic / public**;
no real private conversation text is loaded.

## It uses an EPHEMERAL instance — never the shared one

This host runs a **shared, long-lived `neo4j` container** (ports **7474/7687**)
that may be used by Hermes. The proof script **never connects to it**. Instead it:

- spins up its **own** disposable container `neo4j-dod-test` on **7475/7688**
  (`docker run -d --rm`),
- refuses to run if those vars are ever set to the shared ports (explicit guard),
- installs the `neo4j` Python driver into a **throwaway venv** (`/tmp/neo4jv`) —
  it is **not** added to any repo requirements file,
- tears the container down via a `trap` on `EXIT INT TERM`, so cleanup happens
  **even on failure or Ctrl-C**, and verifies `docker ps -a` shows it gone.

## How to run

```bash
bash deploy/graphiti/prove-dod.sh
```

Requires `docker` and `python3`. Takes ~30–60s (most of it Neo4j 5 booting).

## The only gap to "live"

This proof is **LLM-free on purpose**. The one missing piece for the full
production loop is an **LLM API key** (`GRAPHITI_LLM_API_KEY` →
`OPENAI_API_KEY` / `ANTHROPIC_API_KEY`).

| Capability | Status here | What unlocks it |
|---|---|---|
| Real Neo4j temporal graph | ✅ proven | already works |
| Bi-temporal `(:Decision)` nodes | ✅ proven | already works |
| DoD Cypher query answers the question | ✅ proven | already works |
| Auto-**extracting** decision records from raw conversation text | ⛔ stubbed | **add an LLM key** so Graphiti runs the EXTRACT step |

In production, Graphiti uses the LLM to turn raw conversation episodes into the
structured decision records we hand-load here. Everything *after* extraction —
storage, bi-temporal modeling, and the retrieval query that satisfies the DoD —
is what this script proves on a real Neo4j today. Add the key and the same graph
populates itself from conversations instead of from `DECISION_RECORDS`.

## Real run transcript

```
═══ Phase 10 DoD proof — ephemeral Neo4j (NOT the shared one) ═══

── 1. START ephemeral Neo4j (neo4j-dod-test) on :7475 / :7688 ──
OK Container started. Waiting for HTTP :7475 to answer ...
OK Neo4j HTTP ready after ~18s (HTTP 200).

── 2. THROWAWAY venv + neo4j driver (/tmp/neo4jv) ──
OK neo4j driver installed in throwaway venv.

── 3. LOAD records + RUN DoD query ──
-> Connecting to Neo4j at bolt://localhost:7688 ...
OK Connected.
OK Loaded 4 temporal decision node(s) (valid-time=decided_at, transaction-time=recorded_at).
OK Graph now holds 4 (:Decision) node(s).

-- DoD QUERY -----------------------------------------------
  MATCH (d:Decision) WHERE d.text CONTAINS 'Ontraport'
  RETURN d.decided_at, d.text

  ANSWER: Decided to migrate from Ontraport on 2026-03-02.
          (full record: "We decided to migrate from Ontraport to GoHighLevel.")
          valid-time:       2026-03-02T14:11:00.000000000+00:00
          transaction-time: 2026-06-20T18:21:00.297264000+00:00

OK Phase 10 DoD PROVEN against a real Neo4j temporal graph.

═══ DoD PROVEN. Tearing down (trap) ═══

── TEARDOWN ──────────────────────────────────────────────
OK Removed container 'neo4j-dod-test'.
OK Verified: no 'neo4j-dod-test' in 'docker ps -a'.
```
