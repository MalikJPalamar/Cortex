---
name: gap-analysis
description: Knowledge gap analysis using InfraNodus topology on wiki repos. USE WHEN running the weekly/monthly gap analysis or when Malik asks "what are we missing?"
---

# Gap Analysis — Knowledge Topology

## Purpose

Analyze the three LLM Wiki repos (aob-wiki, builderbee-wiki, centaurion-wiki) for knowledge gaps, disconnected clusters, and unexplored connections. This is L4 sensing — the highest-level review of what the system knows and what it's missing.

## Prerequisites

- InfraNodus connected — MCP server **or** HTTP API (see **InfraNodus Integration** below). Needs `INFRANODUS_API_KEY` on the host; until then the integration is `scaffolded`/`pending-key` and you fall back to manual topology reasoning.
- At least one wiki repo with content to analyze
- Wiki repos: `MalikJPalamar/aob-wiki`, `MalikJPalamar/builderbee-wiki`, `MalikJPalamar/centaurion-wiki`

## Procedure

### 1. Load Wiki Content
Pull current content from all three wiki repos. Identify:
- Total pages per wiki
- Last updated dates
- Topic coverage (what subjects have pages?)

### 2. Run Gap Analysis
Using InfraNodus (or manual analysis if MCP not yet connected):
- **Cluster detection:** What are the main topic clusters in each wiki?
- **Disconnected clusters:** Which clusters have no links between them?
- **Bridge opportunities:** What concepts COULD connect disconnected clusters?
- **Missing topics:** Based on identity/GOALS.md and recent work, what topics SHOULD have wiki pages but don't?

### 3. Cross-Wiki Analysis
The highest-value gaps are often BETWEEN wikis:
- Does AOB knowledge about community management apply to BuilderBee client retention?
- Does BuilderBee's GHL expertise apply to AOB's CRM migration?
- Does Centaurion's framework methodology apply to how AOB structures its facilitator program?

### 4. Generate Research Questions
For each identified gap, generate a research question:
- "How does [concept from wiki A] relate to [concept from wiki B]?"
- "What would happen if we applied [AOB pattern] to [BuilderBee problem]?"
- "What's the relationship between [disconnected cluster 1] and [disconnected cluster 2]?"

### 5. Output

**Weekly format** (GitHub Issue: `[gap-analysis] Week of {date}`):
```markdown
## Knowledge Coverage
| Wiki | Pages | Last Updated | Coverage Score |
|------|-------|-------------|----------------|
| aob-wiki | X | date | X% |
| builderbee-wiki | X | date | X% |
| centaurion-wiki | X | date | X% |

## Gaps Identified
1. [Gap description + why it matters]
2. [Gap description + why it matters]

## Cross-Wiki Connections
- [Potential bridge between wikis]

## Research Questions Generated
- [ ] [Question 1]
- [ ] [Question 2]
- [ ] [Question 3]

## Recommended Actions
- [Specific wiki pages to create or update]
```

## InfraNodus Integration

InfraNodus is the engine for steps 2–4 above. It builds a text-network graph of
the wiki and returns the *structural holes* (gaps) plus the bridge concepts and
research questions that fill them. **Status: scaffolded — set `INFRANODUS_API_KEY`
on the host to activate.** Full runbook: `deploy/infranodus/README.md`. Descriptor:
`memory/infranodus.json`.

**Two equivalent paths:**

1. **MCP (preferred)** — config snippet in `deploy/infranodus/mcp.json`
   (`infranodus-mcp-server` via npx). Once the key is set and the server is merged
   into the host MCP config, call these tools on the wiki text:
   - `generate_knowledge_graph` → build the graph
   - `generate_topical_clusters` → name the clusters (step 2)
   - `generate_content_gaps` → list structural holes (step 2)
   - `develop_conceptual_bridges` → bridge concepts (step 2)
   - `generate_research_questions` → turn gaps into questions (step 4)

2. **HTTP API** — `POST https://infranodus.com/api/v1/dotGraphFromText` with
   `Authorization: Bearer ${INFRANODUS_API_KEY}`, body `{name, text, gapDepth}`.
   Read `.graphSummary` and `.attributes.gaps` from the response. `gapDepth` 0→3
   walks from the most prominent gaps to subtler ones (re-run, raising it, to mine
   the cross-wiki gaps in step 3). See the README for a copy-paste `curl`.

**Invocation:** with the key set, run `/gap-analysis` (or "what are we missing?").
Without the key, proceed with manual topology reasoning and flag that InfraNodus
is `pending-key` in the output.

## Example

For example, gap analysis might reveal that the AOB wiki has a "facilitator onboarding" cluster and BuilderBee wiki has a "client onboarding" cluster, but they are disconnected. The bridge question: "Can the facilitator onboarding checklist pattern be reused for BuilderBee client onboarding?" — creating a cross-venture template.

## Frequency

Weekly (automated via gh-aw). Monthly deep analysis as part of L4 closed-loop review.
