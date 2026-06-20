# MemPalace — Claude Conversation-Export Miner (Phase 10 / Knowledge Graph)

> **Status: SCAFFOLD — runnable today.** The extraction pass is real, stdlib-only,
> and needs no API key or network. The downstream emit to Graphiti + Supermemory
> is documented below but **intentionally not fabricated** — no live round-trip is
> claimed.

MemPalace is **Layer 3** of the memory stack: the *verbatim archive*. This piece
is its front-end miner — it reads Claude conversation exports and turns
decision/fact statements into a structured extract that feeds the knowledge
graph. It is the concrete answer to the Phase 10 Definition of Done:

> *"Agent answers 'When did we decide to migrate from Ontraport?' from Graphiti."*

Every extracted **decision** carries a `timestamp` + `speaker` + verbatim `text`,
so "when did we decide X?" becomes a lookup once these land as Graphiti episodes.

---

## 1. Where Claude exports live / how to obtain them

The miner accepts any directory of `.json` / `.jsonl` files in a Claude-ish shape.
Two common sources:

| Source | How to get it |
|--------|---------------|
| **claude.ai data export** | claude.ai → Settings → *Account* → **Export data**. You receive a zip containing `conversations.json` (an array of conversation objects, each with a `chat_messages` / `messages` list). Unzip it into `deploy/mempalace/exports/`. |
| **Claude Code session transcripts** | Local JSONL transcripts under `~/.claude/projects/<project>/*.jsonl`. Copy or symlink the ones you want mined into `deploy/mempalace/exports/`. |

The parser is **defensive**: it handles conversation objects (`{"messages": [...]}`
or `{"chat_messages": [...]}`), bare lists of conversations, flat lists of
messages, single messages, and several content shapes (string, list of content
blocks, `{text|value}` dicts). Malformed lines/files are skipped with a warning,
not a crash.

> **Privacy:** `deploy/mempalace/exports/` is **gitignored**. Raw transcripts hold
> private content — never commit them. Only the `.gitkeep` placeholder is tracked.

---

## 2. Run the miner

No install step. Python 3 stdlib only.

```bash
cd deploy/mempalace

# See all options
python3 mine_conversations.py --help

# Dry run: parse + count + preview, write nothing
python3 mine_conversations.py exports --dry-run

# Real run: writes mempalace-extract.jsonl next to you
python3 mine_conversations.py exports

# Custom output path
python3 mine_conversations.py /path/to/exports --out /tmp/extract.jsonl
```

Safe edge cases (both exit `0` with a friendly message, no traceback):

```bash
python3 mine_conversations.py ./does-not-exist   # missing dir
python3 mine_conversations.py exports            # empty dir
```

---

## 3. What it extracts

For every message it splits the body into sentence-ish units and classifies each:

- **`decision`** — contains a decision verb: `decided`, `chose`, `will use`,
  `going with`, `switched to`, `migrated`, `migrate from`, `settled on`,
  `picked`, `opted for`, … (full list in `mine_conversations.py`).
- **`fact`** — contains a fact marker: `because`, `the reason`, `turns out`,
  `note that`, `important:`, `key insight`, …

Output: **`mempalace-extract.jsonl`**, one JSON object per item:

```json
{"timestamp": "2026-03-02T14:11:00Z", "source_file": "conversations.json", "type": "decision", "text": "We decided to migrate from Ontraport to GoHighLevel.", "speaker": "assistant"}
```

| Field | Meaning |
|-------|---------|
| `timestamp` | message time (falls back to conversation-level time, or `null`) |
| `source_file` | export filename the item came from |
| `type` | `decision` or `fact` |
| `text` | the verbatim statement (capped at 600 chars) |
| `speaker` | `role` / `sender` / `author` (e.g. `human`, `assistant`) |

This is a **recall-first** heuristic pass — it favors catching real decisions
over precision. Tune the verb/marker lists in the script as the corpus grows.

---

## 4. Where the output goes (downstream — documented, not wired)

`mempalace-extract.jsonl` is the hand-off into the knowledge graph. Two sinks:

### a. Graphiti (primary) — `memory/graphiti.json`

Each record becomes a **temporal episode**. With Graphiti's MCP/SDK wired to the
live Neo4j on VPS1 (`bolt://…:7687`), the loop is:

```text
for record in mempalace-extract.jsonl:
    graphiti.add_episode(
        name=f"{record['type']}:{record['source_file']}",
        episode_body=record['text'],
        reference_time=record['timestamp'],   # makes "when did we decide X?" answerable
        source_description=f"mempalace miner / speaker={record['speaker']}",
    )
```

This is the step that satisfies the Phase 10 DoD: decisions land as
timestamped episodes, so Graphiti can answer *"When did we first decide to
migrate from Ontraport?"*.

### b. Supermemory (secondary) — `memory/supermemory.json`

Each record is also written as a **document** to the relevant container
(`aob` / `builderbee` / `centaurion`) via `POST /v3/documents`, giving the
real-time bus a searchable copy.

> **Why not wired here:** wiring requires a live Neo4j password
> (`NEO4J_PASSWORD`) and `SUPERMEMORY_API_KEY`, both of which live only in the
> host `/root/Centaurion/.env` (gitignored, `600`). Per the project's
> no-fabrication rule, the emit is left as a documented, copy-pasteable step
> rather than a fake "verified" integration. Set those env vars on the host to
> light it up.

---

## 5. How this supports Phase 10

```text
Claude exports ──▶ mine_conversations.py ──▶ mempalace-extract.jsonl
                     (decisions + facts,            │
                      timestamped, verbatim)        ▼
                                          Graphiti episodes (temporal)  ──▶ "When did we decide X?"
                                          Supermemory documents (recall)
```

The miner is the deterministic, offline bridge between raw conversation history
and the temporal graph. It needs no keys to produce value today; the graph emit
flips on the moment the sibling Graphiti scaffold is wired.

---

## Files

| File | Purpose |
|------|---------|
| `memory/mempalace.json` | Integration descriptor (status, miner spec, downstream sinks, env refs) |
| `deploy/mempalace/mine_conversations.py` | The miner (stdlib-only, `--help`, `--dry-run`) |
| `deploy/mempalace/README.md` | This runbook |
| `deploy/mempalace/exports/` | Drop Claude exports here (**gitignored** — only `.gitkeep` tracked) |

## Operator step (the one thing left to go live downstream)

Wire the sibling **Graphiti** scaffold (`memory/graphiti.json`) — set
`NEO4J_PASSWORD` (and optionally `SUPERMEMORY_API_KEY`) in
`/root/Centaurion/.env` — then run the emit loop in §4 over the extract. The
extraction pass itself already runs with zero setup.
