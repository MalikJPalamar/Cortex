# Graphiti — Temporal Knowledge Graph (Phase 10)

> **Status: SCAFFOLD — `pending-key`.** Neo4j is **already live** on this host;
> everything is wired except an LLM key for entity extraction. No live graph is
> fabricated here — Graphiti cannot build a graph without an LLM, and no key is
> present. Two operator steps (below) flip this from `scaffolded` to live.

Graphiti ([getzep/graphiti](https://github.com/getzep/graphiti)) is the
**time axis** of Centaurion's memory stack. Supermemory recalls ("what was I
working on?") and InfraNodus shows topology ("what are we NOT seeing?"). Graphiti
adds the one thing neither can: **when** facts and relationships became true, and
**how they changed**. It does this with a **bi-temporal** graph in Neo4j —
superseded facts are *invalidated*, never deleted, so history stays queryable.

---

## 0. Reality check (read this first)

- **Neo4j is up.** Verified read-only on this host (`srv1514399`) — see §1 output.
- **Graphiti needs an LLM key** (OpenAI or Anthropic) to extract entities and
  relationships from each episode. **That key is not present in this repo or
  scaffold.** Until it is set, this is a documented scaffold, not a working graph.
- We do **not** hardcode the Neo4j password. The live value currently lives in the
  `neo4j` container's `NEO4J_AUTH`; the repo references it as `${NEO4J_PASSWORD}`,
  read from the host `.env`.

## 1. Prerequisite — Neo4j (already satisfied)

Neo4j runs as the Docker container `neo4j` on this host: HTTP on `:7474`, Bolt on
`:7687`. Confirm read-only at any time:

```bash
bash deploy/graphiti/test-connection.sh
```

Captured output from this host (2026-06-20, nothing mutated):

```
═══ Graphiti / Neo4j Connection Test — srv1514399 ═══
✓ Container 'neo4j' running: neo4j:5 | Up 6 weeks | 0.0.0.0:7474->7474/tcp, ... 0.0.0.0:7687->7687/tcp
✓ HTTP http://localhost:7474 → 200
  • Neo4j 5.26.23 (community)
  • bolt_direct: bolt://localhost:7687
✓ Bolt port localhost:7687 open

── Activation secrets (env) ──
✗ NEO4J_PASSWORD not in env
✗ No LLM key in env — Graphiti cannot extract entities without one.
```

Neo4j **5.26.23 Community** — comfortably above Graphiti's `>= 5.26` requirement.
The two `✗` lines are the entire remaining task: the secrets gate activation.

## 2. Set the secrets on the host

Both live in the host `.env` (gitignored, `600` perms) — never in the repo.

```bash
# (a) Neo4j password — the value the `neo4j` container was started with
#     (it is inside the container's NEO4J_AUTH=neo4j/<password>).
echo 'NEO4J_PASSWORD=<the-neo4j-password>' >> /root/Centaurion/.env

# (b) One LLM provider key for entity extraction.
#     GRAPHITI_LLM_API_KEY is the repo-side env-ref; map it to your provider:
echo 'GRAPHITI_LLM_API_KEY=sk-...' >> /root/Centaurion/.env   # OpenAI (default)
# the MCP server reads OPENAI_API_KEY (default) or ANTHROPIC_API_KEY:
echo 'OPENAI_API_KEY=sk-...'       >> /root/Centaurion/.env
# --- OR, for Anthropic instead of OpenAI ---
# echo 'ANTHROPIC_API_KEY=sk-ant-...' >> /root/Centaurion/.env

chmod 600 /root/Centaurion/.env
```

Confirm they load and re-run the test:

```bash
set -a; . /root/Centaurion/.env; set +a
bash deploy/graphiti/test-connection.sh   # all checks should now be ✓
```

## 3. Install Graphiti

**Option A — graphiti-core (Python library, scripted ingest):**

```bash
pip install graphiti-core
# Anthropic provider extra (only if using Claude for extraction):
# pip install "graphiti-core[anthropic]"
```

Minimal one-time index build + a sanity episode (run by the operator after keys
are set — this is the first call that *writes* to the graph):

```python
import asyncio
from datetime import datetime, timezone
from graphiti_core import Graphiti

async def main():
    g = Graphiti(
        uri="bolt://localhost:7687",
        user="neo4j",
        password="<NEO4J_PASSWORD>",   # from env, never hardcode in committed code
    )
    await g.build_indices_and_constraints()      # one-time schema init
    await g.add_episode(
        name="ontraport-decision",
        episode_body="On 2025-09-12 Malik and Anthony decided to migrate AOB off Ontraport to GoHighLevel.",
        source="text",
        source_description="Centaurion decision log",
        reference_time=datetime(2025, 9, 12, tzinfo=timezone.utc),
    )
    # later: results = await g.search("when did we decide to migrate from Ontraport?")

asyncio.run(main())
```

**Option B — Graphiti MCP server (preferred for agent use):**

```bash
git clone https://github.com/getzep/graphiti.git ~/graphiti
cd ~/graphiti/mcp_server
# HTTP transport (default), served at http://localhost:8000/mcp/ :
set -a; . /root/Centaurion/.env; set +a
NEO4J_URI=bolt://localhost:7687 NEO4J_USER=neo4j \
NEO4J_PASSWORD="$NEO4J_PASSWORD" OPENAI_API_KEY="$GRAPHITI_LLM_API_KEY" \
MODEL_NAME=gpt-4o-mini \
  uv run main.py --transport http
# (stdio transport instead: `uv run main.py --transport stdio`)
```

## 4. Register the MCP server with Claude Code

The server config snippet is in [`mcp.json`](./mcp.json) (two documented options).

**HTTP bridge (server running per Option B):**

```bash
claude mcp add graphiti-memory -- npx -y mcp-remote http://localhost:8000/mcp/
```

**stdio (Claude Code launches the server itself, no separate process):**

```bash
set -a; . /root/Centaurion/.env; set +a
claude mcp add graphiti-memory \
  --env NEO4J_URI=bolt://localhost:7687 \
  --env NEO4J_USER=neo4j \
  --env NEO4J_PASSWORD="$NEO4J_PASSWORD" \
  --env OPENAI_API_KEY="$GRAPHITI_LLM_API_KEY" \
  --env MODEL_NAME=gpt-4o-mini \
  -- uv run --directory /root/graphiti/mcp_server main.py --transport stdio
```

Verify:

```bash
claude mcp list   # 'graphiti-memory' should appear and connect
```

### MCP tools exposed

| Tool | Use |
|------|-----|
| `add_memory` / `add_episode` | Ingest an episode (text or JSON); Graphiti extracts entities + temporal edges |
| `search_nodes` | Find entities (people, tools, ventures, concepts) |
| `search_facts` | Query relationships (edges), honouring their validity windows |
| `get_episodes` | Retrieve source episodes with provenance |

## 5. How temporal entity tracking works

Each thing you feed Graphiti is an **episode** (a message, a doc, a decision note).
`add_episode` runs the LLM to extract **entities** (nodes) and **facts** (edges),
then stamps every fact with a **bi-temporal** signature:

| Field | Meaning |
|-------|---------|
| `valid_at` | when the fact became true in the world |
| `invalid_at` | when it stopped being true / was superseded (null = still current) |
| `created_at` | when Graphiti recorded it |
| `expired_at` | administrative expiration |

When a newer episode contradicts an old fact, Graphiti **invalidates** the old
edge (sets `invalid_at`) instead of deleting it. So you can ask both "what is true
*now*?" and "what was true *on date X*?" — and reconstruct how an entity (e.g.
Anna's role, or the Ontraport→GHL decision) evolved over time. See
[`temporal-tracking.md`](./temporal-tracking.md) for the Phase 10 DoD walkthrough.

---

## Files

| File | Purpose |
|------|---------|
| `memory/graphiti.json` | Integration descriptor (status, Neo4j conn, LLM env-ref, MCP, bi-temporal model) |
| `deploy/graphiti/mcp.json` | MCP server config snippet (HTTP-bridge + stdio options; env-refs for secrets) |
| `deploy/graphiti/test-connection.sh` | Read-only Neo4j reachability + secret-presence check |
| `deploy/graphiti/temporal-tracking.md` | Phase 10 DoD and how bi-temporal edges satisfy it |
| `deploy/graphiti/README.md` | This runbook |

## Operator steps (the two things left)

1. **Add `NEO4J_PASSWORD`** (the `neo4j` container's password) to `/root/Centaurion/.env`.
2. **Add an LLM key** — `GRAPHITI_LLM_API_KEY` → `OPENAI_API_KEY` (or `ANTHROPIC_API_KEY`).

Then run §3 install + §4 register. Neo4j itself is already live and verified.
