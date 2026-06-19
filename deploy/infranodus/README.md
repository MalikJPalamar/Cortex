# InfraNodus — Gap Analysis Integration (Phase 9 / PT-7)

> **Status: SCAFFOLD — `pending-key`.** Everything is wired except the API key.
> Drop in `INFRANODUS_API_KEY` and the gap-analysis skill goes live. No live
> connection is fabricated here.

InfraNodus is the **topology lens** for the Centaurion wiki: it turns wiki text
into a knowledge graph and surfaces *structural holes* — disconnected topical
clusters and the bridge concepts that would connect them. This is the engine
behind `skills/gap-analysis/` ("What are we NOT seeing?").

---

## 1. Sign up & get an API key

1. Go to **https://infranodus.com** and create an account (a trial tier is enough
   to validate the integration).
2. Open **https://infranodus.com/api-access** and copy your API token.

## 2. Set the key on the host

The key lives in the host `.env` (gitignored, `600` perms) — never in the repo.

```bash
# On the host (e.g. Hermes / VPS1), append to /root/Centaurion/.env :
echo 'INFRANODUS_API_KEY=in_xxxxxxxxxxxxxxxxxxxx' >> /root/Centaurion/.env
chmod 600 /root/Centaurion/.env
```

Confirm it loads:

```bash
set -a; . /root/Centaurion/.env; set +a
test -n "$INFRANODUS_API_KEY" && echo "INFRANODUS_API_KEY is set" || echo "MISSING"
```

## 3. Wire the MCP server (preferred path)

The official server is `infranodus-mcp-server` (npx). Merge the `mcpServers`
entry from [`mcp.json`](./mcp.json) into the host's Claude Code MCP config
(`~/.claude.json`, or a project `.mcp.json`). With the env var exported, the
server authenticates automatically. Relevant tools for gap analysis:

| Tool | Use |
|------|-----|
| `generate_knowledge_graph` | Build the graph from wiki text |
| `generate_content_gaps`    | List structural holes (the gaps) |
| `generate_topical_clusters`| Name the main clusters |
| `generate_research_questions` | Turn gaps into research questions |
| `develop_conceptual_bridges`  | Suggest bridge concepts |
| `analyze_text`             | One-shot topology + summary |

Quick check after wiring:

```bash
claude mcp list   # 'infranodus' should appear and connect
```

## 4. HTTP API (equivalent path, no MCP)

If you'd rather not run the MCP server, the same capability is a REST call.
Base URL `https://infranodus.com/api/v1/`, bearer auth.

```bash
set -a; . /root/Centaurion/.env; set +a

# Topology + gaps for a wiki page (gapDepth 0 = most prominent gaps):
curl -s https://infranodus.com/api/v1/dotGraphFromText \
  -H "Authorization: Bearer $INFRANODUS_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg text "$(cat docs/centaurion-wiki/*.md)" \
        '{name:"centaurion-wiki", text:$text, gapDepth:0, includeStatements:false}')" \
  | jq '{summary: .graphSummary, gaps: .attributes.gaps}'
```

- `graphSummary` — natural-language topology summary.
- `attributes.gaps` — the structural holes (each = a bridge-question candidate).
- `gapDepth` (0–3) — raise it to iterate from obvious gaps to subtler ones.

## 5. Run a gap analysis over the wiki

Once the key is set, invoke the skill:

```
/gap-analysis            # or: "run the gap analysis" / "what are we missing?"
```

The skill loads the wiki sources (`docs/centaurion-wiki`, and the `aob-wiki` /
`builderbee-wiki` repos once they're split out — see PT-7), runs them through
InfraNodus (MCP tools or the HTTP calls above), and emits the weekly format from
`skills/gap-analysis/SKILL.md`: coverage table, gaps, cross-wiki bridges, and
generated research questions. Highest-value gaps are usually *between* wikis.

---

## Files

| File | Purpose |
|------|---------|
| `memory/infranodus.json` | Integration descriptor (status, endpoints, MCP, consumers) |
| `deploy/infranodus/mcp.json` | MCP server config snippet to merge into the host MCP config |
| `deploy/infranodus/README.md` | This runbook |
| `skills/gap-analysis/SKILL.md` | The consumer skill (see its **InfraNodus Integration** section) |

## Operator step (the one thing left)

**Add `INFRANODUS_API_KEY` to `/root/Centaurion/.env` on the host.** That single
step flips the integration from `scaffolded` to live. Everything else is done.
